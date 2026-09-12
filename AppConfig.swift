import Foundation

/// Edit these values to change the spoofed location. No UI is exposed for
/// this on purpose — the app always reports this fixed position to any page
/// it loads, matching how you used the browser extension pinned to one spot.
enum AppConfig {
    static let latitude: Double = 51.30572073970581
    /// Longitude in decimal degrees, -180...180.
    static let longitude: Double = -0.7607691514605267
    /// Reported GPS accuracy in metres. Lower looks more precise/realistic.
    static let accuracy: Double = 1
    static let spoofEnabled: Bool = true

    static let targetURL: String = "https://web.grindr.com/?profile=true"
    static let windowTitle: String = "Grindr"

    /// Exact desktop Safari UA string. Keep the Safari/WebKit version numbers
    /// matching a real, current Safari release.
    static let safariUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"
}
