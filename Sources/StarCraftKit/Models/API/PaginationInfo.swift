import Foundation

/// Pagination information from API headers
public struct PaginationInfo: Sendable {
    /// Current page number
    public let page: Int
    
    /// Items per page
    public let perPage: Int
    
    /// Total count of items
    public let total: Int
    
    /// Navigation links
    public let links: NavigationLinks
    
    /// Total number of pages
    public var totalPages: Int {
        guard perPage > 0 else { return 0 }
        return Int(ceil(Double(total) / Double(perPage)))
    }
    
    /// Check if there's a next page
    public var hasNextPage: Bool {
        page < totalPages
    }
    
    /// Check if there's a previous page
    public var hasPreviousPage: Bool {
        page > 1
    }
}

/// Navigation links for pagination
public struct NavigationLinks: Sendable {
    public let first: URL?
    public let previous: URL?
    public let next: URL?
    public let last: URL?
    
    /// Parse from Link header
    public init(from linkHeader: String?) {
        guard let linkHeader = linkHeader else {
            self.first = nil
            self.previous = nil
            self.next = nil
            self.last = nil
            return
        }
        
        var links: [String: URL] = [:]
        
        let linkPattern = #/<([^>]+)>;\s*rel="(\w+)"/#
        let matches = linkHeader.matches(of: linkPattern)
        
        for match in matches {
            let urlString = String(match.output.1)
            let rel = String(match.output.2)
            if let url = URL(string: urlString) {
                links[rel] = url
            }
        }
        
        self.first = links["first"]
        self.previous = links["prev"]
        self.next = links["next"]
        self.last = links["last"]
    }
}

/// Extension to extract pagination info from headers
public extension PaginationInfo {
    /// Build from response headers. Header keys are matched case-insensitively
    /// because `HTTPURLResponse.allHeaderFields` casing is not guaranteed across
    /// platforms (notably swift-corelibs-foundation on Linux).
    init?(from headers: [String: String]) {
        let lower = headers.reduce(into: [String: String]()) { $0[$1.key.lowercased()] = $1.value }
        guard let pageStr = lower["x-page"],
              let page = Int(pageStr),
              let perPageStr = lower["x-per-page"],
              let perPage = Int(perPageStr), perPage > 0,
              let totalStr = lower["x-total"],
              let total = Int(totalStr) else {
            return nil
        }

        self.page = page
        self.perPage = perPage
        self.total = total
        self.links = NavigationLinks(from: lower["link"])
    }
}