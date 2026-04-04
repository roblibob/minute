import MinuteCore
import SwiftUI

struct TranscriptionLanguagePicker: View {
    let languages: [TranscriptionLanguage]
    @Binding var selection: TranscriptionLanguage

    var body: some View {
        SettingsMenuField(
            title: "Transcription language",
            subtitle: captionText,
            options: languages,
            selectionLabel: selection.displayName,
            optionLabel: { $0.displayName },
            isSelected: { $0 == selection },
            onSelect: { selection = $0 }
        )
    }

    private var captionText: String {
        if selection == .auto {
            return "Whisper will auto-detect the spoken language."
        }
        return "Force Whisper to transcribe in \(selection.displayName)."
    }
}
