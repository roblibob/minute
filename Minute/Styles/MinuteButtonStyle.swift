import SwiftUI

extension View {
    func minuteStandardButtonStyle() -> some View {
        self.buttonStyle(.bordered)
            .tint(.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
