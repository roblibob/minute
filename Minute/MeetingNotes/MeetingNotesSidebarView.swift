import AppKit
import MinuteCore
import SwiftUI

struct MeetingNotesSidebarView: View {
    @ObservedObject var model: MeetingNotesBrowserViewModel

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            content
        }
        .padding(12)
        .frame(minWidth: 240, idealWidth: 260, maxWidth: 320, maxHeight: .infinity)
        .background(Color(nsColor: NSColor.controlBackgroundColor))
    }

    private var header: some View {
        HStack {
            Text("Notes")
                .font(.headline)

            Spacer()

            Button(action: model.refresh) {
                if model.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.accentColor)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Refresh notes list")
        }
    }

    @ViewBuilder
    private var content: some View {
        if let message = model.sidebarErrorMessage {
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)

                Button("Retry") {
                    model.refresh()
                }
                .minuteStandardButtonStyle()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if model.isRefreshing && model.notes.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ProgressView()
                Text("Loading notes…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if model.notes.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("No notes yet.")
                    .font(.subheadline.weight(.semibold))
                Text("Record a meeting to create your first note.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            List(model.notes) { item in
                Button {
                    model.select(item)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dateLabel(for: item))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(item.title)
                            .font(.callout)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .listRowBackground(rowBackground(for: item))
            }
            .listStyle(.sidebar)
        }
    }

    private func rowBackground(for item: MeetingNoteItem) -> Color? {
        guard model.isOverlayPresented, model.selectedItem?.id == item.id else {
            return nil
        }
        return Color(nsColor: NSColor.selectedContentBackgroundColor).opacity(0.2)
    }

    private func dateLabel(for item: MeetingNoteItem) -> String {
        guard let date = item.date else {
            return "Unknown date"
        }
        return Self.dateFormatter.string(from: date)
    }
}

#Preview {
    MeetingNotesSidebarView(model: MeetingNotesBrowserViewModel())
}
