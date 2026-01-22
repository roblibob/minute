import SwiftUI

enum MinuteTheme {
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
    static let minuteMidnight = Color(red: 0.06, green: 0.07, blue: 0.10)
    static let minuteMidnightDeep = Color(red: 0.04, green: 0.05, blue: 0.08)
    static let minuteSurface = Color.white.opacity(0.06)
    static let minuteSurfaceStrong = Color.white.opacity(0.12)
    static let minuteOutline = Color.white.opacity(0.14)
    static let minuteOutlineStrong = Color.white.opacity(0.22)
    static let minuteTextPrimary = Color.white.opacity(0.92)
    static let minuteTextSecondary = Color.white.opacity(0.65)
    static let minuteTextMuted = Color.white.opacity(0.45)
    static let minuteWaveStart = Color(red: 0.86, green: 0.42, blue: 0.98)
    static let minuteWaveMid = Color(red: 0.62, green: 0.38, blue: 0.96)
    static let minuteWaveEnd = Color(red: 0.46, green: 0.55, blue: 0.98)
    static let minuteGlow = Color(red: 0.72, green: 0.46, blue: 0.96)
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
