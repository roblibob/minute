import CoreAudio
import Foundation
import OSLog

public final class MicrophoneActivityMonitor: @unchecked Sendable {
    public struct Configuration: Sendable, Equatable {
        public var minimumActiveDuration: TimeInterval

        public init(minimumActiveDuration: TimeInterval = 0.35) {
            self.minimumActiveDuration = minimumActiveDuration
        }
    }

    public struct Event: Sendable, Equatable {
        public let deviceID: AudioDeviceID
        public let deviceName: String?
        public let timestamp: Date

        public init(deviceID: AudioDeviceID, deviceName: String?, timestamp: Date) {
            self.deviceID = deviceID
            self.deviceName = deviceName
            self.timestamp = timestamp
        }
    }

    private let configuration: Configuration
    private let logger = Logger(subsystem: "roblibob.Minute", category: "mic-activity")
    private let queue = DispatchQueue(label: "roblibob.Minute.mic-activity")

    private var continuation: AsyncStream<Event>.Continuation?
    private var currentDeviceID: AudioDeviceID = 0
    private var isDeviceActive = false
    private var isRunning = false
    private var pendingActivationWorkItem: DispatchWorkItem?
    private var deviceListenerInstalled = false
    private var hardwareListenerInstalled = false
    private var deviceListener: AudioObjectPropertyListenerBlock?
    private var hardwareListener: AudioObjectPropertyListenerBlock?

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    public func events() -> AsyncStream<Event> {
        AsyncStream { continuation in
            queue.async { [weak self] in
                self?.start(continuation: continuation)
            }
            continuation.onTermination = { @Sendable _ in
                self.queue.async { [weak self] in
                    self?.stop()
                }
            }
        }
    }

    private func start(continuation: AsyncStream<Event>.Continuation) {
        self.continuation = continuation
        guard !isRunning else { return }
        isRunning = true
        installHardwareListenerIfNeeded()
        updateCurrentDevice()
    }

    private func stop() {
        pendingActivationWorkItem?.cancel()
        pendingActivationWorkItem = nil
        removeDeviceListener()
        removeHardwareListener()
        continuation = nil
        isRunning = false
    }

    private func installHardwareListenerIfNeeded() {
        guard !hardwareListenerInstalled else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.updateCurrentDevice()
        }
        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            queue,
            listener
        )
        if status == noErr {
            hardwareListenerInstalled = true
            hardwareListener = listener
        } else {
            logger.error("Failed to add default input device listener: \(status, privacy: .public)")
        }
    }

    private func removeHardwareListener() {
        guard hardwareListenerInstalled else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard let hardwareListener else { return }
        let status = AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            queue,
            hardwareListener
        )
        if status != noErr {
            logger.error("Failed to remove default input device listener: \(status, privacy: .public)")
        }
        hardwareListenerInstalled = false
        self.hardwareListener = nil
    }

    private func updateCurrentDevice() {
        let previousDeviceID = currentDeviceID
        let newDeviceID = fetchDefaultInputDeviceID() ?? 0
        guard newDeviceID != 0 else {
            logger.error("Unable to resolve default input device.")
            removeDeviceListener()
            currentDeviceID = 0
            isDeviceActive = false
            return
        }

        if previousDeviceID != newDeviceID {
            removeDeviceListener()
            currentDeviceID = newDeviceID
            isDeviceActive = false
            installDeviceListener()
        }

        updateRunningState(for: newDeviceID)
    }

    private func installDeviceListener() {
        guard !deviceListenerInstalled else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            guard let self else { return }
            self.updateRunningState(for: self.currentDeviceID)
        }
        let status = AudioObjectAddPropertyListenerBlock(
            currentDeviceID,
            &address,
            queue,
            listener
        )
        if status == noErr {
            deviceListenerInstalled = true
            deviceListener = listener
        } else {
            logger.error("Failed to add mic running listener: \(status, privacy: .public)")
        }
    }

    private func removeDeviceListener() {
        guard deviceListenerInstalled, currentDeviceID != 0 else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard let deviceListener else { return }
        let status = AudioObjectRemovePropertyListenerBlock(
            currentDeviceID,
            &address,
            queue,
            deviceListener
        )
        if status != noErr {
            logger.error("Failed to remove mic running listener: \(status, privacy: .public)")
        }
        deviceListenerInstalled = false
        self.deviceListener = nil
    }

    private func updateRunningState(for deviceID: AudioDeviceID) {
        let running = isDeviceRunning(deviceID)
        if running {
            scheduleActivationCheck(for: deviceID)
        } else {
            pendingActivationWorkItem?.cancel()
            pendingActivationWorkItem = nil
            isDeviceActive = false
        }
    }

    private func scheduleActivationCheck(for deviceID: AudioDeviceID) {
        pendingActivationWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.currentDeviceID == deviceID else { return }
            guard self.isDeviceRunning(deviceID) else { return }
            guard !self.isDeviceActive else { return }
            self.isDeviceActive = true
            self.emitEvent(deviceID: deviceID)
        }
        pendingActivationWorkItem = workItem
        queue.asyncAfter(deadline: .now() + configuration.minimumActiveDuration, execute: workItem)
    }

    private func emitEvent(deviceID: AudioDeviceID) {
        let event = Event(
            deviceID: deviceID,
            deviceName: deviceName(for: deviceID),
            timestamp: Date()
        )
        continuation?.yield(event)
    }

    private func fetchDefaultInputDeviceID() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        if status != noErr {
            logger.error("Failed to query default input device: \(status, privacy: .public)")
            return nil
        }
        return deviceID
    }

    private func isDeviceRunning(_ deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &running)
        if status != noErr {
            logger.error("Failed to query mic running state: \(status, privacy: .public)")
            return false
        }
        return running != 0
    }

    private func deviceName(for deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &name)
        if status != noErr {
            logger.error("Failed to read mic device name: \(status, privacy: .public)")
            return nil
        }
        return name as String
    }
}
