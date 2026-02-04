//
//  MeetingTypePicker.swift
//  Minute
//
//  Created for Feature 003-meeting-type-prompts
//

import SwiftUI
import MinuteCore

struct MeetingTypePicker: View {
    @Binding var selection: MeetingType
    
    var body: some View {
        Menu {
            Picker("Meeting Type", selection: $selection) {
                ForEach(MeetingType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
        } label: {
            HStack {
                Label(selection.displayName, systemImage: iconName(for: selection))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .minuteDropdownStyle()
        }
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: false, vertical: true)
    }
    
    private func iconName(for type: MeetingType) -> String {
        switch type {
        case .autodetect: return "sparkles"
        case .general: return "bubble.left.and.bubble.right"
        case .standup: return "figure.stand"
        case .presentation: return "chart.bar.doc.horizontal"
        case .designReview: return "paintbrush"
        case .oneOnOne: return "person.2"
        case .planning: return "calendar"
        }
    }
}
