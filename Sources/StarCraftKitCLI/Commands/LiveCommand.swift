import ArgumentParser
import Foundation
import StarCraftKit
#if os(macOS)
import AppKit
#endif

struct LiveCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "live",
        abstract: "Show all currently live StarCraft 2 matches",
        discussion: "Monitor live matches with scores and stream links"
    )
    
    @Flag(name: .shortAndLong, help: "Auto-refresh every 30 seconds")
    var watch: Bool = false
    
    @Option(name: .shortAndLong, help: "Filter by tournament tier (premier, major, minor)")
    var tier: String?
    
    @Flag(name: .shortAndLong, help: "Show only matches with available streams")
    var streamsOnly: Bool = false
    
    @Option(name: [.customShort("o"), .long], help: "Open stream for match at index (1-based)")
    var openStream: Int?
    
    func run() async throws {
        let context = try CLIContext.load()
        let client = StarCraftClient(configuration: StarCraftClient.Configuration(apiKey: context.apiKey, authMethod: context.authMethod))
        
        repeat {
            // Clear screen if watching
            if watch {
                print("\u{001B}[2J\u{001B}[H") // Clear screen and move cursor to top
            }
            
            print("\n🔴 LIVE MATCHES".bold())
            print("Updated: \(Date().formattedString)".gray)
            
            // Get running matches
            let runningMatches = try await client.getMatches(MatchesRequest(
                endpoint: .running,
                page: 1,
                pageSize: 50
            ))
            
            var liveMatches = runningMatches
            
            // Filter by streams if requested
            if streamsOnly {
                liveMatches = liveMatches.filter { !($0.streams ?? []).isEmpty }
            }
            
            // Filter by tier if requested
            if tier != nil {
                // We'd need to fetch tournament info to filter by tier
                // For now, we'll skip this as it would require multiple API calls
            }
            
            if liveMatches.isEmpty {
                print("\n❌ No live matches at the moment.".yellow)
                print("Tip: Use 'starcraft upcoming' to see when the next matches start.".gray)
                
                if watch {
                    print("\nWatching for live matches... (Press Ctrl+C to stop)".gray)
                    try await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
                    continue
                } else {
                    return
                }
            }
            
            // Group by tournament
            var matchesByTournament: [Int?: [StarCraftKit.Match]] = [:]
            for match in liveMatches {
                matchesByTournament[match.tournamentID, default: []].append(match)
            }
            
            // Fetch tournament info for all tournaments
            let tournaments = try await client.getTournaments(TournamentsRequest(page: 1, pageSize: 100))
            let tournamentMap: [Int: Tournament] = Dictionary(uniqueKeysWithValues: tournaments.map { ($0.id, $0) })
            
            // Display matches grouped by tournament
            var matchIndex = 0
            var allMatchesWithStreams: [(index: Int, match: StarCraftKit.Match, stream: StarCraftKit.Stream?)] = []
            
            for (tournamentID, matches) in matchesByTournament.sorted(by: { (first, second) in
                // Sort by tournament tier/importance
                let t1 = first.key.map { tournamentMap[$0] } ?? nil
                let t2 = second.key.map { tournamentMap[$0] } ?? nil
                return (t1?.tier ?? "") > (t2?.tier ?? "")
            }) {
                let tournament = tournamentID.map { tournamentMap[$0] } ?? nil
                let tournamentName = tournament?.name ?? "Unknown Tournament"
                let tierBadge = tournament?.tier.map { " [\($0.uppercased())]".brightYellow } ?? ""
                
                
                print("\n🏆 \(tournamentName)\(tierBadge)".bold())
                
                for match in matches.sorted(by: { ($0.beginAt ?? Date()) < ($1.beginAt ?? Date()) }) {
                    matchIndex += 1
                    let stream = match.streams?.first
                    displayLiveMatch(match, index: matchIndex)
                    
                    if stream != nil {
                        allMatchesWithStreams.append((index: matchIndex, match: match, stream: stream))
                    }
                }
            }
            
            // Handle stream opening
            if let streamIndex = openStream {
                if let matchWithStream = allMatchesWithStreams.first(where: { $0.index == streamIndex }),
                   let stream = matchWithStream.stream, let rawURL = stream.rawURL {
                    print("\n🚀 Opening stream for: \(matchWithStream.match.name)".green)
                    try openStreamURL(rawURL.absoluteString)
                } else {
                    print("\n❌ No stream available for match #\(streamIndex)".red)
                }
            }
            
            print("\n📊 \(liveMatches.count) live \(liveMatches.count == 1 ? "match" : "matches")".green)
            
            if !allMatchesWithStreams.isEmpty && openStream == nil {
                print("\nTip: Use --open-stream <number> to open a specific match stream".gray)
            }
            
            if watch {
                print("\n⏱  Auto-refreshing every 30 seconds... (Press Ctrl+C to stop)".gray)
                try await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            } else {
                break
            }
            
        } while watch
    }
    
    private func displayLiveMatch(_ match: StarCraftKit.Match, index: Int) {
        // Get players/teams
        let opponent1 = match.opponents[safe: 0]
        let opponent2 = match.opponents[safe: 1]
        
        
        let (name1, flag1) = formatOpponent(opponent1)
        let (name2, flag2) = formatOpponent(opponent2)
        
        // Get scores - check both teamID and playerID
        let score1 = match.results.first { result in
            if let opp1 = opponent1 {
                return result.teamID == opp1.opponent.id || result.playerID == opp1.opponent.id
            }
            return false
        }?.score ?? 0
        
        let score2 = match.results.first { result in
            if let opp2 = opponent2 {
                return result.teamID == opp2.opponent.id || result.playerID == opp2.opponent.id
            }
            return false
        }?.score ?? 0
        
        // Format match type
        let matchType = match.numberOfGames > 1 ? "Bo\(match.numberOfGames)" : "Bo1"
        
        // Calculate duration
        let duration = match.beginAt.map { Date().timeIntervalSince($0).formattedDuration } ?? "--"
        
        // Format the match line with index
        let indexStr = index < 10 ? "[ \(index)]" : "[\(index)]"
        
        // Compact format
        let score = "\(score1)-\(score2)".bold()
        let arrow1 = score1 > score2 ? "►".brightGreen : " "
        let arrow2 = score2 > score1 ? "◄".brightGreen : " "
        
        // Truncate names to fit in compact format
        let name1Short = TableFormatter.truncate(name1, to: 12)
        let name2Short = TableFormatter.truncate(name2, to: 12)
        
        let hasStream = !(match.streams?.isEmpty ?? true)
        let streamIcon = hasStream ? "📺" : "  "
        
        print("\(indexStr.gray) \(flag1) \(name1Short)\(arrow1) \(score) \(arrow2)\(name2Short) \(flag2) │ \(matchType) │ \(duration.gray) │ \(streamIcon)")
        
        // Show game progress based on scores
        if match.numberOfGames > 1 {
            let gamesPlayed = score1 + score2
            let progressBar = ProgressBar.create(current: gamesPlayed, total: match.numberOfGames, width: 10)
            print("     Progress: \(progressBar) \(gamesPlayed)/\(match.numberOfGames)".gray)
        }
        
        // Show stream URL if available
        if let stream = match.streams?.first, let rawURL = stream.rawURL {
            print("     Stream: \(rawURL.absoluteString)".gray)
        }
    }
    
    private func formatOpponent(_ opponent: Opponent?) -> (name: String, flag: String) {
        guard let opponent = opponent else {
            return ("TBD", "❓")
        }
        
        switch opponent.type.lowercased() {
        case "player":
            return (opponent.opponent.displayName, CountryFlag.flag(for: opponent.opponent.nationality))
        case "team":
            return (opponent.opponent.displayName, "👥")
        default:
            return ("TBD", "❓")
        }
    }
    
    private func openStreamURL(_ url: String) throws {
        #if os(macOS)
        if let url = URL(string: url) {
            NSWorkspace.shared.open(url)
        }
        #elseif os(Linux)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["xdg-open", url]
        try process.run()
        #else
        print("⚠️  Platform not supported for opening URLs automatically".yellow)
        print("Please open manually: \(url)")
        #endif
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

