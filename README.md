# AIProxy iOS SDK

AIProxy SDK for iOS provides secure access to AI models (OpenAI, Anthropic) using device attestation.

## Features

- 🔐 Secure device attestation using iOS DeviceCheck
- 🚀 Simple, intuitive API with async/await support
- 🌊 Streaming support for real-time responses
- 🏗 Clean architecture with design patterns
- 📱 SwiftUI and UIKit compatible
- 🛡 Built-in error handling and retry logic
- 📊 Automatic session management

## Requirements

- iOS 15.0+
- macOS 12.0+
- Swift 5.9+
- Xcode 15.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/aiproxy-ios-sdk.git", from: "1.0.0")
]
```

Or in Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Select version and add to your project

## Quick Start

### 1. Configure the SDK

```swift
import AIProxy

// In your app's initialization (e.g., AppDelegate or App struct)
try AIProxy.configure()
    .withAppId("your_app_id_from_dashboard")
    .withEnvironment(.production)
    .withLogLevel(.error)
    .build()
```

### 2. Make a Chat Request

```swift
// OpenAI models
do {
    let response = try await AIProxy.openai.chat.completions.create(
        model: "gpt-4-turbo-preview", // Use any model without SDK updates
        messages: [
            .system("You are a helpful assistant"),
            .user("Hello! How can I use AIProxy?")
        ],
        temperature: 0.7,
        maxTokens: 1000
    )
    
    print(response.choices.first?.message.content ?? "")
} catch {
    print("Error: \(error)")
}

// Anthropic models
let response = try await AIProxy.anthropic.chat.completions.create(
    model: "claude-3-opus-20240229",
    messages: [.user("Hello Claude!")],
    temperature: 0.7
)
```

### 3. Streaming Responses

```swift
// Stream from OpenAI
let stream = try await AIProxy.openai.chat.completions.stream(
    model: "gpt-4",
    messages: [.user("Write a story about a robot")]
)

for try await chunk in stream {
    if let content = chunk.delta.content {
        print(content, terminator: "")
    }
}

// Stream from Anthropic
let anthropicStream = try await AIProxy.anthropic.chat.completions.stream(
    model: "claude-3-sonnet-20240229",
    messages: [.user("Tell me about AI")]
)
```

## Architecture

The SDK uses several design patterns for maintainability and extensibility:

### Facade Pattern
The main `AIProxy` class provides a simple, unified interface hiding the complexity of attestation, networking, and session management.

### Builder Pattern
Configuration uses a fluent builder pattern for easy setup:
```swift
AIProxy.configure()
    .withAppId("...")
    .withEnvironment(.staging)
    .build()
```

### Observer Pattern
Monitor attestation status changes:
```swift
class MyObserver: AttestationObserver {
    func attestationDidUpdate(status: AttestationStatus) {
        // Handle status updates
    }
}
```

### Chain of Responsibility
Request interceptors process requests through a chain:
- Logging interceptor
- Auth interceptor
- Retry interceptor

### Adapter Pattern
Provider-specific adapters handle differences between OpenAI and Anthropic APIs transparently.

## Error Handling

The SDK provides comprehensive error handling:

```swift
do {
    let response = try await AIProxy.chat.completions.create(...)
} catch AIProxyError.attestationFailed(let reason) {
    // Device attestation failed
} catch AIProxyError.sessionExpired {
    // Session needs renewal (handled automatically)
} catch AIProxyError.rateLimited(let retryAfter) {
    // Rate limit hit, retry after specified time
} catch AIProxyError.networkError(let error) {
    // Network connectivity issues
} catch AIProxyError.providerError(let code, let message) {
    // Provider-specific errors (OpenAI/Anthropic)
}
```

## SwiftUI Integration

```swift
struct ChatView: View {
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = false
    
    var body: some View {
        // Your chat UI
    }
    
    func sendMessage(_ text: String) async {
        messages.append(.user(text))
        isLoading = true
        
        do {
            let response = try await AIProxy.chat.completions.create(
                model: .gpt4,
                messages: messages
            )
            
            if let reply = response.choices.first?.message {
                messages.append(reply)
            }
        } catch {
            // Handle error
        }
        
        isLoading = false
    }
}
```

## Security

- Device attestation ensures only legitimate apps can access the API
- API keys are never exposed in the client app
- Session tokens are stored securely in the iOS Keychain
- All network communication uses TLS 1.3

## Providers and Models

The SDK supports any provider and model configured in your backend. You can use string values for maximum flexibility:

```swift
// Use any model without waiting for SDK updates
try await AIProxy.chat.completions.create(
    provider: "openai",
    model: "gpt-4-1106-preview", // Latest model
    messages: [...]
)

// Works with any provider your backend supports
try await AIProxy.chat.completions.create(
    provider: "anthropic",
    model: "claude-3-opus-20240229",
    messages: [...]
)

// Even custom or future providers
try await AIProxy.chat.completions.create(
    provider: "mistral",
    model: "mistral-large-latest",
    messages: [...]
)
```

### Convenience Constants

For common models, the SDK provides constants you can use:

```swift
// OpenAI Models
ChatModel.gpt4              // "gpt-4"
ChatModel.gpt4Turbo         // "gpt-4-turbo"
ChatModel.gpt4Vision        // "gpt-4-vision-preview"
ChatModel.gpt35Turbo        // "gpt-3.5-turbo"
ChatModel.gpt35Turbo16k     // "gpt-3.5-turbo-16k"

// Anthropic Models
ChatModel.claude3Opus       // "claude-3-opus-20240229"
ChatModel.claude3Sonnet     // "claude-3-sonnet-20240229"
ChatModel.claude3Haiku      // "claude-3-haiku-20240307"
ChatModel.claude2           // "claude-2.1"
ChatModel.claudeInstant     // "claude-instant-1.2"

// Provider Constants
AIProvider.openai           // "openai"
AIProvider.anthropic        // "anthropic"
```

## Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests to our repository.

## License

MIT License - see LICENSE file for details

## Support

- Documentation: https://docs.aiproxy.io
- Issues: https://github.com/your-org/aiproxy-ios-sdk/issues
- Email: support@aiproxy.io