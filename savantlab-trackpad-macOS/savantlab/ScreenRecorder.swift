//
//  ScreenRecorder.swift
//  savantlab-trackpad-macOS
//
//  Screen recording using macOS screencapture utility
//

import Foundation
import Combine

#if os(macOS)

final class ScreenRecorder: ObservableObject {
    @Published var isRecording = false
    @Published var errorMessage: String?
    
    private var recordingProcess: Process?
    private var recordingURL: URL?
    
    func startRecording(outputURL: URL) {
        print("[ScreenRecorder] Starting screen recording to: \(outputURL.path)")
        
        // Ensure output directory exists
        let directory = outputURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        // Use screencapture with video recording
        // -v: video mode
        // No time limit (will stop manually)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-v", outputURL.path]
        
        do {
            try process.run()
            recordingProcess = process
            recordingURL = outputURL
            isRecording = true
            print("[ScreenRecorder] ✓ Recording started")
        } catch {
            print("[ScreenRecorder] ✗ Failed to start recording: \(error)")
            errorMessage = "Failed to start screen recording: \(error.localizedDescription)"
        }
    }
    
    func stopRecording() {
        print("[ScreenRecorder] Stopping screen recording...")
        
        guard let process = recordingProcess else {
            print("[ScreenRecorder] No recording process to stop")
            return
        }
        
        // Terminate the recording process
        process.terminate()
        process.waitUntilExit()
        
        isRecording = false
        recordingProcess = nil
        
        // Verify file was created
        if let url = recordingURL {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if FileManager.default.fileExists(atPath: url.path) {
                    let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
                    let size = attrs?[.size] as? UInt64 ?? 0
                    print("[ScreenRecorder] ✓ Recording saved: \(url.path) (\(size) bytes)")
                } else {
                    print("[ScreenRecorder] ⚠️ Recording file not found")
                }
            }
        }
        
        recordingURL = nil
    }
}

#endif
