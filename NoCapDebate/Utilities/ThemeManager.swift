//
//  ThemeManager.swift
//  DebateFeedback
//
//  Manages theme preference across the app
//

import SwiftUI

@Observable
class ThemeManager {
    static let shared = ThemeManager()

    var currentTheme: Constants.Theme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: Constants.UserDefaultsKeys.themePreference)
        }
    }

    private init() {
        // Load saved preference or default to dark
        if let savedTheme = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.themePreference),
           let theme = Constants.Theme(rawValue: savedTheme) {
            self.currentTheme = theme
        } else {
            self.currentTheme = .dark
            UserDefaults.standard.set(Constants.Theme.dark.rawValue, forKey: Constants.UserDefaultsKeys.themePreference)
        }
    }

    var preferredColorScheme: ColorScheme? {
        currentTheme.colorScheme
    }
}
