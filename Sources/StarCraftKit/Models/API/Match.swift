import Foundation

/// The current status of a StarCraft II match.
public enum MatchStatus: String, Codable, Sendable {
    /// Match has not started yet
    case notStarted = "not_started"

    /// Match is currently being played
    case running

    /// Match has finished
    case finished
}

/// A StarCraft II esports match between two opponents.
///
/// A match represents a competition between two players or teams in a tournament.
/// Each match consists of one or more games (e.g., best of 3, best of 5).
///
/// ## Topics
///
/// ### Match Information
/// - ``id``
/// - ``name``
/// - ``slug``
/// - ``status``
///
/// ### Tournament Context
/// - ``tournamentID``
/// - ``serieID``
/// - ``leagueID``
/// - ``tournament``
/// - ``serie``
/// - ``league``
///
/// ### Timing
/// - ``beginAt``
/// - ``endAt``
///
/// ### Competition Details
/// - ``opponents``
/// - ``games``
/// - ``results``
/// - ``winner``
public struct Match: Codable, Sendable, Identifiable {
    /// Unique identifier for the match
    public let id: Int

    /// Name of the match (falls back to the slug or opponents when the API omits it)
    public let name: String

    /// URL-friendly version of the match name
    public let slug: String

    /// Current status of the match
    public let status: MatchStatus

    /// ID of the parent tournament
    public let tournamentID: Int

    /// ID of the parent series
    public let serieID: Int

    /// ID of the parent league, when provided
    public let leagueID: Int?

    /// Scheduled start time
    public let beginAt: Date?

    /// Actual end time
    public let endAt: Date?

    /// Number of games in the match (best-of)
    public let numberOfGames: Int

    /// List of games in the match
    public let games: [Game]

    /// Teams/players competing
    public let opponents: [Opponent]

    /// Match results
    public let results: [MatchResult]

    /// Winning team/player
    public let winner: Winner?

    /// ID of the winner
    public let winnerID: Int?

    /// Live match data
    public let live: LiveData?

    /// Available streams
    public let streams: [Stream]?

    /// Last modification timestamp
    public let modifiedAt: Date?

    /// Whether the match was forfeited
    public let forfeit: Bool?

    /// Whether the match ended in a draw
    public let draw: Bool?

    /// Whether the match was rescheduled
    public let rescheduled: Bool?

    /// Best-of label, e.g. `best_of`
    public let matchType: String?

    /// Whether detailed per-game stats are available
    public let detailedStats: Bool?

    /// Nested league object (enrichment, best-effort)
    public let league: League?

    /// Nested series object (enrichment, best-effort)
    public let serie: Series?

    /// Nested tournament object (enrichment, best-effort)
    public let tournament: Tournament?

    /// Videogame the match belongs to
    public let videogame: Videogame?

    private enum CodingKeys: String, CodingKey {
        case id, name, slug, status
        case tournamentID = "tournament_id"
        case serieID = "serie_id"
        case leagueID = "league_id"
        case beginAt = "begin_at"
        case endAt = "end_at"
        case numberOfGames = "number_of_games"
        case games, opponents, results, winner
        case winnerID = "winner_id"
        case live
        case streams = "streams_list"
        case modifiedAt = "modified_at"
        case forfeit, draw, rescheduled
        case matchType = "match_type"
        case detailedStats = "detailed_stats"
        case league, serie, tournament, videogame
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decode(Int.self, forKey: .id)
        self.status = (try? container.decodeIfPresent(MatchStatus.self, forKey: .status)) ?? .notStarted
        self.tournamentID = (try? container.decodeIfPresent(Int.self, forKey: .tournamentID)) ?? 0
        self.serieID = (try? container.decodeIfPresent(Int.self, forKey: .serieID)) ?? 0
        self.leagueID = try? container.decodeIfPresent(Int.self, forKey: .leagueID)
        self.beginAt = try? container.decodeIfPresent(Date.self, forKey: .beginAt)
        self.endAt = try? container.decodeIfPresent(Date.self, forKey: .endAt)
        self.games = (try? container.decodeIfPresent([Game].self, forKey: .games)) ?? []
        self.opponents = (try? container.decodeIfPresent([Opponent].self, forKey: .opponents)) ?? []
        self.results = (try? container.decodeIfPresent([MatchResult].self, forKey: .results)) ?? []
        self.winner = try? container.decodeIfPresent(Winner.self, forKey: .winner)
        self.winnerID = try? container.decodeIfPresent(Int.self, forKey: .winnerID)
        self.live = try? container.decodeIfPresent(LiveData.self, forKey: .live)
        self.streams = try? container.decodeIfPresent([Stream].self, forKey: .streams)
        self.modifiedAt = try? container.decodeIfPresent(Date.self, forKey: .modifiedAt)
        self.forfeit = try? container.decodeIfPresent(Bool.self, forKey: .forfeit)
        self.draw = try? container.decodeIfPresent(Bool.self, forKey: .draw)
        self.rescheduled = try? container.decodeIfPresent(Bool.self, forKey: .rescheduled)
        self.matchType = try? container.decodeIfPresent(String.self, forKey: .matchType)
        self.detailedStats = try? container.decodeIfPresent(Bool.self, forKey: .detailedStats)

        self.league = try? container.decodeIfPresent(League.self, forKey: .league)
        self.serie = try? container.decodeIfPresent(Series.self, forKey: .serie)
        self.tournament = try? container.decodeIfPresent(Tournament.self, forKey: .tournament)
        self.videogame = try? container.decodeIfPresent(Videogame.self, forKey: .videogame)

        let rawName = (try? container.decodeIfPresent(String.self, forKey: .name)).flatMap { $0.isEmpty ? nil : $0 }
        let rawSlug = (try? container.decodeIfPresent(String.self, forKey: .slug)).flatMap { $0.isEmpty ? nil : $0 }
        self.slug = rawSlug ?? rawName.map { $0.lowercased().replacingOccurrences(of: " ", with: "-") } ?? "match-\(id)"
        if let rawName {
            self.name = rawName
        } else if self.opponents.count == 2 {
            self.name = "\(self.opponents[0].opponent.name) vs \(self.opponents[1].opponent.name)"
        } else {
            self.name = rawSlug ?? "Match \(id)"
        }

        let rawNumberOfGames = try? container.decodeIfPresent(Int.self, forKey: .numberOfGames)
        self.numberOfGames = rawNumberOfGames ?? Swift.max(self.games.count, 1)
    }

    public init(
        id: Int,
        name: String,
        slug: String,
        status: MatchStatus,
        tournamentID: Int,
        serieID: Int,
        beginAt: Date?,
        endAt: Date?,
        numberOfGames: Int,
        games: [Game],
        opponents: [Opponent],
        results: [MatchResult],
        winner: Winner?,
        winnerID: Int?,
        live: LiveData?,
        streams: [Stream]?,
        modifiedAt: Date?,
        leagueID: Int? = nil,
        forfeit: Bool? = nil,
        draw: Bool? = nil,
        rescheduled: Bool? = nil,
        matchType: String? = nil,
        detailedStats: Bool? = nil,
        league: League? = nil,
        serie: Series? = nil,
        tournament: Tournament? = nil,
        videogame: Videogame? = nil
    ) {
        self.id = id
        self.name = name
        self.slug = slug
        self.status = status
        self.tournamentID = tournamentID
        self.serieID = serieID
        self.leagueID = leagueID
        self.beginAt = beginAt
        self.endAt = endAt
        self.numberOfGames = numberOfGames
        self.games = games
        self.opponents = opponents
        self.results = results
        self.winner = winner
        self.winnerID = winnerID
        self.live = live
        self.streams = streams
        self.modifiedAt = modifiedAt
        self.forfeit = forfeit
        self.draw = draw
        self.rescheduled = rescheduled
        self.matchType = matchType
        self.detailedStats = detailedStats
        self.league = league
        self.serie = serie
        self.tournament = tournament
        self.videogame = videogame
    }
}

/// Game within a match
public struct Game: Codable, Sendable, Identifiable, Equatable, Hashable {
    public let id: Int
    public let beginAt: Date?
    public let endAt: Date?
    public let complete: Bool?
    public let finished: Bool?
    public let forfeit: Bool?
    public let length: Int?
    public let position: Int?
    public let status: MatchStatus?
    public let winner: GameWinner?
    public let winnerType: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case beginAt = "begin_at"
        case endAt = "end_at"
        case complete, finished, forfeit, length, position, status, winner
        case winnerType = "winner_type"
    }

    public static func == (lhs: Game, rhs: Game) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Game winner information (simplified)
public struct GameWinner: Codable, Sendable, Equatable, Hashable {
    public let id: Int?
    public let type: String?
}

/// Opponent in a match
public struct Opponent: Codable, Sendable {
    public let opponent: OpponentDetails
    public let type: String
}

/// Opponent details
public struct OpponentDetails: Codable, Sendable, Identifiable {
    public let id: Int
    public let name: String
    public let slug: String?
    public let imageURL: URL?
    public let acronym: String?
    public let location: String?
    public let active: Bool?
    public let role: String?
    public let modifiedAt: Date?
    public let birthday: Date?
    public let firstName: String?
    public let lastName: String?
    public let nationality: String?
    public let age: Int?

    private enum CodingKeys: String, CodingKey {
        case id, name, slug
        case imageURL = "image_url"
        case acronym, location, active, role
        case modifiedAt = "modified_at"
        case birthday
        case firstName = "first_name"
        case lastName = "last_name"
        case nationality, age
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? "Unknown"
        self.slug = try? container.decodeIfPresent(String.self, forKey: .slug)
        self.imageURL = OpponentDetails.decodeURL(container, .imageURL)
        self.acronym = try? container.decodeIfPresent(String.self, forKey: .acronym)
        self.location = try? container.decodeIfPresent(String.self, forKey: .location)
        self.active = try? container.decodeIfPresent(Bool.self, forKey: .active)
        self.role = try? container.decodeIfPresent(String.self, forKey: .role)
        self.modifiedAt = try? container.decodeIfPresent(Date.self, forKey: .modifiedAt)
        self.birthday = try? container.decodeIfPresent(Date.self, forKey: .birthday)
        self.firstName = try? container.decodeIfPresent(String.self, forKey: .firstName)
        self.lastName = try? container.decodeIfPresent(String.self, forKey: .lastName)
        self.nationality = try? container.decodeIfPresent(String.self, forKey: .nationality)
        self.age = try? container.decodeIfPresent(Int.self, forKey: .age)
    }

    private static func decodeURL(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> URL? {
        guard let string = (try? container.decodeIfPresent(String.self, forKey: key)) ?? nil else { return nil }
        return URL(string: string)
    }
}

/// Match result
public struct MatchResult: Codable, Sendable, Equatable, Hashable {
    public let score: Int
    public let teamID: Int?
    public let playerID: Int?

    private enum CodingKeys: String, CodingKey {
        case score
        case teamID = "team_id"
        case playerID = "player_id"
    }
}

/// Winner information
public struct Winner: Codable, Sendable, Equatable, Hashable {
    public let id: Int
    public let type: String?
    public let name: String?
    public let slug: String?
    public let acronym: String?
    public let imageURL: URL?

    private enum CodingKeys: String, CodingKey {
        case id, type, name, slug, acronym
        case imageURL = "image_url"
    }
}

/// Live match data
public struct LiveData: Codable, Sendable {
    public let supported: Bool
    public let opensAt: Date?
    public let url: URL?

    private enum CodingKeys: String, CodingKey {
        case supported
        case opensAt = "opens_at"
        case url
    }
}

/// Stream information
public struct Stream: Codable, Sendable {
    public let language: String
    public let main: Bool
    public let official: Bool
    public let rawURL: URL?
    public let embedURL: URL?

    private enum CodingKeys: String, CodingKey {
        case language, main, official
        case rawURL = "raw_url"
        case embedURL = "embed_url"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.language = (try? container.decodeIfPresent(String.self, forKey: .language)) ?? ""
        self.main = (try? container.decodeIfPresent(Bool.self, forKey: .main)) ?? false
        self.official = (try? container.decodeIfPresent(Bool.self, forKey: .official)) ?? false
        self.rawURL = Stream.decodeURL(container, .rawURL)
        self.embedURL = Stream.decodeURL(container, .embedURL)
    }

    private static func decodeURL(_ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> URL? {
        guard let string = (try? container.decodeIfPresent(String.self, forKey: key)) ?? nil else { return nil }
        return URL(string: string)
    }
}

// MARK: - Computed Properties
public extension Match {
    /// Check if match is live
    var isLive: Bool { status == .running }

    /// Check if match has ended
    var hasEnded: Bool { status == .finished }

    /// Check if match hasn't started
    var isPending: Bool { status == .notStarted }

    /// Get match duration if available
    var duration: TimeInterval? {
        guard let beginAt, let endAt else { return nil }
        return endAt.timeIntervalSince(beginAt)
    }
}

// MARK: - Equatable / Hashable
extension Match: Equatable, Hashable {
    public static func == (lhs: Match, rhs: Match) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
