import MinuteCore
import SwiftUI

struct KnownSpeakersSettingsSection: View {
    enum Mode {
        case toggleOnly
        case manage
    }

    private let mode: Mode

    @AppStorage(AppDefaultsKey.knownSpeakerSuggestionsEnabled)
    private var knownSpeakerSuggestionsEnabled: Bool = AppConfiguration.Defaults.defaultKnownSpeakerSuggestionsEnabled

    @State private var profiles: [SpeakerProfile] = []
    @State private var loadError: String?

    private let store = SpeakerProfileStore()

    init(mode: Mode = .manage) {
        self.mode = mode
    }

    var body: some View {
        Section("Known speakers") {
            SettingsToggleRow(
                "Known speaker suggestions",
                detail: "When enabled, Minute can suggest names for diarized speakers using local-only voice profiles stored on this Mac.",
                isOn: $knownSpeakerSuggestionsEnabled
            )

            if knownSpeakerSuggestionsEnabled, mode == .manage {
                if let loadError {
                    Text(loadError)
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                if profiles.isEmpty {
                    Text("No speaker profiles yet.")
                        .foregroundStyle(Color.minuteTextSecondary)
                } else {
                    ForEach(profiles) { profile in
                        HStack(spacing: 8) {
                            Text(profile.name)
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

                Button {
                    Task { await refresh() }
                } label: {
                    Text("Refresh profiles")
                }
                .buttonStyle(.plain)
            } else if knownSpeakerSuggestionsEnabled, mode == .toggleOnly {
                Text("Manage profiles in Settings → Speakers.")
                    .foregroundStyle(Color.minuteTextSecondary)
            }
        }
        .task {
            if mode == .manage {
                await refresh()
            }
        }
        .onChange(of: knownSpeakerSuggestionsEnabled) { _, newValue in
            guard mode == .manage else { return }
            if newValue {
                Task { await refresh() }
            } else {
                loadError = nil
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
        KnownSpeakersSettingsSection(mode: .manage)
    }
    .frame(width: 520)
}
