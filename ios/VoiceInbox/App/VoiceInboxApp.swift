import SwiftUI
import SwiftData
import UserNotifications

@main
struct VoiceInboxApp: App {
    private static let notificationDelegate = NotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = Self.notificationDelegate
    }

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
