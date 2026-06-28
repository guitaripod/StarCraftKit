import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import StarCraftKit

/// A `URLProtocol` that intercepts every request and answers it from a test-supplied
/// handler, so the networking stack can be exercised end-to-end with zero network access.
///
/// Wire it into a client through ``MockURLProtocol/makeClient(baseURL:authMethod:retryConfiguration:cacheConfiguration:)``,
/// which builds a `URLSessionConfiguration` carrying this protocol and passes it through
/// `StarCraftClient.Configuration.urlSessionConfiguration`.
final class MockURLProtocol: URLProtocol {
    /// A handler turns a request into a status/headers/body triple. It may also `throw`
    /// to simulate a transport-level (`URLError`) failure.
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    private static let lock = NSLock()
    nonisolated(unsafe) private static var _handler: Handler?
    nonisolated(unsafe) private static var _requestCount = 0
    nonisolated(unsafe) private static var _capturedRequests: [URLRequest] = []

    /// Install the handler invoked for every intercepted request. Resets the counters.
    static func setHandler(_ handler: @escaping Handler) {
        lock.lock()
        defer { lock.unlock() }
        _handler = handler
        _requestCount = 0
        _capturedRequests = []
    }

    /// Remove the handler and clear all recorded state.
    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        _handler = nil
        _requestCount = 0
        _capturedRequests = []
    }

    /// How many requests have been intercepted since the last `setHandler`/`reset`.
    static var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _requestCount
    }

    /// Every request intercepted since the last `setHandler`/`reset`, in order.
    static var capturedRequests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return _capturedRequests
    }

    /// Convenience: respond with the given status, JSON body bytes, and headers.
    static func respond(status: Int, body: Data, headers: [String: String] = [:]) {
        setHandler { request in
            let response = HTTPURLResponse(
                url: request.url ?? URL(string: "https://mock.test")!,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            )!
            return (response, body)
        }
    }

    // MARK: URLProtocol

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canInit(with task: URLSessionTask) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self._requestCount += 1
        Self._capturedRequests.append(request)
        let handler = Self._handler
        Self.lock.unlock()

        guard let handler else {
            let error = URLError(.badServerResponse)
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Client wiring

extension MockURLProtocol {
    /// A dummy base URL; the mock answers regardless of host.
    static let baseURL = URL(string: "https://mock.test")!

    /// Build a `StarCraftClient` whose URLSession is intercepted by ``MockURLProtocol``.
    ///
    /// Retries default to a single attempt so error-path tests don't sleep through backoff.
    static func makeClient(
        baseURL: URL = MockURLProtocol.baseURL,
        authMethod: StarCraftClient.Configuration.AuthMethod = .bearerToken,
        retryConfiguration: RetryConfiguration = RetryConfiguration(maxAttempts: 1),
        cacheConfiguration: StarCraftClient.Configuration.CacheConfiguration = .init()
    ) -> StarCraftClient {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [MockURLProtocol.self]
        let config = StarCraftClient.Configuration(
            apiKey: "test-token",
            authMethod: authMethod,
            baseURL: baseURL,
            retryConfiguration: retryConfiguration,
            cacheConfiguration: cacheConfiguration,
            urlSessionConfiguration: sessionConfig
        )
        return StarCraftClient(configuration: config)
    }

    /// A bare `NetworkingClient` wired to the mock (for lower-level networking tests).
    static func makeNetworkingClient(
        baseURL: URL = MockURLProtocol.baseURL,
        defaultHeaders: [String: String] = [:]
    ) -> NetworkingClient {
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: sessionConfig)
        return NetworkingClient(baseURL: baseURL, session: session, defaultHeaders: defaultHeaders)
    }
}
