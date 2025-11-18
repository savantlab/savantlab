//
//  savantlabApp.swift
//  savantlab
//
//  Created by Stephanie King on 11/15/25.
//

import SwiftUI
import SwiftData

@main
struct savantlabApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        // Harmony lab window: embeds Harmony in a WKWebView and logs trackpad touches.
        #if os(macOS)
        WindowGroup {
            HarmonyTrackpadLabView()
        }
        .modelContainer(sharedModelContainer)
        #endif

        // Optional: Basic trackpad logging window (available via Window menu).
        WindowGroup("Trackpad Capture") {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
