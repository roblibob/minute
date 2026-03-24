import MinuteCore
import SwiftUI

struct VisionProviderPicker: View {
    let providers: [InferenceProvider]
    let builtInModels: [SummarizationModel]
    @Binding var selection: String
    @Binding var builtInModelSelection: String
    @Binding var ollamaModelTag: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Screen context provider")
                .minuteRowTitle()

            Menu {
                ForEach(providers, id: \.rawValue) { provider in
                    Button {
                        selection = provider.rawValue
                    } label: {
                        if provider.rawValue == selection {
                            Label(provider.displayName, systemImage: "checkmark")
                        } else {
                            Text(provider.displayName)
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(selectedProvider?.displayName ?? "Select provider")
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .minuteDropdownStyle()
            }
            .menuStyle(.borderlessButton)

            if let selectedProvider {
                Text(selectedProvider.description)
                    .minuteCaption()
            }

            if selectedProvider == .builtIn {
                SummarizationModelPicker(
                    title: "Screen context model",
                    models: builtInModels,
                    selection: $builtInModelSelection
                )
            } else if selectedProvider == .ollama {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ollama screen context model tag")
                        .minuteRowTitle()

                    TextField("e.g. llava:latest", text: $ollamaModelTag)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()

                    Text("Use an installed Ollama model that supports screen-context or vision inference.")
                        .minuteCaption()
                }
            }
        }
    }

    private var selectedProvider: InferenceProvider? {
        providers.first(where: { $0.rawValue == selection })
    }
}
