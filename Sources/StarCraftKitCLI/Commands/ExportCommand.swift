import ArgumentParser
import Foundation
import StarCraftKit

struct ExportCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "export",
        abstract: "Export StarCraft 2 data in various formats",
        discussion: "Export match, player, or tournament data to JSON or CSV files"
    )
    
    @Argument(help: "Type of data to export (matches, players, tournaments)")
    var dataType: String
    
    @Option(name: .shortAndLong, help: "Output format (json, csv)")
    var format: String = "json"
    
    @Option(name: .shortAndLong, help: "Output file path")
    var output: String?
    
    @Option(name: .shortAndLong, help: "Number of items to export")
    var limit: Int = 100
    
    @Option(name: .shortAndLong, help: "Filter by player name")
    var player: String?
    
    @Option(name: .shortAndLong, help: "Filter by tournament")
    var tournament: String?
    
    @Option(name: .shortAndLong, help: "Filter by date (YYYY-MM-DD)")
    var since: String?
    
    @Flag(name: .shortAndLong, help: "Include all available fields")
    var verbose: Bool = false
    
    func run() async throws {
        let context = try CLIContext.load()
        let client = StarCraftClient(configuration: StarCraftClient.Configuration(apiKey: context.apiKey, authMethod: context.authMethod))
        
        let exportFormat = ExportFormat(rawValue: format.lowercased()) ?? .json
        let outputPath = output ?? "\(dataType)_export.\(exportFormat.fileExtension)"
        
        print("📦 Exporting \(dataType) data...".gray)
        
        switch dataType.lowercased() {
        case "matches":
            try await exportMatches(client: client, format: exportFormat, to: outputPath)
        case "players":
            try await exportPlayers(client: client, format: exportFormat, to: outputPath)
        case "tournaments":
            try await exportTournaments(client: client, format: exportFormat, to: outputPath)
        default:
            throw CLIError.invalidInput("Unknown data type: \(dataType). Use 'matches', 'players', or 'tournaments'")
        }
        
        print("✅ Export complete: \(outputPath)".green)
        print("📄 Format: \(exportFormat.rawValue.uppercased())".cyan)
        
        // Show file size
        if let attributes = try? FileManager.default.attributesOfItem(atPath: outputPath),
           let fileSize = attributes[.size] as? Int64 {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            print("📊 Size: \(formatter.string(fromByteCount: fileSize))".gray)
        }
    }
    
    private func exportMatches(client: StarCraftClient, format: ExportFormat, to path: String) async throws {
        var allMatches: [Match] = []
        var filters: [String: QueryValue] = [:]

        // Apply filters
        if let since = since {
            filters["modified_at"] = .string(since)
        }
        
        // Fetch matches
        print("  Fetching matches...".gray)
        let matches = try await client.getMatches(MatchesRequest(
            endpoint: .all,
            page: 1,
            pageSize: limit,
            filters: filters
        ))
        
        allMatches = matches
        
        // Filter by player if specified
        if let playerFilter = player?.lowercased() {
            print("  Filtering by player: \(playerFilter)".gray)
            allMatches = allMatches.filter { match in
                match.opponents.contains { opponent in
                    opponent.opponent.name.lowercased().contains(playerFilter)
                }
            }
        }
        
        // Filter by tournament if specified
        if let tournamentFilter = tournament?.lowercased() {
            print("  Filtering by tournament: \(tournamentFilter)".gray)
            let tournaments = try await client.getTournaments(TournamentsRequest(pageSize: 100))
            let matchingTournamentIDs = tournaments
                .filter { $0.name.lowercased().contains(tournamentFilter) }
                .map { $0.id }
            
            allMatches = allMatches.filter { match in
                matchingTournamentIDs.contains(match.tournamentID)
            }
        }
        
        print("  Exporting \(allMatches.count) matches...".gray)
        
        switch format {
        case .json:
            try exportMatchesAsJSON(allMatches, to: path)
        case .csv:
            try exportMatchesAsCSV(allMatches, to: path)
        }
    }
    
    private func exportMatchesAsJSON(_ matches: [Match], to path: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        if verbose {
            // Export full match data
            let data = try encoder.encode(matches)
            try data.write(to: URL(fileURLWithPath: path))
        } else {
            // Export simplified match data
            let simplified = matches.map { match in
                SimplifiedMatch(
                    id: match.id,
                    name: match.name,
                    status: match.status.rawValue,
                    beginAt: match.beginAt,
                    opponents: match.opponents.map { $0.opponent.name },
                    winner: match.winner?.name,
                    scores: match.results.map { $0.score }
                )
            }
            let data = try encoder.encode(simplified)
            try data.write(to: URL(fileURLWithPath: path))
        }
    }
    
    private func exportMatchesAsCSV(_ matches: [Match], to path: String) throws {
        var csv = "ID,Name,Status,Date,Player1,Player2,Score1,Score2,Winner,Duration\n"
        
        for match in matches {
            let opponent1 = match.opponents[safe: 0]?.opponent.name ?? "TBD"
            let opponent2 = match.opponents[safe: 1]?.opponent.name ?? "TBD"
            let score1 = match.results[safe: 0]?.score ?? 0
            let score2 = match.results[safe: 1]?.score ?? 0
            let winner = match.winner?.name ?? ""
            let date = match.beginAt?.formattedString ?? ""
            let duration = match.duration?.formattedDuration ?? ""
            
            csv += "\(match.id),\"\(match.name)\",\(match.status.rawValue),\(date),\"\(opponent1)\",\"\(opponent2)\",\(score1),\(score2),\"\(winner)\",\(duration)\n"
        }
        
        try csv.write(toFile: path, atomically: true, encoding: .utf8)
    }
    
    private func exportPlayers(client: StarCraftClient, format: ExportFormat, to path: String) async throws {
        print("  Fetching players...".gray)
        let players = try await client.getPlayers(PlayersRequest(
            page: 1,
            pageSize: limit
        ))
        
        var filteredPlayers = players
        
        // Filter by name if specified
        if let playerFilter = player?.lowercased() {
            print("  Filtering by name: \(playerFilter)".gray)
            filteredPlayers = filteredPlayers.filter { player in
                player.name.lowercased().contains(playerFilter) ||
                player.fullName?.lowercased().contains(playerFilter) ?? false
            }
        }
        
        print("  Exporting \(filteredPlayers.count) players...".gray)
        
        switch format {
        case .json:
            try exportPlayersAsJSON(filteredPlayers, to: path)
        case .csv:
            try exportPlayersAsCSV(filteredPlayers, to: path)
        }
    }
    
    private func exportPlayersAsJSON(_ players: [Player], to path: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        if verbose {
            let data = try encoder.encode(players)
            try data.write(to: URL(fileURLWithPath: path))
        } else {
            let simplified = players.map { player in
                SimplifiedPlayer(
                    id: player.id,
                    name: player.name,
                    fullName: player.fullName,
                    nationality: player.nationality,
                    age: player.age,
                    team: player.currentTeam?.name
                )
            }
            let data = try encoder.encode(simplified)
            try data.write(to: URL(fileURLWithPath: path))
        }
    }
    
    private func exportPlayersAsCSV(_ players: [Player], to path: String) throws {
        var csv = "ID,Name,Full Name,Nationality,Age,Team\n"
        
        for player in players {
            let fullName = player.fullName ?? player.name
            let nationality = player.nationality ?? ""
            let age = player.age.map { String($0) } ?? ""
            let team = player.currentTeam?.name ?? ""
            
            csv += "\(player.id),\"\(player.name)\",\"\(fullName)\",\(nationality),\(age),\"\(team)\"\n"
        }
        
        try csv.write(toFile: path, atomically: true, encoding: .utf8)
    }
    
    private func exportTournaments(client: StarCraftClient, format: ExportFormat, to path: String) async throws {
        print("  Fetching tournaments...".gray)
        let tournaments = try await client.getTournaments(TournamentsRequest(
            page: 1,
            pageSize: limit
        ))
        
        var filteredTournaments = tournaments
        
        // Filter by name if specified
        if let tournamentFilter = tournament?.lowercased() {
            print("  Filtering by name: \(tournamentFilter)".gray)
            filteredTournaments = filteredTournaments.filter { tournament in
                tournament.name.lowercased().contains(tournamentFilter)
            }
        }
        
        print("  Exporting \(filteredTournaments.count) tournaments...".gray)
        
        switch format {
        case .json:
            try exportTournamentsAsJSON(filteredTournaments, to: path)
        case .csv:
            try exportTournamentsAsCSV(filteredTournaments, to: path)
        }
    }
    
    private func exportTournamentsAsJSON(_ tournaments: [Tournament], to path: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        if verbose {
            let data = try encoder.encode(tournaments)
            try data.write(to: URL(fileURLWithPath: path))
        } else {
            let simplified = tournaments.map { tournament in
                SimplifiedTournament(
                    id: tournament.id,
                    name: tournament.name,
                    tier: tournament.tier,
                    beginAt: tournament.beginAt,
                    endAt: tournament.endAt,
                    prizepool: tournament.prizepool,
                    teams: tournament.teamCount
                )
            }
            let data = try encoder.encode(simplified)
            try data.write(to: URL(fileURLWithPath: path))
        }
    }
    
    private func exportTournamentsAsCSV(_ tournaments: [Tournament], to path: String) throws {
        var csv = "ID,Name,Tier,Start Date,End Date,Prize Pool,Teams\n"
        
        for tournament in tournaments {
            let tier = tournament.tier ?? ""
            let startDate = tournament.beginAt?.formattedString ?? ""
            let endDate = tournament.endAt?.formattedString ?? ""
            let prizepool = tournament.prizepool ?? ""
            
            csv += "\(tournament.id),\"\(tournament.name)\",\(tier),\(startDate),\(endDate),\"\(prizepool)\",\(tournament.teamCount)\n"
        }
        
        try csv.write(toFile: path, atomically: true, encoding: .utf8)
    }
}

// MARK: - Export Format
enum ExportFormat: String {
    case json
    case csv
    
    var fileExtension: String {
        return rawValue
    }
}

// MARK: - Simplified Models for Export
struct SimplifiedMatch: Codable {
    let id: Int
    let name: String
    let status: String
    let beginAt: Date?
    let opponents: [String]
    let winner: String?
    let scores: [Int]
}

struct SimplifiedPlayer: Codable {
    let id: Int
    let name: String
    let fullName: String?
    let nationality: String?
    let age: Int?
    let team: String?
}

struct SimplifiedTournament: Codable {
    let id: Int
    let name: String
    let tier: String?
    let beginAt: Date?
    let endAt: Date?
    let prizepool: String?
    let teams: Int
}