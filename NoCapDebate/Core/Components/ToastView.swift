//
//  ToastView.swift
//  DebateFeedback
//
//  Toast notification component for non-critical feedback
//

import SwiftUI

// MARK: - Toast View

struct ToastView: View {
    let message: String
    let icon: String
    let type: ToastType

    enum ToastType {
        case success
        case error
        case info
        case warning

        var color: Color {
            switch self {
            case .success:
                return Constants.Colors.complete
            case .error:
                return Constants.Colors.failed
            case .info:
                return Constants.Colors.primaryBlue
            case .warning:
                return Constants.Colors.warning
            }
        }

        var iconColor: Color {
            return .white
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(type.iconColor)

            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(type.color)
                .shadow(color: type.color.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(typeDescription): \(message)")
    }

    private var typeDescription: String {
        switch type {
        case .success:
            return "Success"
        case .error:
            return "Error"
        case .info:
            return "Information"
        case .warning:
            return "Warning"
        }
    }
}

// MARK: - Toast Modifier

struct ToastModifier: ViewModifier {
    @Binding var isShowing: Bool
    let message: String
    let icon: String
    let type: ToastView.ToastType
    let duration: TimeInterval

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content

            if isShowing {
                VStack {
                    Spacer()

                    ToastView(message: message, icon: icon, type: type)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    isShowing = false
                                }
                            }
                        }
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isShowing)
    }
}

// MARK: - View Extension

extension View {
    /// Show a toast notification
    func toast(
        isShowing: Binding<Bool>,
        message: String,
        icon: String = "checkmark.circle.fill",
        type: ToastView.ToastType = .success,
        duration: TimeInterval = 2.0
    ) -> some View {
        self.modifier(
            ToastModifier(
                isShowing: isShowing,
                message: message,
                icon: icon,
                type: type,
                duration: duration
            )
        )
    }
}

// MARK: - Toast Manager (Observable)

@Observable
class ToastManager {
    var isShowing = false
    var message = ""
    var icon = "checkmark.circle.fill"
    var type: ToastView.ToastType = .success

    func show(_ message: String, icon: String = "checkmark.circle.fill", type: ToastView.ToastType = .success) {
        self.message = message
        self.icon = icon
        self.type = type
        self.isShowing = true

        // Add haptic feedback
        switch type {
        case .success:
            HapticManager.shared.success()
        case .error:
            HapticManager.shared.error()
        case .warning:
            HapticManager.shared.warning()
        case .info:
            HapticManager.shared.light()
        }
    }

    func success(_ message: String, icon: String = "checkmark.circle.fill") {
        show(message, icon: icon, type: .success)
    }

    func error(_ message: String, icon: String = "xmark.circle.fill") {
        show(message, icon: icon, type: .error)
    }

    func info(_ message: String, icon: String = "info.circle.fill") {
        show(message, icon: icon, type: .info)
    }

    func warning(_ message: String, icon: String = "exclamationmark.triangle.fill") {
        show(message, icon: icon, type: .warning)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ToastView(message: "Student added successfully", icon: "checkmark.circle.fill", type: .success)
        ToastView(message: "Failed to upload recording", icon: "xmark.circle.fill", type: .error)
        ToastView(message: "Processing your feedback", icon: "info.circle.fill", type: .info)
        ToastView(message: "Less than 1 minute remaining", icon: "exclamationmark.triangle.fill", type: .warning)
    }
    .padding()
}
