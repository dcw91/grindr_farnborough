import WebKit

/// Blocks well-known tracker/analytics hosts so their scripts never download
/// or execute. This is deliberately a blocklist rather than "block all
/// third-party loads": the Google sign-in flow runs inside a reCAPTCHA
/// iframe on recaptcha.net, and blanket third-party blocking would break it.
enum ContentBlocker {
    /// Compiled once at launch, then attached to every profile's web view.
    private(set) static var ruleList: WKContentRuleList?

    private static let rules = """
    [
      { "trigger": { "url-filter": "google-analytics\\.com" }, "action": { "type": "block" } },
      { "trigger": { "url-filter": "googletagmanager\\.com" }, "action": { "type": "block" } },
      { "trigger": { "url-filter": "doubleclick\\.net" }, "action": { "type": "block" } },
      { "trigger": { "url-filter": "googlesyndication\\.com" }, "action": { "type": "block" } },
      { "trigger": { "url-filter": "segment\\.(com|io)" }, "action": { "type": "block" } },
      { "trigger": { "url-filter": "amplitude\\.com" }, "action": { "type": "block" } },
      { "trigger": { "url-filter": "appsflyer\\.com" }, "action": { "type": "block" } },
      { "trigger": { "url-filter": "braze\\.com" }, "action": { "type": "block" } },
      { "trigger": { "url-filter": "onesignal\\.com" }, "action": { "type": "block" } },
      { "trigger": { "url-filter": "mparticle\\.com" }, "action": { "type": "block" } },
      { "trigger": { "url-filter": "mixpanel\\.com" }, "action": { "type": "block" } },
      { "trigger": { "url-filter": "sentry\\.io" }, "action": { "type": "block" } },
      { "trigger": { "url-filter": "datadoghq\\.(com|eu)" }, "action": { "type": "block" } },
      { "trigger": { "url-filter": "hotjar\\.com" }, "action": { "type": "block" } },
      { "trigger": { "url-filter": "fullstory\\.com" }, "action": { "type": "block" } }
    ]
    """

    /// Async - compileContentRuleList can take a moment on first run. Call
    /// the completion on any queue; AppDelegate hops to main before opening windows.
    static func prepare(completion: @escaping () -> Void) {
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "grindr-thirdparty-junk",
            encodedContentRuleList: rules
        ) { list, error in
            if let error = error {
                print("[ContentBlocker] rule list failed to compile, continuing without blocking: \(error)")
            }
            ruleList = list
            completion()
        }
    }
}
