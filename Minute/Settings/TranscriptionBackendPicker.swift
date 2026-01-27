import MinuteCore
import SwiftUI

struct TranscriptionBackendPicker: View {
    let backends: [TranscriptionBackend]
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transcription engine")
                .minuteRowTitle()

            Menu {
                ForEach(backends) { backend in
                    Button {
                        selection = backend.id
                    } label: {
                        if backend.id == selection {
                            Label(backend.displayName, systemImage: "checkmark")
                        } else {
                            Text(backend.displayName)
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(selectedLabel)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .minuteDropdownStyle()
            }
            .menuStyle(.borderlessButton)

            if let selectedBackend {
                Text(selectedBackend.summary)
                    .minuteCaption()
            }
        }
    }

    private var selectedBackend: TranscriptionBackend? {
        backends.first { $0.id == selection } ?? backends.first
    }

    private var selectedLabel: String {
        selectedBackend?.displayName ?? "Select engine"
    }
}
