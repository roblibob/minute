import Foundation
import MinuteCore

public struct OllamaModelDiscoveryService: OllamaModelDiscovering {
    public var client: OllamaAPIClient

    public init(client: OllamaAPIClient = OllamaAPIClient()) {
        self.client = client
    }

    public func discoverModels() async throws -> OllamaDiscoverySnapshot {
        try await client.listLocalModels()
    }

    public func validateModelTag(_ tag: String, for capability: InferenceCapability) async throws -> CapabilityAvailabilityState {
        try await client.validateModelTag(tag, for: capability)
    }
}
