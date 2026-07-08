//
//  LiquidGlassViews.swift
//  macdragscroll
//
//  Created by OpenAI Codex on 2026-07-08.
//

import AppKit
import SwiftUI

struct LiquidGlassBackdrop: View {
    var dimmingOpacity = 0.62

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            GeometryReader { geometry in
                LinearGradient(
                    colors: [
                        Color(nsColor: .controlBackgroundColor).opacity(0.74),
                        Color(nsColor: .windowBackgroundColor).opacity(0.94),
                        Color(nsColor: .underPageBackgroundColor).opacity(0.72)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                LiquidGlassTrailPattern()
                    .stroke(.white.opacity(0.14), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .blur(radius: 0.8)

                LiquidGlassTrailPattern(phase: 18, lineCount: 4)
                    .stroke(.black.opacity(0.045), style: StrokeStyle(lineWidth: 2, lineCap: .round))

                RadialGradient(
                    colors: [
                        .white.opacity(0.18),
                        .white.opacity(0.04),
                        .clear
                    ],
                    center: .topLeading,
                    startRadius: 8,
                    endRadius: max(geometry.size.width, geometry.size.height) * 0.72
                )
            }

            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(dimmingOpacity)

            Color(nsColor: .windowBackgroundColor)
                .opacity(0.16)
        }
    }
}

struct LiquidGlassSurface<Content: View>: View {
    let cornerRadius: CGFloat
    let tintOpacity: Double
    let strokeOpacity: Double
    let shadowOpacity: Double
    let padding: EdgeInsets
    @ViewBuilder let content: Content

    init(
        cornerRadius: CGFloat = 10,
        tintOpacity: Double = 0.20,
        strokeOpacity: Double = 0.44,
        shadowOpacity: Double = 0.08,
        padding: EdgeInsets = EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10),
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.tintOpacity = tintOpacity
        self.strokeOpacity = strokeOpacity
        self.shadowOpacity = shadowOpacity
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .glassEffect(
                .regular.tint(Color(nsColor: .controlBackgroundColor).opacity(tintOpacity)),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(strokeOpacity), lineWidth: 0.45)
                    .blendMode(.screen)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.28), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(shadowOpacity), radius: 16, x: 0, y: 8)
    }
}

private struct LiquidGlassTrailPattern: Shape {
    var phase: CGFloat = 0
    var lineCount = 6

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard rect.width > 0, rect.height > 0 else { return path }

        for index in 0..<lineCount {
            let fraction = (CGFloat(index) + 1) / CGFloat(lineCount + 1)
            let y = rect.height * fraction + phase

            path.move(to: CGPoint(x: rect.minX - rect.width * 0.08, y: y))
            path.addCurve(
                to: CGPoint(x: rect.maxX + rect.width * 0.08, y: y + rect.height * 0.018),
                control1: CGPoint(x: rect.width * 0.28, y: y - rect.height * 0.055),
                control2: CGPoint(x: rect.width * 0.68, y: y + rect.height * 0.070)
            )
        }

        return path
    }
}
