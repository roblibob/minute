import MinuteCore
import SwiftUI

struct InferenceCapabilityStatusView: View {
    let title: String
    let state: CapabilityAvailabilityState
    let discoveredModelReferences: [String]
    let discoveredModelsTitle: String
    let isRefreshing: Bool
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Text(title)
                    .minuteRowTitle()

                Spacer()

                Button(isRefreshing ? "Refreshing..." : "Refresh") {
                    onRefresh()
                }
                .buttonStyle(.borderless)
                .disabled(isRefreshing)
            }

            Label(statusTitle, systemImage: statusSymbol)
                .foregroundStyle(statusColor)

            if let message = state.message, !message.isEmpty {
                Text(message)
                    .minuteCaption()
            }

            if !discoveredModelReferences.isEmpty {
                Text("\(discoveredModelsTitle): \(discoveredModelReferences.joined(separator: ", "))")
                    .minuteCaption()
            }
        }
    }

    private var statusTitle: String {
        switch state.status {
        case .ready:
            return "Ready"
        case .needsConfiguration:
            return "Needs configuration"
        case .daemonUnavailable:
            return "Daemon unavailable"
        case .serverUnavailable:
            return "Server unavailable"
        case .modelMissing:
            return "Model unavailable"
        case .unsupported:
            return "Unsupported"
        case .visionUnsupported:
            return "Vision unsupported"
        case .unknown:
            return "Status unavailable"
        }
    }

    private var statusSymbol: String {
        switch state.status {
        case .ready:
            return "checkmark.circle.fill"
        case .needsConfiguration, .modelMissing, .visionUnsupported:
            return "exclamationmark.circle"
        case .daemonUnavailable, .serverUnavailable, .unsupported, .unknown:
            return "xmark.circle"
        }
    }

    private var statusColor: Color {
        switch state.status {
        case .ready:
            return .green
        case .needsConfiguration, .modelMissing, .visionUnsupported:
            return .orange
        case .daemonUnavailable, .serverUnavailable, .unsupported, .unknown:
            return .red
        }
    }
}
