import Foundation

public struct TranscriptionModel: Sendable, Equatable, Identifiable {
    public var id: String
    public var displayName: String
    public var summary: String
    public var fileName: String
    public var sourceURL: URL
    public var expectedSHA256Hex: String
    public var expectedFileSizeBytes: Int64?
    public var encoderCoreMLSourceURL: URL?
    public var encoderCoreMLExpectedSHA256Hex: String?
    public var encoderCoreMLExpectedFileSizeBytes: Int64?

    public init(
        id: String,
        displayName: String,
        summary: String,
        fileName: String,
        sourceURL: URL,
        expectedSHA256Hex: String,
        expectedFileSizeBytes: Int64? = nil,
        encoderCoreMLSourceURL: URL? = nil,
        encoderCoreMLExpectedSHA256Hex: String? = nil,
        encoderCoreMLExpectedFileSizeBytes: Int64? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.summary = summary
        self.fileName = fileName
        self.sourceURL = sourceURL
        self.expectedSHA256Hex = expectedSHA256Hex
        self.expectedFileSizeBytes = expectedFileSizeBytes
        self.encoderCoreMLSourceURL = encoderCoreMLSourceURL
        self.encoderCoreMLExpectedSHA256Hex = encoderCoreMLExpectedSHA256Hex
        self.encoderCoreMLExpectedFileSizeBytes = encoderCoreMLExpectedFileSizeBytes
    }

    public var destinationURL: URL {
        WhisperModelPaths.modelURL(fileName: fileName)
    }

    public var encoderCoreMLDestinationURL: URL? {
        guard encoderCoreMLSourceURL != nil, encoderCoreMLExpectedSHA256Hex != nil else { return nil }
        let baseName = fileName.replacingOccurrences(of: ".bin", with: "")
        let encoderName = "\(baseName)-encoder.mlmodelc"
        return WhisperModelPaths.modelURL(fileName: encoderName)
    }
}

public enum TranscriptionModelCatalog {
    public static let defaultModelID = "whisper/base"

    private static let baseModel = TranscriptionModel(
        id: "whisper/base",
        displayName: "Whisper Base (multilingual)",
        summary: "Small, fast, and solid accuracy for mixed-language meetings.",
        fileName: "ggml-base.bin",
        sourceURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin")!,
        expectedSHA256Hex: "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe",
        encoderCoreMLSourceURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base-encoder.mlmodelc.zip")!,
        encoderCoreMLExpectedSHA256Hex: "7e6ab77041942572f239b5b602f8aaa1c3ed29d73e3d8f20abea03a773541089"
    )

    private static let largeV3Turbo = TranscriptionModel(
        id: "whisper/large-v3-turbo",
        displayName: "Whisper Large V3 Turbo",
        summary: "Higher accuracy with a larger download. Good for noisy meetings.",
        fileName: "ggml-large-v3-turbo.bin",
        sourceURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin")!,
        expectedSHA256Hex: "1fc70f774d38eb169993ac391eea357ef47c88757ef72ee5943879b7e8e2bc69",
        expectedFileSizeBytes: 1_624_555_275,
        encoderCoreMLSourceURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-encoder.mlmodelc.zip")!,
        encoderCoreMLExpectedSHA256Hex: "84bedfe895bd7b5de6e8e89a0803dfc5addf8c0c5bc4c937451716bf7cf7988a",
        encoderCoreMLExpectedFileSizeBytes: 1_173_393_014
    )

    // MARK: - NB-Whisper (Norwegian)

    private static let nbWhisperSmall = TranscriptionModel(
        id: "nb-whisper/small",
        displayName: "NB-Whisper Small (Norwegian)",
        summary: "Norwegian-tuned model by NB AI-Lab. Fast with good accuracy for Norwegian.",
        fileName: "nb-whisper-small.bin",
        sourceURL: URL(string: "https://huggingface.co/NbAiLab/nb-whisper-small/resolve/main/ggml-model.bin")!,
        expectedSHA256Hex: "a0fc1555f5bd51044b0ea88bb9b7891e1ee331a8087eddb0afc3a05839db48ab",
        expectedFileSizeBytes: 487_601_984
    )

    private static let nbWhisperMedium = TranscriptionModel(
        id: "nb-whisper/medium",
        displayName: "NB-Whisper Medium (Norwegian)",
        summary: "Norwegian-tuned model by NB AI-Lab. Better accuracy, larger download.",
        fileName: "nb-whisper-medium.bin",
        sourceURL: URL(string: "https://huggingface.co/NbAiLab/nb-whisper-medium/resolve/main/ggml-model.bin")!,
        expectedSHA256Hex: "f73141401d203ee77fc7ddf7bf97926a8a85fe85faa6066a6920e4815f48a73d",
        expectedFileSizeBytes: 1_533_763_076
    )

    private static let nbWhisperLarge = TranscriptionModel(
        id: "nb-whisper/large",
        displayName: "NB-Whisper Large (Norwegian)",
        summary: "Norwegian-tuned model by NB AI-Lab. Best accuracy for Norwegian speech.",
        fileName: "nb-whisper-large.bin",
        sourceURL: URL(string: "https://huggingface.co/NbAiLab/nb-whisper-large/resolve/main/ggml-model.bin")!,
        expectedSHA256Hex: "0f2f66f22e11a7c7da3c582d8e5c89cb2c0011753ba9c7c9731e320a4ba33e76",
        expectedFileSizeBytes: 3_095_033_483
    )

    public static var all: [TranscriptionModel] {
        var models = [baseModel, nbWhisperSmall, nbWhisperMedium, nbWhisperLarge]
        if isLargeModelEnabled {
            models.append(largeV3Turbo)
        }
        return models
    }

    public static var defaultModel: TranscriptionModel {
        model(for: defaultModelID) ?? baseModel
    }

    public static func model(for id: String?) -> TranscriptionModel? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    public static func displayName(for id: String) -> String {
        model(for: id)?.displayName ?? id
    }

    private static var isLargeModelEnabled: Bool {
#if DEBUG
        return ProcessInfo.processInfo.environment["MINUTE_ENABLE_LARGE_WHISPER"] == "1"
#else
        return false
#endif
    }
}
