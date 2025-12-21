import Foundation
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
