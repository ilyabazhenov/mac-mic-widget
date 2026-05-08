import Foundation

enum VisualFeedbackScreenMode: String, CaseIterable, Identifiable {
    case main
    case active

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .main:
            return "menu.visual_notification_screen_main"
        case .active:
            return "menu.visual_notification_screen_active"
        }
    }
}

@MainActor
final class VisualFeedbackService: ObservableObject {
    @Published private(set) var isEnabled: Bool
    @Published private(set) var screenMode: VisualFeedbackScreenMode

    private let defaults: UserDefaults
    private static let isEnabledKey = "visualFeedback.enabled"
    private static let screenModeKey = "visualFeedback.screenMode"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isEnabled = defaults.object(forKey: Self.isEnabledKey) as? Bool ?? true
        if
            let rawScreenMode = defaults.string(forKey: Self.screenModeKey),
            let screenMode = VisualFeedbackScreenMode(rawValue: rawScreenMode)
        {
            self.screenMode = screenMode
        } else {
            self.screenMode = .main
        }
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.isEnabledKey)
    }

    func setScreenMode(_ screenMode: VisualFeedbackScreenMode) {
        self.screenMode = screenMode
        defaults.set(screenMode.rawValue, forKey: Self.screenModeKey)
    }
}
