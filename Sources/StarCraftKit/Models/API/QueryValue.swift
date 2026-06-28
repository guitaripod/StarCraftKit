import Foundation

/// A type-safe, `Sendable` value that can appear in an API query string.
///
/// `QueryValue` replaces the previous `[String: Any]` query model so that every
/// request type is fully `Sendable` (a requirement under the Swift 6 language mode)
/// and so query values are encoded deterministically instead of via
/// `String(describing:)`, which corrupted `Bool`, `Date`, and `Optional` values.
public enum QueryValue: Sendable, Equatable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case date(Date)
    case list([QueryValue])

    /// The individual query-string values this `QueryValue` expands to.
    ///
    /// A single key may map to multiple values (for `.list`), so this returns an
    /// array. PandaScore filters expect comma-free repeated keys for array values.
    public var queryStrings: [String] {
        switch self {
        case .string(let value):
            return [value]
        case .int(let value):
            return [String(value)]
        case .double(let value):
            return [Self.formatDouble(value)]
        case .bool(let value):
            return [value ? "true" : "false"]
        case .date(let value):
            return [ISO8601DateFormatter.pandaScore.string(from: value)]
        case .list(let values):
            return values.flatMap { $0.queryStrings }
        }
    }

    /// The single scalar string used when a key is known to be single-valued
    /// (for cache-key construction and page params).
    public var scalarString: String {
        queryStrings.joined(separator: ",")
    }

    private static func formatDouble(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1e15 {
            return String(Int(value))
        }
        return String(value)
    }
}

// MARK: - Literal conveniences

extension QueryValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}

extension QueryValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self = .int(value)
    }
}

extension QueryValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .bool(value)
    }
}
