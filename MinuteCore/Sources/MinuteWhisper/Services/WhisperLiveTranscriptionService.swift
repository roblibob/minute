import Foundation
import MinuteCore
import os
import whisper

public final class WhisperLiveTranscriptionService: LiveTranscriptionServicing, @unchecked Sendable {
    private let configuration: WhisperLibraryTranscriptionConfiguration
    private let logger = Logger(subsystem: "roblibob.Minute", category: "whisper-live")
    private let lock = NSLock()
    private var ctx: OpaquePointer?

    public init(configuration: WhisperLibraryTranscriptionConfiguration) {
        self.configuration = configuration
    }

    deinit {
        lock.lock()
        let ctx = ctx
        self.ctx = nil
        lock.unlock()
        if let ctx {
            whisper_free(ctx)
        }
    }

    public static func liveDefault() -> WhisperLiveTranscriptionService {
        WhisperLiveTranscriptionService(
            configuration: WhisperLibraryTranscriptionConfiguration(
                modelURL: WhisperModelPaths.defaultBaseModelURL,
                detectLanguage: true,
                language: "auto"
            )
        )
    }

    public func transcribe(samples: [Float]) async throws -> String {
        try Task.checkCancellation()
        guard !samples.isEmpty else { return "" }

        guard FileManager.default.fileExists(atPath: configuration.modelURL.path) else {
            throw MinuteError.modelMissing
        }

        let cancellationBox = LiveWhisperCancellationBox()

        return try await withTaskCancellationHandler {
            try Task.checkCancellation()

            let primary = try runWhisper(
                detectLanguage: configuration.detectLanguage,
                language: configuration.detectLanguage ? nil : configuration.language,
                samples: samples,
                cancellationBox: cancellationBox
            )
            if primary.text.isEmpty, configuration.detectLanguage {
                if let detected = primary.detectedLanguage {
                    return try runWhisper(
                        detectLanguage: false,
                        language: detected,
                        samples: samples,
                        cancellationBox: cancellationBox
                    ).text
                }
                if configuration.language != "auto" {
                    return try runWhisper(
                        detectLanguage: false,
                        language: configuration.language,
                        samples: samples,
                        cancellationBox: cancellationBox
                    ).text
                }
            }
            return primary.text
        } onCancel: {
            cancellationBox.cancel()
        }
    }

    private func runWhisper(
        detectLanguage: Bool,
        language: String?,
        samples: [Float],
        cancellationBox: LiveWhisperCancellationBox
    ) throws -> LiveWhisperResult {
        lock.lock()
        defer { lock.unlock() }
        let ctx = try ensureContextLocked()

        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.n_threads = Int32(configuration.threads)
        params.translate = false
        params.no_context = true
        params.no_timestamps = true
        params.single_segment = true
        params.no_speech_thold = 1.0
        params.logprob_thold = -1.0
        params.suppress_blank = false
        params.suppress_nst = false
        params.print_special = false
        params.print_progress = false
        params.print_realtime = false
        params.print_timestamps = false

        let normalized = (language ?? "en").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if detectLanguage {
            params.detect_language = true
            params.language = nil
        } else {
            params.detect_language = false
            let langID = whisper_lang_id(normalized)
            let fallbackID = whisper_lang_id("en")
            if langID >= 0, let langPtr = whisper_lang_str(langID) {
                params.language = langPtr
            } else if fallbackID >= 0, let langPtr = whisper_lang_str(fallbackID) {
                params.language = langPtr
            } else {
                params.language = nil
                params.detect_language = true
            }
        }

        params.abort_callback = minute_live_ggml_abort_callback
        params.abort_callback_user_data = Unmanaged.passUnretained(cancellationBox).toOpaque()

        let languageLabel = detectLanguage ? "auto" : normalized
        logger.info("Running whisper (live): model=\(self.configuration.modelURL.lastPathComponent, privacy: .public) detectLanguage=\(detectLanguage, privacy: .public) language=\(languageLabel, privacy: .public)")

        let rc: Int32 = samples.withUnsafeBufferPointer { buf in
            whisper_full(ctx, params, buf.baseAddress, Int32(buf.count))
        }

        if rc != 0 {
            if cancellationBox.isCancelled || Task.isCancelled {
                throw CancellationError()
            }
            throw MinuteError.whisperFailed(exitCode: rc, output: "whisper_full failed")
        }

        let nSegments = whisper_full_n_segments(ctx)
        var combined = ""
        combined.reserveCapacity(2048)
        for i in 0..<nSegments {
            if let cText = whisper_full_get_segment_text(ctx, i) {
                let rawText = String(cString: cText)
                let cleaned = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty {
                    combined.append(cleaned)
                }
            }
        }

        let detectedLanguage: String?
        if detectLanguage {
            let langID = whisper_full_lang_id(ctx)
            if langID >= 0, let langPtr = whisper_lang_str(langID) {
                detectedLanguage = String(cString: langPtr)
            } else {
                detectedLanguage = nil
            }
        } else {
            detectedLanguage = nil
        }

        return LiveWhisperResult(
            text: TranscriptNormalizer.normalizeWhisperOutput(combined),
            detectedLanguage: detectedLanguage
        )
    }

    private func ensureContextLocked() throws -> OpaquePointer {
        if let ctx {
            return ctx
        }

        var cparams = whisper_context_default_params()
        cparams.use_gpu = false
        cparams.flash_attn = false

        guard let ctx = whisper_init_from_file_with_params(configuration.modelURL.path, cparams) else {
            throw MinuteError.whisperMissing
        }

        self.ctx = ctx
        return ctx
    }
}

// MARK: - Cancellation bridging

private final class LiveWhisperCancellationBox: @unchecked Sendable {
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

private let minute_live_ggml_abort_callback: ggml_abort_callback = { userData in
    guard let userData else { return false }
    let box = Unmanaged<LiveWhisperCancellationBox>.fromOpaque(userData).takeUnretainedValue()
    return box.isCancelled
}

private struct LiveWhisperResult {
    let text: String
    let detectedLanguage: String?
}
