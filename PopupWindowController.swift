import Cocoa
import WebKit

/// Hosts an OAuth/GSI popup (Google Sign-In, etc.) as a real child WKWebView
/// in its own window. Critically, WKUIDelegate's createWebViewWith method is
/// handed a WKWebViewConfiguration that already carries the *relationship*
/// to the opening page — if you return an actual WKWebView built with that
/// same configuration (instead of returning nil and redirecting elsewhere),
/// window.opener and window.postMessage keep working between the popup and
/// the main page. That link is exactly what Google Identity Services (GSI)
/// depends on to hand the signed-in credential back to web.grindr.com after
/// accounts.google.com/gsi/transform finishes — redirecting that step out
/// to Safari (as a previous version of this app did) breaks the link and
/// the flow stalls right there.
@MainActor
final class PopupWindowController: NSWindowController, NSWindowDelegate {
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
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func windowWillClose(_ notification: Notification) {
        // no-op: the owner (MainWindowController) drops its reference when
        // webViewDidClose fires or when this window closes.
    }
}
