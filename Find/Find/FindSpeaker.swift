import AVFoundation
import Combine
import CoreMotion
import Foundation

/// Reads an answer aloud (driving, FindActivityMonitor). Other audio - music,
/// a podcast, Maps - is turned down while it speaks. Turning the phone
/// face-down stops it.
@MainActor
final class FindSpeaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = FindSpeaker()

    @Published private(set) var isSpeaking = false

    private let synthesizer = AVSpeechSynthesizer()
    private let motion = CMMotionManager()
    private var faceDownSince: Date?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        synthesizer.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        let utterance = AVSpeechUtterance(string: String(text.prefix(600)))
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier.replacingOccurrences(of: "_", with: "-"))
            ?? AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
        isSpeaking = true
        watchForFaceDown()
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        finished()
    }

    private func finished() {
        guard isSpeaking else { return }
        isSpeaking = false
        motion.stopDeviceMotionUpdates()
        faceDownSince = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Face-down = gravity pointing out of the screen for half a second.
    private func watchForFaceDown() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 0.1
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let gravity = data?.gravity else { return }
            if gravity.z > 0.85 {
                if let since = self.faceDownSince {
                    if Date().timeIntervalSince(since) > 0.5 { self.stop() }
                } else {
                    self.faceDownSince = Date()
                }
            } else {
                self.faceDownSince = nil
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if !synthesizer.isSpeaking { finished() }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if !synthesizer.isSpeaking { finished() }
        }
    }
}
