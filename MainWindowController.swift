import Cocoa
import WebKit

final class MainWindowController: NSWindowController, NSWindowDelegate {
    private var webView: WKWebView!
    private var popupControllers: [PopupWindowController] = []
    private var countdownTimer: Timer?
    private var countdownLabel: NSTextField?
    private var remainingTime: Int = 60
    private var clickCount: Int = 0
    private static let clicksPerRefresh = 10
    private var overlayView: NSView!

    private var titleBarRevealed = false
    private static let hotZoneHeight: CGFloat = 10

    /// Height of a standard title bar for this mask, computed without touching
    /// the window's own state (frameRect(forContentRect:styleMask:) is a class
    /// method - ~28 px on current macOS).
    private static func nativeTitleBarHeight() -> CGFloat {
        let probe = NSRect(x: 0, y: 0, width: 100, height: 100)
        let frame = NSWindow.frameRect(forContentRect: probe,
                                       styleMask: [.titled, .closable, .miniaturizable, .resizable])
        return frame.height - probe.height
    }

    private func updateTitleBarVisibility(forMouseY y: CGFloat) {
        guard let window = self.window else { return }
        let h = window.frame.height
        if !titleBarRevealed, y > h - MainWindowController.hotZoneHeight {
            setTitleBarRevealed(true)
        } else if titleBarRevealed, y < h - MainWindowController.nativeTitleBarHeight() {
            setTitleBarRevealed(false)
        }
    }

    private func setTitleBarRevealed(_ revealed: Bool) {
        guard titleBarRevealed != revealed,
              let window = self.window,
              let contentView = window.contentView else { return }
        titleBarRevealed = revealed

        // Page adapts to the smaller viewport rather than sitting under the bar
        let full = contentView.bounds
        let barHeight = MainWindowController.nativeTitleBarHeight()
        let webHeight = revealed ? full.height - barHeight : full.height
        webView.frame = NSRect(x: 0, y: 0, width: full.width, height: webHeight)
        overlayView.frame = webView.frame

        for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(type)?.alphaValue = revealed ? 1 : 0
        }
    }

    convenience init() {
        let styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        let window = KeyableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 818, height: 935),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )

        window.title = AppConfig.windowTitle
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = false
        window.acceptsMouseMovedEvents = true
        window.center()
        window.minSize = NSSize(width: 818, height: 935)

        self.init(window: window)
        window.delegate = self

        // Buttons start invisible - they appear with the "bar"
        for type in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(type)?.alphaValue = 0
        }

        window.onMouseMoved = { [weak self] y in
            self?.updateTitleBarVisibility(forMouseY: y)
        }

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

        setupCountdownLabel()
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

        // Bottom-left corner (AppKit origin is bottom-left, so small y = bottom)
        let labelSize = label.fittingSize
        label.frame = NSRect(
            x: 10,
            y: 20,
            width: labelSize.width + 10,
            height: labelSize.height
        )
        // Flexible right + top margins pin the label to the bottom-left
        label.autoresizingMask = [.maxXMargin, .maxYMargin]

        overlayView.addSubview(label)
        countdownLabel = label
        updateCountdownLabel()
    }

    private func updateCountdownLabel() {
        let minutes = remainingTime / 60
        let seconds = remainingTime % 60
        countdownLabel?.stringValue = String(format: "%d:%02d", minutes, seconds)
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

        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tickTimer()
        }
        // Let macOS coalesce wakeups with other timers; the label only needs
        // to land somewhere within each second.
        timer.tolerance = 0.3
        countdownTimer = timer
    }

    private func tickTimer() {
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
}

final class KeyableWindow: NSWindow {
    var onMouseMoved: ((CGFloat) -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        onMouseMoved?(event.locationInWindow.y)
    }
}
