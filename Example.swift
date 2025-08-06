//import Foundation
//import AIProxy
//
//// MARK: - Example Usage
//
//@main
//struct ExampleApp {
//    static func main() async {
//        do {
//            // Configure the SDK with builder pattern
//            try AIProxy.configure()
//                .withAppId("app_123...")  // Your app ID from dashboard
//                .withEnvironment(.production)
//                .withLogLevel(.debug)
//                .build()
//            
//            // Note: The SDK automatically handles session renewal!
//            // - Initial attestation happens on SDK configuration
//            // - Expired sessions are automatically renewed on API calls
//            // - No manual session management required
//            
//            // Example 1: Simple chat completion
//            try await simpleChatExample()
//            
//            // Example 2: Streaming chat completion
//            try await streamingChatExample()
//            
//            // Example 3: Error handling
//            await errorHandlingExample()
//            
//            // Example 4: Attestation observer
//            await attestationObserverExample()
//            
//        } catch {
//            print("Configuration failed: \(error)")
//        }
//    }
//    
//    // MARK: - Simple Chat Example
//    
//    static func simpleChatExample() async throws {
//        print("\n=== Simple Chat Example ===")
//        
//        // Example 1: Using string-based API for maximum flexibility
//        print("\n1. String-based API (any model):")
//        do {
//            let response = try await AIProxy.openai.chat.completions.create(
//                model: "gpt-4-1106-preview", // Latest GPT-4 Turbo
//                messages: [
//                    .system("You are a helpful assistant."),
//                    .user("What is the capital of France?")
//                ],
//                temperature: 0.7,
//                maxTokens: 100
//            )
//            
//            if let content = response.choices.first?.message.content {
//                print("Assistant: \(content)")
//            }
//        } catch {
//            print("Chat failed: \(error)")
//        }
//        
//        // Example 2: Using convenience constants
//        print("\n2. Using convenience constants:")
//        do {
//            let response = try await AIProxy.openai.chat.completions.create(
//                model: ChatModel.openai(.gpt35Turbo),
//                messages: [.user("Hello!")],
//                temperature: 0.7
//            )
//            
//            if let content = response.choices.first?.message.content {
//                print("Assistant: \(content)")
//            }
//        } catch {
//            print("Chat failed: \(error)")
//        }
//        
//        // Example 3: Using custom/new models not in constants
//        print("\n3. Using newer models:")
//        do {
//            // Use any new model without waiting for SDK updates
//            let response = try await AIProxy.openai.chat.completions.create(
//                model: "gpt-4-turbo-2024-04-09", // Hypothetical future model
//                messages: [.user("Tell me about the latest AI developments")],
//                maxTokens: 150
//            )
//            
//            if let content = response.choices.first?.message.content {
//                print("Assistant: \(content)")
//            }
//        } catch {
//            print("Chat failed: \(error)")
//        }
//    }
//    
//    // MARK: - Streaming Chat Example
//    
//    static func streamingChatExample() async throws {
//        print("\n=== Streaming Chat Example ===")
//        
//        // Example with Anthropic Claude
//        let stream = try await AIProxy.anthropic.chat.completions.stream(
//            model: "claude-3-opus-20240229", // Latest Claude model
//            messages: [
//                .user("Write a short poem about Swift programming")
//            ]
//        )
//        
//        print("Assistant: ", terminator: "")
//        for try await chunk in stream {
//            if let content = chunk.delta.content {
//                print(content, terminator: "")
//                fflush(stdout) // Flush output for real-time display
//            }
//        }
//        print("\n")
//    }
//    
//    // MARK: - Error Handling Example
//    
//    static func errorHandlingExample() async {
//        print("\n=== Error Handling Example ===")
//        
//        do {
//            let response = try await AIProxy.openai.chat.completions.create(
//                model: ChatModel.openai(.gpt4),
//                messages: [.user("Hello!")]
//            )
//            print("Success: \(response.id)")
//        } catch AIProxyError.attestationFailed(let reason) {
//            print("Attestation failed: \(reason)")
//            // Handle attestation failure - maybe show UI to retry
//        } catch AIProxyError.sessionExpired {
//            print("Session expired - SDK will automatically re-authenticate")
//            // Note: This error should rarely occur as SDK handles renewal automatically
//        } catch AIProxyError.networkError(let error) {
//            print("Network error: \(error.localizedDescription)")
//            // Handle network issues
//        } catch AIProxyError.providerError(let code, let message) {
//            print("Provider error \(code): \(message)")
//            // Handle provider-specific errors (OpenAI/Anthropic)
//        } catch AIProxyError.invalidAPIKey {
//            print("Invalid API key - please check dashboard configuration")
//        } catch {
//            print("Unexpected error: \(error)")
//        }
//    }
//    
//    // MARK: - Attestation Observer Example
//    
//    static func attestationObserverExample() async {
//        print("\n=== Attestation Observer Example ===")
//        
//        class MyAttestationObserver: AttestationObserver {
//            func attestationDidUpdate(status: AttestationStatus) {
//                switch status {
//                case .notStarted:
//                    print("Attestation not started")
//                case .inProgress:
//                    print("Attestation in progress...")
//                case .completed:
//                    print("Attestation completed successfully!")
//                case .failed(let error):
//                    print("Attestation failed: \(error)")
//                }
//            }
//            
//            func attestationDidFail(error: Error) {
//                print("Attestation observer notified of failure: \(error)")
//            }
//        }
//        
//        // In a real app, you might add this observer in your view controller
//        let observer = MyAttestationObserver()
//        // Note: In the real implementation, you'd access the attestation manager
//        // through the SDK and add the observer
//    }
//}
//
//// MARK: - SwiftUI Integration Example
//
//import SwiftUI
//
//struct ChatView: View {
//    @State private var messages: [ChatMessage] = []
//    @State private var inputText = ""
//    @State private var isLoading = false
//    @State private var errorMessage: String?
//    
//    var body: some View {
//        VStack {
//            // Messages list
//            ScrollView {
//                LazyVStack(alignment: .leading, spacing: 12) {
//                    ForEach(Array(messages.enumerated()), id: \.offset) { _, message in
//                        MessageBubble(message: message)
//                    }
//                }
//                .padding()
//            }
//            
//            // Input area
//            HStack {
//                TextField("Type a message...", text: $inputText)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//                    .disabled(isLoading)
//                
//                Button(action: sendMessage) {
//                    Image(systemName: "paperplane.fill")
//                        .foregroundColor(isLoading ? .gray : .blue)
//                }
//                .disabled(isLoading || inputText.isEmpty)
//            }
//            .padding()
//            
//            // Error message
//            if let error = errorMessage {
//                Text(error)
//                    .foregroundColor(.red)
//                    .font(.caption)
//                    .padding(.horizontal)
//            }
//        }
//        .onAppear {
//            setupAIProxy()
//        }
//    }
//    
//    private func setupAIProxy() {
//        do {
//            try AIProxy.configure()
//                .withAppId("your_app_id")
//                .withEnvironment(.production)
//                .build()
//        } catch {
//            errorMessage = "Failed to configure AIProxy: \(error.localizedDescription)"
//        }
//    }
//    
//    private func sendMessage() {
//        let userMessage = ChatMessage.user(inputText)
//        messages.append(userMessage)
//        inputText = ""
//        isLoading = true
//        errorMessage = nil
//        
//        Task {
//            do {
//                // You can use any provider/model combination
//                let response = try await AIProxy.openai.chat.completions.create(
//                    model: "gpt-3.5-turbo", // or "gpt-4", etc.
//                    messages: messages,
//                    temperature: 0.7
//                )
//                
//                if let assistantMessage = response.choices.first?.message {
//                    await MainActor.run {
//                        messages.append(assistantMessage)
//                        isLoading = false
//                    }
//                }
//            } catch {
//                await MainActor.run {
//                    errorMessage = error.localizedDescription
//                    isLoading = false
//                }
//            }
//        }
//    }
//}
//
//struct MessageBubble: View {
//    let message: ChatMessage
//    
//    var body: some View {
//        HStack {
//            if message.role == .user {
//                Spacer()
//            }
//            
//            Text(message.content)
//                .padding()
//                .background(message.role == .user ? Color.blue : Color.gray.opacity(0.2))
//                .foregroundColor(message.role == .user ? .white : .primary)
//                .cornerRadius(12)
//            
//            if message.role != .user {
//                Spacer()
//            }
//        }
//    }
//}
