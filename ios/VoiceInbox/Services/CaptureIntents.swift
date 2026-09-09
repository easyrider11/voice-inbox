import AppIntents

/// App Shortcut / Action Button entry (PLAN-MVP.md #8, PROJECT.md §3.1):
/// one press opens the app straight into recording.
struct StartCaptureIntent: AppIntent {
    static let title: LocalizedStringResource = "Start a Capture"
    static let description = IntentDescription("Opens Voice Inbox and starts recording right away")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppState.shared.startToken += 1
        return .result()
    }
}

struct VoiceInboxShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartCaptureIntent(),
            phrases: [
                "Capture with \(.applicationName)",
                "Start recording in \(.applicationName)",
            ],
            shortTitle: "Capture",
            systemImageName: "mic.fill"
        )
    }
}
