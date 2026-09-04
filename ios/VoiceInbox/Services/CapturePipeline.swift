import Foundation
import SwiftData
import Observation

/// Drives one capture through the cloud loop (PROJECT.md §7.5):
/// upload → transcribe → classify/structure → awaiting confirmation.
/// Status transitions are written to SwiftData so the UI follows along.
@MainActor
@Observable
final class CapturePipeline {
    private let api = CaptureAPI()

    func run(_ capture: CaptureRecord, in context: ModelContext) {
        Task {
            await process(capture, in: context)
        }
    }

    private func process(_ capture: CaptureRecord, in context: ModelContext) async {
        guard let filename = capture.audioFilename, AudioStore.exists(filename) else {
            fail(capture, in: context, message: "本地音频不存在")
            return
        }

        do {
            capture.status = .uploading
            try? context.save()

            let created = try await api.createCapture(mode: capture.mode)
            capture.serverId = created.captureId
            let fileURL = try AudioStore.url(for: filename)
            try await api.uploadAudio(fileURL: fileURL, to: created.uploadUrl)

            capture.status = .processing
            try? context.save()
            try await api.process(captureId: created.captureId, timezone: TimeZone.current.identifier)

            // Short captures target < 10 s end-to-end; poll with a generous cap.
            for _ in 0..<40 {
                try await Task.sleep(for: .seconds(1.5))
                let status = try await api.status(captureId: created.captureId)
                if status.status == "done", let result = status.result {
                    apply(result, transcript: status.transcript, language: status.language, to: capture)
                    try? context.save()
                    return
                }
                if status.status == "failed" {
                    throw CaptureAPI.APIError.processingFailed(status.error ?? "处理失败")
                }
            }
            throw CaptureAPI.APIError.timedOut
        } catch {
            fail(capture, in: context, message: ServerHealthMonitor.humanMessage(for: error))
        }
    }

    private func apply(
        _ result: CaptureAPI.Result,
        transcript: String?,
        language: String?,
        to capture: CaptureRecord
    ) {
        capture.transcript = transcript
        capture.language = language
        capture.intentRaw = result.intent
        capture.confidence = result.confidence
        let payload = result.todo ?? result.reminder ?? result.idea
        if let payload, let data = try? JSONEncoder().encode(payload) {
            capture.payloadJSON = String(decoding: data, as: UTF8.self)
        } else {
            capture.payloadJSON = nil
        }
        capture.status = .awaitingConfirm
        capture.lastError = nil
    }

    private func fail(_ capture: CaptureRecord, in context: ModelContext, message: String) {
        capture.status = .failed
        capture.lastError = message
        try? context.save()
    }
}

extension CaptureRecord {
    var decodedPayload: CaptureAPI.Payload? {
        guard let payloadJSON, let data = payloadJSON.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(CaptureAPI.Payload.self, from: data)
    }
}
