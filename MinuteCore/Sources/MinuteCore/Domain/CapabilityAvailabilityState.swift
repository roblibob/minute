import Foundation

public enum CapabilityAvailabilityStatus: String, Sendable, Codable {
    case ready
    case needsConfiguration
    case daemonUnavailable
    case serverUnavailable
    case modelMissing
    case unsupported
    case visionUnsupported
    case unknown
}

public struct CapabilityAvailabilityState: Sendable, Equatable, Codable {
    public var capabilityID: InferenceCapability
    public var providerID: InferenceProvider
    public var isReady: Bool
    public var status: CapabilityAvailabilityStatus
    public var message: String?
    public var selectedReference: String?

    public init(
        capabilityID: InferenceCapability,
        providerID: InferenceProvider,
        isReady: Bool,
        status: CapabilityAvailabilityStatus,
        message: String? = nil,
        selectedReference: String? = nil
    ) {
        self.capabilityID = capabilityID
        self.providerID = providerID
        self.isReady = isReady
        self.status = status
        self.message = message
        self.selectedReference = selectedReference
    }
}

public struct InferenceTaskBinding: Sendable, Equatable, Codable {
    public var capabilityID: InferenceCapability
    public var providerID: InferenceProvider
    public var providerReference: String
    public var connectionBaseURLString: String?
    public var capturedAt: Date
    public var supportsVisionInputs: Bool

    public init(
        capabilityID: InferenceCapability,
        providerID: InferenceProvider,
        providerReference: String,
        connectionBaseURLString: String? = nil,
        capturedAt: Date = Date(),
        supportsVisionInputs: Bool
    ) {
        self.capabilityID = capabilityID
        self.providerID = providerID
        self.providerReference = providerReference
        self.connectionBaseURLString = connectionBaseURLString
        self.capturedAt = capturedAt
        self.supportsVisionInputs = supportsVisionInputs
    }
}
