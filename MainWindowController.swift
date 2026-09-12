import Cocoa
import WebKit

final class MainWindowController: NSWindowController, NSWindowDelegate {
    private var webView: WKWebView!
    private var titleBarView: TitlebarDragView!
    private let hoverZoneHeight: CGFloat = 10
    private var titleBarStrip: NSView!
    private var titleBarVisible = false
    private var popupControllers: [PopupWindowController] = []
    private var countdownTimer: Timer?
    private var countdownLabel: NSTextField?
    private var remainingTime: Int = 60
    private var clickCount: Int = 0
    private static let clicksPerRefresh = 10
    private var overlayView: NSView!

    convenience init() {
        let styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        let window = KeyableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 818, height: 935),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        window.title = AppConfig.windowTitle
        window.center()
        window.minSize = NSSize(width: 818, height: 935)

        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = false

        self.init(window: window)
        window.delegate = self
        
        setup()
        startTimers()
    }

    private func setup() {
        guard let window = self.window else { return }
        
        let contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        contentView.wantsLayer = true
        window.contentView = contentView

        // WebView fills the content area
        webView = makeWebView(frame: NSRect(
            x: 0,
            y: 0,
            width: contentView.bounds.width,
            height: contentView.bounds.height
        ))
        webView.autoresizingMask = [.width, .height]
        contentView.addSubview(webView)

        // Overlay view for the timer - sits on top of webView
        overlayView = NSView(frame: webView.bounds)
        overlayView.autoresizingMask = [.width, .height]
        contentView.addSubview(overlayView)

        // Visible bar, hidden until hover - only as tall as the window buttons need
        let stripHeight = measuredTitleBarHeight()
        titleBarStrip = NSView(frame: NSRect(
            x: 0,
            y: contentView.bounds.height - stripHeight,
            width: contentView.bounds.width,
            height: stripHeight
        ))
        titleBarStrip.wantsLayer = true
        titleBarStrip.layer?.backgroundColor = NSColor.black.cgColor
        titleBarStrip.autoresizingMask = [.width, .minYMargin]
        titleBarStrip.alphaValue = 0
        titleBarStrip.isHidden = true
        contentView.addSubview(titleBarStrip)

        // Invisible hover zone at the very top - this is the drag area too
        titleBarView = TitlebarDragView(frame: NSRect(
            x: 0,
            y: contentView.bounds.height - hoverZoneHeight,
            width: contentView.bounds.width,
            height: hoverZoneHeight
        ))
        titleBarView.autoresizingMask = [.width, .minYMargin]
        titleBarView.onHoverChanged = { [weak self] hovering in
            self?.setTitleBarVisible(hovering, animated: true)
        }
        contentView.addSubview(titleBarView)

        setupCountdownLabel()
        for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(type)?.alphaValue = 0
        }
        loadTarget()
    }

    private func setupCountdownLabel() {
        let label = NSTextField(labelWithString: "1:00")
        label.textColor = .white
        label.backgroundColor = .clear
        label.isBordered = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.alignment = .left
        
        let labelSize = label.fittingSize
        // Position in lower left, within the left black menu bar, above "Terms of Service"
        let overlayHeight = overlayView.bounds.height
        label.frame = NSRect(
            x: 10,
            y: overlayHeight - 40,
            width: labelSize.width + 10,
            height: labelSize.height
        )
        label.autoresizingMask = [.minXMargin, .maxYMargin]
        
        overlayView.addSubview(label)
        countdownLabel = label
        updateCountdownLabel()
    }

    private func updateCountdownLabel() {
        let minutes = remainingTime / 60
        let seconds = remainingTime % 60
        countdownLabel?.stringValue = String(format: "%d:%02d", minutes, seconds)
    }

    /// Smallest bar that still fully contains the traffic-light buttons,
    /// measured live from their frames, clamped to 20–28 px.
    private func measuredTitleBarHeight() -> CGFloat {
        guard let window = self.window, let contentView = window.contentView else { return 24 }
        var lowestBottom: CGFloat = .greatestFiniteMagnitude
        for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            if let button = window.standardWindowButton(type) {
                let frame = button.convert(button.bounds, to: contentView)
                lowestBottom = min(lowestBottom, frame.minY)
            }
        }
        guard lowestBottom.isFinite else { return 24 }
        return min(max(contentView.bounds.height - lowestBottom + 4, 20), 28)
    }

    private func setTitleBarVisible(_ visible: Bool, animated: Bool) {
        guard visible != titleBarVisible, let window = self.window, let contentView = window.contentView else { return }
        titleBarVisible = visible

        let stripHeight = measuredTitleBarHeight()
        let full = contentView.bounds

        // Bar frame + hover zone grows to cover the whole bar while visible
        titleBarStrip.frame = NSRect(x: 0, y: full.height - stripHeight, width: full.width, height: stripHeight)
        let zoneHeight = visible ? stripHeight : hoverZoneHeight
        titleBarView.frame = NSRect(x: 0, y: full.height - zoneHeight, width: full.width, height: zoneHeight)

        // Page shrinks to make room rather than being covered
        let webHeight = visible ? full.height - stripHeight : full.height
        webView.frame = NSRect(x: 0, y: 0, width: full.width, height: webHeight)
        overlayView.frame = webView.frame

        if visible { titleBarStrip.isHidden = false }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = animated ? 0.18 : 0
            self.titleBarStrip.animator().alphaValue = visible ? 1 : 0
            for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                window.standardWindowButton(type)?.animator().alphaValue = visible ? 1 : 0
            }
        }, completionHandler: {
            if !self.titleBarVisible { self.titleBarStrip.isHidden = true }
        })
    }

    private func makeWebView(frame: NSRect) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.addUserScript(GeolocationInjector.script())
        config.userContentController = userContentController
        config.websiteDataStore = .default()

        let preferences = WKPreferences()
        preferences.javaScriptCanOpenWindowsAutomatically = true
        config.preferences = preferences

        let webPagePreferences = WKWebpagePreferences()
        webPagePreferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences = webPagePreferences

        config.applicationNameForUserAgent = "Version/17.5 Safari/605.1.15"

        let view = WKWebView(frame: frame, configuration: config)
        view.uiDelegate = self
        view.navigationDelegate = self
        view.allowsBackForwardNavigationGestures = true
        view.customUserAgent = AppConfig.safariUserAgent
        
        return view
    }

    private func loadTarget() {
        guard let url = URL(string: AppConfig.targetURL) else { return }
        webView.load(URLRequest(url: url))
    }

    private func clickRefreshButton() {
        let js = """
        (function() {
            var btn = document.querySelector('button[aria-label="refresh grid"]');
            if (btn) {
                btn.click();
                return true;
            }
            var buttons = document.querySelectorAll('button');
            for (var i = 0; i < buttons.length; i++) {
                if (buttons[i].getAttribute('aria-label') && buttons[i].getAttribute('aria-label').includes('refresh')) {
                    buttons[i].click();
                    return true;
                }
            }
            return false;
        })();
        """
        webView.evaluateJavaScript(js)
    }

    private func startTimers() {
        countdownTimer?.invalidate()
        remainingTime = 60
        updateCountdownLabel()
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tickTimer()
        }
    }

    @objc private func tickTimer() {
        remainingTime -= 1
        updateCountdownLabel()
        
        if remainingTime == 0 {
            remainingTime = 60
            clickRefreshButton()
            clickCount += 1
            
            if clickCount >= MainWindowController.clicksPerRefresh {
                clickCount = 0
                DispatchQueue.main.async { [weak self] in
                    self?.window?.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                    self?.window?.makeFirstResponder(self?.webView)
                    self?.loadTarget()
                }
            }
        }
    }

    func zoomIn() {
        webView.pageZoom = min(webView.pageZoom + 0.1, 3.0)
    }

    func zoomOut() {
        webView.pageZoom = max(webView.pageZoom - 0.1, 0.25)
    }

    func resetZoom() {
        webView.pageZoom = 1.0
    }

    func windowWillClose(_ notification: Notification) {
        countdownTimer?.invalidate()
        NSApp.terminate(nil)
    }
}

extension MainWindowController: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard navigationAction.targetFrame == nil else { return nil }

        let width = windowFeatures.width?.doubleValue ?? 480
        let height = windowFeatures.height?.doubleValue ?? 640
        let frame = NSRect(x: 0, y: 0, width: max(360, width), height: max(480, height))

        let popup = PopupWindowController(configuration: configuration, frame: frame)
        popup.webView.uiDelegate = self
        popup.webView.navigationDelegate = self
        popupControllers.append(popup)
        popup.showWindow(nil)
        popup.window?.makeKeyAndOrderFront(nil)

        return popup.webView
    }

    func webViewDidClose(_ webView: WKWebView) {
        if let index = popupControllers.firstIndex(where: { $0.webView === webView }) {
            popupControllers[index].close()
            popupControllers.remove(at: index)
        }
    }
}

extension MainWindowController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.clickRefreshButton()
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    }
}

final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
