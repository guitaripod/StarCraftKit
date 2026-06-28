# Authentication

Learn how to authenticate with the PandaScore API using StarCraftKit.

## Overview

StarCraftKit uses token-based authentication with the PandaScore API. You'll need a valid API token to make requests.

## Obtaining an API Token

1. Visit [PandaScore](https://pandascore.co)
2. Sign up for an account
3. Navigate to your dashboard
4. Generate an API token

## Configuring Authentication

### Basic Authentication

```swift
let client = StarCraftClient(apiToken: "your-api-token")
```

### Choosing an Authentication Method

By default the token is sent as a Bearer token in the `Authorization` header. You can
instead send it as a `token` query parameter:

```swift
let config = StarCraftClient.Configuration(
    apiKey: "your-api-token",
    authMethod: .queryParameter // or .bearerToken (default)
)
let client = StarCraftClient(configuration: config)
```

### Using Environment Variables (Recommended)

Store your token securely in environment variables:

```bash
# .env file or shell configuration
export PANDA_TOKEN="your-api-token"
```

Load it in your application:

```swift
guard let token = ProcessInfo.processInfo.environment["PANDA_TOKEN"] else {
    fatalError("PANDA_TOKEN environment variable not set")
}

let client = StarCraftClient(apiToken: token)
```

### Using a Configuration File

For development, you can use a configuration file (remember to add it to `.gitignore`):

```swift
struct Config: Decodable {
    let apiToken: String
}

let configURL = Bundle.main.url(forResource: "config", withExtension: "json")!
let configData = try Data(contentsOf: configURL)
let config = try JSONDecoder().decode(Config.self, from: configData)

let client = StarCraftClient(apiToken: config.apiToken)
```

## Security Best Practices

1. **Never commit API tokens** to version control
2. **Use environment variables** for production deployments
3. **Rotate tokens regularly** for enhanced security
4. **Limit token permissions** to only what's needed
5. **Use HTTPS** for all API communications (handled automatically by StarCraftKit)

## Token Validation

StarCraftKit automatically validates your token on the first request. If invalid, you'll receive an ``APIError/unauthorized(message:)`` error:

```swift
do {
    let matches = try await client.getMatches()
} catch APIError.unauthorized {
    print("Invalid API token")
} catch {
    print("Other error: \(error)")
}
```

## Rate Limiting

PandaScore enforces rate limits on API tokens. StarCraftKit handles rate limiting automatically with:

- Automatic retry with exponential backoff and jitter
- Rate limit header parsing
- Configurable retry behavior

You can inspect the current rate-limit status at any time:

```swift
let (remaining, resetTime) = await client.getRateLimitStatus()
print("Requests remaining: \(remaining ?? -1)")
```

> PandaScore does not send a rate-limit reset header, so `resetTime` is reported as the
> top of the next hour (PandaScore's rate-limit window).

Customize retry behavior through the client configuration:

```swift
let config = StarCraftClient.Configuration(
    apiKey: "your-token",
    retryConfiguration: .aggressive // .default / .aggressive / .conservative
)
let client = StarCraftClient(configuration: config)
```