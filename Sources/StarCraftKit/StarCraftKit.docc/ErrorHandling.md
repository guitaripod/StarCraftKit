# Error Handling

Learn how to handle errors effectively when using StarCraftKit.

## Overview

StarCraftKit uses Swift's error handling mechanism with detailed error types to help you build robust applications. All API methods are marked with `throws` and use async/await.

## Error Types

StarCraftKit defines ``APIError`` as the primary error type with specific cases for different failure scenarios:

### Authentication Errors

```swift
do {
    let matches = try await client.getMatches()
} catch APIError.unauthorized(let message) {
    print("Authentication failed: \(message)")
    // Prompt user to check API token
} catch APIError.forbidden(let message) {
    print("Access denied: \(message)")
    // User's plan may not include this endpoint
}
```

### Network Errors

```swift
do {
    let players = try await client.getPlayers()
} catch APIError.networkError(let underlying) {
    print("Network issue: \(underlying)")
    // Check internet connection
} catch APIError.timeout {
    print("Request timed out")
    // Retry with longer timeout
}
```

### Rate Limiting

```swift
do {
    let tournaments = try await client.getTournaments()
} catch APIError.rateLimitExceeded(let retryAfter, let remaining) {
    if let retryAfter = retryAfter {
        print("Rate limited. Retry after \(retryAfter) seconds")
        // Schedule retry after the specified time
    }
    print("Remaining requests: \(remaining ?? 0)")
}
```

### Data Errors

```swift
do {
    let match = try await client.getMatch(id: 99999)
} catch APIError.notFound(let resource) {
    print("Not found: \(resource)")
    // Handle missing resource
} catch APIError.decodingError(let error, let data) {
    print("Failed to decode response: \(error)")
    // Log the raw data for debugging
}
```

## Comprehensive Error Handling

Here's a complete example showing how to handle all error types:

```swift
func fetchMatchSafely(id: Int) async {
    do {
        let match = try await client.getMatch(id: id)
        print("Match: \(match.name)")
    } catch {
        switch error {
        case APIError.unauthorized:
            handleAuthenticationError()
            
        case APIError.rateLimitExceeded(let retryAfter, _):
            await handleRateLimit(retryAfter: retryAfter)
            
        case APIError.notFound:
            print("Match \(id) not found")
            
        case APIError.networkError:
            print("Network error - check connection")
            
        case APIError.serverError(let code, let message):
            print("Server error \(code): \(message ?? "Unknown")")
            
        case APIError.decodingError:
            print("Invalid response format")
            
        default:
            print("Unexpected error: \(error)")
        }
    }
}
```

## Retry Strategies

### Automatic Retries

StarCraftKit automatically retries certain errors. You can configure this behavior:

```swift
let config = StarCraftClient.Configuration(
    apiKey: "your-token",
    retryConfiguration: .aggressive // More retries
)
let client = StarCraftClient(configuration: config)
```

### Manual Retry Logic

`APIError` already tells you whether it is worth retrying via `isRetryable` and
`suggestedRetryDelay`, so manual retry logic stays small:

```swift
func fetchWithRetry<T>(_ operation: () async throws -> T,
                       maxAttempts: Int = 3) async throws -> T {
    var lastError: Error?

    for attempt in 1...maxAttempts {
        do {
            return try await operation()
        } catch let error as APIError where error.isRetryable {
            lastError = error
            let delay = error.suggestedRetryDelay ?? Double(attempt) * 2.0
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        } catch {
            // Don't retry non-retryable errors
            throw error
        }
    }

    throw lastError ?? APIError.invalidRequest(reason: "Max retries exceeded")
}

// Usage
let matches = try await fetchWithRetry {
    try await client.getLiveMatches()
}
```

> The client already retries retryable errors automatically; this pattern is only
> needed when you want custom retry behavior on top of a sequence of calls.

## Error Recovery

### Fallback Strategies

```swift
func getMatchesWithFallback() async -> [Match] {
    do {
        // Try to get live matches
        return try await client.getLiveMatches()
    } catch {
        // Fall back to cached data
        return loadCachedMatches() ?? []
    }
}
```

### User-Friendly Error Messages

```swift
extension APIError {
    var userFriendlyMessage: String {
        switch self {
        case .unauthorized:
            return "Please check your API credentials"
        case .rateLimitExceeded:
            return "Too many requests. Please wait a moment."
        case .networkError:
            return "Connection error. Check your internet."
        case .notFound:
            return "Content not found"
        case .serverError:
            return "Server issue. Please try again later."
        default:
            return "Something went wrong"
        }
    }
}
```

## Debugging

### Detailed Error Logging

```swift
func logError(_ error: Error, context: String) {
    print("[\(Date())] Error in \(context):")
    
    if let apiError = error as? APIError {
        switch apiError {
        case .httpError(let code, let response):
            print("  HTTP \(code)")
            print("  Response: \(response?.message ?? "None")")
            
        case .decodingError(let underlying, let data):
            print("  Decoding failed: \(underlying)")
            if let data = data, let json = String(data: data, encoding: .utf8) {
                print("  Raw response: \(json)")
            }
            
        default:
            print("  \(apiError.localizedDescription)")
        }
    } else {
        print("  \(error)")
    }
}
```

## Best Practices

1. **Always handle errors** - Don't ignore thrown errors
2. **Be specific** - Handle different error types appropriately
3. **Provide feedback** - Inform users about issues
4. **Log errors** - Keep track of issues for debugging
5. **Implement retries** - For transient failures
6. **Have fallbacks** - Graceful degradation when possible