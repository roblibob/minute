import Testing
import Foundation
@testable import MinuteCore

struct DefaultModelManagerTests {
    @Test
    func ensureModelsPresent_downloadsFileURLAndVerifiesSHA() async throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("minute-model-manager-tests-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        // Create a local "source" file.
        let sourceURL = tempDir.appendingPathComponent("source.bin")
        let content = Data("hello".utf8)
        try content.write(to: sourceURL, options: [.atomic])

        // Destination file path (does not exist).
        let destinationURL = tempDir.appendingPathComponent("dest.bin")

        // Compute expected SHA-256 for "hello".
        let expectedSHA = "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"

        let manager = DefaultModelManager(
            requiredModels: [
                DefaultModelManager.ModelSpec(
                    id: "test",
                    destinationURL: destinationURL,
                    sourceURL: sourceURL,
                    expectedSHA256Hex: expectedSHA
                ),
            ]
        )

        try await manager.ensureModelsPresent(progress: Optional<(@Sendable (ModelDownloadProgress) -> Void)>.none)

        #expect(fm.fileExists(atPath: destinationURL.path))
        let written = try Data(contentsOf: destinationURL)
        expectEqual(written, content)
    }

    @Test
    func ensureModelsPresent_whenSHAMismatches_throwsChecksumMismatchAndDoesNotLeaveFile() async throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("minute-model-manager-tests-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        let sourceURL = tempDir.appendingPathComponent("source.bin")
        try Data("hello".utf8).write(to: sourceURL, options: [.atomic])

        let destinationURL = tempDir.appendingPathComponent("dest.bin")

        let manager = DefaultModelManager(
            requiredModels: [
                DefaultModelManager.ModelSpec(
                    id: "test",
                    destinationURL: destinationURL,
                    sourceURL: sourceURL,
                    expectedSHA256Hex: "deadbeef"
                ),
            ]
        )

        do {
            try await manager.ensureModelsPresent(progress: Optional<(@Sendable (ModelDownloadProgress) -> Void)>.none)
            #expect(Bool(false))
        } catch let err as MinuteError {
            switch err {
            case .modelChecksumMismatch:
                break
            default:
                #expect(Bool(false))
            }
        }

        #expect(!fm.fileExists(atPath: destinationURL.path))
    }

    @Test
    func validateModels_usesChecksumMarkerFastPath_butStillDetectsSizeMismatch() async throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("minute-model-manager-tests-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        let sourceURL = tempDir.appendingPathComponent("source.bin")
        let content = Data("hello".utf8)
        try content.write(to: sourceURL, options: [.atomic])

        let destinationURL = tempDir.appendingPathComponent("dest.bin")
        let expectedSHA = "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"

        let manager = DefaultModelManager(
            requiredModels: [
                DefaultModelManager.ModelSpec(
                    id: "test",
                    destinationURL: destinationURL,
                    sourceURL: sourceURL,
                    expectedSHA256Hex: expectedSHA,
                    expectedFileSizeBytes: Int64(content.count)
                ),
            ]
        )

        try await manager.ensureModelsPresent(progress: Optional<(@Sendable (ModelDownloadProgress) -> Void)>.none)

        let ready = try await manager.validateModels()
        #expect(ready.isReady)

        // Mutate the file so its size no longer matches the pinned spec.
        try Data("hello!".utf8).write(to: destinationURL, options: [.atomic])

        let afterMutation = try await manager.validateModels()
        #expect(afterMutation.missingModelIDs.isEmpty)
        #expect(afterMutation.invalidModelIDs.contains("test"))
    }

    @Test
    func defaultRequiredModels_usesSelectedTranscriptionModel() {
        let models = DefaultModelManager.defaultRequiredModels(
            selectedSummarizationModelID: nil,
            selectedTranscriptionModelID: "whisper/base",
            transcriptionBackend: .whisper
        )

        #expect(models.contains { $0.id == "whisper/base" })
    }

    @Test
    func defaultRequiredModels_excludesWhisperWhenFluidAudioSelected() {
        let models = DefaultModelManager.defaultRequiredModels(
            selectedSummarizationModelID: nil,
            selectedTranscriptionModelID: "whisper/base",
            transcriptionBackend: .fluidAudio
        )

        #expect(!models.contains { $0.id.hasPrefix("whisper/") })
        #expect(models.contains { $0.id.hasPrefix("llm/") })
    }
}
