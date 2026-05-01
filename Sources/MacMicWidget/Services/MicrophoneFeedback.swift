import Foundation

enum MicrophoneChangeSource: Equatable {
    case statusItemSecondaryClick
    case globalHotkey
    case popoverButton
    case popoverSlider
    case automatedRule

    var isExternalFeedbackEligible: Bool {
        switch self {
        case .statusItemSecondaryClick, .globalHotkey, .automatedRule:
            return true
        case .popoverButton, .popoverSlider:
            return false
        }
    }
}

struct MicrophoneFeedbackState: Equatable {
    let isMuted: Bool
    let volumePercent: Int
    let triggerSource: MicrophoneChangeSource
    let timestamp: Date
}

enum FloatingHUDPresentationLogic {
    @MainActor
    static func title(for state: MicrophoneFeedbackState, localizationService: LocalizationService) -> String {
        if state.isMuted {
            return localizationService.string("hud.off")
        }
        return localizationService.string("hud.on", state.volumePercent)
    }
}
