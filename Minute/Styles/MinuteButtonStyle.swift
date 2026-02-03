import AppKit
import SwiftUI

struct MinuteStandardButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let baseColor = Color(nsColor: NSColor.controlAccentColor)
        let fillColor: Color
        if isEnabled {
            fillColor = baseColor.opacity(configuration.isPressed ? 0.82 : 1.0)
        } else {
            fillColor = baseColor.opacity(0.35)
        }

        return configuration.label
            .font(.callout.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .foregroundStyle(Color.white.opacity(isEnabled ? 1.0 : 0.7))
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(fillColor)
            )
            .shadow(color: .clear, radius: 0, x: 0, y: 0)
    }
}

extension View {
    func minuteStandardButtonStyle() -> some View {
        self.buttonStyle(MinuteStandardButtonStyle())
    }
}
