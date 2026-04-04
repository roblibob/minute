import AppKit
import SwiftUI

enum MinuteControlMetrics {
    static let cornerRadius: CGFloat = 10
    static let horizontalPadding: CGFloat = 12
    static let verticalPadding: CGFloat = 10
}

private struct MinuteInputFieldChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: MinuteControlMetrics.cornerRadius, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: MinuteControlMetrics.cornerRadius, style: .continuous)
                    .stroke(Color.minuteOutline, lineWidth: 1)
            )
    }
}

extension View {
    func minuteInputFieldChrome() -> some View {
        modifier(MinuteInputFieldChrome())
    }

    func minuteTextFieldStyle() -> some View {
        self.textFieldStyle(.plain)
            .minuteControlValue()
            .padding(.horizontal, MinuteControlMetrics.horizontalPadding)
            .padding(.vertical, MinuteControlMetrics.verticalPadding)
            .minuteInputFieldChrome()
    }
}
