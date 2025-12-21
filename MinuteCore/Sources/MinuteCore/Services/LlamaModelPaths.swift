import Foundation

public enum LlamaModelPaths {
    private static var applicationSupportRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
    }

    /// Default LLM model location (GGUF).
    public static var defaultLLMModelURL: URL {
        // ~/Library/Application Support/Minute/models/llama/gemma-3-1b-it-Q4_K_M.gguf
        applicationSupportRoot
            .appendingPathComponent("Minute", isDirectory: true)
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent("llama", isDirectory: true)
            .appendingPathComponent("gemma-3-1b-it-Q4_K_M.gguf")
    }
}
