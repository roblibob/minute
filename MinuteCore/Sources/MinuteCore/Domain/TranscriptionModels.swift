import Foundation

public struct TranscriptionModel: Sendable, Equatable, Identifiable {
    public var id: String
    public var displayName: String
    public var summary: String
    public var fileName: String
    public var sourceURL: URL
    public var expectedSHA256Hex: String
    public var expectedFileSizeBytes: Int64?

    public init(
        id: String,
        displayName: String,
        summary: String,
        fileName: String,
        sourceURL: URL,
        expectedSHA256Hex: String,
        expectedFileSizeBytes: Int64? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.summary = summary
        self.fileName = fileName
        self.sourceURL = sourceURL
        self.expectedSHA256Hex = expectedSHA256Hex
        self.expectedFileSizeBytes = expectedFileSizeBytes
    }

    public var destinationURL: URL {
        WhisperModelPaths.modelURL(fileName: fileName)
    }
}

public enum TranscriptionModelCatalog {
    public static let defaultModelID = "whisper/base"

    public static let all: [TranscriptionModel] = [
        TranscriptionModel(
            id: "whisper/base",
            displayName: "Whisper Base (multilingual)",
            summary: "Small, fast, and solid accuracy for mixed-language meetings.",
            fileName: "ggml-base.bin",
            sourceURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin")!,
            expectedSHA256Hex: "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe"
        ),
        TranscriptionModel(
            id: "whisper/large-v3-turbo",
            displayName: "Whisper Large V3 Turbo",
            summary: "Higher accuracy with a larger download. Good for noisy meetings.",
            fileName: "ggml-large-v3-turbo.bin",
            sourceURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin")!,
            expectedSHA256Hex: "1fc70f774d38eb169993ac391eea357ef47c88757ef72ee5943879b7e8e2bc69",
            expectedFileSizeBytes: 1_624_555_275
        ),
    ]

    public static var defaultModel: TranscriptionModel {
        model(for: defaultModelID) ?? all[0]
    }

    public static func model(for id: String?) -> TranscriptionModel? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    public static func displayName(for id: String) -> String {
        model(for: id)?.displayName ?? id
    }
}
