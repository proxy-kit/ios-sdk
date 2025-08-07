//
//  AIKitTestAppApp.swift
//  AIKitTestApp
//
//  Created by Pawan Dixit on 23/07/2025.
//

import SwiftUI
import SecureProxy

@main
struct AIKitTestAppApp: App {
    init() {
        do {
            try SecureProxy.configure(appid: "cmdrsm6dz0009bzxn0gcopuse")
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
