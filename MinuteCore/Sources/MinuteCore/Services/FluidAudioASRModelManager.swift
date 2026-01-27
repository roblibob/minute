@preconcurrency import FluidAudio
import Foundation
import os

public struct FluidAudioASRModelManager: ModelManaging, @unchecked Sendable {
    private let selectionStore: FluidAudioASRModelSelectionStore
    private let logger = Logger(subsystem: "roblibob.Minute", category: "fluidaudio.models")

    public init(selectionStore: FluidAudioASRModelSelectionStore = FluidAudioASRModelSelectionStore()) {
        self.selectionStore = selectionStore
    }

    public func ensureModelsPresent(progress: (@Sendable (ModelDownloadProgress) -> Void)?) async throws {
        let model = selectionStore.selectedModel()
        let version = FluidAudioASRVersionResolver.version(for: model.versionKey)

        progress?(ModelDownloadProgress(fractionCompleted: 0, label: "Downloading \(model.displayName)"))

        do {
            try await AsrModels.download(version: version)
            progress?(ModelDownloadProgress(fractionCompleted: 1, label: "Downloaded \(model.displayName)"))
        } catch {
            logger.error("Failed to download FluidAudio ASR models: \(ErrorHandler.debugMessage(for: error), privacy: .public)")
            throw MinuteError.modelDownloadFailed(underlyingDescription: ErrorHandler.debugMessage(for: error))
        }
    }

    public func validateModels() async throws -> ModelValidationResult {
        let model = selectionStore.selectedModel()
        let version = FluidAudioASRVersionResolver.version(for: model.versionKey)

        let cacheDir = AsrModels.defaultCacheDirectory(for: version)
        let exists = AsrModels.modelsExist(at: cacheDir, version: version)
        guard exists else {
            return ModelValidationResult(missingModelIDs: [model.id], invalidModelIDs: [])
        }
        return ModelValidationResult(missingModelIDs: [], invalidModelIDs: [])
    }

    public func removeModels(withIDs ids: [String]) async throws {
        let model = selectionStore.selectedModel()
        guard ids.contains(model.id) else { return }

        let version = FluidAudioASRVersionResolver.version(for: model.versionKey)
        let cacheDir = AsrModels.defaultCacheDirectory(for: version)
        if FileManager.default.fileExists(atPath: cacheDir.path) {
            do {
                try FileManager.default.removeItem(at: cacheDir)
            } catch {
                throw MinuteError.modelDownloadFailed(
                    underlyingDescription: "Failed to remove FluidAudio model \(model.id): \(error)"
                )
            }
        }
    }
}
