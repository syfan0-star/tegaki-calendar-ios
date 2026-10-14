import os
import UIKit

/// The UIKit delegate behind the SwiftUI app (M4 contract §6.7): registers for the silent pushes of
/// the CloudKit zone subscription (only when the engine really uses CloudKit: never in screenshot
/// mode, under XCTest or with `--no-icloud`), starts the sync engine once, and hands a push to it.
///
/// - No device token is needed (`didRegisterForRemoteNotificationsWithDeviceToken` is not
///   implemented: CloudKit subscriptions do not use it), and no notification permission is asked
///   (silent pushes need none).
/// - A silent push that launches the app in the background arrives as `didFinishLaunching`
///   (`start()`) followed by `didReceiveRemoteNotification`; the engine queues the launch round first.
/// - The push handler returns within 20 s (`SyncBackoff.notificationBudget`): iOS allows about 30 s,
///   and overrunning it makes later silent pushes rarer. The sync itself carries on in the engine's
///   queue; whatever iOS cuts off is caught up at the next foreground `syncNow`.
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    private static let log = Logger(subsystem: "com.syfan0.tegakicalendar", category: "AppDelegate")

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        if SyncEngine.usesCloudKit {
            application.registerForRemoteNotifications()
        }
        // The one and only call of `start()` (App.swift does not call it).
        SyncEngine.shared.start()
        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        let changed = await SyncEngine.shared.handleRemoteNotification(userInfo)
        return changed ? .newData : .noData
    }

    /// Recorded only: the simulator always fails here (it has no push token), and the sync engine
    /// does not depend on pushes (the next foreground `syncNow` catches up).
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Self.log.notice("registerForRemoteNotifications failed: \(error.localizedDescription, privacy: .public)")
    }
}
