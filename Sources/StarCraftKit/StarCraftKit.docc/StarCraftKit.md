# ``StarCraftKit``

A modern Swift 6 SDK for StarCraft II esports data, drawing on PandaScore for live and structured data and Aligulac for ratings and predictions.

## Overview

StarCraftKit provides a comprehensive, type-safe interface to the PandaScore API, enabling developers to integrate StarCraft II esports data into their applications. Whether you're building a tournament tracker, a player statistics app, or a live match viewer, StarCraftKit has you covered — and it pairs PandaScore's structured data with Aligulac's skill ratings, head-to-head records, and match predictions.

```swift
import StarCraftKit

let client = StarCraftClient(apiToken: "YOUR_PANDASCORE_TOKEN")
let liveMatches = try await client.getLiveMatches()
```

### Key Features

- 🚀 **Swift 6**: Full Swift 6 language mode, data-race safe, async/await throughout
- 🎭 **Actor-based client**: ``StarCraftClient`` is an actor; every request type is `Sendable`
- 🔌 **Two data sources**: PandaScore for live/structured esports data, ``AligulacClient`` for ratings & predictions
- 🧱 **Fluent value-type queries**: ``QueryParameters`` composes filtering, sorting, searching, ranges, and pagination
- 🔄 **Automatic retry**: Exponential backoff with jitter
- 💾 **Real response caching**: Actor-based, byte-accurate, per-request TTL
- 📄 **First-class pagination**: Single page, all pages, or an async stream
- 📱 **Cross-platform**: macOS, iOS, tvOS, watchOS, and Linux

## Topics

### Getting Started

- <doc:GettingStarted>
- <doc:Authentication>

### Making Requests

- <doc:BasicRequests>
- <doc:QueryingData>
- <doc:ErrorHandling>

### Essential Types

- ``StarCraftClient``
- ``QueryParameters``
- ``PaginationInfo``
- ``APIError``

### Data Models

- ``Match``
- ``Player``
- ``Team``
- ``Tournament``
- ``League``
- ``Series``

### Aligulac (Ratings & Predictions)

- ``AligulacClient``
- ``AligulacPlayer``
- ``AligulacRating``
- ``AligulacMatch``
- ``HeadToHead``
- ``AligulacMatchPrediction``
