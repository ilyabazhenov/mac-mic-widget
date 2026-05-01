import Foundation

@MainActor
final class VisualFeedbackService: ObservableObject {
    @Published private(set) var isEnabled: Bool

    private let defaults: UserDefaults
    private static let isEnabledKey = "visualFeedback.enabled"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isEnabled = defaults.object(forKey: Self.isEnabledKey) as? Bool ?? true
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.isEnabledKey)
    }
}
