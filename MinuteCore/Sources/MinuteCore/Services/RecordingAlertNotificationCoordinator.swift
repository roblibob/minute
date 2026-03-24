import OSLog
import UserNotifications

@MainActor
public final class RecordingAlertNotificationCoordinator: RecordingAlertNotifying {
    private let notificationCenter: UNUserNotificationCenter
    private let logger = Logger(subsystem: "roblibob.Minute", category: "recording-alert-notifications")

    public init(notificationCenter: UNUserNotificationCenter = .current()) {
        self.notificationCenter = notificationCenter
    }

    public func notifySilenceStopWarning(alert: RecordingAlert) async -> Bool {
        guard await ensureAuthorized() else { return false }

        let content = UNMutableNotificationContent()
        content.title = "Silence detected"
        content.body = alert.message
        content.categoryIdentifier = RecordingAlertNotification.silenceWarningCategoryIdentifier
        content.threadIdentifier = RecordingAlertNotification.silenceWarningCategoryIdentifier
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: RecordingAlertNotification.silenceWarningNotificationIdentifier,
            content: content,
            trigger: nil
        )

        notificationCenter.removePendingNotificationRequests(withIdentifiers: [RecordingAlertNotification.silenceWarningNotificationIdentifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [RecordingAlertNotification.silenceWarningNotificationIdentifier])

        do {
            try await notificationCenter.add(request)
            return true
        } catch {
            logger.error("Failed to schedule silence warning notification: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    public func notifySharedWindowClosed(alert: RecordingAlert) async -> Bool {
        guard await ensureAuthorized() else { return false }

        let content = UNMutableNotificationContent()
        content.title = "Screen context ended"
        content.body = alert.message
        content.categoryIdentifier = RecordingAlertNotification.sharedWindowClosedCategoryIdentifier
        content.threadIdentifier = RecordingAlertNotification.sharedWindowClosedCategoryIdentifier
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: RecordingAlertNotification.sharedWindowClosedNotificationIdentifier,
            content: content,
            trigger: nil
        )

        notificationCenter.removePendingNotificationRequests(withIdentifiers: [RecordingAlertNotification.sharedWindowClosedNotificationIdentifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [RecordingAlertNotification.sharedWindowClosedNotificationIdentifier])

        do {
            try await notificationCenter.add(request)
            return true
        } catch {
            logger.error("Failed to schedule shared-window-closed notification: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    public func notifyScreenContextConfigurationFailure(alert: RecordingAlert) async -> Bool {
        guard await ensureAuthorized() else { return false }

        let content = UNMutableNotificationContent()
        content.title = "Screen context unavailable"
        content.body = alert.message
        content.categoryIdentifier = RecordingAlertNotification.screenContextConfigurationCategoryIdentifier
        content.threadIdentifier = RecordingAlertNotification.screenContextConfigurationCategoryIdentifier
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: RecordingAlertNotification.screenContextConfigurationNotificationIdentifier,
            content: content,
            trigger: nil
        )

        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: [RecordingAlertNotification.screenContextConfigurationNotificationIdentifier]
        )
        notificationCenter.removeDeliveredNotifications(
            withIdentifiers: [RecordingAlertNotification.screenContextConfigurationNotificationIdentifier]
        )

        do {
            try await notificationCenter.add(request)
            return true
        } catch {
            logger.error(
                "Failed to schedule screen-context-configuration notification: \(error.localizedDescription, privacy: .public)"
            )
            return false
        }
    }

    public func clearSilenceStopWarning() async {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [RecordingAlertNotification.silenceWarningNotificationIdentifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [RecordingAlertNotification.silenceWarningNotificationIdentifier])
    }

    public func clearSharedWindowClosedWarning() async {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [RecordingAlertNotification.sharedWindowClosedNotificationIdentifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [RecordingAlertNotification.sharedWindowClosedNotificationIdentifier])
    }

    public func clearScreenContextConfigurationFailure() async {
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: [RecordingAlertNotification.screenContextConfigurationNotificationIdentifier]
        )
        notificationCenter.removeDeliveredNotifications(
            withIdentifiers: [RecordingAlertNotification.screenContextConfigurationNotificationIdentifier]
        )
    }

    private func ensureAuthorized() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                return try await notificationCenter.requestAuthorization(options: [.alert, .sound])
            } catch {
                logger.error("Notification authorization failed: \(error.localizedDescription, privacy: .public)")
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }
}
