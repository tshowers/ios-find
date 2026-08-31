import UIKit

// Tilting the phone toward its side to trigger "tilt left/right" is the same
// physical gesture that normally rotates the UI to landscape, so tilt
// navigation and UIKit's own rotation fight over the same motion.
// TiltNavigationService locks this to .portrait while it's active and
// restores it on disable.
final class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock: UIInterfaceOrientationMask = .all

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        AppDelegate.orientationLock
    }
}
