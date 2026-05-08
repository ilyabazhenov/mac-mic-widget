import Testing
@testable import MacMicWidget

@Test
func statusItemPresentationUsesMutedSymbolAndZeroLevel() {
    let presentation = StatusItemPresentationLogic.makePresentation(isMuted: true, inputVolume: 0.84)

    #expect(presentation.symbolName == "mic.slash.and.signal.meter.fill")
    #expect(presentation.variableValue == 0)
    #expect(presentation.usesContentTint == false)
}

@Test
func statusItemPresentationUsesActiveSymbolWithoutTint() {
    let presentation = StatusItemPresentationLogic.makePresentation(isMuted: false, inputVolume: 0.5)

    #expect(presentation.symbolName == "mic.and.signal.meter.fill")
    #expect(presentation.usesContentTint == false)
}

@Test
func statusItemPresentationBoostsLowNonMutedLevels() {
    let inputVolume: Float = 0.1

    let boostedVisualLevel = StatusItemPresentationLogic.visualLevel(from: inputVolume)
    let linearLevel = Double(inputVolume)

    #expect(boostedVisualLevel > linearLevel)
    #expect(boostedVisualLevel < 1)
    #expect(boostedVisualLevel >= 0.18)
}

@Test
func statusItemPresentationVisualLevelIsClamped() {
    #expect(StatusItemPresentationLogic.visualLevel(from: -0.5) == 0)
    #expect(StatusItemPresentationLogic.visualLevel(from: 2.0) == 1)
}

@Test
func statusItemPresentationVisualLevelDistinguishesKeyLevels() {
    let keyLevels: [Float] = [0.05, 0.10, 0.25, 0.50, 0.75, 1.0]
    let visualLevels = keyLevels.map(StatusItemPresentationLogic.visualLevel(from:))

    for index in 1..<visualLevels.count {
        #expect(visualLevels[index] > visualLevels[index - 1])
    }
    #expect(visualLevels[0] >= 0.18)
    #expect(visualLevels.last == 1)
}

@Test
func statusItemTooltipUsesDefaultClickBehaviorKeys() {
    #expect(
        StatusItemPresentationLogic.tooltipKey(
            isMuted: true,
            clickBehavior: .openControlsOnLeftClick
        ) == "tooltip.muted.open_controls_on_left_click"
    )
    #expect(
        StatusItemPresentationLogic.tooltipKey(
            isMuted: false,
            clickBehavior: .openControlsOnLeftClick
        ) == "tooltip.active.open_controls_on_left_click"
    )
}

@Test
func statusItemTooltipUsesFastClickBehaviorKeys() {
    #expect(
        StatusItemPresentationLogic.tooltipKey(
            isMuted: true,
            clickBehavior: .toggleMuteOnLeftClick
        ) == "tooltip.muted.toggle_mute_on_left_click"
    )
    #expect(
        StatusItemPresentationLogic.tooltipKey(
            isMuted: false,
            clickBehavior: .toggleMuteOnLeftClick
        ) == "tooltip.active.toggle_mute_on_left_click"
    )
}
