import Foundation

/// App-wide constant identifiers. No business logic, no side effects.
enum Constants {

    /// CloudKit container identifier. Mirrors the iCloud entitlement.
    static let cloudContainerID = "iCloud.com.yourcompany.chored"

    /// Shared App Group used by the main app and the widget extension.
    static let appGroupID = "group.com.yourcompany.chored"

    /// Custom URL scheme used for notification deep links.
    static let urlScheme = "chored"

    /// Deep-link URL that opens the Calendar Day view for today.
    static let dayDeepLink = URL(string: "chored://today")!

    // MARK: - Domain limits (client-enforced, see spec)

    enum Limits {
        /// Maximum groups a single user may own/join.
        static let groupsPerUser = 5
        /// Maximum members per group (including owner).
        static let membersPerGroup = 10
        /// Maximum tasks rendered/queried per group per day.
        static let tasksPerGroupPerDay = 20
        /// Maximum description length for a task.
        static let descriptionLength = 140
        /// Maximum task-color presets (0...5).
        static let colorPresetCount = 6
        /// Calendar-day dot cap before collapsing to "+N".
        static let monthDotCap = 3
    }

    // MARK: - CloudKit record types

    enum RecordType {
        static let user = "User"
        static let group = "ChoreGroup"
        static let task = "ChoreTask"
        static let taskLog = "TaskLog"
        static let share = "cloudkit.share"
    }

    // MARK: - UserDefaults keys (stored in the App Group suite)

    enum DefaultsKey {
        static let displayName = "chored.displayName"
        static let userRecordName = "chored.userRecordName"
        static let didRequestNotifications = "chored.didRequestNotifications"
    }
}
