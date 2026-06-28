# Getting Started

Learn how to integrate StarCraftKit into your Swift project and make your first API call.

## Installation

### Swift Package Manager

Add StarCraftKit to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/guitaripod/StarCraftKit.git", from: "2.0.0")
]
```

Then add it to your target dependencies:

```swift
.target(
    name: "YourApp",
    dependencies: ["StarCraftKit"]
)
```

### Xcode

1. In Xcode, select **File → Add Package Dependencies...**
2. Enter the repository URL: `https://github.com/guitaripod/StarCraftKit.git`
3. Select the version you want to use
4. Add StarCraftKit to your target

## Basic Setup

### Import the Framework

```swift
import StarCraftKit
```

### Start with the unified facade

The entry point is ``StarCraft``. SC2 Pulse is free and needs no key, so a bare
`StarCraft()` already powers the ladder, live community streams, and player identity:

```swift
let sc = StarCraft()

let ladder = try await sc.topLadder(region: .eu, race: .zerg)
let scene  = try await sc.liveScene()
let serral = try await sc.profile(of: "Serral")
```

Add credentials to unlock more sources — every argument is optional:

```swift
let sc = StarCraft(
    pandaScoreToken: "your-pandascore-token",   // pro scene
    aligulacKey: "your-aligulac-key"            // ratings & predictions
)
```

See <doc:UnifiedAPI> for the full facade and its composite interfaces.

### Or use a source client directly

For the full PandaScore surface, create a ``StarCraftClient`` with your token and fetch
current live matches:

```swift
let client = StarCraftClient(apiToken: "your-api-token")

do {
    let matches = try await client.getLiveMatches()
    for match in matches {
        print("\(match.name) - Status: \(match.status)")
    }
} catch {
    print("Error: \(error)")
}
```

## Environment Variables

For security, store your API token in environment variables:

```bash
export PANDA_TOKEN="your-api-token"
```

Then load it in your app:

```swift
let token = ProcessInfo.processInfo.environment["PANDA_TOKEN"] ?? ""
let client = StarCraftClient(apiToken: token)
```

## Ratings & Predictions (Aligulac)

For skill ratings, race-matchup performance, head-to-head records, and match
predictions that PandaScore doesn't provide, add the optional ``AligulacClient``. It
needs its own free API key (register at <https://aligulac.com/about/api/>):

```swift
let aligulac = AligulacClient(apiKey: "your-aligulac-key")
if let serral = try await aligulac.searchPlayers(tag: "Serral").first,
   let rating = try await aligulac.rating(playerID: serral.id) {
    print("vs Zerg: \(rating.ratingVsZerg ?? 0)")
}
```

Aligulac data is licensed for non-commercial use **with attribution** — display
`AligulacClient.attribution` ("Rating data from aligulac.com") wherever you show it.

## Next Steps

- Aggregate every source with the <doc:UnifiedAPI> facade
- Learn about <doc:Authentication> and API token management
- Explore <doc:BasicRequests> to fetch different types of data
- Build advanced queries with <doc:QueryingData>
- Understand <doc:ErrorHandling> for robust applications