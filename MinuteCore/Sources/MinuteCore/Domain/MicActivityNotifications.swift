import Foundation

public enum MicActivityNotification {
    public static let categoryIdentifier = "minute.mic-activity"
    public static let startActionIdentifier = "minute.mic-activity.start"
    public static let notificationIdentifier = "minute.mic-activity.notification"
}

public extension Notification.Name {
    static let minuteMicActivityShowPipeline = Notification.Name("minute.mic-activity.show-pipeline")
    static let minuteMicActivityStartRecording = Notification.Name("minute.mic-activity.start-recording")
}
