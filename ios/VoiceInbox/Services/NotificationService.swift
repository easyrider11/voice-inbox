import SwiftData
import UserNotifications

/// Local notifications for reminders (PROJECT.md §5.3): scheduled on confirm,
/// cancelled on completion or deletion, rescheduled on edit.
/// Banners are actionable (PLAN-MVP.md #9): 完成 / 稍后 10 分钟.
@MainActor
enum NotificationService {
    static let reminderCategoryID = "reminder"
    static let doneActionID = "reminder.done"
    static let snoozeActionID = "reminder.snooze10"

    /// Called once at launch so action buttons appear on banners.
    static func registerCategories() {
        let done = UNNotificationAction(
            identifier: doneActionID,
            title: "完成",
            options: []
        )
        let snooze = UNNotificationAction(
            identifier: snoozeActionID,
            title: "稍后 10 分钟",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: reminderCategoryID,
            actions: [done, snooze],
            intentIdentifiers: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    static func ensureAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .denied:
            return false
        default:
            return true
        }
    }

    /// Schedules (or reschedules) the notification for a reminder card.
    static func schedule(for card: ReminderCard) async {
        cancel(card.notificationID)
        guard await ensureAuthorization(), card.fireDate > .now, !card.done else { return }

        let content = UNMutableNotificationContent()
        content.title = card.title
        content.body = "来自语音收件箱的提醒"
        content.sound = .default
        content.categoryIdentifier = reminderCategoryID

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: card.fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let id = card.notificationID ?? UUID().uuidString
        card.notificationID = id

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func cancel(_ id: String?) {
        guard let id else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    /// App icon badge = reminders still due today or overdue (PLAN-MVP.md #7).
    static func updateBadge(with reminders: [ReminderCard]) {
        guard let endOfToday = Calendar.current.date(
            bySettingHour: 23, minute: 59, second: 59, of: .now
        ) else { return }
        let count = reminders.filter { !$0.done && $0.fireDate <= endOfToday }.count
        UNUserNotificationCenter.current().setBadgeCount(count)
    }
}

/// Shows banners while the app is foregrounded and handles banner actions.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let notificationID = response.notification.request.identifier
        let action = response.actionIdentifier
        await MainActor.run { [container] in
            let context = container.mainContext
            guard
                let cards = try? context.fetch(FetchDescriptor<ReminderCard>()),
                let card = cards.first(where: { $0.notificationID == notificationID })
            else { return }

            switch action {
            case NotificationService.doneActionID:
                card.done = true
            case NotificationService.snoozeActionID:
                card.fireDate = .now.addingTimeInterval(10 * 60)
                Task { await NotificationService.schedule(for: card) }
            default:
                break
            }
            try? context.save()
            if let all = try? context.fetch(FetchDescriptor<ReminderCard>()) {
                NotificationService.updateBadge(with: all)
            }
        }
    }
}
