import SwiftUI

struct PermissionStatusRow: View {
    let title: String
    let detail: String
    let isGranted: Bool
    let actionTitle: String?
    let iconSize: Font
    let action: (() -> Void)?

    init(
        title: String,
        detail: String,
        isGranted: Bool,
        actionTitle: String? = nil,
        iconSize: Font = .title3,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.detail = detail
        self.isGranted = isGranted
        self.actionTitle = actionTitle
        self.iconSize = iconSize
        self.action = action
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .minuteRowTitle()
                Text(detail)
                    .minuteRowSubtitle()
            }

            Spacer()

            StatusIcon(isReady: isGranted, size: iconSize)

            if let actionTitle, let action {
                Button(actionTitle) {
                    action()
                }
                .minuteStandardButtonStyle()
                .disabled(isGranted)
            }
        }
    }
}
