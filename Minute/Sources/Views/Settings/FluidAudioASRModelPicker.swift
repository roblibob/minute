import MinuteCore
import SwiftUI

struct FluidAudioASRModelPicker: View {
    let models: [FluidAudioASRModel]
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FluidAudio model")
                .minuteRowTitle()

            Menu {
                ForEach(models) { model in
                    Button {
                        selection = model.id
                    } label: {
                        if model.id == selection {
                            Label(model.displayName, systemImage: "checkmark")
                        } else {
                            Text(model.displayName)
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

            if let selectedModel {
                Text(selectedModel.summary)
                    .minuteCaption()
            }
        }
    }

    private var selectedModel: FluidAudioASRModel? {
        models.first { $0.id == selection } ?? models.first
    }

    private var selectedLabel: String {
        selectedModel?.displayName ?? "Select model"
    }
}
