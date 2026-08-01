import Foundation
import MinuteCore

public struct OllamaAPIClient: Sendable {
    public struct ChatMessage: Sendable, Encodable {
        public var role: String
        public var content: String
        public var images: [String]?

        public init(role: String, content: String, images: [String]? = nil) {
            self.role = role
            self.content = content
            self.images = images
        }
    }

    public struct GenerateOptions: Sendable, Encodable {
        public var temperature: Double?
        public var topP: Double?
        public var topK: Int?
        public var seed: Int?
        public var numPredict: Int?

        public init(
            temperature: Double? = nil,
            topP: Double? = nil,
            topK: Int? = nil,
            seed: Int? = nil,
            numPredict: Int? = nil
        ) {
            self.temperature = temperature
            self.topP = topP
            self.topK = topK
            self.seed = seed
            self.numPredict = numPredict
        }
    }

    public var baseURL: URL
    private let session: URLSession

    /// Default session with an extended request timeout: local servers can take
    /// longer than URLSession's 60-second default to complete a non-streaming
    /// chat completion (large prompts, slow models, cold starts).
    public static let defaultSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = AppConfiguration.Defaults.localServerRequestTimeoutSeconds
        return URLSession(configuration: configuration)
    }()

    public init(
        baseURL: URL = URL(string: AppConfiguration.Defaults.defaultOllamaBaseURL)!,
        session: URLSession = OllamaAPIClient.defaultSession
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    public func listLocalModels() async throws -> OllamaDiscoverySnapshot {
        do {
            let tagsResponse = try await decodeRequest(
                path: "api/tags",
                method: "GET",
                body: Optional<Data>.none,
                errorFactory: { code, message in
                    MinuteError.llamaFailed(exitCode: code, output: message)
                },
                as: TagsResponse.self
            )

            var models: [OllamaModelDescriptor] = []
            models.reserveCapacity(tagsResponse.models.count)

            for model in tagsResponse.models {
                let details = try? await showModelDetails(modelTag: model.name)
                models.append(
                    OllamaModelDescriptor(
                        tag: model.name,
                        displayName: model.name,
                        digest: model.digest,
                        sizeBytes: model.size,
                        modifiedAt: model.modifiedAt,
                        families: details?.modelInfo.families ?? [],
                        parameterSizeLabel: details?.details.parameterSize,
                        quantizationLabel: details?.details.quantizationLevel,
                        capabilities: details?.capabilities ?? [],
                        supportsVision: details?.capabilities.contains("vision"),
                        contextLength: details?.modelInfo.contextLength
                    )
                )
            }

            return OllamaDiscoverySnapshot(
                daemonReachable: true,
                daemonVersion: try? await daemonVersion(),
                models: models.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            )
        } catch let error as MinuteError {
            return OllamaDiscoverySnapshot(
                daemonReachable: false,
                failureReason: ErrorHandler.userMessage(for: error, fallback: "Unable to reach the Ollama daemon.")
            )
        } catch {
            return OllamaDiscoverySnapshot(
                daemonReachable: false,
                failureReason: ErrorHandler.userMessage(for: error, fallback: "Unable to reach the Ollama daemon.")
            )
        }
    }

    public func generate(
        modelTag: String,
        prompt: String,
        systemPrompt: String? = nil,
        format: String? = nil,
        options: GenerateOptions = GenerateOptions()
    ) async throws -> String {
        let trimmedModelTag = modelTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedModelTag.isEmpty else {
            throw MinuteError.modelMissing
        }

        let requestURL = baseURL.appendingPathComponent("api/generate")
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            GenerateRequest(
                model: trimmedModelTag,
                prompt: prompt,
                system: systemPrompt,
                stream: false,
                format: format,
                options: options
            )
        )

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw MinuteError.llamaFailed(exitCode: -1, output: "Invalid Ollama response")
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
                throw MinuteError.llamaFailed(exitCode: Int32(httpResponse.statusCode), output: message)
            }

            let decoded = try JSONDecoder().decode(GenerateResponse.self, from: data)
            guard let output = decoded.resolvedOutput else {
                throw MinuteError.llamaFailed(exitCode: -1, output: "Ollama returned an empty response")
            }
            return output
        } catch let error as MinuteError {
            throw error
        } catch {
            throw MinuteError.llamaFailed(exitCode: -1, output: ErrorHandler.debugMessage(for: error))
        }
    }

    public func chat(
        modelTag: String,
        messages: [ChatMessage],
        format: String? = nil,
        options: GenerateOptions = GenerateOptions()
    ) async throws -> String {
        let trimmedModelTag = modelTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedModelTag.isEmpty else {
            throw MinuteError.modelMissing
        }

        let requestURL = baseURL.appendingPathComponent("api/chat")
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            ChatRequest(
                model: trimmedModelTag,
                messages: messages,
                stream: false,
                format: format,
                options: options
            )
        )

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw MinuteError.llamaMTMDFailed(exitCode: -1, output: "Invalid Ollama response")
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
                throw MinuteError.llamaMTMDFailed(exitCode: Int32(httpResponse.statusCode), output: message)
            }

            let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
            guard let output = decoded.resolvedOutput else {
                throw MinuteError.llamaMTMDFailed(exitCode: -1, output: "Ollama returned an empty response")
            }
            return output
        } catch let error as MinuteError {
            throw error
        } catch {
            throw MinuteError.llamaMTMDFailed(exitCode: -1, output: ErrorHandler.debugMessage(for: error))
        }
    }

    public func validateModelTag(_ tag: String, for capability: InferenceCapability) async throws -> CapabilityAvailabilityState {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return CapabilityAvailabilityState(
                capabilityID: capability,
                providerID: .ollama,
                isReady: false,
                status: .needsConfiguration,
                message: "Enter an Ollama model tag for \(capability.displayName.lowercased()).",
                selectedReference: nil
            )
        }

        do {
            let details = try await showModelDetails(modelTag: trimmed)
            if capability == .vision && !details.capabilities.contains("vision") {
                return CapabilityAvailabilityState(
                    capabilityID: capability,
                    providerID: .ollama,
                    isReady: false,
                    status: .visionUnsupported,
                    message: "Selected Ollama model does not advertise vision support.",
                    selectedReference: trimmed
                )
            }

            return CapabilityAvailabilityState(
                capabilityID: capability,
                providerID: .ollama,
                isReady: true,
                status: .ready,
                message: "Using local Ollama model \(trimmed).",
                selectedReference: trimmed
            )
        } catch let error as MinuteError {
            switch error {
            case .modelMissing:
                return CapabilityAvailabilityState(
                    capabilityID: capability,
                    providerID: .ollama,
                    isReady: false,
                    status: .modelMissing,
                    message: "Selected Ollama model is not downloaded locally. Pull it in Ollama first.",
                    selectedReference: trimmed
                )
            default:
                return CapabilityAvailabilityState(
                    capabilityID: capability,
                    providerID: .ollama,
                    isReady: false,
                    status: .daemonUnavailable,
                    message: "Ollama is unavailable. Start the local daemon and refresh.",
                    selectedReference: trimmed
                )
            }
        } catch {
            return CapabilityAvailabilityState(
                capabilityID: capability,
                providerID: .ollama,
                isReady: false,
                status: .daemonUnavailable,
                message: "Ollama is unavailable. Start the local daemon and refresh.",
                selectedReference: trimmed
            )
        }
    }
}

private extension OllamaAPIClient {
    struct VersionResponse: Decodable {
        var version: String
    }

    struct TagsResponse: Decodable {
        struct Model: Decodable {
            var name: String
            var modifiedAt: Date?
            var size: Int64
            var digest: String

            enum CodingKeys: String, CodingKey {
                case name
                case modifiedAt = "modified_at"
                case size
                case digest
            }
        }

        var models: [Model]
    }

    struct ShowRequest: Encodable {
        var model: String
    }

    struct ShowResponse: Decodable {
        struct ModelDetails: Decodable {
            var parameterSize: String?
            var quantizationLevel: String?

            enum CodingKeys: String, CodingKey {
                case parameterSize = "parameter_size"
                case quantizationLevel = "quantization_level"
            }
        }

        struct ModelInfo: Decodable {
            var families: [String]
            var contextLength: Int?

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: DynamicCodingKey.self)
                let families = try container.decodeIfPresent([String].self, forKey: DynamicCodingKey("general.families")) ?? []
                let contextLength = try container.decodeIfPresent(Int.self, forKey: DynamicCodingKey("llama.context_length"))
                self.families = families
                self.contextLength = contextLength
            }
        }

        var capabilities: [String]
        var details: ModelDetails
        var modelInfo: ModelInfo

        enum CodingKeys: String, CodingKey {
            case capabilities
            case details
            case modelInfo = "model_info"
        }
    }

    struct GenerateRequest: Encodable {
        var model: String
        var prompt: String
        var system: String?
        var stream: Bool
        var format: String?
        var options: GenerateOptions
    }

    struct GenerateResponse: Decodable {
        var response: String?
        var thinking: String?

        var resolvedOutput: String? {
            firstNonEmptyOutput(response, thinking)
        }
    }

    struct ChatRequest: Encodable {
        var model: String
        var messages: [ChatMessage]
        var stream: Bool
        var format: String?
        var options: GenerateOptions
    }

    struct ChatResponse: Decodable {
        struct Message: Decodable {
            var content: String?
            var thinking: String?
        }

        var message: Message
        var thinking: String?

        var resolvedOutput: String? {
            firstNonEmptyOutput(message.content, message.thinking, thinking)
        }
    }

    struct DynamicCodingKey: CodingKey {
        var stringValue: String
        var intValue: Int?

        init(_ stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }

        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }

        init?(intValue: Int) {
            self.stringValue = "\(intValue)"
            self.intValue = intValue
        }
    }

    func daemonVersion() async throws -> String {
        let response = try await decodeRequest(
            path: "api/version",
            method: "GET",
            body: Optional<Data>.none,
            errorFactory: { code, message in
                MinuteError.llamaFailed(exitCode: code, output: message)
            },
            as: VersionResponse.self
        )
        return response.version
    }

    func showModelDetails(modelTag: String) async throws -> ShowResponse {
        do {
            return try await decodeRequest(
                path: "api/show",
                method: "POST",
                body: try JSONEncoder().encode(ShowRequest(model: modelTag)),
                errorFactory: { code, message in
                    if code == 404 {
                        return MinuteError.modelMissing
                    }
                    return MinuteError.llamaFailed(exitCode: code, output: message)
                },
                as: ShowResponse.self
            )
        } catch let error as MinuteError {
            throw error
        } catch {
            throw MinuteError.llamaFailed(exitCode: -1, output: ErrorHandler.debugMessage(for: error))
        }
    }

    func decodeRequest<Response: Decodable>(
        path: String,
        method: String,
        body: Data?,
        errorFactory: @escaping (Int32, String) -> MinuteError,
        as responseType: Response.Type
    ) async throws -> Response {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        request.httpBody = body

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw errorFactory(-1, "Invalid Ollama response")
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
                throw errorFactory(Int32(httpResponse.statusCode), message)
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(responseType, from: data)
        } catch let error as MinuteError {
            throw error
        } catch {
            throw errorFactory(-1, ErrorHandler.debugMessage(for: error))
        }
    }
}

private func firstNonEmptyOutput(_ candidates: String?...) -> String? {
    for candidate in candidates {
        let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty {
            return trimmed
        }
    }
    return nil
}
