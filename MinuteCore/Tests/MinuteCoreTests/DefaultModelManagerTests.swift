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

    @Test
    func defaultRequiredModels_skipsVisionArtifactsWhenScreenContextDisabled() {
        let visionModel = SummarizationModelCatalog.all.first { $0.mmprojDestinationURL != nil } ?? SummarizationModelCatalog.defaultModel
        let summarizationModel = SummarizationModelCatalog.all.first { $0.id != visionModel.id }
            ?? SummarizationModelCatalog.defaultModel

        let models = DefaultModelManager.defaultRequiredModels(
            selectedSummarizationModelID: summarizationModel.id,
            summarizationProvider: .builtIn,
            selectedVisionModelID: visionModel.id,
            visionProvider: .builtIn,
            screenContextEnabled: false,
            selectedTranscriptionModelID: "whisper/base",
            transcriptionBackend: .whisper
        )

        #expect(!models.contains { $0.id == visionModel.id })
        #expect(!models.contains { $0.id == "\(visionModel.id)/mmproj" })
    }

    @Test
    func validateModels_mergesFluidAudioVocabularyReadinessWhenFluidBackendSelected() async throws {
        let suite = "DefaultModelManagerTests.validateModels.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let backendStore = TranscriptionBackendSelectionStore(defaults: defaults, key: "backend")
        backendStore.setSelectedBackendID(TranscriptionBackend.fluidAudio.rawValue)

        let spy = SpyFluidAudioModelManager(
            validationResult: ModelValidationResult(
                missingModelIDs: ["fluidaudio/asr-v3-ctc-vocab"],
                invalidModelIDs: []
            )
        )
        let manager = DefaultModelManager(
            transcriptionBackendStore: backendStore,
            fluidAudioModelManager: spy
        )

        let result = try await manager.validateModels()
        #expect(result.missingModelIDs.contains("fluidaudio/asr-v3-ctc-vocab"))
    }

    @Test
    func removeModels_forwardsCtcVocabularyIDsToFluidAudioModelManager() async throws {
        let suite = "DefaultModelManagerTests.removeModels.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)

        let backendStore = TranscriptionBackendSelectionStore(defaults: defaults, key: "backend")
        backendStore.setSelectedBackendID(TranscriptionBackend.fluidAudio.rawValue)

        let spy = SpyFluidAudioModelManager(validationResult: ModelValidationResult(missingModelIDs: [], invalidModelIDs: []))
        let manager = DefaultModelManager(
            requiredModels: [],
            transcriptionBackendStore: backendStore,
            fluidAudioModelManager: spy
        )

        try await manager.removeModels(withIDs: ["fluidaudio/asr-v3-ctc-vocab"])
        let removed = await spy.removedIDs
        #expect(removed.contains("fluidaudio/asr-v3-ctc-vocab"))
    }
}

actor SpyFluidAudioModelManager: FluidAudioModelManaging {
    private(set) var removedIDs: [String] = []
    private let validationResult: ModelValidationResult

    init(validationResult: ModelValidationResult) {
        self.validationResult = validationResult
    }

    func ensureModelsPresent(progress: (@Sendable (ModelDownloadProgress) -> Void)?) async throws {
        progress?(ModelDownloadProgress(fractionCompleted: 1, label: "ready"))
    }

    func validateModels() async throws -> ModelValidationResult {
        validationResult
    }

    func removeModels(withIDs ids: [String]) async throws {
        removedIDs.append(contentsOf: ids)
    }
}
