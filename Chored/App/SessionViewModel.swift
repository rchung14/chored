import Foundation
import Combine

/// Resolves iCloud identity and the local display name, and drives the root
/// navigation gate (blocking screen vs. name prompt vs. main app).
///
/// Uses `CloudKitServicing` for availability/identity (there is no identity
/// repository — identity is an account concern, not stored domain data) and
/// `UserStore` for the locally cached display name.
@MainActor
final class SessionViewModel: ObservableObject {

    enum Phase: Equatable {
        case loading
        case iCloudUnavailable
        case needsDisplayName(recordName: String)
        case ready(user: User)
    }

    @Published private(set) var phase: Phase = .loading

    private let cloud: CloudKitServicing
    private let notifications: NotificationServicing
    private let sync: SyncServicing
    private let userStore: UserStore

    init(
        cloud: CloudKitServicing,
        notifications: NotificationServicing,
        sync: SyncServicing,
        userStore: UserStore
    ) {
        self.cloud = cloud
        self.notifications = notifications
        self.sync = sync
        self.userStore = userStore
    }

    /// Current resolved user, if any. Used to attribute completions.
    var currentUser: User? {
        if case let .ready(user) = phase { return user }
        return nil
    }

    func bootstrap() async {
        phase = .loading
        let availability = await cloud.availability()

        switch availability {
        case .available(let recordName):
            userStore.userRecordName = recordName
            if userStore.hasDisplayName {
                let user = User(recordName: recordName, displayName: userStore.displayName!)
                userStore.cacheName(user.displayName, for: recordName)
                phase = .ready(user: user)
                await afterReady()
            } else {
                phase = .needsDisplayName(recordName: recordName)
            }

        case .noAccount, .restricted, .unknown:
            // Local-only fallback: if we already have a cached identity, keep
            // running fully offline rather than blocking the user.
            if let cached = userStore.userRecordName, userStore.hasDisplayName {
                phase = .ready(user: User(recordName: cached, displayName: userStore.displayName!))
                await afterReady()
            } else if availability == .noAccount {
                phase = .iCloudUnavailable
            } else {
                // Unknown/restricted without a cached identity: allow a local
                // device-scoped identity so the app is usable without iCloud.
                let localID = userStore.userRecordName ?? "local-\(UUID().uuidString)"
                userStore.userRecordName = localID
                if userStore.hasDisplayName {
                    phase = .ready(user: User(recordName: localID, displayName: userStore.displayName!))
                    await afterReady()
                } else {
                    phase = .needsDisplayName(recordName: localID)
                }
            }
        }
    }

    func saveDisplayName(_ raw: String) async {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        guard case let .needsDisplayName(recordName) = phase else { return }
        userStore.displayName = name
        userStore.cacheName(name, for: recordName)
        phase = .ready(user: User(recordName: recordName, displayName: name))
        await afterReady()
    }

    /// One-time post-login work: notification permission + initial sync.
    private func afterReady() async {
        if !userStore.didRequestNotifications {
            _ = await notifications.requestAuthorization()
            userStore.didRequestNotifications = true
        }
        await sync.sync()
    }

    /// Called when the app returns to the foreground.
    func handleForeground() async {
        await sync.sync()
    }
}
