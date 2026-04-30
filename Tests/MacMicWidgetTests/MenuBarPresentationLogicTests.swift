import Testing
@testable import MacMicWidget

@Test
func menuBarPresentationRoundsAndClampsVolumePercent() {
    #expect(MenuBarPresentationLogic.volumePercent(from: -0.1) == 0)
    #expect(MenuBarPresentationLogic.volumePercent(from: 0.295) == 29)
    #expect(MenuBarPresentationLogic.volumePercent(from: 1.8) == 100)
}

@Test
func menuBarPresentationLevelLabelThresholds() {
    #expect(MenuBarPresentationLogic.levelLabel(isMuted: true, volumePercent: 80) == .muted)
    #expect(MenuBarPresentationLogic.levelLabel(isMuted: false, volumePercent: 29) == .low)
    #expect(MenuBarPresentationLogic.levelLabel(isMuted: false, volumePercent: 30) == .medium)
    #expect(MenuBarPresentationLogic.levelLabel(isMuted: false, volumePercent: 60) == .medium)
    #expect(MenuBarPresentationLogic.levelLabel(isMuted: false, volumePercent: 61) == .high)
}
