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
    enum SoundPreset: String, CaseIterable, Equatable {
        case softBalanced
        case ultraSoft
        case crispShort

        var localizationKey: String {
            switch self {
            case .softBalanced:
                return "menu.sound_preset_soft_balanced"
            case .ultraSoft:
                return "menu.sound_preset_ultra_soft"
            case .crispShort:
                return "menu.sound_preset_crisp_short"
            }
        }
    }

    enum Cue: Equatable {
        case mute
        case unmute
        case error
        case permissionNeeded
    }

    @Published private(set) var isEnabled: Bool
    @Published private(set) var volume: Float
    @Published private(set) var soundPreset: SoundPreset

    private let defaults: UserDefaults
    private let player: AudioCuePlayer
    private let now: () -> Date
    private let toggleMinInterval: TimeInterval
    private let errorMinInterval: TimeInterval
    private let permissionMinInterval: TimeInterval
    private var lastPlaybackByCue: [Cue: Date] = [:]

    private static let isEnabledKey = "audioFeedback.enabled"
    private static let volumeKey = "audioFeedback.volume"
    private static let soundPresetKey = "audioFeedback.soundPreset"

    init(
        defaults: UserDefaults = .standard,
        player: AudioCuePlayer = SystemAudioCuePlayer(),
        minInterval: TimeInterval = 0.2,
        errorMinInterval: TimeInterval = 3.0,
        permissionMinInterval: TimeInterval = 10.0,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.player = player
        self.toggleMinInterval = minInterval
        self.errorMinInterval = errorMinInterval
        self.permissionMinInterval = permissionMinInterval
        self.now = now
        self.isEnabled = defaults.object(forKey: Self.isEnabledKey) as? Bool ?? true
        let savedVolume = defaults.object(forKey: Self.volumeKey) as? Float ?? 0.7
        self.volume = min(max(savedVolume, 0), 1)
        if
            let rawPreset = defaults.string(forKey: Self.soundPresetKey),
            let parsedPreset = SoundPreset(rawValue: rawPreset)
        {
            self.soundPreset = parsedPreset
        } else {
            self.soundPreset = .softBalanced
        }
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

    func setSoundPreset(_ preset: SoundPreset) {
        soundPreset = preset
        defaults.set(preset.rawValue, forKey: Self.soundPresetKey)
    }

    func play(for state: MicrophoneFeedbackState) {
        guard state.triggerSource.isExternalFeedbackEligible else {
            return
        }
        play(cue: state.isMuted ? .mute : .unmute)
    }

    func playError() {
        play(cue: .error)
    }

    func playPermissionNeeded() {
        play(cue: .permissionNeeded)
    }

    func shouldPlay(for state: MicrophoneFeedbackState) -> Bool {
        guard isEnabled else {
            return false
        }
        guard state.triggerSource.isExternalFeedbackEligible else {
            return false
        }
        let cue: Cue = state.isMuted ? .mute : .unmute
        return canPlay(cue: cue)
    }

    private func play(cue: Cue) {
        guard isEnabled else {
            return
        }
        guard canPlay(cue: cue) else {
            return
        }

        let (soundName, playbackVolume) = parameters(for: cue, preset: soundPreset)
        let played = player.playSound(named: soundName, volume: playbackVolume)
        if played == false {
            player.playBeep()
        }
        lastPlaybackByCue[cue] = now()
    }

    private func canPlay(cue: Cue) -> Bool {
        let lastPlaybackAt = lastPlaybackByCue[cue] ?? .distantPast
        return now().timeIntervalSince(lastPlaybackAt) >= interval(for: cue)
    }

    private func interval(for cue: Cue) -> TimeInterval {
        switch cue {
        case .mute, .unmute:
            return toggleMinInterval
        case .error:
            return errorMinInterval
        case .permissionNeeded:
            return permissionMinInterval
        }
    }

    private func parameters(for cue: Cue, preset: SoundPreset) -> (NSSound.Name, Float) {
        switch preset {
        case .softBalanced:
            switch cue {
            case .mute:
                return (NSSound.Name("Pop"), clampedVolume(volume * 0.88))
            case .unmute:
                return (NSSound.Name("Glass"), clampedVolume(volume * 0.88))
            case .error:
                return (NSSound.Name("Morse"), clampedVolume(volume * 0.95))
            case .permissionNeeded:
                return (NSSound.Name("Ping"), clampedVolume(volume * 0.82))
            }
        case .ultraSoft:
            switch cue {
            case .mute:
                return (NSSound.Name("Purr"), clampedVolume(volume * 0.78))
            case .unmute:
                return (NSSound.Name("Frog"), clampedVolume(volume * 0.78))
            case .error:
                return (NSSound.Name("Sosumi"), clampedVolume(volume * 0.88))
            case .permissionNeeded:
                return (NSSound.Name("Bottle"), clampedVolume(volume * 0.72))
            }
        case .crispShort:
            switch cue {
            case .mute:
                return (NSSound.Name("Pop"), clampedVolume(volume * 0.84))
            case .unmute:
                return (NSSound.Name("Tink"), clampedVolume(volume * 0.84))
            case .error:
                return (NSSound.Name("Morse"), clampedVolume(volume * 0.95))
            case .permissionNeeded:
                return (NSSound.Name("Pop"), clampedVolume(volume * 0.78))
            }
        }
    }

    private func clampedVolume(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}
