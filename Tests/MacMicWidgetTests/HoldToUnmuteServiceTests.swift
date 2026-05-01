import Foundation
import Testing
@testable import MacMicWidget

@MainActor
private final class MockHoldMicrophoneController: HoldToUnmuteMicrophoneControlling {
    var isMuted: Bool = true
    private(set) var muteCalls = 0
    private(set) var unmuteCalls = 0

    func muteIfNeeded() -> Bool {
        muteCalls += 1
        guard isMuted == false else { return false }
        isMuted = true
        return true
    }

    func unmuteToLastLevelIfNeeded() -> Bool {
        unmuteCalls += 1
        guard isMuted else { return false }
        isMuted = false
        return true
    }
}

@MainActor
@Test
func holdToUnmutePressFromMutedUnmutesTemporarily() {
    let suiteName = "HoldToUnmuteTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let service = HoldToUnmuteService(defaults: defaults)
    let microphone = MockHoldMicrophoneController()
    service.setEnabled(true)

    let didToggle = service.handleHotkeyPressed(microphone: microphone)

    #expect(didToggle)
    #expect(microphone.isMuted == false)
    #expect(service.isHoldingFromMuted)
}

@MainActor
@Test
func holdToUnmuteReleaseAfterHoldReturnsToMuted() {
    let suiteName = "HoldToUnmuteTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let service = HoldToUnmuteService(defaults: defaults)
    let microphone = MockHoldMicrophoneController()
    service.setEnabled(true)
    _ = service.handleHotkeyPressed(microphone: microphone)

    let didToggle = service.handleHotkeyReleased(microphone: microphone)

    #expect(didToggle)
    #expect(microphone.isMuted)
    #expect(service.isHoldingFromMuted == false)
}

@MainActor
@Test
func holdToUnmuteIgnoresRepeatedKeyDownWhileHolding() {
    let suiteName = "HoldToUnmuteTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let service = HoldToUnmuteService(defaults: defaults)
    let microphone = MockHoldMicrophoneController()
    service.setEnabled(true)

    _ = service.handleHotkeyPressed(microphone: microphone)
    let secondPress = service.handleHotkeyPressed(microphone: microphone)

    #expect(secondPress == false)
    #expect(microphone.unmuteCalls == 1)
}
