import AIProxy
@_exported import ProxyKitCore
import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if canImport(SwiftUI)
import SwiftUI
#endif

open class SecureProxyBase {

    private let defaultModel: ChatModel
    private let defaultSystemPrompt: String
    
    private var messages: [ChatMessage]
    
    /// Create a new ProxyKit chat context
    /// - Parameters:
    ///   - systemPrompt: The initial system prompt (default: "You are a helpful assistant")
    ///   - model: The default chat model to use (default: .gpt4)
    public init(
        model: ChatModel,
        systemPrompt: String = "You are a helpful assistant"
    ) {
        self.defaultSystemPrompt = systemPrompt
        self.defaultModel = model
        self.messages = []
    }

    /// Send a message, maintaining context within this ProxyKit instance
    /// - Parameters:
    ///   - message: The user's message
    ///   - images: Optional array of images or data to send along with the message (multi-modal support)
    ///   - overrides: Optional overrides for the chat model and system prompt for this call
    /// - Returns: The assistant's reply
    @discardableResult
    public func chat(
        message: String,
        images: [InputImage]? = nil,
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
            for image in images {
                if let data = Self.convertChatInputImageToData(image) {
                    parts.append(
                        .imageBase64(
                            data: data.base64EncodedString(),
                            mimeType: "image/jpeg"
                        )
                    )
                }
            }
            messages.append(.user(parts))
        } else {
            messages.append(.user(message))
        }

        let response: ChatResponse
        switch model {
        case .openai(_):
            response = try await ProxyKitAdvance.openai.chat.completions.create(
                model: model.rawValue,
                messages: messages
            )
        case .anthropic(_):
            response = try await ProxyKitAdvance.anthropic.chat.completions.create(
                model: model.rawValue,
                messages: messages
            )
        default:
            fatalError("Custom providers not yet supported")
            break
        }

        guard let assistantMessage = response.choices.first?.message else {
            throw ProxyKitError.providerError(
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

    /// Reset the conversation context for this ProxyKit instance
    public func reset() {
        messages.removeAll()
    }

    /// Global configuration for ProxyKit (forwards to AIProxy)
    /// - Parameters:
    ///   - appid: The application ID required for configuration
    /// - Returns: Error if configuration failed, nil otherwise
    public static func configure(appid: String) throws {
        try ProxyKitAdvance.configure()
            .withAppId(appid)
            .withEnvironment(.production)
            .withLogLevel(.error)
            .build()
    }
}

extension SecureProxyBase {
    
    public enum InputImage {
        case data(Data)
        #if canImport(UIKit)
        case image(UIImage, compressionQuality: CGFloat = 0.9)
        #endif
        #if canImport(SwiftUI) && canImport(UIKit)
        case swiftUIImage(Image, compressionQuality: CGFloat = 0.9)
        #endif
    }

    public struct ChatOverrides {
        public var model: ChatModel?
        public var systemPrompt: String?
        public init(model: ChatModel? = nil, systemPrompt: String? = nil) {
            self.model = model
            self.systemPrompt = systemPrompt
        }
    }
    
    private static func convertChatInputImageToData(_ image: InputImage) -> Data? {
        switch image {
        case .data(let data):
            return data
        #if canImport(UIKit)
        case .image(let uiImage, let compressionQuality):
            return uiImage.jpegData(compressionQuality: compressionQuality)
        #endif
        #if canImport(SwiftUI) && canImport(UIKit)
        case .swiftUIImage(let swiftUIImage, let compressionQuality):
            var resultImage: UIImage?
            let semaphore = DispatchSemaphore(value: 0)
            DispatchQueue.main.async {
                let hosting = UIHostingController(rootView: swiftUIImage)
                hosting.view.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
                hosting.view.backgroundColor = .clear
                let renderer = UIGraphicsImageRenderer(size: hosting.view.bounds.size)
                let uiImage = renderer.image { _ in
                    hosting.view.drawHierarchy(in: hosting.view.bounds, afterScreenUpdates: true)
                }
                resultImage = uiImage
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .now() + 1.0)
            return resultImage?.jpegData(compressionQuality: compressionQuality)
        #endif
        }
    }
}
