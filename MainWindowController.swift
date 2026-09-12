import Cocoa
import WebKit

final class MainWindowController: NSWindowController, NSWindowDelegate {
    private var webView: WKWebView!
    private var titleBarView: TitlebarDragView!
    private let titleBarHeight: CGFloat = 20
    private var popupControllers: [PopupWindowController] = []
    private var countdownTimer: Timer?
    private var countdownLabel: NSTextField?
    private var remainingTime: Int = 60
    private var clickCount: Int = 0
    private static let clicksPerRefresh = 10
    private var overlayView: NSView!

    convenience init() {
        print("[DEBUG] MainWindowController init started")
        
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
        
        print("[DEBUG] Calling setup()")
        setup()
        
        print("[DEBUG] Calling startTimers()")
        startTimers()
        
        print("[DEBUG] MainWindowController init completed")
    }

    private func setup() {
        print("[DEBUG] setup() started")
        guard let window = self.window else { 
            print("[DEBUG] ERROR: window is nil")
            return 
        }
        
        print("[DEBUG] Creating contentView")
        let contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        contentView.wantsLayer = true
        window.contentView = contentView

        print("[DEBUG] Creating webView")
        // WebView fills the content area
        webView = makeWebView(frame: NSRect(
            x: 0,
            y: 0,
            width: contentView.bounds.width,
            height: contentView.bounds.height
        ))
        webView.autoresizingMask = [.width, .height]
        contentView.addSubview(webView)
        
        print("[DEBUG] webView frame: \(webView.frame)")
        print("[DEBUG] webView bounds: \(webView.bounds)")

        // Overlay view for the timer - sits on top of webView
        print("[DEBUG] Creating overlayView")
        overlayView = NSView(frame: webView.bounds)
        overlayView.autoresizingMask = [.width, .height]
        contentView.addSubview(overlayView)

        // Title bar view at the top - this is the invisible drag area
        print("[DEBUG] Creating titleBarView")
        titleBarView = TitlebarDragView(frame: NSRect(
            x: 0,
            y: contentView.bounds.height - titleBarHeight,
            width: contentView.bounds.width,
            height: titleBarHeight
        ))
        titleBarView.autoresizingMask = [.width, .minYMargin]
        titleBarView.onHoverChanged = { [weak self] hovering in
            print("[DEBUG] Hover changed to: \(hovering)")
            self?.setTitleBarButtonsVisible(hovering, animated: true)
        }
        contentView.addSubview(titleBarView)

        print("[DEBUG] Creating countdown label")
        setupCountdownLabel()
        
        print("[DEBUG] Hiding title bar buttons")
        setTitleBarButtonsVisible(false, animated: false)
        
        print("[DEBUG] Loading target URL: \(AppConfig.targetURL)")
        loadTarget()
        
        print("[DEBUG] setup() completed")
    }

    private func setupCountdownLabel() {
        print("[DEBUG] setupCountdownLabel() started")
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
        // Position in lower left, above "Terms of Service" in the left menu bar
        label.frame = NSRect(
            x: 10,
            y: 20,
            width: labelSize.width + 10,
            height: labelSize.height
        )
        label.autoresizingMask = [.minXMargin, .minYMargin]
        
        overlayView.addSubview(label)
        countdownLabel = label
        updateCountdownLabel()
        
        print("[DEBUG] Countdown label created at: \(label.frame)")
    }

    private func updateCountdownLabel() {
        let minutes = remainingTime / 60
        let seconds = remainingTime % 60
        countdownLabel?.stringValue = String(format: "%d:%02d", minutes, seconds)
    }

    private func setTitleBarButtonsVisible(_ visible: Bool, animated: Bool) {
        guard let window = self.window else { return }
        
        let buttons: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                for type in buttons {
                    window.standardWindowButton(type)?.animator().alphaValue = visible ? 1 : 0
                }
            }
        } else {
            for type in buttons {
                window.standardWindowButton(type)?.alphaValue = visible ? 1 : 0
            }
        }
    }

    private func makeWebView(frame: NSRect) -> WKWebView {
        print("[DEBUG] makeWebView() started with frame: \(frame)")
        
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
        
        print("[DEBUG] makeWebView() completed")
        return view
    }

    private func loadTarget() {
        print("[DEBUG] loadTarget() started")
        guard let url = URL(string: AppConfig.targetURL) else { 
            print("[DEBUG] ERROR: Invalid URL")
            return 
        }
        print("[DEBUG] Loading URL: \(url.absoluteString)")
        webView.load(URLRequest(url: url))
        print("[DEBUG] loadTarget() completed")
    }

    private func clickRefreshButton() {
        print("[DEBUG] clickRefreshButton() started")
        let js = """
        (function() {
            var btn = document.querySelector('button[aria-label="refresh grid"]');
            if (btn) {
                btn.click();
                return true;
            }
            // Fallback: try to find by class pattern if aria-label not found
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
        webView.evaluateJavaScript(js) { result, error in
            if let error = error {
                print("[DEBUG] Error clicking refresh button: \(error)")
            } else {
                print("[DEBUG] Refresh button clicked successfully, result: \(String(describing: result))")
            }
        }
        print("[DEBUG] clickRefreshButton() completed")
    }

    private func startTimers() {
        print("[DEBUG] startTimers() started")
        // Countdown timer - updates every second
        countdownTimer?.invalidate()
        remainingTime = 60
        updateCountdownLabel()
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            print("[DEBUG] Timer fired, remainingTime before: \(self?.remainingTime ?? -1)")
            self?.tickTimer()
            print("[DEBUG] Timer fired, remainingTime after: \(self?.remainingTime ?? -1)")
        }
        print("[DEBUG] Timer started")
    }

    private func tickTimer() {
        print("[DEBUG] tickTimer() started, remainingTime: \(remainingTime)")
        remainingTime -= 1
        updateCountdownLabel()
        
        if remainingTime == 0 {
            print("[DEBUG] Timer reached 0, clicking refresh button")
            remainingTime = 60
            clickRefreshButton()
            clickCount += 1
            
            print("[DEBUG] clickCount: \(clickCount)")
            if clickCount >= MainWindowController.clicksPerRefresh {
                print("[DEBUG] Performing full reload")
                clickCount = 0
                window?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                window?.makeFirstResponder(webView)
                loadTarget()
            }
        }
        print("[DEBUG] tickTimer() completed")
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
        print("[DEBUG] windowWillClose()")
        countdownTimer?.invalidate()
        NSApp.terminate(nil)
    }
}

extension MainWindowController: WKUIDelegate {
    /// Called when the page executes window.open() — this is exactly what
    /// Google Identity Services' Sign-In popup does. Returning a real
    /// WKWebView built with the SAME configuration object keeps
    /// window.opener / postMessage wired to the parent page, which is
    /// required for the GSI credential hand-off to complete instead of
    /// stalling on accounts.google.com/gsi/transform.
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

    /// Called when the popup page executes window.close() after it has
    /// finished posting the credential back to the opener — close and
    /// release the matching popup window.
    func webViewDidClose(_ webView: WKWebView) {
        if let index = popupControllers.firstIndex(where: { $0.webView === webView }) {
            popupControllers[index].close()
            popupControllers.remove(at: index)
        }
    }
}

extension MainWindowController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        print("[DEBUG] decidePolicyFor navigationAction: \(navigationAction.request.url?.absoluteString ?? "nil")")
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("[DEBUG] didFinish navigation")
        // After page loads, ensure we can click the button
        // Give a small delay for the page to fully render
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            print("[DEBUG] Delayed refresh button click after page load")
            self?.clickRefreshButton()
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("[DEBUG] didFail navigation with error: \(error)")
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("[DEBUG] didFailProvisionalNavigation with error: \(error)")
    }
}

/// NSWindow subclass so the borderless-styled, titlebar-hidden window can
/// still become key and accept keyboard input (needed for Cmd+/Cmd- to reach
/// the WKWebView and for text fields on the page to receive focus/typing).
final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
