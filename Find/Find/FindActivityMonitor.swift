import Combine
import CoreMotion
import Foundation

/// "Adapt to what I'm doing" (Info): driving reads answers aloud; walking
/// adds walking times to distances. Off by default; turning it on asks for
/// Motion & Fitness. Activity is read on the device and never sent.
@MainActor
final class FindActivityMonitor: ObservableObject {
    enum Mode {
        case driving
        case walking
        case other
    }

    static let shared = FindActivityMonitor()

    @Published private(set) var isEnabled = UserDefaults.standard.bool(forKey: "find.adaptToActivity")
    @Published private(set) var mode: Mode = .other

    private let manager = CMMotionActivityManager()
    private var isRunning = false

    var isSupported: Bool { CMMotionActivityManager.isActivityAvailable() }

    private init() {
        if isEnabled { start() }
    }

    /// Returns false when Motion & Fitness is off for Find (or unsupported).
    @discardableResult
    func setEnabled(_ enabled: Bool) async -> Bool {
        guard enabled else {
            stop()
            save(false)
            return true
        }
        guard isSupported else { return false }
        if CMMotionActivityManager.authorizationStatus() == .notDetermined {
            // The permission prompt appears on the first query.
            let allowed = await withCheckedContinuation { continuation in
                manager.queryActivityStarting(from: Date().addingTimeInterval(-60), to: Date(), to: .main) { _, error in
                    continuation.resume(returning: (error as NSError?)?.code != Int(CMErrorMotionActivityNotAuthorized.rawValue))
                }
            }
            guard allowed else { return false }
        }
        guard CMMotionActivityManager.authorizationStatus() == .authorized else { return false }
        save(true)
        start()
        return true
    }

    /// Minutes on foot at an easy 3 mph, for a "0.4 mi" style distance.
    func walkingTime(for distance: String?) -> String? {
        guard mode == .walking, let distance,
              let miles = Double(distance.split(separator: " ").first ?? "") else { return nil }
        return "\(max(1, Int((miles * 20).rounded()))) min walk"
    }

    private func save(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "find.adaptToActivity")
    }

    private func start() {
        guard isSupported, !isRunning else { return }
        isRunning = true
        manager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self, let activity, activity.confidence != .low else { return }
            if activity.automotive {
                self.mode = .driving
            } else if activity.walking || activity.running {
                self.mode = .walking
            } else if activity.stationary || activity.cycling {
                self.mode = .other
            }
        }
    }

    private func stop() {
        manager.stopActivityUpdates()
        isRunning = false
        mode = .other
    }
}
