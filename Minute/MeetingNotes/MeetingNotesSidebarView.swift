import MinuteCore
import SwiftUI

struct MeetingNotesSidebarView: View {
    @ObservedObject var model: MeetingNotesBrowserViewModel

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            content
        }
        .padding(16)
        .frame(minWidth: 260, idealWidth: 300, maxWidth: 360, maxHeight: .infinity)
        .background(Color.minuteMidnightDeep)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Library")
                .font(.system(size: 16, weight: .semibold))
                .tracking(-0.2)
                .foregroundStyle(Color.minuteTextPrimary)

            Text("Timeline")
                .minuteFootnote()
                .textCase(.uppercase)
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
                Text("No meetings yet.")
                    .minuteRowTitle()
                Text("Start a recording to build your second brain.")
                    .minuteCaption()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(timelineSections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title)
                                .minuteFootnote()
                                .textCase(.uppercase)

                            ForEach(section.items) { item in
                                let preview = model.preview(for: item)
                                MeetingNoteCard(
                                    item: item,
                                    summaryLine: preview?.summaryLine ?? "No summary yet.",
                                    timeLabel: timeLabel(for: item),
                                    durationLabel: durationLabel(for: preview),
                                    isSelected: model.selectedItem?.id == item.id,
                                    onSelect: { model.select(item) },
                                    onDelete: { model.delete(item) }
                                )
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var timelineSections: [MeetingTimelineSection] {
        let now = Date()
        var buckets: [String: [MeetingNoteItem]] = [:]

        for item in model.notes {
            let title = sectionTitle(for: item.date, now: now)
            buckets[title, default: []].append(item)
        }

        let orderedTitles = sectionOrder()
        var sections: [MeetingTimelineSection] = []
        for title in orderedTitles {
            guard let items = buckets[title], !items.isEmpty else { continue }
            sections.append(MeetingTimelineSection(title: title, items: items))
        }
        if let undated = buckets["Undated"], !undated.isEmpty {
            sections.append(MeetingTimelineSection(title: "Undated", items: undated))
        }
        return sections
    }

    private func sectionTitle(for date: Date?, now: Date) -> String {
        guard let date else { return "Undated" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }

        if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            return "This Week"
        }
        if let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now),
           calendar.isDate(date, equalTo: lastWeek, toGranularity: .weekOfYear) {
            return "Last Week"
        }
        if calendar.isDate(date, equalTo: now, toGranularity: .month) {
            return "This Month"
        }
        if let lastMonth = calendar.date(byAdding: .month, value: -1, to: now),
           calendar.isDate(date, equalTo: lastMonth, toGranularity: .month) {
            return "Last Month"
        }
        if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            return "Earlier This Year"
        }
        return "Previous Years"
    }

    private func sectionOrder() -> [String] {
        [
            "Today",
            "Yesterday",
            "This Week",
            "Last Week",
            "This Month",
            "Last Month",
            "Earlier This Year",
            "Previous Years"
        ]
    }

    private func timeLabel(for item: MeetingNoteItem) -> String {
        guard let date = item.date else {
            return "Unknown time"
        }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) || calendar.isDateInYesterday(date) {
            return Self.timeFormatter.string(from: date)
        }
        return Self.fullDateFormatter.string(from: date)
    }

    private func durationLabel(for preview: MeetingNotesBrowserViewModel.NotePreview?) -> String? {
        guard let seconds = preview?.durationSeconds,
              let formatted = Self.durationFormatter.string(from: seconds) else {
            return nil
        }
        return formatted
    }
}

private struct MeetingTimelineSection: Identifiable {
    let title: String
    let items: [MeetingNoteItem]
    var id: String { title }
}

private struct MeetingNoteCard: View {
    let item: MeetingNoteItem
    let summaryLine: String
    let timeLabel: String
    let durationLabel: String?
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(Color.minuteTextPrimary)
                    .lineLimit(2)

                Text(summaryLine)
                    .font(.system(size: 12, weight: .medium))
                    .tracking(-0.1)
                    .foregroundStyle(Color.minuteTextSecondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(timeLabel)
                    if let durationLabel {
                        Text("(\(durationLabel))")
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .tracking(-0.1)
                .foregroundStyle(Color.minuteTextMuted)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .minuteGlassPanel(
            cornerRadius: 12,
            fill: isSelected ? Color.minuteGlow.opacity(0.18) : Color.minuteSurface,
            border: isSelected ? Color.minuteGlow.opacity(0.7) : Color.minuteOutline,
            shadowOpacity: 0.2
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.minuteGlow.opacity(isSelected ? 0.45 : 0), lineWidth: 1.2)
        )
        .contextMenu {
            Button("Rename…") {}
                .disabled(true)
            Divider()
            Button(role: .destructive) {
                onDelete()
            } label: {
                Text("Delete")
            }
        }
    }
}

#Preview {
    MeetingNotesSidebarView(model: MeetingNotesBrowserViewModel())
}
