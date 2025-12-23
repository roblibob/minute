import AppKit
import SwiftUI

extension View {
    func minuteTextFieldStyle() -> some View {
        self.textFieldStyle(.plain)
            .font(.callout)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
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
