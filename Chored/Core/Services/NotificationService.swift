import Foundation
import UserNotifications

/// Local notification scheduling + permission. Side effects only — copy text is
/// passed in by callers (which compose it from the spec's voice table), so no
/// business logic lives here.
protocol NotificationServicing {
    func requestAuthorization() async -> Bool
    /// Schedules a one-shot local nudge identified by `id`, replacing any
    /// existing request with the same id. `fireDate` in the past is ignored.
    func scheduleNudge(id: String, body: String, at fireDate: Date) async
    func cancelNudge(id: String)
    func setBadge(_ count: Int) async
}

final class NotificationService: NotificationServicing {

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func scheduleNudge(id: String, body: String, at fireDate: Date) async {
        guard fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.body = body
        content.sound = .default
        content.badge = 1
        // Deep-link payload: tapping opens today's Day view.
        content.userInfo = ["deepLink": Constants.dayDeepLink.absoluteString]

        let interval = max(1, fireDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        center.removePendingNotificationRequests(withIdentifiers: [id])
        try? await center.add(request)
    }

    func cancelNudge(id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }

    func setBadge(_ count: Int) async {
        try? await center.setBadgeCount(count)
    }
}
