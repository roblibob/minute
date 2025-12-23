import Foundation
import MinuteCore
import SwiftUI

struct SummarizationModelPicker: View {
    let models: [SummarizationModel]
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Summarization model")
                .font(.headline)

            Menu {
                ForEach(models) { model in
                    Button {
                        selection = model.id
                    } label: {
                        if model.id == selection {
                            Label(menuLabel(for: model), systemImage: "checkmark")
                        } else {
                            Text(menuLabel(for: model))
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(selectedMenuLabel)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .minuteDropdownStyle()
            }
            .menuStyle(.borderlessButton)

            if let selectedModel {
                Text(selectedModel.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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
