import Foundation
import os

struct RecordingSessionMarker: Codable, Sendable, Equatable {
    let formatVersion: Int
    let startedAt: Date
    let microphoneEnabled: Bool
    let systemAudioEnabled: Bool

    init(
        formatVersion: Int = 1,
        startedAt: Date,
        microphoneEnabled: Bool,
        systemAudioEnabled: Bool
    ) {
        self.formatVersion = formatVersion
        self.startedAt = startedAt
        self.microphoneEnabled = microphoneEnabled
        self.systemAudioEnabled = systemAudioEnabled
    }
}

enum RecordingSessionMarkerStore {
    static let fileName = "minute-session.json"

    static func markerURL(for sessionURL: URL) -> URL {
        sessionURL.appendingPathComponent(fileName)
    }

    static func write(_ marker: RecordingSessionMarker, to sessionURL: URL) throws {
        let data = try JSONEncoder().encode(marker)
        try data.write(to: markerURL(for: sessionURL), options: [.atomic])
    }

    static func read(from sessionURL: URL) -> RecordingSessionMarker? {
        let url = markerURL(for: sessionURL)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(RecordingSessionMarker.self, from: data)
        } catch {
            return nil
        }
    }
}

public actor DefaultRecordingRecoveryService: RecordingRecoveryServicing {
    private let logger = Logger(subsystem: "roblibob.Minute", category: "recovery")
    private let fileManager = FileManager.default

    public init() {}

    public func findRecoverableRecordings() async -> [RecoverableRecording] {
        let tempRoot = fileManager.temporaryDirectory
        guard let contents = try? fileManager.contentsOfDirectory(
            at: tempRoot,
            includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var results: [RecoverableRecording] = []

        for url in contents {
            if Task.isCancelled { return results }
            guard url.lastPathComponent.hasPrefix("minute-capture-") else { continue }
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { continue }

            let captureURL = url.appendingPathComponent("capture.caf")
            let systemURL = url.appendingPathComponent("system.caf")
            let contractURL = url.appendingPathComponent("contract.wav")

            let hasCapture = fileManager.fileExists(atPath: captureURL.path)
            let hasContract = fileManager.fileExists(atPath: contractURL.path)
            guard hasCapture || hasContract else { continue }

            let marker = RecordingSessionMarkerStore.read(from: url)
            let startedAt = resolveStartDate(
                sessionURL: url,
                marker: marker,
                captureURL: hasCapture ? captureURL : nil,
                contractURL: hasContract ? contractURL : nil
            )

            results.append(
                RecoverableRecording(
                    id: url.lastPathComponent,
                    sessionURL: url,
                    startedAt: startedAt,
                    captureURL: hasCapture ? captureURL : nil,
                    systemCaptureURL: fileManager.fileExists(atPath: systemURL.path) ? systemURL : nil,
                    contractWavURL: hasContract ? contractURL : nil,
                    microphoneEnabled: marker?.microphoneEnabled,
                    systemAudioEnabled: marker?.systemAudioEnabled
                )
            )
        }

        return results.sorted { $0.startedAt > $1.startedAt }
    }

    public func recover(recording: RecoverableRecording) async throws -> RecordingRecoveryResult {
        try Task.checkCancellation()

        let sessionURL = recording.sessionURL
        let captureURL = recording.captureURL ?? sessionURL.appendingPathComponent("capture.caf")
        let systemURL = sessionURL.appendingPathComponent("system.caf")
        let contractURL = sessionURL.appendingPathComponent("contract.wav")

        let hasCapture = fileManager.fileExists(atPath: captureURL.path)
        let hasSystem = fileManager.fileExists(atPath: systemURL.path)
        let hasContract = fileManager.fileExists(atPath: contractURL.path)

        if hasContract {
            if (try? ContractWavVerifier.verifyContractWav(at: contractURL)) == nil {
                logger.info("Existing contract WAV invalid; re-exporting.")
            } else {
                let duration = try ContractWavVerifier.durationSeconds(ofContractWavAt: contractURL)
                let startedAt = recording.startedAt
                let stoppedAt = startedAt.addingTimeInterval(duration)
                return RecordingRecoveryResult(
                    wavURL: contractURL,
                    duration: duration,
                    startedAt: startedAt,
                    stoppedAt: stoppedAt
                )
            }
        }

        guard hasCapture else {
            throw MinuteError.audioExportFailed
        }

        do {
            if hasSystem {
                try await AudioWavMixer.mixToContractWav(micURL: captureURL, systemURL: systemURL, outputURL: contractURL)
            } else {
                try await AudioWavConverter.convertToContractWav(inputURL: captureURL, outputURL: contractURL)
            }

            try ContractWavVerifier.verifyContractWav(at: contractURL)
            let duration = try ContractWavVerifier.durationSeconds(ofContractWavAt: contractURL)
            let startedAt = recording.startedAt
            let stoppedAt = startedAt.addingTimeInterval(duration)
            return RecordingRecoveryResult(
                wavURL: contractURL,
                duration: duration,
                startedAt: startedAt,
                stoppedAt: stoppedAt
            )
        } catch {
            logger.error("Recovery export failed: \(ErrorHandler.debugMessage(for: error), privacy: .public)")
            throw MinuteError.audioExportFailed
        }
    }

    public func discard(recording: RecoverableRecording) async {
        let tempRootURL = fileManager.temporaryDirectory.standardizedFileURL
        let tempRootPath = tempRootURL.path.hasSuffix("/") ? tempRootURL.path : tempRootURL.path + "/"
        let sessionPath = recording.sessionURL.standardizedFileURL.path
        guard sessionPath.hasPrefix(tempRootPath) else { return }
        try? fileManager.removeItem(at: recording.sessionURL)
    }
}

private func resolveStartDate(
    sessionURL: URL,
    marker: RecordingSessionMarker?,
    captureURL: URL?,
    contractURL: URL?
) -> Date {
    if let marker {
        return marker.startedAt
    }

    if let captureURL,
       let date = try? captureURL.resourceValues(forKeys: [.creationDateKey]).creationDate {
        return date
    }

    if let contractURL,
       let date = try? contractURL.resourceValues(forKeys: [.creationDateKey]).creationDate {
        return date
    }

    if let date = try? sessionURL.resourceValues(forKeys: [.creationDateKey]).creationDate {
        return date
    }

    return Date()
}
