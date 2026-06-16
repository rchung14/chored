import Foundation
import SwiftData

/// Reads the shared SwiftData container (App Group) for the widget, and builds a
/// `TaskRepository` so the widget reuses the exact same completion flow as the
/// app. `@MainActor` because it drives the SwiftData main context.
@MainActor
struct WidgetDataStore {

    let container: ModelContainer
    private let cloud: CloudKitServicing
    private let notifications: NotificationServicing
    private let userStore: UserStore

    init() {
        self.container = PersistenceController.makeSharedContainer()
        self.cloud = CloudKitService()
        self.notifications = NotificationService()
        self.userStore = UserStore()
    }

    /// Incomplete tasks due today across all groups, sorted by name.
    func todaysIncompleteTasks(limit: Int) -> [ChoreTask] {
        let descriptor = FetchDescriptor<SDChoreTask>()
        let all = (try? container.mainContext.fetch(descriptor)) ?? []
        let today = Date()
        return all
            .map(\.domain)
            .filter { !$0.isComplete && $0.occurs(on: today) }
            .sorted { $0.name < $1.name }
            .prefix(limit)
            .map { $0 }
    }

    func task(byID id: String) -> ChoreTask? {
        let descriptor = FetchDescriptor<SDChoreTask>(predicate: #Predicate { $0.id == id })
        return (try? container.mainContext.fetch(descriptor))?.first?.domain
    }

    func displayName(for recordName: String) -> String {
        if recordName == userStore.userRecordName, let name = userStore.displayName { return name }
        return userStore.cachedName(for: recordName) ?? "Roommate"
    }

    var currentUserRecordName: String {
        userStore.userRecordName ?? "local"
    }

    /// Builds the shared completion pipeline (same code path as the app).
    func makeTaskRepository() -> TaskRepository {
        let logRepo = TaskLogRepository(container: container, cloud: cloud)
        return TaskRepository(
            container: container,
            cloud: cloud,
            notifications: notifications,
            logRepository: logRepo
        )
    }
}
