import MinuteCore
import SwiftUI

struct KnownSpeakersSettingsSection: View {
    @AppStorage(AppDefaultsKey.knownSpeakerSuggestionsEnabled)
    private var knownSpeakerSuggestionsEnabled: Bool = AppConfiguration.Defaults.defaultKnownSpeakerSuggestionsEnabled

    @State private var profiles: [SpeakerProfile] = []
    @State private var loadError: String?

    private let store = SpeakerProfileStore()

    var body: some View {
        Section("People & Speakers") {
            SettingsToggleRow(
                "Known speaker suggestions",
                detail: "When enabled, Minute can suggest names for diarized speakers using local-only voice profiles stored on this Mac.",
                isOn: $knownSpeakerSuggestionsEnabled
            )

            if knownSpeakerSuggestionsEnabled {
                if let loadError {
                    SettingsInlineMessage(text: loadError, tone: .error)
                }

                if profiles.isEmpty {
                    SettingsInlineMessage(text: "No speaker profiles yet.")
                } else {
                    ForEach(profiles) { profile in
                        SettingsCard {
                            HStack(spacing: 8) {
                                Text(profile.name)
                                    .minuteControlValue()
                                    .lineLimit(1)

                                Spacer()

                                Button(role: .destructive) {
                                    Task { await delete(profileID: profile.id) }
                                } label: {
                                    Text("Delete")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }

                SettingsActionRow {
                    Button {
                        Task { await refresh() }
                    } label: {
                        Text("Refresh profiles")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .task {
            guard knownSpeakerSuggestionsEnabled else { return }
            await refresh()
        }
        .onChange(of: knownSpeakerSuggestionsEnabled) { _, newValue in
            if newValue {
                Task { await refresh() }
            } else {
                loadError = nil
                profiles = []
            }
        }
    }

    @MainActor
    private func refresh() async {
        do {
            let loaded = try await store.listProfiles()
            profiles = loaded
            loadError = nil
        } catch {
            loadError = "Unable to load speaker profiles."
        }
    }

    @MainActor
    private func delete(profileID: String) async {
        do {
            try await store.deleteProfile(profileID: profileID)
            await refresh()
        } catch {
            loadError = "Unable to delete speaker profile."
        }
    }
}

#Preview {
    Form {
        KnownSpeakersSettingsSection()
    }
    .frame(width: 520)
}
