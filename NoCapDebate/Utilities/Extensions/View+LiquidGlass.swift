//
//  View+LiquidGlass.swift
//  DebateFeedback
//
//  Apple's Liquid Glass material effects for modern iOS design
//

import SwiftUI

// MARK: - Liquid Glass Material Variants

enum LiquidGlassMaterial {
    case thin      // For interactive elements like buttons or selected items
    case regular   // Separate sections like sidebars or grouped table views
    case thick     // Create dark, distinct elements on top of regular background
}

// MARK: - Liquid Glass Modifier

struct LiquidGlassModifier: ViewModifier {
    let material: LiquidGlassMaterial
    let borderColor: Color
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Base material layer
                    materialBackground
                        .cornerRadius(cornerRadius)

                    // Refraction layer - simulates light passing through glass
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.15),
                                    Color.clear,
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blur(radius: 1)
                }
            )
            .overlay(
                // Specular highlights - creates the glass reflection effect
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                borderColor.opacity(0.8),
                                borderColor.opacity(0.3),
                                borderColor.opacity(0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: materialThickness
                    )
            )
            .shadow(color: borderColor.opacity(0.4), radius: 12, x: 0, y: 4)
            .shadow(color: borderColor.opacity(0.2), radius: 24, x: 0, y: 8)
    }

    private var materialBackground: some View {
        Group {
            switch material {
            case .thin:
                // Thin material - for interactive elements
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .background(Constants.Colors.cardBackground.opacity(0.3))
            case .regular:
                // Regular material - for section separation
                Rectangle()
                    .fill(.regularMaterial)
                    .background(Constants.Colors.cardBackground.opacity(0.5))
            case .thick:
                // Thick material - for prominent elements
                Rectangle()
                    .fill(.thickMaterial)
                    .background(Constants.Colors.cardBackground.opacity(0.7))
            }
        }
    }

    private var materialThickness: CGFloat {
        switch material {
        case .thin: return 1.5
        case .regular: return 2.0
        case .thick: return 2.5
        }
    }
}

// MARK: - Floating Card Modifier

struct FloatingCardModifier: ViewModifier {
    let gradient: LinearGradient
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Base translucent layer
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.regularMaterial)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Constants.Colors.cardBackground.opacity(0.6))
                        )

                    // Gradient overlay for depth
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            gradient.opacity(0.15)
                        )

                    // Specular highlight layer
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .center
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Constants.Colors.softCyan.opacity(0.6),
                                Constants.Colors.softPink.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Constants.Colors.softCyan.opacity(0.3), radius: 16, x: 0, y: 8)
            .shadow(color: Constants.Colors.softPink.opacity(0.2), radius: 32, x: 0, y: 16)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
    }
}

// MARK: - View Extensions

extension View {
    /// Apply Liquid Glass material effect with specified variant
    func liquidGlass(
        material: LiquidGlassMaterial = .regular,
        borderColor: Color = Constants.Colors.softCyan,
        cornerRadius: CGFloat = 20
    ) -> some View {
        self.modifier(LiquidGlassModifier(
            material: material,
            borderColor: borderColor,
            cornerRadius: cornerRadius
        ))
    }

    /// Apply floating card effect with translucent background
    func floatingCard(gradient: LinearGradient = Constants.Gradients.primaryButton) -> some View {
        self.modifier(FloatingCardModifier(gradient: gradient))
    }

    /// Apply dynamic vibrancy effect for text over translucent backgrounds
    func vibrancyEffect() -> some View {
        self
            .foregroundStyle(.primary)
            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Liquid Glass Button Style

struct LiquidGlassButtonStyle: ButtonStyle {
    let gradient: LinearGradient
    let material: LiquidGlassMaterial

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 16)
            .padding(.horizontal, 32)
            .background(
                ZStack {
                    // Base material
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.thinMaterial)

                    // Gradient overlay
                    RoundedRectangle(cornerRadius: 16)
                        .fill(gradient.opacity(0.8))

                    // Specular highlight
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
            )
            .foregroundColor(.white)
            .shadow(color: Constants.Colors.softCyan.opacity(0.5), radius: 12, x: 0, y: 6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

extension View {
    func liquidGlassButton(
        gradient: LinearGradient = Constants.Gradients.primaryButton,
        material: LiquidGlassMaterial = .thin
    ) -> some View {
        self.buttonStyle(LiquidGlassButtonStyle(gradient: gradient, material: material))
    }
}
