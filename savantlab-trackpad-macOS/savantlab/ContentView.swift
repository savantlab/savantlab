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
                Button(logger.isRecording ? "Stop recording" : "Start recording") {
                    if logger.isRecording {
                        logger.stopRecording()
                    } else {
                        logger.startRecording()
                    }
                }
                .keyboardShortcut(.space, modifiers: [])

                Text(logger.isRecording ? "● Recording" : "Idle")
                    .foregroundStyle(logger.isRecording ? .red : .secondary)
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
