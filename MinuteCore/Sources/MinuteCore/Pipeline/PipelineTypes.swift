import Foundation

public enum PipelineStage: String, Sendable, Equatable {
    case downloadingModels
    case transcribing
    case summarizing
    case writing
}

public struct PipelineProgress: Sendable, Equatable {
    public var stage: PipelineStage
    public var fractionCompleted: Double
    public var extraction: MeetingExtraction?

    public init(stage: PipelineStage, fractionCompleted: Double, extraction: MeetingExtraction? = nil) {
        self.stage = stage
        self.fractionCompleted = fractionCompleted
        self.extraction = extraction
    }

    public static func downloadingModels(fractionCompleted: Double) -> PipelineProgress {
        PipelineProgress(stage: .downloadingModels, fractionCompleted: fractionCompleted)
    }

    public static func transcribing(fractionCompleted: Double) -> PipelineProgress {
        PipelineProgress(stage: .transcribing, fractionCompleted: fractionCompleted)
    }

    public static func summarizing(fractionCompleted: Double) -> PipelineProgress {
        PipelineProgress(stage: .summarizing, fractionCompleted: fractionCompleted)
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
    public var meetingType: MeetingType
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
        meetingType: MeetingType = .autodetect,
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
        self.meetingType = meetingType
        self.knownSpeakerSuggestionsEnabled = knownSpeakerSuggestionsEnabled
    }
}
