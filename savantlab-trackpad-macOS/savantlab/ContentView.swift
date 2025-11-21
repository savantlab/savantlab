//
//  ContentView.swift
//  savantlab
//
//  Created by Stephanie King on 11/15/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    #if os(macOS)
    @StateObject private var logger = TrackpadEventLogger()
    #endif

    var body: some View {
        #if os(macOS)
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                if logger.isPaused {
                    Button("Start Session") {
                        logger.startSession()
                    }
                } else {
                    Button("Stop") {
                        logger.stopSession()
                    }
                    
                    Button("Save") {
                        logger.saveSession()
                    }
                    .keyboardShortcut("s", modifiers: .command)
                }

                Text(logger.isPaused ? "Ready" : "● Logging")
                    .foregroundStyle(logger.isPaused ? .secondary : Color.green)
            }

            Text("Events recorded: \(logger.eventCount)")
                .font(.subheadline)

            Text("Last event: \(logger.lastEventDescription)")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if let url = logger.sessionFileURL {
                Text("Session file: \(url.path)")
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
            }

            Divider()

            Text("Move the pointer over this window and use the trackpad (move, scroll, pinch, rotate, swipe) while recording is on.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            TrackpadCaptureView(logger: logger)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
        }
        .padding()
        #else
        Text("Trackpad recording is only available on macOS.")
            .padding()
        #endif
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
