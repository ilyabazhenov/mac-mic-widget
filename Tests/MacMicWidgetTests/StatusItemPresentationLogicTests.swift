import Testing
@testable import MacMicWidget

@Test
func statusItemPresentationUsesMutedSymbolAndZeroLevel() {
    let presentation = StatusItemPresentationLogic.makePresentation(isMuted: true, inputVolume: 0.84)

    #expect(presentation.symbolName == "mic.slash.and.signal.meter.fill")
    #expect(presentation.variableValue == 0)
}

@Test
func statusItemPresentationBoostsLowNonMutedLevels() {
    let inputVolume: Float = 0.1

    let boostedVisualLevel = StatusItemPresentationLogic.visualLevel(from: inputVolume)
    let linearLevel = Double(inputVolume)

    #expect(boostedVisualLevel > linearLevel)
    #expect(boostedVisualLevel < 1)
    #expect(boostedVisualLevel >= 0.34)
}

@Test
func statusItemPresentationVisualLevelIsClamped() {
    #expect(StatusItemPresentationLogic.visualLevel(from: -0.5) == 0)
    #expect(StatusItemPresentationLogic.visualLevel(from: 2.0) == 1)
}
