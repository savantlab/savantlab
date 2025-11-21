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
    @Published var eventCount: Int = 0
    @Published var lastEventDescription: String = "Waiting to start..."
    @Published var sessionFileURL: URL?
    @Published var sessionDuration: TimeInterval = 0
    @Published var isPaused: Bool = true

    private var fileHandle: FileHandle?
    private var sessionStartTime: Date?
    private var timerTask: Task<Void, Never>?
    var saveCanvasImage: ((URL) -> Bool)?

    private static let timestampFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.timeZone = .current
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    
    init() {
        // Don't start automatically - wait for user to press start
    }

    func startSession() {
        print("[Logger] ===== Starting new session =====")

        do {
            print("[Logger] Creating session file URL...")
            let fileURL = try makeNewSessionFileURL()
            print("[Logger] Session URL created: \(fileURL.path)")
            sessionFileURL = fileURL
            print("[Logger] Checking/creating directory...")

            if !FileManager.default.fileExists(atPath: fileURL.deletingLastPathComponent().path) {
                try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                print("[Logger] Directory created")
            } else {
                print("[Logger] Directory exists")
            }

            print("[Logger] Creating file with header...")
            
            // Write header directly to create persistent file
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
            
            // Use Data.write to create persistent file
            if let headerData = header.data(using: .utf8) {
                try headerData.write(to: fileURL, options: [.atomic])
                print("[Logger] File created with header: \(fileURL.path)")
            }
            
            // Verify file exists
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                throw NSError(domain: "TrackpadLogger", code: 1, userInfo: [NSLocalizedDescriptionKey: "File creation failed"])
            }
            
            // Open file handle and KEEP IT OPEN for writing
            fileHandle = try FileHandle(forWritingTo: fileURL)
            try fileHandle?.seekToEnd()
            print("[Logger] File handle opened for writing")

            eventCount = 0
            lastEventDescription = "Session started"
            sessionStartTime = Date()
            sessionDuration = 0
            isPaused = false
            print("[Logger] Session started successfully. File: \(fileURL.path)")
            
            // Start timer task
            timerTask = Task { @MainActor [weak self] in
                while let self = self, let startTime = self.sessionStartTime {
                    self.sessionDuration = Date().timeIntervalSince(startTime)
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                }
            }
        } catch {
            lastEventDescription = "Failed to start session: \(error.localizedDescription)"
            print("[Logger] ERROR: \(error)")
            fileHandle = nil
        }
    }

    func stopSession() {
        print("[Logger] ===== Stopping session (no save) =====")
        
        // Cancel timer task
        timerTask?.cancel()
        timerTask = nil
        sessionStartTime = nil
        isPaused = true
        
        // Close current file
        try? fileHandle?.close()
        fileHandle = nil
        
        lastEventDescription = "Session stopped. Ready to start new session."
    }
    
    func saveSession() {
        print("[Logger] ===== Saving and stopping session =====")
        
        guard let sessionURL = sessionFileURL else {
            print("[Logger] ERROR: No session URL to save")
            return
        }
        
        // Cancel timer task
        timerTask?.cancel()
        timerTask = nil
        sessionStartTime = nil
        isPaused = true
        
        // Close current file and verify it exists
        if let fh = fileHandle {
            print("[Logger] Synchronizing file...")
            try? fh.synchronize()  // Force write to disk
            print("[Logger] Closing file...")
            try? fh.close()
            fileHandle = nil
            
            // Verify file exists after close
            let fm = FileManager.default
            if fm.fileExists(atPath: sessionURL.path) {
                let attrs = try? fm.attributesOfItem(atPath: sessionURL.path)
                let size = attrs?[.size] as? UInt64 ?? 0
                print("[Logger] ✓ File persisted: \(sessionURL.path) (\(size) bytes)")
            } else {
                print("[Logger] ⚠️ WARNING: File disappeared after close: \(sessionURL.path)")
            }
        } else {
            fileHandle = nil
        }
        
        // Save canvas image
        let imageURL = sessionURL.deletingPathExtension().appendingPathExtension("png")
        if let saveImage = saveCanvasImage, saveImage(imageURL) {
            print("[Logger] Canvas image saved to: \(imageURL.path)")
        }
        
        // DISABLED: Don't copy files - keep them only in container
        // DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        //     self?.copyToUserDocuments(csvURL: sessionURL, imageURL: imageURL)
        // }
        
        // DON'T clear sessionFileURL - keep it for reference
        lastEventDescription = "Session saved. Ready to start new session."
    }

    /// Handle generic pointer / scroll / gesture events.
    func handle(event: NSEvent) {
        guard !isPaused, sessionFileURL != nil else {
            print("[Logger] handle() blocked - isPaused: \(isPaused), hasURL: \(sessionFileURL != nil)")
            return
        }

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
        
        // Mouse drag events don't have phase or scrolling deltas
        // Only scroll/gesture events have these properties
        let phase: UInt64 = 0
        let scrollDeltaX: CGFloat = 0.0
        let scrollDeltaY: CGFloat = 0.0

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

        if let data = line.data(using: .utf8), let url = sessionFileURL {
            // Append to file using FileHandle
            do {
                // Reopen handle if it was closed
                if fileHandle == nil {
                    fileHandle = try FileHandle(forWritingTo: url)
                }
                try fileHandle?.seekToEnd()
                fileHandle?.write(data)
                try fileHandle?.synchronize()
            } catch {
                print("[Logger] ERROR writing event: \(error)")
                // Try to reopen handle
                fileHandle = try? FileHandle(forWritingTo: url)
            }
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.eventCount += 1
            self.lastEventDescription = "#\(self.eventCount) \(typeDescription) at (\(String(format: "%.1f", location.x)), \(String(format: "%.1f", location.y)))"
        }
    }

    /// Handle per-finger NSTouch events from HarmonyTouchHostingView.
    func handleTouches(event: NSEvent) {
        guard !isPaused, sessionFileURL != nil else { return }

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
