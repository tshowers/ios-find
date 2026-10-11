import UIKit
import UserNotifications

// Tilting the phone toward its side to trigger "tilt left/right" is the same
// physical gesture that normally rotates the UI to landscape, so tilt
// navigation and UIKit's own rotation fight over the same motion.
// TiltNavigationService locks this to .portrait while it's active and
// restores it on disable.
//
// Also the bridge for Watch notifications: it passes the APNs token and
// notification taps to FindWatchStore / SearchView through
// NotificationCenter (see FindWatchStore.swift).
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static var orientationLock: UIInterfaceOrientationMask = .all
    /// A tapped Watch notification's search, kept until SearchView is on
    /// screen to run it (a tap can launch the app from scratch).
    @MainActor static var pendingWatchQuery: String?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // Tokens can change, so re-register on each launch once allowed
        // (permission itself is only asked when something is first watched).
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            DispatchQueue.main.async { application.registerForRemoteNotifications() }
        }
        return true
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        AppDelegate.orientationLock
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        NotificationCenter.default.post(name: .findPushTokenReceived, object: token)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // No push on this device (simulator, or no network); Watch still
        // works through the History badge.
    }

    // Show a Watch notification even while Find is open.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    // Tapping a Watch notification opens that search.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let query = response.notification.request.content.userInfo["query"] as? String, !query.isEmpty else { return }
        await MainActor.run {
            AppDelegate.pendingWatchQuery = query
            NotificationCenter.default.post(name: .findOpenWatchedQuery, object: query)
        }
    }
}
