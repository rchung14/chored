import UIKit
import UserNotifications
import CloudKit

extension Notification.Name {
    /// Posted when a CloudKit silent push arrives or an invite share is
    /// accepted, so the app can re-sync. File-scoped (nonisolated) so it can be
    /// referenced from both main-actor and nonisolated delegate callbacks.
    static let choredRemoteChange = Notification.Name("chored.didReceiveRemoteChange")
}

/// Remote-notification registration only. No business logic. Sync and routing
/// are handled by SwiftUI/`SessionViewModel`; here we just register for APNs and
/// forward CloudKit silent pushes as an in-process notification.
final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        return true
    }

    // `nonisolated` + completion-handler (synchronous) form: UIKit invokes this
    // from a non-isolated context, so staying off the main actor and avoiding an
    // async hop means the non-Sendable `userInfo` never crosses an actor
    // boundary. We don't read `userInfo`; posting to NotificationCenter is
    // thread-safe.
    nonisolated func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        NotificationCenter.default.post(name: .choredRemoteChange, object: nil)
        completionHandler(.newData)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Non-fatal: remote push is additive. App remains fully usable locally.
    }

    // Accept an incoming CKShare (roommate tapped an invite link). Thin
    // forwarder: the system stages the share; we trigger a re-sync to surface
    // the joined group. No business logic here.
    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith metadata: CKShare.Metadata
    ) {
        Task {
            let container = CKContainer(identifier: Constants.cloudContainerID)
            _ = try? await container.accept(metadata)
            NotificationCenter.default.post(name: .choredRemoteChange, object: nil)
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {

    // Show banners while the app is foregrounded (banner + sound + badge).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge, .list]
    }

    // Any notification tap deep-links to today's Day view.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        NotificationCenter.default.post(name: .choredRemoteChange, object: Constants.dayDeepLink)
    }
}
