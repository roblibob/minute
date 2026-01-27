import Foundation

public struct FluidAudioASRModel: Sendable, Equatable, Identifiable {
    public var id: String
    public var displayName: String
    public var summary: String
    public var versionKey: String

    public init(id: String, displayName: String, summary: String, versionKey: String) {
        self.id = id
        self.displayName = displayName
        self.summary = summary
        self.versionKey = versionKey
    }
}

public enum FluidAudioASRModelCatalog {
    public static let defaultModelID = "fluidaudio/asr-v3"

    private static let v3 = FluidAudioASRModel(
        id: "fluidaudio/asr-v3",
        displayName: "Parakeet TDT v3",
        summary: "Multilingual ASR (25 European languages).",
        versionKey: "v3"
    )

    private static let v2 = FluidAudioASRModel(
        id: "fluidaudio/asr-v2",
        displayName: "Parakeet TDT v2",
        summary: "English-only ASR with smaller download.",
        versionKey: "v2"
    )

    public static var all: [FluidAudioASRModel] {
        [v3, v2]
    }

    public static var defaultModel: FluidAudioASRModel {
        model(for: defaultModelID) ?? v3
    }

    public static func model(for id: String?) -> FluidAudioASRModel? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    public static func displayName(for id: String) -> String {
        model(for: id)?.displayName ?? id
    }
}
