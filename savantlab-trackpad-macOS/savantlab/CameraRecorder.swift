//
//  CameraRecorder.swift
//  savantlab-trackpad-macOS
//
//  Records face video from built-in FaceTime camera for eye tracking analysis
//

import Foundation
import AVFoundation
import Combine

#if os(macOS)

final class CameraRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var errorMessage: String?
    
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureMovieFileOutput?
    private var recordingURL: URL?
    
    func startRecording(outputURL: URL) {
        print("[CameraRecorder] ========== START RECORDING CALLED ==========")
        print("[CameraRecorder] Output URL: \(outputURL.path)")
        
        let directory = outputURL.deletingLastPathComponent()
        print("[CameraRecorder] Creating directory: \(directory.path)")
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            print("[CameraRecorder] ✓ Directory ready")
        } catch {
            print("[CameraRecorder] ⚠️ Directory creation error: \(error)")
        }
        
        print("[CameraRecorder] Launching async Task...")
        Task {
            await setupAndStartCapture(outputURL: outputURL)
        }
        print("[CameraRecorder] Task launched")
    }
    
    private func setupAndStartCapture(outputURL: URL) async {
        print("[CameraRecorder] setupAndStartCapture called with URL: \(outputURL.path)")
        do {
            // Create capture session
            let session = AVCaptureSession()
            session.sessionPreset = .high
            print("[CameraRecorder] Capture session created")
            
            // Find camera device
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera],
                mediaType: .video,
                position: .front
            )
            
            print("[CameraRecorder] Looking for camera... found \(discoverySession.devices.count) devices")
            
            guard let camera = discoverySession.devices.first else {
                print("[CameraRecorder] ❌ No camera found")
                await MainActor.run {
                    errorMessage = "No camera device found"
                }
                return
            }
            
            print("[CameraRecorder] ✓ Found camera: \(camera.localizedName)")
            
            // Add camera input
            print("[CameraRecorder] Creating video input...")
            let videoInput = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(videoInput) {
                session.addInput(videoInput)
                print("[CameraRecorder] ✓ Video input added")
            } else {
                print("[CameraRecorder] ❌ Cannot add video input")
            }
            
            // Add movie output
            print("[CameraRecorder] Creating movie output...")
            let movieOutput = AVCaptureMovieFileOutput()
            if session.canAddOutput(movieOutput) {
                session.addOutput(movieOutput)
                print("[CameraRecorder] ✓ Movie output added")
            } else {
                print("[CameraRecorder] ❌ Cannot add movie output")
            }
            
            // Store references
            self.captureSession = session
            self.videoOutput = movieOutput
            self.recordingURL = outputURL
            print("[CameraRecorder] References stored")
            
            // Start session
            print("[CameraRecorder] Starting capture session...")
            session.startRunning()
            print("[CameraRecorder] ✓ Capture session running")
            
            // Start recording to file
            print("[CameraRecorder] Starting recording to: \(outputURL.lastPathComponent)")
            movieOutput.startRecording(to: outputURL, recordingDelegate: self)
            print("[CameraRecorder] startRecording() called")
            
            await MainActor.run {
                isRecording = true
                print("[CameraRecorder] ✓ Recording started successfully")
            }
        } catch {
            print("[CameraRecorder] ❌ Failed to start: \(error)")
            print("[CameraRecorder] Error details: \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = "Failed to start camera: \(error.localizedDescription)"
            }
        }
    }
    
    func stopRecording() {
        print("[CameraRecorder] Stopping camera recording...")
        
        videoOutput?.stopRecording()
        captureSession?.stopRunning()
        
        isRecording = false
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension CameraRecorder: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("[CameraRecorder] Recording error: \(error)")
            return
        }
        
        // Verify file was created
        if FileManager.default.fileExists(atPath: outputFileURL.path) {
            let size = (try? FileManager.default.attributesOfItem(atPath: outputFileURL.path)[.size] as? UInt64) ?? 0
            print("[CameraRecorder] ✓ Camera recording saved: \(outputFileURL.lastPathComponent) (\(size/1024/1024) MB)")
        } else {
            print("[CameraRecorder] ⚠️ Camera recording file not found")
        }
        
        // Cleanup
        captureSession = nil
        videoOutput = nil
        recordingURL = nil
    }
}

#endif
