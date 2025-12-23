import AppKit
import SwiftUI

struct MinuteDropdownLabelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.callout)
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color(nsColor: NSColor.separatorColor), lineWidth: 1)
            )
    }
}

extension View {
    func minuteDropdownStyle() -> some View {
        modifier(MinuteDropdownLabelStyle())
    }
}
