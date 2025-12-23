import AVFoundation
import Combine
import CoreGraphics
import Foundation
import MinuteCore

@MainActor
final class OnboardingViewModel: ObservableObject {
    enum Step: Int, CaseIterable {
        case intro
        case permissions
        case models
        case vault
        case complete
    }

    enum ModelsState: Equatable {
        case checking
        case ready
        case needsDownload(message: String?)
        case downloading(progress: ModelDownloadProgress?)
    }

    @Published private(set) var currentStep: Step = .intro
    @Published private(set) var microphonePermissionGranted = false
    @Published private(set) var screenRecordingPermissionGranted = false
    @Published private(set) var vaultConfigured = false
    @Published private(set) var modelsState: ModelsState = .checking
    @Published var selectedSummarizationModelID: String {
        didSet {
            guard oldValue != selectedSummarizationModelID else { return }
            summarizationModelStore.setSelectedModelID(selectedSummarizationModelID)
            Task { await refreshModelsStatus() }
        }
    }

    private let modelManager: any ModelManaging
    private let vaultAccess: VaultAccess
    private let defaults: UserDefaults
    private let summarizationModelStore: SummarizationModelSelectionStore

    private var defaultsObserver: AnyCancellable?
    private var modelTask: Task<Void, Never>?

    private enum DefaultsKey {
        static let didShowIntro = "didShowOnboardingIntro"
        static let didCompleteOnboarding = "didCompleteOnboarding"
        static let lastStep = "onboardingLastStep"
        static let didSkipPermissions = "didSkipOnboardingPermissions"
        static let vaultRootBookmark = "vaultRootBookmark"
        static let debugBuildStamp = "onboardingDebugBuildStamp"
    }

    init(
        modelManager: (any ModelManaging)? = nil,
        defaults: UserDefaults = .standard,
        summarizationModelStore: SummarizationModelSelectionStore? = nil
    ) {
        let store = summarizationModelStore ?? SummarizationModelSelectionStore(defaults: defaults)
        self.modelManager = modelManager ?? DefaultModelManager(selectionStore: store)
        self.defaults = defaults
        self.summarizationModelStore = store
        let selectedModel = store.selectedModel()
        self.selectedSummarizationModelID = selectedModel.id
        if store.selectedModelID() != selectedModel.id {
            store.setSelectedModelID(selectedModel.id)
        }
        let bookmarkStore = UserDefaultsVaultBookmarkStore(defaults: defaults, key: DefaultsKey.vaultRootBookmark)
        self.vaultAccess = VaultAccess(bookmarkStore: bookmarkStore)

        resetForDebugBuildIfNeeded()
        refreshAll()

        defaultsObserver = NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshVaultStatus()
            }
    }

    deinit {
        modelTask?.cancel()
    }

    var permissionsReady: Bool {
        microphonePermissionGranted && screenRecordingPermissionGranted
    }

    var modelsReady: Bool {
        if case .ready = modelsState {
            return true
        }
        return false
    }

    var requirementsMet: Bool {
        permissionsSatisfied && modelsReady && vaultConfigured
    }

    var isComplete: Bool {
        didCompleteOnboarding
    }

    var summarizationModels: [SummarizationModel] {
        SummarizationModelCatalog.all
    }

    var primaryButtonTitle: String {
        switch currentStep {
        case .vault:
            return "Done"
        case .complete:
            return "Done"
        default:
            return "Continue"
        }
    }

    var primaryButtonEnabled: Bool {
        switch currentStep {
        case .intro:
            return true
        case .permissions:
            return permissionsSatisfied
        case .models:
            return modelsReady
        case .vault:
            return vaultConfigured
        case .complete:
            return true
        }
    }

    func refreshAll() {
        refreshPermissions()
        refreshVaultStatus()
        Task { await refreshModelsStatus() }
        updateCurrentStepIfNeeded()
    }

    func requestMicrophonePermission() {
        Task {
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            microphonePermissionGranted = granted
            updateCurrentStepIfNeeded()
        }
    }

    func requestScreenRecordingPermission() {
        let granted = CGRequestScreenCaptureAccess()
        screenRecordingPermissionGranted = granted || CGPreflightScreenCaptureAccess()
        updateCurrentStepIfNeeded()
    }

    func startModelDownload() {
        modelTask?.cancel()
        modelsState = .downloading(progress: ModelDownloadProgress(fractionCompleted: 0, label: "Starting download"))

        modelTask = Task { [weak self] in
            guard let self else { return }

            do {
                let validation = try await modelManager.validateModels()
                if !validation.invalidModelIDs.isEmpty {
                    try await modelManager.removeModels(withIDs: validation.invalidModelIDs)
                }

                try await modelManager.ensureModelsPresent { [weak self] update in
                    Task { @MainActor [weak self] in
                        self?.modelsState = .downloading(progress: update)
                    }
                }

                modelsState = .checking
                await refreshModelsStatus()
            } catch {
                let message = (error as? MinuteError)?.errorDescription ?? String(describing: error)
                modelsState = .needsDownload(message: message)
            }
        }
    }

    func advance() {
        switch currentStep {
        case .intro:
            didShowIntro = true
            setCurrentStep(.permissions)

        case .permissions:
            guard permissionsSatisfied else { return }
            setCurrentStep(.models)

        case .models:
            guard modelsReady else { return }
            setCurrentStep(.vault)

        case .vault:
            guard vaultConfigured else { return }
            didCompleteOnboarding = true
            setCurrentStep(.complete)

        case .complete:
            break
        }
    }

    func skipPermissions() {
        didSkipPermissions = true
        setCurrentStep(.models)
    }

    private func refreshPermissions() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        microphonePermissionGranted = (status == .authorized)
        screenRecordingPermissionGranted = CGPreflightScreenCaptureAccess()
    }

    private func refreshVaultStatus() {
        do {
            _ = try vaultAccess.resolveVaultRootURL()
            vaultConfigured = true
        } catch {
            vaultConfigured = false
        }

        updateCurrentStepIfNeeded()
    }

    private func refreshModelsStatus() async {
        if case .downloading = modelsState {
            return
        }

        modelsState = .checking

        do {
            let result = try await modelManager.validateModels()
            if result.isReady {
                modelsState = .ready
            } else {
                modelsState = .needsDownload(message: modelMessage(from: result))
            }
        } catch {
            let message = (error as? MinuteError)?.errorDescription ?? String(describing: error)
            modelsState = .needsDownload(message: message)
        }

        updateCurrentStepIfNeeded()
    }

    private func modelMessage(from result: ModelValidationResult) -> String {
        if result.missingModelIDs.isEmpty && result.invalidModelIDs.isEmpty {
            return "Models ready."
        }

        var parts: [String] = []
        if !result.missingModelIDs.isEmpty {
            let names = result.missingModelIDs.map { SummarizationModelCatalog.displayName(for: $0) }
            parts.append("Missing: \(names.joined(separator: ", "))")
        }
        if !result.invalidModelIDs.isEmpty {
            let names = result.invalidModelIDs.map { SummarizationModelCatalog.displayName(for: $0) }
            parts.append("Invalid: \(names.joined(separator: ", "))")
        }
        return parts.joined(separator: " ")
    }

    private func updateCurrentStepIfNeeded() {
        guard didShowIntro else {
            setCurrentStep(.intro, persist: false)
            return
        }

        let required = requiredStep()
        let stored = storedStep() ?? required
        var target = stored

        if required.rawValue < stored.rawValue {
            target = required
        }

        if currentStep != target {
            setCurrentStep(target, persist: false)
        }
    }

    private func requiredStep() -> Step {
        if !permissionsSatisfied {
            return .permissions
        }
        if !modelsReady {
            return .models
        }
        if !vaultConfigured {
            return .vault
        }
        return .complete
    }

    private func storedStep() -> Step? {
        guard defaults.object(forKey: DefaultsKey.lastStep) != nil else {
            return nil
        }

        let raw = defaults.integer(forKey: DefaultsKey.lastStep)
        return Step(rawValue: raw)
    }

    private func setCurrentStep(_ step: Step, persist: Bool = true) {
        currentStep = step
        if persist {
            defaults.set(step.rawValue, forKey: DefaultsKey.lastStep)
        }
    }

    private var didShowIntro: Bool {
        get { defaults.bool(forKey: DefaultsKey.didShowIntro) }
        set { defaults.set(newValue, forKey: DefaultsKey.didShowIntro) }
    }

    private var didCompleteOnboarding: Bool {
        get { defaults.bool(forKey: DefaultsKey.didCompleteOnboarding) }
        set { defaults.set(newValue, forKey: DefaultsKey.didCompleteOnboarding) }
    }

    private var didSkipPermissions: Bool {
        get { defaults.bool(forKey: DefaultsKey.didSkipPermissions) }
        set { defaults.set(newValue, forKey: DefaultsKey.didSkipPermissions) }
    }

    private var permissionsSatisfied: Bool {
        permissionsReady || didSkipPermissions
    }

    private func resetForDebugBuildIfNeeded() {
        #if DEBUG
        let currentStamp = debugBuildStamp()
        let previousStamp = defaults.double(forKey: DefaultsKey.debugBuildStamp)

        if currentStamp > 0, previousStamp > 0, currentStamp != previousStamp {
            resetOnboardingState()
        }

        if currentStamp > 0 {
            defaults.set(currentStamp, forKey: DefaultsKey.debugBuildStamp)
        }
        #endif
    }

    private func resetOnboardingState() {
        defaults.removeObject(forKey: DefaultsKey.didShowIntro)
        defaults.removeObject(forKey: DefaultsKey.didCompleteOnboarding)
        defaults.removeObject(forKey: DefaultsKey.lastStep)
        defaults.removeObject(forKey: DefaultsKey.didSkipPermissions)
    }

    private func debugBuildStamp() -> Double {
        guard let executableURL = Bundle.main.executableURL,
              let attributes = try? FileManager.default.attributesOfItem(atPath: executableURL.path),
              let modified = attributes[.modificationDate] as? Date
        else {
            return 0
        }

        return modified.timeIntervalSince1970
    }
}
