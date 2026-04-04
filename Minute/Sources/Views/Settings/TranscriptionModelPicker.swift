import Foundation
import MinuteCore
import SwiftUI

struct TranscriptionModelPicker: View {
    let models: [TranscriptionModel]
    @Binding var selection: String

    var body: some View {
        SettingsMenuField(
            title: "Transcription model",
            subtitle: selectedModel?.summary,
            options: models,
            selectionLabel: selectedMenuLabel,
            optionLabel: menuLabel(for:),
            isSelected: { $0.id == selection },
            onSelect: { selection = $0.id }
        )
    }

    private var selectedModel: TranscriptionModel? {
        models.first { $0.id == selection } ?? models.first
    }

    private var selectedMenuLabel: String {
        guard let selectedModel else { return "Select model" }
        return menuLabel(for: selectedModel)
    }

    private func sizeLabel(for model: TranscriptionModel) -> String? {
        guard let bytes = model.expectedFileSizeBytes else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func menuLabel(for model: TranscriptionModel) -> String {
        if let size = sizeLabel(for: model) {
            return "\(model.displayName) (\(size))"
        }
        return model.displayName
    }
}
