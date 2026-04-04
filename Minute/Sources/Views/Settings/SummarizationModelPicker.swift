import Foundation
import MinuteCore
import SwiftUI

struct SummarizationModelPicker: View {
    let title: String
    let models: [SummarizationModel]
    @Binding var selection: String

    init(
        title: String = "Summarization model",
        models: [SummarizationModel],
        selection: Binding<String>
    ) {
        self.title = title
        self.models = models
        self._selection = selection
    }

    var body: some View {
        SettingsMenuField(
            title: title,
            subtitle: selectedModel?.summary,
            options: models,
            selectionLabel: selectedMenuLabel,
            optionLabel: menuLabel(for:),
            isSelected: { $0.id == selection },
            onSelect: { selection = $0.id }
        )
    }

    private var selectedModel: SummarizationModel? {
        models.first { $0.id == selection } ?? models.first
    }

    private var selectedMenuLabel: String {
        guard let selectedModel else { return "Select model" }
        return menuLabel(for: selectedModel)
    }

    private func sizeLabel(for model: SummarizationModel) -> String? {
        guard let bytes = model.expectedFileSizeBytes else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func menuLabel(for model: SummarizationModel) -> String {
        if let size = sizeLabel(for: model) {
            return "\(model.displayName) (\(size))"
        }
        return model.displayName
    }
}
