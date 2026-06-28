import Foundation

/// A unified profile of a StarCraft II player, aggregated across every configured source.
///
/// `PlayerProfile` is the SDK's flagship composite: it fuses SC2 Pulse ladder identity
/// (MMR, race, region, clan, pro/Aligulac cross-links), Aligulac skill ratings, and the
/// PandaScore pro profile and upcoming pro matches into one object. Fields are `nil` when
/// the relevant source isn't configured or has no data, so a profile degrades gracefully.
public struct PlayerProfile: Sendable {
    /// The query used to resolve this player.
    public let query: String
    /// Best display name resolved across sources.
    public let displayName: String
    /// SC2 Pulse ladder identity (free): MMR, race, region, clan, online links.
    public let ladder: LadderCharacter?
    /// Aligulac Bayesian rating with race matchups.
    public let rating: AligulacRating?
    /// PandaScore professional profile.
    public let proPlayer: Player?
    /// Upcoming professional matches from PandaScore.
    public let upcomingProMatches: [Match]

    /// Best available ladder MMR.
    public var mmr: Int? { ladder?.mmr }
    /// Current ladder rank, if ranked this season.
    public var ladderRank: Int? { ladder?.rank }
    /// Main race across sources.
    public var race: Race? { ladder?.mainRace }
    /// Battle.net region.
    public var region: String? { ladder?.region }
    /// ISO country code, preferring the pro profile.
    public var country: String? {
        proPlayer?.nationality ?? ladder?.members.proPlayer?.proPlayer?.country
    }
    /// Career earnings in USD (SC2 Pulse).
    public var earnings: Int? { ladder?.earnings }
    /// Clan tag, if any.
    public var clanTag: String? { ladder?.clanTag }
    /// Linked Aligulac id, if known.
    public var aligulacId: Int? { ladder?.aligulacId }
    /// Whether this player has a known professional identity.
    public var isPro: Bool { proPlayer != nil || ladder?.proNickname != nil }
    /// The sources that contributed data to this profile.
    public var contributingSources: [DataSource] {
        var sources: [DataSource] = []
        if ladder != nil { sources.append(.sc2Pulse) }
        if rating != nil { sources.append(.aligulac) }
        if proPlayer != nil || !upcomingProMatches.isEmpty { sources.append(.pandaScore) }
        return sources
    }
}

/// A predictive preview of a matchup between two players.
///
/// Combines Aligulac's win-probability prediction and head-to-head record with each
/// player's current ladder MMR for a complete pre-match picture.
public struct Matchup: Sendable {
    public let playerA: String
    public let playerB: String
    public let bestOf: Int
    /// Aligulac win-probability prediction.
    public let prediction: AligulacMatchPrediction?
    /// All-time head-to-head record.
    public let headToHead: HeadToHead?
    /// Player A's ladder identity.
    public let ladderA: LadderCharacter?
    /// Player B's ladder identity.
    public let ladderB: LadderCharacter?

    /// Current ladder MMR gap (A − B), when both are known.
    public var mmrDifference: Int? {
        guard let a = ladderA?.mmr, let b = ladderB?.mmr else { return nil }
        return a - b
    }

    /// The favored player's name by Aligulac probability, if available.
    public var favorite: String? {
        guard let pa = prediction?.probabilityA, let pb = prediction?.probabilityB else { return nil }
        return pa >= pb ? playerA : playerB
    }
}

/// A snapshot of everything happening in StarCraft II right now.
///
/// Fuses the pro scene (live PandaScore matches and running tournaments) with the
/// ladder community (live SC2 Pulse streams) into a single "what's on" view.
public struct LiveScene: Sendable {
    /// Currently live professional matches (PandaScore).
    public let liveMatches: [Match]
    /// Live community streams with viewer counts (SC2 Pulse, free).
    public let liveStreams: [LadderStream]
    /// Tournaments currently running (PandaScore).
    public let runningTournaments: [Tournament]

    /// Total live viewers across all community streams.
    public var totalViewers: Int {
        liveStreams.reduce(0) { $0 + ($1.stream.viewerCount ?? 0) }
    }
    /// Whether anything is happening right now.
    public var isActive: Bool {
        !liveMatches.isEmpty || !liveStreams.isEmpty
    }
}

/// A snapshot of the ranked ladder leaderboard.
public struct LadderSnapshot: Sendable {
    public let region: SC2Region?
    public let league: LadderLeague
    public let queue: LadderQueue
    public let teams: [LadderTeam]
}

/// The data sources StarCraftKit can aggregate.
public enum DataSource: String, Sendable, CaseIterable {
    /// PandaScore — professional esports (matches, tournaments, players, teams). Needs a token.
    case pandaScore
    /// Aligulac — Bayesian ratings, predictions, head-to-head. Needs a free key.
    case aligulac
    /// SC2 Pulse — free, no-auth ladder/MMR, streams, clans, identity cross-links.
    case sc2Pulse
    /// Blizzard Battle.net — official ladder/profile/grandmaster. Needs OAuth credentials.
    case blizzard
}
