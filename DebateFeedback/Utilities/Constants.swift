//
//  Constants.swift
//  DebateFeedback
//
//

import SwiftUI

enum Constants {

    // MARK: - API Configuration
    enum API {
        #if DEBUG
        // Note: To use localhost, App Transport Security (ATS) must be configured in Info.plist to allow arbitrary loads.
        // Defaulting to production for now to ensure it works out of the box.
        // static let baseURL = "http://localhost:3000/api" 
        static let baseURL = "https://api.genalphai.com/api"
        static let useMockData = false
        #else
        static let baseURL = "https://api.genalphai.com/api"
        static let useMockData = false
        #endif
        
        static let requestTimeout: TimeInterval = 30.0
        static let uploadTimeout: TimeInterval = 120.0
        static let maxRetryAttempts = 3
        static let feedbackPollingInterval: TimeInterval = 5.0
    }

    // MARK: - Audio Configuration
    enum Audio {
        static let fileExtension = "m4a"
        static let sampleRate: Double = 44100.0
        static let bitRate = 128000 // 128kbps
        static let numberOfChannels = 1 // Mono

        // Bell timings (in seconds)
        static let firstBellTime: TimeInterval = 60.0
        static let overtimeBellInterval: TimeInterval = 15.0

        // Audio file names
        static let bellSingleSound = "bell_1"
        static let bellDoubleSound = "bell_2"
        static let bellTripleSound = "bell_3"
    }

    // MARK: - Timer Configuration
    enum Timer {
        static let displayRefreshRate = 60 // FPS for timer updates
        static let timerAccuracyTolerance: TimeInterval = 0.1 // ±100ms
    }

    // MARK: - UI Colors
    enum Colors {
        // MARK: Light Mode Colors

        // Background colors - Light clean theme
        static let lightBackgroundPrimary = Color.white // Pure white
        static let lightBackgroundSecondary = Color(red: 0.98, green: 0.98, blue: 0.99) // #fafafe - Very light gray
        static let lightBackgroundTertiary = Color(red: 0.95, green: 0.96, blue: 0.98) // #f2f4f9 - Light blue-gray
        static let lightCardBackground = Color.white // White cards with shadows

        // MARK: Dark Mode Colors

        // Background colors - Dark theme
        static let darkBackgroundPrimary = Color.black // True black
        static let darkBackgroundSecondary = Color(red: 0.10, green: 0.10, blue: 0.12) // Very dark gray
        static let darkBackgroundTertiary = Color(red: 0.20, green: 0.20, blue: 0.22) // #333338 - Lighter dark gray
        static let darkCardBackground = Color(red: 0.16, green: 0.16, blue: 0.18) // #28282e - Card background

        // MARK: Adaptive Colors (switch based on color scheme)

        static var backgroundLight: Color {
            Color.adaptiveColor(light: lightBackgroundPrimary, dark: darkBackgroundPrimary)
        }

        static var backgroundSecondary: Color {
            Color.adaptiveColor(light: lightBackgroundSecondary, dark: darkBackgroundSecondary)
        }

        static var backgroundTertiary: Color {
            Color.adaptiveColor(light: lightBackgroundTertiary, dark: darkBackgroundTertiary)
        }

        static var cardBackground: Color {
            Color.adaptiveColor(light: lightCardBackground, dark: darkCardBackground)
        }

        // Mascot-inspired colors (from Ollie the Owl)
        static let mascotNavy = Color(red: 0.12, green: 0.23, blue: 0.37) // #1e3a5f - Navy blue
        static let mascotPink = Color(red: 0.97, green: 0.14, blue: 0.52) // #f72585 - Hot pink
        static let mascotLightBlue = Color(red: 0.86, green: 0.91, blue: 1.0) // #dbe9ff - Light blue

        // Enhanced colors for UI
        static let softPink = mascotPink // Use mascot pink
        static let softMint = Color(red: 0.50, green: 0.90, blue: 0.75) // #80e6bf - Vibrant mint
        static let softCyan = Color(red: 0.45, green: 0.80, blue: 0.95) // #73ccf2 - Vibrant cyan
        static let softPurple = Color(red: 0.75, green: 0.65, blue: 0.95) // #bfa6f2 - Vibrant purple

        // Blue buttons (more vibrant)
        static let primaryBlue = Color(red: 0.20, green: 0.52, blue: 0.95) // #3385f2 - More vibrant blue
        static let primaryBlueDark = Color(red: 0.15, green: 0.42, blue: 0.88) // #2668e0 - Darker vibrant blue

        // Primary action colors
        static let primaryAction = primaryBlue
        static let secondaryAction = softPink
        static let tertiaryAction = softMint

        // Status colors
        static let recordingActive = Color.red
        static let success = softMint
        static let warning = Color(red: 1.0, green: 0.85, blue: 0.60) // Soft orange
        static let error = Color(red: 1.0, green: 0.70, blue: 0.70) // Soft red

        // Text colors - Light mode
        static let lightTextPrimary = Color(red: 0.12, green: 0.12, blue: 0.15) // #1e1e26 - Almost black
        static let lightTextSecondary = Color(red: 0.45, green: 0.45, blue: 0.50) // #737380 - Medium gray
        static let lightTextTertiary = Color(red: 0.65, green: 0.65, blue: 0.70) // #a6a6b3 - Light gray

        // Text colors - Dark mode
        static let darkTextPrimary = Color(red: 0.95, green: 0.95, blue: 0.97) // #f2f2f7 - Almost white
        static let darkTextSecondary = Color(red: 0.60, green: 0.60, blue: 0.65) // #99999a - Medium gray
        static let darkTextTertiary = Color(red: 0.40, green: 0.40, blue: 0.45) // #666673 - Dark gray

        // Adaptive text colors
        static var textPrimary: Color {
            Color.adaptiveColor(light: lightTextPrimary, dark: darkTextPrimary)
        }

        static var textSecondary: Color {
            Color.adaptiveColor(light: lightTextSecondary, dark: darkTextSecondary)
        }

        static var textTertiary: Color {
            Color.adaptiveColor(light: lightTextTertiary, dark: darkTextTertiary)
        }

        static let textOnButton = Color.white // White text on colored buttons

        static var textOnCard: Color {
            textPrimary // Adapts with textPrimary
        }

        // Team colors - soft pastels
        static let propTeam = softCyan
        static let oppTeam = softPink

        // BP Teams
        static let ogTeam = softCyan
        static let ooTeam = softPink
        static let cgTeam = softMint
        static let coTeam = softPurple

        // Status colors
        static let pending = Color.gray
        static let uploading = softCyan
        static let uploaded = softMint
        static let failed = error
        static let processing = softPurple
        static let complete = softMint
    }

    // MARK: - Gradients
    enum Gradients {
        // Blue gradient for primary buttons
        static let primaryButton = LinearGradient(
            colors: [Colors.primaryBlue, Colors.primaryBlueDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let secondaryButton = LinearGradient(
            colors: [Colors.softPink],
            startPoint: .leading,
            endPoint: .trailing
        )

        static let propTeam = LinearGradient(
            colors: [Colors.softCyan],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let oppTeam = LinearGradient(
            colors: [Colors.softPink],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let background = LinearGradient(
            colors: [Colors.backgroundLight],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - UI Sizing
    enum Sizing {
        static let minimumTapTarget: CGFloat = 44.0
        static let buttonCornerRadius: CGFloat = 12.0
        static let cardCornerRadius: CGFloat = 16.0
        static let standardPadding: CGFloat = 16.0
        static let compactPadding: CGFloat = 8.0

        // Timer display
        static let timerFontSizeiPhone: CGFloat = 72.0
        static let timerFontSizeiPad: CGFloat = 120.0
    }

    // MARK: - Animation
    enum Animation {
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let spring = SwiftUI.Animation.spring(response: 0.5, dampingFraction: 0.7)
    }

    // MARK: - Theme Configuration
    enum Theme: String, CaseIterable {
        case light
        case dark
        case system

        var displayName: String {
            switch self {
            case .light:
                return "Light"
            case .dark:
                return "Dark"
            case .system:
                return "System"
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .light:
                return .light
            case .dark:
                return .dark
            case .system:
                return nil
            }
        }
    }

    // MARK: - User Defaults Keys
    enum UserDefaultsKeys {
        static let deviceId = "com.debatefeedback.deviceId"
        static let authToken = "com.debatefeedback.authToken"
        static let currentTeacherId = "com.debatefeedback.teacherId"
        static let isGuestMode = "com.debatefeedback.isGuestMode"
        static let hasShownOnboarding = "com.debatefeedback.hasShownOnboarding"
        static let themePreference = "com.debatefeedback.themePreference"
    }

    // MARK: - File Management
    enum Files {
        static let audioDirectory = "Recordings"
        static let maxLocalStorageDays = 1 // Delete files older than 24 hours
    }

    // MARK: - Debate Formats
    static let debateFormats: [DebateFormat] = [.wsdc, .bp, .ap, .australs]

    // MARK: - Validation
    enum Validation {
        static let minimumMotionLength = 5
        static let maximumMotionLength = 200
        static let minimumSpeakerName = 2
        static let maximumSpeakerName = 50
        static let minimumSpeechTime = 60 // 1 minute
        static let maximumSpeechTime = 900 // 15 minutes
    }

    // MARK: - Error Messages
    enum ErrorMessages {
        static let networkUnavailable = "No internet connection. Please check your network settings."
        static let uploadFailed = "Failed to upload recording. Tap to retry."
        static let microphonePermissionDenied = "Microphone access is required. Please enable it in Settings."
        static let recordingFailed = "Failed to start recording. Please try again."
        static let invalidMotion = "Please enter a valid motion (5-200 characters)."
        static let noStudentsSelected = "Please add at least one student to each team."
        static let teamAssignmentIncomplete = "Please assign all students to teams."
    }
}

// MARK: - Device Type Helper
extension Constants {
    static var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    static var timerFontSize: CGFloat {
        isIPad ? Sizing.timerFontSizeiPad : Sizing.timerFontSizeiPhone
    }
}

// MARK: - Color Extension for Adaptive Colors
extension Color {
    /// Creates a color that adapts to the current color scheme
    static func adaptiveColor(light: Color, dark: Color) -> Color {
        Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            case .light, .unspecified:
                return UIColor(light)
            @unknown default:
                return UIColor(light)
            }
        })
    }
}
