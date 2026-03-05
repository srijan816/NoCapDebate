//
//  SubtleGlitterView.swift
//  DebateFeedback
//
//

import SwiftUI

struct SubtleGlitterView: View {
    @State private var sparkles: [Sparkle] = []

    struct Sparkle: Identifiable {
        let id = UUID()
        let x: CGFloat
        let y: CGFloat
        let color: Color
        let size: CGFloat
        let delay: Double
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(sparkles) { sparkle in
                    SparkleShape()
                        .fill(sparkle.color)
                        .frame(width: sparkle.size, height: sparkle.size)
                        .position(x: sparkle.x, y: sparkle.y)
                        .opacity(0.25)
                }
            }
            .onAppear {
                generateSparkles(in: geometry.size)
            }
        }
        .allowsHitTesting(false) // Prevent interaction with background
    }

    private func generateSparkles(in size: CGSize) {
        // Only 8-10 sparkles total (very subtle)
        let count = Int.random(in: 8...10)
        let colors = [Constants.Colors.primaryBlue, Constants.Colors.softPink]

        sparkles = (0..<count).map { index in
            Sparkle(
                x: CGFloat.random(in: 20...(size.width - 20)),
                y: CGFloat.random(in: 20...(size.height - 20)),
                color: colors.randomElement()!,
                size: CGFloat.random(in: 4...8),
                delay: Double.random(in: 0...2)
            )
        }
    }
}

// Custom sparkle/star shape
struct SparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        // Create a 4-pointed star
        for i in 0..<4 {
            let angle = Double(i) * .pi / 2
            let point = CGPoint(
                x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle))
            )

            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: center)
                path.addLine(to: point)
            }
        }
        path.closeSubpath()

        return path
    }
}

#Preview {
    ZStack {
        Color.white
        SubtleGlitterView()
    }
}
