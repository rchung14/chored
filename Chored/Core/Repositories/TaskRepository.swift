import Foundation
import SwiftData

/// Task CRUD + the shared completion flow. Composes SwiftData (local source of
/// truth), CloudKit (additive push), and notifications. Returns domain models.
/// No SwiftUI.
@MainActor
protocol TaskRepositorying {
    func tasks(inGroup groupID: String, on day: Date) async -> [ChoreTask]
    func allTasks(inGroups groupIDs: [String]) async -> [ChoreTask]
    func createTask(_ task: ChoreTask) async throws -> ChoreTask
    func update(_ task: ChoreTask) async throws -> ChoreTask
    func delete(_ task: ChoreTask) async throws
    /// Shared by app + widget. Writes a log, transforms the task per the
    /// completion rules, reschedules the elapsed-time nudge, and syncs.
    func completeTask(
        _ task: ChoreTask,
        byUserRecordName userRecordName: String,
        displayName: @escaping (String) -> String
    ) async throws -> ChoreTask
}

enum TaskRepositoryError: LocalizedError {
    case dailyLimitReached
    var errorDescription: String? {
        switch self {
        case .dailyLimitReached:
            return "A group can have up to \(Constants.Limits.tasksPerGroupPerDay) tasks on a single day."
        }
    }
}

@MainActor
final class TaskRepository: TaskRepositorying {

    private let container: ModelContainer
    private let cloud: CloudKitServicing
    private let notifications: NotificationServicing
    private let logRepository: TaskLogRepositorying

    init(
        container: ModelContainer,
        cloud: CloudKitServicing,
        notifications: NotificationServicing,
        logRepository: TaskLogRepositorying
    ) {
        self.container = container
        self.cloud = cloud
        self.notifications = notifications
        self.logRepository = logRepository
    }

    private var context: ModelContext { container.mainContext }

    // MARK: - Reads

    func tasks(inGroup groupID: String, on day: Date) async -> [ChoreTask] {
        let descriptor = FetchDescriptor<SDChoreTask>(
            predicate: #Predicate { $0.groupID == groupID }
        )
        let all = (try? context.fetch(descriptor)) ?? []
        let occurring = all
            .map(\.domain)
            .filter { $0.occurs(on: day) }
            .sorted { $0.name < $1.name }
        // Enforce the query/UI cap of 20 tasks per group per day.
        return Array(occurring.prefix(Constants.Limits.tasksPerGroupPerDay))
    }

    func allTasks(inGroups groupIDs: [String]) async -> [ChoreTask] {
        let descriptor = FetchDescriptor<SDChoreTask>()
        let all = (try? context.fetch(descriptor)) ?? []
        return all.map(\.domain).filter { groupIDs.contains($0.groupID) }
    }

    // MARK: - Writes

    func createTask(_ task: ChoreTask) async throws -> ChoreTask {
        // Enforce the 20-per-group-per-day cap on the start day.
        let sameDay = await tasks(inGroup: task.groupID, on: task.startDate)
        guard sameDay.count < Constants.Limits.tasksPerGroupPerDay else {
            throw TaskRepositoryError.dailyLimitReached
        }
        return try await persist(task)
    }

    func update(_ task: ChoreTask) async throws -> ChoreTask {
        try await persist(task)
    }

    func delete(_ task: ChoreTask) async throws {
        let id = task.id
        let descriptor = FetchDescriptor<SDChoreTask>(predicate: #Predicate { $0.id == id })
        if let sd = try? context.fetch(descriptor).first {
            context.delete(sd)
            try? context.save()
        }
        notifications.cancelNudge(id: task.id)
        if case .available = await cloud.availability() {
            try? await cloud.delete(taskID: task.id, inGroup: task.groupID)
        }
    }

    // MARK: - Completion flow (shared with widget)

    func completeTask(
        _ task: ChoreTask,
        byUserRecordName userRecordName: String,
        displayName: @escaping (String) -> String
    ) async throws -> ChoreTask {
        let now = Date()

        // 1. Write TaskLog (local first; pushed/flagged below).
        let log = TaskLog(
            taskID: task.id,
            groupID: task.groupID,
            completedByRecordName: userRecordName,
            completedAt: now
        )

        // 2/3. Transform the task (alternating rotate + recurring advance).
        let transformed = task.completed(at: now)

        // 4. Reschedule the elapsed-time nudge.
        if let interval = task.estimatedIntervalDays {
            notifications.cancelNudge(id: task.id)
            let fireDate = now.adding(days: interval)
            let assignee = displayName(transformed.assigneeRecordName)
            let body = NotificationCopy.elapsedInterval(
                days: interval, taskName: task.name, assignee: assignee
            )
            await notifications.scheduleNudge(id: task.id, body: body, at: fireDate)
        }

        // 5. Persist locally immediately, then push (or flag pendingSync).
        let online = isAvailable(await cloud.availability())
        await logRepository.append(log, pendingSync: !online)
        let saved = try await persist(transformed, forcePending: !online)

        if online {
            _ = try? await cloud.save(log: log)
        }
        return saved
    }

    // MARK: - Helpers

    private func persist(_ task: ChoreTask, forcePending: Bool = false) async throws -> ChoreTask {
        let online = isAvailable(await cloud.availability())
        let pending = forcePending || !online

        let id = task.id
        let descriptor = FetchDescriptor<SDChoreTask>(predicate: #Predicate { $0.id == id })
        if let existing = try? context.fetch(descriptor).first {
            existing.apply(task, pendingSync: pending)
        } else {
            context.insert(SDChoreTask.make(from: task, pendingSync: pending))
        }
        try? context.save()

        if online {
            if let remote = try? await cloud.save(task: task) {
                // Clear the pending flag now that the push succeeded.
                if let sd = try? context.fetch(descriptor).first {
                    sd.pendingSync = false
                }
                try? context.save()
                return remote
            }
        }
        return task
    }

    private func isAvailable(_ availability: CloudAvailability) -> Bool {
        if case .available = availability { return true }
        return false
    }
}
