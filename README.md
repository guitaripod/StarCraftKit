# StarCraftKit

[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![CI](https://github.com/guitaripod/StarCraftKit/actions/workflows/ci.yml/badge.svg)](https://github.com/guitaripod/StarCraftKit/actions/workflows/ci.yml)
[![Documentation](https://github.com/guitaripod/StarCraftKit/actions/workflows/docc.yml/badge.svg)](https://github.com/guitaripod/StarCraftKit/actions/workflows/docc.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20iOS%20%7C%20watchOS%20%7C%20tvOS-lightgray.svg)](https://developer.apple.com/swift/)

**One interface to all of StarCraft II.** StarCraftKit is a modern, production-ready Swift 6
SDK that aggregates four data sources behind a single facade — `StarCraft` — and fuses them
into composite answers: a player's complete cross-source profile, a predictive matchup
preview, and a live snapshot of everything happening in the scene right now.

```swift
import StarCraftKit

// SC2 Pulse is free and needs no key — this already does ladder, streams, and profiles.
let sc = StarCraft()

let serral = try await sc.profile(of: "Serral")     // ladder MMR + rating + pro profile, fused
let ladder = try await sc.topLadder(region: .eu, race: .zerg)
let now    = try await sc.liveScene()               // live matches + community streams + tournaments
```

## The unified `StarCraft` facade

`StarCraft` is the single entry point. Every credential is **optional**: SC2 Pulse (free,
no auth) is always available, so a bare `StarCraft()` already powers ladder leaderboards,
live community streams, seasons, patches, and player identity. Add tokens to unlock more —
sources you don't configure simply contribute nothing, and the composite views degrade
gracefully around them.

```swift
// Configure only what you have. All four arguments are optional.
let sc = StarCraft(
    pandaScoreToken: panda,                                  // pro scene (optional)
    aligulacKey: aligulac,                                   // ratings & predictions (optional)
    blizzardCredentials: .init(clientId: id, clientSecret: secret)  // official ladder (optional)
)

// Which sources are live right now?
print(sc.availableSources)   // e.g. [.sc2Pulse, .pandaScore, .aligulac, .blizzard]
```

You can also compose the facade from pre-configured source clients (handy for testing or
custom configurations):

```swift
let sc = StarCraft(
    pulse: SC2PulseClient(),
    pandaScore: StarCraftClient(apiToken: panda),
    aligulac: AligulacClient(apiKey: aligulac)
)
```

## Data Sources

StarCraftKit aggregates four complementary sources. SC2 Pulse is the free backbone; the
others are opt-in companions you enable with your own credentials.

| Source | Provides | Auth | Cost |
| --- | --- | --- | --- |
| **SC2 Pulse** | Ladder MMR & ranks, race distribution, clans, **live community streams** (with viewer counts), seasons, patches, recent ladder matches, and identity cross-links (ladder account → pro player → Aligulac id) | None | Free |
| **PandaScore** | Pro esports: matches, tournaments, players, teams, series, leagues | API token | Free tier |
| **Aligulac** | Bayesian skill ratings (per-race matchups), win-probability predictions, head-to-head records | Free API key (attribution required) | Free |
| **Blizzard Battle.net** | Official grandmaster ladder, current ranked season, player career profile | OAuth client credentials | Free (developer app) |

SC2 Pulse data is courtesy of **sc2pulse.nephest.com**. Aligulac data requires attribution
(`AligulacClient.attribution` — see [Aligulac attribution](#aligulac-attribution)).

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

No key required — SC2 Pulse powers the ladder, streams, and basic identity for free.

```swift
import StarCraftKit

let sc = StarCraft()

// Top of the grandmaster ladder, filtered by region and race
let ladder = try await sc.topLadder(region: .eu, race: .zerg, limit: 25)
for team in ladder.teams {
    print(team.name ?? "?", team.rating ?? 0)
}

// What's on right now: pro matches, community streams, running tournaments
let scene = try await sc.liveScene()
print("\(scene.liveStreams.count) streams · \(scene.totalViewers) viewers")

// A player's cross-source profile (ladder identity + any configured extras)
let serral = try await sc.profile(of: "Serral")
print(serral.displayName, serral.mmr ?? 0, serral.race?.displayName ?? "?")
print("Sources used:", serral.contributingSources.map(\.rawValue))
```

Add a token to enrich the same calls — e.g. with an Aligulac key, `matchup` returns a real
win prediction:

```swift
let sc = StarCraft(aligulacKey: "YOUR_ALIGULAC_KEY")

let m = try await sc.matchup("Serral", vs: "Maru", bestOf: 5)
if let p = m.prediction {
    print("P(Serral): \(p.probabilityA ?? 0)  P(Maru): \(p.probabilityB ?? 0)")
    print("Favorite:", m.favorite ?? "—")
}
print("Ladder MMR gap:", m.mmrDifference ?? 0)
```

## Composite Interfaces

The value-add of the facade is that it **fuses** sources into one answer. Each composite
pulls from every configured source in parallel and degrades gracefully when one is absent.

### `profile(of:)` → `PlayerProfile`

Resolves a player by name across all sources: SC2 Pulse ladder identity (MMR, rank, race,
region, clan), the linked Aligulac rating, the PandaScore pro profile, and upcoming pro
matches.

```swift
let p = try await sc.profile(of: "Serral")

p.displayName            // best name across sources
p.mmr                    // ladder MMR (SC2 Pulse)
p.ladderRank             // current ladder rank, if ranked
p.race                   // main race
p.region                 // Battle.net region
p.clanTag                // clan tag, if any
p.country                // ISO country (prefers the pro profile)
p.earnings               // career earnings in USD (SC2 Pulse)
p.isPro                  // has a known pro identity?
p.rating                 // AligulacRating? (per-race matchups)
p.proPlayer              // PandaScore Player?
p.upcomingProMatches     // [Match]
p.contributingSources    // which sources actually contributed
```

### `matchup(_:vs:bestOf:)` → `Matchup`

A predictive preview of two players: the ladder MMR gap, Aligulac's win-probability
prediction, and the all-time head-to-head record.

```swift
let m = try await sc.matchup("Serral", vs: "Maru", bestOf: 5)

m.mmrDifference          // ladder MMR gap (A − B), when both are known
m.prediction             // AligulacMatchPrediction? (needs Aligulac)
m.favorite               // favored player's name by Aligulac probability
m.headToHead             // HeadToHead? all-time record (needs Aligulac)
m.ladderA                // LadderCharacter? for player A
m.ladderB                // LadderCharacter? for player B
```

### `liveScene()` → `LiveScene`

A single "what's on" view fusing the pro scene with the ladder community.

```swift
let scene = try await sc.liveScene()

scene.liveMatches        // live pro matches (PandaScore)
scene.liveStreams        // live community streams with viewer counts (SC2 Pulse)
scene.runningTournaments // running tournaments (PandaScore)
scene.totalViewers       // summed viewer count across community streams
scene.isActive           // is anything happening right now?
```

### Free ladder, streams, seasons & patches (SC2 Pulse)

```swift
let snapshot = try await sc.topLadder(region: .eu, race: .zerg)  // LadderSnapshot
let streams  = try await sc.liveStreams(limit: 50)               // [LadderStream]
let seasons  = try await sc.seasons()                            // [PulseSeason]
let patches  = try await sc.patches()                            // [GamePatch]
```

### Official Blizzard ladder (needs OAuth credentials)

```swift
let sc = StarCraft(blizzardCredentials: .init(clientId: id, clientSecret: secret))

let gm     = try await sc.officialLadder(region: .eu)   // [GrandmasterTeam]
let season = try await sc.officialSeason(region: .eu)   // BlizzardSeason
```

### Pro scene pass-throughs (needs a PandaScore token)

```swift
let live     = try await sc.liveMatches()        // [Match]
let upcoming = try await sc.upcomingMatches()    // [Match]
let past     = try await sc.pastMatches()        // [Match]
let events   = try await sc.tournaments()        // [Tournament]
```

These throw `APIError.invalidRequest` if you call them without configuring the underlying
source — check `sc.availableSources` first, or just configure the token.

## Advanced: direct source access

The facade exposes each underlying client, and you can also instantiate every source
standalone. Reach for these when you need an endpoint the composites don't surface, custom
configuration, caching control, or pagination.

```swift
let sc = StarCraft(pandaScoreToken: panda, aligulacKey: aligulac)

sc.pulse        // SC2PulseClient   (always present)
sc.pandaScore   // StarCraftClient? (PandaScore)
sc.aligulac     // AligulacClient?
sc.blizzard     // BlizzardClient?
```

### PandaScore — `StarCraftClient`

The full PandaScore esports client. Actor-based, with caching, retry, and first-class
pagination.

```swift
let client = StarCraftClient(apiToken: "YOUR_PANDASCORE_TOKEN")

// First page / single resource / everything (paginated automatically)
let players = try await client.getPlayers()
let player  = try await client.getPlayer(id: 12345)
let all     = try await client.getAllPlayers()

// Match convenience methods
let liveMatches = try await client.getLiveMatches()
let upcoming    = try await client.getUpcomingMatches()
let past        = try await client.getPastMatches()
let bracket     = try await client.getTournamentMatches(tournamentId: 11111)

// Search
let serral = try await client.searchPlayers(name: "Serral")
let teams  = try await client.searchTeams(name: "Dragon")
```

#### Building queries

`QueryParameters` is a value type with a fluent, chainable API. Every modifier returns a
new copy, so queries are easy to compose and safe to share across tasks.

```swift
let query = QueryParameters()
    .filter("nationality", "KR")          // filter[nationality]=KR
    .filter("year", 2024)                 // Int literal
    .filter("detailed_stats", true)       // Bool literal
    .search("name", "Serral")             // search[name]=Serral
    .range("number_of_games", from: 3, to: 5)
    .sort("name", .ascending)
    .perPage(20)
    .page(1)

let koreanPlayers = try await client.getPlayers(PlayersRequest(parameters: query))
```

#### Pagination

```swift
// A single page with metadata parsed from response headers
let (players, info): ([Player], PaginationInfo?) =
    try await client.executePage(PlayersRequest())

// Every page at once, with an optional cap
let firstFivePages: [Match] =
    try await client.executePaginated(MatchesRequest(), maxPages: 5)

// Or as an async stream — no need to materialize all pages
for try await player in client.elements(of: PlayersRequest()) as AsyncThrowingStream<Player, Error> {
    print(player.name)
}
```

#### Configuration, rate limit & cache

```swift
let config = StarCraftClient.Configuration(
    apiKey: "YOUR_PANDASCORE_TOKEN",
    authMethod: .queryParameter,                 // or .bearerToken (default)
    retryConfiguration: .aggressive,             // .default / .aggressive / .conservative
    cacheConfiguration: .init(maxSize: 200, defaultTTL: 600)
)
let client = StarCraftClient(configuration: config)

let (remaining, resetTime) = await client.getRateLimitStatus()
let stats = await client.getCacheStatistics()
await client.clearCache()
```

### SC2 Pulse — `SC2PulseClient`

The free, no-auth ladder/streams/identity client (data from `sc2pulse.nephest.com`).

```swift
let pulse = SC2PulseClient()

let characters = try await pulse.searchCharacters("Serral")   // [LadderCharacter]
let top        = try await pulse.topLadder(region: .eu, race: .zerg, limit: 50)
let streams    = try await pulse.liveStreams(limit: 50)       // [LadderStream]
let clans      = try await pulse.clans(query: "ONSYDE")       // [PulseClan]
let seasons    = try await pulse.seasons()                    // [PulseSeason]
let patches    = try await pulse.patches()                    // [GamePatch]

// Recent ladder matches for a known character id
let matches = try await pulse.recentMatches(characterId: 12345)
```

### Aligulac — `AligulacClient`

Bayesian skill ratings, race matchups, head-to-head, and win predictions.

```swift
let aligulac = AligulacClient(apiKey: "YOUR_ALIGULAC_KEY")

if let serral = try await aligulac.searchPlayers(tag: "Serral").first,
   let rating = try await aligulac.rating(playerID: serral.id) {
    print("Overall: \(rating.rating ?? 0)")
    print("vs Protoss: \(rating.ratingVsProtoss ?? 0)")
    print("vs Terran:  \(rating.ratingVsTerran ?? 0)")
    print("vs Zerg:    \(rating.ratingVsZerg ?? 0)")
}

let top        = try await aligulac.topRatings(limit: 10)
let h2h        = try await aligulac.headToHead(playerA: 485, playerB: 124)
let prediction = try await aligulac.predictMatch(playerA: 485, playerB: 124, bestOf: 5)
let history    = try await aligulac.matches(playerID: 485)
let player     = try await aligulac.player(id: 485)
```

#### Aligulac attribution

Aligulac requires **your own free API key** — register at
[https://aligulac.com/about/api/](https://aligulac.com/about/api/). Its data is licensed
for **non-commercial use with attribution**: wherever you display Aligulac-derived data,
show the required attribution string, and never redistribute the bulk database dump.

```swift
Text(AligulacClient.attribution) // "Rating data from aligulac.com"
```

### Blizzard Battle.net — `BlizzardClient`

Official ladder and profile data. Uses the OAuth client-credentials flow and caches the
access token. Register a developer app at [develop.battle.net](https://develop.battle.net).

```swift
let blizzard = BlizzardClient(credentials: .init(clientId: id, clientSecret: secret))

let gm      = try await blizzard.grandmasterLadder(region: .eu)   // [GrandmasterTeam]
let season  = try await blizzard.currentSeason(region: .eu)       // BlizzardSeason
let profile = try await blizzard.profile(region: .eu, realmId: 1, profileId: 1234567)
```

## Error Handling

All API methods `throw`. Network and API failures surface as `APIError`:

```swift
do {
    let scene = try await sc.liveScene()
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
        print("Invalid request: \(reason)")    // e.g. a source isn't configured
    case .cacheError(let underlying):
        print("Cache error: \(underlying)")
    }
}
```

`APIError` also exposes `isRetryable` and `suggestedRetryDelay`. Retryable errors
(network, timeout, server, rate-limit) are retried automatically.

## CLI Tool

StarCraftKit ships a `starcraft` CLI. The unified commands work against the free SC2 Pulse
backbone with **zero configuration**; tokens unlock the richer ones.

```bash
# Unified commands — no key required (SC2 Pulse)
starcraft profile Serral             # cross-source dossier (PANDA_TOKEN/ALIGULAC_TOKEN enrich it)
starcraft ladder --region eu --race zerg --limit 25
starcraft scene                      # everything live: pro matches, streams, tournaments
starcraft matchup Serral Maru --best-of 5
starcraft streams                    # live community streams by viewers
starcraft seasons
starcraft patches

# Optional tokens enrich the unified commands and power the pro-scene commands
export PANDA_TOKEN="your_pandascore_key"    # pro matches, profiles, tournaments
export ALIGULAC_TOKEN="your_aligulac_key"   # ratings, predictions, head-to-head

# Pro-scene commands (PandaScore — need PANDA_TOKEN)
starcraft live
starcraft today
starcraft upcoming
starcraft players
starcraft player-schedule Serral
starcraft tournaments
starcraft tournament-matches GSL
starcraft search Serral

# Ratings & predictions (Aligulac — need ALIGULAC_TOKEN)
starcraft rating Serral
starcraft predict Serral Maru
```

> The unified `profile`, `ladder`, `scene`, `matchup`, `streams`, `seasons`, and `patches`
> commands run with no key at all. Blizzard credentials are not yet wired into the CLI.

Use `--help` with any command for its full set of options.

## Features

- 🌐 **Unified `StarCraft` facade** — one interface aggregating four data sources
- 🧩 **Composite views** — `PlayerProfile`, `Matchup`, `LiveScene`, `LadderSnapshot` fuse sources into single answers that degrade gracefully
- 🆓 **Free by default** — SC2 Pulse needs no key; ladder, streams, seasons, patches, and identity work out of the box
- 🚀 **Swift 6** — full Swift 6 language mode, data-race safe, async/await throughout
- 🎭 **Actor-based clients** — every source client is an actor; every request type is `Sendable`
- 🔌 **Four sources** — SC2 Pulse, PandaScore, Aligulac, Blizzard Battle.net
- 🧱 **Fluent, value-type queries** — chainable filtering, sorting, searching, ranges, and pagination (PandaScore)
- 🔄 **Automatic retry** — exponential backoff with jitter
- 💾 **Real response caching** — actor-based, byte-accurate, per-request TTL
- 📄 **First-class pagination** — single page, all pages, or an async stream
- 🛡️ **Robust decoding** — models tolerate the APIs' nulls and missing fields
- 📱 **Cross-platform** — macOS, iOS, watchOS, tvOS, and Linux
- 📚 **Full DocC documentation** — for every public API

## Requirements

- Swift 6.0+
- macOS 13.0+ / iOS 16.0+ / watchOS 9.0+ / tvOS 16.0+
- **No key** for SC2 Pulse (ladder, streams, seasons, patches, identity)
- A free PandaScore API key for the pro scene: <https://developers.pandascore.co>
- A free Aligulac API key for ratings/predictions: <https://aligulac.com/about/api/>
- Blizzard OAuth client credentials for official data: <https://develop.battle.net>

## Documentation

Full API documentation: https://guitaripod.github.io/StarCraftKit

Generate it locally:

```bash
swift package generate-documentation
```

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

- [SC2 Pulse](https://sc2pulse.nephest.com) for free ladder, streams, and identity data
- [PandaScore](https://pandascore.co) for the StarCraft II esports API
- [Aligulac](https://aligulac.com) for community StarCraft II ratings and predictions
- [Blizzard](https://develop.battle.net) for the official Battle.net SC2 API
- The Swift community for excellent open-source tools and libraries

## Author

Marcus Ziadé - [@guitaripod](https://github.com/guitaripod)
