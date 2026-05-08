import Foundation

struct StatusItemPresentation: Equatable {
    let symbolName: String
    let variableValue: Double
    let usesContentTint: Bool
}

enum StatusItemPresentationLogic {
    // < 1 boosts low values, making 5-25% more readable in the menu bar icon.
    private static let lowLevelGamma: Double = 0.70
    // Keep active state visible without flattening low levels into one value.
    private static let minimumActiveVisualLevel: Double = 0.18

    static func makePresentation(isMuted: Bool, inputVolume: Float) -> StatusItemPresentation {
        if isMuted {
            return StatusItemPresentation(
                symbolName: "mic.slash.and.signal.meter.fill",
                variableValue: 0,
                usesContentTint: false
            )
        }

        return StatusItemPresentation(
            symbolName: "mic.and.signal.meter.fill",
            variableValue: visualLevel(from: inputVolume),
            usesContentTint: false
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

    static func tooltipKey(isMuted: Bool, clickBehavior: StatusItemClickBehavior) -> String {
        switch (isMuted, clickBehavior) {
        case (true, .openControlsOnLeftClick):
            return "tooltip.muted.open_controls_on_left_click"
        case (false, .openControlsOnLeftClick):
            return "tooltip.active.open_controls_on_left_click"
        case (true, .toggleMuteOnLeftClick):
            return "tooltip.muted.toggle_mute_on_left_click"
        case (false, .toggleMuteOnLeftClick):
            return "tooltip.active.toggle_mute_on_left_click"
        }
    }
}
