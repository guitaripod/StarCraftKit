import Foundation

/// Comprehensive error types for StarCraftKit API operations.
///
/// `APIError` provides detailed error information for all types of failures
/// that can occur when interacting with the PandaScore API.
///
/// ## Error Handling
///
/// ```swift
/// do {
///     let matches = try await client.getLiveMatches()
/// } catch APIError.unauthorized {
///     print("Invalid API token - check your credentials")
/// } catch APIError.rateLimitExceeded(let retryAfter, _) {
///     print("Rate limit hit - retry after \(retryAfter ?? 60) seconds")
/// } catch APIError.networkError(let underlying) {
///     print("Network issue: \(underlying.localizedDescription)")
/// } catch {
///     print("Unexpected error: \(error)")
/// }
/// ```
///
/// ## Common Errors
///
/// - ``unauthorized(message:)``: Invalid or missing API token
/// - ``rateLimitExceeded(retryAfter:remaining:)``: Too many requests
/// - ``notFound(resource:)``: Requested resource doesn't exist
/// - ``networkError(underlying:)``: Network connectivity issues
///
/// ## Topics
///
/// ### Authentication Errors
/// - ``unauthorized(message:)``
/// - ``forbidden(message:)``
///
/// ### Network Errors
/// - ``networkError(underlying:)``
/// - ``httpError(statusCode:response:)``
/// - ``timeout``
///
/// ### API Limits
/// - ``rateLimitExceeded(retryAfter:remaining:)``
///
/// ### Data Errors
/// - ``notFound(resource:)``
/// - ``decodingError(underlying:data:)``
/// - ``invalidRequest(reason:)``
///
/// ### Server Errors
/// - ``serverError(statusCode:message:)``
public enum APIError: LocalizedError, Sendable {
    /// Network connectivity issues
    case networkError(underlying: Error)
    
    /// HTTP errors with status code and optional error response
    case httpError(statusCode: Int, response: ErrorResponse?)
    
    /// Authentication failures
    case unauthorized(message: String)
    
    /// Access forbidden (plan limitations)
    case forbidden(message: String)
    
    /// Resource not found
    case notFound(resource: String)
    
    /// Rate limit exceeded
    case rateLimitExceeded(retryAfter: TimeInterval?, remaining: Int?)
    
    /// Server errors (5xx)
    case serverError(statusCode: Int, message: String?)
    
    /// Decoding errors
    case decodingError(underlying: Error, data: Data?)
    
    /// Invalid request configuration
    case invalidRequest(reason: String)
    
    /// Timeout
    case timeout

    /// Cache error
    case cacheError(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .httpError(let statusCode, let response):
            return "HTTP \(statusCode): \(response?.message ?? "Unknown error")"
        case .unauthorized(let message):
            return "Unauthorized: \(message)"
        case .forbidden(let message):
            return "Forbidden: \(message)"
        case .notFound(let resource):
            return "Resource not found: \(resource)"
        case .rateLimitExceeded(let retryAfter, let remaining):
            var message = "Rate limit exceeded"
            if let remaining = remaining {
                message += " (remaining: \(remaining))"
            }
            if let retryAfter = retryAfter {
                message += " - retry after \(Int(retryAfter))s"
            }
            return message
        case .serverError(let statusCode, let message):
            return "Server error \(statusCode): \(message ?? "Unknown error")"
        case .decodingError(let error, _):
            return "Decoding error: \(error.localizedDescription)"
        case .invalidRequest(let reason):
            return "Invalid request: \(reason)"
        case .timeout:
            return "Request timed out"
        case .cacheError(let error):
            return "Cache error: \(error.localizedDescription)"
        }
    }
    
    /// Whether this error is retryable
    public var isRetryable: Bool {
        switch self {
        case .networkError, .timeout, .serverError, .rateLimitExceeded:
            return true
        default:
            return false
        }
    }
    
    /// Suggested retry delay in seconds
    public var suggestedRetryDelay: TimeInterval? {
        switch self {
        case .rateLimitExceeded(let retryAfter, _):
            return retryAfter
        case .serverError:
            return 5.0
        case .networkError, .timeout:
            return 2.0
        default:
            return nil
        }
    }
}

/// Error response from the API
public struct ErrorResponse: Codable, Sendable {
    public let error: String
    public let message: String
}