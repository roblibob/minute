import Foundation

public struct OllamaDiscoverySnapshot: Sendable, Equatable, Codable {
    public var daemonReachable: Bool
    public var daemonVersion: String?
    public var discoveredAt: Date
    public var models: [OllamaModelDescriptor]
    public var failureReason: String?

    public init(
        daemonReachable: Bool,
        daemonVersion: String? = nil,
        discoveredAt: Date = Date(),
        models: [OllamaModelDescriptor] = [],
        failureReason: String? = nil
    ) {
        self.daemonReachable = daemonReachable
        self.daemonVersion = daemonVersion
        self.discoveredAt = discoveredAt
        self.models = models
        self.failureReason = failureReason
    }
}

public struct OllamaModelDescriptor: Sendable, Equatable, Codable, Identifiable {
    public var id: String { tag }

    public var tag: String
    public var displayName: String
    public var digest: String
    public var sizeBytes: Int64
    public var modifiedAt: Date?
    public var families: [String]
    public var parameterSizeLabel: String?
    public var quantizationLabel: String?
    public var capabilities: [String]
    public var supportsVision: Bool
    public var contextLength: Int?

    public init(
        tag: String,
        displayName: String,
        digest: String,
        sizeBytes: Int64,
        modifiedAt: Date? = nil,
        families: [String] = [],
        parameterSizeLabel: String? = nil,
        quantizationLabel: String? = nil,
        capabilities: [String] = [],
        supportsVision: Bool? = nil,
        contextLength: Int? = nil
    ) {
        self.tag = tag
        self.displayName = displayName
        self.digest = digest
        self.sizeBytes = sizeBytes
        self.modifiedAt = modifiedAt
        self.families = families
        self.parameterSizeLabel = parameterSizeLabel
        self.quantizationLabel = quantizationLabel
        self.capabilities = capabilities
        self.supportsVision = supportsVision ?? capabilities.contains("vision")
        self.contextLength = contextLength
    }
}
