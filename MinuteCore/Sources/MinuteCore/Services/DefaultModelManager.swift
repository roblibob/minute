import CryptoKit
import Foundation
import os

/// Downloads and verifies required local model files under Application Support.
///<
/// Networking must only be used for model downloads.
public actor DefaultModelManager: ModelManaging {
    public struct ModelSpec: Sendable, Equatable {
        public var id: String
        public var destinationURL: URL
        public var sourceURL: URL
        public var expectedSHA256Hex: String
        public var expectedFileSizeBytes: Int64?

        public init(
            id: String,
            destinationURL: URL,
            sourceURL: URL,
            expectedSHA256Hex: String,
            expectedFileSizeBytes: Int64? = nil
        ) {
            self.id = id
            self.destinationURL = destinationURL
            self.sourceURL = sourceURL
            self.expectedSHA256Hex = expectedSHA256Hex
            self.expectedFileSizeBytes = expectedFileSizeBytes
        }
    }

    private struct ChecksumMarker: Codable {
        var expectedSHA256Hex: String
        var verifiedSHA256Hex: String
    }

    private let requiredModelsOverride: [ModelSpec]?
    private let selectionStore: SummarizationModelSelectionStore
    private let logger = Logger(subsystem: "roblibob.Minute", category: "models")

    public init(
        requiredModels: [ModelSpec]? = nil,
        selectionStore: SummarizationModelSelectionStore = SummarizationModelSelectionStore()
    ) {
        self.requiredModelsOverride = requiredModels
        self.selectionStore = selectionStore
    }

    public func ensureModelsPresent(progress: (@Sendable (ModelDownloadProgress) -> Void)? = nil) async throws {
        let requiredModels = resolvedRequiredModels()

        // Ensure the app is configured with pinned URLs + checksums.
        for spec in requiredModels {
            if spec.expectedSHA256Hex == "REPLACE_ME" || spec.expectedSHA256Hex.isEmpty || spec.sourceURL.absoluteString.contains("REPLACE_ME") {
                throw MinuteError.modelDownloadFailed(underlyingDescription: "Model pinning not configured for \(spec.id). Please set pinned URL + SHA-256.")
            }
        }

        let fileManager = FileManager.default
        let missing = requiredModels.filter { !fileManager.fileExists(atPath: $0.destinationURL.path) }
        if missing.isEmpty {
            progress?(ModelDownloadProgress(fractionCompleted: 1, label: "Models present"))
            return
        }

        let total = missing.count
        var completed = 0

        for spec in missing {
            try Task.checkCancellation()

            logger.info("Downloading model \(spec.id, privacy: .public) from \(spec.sourceURL.absoluteString, privacy: .public)")

            let label = "Downloading \(spec.id)"

            // Ensure destination folder exists.
            try fileManager.createDirectory(at: spec.destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)

            let tempURL = fileManager.temporaryDirectory.appendingPathComponent("minute-model-\(UUID().uuidString)")

            do {
                let completedSoFar = completed
                let downloadedURL = try await download(from: spec.sourceURL, to: tempURL) { fileFraction in
                    let overall = (Double(completedSoFar) + fileFraction) / Double(total)
                    progress?(ModelDownloadProgress(fractionCompleted: overall, label: label))
                }

                // Verify SHA-256.
                let sha = try sha256Hex(of: downloadedURL)
                if sha.lowercased() != spec.expectedSHA256Hex.lowercased() {
                    try? fileManager.removeItem(at: downloadedURL)
                    throw MinuteError.modelChecksumMismatch
                }

                // Optional: verify file size.
                if let expectedSize = spec.expectedFileSizeBytes {
                    let attrs = try fileManager.attributesOfItem(atPath: downloadedURL.path)
                    let size = (attrs[.size] as? NSNumber)?.int64Value
                    if size != expectedSize {
                        try? fileManager.removeItem(at: downloadedURL)
                        throw MinuteError.modelChecksumMismatch
                    }
                }

                // Materialize the verified artifact.
                if spec.sourceURL.pathExtension.lowercased() == "zip", spec.destinationURL.pathExtension.lowercased() == "mlmodelc" {
                    // Special case: Core ML encoder distributed as a .zip containing a .mlmodelc directory.
                    // (whisper.cpp will look for `<model>-encoder.mlmodelc` next to the ggml model file).
                    try extractZipModel(at: downloadedURL, to: spec.destinationURL, expectedSHA256Hex: spec.expectedSHA256Hex)
                } else {
                    // Atomically move into place (best-effort replace).
                    if fileManager.fileExists(atPath: spec.destinationURL.path) {
                        try? fileManager.removeItem(at: spec.destinationURL)
                    }
                    try? fileManager.removeItem(at: checksumMarkerURL(for: spec.destinationURL))
                    try fileManager.moveItem(at: downloadedURL, to: spec.destinationURL)
                    try writeChecksumMarker(
                        for: spec.destinationURL,
                        expectedSHA256Hex: spec.expectedSHA256Hex,
                        verifiedSHA256Hex: sha
                    )
                }

                completed += 1
                let overall = Double(completed) / Double(total)
                progress?(ModelDownloadProgress(fractionCompleted: overall, label: "Downloaded \(spec.id)"))
            } catch let minuteError as MinuteError {
                // Ensure temp is gone.
                try? fileManager.removeItem(at: tempURL)
                throw minuteError
            } catch {
                try? fileManager.removeItem(at: tempURL)
                throw MinuteError.modelDownloadFailed(underlyingDescription: String(describing: error))
            }
        }

        progress?(ModelDownloadProgress(fractionCompleted: 1, label: "Models ready"))
    }

    public func validateModels() async throws -> ModelValidationResult {
        let requiredModels = resolvedRequiredModels()
        let fileManager = FileManager.default
        var missing: [String] = []
        var invalid: [String] = []

        for spec in requiredModels {
            if isDirectoryModel(spec) {
                var isDir: ObjCBool = false
                guard fileManager.fileExists(atPath: spec.destinationURL.path, isDirectory: &isDir) else {
                    missing.append(spec.id)
                    continue
                }

                guard isDir.boolValue else {
                    invalid.append(spec.id)
                    continue
                }

                let marker: ChecksumMarker?
                do {
                    marker = try readChecksumMarker(for: spec.destinationURL)
                } catch {
                    invalid.append(spec.id)
                    continue
                }

                guard let marker,
                      marker.expectedSHA256Hex.lowercased() == spec.expectedSHA256Hex.lowercased()
                else {
                    invalid.append(spec.id)
                    continue
                }

                do {
                    let current = try directoryChecksumHex(of: spec.destinationURL)
                    if current.lowercased() != marker.verifiedSHA256Hex.lowercased() {
                        invalid.append(spec.id)
                    }
                } catch {
                    invalid.append(spec.id)
                }
            } else {
                guard fileManager.fileExists(atPath: spec.destinationURL.path) else {
                    missing.append(spec.id)
                    continue
                }

                do {
                    let sha = try sha256Hex(of: spec.destinationURL)
                    if sha.lowercased() != spec.expectedSHA256Hex.lowercased() {
                        invalid.append(spec.id)
                        continue
                    }

                    if let expectedSize = spec.expectedFileSizeBytes {
                        let attrs = try fileManager.attributesOfItem(atPath: spec.destinationURL.path)
                        let size = (attrs[.size] as? NSNumber)?.int64Value
                        if size != expectedSize {
                            invalid.append(spec.id)
                        }
                    }
                } catch {
                    invalid.append(spec.id)
                }
            }
        }

        return ModelValidationResult(missingModelIDs: missing, invalidModelIDs: invalid)
    }

    public func removeModels(withIDs ids: [String]) async throws {
        let requiredModels = resolvedRequiredModels()
        let fileManager = FileManager.default

        for spec in requiredModels where ids.contains(spec.id) {
            if fileManager.fileExists(atPath: spec.destinationURL.path) {
                do {
                    try fileManager.removeItem(at: spec.destinationURL)
                } catch {
                    throw MinuteError.modelDownloadFailed(underlyingDescription: "Failed to remove model \(spec.id): \(error)")
                }
            }

            try? fileManager.removeItem(at: checksumMarkerURL(for: spec.destinationURL))
        }
    }

    // MARK: - Defaults

    /// Default pinned model list.
    public static func defaultRequiredModels(selectedSummarizationModelID: String? = nil) -> [ModelSpec] {
        let whisperURL = WhisperModelPaths.defaultBaseModelURL
        let whisperCoreMLEncoderURL = WhisperModelPaths.defaultBaseEncoderCoreMLURL
        let summarizationModel = SummarizationModelCatalog.model(for: selectedSummarizationModelID) ?? SummarizationModelCatalog.defaultModel

        var models: [ModelSpec] = [
            // Whisper (multilingual)
            ModelSpec(
                id: "whisper/base",
                destinationURL: whisperURL,
                sourceURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin")!,
                expectedSHA256Hex: "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe"
            ),

            // Optional Whisper Core ML encoder (required by some whisper.cpp builds on Apple platforms).
            // Downloaded as a .zip and extracted into a `.mlmodelc` directory.
            ModelSpec(
                id: "whisper/base-encoder-coreml",
                destinationURL: whisperCoreMLEncoderURL,
                sourceURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base-encoder.mlmodelc.zip")!,
                expectedSHA256Hex: "7e6ab77041942572f239b5b602f8aaa1c3ed29d73e3d8f20abea03a773541089"
            ),

            // LLM (GGUF)
            ModelSpec(
                id: summarizationModel.id,
                destinationURL: summarizationModel.destinationURL,
                sourceURL: summarizationModel.sourceURL,
                expectedSHA256Hex: summarizationModel.expectedSHA256Hex,
                expectedFileSizeBytes: summarizationModel.expectedFileSizeBytes
            ),
        ]

        if let mmprojURL = summarizationModel.mmprojDestinationURL,
           let mmprojSourceURL = summarizationModel.mmprojSourceURL,
           let mmprojExpectedSHA256Hex = summarizationModel.mmprojExpectedSHA256Hex {
            models.append(
                ModelSpec(
                    id: "\(summarizationModel.id)/mmproj",
                    destinationURL: mmprojURL,
                    sourceURL: mmprojSourceURL,
                    expectedSHA256Hex: mmprojExpectedSHA256Hex,
                    expectedFileSizeBytes: summarizationModel.mmprojExpectedFileSizeBytes
                )
            )
        }

        return models
    }

    private func resolvedRequiredModels() -> [ModelSpec] {
        if let requiredModelsOverride {
            return requiredModelsOverride
        }

        let selectedID = selectionStore.selectedModelID()
        return DefaultModelManager.defaultRequiredModels(selectedSummarizationModelID: selectedID)
    }

    // MARK: - Download + hashing

    private func isDirectoryModel(_ spec: ModelSpec) -> Bool {
        spec.destinationURL.pathExtension.lowercased() == "mlmodelc"
    }

    private func checksumMarkerURL(for destinationURL: URL) -> URL {
        destinationURL.appendingPathExtension("sha256")
    }

    private func writeChecksumMarker(
        for destinationURL: URL,
        expectedSHA256Hex: String,
        verifiedSHA256Hex: String
    ) throws {
        let marker = ChecksumMarker(
            expectedSHA256Hex: expectedSHA256Hex,
            verifiedSHA256Hex: verifiedSHA256Hex
        )

        let data = try JSONEncoder().encode(marker)
        try data.write(to: checksumMarkerURL(for: destinationURL), options: [.atomic])
    }

    private func readChecksumMarker(for destinationURL: URL) throws -> ChecksumMarker? {
        let url = checksumMarkerURL(for: destinationURL)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ChecksumMarker.self, from: data)
    }

    private func download(from sourceURL: URL, to destinationURL: URL, onProgress: (@Sendable (Double) -> Void)?) async throws -> URL {
        final class Coordinator: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
            let destinationURL: URL
            let onProgress: (@Sendable (Double) -> Void)?
            var continuation: CheckedContinuation<URL, Error>?

            init(destinationURL: URL, onProgress: (@Sendable (Double) -> Void)?) {
                self.destinationURL = destinationURL
                self.onProgress = onProgress
            }

            func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
                guard totalBytesExpectedToWrite > 0 else { return }
                let f = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
                onProgress?(min(max(f, 0), 1))
            }

            func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
                do {
                    // Replace any existing temp file.
                    try? FileManager.default.removeItem(at: destinationURL)
                    try FileManager.default.moveItem(at: location, to: destinationURL)
                    continuation?.resume(returning: destinationURL)
                    continuation = nil
                } catch {
                    continuation?.resume(throwing: error)
                    continuation = nil
                }
            }

            func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
                if let error {
                    continuation?.resume(throwing: error)
                    continuation = nil
                }
            }
        }

        let coordinator = Coordinator(destinationURL: destinationURL, onProgress: onProgress)
        let session = URLSession(configuration: .default, delegate: coordinator, delegateQueue: nil)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            coordinator.continuation = continuation
            let task = session.downloadTask(with: sourceURL)
            task.resume()
        }
    }

    private func sha256Hex(of fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            let chunk = try handle.read(upToCount: 1024 * 1024)
            guard let chunk, !chunk.isEmpty else { break }
            hasher.update(data: chunk)
        }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func directoryChecksumHex(of directoryURL: URL) throws -> String {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: directoryURL, includingPropertiesForKeys: [.isRegularFileKey]) else {
            throw MinuteError.modelDownloadFailed(underlyingDescription: "Failed to read model directory for checksum.")
        }

        var files: [URL] = []
        for case let fileURL as URL in enumerator {
            let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
            if values.isRegularFile == true {
                files.append(fileURL)
            }
        }

        files.sort { $0.path < $1.path }

        var hasher = SHA256()
        let basePath = directoryURL.path

        for fileURL in files {
            let relativePath = fileURL.path.replacingOccurrences(of: basePath + "/", with: "")
            if let pathData = relativePath.data(using: .utf8) {
                hasher.update(data: pathData)
            }

            let handle = try FileHandle(forReadingFrom: fileURL)
            defer { try? handle.close() }

            while true {
                let chunk = try handle.read(upToCount: 1024 * 1024)
                guard let chunk, !chunk.isEmpty else { break }
                hasher.update(data: chunk)
            }
        }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func extractZipModel(at zipURL: URL, to destinationDirectoryURL: URL, expectedSHA256Hex: String) throws {
        let fileManager = FileManager.default

        // Extract into a temporary directory first.
        let tempRoot = fileManager.temporaryDirectory
            .appendingPathComponent("minute-model-unzip-\(UUID().uuidString)", isDirectory: true)

        try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempRoot) }

        // Use `ditto` because it's available on macOS and handles `.zip` reliably.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", zipURL.path, tempRoot.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            throw MinuteError.modelDownloadFailed(underlyingDescription: "Failed to launch ditto for zip extraction: \(error)")
        }

        process.waitUntilExit()

        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw MinuteError.modelDownloadFailed(underlyingDescription: "Zip extraction failed (exit=\(process.terminationStatus)).\n\(output)")
        }

        // Prefer the expected directory name (most zips contain a single top-level `.mlmodelc` directory).
        var extractedDir = tempRoot.appendingPathComponent(destinationDirectoryURL.lastPathComponent, isDirectory: true)

        if !fileManager.fileExists(atPath: extractedDir.path) {
            // Fallback: pick the first `.mlmodelc` directory under the extracted root.
            let contents = try fileManager.contentsOfDirectory(at: tempRoot, includingPropertiesForKeys: nil)
            if let first = contents.first(where: { $0.pathExtension.lowercased() == "mlmodelc" }) {
                extractedDir = first
            } else {
                throw MinuteError.modelDownloadFailed(underlyingDescription: "Zip extraction produced no .mlmodelc directory")
            }
        }

        // Atomically replace the destination directory.
        if fileManager.fileExists(atPath: destinationDirectoryURL.path) {
            try? fileManager.removeItem(at: destinationDirectoryURL)
        }

        try fileManager.createDirectory(at: destinationDirectoryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.moveItem(at: extractedDir, to: destinationDirectoryURL)

        do {
            let verifiedSHA = try directoryChecksumHex(of: destinationDirectoryURL)
            try writeChecksumMarker(
                for: destinationDirectoryURL,
                expectedSHA256Hex: expectedSHA256Hex,
                verifiedSHA256Hex: verifiedSHA
            )
        } catch {
            try? fileManager.removeItem(at: destinationDirectoryURL)
            throw MinuteError.modelDownloadFailed(underlyingDescription: "Failed to verify extracted model: \(error)")
        }

        // Cleanup the downloaded zip.
        try? fileManager.removeItem(at: zipURL)
    }
}
