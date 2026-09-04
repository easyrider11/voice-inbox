import Foundation

/// Thin client for the capture pipeline API (PROJECT.md §9).
/// The base URL is user-configurable in 设置 (simulator: loopback; device: Mac LAN IP).
struct CaptureAPI {
    var baseURL: URL { ServerConfig.baseURL }

    struct CreateResponse: Decodable {
        let captureId: String
        let uploadUrl: String
    }

    /// Unified payload DTO — the server fills the fields for the detected intent.
    struct Payload: Codable {
        var title: String?
        var details: String?
        var subtasks: [String]?
        var fireAt: String?
        var bullets: [String]?
    }

    struct Result: Decodable {
        let intent: String
        let confidence: Double
        let todo: Payload?
        let reminder: Payload?
        let idea: Payload?
    }

    struct StatusResponse: Decodable {
        let status: String
        let transcript: String?
        let language: String?
        let result: Result?
        let error: String?
    }

    enum APIError: LocalizedError {
        case badStatus(Int)
        case processingFailed(String)
        case timedOut

        var errorDescription: String? {
            switch self {
            case .badStatus(let code): "服务器返回 \(code)"
            case .processingFailed(let message): message
            case .timedOut: "处理超时，请重试"
            }
        }
    }

    func createCapture(mode: CaptureMode) async throws -> CreateResponse {
        var request = URLRequest(url: baseURL.appending(path: "v1/captures"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["mode": mode.rawValue])
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.check(response)
        return try JSONDecoder().decode(CreateResponse.self, from: data)
    }

    func uploadAudio(fileURL: URL, to uploadUrl: String) async throws {
        guard let url = URL(string: uploadUrl) else { throw APIError.badStatus(0) }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("audio/mp4", forHTTPHeaderField: "Content-Type")
        let (_, response) = try await URLSession.shared.upload(for: request, fromFile: fileURL)
        try Self.check(response)
    }

    /// Pass `transcript` when the phone already transcribed the audio on-device;
    /// the server then skips its own ASR and only structures the text.
    func process(captureId: String, timezone: String, transcript: String? = nil, language: String? = nil) async throws {
        var request = URLRequest(url: baseURL.appending(path: "v1/captures/\(captureId)/process"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: String] = ["timezone": timezone]
        if let transcript { body["transcript"] = transcript }
        if let language { body["language"] = language }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.check(response)
    }

    func status(captureId: String) async throws -> StatusResponse {
        let (data, response) = try await URLSession.shared.data(
            from: baseURL.appending(path: "v1/captures/\(captureId)")
        )
        try Self.check(response)
        return try JSONDecoder().decode(StatusResponse.self, from: data)
    }

    private static func check(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.badStatus(http.statusCode)
        }
    }
}
