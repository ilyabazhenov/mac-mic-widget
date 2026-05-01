import Foundation

@MainActor
protocol HoldToUnmuteMicrophoneControlling: AnyObject {
    var isMuted: Bool { get }
    @discardableResult func muteIfNeeded() -> Bool
    @discardableResult func unmuteToLastLevelIfNeeded() -> Bool
}

@MainActor
final class HoldToUnmuteService: ObservableObject {
    @Published private(set) var isEnabled: Bool
    @Published private(set) var isHoldingFromMuted = false

    private let defaults: UserDefaults
    private static let isEnabledKey = "holdToUnmute.enabled"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isEnabled = defaults.object(forKey: Self.isEnabledKey) as? Bool ?? false
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.isEnabledKey)
    }

    @discardableResult
    func handleHotkeyPressed(microphone: HoldToUnmuteMicrophoneControlling) -> Bool {
        guard isEnabled else {
            return false
        }
        guard isHoldingFromMuted == false else {
            return false
        }
        guard microphone.isMuted else {
            return false
        }

        let didUnmute = microphone.unmuteToLastLevelIfNeeded()
        if didUnmute {
            isHoldingFromMuted = true
        }
        return didUnmute
    }

    @discardableResult
    func handleHotkeyReleased(microphone: HoldToUnmuteMicrophoneControlling) -> Bool {
        guard isHoldingFromMuted else {
            return false
        }
        isHoldingFromMuted = false
        return microphone.muteIfNeeded()
    }
}

extension MicrophoneService: HoldToUnmuteMicrophoneControlling {}
