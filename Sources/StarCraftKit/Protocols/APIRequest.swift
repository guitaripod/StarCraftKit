import Foundation

/// HTTP method types
public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

/// A response type that can be decoded and safely crossed actor boundaries.
public typealias APIResponse = Decodable & Sendable

/// Protocol defining an API request
public protocol APIRequest: Sendable {
    /// The response type expected from this request
    associatedtype Response: APIResponse

    /// The path component of the URL (e.g., "/starcraft-2/players")
    var path: String { get }

    /// The HTTP method for the request
    var method: HTTPMethod { get }

    /// Query parameters to include in the request
    var queryParameters: [String: QueryValue] { get }

    /// Headers to include in the request
    var headers: [String: String] { get }

    /// Request body (for POST, PUT, PATCH requests)
    var body: Data? { get }

    /// Whether this request supports pagination
    var supportsPagination: Bool { get }

    /// Cache policy for this request
    var cachePolicy: CachePolicy { get }
}

/// Default implementations
public extension APIRequest {
    var method: HTTPMethod { .get }
    var queryParameters: [String: QueryValue] { [:] }
    var headers: [String: String] { [:] }
    var body: Data? { nil }
    var supportsPagination: Bool { true }
    var cachePolicy: CachePolicy { .useCache(ttl: 300) }
}

/// Cache policy for requests
public enum CachePolicy: Sendable, Equatable {
    /// Don't cache this request
    case noCache
    /// Use cache with time-to-live in seconds
    case useCache(ttl: TimeInterval)
    /// Cache indefinitely
    case cacheForever
}