import ArgumentParser
import Foundation
import StarCraftKit

private enum CLIRace {
    static func parse(_ s: String?) -> Race? {
        guard let s = s?.lowercased() else { return nil }
        switch s {
        case "t", "terran": return .terran
        case "p", "protoss": return .protoss
        case "z", "zerg": return .zerg
        case "r", "random": return .random
        default: return nil
        }
    }
    static func badge(_ race: Race?) -> String {
        switch race {
        case .terran: return "🔴 T"
        case .protoss: return "🔵 P"
        case .zerg: return "🟣 Z"
        case .random: return "⚪ R"
        case .unknown, .none: return "  ?"
        }
    }
}

private extension Double {
    var pct: String { String(format: "%.0f%%", self * 100) }
    var ratingStr: String { String(format: "%+.2f", self) }
}

// MARK: - profile (cross-source dossier)

struct ProfileCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "profile",
        abstract: "Unified player dossier across ladder, ratings, and the pro scene",
        discussion: "Works with no key (SC2 Pulse ladder). PANDA_TOKEN adds the pro profile; ALIGULAC_TOKEN adds ratings."
    )

    @Argument(help: "Player name or tag, e.g. Serral")
    var name: String

    func run() async throws {
        let sc = CLIContext.makeStarCraft()
        let p = try await sc.profile(of: name)

        print("\n👤 \(p.displayName)".bold() + "  \(CLIRace.badge(p.race))")
        if let country = p.country { print("   Country: \(CountryFlag.flag(for: country)) \(country)".gray) }
        if let region = p.region { print("   Region: \(region)".gray) }
        if let clan = p.clanTag { print("   Clan: [\(clan)]".gray) }

        if let mmr = p.mmr {
            let rank = p.ladderRank.map { " · rank #\($0)" } ?? ""
            print("\n   🪜 Ladder MMR: \(mmr.formattedString)\(rank)".cyan)
        }
        if let total = p.ladder?.totalGamesPlayed {
            print("   Games played: \(total.formattedString)".gray)
        }

        if let rating = p.rating {
            print("\n   ⭐ Aligulac rating: \((rating.rating ?? 0).ratingStr)".cyan)
            print("      vP \((rating.ratingVsProtoss ?? 0).ratingStr)  vT \((rating.ratingVsTerran ?? 0).ratingStr)  vZ \((rating.ratingVsZerg ?? 0).ratingStr)".gray)
        }

        if p.isPro {
            print("\n   🏆 Professional".bold())
            if let earnings = p.earnings { print("      Career earnings: $\(earnings.formattedString)".gray) }
            if let team = p.proPlayer?.currentTeam?.name { print("      Team: \(team)".gray) }
            if !p.upcomingProMatches.isEmpty {
                print("      Upcoming matches:".gray)
                for match in p.upcomingProMatches.prefix(5) {
                    let when = match.beginAt?.relativeTime ?? "TBD"
                    print("        • \(match.name) (\(when))".gray)
                }
            }
        }

        let sources = p.contributingSources.map(\.rawValue).joined(separator: ", ")
        print("\n   Sources: \(sources.isEmpty ? "none" : sources)".gray)
        print("   \(AligulacClient.attribution)".gray)
    }
}

// MARK: - ladder (free leaderboard)

struct LadderCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ladder",
        abstract: "Top ranked ladder leaderboard (free, via SC2 Pulse)",
        discussion: "No API key required."
    )

    @Option(name: .long, help: "Region: us, eu, kr, cn")
    var region: String?

    @Option(name: .long, help: "Race filter: terran, protoss, zerg, random")
    var race: String?

    @Option(name: .shortAndLong, help: "Number of players (max 100)")
    var limit: Int = 25

    func run() async throws {
        let sc = CLIContext.makeStarCraft()
        let regionEnum = region.flatMap { SC2Region(rawValue: $0.uppercased()) }
        let snapshot = try await sc.topLadder(
            region: regionEnum,
            race: CLIRace.parse(race),
            limit: min(100, max(1, limit))
        )

        let scope = regionEnum?.rawValue ?? "GLOBAL"
        print("\n🪜 GRANDMASTER LADDER — \(scope)".bold())
        for (index, team) in snapshot.teams.enumerated() {
            let rank = String(format: "%2d", index + 1)
            let name = (team.name ?? "?").padding(toLength: 16, withPad: " ", startingAt: 0)
            let mmr = (team.rating ?? 0).formattedString
            let wl = "\(team.wins ?? 0)-\(team.losses ?? 0)"
            let wr = team.winRate.map { " (\($0.pct))" } ?? ""
            let reg = team.region ?? ""
            print("\(rank.gray). \(CLIRace.badge(team.mainRace)) \(name) \(mmr.cyan)  \(wl.gray)\(wr.gray)  \(reg.gray)")
        }
        print("\nData from sc2pulse.nephest.com".gray)
    }
}

// MARK: - scene (what's on right now)

struct SceneCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scene",
        abstract: "Everything happening in StarCraft 2 right now: matches, streams, tournaments"
    )

    func run() async throws {
        let sc = CLIContext.makeStarCraft()
        let scene = try await sc.liveScene()

        print("\n📡 STARCRAFT 2 — LIVE NOW".bold())

        print("\n🔴 Pro matches: \(scene.liveMatches.count)".cyan)
        for match in scene.liveMatches.prefix(8) {
            print("   • \(match.name)".gray)
        }
        if scene.pandaScoreHint { print("   (set PANDA_TOKEN to see live pro matches)".gray) }

        print("\n🏆 Running tournaments: \(scene.runningTournaments.count)".cyan)
        for tournament in scene.runningTournaments.prefix(5) {
            print("   • \(tournament.name)".gray)
        }

        let streams = scene.liveStreams.sorted { ($0.stream.viewerCount ?? 0) > ($1.stream.viewerCount ?? 0) }
        print("\n📺 Community streams: \(streams.count) · \(scene.totalViewers.formattedString) viewers".cyan)
        for stream in streams.prefix(10) {
            let viewers = (stream.stream.viewerCount ?? 0).formattedString
            let who = stream.proPlayer?.proPlayer?.nickname ?? stream.stream.userName ?? "?"
            let title = TableFormatter.truncate(stream.stream.title ?? "", to: 48)
            print("   \(viewers.padding(toLength: 7, withPad: " ", startingAt: 0).brightGreen) \(who.padding(toLength: 14, withPad: " ", startingAt: 0)) \(title.gray)")
        }
        print("\nData from sc2pulse.nephest.com".gray)
    }
}

private extension LiveScene {
    var pandaScoreHint: Bool {
        liveMatches.isEmpty && ProcessInfo.processInfo.environment["PANDA_TOKEN"] == nil
    }
}

// MARK: - matchup (predictive preview)

struct MatchupCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "matchup",
        abstract: "Predictive preview of two players: MMR, prediction, head-to-head",
        discussion: "Ladder MMR is free. Prediction and head-to-head require ALIGULAC_TOKEN."
    )

    @Argument(help: "First player") var playerA: String
    @Argument(help: "Second player") var playerB: String
    @Option(name: .shortAndLong, help: "Best-of series length") var bestOf: Int = 5

    func run() async throws {
        let sc = CLIContext.makeStarCraft()
        let m = try await sc.matchup(playerA, vs: playerB, bestOf: bestOf)

        print("\n⚔️  \(m.playerA) vs \(m.playerB)  (Bo\(bestOf))".bold())

        if let a = m.ladderA?.mmr, let b = m.ladderB?.mmr {
            print("\n   Ladder MMR: \(a.formattedString) vs \(b.formattedString)".cyan)
            if let diff = m.mmrDifference {
                let leader = diff > 0 ? m.playerA : m.playerB
                print("   Edge: \(leader) by \(abs(diff).formattedString) MMR".gray)
            }
        }

        if let pred = m.prediction, let pa = pred.probabilityA, let pb = pred.probabilityB {
            print("\n   🔮 Win probability:".bold())
            print("      \(m.playerA): \(pa.pct)".cyan)
            print("      \(m.playerB): \(pb.pct)".cyan)
            if let favorite = m.favorite { print("      Favorite: \(favorite.green)") }
        } else {
            print("\n   🔮 Prediction unavailable (set ALIGULAC_TOKEN)".gray)
        }

        if let h2h = m.headToHead {
            print("\n   ⚔️  Head-to-head: \(h2h.winsA)-\(h2h.winsB)".cyan)
        }
        print("\n   \(AligulacClient.attribution)".gray)
    }
}

// MARK: - seasons / patches

struct SeasonsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "seasons",
        abstract: "Current and recent ranked ladder seasons (free)"
    )

    func run() async throws {
        let sc = CLIContext.makeStarCraft()
        let seasons = try await sc.seasons()
        print("\n📅 LADDER SEASONS".bold())
        for season in seasons.prefix(12) {
            let label = "\(season.year ?? 0) S\(season.number ?? 0)"
            let region = season.region ?? ""
            let window = [season.start, season.end].compactMap { $0?.prefix(10) }.joined(separator: " → ")
            print("   \(label.padding(toLength: 9, withPad: " ", startingAt: 0).cyan) \(region.padding(toLength: 4, withPad: " ", startingAt: 0)) \(window.gray)")
        }
        print("\nData from sc2pulse.nephest.com".gray)
    }
}

struct PatchesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "patches",
        abstract: "Recent StarCraft 2 game patches (free)"
    )

    func run() async throws {
        let sc = CLIContext.makeStarCraft()
        let patches = try await sc.patches()
        print("\n🩹 GAME PATCHES".bold())
        for patch in patches.prefix(15) {
            let version = patch.version ?? "?"
            let build = patch.build.map { "build \($0)" } ?? ""
            print("   \(version.cyan)  \(build.gray)")
        }
        print("\nData from sc2pulse.nephest.com".gray)
    }
}

// MARK: - community streams

struct CommunityStreamsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "streams",
        abstract: "Live StarCraft 2 community streams by viewers (free, via SC2 Pulse)"
    )

    @Option(name: .shortAndLong, help: "Number of streams to show") var limit: Int = 25

    func run() async throws {
        let sc = CLIContext.makeStarCraft()
        let streams = try await sc.liveStreams(limit: min(100, max(1, limit)))
            .sorted { ($0.stream.viewerCount ?? 0) > ($1.stream.viewerCount ?? 0) }

        print("\n📺 LIVE COMMUNITY STREAMS".bold())
        for stream in streams {
            let viewers = (stream.stream.viewerCount ?? 0).formattedString
            let who = stream.proPlayer?.proPlayer?.nickname ?? stream.stream.userName ?? "?"
            let title = TableFormatter.truncate(stream.stream.title ?? "", to: 50)
            print("   \(viewers.padding(toLength: 7, withPad: " ", startingAt: 0).brightGreen) \(who.padding(toLength: 16, withPad: " ", startingAt: 0)) \(title.gray)")
            if let url = stream.stream.url { print("           \(url)".gray) }
        }
        print("\nData from sc2pulse.nephest.com".gray)
    }
}
