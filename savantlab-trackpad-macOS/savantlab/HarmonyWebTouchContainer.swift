//
//  HarmonyWebTouchContainer.swift
//  savantlab-trackpad-macOS
//
//  Hosts a local HTML canvas and captures trackpad events to create drawings.
//

import SwiftUI

#if os(macOS)
import AppKit
import WebKit

struct HarmonyWebTouchContainer: NSViewRepresentable {
    @ObservedObject var logger: TrackpadEventLogger

    func makeNSView(context: Context) -> CanvasTouchHostingView {
        let view = CanvasTouchHostingView(frame: .zero)
        view.configure(with: logger)
        return view
    }

    func updateNSView(_ nsView: CanvasTouchHostingView, context: Context) {
        // Nothing dynamic to update for now.
    }
}

/// NSView that embeds a WKWebView with local canvas and translates trackpad events to drawing.
final class CanvasTouchHostingView: NSView, WKNavigationDelegate, WKScriptMessageHandler {
    private var logger: TrackpadEventLogger?
    private let webView: WKWebView
    private var lastPoint: CGPoint?
    private var isDrawing = false

    override var acceptsFirstResponder: Bool { true }
    override var wantsUpdateLayer: Bool { true }

    override init(frame frameRect: NSRect) {
        // Configure WKWebView
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        
        // Enable console logging
        let contentController = WKUserContentController()
        let consoleScript = WKUserScript(
            source: """
            console.log = (function(oldLog) {
                return function(message) {
                    oldLog.apply(console, arguments);
                    window.webkit.messageHandlers.logging.postMessage(String(message));
                };
            })(console.log);
            console.error = (function(oldError) {
                return function(message) {
                    oldError.apply(console, arguments);
                    window.webkit.messageHandlers.logging.postMessage('ERROR: ' + String(message));
                };
            })(console.error);
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        contentController.addUserScript(consoleScript)
        config.userContentController = contentController
        
        self.webView = WKWebView(frame: .zero, configuration: config)
        
        super.init(frame: frameRect)

        webView.navigationDelegate = self
        webView.configuration.userContentController.add(self, name: "logging")
        webView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(webView)

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // Load local Harmony HTML file
        if let htmlPath = Bundle.main.path(forResource: "harmony", ofType: "html"),
           let htmlString = try? String(contentsOfFile: htmlPath, encoding: .utf8) {
            let baseURL = URL(fileURLWithPath: htmlPath).deletingLastPathComponent()
            webView.loadHTMLString(htmlString, baseURL: baseURL)
            print("[HarmonyView] Loading Harmony from: \(htmlPath) with baseURL: \(baseURL)")
        } else {
            print("[HarmonyView] ERROR: harmony.html not found or could not be read")
        }

        // Ensure we receive mouse/touch events
        window?.acceptsMouseMovedEvents = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with logger: TrackpadEventLogger) {
        self.logger = logger
    }
    
    // MARK: - Drawing helpers
    
    private func drawLineInCanvas(from start: CGPoint, to end: CGPoint) {
        let js = "window.drawLine(\(start.x), \(start.y), \(end.x), \(end.y));"
        webView.evaluateJavaScript(js) { result, error in
            if let error = error {
                print("[CanvasView] JS error: \(error)")
            }
        }
    }

    // MARK: - Mouse/Trackpad handling
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        isDrawing = true
        let point = convert(event.locationInWindow, from: nil)
        lastPoint = point
        logger?.handle(event: event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        let point = convert(event.locationInWindow, from: nil)
        
        if let last = lastPoint {
            drawLineInCanvas(from: last, to: point)
        }
        
        lastPoint = point
        logger?.handle(event: event)
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        isDrawing = false
        lastPoint = nil
        logger?.handle(event: event)
    }

    // MARK: - Touch handling (for per-finger tracking)

    override func touchesBegan(with event: NSEvent) {
        super.touchesBegan(with: event)
        logger?.handleTouches(event: event)
    }

    override func touchesMoved(with event: NSEvent) {
        super.touchesMoved(with: event)
        logger?.handleTouches(event: event)
    }

    override func touchesEnded(with event: NSEvent) {
        super.touchesEnded(with: event)
        logger?.handleTouches(event: event)
    }

    override func touchesCancelled(with event: NSEvent) {
        super.touchesCancelled(with: event)
        logger?.handleTouches(event: event)
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("[HarmonyView] Started loading")
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("[HarmonyView] Finished loading successfully")
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("[HarmonyView] Failed to load: \(error.localizedDescription)")
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("[HarmonyView] Failed provisional navigation: \(error.localizedDescription)")
    }
    
    // MARK: - WKScriptMessageHandler
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "logging", let messageBody = message.body as? String {
            print("[HarmonyView JS] \(messageBody)")
        }
    }
}

#endif
