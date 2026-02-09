import MinuteCore
import SwiftUI

struct MeetingNotesSidebarView: View {
    @ObservedObject var model: MeetingNotesBrowserViewModel
    @State private var expandedSections: Set<String> = []

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

    private var topInset: CGFloat {
        if #available(macOS 26.0, *) {
            12
        } else {
            40
        }
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MinuteTheme.sidebarBackground)
            .safeAreaPadding(.top, topInset)
    }

    @ViewBuilder
    private var content: some View {
        if let message = model.sidebarErrorMessage {
            List {
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
                .listRowBackground(Color.clear)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        } else if model.isRefreshing && model.notes.isEmpty {
            List {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView()
                    Text("Loading notes…")
                        .minuteCaption()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowBackground(Color.clear)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        } else if model.notes.isEmpty {
            List {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No meetings yet.")
                        .minuteRowTitle()
                    Text("Start a recording to build your second brain.")
                        .minuteCaption()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowBackground(Color.clear)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        } else {
            List {
                ForEach(timelineSections) { section in
                    let sectionBinding = binding(for: section)
                    DisclosureGroup(isExpanded: sectionBinding) {
                        ForEach(section.items) { item in
                            let preview = model.preview(for: item)
                            MeetingNoteRow(
                                item: item,
                                summaryLine: preview?.summaryLine ?? "No summary yet.",
                                timeLabel: timeLabel(for: item),
                                durationLabel: durationLabel(for: preview),
                                isSelected: model.selectedItem?.id == item.id,
                                onSelect: { model.select(item) },
                                onOpenSummaryInApp: { model.openSummaryInApp(for: item) },
                                onOpenTranscriptInApp: { model.openTranscriptInApp(for: item) },
                                onOpenSummaryInObsidian: { model.openSummaryInObsidian(for: item) },
                                onOpenTranscriptInObsidian: { model.openTranscriptInObsidian(for: item) },
                                onRevealInFinder: { model.revealInFinder(for: item) },
                                onDelete: { model.delete(item) }
                            )
                            .listRowInsets(EdgeInsets(top: 6, leading: 2, bottom: 6, trailing: 8))
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(section.title)
                                .minuteFootnote()
                                .textCase(.uppercase)

                            Text("\(section.items.count)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.minuteTextMuted)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            sectionBinding.wrappedValue.toggle()
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .animation(.easeInOut(duration: 0.18), value: expandedSections)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .onAppear {
                updateExpandedSections(with: timelineSections)
            }
            .onChange(of: timelineSections.map(\.id)) { _, _ in
                updateExpandedSections(with: timelineSections)
            }
        }
    }

    private func binding(for section: MeetingTimelineSection) -> Binding<Bool> {
        Binding(
            get: { expandedSections.contains(section.id) },
            set: { isExpanded in
                if isExpanded {
                    expandedSections.insert(section.id)
                } else {
                    expandedSections.remove(section.id)
                }
            }
        )
    }

    private func updateExpandedSections(with sections: [MeetingTimelineSection]) {
        let validIDs = Set(sections.map(\.id))
        expandedSections = expandedSections.intersection(validIDs)
        if expandedSections.isEmpty, let first = sections.first {
            expandedSections = [first.id]
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

private struct MeetingNoteRow: View {
    let item: MeetingNoteItem
    let summaryLine: String
    let timeLabel: String
    let durationLabel: String?
    let isSelected: Bool
    let onSelect: () -> Void
    let onOpenSummaryInApp: () -> Void
    let onOpenTranscriptInApp: () -> Void
    let onOpenSummaryInObsidian: () -> Void
    let onOpenTranscriptInObsidian: () -> Void
    let onRevealInFinder: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(summaryLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(timeLabel)
                    if let durationLabel {
                        Text("(\(durationLabel))")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
        .contextMenu {
            Button {
                onOpenSummaryInApp()
            } label: {
                Label("View Summary", systemImage: "doc.text")
            }

            Button {
                onOpenTranscriptInApp()
            } label: {
                Label("View Transcript", systemImage: "text.bubble")
            }
            .disabled(!item.hasTranscript)

            Divider()

            Button {
                onOpenSummaryInObsidian()
            } label: {
                Label("Open Summary in Obsidian", systemImage: "arrow.up.right.square")
            }

            Button {
                onOpenTranscriptInObsidian()
            } label: {
                Label("Open Transcript in Obsidian", systemImage: "arrow.up.right.square")
            }
            .disabled(!item.hasTranscript)

            Button {
                onRevealInFinder()
            } label: {
                Label("Reveal in Finder", systemImage: "finder")
            }

            Divider()
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#Preview {
    MeetingNotesSidebarView(model: MeetingNotesBrowserViewModel())
}
