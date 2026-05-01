import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case russian

    var id: String { rawValue }

    var localeIdentifier: String? {
        switch self {
        case .system:
            return nil
        case .english:
            return "en"
        case .russian:
            return "ru"
        }
    }
}

@MainActor
final class LocalizationService: ObservableObject {
    @Published private(set) var selectedLanguage: AppLanguage

    private let defaults: UserDefaults
    private static let languageKey = "app.language"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if
            let raw = defaults.string(forKey: Self.languageKey),
            let language = AppLanguage(rawValue: raw)
        {
            self.selectedLanguage = language
        } else {
            self.selectedLanguage = .system
        }
    }

    func setLanguage(_ language: AppLanguage) {
        selectedLanguage = language
        defaults.set(language.rawValue, forKey: Self.languageKey)
    }

    func string(_ key: String) -> String {
        NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
    }

    func string(_ key: String, _ arguments: CVarArg...) -> String {
        let format = string(key)
        return String(format: format, locale: Locale(identifier: effectiveLanguageCode), arguments: arguments)
    }

    func displayName(for language: AppLanguage) -> String {
        switch language {
        case .system:
            return string("language.system")
        case .english:
            return string("language.english")
        case .russian:
            return string("language.russian")
        }
    }

    var effectiveLocale: Locale {
        Locale(identifier: effectiveLanguageCode)
    }

    private var effectiveLanguageCode: String {
        if let localeIdentifier = selectedLanguage.localeIdentifier {
            return localeIdentifier
        }

        if let preferred = Locale.preferredLanguages.first {
            if preferred.lowercased().hasPrefix("ru") {
                return "ru"
            }
        }
        return "en"
    }

    private var bundle: Bundle {
        if
            let path = Bundle.module.path(forResource: effectiveLanguageCode, ofType: "lproj"),
            let localizedBundle = Bundle(path: path)
        {
            return localizedBundle
        }
        return Bundle.module
    }
}
