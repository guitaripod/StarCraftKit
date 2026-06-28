import Foundation

/// Protocol defining the core API client functionality for StarCraft 2 data access
public protocol APIClientProtocol: Sendable {
    /// Execute a request and return the decoded response.
    /// - Parameter request: The API request to execute
    /// - Returns: The decoded response of type T
    /// - Throws: APIError if the request fails
    func execute<T: APIResponse>(_ request: any APIRequest) async throws -> T

    /// Execute a paginated request and return all pages.
    /// - Parameters:
    ///   - request: The API request to execute
    ///   - maxPages: Maximum number of pages to fetch (nil for all)
    /// - Returns: Array of all items across all pages
    /// - Throws: APIError if the request fails
    func executePaginated<T: APIResponse>(_ request: any APIRequest, maxPages: Int?) async throws -> [T]
}
