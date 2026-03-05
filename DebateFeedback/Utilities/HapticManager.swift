//
//  HapticManager.swift
//  DebateFeedback
//
//  Haptic feedback manager for premium tactile interactions
//

import UIKit

/// Centralized manager for haptic feedback throughout the app
class HapticManager {
    static let shared = HapticManager()

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()

    private init() {
        // Prepare generators for faster response
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notification.prepare()
        selectionGenerator.prepare()
    }

    // MARK: - Impact Feedback

    /// Light impact for subtle button taps and selections
    func light() {
        impactLight.impactOccurred()
        impactLight.prepare()
    }

    /// Medium impact for standard interactions like team assignments
    func medium() {
        impactMedium.impactOccurred()
        impactMedium.prepare()
    }

    /// Heavy impact for important actions like starting/stopping recordings
    func heavy() {
        impactHeavy.impactOccurred()
        impactHeavy.prepare()
    }

    /// Selection feedback for picker-like interactions
    func selection() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    // MARK: - Notification Feedback

    /// Success notification (e.g., debate completed, upload successful)
    func success() {
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    /// Warning notification (e.g., 1 minute remaining)
    func warning() {
        notification.notificationOccurred(.warning)
        notification.prepare()
    }

    /// Error notification (e.g., upload failed, validation error)
    func error() {
        notification.notificationOccurred(.error)
        notification.prepare()
    }

    // MARK: - Convenience Methods

    /// Generic impact based on style
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        switch style {
        case .light:
            light()
        case .medium:
            medium()
        case .heavy:
            heavy()
        case .soft:
            light()
        case .rigid:
            heavy()
        @unknown default:
            medium()
        }
    }

    /// Generic notification based on type
    func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        switch type {
        case .success:
            success()
        case .warning:
            warning()
        case .error:
            error()
        @unknown default:
            break
        }
    }
}
