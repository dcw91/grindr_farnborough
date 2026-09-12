import Foundation

/// One location + login pairing. Each profile gets its own persistent website
/// data store (keyed by dataStoreIdentifier), so both windows stay logged in
/// independently while sharing the same WKProcessPool.
struct LocationProfile {
    let name: String
    let latitude: Double
    let longitude: Double
    /// Reported GPS accuracy in metres. Lower looks more precise/realistic.
    let accuracy: Double
    /// Stable per-login identifier. Do not change once a profile is in use,
    /// or its stored session will be orphaned.
    let dataStoreIdentifier: UUID
}

enum AppConfig {
    static let spoofEnabled = true

    /// One window per profile, all inside a single app process.
    static let profiles: [LocationProfile] = [
        LocationProfile(
            name: "Farnborough",
            latitude: 51.30572073970581,
            longitude: -0.7607691514605267,
            accuracy: 1,
            dataStoreIdentifier: UUID(uuidString: "F6B7C8D2-3E45-4A67-9B01-2C3D4E5F6071")!
        ),
        LocationProfile(
            name: "Plymouth",
            latitude: 50.37520489584196,
            longitude: -4.140465291589633,
            accuracy: 1,
            dataStoreIdentifier: UUID(uuidString: "A1B2C3D4-5E6F-4789-0ABC-DEF012345678")!
        )
    ]

    static let targetURL = "https://web.grindr.com/?profile=true"

    /// Exact desktop Safari UA string. Keep the Safari/WebKit version numbers
    /// matching a real, current Safari release.
    static let safariUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"
}
