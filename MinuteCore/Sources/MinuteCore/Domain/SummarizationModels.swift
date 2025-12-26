import Foundation

public struct SummarizationModel: Sendable, Equatable, Identifiable {
    public var id: String
    public var displayName: String
    public var summary: String
    public var fileName: String
    public var sourceURL: URL
    public var expectedSHA256Hex: String
    public var expectedFileSizeBytes: Int64?
    public var mmprojFileName: String?
    public var mmprojSourceURL: URL?
    public var mmprojExpectedSHA256Hex: String?
    public var mmprojExpectedFileSizeBytes: Int64?

    public init(
        id: String,
        displayName: String,
        summary: String,
        fileName: String,
        sourceURL: URL,
        expectedSHA256Hex: String,
        expectedFileSizeBytes: Int64? = nil,
        mmprojFileName: String? = nil,
        mmprojSourceURL: URL? = nil,
        mmprojExpectedSHA256Hex: String? = nil,
        mmprojExpectedFileSizeBytes: Int64? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.summary = summary
        self.fileName = fileName
        self.sourceURL = sourceURL
        self.expectedSHA256Hex = expectedSHA256Hex
        self.expectedFileSizeBytes = expectedFileSizeBytes
        self.mmprojFileName = mmprojFileName
        self.mmprojSourceURL = mmprojSourceURL
        self.mmprojExpectedSHA256Hex = mmprojExpectedSHA256Hex
        self.mmprojExpectedFileSizeBytes = mmprojExpectedFileSizeBytes
    }

    public var destinationURL: URL {
        LlamaModelPaths.modelURL(fileName: fileName)
    }

    public var mmprojDestinationURL: URL? {
        guard let mmprojFileName else { return nil }
        return LlamaModelPaths.mmprojURL(fileName: mmprojFileName)
    }
}

public enum SummarizationModelCatalog {
    public static let defaultModelID = "llm/gemma-3-27b-it-q4_k_m"

    public static let all: [SummarizationModel] = [
        SummarizationModel(
            id: "llm/gemma-3-4b-it-q4_k_m",
            displayName: "Gemma 3 4B IT (Q4_K_M)",
            summary: "Balanced quality and speed. Moderate download size. Multimodal.",
            fileName: "gemma-3-4b-it-Q4_K_M.gguf",
            sourceURL: URL(string: "https://huggingface.co/ggml-org/gemma-3-4b-it-GGUF/resolve/main/gemma-3-4b-it-Q4_K_M.gguf")!,
            expectedSHA256Hex: "882e8d2db44dc554fb0ea5077cb7e4bc49e7342a1f0da57901c0802ea21a0863",
            expectedFileSizeBytes: 2_489_757_856,
            mmprojFileName: "gemma-3-4b-it-mmproj-model-f16.gguf",
            mmprojSourceURL: URL(string: "https://huggingface.co/ggml-org/gemma-3-4b-it-GGUF/resolve/main/mmproj-model-f16.gguf")!,
            mmprojExpectedSHA256Hex: "8c0fb064b019a6972856aaae2c7e4792858af3ca4561be2dbf649123ba6c40cb",
            mmprojExpectedFileSizeBytes: 851_251_104
        ),
        SummarizationModel(
            id: "llm/gemma-3-27b-it-q4_k_m",
            displayName: "Gemma 3 27B IT (Q4_K_M)",
            summary: "Best quality summaries. Large download. Multimodal.",
            fileName: "gemma-3-27b-it-Q4_K_M.gguf",
            sourceURL: URL(string: "https://huggingface.co/ggml-org/gemma-3-27b-it-GGUF/resolve/main/gemma-3-27b-it-Q4_K_M.gguf")!,
            expectedSHA256Hex: "edc9aff4d811a285b9157618130b08688b0768d94ee5355b02dc0cb713012e15",
            expectedFileSizeBytes: 16_546_404_736,
            mmprojFileName: "gemma-3-27b-it-mmproj-model-f16.gguf",
            mmprojSourceURL: URL(string: "https://huggingface.co/ggml-org/gemma-3-27b-it-GGUF/resolve/main/mmproj-model-f16.gguf")!,
            mmprojExpectedSHA256Hex: "54cb61c842fe49ac3c89bc1a614a2778163eb49f3dec2b90ff688b4c0392cb48",
            mmprojExpectedFileSizeBytes: 857_739_168
        ),
    ]

    public static var defaultModel: SummarizationModel {
        model(for: defaultModelID) ?? all[0]
    }

    public static func model(for id: String?) -> SummarizationModel? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    public static func displayName(for id: String) -> String {
        model(for: id)?.displayName ?? id
    }
}
