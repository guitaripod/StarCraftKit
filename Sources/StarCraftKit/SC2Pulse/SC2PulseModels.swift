import Foundation

/// Battle.net region as used by SC2 Pulse / Blizzard.
public enum SC2Region: String, Codable, Sendable, CaseIterable {
    case us = "US"
    case eu = "EU"
    case kr = "KR"
    case cn = "CN"
}

/// Ranked ladder league tiers.
public enum LadderLeague: String, Codable, Sendable, CaseIterable {
    case bronze = "BRONZE"
    case silver = "SILVER"
    case gold = "GOLD"
    case platinum = "PLATINUM"
    case diamond = "DIAMOND"
    case master = "MASTER"
    case grandmaster = "GRANDMASTER"
}

/// Matchmaking queues.
public enum LadderQueue: String, Codable, Sendable, CaseIterable {
    case lotv1v1 = "LOTV_1V1"
    case lotv2v2 = "LOTV_2V2"
    case lotv3v3 = "LOTV_3V3"
    case lotv4v4 = "LOTV_4V4"
    case lotvArchon = "LOTV_ARCHON"
}

/// Team composition for a ladder query.
public enum LadderTeamType: String, Codable, Sendable, CaseIterable {
    case arranged = "ARRANGED"
    case random = "RANDOM"
}

public extension Race {
    /// Map an SC2 Pulse race string (`TERRAN`/`PROTOSS`/`ZERG`/`RANDOM`) to a ``Race``.
    init?(pulseName: String) {
        switch pulseName.uppercased() {
        case "TERRAN": self = .terran
        case "PROTOSS": self = .protoss
        case "ZERG": self = .zerg
        case "RANDOM": self = .random
        default: return nil
        }
    }
}

// MARK: - Core identity

/// A Battle.net character (ladder account toon).
public struct PulsePlayerCharacter: Codable, Sendable, Identifiable {
    public let id: Int
    public let accountId: Int?
    public let realm: Int?
    public let region: String?
    public let battlenetId: Int?
    /// Full toon name including discriminator, e.g. `Serral#769`.
    public let name: String?
    /// Display tag without discriminator, e.g. `Serral`.
    public let tag: String?
    public let discriminator: Int?
}

public struct PulseAccount: Codable, Sendable, Identifiable {
    public let id: Int
    public let battleTag: String?
    public let partition: String?
    public let hidden: Bool?
    public let tag: String?
    public let discriminator: Int?
}

public struct PulseClan: Codable, Sendable, Identifiable {
    public let id: Int
    public let tag: String?
    public let region: String?
    public let name: String?
    public let members: Int?
    public let activeMembers: Int?
    public let avgRating: Int?
    public let games: Int?
}

/// A professional player record as tracked by SC2 Pulse (cross-links to Aligulac).
public struct PulseProPlayer: Codable, Sendable, Identifiable {
    public let id: Int?
    public let aligulacId: Int?
    public let nickname: String?
    public let name: String?
    public let country: String?
    public let birthday: String?
    /// Career earnings in USD.
    public let earnings: Int?
}

public struct PulseProTeam: Codable, Sendable {
    public let id: Int?
    public let aligulacId: Int?
    public let name: String?
    public let shortName: String?
}

public struct PulseSocialLink: Codable, Sendable {
    public let type: String?
    public let url: String?
    public let serviceUserId: String?
}

public struct PulseLadderProPlayer: Codable, Sendable {
    public let proPlayer: PulseProPlayer?
    public let proTeam: PulseProTeam?
    public let links: [PulseSocialLink]?
}

// MARK: - Ladder membership & stats

public struct LadderStats: Codable, Sendable {
    public let rating: Int?
    public let gamesPlayed: Int?
    public let rank: Int?
}

/// One member of a ladder team, carrying the character, account, clan, race
/// distribution, and any linked pro identity.
public struct LadderTeamMember: Codable, Sendable {
    public let character: PulsePlayerCharacter
    public let account: PulseAccount?
    public let clan: PulseClan?
    public let terranGamesPlayed: Int?
    public let protossGamesPlayed: Int?
    public let zergGamesPlayed: Int?
    public let randomGamesPlayed: Int?
    public let proId: Int?
    public let proNickname: String?
    public let proTeam: String?
    public let proPlayer: PulseLadderProPlayer?

    /// Games played per race.
    public var gamesByRace: [Race: Int] {
        var result: [Race: Int] = [:]
        if let t = terranGamesPlayed, t > 0 { result[.terran] = t }
        if let p = protossGamesPlayed, p > 0 { result[.protoss] = p }
        if let z = zergGamesPlayed, z > 0 { result[.zerg] = z }
        if let r = randomGamesPlayed, r > 0 { result[.random] = r }
        return result
    }

    /// The race this player plays most (ties broken deterministically by race).
    public var mainRace: Race? {
        gamesByRace.max { lhs, rhs in
            lhs.value != rhs.value ? lhs.value < rhs.value : lhs.key.rawValue > rhs.key.rawValue
        }?.key
    }

    /// The Aligulac id linked to this member, if known.
    public var aligulacId: Int? {
        proPlayer?.proPlayer?.aligulacId
    }
}

/// A distinct ladder character returned by a character search, with current and
/// previous-season summary stats.
public struct LadderCharacter: Codable, Sendable {
    /// Highest league tier reached (0 = Bronze … 6 = Grandmaster).
    public let leagueMax: Int?
    public let ratingMax: Int?
    public let totalGamesPlayed: Int?
    public let previousStats: LadderStats?
    public let currentStats: LadderStats?
    public let members: LadderTeamMember

    /// Best available MMR (current season, else peak).
    public var mmr: Int? {
        currentStats?.rating ?? ratingMax
    }
    /// Current ladder rank, if ranked this season.
    public var rank: Int? { currentStats?.rank }
    public var name: String? { members.character.tag ?? members.character.name }
    /// Best human-facing name, preferring the pro nickname over a ladder barcode tag.
    public var displayName: String? { members.proNickname ?? name }
    public var region: String? { members.character.region }
    public var mainRace: Race? { members.mainRace }
    public var clanTag: String? { members.clan?.tag }
    public var aligulacId: Int? { members.aligulacId }
    public var proNickname: String? { members.proNickname }
    public var earnings: Int? { members.proPlayer?.proPlayer?.earnings }
}

public struct BaseLeague: Codable, Sendable {
    public let type: Int?
    public let queueType: Int?
    public let teamType: Int?
}

/// A ranked ladder team (a row on the ladder leaderboard).
public struct LadderTeam: Codable, Sendable, Identifiable {
    public let id: Int
    public let rating: Int?
    public let wins: Int?
    public let losses: Int?
    public let ties: Int?
    public let season: Int?
    public let region: String?
    public let league: BaseLeague?
    public let globalRank: Int?
    public let regionRank: Int?
    public let leagueRank: Int?
    public let lastPlayed: String?
    public let members: [LadderTeamMember]

    public var primaryMember: LadderTeamMember? { members.first }
    public var name: String? { primaryMember?.character.tag ?? primaryMember?.character.name }
    public var mainRace: Race? { primaryMember?.mainRace }

    public var winRate: Double? {
        let w = wins ?? 0
        let total = w + (losses ?? 0)
        guard total > 0 else { return nil }
        return Double(w) / Double(total)
    }
}

// MARK: - Streams, seasons, tiers, matches

public struct PulseVideoStream: Codable, Sendable {
    public let service: String?
    public let id: String?
    public let userName: String?
    public let userId: String?
    public let title: String?
    public let url: String?
    public let language: String?
    public let viewerCount: Int?
    public let thumbnailUrl: String?
    public let profileImageUrl: String?
}

/// A live community stream, optionally linked to a pro player and ladder team.
public struct LadderStream: Codable, Sendable {
    public let stream: PulseVideoStream
    public let proPlayer: PulseLadderProPlayer?
    public let team: LadderTeam?
    public let featured: Bool?
}

private struct CommunityStreamResult: Codable, Sendable {
    let streams: [LadderStream]?
}

public struct PulseSeason: Codable, Sendable, Identifiable {
    public let id: Int
    public let number: Int?
    public let year: Int?
    public let start: String?
    public let end: String?
    public let battlenetId: Int?
    public let region: String?
}

public struct LadderTier: Codable, Sendable {
    public let type: String?
    public let minRating: Int?
    public let maxRating: Int?
    public let leagueId: Int?
}

public struct SC2MapInfo: Codable, Sendable, Identifiable {
    public let id: Int?
    public let name: String?
}

public struct PulseMatchInfo: Codable, Sendable {
    public let id: Int?
    public let date: String?
    public let type: String?
    public let region: String?
    public let duration: Int?
}

public struct LadderMatchParticipant: Codable, Sendable {
    public let team: LadderTeam?
    public let twitchVodUrl: String?
}

/// A finished ladder match with its map and participants.
public struct LadderMatch: Codable, Sendable {
    public let match: PulseMatchInfo?
    public let map: SC2MapInfo?
    public let participants: [LadderMatchParticipant]?
}

public struct GamePatch: Codable, Sendable, Identifiable {
    public let id: Int?
    public let build: Int?
    public let version: String?
    public let versus: Bool?
}
