import MinuteCore
import SwiftUI

struct VocabularyBoostingSection: View {
    @ObservedObject var model: ModelsSettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsToggleRow(
                "Enable vocabulary boosting",
                detail: "Improve recognition for names, acronyms, and domain terms.",
                isOn: $model.vocabularyBoostingEnabled
            )

            SettingsFieldBlock(
                title: "Terms",
                subtitle: "Comma or newline separated terms and phrases."
            ) {
                SettingsMultilineInput(
                    text: $model.vocabularyBoostingTermsInput,
                    placeholder: "Acme, Q4 planning, InfraOps",
                    minHeight: 72
                )
                .accessibilityLabel(Text("Vocabulary terms"))
                .accessibilityHint(Text("Comma or newline separated terms and phrases."))
            }

            Picker("Strength", selection: $model.vocabularyBoostingStrength) {
                ForEach(VocabularyBoostingStrength.allCases) { strength in
                    Text(strength.displayName).tag(strength)
                }
            }
            .pickerStyle(.segmented)

            SettingsInlineMessage(text: model.vocabularyHintText)

            if model.showsVocabularyReadinessRow, let message = model.vocabularyReadinessMessage {
                SettingsCard {
                    HStack(alignment: .center, spacing: 10) {
                        StatusIcon(state: .attention)
                        Text(message)
                            .minuteCaption()
                        Spacer()
                        Button("Download Models") {
                            model.startDownload()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }
        }
    }
}
