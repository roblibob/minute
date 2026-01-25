import Foundation

public struct TranscriptSegment: Sendable, Equatable, Codable {
    public var startSeconds: Double
    public var endSeconds: Double
    public var text: String

    public init(startSeconds: Double, endSeconds: Double, text: String) {
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.text = text
    }
}

public struct SpeakerSegment: Sendable, Equatable, Codable {
    public var startSeconds: Double
    public var endSeconds: Double
    public var speakerId: Int

    public init(startSeconds: Double, endSeconds: Double, speakerId: Int) {
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.speakerId = speakerId
    }
}

public struct AttributedTranscriptSegment: Sendable, Equatable, Codable {
    public var startSeconds: Double
    public var endSeconds: Double
    public var speakerId: Int
    public var text: String

    public init(startSeconds: Double, endSeconds: Double, speakerId: Int, text: String) {
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.speakerId = speakerId
        self.text = text
    }
}

public struct TranscriptionResult: Sendable, Equatable, Codable {
    public var text: String
    public var segments: [TranscriptSegment]

    public init(text: String, segments: [TranscriptSegment]) {
        self.text = text
        self.segments = segments
    }
}
