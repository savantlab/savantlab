//
//  HarmonyTrackpadLabView.swift
//  savantlab-trackpad-macOS
//
//  A dedicated window that embeds Mr. Doob's Harmony in a WKWebView and
//  logs trackpad finger activity via NSTouch while you draw.
//

import SwiftUI

#if os(macOS)
import AppKit

struct HarmonyTrackpadLabView: View {
    @StateObject private var logger = TrackpadEventLogger()
    @StateObject private var screenRecorder = ScreenRecorder()
    @State private var clearCanvasTrigger = 0
    @State private var canvasView: DrawingCanvasView?

    var body: some View {
        VStack(spacing: 16) {
            // Instructions at the top
            VStack(alignment: .leading, spacing: 8) {
                Text("Trackpad Drawing Lab")
                    .font(.title2.bold())
                
                Text("Instructions:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("1. Press 'Start Session' to begin logging")
                    Text("2. Draw in the canvas using your trackpad")
                    Text("3. Press 'Stop' to pause without saving, or 'Save' (⌘S) to save")
                    Text("4. Press 'Start Session' again to begin a new session")
                }
                .font(.body)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            // Timer and controls
            HStack(spacing: 16) {
                if logger.isPaused {
                    Button(action: {
                        logger.startSession()
                        startScreenRecording()
                    }) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text("Start Session")
                        }
                        .font(.title3)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                } else {
                    Button(action: {
                        logger.stopSession()
                        screenRecorder.stopRecording()
                    }) {
                        HStack {
                            Image(systemName: "stop.circle.fill")
                            Text("Stop")
                        }
                        .font(.title3)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    
                    Button(action: {
                        logger.saveSession()
                        screenRecorder.stopRecording()
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save")
                        }
                        .font(.title3)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .keyboardShortcut("s", modifiers: .command)
                }
                
                Button(action: {
                    clearCanvasTrigger += 1
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Clear Canvas")
                    }
                    .font(.title3)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Session:")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(formatDuration(logger.sessionDuration))
                            .font(.title2.monospacedDigit().bold())
                            .foregroundColor(logger.isPaused ? .secondary : .green)
                    }
                    
                    Text(logger.isPaused ? "Ready" : "● Logging")
                        .font(.caption)
                        .foregroundColor(logger.isPaused ? .secondary : .green)
                }
                
                Spacer()
                
                if let url = logger.sessionFileURL {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Session file:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(url.lastPathComponent)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)

            // Drawing canvas
            NativeDrawingView(logger: logger, clearTrigger: clearCanvasTrigger, canvasViewRef: $canvasView)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
                .border(Color.gray.opacity(0.3), width: 2)
                .cornerRadius(4)
        }
        .padding()
        .frame(minWidth: 900, minHeight: 700)
        .onChange(of: canvasView) { newCanvasView in
            // Setup canvas save callback when canvas is ready
            logger.saveCanvasImage = { url in
                return newCanvasView?.saveAsImage(to: url) ?? false
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let milliseconds = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, milliseconds)
    }
    
    private func startScreenRecording() {
        guard let sessionURL = logger.sessionFileURL else { return }
        let videoURL = sessionURL.deletingPathExtension().appendingPathExtension("mov")
        screenRecorder.startRecording(outputURL: videoURL)
    }
}

#else

struct HarmonyTrackpadLabView: View {
    var body: some View {
        Text("Harmony trackpad lab is only available on macOS.")
    }
}

#endif
