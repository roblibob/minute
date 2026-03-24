import Foundation

public enum MicActivityNotification {
    public static let categoryIdentifier = "minute.mic-activity"
    public static let startActionIdentifier = "minute.mic-activity.start"
    public static let notificationIdentifier = "minute.mic-activity.notification"
}

public enum RecordingAlertNotification {
    public static let silenceWarningCategoryIdentifier = "minute.recording-alert.silence-warning"
    public static let sharedWindowClosedCategoryIdentifier = "minute.recording-alert.shared-window-closed"
    public static let screenContextConfigurationCategoryIdentifier = "minute.recording-alert.screen-context-configuration"
    public static let keepRecordingActionIdentifier = "minute.recording-alert.keep-recording"
    public static let silenceWarningNotificationIdentifier = "minute.recording-alert.silence-warning"
    public static let sharedWindowClosedNotificationIdentifier = "minute.recording-alert.shared-window-closed"
    public static let screenContextConfigurationNotificationIdentifier = "minute.recording-alert.screen-context-configuration"
}

public extension Notification.Name {
    static let minuteMicActivityShowPipeline = Notification.Name("minute.mic-activity.show-pipeline")
    static let minuteMicActivityStartRecording = Notification.Name("minute.mic-activity.start-recording")
    static let minuteRecordingAlertShowPipeline = Notification.Name("minute.recording-alert.show-pipeline")
    static let minuteRecordingAlertKeepRecording = Notification.Name("minute.recording-alert.keep-recording")
}
