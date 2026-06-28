import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Logging

/// A client for the official Blizzard Battle.net StarCraft II API.
///
/// Provides authoritative, free (with a developer OAuth app) ladder and profile data:
/// the grandmaster leaderboard, the current ranked season, and player career profiles.
/// Uses the OAuth client-credentials flow and caches the access token.
///
/// ```swift
/// let blizzard = BlizzardClient(credentials: .init(clientId: id, clientSecret: secret))
/// let gm = try await blizzard.grandmasterLadder(region: .eu)
/// ```
public actor BlizzardClient {
    private let credentials: BlizzardCredentials
    private let session: URLSession
    private let networkingClient: NetworkingClient
    private let retryHandler: RetryHandler
    private let decoder: JSONDecoder
    private let oauthURL: URL

    private var cachedToken: String?
    private var tokenExpiry: Date?

    public struct Configuration: Sendable {
        public let credentials: BlizzardCredentials
        public let oauthURL: URL
        public let retryConfiguration: RetryConfiguration
        public let urlSessionConfiguration: URLSessionConfiguration

        public init(
            credentials: BlizzardCredentials,
            oauthURL: URL = URL(string: "https://oauth.battle.net/token")!,
            retryConfiguration: RetryConfiguration = .default,
            urlSessionConfiguration: URLSessionConfiguration = .default
        ) {
            self.credentials = credentials
            self.oauthURL = oauthURL
            self.retryConfiguration = retryConfiguration
            self.urlSessionConfiguration = urlSessionConfiguration
        }
    }

    public init(configuration: Configuration) {
        self.credentials = configuration.credentials
        self.oauthURL = configuration.oauthURL
        self.session = URLSession(configuration: configuration.urlSessionConfiguration)
        self.networkingClient = NetworkingClient(
            baseURL: URL(string: "https://us.api.blizzard.com")!,
            session: session,
            logger: Logger(label: "StarCraftKit.Blizzard.Networking")
        )
        self.retryHandler = RetryHandler(
            configuration: configuration.retryConfiguration,
            logger: Logger(label: "StarCraftKit.Blizzard.Retry")
        )
        self.decoder = JSONDecoder()
    }

    public init(credentials: BlizzardCredentials) {
        self.init(configuration: Configuration(credentials: credentials))
    }

    // MARK: - Endpoints

    /// The official grandmaster ladder for a region.
    public func grandmasterLadder(region: BlizzardRegion) async throws -> [GrandmasterTeam] {
        let ladder: GrandmasterLadder = try await get(region: region, path: "sc2/ladder/grandmaster/\(region.regionId)")
        return ladder.ladderTeams ?? []
    }

    /// The current ranked season for a region.
    public func currentSeason(region: BlizzardRegion) async throws -> BlizzardSeason {
        try await get(region: region, path: "sc2/ladder/season/\(region.regionId)")
    }

    /// A player's career profile.
    public func profile(region: BlizzardRegion, realmId: Int, profileId: Int) async throws -> BlizzardProfile {
        try await get(region: region, path: "sc2/profile/\(region.regionId)/\(realmId)/\(profileId)")
    }

    /// Profile lookup metadata.
    public func profileMetadata(region: BlizzardRegion, realmId: Int, profileId: Int) async throws -> BlizzardProfileMetadata {
        try await get(region: region, path: "sc2/metadata/profile/\(region.regionId)/\(realmId)/\(profileId)")
    }

    // MARK: - Private

    private func get<T: Decodable>(region: BlizzardRegion, path: String) async throws -> T {
        let data = try await authorizedData(region: region, path: path)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(underlying: error, data: data)
        }
    }

    /// Fetch with the current token; on a 401 (e.g. a revoked token before its cached
    /// expiry), invalidate the cache and retry once with a fresh token.
    private func authorizedData(region: BlizzardRegion, path: String) async throws -> Data {
        do {
            return try await sendAuthorized(region: region, path: path)
        } catch APIError.unauthorized {
            cachedToken = nil
            tokenExpiry = nil
            return try await sendAuthorized(region: region, path: path)
        }
    }

    private func sendAuthorized(region: BlizzardRegion, path: String) async throws -> Data {
        let token = try await accessToken()
        guard let url = URL(string: path, relativeTo: region.apiHost) else {
            throw APIError.invalidRequest(reason: "Invalid Blizzard path: \(path)")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, _) = try await retryHandler.send(client: networkingClient, request: request)
        return data
    }

    private func accessToken() async throws -> String {
        if let cachedToken, let tokenExpiry, tokenExpiry > Date() {
            return cachedToken
        }
        let token = try await fetchToken()
        cachedToken = token.accessToken
        tokenExpiry = Date().addingTimeInterval(TimeInterval(max(60, token.expiresIn - 60)))
        return token.accessToken
    }

    private func fetchToken() async throws -> BlizzardToken {
        var request = URLRequest(url: oauthURL)
        request.httpMethod = "POST"
        let basic = Data("\(credentials.clientId):\(credentials.clientSecret)".utf8).base64EncodedString()
        request.setValue("Basic \(basic)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("grant_type=client_credentials".utf8)

        let (data, _) = try await retryHandler.send(client: networkingClient, request: request)
        do {
            return try decoder.decode(BlizzardToken.self, from: data)
        } catch {
            throw APIError.decodingError(underlying: error, data: data)
        }
    }
}
