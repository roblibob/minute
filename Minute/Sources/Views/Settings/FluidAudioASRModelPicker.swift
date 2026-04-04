import MinuteCore
import SwiftUI

struct FluidAudioASRModelPicker: View {
    let models: [FluidAudioASRModel]
    @Binding var selection: String

    var body: some View {
        SettingsMenuField(
            title: "FluidAudio model",
            subtitle: selectedModel?.summary,
            options: models,
            selectionLabel: selectedLabel,
            optionLabel: { $0.displayName },
            isSelected: { $0.id == selection },
            onSelect: { selection = $0.id }
        )
    }

    private var selectedModel: FluidAudioASRModel? {
        models.first { $0.id == selection } ?? models.first
    }

    private var selectedLabel: String {
        selectedModel?.displayName ?? "Select model"
    }
}
