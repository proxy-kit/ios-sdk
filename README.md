# ProxyKit iOS SDK

Secure AI proxy for iOS apps. Access OpenAI and Anthropic models without exposing API keys.

## Installation

Add to your Xcode project:
1. **File → Add Package Dependencies**
2. Enter: `https://github.com/proxy-kit/ios-sdk`
3. Click **Add Package**

## Setup

### 1. Enable App Attest

In Xcode:
1. Select your target
2. Go to **Signing & Capabilities**
3. Add **App Attest** capability

### 2. Initialize

```swift
import ProxyKitCore

@main
struct MyApp: App {
    init() {
        ProxyKit.configure(appId: "app_xxxxxxxxxxxxx") // Get from dashboard
    }
}
```

## Usage

### Basic Chat

```swift
let response = try await ProxyKit.chat.completions.create(
    model: "gpt-4",
    messages: [
        ChatMessage(role: "user", content: "Hello!")
    ]
)

print(response.choices.first?.message.content ?? "")
```

### Streaming

```swift
for try await chunk in ProxyKit.chat.completions.stream(
    model: "gpt-4", 
    messages: messages
) {
    if let content = chunk.choices.first?.delta.content {
        print(content, terminator: "")
    }
}
```

### With Context (SecureProxy)

Keep conversation history automatically:

```swift
import SecureProxy

let chat = SecureProxy(model: .openai(.gpt4))

// Remembers previous messages
let response1 = try await chat.chat(message: "What's Swift?")
let response2 = try await chat.chat(message: "Tell me more") // Knows context
```

## SwiftUI Example

```swift
import SwiftUI
import SecureProxy

struct ChatView: View {
    @State private var messages: [String] = []
    @State private var input = ""
    let chat = SecureProxy(model: .openai(.gpt4))
    
    var body: some View {
        VStack {
            ScrollView {
                ForEach(messages, id: \.self) { message in
                    Text(message)
                        .padding()
                }
            }
            
            HStack {
                TextField("Message", text: $input)
                Button("Send") {
                    Task {
                        let userMessage = input
                        messages.append("You: \(userMessage)")
                        input = ""
                        
                        if let response = try? await chat.chat(message: userMessage) {
                            messages.append("AI: \(response)")
                        }
                    }
                }
            }
            .padding()
        }
    }
}
```

## Error Handling

```swift
do {
    let response = try await ProxyKit.chat.completions.create(...)
} catch {
    print("Error: \(error)")
}
```

## Requirements

- iOS 16.0+
- Real device (simulator won't work for attestation)

## Troubleshooting

**Attestation fails?**
- Check App Attest is enabled
- Verify app ID matches dashboard
- Use real device, not simulator

**Need help?**
- [Documentation](https://docs.proxykit.dev)
- [Dashboard](https://app.proxykit.dev)

## License

MIT