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

        let primary = try runWhisper(
            detectLanguage: configuration.detectLanguage,
            language: configuration.detectLanguage ? nil : configuration.language,
            samples: samples
        )
        if primary.isEmpty, configuration.detectLanguage {
            let fallbackLanguage = configuration.language == "auto" ? "en" : configuration.language
            return try runWhisper(detectLanguage: false, language: fallbackLanguage, samples: samples)
        }
        return primary
    }

    private func runWhisper(detectLanguage: Bool, language: String?, samples: [Float]) throws -> String {
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

        if detectLanguage {
            params.detect_language = true
            params.language = nil
        } else {
            params.detect_language = false
            let langCString = strdup(language ?? "en")
            defer { free(langCString) }
            if let langCString {
                params.language = UnsafePointer(langCString)
            }
        }

        let cancellationBox = LiveWhisperCancellationBox()
        params.abort_callback = minute_live_ggml_abort_callback
        params.abort_callback_user_data = Unmanaged.passUnretained(cancellationBox).toOpaque()

        let languageLabel = language ?? "auto"
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

        return TranscriptNormalizer.normalizeWhisperOutput(combined)
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
