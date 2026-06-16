import Foundation
import Combine
import SwiftData

/// Dependency-injection root. Constructs the single shared SwiftData container
/// and wires services → repositories. Held by `ChoreApp` and injected into the
/// environment. `@MainActor` because the repositories drive the main context.
@MainActor
final class AppContainer: ObservableObject {

    let modelContainer: ModelContainer

    let cloud: CloudKitServicing
    let notifications: NotificationServicing
    let sync: SyncServicing

    let groupRepository: GroupRepositorying
    let taskRepository: TaskRepositorying
    let logRepository: TaskLogRepositorying

    let userStore: UserStore

    init() {
        let container = PersistenceController.makeSharedContainer()
        self.modelContainer = container

        let cloud = CloudKitService()
        let notifications = NotificationService()
        self.cloud = cloud
        self.notifications = notifications
        self.sync = SyncService(cloud: cloud, container: container)

        let logRepo = TaskLogRepository(container: container, cloud: cloud)
        self.logRepository = logRepo
        self.groupRepository = GroupRepository(cloud: cloud)
        self.taskRepository = TaskRepository(
            container: container,
            cloud: cloud,
            notifications: notifications,
            logRepository: logRepo
        )
        self.userStore = UserStore()
    }
}
