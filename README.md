# ProxyKit iOS SDK

ProxyKit SDK for iOS provides secure access to AI models (OpenAI, Anthropic) using device attestation. Choose between two integration styles:

- **SecureProxy**: Simple, context-aware conversations with automatic message history
- **AIProxy**: Full control over API calls for advanced use cases

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
    .package(url: "https://github.com/proxy-kit/ios-sdk", from: "1.0.0")
]
```

Or in Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Select version and add to your project

## Quick Start

### 1. Configure the SDK

Choose your configuration style:

#### SecureProxy (Simple)
```swift
import SecureProxy

// In your app's initialization
_ = SecureProxy.configure(appid: "your_app_id_from_dashboard")
```

#### AIProxy (Advanced)
```swift
import AIProxy

// In your app's initialization
try AIProxy.configure()
    .withAppId("your_app_id_from_dashboard")
    .withEnvironment(.production)
    .withLogLevel(.error)
    .build()
```

### 2. Make a Chat Request

#### SecureProxy (Context-aware conversations)
```swift
// Create a chat instance with context
let chat = SecureProxy(
    model: .openai(.gpt4),
    systemPrompt: "You are a helpful assistant"
)

// Send messages - context is automatically maintained
let response1 = try await chat.chat(message: "Hello! Tell me about Swift")
let response2 = try await chat.chat(message: "What are its main features?")

// Send with images
let imageData = UIImage(named: "example")?.jpegData(compressionQuality: 0.9)
let response = try await chat.chat(
    message: "What's in this image?",
    images: [imageData]
)
```

#### AIProxy (Direct API calls)
```swift
// OpenAI models
do {
    let response = try await AIProxy.openai.chat.completions.create(
        model: "gpt-4",
        messages: [
            .system("You are a helpful assistant"),
            .user("Hello! How can I use ProxyKit?")
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

### SecureProxy Example (Recommended for chat interfaces)
```swift
struct ChatView: View {
    @State private var messages: [(String, Bool)] = [] // (text, isUser)
    @State private var input = ""
    let chat = SecureProxy(model: .openai(.gpt4))
    
    var body: some View {
        VStack {
            ScrollView {
                ForEach(messages.indices, id: \.self) { index in
                    HStack {
                        if messages[index].1 {
                            Spacer()
                            Text(messages[index].0)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        } else {
                            Text(messages[index].0)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(10)
                            Spacer()
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            HStack {
                TextField("Type a message", text: $input)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Send") {
                    Task { await sendMessage() }
                }
                .disabled(input.isEmpty)
            }
            .padding()
        }
    }
    
    func sendMessage() async {
        let userMessage = input
        messages.append((userMessage, true))
        input = ""
        
        do {
            let response = try await chat.chat(message: userMessage)
            messages.append((response, false))
        } catch {
            messages.append(("Error: \(error.localizedDescription)", false))
        }
    }
}
```

### AIProxy Example (For custom implementations)
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
            let response = try await AIProxy.openai.chat.completions.create(
                model: "gpt-4",
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

Both SecureProxy and AIProxy support OpenAI and Anthropic models:

### SecureProxy
```swift
// OpenAI models
let gptChat = SecureProxy(model: .openai(.gpt4))
let turboChat = SecureProxy(model: .openai(.gpt35Turbo))

// Anthropic models
let claudeChat = SecureProxy(model: .anthropic(.claude3Opus))
let sonnetChat = SecureProxy(model: .anthropic(.claude3Sonnet))
```

### AIProxy
```swift
// OpenAI
try await AIProxy.openai.chat.completions.create(
    model: "gpt-4",
    messages: [...]
)

// Anthropic
try await AIProxy.anthropic.chat.completions.create(
    model: "claude-3-opus-20240229",
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

- Documentation: https://secureapikey.com/docs
- Issues: https://github.com/proxy-kit/ios-sdk/issues
- Dashboard: https://secureapikey.com