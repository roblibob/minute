import Foundation
import MinuteCore

enum ProcessingStage: String, Sendable {
    case downloadingModels
    case transcribing
    case summarizing
}

struct RecordingSession: Sendable {
    var id: UUID
    var startedAt: Date

    init(id: UUID = UUID(), startedAt: Date = Date()) {
        self.id = id
        self.startedAt = startedAt
    }
}

struct PipelineContext: Sendable {
    var vaultFolders: MeetingFileContract.VaultFolders
    var audioTempURL: URL
    var audioDurationSeconds: TimeInterval
    var startedAt: Date
    var stoppedAt: Date
    var workingDirectoryURL: URL

    init(
        vaultFolders: MeetingFileContract.VaultFolders,
        audioTempURL: URL,
        audioDurationSeconds: TimeInterval,
        startedAt: Date,
        stoppedAt: Date,
        workingDirectoryURL: URL
    ) {
        self.vaultFolders = vaultFolders
        self.audioTempURL = audioTempURL
        self.audioDurationSeconds = audioDurationSeconds
        self.startedAt = startedAt
        self.stoppedAt = stoppedAt
        self.workingDirectoryURL = workingDirectoryURL
    }
}

enum MeetingPipelineState {
    case idle
    case recording(session: RecordingSession)
    case recorded(audioTempURL: URL, durationSeconds: TimeInterval, startedAt: Date, stoppedAt: Date)
    case processing(stage: ProcessingStage, context: PipelineContext)
    case writing(context: PipelineContext, extraction: MeetingExtraction)
    case done(noteURL: URL, audioURL: URL)
    case failed(error: MinuteError, debugOutput: String?)

    var statusLabel: String {
        switch self {
        case .idle:
            return "Idle"
        case .recording:
            return "Recording"
        case .recorded:
            return "Recorded"
        case .processing(let stage, _):
            switch stage {
            case .downloadingModels:
                return "Processing — Downloading Models"
            case .transcribing:
                return "Processing — Transcribing"
            case .summarizing:
                return "Processing — Summarizing"
            }
        case .writing:
            return "Writing"
        case .done:
            return "Done"
        case .failed:
            return "Failed"
        }
    }

    var canStartRecording: Bool {
        if case .idle = self { return true }
        return false
    }

    var canStopRecording: Bool {
        if case .recording = self { return true }
        return false
    }

    var canProcess: Bool {
        if case .recorded = self { return true }
        return false
    }

    var canCancelProcessing: Bool {
        switch self {
        case .processing, .writing:
            return true
        default:
            return false
        }
    }

    var canReset: Bool {
        switch self {
        case .done, .failed:
            return true
        default:
            return false
        }
    }

    var recordedContextIfAvailable: (audioTempURL: URL, durationSeconds: TimeInterval, startedAt: Date, stoppedAt: Date)? {
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

enum MeetingPipelineAction: Sendable {
    case startRecording
    case stopRecording
    case process
    case cancelProcessing
    case reset
}
