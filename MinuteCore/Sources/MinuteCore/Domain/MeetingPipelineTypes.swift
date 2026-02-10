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

public enum MeetingPipelineAction: Sendable, Codable, Equatable {
    case startRecording
    case startRecordingWithWindow(ScreenContextWindowSelection)
    case stopRecording
    case cancelRecording
    case process
    case importFile(URL)
    case cancelProcessing
    case reset

    private enum CodingKeys: String, CodingKey {
        case type
        case windowSelection
        case url
    }

    private enum Kind: String, Codable {
        case startRecording
        case startRecordingWithWindow
        case stopRecording
        case cancelRecording
        case process
        case importFile
        case cancelProcessing
        case reset
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .type)

        switch kind {
        case .startRecording:
            self = .startRecording
        case .startRecordingWithWindow:
            let selection = try container.decode(ScreenContextWindowSelection.self, forKey: .windowSelection)
            self = .startRecordingWithWindow(selection)
        case .stopRecording:
            self = .stopRecording
        case .cancelRecording:
            self = .cancelRecording
        case .process:
            self = .process
        case .importFile:
            let url = try container.decode(URL.self, forKey: .url)
            self = .importFile(url)
        case .cancelProcessing:
            self = .cancelProcessing
        case .reset:
            self = .reset
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .startRecording:
            try container.encode(Kind.startRecording, forKey: .type)
        case .startRecordingWithWindow(let selection):
            try container.encode(Kind.startRecordingWithWindow, forKey: .type)
            try container.encode(selection, forKey: .windowSelection)
        case .stopRecording:
            try container.encode(Kind.stopRecording, forKey: .type)
        case .cancelRecording:
            try container.encode(Kind.cancelRecording, forKey: .type)
        case .process:
            try container.encode(Kind.process, forKey: .type)
        case .importFile(let url):
            try container.encode(Kind.importFile, forKey: .type)
            try container.encode(url, forKey: .url)
        case .cancelProcessing:
            try container.encode(Kind.cancelProcessing, forKey: .type)
        case .reset:
            try container.encode(Kind.reset, forKey: .type)
        }
    }
}
