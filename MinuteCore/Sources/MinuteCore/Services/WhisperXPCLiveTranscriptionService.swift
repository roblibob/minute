import Foundation
import os

public struct WhisperXPCLiveTranscriptionConfiguration: Sendable, Equatable {
    public var serviceName: String
    public var modelURL: URL
    public var detectLanguage: Bool
    public var language: String
    public var threads: Int

    public init(
        serviceName: String,
        modelURL: URL,
        detectLanguage: Bool = true,
        language: String = "auto",
        threads: Int = 4
    ) {
        self.serviceName = serviceName
        self.modelURL = modelURL
        self.detectLanguage = detectLanguage
        self.language = language
        self.threads = threads
    }
}

public final class WhisperXPCLiveTranscriptionService: LiveTranscriptionServicing, @unchecked Sendable {
    private let configuration: WhisperXPCLiveTranscriptionConfiguration
    private let lock = NSLock()
    private var connection: NSXPCConnection
    private let modelURLProvider: () -> URL
    private let logger = Logger(subsystem: "roblibob.Minute", category: "whisper-xpc-live")
    private var isDisabled = false

    public init(
        configuration: WhisperXPCLiveTranscriptionConfiguration,
        modelURLProvider: (() -> URL)? = nil
    ) {
        self.configuration = configuration
        self.modelURLProvider = modelURLProvider ?? { configuration.modelURL }
        self.connection = Self.makeConnection(serviceName: configuration.serviceName)
        self.connection.interruptionHandler = { [weak self] in
            self?.disableService(reason: "XPC interrupted")
        }
        self.connection.invalidationHandler = { [weak self] in
            self?.disableService(reason: "XPC invalidated")
        }
    }

    deinit {
        connection.invalidate()
    }

    public static func liveDefault() -> WhisperXPCLiveTranscriptionService {
        let selectionStore = TranscriptionModelSelectionStore()
        let fallbackURL = selectionStore.selectedModel().destinationURL
        let modelURLProvider = {
            let selected = selectionStore.selectedModel().destinationURL
            return WhisperModelPaths.resolvedModelURL(fallback: selected)
        }
        return WhisperXPCLiveTranscriptionService(
            configuration: WhisperXPCLiveTranscriptionConfiguration(
                serviceName: "com.roblibob.Minute.WhisperService",
                modelURL: WhisperModelPaths.resolvedModelURL(fallback: fallbackURL),
                detectLanguage: true,
                language: "auto",
                threads: 4
            ),
            modelURLProvider: modelURLProvider
        )
    }

    public func transcribe(samples: [Float]) async throws -> String {
        try Task.checkCancellation()

        if samples.isEmpty {
            return ""
        }

        if isServiceDisabled() {
            return ""
        }

        let data = samples.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }

        return try await performTranscription(data: data, attempt: 0)
    }

    private func performTranscription(data: Data, attempt: Int) async throws -> String {
        do {
            return try await performTranscriptionOnce(data: data)
        } catch {
            if attempt == 0 {
                logger.info("Retrying live XPC transcription after failure: \(ErrorHandler.debugMessage(for: error), privacy: .public)")
                resetConnection()
                do {
                    return try await performTranscriptionOnce(data: data)
                } catch {
                    disableService(reason: "XPC live retry failed")
                    throw error
                }
            } else {
                disableService(reason: "XPC live failed")
                throw error
            }
        }
    }

    private func performTranscriptionOnce(data: Data) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let proxy = connectionSnapshot().remoteObjectProxyWithErrorHandler { error in
                self.logger.error("XPC error: \(ErrorHandler.debugMessage(for: error), privacy: .public)")
                continuation.resume(throwing: MinuteError.whisperFailed(exitCode: -1, output: error.localizedDescription))
            }

            guard let remote = proxy as? WhisperXPCTranscriptionProtocol else {
                continuation.resume(throwing: MinuteError.whisperMissing)
                return
            }

            let modelURL = modelURLProvider()

            remote.transcribeLive(
                samples: data,
                sampleRateHz: 16_000,
                modelPath: modelURL.path,
                detectLanguage: configuration.detectLanguage,
                language: configuration.language,
                threads: configuration.threads
            ) { responseData, errorMessage in
                if let errorMessage, !errorMessage.isEmpty {
                    continuation.resume(throwing: MinuteError.whisperFailed(exitCode: -1, output: errorMessage))
                    return
                }

                guard let responseData else {
                    continuation.resume(throwing: MinuteError.whisperFailed(exitCode: -1, output: "missing XPC response"))
                    return
                }

                do {
                    let decoded = try JSONDecoder().decode(WhisperXPCLiveTranscriptionResult.self, from: responseData)
                    continuation.resume(returning: decoded.text)
                } catch {
                    continuation.resume(throwing: MinuteError.whisperFailed(exitCode: -1, output: "failed to decode XPC response: \(error)"))
                }
            }
        }
    }

    private static func makeConnection(serviceName: String) -> NSXPCConnection {
        let connection = NSXPCConnection(serviceName: serviceName)
        connection.remoteObjectInterface = NSXPCInterface(with: WhisperXPCTranscriptionProtocol.self)
        connection.resume()
        return connection
    }

    private func connectionSnapshot() -> NSXPCConnection {
        lock.lock()
        let snapshot = connection
        lock.unlock()
        return snapshot
    }

    private func resetConnection() {
        lock.lock()
        let old = connection
        let newConnection = Self.makeConnection(serviceName: configuration.serviceName)
        newConnection.interruptionHandler = { [weak self] in
            self?.disableService(reason: "XPC interrupted")
        }
        newConnection.invalidationHandler = { [weak self] in
            self?.disableService(reason: "XPC invalidated")
        }
        connection = newConnection
        lock.unlock()
        old.invalidate()
    }

    private func disableService(reason: String) {
        lock.lock()
        let shouldLog = !isDisabled
        isDisabled = true
        lock.unlock()
        if shouldLog {
            logger.error("Disabling live XPC transcription: \(reason, privacy: .public)")
        }
    }

    private func isServiceDisabled() -> Bool {
        lock.lock()
        let value = isDisabled
        lock.unlock()
        return value
    }
}
