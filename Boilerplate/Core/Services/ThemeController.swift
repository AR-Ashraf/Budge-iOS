import SwiftUI

/// Central theme state: one place to read/write appearance and drive root `preferredColorScheme`.
/// Call ``preference`` from any view via `@Environment(ThemeController.self)`.
@Observable
@MainActor
final class ThemeController {
    /// Matches ``UserDefaultsWrapper/selectedTheme`` (`"selectedTheme"`).
    var preference: AppThemeOption {
        didSet {
            guard preference != oldValue else { return }
            UserDefaultsWrapper.selectedTheme = preference.rawValue
        }
    }

    /// For `View.preferredColorScheme` on the app root (`nil` = system).
    var preferredColorScheme: ColorScheme? {
        preference.colorScheme
    }

    init() {
        Self.migrateLegacyKeysIfNeeded()
        let raw = UserDefaults.standard.string(forKey: "selectedTheme")
            ?? UserDefaultsWrapper.selectedTheme
        preference = AppThemeOption(rawValue: raw) ?? .system
    }

    /// Cycle light ↔ dark; if preference is system, toggles relative to the current system style.
    func toggleLightDark(currentSystemScheme: ColorScheme) {
        switch preference {
        case .light:
            preference = .dark
        case .dark:
            preference = .light
        case .system:
            preference = currentSystemScheme == .dark ? .light : .dark
        }
    }

    private static func migrateLegacyKeysIfNeeded() {
        let defaults = UserDefaults.standard
        let key = "selectedTheme"

        if let legacy = defaults.string(forKey: "themePreference") {
            if defaults.string(forKey: key) == nil {
                defaults.set(legacy, forKey: key)
            }
            defaults.removeObject(forKey: "themePreference")
        }

        let oldFinancial = "financialSetupThemePreference"
        if let old = defaults.string(forKey: oldFinancial), defaults.string(forKey: key) == nil {
            defaults.set(old, forKey: key)
            defaults.removeObject(forKey: oldFinancial)
        }
    }
}
