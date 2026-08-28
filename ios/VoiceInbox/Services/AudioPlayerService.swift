import AVFoundation
import Observation

/// Minimal local playback for captured audio (M1 verification path:
/// "a recording completed and played back").
@MainActor
@Observable
final class AudioPlayerService: NSObject, AVAudioPlayerDelegate {
    private(set) var playingFilename: String?
    private var player: AVAudioPlayer?

    /// Plays the file, or stops if it is already playing.
    func toggle(filename: String) {
        if playingFilename == filename {
            stop()
            return
        }
        stop()
        guard let url = try? AudioStore.url(for: filename), AudioStore.exists(filename) else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.play()
            self.player = player
            playingFilename = filename
        } catch {
            stop()
        }
    }

    func stop() {
        player?.stop()
        player = nil
        playingFilename = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stop()
        }
    }
}
