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

            Picker("Summarization model", selection: $selection) {
                ForEach(models) { model in
                    Text(menuLabel(for: model))
                        .tag(model.id)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()

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
