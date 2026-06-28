# StarCraftKit

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![CI](https://github.com/guitaripod/StarCraftKit/actions/workflows/ci.yml/badge.svg)](https://github.com/guitaripod/StarCraftKit/actions/workflows/ci.yml)
[![Documentation](https://github.com/guitaripod/StarCraftKit/actions/workflows/docc.yml/badge.svg)](https://github.com/guitaripod/StarCraftKit/actions/workflows/docc.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20iOS%20%7C%20watchOS%20%7C%20tvOS-lightgray.svg)](https://developer.apple.com/swift/)

A modern, production-ready Swift 6 SDK for StarCraft II esports data. StarCraftKit pulls live and structured competitive data from **PandaScore** and pairs it with skill ratings, head-to-head records, and match predictions from **Aligulac** — giving you the best available picture of the pro scene from one package.

## Features

- 🚀 **Swift 6** — full Swift 6 language mode, data-race safe, async/await throughout
- 🎭 **Actor-based client** — `StarCraftClient` is an actor; every request type is `Sendable`
- 🔌 **Two data sources** — PandaScore for live/structured esports data, Aligulac for ratings & predictions
- 🧱 **Fluent, value-type queries** — chainable filtering, sorting, searching, ranges, and pagination
- 🔄 **Automatic retry** — exponential backoff with jitter for resilient calls
- 💾 **Real response caching** — actor-based, byte-accurate, per-request TTL
- 📄 **First-class pagination** — single page, all pages, or an async stream of elements
- 🛡️ **Robust decoding** — models tolerate the API's nulls and missing fields
- 📱 **Cross-platform** — macOS, iOS, watchOS, tvOS, and Linux
- 🧪 **Comprehensive test suite** — covers models, decoding, networking, caching, and pagination
- 📚 **Full DocC documentation** — for every public API

## Installation

### Swift Package Manager

Add StarCraftKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/guitaripod/StarCraftKit", from: "2.0.0")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies
2. Enter: `https://github.com/guitaripod/StarCraftKit`

## Quick Start

```swift
import StarCraftKit

// Simplest form — just your PandaScore token
let client = StarCraftClient(apiToken: "YOUR_PANDASCORE_TOKEN")

// Live matches right now
let liveMatches = try await client.getLiveMatches()

// Search for a player by name
let serral = try await client.searchPlayers(name: "Serral")

// Upcoming tournaments
let tournaments = try await client.getTournaments()
```

## Fetching Data

Every resource follows the same naming convention:

- `getPlayers(_:)` — the first page of results
- `getAllPlayers()` — every page, fetched automatically
- `getPlayer(id:)` — a single resource by id

```swift
// First page
let players = try await client.getPlayers()
let teams = try await client.getTeams()
let matches = try await client.getMatches()
let series = try await client.getSeries()
let leagues = try await client.getLeagues()

// Everything (paginated automatically)
let allPlayers = try await client.getAllPlayers()
let allTournaments = try await client.getAllTournaments()

// A single resource by id
let player = try await client.getPlayer(id: 12345)
let team = try await client.getTeam(id: 67890)
let match = try await client.getMatch(id: 11111)
let tournament = try await client.getTournament(id: 222)
let league = try await client.getLeague(id: 333)
let oneSeries = try await client.getSeries(id: 444)
```

### Match convenience methods

```swift
let live = try await client.getLiveMatches()
let upcoming = try await client.getUpcomingMatches()
let past = try await client.getPastMatches()
let bracket = try await client.getTournamentMatches(tournamentId: 11111)
```

### Search

```swift
let players = try await client.searchPlayers(name: "Maru")
let teams = try await client.searchTeams(name: "Dragon")
```

### The richer `Match` model

`Match` exposes its full tournament context. Alongside the `tournamentID`, `serieID`,
and `leagueID`, decoded matches carry nested `tournament`, `serie`, `league`, and
`videogame` objects when the API provides them, plus `forfeit`, `draw`, `matchType`,
and `detailedStats` flags.

```swift
for match in try await client.getLiveMatches() {
    print(match.name)
    if let tournament = match.tournament {
        print("  Tournament: \(tournament.name)")
    }
    if match.forfeit == true { print("  (forfeit)") }
}
```

## Building Queries

`QueryParameters` is a value type with a fluent, chainable API. Every modifier returns
a new copy, so queries are easy to compose and safe to share across tasks.

```swift
let query = QueryParameters()
    .filter("nationality", "KR")          // filter[nationality]=KR
    .sort("name", .ascending)             // sort=name
    .perPage(20)
    .page(1)

let koreanPlayers = try await client.getPlayers(PlayersRequest(parameters: query))
```

Filter values are a `QueryValue`. String, integer, and boolean literals work directly:

```swift
let query = QueryParameters()
    .filter("year", 2024)                 // Int literal
    .filter("nationality", "KR")          // String literal
    .filter("detailed_stats", true)       // Bool literal
```

Search and numeric ranges:

```swift
let query = QueryParameters()
    .search("name", "Serral")             // search[name]=Serral
    .range("number_of_games", from: 3, to: 5)  // range[number_of_games]=3,5
```

Apply a query to matches:

```swift
let parameters = QueryParameters()
    .filter("status", "finished")
    .sort("end_at", .descending)
    .perPage(50)

let matches = try await client.getMatches(parameters: parameters)
```

## Pagination

### A single page with metadata

`executePage(_:)` returns the decoded items plus the pagination metadata parsed from
the response headers (`X-Page`, `X-Per-Page`, `X-Total`).

```swift
let (players, info): ([Player], PaginationInfo?) =
    try await client.executePage(PlayersRequest())

if let info {
    print("Page \(info.page) of \(info.totalPages) — \(info.total) total")
    print("Has next page: \(info.hasNextPage)")
}
```

### Every page at once

```swift
// Convenience accessors
let allTeams = try await client.getAllTeams()

// Or directly, with an optional page cap
let firstFivePages: [Match] =
    try await client.executePaginated(MatchesRequest(), maxPages: 5)
```

### As an async stream

Stream every element of a paginated resource without materializing all pages at once:

```swift
for try await player in client.elements(of: PlayersRequest()) as AsyncThrowingStream<Player, Error> {
    print(player.name)
}
```

## Error Handling

All API methods `throw`. Network and API failures surface as `APIError`:

```swift
do {
    let matches = try await client.getMatches()
} catch let error as APIError {
    switch error {
    case .unauthorized(let message):
        print("Invalid API token: \(message)")
    case .forbidden(let message):
        print("Access denied (plan limitation): \(message)")
    case .notFound(let resource):
        print("Not found: \(resource)")
    case .rateLimitExceeded(let retryAfter, let remaining):
        print("Rate limited. Retry after \(retryAfter ?? 60)s, remaining: \(remaining ?? 0)")
    case .networkError(let underlying):
        print("Network issue: \(underlying.localizedDescription)")
    case .timeout:
        print("Request timed out")
    case .httpError(let statusCode, _):
        print("HTTP \(statusCode)")
    case .serverError(let statusCode, let message):
        print("Server error \(statusCode): \(message ?? "")")
    case .decodingError(let underlying, _):
        print("Decoding failed: \(underlying)")
    case .invalidRequest(let reason):
        print("Invalid request: \(reason)")
    case .cacheError(let underlying):
        print("Cache error: \(underlying)")
    }
}
```

`APIError` also exposes `isRetryable` and `suggestedRetryDelay`. Retryable errors
(network, timeout, server, rate-limit) are retried automatically by the client.

## Configuration

```swift
let config = StarCraftClient.Configuration(
    apiKey: "YOUR_PANDASCORE_TOKEN",
    authMethod: .queryParameter,                 // or .bearerToken (default)
    retryConfiguration: .aggressive,             // .default / .aggressive / .conservative
    cacheConfiguration: .init(maxSize: 200, defaultTTL: 600)
)
let client = StarCraftClient(configuration: config)
```

`Configuration` is built around `apiKey`; an `apiToken` alias is provided for
readability. Both `StarCraftClient(apiToken:)` and `StarCraftClient(configuration:)`
are available.

### Rate limit & cache status

```swift
// Rate limit. PandaScore sends no reset header, so resetTime is the top of the next hour.
let (remaining, resetTime) = await client.getRateLimitStatus()
print("Requests remaining: \(remaining ?? -1)")

// Cache
let stats = await client.getCacheStatistics()
print("Cache hit rate: \(stats.hitRate * 100)%")
await client.clearCache()
```

## Data Sources

StarCraftKit deliberately draws on two complementary sources so you get both live
structured data and the analytics PandaScore doesn't provide.

| Source | Role | Provides |
| --- | --- | --- |
| **PandaScore** (primary) | Live & structured esports data | Matches, players, teams, tournaments, series, leagues, streams |
| **Aligulac** (optional) | Ratings & analytics | Bayesian skill ratings, race-matchup performance, head-to-head, match predictions |

PandaScore is required (`StarCraftClient`). Aligulac is an optional companion client
you opt into with your own free key when you want ratings or predictions.

## Aligulac Integration

[Aligulac](https://aligulac.com) is the canonical community ratings database for
StarCraft II. `AligulacClient` surfaces data PandaScore lacks: Bayesian skill ratings
with per-race matchup breakdowns, head-to-head records, and win-probability predictions.

```swift
let aligulac = AligulacClient(apiKey: "YOUR_ALIGULAC_KEY")

// Find a player and read their rating
if let serral = try await aligulac.searchPlayers(tag: "Serral").first {
    if let rating = try await aligulac.rating(playerID: serral.id) {
        print("Overall: \(rating.rating ?? 0)")
        print("vs Protoss: \(rating.ratingVsProtoss ?? 0)")
        print("vs Terran:  \(rating.ratingVsTerran ?? 0)")
        print("vs Zerg:    \(rating.ratingVsZerg ?? 0)")
    }
}

// Top of the active-rating leaderboard
let top = try await aligulac.topRatings(limit: 10)

// Head-to-head record and a best-of-5 prediction between two players
let h2h = try await aligulac.headToHead(playerA: 485, playerB: 124)
print("\(h2h.winsA) – \(h2h.winsB)")

let prediction = try await aligulac.predictMatch(playerA: 485, playerB: 124, bestOf: 5)
print("P(A wins): \(prediction.probabilityA ?? 0)")

// Recent matches and full player record
let matches = try await aligulac.matches(playerID: 485)
let player = try await aligulac.player(id: 485)
```

### Requirements & attribution

Aligulac requires **your own free API key** — register at
[https://aligulac.com/about/api/](https://aligulac.com/about/api/). All requests are
made over HTTPS.

Aligulac's data is licensed for **non-commercial use with attribution**. Wherever you
display Aligulac-derived data, you must show the attribution string:

```swift
Text(AligulacClient.attribution) // "Rating data from aligulac.com"
```

Do not redistribute Aligulac's bulk database dump.

## CLI Tool

StarCraftKit ships a `starcraft` CLI for exploring the data from your terminal.

```bash
# Set your PandaScore token
export PANDA_TOKEN="your_api_key_here"

# Live tracking
swift run starcraft live
swift run starcraft today
swift run starcraft upcoming

# Players, teams, tournaments, series, leagues, matches
swift run starcraft players
swift run starcraft player-schedule Serral
swift run starcraft player-matches Maru
swift run starcraft tournaments
swift run starcraft tournament-matches GSL
swift run starcraft teams
swift run starcraft series
swift run starcraft leagues
swift run starcraft matches

# Universal search
swift run starcraft search Serral

# Export data
swift run starcraft export

# Open a live match's Twitch/YouTube stream
swift run starcraft stream --open

# Cache utilities
swift run starcraft cache stats
```

> The `stream` command opens the Twitch/YouTube URLs embedded in PandaScore match data.
> The library itself does not expose a streaming/WebSocket API.

Use `--help` with any command for its full set of options.

## API Coverage

- ✅ **Leagues** — list all StarCraft II leagues, fetch by id
- ✅ **Matches** — all, past, running, upcoming, by tournament, and by id
- ✅ **Players** — list, search, filter, fetch by id
- ✅ **Teams** — list, search, fetch by id
- ✅ **Series** — list and fetch by id
- ✅ **Tournaments** — list, fetch by id, with prize pools
- ✅ **Pagination** — single page, all pages, or async stream
- ✅ **Aligulac** — ratings, race matchups, head-to-head, predictions (optional)

## Architecture

```
StarCraftKit/
├── Core/
│   ├── Networking/     # API client, retry logic
│   └── Cache/          # Thread-safe response caching (raw bytes + TTL)
├── Models/
│   ├── API/            # API response models & query types
│   └── Domain/         # Computed/business-logic helpers
├── Aligulac/           # Aligulac client and models
├── Protocols/          # APIRequest and core protocol definitions
└── Endpoints/          # Type-safe request definitions
```

### Key Components

- **StarCraftClient** — actor-based entry point for all PandaScore operations
- **AligulacClient** — optional companion for ratings and predictions
- **QueryParameters** — value-type fluent query builder
- **NetworkingClient** — HTTP requests with retry
- **ResponseCache** — actor-based caching of raw response bytes with TTL
- **RetryHandler** — configurable exponential backoff with jitter

## Testing

```bash
# Run all tests
swift test

# Run a specific test
swift test --filter PlayerTests

# Verbose output
swift test -v
```

The test suite uses `MockURLProtocol` with JSON fixtures to exercise decoding,
networking, caching, and pagination without hitting the live API.

## Documentation

Full API documentation: https://guitaripod.github.io/StarCraftKit

Generate it locally:

```bash
swift package generate-documentation
```

## Requirements

- Swift 6.0+
- macOS 13.0+ / iOS 16.0+ / watchOS 9.0+ / tvOS 16.0+
- A PandaScore API key (get one at https://developers.pandascore.co)
- For ratings/predictions: a free Aligulac API key (https://aligulac.com/about/api/)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [PandaScore](https://pandascore.co) for the StarCraft II esports API
- [Aligulac](https://aligulac.com) for community StarCraft II ratings and predictions
- The Swift community for excellent open-source tools and libraries

## Author

Marcus Ziadé - [@guitaripod](https://github.com/guitaripod)
