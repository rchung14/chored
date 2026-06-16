import Foundation

/// Notification body strings, matching the DESIGN.md voice table exactly.
/// Conversational, no emoji, no exclamation marks. Foundation only.
enum NotificationCopy {

    static func dueToday(taskName: String, assignee: String) -> String {
        "\(taskName) is due today — \(assignee)'s turn."
    }

    static func dueInOneHour(taskName: String, assignee: String) -> String {
        "\(taskName) due in an hour — \(assignee)'s on it."
    }

    static func elapsedInterval(days: Int, taskName: String, assignee: String) -> String {
        "It's been \(days) days since \(taskName). \(assignee)'s turn if it needs doing."
    }

    static func alternatingRotation(taskName: String, nextAssignee: String) -> String {
        "\(taskName) is now \(nextAssignee)'s responsibility."
    }
}
