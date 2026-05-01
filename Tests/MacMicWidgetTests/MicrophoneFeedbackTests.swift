import AppKit
import Foundation
import Testing
@testable import MacMicWidget

@MainActor
@Test
func floatingHUDTitleUsesMutedAndPercentVariants() {
    let localizationService = LocalizationService(defaults: UserDefaults(suiteName: #function)!)
    let muted = MicrophoneFeedbackState(
        isMuted: true,
        volumePercent: 0,
        triggerSource: .globalHotkey,
        timestamp: .now
    )
    #expect(
        FloatingHUDPresentationLogic.title(for: muted, localizationService: localizationService)
            == localizationService.string("hud.off")
    )

    let unmuted = MicrophoneFeedbackState(
        isMuted: false,
        volumePercent: 37,
        triggerSource: .statusItemSecondaryClick,
        timestamp: .now
    )
    #expect(
        FloatingHUDPresentationLogic.title(for: unmuted, localizationService: localizationService)
            == localizationService.string("hud.on", 37)
    )
}

@Test
func feedbackEligibilityTreatsPopoverAsInternal() {
    #expect(MicrophoneChangeSource.statusItemSecondaryClick.isExternalFeedbackEligible)
    #expect(MicrophoneChangeSource.globalHotkey.isExternalFeedbackEligible)
    #expect(MicrophoneChangeSource.automatedRule.isExternalFeedbackEligible)
    #expect(MicrophoneChangeSource.popoverButton.isExternalFeedbackEligible == false)
    #expect(MicrophoneChangeSource.popoverSlider.isExternalFeedbackEligible == false)
}

@MainActor
@Test
func audioFeedbackPlaysOnlyForEligibleSourcesWhenEnabled() {
    let player = MockAudioCuePlayer()
    let service = AudioFeedbackService(
        defaults: UserDefaults(suiteName: #function)!,
        player: player,
        minInterval: 0,
        now: Date.init
    )
    service.setEnabled(true)

    service.play(for: MicrophoneFeedbackState(
        isMuted: true,
        volumePercent: 0,
        triggerSource: .statusItemSecondaryClick,
        timestamp: .now
    ))
    #expect(player.playedNames.count == 1)

    service.play(for: MicrophoneFeedbackState(
        isMuted: false,
        volumePercent: 45,
        triggerSource: .popoverButton,
        timestamp: .now
    ))
    #expect(player.playedNames.count == 1)
}

@MainActor
@Test
func audioFeedbackSkipsPlaybackWhenDisabled() {
    let player = MockAudioCuePlayer()
    let service = AudioFeedbackService(
        defaults: UserDefaults(suiteName: #function)!,
        player: player,
        minInterval: 0,
        now: Date.init
    )
    service.setEnabled(false)

    service.play(for: MicrophoneFeedbackState(
        isMuted: false,
        volumePercent: 66,
        triggerSource: .globalHotkey,
        timestamp: .now
    ))

    #expect(player.playedNames.isEmpty)
    #expect(player.beepCount == 0)
}

@MainActor
@Test
func audioFeedbackFallsBackToBeepWhenSoundPlaybackFails() {
    let suiteName = "audioFeedbackFallsBackToBeepWhenSoundPlaybackFails"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    let player = MockAudioCuePlayer()
    player.shouldPlaySucceed = false
    let service = AudioFeedbackService(
        defaults: defaults,
        player: player,
        minInterval: 0,
        now: Date.init
    )
    service.setEnabled(true)

    service.play(for: MicrophoneFeedbackState(
        isMuted: true,
        volumePercent: 0,
        triggerSource: .globalHotkey,
        timestamp: .now
    ))

    #expect(player.playedNames.count == 1)
    #expect(player.beepCount == 1)
}

@MainActor
@Test
func audioFeedbackVolumePersistsAndIsUsedForPlayback() {
    let suiteName = "audioFeedbackVolumePersistsAndIsUsedForPlayback"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    let player = MockAudioCuePlayer()
    let service = AudioFeedbackService(
        defaults: defaults,
        player: player,
        minInterval: 0,
        now: Date.init
    )

    service.setVolume(0.35)
    #expect(abs(service.volume - 0.35) < 0.0001)

    service.play(for: MicrophoneFeedbackState(
        isMuted: false,
        volumePercent: 42,
        triggerSource: .globalHotkey,
        timestamp: .now
    ))
    #expect(abs((player.playedVolumes.last ?? 0) - 0.308) < 0.0001)

    let restored = AudioFeedbackService(
        defaults: defaults,
        player: player,
        minInterval: 0,
        now: Date.init
    )
    #expect(abs(restored.volume - 0.35) < 0.0001)
}

@MainActor
@Test
func audioFeedbackRespectsDebounceInterval() {
    let suiteName = "audioFeedbackRespectsDebounceInterval"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    var now = Date(timeIntervalSince1970: 1_000)
    let player = MockAudioCuePlayer()
    let service = AudioFeedbackService(
        defaults: defaults,
        player: player,
        minInterval: 1.0,
        now: { now }
    )

    let state = MicrophoneFeedbackState(
        isMuted: false,
        volumePercent: 33,
        triggerSource: .globalHotkey,
        timestamp: .now
    )

    service.play(for: state)
    service.play(for: state)
    #expect(player.playedNames.count == 1)

    now = now.addingTimeInterval(1.1)
    service.play(for: state)
    #expect(player.playedNames.count == 2)
}

@MainActor
@Test
func audioFeedbackUsesDistinctCuesForMuteAndUnmute() {
    let player = MockAudioCuePlayer()
    let service = AudioFeedbackService(
        defaults: UserDefaults(suiteName: #function)!,
        player: player,
        minInterval: 0,
        now: Date.init
    )
    service.setEnabled(true)
    service.setVolume(0.8)

    service.play(for: MicrophoneFeedbackState(
        isMuted: true,
        volumePercent: 0,
        triggerSource: .globalHotkey,
        timestamp: .now
    ))
    service.play(for: MicrophoneFeedbackState(
        isMuted: false,
        volumePercent: 40,
        triggerSource: .globalHotkey,
        timestamp: .now
    ))

    #expect(player.playedNames == [NSSound.Name("Pop"), NSSound.Name("Glass")])
    #expect(abs((player.playedVolumes.first ?? 0) - 0.704) < 0.0001)
    #expect(abs((player.playedVolumes.last ?? 0) - 0.704) < 0.0001)
}

@MainActor
@Test
func audioFeedbackAppliesSeparateRateLimitsForErrorAndPermissionSignals() {
    let suiteName = "audioFeedbackAppliesSeparateRateLimitsForErrorAndPermissionSignals"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    var now = Date(timeIntervalSince1970: 2_000)
    let player = MockAudioCuePlayer()
    let service = AudioFeedbackService(
        defaults: defaults,
        player: player,
        minInterval: 0,
        errorMinInterval: 3.0,
        permissionMinInterval: 10.0,
        now: { now }
    )
    service.setEnabled(true)

    service.playError()
    service.playError()
    #expect(player.playedNames == [NSSound.Name("Morse")])

    now = now.addingTimeInterval(3.1)
    service.playError()
    #expect(player.playedNames == [NSSound.Name("Morse"), NSSound.Name("Morse")])

    service.playPermissionNeeded()
    service.playPermissionNeeded()
    #expect(player.playedNames.last == NSSound.Name("Ping"))
    #expect(player.playedNames.filter { $0 == NSSound.Name("Ping") }.count == 1)

    now = now.addingTimeInterval(10.1)
    service.playPermissionNeeded()
    #expect(player.playedNames.filter { $0 == NSSound.Name("Ping") }.count == 2)
}

@MainActor
@Test
func audioFeedbackUsesSelectedPresetAndPersistsIt() {
    let suiteName = "audioFeedbackUsesSelectedPresetAndPersistsIt"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    let player = MockAudioCuePlayer()
    let service = AudioFeedbackService(
        defaults: defaults,
        player: player,
        minInterval: 0,
        now: Date.init
    )
    service.setEnabled(true)
    service.setSoundPreset(.ultraSoft)
    service.play(for: MicrophoneFeedbackState(
        isMuted: true,
        volumePercent: 0,
        triggerSource: .globalHotkey,
        timestamp: .now
    ))
    #expect(player.playedNames.last == NSSound.Name("Purr"))

    let restored = AudioFeedbackService(
        defaults: defaults,
        player: player,
        minInterval: 0,
        now: Date.init
    )
    #expect(restored.soundPreset == .ultraSoft)
}

@MainActor
@Test
func visualFeedbackDefaultsToEnabledAndPersistsUpdates() {
    let suiteName = "visualFeedbackDefaultsToEnabledAndPersistsUpdates"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    let service = VisualFeedbackService(defaults: defaults)
    #expect(service.isEnabled)

    service.setEnabled(false)
    #expect(service.isEnabled == false)

    let restored = VisualFeedbackService(defaults: defaults)
    #expect(restored.isEnabled == false)
}

@MainActor
@Test
func localizationServicePersistsLanguageAndReturnsLocalizedStrings() {
    let suiteName = "localizationServicePersistsLanguageAndReturnsLocalizedStrings"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)

    let service = LocalizationService(defaults: defaults)
    service.setLanguage(.russian)
    #expect(service.selectedLanguage == .russian)
    #expect(service.string("menu.microphone") == "Микрофон")

    let restored = LocalizationService(defaults: defaults)
    #expect(restored.selectedLanguage == .russian)
    #expect(restored.string("menu.quit") == "Выйти")
}

private final class MockAudioCuePlayer: AudioCuePlayer {
    var playedNames: [NSSound.Name] = []
    var playedVolumes: [Float] = []
    var beepCount = 0
    var shouldPlaySucceed = true

    func playSound(named: NSSound.Name, volume: Float) -> Bool {
        playedNames.append(named)
        playedVolumes.append(volume)
        return shouldPlaySucceed
    }

    func playBeep() {
        beepCount += 1
    }
}
