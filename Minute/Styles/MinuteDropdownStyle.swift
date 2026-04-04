import AppKit
import SwiftUI

struct MinuteDropdownLabelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .minuteControlValue()
            .padding(.horizontal, MinuteControlMetrics.horizontalPadding)
            .padding(.vertical, MinuteControlMetrics.verticalPadding)
            .minuteInputFieldChrome()
    }
}

extension View {
    func minuteDropdownStyle() -> some View {
        modifier(MinuteDropdownLabelStyle())
    }
}
