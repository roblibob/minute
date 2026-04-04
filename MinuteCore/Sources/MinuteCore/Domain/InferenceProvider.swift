import Foundation

public enum InferenceProvider: String, CaseIterable, Sendable, Codable {
    case builtIn
    case ollama
    case lmStudio

    public var displayName: String {
        switch self {
        case .builtIn:
            return "Built-in"
        case .ollama:
            return "Ollama"
        case .lmStudio:
            return "LM Studio"
        }
    }

    public var description: String {
        switch self {
        case .builtIn:
            return "Use Minute's built-in local models."
        case .ollama:
            return "Use a local Ollama daemon and a model tag you manage."
        case .lmStudio:
            return "Use a local LM Studio server and a model you manage."
        }
    }
}
