import SwiftUI

extension View {
    func minuteSectionTitle() -> some View {
        font(.system(size: 18, weight: .semibold))
            .tracking(-0.3)
            .foregroundStyle(Color.minuteTextPrimary)
    }

    func minuteRowTitle() -> some View {
        font(.system(size: 15, weight: .semibold))
            .tracking(-0.2)
            .foregroundStyle(Color.minuteTextPrimary)
    }

    func minuteRowSubtitle() -> some View {
        font(.system(size: 13, weight: .medium))
            .tracking(-0.1)
            .foregroundStyle(Color.minuteTextSecondary)
    }

    func minuteCaption() -> some View {
        font(.system(size: 12, weight: .medium))
            .tracking(-0.1)
            .foregroundStyle(Color.minuteTextSecondary)
    }

    func minuteFootnote() -> some View {
        font(.system(size: 11, weight: .medium))
            .tracking(-0.1)
            .foregroundStyle(Color.minuteTextMuted)
    }
}
