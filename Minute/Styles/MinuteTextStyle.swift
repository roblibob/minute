import SwiftUI

extension View {
    func minuteSectionTitle() -> some View {
        font(.title3.bold())
    }

    func minuteRowTitle() -> some View {
        font(.headline)
    }

    func minuteRowSubtitle() -> some View {
        font(.subheadline)
            .foregroundStyle(.secondary)
    }

    func minuteCaption() -> some View {
        font(.callout)
            .foregroundStyle(.secondary)
    }

    func minuteFootnote() -> some View {
        font(.footnote)
            .foregroundStyle(.secondary)
    }
}
