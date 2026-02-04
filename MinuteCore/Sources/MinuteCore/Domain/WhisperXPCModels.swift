import Foundation

@objc public protocol WhisperXPCTranscriptionProtocol: NSObjectProtocol {
    func transcribe(
        wavPath: String,
        modelPath: String,
        detectLanguage: Bool,
        language: String,
        threads: Int,
        reply: @escaping (Data?, String?) -> Void
    )
}

public struct WhisperXPCSegment: Codable, Sendable, Equatable {
    public var startSeconds: Double
    public var endSeconds: Double
    public var text: String

    public init(startSeconds: Double, endSeconds: Double, text: String) {
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.text = text
    }
}

public struct WhisperXPCTranscriptionResult: Codable, Sendable, Equatable {
    public var text: String
    public var segments: [WhisperXPCSegment]

    public init(text: String, segments: [WhisperXPCSegment]) {
        self.text = text
        self.segments = segments
    }
}
