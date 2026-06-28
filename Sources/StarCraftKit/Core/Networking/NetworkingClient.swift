import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Logging

/// Core networking client for API communication.
///
/// `NetworkingClient` performs the raw HTTP exchange and maps non-2xx responses to
/// ``APIError``. Decoding is performed by the caller so that the response cache can
/// store the original response bytes (avoiding an `Encodable` round-trip).
public actor NetworkingClient {
    private let session: URLSession
    private let logger: Logger
    private let baseURL: URL
    private let defaultHeaders: [String: String]

    /// Rate limit tracking. PandaScore documents only `X-Rate-Limit-Remaining`;
    /// the window is a fixed hourly bucket, so the reset is computed, not read.
    private var rateLimitRemaining: Int?

    public init(
        baseURL: URL,
        session: URLSession = .shared,
        defaultHeaders: [String: String] = [:],
        logger: Logger = Logger(label: "StarCraftKit.NetworkingClient")
    ) {
        self.baseURL = baseURL
        self.session = session
        self.defaultHeaders = defaultHeaders
        self.logger = logger
    }

    /// Execute a request and return the validated raw response body and headers.
    public func send(_ request: URLRequest) async throws -> (data: Data, headers: [String: String]) {
        logger.debug("Executing request: \(request.url?.absoluteString ?? "unknown")")

        let data: Data
        let response: URLResponse
        do {
            #if canImport(FoundationNetworking)
            (data, response) = try await withCheckedThrowingContinuation { continuation in
                let task = session.dataTask(with: request) { data, response, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let data, let response {
                        continuation.resume(returning: (data, response))
                    } else {
                        continuation.resume(throwing: URLError(.badServerResponse))
                    }
                }
                task.resume()
            }
            #else
            (data, response) = try await session.data(for: request)
            #endif
        } catch let error as APIError {
            throw error
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw APIError.timeout
        } catch {
            throw APIError.networkError(underlying: error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(underlying: URLError(.badServerResponse))
        }

        updateRateLimitInfo(from: httpResponse)

        let headers = httpResponse.allHeaderFields.reduce(into: [String: String]()) { result, header in
            if let key = header.key as? String, let value = header.value as? String {
                result[key.lowercased()] = value
            }
        }

        try validateResponse(httpResponse, data: data)

        return (data, headers)
    }

    /// Build a `URLRequest` from components.
    public func buildRequest(
        path: String,
        method: HTTPMethod,
        queryParameters: [String: QueryValue] = [:],
        headers: [String: String] = [:],
        body: Data? = nil
    ) throws -> URLRequest {
        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard let url = URL(string: normalizedPath, relativeTo: baseURL) else {
            throw APIError.invalidRequest(reason: "Invalid path: \(path)")
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)

        if !queryParameters.isEmpty {
            var queryItems: [URLQueryItem] = []
            for (key, value) in queryParameters.sorted(by: { $0.key < $1.key }) {
                for stringValue in value.queryStrings {
                    queryItems.append(URLQueryItem(name: key, value: stringValue))
                }
            }
            components?.queryItems = queryItems
        }

        guard let finalURL = components?.url else {
            throw APIError.invalidRequest(reason: "Failed to build URL")
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = method.rawValue
        request.httpBody = body

        for (key, value) in defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        if request.value(forHTTPHeaderField: "Content-Type") == nil, body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        return request
    }

    /// Current rate limit status. `resetTime` is the top of the next hour (PandaScore
    /// uses a fixed hourly window and sends no reset header).
    public func getRateLimitStatus() -> (remaining: Int?, resetTime: Date?) {
        (rateLimitRemaining, Self.topOfNextHour())
    }

    private func updateRateLimitInfo(from response: HTTPURLResponse) {
        if let remainingString = response.value(forHTTPHeaderField: "X-Rate-Limit-Remaining"),
           let remaining = Int(remainingString) {
            rateLimitRemaining = remaining
        }
    }

    private static func topOfNextHour(from date: Date = Date()) -> Date {
        let interval = date.timeIntervalSinceReferenceDate
        let nextHour = (floor(interval / 3600) + 1) * 3600
        return Date(timeIntervalSinceReferenceDate: nextHour)
    }

    private func validateResponse(_ response: HTTPURLResponse, data: Data) throws {
        switch response.statusCode {
        case 200...299:
            return
        case 400:
            let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw APIError.httpError(statusCode: 400, response: errorResponse)
        case 401:
            let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw APIError.unauthorized(message: errorResponse?.message ?? "Invalid authentication token")
        case 403:
            let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw APIError.forbidden(message: errorResponse?.message ?? "Plan does not support requested URL")
        case 404:
            throw APIError.notFound(resource: response.url?.absoluteString ?? "unknown")
        case 429:
            let retryAfter = Self.parseRetryAfter(response.value(forHTTPHeaderField: "Retry-After"))
            let remaining = response.value(forHTTPHeaderField: "X-Rate-Limit-Remaining").flatMap(Int.init)
            throw APIError.rateLimitExceeded(retryAfter: retryAfter, remaining: remaining)
        case 500...599:
            let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw APIError.serverError(statusCode: response.statusCode, message: errorResponse?.message)
        default:
            let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw APIError.httpError(statusCode: response.statusCode, response: errorResponse)
        }
    }

    /// Parse a `Retry-After` header, which per RFC 7231 may be delta-seconds or an HTTP-date.
    static func parseRetryAfter(_ value: String?) -> TimeInterval? {
        guard let value = value?.trimmingCharacters(in: .whitespaces), !value.isEmpty else {
            return nil
        }
        if let seconds = TimeInterval(value) {
            return seconds
        }
        if let date = httpDateFormatter.date(from: value) {
            return Swift.max(0, date.timeIntervalSinceNow)
        }
        return nil
    }

    private static let httpDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
