import AIProxy
@_exported import AIProxyCore
import Foundation

#if canImport(UIKit)
    import UIKit
#endif

#if canImport(SwiftUI)
    import SwiftUI
#endif

open class SecureProxyBase {

    public struct ChatOverrides {
        public var model: ChatModel?
        public var systemPrompt: String?
        public init(model: ChatModel? = nil, systemPrompt: String? = nil) {
            self.model = model
            self.systemPrompt = systemPrompt
        }
    }

    private var messages: [ChatMessage]
    private let defaultSystemPrompt: String
    private let defaultModel: ChatModel

    /// Create a new ProxyKit chat context
    /// - Parameters:
    ///   - systemPrompt: The initial system prompt (default: "You are a helpful assistant")
    ///   - model: The default chat model to use (default: .gpt4)
    public init(
        model: ChatModel = .openai(.gpt4),
        systemPrompt: String = "You are a helpful assistant"
    ) {
        self.defaultSystemPrompt = systemPrompt
        self.defaultModel = model
        self.messages = []
    }

    /// Send a message, maintaining context within this ProxyKit instance
    /// - Parameters:
    ///   - message: The user's message
    ///   - overrides: Optional overrides for the chat model and system prompt for this call
    ///   - images: Optional array of image data to send along with the message (multi-modal support)
    /// - Returns: The assistant's reply
    @discardableResult
    public func chat(
        message: String,
        images: [Data]? = nil,
        overrides: ChatOverrides = ChatOverrides()
    ) async throws -> String {
        let model = overrides.model ?? defaultModel

        // Add system prompt if starting a new session
        if messages.isEmpty {
            let prompt = overrides.systemPrompt ?? defaultSystemPrompt
            messages.append(.system(prompt))
        }

        // Add the current user message, handling optional images as parts
        if let images = images, !images.isEmpty {
            var parts: [ContentPart] = [.text(message)]
            for imageData in images {
                parts.append(
                    .imageBase64(
                        data: imageData.base64EncodedString(),
                        mimeType: "image/jpeg"
                    )
                )
            }
            messages.append(.user(parts))
        } else {
            messages.append(.user(message))
        }

        let response: ChatResponse
        switch model {
        case .openai(_):
            response = try await AIProxy.openai.chat.completions.create(
                model: model.rawValue,
                messages: messages
            )
        case .anthropic(_):
            response = try await AIProxy.anthropic.chat.completions.create(
                model: model.rawValue,
                messages: messages
            )
        default:
            fatalError("Custom providers not yet supported")
            break
        }

        guard let assistantMessage = response.choices.first?.message else {
            throw AIProxyError.providerError(
                code: "no_response",
                message: "No assistant message received."
            )
        }

        // Extract string content from the message
        let messageText: String
        switch assistantMessage.content {
        case .string(let text):
            messageText = text
        case .parts(let parts):
            // For multi-modal responses, concatenate text parts
            messageText = parts.compactMap { part in
                if case .text(let text) = part {
                    return text
                }
                return nil
            }.joined(separator: " ")
        }

        // Update conversation context
        messages.append(assistantMessage)

        return messageText
    }

    #if canImport(UIKit)
        /// Send a message with associated UIKit images, maintaining context within this ProxyKit instance
        /// - Parameters:
        ///   - message: The user's message
        ///   - uiImages: Array of UIImage to send along with the message
        ///   - overrides: Optional overrides for the chat model and system prompt for this call
        /// - Returns: The assistant's reply
        @discardableResult
        public func chat(
            message: String,
            uiImages: [UIImage],
            overrides: ChatOverrides = ChatOverrides()
        ) async throws -> String {
            let imageDatas = uiImages.compactMap {
                Self.convertUIImageToJPEGData($0)
            }
            return try await chat(
                message: message,
                images: imageDatas,
                overrides: overrides
            )
        }
    #endif

    #if canImport(UIKit) && canImport(SwiftUI)
        /// Send a message with associated SwiftUI images, maintaining context within this ProxyKit instance
        /// - Parameters:
        ///   - message: The user's message
        ///   - swiftUIImages: Array of SwiftUI Image to send along with the message
        ///   - overrides: Optional overrides for the chat model and system prompt for this call
        /// - Returns: The assistant's reply
        @discardableResult
        public func chat(
            message: String,
            swiftUIImages: [Image],
            overrides: ChatOverrides = ChatOverrides()
        ) async throws -> String {
            let imageDatas = swiftUIImages.compactMap {
                Self.convertSwiftUIImageToJPEGData($0)
            }
            return try await chat(
                message: message,
                images: imageDatas,
                overrides: overrides
            )
        }
    #endif

    /// Reset the conversation context for this ProxyKit instance
    public func reset() {
        messages.removeAll()
    }

    /// Global configuration for ProxyKit (forwards to AIProxy)
    /// - Parameters:
    ///   - appid: The application ID required for configuration
    /// - Returns: Error if configuration failed, nil otherwise
    public static func configure(appid: String) -> Error? {
        do {
            try AIProxy.configure()
                .withAppId(appid)
                .build()
            return nil
        } catch {
            return error
        }
    }

    #if canImport(UIKit)
        private static func convertUIImageToJPEGData(_ image: UIImage) -> Data?
        {
            image.jpegData(compressionQuality: 0.9)
        }
    #endif

    #if canImport(UIKit) && canImport(SwiftUI)
        private static func convertSwiftUIImageToJPEGData(_ image: Image)
            -> Data?
        {
            // Attempt to extract UIImage from SwiftUI Image
            // This approach uses a UIView hosting method and snapshot

            struct ImageRendererView: UIViewRepresentable {
                let image: Image
                let completion: (UIImage?) -> Void

                func makeUIView(context: Context) -> UIView {
                    let hosting = UIHostingController(rootView: image)
                    hosting.view.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
                    hosting.view.backgroundColor = .clear
                    DispatchQueue.main.async {
                        let renderer = UIGraphicsImageRenderer(
                            size: hosting.view.bounds.size
                        )
                        let uiImage = renderer.image { _ in
                            hosting.view.drawHierarchy(
                                in: hosting.view.bounds,
                                afterScreenUpdates: true
                            )
                        }
                        completion(uiImage)
                    }
                    return hosting.view
                }

                func updateUIView(_ uiView: UIView, context: Context) {}
            }

            // Use a semaphore to wait synchronously for the UIImage extraction on main thread
            var resultImage: UIImage?
            let semaphore = DispatchSemaphore(value: 0)

            DispatchQueue.main.async {
                let hosting = UIHostingController(rootView: image)
                hosting.view.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
                hosting.view.backgroundColor = .clear

                let renderer = UIGraphicsImageRenderer(
                    size: hosting.view.bounds.size
                )
                let uiImage = renderer.image { _ in
                    hosting.view.drawHierarchy(
                        in: hosting.view.bounds,
                        afterScreenUpdates: true
                    )
                }
                resultImage = uiImage
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .now() + 1.0)  // wait max 1 second

            return resultImage?.jpegData(compressionQuality: 0.9)
        }
    #endif
}
