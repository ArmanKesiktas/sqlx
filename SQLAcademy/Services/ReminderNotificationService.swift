import Foundation
import UserNotifications

struct ReminderNotificationService: Sendable {
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    func scheduleDailyReminder(hour: Int = 20, minute: Int = 0) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["sqlx.daily.reminder"])

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let content = UNMutableNotificationContent()
        content.title = "SQLX"
        content.body = "Bugünkü SQL görevlerini tamamla ve serini koru."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "sqlx.daily.reminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
