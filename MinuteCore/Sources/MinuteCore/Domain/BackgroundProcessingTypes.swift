import Foundation

public enum BackgroundProcessingOutcome: Sendable, Equatable {
    case completed(noteURL: URL, audioURL: URL?)
    case canceled
    case failed(message: String)
}

public struct BackgroundProcessingSnapshot: Sendable, Equatable {
    public var activeMeetingID: UUID?
    public var activeStage: PipelineStage?
    public var activeProgress: Double?

    public var pendingMeetingID: UUID?

    public var lastOutcome: BackgroundProcessingOutcome?

    public init(
        activeMeetingID: UUID? = nil,
        activeStage: PipelineStage? = nil,
        activeProgress: Double? = nil,
        pendingMeetingID: UUID? = nil,
        lastOutcome: BackgroundProcessingOutcome? = nil
    ) {
        self.activeMeetingID = activeMeetingID
        self.activeStage = activeStage
        self.activeProgress = activeProgress
        self.pendingMeetingID = pendingMeetingID
        self.lastOutcome = lastOutcome
    }
}
