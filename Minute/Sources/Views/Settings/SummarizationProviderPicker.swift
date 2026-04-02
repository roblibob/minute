import MinuteCore
import SwiftUI

struct SummarizationProviderPicker: View {
    let providers: [InferenceProvider]
    @Binding var selection: String
    @Binding var ollamaModelTag: String
    @Binding var lmStudioModelIdentifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Summarization provider")
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

            if selectedProvider == .ollama {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ollama model tag")
                        .minuteRowTitle()

                    TextField("e.g. llama3.2:latest", text: $ollamaModelTag)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()

                    Text("Use a tag already available in your local Ollama daemon.")
                        .minuteCaption()
                }
            } else if selectedProvider == .lmStudio {
                VStack(alignment: .leading, spacing: 6) {
                    Text("LM Studio model")
                        .minuteRowTitle()

                    TextField("e.g. qwen2.5-7b-instruct", text: $lmStudioModelIdentifier)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()

                    Text("Use a model identifier already available in your local LM Studio server.")
                        .minuteCaption()
                }
            }
        }
    }

    private var selectedProvider: InferenceProvider? {
        providers.first(where: { $0.rawValue == selection })
    }
}
