import Foundation

/// Where the thin backend lives. The simulator reaches the Mac via loopback;
/// a real device needs the Mac's LAN address — editable in 设置 (PLAN-MVP.md #1).
enum ServerConfig {
    static let storageKey = "serverBaseURL"

    static let fallback: String = {
        #if targetEnvironment(simulator)
        "http://127.0.0.1:8787"
        #else
        // The Mac's Bonjour name survives IP changes across Wi-Fi networks;
        // the raw IP broke twice in one week. Editable in 设置 if the Mac is renamed.
        "http://MacBook-Air-2.local:8787"
        #endif
    }()

    static var baseURL: URL {
        let stored = UserDefaults.standard.string(forKey: storageKey)
        if let stored, let url = URL(string: stored), url.scheme != nil {
            return url
        }
        return URL(string: fallback)!
    }
}
