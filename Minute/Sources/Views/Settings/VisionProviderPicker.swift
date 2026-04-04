import MinuteCore
import SwiftUI

struct VisionProviderPicker: View {
    let providers: [InferenceProvider]
    let builtInModels: [SummarizationModel]
    @Binding var selection: String
    @Binding var builtInModelSelection: String
    @Binding var ollamaModelTag: String
    @Binding var lmStudioModelIdentifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsMenuField(
                title: "Screen context provider",
                subtitle: selectedProvider?.description,
                options: providers,
                selectionLabel: selectedProvider?.displayName ?? "Select provider",
                optionLabel: { $0.displayName },
                isSelected: { $0.rawValue == selection },
                onSelect: { selection = $0.rawValue }
            )

            if selectedProvider == .builtIn {
                SummarizationModelPicker(
                    title: "Screen context model",
                    models: builtInModels,
                    selection: $builtInModelSelection
                )
            } else if selectedProvider == .ollama {
                SettingsFieldBlock(
                    title: "Ollama screen context model tag",
                    subtitle: "Use an installed Ollama model that supports screen-context or vision inference."
                ) {
                    SettingsSingleLineInput(
                        text: $ollamaModelTag,
                        placeholder: "e.g. llava:latest"
                    )
                }
            } else if selectedProvider == .lmStudio {
                SettingsFieldBlock(
                    title: "LM Studio screen context model",
                    subtitle: "Use a local LM Studio model that supports vision or screen-context input."
                ) {
                    SettingsSingleLineInput(
                        text: $lmStudioModelIdentifier,
                        placeholder: "e.g. qwen2.5-vl-7b"
                    )
                }
            }
        }
    }

    private var selectedProvider: InferenceProvider? {
        providers.first(where: { $0.rawValue == selection })
    }
}
