import SwiftUI

struct StatusDrawerModel {
    let title: String
    let detail: String
    let progress: Double?
    let showsActivity: Bool
    let isError: Bool
    let actionTitle: String?
    let action: (() -> Void)?
    let secondaryActionTitle: String?
    let secondaryAction: (() -> Void)?
}

struct StatusDrawerView: View {
    let model: StatusDrawerModel
    let isCompact: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: isCompact ? 4 : 6) {
                Text(model.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(model.isError ? Color.red.opacity(0.9) : Color.minuteTextPrimary)

                Text(model.detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.minuteTextSecondary)
                    .lineLimit(isCompact ? 1 : nil)
                    .truncationMode(.tail)

                if let progress = model.progress {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                } else if model.showsActivity {
                    ProgressView()
                        .progressViewStyle(.linear)
                }
            }

            Spacer(minLength: 0)

            if let actionTitle = model.actionTitle, let action = model.action {
                HStack(spacing: 8) {
                    if let secondaryTitle = model.secondaryActionTitle,
                       let secondaryAction = model.secondaryAction {
                        Button(secondaryTitle) {
                            secondaryAction()
                        }
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .foregroundStyle(Color.minuteTextPrimary)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.minuteOutline, lineWidth: 1)
                        )
                    }

                    Button(actionTitle) {
                        action()
                    }
                    .minuteStandardButtonStyle()
                }
            }
        }
        .padding(isCompact ? 10 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .minuteGlassPanel(
            cornerRadius: 16,
            fill: Color.minuteSurfaceStrong,
            border: model.isError ? Color.red.opacity(0.6) : Color.minuteOutline,
            shadowOpacity: 0.2
        )
    }
}
