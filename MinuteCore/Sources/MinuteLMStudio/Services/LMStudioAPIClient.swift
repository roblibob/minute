import Foundation
import MinuteCore

public struct LMStudioAPIClient: Sendable {
    public struct ChatMessage: Sendable, Encodable {
        public struct ContentPart: Sendable, Encodable {
            public var type: String
            public var text: String?
            public var imageURL: ImageURL?

            public struct ImageURL: Sendable, Encodable {
                public var url: String

                public init(url: String) {
                    self.url = url
                }
            }

            public init(type: String, text: String? = nil, imageURL: ImageURL? = nil) {
                self.type = type
                self.text = text
                self.imageURL = imageURL
            }

            public static func text(_ value: String) -> Self {
                Self(type: "text", text: value)
            }

            public static func imageDataURL(_ value: String) -> Self {
                Self(type: "image_url", imageURL: ImageURL(url: value))
            }

            enum CodingKeys: String, CodingKey {
                case type
                case text
                case imageURL = "image_url"
            }
        }

        public var role: String
        public var content: [ContentPart]

        public init(role: String, content: [ContentPart]) {
            self.role = role
            self.content = content
        }

        enum CodingKeys: String, CodingKey {
            case role
            case content
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(role, forKey: .role)
            if content.count == 1,
               let first = content.first,
               first.type == "text",
               let text = first.text,
               first.imageURL == nil {
                try container.encode(text, forKey: .content)
            } else {
                try container.encode(content, forKey: .content)
            }
        }
    }

    public var baseURL: URL
    private let session: URLSession

    public init(
        baseURL: URL = URL(string: AppConfiguration.Defaults.defaultLMStudioBaseURL)!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    public func listLocalModels() async throws -> LMStudioDiscoverySnapshot {
        do {
            let response = try await decodeRequest(
                path: "api/v0/models",
                method: "GET",
                body: Optional<Data>.none,
                as: ModelListResponse.self
            )

            return LMStudioDiscoverySnapshot(
                serverReachable: true,
                models: response.models
                    .map(\.descriptor)
                    .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            )
        } catch {
            return LMStudioDiscoverySnapshot(
                serverReachable: false,
                failureReason: "LM Studio is unavailable. Start the local server and refresh."
            )
        }
    }

    public func complete(
        modelIdentifier: String,
        systemPrompt: String?,
        prompt: String,
        maxTokens: Int
    ) async throws -> String {
        var messages: [ChatMessage] = []
        if let systemPrompt, !systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append(ChatMessage(role: "system", content: [.text(systemPrompt)]))
        }
        messages.append(ChatMessage(role: "user", content: [.text(prompt)]))
        do {
            return try await performChatCompletion(
                modelIdentifier: modelIdentifier,
                messages: messages,
                maxTokens: maxTokens
            )
        } catch let error as MinuteError {
            throw error
        } catch let error as LMStudioRequestError {
            throw MinuteError.llamaFailed(
                exitCode: Int32(error.statusCode),
                output: error.message
            )
        } catch {
            throw MinuteError.llamaFailed(
                exitCode: -1,
                output: ErrorHandler.debugMessage(for: error)
            )
        }
    }

    public func chat(
        modelIdentifier: String,
        messages: [ChatMessage],
        maxTokens: Int
    ) async throws -> String {
        do {
            return try await performChatCompletion(
                modelIdentifier: modelIdentifier,
                messages: messages,
                maxTokens: maxTokens
            )
        } catch let error as MinuteError {
            throw error
        } catch let error as LMStudioRequestError {
            throw MinuteError.llamaMTMDFailed(
                exitCode: Int32(error.statusCode),
                output: error.message
            )
        } catch {
            throw MinuteError.llamaMTMDFailed(
                exitCode: -1,
                output: ErrorHandler.debugMessage(for: error)
            )
        }
    }

    public func validateModelIdentifier(
        _ identifier: String,
        for capability: InferenceCapability
    ) async throws -> CapabilityAvailabilityState {
        let trimmedIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIdentifier.isEmpty else {
            return CapabilityAvailabilityState(
                capabilityID: capability,
                providerID: .lmStudio,
                isReady: false,
                status: .needsConfiguration,
                message: "Choose an LM Studio model for \(capability.displayName.lowercased()).",
                selectedReference: nil
            )
        }

        do {
            let model = try await fetchModelRecord(identifier: trimmedIdentifier)
            let descriptor = model.descriptor
            if descriptor.modelType.caseInsensitiveCompare("embeddings") == .orderedSame {
                return CapabilityAvailabilityState(
                    capabilityID: capability,
                    providerID: .lmStudio,
                    isReady: false,
                    status: .unsupported,
                    message: "Selected LM Studio model does not support text generation.",
                    selectedReference: trimmedIdentifier
                )
            }
            if capability == .vision && !descriptor.supportsVision {
                return CapabilityAvailabilityState(
                    capabilityID: capability,
                    providerID: .lmStudio,
                    isReady: false,
                    status: .visionUnsupported,
                    message: "Selected LM Studio model does not advertise vision support.",
                    selectedReference: trimmedIdentifier
                )
            }

            return CapabilityAvailabilityState(
                capabilityID: capability,
                providerID: .lmStudio,
                isReady: true,
                status: .ready,
                message: "Using local LM Studio model \(descriptor.displayName).",
                selectedReference: trimmedIdentifier
            )
        } catch let error as LMStudioRequestError {
            switch error {
            case .notFound:
                return CapabilityAvailabilityState(
                    capabilityID: capability,
                    providerID: .lmStudio,
                    isReady: false,
                    status: .modelMissing,
                    message: "Selected LM Studio model is not available in the local server. Load it in LM Studio first.",
                    selectedReference: trimmedIdentifier
                )
            case .requestFailed:
                return CapabilityAvailabilityState(
                    capabilityID: capability,
                    providerID: .lmStudio,
                    isReady: false,
                    status: .serverUnavailable,
                    message: "LM Studio is unavailable. Start the local server and refresh.",
                    selectedReference: trimmedIdentifier
                )
            }
        } catch {
            return CapabilityAvailabilityState(
                capabilityID: capability,
                providerID: .lmStudio,
                isReady: false,
                status: .serverUnavailable,
                message: "LM Studio is unavailable. Start the local server and refresh.",
                selectedReference: trimmedIdentifier
            )
        }
    }
}

private extension LMStudioAPIClient {
    enum LMStudioRequestError: Error {
        case notFound
        case requestFailed(statusCode: Int, message: String)

        var statusCode: Int {
            switch self {
            case .notFound:
                return 404
            case .requestFailed(let statusCode, _):
                return statusCode
            }
        }

        var message: String {
            switch self {
            case .notFound:
                return "LM Studio model not found"
            case .requestFailed(_, let message):
                return message
            }
        }
    }

    struct ChatCompletionRequest: Encodable {
        var model: String
        var messages: [ChatMessage]
        var temperature: Double
        var topP: Double
        var maxTokens: Int
        var seed: Int

        enum CodingKeys: String, CodingKey {
            case model
            case messages
            case temperature
            case topP = "top_p"
            case maxTokens = "max_tokens"
            case seed
        }
    }

    func performChatCompletion(
        modelIdentifier: String,
        messages: [ChatMessage],
        maxTokens: Int
    ) async throws -> String {
        let trimmedModelIdentifier = modelIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedModelIdentifier.isEmpty else {
            throw MinuteError.modelMissing
        }

        let requestBody = ChatCompletionRequest(
            model: trimmedModelIdentifier,
            messages: messages,
            temperature: 0.2,
            topP: 0.9,
            maxTokens: maxTokens,
            seed: 42
        )
        let data = try JSONEncoder().encode(requestBody)
        let response = try await decodeRequest(
            path: "v1/chat/completions",
            method: "POST",
            body: data,
            as: ChatCompletionResponse.self
        )

        guard let output = response.resolvedOutput else {
            throw LMStudioRequestError.requestFailed(statusCode: -1, message: "LM Studio returned an empty response")
        }
        return output
    }

    struct ChatCompletionResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                enum ContentValue: Decodable {
                    case string(String)
                    case parts([ContentPart])

                    struct ContentPart: Decodable {
                        var type: String?
                        var text: String?
                    }

                    init(from decoder: Decoder) throws {
                        let container = try decoder.singleValueContainer()
                        if let value = try? container.decode(String.self) {
                            self = .string(value)
                        } else {
                            self = .parts(try container.decode([ContentPart].self))
                        }
                    }
                }

                var content: ContentValue?
            }

            var message: Message
        }

        var choices: [Choice]

        var resolvedOutput: String? {
            for choice in choices {
                switch choice.message.content {
                case .string(let value):
                    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        return trimmed
                    }
                case .parts(let parts):
                    let text = parts.compactMap(\.text).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty {
                        return text
                    }
                case .none:
                    continue
                }
            }
            return nil
        }
    }

    struct ModelListResponse: Decodable {
        var models: [ModelRecord]

        init(from decoder: Decoder) throws {
            if let container = try? decoder.singleValueContainer(),
               let models = try? container.decode([ModelRecord].self) {
                self.models = models
                return
            }

            let container = try decoder.container(keyedBy: DynamicCodingKey.self)
            self.models = try container.decodeIfPresent([ModelRecord].self, forKey: DynamicCodingKey("data"))
                ?? container.decodeIfPresent([ModelRecord].self, forKey: DynamicCodingKey("models"))
                ?? []
        }
    }

    struct ModelRecord: Decodable {
        var identifier: String
        var displayName: String
        var modelType: String
        var publisher: String?
        var architecture: String?
        var compatibilityType: String?
        var quantizationLabel: String?
        var state: String?
        var maxContextLength: Int?
        var supportsVision: Bool

        var descriptor: LMStudioModelDescriptor {
            LMStudioModelDescriptor(
                identifier: identifier,
                displayName: displayName,
                modelType: modelType,
                publisher: publisher,
                architecture: architecture,
                compatibilityType: compatibilityType,
                quantizationLabel: quantizationLabel,
                state: state,
                maxContextLength: maxContextLength,
                supportsVision: supportsVision
            )
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: DynamicCodingKey.self)

            let identifier = try container.decodeIfPresent(String.self, forKey: DynamicCodingKey("id"))
                ?? container.decodeIfPresent(String.self, forKey: DynamicCodingKey("model_id"))
                ?? container.decodeIfPresent(String.self, forKey: DynamicCodingKey("path"))
                ?? ""
            self.identifier = identifier

            let displayName = try container.decodeIfPresent(String.self, forKey: DynamicCodingKey("display_name"))
                ?? container.decodeIfPresent(String.self, forKey: DynamicCodingKey("name"))
                ?? identifier.components(separatedBy: "/").last
                ?? identifier
            self.displayName = displayName

            let modelType = try container.decodeIfPresent(String.self, forKey: DynamicCodingKey("type"))
                ?? container.decodeIfPresent(String.self, forKey: DynamicCodingKey("model_type"))
                ?? "llm"
            self.modelType = modelType

            publisher = try container.decodeIfPresent(String.self, forKey: DynamicCodingKey("publisher"))
            architecture = try container.decodeIfPresent(String.self, forKey: DynamicCodingKey("architecture"))
                ?? container.decodeIfPresent(String.self, forKey: DynamicCodingKey("arch"))
            compatibilityType = try container.decodeIfPresent(String.self, forKey: DynamicCodingKey("compatibility_type"))
            quantizationLabel = try container.decodeIfPresent(String.self, forKey: DynamicCodingKey("quantization"))
                ?? container.decodeIfPresent(String.self, forKey: DynamicCodingKey("quantization_label"))
            state = try container.decodeIfPresent(String.self, forKey: DynamicCodingKey("state"))
            maxContextLength = try container.decodeIfPresent(Int.self, forKey: DynamicCodingKey("max_context_length"))

            let explicitSupportsVision = try container.decodeIfPresent(Bool.self, forKey: DynamicCodingKey("supports_vision"))
            let capabilities = try container.decodeIfPresent([String].self, forKey: DynamicCodingKey("capabilities")) ?? []
            supportsVision = explicitSupportsVision
                ?? (modelType.caseInsensitiveCompare("vlm") == .orderedSame)
                || capabilities.contains(where: { $0.caseInsensitiveCompare("vision") == .orderedSame })
        }
    }

    func fetchModelRecord(identifier: String) async throws -> ModelRecord {
        let encodedIdentifier = identifier.addingPercentEncoding(withAllowedCharacters: .urlPathSegmentAllowed)
            ?? identifier
        do {
            return try await decodeRequest(
                path: "api/v0/models/\(encodedIdentifier)",
                method: "GET",
                body: Optional<Data>.none,
                as: ModelRecord.self
            )
        } catch let error as LMStudioRequestError {
            switch error {
            case .notFound:
                throw error
            case .requestFailed:
                let models = try await decodeRequest(
                    path: "api/v0/models",
                    method: "GET",
                    body: Optional<Data>.none,
                    as: ModelListResponse.self
                )
                if let model = models.models.first(where: {
                    $0.identifier.caseInsensitiveCompare(identifier) == .orderedSame
                }) {
                    return model
                }
                throw error
            }
        }
    }

    func decodeRequest<Response: Decodable>(
        path: String,
        method: String,
        body: Data?,
        as type: Response.Type
    ) async throws -> Response {
        var request = URLRequest(url: endpointURL(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LMStudioRequestError.requestFailed(statusCode: -1, message: "Invalid LM Studio response")
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
                if httpResponse.statusCode == 404 {
                    throw LMStudioRequestError.notFound
                }
                throw LMStudioRequestError.requestFailed(statusCode: httpResponse.statusCode, message: message)
            }

            return try JSONDecoder().decode(type, from: data)
        } catch let error as LMStudioRequestError {
            throw error
        } catch {
            throw LMStudioRequestError.requestFailed(statusCode: -1, message: ErrorHandler.debugMessage(for: error))
        }
    }

    func endpointURL(path: String) -> URL {
        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let basePath = baseURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let joinedPath = ([basePath].filter { !$0.isEmpty } + [normalizedPath]).joined(separator: "/")
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) ?? URLComponents()
        components.scheme = components.scheme ?? baseURL.scheme
        components.host = components.host ?? baseURL.host
        components.port = components.port ?? baseURL.port
        components.percentEncodedPath = "/" + joinedPath
        return components.url ?? baseURL.appendingPathComponent(normalizedPath)
    }
}

private extension CharacterSet {
    static let urlPathSegmentAllowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
}

private struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(stringValue: String) {
        self.init(stringValue)
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}
