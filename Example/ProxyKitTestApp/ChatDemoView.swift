//
//  ChatDemoView.swift
//  AIKitTestApp
//
//  Created by Pawan Dixit on 02/08/2025.
//

import SwiftUI
import SecureProxy

struct ChatDemoView: View {
    @Environment(ProxyKit.self) var chatProxy

    @State private var userPrompt = ""
    @State private var systemPrompt = "You are a helpful assistant"
    @State private var chatResponse: String? = nil
    @State private var isProcessing = false
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Chat with SecureProxy")
                .font(.title2.bold())

            TextField("System Prompt", text: $systemPrompt)
                .textFieldStyle(.roundedBorder)

            TextField("Your prompt", text: $userPrompt)
                .textFieldStyle(.roundedBorder)

            Button(action: runChatDemo) {
                Label("Send Chat", systemImage: "paperplane")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isProcessing || userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let chatResponse {
                Text("Response:")
                    .font(.headline)
                Text(chatResponse)
                    .padding(.bottom, 4)
                    .font(.body)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            }

            if let error = errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .bold()
            }

            if isProcessing {
                ProgressView()
                    .padding(.vertical)
            }
        }
        .padding(.vertical)
    }

    func runChatDemo() {
        isProcessing = true
        errorMessage = nil
        chatResponse = nil
        Task {
            do {
                let result = try await chatProxy.chat(message: userPrompt)
                await MainActor.run {
                    chatResponse = result
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
            await MainActor.run { isProcessing = false }
        }
    }
}


#Preview {
    ChatDemoView()
}
