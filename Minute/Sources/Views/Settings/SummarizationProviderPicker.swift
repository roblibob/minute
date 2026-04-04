import MinuteCore
import SwiftUI

struct SummarizationProviderPicker: View {
    let providers: [InferenceProvider]
    @Binding var selection: String
    @Binding var ollamaModelTag: String
    @Binding var lmStudioModelIdentifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsMenuField(
                title: "Summarization provider",
                subtitle: selectedProvider?.description,
                options: providers,
                selectionLabel: selectedProvider?.displayName ?? "Select provider",
                optionLabel: { $0.displayName },
                isSelected: { $0.rawValue == selection },
                onSelect: { selection = $0.rawValue }
            )

            if selectedProvider == .ollama {
                SettingsFieldBlock(
                    title: "Ollama model tag",
                    subtitle: "Use a tag already available in your local Ollama daemon."
                ) {
                    SettingsSingleLineInput(
                        text: $ollamaModelTag,
                        placeholder: "e.g. llama3.2:latest"
                    )
                }
            } else if selectedProvider == .lmStudio {
                SettingsFieldBlock(
                    title: "LM Studio model",
                    subtitle: "Use a model identifier already available in your local LM Studio server."
                ) {
                    SettingsSingleLineInput(
                        text: $lmStudioModelIdentifier,
                        placeholder: "e.g. qwen2.5-7b-instruct"
                    )
                }
            }
        }
    }

    private var selectedProvider: InferenceProvider? {
        providers.first(where: { $0.rawValue == selection })
    }
}
