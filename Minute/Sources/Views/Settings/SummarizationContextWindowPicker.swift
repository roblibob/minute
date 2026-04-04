import MinuteCore
import SwiftUI

struct SummarizationContextWindowPicker: View {
    let presets: [SummarizationContextWindowPreset]
    let recommendedPreset: SummarizationContextWindowPreset
    @Binding var selection: SummarizationContextWindowPreset

    var body: some View {
        SettingsFieldBlock(
            title: "Summarization context window",
            subtitle: selection.detailText
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(selection.displayName)
                        .minuteControlValue()
                    Spacer()
                    Text(tokenCountLabel)
                        .minuteCaption()
                }

                SettingsSteppedControl(
                    stepLabels: presets.map(\.shortDisplayName),
                    selectedIndex: selectedIndexBinding
                )

                SettingsInlineMessage(text: recommendationText)
            }
        }
        .gridCellColumns(2)
    }

    private var selectedIndexBinding: Binding<Int> {
        Binding(
            get: { selectedIndex },
            set: { index in
                guard presets.indices.contains(index) else { return }
                selection = presets[index]
            }
        )
    }

    private var recommendationText: String {
        "Default on this Mac: \(recommendedPreset.displayName)."
    }

    private var selectedIndex: Int {
        presets.firstIndex(of: selection) ?? 0
    }

    private var tokenCountLabel: String {
        "\(selection.requestedContextTokens ?? recommendedPreset.requestedContextTokens ?? 8_192) tokens"
    }
}
