//
//  ScreenRecorder.swift
//  savantlab-trackpad-macOS
//
//  Screen recording using native AVFoundation ScreenCaptureKit
//

import Foundation
import Combine
import AVFoundation
import ScreenCaptureKit

#if os(macOS)

@available(macOS 12.3, *)
final class ScreenRecorder: NSObject, ObservableObject, SCStreamOutput {
    @Published var isRecording = false
    @Published var errorMessage: String?
    
    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var recordingURL: URL?
    private var startTime: CMTime?
    private var frameCount: Int64 = 0
    
    func startRecording(outputURL: URL) {
        print("[ScreenRecorder] ========== START SCREEN RECORDING ==========")
        print("[ScreenRecorder] Output URL: \(outputURL.path)")
        
        let directory = outputURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            print("[ScreenRecorder] ✓ Directory ready")
        } catch {
            print("[ScreenRecorder] Directory error: \(error)")
        }
        
        Task {
            await startCapture(outputURL: outputURL)
        }
    }
    
    private func startCapture(outputURL: URL) async {
        print("[ScreenRecorder] startCapture called")
        do {
            print("[ScreenRecorder] Getting shareable content...")
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            print("[ScreenRecorder] Found \(content.displays.count) displays")
            
            guard let display = content.displays.first else {
                print("[ScreenRecorder] ❌ No display found")
                return
            }
            print("[ScreenRecorder] ✓ Using display: \(display.width)x\(display.height)")
            
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = display.width
            config.height = display.height
            config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.showsCursor = true
            
            // Setup asset writer
            print("[ScreenRecorder] Creating asset writer...")
            assetWriter = try AVAssetWriter(url: outputURL, fileType: .mov)
            print("[ScreenRecorder] ✓ Asset writer created")
            
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: display.width,
                AVVideoHeightKey: display.height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 6000000,
                    AVVideoExpectedSourceFrameRateKey: 30
                ]
            ]
            
            videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput?.expectsMediaDataInRealTime = true
            
            let sourcePixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: display.width,
                kCVPixelBufferHeightKey as String: display.height
            ]
            
            adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: videoInput!,
                sourcePixelBufferAttributes: sourcePixelBufferAttributes
            )
            
            if let input = videoInput, let writer = assetWriter, writer.canAdd(input) {
                writer.add(input)
            }
            
            // Start writing
            print("[ScreenRecorder] Starting asset writer...")
            assetWriter?.startWriting()
            assetWriter?.startSession(atSourceTime: .zero)
            print("[ScreenRecorder] ✓ Asset writer started")
            
            // Create and start stream
            print("[ScreenRecorder] Creating SCStream...")
            let stream = SCStream(filter: filter, configuration: config, delegate: nil)
            print("[ScreenRecorder] Adding stream output...")
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: DispatchQueue(label: "ScreenRecorder"))
            print("[ScreenRecorder] Starting capture...")
            try await stream.startCapture()
            print("[ScreenRecorder] ✓ Capture started")
            
            self.stream = stream
            self.recordingURL = outputURL
            self.frameCount = 0
            
            await MainActor.run {
                isRecording = true
                print("[ScreenRecorder] ✓ Recording started")
            }
        } catch {
            print("[ScreenRecorder] ❌ Failed to start: \(error)")
            print("[ScreenRecorder] Error type: \(type(of: error))")
            print("[ScreenRecorder] Error description: \(error.localizedDescription)")
            await MainActor.run {
                errorMessage = "Failed: \(error.localizedDescription)"
            }
        }
    }
    
    // SCStreamOutput delegate method
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              let videoInput = videoInput,
              let adaptor = adaptor,
              videoInput.isReadyForMoreMediaData else {
            return
        }
        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let presentationTime = CMTime(value: frameCount, timescale: 30)
        adaptor.append(imageBuffer, withPresentationTime: presentationTime)
        frameCount += 1
    }
    
    func stopRecording() {
        print("[ScreenRecorder] Stopping...")
        
        Task {
            if let stream = stream {
                try? await stream.stopCapture()
            }
            
            videoInput?.markAsFinished()
            await assetWriter?.finishWriting()
            
            if let url = recordingURL, FileManager.default.fileExists(atPath: url.path) {
                let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64) ?? 0
                print("[ScreenRecorder] ✓ Saved: \(url.lastPathComponent) (\(size/1024/1024) MB, \(frameCount) frames)")
            }
            
            await MainActor.run {
                isRecording = false
            }
            
            stream = nil
            assetWriter = nil
            videoInput = nil
            adaptor = nil
            recordingURL = nil
            frameCount = 0
        }
    }
}

#endif
