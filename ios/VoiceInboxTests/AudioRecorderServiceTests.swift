import AVFoundation
import Testing
@testable import VoiceInbox

/// M1 definition of done: a full recording completes and plays back.
/// Requires microphone permission pre-granted on the simulator:
/// `xcrun simctl privacy <udid> grant microphone com.voiceinbox.app`
@MainActor
struct AudioRecorderServiceTests {
    @Test func recordsAndPersistsAPlayableFile() async throws {
        let service = AudioRecorderService()
        try await service.start()
        #expect(service.isRecording)

        try await Task.sleep(for: .seconds(1.2))
        let result = try #require(service.stop())

        #expect(!service.isRecording)
        #expect(result.duration > 0.5)
        #expect(AudioStore.exists(result.filename))

        let url = try AudioStore.url(for: result.filename)
        let player = try AVAudioPlayer(contentsOf: url)
        #expect(player.duration > 0.5)

        AudioStore.delete(result.filename)
    }

    @Test func cancelDeletesTheFile() async throws {
        let service = AudioRecorderService()
        try await service.start()
        try await Task.sleep(for: .milliseconds(400))

        let filename = try #require(service.currentFilename)
        service.cancel()

        #expect(!service.isRecording)
        #expect(!AudioStore.exists(filename))
    }

    @Test func stopWithoutStartReturnsNil() {
        let service = AudioRecorderService()
        #expect(service.stop() == nil)
    }
}
