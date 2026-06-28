import Foundation

/// Battle.net regions for the official Blizzard SC2 API (China uses separate credentials
/// and is intentionally omitted).
public enum BlizzardRegion: String, Sendable, CaseIterable {
    case us, eu, kr, tw

    /// Numeric region id used in SC2 API paths (KR and TW share id 3).
    public var regionId: Int {
        switch self {
        case .us: return 1
        case .eu: return 2
        case .kr, .tw: return 3
        }
    }

    /// API host for this region.
    public var apiHost: URL {
        URL(string: "https://\(rawValue).api.blizzard.com")!
    }
}

/// OAuth client credentials for the Blizzard API (register at develop.battle.net).
public struct BlizzardCredentials: Sendable {
    public let clientId: String
    public let clientSecret: String

    public init(clientId: String, clientSecret: String) {
        self.clientId = clientId
        self.clientSecret = clientSecret
    }
}

struct BlizzardToken: Decodable, Sendable {
    let accessToken: String
    let expiresIn: Int

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}

/// The current ranked season for a region. Dates arrive as quoted Unix-epoch strings.
public struct BlizzardSeason: Codable, Sendable {
    public let seasonId: Int
    public let number: Int?
    public let year: Int?
    public let startDate: String?
    public let endDate: String?

    public var start: Date? { Self.date(from: startDate) }
    public var end: Date? { Self.date(from: endDate) }

    private static func date(from epochString: String?) -> Date? {
        guard let epochString, let seconds = TimeInterval(epochString) else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }
}

/// A member of a grandmaster ladder team (ids arrive as strings; clanTag is optional).
public struct GrandmasterMember: Codable, Sendable {
    public let id: String?
    public let realm: Int?
    public let region: Int?
    public let displayName: String?
    public let clanTag: String?
    public let favoriteRace: String?

    public var race: Race? { favoriteRace.flatMap { Race(pulseName: $0) } }
}

/// One row of the official grandmaster ladder.
public struct GrandmasterTeam: Codable, Sendable {
    public let teamMembers: [GrandmasterMember]?
    public let previousRank: Int?
    public let points: Int?
    public let wins: Int?
    public let losses: Int?
    public let mmr: Int?
    public let joinTimestamp: Int64?

    public var primary: GrandmasterMember? { teamMembers?.first }
    public var name: String? { primary?.displayName }
    public var race: Race? { primary?.race }

    public var winRate: Double? {
        let w = wins ?? 0
        let total = w + (losses ?? 0)
        guard total > 0 else { return nil }
        return Double(w) / Double(total)
    }
}

struct GrandmasterLadder: Codable, Sendable {
    let ladderTeams: [GrandmasterTeam]?
}

/// Compact official profile (career win counts and totals).
public struct BlizzardProfile: Codable, Sendable {
    public struct Summary: Codable, Sendable {
        public let displayName: String?
        public let totalSwarmLevel: Int?
        public let totalAchievementPoints: Int?
    }
    public struct Career: Codable, Sendable {
        public let terranWins: Int?
        public let zergWins: Int?
        public let protossWins: Int?
        public let totalCareerGames: Int?
        public let totalGamesThisSeason: Int?
        public let current1v1LeagueName: String?
    }
    public let summary: Summary?
    public let career: Career?
}

/// Profile lookup metadata (the `name` field is the display name here).
public struct BlizzardProfileMetadata: Codable, Sendable {
    public let name: String?
    public let profileUrl: String?
    public let avatarUrl: String?
    public let profileId: String?
    public let regionId: Int?
    public let realmId: Int?
}
