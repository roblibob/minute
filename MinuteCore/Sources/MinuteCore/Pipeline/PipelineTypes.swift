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
    public var audioDurationSeconds: TimeInterval
    public var startedAt: Date
    public var stoppedAt: Date
    public var workingDirectoryURL: URL
    public var saveAudio: Bool
    public var saveTranscript: Bool
    public var screenContextEvents: [ScreenContextEvent]

    public init(
        vaultFolders: MeetingFileContract.VaultFolders,
        audioTempURL: URL,
        audioDurationSeconds: TimeInterval,
        startedAt: Date,
        stoppedAt: Date,
        workingDirectoryURL: URL,
        saveAudio: Bool,
        saveTranscript: Bool,
        screenContextEvents: [ScreenContextEvent] = []
    ) {
        self.vaultFolders = vaultFolders
        self.audioTempURL = audioTempURL
        self.audioDurationSeconds = audioDurationSeconds
        self.startedAt = startedAt
        self.stoppedAt = stoppedAt
        self.workingDirectoryURL = workingDirectoryURL
        self.saveAudio = saveAudio
        self.saveTranscript = saveTranscript
        self.screenContextEvents = screenContextEvents
    }
}
