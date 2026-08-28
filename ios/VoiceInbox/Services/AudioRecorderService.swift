import AVFoundation
import Observation

/// Recording core (M1): wraps AVAudioRecorder, publishes elapsed time and level
/// for the UI, and persists AAC (.m4a) files into AudioStore.
@MainActor
@Observable
final class AudioRecorderService {
    enum RecorderError: LocalizedError {
        case permissionDenied
        case failedToStart

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                "没有麦克风权限。请在设置中允许 Voice Inbox 使用麦克风。"
            case .failedToStart:
                "录音启动失败，请重试。"
            }
        }
    }

    struct Result {
        let filename: String
        let duration: TimeInterval
    }

    private(set) var isRecording = false
    private(set) var elapsed: TimeInterval = 0
    /// Normalized input level 0...1 for the UI pulse.
    private(set) var level: Float = 0
    private(set) var currentFilename: String?

    private var recorder: AVAudioRecorder?
    private var meterTask: Task<Void, Never>?

    func start() async throws {
        guard !isRecording else { return }

        guard await AVAudioApplication.requestRecordPermission() else {
            throw RecorderError.permissionDenied
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let filename = UUID().uuidString + ".m4a"
        let url = try AudioStore.url(for: filename)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        guard recorder.record() else {
            throw RecorderError.failedToStart
        }

        self.recorder = recorder
        currentFilename = filename
        isRecording = true
        elapsed = 0
        level = 0

        meterTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                self?.tick()
            }
        }
    }

    /// Stops and keeps the file. Returns nil if nothing was recording.
    func stop() -> Result? {
        guard let recorder, let filename = currentFilename else { return nil }
        let duration = recorder.currentTime
        recorder.stop()
        cleanup()
        return Result(filename: filename, duration: duration)
    }

    /// Stops and deletes the file.
    func cancel() {
        guard let recorder else { return }
        recorder.stop()
        recorder.deleteRecording()
        cleanup()
    }

    private func tick() {
        guard let recorder, isRecording else { return }
        recorder.updateMeters()
        elapsed = recorder.currentTime
        let db = recorder.averagePower(forChannel: 0) // -160 dB ... 0 dB
        level = max(0, min(1, (db + 50) / 50))
    }

    private func cleanup() {
        meterTask?.cancel()
        meterTask = nil
        recorder = nil
        currentFilename = nil
        isRecording = false
        elapsed = 0
        level = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}
