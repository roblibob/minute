import Foundation
import os
import MinuteCore
import MinuteWhisper

@main
struct WhisperXPCMain {
    static func main() {
        let delegate = WhisperXPCServiceDelegate()
        let listener = NSXPCListener.service()
        listener.delegate = delegate
        listener.resume()
        RunLoop.current.run()
    }
}

final class WhisperXPCServiceDelegate: NSObject, NSXPCListenerDelegate {
    private let service = WhisperXPCService()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: WhisperXPCTranscriptionProtocol.self)
        newConnection.exportedObject = service
        newConnection.resume()
        return true
    }
}

final class WhisperXPCService: NSObject, WhisperXPCTranscriptionProtocol {
    private let worker = WhisperXPCWorker()
    private let liveWorker = WhisperXPCLiveWorker()
    private let encoder = JSONEncoder()

    func transcribe(
        wavPath: String,
        modelPath: String,
        detectLanguage: Bool,
        language: String,
        threads: Int,
        reply: @escaping (Data?, String?) -> Void
    ) {
        Task {
            do {
                let result = try await worker.transcribe(
                    wavPath: wavPath,
                    modelPath: modelPath,
                    detectLanguage: detectLanguage,
                    language: language,
                    threads: threads
                )
                let data = try encoder.encode(result)
                reply(data, nil)
            } catch {
                if let minuteError = error as? MinuteError {
                    reply(nil, minuteError.debugSummary)
                } else {
                    reply(nil, String(describing: error))
                }
            }
        }
    }

    func transcribeLive(
        samples: Data,
        sampleRateHz: Double,
        modelPath: String,
        detectLanguage: Bool,
        language: String,
        threads: Int,
        reply: @escaping (Data?, String?) -> Void
    ) {
        Task {
            do {
                let result = try await liveWorker.transcribe(
                    samples: samples,
                    sampleRateHz: sampleRateHz,
                    modelPath: modelPath,
                    detectLanguage: detectLanguage,
                    language: language,
                    threads: threads
                )
                let data = try encoder.encode(result)
                reply(data, nil)
            } catch {
                if let minuteError = error as? MinuteError {
                    reply(nil, minuteError.debugSummary)
                } else {
                    reply(nil, String(describing: error))
                }
            }
        }
    }
}

actor WhisperXPCWorker {
    func transcribe(
        wavPath: String,
        modelPath: String,
        detectLanguage: Bool,
        language: String,
        threads: Int
    ) async throws -> WhisperXPCTranscriptionResult {
        let service = WhisperLibraryTranscriptionService(
            configuration: WhisperLibraryTranscriptionConfiguration(
                modelURL: URL(fileURLWithPath: modelPath),
                detectLanguage: detectLanguage,
                language: language,
                threads: threads
            )
        )

        let result = try await service.transcribe(wavURL: URL(fileURLWithPath: wavPath))
        let segments = result.segments.map { segment in
            WhisperXPCSegment(
                startSeconds: segment.startSeconds,
                endSeconds: segment.endSeconds,
                text: segment.text
            )
        }
        return WhisperXPCTranscriptionResult(text: result.text, segments: segments)
    }
}

actor WhisperXPCLiveWorker {
    private var service: WhisperLiveTranscriptionService?
    private var config: WhisperLibraryTranscriptionConfiguration?
    private let logger = Logger(subsystem: "roblibob.Minute", category: "whisper-xpc-live")

    func transcribe(
        samples: Data,
        sampleRateHz: Double,
        modelPath: String,
        detectLanguage: Bool,
        language: String,
        threads: Int
    ) async throws -> WhisperXPCLiveTranscriptionResult {
        if abs(sampleRateHz - 16_000) > 0.1 {
            logger.info("Live samples not at 16kHz: \(sampleRateHz, privacy: .public)")
        }

        guard samples.count % MemoryLayout<Float>.size == 0 else {
            throw MinuteError.whisperFailed(exitCode: -1, output: "invalid live sample buffer size")
        }

        let config = WhisperLibraryTranscriptionConfiguration(
            modelURL: URL(fileURLWithPath: modelPath),
            detectLanguage: detectLanguage,
            language: language,
            threads: threads
        )

        let service = try ensureService(for: config)

        let floatCount = samples.count / MemoryLayout<Float>.size
        let floatSamples = samples.withUnsafeBytes { rawBuffer -> [Float] in
            let buffer = rawBuffer.bindMemory(to: Float.self)
            return Array(buffer.prefix(floatCount))
        }

        let text = try await service.transcribe(samples: floatSamples)

        return WhisperXPCLiveTranscriptionResult(text: text, detectedLanguage: nil)
    }

    private func ensureService(for config: WhisperLibraryTranscriptionConfiguration) throws -> WhisperLiveTranscriptionService {
        if let existing = service, self.config == config {
            return existing
        }

        let newService = WhisperLiveTranscriptionService(configuration: config)
        self.service = newService
        self.config = config
        return newService
    }
}
