import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Logging

/// The main client for interacting with the PandaScore StarCraft II API.
///
/// `StarCraftClient` is an actor that provides thread-safe access to all StarCraft II
/// esports data. It handles authentication, caching, retry logic, and pagination.
///
/// ## Creating a Client
///
/// ```swift
/// // Simplest form
/// let client = StarCraftClient(apiToken: "your-api-token")
///
/// // Custom configuration
/// let config = StarCraftClient.Configuration(
///     apiKey: "your-api-token",
///     retryConfiguration: .aggressive,
///     cacheConfiguration: .init(maxSize: 200, defaultTTL: 600)
/// )
/// let client = StarCraftClient(configuration: config)
/// ```
///
/// ## Making Requests
///
/// ```swift
/// let matches = try await client.getLiveMatches()
/// let serral = try await client.searchPlayers(name: "Serral")
/// let player = try await client.getPlayer(id: 12345)
/// ```
///
/// ## Topics
///
/// ### Matches
/// - ``getLiveMatches()``
/// - ``getUpcomingMatches()``
/// - ``getPastMatches()``
/// - ``getMatches(_:)``
/// - ``getMatch(id:)``
/// - ``getTournamentMatches(tournamentId:parameters:)``
///
/// ### Players
/// - ``getPlayers(_:)``
/// - ``getPlayer(id:)``
/// - ``searchPlayers(name:)``
///
/// ### Teams
/// - ``getTeams(_:)``
/// - ``getTeam(id:)``
///
/// ### Tournaments
/// - ``getTournaments(_:)``
/// - ``getTournament(id:)``
public actor StarCraftClient: APIClientProtocol {
    private let networkingClient: NetworkingClient
    private let cache: ResponseCache
    private let retryHandler: RetryHandler
    private let logger: Logger
    private let decoder: JSONDecoder
    private let configuration: Configuration

    /// Configuration options for the StarCraft client.
    public struct Configuration: Sendable {
        public let apiKey: String
        public let authMethod: AuthMethod
        public let baseURL: URL
        public let retryConfiguration: RetryConfiguration
        public let cacheConfiguration: CacheConfiguration
        public let urlSessionConfiguration: URLSessionConfiguration

        /// The API token (alias for ``apiKey``).
        public var apiToken: String { apiKey }

        public enum AuthMethod: Sendable {
            case bearerToken
            case queryParameter
        }

        public struct CacheConfiguration: Sendable {
            public let maxSize: Int
            public let defaultTTL: TimeInterval

            public init(maxSize: Int = 100, defaultTTL: TimeInterval = 300) {
                self.maxSize = maxSize
                self.defaultTTL = defaultTTL
            }
        }

        public init(
            apiKey: String,
            authMethod: AuthMethod = .bearerToken,
            baseURL: URL = URL(string: "https://api.pandascore.co")!,
            retryConfiguration: RetryConfiguration = .default,
            cacheConfiguration: CacheConfiguration = CacheConfiguration(),
            urlSessionConfiguration: URLSessionConfiguration = .default
        ) {
            self.apiKey = apiKey
            self.authMethod = authMethod
            self.baseURL = baseURL
            self.retryConfiguration = retryConfiguration
            self.cacheConfiguration = cacheConfiguration
            self.urlSessionConfiguration = urlSessionConfiguration
        }
    }

    /// Create a client from a full configuration.
    public init(configuration: Configuration) {
        self.configuration = configuration
        self.logger = Logger(label: "StarCraftKit.Client")

        var defaultHeaders: [String: String] = [:]
        if configuration.authMethod == .bearerToken {
            defaultHeaders["Authorization"] = "Bearer \(configuration.apiKey)"
        }

        let session = URLSession(configuration: configuration.urlSessionConfiguration)

        self.networkingClient = NetworkingClient(
            baseURL: configuration.baseURL,
            session: session,
            defaultHeaders: defaultHeaders,
            logger: Logger(label: "StarCraftKit.NetworkingClient")
        )

        self.cache = ResponseCache(
            maxCacheSize: configuration.cacheConfiguration.maxSize,
            logger: Logger(label: "StarCraftKit.Cache")
        )

        self.retryHandler = RetryHandler(
            configuration: configuration.retryConfiguration,
            logger: Logger(label: "StarCraftKit.RetryHandler")
        )

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .pandaScore
    }

    /// Create a client from just an API token.
    public init(apiToken: String) {
        self.init(configuration: Configuration(apiKey: apiToken))
    }

    // MARK: - Core execution

    /// Execute an API request and decode the response.
    public func execute<T: APIResponse>(_ request: any APIRequest) async throws -> T {
        let (data, _) = try await fetch(request)
        return try decode(data, as: T.self)
    }

    /// Execute a request and return both the decoded list and its pagination metadata.
    public func executePage<T: APIResponse>(_ request: any APIRequest) async throws -> (items: [T], pagination: PaginationInfo?) {
        let (data, headers) = try await fetch(request)
        let items = try decode(data, as: [T].self)
        return (items, PaginationInfo(from: headers))
    }

    /// Execute a paginated request and return every page's items.
    public func executePaginated<T: APIResponse>(_ request: any APIRequest, maxPages: Int? = nil) async throws -> [T] {
        var allItems: [T] = []
        let pageSize = requestedPageSize(for: request)
        var currentPage = 1

        while maxPages == nil || currentPage <= maxPages! {
            let (items, pagination): ([T], PaginationInfo?) = try await fetchPage(request, page: currentPage, pageSize: pageSize)
            allItems.append(contentsOf: items)

            if items.isEmpty { break }
            if let pagination {
                if allItems.count >= pagination.total || !pagination.hasNextPage { break }
            } else if items.count < pageSize {
                break
            }
            currentPage += 1
        }

        return allItems
    }

    /// Stream every element of a paginated resource as an async sequence.
    ///
    /// ```swift
    /// for try await player in client.elements(of: PlayersRequest()) as AsyncThrowingStream<Player, Error> {
    ///     print(player.name)
    /// }
    /// ```
    public nonisolated func elements<Element: APIResponse>(
        of request: any APIRequest,
        pageSize: Int = 50
    ) -> AsyncThrowingStream<Element, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var page = 1
                    while !Task.isCancelled {
                        let (items, pagination): ([Element], PaginationInfo?) =
                            try await self.fetchPage(request, page: page, pageSize: pageSize)
                        for item in items { continuation.yield(item) }

                        if items.isEmpty { break }
                        if let pagination {
                            if !pagination.hasNextPage { break }
                        } else if items.count < pageSize {
                            break
                        }
                        page += 1
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Status & cache

    /// Rate limit status. `resetTime` is the top of the next hour (PandaScore's window).
    public func getRateLimitStatus() async -> (remaining: Int?, resetTime: Date?) {
        await networkingClient.getRateLimitStatus()
    }

    /// Clear the response cache.
    public func clearCache() async {
        await cache.clearAll()
    }

    /// Cache statistics.
    public func getCacheStatistics() async -> CacheStatistics {
        await cache.getStatistics()
    }

    // MARK: - Private

    private func fetch(_ request: any APIRequest) async throws -> (data: Data, headers: [String: String]) {
        let cacheable = request.method == .get && request.cachePolicy != .noCache
        let cacheKey = buildCacheKey(for: request)

        if cacheable, let cached = await cache.data(for: cacheKey) {
            return cached
        }

        let urlRequest = try await buildURLRequest(for: request, overridingQuery: nil)
        let (data, headers) = try await retryHandler.send(client: networkingClient, request: urlRequest)

        if cacheable, let ttl = ttl(for: request.cachePolicy) {
            await cache.store(data, headers: headers, for: cacheKey, ttl: ttl)
        }
        return (data, headers)
    }

    private func fetchPage<T: APIResponse>(
        _ request: any APIRequest,
        page: Int,
        pageSize: Int
    ) async throws -> (items: [T], pagination: PaginationInfo?) {
        var params = request.queryParameters
        params["page[number]"] = .int(page)
        params["page[size]"] = .int(pageSize)

        let urlRequest = try await buildURLRequest(for: request, overridingQuery: params)
        let (data, headers) = try await retryHandler.send(client: networkingClient, request: urlRequest)
        let items = try decode(data, as: [T].self)
        return (items, PaginationInfo(from: headers))
    }

    private func buildURLRequest(
        for request: any APIRequest,
        overridingQuery: [String: QueryValue]?
    ) async throws -> URLRequest {
        var queryParams = overridingQuery ?? request.queryParameters
        if configuration.authMethod == .queryParameter {
            queryParams["token"] = .string(configuration.apiKey)
        }
        return try await networkingClient.buildRequest(
            path: request.path,
            method: request.method,
            queryParameters: queryParams,
            headers: request.headers,
            body: request.body
        )
    }

    private func decode<T: APIResponse>(_ data: Data, as type: T.Type) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            logger.error("Decoding error for \(T.self): \(error)")
            throw APIError.decodingError(underlying: error, data: data)
        }
    }

    private func ttl(for policy: CachePolicy) -> TimeInterval? {
        switch policy {
        case .noCache:
            return nil
        case .useCache(let ttl):
            return ttl
        case .cacheForever:
            return 60 * 60 * 24 * 365 * 10
        }
    }

    private func requestedPageSize(for request: any APIRequest) -> Int {
        if case .int(let size)? = request.queryParameters["page[size]"] {
            return min(100, max(1, size))
        }
        return 50
    }

    private func buildCacheKey(for request: any APIRequest) -> String {
        var components = [request.method.rawValue, request.path]
        for (key, value) in request.queryParameters.sorted(by: { $0.key < $1.key }) {
            components.append("\(key)=\(value.scalarString)")
        }
        if let body = request.body {
            components.append("body=\(body.hashValue)")
        }
        return components.joined(separator: "&")
    }
}

// MARK: - Convenience Methods
public extension StarCraftClient {
    // Leagues
    func getLeagues(_ request: LeaguesRequest = LeaguesRequest()) async throws -> [League] {
        try await execute(request)
    }
    func getAllLeagues() async throws -> [League] {
        try await executePaginated(LeaguesRequest(), maxPages: nil)
    }
    func getLeague(id: Int) async throws -> League {
        try await execute(LeagueRequest(id: id))
    }

    // Matches
    func getMatches(_ request: MatchesRequest = MatchesRequest()) async throws -> [Match] {
        try await execute(request)
    }
    func getMatches(parameters: QueryParameters) async throws -> [Match] {
        try await execute(MatchesRequest(parameters: parameters))
    }
    func getAllMatches() async throws -> [Match] {
        try await executePaginated(MatchesRequest(), maxPages: nil)
    }
    func getMatch(id: Int) async throws -> Match {
        try await execute(MatchRequest(id: id))
    }
    func getLiveMatches() async throws -> [Match] {
        try await getMatches(.running())
    }
    func getUpcomingMatches() async throws -> [Match] {
        try await getMatches(.upcoming())
    }
    func getPastMatches() async throws -> [Match] {
        try await getMatches(.past())
    }
    func getTournamentMatches(tournamentId: Int, parameters: QueryParameters = QueryParameters()) async throws -> [Match] {
        try await execute(MatchesRequest(parameters: parameters.filter("tournament_id", .int(tournamentId))))
    }

    // Players
    func getPlayers(_ request: PlayersRequest = PlayersRequest()) async throws -> [Player] {
        try await execute(request)
    }
    func getAllPlayers() async throws -> [Player] {
        try await executePaginated(PlayersRequest(), maxPages: nil)
    }
    func getPlayer(id: Int) async throws -> Player {
        try await execute(PlayerRequest(id: id))
    }
    func searchPlayers(name: String) async throws -> [Player] {
        try await getPlayers(.searchByName(name))
    }

    // Teams
    func getTeams(_ request: TeamsRequest = TeamsRequest()) async throws -> [Team] {
        try await execute(request)
    }
    func getAllTeams() async throws -> [Team] {
        try await executePaginated(TeamsRequest(), maxPages: nil)
    }
    func getTeam(id: Int) async throws -> Team {
        try await execute(TeamRequest(id: id))
    }
    func searchTeams(name: String) async throws -> [Team] {
        try await getTeams(.searchByName(name))
    }

    // Series
    func getSeries(_ request: SeriesRequest = SeriesRequest()) async throws -> [Series] {
        try await execute(request)
    }
    func getAllSeries() async throws -> [Series] {
        try await executePaginated(SeriesRequest(), maxPages: nil)
    }
    func getSeries(id: Int) async throws -> Series {
        try await execute(SingleSeriesRequest(id: id))
    }

    // Tournaments
    func getTournaments(_ request: TournamentsRequest = TournamentsRequest()) async throws -> [Tournament] {
        try await execute(request)
    }
    func getAllTournaments() async throws -> [Tournament] {
        try await executePaginated(TournamentsRequest(), maxPages: nil)
    }
    func getTournament(id: Int) async throws -> Tournament {
        try await execute(TournamentRequest(id: id))
    }
}
