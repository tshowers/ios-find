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
// without touching the screen. CoreMotion's raw device-motion doesn't need
// the iOS 13 DeviceOrientationEvent-style permission prompt the web version
// requires in Safari.
//
// This detects a *flick* - a fast, deliberate rotation past a threshold -
// rather than "tilt and hold a pose". That's a deliberate departure from an
// earlier version that used CMDeviceMotion.attitude (an absolute-orientation
// estimate) with a calibrated baseline: attitude's roll/pitch axes are fixed
// to the device's physical shape, so on a larger, often-propped device like
// iPad (rarely held bolt upright the way a phone is), a "tilt down" gesture
// could read as more roll than pitch and get misrouted entirely - not just
// mis-thresholded. rotationRate (the gyroscope's angular velocity, degrees/
// sec around each device-local axis) sidesteps that: it measures how fast
// something is turning right now, with no "neutral pose" to calibrate wrong
// in the first place, and naturally ignores slow postural drift.
final class TiltNavigationService: ObservableObject {
    @Published private(set) var tilt: TiltDirection = .center
    @Published private(set) var isActive = false

    // Live debug readout (rate + accumulated angle for each axis), published
    // only so the Info tab can show it while diagnosing sign/axis mapping.
    @Published private(set) var debugRollRate: Double = 0
    @Published private(set) var debugPitchRate: Double = 0
    @Published private(set) var debugRollAccum: Double = 0
    @Published private(set) var debugPitchAccum: Double = 0

    private let motionManager = CMMotionManager()

    // A leaky integrator, not a fixed time window: each sample adds
    // (rate * dt) and the running total decays every sample. That combines
    // "how fast" and "how far" into one number - a slow drift never
    // accumulates enough before decaying away, but a fast flick outruns the
    // decay and crosses the threshold within a few samples.
    private var rollAccumDeg: Double = 0
    private var pitchAccumDeg: Double = 0
    private let decayPerSample: Double = 0.85
    private let angleThresholdDeg: Double = 20
    // Ignore new flicks for a moment after one fires, so a single physical
    // gesture (which spans several samples) doesn't fire repeatedly.
    private let cooldownSeconds: TimeInterval = 0.8
    private var lastTriggerAt: Date?
    // How long a committed tilt stays "active" for the UI (pill highlight)
    // before resetting to center on its own.
    private let displaySeconds: TimeInterval = 1.2
    private var resetWorkItem: DispatchWorkItem?

    var isSupported: Bool {
        motionManager.isDeviceMotionAvailable
    }

    func enable() {
        guard isSupported, !isActive else { return }

        rollAccumDeg = 0
        pitchAccumDeg = 0
        lastTriggerAt = nil
        tilt = .center

        // Tilting the phone/iPad toward its side to register "left"/"right"
        // is the same gesture that normally rotates the UI to landscape, so
        // lock to portrait for the duration of tilt navigation. On iPad,
        // supportedInterfaceOrientationsFor: + attemptRotationToDeviceOrientation()
        // alone is unreliable - requestGeometryUpdate is the API Apple
        // actually documents for forcing this at runtime.
        AppDelegate.orientationLock = .portrait
        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { error in
                print("[Find] tilt nav orientation lock request failed: \(error)")
            }
        }
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
        rollAccumDeg = 0
        pitchAccumDeg = 0
        debugRollRate = 0
        debugPitchRate = 0
        debugRollAccum = 0
        debugPitchAccum = 0
        lastTriggerAt = nil
        resetWorkItem?.cancel()
        resetWorkItem = nil
        tilt = .center

        AppDelegate.orientationLock = .all
        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .all)) { _ in }
        }
        UIViewController.attemptRotationToDeviceOrientation()
    }

    private func handle(_ motion: CMDeviceMotion) {
        let dt = motionManager.deviceMotionUpdateInterval
        // rotationRate is in the device's own local axes: y is rotation
        // around the top-to-bottom axis of the screen (rolling side to
        // side), x is rotation around the left-to-right axis (pitching
        // forward/back) - same axis pairing as attitude.roll/pitch, just as
        // an instantaneous rate instead of an absolute angle.
        let rollRateDeg = motion.rotationRate.y * 180 / .pi
        let pitchRateDeg = motion.rotationRate.x * 180 / .pi

        rollAccumDeg = rollAccumDeg * decayPerSample + rollRateDeg * dt
        pitchAccumDeg = pitchAccumDeg * decayPerSample + pitchRateDeg * dt

        debugRollRate = rollRateDeg
        debugPitchRate = pitchRateDeg
        debugRollAccum = rollAccumDeg
        debugPitchAccum = pitchAccumDeg

        if let lastTriggerAt, Date().timeIntervalSince(lastTriggerAt) < cooldownSeconds {
            return
        }

        var candidate: TiltDirection = .center
        if abs(rollAccumDeg) > abs(pitchAccumDeg) {
            if abs(rollAccumDeg) > angleThresholdDeg {
                candidate = rollAccumDeg > 0 ? .left : .right
            }
        } else {
            if abs(pitchAccumDeg) > angleThresholdDeg {
                candidate = pitchAccumDeg > 0 ? .up : .down
            }
        }

        guard candidate != .center else { return }

        lastTriggerAt = Date()
        rollAccumDeg = 0
        pitchAccumDeg = 0
        fire(candidate)
    }

    private func fire(_ direction: TiltDirection) {
        resetWorkItem?.cancel()
        tilt = direction

        let workItem = DispatchWorkItem { [weak self] in
            self?.tilt = .center
        }
        resetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + displaySeconds, execute: workItem)
    }
}
