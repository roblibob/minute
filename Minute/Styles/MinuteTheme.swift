import AppKit
import SwiftUI

enum MinuteTheme {
    static let windowBackground = Color(nsColor: NSColor.windowBackgroundColor)
    static let sidebarBackground = Color(nsColor: NSColor.controlBackgroundColor)

    static let backgroundGradient = LinearGradient(
        colors: [
            Color.minuteMidnight,
            Color.minuteMidnightDeep,
            Color.minuteMidnight
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let waveformGradient = Gradient(
        colors: [
            Color.minuteWaveStart,
            Color.minuteWaveMid,
            Color.minuteWaveEnd
        ]
    )

    static let waveformLinearGradient = LinearGradient(
        gradient: waveformGradient,
        startPoint: .leading,
        endPoint: .trailing
    )
}

extension Color {
    static let minuteMidnight = dynamicColor(
        name: "minute.midnight",
        light: NSColor(calibratedRed: 0.95, green: 0.96, blue: 0.98, alpha: 1),
        dark: NSColor(calibratedRed: 0.06, green: 0.07, blue: 0.10, alpha: 1)
    )
    static let minuteMidnightDeep = dynamicColor(
        name: "minute.midnightDeep",
        light: NSColor(calibratedRed: 0.90, green: 0.92, blue: 0.95, alpha: 1),
        dark: NSColor(calibratedRed: 0.04, green: 0.05, blue: 0.08, alpha: 1)
    )
    static let minuteSurface = dynamicColor(
        name: "minute.surface",
        light: NSColor.black.withAlphaComponent(0.06),
        dark: NSColor.white.withAlphaComponent(0.06)
    )
    static let minuteSurfaceStrong = dynamicColor(
        name: "minute.surfaceStrong",
        light: NSColor.black.withAlphaComponent(0.12),
        dark: NSColor.white.withAlphaComponent(0.12)
    )
    static let minuteOutline = dynamicColor(
        name: "minute.outline",
        light: NSColor.black.withAlphaComponent(0.14),
        dark: NSColor.white.withAlphaComponent(0.14)
    )
    static let minuteOutlineStrong = dynamicColor(
        name: "minute.outlineStrong",
        light: NSColor.black.withAlphaComponent(0.22),
        dark: NSColor.white.withAlphaComponent(0.22)
    )
    static let minuteTextPrimary = dynamicColor(
        name: "minute.textPrimary",
        light: NSColor.black.withAlphaComponent(0.88),
        dark: NSColor.white.withAlphaComponent(0.92)
    )
    static let minuteTextSecondary = dynamicColor(
        name: "minute.textSecondary",
        light: NSColor.black.withAlphaComponent(0.62),
        dark: NSColor.white.withAlphaComponent(0.65)
    )
    static let minuteTextMuted = dynamicColor(
        name: "minute.textMuted",
        light: NSColor.black.withAlphaComponent(0.44),
        dark: NSColor.white.withAlphaComponent(0.45)
    )
    static let minuteInk = Color.black.opacity(0.82)
    static let minuteWaveStart = Color(red: 0.86, green: 0.42, blue: 0.98)
    static let minuteWaveMid = Color(red: 0.62, green: 0.38, blue: 0.96)
    static let minuteWaveEnd = Color(red: 0.46, green: 0.55, blue: 0.98)
    static let minuteGlow = Color(red: 0.72, green: 0.46, blue: 0.96)
    static let minuteAccent = Color(nsColor: NSColor.controlAccentColor)

    private static func dynamicColor(
        name: String,
        light: NSColor,
        dark: NSColor
    ) -> Color {
        Color(nsColor: NSColor(name: NSColor.Name(name)) { appearance in
            let match = appearance.bestMatch(from: [.aqua, .darkAqua])
            if match == .darkAqua {
                return dark
            }
            return light
        })
    }
}

struct MinuteGlassPanelStyle: ViewModifier {
    var cornerRadius: CGFloat
    var fill: Color
    var border: Color
    var shadowOpacity: Double

    init(
        cornerRadius: CGFloat = 16,
        fill: Color = Color.minuteSurface,
        border: Color = Color.minuteOutline,
        shadowOpacity: Double = 0.25
    ) {
        self.cornerRadius = cornerRadius
        self.fill = fill
        self.border = border
        self.shadowOpacity = shadowOpacity
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(fill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(border, lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(shadowOpacity), radius: 16, x: 0, y: 10)
    }
}

extension View {
    func minuteGlassPanel(
        cornerRadius: CGFloat = 16,
        fill: Color = Color.minuteSurface,
        border: Color = Color.minuteOutline,
        shadowOpacity: Double = 0.25
    ) -> some View {
        modifier(
            MinuteGlassPanelStyle(
                cornerRadius: cornerRadius,
                fill: fill,
                border: border,
                shadowOpacity: shadowOpacity
            )
        )
    }
}
