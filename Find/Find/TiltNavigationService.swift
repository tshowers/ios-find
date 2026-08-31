import CoreMotion
import Combine
import UIKit

enum TiltDirection: String {
    case left
    case right
    case up
    case down
    case center
}

// Mirrors the web app's FindGyroscopeService: tilt maps to one of the four
// context pills (left/right/up/down), letting a user drill into a result
// without touching the screen. CoreMotion's raw device-motion attitude
// doesn't need the iOS 13 DeviceOrientationEvent-style permission prompt the
// web version requires in Safari.
//
// Unlike the web version (which hardcodes a "held upright" baseline of 45
// degrees pitch), this calibrates against however the phone is actually
// being held at the moment tilt navigation is enabled, then measures tilt as
// the deviation from that baseline - more robust across different holding
// postures, at the cost of needing to re-enable if the holding posture
// changes drastically.
final class TiltNavigationService: ObservableObject {
    @Published private(set) var tilt: TiltDirection = .center
    @Published private(set) var isActive = false

    private let motionManager = CMMotionManager()
    private var baselineRoll: Double?
    private var baselinePitch: Double?
    private var smoothedRoll: Double = 0
    private var smoothedPitch: Double = 0

    // A deliberate, obvious tilt - roughly a third of the way to holding the
    // phone on its side - not a small wobble from normal handling or
    // scrolling. Below this, any hand tremor or scroll gesture was
    // registering as a tilt and thrashing the pill highlight.
    private let thresholdDegrees: Double = 45
    // Raw device-motion samples are noisy enough, second to second, that a
    // single sample crossing the threshold isn't trustworthy on its own -
    // require the same direction to hold for this long before it commits.
    private let commitDelaySeconds: TimeInterval = 1.0
    // Exponential-moving-average weight for the incoming sample; lower is
    // smoother/slower to react.
    private let smoothingFactor: Double = 0.12

    private var pendingDirection: TiltDirection = .center
    private var pendingSince: Date?

    var isSupported: Bool {
        motionManager.isDeviceMotionAvailable
    }

    func enable() {
        guard isSupported, !isActive else { return }

        baselineRoll = nil
        baselinePitch = nil
        pendingDirection = .center
        pendingSince = nil

        // Tilting the phone toward its side to register "left"/"right" is
        // the same gesture that normally rotates the UI to landscape, so
        // lock to portrait for the duration of tilt navigation.
        AppDelegate.orientationLock = .portrait
        UIViewController.attemptRotationToDeviceOrientation()

        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.handle(motion)
        }
        isActive = true
    }

    func disable() {
        motionManager.stopDeviceMotionUpdates()
        isActive = false
        baselineRoll = nil
        baselinePitch = nil
        pendingDirection = .center
        pendingSince = nil
        tilt = .center

        AppDelegate.orientationLock = .all
        UIViewController.attemptRotationToDeviceOrientation()
    }

    private func handle(_ motion: CMDeviceMotion) {
        guard let baselineRoll, let baselinePitch else {
            self.baselineRoll = motion.attitude.roll
            self.baselinePitch = motion.attitude.pitch
            smoothedRoll = motion.attitude.roll
            smoothedPitch = motion.attitude.pitch
            return
        }

        smoothedRoll += (motion.attitude.roll - smoothedRoll) * smoothingFactor
        smoothedPitch += (motion.attitude.pitch - smoothedPitch) * smoothingFactor

        let rollDelta = (smoothedRoll - baselineRoll) * 180 / .pi
        let pitchDelta = (smoothedPitch - baselinePitch) * 180 / .pi

        var candidate: TiltDirection = .center
        if abs(rollDelta) > abs(pitchDelta) {
            if rollDelta > thresholdDegrees {
                candidate = .left
            } else if rollDelta < -thresholdDegrees {
                candidate = .right
            }
        } else {
            if pitchDelta > thresholdDegrees {
                candidate = .up
            } else if pitchDelta < -thresholdDegrees {
                candidate = .down
            }
        }

        // Returning to center cancels immediately - only committing to a new
        // direction requires the sustained hold, matching "tilt and hold",
        // not "any flick counts".
        if candidate == .center {
            pendingDirection = .center
            pendingSince = nil
            if tilt != .center {
                tilt = .center
            }
            return
        }

        if candidate != pendingDirection {
            pendingDirection = candidate
            pendingSince = Date()
            return
        }

        guard let pendingSince, Date().timeIntervalSince(pendingSince) >= commitDelaySeconds else {
            return
        }

        if tilt != candidate {
            tilt = candidate
        }
    }
}
