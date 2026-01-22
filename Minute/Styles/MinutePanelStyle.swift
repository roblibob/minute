import AppKit
import SwiftUI

struct MinutePanelStyle: ViewModifier {
    var cornerRadius: CGFloat
    var fill: Color
    var border: Color
    var borderWidth: CGFloat

    init(
        cornerRadius: CGFloat = 16,
        fill: Color = Color(nsColor: NSColor.windowBackgroundColor),
        border: Color = Color.black.opacity(0.08),
        borderWidth: CGFloat = 1
    ) {
        self.cornerRadius = cornerRadius
        self.fill = fill
        self.border = border
        self.borderWidth = borderWidth
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(border, lineWidth: borderWidth)
            )
    }
}

extension View {
    func minutePanelStyle(
        cornerRadius: CGFloat = 16,
        fill: Color = Color(nsColor: NSColor.windowBackgroundColor),
        border: Color = Color.black.opacity(0.08),
        borderWidth: CGFloat = 1
    ) -> some View {
        modifier(
            MinutePanelStyle(
                cornerRadius: cornerRadius,
                fill: fill,
                border: border,
                borderWidth: borderWidth
            )
        )
    }
}
