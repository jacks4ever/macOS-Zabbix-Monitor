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
        case .system: return String(localized: "language.system", defaultValue: "System Default")
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

    /// Use shared UserDefaults so widget can access the language preference
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: userDefaultsSuite)
    }

    @Published var selectedLanguage: AppLanguage = .system {
        didSet {
            sharedDefaults?.set(selectedLanguage.rawValue, forKey: languageKey)
            sharedDefaults?.synchronize()

            // Refresh widget when language changes
            #if canImport(WidgetKit)
            DispatchQueue.main.async {
                WidgetCenter.shared.reloadAllTimelines()
            }
            #endif
        }
    }

    /// The effective locale to use (selected language or system default)
    var effectiveLocale: Locale {
        selectedLanguage.locale ?? Locale.current
    }

    private init() {
        // Load saved language preference after initialization
        if let savedLanguage = sharedDefaults?.string(forKey: languageKey),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.selectedLanguage = language
        }
    }
}
#endif
