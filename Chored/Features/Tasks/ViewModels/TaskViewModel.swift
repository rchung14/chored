import Foundation
import Combine

/// Backs task creation, detail, completion, and deletion. Depends on the task +
/// log repositories. No SwiftUI/UIKit layout types.
@MainActor
final class TaskViewModel: ObservableObject {

    @Published private(set) var recentLogs: [TaskLog] = []
    @Published var errorMessage: String?

    private let taskRepository: TaskRepositorying
    private let logRepository: TaskLogRepositorying
    private let userStore: UserStore
    private let currentUser: User

    init(
        taskRepository: TaskRepositorying,
        logRepository: TaskLogRepositorying,
        userStore: UserStore,
        currentUser: User
    ) {
        self.taskRepository = taskRepository
        self.logRepository = logRepository
        self.userStore = userStore
        self.currentUser = currentUser
    }

    /// Resolve a record name to a display name for chips/logs/notifications.
    func displayName(for recordName: String) -> String {
        if recordName == currentUser.recordName { return currentUser.displayName }
        return userStore.cachedName(for: recordName) ?? "Roommate"
    }

    func loadLogs(for task: ChoreTask) async {
        recentLogs = await logRepository.recentLogs(forTask: task.id, limit: 5)
    }

    @discardableResult
    func create(_ task: ChoreTask) async -> Bool {
        do {
            _ = try await taskRepository.createTask(task)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func complete(_ task: ChoreTask) async -> ChoreTask? {
        do {
            let updated = try await taskRepository.completeTask(
                task,
                byUserRecordName: currentUser.recordName,
                displayName: { [weak self] in self?.displayName(for: $0) ?? "Roommate" }
            )
            await loadLogs(for: task)
            return updated
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func delete(_ task: ChoreTask) async {
        do {
            try await taskRepository.delete(task)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Delete permitted for the group owner or the current assignee only.
    func canDelete(_ task: ChoreTask, group: ChoreGroup?) -> Bool {
        if task.assigneeRecordName == currentUser.recordName { return true }
        if let group, group.isOwner(currentUser.recordName) { return true }
        return false
    }
}
