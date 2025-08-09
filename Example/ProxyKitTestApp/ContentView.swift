//
//  ContentView.swift
//  AIKitTestApp
//
//  Created by Pawan Dixit on 23/07/2025.
//

import SwiftUI
import SecureProxy

struct ContentView: View {
    enum DemoSelection: String, CaseIterable, Identifiable {
        case chat = "Chat"
        case vision = "Vision"
        var id: String { rawValue }
    }

    @State private var selection: DemoSelection = .chat

    @State private var chatProxy = ProxyKit(model: .openai(.gpt4))
    @State private var visionProxy = ProxyKit(model: .openai(.gpt4))

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("🔐 SecureProxy API Showcase")
                    .font(.largeTitle.bold())
                    .padding(.top)

                Picker("Demo", selection: $selection) {
                    ForEach(DemoSelection.allCases) { demo in
                        Text(demo.rawValue).tag(demo)
                    }
                }
                .pickerStyle(.segmented)

                switch selection {
                case .chat:
                    ChatDemoView()
                        .environment(chatProxy)
                case .vision:
                    VisionDemoView()
                        .environment(visionProxy)
                }
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
