//
//  VisualizerPreview.swift
//  macdragscroll
//
//  Interactive preview used by Visualizer settings.
//

import AppKit
import SwiftUI

private func localized(_ key: String, value: String, comment: String) -> String {
    AppLocalization.shared.localizedString(key, value: value, comment: comment)
}

struct VisualizerPreviewCard: View {
    @ObservedObject var settings: SettingsManager
    @State private var previewDrag = CGSize(width: 48, height: -18)

    var body: some View {
        LiquidGlassSurface(cornerRadius: 12, tintOpacity: 0.18, strokeOpacity: 0.42, shadowOpacity: 0.08, padding: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(localized("live_preview", value: "Live Preview", comment: "Live preview title"))
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text(localized("drag_preview_hint", value: "Drag in the preview", comment: "Drag preview hint"))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.70)

                    previewBackground

                    visualizer
                }
                .frame(height: 210)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            previewDrag = clamped(value.translation, maxLength: 70)
                        }
                )
            }
        }
    }

    private var previewBackground: some View {
        NormalPreviewScene()
    }

    private var visualizer: some View {
        let side = ScrollOverlayGeometry.sideLength(
            deadZoneRadius: CGFloat(settings.deadZoneRadius),
            visualizerSize: CGFloat(settings.visualizerSize)
        )
        let opacity = CGFloat(settings.overlayOpacity)
        let glassIntensity = CGFloat(settings.liquidGlassIntensity)
        let distance = sqrt(previewDrag.width * previewDrag.width + previewDrag.height * previewDrag.height)
        let unitX = distance > 0 ? previewDrag.width / distance : 0
        let unitY = distance > 0 ? previewDrag.height / distance : 0
        let effectiveDistance = max(distance - CGFloat(settings.deadZoneRadius), 0)
        let travel = min(effectiveDistance * (0.55 + glassIntensity * 0.07), side * 0.25)
        let dotRadius = min(max(side * 0.074, 4.0), 10.0)
        let tintColor = settings.visualizerTintStyle.glassTintColor(intensity: settings.liquidGlassIntensity)
            ?? NSColor.white.withAlphaComponent(min(0.090 + glassIntensity * 0.018, 0.14))
        let tint = Color(nsColor: tintColor)
        let activation = min(effectiveDistance / 42, 1)
        let aeroBlue = Color(red: 0.70, green: 0.92, blue: 1.0)

        return ZStack {
            VisualizerPreviewGlassCircle(
                tint: tint,
                opacity: opacity,
                glassIntensity: glassIntensity,
                activation: activation,
                aeroBlue: aeroBlue
            )

            VisualizerPreviewDot(
                dotRadius: dotRadius,
                opacity: opacity,
                glassIntensity: glassIntensity,
                aeroBlue: aeroBlue
            )
                .frame(width: dotRadius * 2, height: dotRadius * 2)
                .offset(x: unitX * travel, y: unitY * travel)
        }
        .frame(width: side, height: side)
        .rotation3DEffect(.degrees(unitY * (3.3 + glassIntensity * 1.2)), axis: (x: 1, y: 0, z: 0), perspective: 0.55)
        .rotation3DEffect(.degrees(-unitX * (3.3 + glassIntensity * 1.2)), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
    }

    private func clamped(_ size: CGSize, maxLength: CGFloat) -> CGSize {
        let length = sqrt(size.width * size.width + size.height * size.height)
        guard length > maxLength, length > 0 else { return size }
        let scale = maxLength / length
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
}

private struct VisualizerPreviewGlassCircle: View {
    let tint: Color
    let opacity: CGFloat
    let glassIntensity: CGFloat
    let activation: CGFloat
    let aeroBlue: Color

    var body: some View {
        Circle()
            .fill(Color.white.opacity(baseFillOpacity))
            .glassEffect(.regular.tint(tint), in: Circle())
            .overlay { highlightWash }
            .overlay { outerHighlight }
            .overlay { lowerRim }
            .shadow(color: .white.opacity(upperGlowOpacity), radius: 7 + glassIntensity * 1.4, x: -1.5, y: -1.5)
            .shadow(color: .black.opacity(lowerShadowOpacity), radius: 9 + glassIntensity * 1.8, x: 0, y: 2.5)
    }

    private var highlightWash: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        .white.opacity(topWashOpacity),
                        .white.opacity(midWashOpacity),
                        aeroBlue.opacity(blueWashOpacity)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Circle())
    }

    private var outerHighlight: some View {
        Circle()
            .stroke(.white.opacity(outerStrokeOpacity), lineWidth: 1.1)
    }

    private var lowerRim: some View {
        Circle()
            .stroke(.black.opacity(lowerRimOpacity), lineWidth: 0.6)
    }

    private var baseFillOpacity: CGFloat {
        min(0.060 * opacity * (0.90 + glassIntensity * 0.12), 0.16)
    }

    private var topWashOpacity: CGFloat {
        min((0.24 + activation * 0.08) * opacity * (0.86 + glassIntensity * 0.18), 0.52)
    }

    private var midWashOpacity: CGFloat {
        min(0.085 * opacity * (0.88 + glassIntensity * 0.16), 0.24)
    }

    private var blueWashOpacity: CGFloat {
        min((0.018 + activation * 0.018) * opacity * (0.75 + glassIntensity * 0.14), 0.070)
    }

    private var outerStrokeOpacity: CGFloat {
        min((0.30 + activation * 0.06) * opacity * (0.92 + glassIntensity * 0.10), 0.48)
    }

    private var lowerRimOpacity: CGFloat {
        min(0.040 * opacity * (0.80 + glassIntensity * 0.08), 0.075)
    }

    private var upperGlowOpacity: CGFloat {
        min(0.13 * opacity * (0.85 + glassIntensity * 0.10), 0.24)
    }

    private var lowerShadowOpacity: CGFloat {
        min(0.085 * opacity * (0.80 + glassIntensity * 0.12), 0.16)
    }
}

private struct VisualizerPreviewDot: View {
    let dotRadius: CGFloat
    let opacity: CGFloat
    let glassIntensity: CGFloat
    let aeroBlue: Color

    var body: some View {
        Circle()
            .fill(dotFill)
            .overlay { topStroke }
            .overlay { bottomStroke }
            .shadow(color: .white.opacity(upperGlowOpacity), radius: 3.5 + glassIntensity * 0.8, x: -0.8, y: -0.8)
            .shadow(color: .black.opacity(lowerShadowOpacity), radius: 6 + glassIntensity * 1.6, x: 0, y: 1.2)
    }

    private var dotFill: RadialGradient {
        RadialGradient(
            colors: [
                .white.opacity(coreOpacity),
                .white.opacity(midOpacity),
                aeroBlue.opacity(edgeOpacity)
            ],
            center: .topLeading,
            startRadius: 0,
            endRadius: dotRadius * 1.6
        )
    }

    private var topStroke: some View {
        Circle()
            .stroke(.white.opacity(topStrokeOpacity), lineWidth: 0.85)
    }

    private var bottomStroke: some View {
        Circle()
            .stroke(.black.opacity(bottomStrokeOpacity), lineWidth: 0.45)
    }

    private var coreOpacity: CGFloat {
        min(0.82 * opacity * (0.96 + glassIntensity * 0.06), 0.92)
    }

    private var midOpacity: CGFloat {
        min(0.54 * opacity * (0.92 + glassIntensity * 0.08), 0.76)
    }

    private var edgeOpacity: CGFloat {
        min(0.18 * opacity * (0.80 + glassIntensity * 0.12), 0.28)
    }

    private var topStrokeOpacity: CGFloat {
        min(0.45 * opacity * (0.90 + glassIntensity * 0.08), 0.58)
    }

    private var bottomStrokeOpacity: CGFloat {
        min(0.035 * opacity * (0.85 + glassIntensity * 0.10), 0.070)
    }

    private var upperGlowOpacity: CGFloat {
        min(0.20 * opacity * (0.86 + glassIntensity * 0.10), 0.32)
    }

    private var lowerShadowOpacity: CGFloat {
        min(0.090 * opacity * (0.85 + glassIntensity * 0.12), 0.17)
    }
}

private struct NormalPreviewScene: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let isDark = colorScheme == .dark

            ZStack {
                LinearGradient(
                    colors: isDark
                        ? [
                            Color(red: 0.12, green: 0.13, blue: 0.14),
                            Color(red: 0.18, green: 0.19, blue: 0.20)
                        ]
                        : [
                            Color(red: 0.83, green: 0.86, blue: 0.88),
                            Color(red: 0.74, green: 0.78, blue: 0.80)
                        ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.black.opacity(isDark ? 0.16 : 0.08))
                    .frame(width: size.width * 0.80, height: size.height * 0.76)
                    .offset(x: size.width * 0.020, y: size.height * 0.035)
                    .blur(radius: 7)

                appWindow(size: size, isDark: isDark)
                    .frame(width: size.width * 0.82, height: size.height * 0.74)
            }
        }
    }

    private func appWindow(size: CGSize, isDark: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isDark ? Color(red: 0.18, green: 0.19, blue: 0.20) : Color(red: 0.94, green: 0.95, blue: 0.95))

            VStack(spacing: 0) {
                toolbar(isDark: isDark)
                    .frame(height: max(size.height * 0.105, 22))

                HStack(spacing: 0) {
                    sidebar(isDark: isDark)
                        .frame(width: size.width * 0.18)

                    Divider().opacity(isDark ? 0.18 : 0.35)

                    documentArea(isDark: isDark)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(.white.opacity(isDark ? 0.12 : 0.45), lineWidth: 0.7)
        }
    }

    private func toolbar(isDark: Bool) -> some View {
        HStack(spacing: 7) {
            Circle().fill(Color.red.opacity(0.74)).frame(width: 7, height: 7)
            Circle().fill(Color.yellow.opacity(0.74)).frame(width: 7, height: 7)
            Circle().fill(Color.green.opacity(0.74)).frame(width: 7, height: 7)

            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(.white.opacity(isDark ? 0.08 : 0.58))
                .frame(width: 88, height: 12)
                .padding(.leading, 12)

            Spacer()
        }
        .padding(.horizontal, 12)
        .background(isDark ? Color.white.opacity(0.035) : Color.white.opacity(0.46))
    }

    private func sidebar(isDark: Bool) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(.white.opacity(isDark ? 0.08 : 0.48))
                    .frame(width: index == 0 ? 40 : 32, height: 5)
            }

            Spacer()
        }
        .padding(12)
        .background(isDark ? Color.black.opacity(0.10) : Color.white.opacity(0.28))
    }

    private func documentArea(isDark: Bool) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.07))
                .frame(width: 150, height: 11)
                .padding(.top, 14)

            ForEach(0..<7, id: \.self) { index in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isDark ? Color.white.opacity(0.07) : Color.black.opacity(0.055))
                        .frame(width: 34, height: 24)

                    VStack(alignment: .leading, spacing: 5) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(isDark ? Color.white.opacity(0.11) : Color.black.opacity(0.10))
                            .frame(width: CGFloat([142, 118, 156, 132, 148, 112, 136][index]), height: 5)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(isDark ? Color.white.opacity(0.055) : Color.black.opacity(0.045))
                            .frame(width: CGFloat([96, 130, 86, 116, 102, 126, 90][index]), height: 4)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .background(isDark ? Color.white.opacity(0.018) : Color.white.opacity(0.34))
    }
}
