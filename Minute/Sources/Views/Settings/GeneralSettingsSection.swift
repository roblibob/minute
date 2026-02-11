import MinuteCore
import SwiftUI

struct GeneralSettingsSection: View {
    @AppStorage(AppDefaultsKey.saveAudio) private var saveAudio: Bool = AppConfiguration.Defaults.defaultSaveAudio
    @AppStorage(AppDefaultsKey.saveTranscript) private var saveTranscript: Bool = AppConfiguration.Defaults.defaultSaveTranscript
    @AppStorage(AppDefaultsKey.normalizeAnalysisAudio)
    private var normalizeAnalysisAudio: Bool = AppConfiguration.Defaults.defaultNormalizeAnalysisAudio
    @AppStorage(AppDefaultsKey.micActivityNotificationsEnabled)
    private var micActivityNotificationsEnabled: Bool = AppConfiguration.Defaults.defaultMicActivityNotificationsEnabled
    @AppStorage(AppDefaultsKey.outputLanguage)
    private var outputLanguageRaw: String = AppConfiguration.Defaults.defaultOutputLanguage.rawValue

    private var outputLanguageBinding: Binding<OutputLanguage> {
        Binding(
            get: { OutputLanguage.resolved(from: outputLanguageRaw) },
            set: { outputLanguageRaw = $0.rawValue }
        )
    }

    var body: some View {
        Group {
            Section("Options") {
                SettingsToggleRow(
                    "Save audio",
                    detail: "When off, audio is not saved to the vault or linked in the note.",
                    isOn: $saveAudio
                )

                SettingsToggleRow(
                    "Save transcript",
                    detail: "When off, the transcript file and link are omitted from the note.",
                    isOn: $saveTranscript
                )

                SettingsToggleRow(
                    "Normalize audio for analysis",
                    detail: "Improves quiet/far speakers in transcription and diarization. Does not change the saved vault audio.",
                    isOn: $normalizeAnalysisAudio
                )

                SettingsToggleRow(
                    "Mic activity reminders",
                    detail: "Show a notification when the microphone becomes active.",
                    isOn: $micActivityNotificationsEnabled
                )
            }

            Section("Language") {
                Picker("Output language", selection: outputLanguageBinding) {
                    ForEach(OutputLanguage.allCases, id: \.self) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.menu)

                Text("Used when session language processing is set to Auto -> Picked language.")
                    .minuteCaption()
            }

            KnownSpeakersSettingsSection(mode: .toggleOnly)
        }
    }
}

#Preview {
    Form {
        GeneralSettingsSection()
    }
    .frame(width: 420)
}
