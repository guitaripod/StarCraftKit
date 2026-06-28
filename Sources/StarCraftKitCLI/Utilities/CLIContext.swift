import Foundation
import StarCraftKit

// MARK: - CLI Context
struct CLIContext {
    let apiKey: String
    let authMethod: StarCraftClient.Configuration.AuthMethod
    let aligulacKey: String?

    static func load() throws -> CLIContext {
        guard let apiKey = ProcessInfo.processInfo.environment["PANDA_TOKEN"] else {
            throw CLIError.missingAPIKey
        }

        let authMethod: StarCraftClient.Configuration.AuthMethod =
            ProcessInfo.processInfo.environment["AUTH_METHOD"] == "query" ? .queryParameter : .bearerToken

        let aligulacKey = ProcessInfo.processInfo.environment["ALIGULAC_TOKEN"]

        return CLIContext(apiKey: apiKey, authMethod: authMethod, aligulacKey: aligulacKey)
    }

    func makeClient() -> StarCraftClient {
        StarCraftClient(configuration: .init(apiKey: apiKey, authMethod: authMethod))
    }

    /// Build an Aligulac client, requiring `ALIGULAC_TOKEN` to be set.
    func makeAligulacClient() throws -> AligulacClient {
        guard let aligulacKey, !aligulacKey.isEmpty else {
            throw CLIError.missingAligulacKey
        }
        return AligulacClient(apiKey: aligulacKey)
    }
}

// MARK: - CLI Errors
enum CLIError: LocalizedError {
    case missingAPIKey
    case missingAligulacKey
    case invalidInput(String)
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Missing API key. Set PANDA_TOKEN environment variable."
        case .missingAligulacKey:
            return "Missing Aligulac key. Set ALIGULAC_TOKEN (free key at https://aligulac.com/about/api/)."
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .notFound(let message):
            return "Not found: \(message)"
        }
    }
}
