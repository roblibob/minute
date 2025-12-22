@preconcurrency import AVFoundation
import Foundation
import os

/// Captures microphone audio into a temporary file, then exports a deterministic contract WAV.
///
/// This implementation uses an AudioToolbox `ExtAudioFile` conversion step for deterministic output.
/// Task 09 may introduce an `ffmpeg`-backed conversion path.
public actor DefaultAudioService: AudioServicing, AudioLevelMetering {
    private let logger = Logger(subsystem: "roblibob.Minute", category: "audio")
    private let levelMixer = AudioLevelMixer()

    private var engine: AVAudioEngine?
    private var tapWriter: AudioTapWriter?
    private var systemCapture: SystemAudioCapture?
    private var sessionDirectoryURL: URL?
    private var captureURL: URL?
    private var systemCaptureURL: URL?

    public init() {}

    public func setLevelHandler(_ handler: (@Sendable (Float) -> Void)?) async {
        levelMixer.setHandler(handler)
    }

    private struct CaptureComponents: @unchecked Sendable {
        let engine: AVAudioEngine
        let tapWriter: AudioTapWriter
        let format: AVAudioFormat
    }

    public func startRecording() async throws {
        // Prevent double-start.
        guard engine == nil else { return }

        let sessionDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("minute-capture-\(UUID().uuidString)", isDirectory: true)

        try FileManager.default.createDirectory(at: sessionDirectoryURL, withIntermediateDirectories: true)

        let captureURL = sessionDirectoryURL.appendingPathComponent("capture.caf")
        let systemCaptureURL = sessionDirectoryURL.appendingPathComponent("system.caf")

        let logger = logger

        // Capture with AVAudioEngine tap to avoid silent recordings on macOS.
        let levelMixer = levelMixer

        let components: CaptureComponents = try await MainActor.run {
            let engine = AVAudioEngine()
            let inputNode = engine.inputNode
            let format = inputNode.inputFormat(forBus: 0)
            let file = try AVAudioFile(forWriting: captureURL, settings: format.settings)
            let tapWriter = AudioTapWriter(file: file, logger: logger)

            inputNode.installTap(onBus: 0, bufferSize: 4_096, format: format) { @Sendable [tapWriter] buffer, _ in
                tapWriter.write(buffer)
                levelMixer.updateMic(Self.level(for: buffer))
            }

            engine.prepare()
            try engine.start()

            return CaptureComponents(engine: engine, tapWriter: tapWriter, format: format)
        }

        let engine = components.engine
        let tapWriter = components.tapWriter
        let captureFormat = components.format

        let systemCapture: SystemAudioCapture
        do {
            systemCapture = try await SystemAudioCapture.start(
                outputURL: systemCaptureURL,
                logger: logger,
                levelHandler: { level in
                    levelMixer.updateSystem(level)
                }
            )
        } catch {
            await MainActor.run {
                engine.inputNode.removeTap(onBus: 0)
                engine.stop()
            }
            throw error
        }

        self.sessionDirectoryURL = sessionDirectoryURL
        self.captureURL = captureURL
        self.systemCaptureURL = systemCaptureURL
        self.engine = engine
        self.tapWriter = tapWriter
        self.systemCapture = systemCapture

        logger.info("Recording started: \(captureURL.path, privacy: .public) format=\(captureFormat.sampleRate)Hz")
    }

    public func stopRecording() async throws -> AudioCaptureResult {
        try Task.checkCancellation()

        guard let engine else {
            throw MinuteError.audioExportFailed
        }

        await MainActor.run {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        self.engine = nil

        guard let sessionDirectoryURL, let captureURL else {
            throw MinuteError.audioExportFailed
        }

        let systemCapture = systemCapture
        self.systemCapture = nil
        if let systemCapture {
            try await systemCapture.stop()
        }

        let writerError = tapWriter?.takeError()
        self.tapWriter = nil
        if writerError != nil {
            throw MinuteError.audioExportFailed
        }

        logger.info("Recording stopped: \(captureURL.path, privacy: .public)")

        // Export to contract wav in the same session dir.
        let wavURL = sessionDirectoryURL.appendingPathComponent("contract.wav")

        do {
            let systemCaptureURL = systemCaptureURL
            self.systemCaptureURL = nil
            if let systemCaptureURL {
                try await AudioWavMixer.mixToContractWav(micURL: captureURL, systemURL: systemCaptureURL, outputURL: wavURL)
            } else {
                try await convertToContractWav(inputURL: captureURL, outputURL: wavURL)
            }
            try ContractWavVerifier.verifyContractWav(at: wavURL)
            let duration = try ContractWavVerifier.durationSeconds(ofContractWavAt: wavURL)

            logger.info("Contract WAV ready: \(wavURL.path, privacy: .public) duration=\(duration)")

            // Leave the session dir in temp; pipeline will reference wavURL.
            return AudioCaptureResult(wavURL: wavURL, duration: duration)
        } catch is CancellationError {
            // Best-effort cleanup.
            try? FileManager.default.removeItem(at: sessionDirectoryURL)
            throw CancellationError()
        } catch {
            logger.error("Audio export failed: \(String(describing: error), privacy: .public)")
            throw MinuteError.audioExportFailed
        }
    }

    public func convertToContractWav(inputURL: URL, outputURL: URL) async throws {
        try await AudioWavConverter.convertToContractWav(inputURL: inputURL, outputURL: outputURL)
    }

    private static func level(for buffer: AVAudioPCMBuffer) -> Float {
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return 0 }

        if let channelData = buffer.floatChannelData {
            let channel = channelData[0]
            var sum: Float = 0
            for index in 0..<frameLength {
                let sample = channel[index]
                sum += sample * sample
            }

            let rms = sqrt(sum / Float(frameLength))
            return min(max(rms * 4, 0), 1)
        }

        if let channelData = buffer.int16ChannelData {
            let channel = channelData[0]
            let scale = 1.0 / Float(Int16.max)
            var sum: Float = 0
            for index in 0..<frameLength {
                let sample = Float(channel[index]) * scale
                sum += sample * sample
            }

            let rms = sqrt(sum / Float(frameLength))
            return min(max(rms * 4, 0), 1)
        }

        return 0
    }
}

private final class AudioTapWriter: @unchecked Sendable {
    private let file: AVAudioFile
    private let logger: Logger
    private let lock = NSLock()
    private var writeError: Error?

    init(file: AVAudioFile, logger: Logger) {
        self.file = file
        self.logger = logger
    }

    func write(_ buffer: AVAudioPCMBuffer) {
        do {
            try file.write(from: buffer)
        } catch {
            lock.lock()
            let shouldLog = (writeError == nil)
            if shouldLog {
                writeError = error
            }
            lock.unlock()
            if shouldLog {
                logger.error("Audio tap write failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    func takeError() -> Error? {
        lock.lock()
        defer { lock.unlock() }
        return writeError
    }
}

private final class AudioLevelMixer: @unchecked Sendable {
    private let lock = NSLock()
    private var handler: (@Sendable (Float) -> Void)?
    private var micLevel: Float = 0
    private var systemLevel: Float = 0

    func setHandler(_ handler: (@Sendable (Float) -> Void)?) {
        lock.lock()
        self.handler = handler
        lock.unlock()
    }

    func updateMic(_ level: Float) {
        update(mic: level, system: nil)
    }

    func updateSystem(_ level: Float) {
        update(mic: nil, system: level)
    }

    private func update(mic: Float?, system: Float?) {
        lock.lock()
        if let mic {
            micLevel = mic
        }
        if let system {
            systemLevel = system
        }
        let combined = min(max(micLevel + systemLevel, 0), 1)
        let handler = handler
        lock.unlock()
        handler?(combined)
    }
}
