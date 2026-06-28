import ArgumentParser
import Foundation
import StarCraftKit

// Date formatting moved to UIEnhancements.swift

extension Int {
    var formattedString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

/// The main command-line interface for StarCraftKit.
///
/// `StarCraftCLI` provides comprehensive access to StarCraft II esports data through
/// an intuitive command-line interface. It supports tracking live matches, exploring
/// player statistics, browsing tournaments, and much more.
///
/// ## Setup
///
/// Set your PandaScore API token before using:
/// ```bash
/// export PANDA_TOKEN="your-api-token"
/// ```
///
/// ## Basic Usage
///
/// ```bash
/// # View live matches
/// starcraft live
///
/// # Search for a player
/// starcraft search player Serral
///
/// # Check today's matches
/// starcraft today
///
/// # Get help
/// starcraft --help
/// ```
///
/// ## Available Commands
///
/// The CLI is organized into logical command groups:
///
/// ### Live Tracking
/// - `live`: Currently running matches
/// - `today`: Today's match schedule
/// - `upcoming`: Future matches
///
/// ### Player Information
/// - `players`: List all players
/// - `player-schedule`: Specific player's matches
/// - `player-matches`: Player's match history
///
/// ### Tournament Data
/// - `tournaments`: Browse tournaments
/// - `tournament-matches`: Tournament brackets
/// - `series`: Tournament series
///
/// ### Search & Export
/// - `search`: Universal search
/// - `export`: Export data to JSON/CSV
///
/// ## Topics
///
/// ### Subcommands
/// - ``LiveCommand``
/// - ``TodayCommand``
/// - ``UpcomingCommand``
/// - ``PlayersCommand``
/// - ``PlayerScheduleCommand``
/// - ``SearchCommand``
@main
struct StarCraftCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "starcraft",
        abstract: "🎮 StarCraft 2 Pro Scene CLI - Track players, matches, and tournaments",
        discussion: """
        A powerful command-line tool for accessing StarCraft 2 esports data.
        
        GETTING STARTED:
          1. Set your API key: export PANDA_TOKEN="your-api-key"
          2. Check live matches: starcraft live
          3. Find a player: starcraft search "Serral"
          4. Track a player: starcraft player-schedule "Serral"
        
        COMMON WORKFLOWS:
          • View today's matches: starcraft today
          • Check upcoming matches: starcraft upcoming
          • Find when a player plays next: starcraft player-schedule <name>
          • View tournament bracket: starcraft tournament-matches <name>
          • Search for anything: starcraft search <query>
        
        TIPS:
          • Use --help with any command for more options
          • Many commands support filtering and detailed views
          • Live command supports auto-refresh with --watch
        """,
        version: "2.0.0",
        subcommands: [
            // Live tracking
            LiveCommand.self,
            TodayCommand.self,
            UpcomingCommand.self,
            
            // Player commands
            PlayerScheduleCommand.self,
            PlayerMatchesCommand.self,
            PlayersCommand.self,
            
            // Tournament commands
            TournamentMatchesCommand.self,
            TournamentsCommand.self,
            
            // Unified — aggregated across all sources
            ProfileCommand.self,
            SceneCommand.self,
            LadderCommand.self,
            MatchupCommand.self,
            CommunityStreamsCommand.self,
            SeasonsCommand.self,
            PatchesCommand.self,

            // Search
            SearchCommand.self,

            // Ratings & predictions (Aligulac)
            RatingCommand.self,
            RatingsCommand.self,
            HeadToHeadCommand.self,
            PredictCommand.self,

            // Core entities
            MatchesCommand.self,
            TeamsCommand.self,
            SeriesCommand.self,
            LeaguesCommand.self,

            // Export & Streaming
            ExportCommand.self,
            StreamCommand.self,

            // Utilities
            CacheCommand.self,
            TestCommand.self,
            DebugCommand.self
        ],
        defaultSubcommand: nil
    )
    
    func run() throws {
        print(Self.helpMessage())
    }
}

// MARK: - Configuration
extension StarCraftClient.Configuration {
    static func fromEnvironment() throws -> Self {
        let context = try CLIContext.load()
        return StarCraftClient.Configuration(apiKey: context.apiKey, authMethod: context.authMethod)
    }
}

// MARK: - Output Formatting
protocol OutputFormattable {
    func formatForOutput() -> String
}

extension League: OutputFormattable {
    func formatForOutput() -> String {
        """
        League: \(name)
        ID: \(id)
        Slug: \(slug)
        Modified: \(modifiedAt?.formattedString ?? "—")
        """
    }
}

extension Match: OutputFormattable {
    func formatForOutput() -> String {
        """
        Match: \(name)
        Status: \(status.rawValue)
        Begin: \(beginAt?.formattedString ?? "TBD")
        Tournament: \(tournamentID)
        """
    }
}

extension Player: OutputFormattable {
    func formatForOutput() -> String {
        """
        Player: \(displayName)
        Nationality: \(nationality ?? "Unknown")
        Team: \(currentTeam?.name ?? "None")
        Role: \(role ?? "Unknown")
        """
    }
}

extension Team: OutputFormattable {
    func formatForOutput() -> String {
        """
        Team: \(displayName)
        Location: \(location ?? "Unknown")
        Players: \(rosterSize)
        """
    }
}

extension Series: OutputFormattable {
    func formatForOutput() -> String {
        """
        Series: \(fullName)
        Year: \(year ?? 0)
        Begin: \(beginAt?.formattedString ?? "TBD")
        Tournaments: \(tournamentCount)
        """
    }
}

extension Tournament: OutputFormattable {
    func formatForOutput() -> String {
        """
        Tournament: \(name)
        Prize Pool: \(prizepool ?? "None")
        Begin: \(beginAt?.formattedString ?? "TBD")
        Teams: \(teamCount)
        """
    }
}