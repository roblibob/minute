import Foundation

public enum RecordingAlertType: String, Sendable, Codable, Equatable {
    case silenceStopWarning = "silence_stop_warning"
    case screenWindowClosed = "screen_window_closed"
    case screenWindowClosedStopWarning = "screen_window_closed_stop_warning"
    case screenContextConfigurationFailure = "screen_context_configuration_failure"
}

public enum RecordingAlertAction: String, Sendable, Codable, Equatable {
    case keepRecording = "keep_recording"
    case acknowledge = "acknowledge"
}

public enum RecordingAlertStatus: String, Sendable, Codable, Equatable {
    case active
    case resolved
    case expired
}

public struct RecordingAlert: Sendable, Equatable, Identifiable, Codable {
    public var id: UUID
    public var type: RecordingAlertType
    public var sessionID: UUID
    public var message: String
    public var issuedAt: Date
    public var expiresAt: Date?
    public var actions: [RecordingAlertAction]
    public var status: RecordingAlertStatus

    public init(
        id: UUID = UUID(),
        type: RecordingAlertType,
        sessionID: UUID,
        message: String,
        issuedAt: Date = Date(),
        expiresAt: Date? = nil,
        actions: [RecordingAlertAction] = [],
        status: RecordingAlertStatus = .active
    ) {
        self.id = id
        self.type = type
        self.sessionID = sessionID
        self.message = message
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.actions = actions
        self.status = status
    }

    public var isValid: Bool {
        switch type {
        case .silenceStopWarning:
            return expiresAt != nil
        case .screenWindowClosed, .screenContextConfigurationFailure:
            return expiresAt == nil
        case .screenWindowClosedStopWarning:
            return expiresAt != nil
        }
    }
}

public enum RecordingSessionEventType: String, Sendable, Codable, Equatable {
    case silenceWarningIssued = "silence_warning_issued"
    case keepRecordingSelected = "keep_recording_selected"
    case warningCanceledBySpeech = "warning_canceled_by_speech"
    case autoStopExecuted = "auto_stop_executed"
    case manualStop = "manual_stop"
    case recordingCanceled = "recording_canceled"
    case screenWindowClosedNotified = "screen_window_closed_notified"
    case screenContextConfigurationNotified = "screen_context_configuration_notified"
}

public struct RecordingSessionEvent: Sendable, Equatable, Identifiable, Codable {
    public var id: UUID
    public var sessionID: UUID
    public var eventType: RecordingSessionEventType
    public var timestamp: Date
    public var metadata: [String: String]

    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        eventType: RecordingSessionEventType,
        timestamp: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.sessionID = sessionID
        self.eventType = eventType
        self.timestamp = timestamp
        self.metadata = metadata
    }
}
