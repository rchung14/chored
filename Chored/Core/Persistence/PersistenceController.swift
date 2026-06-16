import Foundation
import SwiftData

/// Builds the shared SwiftData `ModelContainer` living in the App Group, so the
/// main app and the widget read/write the same on-disk store. This is the
/// app's offline source of truth (CloudKit sync is additive on top).
enum PersistenceController {

    static let schema = Schema([SDChoreTask.self, SDTaskLog.self])

    /// Shared container backed by the App Group. Falls back to an in-memory
    /// store if the group container is unavailable (e.g. local-only development
    /// without App Group entitlements) so the app never crashes.
    ///
    /// `cloudKitDatabase: .none` is essential: the app holds the CloudKit
    /// entitlement, which makes SwiftData try to auto-mirror the store to
    /// CloudKit — and that rejects our non-optional attributes and `.unique`
    /// IDs. We sync CloudKit manually via `CloudKitService`, so SwiftData's
    /// automatic mirroring must be disabled.
    static func makeSharedContainer() -> ModelContainer {
        // Preferred: shared store in the App Group (readable by the widget).
        // Locate the container via FileManager — a missing entitlement returns
        // nil here, whereas SwiftData's `.identifier` group container would
        // raise an uncatchable fatalError on unsigned / free-account builds.
        if let groupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupID) {
            let storeURL = groupURL.appendingPathComponent("Chored.store")
            let config = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
            if let container = try? ModelContainer(for: schema, configurations: config) {
                return container
            }
        }

        // Local-only fallback. Keeps the app runnable without App Group setup
        // (e.g. unsigned builds or a free developer account). Not shared with
        // the widget, which is acceptable degradation.
        let memoryConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try! ModelContainer(for: schema, configurations: memoryConfig)
    }
}
