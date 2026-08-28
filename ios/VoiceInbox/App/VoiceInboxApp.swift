import SwiftUI
import SwiftData
import UserNotifications

@main
struct VoiceInboxApp: App {
    private static let container: ModelContainer = {
        do {
            return try ModelContainer(for: CaptureRecord.self, TodoCard.self, ReminderCard.self, IdeaCard.self, MeetingNote.self)
        } catch {
            fatalError("Failed to create model container: \(error)")
        }
    }()

    private static let notificationDelegate = NotificationDelegate(container: container)

    init() {
        UNUserNotificationCenter.current().delegate = Self.notificationDelegate
        NotificationService.registerCategories()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(Self.container)
    }
}
