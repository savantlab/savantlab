//
//  NativeDrawingView.swift
//  savantlab-trackpad-macOS
//
//  Native macOS drawing view with shaded brush effect, similar to Harmony
//

import SwiftUI

#if os(macOS)
import AppKit

struct NativeDrawingView: NSViewRepresentable {
    @ObservedObject var logger: TrackpadEventLogger
    var clearTrigger: Int
    @Binding var canvasViewRef: DrawingCanvasView?
    
    func makeNSView(context: Context) -> DrawingCanvasView {
        let view = DrawingCanvasView()
        view.logger = logger
        DispatchQueue.main.async {
            canvasViewRef = view
        }
        return view
    }
    
    func updateNSView(_ nsView: DrawingCanvasView, context: Context) {
        // Clear canvas when trigger changes
        if context.coordinator.lastClearTrigger != clearTrigger {
            nsView.clearCanvas()
            context.coordinator.lastClearTrigger = clearTrigger
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var lastClearTrigger = 0
    }
}

final class DrawingCanvasView: NSView {
    var logger: TrackpadEventLogger?
    private var strokePoints: [CGPoint] = []  // All points in current stroke
    private var allCompletedStrokes: [[CGPoint]] = []  // All completed strokes
    private var lastPoint: CGPoint?
    
    override var acceptsFirstResponder: Bool { true }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        window?.acceptsMouseMovedEvents = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        // White background
        NSColor.white.setFill()
        dirtyRect.fill()
        
        // Draw all completed strokes
        for points in allCompletedStrokes {
            drawShadedStroke(points: points)
        }
        
        // Draw current stroke in progress
        if !strokePoints.isEmpty {
            drawShadedStroke(points: strokePoints)
        }
    }
    
    private func drawShadedStroke(points: [CGPoint]) {
        let brushSize: CGFloat = 2.0
        let maxDistance: CGFloat = 1000.0
        let brushPressure: CGFloat = 1.0
        
        // For each point in the stroke
        for (count, currentPoint) in points.enumerated() {
            // Draw lines from current point to all previous points within distance
            for i in 0..<points.count {
                let targetPoint = points[i]
                
                let dx = targetPoint.x - currentPoint.x
                let dy = targetPoint.y - currentPoint.y
                let distanceSquared = dx * dx + dy * dy
                
                // Only draw if within threshold distance
                if distanceSquared < maxDistance {
                    // Calculate opacity based on distance (closer = more opaque)
                    let alpha = (1.0 - (distanceSquared / maxDistance)) * 0.1 * brushPressure
                    
                    NSColor.black.withAlphaComponent(alpha).setStroke()
                    
                    let path = NSBezierPath()
                    path.lineWidth = brushSize
                    path.lineCapStyle = .round
                    path.move(to: currentPoint)
                    path.line(to: targetPoint)
                    path.stroke()
                }
            }
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        strokePoints = [point]
        lastPoint = point
        
        logger?.handle(event: event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        
        // Add point to current stroke
        strokePoints.append(point)
        
        lastPoint = point
        needsDisplay = true
        
        logger?.handle(event: event)
    }
    
    override func mouseUp(with event: NSEvent) {
        // Save completed stroke
        if !strokePoints.isEmpty {
            allCompletedStrokes.append(strokePoints)
            strokePoints = []
        }
        lastPoint = nil
        needsDisplay = true
        
        logger?.handle(event: event)
    }
    
    // Handle gestures
    override func scrollWheel(with event: NSEvent) {
        logger?.handle(event: event)
    }
    
    override func magnify(with event: NSEvent) {
        logger?.handle(event: event)
    }
    
    override func rotate(with event: NSEvent) {
        logger?.handle(event: event)
    }
    
    func clearCanvas() {
        allCompletedStrokes.removeAll()
        strokePoints.removeAll()
        needsDisplay = true
    }
    
    func saveAsImage(to url: URL) -> Bool {
        guard let bitmapRep = bitmapImageRepForCachingDisplay(in: bounds) else {
            return false
        }
        
        cacheDisplay(in: bounds, to: bitmapRep)
        
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return false
        }
        
        do {
            try pngData.write(to: url)
            print("[Canvas] Saved image to: \(url.path)")
            return true
        } catch {
            print("[Canvas] Failed to save image: \(error)")
            return false
        }
    }
}

#endif
