/// StarCraftKit - A modern Swift SDK for the PandaScore StarCraft 2 API
///
/// StarCraftKit provides a comprehensive, type-safe interface to access StarCraft 2
/// esports data including leagues, matches, players, teams, series, and tournaments.
///
/// ## Features
/// - Protocol-oriented architecture with clean abstractions
/// - Full async/await support for modern concurrency
/// - Automatic retry with exponential backoff
/// - Response caching with configurable TTL
/// - Thread-safe design using Swift actors
/// - Comprehensive error handling
/// - Type-safe query builders
/// - Cross-platform support (macOS, iOS, watchOS, tvOS)
///
/// ## Quick Start
/// ```swift
/// // Initialize the client
/// let config = StarCraftClient.Configuration(apiKey: "YOUR_API_KEY")
/// let client = StarCraftClient(configuration: config)
///
/// // Fetch data
/// let players = try await client.getPlayers()
/// let liveMatches = try await client.getLiveMatches()
/// let tournaments = try await client.getTournaments(.upcoming())
/// ```
///
/// ## Authentication
/// StarCraftKit supports two authentication methods:
/// - Bearer token (default): Token sent in Authorization header
/// - Query parameter: Token sent as URL parameter
///
/// ## Advanced Usage
/// ```swift
/// // Custom query with filters and sorting
/// let request = PlayersRequest(
///     page: 1,
///     pageSize: 100,
///     sort: [SortParameter(field: "name", direction: .ascending)],
///     nationality: "KR"
/// )
/// let koreanPlayers = try await client.getPlayers(request)
///
/// // Fetch all pages
/// let allTournaments = try await client.executePaginated(
///     TournamentsRequest(),
///     maxPages: nil
/// )
/// ```

// Re-export all public types
public typealias StarCraftAPI = StarCraftClient

// Re-export protocols
@_exported import struct Foundation.URL
@_exported import struct Foundation.Date
@_exported import struct Foundation.Data
@_exported import struct Foundation.TimeInterval

// Version information
public enum StarCraftKitInfo {
    public static let version = "2.0.0"
    public static let minimumSwiftVersion = "6.0"
}