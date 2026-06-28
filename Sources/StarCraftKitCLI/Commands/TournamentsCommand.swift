import ArgumentParser
import Foundation
import StarCraftKit

struct TournamentsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tournaments",
        abstract: "Fetch and display StarCraft 2 tournaments"
    )
    
    @Option(name: .shortAndLong, help: "Page number")
    var page: Int = 1
    
    @Option(name: .shortAndLong, help: "Items per page")
    var size: Int = 10
    
    @Option(name: .long, help: "Tournament type: all, past, running, upcoming")
    var type: String = "all"
    
    @Option(name: .long, help: "Filter by series ID")
    var serieID: Int?
    
    @Option(name: .long, help: "Filter by league ID")
    var leagueID: Int?
    
    @Option(name: .long, help: "Filter by tier")
    var tier: String?
    
    @Flag(name: .long, help: "Show only tournaments with prize pools")
    var prizePools = false
    
    mutating func run() async throws {
        let config = try StarCraftClient.Configuration.fromEnvironment()
        let client = StarCraftClient(configuration: config)
        
        let endpoint: TournamentEndpoint
        switch type.lowercased() {
        case "past":
            endpoint = .past
            print("🏁 Fetching past tournaments...")
        case "running":
            endpoint = .running
            print("🔴 Fetching running tournaments...")
        case "upcoming":
            endpoint = .upcoming
            print("📅 Fetching upcoming tournaments...")
        default:
            endpoint = .all
            print("🎮 Fetching all tournaments...")
        }
        
        do {
            let request: TournamentsRequest
            
            if prizePools {
                request = .withPrizePools(page: page, pageSize: size)
            } else {
                request = TournamentsRequest(
                    endpoint: endpoint,
                    page: page,
                    pageSize: size,
                    serieID: serieID,
                    leagueID: leagueID,
                    tier: tier
                )
            }
            
            let tournaments = try await client.getTournaments(request)
            
            if tournaments.isEmpty {
                print("\n📭 No tournaments found")
                return
            }
            
            print("\n📋 Found \(tournaments.count) tournaments:\n")
            
            for (index, tournament) in tournaments.enumerated() {
                print("[\(index + 1)] \(tournament.formatForOutput())")
                
                if let tier = tournament.tier {
                    print("   Tier: \(tier)")
                }
                
                if tournament.liveSupported == true {
                    print("   📡 Live Data Supported")
                }

                if tournament.hasBracket == true {
                    print("   🏆 Has Bracket")
                }
                
                if tournament.isRunning {
                    print("   🔴 Currently Running")
                } else if tournament.hasEnded {
                    print("   ✅ Completed")
                } else if tournament.isPending {
                    print("   ⏳ Upcoming")
                }
                
                print(String(repeating: "-", count: 50))
            }
            
            let prizePools = tournaments.compactMap { $0.prizepoolAmount }
            if !prizePools.isEmpty {
                let total = prizePools.reduce(0, +)
                print("\n💰 Total prize pool: $\(Int(total).formattedString)")
            }
            
        } catch {
            print("❌ Error: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}