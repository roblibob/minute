import MinuteCore
import SwiftUI

enum MeetingTypeSelectionStyle {
    static func symbolName(for definition: MeetingTypeDefinition) -> String {
        guard definition.source == .builtIn else {
            return "sparkles"
        }

        guard let builtInType = MeetingType(rawValue: definition.typeId) else {
            return "shippingbox.fill"
        }

        switch builtInType {
        case .autodetect:
            return "wand.and.stars"
        case .general:
            return "person.3.fill"
        case .standup:
            return "figure.walk.motion"
        case .designReview:
            return "paintpalette.fill"
        case .oneOnOne:
            return "person.2.fill"
        case .presentation:
            return "rectangle.on.rectangle.angled"
        case .planning:
            return "calendar.badge.clock"
        case .interviewTaken:
            return "person.crop.circle.badge.questionmark"
        case .interviewGiven:
            return "person.crop.circle.badge.checkmark"
        case .allHands:
            return "megaphone.fill"
        case .retrospective:
            return "arrow.uturn.backward.circle.fill"
        }
    }

    static func symbolTint(for definition: MeetingTypeDefinition) -> Color {
        definition.source == .custom ? .blue : .minuteGlow
    }
}

struct MeetingTypeSelectionChip: View {
    let title: String
    let symbolName: String
    let symbolTint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbolName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(symbolTint)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.minuteGlow.opacity(0.20) : Color.minuteSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.minuteGlow.opacity(0.75) : Color.minuteOutline, lineWidth: isSelected ? 1.5 : 1)
            )
            .foregroundStyle(isSelected ? Color.minuteTextPrimary : Color.minuteTextSecondary)
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct MeetingTypeSelectionWrapLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        let maxRowWidth = proposal.width ?? .infinity
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var widestRow: CGFloat = 0

        for subview in subviews {
            let idealSize = subview.sizeThatFits(.unspecified)
            let itemWidth = min(idealSize.width, maxRowWidth)

            if currentRowWidth > 0 && currentRowWidth + itemWidth > maxRowWidth {
                widestRow = max(widestRow, currentRowWidth - horizontalSpacing)
                totalHeight += currentRowHeight + verticalSpacing
                currentRowWidth = 0
                currentRowHeight = 0
            }

            currentRowWidth += itemWidth + horizontalSpacing
            currentRowHeight = max(currentRowHeight, idealSize.height)
        }

        if !subviews.isEmpty {
            widestRow = max(widestRow, max(0, currentRowWidth - horizontalSpacing))
            totalHeight += currentRowHeight
        }

        return CGSize(
            width: proposal.width ?? widestRow,
            height: totalHeight
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        var cursorX = bounds.minX
        var cursorY = bounds.minY
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let idealSize = subview.sizeThatFits(.unspecified)
            let availableWidth = bounds.width
            let itemWidth = min(idealSize.width, availableWidth)

            if cursorX > bounds.minX && cursorX + itemWidth > bounds.maxX {
                cursorX = bounds.minX
                cursorY += currentRowHeight + verticalSpacing
                currentRowHeight = 0
            }

            subview.place(
                at: CGPoint(x: cursorX, y: cursorY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: itemWidth, height: idealSize.height)
            )

            cursorX += itemWidth + horizontalSpacing
            currentRowHeight = max(currentRowHeight, idealSize.height)
        }
    }
}
