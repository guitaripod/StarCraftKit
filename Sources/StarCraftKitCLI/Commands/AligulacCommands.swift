import ArgumentParser
import Foundation
import StarCraftKit

// MARK: - Shared helpers

private enum AligulacResolver {
    /// Resolve a player tag to a single Aligulac player (prefers an exact, case-insensitive tag match).
    static func resolve(_ tag: String, using client: AligulacClient) async throws -> AligulacPlayer {
        let candidates = try await client.searchPlayers(tag: tag, limit: 25)
        guard !candidates.isEmpty else {
            throw CLIError.notFound("No Aligulac player matching \"\(tag)\"")
        }
        if let exact = candidates.first(where: { ($0.tag ?? "").caseInsensitiveCompare(tag) == .orderedSame }) {
            return exact
        }
        return candidates[0]
    }

    static func raceBadge(_ race: Race?) -> String {
        switch race {
        case .protoss: return "🔵 P"
        case .terran: return "🔴 T"
        case .zerg: return "🟣 Z"
        case .random: return "⚪ R"
        case .unknown, .none: return "❔"
        }
    }
}

private extension Double {
    var ratingString: String { String(format: "%+.2f", self) }
    var percentString: String { String(format: "%.0f%%", self * 100) }
}

// MARK: - rating

struct RatingCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rating",
        abstract: "Show a player's Aligulac skill rating (overall + race matchups)",
        discussion: "Requires ALIGULAC_TOKEN. \(AligulacClient.attribution)."
    )

    @Argument(help: "Player tag, e.g. Serral")
    var player: String

    func run() async throws {
        let aligulac = try CLIContext.load().makeAligulacClient()
        let resolved = try await AligulacResolver.resolve(player, using: aligulac)

        let header = "\(AligulacResolver.raceBadge(resolved.race)) \(resolved.tag ?? player)"
        print("\n⭐ \(header)".bold())
        if let name = resolved.name { print("   \(name)".gray) }
        if let country = resolved.country { print("   Country: \(country)".gray) }

        guard let rating = try await aligulac.rating(playerID: resolved.id) else {
            print("\n   No rating data available.".yellow)
            print("\n\(AligulacClient.attribution)".gray)
            return
        }

        print("\n   Rating:    \((rating.rating ?? 0).ratingString)".cyan)
        print("   vs Protoss: \((rating.ratingVsProtoss ?? 0).ratingString)")
        print("   vs Terran:  \((rating.ratingVsTerran ?? 0).ratingString)")
        print("   vs Zerg:    \((rating.ratingVsZerg ?? 0).ratingString)")
        if let dev = rating.dev { print("   Uncertainty: ±\(String(format: "%.2f", dev))".gray) }
        print("   Status: \(rating.isActive ? "active".green : "inactive".yellow)")
        print("\n\(AligulacClient.attribution)".gray)
    }
}

// MARK: - ratings (leaderboard)

struct RatingsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ratings",
        abstract: "Show the current Aligulac top-rated active players",
        discussion: "Requires ALIGULAC_TOKEN. \(AligulacClient.attribution)."
    )

    @Option(name: .shortAndLong, help: "Number of players to show (max 25)")
    var limit: Int = 15

    func run() async throws {
        let aligulac = try CLIContext.load().makeAligulacClient()
        let bounded = min(25, max(1, limit))
        let ratings = try await aligulac.topRatings(limit: bounded)

        print("\n🏅 TOP \(bounded) ACTIVE PLAYERS".bold())

        let players = try await resolvePlayers(for: ratings, using: aligulac)
        for (index, rating) in ratings.enumerated() {
            let id = AligulacClient.resourceID(rating.player)
            let player = id.flatMap { players[$0] }
            let badge = AligulacResolver.raceBadge(player?.race)
            let tag = player?.tag ?? "player \(id.map(String.init) ?? "?")"
            let rank = String(format: "%2d", index + 1)
            print("\(rank.gray). \(badge) \(tag.padding(toLength: 16, withPad: " ", startingAt: 0)) \((rating.rating ?? 0).ratingString.cyan)")
        }
        print("\n\(AligulacClient.attribution)".gray)
    }

    private func resolvePlayers(for ratings: [AligulacRating], using client: AligulacClient) async throws -> [Int: AligulacPlayer] {
        let ids = Set(ratings.compactMap { AligulacClient.resourceID($0.player) })
        return try await withThrowingTaskGroup(of: AligulacPlayer?.self) { group in
            for id in ids {
                group.addTask { try? await client.player(id: id) }
            }
            var result: [Int: AligulacPlayer] = [:]
            for try await player in group {
                if let player { result[player.id] = player }
            }
            return result
        }
    }
}

// MARK: - head-to-head

struct HeadToHeadCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "head-to-head",
        abstract: "Show the all-time head-to-head record between two players",
        discussion: "Requires ALIGULAC_TOKEN. \(AligulacClient.attribution)."
    )

    @Argument(help: "First player tag")
    var playerA: String

    @Argument(help: "Second player tag")
    var playerB: String

    func run() async throws {
        let aligulac = try CLIContext.load().makeAligulacClient()
        async let a = AligulacResolver.resolve(playerA, using: aligulac)
        async let b = AligulacResolver.resolve(playerB, using: aligulac)
        let (pa, pb) = try await (a, b)

        let h2h = try await aligulac.headToHead(playerA: pa.id, playerB: pb.id)

        let tagA = pa.tag ?? playerA
        let tagB = pb.tag ?? playerB
        print("\n⚔️  \(tagA) vs \(tagB)".bold())
        print("   \(h2h.winsA) - \(h2h.winsB)".cyan)
        if let rate = h2h.winRateA {
            print("   \(tagA) wins \(rate.percentString) of meetings".gray)
        } else {
            print("   No recorded matches.".yellow)
        }

        let recent = h2h.matches.prefix(8)
        if !recent.isEmpty {
            print("\n   Recent matches:".bold())
            for match in recent {
                let firstIsA = AligulacClient.resourceID(match.playerA) == pa.id
                let leftScore = firstIsA ? (match.scoreA ?? 0) : (match.scoreB ?? 0)
                let rightScore = firstIsA ? (match.scoreB ?? 0) : (match.scoreA ?? 0)
                let date = match.date ?? "—"
                print("   \(date.gray)  \(tagA) \(leftScore)-\(rightScore) \(tagB)")
            }
        }
        print("\n\(AligulacClient.attribution)".gray)
    }
}

// MARK: - predict

struct PredictCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "predict",
        abstract: "Predict a best-of-N series between two players using Aligulac",
        discussion: "Requires ALIGULAC_TOKEN. \(AligulacClient.attribution)."
    )

    @Argument(help: "First player tag")
    var playerA: String

    @Argument(help: "Second player tag")
    var playerB: String

    @Option(name: .shortAndLong, help: "Best-of series length (default 5)")
    var bestOf: Int = 5

    func run() async throws {
        let aligulac = try CLIContext.load().makeAligulacClient()
        async let a = AligulacResolver.resolve(playerA, using: aligulac)
        async let b = AligulacResolver.resolve(playerB, using: aligulac)
        let (pa, pb) = try await (a, b)

        let prediction = try await aligulac.predictMatch(playerA: pa.id, playerB: pb.id, bestOf: bestOf)
        let tagA = pa.tag ?? playerA
        let tagB = pb.tag ?? playerB

        print("\n🔮 Prediction — Bo\(bestOf): \(tagA) vs \(tagB)".bold())
        if let pA = prediction.probabilityA, let pB = prediction.probabilityB {
            print("   \(tagA): \(pA.percentString)".cyan)
            print("   \(tagB): \(pB.percentString)".cyan)
            let favorite = pA >= pB ? tagA : tagB
            print("   Favorite: \(favorite.green)")
        } else {
            print("   Prediction unavailable for these players.".yellow)
        }
        if let sa = prediction.medianScoreA, let sb = prediction.medianScoreB {
            print("   Expected score: \(Int(sa.rounded()))-\(Int(sb.rounded()))".gray)
        }
        print("\n\(AligulacClient.attribution)".gray)
    }
}
