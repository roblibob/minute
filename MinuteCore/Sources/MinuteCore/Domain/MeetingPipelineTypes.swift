import Foundation

public enum ProcessingStage: String, Sendable {
    case downloadingModels
    case transcribing
    case summarizing
}

public struct RecordingSession: Sendable {
    public var id: UUID
    public var startedAt: Date

    public init(id: UUID = UUID(), startedAt: Date = Date()) {
        self.id = id
        self.startedAt = startedAt
    }
}

public enum MeetingPipelineState {
    case idle
    case importing(sourceURL: URL)
    case recording(session: RecordingSession)
    case recorded(audioTempURL: URL, durationSeconds: TimeInterval, startedAt: Date, stoppedAt: Date)
    case processing(stage: ProcessingStage, context: PipelineContext)
    case writing(context: PipelineContext, extraction: MeetingExtraction)
    case done(noteURL: URL, audioURL: URL?)
    case failed(error: MinuteError, debugOutput: String?)

    public var statusLabel: String {
        switch self {
        case .idle:
            return "Idle"
        case .importing:
            return "Importing"
        case .recording:
            return "Recording"
        case .recorded:
            return "Recorded"
        case .processing(let stage, _):
            switch stage {
            case .downloadingModels:
                return "Downloading Models"
            case .transcribing:
                return "Transcribing"
            case .summarizing:
                return "Summarizing"
            }
        case .writing:
            return "Writing"
        case .done:
            return "Done"
        case .failed:
            return "Failed"
        }
    }

    public var canStartRecording: Bool {
        if case .idle = self { return true }
        return false
    }

    public var canImportMedia: Bool {
        switch self {
        case .idle, .recorded, .done, .failed:
            return true
        default:
            return false
        }
    }

    public var canStopRecording: Bool {
        if case .recording = self { return true }
        return false
    }

    public var canProcess: Bool {
        if case .recorded = self { return true }
        return false
    }

    public var canCancelProcessing: Bool {
        switch self {
        case .importing, .processing, .writing:
            return true
        default:
            return false
        }
    }

    public var canReset: Bool {
        switch self {
        case .done, .failed:
            return true
        default:
            return false
        }
    }

    public var recordedContextIfAvailable: (audioTempURL: URL, durationSeconds: TimeInterval, startedAt: Date, stoppedAt: Date)? {
        switch self {
        case .recorded(let audioTempURL, let durationSeconds, let startedAt, let stoppedAt):
            return (audioTempURL: audioTempURL, durationSeconds: durationSeconds, startedAt: startedAt, stoppedAt: stoppedAt)
        case .processing(_, let context):
            return (audioTempURL: context.audioTempURL, durationSeconds: context.audioDurationSeconds, startedAt: context.startedAt, stoppedAt: context.stoppedAt)
        case .writing(let context, _):
            return (audioTempURL: context.audioTempURL, durationSeconds: context.audioDurationSeconds, startedAt: context.startedAt, stoppedAt: context.stoppedAt)
        default:
            return nil
        }
    }
}

public enum MeetingPipelineAction: Sendable {
    case startRecording
    case startRecordingWithWindow(ScreenContextWindowSelection)
    case stopRecording
    case process
    case importFile(URL)
    case cancelProcessing
    case reset
}
