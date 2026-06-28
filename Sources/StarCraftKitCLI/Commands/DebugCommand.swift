import ArgumentParser
import Foundation
import StarCraftKit

struct DebugCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "debug",
        abstract: "Debug API responses",
        discussion: "Shows raw API data for debugging"
    )
    
    @Option(name: .shortAndLong, help: "Entity type to debug")
    var type: String = "match"
    
    func run() async throws {
        let context = try CLIContext.load()
        let client = StarCraftClient(configuration: StarCraftClient.Configuration(apiKey: context.apiKey, authMethod: context.authMethod))
        
        switch type {
        case "match":
            let matches = try await client.getMatches(MatchesRequest(
                endpoint: .past,
                page: 1,
                pageSize: 1
            ))
            
            if let match = matches.first {
                print("Match ID: \(match.id)")
                print("Name: \(match.name)")
                print("Status: \(match.status.rawValue)")
                print("Best of: \(match.numberOfGames)")
                if let matchType = match.matchType { print("Match type: \(matchType)") }
                if let league = match.league { print("League: \(league.name)") }
                if let serie = match.serie { print("Serie: \(serie.fullName)") }
                if let tournament = match.tournament { print("Tournament: \(tournament.name)") }
                if let videogame = match.videogame { print("Videogame: \(videogame.name)") }
                if let forfeit = match.forfeit { print("Forfeit: \(forfeit)") }
                if let detailedStats = match.detailedStats { print("Detailed stats: \(detailedStats)") }
                print("Opponents count: \(match.opponents.count)")
                
                for (index, opponent) in match.opponents.enumerated() {
                    print("\nOpponent \(index + 1):")
                    print("  Type: \(opponent.type)")
                    print("  ID: \(opponent.opponent.id)")
                    print("  Name: \(opponent.opponent.name)")
                    print("  Slug: \(opponent.opponent.slug ?? "—")")
                    
                    if let nationality = opponent.opponent.nationality {
                        print("  Nationality: \(nationality)")
                    }
                    if let firstName = opponent.opponent.firstName {
                        print("  First Name: \(firstName)")
                    }
                    if let lastName = opponent.opponent.lastName {
                        print("  Last Name: \(lastName)")
                    }
                }
                
                print("\nResults:")
                for result in match.results {
                    print("  Score: \(result.score)")
                    print("  Team ID: \(result.teamID ?? -1)")
                    print("  Player ID: \(result.playerID ?? -1)")
                }
                
                print("\nWinner:")
                if let winner = match.winner {
                    print("  ID: \(winner.id)")
                    print("  Type: \(winner.type ?? "nil")")
                    print("  Name: \(winner.name ?? "nil")")
                } else {
                    print("  No winner")
                }
            } else {
                print("No matches found")
            }
            
        case "player":
            let players = try await client.getPlayers(PlayersRequest(
                page: 1,
                pageSize: 5
            ))
            
            for player in players {
                print("\nPlayer:")
                print("  ID: \(player.id)")
                print("  Name: \(player.name)")
                print("  Display Name: \(player.displayName)")
                print("  First Name: \(player.firstName ?? "nil")")
                print("  Last Name: \(player.lastName ?? "nil")")
            }
            
        default:
            print("Unknown type: \(type)")
        }
    }
}