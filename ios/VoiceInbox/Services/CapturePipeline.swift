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
            fail(capture, in: context, message: String(localized: "The local audio file is missing"))
            return
        }

        do {
            capture.status = .uploading
            try? context.save()

            let created = try await api.createCapture(mode: capture.mode)
            capture.serverId = created.captureId
            let fileURL = try AudioStore.url(for: filename)

            // No real ASR on the server yet → transcribe on the phone and send
            // text only. A local failure is reported, never papered over with
            // the mock's canned transcripts.
            var local: SpeechTranscriber.Transcript?
            if ServerHealthMonitor.serverASRIsMock {
                local = try await SpeechTranscriber.transcribe(fileURL: fileURL)
            } else {
                try await api.uploadAudio(fileURL: fileURL, to: created.uploadUrl)
            }

            capture.status = .processing
            try? context.save()
            try await api.process(
                captureId: created.captureId,
                timezone: TimeZone.current.identifier,
                localeHint: RecognitionLanguage.current.hint,
                transcript: local?.text,
                language: local?.language
            )

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
                    throw CaptureAPI.APIError.processingFailed(status.error ?? String(localized: "Processing failed"))
                }
            }
            throw CaptureAPI.APIError.timedOut
        } catch {
            // Cloud path failed. If the failure wasn't on-device speech itself,
            // finish on the phone: Apple speech + the local rule structurer.
            // The capture never dies just because a server is unreachable
            // (offline use, and App Review has no access to a private Mac).
            if error is SpeechTranscriber.Failure {
                fail(capture, in: context, message: error.localizedDescription)
                return
            }
            do {
                try await completeOnDevice(capture, filename: filename)
                try? context.save()
            } catch let localError {
                fail(
                    capture,
                    in: context,
                    message: ServerHealthMonitor.humanMessage(for: error) + "; on-device processing also failed: " + localError.localizedDescription
                )
            }
        }
    }

    /// Entire loop on the phone: transcript from Apple speech, card from the
    /// same rules the server's fallback structurer uses.
    private func completeOnDevice(_ capture: CaptureRecord, filename: String) async throws {
        let fileURL = try AudioStore.url(for: filename)
        let transcript = try await SpeechTranscriber.transcribe(fileURL: fileURL)
        let output = LocalStructurer.structure(transcript.text)
        store(
            intent: output.intent,
            confidence: output.confidence,
            payload: output.payload,
            transcript: transcript.text,
            language: transcript.language,
            to: capture
        )
    }

    private func apply(
        _ result: CaptureAPI.Result,
        transcript: String?,
        language: String?,
        to capture: CaptureRecord
    ) {
        store(
            intent: result.intent,
            confidence: result.confidence,
            payload: result.todo ?? result.reminder ?? result.idea,
            transcript: transcript,
            language: language,
            to: capture
        )
    }

    private func store(
        intent: String,
        confidence: Double,
        payload: CaptureAPI.Payload?,
        transcript: String?,
        language: String?,
        to capture: CaptureRecord
    ) {
        capture.transcript = transcript
        capture.language = language
        capture.intentRaw = intent
        capture.confidence = confidence
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
