//
//  TrackpadEventLogger.swift
//  savantlab-trackpad-macOS
//
//  Logs mouse/trackpad events (move, scroll, basic gestures) to a session file.
//

import Foundation
import SwiftUI
import Combine

#if os(macOS)
import AppKit

final class TrackpadEventLogger: ObservableObject {
    @Published var isRecording: Bool = false
    @Published var eventCount: Int = 0
    @Published var lastEventDescription: String = "No events yet"
    @Published var sessionFileURL: URL?
    @Published var recordingDuration: TimeInterval = 0

    private var fileHandle: FileHandle?
    private var recordingStartTime: Date?
    private var timerTask: Task<Void, Never>?
    var saveCanvasImage: ((URL) -> Bool)?

    private static let timestampFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.timeZone = .current
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    func startRecording() {
        print("[Logger] startRecording called")
        guard !isRecording else {
            print("[Logger] Already recording, ignoring")
            return
        }

        do {
            let fileURL = try makeNewSessionFileURL()
            sessionFileURL = fileURL

            if !FileManager.default.fileExists(atPath: fileURL.deletingLastPathComponent().path) {
                try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            }

            if !FileManager.default.fileExists(atPath: fileURL.path) {
                FileManager.default.createFile(atPath: fileURL.path, contents: nil)
            }

            fileHandle = try FileHandle(forWritingTo: fileURL)
            try fileHandle?.seekToEnd()

            // Unified header for both pointer/gesture events and per-finger touches.
            let header = [
                "timestamp_local",
                "event_type",
                "x",
                "y",
                "deltaX",
                "deltaY",
                "phase",
                "scrollDeltaX",
                "scrollDeltaY",
                "touch_id",
                "touch_phase",
                "touch_normalizedX",
                "touch_normalizedY",
                "touch_isResting"
            ].joined(separator: ",") + "\n"

            if let data = header.data(using: .utf8) {
                fileHandle?.write(data)
            }

            eventCount = 0
            lastEventDescription = "Recording started"
            recordingStartTime = Date()
            recordingDuration = 0
            isRecording = true
            print("[Logger] Recording started successfully. Session file: \(fileURL.path)")
            
            // Start simple timer task
            timerTask = Task { @MainActor [weak self] in
                while let self = self, self.isRecording, let startTime = self.recordingStartTime {
                    self.recordingDuration = Date().timeIntervalSince(startTime)
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                }
            }
        } catch {
            lastEventDescription = "Failed to start recording: \(error.localizedDescription)"
            isRecording = false
            fileHandle = nil
        }
    }

    func stopRecording() {
        isRecording = false
        timerTask?.cancel()
        timerTask = nil
        recordingStartTime = nil
        recordingDuration = 0  // Reset timer to 00:00.0
        try? fileHandle?.close()
        fileHandle = nil
        
        // Save canvas image
        if let sessionURL = sessionFileURL {
            let imageURL = sessionURL.deletingPathExtension().appendingPathExtension("png")
            if let saveImage = saveCanvasImage, saveImage(imageURL) {
                print("[Logger] Canvas image saved to: \(imageURL.path)")
            }
            
            // Copy both CSV and PNG to user's Documents folder
            copyToUserDocuments(csvURL: sessionURL, imageURL: imageURL)
        }
        
        lastEventDescription = "Recording stopped"
    }

    /// Handle generic pointer / scroll / gesture events.
    func handle(event: NSEvent) {
        guard isRecording else { return }

        let now = Date()
        let ts = Self.timestampFormatter.string(from: now)

        let typeDescription: String
        switch event.type {
        case .mouseMoved: typeDescription = "mouseMoved"
        case .leftMouseDragged: typeDescription = "leftMouseDragged"
        case .rightMouseDragged: typeDescription = "rightMouseDragged"
        case .otherMouseDragged: typeDescription = "otherMouseDragged"
        case .scrollWheel: typeDescription = "scrollWheel"
        case .magnify: typeDescription = "magnify"
        case .rotate: typeDescription = "rotate"
        case .swipe: typeDescription = "swipe"
        default: typeDescription = "other(\(event.type.rawValue))"
        }

        let location = event.locationInWindow
        let deltaX = event.deltaX
        let deltaY = event.deltaY
        let phase = event.phase.rawValue
        let scrollDeltaX = event.scrollingDeltaX
        let scrollDeltaY = event.scrollingDeltaY

        let fields: [String] = [
            ts,
            typeDescription,
            String(describing: location.x),
            String(describing: location.y),
            String(describing: deltaX),
            String(describing: deltaY),
            String(describing: phase),
            String(describing: scrollDeltaX),
            String(describing: scrollDeltaY),
            "", // touch_id
            "", // touch_phase
            "", // touch_normalizedX
            "", // touch_normalizedY
            ""  // touch_isResting
        ]

        let line = fields.joined(separator: ",") + "\n"

        if let data = line.data(using: .utf8) {
            fileHandle?.write(data)
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.eventCount += 1
            self.lastEventDescription = "#\(self.eventCount) \(typeDescription) at (\(String(format: "%.1f", location.x)), \(String(format: "%.1f", location.y)))"
        }
    }

    /// Handle per-finger NSTouch events from HarmonyTouchHostingView.
    func handleTouches(event: NSEvent) {
        guard isRecording else { return }

        let now = Date()
        let ts = Self.timestampFormatter.string(from: now)

        let touches = event.touches(matching: .any, in: nil)
        guard !touches.isEmpty else { return }

        for touch in touches {
            let touchID = touch.identity.hash
            let pos = touch.normalizedPosition
            let phase = touch.phase.rawValue
            let isResting = touch.isResting

            let fields: [String] = [
                ts,
                "touch", // event_type
                "",      // x (not applicable – use normalized instead)
                "",      // y
                "",      // deltaX
                "",      // deltaY
                String(describing: phase),
                "",      // scrollDeltaX
                "",      // scrollDeltaY
                String(describing: touchID),
                String(describing: phase),
                String(describing: pos.x),
                String(describing: pos.y),
                String(describing: isResting)
            ]

            let line = fields.joined(separator: ",") + "\n"

            if let data = line.data(using: .utf8) {
                fileHandle?.write(data)
            }
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.eventCount += touches.count
            self.lastEventDescription = "#\(self.eventCount) touches (latest: phase=\(event.phase.rawValue), count=\(touches.count))"
        }
    }

    private func makeNewSessionFileURL() throws -> URL {
        let fm = FileManager.default
        let baseDir = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let folder = baseDir.appendingPathComponent("savantlab-trackpad-sessions", isDirectory: true)

        let df = DateFormatter()
        df.locale = Locale.current
        df.timeZone = TimeZone.current
        df.dateFormat = "yyyyMMdd-HHmmss"
        let filename = "session-\(df.string(from: Date())).csv"

        return folder.appendingPathComponent(filename)
    }
    
    private func copyToUserDocuments(csvURL: URL, imageURL: URL) {
        let fm = FileManager.default
        
        // Use home directory directly to bypass sandbox
        let homeDir = NSHomeDirectory()
        let targetFolder = URL(fileURLWithPath: homeDir)
            .appendingPathComponent("Documents")
            .appendingPathComponent("savantlab-trackpad-sessions")
        
        // Create folder if needed
        try? fm.createDirectory(at: targetFolder, withIntermediateDirectories: true)
        
        // Copy CSV
        let targetCSV = targetFolder.appendingPathComponent(csvURL.lastPathComponent)
        try? fm.removeItem(at: targetCSV) // Remove if exists
        do {
            try fm.copyItem(at: csvURL, to: targetCSV)
            print("[Logger] Copied CSV to: \(targetCSV.path)")
        } catch {
            print("[Logger] Failed to copy CSV: \(error)")
        }
        
        // Copy PNG if it exists
        if fm.fileExists(atPath: imageURL.path) {
            let targetPNG = targetFolder.appendingPathComponent(imageURL.lastPathComponent)
            try? fm.removeItem(at: targetPNG) // Remove if exists
            do {
                try fm.copyItem(at: imageURL, to: targetPNG)
                print("[Logger] Copied PNG to: \(targetPNG.path)")
            } catch {
                print("[Logger] Failed to copy PNG: \(error)")
            }
        }
    }
}

#endif
