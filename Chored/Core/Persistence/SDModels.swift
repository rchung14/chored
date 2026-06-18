import Foundation
import SwiftData

/// Local SwiftData mirror of `ChoreTask`. Lives in the App Group container so
/// the widget can read it. `pendingSync` flags completions made offline or in
/// the widget that the main app must flush to CloudKit on next foreground.
@Model
final class SDChoreTask {

    @Attribute(.unique) var id: String
    var groupID: String
    var name: String
    var taskDescription: String
    var colorPreset: Int
    var assigneeRecordName: String

    var isRecurring: Bool
    var weekdayMask: Int?
    var recurringDates: [Date]?
    var excludedDates: [Date]?

    var isAlternating: Bool
    var alternatingOrder: [String]

    var startDate: Date
    var endDate: Date?
    var estimatedIntervalDays: Int?

    var isComplete: Bool
    var completedAt: Date?

    /// Set when a local mutation has not yet been pushed to CloudKit.
    var pendingSync: Bool

    init(
        id: String,
        groupID: String,
        name: String,
        taskDescription: String,
        colorPreset: Int,
        assigneeRecordName: String,
        isRecurring: Bool,
        weekdayMask: Int?,
        recurringDates: [Date]?,
        excludedDates: [Date]?,
        isAlternating: Bool,
        alternatingOrder: [String],
        startDate: Date,
        endDate: Date?,
        estimatedIntervalDays: Int?,
        isComplete: Bool,
        completedAt: Date?,
        pendingSync: Bool
    ) {
        self.id = id
        self.groupID = groupID
        self.name = name
        self.taskDescription = taskDescription
        self.colorPreset = colorPreset
        self.assigneeRecordName = assigneeRecordName
        self.isRecurring = isRecurring
        self.weekdayMask = weekdayMask
        self.recurringDates = recurringDates
        self.excludedDates = excludedDates
        self.isAlternating = isAlternating
        self.alternatingOrder = alternatingOrder
        self.startDate = startDate
        self.endDate = endDate
        self.estimatedIntervalDays = estimatedIntervalDays
        self.isComplete = isComplete
        self.completedAt = completedAt
        self.pendingSync = pendingSync
    }
}

/// Local SwiftData mirror of `TaskLog`.
@Model
final class SDTaskLog {

    @Attribute(.unique) var id: String
    var taskID: String
    var groupID: String
    var completedByRecordName: String
    var completedAt: Date
    var pendingSync: Bool

    init(
        id: String,
        taskID: String,
        groupID: String,
        completedByRecordName: String,
        completedAt: Date,
        pendingSync: Bool
    ) {
        self.id = id
        self.taskID = taskID
        self.groupID = groupID
        self.completedByRecordName = completedByRecordName
        self.completedAt = completedAt
        self.pendingSync = pendingSync
    }
}

// MARK: - Domain <-> SwiftData mapping

extension SDChoreTask {

    /// Convert to the pure domain model.
    var domain: ChoreTask {
        ChoreTask(
            id: id,
            groupID: groupID,
            name: name,
            description: taskDescription,
            colorPreset: colorPreset,
            assigneeRecordName: assigneeRecordName,
            isRecurring: isRecurring,
            weekdayMask: weekdayMask,
            recurringDates: recurringDates,
            excludedDates: excludedDates,
            isAlternating: isAlternating,
            alternatingOrder: alternatingOrder,
            startDate: startDate,
            endDate: endDate,
            estimatedIntervalDays: estimatedIntervalDays,
            isComplete: isComplete,
            completedAt: completedAt
        )
    }

    /// Overwrite all fields from a domain model.
    func apply(_ task: ChoreTask, pendingSync: Bool) {
        groupID = task.groupID
        name = task.name
        taskDescription = task.description
        colorPreset = task.colorPreset
        assigneeRecordName = task.assigneeRecordName
        isRecurring = task.isRecurring
        weekdayMask = task.weekdayMask
        recurringDates = task.recurringDates
        excludedDates = task.excludedDates
        isAlternating = task.isAlternating
        alternatingOrder = task.alternatingOrder
        startDate = task.startDate
        endDate = task.endDate
        estimatedIntervalDays = task.estimatedIntervalDays
        isComplete = task.isComplete
        completedAt = task.completedAt
        self.pendingSync = pendingSync
    }

    static func make(from task: ChoreTask, pendingSync: Bool) -> SDChoreTask {
        SDChoreTask(
            id: task.id,
            groupID: task.groupID,
            name: task.name,
            taskDescription: task.description,
            colorPreset: task.colorPreset,
            assigneeRecordName: task.assigneeRecordName,
            isRecurring: task.isRecurring,
            weekdayMask: task.weekdayMask,
            recurringDates: task.recurringDates,
            excludedDates: task.excludedDates,
            isAlternating: task.isAlternating,
            alternatingOrder: task.alternatingOrder,
            startDate: task.startDate,
            endDate: task.endDate,
            estimatedIntervalDays: task.estimatedIntervalDays,
            isComplete: task.isComplete,
            completedAt: task.completedAt,
            pendingSync: pendingSync
        )
    }
}

extension SDTaskLog {

    var domain: TaskLog {
        TaskLog(
            id: id,
            taskID: taskID,
            groupID: groupID,
            completedByRecordName: completedByRecordName,
            completedAt: completedAt
        )
    }

    static func make(from log: TaskLog, pendingSync: Bool) -> SDTaskLog {
        SDTaskLog(
            id: log.id,
            taskID: log.taskID,
            groupID: log.groupID,
            completedByRecordName: log.completedByRecordName,
            completedAt: log.completedAt,
            pendingSync: pendingSync
        )
    }
}
