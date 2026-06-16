import Foundation
import SwiftData

/// Builds the shared SwiftData `ModelContainer` living in the App Group, so the
/// main app and the widget read/write the same on-disk store. This is the
/// app's offline source of truth (CloudKit sync is additive on top).
enum PersistenceController {

    static let schema = Schema([SDChoreTask.self, SDTaskLog.self])

    /// Shared container backed by the App Group. Falls back to an in-memory
    /// store if the group container is unavailable (e.g. misconfigured
    /// entitlements during local-only development) so the app never crashes.
    static func makeSharedContainer() -> ModelContainer {
        if let groupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupID) {
            let storeURL = groupURL.appendingPathComponent("Chored.store")
            let config = ModelConfiguration(url: storeURL)
            if let container = try? ModelContainer(for: schema, configurations: config) {
                return container
            }
        }
        // Local-only fallback. Keeps the app runnable without App Group setup.
        let memoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
        // Force-try is acceptable here: an in-memory store of a static schema
        // cannot realistically fail, and there is no safe degraded mode below.
        return try! ModelContainer(for: schema, configurations: memoryConfig)
    }
}
