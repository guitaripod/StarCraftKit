import ArgumentParser
import Foundation
import StarCraftKit
#if os(macOS)
import AppKit
#endif

struct StreamCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stream",
        abstract: "Open Twitch/YouTube streams for live matches",
        discussion: """
        Find and open streams for matches that are currently live or upcoming.
        
        Examples:
          starcraft stream                    # List all available streams
          starcraft stream --open             # Open the first available stream
          starcraft stream --match 123456     # Open stream for specific match
          starcraft stream --player Serral    # Find streams for matches with player
          starcraft stream --tournament GSL   # Find streams for tournament matches
        """
    )
    
    @Option(name: .shortAndLong, help: "Specific match ID to open stream for")
    var match: Int?
    
    @Option(name: .shortAndLong, help: "Filter by player name")
    var player: String?
    
    @Option(name: .shortAndLong, help: "Filter by tournament name")
    var tournament: String?
    
    @Flag(name: .shortAndLong, help: "Open the stream in default browser")
    var open: Bool = false
    
    @Flag(name: .shortAndLong, help: "Show all streams including non-official")
    var all: Bool = false
    
    @Option(name: .shortAndLong, help: "Preferred language for streams (e.g., en, kr)")
    var language: String?
    
    func run() async throws {
        let context = try CLIContext.load()
        let client = StarCraftClient(configuration: StarCraftClient.Configuration(apiKey: context.apiKey, authMethod: context.authMethod))
        
        if let matchID = match {
            // Get specific match
            try await handleSpecificMatch(matchID, client: client)
        } else {
            // Find matches with streams
            try await findStreamsForMatches(client: client)
        }
    }
    
    private func handleSpecificMatch(_ matchID: Int, client: StarCraftClient) async throws {
        print("🔍 Looking for streams for match \(matchID)...".gray)

        let match: Match
        do {
            match = try await client.getMatch(id: matchID)
        } catch {
            print("❌ Match not found".red)
            return
        }

        guard let streams = match.streams, !streams.isEmpty else {
            print("❌ No streams available for this match".red)
            return
        }
        
        displayMatchWithStreams(match, streams: streams)
        
        if open {
            try openStream(streams.first { $0.main } ?? streams.first!)
        }
    }
    
    private func findStreamsForMatches(client: StarCraftClient) async throws {
        print("🔍 Finding matches with streams...".gray)
        
        // Get live matches
        let liveMatches = try await client.getMatches(MatchesRequest(
            endpoint: .running,
            pageSize: 50
        ))
        
        // Get upcoming matches (next 2 hours)
        let upcomingMatches = try await client.getMatches(MatchesRequest(
            endpoint: .upcoming,
            pageSize: 50
        ))
        
        var matchesWithStreams: [(match: Match, streams: [StarCraftKit.Stream])] = []
        
        // Check live matches
        for match in liveMatches {
            if let streams = match.streams, !streams.isEmpty {
                matchesWithStreams.append((match, streams))
            }
        }
        
        // Check upcoming matches that might have streams scheduled
        for match in upcomingMatches {
            if let streams = match.streams, !streams.isEmpty {
                if let beginAt = match.beginAt, beginAt.timeIntervalSinceNow < 7200 { // 2 hours
                    matchesWithStreams.append((match, streams))
                }
            }
        }
        
        // Apply filters
        if let playerFilter = player?.lowercased() {
            matchesWithStreams = matchesWithStreams.filter { item in
                item.match.opponents.contains { opponent in
                    opponent.opponent.name.lowercased().contains(playerFilter)
                }
            }
        }
        
        if let tournamentFilter = tournament?.lowercased() {
            let tournaments = try await client.getTournaments(TournamentsRequest(pageSize: 100))
            let matchingTournamentIDs = tournaments
                .filter { $0.name.lowercased().contains(tournamentFilter) }
                .map { $0.id }
            
            matchesWithStreams = matchesWithStreams.filter { item in
                matchingTournamentIDs.contains(item.match.tournamentID)
            }
        }
        
        if matchesWithStreams.isEmpty {
            print("❌ No matches with streams found".red)
            print("\nTip: Try checking back when matches are live!".gray)
            return
        }
        
        // Display results
        print("\n📺 Matches with Streams".bold())
        
        for (index, (match, streams)) in matchesWithStreams.enumerated() {
            print()
            displayMatchWithStreams(match, streams: streams)
            
            if open && index == 0 {
                // Open the first stream
                if let stream = streams.first(where: { $0.main }) ?? streams.first {
                    try openStream(stream)
                }
            }
        }
        
        if !open && !matchesWithStreams.isEmpty {
            print("\nTip: Use --open to automatically open the first stream".gray)
        }
    }
    
    private func displayMatchWithStreams(_ match: Match, streams: [StarCraftKit.Stream]) {
        // Match header
        let status = match.isLive ? "● LIVE".brightGreen : "◯ Upcoming".yellow
        print("\(status) \(match.name)")
        
        // Players/Teams
        if match.opponents.count >= 2 {
            let p1 = match.opponents[0].opponent
            let p2 = match.opponents[1].opponent
            print("  \(CountryFlag.flag(for: p1.nationality)) \(p1.name) vs \(CountryFlag.flag(for: p2.nationality)) \(p2.name)")
        }
        
        // Time info
        if let beginAt = match.beginAt {
            if match.isLive {
                print("  Started: \(beginAt.relativeTime)".gray)
            } else {
                print("  Starts: \(beginAt.relativeTime) (\(beginAt.timeOnly) \(beginAt.dateOnly))".gray)
            }
        }
        
        // Streams
        print("  Streams:".cyan)
        let displayStreams = all ? streams : streams.filter { $0.official || $0.main }
        
        for stream in displayStreams {
            let officialBadge = stream.official ? " [Official]".brightGreen : ""
            let mainBadge = stream.main ? " [Main]".brightYellow : ""
            let languageInfo = " (\(stream.language.uppercased()))"
            
            // Check if it's filtered by language
            if let preferredLang = language, !stream.language.lowercased().contains(preferredLang.lowercased()) {
                continue
            }
            
            let streamURL = stream.rawURL?.absoluteString ?? ""
            let platform = detectPlatform(from: streamURL)
            print("    \(platform)\(languageInfo)\(officialBadge)\(mainBadge)")
            print("    \(streamURL)".gray)
        }
    }
    
    private func detectPlatform(from url: String) -> String {
        if url.contains("twitch.tv") {
            return "📺 Twitch".brightMagenta
        } else if url.contains("youtube.com") || url.contains("youtu.be") {
            return "📺 YouTube".brightRed
        } else if url.contains("afreecatv.com") {
            return "📺 AfreecaTV".brightBlue
        } else {
            return "📺 Stream".cyan
        }
    }
    
    private func openStream(_ stream: StarCraftKit.Stream) throws {
        guard let url = stream.rawURL?.absoluteString else {
            print("\n❌ No stream URL available".red)
            return
        }
        print("\n🚀 Opening stream: \(url)".green)
        
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