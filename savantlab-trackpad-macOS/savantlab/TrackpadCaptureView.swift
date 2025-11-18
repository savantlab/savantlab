//
//  TrackpadCaptureView.swift
//  savantlab-trackpad-macOS
//
//  SwiftUI wrapper around an NSView that listens for mouse/trackpad events.
//

import SwiftUI

#if os(macOS)
import AppKit

struct TrackpadCaptureView: NSViewRepresentable {
    @ObservedObject var logger: TrackpadEventLogger

    func makeNSView(context: Context) -> TrackingNSView {
        let view = TrackingNSView()
        view.onEvent = { event in
            logger.handle(event: event)
        }
        return view
    }

    func updateNSView(_ nsView: TrackingNSView, context: Context) {
        // Nothing to update dynamically for now.
    }
}

final class TrackingNSView: NSView {
    var onEvent: ((NSEvent) -> Void)?
    private var trackingArea: NSTrackingArea?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let existing = trackingArea {
            removeTrackingArea(existing)
        }

        let options: NSTrackingArea.Options = [
            .mouseMoved,
            .activeAlways,
            .inVisibleRect
        ]

        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        onEvent?(event)
    }

    override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)
        onEvent?(event)
    }

    override func magnify(with event: NSEvent) {
        super.magnify(with: event)
        onEvent?(event)
    }

    override func rotate(with event: NSEvent) {
        super.rotate(with: event)
        onEvent?(event)
    }

    override func swipe(with event: NSEvent) {
        super.swipe(with: event)
        onEvent?(event)
    }
}

#else

/// Stub view for non-macOS platforms so the code still compiles if ever built there.
struct TrackpadCaptureView: View {
    var body: some View {
        Text("Trackpad capture is only available on macOS.")
    }
}

#endif
