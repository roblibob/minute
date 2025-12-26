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
        contextSize: Int? = 4096,
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
public struct LlamaLibrarySummarizationService: SummarizationServicing {
    private let configuration: LlamaLibrarySummarizationConfiguration
    private let logger = Logger(subsystem: "roblibob.Minute", category: "llama-lib")

    public init(configuration: LlamaLibrarySummarizationConfiguration) {
        self.configuration = configuration
    }

    public static func liveDefault(
        selectionStore: SummarizationModelSelectionStore = SummarizationModelSelectionStore()
    ) -> LlamaLibrarySummarizationService {
        let model = selectionStore.selectedModel()
        return LlamaLibrarySummarizationService(
            configuration: LlamaLibrarySummarizationConfiguration(
                modelURL: model.destinationURL
            )
        )
    }

    public func summarize(transcript: String, meetingDate: Date) async throws -> String {
        try await runLlama(
            prompt: PromptBuilder.summarizationPrompt(
                transcript: transcript,
                meetingDate: meetingDate
            )
        )
    }

    public func repairJSON(_ invalidJSON: String) async throws -> String {
        try await runLlama(prompt: PromptBuilder.repairPrompt(invalidOutput: invalidJSON))
    }

    private func runLlama(prompt: String) async throws -> String {
        try Task.checkCancellation()

        guard FileManager.default.fileExists(atPath: configuration.modelURL.path) else {
            throw MinuteError.modelMissing
        }

        LlamaLibraryRuntime.ensureBackendInitialized()

        let modelParams = llama_model_default_params()
        guard let model = llama_model_load_from_file(configuration.modelURL.path, modelParams) else {
            throw MinuteError.llamaFailed(exitCode: -1, output: "Failed to load llama model")
        }
        defer { llama_model_free(model) }

        let vocab = llama_model_get_vocab(model)
        let formattedPrompt = formatPrompt(prompt: prompt, model: model)

        var promptTokens = tokenize(formattedPrompt, vocab: vocab)
        guard !promptTokens.isEmpty else {
            throw MinuteError.llamaFailed(exitCode: -1, output: "Prompt tokenization failed")
        }

        let maxTrainCtx = Int(llama_model_n_ctx_train(model))
        let requestedCtx = configuration.contextSize ?? maxTrainCtx
        let neededCtx = promptTokens.count + configuration.maxTokens
        let nCtx = max(128, min(max(requestedCtx, neededCtx), maxTrainCtx))
        let nBatch = min(max(promptTokens.count, 256), nCtx)

        var ctxParams = llama_context_default_params()
        ctxParams.n_ctx = UInt32(nCtx)
        ctxParams.n_batch = UInt32(nBatch)
        ctxParams.n_seq_max = 1

        guard let ctx = llama_init_from_model(model, ctxParams) else {
            throw MinuteError.llamaFailed(exitCode: -1, output: "Failed to init llama context")
        }
        defer { llama_free(ctx) }

        if let threads = configuration.threads {
            let batchThreads = configuration.threadsBatch ?? threads
            llama_set_n_threads(ctx, Int32(threads), Int32(batchThreads))
        }

        let promptTokenCount = promptTokens.count
        let promptDecodeRC = promptTokens.withUnsafeMutableBufferPointer { buffer -> Int32 in
            let batch = llama_batch_get_one(buffer.baseAddress, Int32(promptTokenCount))
            return llama_decode(ctx, batch)
        }
        if promptDecodeRC != 0 {
            throw MinuteError.llamaFailed(exitCode: promptDecodeRC, output: "llama_decode(prompt) failed")
        }

        let sampler = try makeSampler()
        defer { llama_sampler_free(sampler) }

        let eosToken = llama_vocab_eos(vocab)
        var output = ""
        output.reserveCapacity(4096)

        for _ in 0..<configuration.maxTokens {
            try Task.checkCancellation()

            let token = llama_sampler_sample(sampler, ctx, -1)
            if token == eosToken {
                break
            }

            output.append(tokenToString(token, vocab: vocab))

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

    private func makeSampler() throws -> UnsafeMutablePointer<llama_sampler> {
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

    private func formatPrompt(prompt: String, model: OpaquePointer?) -> String {
        guard let model, let template = llama_model_chat_template(model, nil) else {
            return prompt
        }

        let messages = [ChatMessage(role: "user", content: prompt)]
        guard let formatted = applyChatTemplate(template: template, messages: messages) else {
            return prompt
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
        meetingDate: Date
    ) -> String {
        let systemPrompt: String = """
        You are an expert automated meeting secretary. Your goal is to analyze a chronological meeting timeline and generate a structured, factual summary in strict JSON format.

        The timeline includes:
        - Spoken transcript entries, prefixed like: [MM:SS] Speaker N: ...
        - Screen context entries, prefixed like: [MM:SS] Screen (Window Title): ...
        Use screen entries only as supplemental context (agenda, slide content, participants). Do not invent decisions or action items based solely on screen entries.

        ### CORE INSTRUCTIONS
        1. **Truthfulness is Paramount:** Base all outputs *exclusively* on the provided transcript. Do not infer feelings, motives, or details not explicitly spoken. If a point is ambiguous, omit it rather than guessing.
        2. **ASR Error Correction:** The transcript is machine-generated and may contain phonetic errors (e.g., "sink" instead of "sync"). Use context to interpret the correct meaning, but do not alter the factual substance.
        3. **Filter Noise:** Ignore small talk, pleasantries, incomplete sentences, and non-substantive filler (um, ah). Focus on the "business" of the meeting.
        4. **Language Handling:** Detect the dominant language of the business discussion. Output the summary in that language. Retain specific technical terms or proper nouns in their original language.

        ### OUTPUT FORMAT
        You must output a single, valid JSON object. Do not include markdown formatting (```json), explanations, or raw text outside the braces.

        Schema definition:
        {
            "title": "string (3-8 words, filename-safe, summarizes the main topic)",
            "date": "YYYY-MM-DD (use provided date unless transcript explicitly mentions a different meeting date)",
            "summary": "string (A concise executive summary of 2-5 sentences. Focus on the 'what' and 'why' of the meeting outcomes.)",
            "decisions": ["string (Explicit agreements or conclusions reached. Empty if none.)"],
            "action_items": [
                {
                "owner": "string (Name of the person assigned. Use 'Unassigned' if clear task but no owner. Do not guess names.)",
                "task": "string (Start with a verb. Be specific.)",
                "due": "YYYY-MM-DD (ISO format if mentioned, otherwise empty string)"
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

        logger.info("System prompt: \(systemPrompt)")
        return systemPrompt
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
            "action_items": [{"owner": "string", "task": "string", "due": "string"}],
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
