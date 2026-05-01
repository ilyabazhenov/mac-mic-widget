import Foundation

struct StatusItemPresentation: Equatable {
    let symbolName: String
    let variableValue: Double
}

enum StatusItemPresentationLogic {
    // < 1 boosts low values, making 5-25% more readable in the menu bar icon.
    private static let lowLevelGamma: Double = 0.65
    // Keep active state visually obvious at a quick glance.
    private static let minimumActiveVisualLevel: Double = 0.34

    static func makePresentation(isMuted: Bool, inputVolume: Float) -> StatusItemPresentation {
        if isMuted {
            return StatusItemPresentation(
                symbolName: "mic.slash.fill",
                variableValue: 0
            )
        }

        return StatusItemPresentation(
            symbolName: "mic.and.signal.meter.fill",
            variableValue: visualLevel(from: inputVolume)
        )
    }

    static func visualLevel(from inputVolume: Float) -> Double {
        let normalized = Double(clamp(inputVolume))
        guard normalized > 0 else {
            return 0
        }

        let boosted = pow(normalized, lowLevelGamma)
        let emphasized = max(boosted, minimumActiveVisualLevel)
        return min(1, max(0, emphasized))
    }
}
