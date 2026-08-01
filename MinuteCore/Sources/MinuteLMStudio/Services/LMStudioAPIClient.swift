import CoreGraphics
import Foundation
import ImageIO
import MinuteCore
import UniformTypeIdentifiers

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

    /// Default session with an extended request timeout: local servers can take
    /// longer than URLSession's 60-second default to complete a non-streaming
    /// chat completion (large prompts, slow models, cold starts).
    public static let defaultSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = AppConfiguration.Defaults.localServerRequestTimeoutSeconds
        return URLSession(configuration: configuration)
    }()

    public init(
        baseURL: URL = URL(string: AppConfiguration.Defaults.defaultLMStudioBaseURL)!,
        session: URLSession = LMStudioAPIClient.defaultSession
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
            if capability == .vision {
                do {
                    try await probeVisionInputSupport(modelIdentifier: trimmedIdentifier)
                } catch let error as LMStudioRequestError {
                    return CapabilityAvailabilityState(
                        capabilityID: capability,
                        providerID: .lmStudio,
                        isReady: false,
                        status: .visionUnsupported,
                        message: visionProbeFailureMessage(from: error.message),
                        selectedReference: trimmedIdentifier
                    )
                }
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

    struct ErrorResponse: Decodable {
        enum ErrorValue: Decodable {
            case string(String)
            case object(Detail)

            struct Detail: Decodable {
                var message: String?
                var code: String?
                var type: String?
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let value = try? container.decode(String.self) {
                    self = .string(value)
                } else {
                    self = .object(try container.decode(Detail.self))
                }
            }

            var resolvedMessage: String? {
                switch self {
                case .string(let value):
                    return value
                case .object(let detail):
                    return detail.message ?? detail.code ?? detail.type
                }
            }
        }

        var error: ErrorValue?
        var message: String?

        var resolvedMessage: String? {
            error?.resolvedMessage ?? message
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

    func probeVisionInputSupport(modelIdentifier: String) async throws {
        let response = try await performChatCompletion(
            modelIdentifier: modelIdentifier,
            messages: [
                ChatMessage(
                    role: "user",
                    content: [
                        .text("Reply with OK."),
                        .imageDataURL(Self.visionProbeImageDataURL)
                    ]
                )
            ],
            maxTokens: 8
        )

        guard !response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LMStudioRequestError.requestFailed(
                statusCode: -1,
                message: "LM Studio returned an empty response for image input."
            )
        }
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
                let message = decodedErrorMessage(from: data) ?? String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
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

    func decodedErrorMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        let decoded = try? JSONDecoder().decode(ErrorResponse.self, from: data)
        return decoded?.resolvedMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func visionProbeFailureMessage(from backendMessage: String) -> String {
        let trimmedMessage = backendMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            return "Selected LM Studio model could not process image input. Load the model in LM Studio or choose another vision-capable model."
        }

        return "Selected LM Studio model could not process image input. Load the model in LM Studio or choose another vision-capable model. LM Studio reported: \(trimmedMessage)"
    }

    static var visionProbeImageDataURL: String {
        "data:image/png;base64,\(visionProbeImageBase64)"
    }

    private static let visionProbeImageBase64: String = {
        let size = CGSize(width: 800, height: 600)
        let bytesPerRow = Int(size.width) * 4
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: Int(size.width),
                height: Int(size.height),
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return ""
        }

        context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        context.fill(CGRect(origin: .zero, size: size))
        context.setFillColor(red: 0.85, green: 0.9, blue: 0.95, alpha: 1)
        context.fill(CGRect(x: 48, y: 56, width: 704, height: 120))
        context.fill(CGRect(x: 48, y: 216, width: 520, height: 36))
        context.fill(CGRect(x: 48, y: 276, width: 612, height: 36))
        context.fill(CGRect(x: 48, y: 336, width: 468, height: 36))

        guard let image = context.makeImage() else {
            return ""
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return ""
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            return ""
        }

        return Data(referencing: data).base64EncodedString()
    }()
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
