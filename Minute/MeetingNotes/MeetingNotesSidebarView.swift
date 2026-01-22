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
                .minuteSectionTitle()

            Spacer()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let message = model.sidebarErrorMessage {
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .minuteCaption()
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
                    .minuteCaption()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if model.notes.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("No notes yet.")
                    .minuteRowTitle()
                Text("Record a meeting to create your first note.")
                    .minuteCaption()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            List(model.notes) { item in
                MeetingNoteRow(
                    item: item,
                    dateLabel: dateLabel(for: item),
                    isSelected: model.isOverlayPresented && model.selectedItem?.id == item.id,
                    onSelect: { model.select(item) },
                    onDelete: { model.delete(item) }
                )
            }
            .listStyle(.sidebar)
        }
    }

    private func dateLabel(for item: MeetingNoteItem) -> String {
        guard let date = item.date else {
            return "Unknown date"
        }
        return Self.dateFormatter.string(from: date)
    }
}

private struct MeetingNoteRow: View {
    let item: MeetingNoteItem
    let dateLabel: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dateLabel)
                        .minuteCaption()

                    Text(item.title)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Delete note")
            .accessibilityLabel("Delete note")
        }
        .listRowBackground(rowBackground)
    }

    private var rowBackground: Color? {
        guard isSelected else { return nil }
        return Color(nsColor: NSColor.selectedContentBackgroundColor)
    }
}

#Preview {
    MeetingNotesSidebarView(model: MeetingNotesBrowserViewModel())
}
