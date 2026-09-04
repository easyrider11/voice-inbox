import Foundation
import Observation

/// Checks whether the configured server answers, so a bad address or a blocked
/// local network shows up on the home screen at launch — not after the first
/// recording fails. Also turns raw URL errors into plain-language messages.
@MainActor
@Observable
final class ServerHealthMonitor {
    enum State: Equatable {
        case unknown
        case ok
        case unreachable(String)
    }

    private(set) var state: State = .unknown
    private(set) var isChecking = false

    private struct Health: Decodable {
        struct Providers: Decodable {
            let asr: String
            let structurer: String
        }
        let providers: Providers
    }

    /// What the server said its ASR is on the last successful check.
    /// Unknown counts as mock so the phone never trusts canned transcripts.
    private(set) static var lastKnownASRProvider: String?

    static var serverASRIsMock: Bool {
        lastKnownASRProvider == nil || lastKnownASRProvider == "mock"
    }

    func check() async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        var request = URLRequest(url: ServerConfig.baseURL.appending(path: "health"))
        request.timeoutInterval = 4
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                if let health = try? JSONDecoder().decode(Health.self, from: data) {
                    Self.lastKnownASRProvider = health.providers.asr
                }
                state = .ok
            } else {
                state = .unreachable("服务器返回了异常状态（\(Self.address)）")
            }
        } catch {
            state = .unreachable(Self.humanMessage(for: error))
        }
    }

    /// "192.168.20.21:8787" — what the user needs to compare against the Mac.
    static var address: String {
        let url = ServerConfig.baseURL
        guard let host = url.host else { return url.absoluteString }
        let port = url.port.map { ":\($0)" } ?? ""
        return host + port
    }

    static func humanMessage(for error: Error) -> String {
        guard let urlError = error as? URLError else {
            return error.localizedDescription
        }
        switch urlError.code {
        case .cannotConnectToHost, .timedOut, .cannotFindHost, .dnsLookupFailed,
             .networkConnectionLost, .notConnectedToInternet:
            return "\(address) 没有响应。检查：手机和 Mac 在同一 Wi-Fi；iOS 设置 → Voice Inbox → 本地网络 已打开。（错误码 \(urlError.code.rawValue)）"
        case .appTransportSecurityRequiresSecureConnection:
            return "系统拒绝了 http 连接（ATS）。（错误码 \(urlError.code.rawValue)）"
        default:
            return "\(urlError.localizedDescription)（错误码 \(urlError.code.rawValue)）"
        }
    }
}
