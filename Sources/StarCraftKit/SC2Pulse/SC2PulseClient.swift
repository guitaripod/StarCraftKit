import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Logging

/// Element wrapper that decodes to `nil` instead of throwing, so a single malformed
/// row never aborts an entire array decode.
struct FailableDecodable<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try? container.decode(T.self)
    }
}

/// A client for the free, no-auth SC2 Pulse API (`https://sc2pulse.nephest.com/sc2/`).
///
/// SC2 Pulse aggregates Blizzard ladder data and adds cross-references that make it the
/// ideal free identity hub: ladder MMR, race distribution, clans, live community streams,
/// and links from a ladder account to its pro player and Aligulac id — all without an API key.
public actor SC2PulseClient {
    private let networkingClient: NetworkingClient
    private let retryHandler: RetryHandler
    private let decoder: JSONDecoder
    private let configuration: Configuration

    public struct Configuration: Sendable {
        public let baseURL: URL
        /// SC2 Pulse asks integrators to send an identifying User-Agent.
        public let userAgent: String
        public let retryConfiguration: RetryConfiguration
        public let urlSessionConfiguration: URLSessionConfiguration

        public init(
            baseURL: URL = URL(string: "https://sc2pulse.nephest.com/sc2/")!,
            userAgent: String = "StarCraftKit/2.0 (+https://github.com/guitaripod/StarCraftKit)",
            retryConfiguration: RetryConfiguration = .default,
            urlSessionConfiguration: URLSessionConfiguration = .default
        ) {
            self.baseURL = baseURL
            self.userAgent = userAgent
            self.retryConfiguration = retryConfiguration
            self.urlSessionConfiguration = urlSessionConfiguration
        }
    }

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        let session = URLSession(configuration: configuration.urlSessionConfiguration)
        self.networkingClient = NetworkingClient(
            baseURL: configuration.baseURL,
            session: session,
            defaultHeaders: ["User-Agent": configuration.userAgent],
            logger: Logger(label: "StarCraftKit.SC2Pulse.Networking")
        )
        self.retryHandler = RetryHandler(
            configuration: configuration.retryConfiguration,
            logger: Logger(label: "StarCraftKit.SC2Pulse.Retry")
        )
        self.decoder = JSONDecoder()
    }

    // MARK: - Characters / identity

    /// Search ladder characters by name. Results carry MMR, race, clan and any linked
    /// pro/Aligulac identity.
    public func searchCharacters(_ query: String) async throws -> [LadderCharacter] {
        try await lenientArray(path: "api/characters", query: ["query": .string(query)])
    }

    /// Characters linked to a given Aligulac/SC2-Pulse pro player id.
    public func characters(proPlayerId: Int) async throws -> [LadderCharacter] {
        try await lenientArray(path: "api/characters", query: ["proPlayerId": .int(proPlayerId)])
    }

    // MARK: - Ladder

    /// The current ranked ladder leaderboard, highest rated first.
    public func topLadder(
        region: SC2Region? = nil,
        race: Race? = nil,
        league: LadderLeague = .grandmaster,
        queue: LadderQueue = .lotv1v1,
        limit: Int = 50
    ) async throws -> [LadderTeam] {
        var query: [String: QueryValue] = [
            "recent": .string(""),
            "queue": .string(queue.rawValue),
            "league": .string(league.rawValue),
            "limit": .int(limit)
        ]
        if let region { query["region"] = .string(region.rawValue) }
        if let race { query["race"] = .string(Self.pulseRace(race)) }
        return try await lenientArray(path: "api/teams", query: query)
    }

    /// All known ladder seasons across regions.
    public func seasons() async throws -> [PulseSeason] {
        try await lenientArray(path: "api/seasons", query: [:])
    }

    // MARK: - Live streams

    /// Live StarCraft II community streams, with viewer counts and linked pro players.
    public func liveStreams(limit: Int = 50) async throws -> [LadderStream] {
        let (data, _) = try await fetch(path: "api/streams", query: ["limit": .int(limit)])
        struct Wrapper: Decodable { let streams: [FailableDecodable<LadderStream>]? }
        let wrapper = try decodeOrThrow(Wrapper.self, from: data)
        return wrapper.streams?.compactMap(\.value) ?? []
    }

    // MARK: - Matches

    /// Recent ladder matches for a character (most recent first).
    public func recentMatches(characterId: Int, limit: Int = 20) async throws -> [LadderMatch] {
        let (data, _) = try await fetch(
            path: "api/character-matches",
            query: ["characterId": .int(characterId), "limit": .int(limit)]
        )
        struct Wrapper: Decodable { let result: [FailableDecodable<LadderMatch>]? }
        let wrapper = try decodeOrThrow(Wrapper.self, from: data)
        return wrapper.result?.compactMap(\.value) ?? []
    }

    /// MMR thresholds keyed by region → league → tier, flattened to a list.
    public func tierThresholds(
        queue: LadderQueue = .lotv1v1,
        teamType: LadderTeamType = .arranged,
        season: Int,
        region: SC2Region? = nil
    ) async throws -> [LadderTier] {
        var query: [String: QueryValue] = [
            "queue": .string(queue.rawValue),
            "teamType": .string(teamType.rawValue),
            "season": .int(season)
        ]
        if let region { query["region"] = .string(region.rawValue) }
        let (data, _) = try await fetch(path: "api/tier-thresholds", query: query)
        let nested = (try? decoder.decode([String: [String: [String: [Int]]]].self, from: data)) ?? [:]
        var result: [LadderTier] = []
        for (_, leagues) in nested {
            for (leagueKey, tiers) in leagues {
                let leagueId = Int(leagueKey)
                for (_, bounds) in tiers where bounds.count >= 2 {
                    result.append(LadderTier(type: nil, minRating: bounds[0], maxRating: bounds[1], leagueId: leagueId))
                }
            }
        }
        return result
    }

    // MARK: - Meta

    /// Known game patches (most recent first).
    public func patches() async throws -> [GamePatch] {
        let (data, _) = try await fetch(path: "api/patches", query: [:])
        struct Wrapper: Decodable { let patch: GamePatch? }
        let wrapped = try decodeOrThrow([FailableDecodable<Wrapper>].self, from: data)
        return wrapped.compactMap { $0.value?.patch }
    }

    /// Search clans by name or tag.
    public func clans(query: String) async throws -> [PulseClan] {
        try await lenientArray(path: "api/clans", query: ["query": .string(query)])
    }

    // MARK: - Private

    private func lenientArray<T: Decodable>(path: String, query: [String: QueryValue]) async throws -> [T] {
        let (data, _) = try await fetch(path: path, query: query)
        let wrapped = try decodeOrThrow([FailableDecodable<T>].self, from: data)
        return wrapped.compactMap(\.value)
    }

    private func fetch(path: String, query: [String: QueryValue]) async throws -> (Data, [String: String]) {
        let request = try await networkingClient.buildRequest(path: path, method: .get, queryParameters: query)
        return try await retryHandler.send(client: networkingClient, request: request)
    }

    private func decodeOrThrow<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(underlying: error, data: data)
        }
    }

    private static func pulseRace(_ race: Race) -> String {
        switch race {
        case .terran: return "TERRAN"
        case .protoss: return "PROTOSS"
        case .zerg: return "ZERG"
        case .random, .unknown: return "RANDOM"
        }
    }
}
