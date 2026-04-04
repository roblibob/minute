import SwiftUI

struct SettingsCategoryDefinition: Identifiable, Hashable {
    enum ID: String, CaseIterable, Hashable {
        case general
        case storage
        case speakers
        case privacy
        case ai
        case meetingTypes
        case updates
    }

    var id: ID
    var title: String
    var iconName: String
    var sortOrder: Int
    var description: String
    var isVisible: Bool

    var accessibilityLabel: String {
        "\(title) settings category"
    }
}

struct SettingsEntryDefinition: Hashable {
    enum ID: String, CaseIterable, Hashable {
        case saveAudio
        case saveTranscript
        case normalizeAnalysisAudio
        case micActivityNotifications
        case outputLanguage
        case vaultRoot
        case meetingsFolder
        case audioFolder
        case transcriptsFolder
        case knownSpeakerSuggestions
        case speakerProfiles
        case microphoneAccess
        case screenRecordingAccess
        case transcriptionEngine
        case transcriptionModel
        case transcriptionLanguage
        case fluidAudioModel
        case vocabularyBoosting
        case summarizationProvider
        case summarizationModel
        case summarizationContextWindow
        case screenContextEnabled
        case screenContextProvider
        case screenContextModel
        case screenContextCaptureInterval
        case screenContextVideoImport
        case ollamaBaseURL
        case lmStudioBaseURL
        case transcriptionModelDownloads
        case summarizationModelDownloads
        case screenContextModelDownloads
        case meetingTypesEditor
        case automaticallyCheckUpdates
        case automaticallyDownloadUpdates
        case checkForUpdates
    }

    let id: ID
    let categoryID: SettingsCategoryDefinition.ID
}

enum SettingsCategoryCatalog {
    // When adding a new category:
    // 1) Add a new `ID` case.
    // 2) Insert a `SettingsCategoryDefinition` with a unique `sortOrder`.
    // 3) Keep titles task-oriented and stable so users build navigation memory.
    // 4) Update `MainSettingsView` switch rendering and category coverage tests.
    static func categories(updatesEnabled: Bool) -> [SettingsCategoryDefinition] {
        var definitions: [SettingsCategoryDefinition] = [
            SettingsCategoryDefinition(
                id: .general,
                title: "General",
                iconName: "slider.horizontal.3",
                sortOrder: 10,
                description: "Recording defaults, output behavior, and language.",
                isVisible: true
            ),
            SettingsCategoryDefinition(
                id: .storage,
                title: "Vault",
                iconName: "externaldrive",
                sortOrder: 20,
                description: "Vault root and folders for notes, audio, and transcripts.",
                isVisible: true
            ),
            SettingsCategoryDefinition(
                id: .speakers,
                title: "Speakers",
                iconName: "person.2",
                sortOrder: 30,
                description: "Known speaker suggestions and profile management.",
                isVisible: true
            ),
            SettingsCategoryDefinition(
                id: .privacy,
                title: "Privacy & Permissions",
                iconName: "hand.raised",
                sortOrder: 40,
                description: "Microphone and screen recording permissions.",
                isVisible: true
            ),
            SettingsCategoryDefinition(
                id: .ai,
                title: "AI & Models",
                iconName: "sparkles",
                sortOrder: 50,
                description: "Transcription, summarization, screen context, and local model readiness.",
                isVisible: true
            ),
            SettingsCategoryDefinition(
                id: .meetingTypes,
                title: "Meeting Types",
                iconName: "list.bullet.rectangle",
                sortOrder: 55,
                description: "Create and edit built-in and custom meeting prompts.",
                isVisible: true
            ),
            SettingsCategoryDefinition(
                id: .updates,
                title: "Updates",
                iconName: "arrow.down.circle",
                sortOrder: 60,
                description: "Application update checks and channels.",
                isVisible: updatesEnabled
            ),
        ]

        definitions.sort { $0.sortOrder < $1.sortOrder }
        return definitions.filter(\.isVisible)
    }

    static func entries(updatesEnabled: Bool) -> [SettingsEntryDefinition] {
        var definitions: [SettingsEntryDefinition] = [
            SettingsEntryDefinition(id: .saveAudio, categoryID: .general),
            SettingsEntryDefinition(id: .saveTranscript, categoryID: .general),
            SettingsEntryDefinition(id: .normalizeAnalysisAudio, categoryID: .general),
            SettingsEntryDefinition(id: .micActivityNotifications, categoryID: .general),
            SettingsEntryDefinition(id: .outputLanguage, categoryID: .general),
            SettingsEntryDefinition(id: .vaultRoot, categoryID: .storage),
            SettingsEntryDefinition(id: .meetingsFolder, categoryID: .storage),
            SettingsEntryDefinition(id: .audioFolder, categoryID: .storage),
            SettingsEntryDefinition(id: .transcriptsFolder, categoryID: .storage),
            SettingsEntryDefinition(id: .knownSpeakerSuggestions, categoryID: .speakers),
            SettingsEntryDefinition(id: .speakerProfiles, categoryID: .speakers),
            SettingsEntryDefinition(id: .microphoneAccess, categoryID: .privacy),
            SettingsEntryDefinition(id: .screenRecordingAccess, categoryID: .privacy),
            SettingsEntryDefinition(id: .transcriptionEngine, categoryID: .ai),
            SettingsEntryDefinition(id: .transcriptionModel, categoryID: .ai),
            SettingsEntryDefinition(id: .transcriptionLanguage, categoryID: .ai),
            SettingsEntryDefinition(id: .fluidAudioModel, categoryID: .ai),
            SettingsEntryDefinition(id: .vocabularyBoosting, categoryID: .ai),
            SettingsEntryDefinition(id: .summarizationProvider, categoryID: .ai),
            SettingsEntryDefinition(id: .summarizationModel, categoryID: .ai),
            SettingsEntryDefinition(id: .summarizationContextWindow, categoryID: .ai),
            SettingsEntryDefinition(id: .screenContextEnabled, categoryID: .ai),
            SettingsEntryDefinition(id: .screenContextProvider, categoryID: .ai),
            SettingsEntryDefinition(id: .screenContextModel, categoryID: .ai),
            SettingsEntryDefinition(id: .screenContextCaptureInterval, categoryID: .ai),
            SettingsEntryDefinition(id: .screenContextVideoImport, categoryID: .ai),
            SettingsEntryDefinition(id: .ollamaBaseURL, categoryID: .ai),
            SettingsEntryDefinition(id: .lmStudioBaseURL, categoryID: .ai),
            SettingsEntryDefinition(id: .transcriptionModelDownloads, categoryID: .ai),
            SettingsEntryDefinition(id: .summarizationModelDownloads, categoryID: .ai),
            SettingsEntryDefinition(id: .screenContextModelDownloads, categoryID: .ai),
            SettingsEntryDefinition(id: .meetingTypesEditor, categoryID: .meetingTypes),
        ]

        if updatesEnabled {
            definitions.append(contentsOf: [
                SettingsEntryDefinition(id: .automaticallyCheckUpdates, categoryID: .updates),
                SettingsEntryDefinition(id: .automaticallyDownloadUpdates, categoryID: .updates),
                SettingsEntryDefinition(id: .checkForUpdates, categoryID: .updates),
            ])
        }

        return definitions
    }

    static func categoryID(
        for entryID: SettingsEntryDefinition.ID,
        updatesEnabled: Bool
    ) -> SettingsCategoryDefinition.ID? {
        entries(updatesEnabled: updatesEnabled)
            .first(where: { $0.id == entryID })?
            .categoryID
    }

    static func fallbackSelection(
        current: SettingsCategoryDefinition.ID?,
        available: [SettingsCategoryDefinition]
    ) -> SettingsCategoryDefinition.ID? {
        if let current,
           available.contains(where: { $0.id == current }) {
            return current
        }
        return available.first?.id
    }
}
