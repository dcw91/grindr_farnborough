import Cocoa
import WebKit

@MainActor
final class MainWindowController: NSWindowController, NSWindowDelegate {
    private var webView: WKWebView!
    private var dragBar: TitlebarDragView!
    private let dragBarHeight: CGFloat = 34
    private var popupControllers: [PopupWindowController] = []
    private var refreshTimer: Timer?

    convenience init() {
        let styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        let window = KeyableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 860),
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        window.title = AppConfig.windowTitle
        window.center()
        window.minSize = NSSize(width: 360, height: 480)

        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = false

        self.init(window: window)
        window.delegate = self
        setup()
        startRefreshTimer()
    }

    private func setup() {
        guard let window = self.window else { return }
        let contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        contentView.wantsLayer = true
        window.contentView = contentView

        webView = makeWebView(frame: contentView.bounds)
        webView.autoresizingMask = [.width, .height]
        contentView.addSubview(webView)

        dragBar = TitlebarDragView(frame: NSRect(
            x: 0,
            y: contentView.bounds.height - dragBarHeight,
            width: contentView.bounds.width,
            height: dragBarHeight
        ))
        dragBar.autoresizingMask = [.width, .minYMargin]
        dragBar.onHoverChanged = { [weak self] hovering in
            self?.setTitlebarControlsHidden(!hovering, animated: true)
        }
        contentView.addSubview(dragBar)

        setTitlebarControlsHidden(true, animated: false)
        loadTarget()
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

    func zoomIn() {
        webView.pageZoom = min(webView.pageZoom + 0.1, 3.0)
    }

    func zoomOut() {
        webView.pageZoom = max(webView.pageZoom - 0.1, 0.25)
    }

    func resetZoom() {
        webView.pageZoom = 1.0
    }

    private func setTitlebarControlsHidden(_ hidden: Bool, animated: Bool) {
        guard let window = self.window else { return }
        let buttons: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                for type in buttons {
                    window.standardWindowButton(type)?.animator().alphaValue = hidden ? 0 : 1
                }
            }
        } else {
            for type in buttons {
                window.standardWindowButton(type)?.alphaValue = hidden ? 0 : 1
            }
        }
    }

    func windowWillClose(_ notification: Notification) {
        refreshTimer?.invalidate()
        NSApp.terminate(nil)
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 180, repeats: true) { [weak self] _ in
            self?.window?.makeKeyAndOrderFront(nil)
            self?.loadTarget()
        }
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
        decisionHandler(.allow)
    }
}

/// NSWindow subclass so the borderless-styled, titlebar-hidden window can
/// still become key and accept keyboard input (needed for Cmd+/Cmd- to reach
/// the WKWebView and for text fields on the page to receive focus/typing).
final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
