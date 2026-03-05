//
//  SkeletonView.swift
//  DebateFeedback
//
//  Skeleton loading components for better perceived performance
//

import SwiftUI

// MARK: - Skeleton Modifier

struct SkeletonModifier: ViewModifier {
    @State private var shimmerOffset: CGFloat = -1

    let isLoading: Bool
    let animation: Animation

    init(isLoading: Bool = true, animation: Animation = .linear(duration: 1.5).repeatForever(autoreverses: false)) {
        self.isLoading = isLoading
        self.animation = animation
    }

    func body(content: Content) -> some View {
        content
            .opacity(isLoading ? 0.3 : 1.0)
            .overlay(
                Group {
                    if isLoading {
                        GeometryReader { geometry in
                            LinearGradient(
                                colors: [
                                    .clear,
                                    Constants.Colors.backgroundLight.opacity(0.6),
                                    .clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: geometry.size.width)
                            .offset(x: shimmerOffset * (geometry.size.width + 100))
                            .onAppear {
                                withAnimation(animation) {
                                    shimmerOffset = 2
                                }
                            }
                        }
                    }
                }
            )
            .accessibilityLabel(isLoading ? "Loading" : "")
    }
}

extension View {
    /// Apply skeleton loading effect
    func skeleton(isLoading: Bool = true) -> some View {
        self.modifier(SkeletonModifier(isLoading: isLoading))
    }
}

// MARK: - Skeleton Shapes

struct SkeletonRectangle: View {
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat

    init(width: CGFloat? = nil, height: CGFloat = 20, cornerRadius: CGFloat = 4) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Constants.Colors.textTertiary.opacity(0.2))
            .frame(width: width, height: height)
            .skeleton()
    }
}

struct SkeletonCircle: View {
    let size: CGFloat

    init(size: CGFloat = 40) {
        self.size = size
    }

    var body: some View {
        Circle()
            .fill(Constants.Colors.textTertiary.opacity(0.2))
            .frame(width: size, height: size)
            .skeleton()
    }
}

// MARK: - Feedback Card Skeleton

struct FeedbackCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack {
                SkeletonCircle(size: 10)
                Spacer()
                SkeletonRectangle(width: 40, height: 12)
            }

            // Speaker name
            SkeletonRectangle(width: nil, height: 20)

            // Position
            SkeletonRectangle(width: 100, height: 16)

            // Status
            SkeletonRectangle(width: 60, height: 14)
        }
        .padding()
        .background(Constants.Colors.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Recording Card Skeleton

struct RecordingCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    SkeletonRectangle(width: 100, height: 14)
                    SkeletonRectangle(width: 60, height: 10)
                }

                Spacer()

                SkeletonCircle(size: 20)
            }

            HStack {
                SkeletonCircle(size: 8)
                SkeletonRectangle(width: 40, height: 10)
            }

            HStack {
                SkeletonCircle(size: 8)
                SkeletonRectangle(width: 50, height: 10)
            }
        }
        .padding(16)
        .frame(width: 170)
        .frame(minHeight: 130)
        .softCard(
            backgroundColor: Constants.Colors.cardBackground,
            borderColor: nil,
            cornerRadius: 16
        )
    }
}

// MARK: - Student List Skeleton

struct StudentListSkeleton: View {
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 12) {
                    SkeletonCircle(size: 36)

                    VStack(alignment: .leading, spacing: 4) {
                        SkeletonRectangle(width: 120, height: 16)
                        SkeletonRectangle(width: 80, height: 12)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        SkeletonRectangle(width: 50, height: 28, cornerRadius: 12)
                        SkeletonRectangle(width: 50, height: 28, cornerRadius: 12)
                        SkeletonCircle(size: 24)
                    }
                }
                .padding()
                .background(Constants.Colors.backgroundSecondary)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Constants.Colors.softCyan.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
}

// MARK: - Class Alternative Skeleton

struct ClassAlternativeSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 4) {
                    SkeletonRectangle(width: 80, height: 14)
                    SkeletonRectangle(width: 60, height: 10)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Constants.Colors.backgroundSecondary)
                )
            }
        }
    }
}

// MARK: - History Card Skeleton

struct HistoryCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Motion
            SkeletonRectangle(width: nil, height: 16)
            SkeletonRectangle(width: 200, height: 16)

            // Metadata
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    SkeletonCircle(size: 12)
                    SkeletonRectangle(width: 60, height: 12)
                }
                HStack(spacing: 4) {
                    SkeletonCircle(size: 12)
                    SkeletonRectangle(width: 80, height: 12)
                }
            }

            // Stats
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    SkeletonRectangle(width: 40, height: 20)
                    SkeletonRectangle(width: 50, height: 10)
                }
                VStack(spacing: 4) {
                    SkeletonRectangle(width: 40, height: 20)
                    SkeletonRectangle(width: 50, height: 10)
                }
            }
        }
        .padding()
        .background(Constants.Colors.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 24) {
            Text("Feedback Card Skeleton")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(0..<4, id: \.self) { _ in
                    FeedbackCardSkeleton()
                }
            }

            Divider()

            Text("Recording Card Skeleton")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(0..<3, id: \.self) { _ in
                        RecordingCardSkeleton()
                    }
                }
            }

            Divider()

            Text("Student List Skeleton")
                .font(.headline)
            StudentListSkeleton()

            Divider()

            Text("Class Alternative Skeleton")
                .font(.headline)
            ClassAlternativeSkeleton()

            Divider()

            Text("History Card Skeleton")
                .font(.headline)
            HistoryCardSkeleton()
        }
        .padding()
    }
}
