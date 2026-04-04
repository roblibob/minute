import SwiftUI

extension View {
    func minuteSettingsHeaderTitle() -> some View {
        font(.system(size: 22, weight: .semibold))
            .tracking(-0.4)
            .foregroundStyle(Color.minuteTextPrimary)
    }

    func minuteSettingsHeaderSubtitle() -> some View {
        font(.system(size: 13, weight: .medium))
            .tracking(-0.1)
            .foregroundStyle(Color.minuteTextSecondary)
    }

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

    func minuteControlValue() -> some View {
        font(.system(size: 14, weight: .medium))
            .tracking(-0.1)
            .foregroundStyle(Color.minuteTextPrimary)
    }
}
