# Aggregating StarCraft Data

Use the ``StarCraft`` facade to reach every data source through one interface and fuse them into composite answers.

## Overview

``StarCraft`` is the single entry point to the SDK. It sits over four sources and exposes
both thin pass-throughs and **composite interfaces** that combine those sources into a
single result. Every credential is optional: SC2 Pulse is free and always available, so the
facade is useful with no configuration at all.

```swift
import StarCraftKit

let sc = StarCraft()   // free: SC2 Pulse only
```

## Configuring sources

Pass only the credentials you have. Each omitted source is simply disabled, and the
composites work around it.

```swift
let sc = StarCraft(
    pandaScoreToken: panda,                                          // pro scene
    aligulacKey: aligulac,                                           // ratings & predictions
    blizzardCredentials: .init(clientId: id, clientSecret: secret)   // official ladder
)

print(sc.availableSources)   // e.g. [.sc2Pulse, .pandaScore, .aligulac, .blizzard]
```

You can also compose the facade from pre-configured clients — useful for testing or custom
configuration:

```swift
let sc = StarCraft(
    pulse: SC2PulseClient(),
    pandaScore: StarCraftClient(apiToken: panda),
    aligulac: AligulacClient(apiKey: aligulac)
)
```

## The four sources

| Source | Client | Provides | Auth |
| --- | --- | --- | --- |
| SC2 Pulse | ``SC2PulseClient`` | Ladder MMR, race distribution, clans, live community streams, seasons, patches, identity cross-links | None (free) |
| PandaScore | ``StarCraftClient`` | Pro matches, tournaments, players, teams | API token |
| Aligulac | ``AligulacClient`` | Bayesian ratings, predictions, head-to-head | Free key (attribution) |
| Blizzard | ``BlizzardClient`` | Official grandmaster ladder, season, profile | OAuth credentials |

SC2 Pulse data is courtesy of `sc2pulse.nephest.com`. Aligulac data requires attribution
(``AligulacClient/attribution`` — `"Rating data from aligulac.com"`).

## Composite interfaces

### A complete player profile

``StarCraft/profile(of:)`` resolves a player by name across every configured source and
returns a ``PlayerProfile``. It fuses SC2 Pulse ladder identity, the linked Aligulac
rating, and the PandaScore pro profile with upcoming matches.

```swift
let p = try await sc.profile(of: "Serral")

print(p.displayName)              // best name across sources
print(p.mmr ?? 0)                 // ladder MMR (SC2 Pulse)
print(p.race?.displayName ?? "?") // main race
print(p.rating?.rating ?? 0)      // Aligulac overall rating, if configured
print(p.isPro)                    // known pro identity?
print(p.contributingSources)      // which sources actually contributed
```

Every enrichment is optional. With no Aligulac key, ``PlayerProfile/rating`` is `nil`; with
no PandaScore token, ``PlayerProfile/proPlayer`` and ``PlayerProfile/upcomingProMatches``
stay empty. The ladder identity from SC2 Pulse is always attempted.

### A predictive matchup

``StarCraft/matchup(_:vs:bestOf:)`` returns a ``Matchup`` combining each player's ladder
MMR with Aligulac's win prediction and head-to-head record.

```swift
let m = try await sc.matchup("Serral", vs: "Maru", bestOf: 5)

if let diff = m.mmrDifference {
    print("Ladder MMR gap (A − B): \(diff)")    // always available via SC2 Pulse
}
if let prediction = m.prediction {              // needs an Aligulac key
    print("P(Serral): \(prediction.probabilityA ?? 0)")
    print("Favorite: \(m.favorite ?? "—")")
}
if let h2h = m.headToHead {
    print("Head-to-head: \(h2h.winsA)-\(h2h.winsB)")
}
```

### A live snapshot of the scene

``StarCraft/liveScene()`` returns a ``LiveScene`` fusing the pro scene (live PandaScore
matches and running tournaments) with the ladder community (live SC2 Pulse streams).

```swift
let scene = try await sc.liveScene()

print("Pro matches: \(scene.liveMatches.count)")
print("Streams: \(scene.liveStreams.count) · \(scene.totalViewers) viewers")
print("Tournaments: \(scene.runningTournaments.count)")
print("Anything live? \(scene.isActive)")
```

The community streams come from SC2 Pulse and need no key; the live matches and tournaments
populate only when a PandaScore token is configured.

## Free ladder data

``StarCraft/topLadder(region:race:league:queue:limit:)`` returns a ``LadderSnapshot`` from
SC2 Pulse — no key required.

```swift
let snapshot = try await sc.topLadder(region: .eu, race: .zerg, limit: 25)
for team in snapshot.teams {
    print(team.name ?? "?", team.rating ?? 0)
}

let streams = try await sc.liveStreams(limit: 50)   // [LadderStream]
let seasons = try await sc.seasons()                // [PulseSeason]
let patches = try await sc.patches()                // [GamePatch]
```

## Official Blizzard data

With OAuth credentials, the facade exposes the official ladder and season.

```swift
let sc = StarCraft(blizzardCredentials: .init(clientId: id, clientSecret: secret))

let gm     = try await sc.officialLadder(region: .eu)   // [GrandmasterTeam]
let season = try await sc.officialSeason(region: .eu)   // BlizzardSeason
```

Calling a source-specific method without configuring that source throws
``APIError/invalidRequest(reason:)``. Check ``StarCraft/availableSources`` first, or simply
provide the credential.

## Reaching a source directly

For endpoints the composites don't surface, access each underlying client through the
facade — ``StarCraft/pulse``, ``StarCraft/pandaScore``, ``StarCraft/aligulac``, and
``StarCraft/blizzard`` — or instantiate any client standalone.

```swift
let pulse = SC2PulseClient()
let clans = try await pulse.clans(query: "ONSYDE")

let aligulac = AligulacClient(apiKey: aligulac)
let top = try await aligulac.topRatings(limit: 10)
```

See <doc:BasicRequests> and <doc:QueryingData> for the full PandaScore client surface.
