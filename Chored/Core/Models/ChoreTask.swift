import Foundation

/// A single chore. Pure domain model (Foundation only).
///
/// Recurrence is expressed either as a weekday bitmask (`weekdayMask`) or as an
/// additive list of specific dates (`recurringDates`). Alternating tasks rotate
/// the assignee through `alternatingOrder` on completion (never on date change).
struct ChoreTask: Identifiable, Equatable, Hashable, Codable {

    let id: String
    let groupID: String

    var name: String

    /// Optional, capped at 140 characters by the creation UI.
    var description: String

    /// Index into `TaskColorPreset` (0...5).
    var colorPreset: Int

    /// Record name of the currently responsible member.
    var assigneeRecordName: String

    // MARK: Recurrence

    var isRecurring: Bool
    /// Sunday = bit 0 ... Saturday = bit 6. Nil when using `recurringDates`.
    var weekdayMask: Int?
    /// Explicit recurrence dates (additive list). Nil when using `weekdayMask`.
    var recurringDates: [Date]?

    // MARK: Alternating assignment

    var isAlternating: Bool
    /// Ordered member record names the assignee rotates through.
    var alternatingOrder: [String]

    // MARK: Scheduling

    var startDate: Date
    var endDate: Date?

    /// Optional elapsed-time nudge interval, in days.
    var estimatedIntervalDays: Int?

    // MARK: Completion state

    var isComplete: Bool
    var completedAt: Date?

    init(
        id: String = UUID().uuidString,
        groupID: String,
        name: String,
        description: String = "",
        colorPreset: Int = 0,
        assigneeRecordName: String,
        isRecurring: Bool = false,
        weekdayMask: Int? = nil,
        recurringDates: [Date]? = nil,
        isAlternating: Bool = false,
        alternatingOrder: [String] = [],
        startDate: Date = Date(),
        endDate: Date? = nil,
        estimatedIntervalDays: Int? = nil,
        isComplete: Bool = false,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.groupID = groupID
        self.name = name
        self.description = description
        self.colorPreset = colorPreset
        self.assigneeRecordName = assigneeRecordName
        self.isRecurring = isRecurring
        self.weekdayMask = weekdayMask
        self.recurringDates = recurringDates
        self.isAlternating = isAlternating
        self.alternatingOrder = alternatingOrder
        self.startDate = startDate
        self.endDate = endDate
        self.estimatedIntervalDays = estimatedIntervalDays
        self.isComplete = isComplete
        self.completedAt = completedAt
    }
}
