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
    private let logger = Logger(subsystem: "knowitflx.Minute", category: "llama-lib")

    public init(configuration: LlamaLibrarySummarizationConfiguration) {
        self.configuration = configuration
    }

    public static func liveDefault() -> LlamaLibrarySummarizationService {
        LlamaLibrarySummarizationService(
            configuration: LlamaLibrarySummarizationConfiguration(
                modelURL: LlamaModelPaths.defaultLLMModelURL
            )
        )
    }

    public func summarize(transcript: String, meetingDate: Date) async throws -> String {
        try await runLlama(prompt: PromptBuilder.summarizationPrompt(transcript: transcript, meetingDate: meetingDate))
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
    private static let logger = Logger(subsystem: "knowitflx.Minute", category: "llama-lib")
    private static let backendInit: Void = {
        llama_backend_init()
        logger.info("llama backend initialized")
    }()

    static func ensureBackendInitialized() {
        _ = backendInit
    }
}

private enum PromptBuilder {
    static func summarizationPrompt(transcript: String, meetingDate: Date) -> String {
        let isoDate = MeetingFileContract.isoDate(meetingDate)

        return """
        You must output JSON only.

        Return exactly one JSON object matching this schema:
        {
          \"title\": string,
          \"date\": \"YYYY-MM-DD\",
          \"summary\": string,
          \"decisions\": [string],
          \"action_items\": [{\"owner\": string, \"task\": string, \"due\": string}],
          \"open_questions\": [string],
          \"key_points\": [string]
        }

        Rules:
        - Output must be a single JSON object.
        - No markdown, no code fences, no commentary.
        - All arrays must be present (use [] if none).
        - date must be \"\(isoDate)\" unless the transcript clearly indicates a different meeting date.
        - action_items.due must be \"YYYY-MM-DD\" or \"\".
        - Do not invent facts. Only use information from the transcript.
        - Do not copy long phrases from the transcript. Paraphrase and summarize.
        - title must be a short topic-based phrase (3-8 words), suitable for a filename (no slashes).
        - summary must be 2-5 sentences focused on outcomes and key takeaways, not a transcript dump.
        - decisions must list explicit decisions only (empty if none).
        - action_items must list explicit tasks with an owner and task; if owner is unknown use \"\".
        - open_questions should capture unresolved issues or follow-ups (empty if none).
        - key_points should capture notable facts, constraints, or context (empty if none).
        - If the title is unknown, use \"Meeting \(isoDate)\".

        Transcript:
        \(transcript)
        """
    }

    static func repairPrompt(invalidOutput: String) -> String {
        return """
        You must output JSON only.

        The following text was intended to be a JSON object but is invalid or does not match the schema.
        Produce a corrected JSON object that matches this schema exactly:
        {
          \"title\": string,
          \"date\": \"YYYY-MM-DD\",
          \"summary\": string,
          \"decisions\": [string],
          \"action_items\": [{\"owner\": string, \"task\": string, \"due\": string}],
          \"open_questions\": [string],
          \"key_points\": [string]
        }

        Rules:
        - Output must be a single JSON object.
        - No markdown, no code fences, no commentary.
        - All arrays must be present.
        - If a field cannot be recovered, use an empty string or empty array as appropriate.
        - action_items.due must be \"YYYY-MM-DD\" or \"\".

        Invalid output:
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
