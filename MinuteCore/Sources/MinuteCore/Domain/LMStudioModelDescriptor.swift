import Foundation

public struct LMStudioDiscoverySnapshot: Sendable, Equatable, Codable {
    public var serverReachable: Bool
    public var discoveredAt: Date
    public var models: [LMStudioModelDescriptor]
    public var failureReason: String?

    public init(
        serverReachable: Bool,
        discoveredAt: Date = Date(),
        models: [LMStudioModelDescriptor] = [],
        failureReason: String? = nil
    ) {
        self.serverReachable = serverReachable
        self.discoveredAt = discoveredAt
        self.models = models
        self.failureReason = failureReason
    }
}

public struct LMStudioModelDescriptor: Sendable, Equatable, Codable, Identifiable {
    public var id: String { identifier }

    public var identifier: String
    public var displayName: String
    public var modelType: String
    public var publisher: String?
    public var architecture: String?
    public var compatibilityType: String?
    public var quantizationLabel: String?
    public var state: String?
    public var maxContextLength: Int?
    public var supportsVision: Bool

    public init(
        identifier: String,
        displayName: String,
        modelType: String,
        publisher: String? = nil,
        architecture: String? = nil,
        compatibilityType: String? = nil,
        quantizationLabel: String? = nil,
        state: String? = nil,
        maxContextLength: Int? = nil,
        supportsVision: Bool? = nil
    ) {
        self.identifier = identifier
        self.displayName = displayName
        self.modelType = modelType
        self.publisher = publisher
        self.architecture = architecture
        self.compatibilityType = compatibilityType
        self.quantizationLabel = quantizationLabel
        self.state = state
        self.maxContextLength = maxContextLength
        self.supportsVision = supportsVision ?? modelType.caseInsensitiveCompare("vlm") == .orderedSame
    }
}
