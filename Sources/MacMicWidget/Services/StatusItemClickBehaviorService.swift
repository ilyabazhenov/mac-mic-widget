import Foundation

enum StatusItemClickBehavior: String, CaseIterable, Identifiable {
    case openControlsOnLeftClick
    case toggleMuteOnLeftClick

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .openControlsOnLeftClick:
            return "menu.left_click_open_controls"
        case .toggleMuteOnLeftClick:
            return "menu.left_click_toggle_mute"
        }
    }
}

@MainActor
final class StatusItemClickBehaviorService: ObservableObject {
    @Published private(set) var clickBehavior: StatusItemClickBehavior

    private let defaults: UserDefaults
    static let defaultsKey = "statusItem.clickBehavior"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if
            let raw = defaults.string(forKey: Self.defaultsKey),
            let clickBehavior = StatusItemClickBehavior(rawValue: raw)
        {
            self.clickBehavior = clickBehavior
        } else {
            self.clickBehavior = .openControlsOnLeftClick
        }
    }

    func setClickBehavior(_ clickBehavior: StatusItemClickBehavior) {
        self.clickBehavior = clickBehavior
        defaults.set(clickBehavior.rawValue, forKey: Self.defaultsKey)
    }
}
