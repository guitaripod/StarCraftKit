# ``StarCraftKit``

One interface to all of StarCraft II — a Swift 6 SDK that aggregates four data sources behind a single facade and fuses them into composite answers.

## Overview

StarCraftKit's entry point is ``StarCraft``: a single abstraction over every source the SDK
can reach. It exposes thin pass-throughs to each source **and** composite interfaces that
fuse them into one answer — ``StarCraft/profile(of:)``, ``StarCraft/matchup(_:vs:bestOf:)``,
and ``StarCraft/liveScene()``.

Every credential is optional. SC2 Pulse is free and needs no key, so a bare `StarCraft()`
already powers the ladder, live community streams, seasons, patches, and player identity.
Add tokens to unlock the pro scene (PandaScore), ratings and predictions (Aligulac), and the
official Blizzard ladder. Sources you don't configure simply contribute nothing, and the
composites degrade gracefully.

```swift
import StarCraftKit

let sc = StarCraft()   // free: SC2 Pulse only

let serral = try await sc.profile(of: "Serral")     // ladder + rating + pro profile, fused
let ladder = try await sc.topLadder(region: .eu, race: .zerg)
let now    = try await sc.liveScene()               // live matches + streams + tournaments
```

### Data Sources

StarCraftKit aggregates four complementary sources, enumerated by ``DataSource``:

- **SC2 Pulse** (``SC2PulseClient``) — free, no auth. Ladder MMR & ranks, race distribution, clans, live community streams with viewer counts, seasons, patches, recent ladder matches, and identity cross-links. Data from `sc2pulse.nephest.com`.
- **PandaScore** (``StarCraftClient``) — pro esports: matches, tournaments, players, teams, series, leagues. Needs an API token.
- **Aligulac** (``AligulacClient``) — Bayesian ratings, per-race matchups, predictions, head-to-head. Needs a free key; attribution required (``AligulacClient/attribution``).
- **Blizzard Battle.net** (``BlizzardClient``) — official grandmaster ladder, ranked season, career profile. Needs OAuth credentials.

### Composite Views

The facade's value-add is fusing sources into single answers:

- ``PlayerProfile`` — ladder identity + Aligulac rating + PandaScore pro profile + upcoming matches.
- ``Matchup`` — ladder MMR gap + Aligulac prediction + head-to-head.
- ``LiveScene`` — live pro matches + live community streams + running tournaments.
- ``LadderSnapshot`` — a ranked ladder leaderboard.

### Key Features

- 🌐 **Unified facade**: ``StarCraft`` aggregates four data sources behind one interface
- 🧩 **Composite views**: ``PlayerProfile``, ``Matchup``, ``LiveScene`` fuse sources, degrading gracefully
- 🆓 **Free by default**: SC2 Pulse needs no key
- 🚀 **Swift 6**: Full Swift 6 language mode, data-race safe, async/await throughout
- 🎭 **Actor-based clients**: every source client is an actor; every request type is `Sendable`
- 🧱 **Fluent value-type queries**: ``QueryParameters`` composes filtering, sorting, searching, ranges, and pagination
- 🔄 **Automatic retry**: Exponential backoff with jitter
- 💾 **Real response caching**: Actor-based, byte-accurate, per-request TTL
- 📄 **First-class pagination**: Single page, all pages, or an async stream
- 📱 **Cross-platform**: macOS, iOS, tvOS, watchOS, and Linux

## Topics

### Getting Started

- <doc:GettingStarted>
- <doc:UnifiedAPI>
- <doc:Authentication>

### The Unified Facade

- ``StarCraft``
- ``DataSource``

### Composite Types

- ``PlayerProfile``
- ``Matchup``
- ``LiveScene``
- ``LadderSnapshot``

### Data Sources

- ``SC2PulseClient``
- ``StarCraftClient``
- ``AligulacClient``
- ``BlizzardClient``

### Making Requests (PandaScore)

- <doc:BasicRequests>
- <doc:QueryingData>
- <doc:ErrorHandling>
- ``QueryParameters``
- ``PaginationInfo``
- ``APIError``

### Pro Scene Models (PandaScore)

- ``Match``
- ``Player``
- ``Team``
- ``Tournament``
- ``League``
- ``Series``

### Ladder & Identity Models (SC2 Pulse)

- ``LadderCharacter``
- ``LadderTeam``
- ``LadderStream``
- ``PulseSeason``
- ``GamePatch``
- ``SC2Region``
- ``LadderLeague``
- ``Race``

### Ratings & Predictions (Aligulac)

- ``AligulacPlayer``
- ``AligulacRating``
- ``AligulacMatch``
- ``HeadToHead``
- ``AligulacMatchPrediction``

### Official Data (Blizzard)

- ``BlizzardCredentials``
- ``BlizzardRegion``
- ``GrandmasterTeam``
- ``BlizzardSeason``
- ``BlizzardProfile``
