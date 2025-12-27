import Foundation
import os

public struct WhisperXPCTranscriptionConfiguration: Sendable, Equatable {
    public var serviceName: String
    public var modelURL: URL
    public var detectLanguage: Bool
    public var language: String
    public var threads: Int

    public init(
        serviceName: String,
        modelURL: URL,
        detectLanguage: Bool,
        language: String,
        threads: Int
    ) {
        self.serviceName = serviceName
        self.modelURL = modelURL
        self.detectLanguage = detectLanguage
        self.language = language
        self.threads = threads
    }
}

public final class WhisperXPCTranscriptionService: TranscriptionServicing, @unchecked Sendable {
    private let configuration: WhisperXPCTranscriptionConfiguration
    private let connection: NSXPCConnection
    private let logger = Logger(subsystem: "roblibob.Minute", category: "whisper-xpc")

    public init(configuration: WhisperXPCTranscriptionConfiguration) {
        self.configuration = configuration
        let connection = NSXPCConnection(serviceName: configuration.serviceName)
        connection.remoteObjectInterface = NSXPCInterface(with: WhisperXPCTranscriptionProtocol.self)
        connection.resume()
        self.connection = connection
    }

    deinit {
        connection.invalidate()
    }

    public static func liveDefault() -> WhisperXPCTranscriptionService {
        WhisperXPCTranscriptionService(
            configuration: WhisperXPCTranscriptionConfiguration(
                serviceName: "com.roblibob.Minute.WhisperService",
                modelURL: WhisperModelPaths.defaultBaseModelURL,
                detectLanguage: true,
                language: "auto",
                threads: 4
            )
        )
    }

    public func transcribe(wavURL: URL) async throws -> TranscriptionResult {
        return try await withCheckedThrowingContinuation { continuation in
            let lock = NSLock()
            var finished = false

            func finish(_ result: Result<TranscriptionResult, Error>) {
                lock.lock()
                defer { lock.unlock() }
                guard !finished else { return }
                finished = true
                switch result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            let proxy = connection.remoteObjectProxyWithErrorHandler { error in
                self.logger.error("XPC error: \(String(describing: error), privacy: .public)")
                finish(.failure(MinuteError.whisperFailed(exitCode: -1, output: error.localizedDescription)))
            }

            guard let remote = proxy as? WhisperXPCTranscriptionProtocol else {
                finish(.failure(MinuteError.whisperMissing))
                return
            }

            remote.transcribe(
                wavPath: wavURL.path,
                modelPath: configuration.modelURL.path,
                detectLanguage: configuration.detectLanguage,
                language: configuration.language,
                threads: configuration.threads
            ) { data, errorMessage in
                if let errorMessage, !errorMessage.isEmpty {
                    finish(.failure(MinuteError.whisperFailed(exitCode: -1, output: errorMessage)))
                    return
                }

                guard let data else {
                    finish(.failure(MinuteError.whisperFailed(exitCode: -1, output: "missing XPC response")))
                    return
                }

                do {
                    let decoded = try JSONDecoder().decode(WhisperXPCTranscriptionResult.self, from: data)
                    let segments = decoded.segments.map { segment in
                        TranscriptSegment(
                            startSeconds: segment.startSeconds,
                            endSeconds: segment.endSeconds,
                            text: segment.text
                        )
                    }
                    finish(.success(TranscriptionResult(text: decoded.text, segments: segments)))
                } catch {
                    finish(.failure(MinuteError.whisperFailed(exitCode: -1, output: "failed to decode XPC response: \(error)")))
                }
            }
        }
    }
}
