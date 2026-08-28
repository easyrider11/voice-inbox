import AppIntents

/// App Shortcut / Action Button entry (PLAN-MVP.md #8, PROJECT.md §3.1):
/// one press opens the app straight into recording.
struct StartCaptureIntent: AppIntent {
    static let title: LocalizedStringResource = "开始记一条"
    static let description = IntentDescription("打开 Voice Inbox 并立刻开始录音")
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
                "用 \(.applicationName) 记一条",
                "\(.applicationName) 开始录音",
            ],
            shortTitle: "记一条",
            systemImageName: "mic.fill"
        )
    }
}
