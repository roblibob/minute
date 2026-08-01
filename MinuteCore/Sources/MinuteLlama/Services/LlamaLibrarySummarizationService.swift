private import llama
import Foundation
import MinuteCore
import os

public struct LlamaLibrarySummarizationConfiguration: Sendable, Equatable {
    public var modelURL: URL
    public var temperature: Double
    public var topP: Double?
    public var topK: Int?
    public var seed: UInt32?
    public var maxTokens: Int
    public var contextSize: Int?
    public var threads: Int?
    public var threadsBatch: Int?

    public init(
        modelURL: URL,
        temperature: Double = 0.2,
        topP: Double? = 0.9,
        topK: Int? = 40,
        seed: UInt32? = 42,
        maxTokens: Int = 1024,
        contextSize: Int? = 8192,
        threads: Int? = nil,
        threadsBatch: Int? = nil
    ) {
        self.modelURL = modelURL
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.seed = seed
        self.maxTokens = maxTokens
        self.contextSize = contextSize
        self.threads = threads
        self.threadsBatch = threadsBatch
    }
}

/// Summarization + schema extraction using a local llama.cpp XCFramework.
public struct LlamaLibrarySummarizationService: RuntimeAwareSummarizationServicing {
    private static let transcriptMarker = "__MINUTE_TRANSCRIPT_MARKER__"

    private let configuration: LlamaLibrarySummarizationConfiguration
    private let logger = Logger(subsystem: "roblibob.Minute", category: "llama-lib")
    private let loadedModelStore: LoadedLlamaModelStore

    public init(configuration: LlamaLibrarySummarizationConfiguration) {
        self.configuration = configuration
        self.loadedModelStore = LoadedLlamaModelStore(configuration: configuration)
    }

    public static func liveDefault(
        selectionStore: SummarizationModelSelectionStore = SummarizationModelSelectionStore(),
        contextWindowStore: SummarizationContextWindowSelectionStore = SummarizationContextWindowSelectionStore(),
        hardwareProfile: SummarizationHardwareProfile = .current()
    ) -> LlamaLibrarySummarizationService {
        let model = selectionStore.selectedModel()
        return LlamaLibrarySummarizationService(
            configuration: LlamaLibrarySummarizationConfiguration(
                modelURL: model.destinationURL,
                contextSize: contextWindowStore.requestedContextTokens(hardwareProfile: hardwareProfile)
            )
        )
    }

    public func summarize(
        transcript: String,
        meetingDate: Date,
        meetingType: MeetingType,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage
    ) async throws -> String {
        try await summarize(
            transcript: transcript,
            meetingDate: meetingDate,
            meetingType: meetingType,
            languageProcessing: languageProcessing,
            outputLanguage: outputLanguage,
            resolvedPromptBundle: nil
        )
    }

    public func summarize(
        transcript: String,
        meetingDate: Date,
        meetingType: MeetingType,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage,
        resolvedPromptBundle: ResolvedPromptBundle?
    ) async throws -> String {
        let prompts = resolvedPrompts(
            meetingType: meetingType,
            languageProcessing: languageProcessing,
            outputLanguage: outputLanguage,
            resolvedPromptBundle: resolvedPromptBundle
        )
        let loadedModel = try await loadedModelStore.load()

        logger.info(
            "Summarization system prompt [meetingType=\(meetingType.rawValue, privacy: .public), languageProcessing=\(languageProcessing.rawValue, privacy: .public), outputLanguage=\(outputLanguage.rawValue, privacy: .public), length=\(prompts.systemPrompt.count, privacy: .public), hash=\(prompts.systemPrompt, privacy: .private(mask: .hash))]"
        )

        return try await runLlama(
            systemPrompt: prompts.systemPrompt,
            userPrompt: PromptFactory.userPrompt(
                transcript: datedTranscript(transcript, meetingDate: meetingDate),
                preamble: prompts.userPromptPreamble
            ),
            configuration: configuration,
            loadedModel: loadedModel
        )
    }

    public func makeRuntimePassPlan(
        transcript: String,
        meetingDate: Date,
        meetingType: MeetingType,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage,
        resolvedPromptBundle: ResolvedPromptBundle?
    ) async throws -> SummarizationRuntimePassPlan {
        let prompts = resolvedPrompts(
            meetingType: meetingType,
            languageProcessing: languageProcessing,
            outputLanguage: outputLanguage,
            resolvedPromptBundle: resolvedPromptBundle
        )
        let loadedModel = try await loadedModelStore.load()
        let datedTranscript = datedTranscript(transcript, meetingDate: meetingDate)
        let contextWindowTokens = loadedModel.contextWindowTokens(requested: configuration.contextSize ?? 8192)
        let summaryPlaceholder = placeholderSummaryJSON(
            targetTokens: configuration.maxTokens,
            vocab: loadedModel.vocab
        )
        let promptOverheadTokens = max(
            promptOverheadTokens(
                systemPrompt: passDeltaSystemPrompt(baseSystemPrompt: prompts.systemPrompt),
                userPrompt: passDeltaUserPrompt(
                    preamble: prompts.userPromptPreamble,
                    previousSummaryJSON: nil,
                    transcriptChunk: Self.transcriptMarker,
                    passIndex: 1,
                    totalPasses: 1
                ),
                transcriptMarker: Self.transcriptMarker,
                vocab: loadedModel.vocab,
                model: loadedModel.model
            ),
            promptOverheadTokens(
                systemPrompt: passDeltaSystemPrompt(baseSystemPrompt: prompts.systemPrompt),
                userPrompt: passDeltaUserPrompt(
                    preamble: prompts.userPromptPreamble,
                    previousSummaryJSON: summaryPlaceholder,
                    transcriptChunk: Self.transcriptMarker,
                    passIndex: 2,
                    totalPasses: 2
                ),
                transcriptMarker: Self.transcriptMarker,
                vocab: loadedModel.vocab,
                model: loadedModel.model
            )
        )
        let estimate = SummarizationPassPlanner.estimate(
            transcript: datedTranscript,
            contextWindowTokens: contextWindowTokens,
            reservedOutputTokens: configuration.maxTokens,
            safetyMarginTokens: 256,
            promptOverheadTokens: promptOverheadTokens,
            tokenEstimator: { tokenCount(for: $0, vocab: loadedModel.vocab) }
        )
        let chunks = SummarizationPassPlanner.chunkTranscript(
            datedTranscript,
            availableInputTokensPerPass: estimate.availableInputTokensPerPass,
            tokenEstimator: { tokenCount(for: $0, vocab: loadedModel.vocab) }
        )
        let runtimeChunks = chunks.map {
            SummarizationRuntimeChunk(
                transcript: $0,
                tokenCount: max(1, tokenCount(for: $0, vocab: loadedModel.vocab))
            )
        }

        logger.info(
            "Summarization runtime plan [estimatedTokens=\(estimate.estimatedTotalInputTokens, privacy: .public), availablePerPass=\(estimate.availableInputTokensPerPass, privacy: .public), passCount=\(runtimeChunks.count, privacy: .public)]"
        )

        return SummarizationRuntimePassPlan(
            contextWindowTokens: estimate.contextWindowTokens,
            reservedOutputTokens: estimate.reservedOutputTokens,
            safetyMarginTokens: estimate.safetyMarginTokens,
            promptOverheadTokens: estimate.promptOverheadTokens,
            availableInputTokensPerPass: estimate.availableInputTokensPerPass,
            estimatedTotalInputTokens: estimate.estimatedTotalInputTokens,
            chunks: runtimeChunks
        )
    }

    public func summarizePass(
        transcriptChunk: String,
        previousSummaryJSON: String?,
        passIndex: Int,
        totalPasses: Int,
        meetingDate: Date,
        meetingType: MeetingType,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage,
        resolvedPromptBundle: ResolvedPromptBundle?
    ) async throws -> String {
        let prompts = resolvedPrompts(
            meetingType: meetingType,
            languageProcessing: languageProcessing,
            outputLanguage: outputLanguage,
            resolvedPromptBundle: resolvedPromptBundle
        )
        let loadedModel = try await loadedModelStore.load()
        let transcriptChunk = datedTranscript(transcriptChunk, meetingDate: meetingDate)
        let userPrompt = passDeltaUserPrompt(
            preamble: prompts.userPromptPreamble,
            previousSummaryJSON: previousSummaryJSON,
            transcriptChunk: transcriptChunk,
            passIndex: passIndex,
            totalPasses: totalPasses
        )

        return try await runLlama(
            systemPrompt: passDeltaSystemPrompt(baseSystemPrompt: prompts.systemPrompt),
            userPrompt: userPrompt,
            configuration: configuration,
            loadedModel: loadedModel
        )
    }

    public func classify(transcript: String) async throws -> MeetingType {
        let prompt = MeetingTypeClassifier.prompt(for: transcript)
        let response = try await runLlama(
            systemPrompt: nil,
            userPrompt: prompt,
            configuration: classifyConfiguration(),
            loadedModel: try await loadedModelStore.load()
        )
        return MeetingTypeClassifier.parseResponse(response)
    }

    public func classify(
        transcript: String,
        candidates: [MeetingTypeClassifierCandidate],
        fallbackTypeID: String
    ) async throws -> String {
        let prompt = MeetingTypeClassifier.prompt(
            for: transcript,
            candidates: candidates,
            fallbackLabel: candidates.first(where: { $0.typeId == fallbackTypeID })?.label ?? "General"
        )
        let response = try await runLlama(
            systemPrompt: nil,
            userPrompt: prompt,
            configuration: classifyConfiguration(),
            loadedModel: try await loadedModelStore.load()
        )
        return MeetingTypeClassifier.parseResponse(
            response,
            candidates: candidates,
            fallbackTypeID: fallbackTypeID
        )
    }

    public func repairJSON(_ invalidJSON: String) async throws -> String {
        try await runLlama(
            systemPrompt: nil,
            userPrompt: PromptBuilder.repairPrompt(invalidOutput: invalidJSON),
            configuration: configuration,
            loadedModel: try await loadedModelStore.load()
        )
    }

    private func classifyConfiguration() -> LlamaLibrarySummarizationConfiguration {
        var classifyConfiguration = configuration
        classifyConfiguration.temperature = 0.0
        classifyConfiguration.topP = nil
        classifyConfiguration.topK = nil
        classifyConfiguration.seed = nil
        classifyConfiguration.maxTokens = 16
        return classifyConfiguration
    }

    private func resolvedPrompts(
        meetingType: MeetingType,
        languageProcessing: LanguageProcessingProfile,
        outputLanguage: OutputLanguage,
        resolvedPromptBundle: ResolvedPromptBundle?
    ) -> (systemPrompt: String, userPromptPreamble: String) {
        if let resolvedPromptBundle {
            return (
                systemPrompt: resolvedPromptBundle.systemPrompt,
                userPromptPreamble: resolvedPromptBundle.userPromptPreamble
            )
        }

        let strategy = PromptFactory.strategy(for: meetingType)
        return (
            systemPrompt: PromptFactory.systemPrompt(
                strategy: strategy,
                languageProcessing: languageProcessing,
                outputLanguage: outputLanguage
            ),
            userPromptPreamble: PromptFactory.userPromptPreamble(
                strategy: strategy,
                languageProcessing: languageProcessing,
                outputLanguage: outputLanguage
            )
        )
    }

    private func datedTranscript(_ transcript: String, meetingDate: Date) -> String {
        "Meeting Date: \(MinuteISODate.format(meetingDate))\n\n\(transcript)"
    }

    private func runLlama(
        systemPrompt: String?,
        userPrompt: String,
        configuration: LlamaLibrarySummarizationConfiguration,
        loadedModel: LoadedLlamaModelHandle
    ) async throws -> String {
        try Task.checkCancellation()

        let formattedPrompt = formatPrompt(systemPrompt: systemPrompt, userPrompt: userPrompt, model: loadedModel.model)
        var promptTokens = tokenize(formattedPrompt, vocab: loadedModel.vocab)
        guard !promptTokens.isEmpty else {
            throw MinuteError.llamaFailed(exitCode: -1, output: "Prompt tokenization failed")
        }

        let nCtx = loadedModel.contextWindowTokens(requested: configuration.contextSize ?? 8192)
        let nBatch = min(512, nCtx)
        let maxPromptTokens = max(1, nCtx - max(configuration.maxTokens, 32) - 8)
        if promptTokens.count > maxPromptTokens {
            logger.error(
                "Prompt exceeds context budget; truncating [promptTokens=\(promptTokens.count, privacy: .public), maxPromptTokens=\(maxPromptTokens, privacy: .public)]"
            )
            promptTokens = Array(promptTokens.prefix(maxPromptTokens))
        }

        var ctxParams = llama_context_default_params()
        ctxParams.n_ctx = UInt32(nCtx)
        ctxParams.n_batch = UInt32(nBatch)
        ctxParams.n_seq_max = 1
        if loadedModel.shouldUseGPUOffload {
            ctxParams.flash_attn_type = LLAMA_FLASH_ATTN_TYPE_ENABLED
            ctxParams.offload_kqv = true
            ctxParams.op_offload = true
        }

        guard let ctx = llama_init_from_model(loadedModel.model, ctxParams) else {
            throw MinuteError.llamaFailed(exitCode: -1, output: "Failed to init llama context")
        }
        defer { llama_free(ctx) }

        if let threads = configuration.threads {
            let batchThreads = configuration.threadsBatch ?? threads
            llama_set_n_threads(ctx, Int32(threads), Int32(batchThreads))
        }

        var tokenIndex = 0
        while tokenIndex < promptTokens.count {
            let endIndex = min(tokenIndex + nBatch, promptTokens.count)
            let chunk = Array(promptTokens[tokenIndex..<endIndex])
            var mutableChunk = chunk
            let decodeRC = mutableChunk.withUnsafeMutableBufferPointer { buffer -> Int32 in
                let batch = llama_batch_get_one(buffer.baseAddress, Int32(chunk.count))
                return llama_decode(ctx, batch)
            }
            if decodeRC != 0 {
                throw MinuteError.llamaFailed(exitCode: decodeRC, output: "llama_decode(prompt-chunk) failed")
            }
            tokenIndex = endIndex
        }

        let sampler = try makeSampler(configuration: configuration)
        defer { llama_sampler_free(sampler) }

        let eosToken = llama_vocab_eos(loadedModel.vocab)
        var output = ""
        output.reserveCapacity(4096)

        for _ in 0..<configuration.maxTokens {
            try Task.checkCancellation()

            let token = llama_sampler_sample(sampler, ctx, -1)
            if token == eosToken {
                break
            }

            output.append(tokenToString(token, vocab: loadedModel.vocab))

            var nextToken = token
            let batch = llama_batch_get_one(&nextToken, 1)
            let rc = llama_decode(ctx, batch)
            if rc != 0 {
                throw MinuteError.llamaFailed(exitCode: rc, output: "llama_decode(next) failed")
            }
        }

        logger.info("Llama output length: \(output.count, privacy: .public)")
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func makeSampler(configuration: LlamaLibrarySummarizationConfiguration) throws -> UnsafeMutablePointer<llama_sampler> {
        let params = llama_sampler_chain_default_params()
        guard let chain = llama_sampler_chain_init(params) else {
            throw MinuteError.llamaFailed(exitCode: -1, output: "Failed to init llama sampler")
        }

        if let topK = configuration.topK {
            llama_sampler_chain_add(chain, llama_sampler_init_top_k(Int32(topK)))
        }

        if let topP = configuration.topP {
            llama_sampler_chain_add(chain, llama_sampler_init_top_p(Float(topP), 1))
        }

        llama_sampler_chain_add(chain, llama_sampler_init_temp(Float(configuration.temperature)))

        if let seed = configuration.seed {
            llama_sampler_chain_add(chain, llama_sampler_init_dist(seed))
        } else {
            llama_sampler_chain_add(chain, llama_sampler_init_greedy())
        }

        return chain
    }

    private func passDeltaUserPrompt(
        preamble: String,
        previousSummaryJSON: String?,
        transcriptChunk: String,
        passIndex: Int,
        totalPasses: Int
    ) -> String {
        let existingStateBlock: String
        if let previousSummaryJSON,
           !previousSummaryJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            existingStateBlock = """
            Existing accepted state:
            \(previousSummaryJSON)

            """
        } else {
            existingStateBlock = ""
        }

        return """
        \(preamble)

        Process summarization pass \(passIndex) of \(totalPasses).
        Use the existing accepted state only to avoid duplicates.
        Return only net-new material from this transcript chunk.

        Return one valid JSON object with exactly these fields:
        - title (string; empty string if unchanged)
        - date (YYYY-MM-DD; empty string if unchanged)
        - summary_points (array of short, high-signal new facts from this chunk only)
        - decisions (array of new decisions only)
        - action_items (array of objects with owner, task, due_date, status, and comments; new or materially refined items only)
        - open_questions (array of new open questions only)
        - key_points (array of new key points only)
        - participants (array of objects with name and role; newly identified participants only)
        - topics (array of objects with title and points; new topics or new points for existing topics only)

        Rules:
        - Do not restate information already captured in the existing accepted state.
        - Do not rewrite the full meeting summary.
        - Use empty arrays when there is nothing new for a field.
        - Do not output markdown fences or prose outside JSON.

        \(existingStateBlock)Transcript chunk:
        \(transcriptChunk)
        """
    }

    private func passDeltaSystemPrompt(baseSystemPrompt: String) -> String {
        """
        \(baseSystemPrompt)

        ### INCREMENTAL PASS MODE
        For this request, do not return a complete meeting summary object.
        Return only a pass delta JSON object with exactly these fields:
        - title
        - date
        - summary_points
        - decisions
        - action_items
        - open_questions
        - key_points
        - participants
        - topics
        """
    }

    private func formatPrompt(systemPrompt: String?, userPrompt: String, model: OpaquePointer?) -> String {
        guard let model, let template = llama_model_chat_template(model, nil) else {
            return systemPrompt.map { $0 + "\n\n" + userPrompt } ?? userPrompt
        }

        var messages: [ChatMessage] = []
        if let systemPrompt {
            messages.append(ChatMessage(role: "system", content: systemPrompt))
        }
        messages.append(ChatMessage(role: "user", content: userPrompt))

        guard let formatted = applyChatTemplate(template: template, messages: messages) else {
             return systemPrompt.map { $0 + "\n\n" + userPrompt } ?? userPrompt
        }

        return formatted
    }

    private func applyChatTemplate(template: UnsafePointer<CChar>, messages: [ChatMessage]) -> String? {
        guard !messages.isEmpty else { return nil }

        var cStrings: [ChatMessageCString] = []
        cStrings.reserveCapacity(messages.count)

        defer {
            for entry in cStrings {
                free(entry.role)
                free(entry.content)
            }
        }

        for message in messages {
            guard let role = strdup(message.role),
                  let content = strdup(message.content)
            else {
                return nil
            }
            cStrings.append(ChatMessageCString(role: role, content: content))
        }

        let chatMessages = cStrings.map {
            llama_chat_message(role: UnsafePointer($0.role), content: UnsafePointer($0.content))
        }

        let estimated = max(256, messages.reduce(0) { $0 + $1.role.utf8.count + $1.content.utf8.count } * 2)
        var buffer = [CChar](repeating: 0, count: estimated)

        func apply(to buffer: inout [CChar]) -> Int32 {
            buffer.withUnsafeMutableBufferPointer { buf in
                chatMessages.withUnsafeBufferPointer { chat in
                    guard let base = chat.baseAddress else { return -1 }
                    return llama_chat_apply_template(template, base, chat.count, true, buf.baseAddress, Int32(buf.count))
                }
            }
        }

        var count = apply(to: &buffer)
        if count <= 0 {
            return nil
        }

        if count >= buffer.count {
            buffer = [CChar](repeating: 0, count: Int(count) + 1)
            count = apply(to: &buffer)
            if count <= 0 {
                return nil
            }
        }

        let bytes = buffer.prefix(Int(count)).map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }

    private func tokenCount(for text: String, vocab: OpaquePointer?) -> Int {
        tokenize(text, vocab: vocab).count
    }

    private func promptOverheadTokens(
        systemPrompt: String?,
        userPrompt: String,
        transcriptMarker: String,
        vocab: OpaquePointer?,
        model: OpaquePointer?
    ) -> Int {
        let formattedPrompt = formatPrompt(systemPrompt: systemPrompt, userPrompt: userPrompt, model: model)
        let totalTokens = tokenCount(for: formattedPrompt, vocab: vocab)
        let markerTokens = max(1, tokenCount(for: transcriptMarker, vocab: vocab))
        return max(0, totalTokens - markerTokens)
    }

    private func placeholderSummaryJSON(targetTokens: Int, vocab: OpaquePointer?) -> String {
        guard targetTokens > 0 else { return "{\"summary\":\"\"}" }
        guard vocab != nil else { return placeholderJSON(notes: Array(repeating: "placeholder", count: targetTokens)) }

        var notes: [String] = []
        notes.reserveCapacity(targetTokens)
        while tokenCount(for: placeholderJSON(notes: notes), vocab: vocab) < targetTokens {
            notes.append("placeholder")
        }
        return placeholderJSON(notes: notes)
    }

    private func placeholderJSON(notes: [String]) -> String {
        let encodedNotes = notes.map { "\"\($0)\"" }.joined(separator: ",")
        return """
        {"title":"Placeholder","date":"1970-01-01","summary":"Placeholder","decisions":[\(encodedNotes)],"action_items":[],"open_questions":[],"key_points":[]}
        """
    }

    private func tokenize(_ text: String, vocab: OpaquePointer?) -> [llama_token] {
        guard let vocab else { return [] }

        return text.withCString { cString in
            let length = Int32(strlen(cString))
            var tokens = [llama_token](repeating: 0, count: max(32, text.utf8.count + 8))
            var count = llama_tokenize(vocab, cString, length, &tokens, Int32(tokens.count), true, true)

            if count == Int32.min {
                return []
            }

            if count < 0 {
                let needed = Int(-count)
                tokens = [llama_token](repeating: 0, count: needed)
                count = llama_tokenize(vocab, cString, length, &tokens, Int32(tokens.count), true, true)
            }

            guard count > 0 else { return [] }
            return Array(tokens.prefix(Int(count)))
        }
    }

    private func tokenToString(_ token: llama_token, vocab: OpaquePointer?) -> String {
        guard let vocab else { return "" }

        var buffer = [CChar](repeating: 0, count: 256)
        var count = llama_token_to_piece(vocab, token, &buffer, Int32(buffer.count), 0, false)

        if count < 0 {
            let needed = Int(-count)
            buffer = [CChar](repeating: 0, count: needed)
            count = llama_token_to_piece(vocab, token, &buffer, Int32(buffer.count), 0, false)
        }

        guard count > 0 else { return "" }
        let bytes = buffer.prefix(Int(count)).map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }
}

private actor LoadedLlamaModelStore {
    private let configuration: LlamaLibrarySummarizationConfiguration
    private var loadedModel: LoadedLlamaModelHandle?

    init(configuration: LlamaLibrarySummarizationConfiguration) {
        self.configuration = configuration
    }

    func load() throws -> LoadedLlamaModelHandle {
        if let loadedModel {
            return loadedModel
        }

        try Task.checkCancellation()
        guard FileManager.default.fileExists(atPath: configuration.modelURL.path) else {
            throw MinuteError.modelMissing
        }

        let environment = ProcessInfo.processInfo.environment
        let physicalMemoryBytes = ProcessInfo.processInfo.physicalMemory
        let modelSizeBytes: Int64? = {
            guard let size = (try? FileManager.default.attributesOfItem(atPath: configuration.modelURL.path)[.size]) as? NSNumber else {
                return nil
            }
            return size.int64Value
        }()

        if environment["MINUTE_ALLOW_LARGE_LLM"] != "1",
           let modelSizeBytes,
           modelSizeBytes > 0 {
            let minHeadroomBytes: Int64 = 4 * 1024 * 1024 * 1024
            if Int64(physicalMemoryBytes) - modelSizeBytes < minHeadroomBytes {
                throw MinuteError.llamaModelTooLarge(
                    modelSizeBytes: modelSizeBytes,
                    physicalMemoryBytes: physicalMemoryBytes
                )
            }
        }

        LlamaLibraryRuntime.ensureBackendInitialized()

        var modelParams = llama_model_default_params()
        let gpuExplicitlyDisabled = environment["MINUTE_DISABLE_LLAMA_GPU"] == "1"
        let gpuExplicitlyEnabled = environment["MINUTE_PREFER_LLAMA_GPU"] == "1"
        let modelLooksSmallEnoughForGPU = (modelSizeBytes ?? Int64.max) <= 5 * 1024 * 1024 * 1024
        let hostLikelySafeForGPU = physicalMemoryBytes >= 16 * 1024 * 1024 * 1024
            || (modelSizeBytes ?? Int64.max) <= 3 * 1024 * 1024 * 1024
        let shouldUseGPUOffload = llama_supports_gpu_offload()
            && !gpuExplicitlyDisabled
            && (gpuExplicitlyEnabled || (modelLooksSmallEnoughForGPU && hostLikelySafeForGPU))

        if shouldUseGPUOffload {
            modelParams.n_gpu_layers = Int32.max
        }

        guard let model = llama_model_load_from_file(configuration.modelURL.path, modelParams) else {
            throw MinuteError.llamaFailed(exitCode: -1, output: "Failed to load llama model")
        }

        let handle = LoadedLlamaModelHandle(
            model: model,
            vocab: llama_model_get_vocab(model),
            maxTrainContextTokens: Int(llama_model_n_ctx_train(model)),
            shouldUseGPUOffload: shouldUseGPUOffload
        )
        loadedModel = handle
        return handle
    }
}

private final class LoadedLlamaModelHandle: @unchecked Sendable {
    let model: OpaquePointer
    let vocab: OpaquePointer?
    let maxTrainContextTokens: Int
    let shouldUseGPUOffload: Bool

    init(
        model: OpaquePointer,
        vocab: OpaquePointer?,
        maxTrainContextTokens: Int,
        shouldUseGPUOffload: Bool
    ) {
        self.model = model
        self.vocab = vocab
        self.maxTrainContextTokens = maxTrainContextTokens
        self.shouldUseGPUOffload = shouldUseGPUOffload
    }

    deinit {
        llama_model_free(model)
    }

    func contextWindowTokens(requested: Int) -> Int {
        max(512, min(requested, maxTrainContextTokens))
    }
}

private enum LlamaLibraryRuntime {
    private static let logger = Logger(subsystem: "roblibob.Minute", category: "llama-lib")
    private static let backendInit: Void = {
        llama_backend_init()
        logger.info("llama backend initialized")
    }()

    static func ensureBackendInitialized() {
        _ = backendInit
    }
}

private enum PromptBuilder {
    private static let logger = Logger(subsystem: "roblibob.Minute", category: "prompt-builder")
    static func summarizationPrompt(
        transcript: String,
        meetingDate: Date,
        languageProcessing: LanguageProcessingProfile = .autoToEnglish
    ) -> String {
        let systemPrompt: String = """
        You are an expert automated meeting secretary. Your goal is to analyze a chronological meeting timeline and generate a structured, factual summary in strict JSON format.

        The timeline includes:
        - Spoken transcript entries, prefixed like: [MM:SS] Speaker N: ...
        - Screen context entries, prefixed like: [MM:SS] Screen (Window Title): ...

        ### CORE INSTRUCTIONS
        1. **Truthfulness is Paramount:** Base all outputs *exclusively* on the provided transcript. Do not infer feelings, motives, or details not explicitly spoken. If a point is ambiguous, omit it rather than guessing.
        2. **ASR Error Correction:** The transcript is machine-generated and may contain phonetic errors (e.g., "sink" instead of "sync"). Use context to interpret the correct meaning, but do not alter the factual substance.
        3. **Filter Noise:** Ignore small talk, pleasantries, incomplete sentences, and non-substantive filler (um, ah). Focus on the "business" of the meeting.
        4. **Language Handling:** Detect the dominant language of the business discussion. Retain specific technical terms or proper nouns in their original language.

        ### OUTPUT FORMAT
        You must output a single, valid JSON object. Do not include markdown formatting (```json), explanations, or raw text outside the braces.

        Schema definition:
        {
            "title": "string (3-8 words, filename-safe, summarizes the main topic)",
            "date": "YYYY-MM-DD (use provided date unless transcript explicitly mentions a different meeting date)",
            "summary": "string (A concise executive summary of 3-8 sentences. Focus on the 'what' and 'why' of the meeting outcomes. Also a summary of the full names of the main participants )",
            "decisions": ["string (Explicit agreements or conclusions reached. Empty if none.)"],
            "action_items": [
                {
                "owner": "string (Name of the person assigned. Use 'Unassigned' if clear task but no owner. Do not guess names.)",
                "task": "string (Start with a verb. Be specific.)"
                }
            ],
            "open_questions": ["string (Unresolved issues or topics tabled for later. Empty if none.)"],
            "key_points": ["string (Notable facts, constraints, or context essential to understanding the meeting. Empty if none.)"]
        }

        ### CRITICAL RULES
        - **No Hallucinations:** If a field (like decisions or action_items) has no content in the transcript, return an empty array []. Do not invent tasks to fill space.
        - **Action Item Specificity:** Only list an action item if there is a clear commitment to perform a task. Do not list general suggestions as action items.
        - **Formatting:** Ensure the JSON is minified or properly escaped so it can be parsed programmatically.

        Timeline follows:
        \(transcript)
        """

        let instruction = languageProcessing
            .summarizationSystemInstruction
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedPrompt = instruction.isEmpty ? systemPrompt : (systemPrompt + "\n\n" + instruction + "\n")

        #if DEBUG
        logger.info("System prompt: \(resolvedPrompt)")
        #endif
        _ = meetingDate
        return resolvedPrompt
    }

    static func repairPrompt(invalidOutput: String) -> String {
        return """
        You are a JSON syntax repair engine. Your only task is to fix the provided text so it becomes a valid, parseable JSON object.

        ### SCHEMA ENFORCEMENT
        Refactor the input into exactly this structure:
        {
            "title": "string",
            "date": "YYYY-MM-DD",
            "summary": "string",
            "decisions": ["string"],
            "action_items": [{"owner": "string", "task": "string"}],
            "open_questions": ["string"],
            "key_points": ["string"]
        }

        ### REPAIR RULES
        1. **Remove Markdown:** Strip all markdown formatting, code fences (```json), and surrounding commentary.
        2. **Fix Escaping:** Identify double quotes used *inside* string values (e.g., dialogue or quoted terms) and escape them properly (e.g., change "He said "Hello"" to "He said \"Hello\"").
        3. **Close Structure:** If the input is truncated, close all open arrays and braces to ensure valid syntax, even if it means losing the last partial sentence.
        4. **Data Preservation:** Do not change the content, language, or meaning of the text. Only fix the syntax.
        5. **Fallbacks:** If a required array is missing, insert an empty array []. If a string is missing, use "".

        Input Text to Repair:
        \(invalidOutput)
        """
    }
}

private struct ChatMessage: Sendable {
    let role: String
    let content: String
}

private struct ChatMessageCString {
    let role: UnsafeMutablePointer<CChar>
    let content: UnsafeMutablePointer<CChar>
}
