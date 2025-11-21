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
        print("[ScreenRecorder] Starting screen recording to: \(outputURL.path)")
        
        let directory = outputURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        Task {
            await startCapture(outputURL: outputURL)
        }
    }
    
    private func startCapture(outputURL: URL) async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            
            guard let display = content.displays.first else {
                print("[ScreenRecorder] No display found")
                return
            }
            
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = display.width
            config.height = display.height
            config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.showsCursor = true
            
            // Setup asset writer
            assetWriter = try AVAssetWriter(url: outputURL, fileType: .mov)
            
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
            assetWriter?.startWriting()
            assetWriter?.startSession(atSourceTime: .zero)
            
            // Create and start stream
            let stream = SCStream(filter: filter, configuration: config, delegate: nil)
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: DispatchQueue(label: "ScreenRecorder"))
            try await stream.startCapture()
            
            self.stream = stream
            self.recordingURL = outputURL
            self.frameCount = 0
            
            await MainActor.run {
                isRecording = true
                print("[ScreenRecorder] ✓ Recording started")
            }
        } catch {
            print("[ScreenRecorder] Failed to start: \(error)")
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
