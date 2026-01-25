import MinuteCore
import OSLog
import UserNotifications

@MainActor
final class MicActivityNotificationCoordinator {
    private let monitor: MicrophoneActivityMonitor
    private let notificationCenter: UNUserNotificationCenter
    private let logger = Logger(subsystem: "roblibob.Minute", category: "mic-activity-notifications")
    private var task: Task<Void, Never>?
    private var pipelineState: MeetingPipelineState = .idle
    private var isEnabled = false
    private var lastNotificationAt: Date?
    private let minimumNotificationInterval: TimeInterval = 30

    init(
        monitor: MicrophoneActivityMonitor = MicrophoneActivityMonitor(),
        notificationCenter: UNUserNotificationCenter = .current()
    ) {
        self.monitor = monitor
        self.notificationCenter = notificationCenter
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled {
            start()
            Task { _ = await ensureAuthorized() }
        } else {
            stop()
        }
    }

    func updatePipelineState(_ state: MeetingPipelineState) {
        pipelineState = state
    }

    func stop() {
        task?.cancel()
        task = nil
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [MicActivityNotification.notificationIdentifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [MicActivityNotification.notificationIdentifier])
    }

    private func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            guard let self else { return }
            for await event in monitor.events() {
                await self.handle(event)
            }
        }
    }

    private func handle(_ event: MicrophoneActivityMonitor.Event) async {
        guard isEnabled else { return }
        guard shouldNotify(for: pipelineState) else { return }

        if let lastNotificationAt, Date().timeIntervalSince(lastNotificationAt) < minimumNotificationInterval {
            return
        }

        guard await ensureAuthorized() else { return }
        await scheduleNotification(deviceName: event.deviceName)
        lastNotificationAt = Date()
    }

    private func shouldNotify(for state: MeetingPipelineState) -> Bool {
        switch state {
        case .idle, .done, .failed:
            return true
        default:
            return false
        }
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

    private func scheduleNotification(deviceName: String?) async {
        let content = UNMutableNotificationContent()
        content.title = "Microphone active"
        if let deviceName {
            content.body = "\(deviceName) is live. Start recording this meeting?"
        } else {
            content.body = "Start recording this meeting?"
        }
        content.categoryIdentifier = MicActivityNotification.categoryIdentifier
        content.threadIdentifier = MicActivityNotification.categoryIdentifier
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: MicActivityNotification.notificationIdentifier,
            content: content,
            trigger: nil
        )

        notificationCenter.removeDeliveredNotifications(withIdentifiers: [MicActivityNotification.notificationIdentifier])
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [MicActivityNotification.notificationIdentifier])

        do {
            try await notificationCenter.add(request)
        } catch {
            logger.error("Failed to schedule mic activity notification: \(error.localizedDescription, privacy: .public)")
        }
    }
}
