import Combine
import Foundation
import MinuteCore

@MainActor
final class ModelsSettingsViewModel: ObservableObject {
    enum State: Equatable {
        case checking
        case ready
        case needsDownload(message: String?)
        case downloading(progress: ModelDownloadProgress?)
    }

    @Published private(set) var state: State = .checking

    private let modelManager: any ModelManaging
    private var modelTask: Task<Void, Never>?

    init(modelManager: any ModelManaging = DefaultModelManager()) {
        self.modelManager = modelManager
        refresh()
    }

    deinit {
        modelTask?.cancel()
    }

    func refresh() {
        Task { await refreshModelsStatus() }
    }

    func startDownload() {
        modelTask?.cancel()
        state = .downloading(progress: ModelDownloadProgress(fractionCompleted: 0, label: "Starting download"))

        modelTask = Task { [weak self] in
            guard let self else { return }

            do {
                let validation = try await modelManager.validateModels()
                if !validation.invalidModelIDs.isEmpty {
                    try await modelManager.removeModels(withIDs: validation.invalidModelIDs)
                }

                try await modelManager.ensureModelsPresent { [weak self] update in
                    Task { @MainActor [weak self] in
                        self?.state = .downloading(progress: update)
                    }
                }

                state = .checking
                await refreshModelsStatus()
            } catch {
                let message = (error as? MinuteError)?.errorDescription ?? String(describing: error)
                state = .needsDownload(message: message)
            }
        }
    }

    private func refreshModelsStatus() async {
        if case .downloading = state {
            return
        }

        state = .checking

        do {
            let result = try await modelManager.validateModels()
            if result.isReady {
                state = .ready
            } else {
                state = .needsDownload(message: modelMessage(from: result))
            }
        } catch {
            let message = (error as? MinuteError)?.errorDescription ?? String(describing: error)
            state = .needsDownload(message: message)
        }
    }

    private func modelMessage(from result: ModelValidationResult) -> String {
        if result.missingModelIDs.isEmpty && result.invalidModelIDs.isEmpty {
            return "Models ready."
        }

        var parts: [String] = []
        if !result.missingModelIDs.isEmpty {
            parts.append("Missing: \(result.missingModelIDs.joined(separator: ", "))")
        }
        if !result.invalidModelIDs.isEmpty {
            parts.append("Invalid: \(result.invalidModelIDs.joined(separator: ", "))")
        }
        return parts.joined(separator: " ")
    }
}
