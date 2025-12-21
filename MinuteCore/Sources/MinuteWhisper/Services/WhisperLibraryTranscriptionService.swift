import Foundation
import MinuteCore
import os
import whisper

public struct WhisperLibraryTranscriptionConfiguration: Sendable, Equatable {
    public var modelURL: URL

    /// Set to true for multilingual models (recommended). When true, Whisper will auto-detect language.
    public var detectLanguage: Bool

    /// Language hint when `detectLanguage` is false.
    public var language: String

    public var threads: Int

    public init(
        modelURL: URL,
        /// For v1 determinism, default to a fixed language.
        /// Set `detectLanguage = true` to enable Whisper's auto-detection.
        detectLanguage: Bool = false,
        language: String = "sv",
        threads: Int = 4
    ) {
        self.modelURL = modelURL
        self.detectLanguage = detectLanguage
        self.language = language
        self.threads = threads
    }
}

/// Transcription service backed by the precompiled whisper.cpp XCFramework.
///
/// Uses the whisper.cpp C API (see `whisper.h`) directly from Swift.
public struct WhisperLibraryTranscriptionService: TranscriptionServicing {
    private let configuration: WhisperLibraryTranscriptionConfiguration
    private let logger = Logger(subsystem: "roblibob.Minute", category: "whisper-lib")

    public init(configuration: WhisperLibraryTranscriptionConfiguration) {
        self.configuration = configuration
    }

    public static func liveDefault() -> WhisperLibraryTranscriptionService {
        // v1 default: multilingual model + auto language detection so we can transcribe both Swedish + English.
        WhisperLibraryTranscriptionService(
            configuration: WhisperLibraryTranscriptionConfiguration(
                modelURL: WhisperModelPaths.defaultBaseModelURL,
                detectLanguage: true,
                // Unused when `detectLanguage = true`, but keep a Swedish hint for easier debugging.
                language: "sv"
            )
        )
    }

    public func transcribe(wavURL: URL) async throws -> TranscriptionResult {
        // Validate model.
        guard FileManager.default.fileExists(atPath: configuration.modelURL.path) else {
            throw MinuteError.modelMissing
        }

        // Read contract WAV into float32 PCM @ 16kHz.
        let pcm = try ContractWavPCMReader.readPCM16Mono(at: wavURL)
        let samples = pcm.asFloat32()
        if samples.isEmpty {
            throw MinuteError.whisperFailed(exitCode: 0, output: "WAV contained 0 samples")
        }

        let stats = WhisperSampleStats(samples: samples, sampleRateHz: 16_000)
        logger.info(
            "WAV stats: duration=\(stats.durationSeconds, privacy: .public)s peak=\(stats.peak, privacy: .public) rms=\(stats.rms, privacy: .public)"
        )

        let cancellationBox = WhisperCancellationBox()

        return try await withTaskCancellationHandler {
            try Task.checkCancellation()

            func runWhisper(detectLanguage: Bool, language: String?) throws -> TranscriptionResult {
                // Context init.
                var cparams = whisper_context_default_params()
                // Determinism: prefer CPU path for v1.
                cparams.use_gpu = false
                cparams.flash_attn = false

                let ctx = whisper_init_from_file_with_params(configuration.modelURL.path, cparams)
                guard let ctx else {
                    throw MinuteError.whisperMissing
                }
                defer { whisper_free(ctx) }

                // Fixed decoding parameters.
                var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
                params.n_threads = Int32(configuration.threads)

                params.translate = false
                params.no_context = true
                params.no_timestamps = true

                // Make "no speech" gating as permissive as possible so we don't end up with an empty transcript
                // for quiet recordings. (Threshold is a probability in [0, 1].)
                params.no_speech_thold = 1.0

                // Disable additional gating based on average token log-probability.
                params.logprob_thold = -1.0

                // Reduce suppression to bias towards returning *something* over returning an empty transcript.
                params.suppress_blank = false
                params.suppress_nst = false

                params.print_special = false
                params.print_progress = false
                params.print_realtime = false
                params.print_timestamps = false

                // Language handling.
                if detectLanguage {
                    // For auto-detection, whisper accepts nullptr / "" / "auto".
                    params.detect_language = true
                    params.language = nil
                } else {
                    params.detect_language = false

                    // C string must stay alive for the duration of whisper_full.
                    let langCString = strdup(language ?? "en")
                    defer { free(langCString) }
                    if let langCString {
                        params.language = UnsafePointer(langCString)
                    }
                }

                // Cancellation via ggml abort callback.
                params.abort_callback = minute_ggml_abort_callback
                params.abort_callback_user_data = Unmanaged.passUnretained(cancellationBox).toOpaque()

                let languageLabel = language ?? "auto"
                logger.info("Running whisper (library): model=\(self.configuration.modelURL.lastPathComponent, privacy: .public) detectLanguage=\(detectLanguage, privacy: .public) language=\(languageLabel, privacy: .public)")

                let rc: Int32 = samples.withUnsafeBufferPointer { buf in
                    whisper_full(ctx, params, buf.baseAddress, Int32(buf.count))
                }

                if rc != 0 {
                    if cancellationBox.isCancelled || Task.isCancelled {
                        throw CancellationError()
                    }
                    throw MinuteError.whisperFailed(exitCode: rc, output: "whisper_full failed")
                }

                try Task.checkCancellation()

                // Collect text segments.
                let nSegments = whisper_full_n_segments(ctx)
                var combined = ""
                combined.reserveCapacity(4096)

                var segmentTexts: [String] = []
                segmentTexts.reserveCapacity(Int(nSegments))

                var transcriptSegments: [TranscriptSegment] = []
                transcriptSegments.reserveCapacity(Int(nSegments))

                for i in 0 ..< nSegments {
                    if let cText = whisper_full_get_segment_text(ctx, i) {
                        let rawText = String(cString: cText)
                        let cleaned = rawText.trimmingCharacters(in: .whitespacesAndNewlines)

                        let t0 = whisper_full_get_segment_t0(ctx, i)
                        let t1 = whisper_full_get_segment_t1(ctx, i)
                        let startSeconds = Double(t0) / 100.0
                        let endSeconds = Double(t1) / 100.0

                        if !cleaned.isEmpty {
                            segmentTexts.append(cleaned)
                            transcriptSegments.append(
                                TranscriptSegment(startSeconds: startSeconds, endSeconds: endSeconds, text: cleaned)
                            )
                            combined.append(cleaned)
                        }
                    }
                }

                WhisperDebugLogging.maybePrintSegmentsAsMarkdownTable(segmentTexts)
                WhisperDebugLogging.maybePrintTranscript(combined)

                let normalized = TranscriptNormalizer.normalizeWhisperOutput(combined)
                return TranscriptionResult(text: normalized, segments: transcriptSegments)
            }

            var result = try runWhisper(detectLanguage: configuration.detectLanguage, language: configuration.detectLanguage ? nil : configuration.language)
            if result.text.isEmpty, configuration.detectLanguage {
                // Retry with an explicit English hint for better results on English-only audio.
                result = try runWhisper(detectLanguage: false, language: "en")
            }

            if result.text.isEmpty {
                throw MinuteError.whisperFailed(
                    exitCode: 0,
                    output: "whisper returned empty transcript (duration=\(stats.durationSeconds)s peak=\(stats.peak) rms=\(stats.rms)). If you are speaking English, set language='en'; for Swedish, set language='sv' and disable auto-detect."
                )
            }

            return result
        } onCancel: {
            cancellationBox.cancel()
        }
    }
}

// MARK: - Cancellation bridging

final class WhisperCancellationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }
}

private let minute_ggml_abort_callback: ggml_abort_callback = { userData in
    guard let userData else { return false }
    let box = Unmanaged<WhisperCancellationBox>.fromOpaque(userData).takeUnretainedValue()
    return box.isCancelled
}

private enum WhisperDebugLogging {
    /// Off by default. Enable by setting env var: `MINUTE_DEBUG_WHISPER_SEGMENTS=1`.
    private static var shouldPrintSegments: Bool {
        ProcessInfo.processInfo.environment["MINUTE_DEBUG_WHISPER_SEGMENTS"] == "1"
    }

    /// Off by default. Enable by setting env var: `MINUTE_DEBUG_WHISPER_TRANSCRIPT=1`.
    private static var shouldPrintTranscript: Bool {
        ProcessInfo.processInfo.environment["MINUTE_DEBUG_WHISPER_TRANSCRIPT"] == "1"
    }

    static func maybePrintSegmentsAsMarkdownTable(_ segments: [String]) {
#if DEBUG
        guard shouldPrintSegments else { return }
        guard !segments.isEmpty else {
            print("\n[Minute] Whisper segments: <none>\n")
            return
        }

        print("\n[Minute] Whisper segments (markdown table)\n")
        print("| # | text |")
        print("|---:|------|")
        for (idx, s) in segments.enumerated() {
            let cleaned = s
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "|", with: "\\|")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            // Avoid megabytes of log spam: cap each cell.
            let capped = cleaned.count > 400 ? String(cleaned.prefix(400)) + "…" : cleaned
            print("| \(idx) | \(capped) |")
        }
        print("\n")
#endif
    }

    static func maybePrintTranscript(_ transcript: String) {
#if DEBUG
        guard shouldPrintTranscript else { return }
        print("\n[Minute] Whisper transcript BEGIN\n\n\(transcript)\n\n[Minute] Whisper transcript END\n")
#endif
    }
}

private struct WhisperSampleStats: Sendable {
    let sampleRateHz: Int
    let durationSeconds: Double
    let peak: Double
    let rms: Double

    init(samples: [Float], sampleRateHz: Int) {
        self.sampleRateHz = sampleRateHz
        self.durationSeconds = Double(samples.count) / Double(sampleRateHz)

        var peak: Double = 0
        var sumSquares: Double = 0

        for s in samples {
            let v = Double(s)
            peak = max(peak, abs(v))
            sumSquares += v * v
        }

        self.peak = peak
        self.rms = samples.isEmpty ? 0 : sqrt(sumSquares / Double(samples.count))
    }
}
