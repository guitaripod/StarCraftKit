# Basic Requests

Learn how to fetch different types of StarCraft II esports data using StarCraftKit.

## Overview

StarCraftKit provides simple, intuitive methods for fetching various types of esports data. All requests are asynchronous and use Swift's async/await pattern.

Each resource follows the same naming convention:

- `getPlayers(_:)` — the first page of results
- `getAllPlayers()` — every page, fetched automatically
- `getPlayer(id:)` — a single resource by id

## Fetching Matches

### Live Matches

Get currently running matches:

```swift
let liveMatches = try await client.getLiveMatches()
for match in liveMatches {
    print(match.name)
    if let tournament = match.tournament {
        print("  Tournament: \(tournament.name)")
    }
    if let first = match.results.first, let last = match.results.last {
        print("  Score: \(first.score) - \(last.score)")
    }
}
```

### Upcoming Matches

Fetch matches scheduled for the future:

```swift
let upcomingMatches = try await client.getUpcomingMatches()
print("Next \(upcomingMatches.count) matches:")
for match in upcomingMatches {
    if let beginAt = match.beginAt {
        print("\(match.name) starts at \(beginAt)")
    }
}
```

### Past Matches

Get recently completed matches:

```swift
let pastMatches = try await client.getPastMatches()
for match in pastMatches {
    if let winner = match.winner {
        print("\(match.name): \(winner.name ?? "Unknown") won")
    }
}
```

### A Single Match

```swift
let match = try await client.getMatch(id: 11111)
```

### Filtering Matches

```swift
let parameters = QueryParameters()
    .filter("status", "finished")
    .sort("end_at", .descending)
    .perPage(50)

let matches = try await client.getMatches(parameters: parameters)
```

## Fetching Players

### All Players

```swift
let players = try await client.getPlayers()
for player in players {
    print("\(player.name) - \(player.nationality ?? "Unknown")")
}
```

### Search for Players

```swift
// Convenience helper
let results = try await client.searchPlayers(name: "Serral")

// Or build the query yourself
let parameters = QueryParameters()
    .search("name", "Serral")
    .perPage(10)
let searchResults = try await client.getPlayers(PlayersRequest(parameters: parameters))
```

### Player Details

```swift
let player = try await client.getPlayer(id: 12345)
print("Player: \(player.name)")
print("Team: \(player.currentTeam?.name ?? "No team")")
```

## Fetching Teams

### Teams

```swift
let teams = try await client.getTeams()
for team in teams {
    print("\(team.name) - \(team.acronym ?? "")")
}
```

### Search for Teams

```swift
let dragons = try await client.searchTeams(name: "Dragon")
```

### Team Details

```swift
let team = try await client.getTeam(id: 67890)
print("Team: \(team.name)")
print("Players: \(team.players?.count ?? 0)")
```

## Fetching Tournaments

### Tournaments

```swift
let tournaments = try await client.getTournaments()
for tournament in tournaments {
    print(tournament.name)
    if let prizePool = tournament.prizepool {
        print("  Prize Pool: \(prizePool)")
    }
}
```

### A Single Tournament

```swift
let tournament = try await client.getTournament(id: 222)
```

### Tournament Matches

```swift
let matches = try await client.getTournamentMatches(tournamentId: 11111)
print("Tournament has \(matches.count) matches")
```

## Fetching Leagues

```swift
let leagues = try await client.getLeagues()
for league in leagues {
    print("\(league.name) - \(league.slug)")
}

let league = try await client.getLeague(id: 333)
```

## Fetching Series

### All Series

```swift
let series = try await client.getSeries()
for serie in series {
    print("\(serie.fullName) - Year: \(serie.year ?? 0)")
}
```

### A Single Series

```swift
let oneSeries = try await client.getSeries(id: 444)
```

## Fetching Everything

To page through every result automatically, use the `getAll*` accessors:

```swift
let allPlayers = try await client.getAllPlayers()
let allTeams = try await client.getAllTeams()
let allTournaments = try await client.getAllTournaments()
let allSeries = try await client.getAllSeries()
let allLeagues = try await client.getAllLeagues()
let allMatches = try await client.getAllMatches()
```

## Error Handling

Always handle potential errors when making requests:

```swift
do {
    let matches = try await client.getLiveMatches()
    // Process matches
} catch APIError.rateLimitExceeded(let retryAfter, _) {
    print("Rate limit exceeded. Retry after \(retryAfter ?? 60) seconds")
} catch APIError.notFound(let resource) {
    print("Resource not found: \(resource)")
} catch {
    print("Unexpected error: \(error)")
}
```

## Next Steps

- Learn about <doc:QueryingData> for advanced filtering, sorting, and pagination
- Understand <doc:ErrorHandling> for robust applications
