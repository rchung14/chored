import SwiftUI
import SwiftData

@main
struct ChoreApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var container: AppContainer
    @StateObject private var session: SessionViewModel

    init() {
        let container = AppContainer()
        _container = StateObject(wrappedValue: container)
        _session = StateObject(wrappedValue: SessionViewModel(
            cloud: container.cloud,
            notifications: container.notifications,
            sync: container.sync,
            userStore: container.userStore
        ))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container)
                .environmentObject(session)
                .modelContainer(container.modelContainer)
                .task { await session.bootstrap() }
        }
    }
}
