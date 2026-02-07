import Foundation

/// Abstraction for offline diarization to enable deterministic testing without depending on FluidAudio types.
public protocol OfflineDiarizerManaging: Sendable {
    /// Ensures required diarization models are present and ready.
    func prepareModels() async throws

    /// Runs offline diarization and returns MinuteCore speaker segments.
    func diarize(wavURL: URL, embeddingExportURL: URL?) async throws -> [SpeakerSegment]
}
