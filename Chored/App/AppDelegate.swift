import UIKit
import UserNotifications
import CloudKit

/// Remote-notification registration only. No business logic. Sync and routing
/// are handled by SwiftUI/`SessionViewModel`; here we just register for APNs and
/// forward CloudKit silent pushes as an in-process notification.
final class AppDelegate: NSObject, UIApplicationDelegate {

    /// Posted when a CloudKit silent push arrives, so the app can re-sync.
    static let didReceiveRemoteChange = Notification.Name("chored.didReceiveRemoteChange")

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        NotificationCenter.default.post(name: Self.didReceiveRemoteChange, object: nil)
        return .newData
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
            NotificationCenter.default.post(name: Self.didReceiveRemoteChange, object: nil)
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
        NotificationCenter.default.post(
            name: Self.didReceiveRemoteChange, object: Constants.dayDeepLink
        )
    }
}
