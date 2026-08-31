import CoreMotion
import Combine

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
    private let thresholdDegrees: Double = 15

    var isSupported: Bool {
        motionManager.isDeviceMotionAvailable
    }

    func enable() {
        guard isSupported, !isActive else { return }

        baselineRoll = nil
        baselinePitch = nil
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
        tilt = .center
    }

    private func handle(_ motion: CMDeviceMotion) {
        guard let baselineRoll, let baselinePitch else {
            self.baselineRoll = motion.attitude.roll
            self.baselinePitch = motion.attitude.pitch
            return
        }

        let rollDelta = (motion.attitude.roll - baselineRoll) * 180 / .pi
        let pitchDelta = (motion.attitude.pitch - baselinePitch) * 180 / .pi

        var next: TiltDirection = .center
        if abs(rollDelta) > abs(pitchDelta) {
            if rollDelta > thresholdDegrees {
                next = .left
            } else if rollDelta < -thresholdDegrees {
                next = .right
            }
        } else {
            if pitchDelta > thresholdDegrees {
                next = .up
            } else if pitchDelta < -thresholdDegrees {
                next = .down
            }
        }

        if next != tilt {
            tilt = next
        }
    }
}
