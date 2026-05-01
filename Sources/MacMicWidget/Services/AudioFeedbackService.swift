import AppKit
import Foundation

protocol AudioCuePlayer {
    func playSound(named: NSSound.Name, volume: Float) -> Bool
    func playBeep()
}

struct SystemAudioCuePlayer: AudioCuePlayer {
    func playSound(named: NSSound.Name, volume: Float) -> Bool {
        guard let sound = NSSound(named: named) else {
            return false
        }
        sound.stop()
        sound.volume = min(max(volume, 0), 1)
        return sound.play()
    }

    func playBeep() {
        NSSound.beep()
    }
}

@MainActor
final class AudioFeedbackService: ObservableObject {
    @Published private(set) var isEnabled: Bool
    @Published private(set) var volume: Float

    private let defaults: UserDefaults
    private let player: AudioCuePlayer
    private let now: () -> Date
    private let minInterval: TimeInterval
    private var lastPlaybackAt: Date = .distantPast

    private static let isEnabledKey = "audioFeedback.enabled"
    private static let volumeKey = "audioFeedback.volume"

    init(
        defaults: UserDefaults = .standard,
        player: AudioCuePlayer = SystemAudioCuePlayer(),
        minInterval: TimeInterval = 0.2,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.player = player
        self.minInterval = minInterval
        self.now = now
        self.isEnabled = defaults.object(forKey: Self.isEnabledKey) as? Bool ?? true
        let savedVolume = defaults.object(forKey: Self.volumeKey) as? Float ?? 0.7
        self.volume = min(max(savedVolume, 0), 1)
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.isEnabledKey)
    }

    func setVolume(_ value: Float) {
        let clamped = min(max(value, 0), 1)
        volume = clamped
        defaults.set(clamped, forKey: Self.volumeKey)
    }

    func play(for state: MicrophoneFeedbackState) {
        guard shouldPlay(for: state) else {
            return
        }

        // Softer defaults than Basso/Tink to reduce fatigue on frequent toggles.
        let soundName: NSSound.Name = state.isMuted ? NSSound.Name("Pop") : NSSound.Name("Glass")
        let played = player.playSound(named: soundName, volume: volume)
        if played == false {
            player.playBeep()
        }
        lastPlaybackAt = now()
    }

    func shouldPlay(for state: MicrophoneFeedbackState) -> Bool {
        guard isEnabled else {
            return false
        }
        guard state.triggerSource.isExternalFeedbackEligible else {
            return false
        }
        return now().timeIntervalSince(lastPlaybackAt) >= minInterval
    }
}
