//
//  AIKitTestAppApp.swift
//  AIKitTestApp
//
//  Created by Pawan Dixit on 23/07/2025.
//

import SwiftUI
import SecureProxy

@main
struct ProxyKitTestApp: App {
    init() {
        do {
            try ProxyKit.configure(appid: "paste-your-app-id-here")
        } catch {
            assertionFailure(error.localizedDescription)
        }
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
