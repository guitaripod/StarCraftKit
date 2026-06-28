import Foundation

/// A composable, value-type description of an API query (pagination, sorting,
/// filtering, searching and numeric ranges).
///
/// Build queries fluently — every modifier returns a new `QueryParameters`:
///
/// ```swift
/// let query = QueryParameters()
///     .filter("nationality", "KR")
///     .sort("name", .ascending)
///     .perPage(20)
///     .page(1)
/// let koreanPlayers = try await client.getPlayers(PlayersRequest(parameters: query))
/// ```
public struct QueryParameters: Sendable, Equatable, Hashable {
    /// Pagination parameters.
    public var pagination: PaginationParameters?

    /// Sort parameters, applied in order.
    public var sort: [SortParameter]?

    /// Filter parameters (`filter[key]=value`).
    public var filters: [String: QueryValue]?

    /// Search parameters (`search[key]=value`).
    public var search: [String: String]?

    /// Numeric range parameters (`range[key]=min,max`).
    public var ranges: [String: RangeParameter]?

    public init(
        pagination: PaginationParameters? = nil,
        sort: [SortParameter]? = nil,
        filters: [String: QueryValue]? = nil,
        search: [String: String]? = nil,
        ranges: [String: RangeParameter]? = nil
    ) {
        self.pagination = pagination
        self.sort = sort
        self.filters = filters
        self.search = search
        self.ranges = ranges
    }

    /// Convert to the flat dictionary used to build URL query items.
    public func toDictionary() -> [String: QueryValue] {
        var params: [String: QueryValue] = [:]

        if let pagination {
            params["page[number]"] = .int(pagination.page)
            params["page[size]"] = .int(pagination.size)
        }

        if let sort, !sort.isEmpty {
            params["sort"] = .string(sort.map { $0.toString() }.joined(separator: ","))
        }

        if let filters {
            for (key, value) in filters {
                params["filter[\(key)]"] = value
            }
        }

        if let search {
            for (key, value) in search {
                params["search[\(key)]"] = .string(value)
            }
        }

        if let ranges {
            for (key, range) in ranges {
                params["range[\(key)]"] = .string(range.toString())
            }
        }

        return params
    }
}

// MARK: - Fluent modifiers

public extension QueryParameters {
    /// Set the 1-based page number.
    func page(_ number: Int) -> QueryParameters {
        var copy = self
        let size = copy.pagination?.size ?? 50
        copy.pagination = PaginationParameters(page: number, size: size)
        return copy
    }

    /// Set the page size (clamped to PandaScore's 1...100 range).
    func perPage(_ size: Int) -> QueryParameters {
        var copy = self
        let page = copy.pagination?.page ?? 1
        copy.pagination = PaginationParameters(page: page, size: size)
        return copy
    }

    /// Append a sort field.
    func sort(_ field: String, _ direction: SortDirection = .ascending) -> QueryParameters {
        var copy = self
        copy.sort = (copy.sort ?? []) + [SortParameter(field: field, direction: direction)]
        return copy
    }

    /// Add (or replace) a filter.
    func filter(_ key: String, _ value: QueryValue) -> QueryParameters {
        var copy = self
        var filters = copy.filters ?? [:]
        filters[key] = value
        copy.filters = filters
        return copy
    }

    /// Add (or replace) a search term.
    func search(_ key: String, _ value: String) -> QueryParameters {
        var copy = self
        var search = copy.search ?? [:]
        search[key] = value
        copy.search = search
        return copy
    }

    /// Add (or replace) a numeric range filter.
    func range(_ key: String, from min: Double? = nil, to max: Double? = nil) -> QueryParameters {
        var copy = self
        var ranges = copy.ranges ?? [:]
        ranges[key] = RangeParameter(min: min, max: max)
        copy.ranges = ranges
        return copy
    }
}

/// Pagination parameters.
public struct PaginationParameters: Sendable, Equatable, Hashable {
    /// Page number (1-based).
    public let page: Int

    /// Number of items per page (PandaScore caps this at 100).
    public let size: Int

    public init(page: Int = 1, size: Int = 50) {
        self.page = max(1, page)
        self.size = min(100, max(1, size))
    }
}

/// Sort parameter.
public struct SortParameter: Sendable, Equatable, Hashable {
    /// Field to sort by.
    public let field: String

    /// Sort direction.
    public let direction: SortDirection

    public init(field: String, direction: SortDirection = .ascending) {
        self.field = field
        self.direction = direction
    }

    /// PandaScore string representation (`-field` for descending).
    public func toString() -> String {
        switch direction {
        case .ascending: return field
        case .descending: return "-\(field)"
        }
    }
}

/// Sort direction.
public enum SortDirection: Sendable, Equatable, Hashable {
    case ascending
    case descending
}

/// Range parameter for numeric filtering.
public struct RangeParameter: Sendable, Equatable, Hashable {
    /// Minimum value (inclusive).
    public let min: Double?

    /// Maximum value (inclusive).
    public let max: Double?

    public init(min: Double? = nil, max: Double? = nil) {
        self.min = min
        self.max = max
    }

    /// PandaScore string representation (`min,max`), formatting integral bounds
    /// without a trailing `.0` to match `QueryValue` encoding.
    public func toString() -> String {
        let lo = min.map { QueryValue.double($0).scalarString } ?? ""
        let hi = max.map { QueryValue.double($0).scalarString } ?? ""
        switch (min, max) {
        case (_?, _?): return "\(lo),\(hi)"
        case (_?, nil): return "\(lo),"
        case (nil, _?): return ",\(hi)"
        default: return ""
        }
    }
}
