import Foundation

/// StarCraft II races as classified by Aligulac.
public enum Race: String, Codable, Sendable, CaseIterable {
    case protoss = "P"
    case terran = "T"
    case zerg = "Z"
    case random = "R"
    case unknown = "S"

    public var displayName: String {
        switch self {
        case .protoss: return "Protoss"
        case .terran: return "Terran"
        case .zerg: return "Zerg"
        case .random: return "Random"
        case .unknown: return "Unknown"
        }
    }
}

/// Pagination metadata returned by every Aligulac list response.
public struct AligulacMeta: Codable, Sendable {
    public let limit: Int?
    public let offset: Int?
    public let totalCount: Int?
    public let next: String?
    public let previous: String?

    private enum CodingKeys: String, CodingKey {
        case limit, offset, next, previous
        case totalCount = "total_count"
    }
}

/// A page of Aligulac objects (`{ "meta": ..., "objects": [...] }`).
public struct AligulacPage<Object: Codable & Sendable>: Codable, Sendable {
    public let meta: AligulacMeta
    public let objects: [Object]
}

/// A professional StarCraft II player as tracked by Aligulac.
///
/// Aligulac is the canonical community ratings database; it provides data PandaScore
/// does not — Bayesian skill ratings, race-matchup performance, and deep history.
public struct AligulacPlayer: Codable, Sendable, Identifiable {
    public let id: Int
    public let tag: String?
    public let name: String?
    public let country: String?
    public let race: Race?
    public let birthday: String?
    /// Resource URI of the player's current rating (resolve via ``AligulacClient/rating(playerID:)``).
    public let currentRating: String?

    private enum CodingKeys: String, CodingKey {
        case id, tag, name, country, race, birthday
        case currentRating = "current_rating"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.tag = try? container.decodeIfPresent(String.self, forKey: .tag)
        self.name = try? container.decodeIfPresent(String.self, forKey: .name)
        self.country = try? container.decodeIfPresent(String.self, forKey: .country)
        self.race = try? container.decodeIfPresent(Race.self, forKey: .race)
        self.birthday = try? container.decodeIfPresent(String.self, forKey: .birthday)
        self.currentRating = try? container.decodeIfPresent(String.self, forKey: .currentRating)
    }
}

/// A Bayesian skill rating for a player in a given rating period.
///
/// Ratings are race-matchup specific: ``ratingVsProtoss``, ``ratingVsTerran`` and
/// ``ratingVsZerg`` capture how the player performs against each opposing race.
public struct AligulacRating: Codable, Sendable, Identifiable {
    public let id: Int
    public let player: String?
    public let period: String?
    /// Overall rating (0 is average; units are roughly +/- 1.0 across the field).
    public let rating: Double?
    public let ratingVsProtoss: Double?
    public let ratingVsTerran: Double?
    public let ratingVsZerg: Double?
    /// Rating uncertainty (standard deviation).
    public let dev: Double?
    public let position: Int?
    public let decay: Int?

    private enum CodingKeys: String, CodingKey {
        case id, player, period, rating, dev, position, decay
        case ratingVsProtoss = "rating_vp"
        case ratingVsTerran = "rating_vt"
        case ratingVsZerg = "rating_vz"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.player = try? container.decodeIfPresent(String.self, forKey: .player)
        self.period = try? container.decodeIfPresent(String.self, forKey: .period)
        self.rating = try? container.decodeIfPresent(Double.self, forKey: .rating)
        self.ratingVsProtoss = try? container.decodeIfPresent(Double.self, forKey: .ratingVsProtoss)
        self.ratingVsTerran = try? container.decodeIfPresent(Double.self, forKey: .ratingVsTerran)
        self.ratingVsZerg = try? container.decodeIfPresent(Double.self, forKey: .ratingVsZerg)
        self.dev = try? container.decodeIfPresent(Double.self, forKey: .dev)
        self.position = try? container.decodeIfPresent(Int.self, forKey: .position)
        self.decay = try? container.decodeIfPresent(Int.self, forKey: .decay)
    }

    /// Whether the player is considered active (low decay).
    public var isActive: Bool {
        (decay ?? 0) < 4
    }
}

/// A single played match (series) in Aligulac's history.
public struct AligulacMatch: Codable, Sendable, Identifiable {
    public let id: Int
    public let date: String?
    /// Resource URI of player A.
    public let playerA: String?
    /// Resource URI of player B.
    public let playerB: String?
    public let scoreA: Int?
    public let scoreB: Int?
    public let raceA: Race?
    public let raceB: Race?
    public let event: String?

    private enum CodingKeys: String, CodingKey {
        case id, date, event
        case playerA = "pla"
        case playerB = "plb"
        case scoreA = "sca"
        case scoreB = "scb"
        case raceA = "rca"
        case raceB = "rcb"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.date = try? container.decodeIfPresent(String.self, forKey: .date)
        self.event = try? container.decodeIfPresent(String.self, forKey: .event)
        self.playerA = try? container.decodeIfPresent(String.self, forKey: .playerA)
        self.playerB = try? container.decodeIfPresent(String.self, forKey: .playerB)
        self.scoreA = try? container.decodeIfPresent(Int.self, forKey: .scoreA)
        self.scoreB = try? container.decodeIfPresent(Int.self, forKey: .scoreB)
        self.raceA = try? container.decodeIfPresent(Race.self, forKey: .raceA)
        self.raceB = try? container.decodeIfPresent(Race.self, forKey: .raceB)
    }
}

/// A head-to-head record between two players, derived from match history.
public struct HeadToHead: Sendable {
    public let playerAID: Int
    public let playerBID: Int
    public let winsA: Int
    public let winsB: Int
    public let matches: [AligulacMatch]

    /// Player A's historical win share (0...1), or `nil` when no games are recorded.
    public var winRateA: Double? {
        let total = winsA + winsB
        guard total > 0 else { return nil }
        return Double(winsA) / Double(total)
    }
}

/// The win-probability prediction for a match between two players.
public struct AligulacMatchPrediction: Decodable, Sendable {
    /// Probability (0...1) that player A wins the series.
    public let probabilityA: Double?
    /// Probability (0...1) that player B wins the series.
    public let probabilityB: Double?
    /// Expected median score for player A.
    public let medianScoreA: Double?
    /// Expected median score for player B.
    public let medianScoreB: Double?
    public let playerATag: String?
    public let playerBTag: String?

    private enum CodingKeys: String, CodingKey {
        case probabilityA = "proba"
        case probabilityB = "probb"
        case medianScoreA = "sca"
        case medianScoreB = "scb"
        case pla, plb
    }

    private struct NestedTag: Codable { let tag: String? }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.probabilityA = try? container.decodeIfPresent(Double.self, forKey: .probabilityA)
        self.probabilityB = try? container.decodeIfPresent(Double.self, forKey: .probabilityB)
        self.medianScoreA = try? container.decodeIfPresent(Double.self, forKey: .medianScoreA)
        self.medianScoreB = try? container.decodeIfPresent(Double.self, forKey: .medianScoreB)
        self.playerATag = (try? container.decodeIfPresent(NestedTag.self, forKey: .pla))?.tag
        self.playerBTag = (try? container.decodeIfPresent(NestedTag.self, forKey: .plb))?.tag
    }
}
