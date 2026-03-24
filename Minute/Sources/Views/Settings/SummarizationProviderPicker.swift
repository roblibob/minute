import MinuteCore
import SwiftUI

struct SummarizationProviderPicker: View {
    let providers: [InferenceProvider]
    @Binding var selection: String
    @Binding var ollamaModelTag: String

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
            }
        }
    }

    private var selectedProvider: InferenceProvider? {
        providers.first(where: { $0.rawValue == selection })
    }
}
