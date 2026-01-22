import MinuteCore
import SwiftUI

struct ModelDownloadStatusView: View {
    enum Style {
        case card
        case plain
    }

    let title: String
    let detail: String
    let status: StatusIcon.State
    let progress: ModelDownloadProgress?
    let showsSpinner: Bool
    let message: String?
    let buttonTitle: String
    let buttonEnabled: Bool
    let style: Style
    let action: () -> Void

    var body: some View {
        let content = VStack(alignment: .leading, spacing: 12) {
            header

            if let progress {
                ProgressView(value: progress.fractionCompleted) {
                    Text(progress.label)
                }
            } else if showsSpinner {
                ProgressView("Checking models...")
            }

            if let message {
                Text(message)
                    .minuteCaption()
            }

            HStack {
                Button(buttonTitle) {
                    action()
                }
                .minuteStandardButtonStyle()
                .disabled(!buttonEnabled)

                Spacer()
            }
        }

        switch style {
        case .card:
            content.minuteCardStyle(padding: 16)
        case .plain:
            content.padding(.vertical, 6)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .minuteRowTitle()
                Text(detail)
                    .minuteRowSubtitle()
            }

            Spacer()

            StatusIcon(state: status)
        }
    }
}
