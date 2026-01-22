import SwiftUI

struct MinuteCardStyle: ViewModifier {
    var padding: CGFloat
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.tertiary, lineWidth: 1)
            )
    }
}

extension View {
    func minuteCardStyle(padding: CGFloat = 16, cornerRadius: CGFloat = 12) -> some View {
        modifier(MinuteCardStyle(padding: padding, cornerRadius: cornerRadius))
    }
}
