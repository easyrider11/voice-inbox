import Foundation
import Speech
import os

/// On-device speech recognition (Apple). Gives real transcripts with no cloud
/// keys: the phone turns audio into text, and only the text goes to the server
/// for structuring. Used while the server's ASR is still the mock; once a real
/// server ASR is configured the pipeline uploads audio instead.
enum SpeechTranscriber {
    enum Failure: LocalizedError {
        case notAuthorized
        case unavailable
        case empty

        var errorDescription: String? {
            switch self {
            case .notAuthorized: String(localized: "Speech recognition isn't allowed. Turn it on in iOS Settings → Voice Inbox → Speech Recognition.")
            case .unavailable: String(localized: "On-device speech recognition isn't available right now (check the language pack, or try again).")
            case .empty: String(localized: "Didn't catch that. Try again.")
            }
        }
    }

    struct Transcript {
        let text: String
        let language: String
    }

    static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    static func transcribe(fileURL: URL, locale: Locale = RecognitionLanguage.current.locale) async throws -> Transcript {
        guard await requestAuthorization() else { throw Failure.notAuthorized }
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw Failure.unavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.shouldReportPartialResults = false
        request.addsPunctuation = true
        // Keep audio on the phone when the device can do it (iPhone 14 Pro can).
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition

        // The task handler can fire more than once (final result, then a
        // cancellation error); a continuation may only resume once.
        let resumed = OSAllocatedUnfairLock(initialState: false)
        let text: String = try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                // Only plain values cross into the lock closure (Sendable-safe).
                let isTerminal = error != nil || result?.isFinal == true
                let transcriptText = result?.bestTranscription.formattedString
                let first = resumed.withLock { done -> Bool in
                    guard !done, isTerminal else { return false }
                    done = true
                    return true
                }
                guard first else { return }
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: transcriptText ?? "")
                }
            }
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw Failure.empty }
        return Transcript(text: trimmed, language: locale.identifier)
    }
}
