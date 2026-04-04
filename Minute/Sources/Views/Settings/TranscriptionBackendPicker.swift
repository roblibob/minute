import MinuteCore
import SwiftUI

struct TranscriptionBackendPicker: View {
    let backends: [TranscriptionBackend]
    @Binding var selection: String

    var body: some View {
        SettingsMenuField(
            title: "Transcription engine",
            subtitle: selectedBackend?.summary,
            options: backends,
            selectionLabel: selectedLabel,
            optionLabel: { $0.displayName },
            isSelected: { $0.id == selection },
            onSelect: { selection = $0.id }
        )
    }

    private var selectedBackend: TranscriptionBackend? {
        backends.first { $0.id == selection } ?? backends.first
    }

    private var selectedLabel: String {
        selectedBackend?.displayName ?? "Select engine"
    }
}
