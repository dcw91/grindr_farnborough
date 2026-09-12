import Cocoa
import WebKit

/// Hosts an OAuth/GSI popup (Google Sign-In, etc.) as a real child WKWebView
/// in its own window. Returning a WKWebView built with the configuration
/// handed to createWebViewWith keeps window.opener / postMessage wired to the
/// parent page, which GSI needs to hand the credential back to the main page.
final class PopupWindowController: NSWindowController {
    let webView: WKWebView

    init(configuration: WKWebViewConfiguration, frame: NSRect) {
        webView = WKWebView(frame: NSRect(origin: .zero, size: frame.size), configuration: configuration)
        webView.customUserAgent = AppConfig.safariUserAgent

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Sign in"
        window.center()
        window.minSize = NSSize(width: 320, height: 420)
        window.contentView = webView
        webView.autoresizingMask = [.width, .height]

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}
