import Foundation

public enum PipelineStage: String, Sendable, Equatable {
    case downloadingModels
    case normalizingAudioLevels
    case transcribing
    case summarizing
    case writing
}

public struct PipelineProgress: Sendable, Equatable {
    public var stage: PipelineStage
    public var fractionCompleted: Double
    public var extraction: MeetingExtraction?
    public var preflightBudgetTokens: Int?
    public var estimatedPassCount: Int?
    public var currentPassIndex: Int?
    public var totalPassCount: Int?
    public var resumedFromPassIndex: Int?

    public init(
        stage: PipelineStage,
        fractionCompleted: Double,
        extraction: MeetingExtraction? = nil,
        preflightBudgetTokens: Int? = nil,
        estimatedPassCount: Int? = nil,
        currentPassIndex: Int? = nil,
        totalPassCount: Int? = nil,
        resumedFromPassIndex: Int? = nil
    ) {
        self.stage = stage
        self.fractionCompleted = fractionCompleted
        self.extraction = extraction
        self.preflightBudgetTokens = preflightBudgetTokens
        self.estimatedPassCount = estimatedPassCount
        self.currentPassIndex = currentPassIndex
        self.totalPassCount = totalPassCount
        self.resumedFromPassIndex = resumedFromPassIndex
    }

    public static func downloadingModels(fractionCompleted: Double) -> PipelineProgress {
        PipelineProgress(stage: .downloadingModels, fractionCompleted: fractionCompleted)
    }

    public static func transcribing(fractionCompleted: Double) -> PipelineProgress {
        PipelineProgress(stage: .transcribing, fractionCompleted: fractionCompleted)
    }

    public static func normalizingAudioLevels(fractionCompleted: Double) -> PipelineProgress {
        PipelineProgress(stage: .normalizingAudioLevels, fractionCompleted: fractionCompleted)
    }

    public static func summarizing(
        fractionCompleted: Double,
        preflightBudgetTokens: Int? = nil,
        estimatedPassCount: Int? = nil,
        currentPassIndex: Int? = nil,
        totalPassCount: Int? = nil,
        resumedFromPassIndex: Int? = nil
    ) -> PipelineProgress {
        PipelineProgress(
            stage: .summarizing,
            fractionCompleted: fractionCompleted,
            preflightBudgetTokens: preflightBudgetTokens,
            estimatedPassCount: estimatedPassCount,
            currentPassIndex: currentPassIndex,
            totalPassCount: totalPassCount,
            resumedFromPassIndex: resumedFromPassIndex
        )
    }

    public static func writing(fractionCompleted: Double, extraction: MeetingExtraction) -> PipelineProgress {
        PipelineProgress(stage: .writing, fractionCompleted: fractionCompleted, extraction: extraction)
    }
}

public struct PipelineResult: Sendable, Equatable {
    public var noteURL: URL
    public var audioURL: URL?

    public init(noteURL: URL, audioURL: URL?) {
        self.noteURL = noteURL
        self.audioURL = audioURL
    }
}

public enum TranscriptTimelineEntryKind: String, Codable, Sendable, Equatable {
    case speakerSegment
    case screenContext
}

public struct TranscriptTimelineEntry: Codable, Sendable, Equatable {
    public var kind: TranscriptTimelineEntryKind
    public var timestampStartSeconds: Double
    public var timestampEndSeconds: Double?
    public var displayLabel: String
    public var text: String
    public var speakerId: Int?
    public var windowTitle: String?

    public init(
        kind: TranscriptTimelineEntryKind,
        timestampStartSeconds: Double,
        timestampEndSeconds: Double? = nil,
        displayLabel: String,
        text: String,
        speakerId: Int? = nil,
        windowTitle: String? = nil
    ) {
        self.kind = kind
        self.timestampStartSeconds = timestampStartSeconds
        self.timestampEndSeconds = timestampEndSeconds
        self.displayLabel = displayLabel
        self.text = text
        self.speakerId = speakerId
        self.windowTitle = windowTitle
    }
}

public enum ReprocessBlockingReason: String, Codable, Sendable, Equatable {
    case missingTranscript
    case unreadableTranscript
    case invalidTargetType
}

public struct ReprocessAvailability: Codable, Sendable, Equatable {
    public var meetingId: String
    public var canReprocess: Bool
    public var blockingReason: ReprocessBlockingReason?
    public var currentMeetingTypeId: String?
    public var allowedTargetTypeIds: [String]
    public var requiresOverwriteConfirmation: Bool

    public init(
        meetingId: String,
        canReprocess: Bool,
        blockingReason: ReprocessBlockingReason? = nil,
        currentMeetingTypeId: String? = nil,
        allowedTargetTypeIds: [String] = [],
        requiresOverwriteConfirmation: Bool = false
    ) {
        self.meetingId = meetingId
        self.canReprocess = canReprocess
        self.blockingReason = blockingReason
        self.currentMeetingTypeId = currentMeetingTypeId
        self.allowedTargetTypeIds = allowedTargetTypeIds
        self.requiresOverwriteConfirmation = requiresOverwriteConfirmation
    }
}

public struct ReprocessMeetingRequest: Codable, Sendable, Equatable {
    public var meetingId: String
    public var noteURL: URL
    public var transcriptURL: URL
    public var targetMeetingTypeId: String
    public var currentMeetingTypeId: String?
    public var overwriteConfirmed: Bool

    public init(
        meetingId: String,
        noteURL: URL,
        transcriptURL: URL,
        targetMeetingTypeId: String,
        currentMeetingTypeId: String? = nil,
        overwriteConfirmed: Bool
    ) {
        self.meetingId = meetingId
        self.noteURL = noteURL
        self.transcriptURL = transcriptURL
        self.targetMeetingTypeId = targetMeetingTypeId
        self.currentMeetingTypeId = currentMeetingTypeId
        self.overwriteConfirmed = overwriteConfirmed
    }

    public func validated(availableTargetTypeIDs: Set<String>) throws -> ReprocessMeetingRequest {
        let normalizedTargetTypeID = targetMeetingTypeId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedTargetTypeID.isEmpty,
              normalizedTargetTypeID != MeetingType.autodetect.rawValue,
              availableTargetTypeIDs.contains(normalizedTargetTypeID) else {
            throw MinuteError.invalidMeetingTypeSelection
        }

        guard overwriteConfirmed else {
            throw MinuteError.reprocessOverwriteConfirmationRequired
        }

        var copy = self
        copy.targetMeetingTypeId = normalizedTargetTypeID
        return copy
    }
}

public struct PipelineContext: Sendable {
    public var vaultFolders: MeetingFileContract.VaultFolders
    public var audioTempURL: URL
    /// Audio URL used as input for analysis steps like transcription/diarization.
    ///
    /// Defaults to `audioTempURL`, but may point to a normalized temporary WAV when enabled.
    public var analysisAudioURL: URL
    public var audioDurationSeconds: TimeInterval
    public var startedAt: Date
    public var stoppedAt: Date
    public var workingDirectoryURL: URL
    public var saveAudio: Bool
    public var saveTranscript: Bool
    public var normalizeAnalysisAudio: Bool
    public var screenContextEvents: [ScreenContextEvent]
    public var transcriptionOverride: TranscriptionResult?
    public var transcriptionVocabulary: TranscriptionVocabularySettings?
    public var meetingTypeSelection: MeetingTypeSelection
    public var meetingType: MeetingType
    public var languageProcessing: LanguageProcessingProfile
    public var outputLanguage: OutputLanguage
    public var knownSpeakerSuggestionsEnabled: Bool

    public init(
        vaultFolders: MeetingFileContract.VaultFolders,
        audioTempURL: URL,
        analysisAudioURL: URL? = nil,
        audioDurationSeconds: TimeInterval,
        startedAt: Date,
        stoppedAt: Date,
        workingDirectoryURL: URL,
        saveAudio: Bool,
        saveTranscript: Bool,
        normalizeAnalysisAudio: Bool = false,
        screenContextEvents: [ScreenContextEvent] = [],
        transcriptionOverride: TranscriptionResult? = nil,
        transcriptionVocabulary: TranscriptionVocabularySettings? = nil,
        meetingTypeSelection: MeetingTypeSelection? = nil,
        meetingType: MeetingType = .autodetect,
        languageProcessing: LanguageProcessingProfile = .autoToEnglish,
        outputLanguage: OutputLanguage = .defaultSelection,
        knownSpeakerSuggestionsEnabled: Bool = false
    ) {
        self.vaultFolders = vaultFolders
        self.audioTempURL = audioTempURL
        self.analysisAudioURL = analysisAudioURL ?? audioTempURL
        self.audioDurationSeconds = audioDurationSeconds
        self.startedAt = startedAt
        self.stoppedAt = stoppedAt
        self.workingDirectoryURL = workingDirectoryURL
        self.saveAudio = saveAudio
        self.saveTranscript = saveTranscript
        self.normalizeAnalysisAudio = normalizeAnalysisAudio
        self.screenContextEvents = screenContextEvents
        self.transcriptionOverride = transcriptionOverride
        self.transcriptionVocabulary = transcriptionVocabulary
        self.meetingTypeSelection = meetingTypeSelection ?? MeetingTypeSelection(
            selectionMode: meetingType == .autodetect ? .autodetect : .manual,
            selectedTypeId: meetingType.rawValue
        )
        self.meetingType = meetingType
        self.languageProcessing = languageProcessing
        self.outputLanguage = outputLanguage
        self.knownSpeakerSuggestionsEnabled = knownSpeakerSuggestionsEnabled
    }
}
