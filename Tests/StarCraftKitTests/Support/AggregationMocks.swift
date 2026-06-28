import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import StarCraftKit

/// Factories that wire the new aggregation-layer clients (SC2 Pulse, Aligulac, Blizzard,
/// PandaScore) to ``MockURLProtocol`` so the unified ``StarCraft`` facade can be exercised
/// hermetically. Each client is given a distinct, recognizable host so a single mock
/// handler can route by `request.url!.host` when multiple sources are composed.
enum AggregationMocks {
    private static func mockSessionConfiguration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return config
    }

    /// Distinct hosts so a composed mock handler can tell the sources apart by URL host.
    enum Host {
        static let pulse = "pulse.mock.test"
        static let aligulac = "aligulac.mock.test"
        static let panda = "panda.mock.test"
        static let blizzardOAuth = "oauth.mock.test"
    }

    static func pulseBaseURL() -> URL {
        URL(string: "https://\(Host.pulse)/sc2/")!
    }

    static func makePulseClient(userAgent: String = "StarCraftKitTests/1.0") -> SC2PulseClient {
        let config = SC2PulseClient.Configuration(
            baseURL: pulseBaseURL(),
            userAgent: userAgent,
            retryConfiguration: RetryConfiguration(maxAttempts: 1),
            urlSessionConfiguration: mockSessionConfiguration()
        )
        return SC2PulseClient(configuration: config)
    }

    static func makeAligulacClient() -> AligulacClient {
        let config = AligulacClient.Configuration(
            apiKey: "test-aligulac-key",
            baseURL: URL(string: "https://\(Host.aligulac)/api/v1/")!,
            retryConfiguration: RetryConfiguration(maxAttempts: 1),
            urlSessionConfiguration: mockSessionConfiguration()
        )
        return AligulacClient(configuration: config)
    }

    static func makePandaScoreClient() -> StarCraftClient {
        let config = StarCraftClient.Configuration(
            apiKey: "test-panda-token",
            baseURL: URL(string: "https://\(Host.panda)")!,
            retryConfiguration: RetryConfiguration(maxAttempts: 1),
            urlSessionConfiguration: mockSessionConfiguration()
        )
        return StarCraftClient(configuration: config)
    }

    /// A Blizzard client whose OAuth token endpoint and SC2 API hosts both hit the mock.
    /// The OAuth URL uses a distinct host so the handler can serve a token there.
    static func makeBlizzardClient() -> BlizzardClient {
        let config = BlizzardClient.Configuration(
            credentials: .init(clientId: "client-id", clientSecret: "client-secret"),
            oauthURL: URL(string: "https://\(Host.blizzardOAuth)/token")!,
            retryConfiguration: RetryConfiguration(maxAttempts: 1),
            urlSessionConfiguration: mockSessionConfiguration()
        )
        return BlizzardClient(configuration: config)
    }

    /// Build an `HTTPURLResponse`/`Data` pair for the mock handler.
    static func ok(_ request: URLRequest, _ body: Data, headers: [String: String] = [:]) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://mock.test")!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
        return (response, body)
    }
}
