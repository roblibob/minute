import Foundation

public enum InferenceProvider: String, CaseIterable, Sendable, Codable {
    case builtIn
    case ollama

    public var displayName: String {
        switch self {
        case .builtIn:
            return "Built-in"
        case .ollama:
            return "Ollama"
        }
    }

    public var description: String {
        switch self {
        case .builtIn:
            return "Use Minute's built-in local models."
        case .ollama:
            return "Use a local Ollama daemon and a model tag you manage."
        }
    }
}
