import Foundation

/// The unified entry point to all of StarCraft II.
///
/// `StarCraft` is a single abstraction over every data source StarCraftKit can reach —
/// the professional scene (PandaScore), skill ratings and predictions (Aligulac), and the
/// free, no-auth ladder/streams community data (SC2 Pulse). It exposes both thin
/// pass-throughs and **composite interfaces** that fuse the sources into one answer:
/// ``profile(of:)``, ``matchup(_:vs:bestOf:)`` and ``liveScene()``.
///
/// ```swift
/// // SC2 Pulse works with no key at all; add tokens to unlock more.
/// let sc = StarCraft(pandaScoreToken: panda, aligulacKey: aligulac)
///
/// let serral = try await sc.profile(of: "Serral")   // ladder MMR + rating + pro profile
/// let preview = try await sc.matchup("Serral", vs: "Maru")
/// let now = try await sc.liveScene()                // live matches + streams + tournaments
/// ```
///
/// Sources you don't configure simply contribute nothing — composites degrade gracefully.
public struct StarCraft: Sendable {
    /// Free, no-auth ladder/streams source. Always available.
    public let pulse: SC2PulseClient
    /// Professional esports source (PandaScore). `nil` unless a token was provided.
    public let pandaScore: StarCraftClient?
    /// Ratings & predictions source (Aligulac). `nil` unless a key was provided.
    public let aligulac: AligulacClient?
    /// Official Blizzard source. `nil` unless OAuth credentials were provided.
    public let blizzard: BlizzardClient?

    public struct Configuration: Sendable {
        public var pandaScoreToken: String?
        public var aligulacKey: String?
        public var blizzardCredentials: BlizzardCredentials?
        public var pulseConfiguration: SC2PulseClient.Configuration

        public init(
            pandaScoreToken: String? = nil,
            aligulacKey: String? = nil,
            blizzardCredentials: BlizzardCredentials? = nil,
            pulseConfiguration: SC2PulseClient.Configuration = .init()
        ) {
            self.pandaScoreToken = pandaScoreToken
            self.aligulacKey = aligulacKey
            self.blizzardCredentials = blizzardCredentials
            self.pulseConfiguration = pulseConfiguration
        }
    }

    public init(configuration: Configuration) {
        self.pulse = SC2PulseClient(configuration: configuration.pulseConfiguration)
        self.pandaScore = configuration.pandaScoreToken.map { StarCraftClient(apiToken: $0) }
        self.aligulac = configuration.aligulacKey.map { AligulacClient(apiKey: $0) }
        self.blizzard = configuration.blizzardCredentials.map { BlizzardClient(credentials: $0) }
    }

    /// Compose the facade from already-configured source clients (power users & testing).
    public init(
        pulse: SC2PulseClient,
        pandaScore: StarCraftClient? = nil,
        aligulac: AligulacClient? = nil,
        blizzard: BlizzardClient? = nil
    ) {
        self.pulse = pulse
        self.pandaScore = pandaScore
        self.aligulac = aligulac
        self.blizzard = blizzard
    }

    /// Convenience initializer. Omit a credential to disable that source.
    public init(
        pandaScoreToken: String? = nil,
        aligulacKey: String? = nil,
        blizzardCredentials: BlizzardCredentials? = nil
    ) {
        self.init(configuration: Configuration(
            pandaScoreToken: pandaScoreToken,
            aligulacKey: aligulacKey,
            blizzardCredentials: blizzardCredentials
        ))
    }

    /// The sources currently configured.
    public var availableSources: [DataSource] {
        var sources: [DataSource] = [.sc2Pulse]
        if pandaScore != nil { sources.append(.pandaScore) }
        if aligulac != nil { sources.append(.aligulac) }
        if blizzard != nil { sources.append(.blizzard) }
        return sources
    }

    // MARK: - Official Blizzard data

    /// The official Blizzard grandmaster ladder for a region.
    public func officialLadder(region: BlizzardRegion) async throws -> [GrandmasterTeam] {
        try await requireBlizzard().grandmasterLadder(region: region)
    }

    /// The official current ranked season for a region.
    public func officialSeason(region: BlizzardRegion) async throws -> BlizzardSeason {
        try await requireBlizzard().currentSeason(region: region)
    }

    private func requireBlizzard() throws -> BlizzardClient {
        guard let blizzard else {
            throw APIError.invalidRequest(reason: "Blizzard source not configured — provide OAuth credentials")
        }
        return blizzard
    }

    // MARK: - Composite interfaces

    /// Resolve a complete cross-source profile for a player by name.
    public func profile(of name: String) async throws -> PlayerProfile {
        let characters = try await pulse.searchCharacters(name)
        let ladder = Self.bestMatch(characters, for: name)

        async let ratingResult = resolveRating(ladder: ladder, name: name)
        async let proResult = resolveProProfile(ladder: ladder, name: name)

        let rating = await ratingResult
        let (proPlayer, upcoming) = await proResult

        let displayName = ladder?.displayName ?? proPlayer?.name ?? name
        return PlayerProfile(
            query: name,
            displayName: displayName,
            ladder: ladder,
            rating: rating,
            proPlayer: proPlayer,
            upcomingProMatches: upcoming
        )
    }

    /// Build a predictive preview of a matchup between two players.
    public func matchup(_ playerA: String, vs playerB: String, bestOf: Int = 5) async throws -> Matchup {
        async let charsATask = pulse.searchCharacters(playerA)
        async let charsBTask = pulse.searchCharacters(playerB)
        let ladderA = Self.bestMatch(try await charsATask, for: playerA)
        let ladderB = Self.bestMatch(try await charsBTask, for: playerB)

        var prediction: AligulacMatchPrediction?
        var headToHead: HeadToHead?
        if let aligulac {
            async let idATask = resolveAligulacId(ladder: ladderA, name: playerA)
            async let idBTask = resolveAligulacId(ladder: ladderB, name: playerB)
            if let idA = await idATask, let idB = await idBTask {
                async let predictionTask = try? aligulac.predictMatch(playerA: idA, playerB: idB, bestOf: bestOf)
                async let h2hTask = try? aligulac.headToHead(playerA: idA, playerB: idB)
                prediction = await predictionTask
                headToHead = await h2hTask
            }
        }

        return Matchup(
            playerA: ladderA?.displayName ?? playerA,
            playerB: ladderB?.displayName ?? playerB,
            bestOf: bestOf,
            prediction: prediction,
            headToHead: headToHead,
            ladderA: ladderA,
            ladderB: ladderB
        )
    }

    /// A snapshot of everything happening right now: pro matches, community streams, tournaments.
    public func liveScene() async throws -> LiveScene {
        async let streamsTask = pulse.liveStreams()

        var liveMatches: [Match] = []
        var runningTournaments: [Tournament] = []
        if let pandaScore {
            async let matchesTask = pandaScore.getLiveMatches()
            async let tournamentsTask = pandaScore.getTournaments(.running())
            liveMatches = (try? await matchesTask) ?? []
            runningTournaments = (try? await tournamentsTask) ?? []
        }
        let streams = (try? await streamsTask) ?? []

        return LiveScene(liveMatches: liveMatches, liveStreams: streams, runningTournaments: runningTournaments)
    }

    // MARK: - Ladder (free / SC2 Pulse)

    /// The ranked ladder leaderboard.
    public func topLadder(
        region: SC2Region? = nil,
        race: Race? = nil,
        league: LadderLeague = .grandmaster,
        queue: LadderQueue = .lotv1v1,
        limit: Int = 50
    ) async throws -> LadderSnapshot {
        let teams = try await pulse.topLadder(region: region, race: race, league: league, queue: queue, limit: limit)
        return LadderSnapshot(region: region, league: league, queue: queue, teams: teams)
    }

    /// Live community streams (free).
    public func liveStreams(limit: Int = 50) async throws -> [LadderStream] {
        try await pulse.liveStreams(limit: limit)
    }

    /// Ladder seasons across regions.
    public func seasons() async throws -> [PulseSeason] {
        try await pulse.seasons()
    }

    /// Known game patches.
    public func patches() async throws -> [GamePatch] {
        try await pulse.patches()
    }

    // MARK: - Pro scene (PandaScore pass-throughs)

    public func liveMatches() async throws -> [Match] {
        try await requirePandaScore().getLiveMatches()
    }
    public func upcomingMatches() async throws -> [Match] {
        try await requirePandaScore().getUpcomingMatches()
    }
    public func pastMatches() async throws -> [Match] {
        try await requirePandaScore().getPastMatches()
    }
    public func tournaments(_ request: TournamentsRequest = TournamentsRequest()) async throws -> [Tournament] {
        try await requirePandaScore().getTournaments(request)
    }

    // MARK: - Private

    private func requirePandaScore() throws -> StarCraftClient {
        guard let pandaScore else {
            throw APIError.invalidRequest(reason: "PandaScore source not configured — provide a token to use the pro scene")
        }
        return pandaScore
    }

    private func resolveAligulacId(ladder: LadderCharacter?, name: String) async -> Int? {
        if let id = ladder?.aligulacId { return id }
        guard let aligulac else { return nil }
        let searchName = ladder?.proNickname ?? name
        let candidates = try? await aligulac.searchPlayers(tag: searchName)
        return candidates?.first { $0.tag?.caseInsensitiveCompare(searchName) == .orderedSame }?.id
            ?? candidates?.first?.id
    }

    private func resolveRating(ladder: LadderCharacter?, name: String) async -> AligulacRating? {
        guard let aligulac else { return nil }
        guard let id = await resolveAligulacId(ladder: ladder, name: name) else { return nil }
        return try? await aligulac.rating(playerID: id)
    }

    private func resolveProProfile(ladder: LadderCharacter?, name: String) async -> (player: Player?, upcoming: [Match]) {
        guard let pandaScore else { return (nil, []) }
        let searchName = ladder?.proNickname ?? name
        let candidates = (try? await pandaScore.searchPlayers(name: searchName)) ?? []
        let match = candidates.first { $0.name.caseInsensitiveCompare(searchName) == .orderedSame } ?? candidates.first
        guard let player = match else {
            return (nil, [])
        }
        let upcoming = (try? await pandaScore.getMatches(
            MatchesRequest(endpoint: .upcoming, opponentID: player.id)
        )) ?? []
        return (player, upcoming)
    }

    private static func bestMatch(_ characters: [LadderCharacter], for name: String) -> LadderCharacter? {
        characters.first {
            $0.name?.caseInsensitiveCompare(name) == .orderedSame ||
            $0.proNickname?.caseInsensitiveCompare(name) == .orderedSame
        } ?? characters.first
    }
}
