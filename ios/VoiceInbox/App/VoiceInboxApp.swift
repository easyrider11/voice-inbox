import SwiftUI
import SwiftData

@main
struct VoiceInboxApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(for: [
            CaptureRecord.self,
            TodoCard.self,
            ReminderCard.self,
            IdeaCard.self,
            MeetingNote.self,
        ])
    }
}
