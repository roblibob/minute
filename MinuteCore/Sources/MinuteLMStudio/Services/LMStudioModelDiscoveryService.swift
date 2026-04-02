import Foundation
import MinuteCore

public struct LMStudioModelDiscoveryService: LMStudioModelDiscovering {
    public var client: LMStudioAPIClient

    public init(client: LMStudioAPIClient = LMStudioAPIClient()) {
        self.client = client
    }

    public func discoverModels() async throws -> LMStudioDiscoverySnapshot {
        try await client.listLocalModels()
    }

    public func validateModelIdentifier(
        _ identifier: String,
        for capability: InferenceCapability
    ) async throws -> CapabilityAvailabilityState {
        try await client.validateModelIdentifier(identifier, for: capability)
    }
}
