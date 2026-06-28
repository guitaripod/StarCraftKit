# Querying Data

Learn how to use ``QueryParameters`` to filter, sort, search, and paginate API results.

## Overview

``QueryParameters`` is a value type with a fluent, chainable API. Every modifier
returns a new copy, so queries are easy to compose and safe to share across tasks.

Pass a query either through a request type (for players, teams, tournaments, series,
and leagues) or through the `getMatches(parameters:)` convenience method (for matches).

```swift
let parameters = QueryParameters()
    .filter("nationality", "KR")
    .sort("name", .ascending)
    .perPage(20)
    .page(1)

// Players, teams, etc. take a request:
let players = try await client.getPlayers(PlayersRequest(parameters: parameters))

// Matches have a parameters convenience overload:
let matches = try await client.getMatches(parameters: parameters)
```

## Filtering

Filters map to `filter[key]=value`. Values are a ``QueryValue``; string, integer, and
boolean literals work directly.

### Single Filter

```swift
let parameters = QueryParameters()
    .filter("nationality", "KR")
```

### Multiple Filters

```swift
let parameters = QueryParameters()
    .filter("nationality", "KR")
    .filter("role", "Terran")
```

### Boolean and Integer Filters

```swift
let parameters = QueryParameters()
    .filter("detailed_stats", true)   // Bool literal
    .filter("year", 2024)             // Int literal
```

### Numeric Range Filters

Ranges map to `range[key]=min,max` and take numeric bounds (either bound is optional):

```swift
let parameters = QueryParameters()
    .range("number_of_games", from: 3, to: 5)

// Open-ended ranges are allowed
let atLeastThree = QueryParameters()
    .range("number_of_games", from: 3)
```

## Searching

Search maps to `search[key]=value` and matches partial values:

```swift
let parameters = QueryParameters()
    .search("name", "Serral")

let players = try await client.getPlayers(PlayersRequest(parameters: parameters))
```

## Sorting

Sort fields are applied in order. Descending sorts are rendered as `-field`.

### Single Sort

```swift
let parameters = QueryParameters()
    .sort("name", .ascending)
```

### Multiple Sorts

```swift
let parameters = QueryParameters()
    .sort("begin_at", .descending)
    .sort("name", .ascending)
```

## Pagination

Control page size and page number. PandaScore caps page size at 100; values are
clamped to `1...100`.

```swift
let parameters = QueryParameters()
    .perPage(50)
    .page(2)
```

### A Single Page with Metadata

`executePage(_:)` returns the items plus the pagination metadata parsed from the
response headers:

```swift
let (players, info): ([Player], PaginationInfo?) =
    try await client.executePage(PlayersRequest(parameters: parameters))

if let info {
    print("Page \(info.page) of \(info.totalPages) — \(info.total) total")
    print("Has next page: \(info.hasNextPage)")
}
```

### Every Page at Once

```swift
// Convenience accessor
let allPlayers = try await client.getAllPlayers()

// Or directly, with an optional page cap
let firstThreePages: [Player] =
    try await client.executePaginated(PlayersRequest(), maxPages: 3)
```

### Streaming Elements

Stream every element without materializing all pages at once:

```swift
for try await player in client.elements(of: PlayersRequest()) as AsyncThrowingStream<Player, Error> {
    print(player.name)
}
```

## Complex Queries

Combine filtering, ranges, sorting, and pagination:

```swift
let parameters = QueryParameters()
    .filter("status", "finished")
    .range("number_of_games", from: 3, to: 5)
    .sort("end_at", .descending)
    .perPage(50)

let matches = try await client.getMatches(parameters: parameters)
```

## Common Filter Fields

### Players
- `nationality`: Country code (e.g., "KR", "US")
- `current_team_id`: Current team ID

### Matches
- `status`: Match status (`not_started`, `running`, `finished`)
- `tournament_id`: Tournament ID
- `serie_id`: Series ID
- `league_id`: League ID
- `opponent_id`: Player or team ID

### Tournaments
- `tier`: Tournament tier
- `serie_id`: Series ID

## Performance Tips

1. **Use specific filters** to reduce response size
2. **Limit results** with `perPage()` when you don't need everything
3. **Stream** with `elements(of:)` for large datasets instead of buffering all pages

## Error Handling

```swift
do {
    let results = try await client.getMatches(parameters: parameters)
} catch APIError.invalidRequest(let reason) {
    print("Invalid query: \(reason)")
} catch {
    print("Query failed: \(error)")
}
```
