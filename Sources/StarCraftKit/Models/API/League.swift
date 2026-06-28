import Foundation

/// StarCraft 2 league representation
public struct League: Codable, Sendable, Identifiable {
    /// Unique identifier for the league
    public let id: Int
    
    /// Name of the league
    public let name: String
    
    /// URL-friendly version of the league name
    public let slug: String
    
    /// URL to the league's logo/image
    public let imageURL: URL?

    /// Official URL for the league
    public let url: URL?

    /// Last modification timestamp
    public let modifiedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case slug
        case imageURL = "image_url"
        case url
        case modifiedAt = "modified_at"
    }
}

// MARK: - Defensive Decoding
public extension League {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let id = try c.decode(Int.self, forKey: .id)
        self.id = id
        self.name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "League \(id)"
        self.slug = (try? c.decodeIfPresent(String.self, forKey: .slug)) ?? "league-\(id)"
        self.imageURL = try? c.decodeIfPresent(URL.self, forKey: .imageURL)
        self.url = try? c.decodeIfPresent(URL.self, forKey: .url)
        self.modifiedAt = try? c.decodeIfPresent(Date.self, forKey: .modifiedAt)
    }
}

// MARK: - Equatable
extension League: Equatable {
    public static func == (lhs: League, rhs: League) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Hashable
extension League: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}