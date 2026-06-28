import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Logging

/// A client for the Aligulac StarCraft II ratings API (`https://aligulac.com/api/v1/`).
///
/// Aligulac complements ``StarCraftClient``/PandaScore with data the latter does not
/// provide: Bayesian skill ratings, race-matchup performance, head-to-head records,
/// and match win-probability predictions.
///
/// ## Requirements & attribution
///
/// Every request needs your own free Aligulac API key (register at
/// `https://aligulac.com/about/api/`). Aligulac data is licensed for non-commercial use
/// **with attribution** — display "data from aligulac.com" wherever you surface it, and
/// never redistribute the bulk database dump.
///
/// ```swift
/// let aligulac = AligulacClient(apiKey: "your-aligulac-key")
/// let serral = try await aligulac.searchPlayers(tag: "Serral").first
/// if let id = serral?.id {
///     let rating = try await aligulac.rating(playerID: id)
///     print("vs Zerg: \(rating?.ratingVsZerg ?? 0)")
/// }
/// ```
public actor AligulacClient {
    private let networkingClient: NetworkingClient
    private let retryHandler: RetryHandler
    private let decoder: JSONDecoder
    private let configuration: Configuration

    public struct Configuration: Sendable {
        public let apiKey: String
        public let baseURL: URL
        public let retryConfiguration: RetryConfiguration
        public let urlSessionConfiguration: URLSessionConfiguration

        public init(
            apiKey: String,
            baseURL: URL = URL(string: "https://aligulac.com/api/v1/")!,
            retryConfiguration: RetryConfiguration = .default,
            urlSessionConfiguration: URLSessionConfiguration = .default
        ) {
            self.apiKey = apiKey
            self.baseURL = baseURL
            self.retryConfiguration = retryConfiguration
            self.urlSessionConfiguration = urlSessionConfiguration
        }
    }

    public init(configuration: Configuration) {
        self.configuration = configuration
        let session = URLSession(configuration: configuration.urlSessionConfiguration)
        self.networkingClient = NetworkingClient(
            baseURL: configuration.baseURL,
            session: session,
            logger: Logger(label: "StarCraftKit.Aligulac.Networking")
        )
        self.retryHandler = RetryHandler(
            configuration: configuration.retryConfiguration,
            logger: Logger(label: "StarCraftKit.Aligulac.Retry")
        )
        self.decoder = JSONDecoder()
    }

    /// Create a client from just an Aligulac API key.
    public init(apiKey: String) {
        self.init(configuration: Configuration(apiKey: apiKey))
    }

    /// Attribution string Aligulac's license requires you to display.
    public nonisolated static let attribution = "Rating data from aligulac.com"

    // MARK: - Players

    /// Fetch a single player by Aligulac id.
    public func player(id: Int) async throws -> AligulacPlayer {
        try await execute(path: "player/\(id)/")
    }

    /// Search players by tag (case-insensitive substring).
    public func searchPlayers(tag: String, limit: Int = 20) async throws -> [AligulacPlayer] {
        let page: AligulacPage<AligulacPlayer> = try await execute(
            path: "player/",
            query: ["tag__icontains": .string(tag), "limit": .int(limit)]
        )
        return page.objects
    }

    // MARK: - Ratings

    /// The most recent rating for a player, if one exists.
    public func rating(playerID: Int) async throws -> AligulacRating? {
        let page: AligulacPage<AligulacRating> = try await execute(
            path: "rating/",
            query: ["player": .int(playerID), "order_by": .string("-period"), "limit": .int(1)]
        )
        return page.objects.first
    }

    /// The current active-rating leaderboard, highest first.
    public func topRatings(limit: Int = 20) async throws -> [AligulacRating] {
        let page: AligulacPage<AligulacRating> = try await execute(
            path: "activerating/",
            query: ["order_by": .string("-rating"), "limit": .int(limit)]
        )
        return page.objects
    }

    // MARK: - Matches & head-to-head

    /// Recent matches involving a player (most recent first).
    public func matches(playerID: Int, limit: Int = 20) async throws -> [AligulacMatch] {
        async let asA: AligulacPage<AligulacMatch> = execute(
            path: "match/",
            query: ["pla": .int(playerID), "order_by": .string("-date"), "limit": .int(limit)]
        )
        async let asB: AligulacPage<AligulacMatch> = execute(
            path: "match/",
            query: ["plb": .int(playerID), "order_by": .string("-date"), "limit": .int(limit)]
        )
        let combined = try await (asA.objects + asB.objects)
        return Array(combined.sorted { ($0.date ?? "") > ($1.date ?? "") }.prefix(limit))
    }

    /// The head-to-head record between two players.
    public func headToHead(playerA: Int, playerB: Int, limit: Int = 100) async throws -> HeadToHead {
        let page: AligulacPage<AligulacMatch> = try await execute(
            path: "match/",
            query: [
                "pla__in": .string("\(playerA),\(playerB)"),
                "plb__in": .string("\(playerA),\(playerB)"),
                "order_by": .string("-date"),
                "limit": .int(limit)
            ]
        )
        var winsA = 0
        var winsB = 0
        for match in page.objects {
            // Skip records whose first-player URI can't be resolved to one of the two,
            // so an unparseable URI never silently credits the wrong player.
            guard let firstID = Self.resourceID(match.playerA), firstID == playerA || firstID == playerB else { continue }
            let firstIsA = firstID == playerA
            let scoreFirst = match.scoreA ?? 0
            let scoreSecond = match.scoreB ?? 0
            guard scoreFirst != scoreSecond else { continue }
            let firstWon = scoreFirst > scoreSecond
            if firstWon == firstIsA { winsA += 1 } else { winsB += 1 }
        }
        return HeadToHead(playerAID: playerA, playerBID: playerB, winsA: winsA, winsB: winsB, matches: page.objects)
    }

    // MARK: - Predictions

    /// Predict the outcome of a best-of-`bestOf` series between two players.
    public func predictMatch(playerA: Int, playerB: Int, bestOf: Int = 5) async throws -> AligulacMatchPrediction {
        try await execute(
            path: "predictmatch/\(playerA),\(playerB)/",
            query: ["bo": .int(bestOf)]
        )
    }

    // MARK: - Private

    private func execute<T: APIResponse>(path: String, query: [String: QueryValue] = [:]) async throws -> T {
        var queryParams = query
        queryParams["apikey"] = .string(configuration.apiKey)
        let request = try await networkingClient.buildRequest(
            path: path,
            method: .get,
            queryParameters: queryParams
        )
        let (data, _) = try await retryHandler.send(client: networkingClient, request: request)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(underlying: error, data: data)
        }
    }

    /// Extract the trailing numeric id from a Tastypie resource URI, e.g. `/api/v1/player/123/`.
    public nonisolated static func resourceID(_ uri: String?) -> Int? {
        guard let uri else { return nil }
        let digits = uri.split(separator: "/").last { Int($0) != nil }
        return digits.flatMap { Int($0) }
    }
}
