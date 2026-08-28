import UserNotifications

/// Local notifications for reminders (PROJECT.md §5.3): scheduled on confirm,
/// cancelled on completion or deletion, rescheduled on edit.
@MainActor
enum NotificationService {
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
}

/// Shows reminder banners even while the app is in the foreground.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
