import Foundation
#if canImport(Combine)
import Combine
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Supported languages for the app
enum AppLanguage: String, CaseIterable, Codable {
    case system = "system"
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case chinese = "zh-Hans"
    case japanese = "ja"
    case latvian = "lv"
    case russian = "ru"

    /// Display name shown in Settings (in native language)
    var displayName: String {
        switch self {
        case .system: return AppLanguage.localizedSystemDefault()
        case .english: return "English"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .chinese: return "中文"
        case .japanese: return "日本語"
        case .latvian: return "Latviešu"
        case .russian: return "Русский"
        }
    }

    /// Get "System Default" localized to the currently selected app language
    private static func localizedSystemDefault() -> String {
        #if canImport(Combine)
        let selectedLanguage = LanguageManager.shared.selectedLanguage
        // If system is selected, use standard localization
        guard selectedLanguage != .system else {
            return String(localized: "language.system", defaultValue: "System Default")
        }
        // Load from the appropriate .lproj bundle
        let languageCode = selectedLanguage.rawValue
        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: "language.system", value: "System Default", table: "Localizable")
        }
        #endif
        return String(localized: "language.system", defaultValue: "System Default")
    }

    /// Returns the Locale for this language, or nil for system default
    var locale: Locale? {
        switch self {
        case .system: return nil
        case .english: return Locale(identifier: "en")
        case .spanish: return Locale(identifier: "es")
        case .french: return Locale(identifier: "fr")
        case .german: return Locale(identifier: "de")
        case .chinese: return Locale(identifier: "zh-Hans")
        case .japanese: return Locale(identifier: "ja")
        case .latvian: return Locale(identifier: "lv")
        case .russian: return Locale(identifier: "ru")
        }
    }
}

// MARK: - Language Manager (Main App Only)
// LanguageManager requires Combine which is not available in widget extensions.
// The widget reads language preferences directly from shared UserDefaults.

#if canImport(Combine)
/// Manages app-wide language settings, stored in shared UserDefaults for widget access
class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    private let languageKey = "app_language"
    private var cancellables = Set<AnyCancellable>()

    /// Use shared UserDefaults so widget can access the language preference
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: userDefaultsSuite)
    }

    @Published var selectedLanguage: AppLanguage = .system

    /// The effective locale to use (selected language or system default)
    var effectiveLocale: Locale {
        selectedLanguage.locale ?? Locale.current
    }

    private init() {
        // Load saved language preference
        if let savedLanguage = sharedDefaults?.string(forKey: languageKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            selectedLanguage = language
        }

        // Set up Combine subscription for persistence (after loading initial value)
        $selectedLanguage
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] value in
                guard let self = self else { return }
                self.sharedDefaults?.set(value.rawValue, forKey: self.languageKey)
                self.sharedDefaults?.synchronize()

                // Refresh widget when language changes
                #if canImport(WidgetKit)
                WidgetCenter.shared.reloadAllTimelines()
                #endif
            }
            .store(in: &cancellables)
    }
}
#endif
