import Foundation

enum MicActivityNotification {
    static let categoryIdentifier = "minute.mic-activity"
    static let startActionIdentifier = "minute.mic-activity.start"
    static let notificationIdentifier = "minute.mic-activity.notification"
}

extension Notification.Name {
    static let minuteMicActivityShowPipeline = Notification.Name("minute.mic-activity.show-pipeline")
    static let minuteMicActivityStartRecording = Notification.Name("minute.mic-activity.start-recording")
}
