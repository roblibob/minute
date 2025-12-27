import Foundation

public enum LlamaModelPaths {
    private static var applicationSupportRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
    }

    public static func modelURL(fileName: String) -> URL {
        applicationSupportRoot
            .appendingPathComponent("Minute", isDirectory: true)
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent("llama", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    public static func mmprojURL(fileName: String) -> URL {
        applicationSupportRoot
            .appendingPathComponent("Minute", isDirectory: true)
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent("llama", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    /// Default LLM model location (GGUF).
    public static var defaultLLMModelURL: URL {
        // ~/Library/Application Support/Minute/models/llama/gemma-3-27b-it-Q4_K_M.gguf
        modelURL(fileName: "gemma-3-27b-it-Q4_K_M.gguf")
    }
}
