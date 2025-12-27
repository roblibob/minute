# Architectural Review — Minute Application

**Review Date:** 2025-12-27  
**Reviewer:** Senior Software Architect  
**Scope:** Comprehensive high-level architectural analysis

---

## Executive Summary

Minute is a macOS meeting transcription and summarization application with a well-structured core architecture. The codebase demonstrates strong separation of concerns through the [`MinuteCore`](MinuteCore/) package and thoughtful protocol-based service design. However, there are significant architectural issues that impact maintainability, testability, and long-term evolution.

**Key Strengths:**
- Clean module boundaries between UI and business logic
- Protocol-driven service architecture enabling testability
- Proper use of Swift concurrency (`async`/`await`, `actor`)
- Deterministic output contracts for file generation
- Comprehensive error domain modeling

**Critical Issues:**
- **God Object anti-pattern:** [`MeetingPipelineViewModel`](Minute/Pipeline/MeetingPipelineViewModel.swift) violates SRP with 790 lines and 15+ responsibilities
- **Tight coupling:** Service instantiation logic embedded in view models
- **Configuration sprawl:** Settings scattered across UserDefaults, stores, and direct service dependencies
- **Missing abstraction:** State machine logic mixed with orchestration concerns
- **Concurrency inconsistencies:** Mix of `@MainActor`, `actor`, and `@unchecked Sendable` patterns

---

## 1. System Structure & Module Boundaries

### Current Architecture

```
Minute/                          # UI Layer (SwiftUI)
├─ Pipeline/                     # Meeting processing orchestration
├─ Settings/                     # Configuration UI
├─ MeetingNotes/                 # Note browsing
└─ Onboarding/                   # First-run wizard

MinuteCore/                      # Business Logic (Swift Package)
├─ Sources/MinuteCore/
│  ├─ Domain/                    # Models & errors
│  ├─ Services/                  # Core services
│  ├─ Rendering/                 # Markdown generation
│  ├─ Vault/                     # Obsidian vault access
│  └─ Utilities/                 # Helpers
├─ Sources/MinuteLlama/          # Llama integration
└─ Sources/MinuteWhisper/        # Whisper integration
```

### ✅ Strengths

1. **Clear package separation:** Business logic isolated in [`MinuteCore`](MinuteCore/) prevents UI coupling
2. **Domain-driven structure:** [`Domain/`](MinuteCore/Sources/MinuteCore/Domain/) directory centralizes models and errors
3. **Feature modules:** [`MinuteLlama`](MinuteCore/Sources/MinuteLlama/) and [`MinuteWhisper`](MinuteCore/Sources/MinuteWhisper/) isolate ML dependencies

### ❌ Issues

#### 1.1 Missing Pipeline Coordinator Layer

**Problem:** [`MeetingPipelineViewModel.swift`](Minute/Pipeline/MeetingPipelineViewModel.swift:12) (790 lines) is a God Object combining:
- State machine management
- Service orchestration
- Permission handling
- Audio level monitoring
- Screen context capture coordination
- File cleanup
- UI state binding
- Vault configuration snapshotting

**Example:**
```swift
// MeetingPipelineViewModel.swift:419-522
private func runPipeline(context: PipelineContext) async {
    // 100+ lines of sequential orchestration
    // Mixes state transitions, progress updates, error handling,
    // and business logic
}
```

**Why This Is Problematic:**
- Impossible to test pipeline logic without mocking 10+ dependencies
- Changes to UI requirements necessitate changes to business logic
- Cannot reuse pipeline orchestration in CLI tools or tests
- Poor cohesion: permissions, audio levels, and transcription have nothing in common

**Recommended Solution:**

Extract a pure `MeetingPipelineCoordinator` in `MinuteCore`:

```swift
// MinuteCore/Sources/MinuteCore/Pipeline/MeetingPipelineCoordinator.swift

/// Pure business logic coordinator (no UI dependencies)
public actor MeetingPipelineCoordinator {
    private let audioService: any AudioServicing
    private let transcriptionService: any TranscriptionServicing
    private let summarizationService: any SummarizationServicing
    private let vaultWriter: any VaultWriting
    
    public func execute(
        audioURL: URL,
        context: PipelineContext,
        progress: (@Sendable (PipelineProgress) -> Void)?
    ) async throws -> PipelineResult {
        progress?(.stage(.downloadingModels, fraction: 0))
        // ... pure orchestration logic
        return PipelineResult(noteURL: noteURL, audioURL: audioURL)
    }
}
```

Then simplify the ViewModel:

```swift
// Minute/Pipeline/MeetingPipelineViewModel.swift

@MainActor
final class MeetingPipelineViewModel: ObservableObject {
    private let coordinator: MeetingPipelineCoordinator
    
    func startProcessing() {
        Task {
            do {
                let result = try await coordinator.execute(
                    audioURL: recordedAudioURL,
                    context: makeContext(),
                    progress: { [weak self] update in
                        self?.progress = update.fraction
                    }
                )
                state = .done(result)
            } catch {
                state = .failed(error)
            }
        }
    }
}
```

**Benefits:**
- Coordinator testable in isolation with mock services
- ViewModel reduced to ~200 lines of UI-specific concerns
- Reusable in server/CLI contexts
- Clear SRP: ViewModel = UI state, Coordinator = business logic

---

#### 1.2 Unclear Vault Abstraction Boundary

**Problem:** Vault access logic split across multiple files:
- [`VaultAccess.swift`](MinuteCore/Sources/MinuteCore/Vault/VaultAccess.swift:3) — Bookmark resolution
- [`UserDefaultsVaultBookmarkStore.swift`](MinuteCore/Sources/MinuteCore/Vault/UserDefaultsVaultBookmarkStore.swift) — Persistence
- [`MeetingPipelineViewModel.swift`](Minute/Pipeline/MeetingPipelineViewModel.swift:563) — Path configuration (`meetingsRelativePath`, `audioRelativePath`)

**Example:**
```swift
// MeetingPipelineViewModel.swift:570-574
let defaults = UserDefaults.standard
let meetings = defaults.string(forKey: DefaultsKey.meetingsRelativePath) ?? "Meetings"
let audio = defaults.string(forKey: DefaultsKey.audioRelativePath) ?? "Meetings/_audio"
// ... this is business logic, not UI configuration
```

**Why This Is Problematic:**
- UserDefaults keys duplicated across [`VaultSettingsModel`](Minute/Settings/VaultSettingsModel.swift), [`AppDefaults`](Minute/Settings/AppDefaults.swift), and pipeline
- Hard to test vault writing without mocking entire UserDefaults
- Violates DIP: high-level pipeline depends on low-level UserDefaults

**Recommended Solution:**

Introduce a comprehensive `VaultConfiguration` value type:

```swift
// MinuteCore/Sources/MinuteCore/Vault/VaultConfiguration.swift

public struct VaultConfiguration: Sendable, Equatable {
    public var rootURL: URL
    public var meetingsPath: String
    public var audioPath: String
    public var transcriptsPath: String
    public var saveAudio: Bool
    public var saveTranscript: Bool
    
    public static let `default` = VaultConfiguration(
        meetingsPath: "Meetings",
        audioPath: "Meetings/_audio",
        transcriptsPath: "Meetings/_transcripts",
        saveAudio: true,
        saveTranscript: true
    )
}

public protocol VaultConfigurationProviding: Sendable {
    func loadConfiguration() throws -> VaultConfiguration
}
```

Then inject it:

```swift
// MeetingPipelineViewModel.swift

init(
    vaultConfigProvider: any VaultConfigurationProviding,
    // ... other services
) {
    self.vaultConfigProvider = vaultConfigProvider
}

private func makeContext() -> PipelineContext? {
    guard let config = try? vaultConfigProvider.loadConfiguration() else {
        return nil
    }
    return PipelineContext(vaultConfiguration: config, ...)
}
```

**Benefits:**
- Single source of truth for vault paths
- Easily testable with mock provider
- Type-safe configuration (no string keys)
- Supports future features (e.g., multiple vaults)

---

## 2. Service Protocols & Dependency Injection

### ✅ Strengths

The [`ServiceProtocols.swift`](MinuteCore/Sources/MinuteCore/Services/ServiceProtocols.swift) file demonstrates excellent protocol design:

1. **Single-purpose protocols:** Each protocol has 1-3 focused methods
2. **Sendable conformance:** Proper Swift 6 concurrency support
3. **Testability:** Protocols enable easy mocking
4. **Clear contracts:** Well-documented with deterministic output expectations

### ❌ Issues

#### 2.1 Inconsistent Lifecycle Management

**Problem:** Service creation patterns vary wildly:

**Pattern A: Static factory in service**
```swift
// WhisperLibraryTranscriptionService.swift:43
public static func liveDefault() -> WhisperLibraryTranscriptionService
```

**Pattern B: Static factory in ViewModel**
```swift
// MeetingPipelineViewModel.swift:123-146
static func live() -> MeetingPipelineViewModel {
    let selectionStore = SummarizationModelSelectionStore()
    let summarizationServiceProvider: () -> any SummarizationServicing = {
        LlamaLibrarySummarizationService.liveDefault(selectionStore: selectionStore)
    }
    // ... 20 more lines of dependency wiring
}
```

**Pattern C: Direct instantiation in initializer**
```swift
// DefaultModelManager.swift:40-46
public init(
    requiredModels: [ModelSpec]? = nil,
    selectionStore: SummarizationModelSelectionStore = SummarizationModelSelectionStore()
)
```

**Why This Is Problematic:**
- No consistent place to find service configuration
- Static factories prevent runtime configuration changes
- Closures (`() -> SummarizationServicing`) obscure ownership and lifecycle
- Impossible to replace services at runtime (e.g., for A/B testing models)

**Recommended Solution:**

Introduce a **Dependency Container** pattern:

```swift
// MinuteCore/Sources/MinuteCore/ServiceContainer.swift

public final class ServiceContainer: Sendable {
    // Singleton instances (actors/thread-safe services)
    private let modelManager: any ModelManaging
    private let vaultConfigProvider: any VaultConfigurationProviding
    
    // Factory closures (for per-request services)
    private let audioServiceFactory: @Sendable () -> any AudioServicing
    private let transcriptionServiceFactory: @Sendable () -> any TranscriptionServicing
    private let summarizationServiceFactory: @Sendable () -> any SummarizationServicing
    
    public init(configuration: ServiceConfiguration) {
        // Wire up dependencies once
    }
    
    public func makeAudioService() -> any AudioServicing {
        audioServiceFactory()
    }
    
    public func transcriptionService() -> any TranscriptionServicing {
        transcriptionServiceFactory()
    }
    
    // etc.
}
```

Then inject the container:

```swift
// MeetingPipelineViewModel.swift

@MainActor
final class MeetingPipelineViewModel: ObservableObject {
    private let services: ServiceContainer
    
    init(services: ServiceContainer) {
        self.services = services
    }
    
    static func live() -> MeetingPipelineViewModel {
        MeetingPipelineViewModel(services: .liveConfiguration())
    }
}
```

**Benefits:**
- Single point of configuration
- Easy to swap implementations (live vs. mock vs. test doubles)
- Clear dependency graph
- Supports future DI frameworks (e.g., Swinject)

---

#### 2.2 Protocol Granularity Issues

**Problem:** [`AudioServicing`](MinuteCore/Sources/MinuteCore/Services/ServiceProtocols.swift:31) combines recording and conversion:

```swift
public protocol AudioServicing: Sendable {
    func startRecording() async throws
    func stopRecording() async throws -> AudioCaptureResult
    func convertToContractWav(inputURL: URL, outputURL: URL) async throws
}
```

But only [`DefaultAudioService`](MinuteCore/Sources/MinuteCore/Services/DefaultAudioService.swift:9) implements it. The conversion method is also used standalone by [`DefaultMediaImportService`](MinuteCore/Sources/MinuteCore/Services/DefaultMediaImportService.swift).

**Why This Is Problematic:**
- Forces mock implementations to implement unused methods
- Violates ISP (Interface Segregation Principle)
- Conversion logic should be a separate concern

**Recommended Solution:**

Split into focused protocols:

```swift
public protocol AudioCapturing: Sendable {
    func startRecording() async throws
    func stopRecording() async throws -> AudioCaptureResult
}

public protocol AudioWavConverting: Sendable {
    func convertToContractWav(inputURL: URL, outputURL: URL) async throws
}

public typealias AudioServicing = AudioCapturing & AudioWavConverting
```

**Benefits:**
- Mock implementations only implement what they need
- Conversion logic independently injectable
- Clearer contracts

---

## 3. State Management & Data Flow

### Current Approach

State is managed via:
1. **Pipeline State Machine:** [`MeetingPipelineState`](Minute/Pipeline/MeetingPipelineTypes.swift:54) enum with associated values
2. **Published Properties:** `@Published` in ViewModels
3. **UserDefaults:** For persistent settings
4. **Actor isolation:** For concurrent service state

### ✅ Strengths

1. **Type-safe state machine:** Impossible states are unrepresentable
2. **Clear state transitions:** [`send(_ action: MeetingPipelineAction)`](Minute/Pipeline/MeetingPipelineViewModel.swift:157) centralizes mutations
3. **Immutable state:** Associated values prevent accidental mutation

### ❌ Issues

#### 3.1 State Machine Mixed with Orchestration

**Problem:** The state machine in [`MeetingPipelineState.swift`](Minute/Pipeline/MeetingPipelineTypes.swift:54) is coupled to orchestration details:

```swift
case processing(stage: ProcessingStage, context: PipelineContext)
case writing(context: PipelineContext, extraction: MeetingExtraction)
```

The `PipelineContext` contains:
- Vault configuration
- Audio temp URLs
- Working directory paths
- Screen context events

**Why This Is Problematic:**
- State representation includes implementation details
- Cannot serialize/persist state (contains URLs, non-Codable types)
- Hard to implement "resume from crash" functionality
- UI queries like `statusLabel` are mixed with data access like `recordedContextIfAvailable`

**Recommended Solution:**

Separate **pure state** from **runtime context**:

```swift
// Pure state machine (serializable, UI-focused)
public enum MeetingState: Codable, Equatable {
    case idle
    case recording(sessionID: UUID, startedAt: Date)
    case recorded(sessionID: UUID, duration: TimeInterval)
    case processing(stage: ProcessingStage, progress: Double?)
    case done(noteFilename: String)
    case failed(errorCode: String)
}

// Runtime context (managed by coordinator)
public struct PipelineContext {
    let audioURL: URL
    let vaultConfig: VaultConfiguration
    let screenEvents: [ScreenContextEvent]
}
```

**Benefits:**
- State can be saved/restored across app launches
- Clear separation between "what happened" (state) and "how to do it" (context)
- Easier to implement undo/redo or process replay

---

#### 3.2 Configuration Scattered Across Multiple Stores

**Problem:** Related settings live in different places:

| Setting | Location | Access Pattern |
|---------|----------|----------------|
| Vault root bookmark | [`UserDefaultsVaultBookmarkStore`](MinuteCore/Sources/MinuteCore/Vault/UserDefaultsVaultBookmarkStore.swift) | Custom store |
| Meetings relative path | `UserDefaults` | Direct string key |
| Save audio flag | [`AppDefaults.swift`](Minute/Settings/AppDefaults.swift) | `@AppStorage` |
| Summarization model ID | [`SummarizationModelSelectionStore`](MinuteCore/Sources/MinuteCore/Services/SummarizationModelSelectionStore.swift) | Custom store |
| Screen context enabled | `UserDefaults` | `@AppStorage` |

**Example from [`MeetingPipelineViewModel.swift`](Minute/Pipeline/MeetingPipelineViewModel.swift:563):**
```swift
private func makePipelineContext(...) -> PipelineContext? {
    let defaults = UserDefaults.standard
    let meetings = defaults.string(forKey: DefaultsKey.meetingsRelativePath) ?? "Meetings"
    let audio = defaults.string(forKey: DefaultsKey.audioRelativePath) ?? "Meetings/_audio"
    let saveAudio = defaults.object(forKey: AppDefaultsKey.saveAudio) as? Bool ?? true
    // ... scattered across 4 different key hierarchies
}
```

**Why This Is Problematic:**
- No single source of truth for configuration
- Impossible to reset to defaults atomically
- Hard to implement configuration profiles or migrations
- Key string literals duplicated

**Recommended Solution:**

Consolidate into a unified `AppConfiguration` actor:

```swift
// MinuteCore/Sources/MinuteCore/Configuration/AppConfiguration.swift

public actor AppConfiguration {
    public struct Settings: Codable, Sendable {
        public var vault: VaultSettings
        public var processing: ProcessingSettings
        public var models: ModelSettings
        
        public static let `default` = Settings(...)
    }
    
    private let store: any ConfigurationStore
    private var cached: Settings?
    
    public func load() async -> Settings {
        if let cached { return cached }
        let loaded = (try? await store.load()) ?? .default
        cached = loaded
        return loaded
    }
    
    public func update(_ transform: (inout Settings) -> Void) async throws {
        var settings = await load()
        transform(&settings)
        try await store.save(settings)
        cached = settings
    }
}
```

**Benefits:**
- Atomic reads and writes
- Type-safe configuration
- Easy migrations via `Codable` versioning
- Testable without UserDefaults

---

## 4. Error Handling

### ✅ Strengths

1. **Domain-specific error type:** [`MinuteError`](MinuteCore/Sources/MinuteCore/Domain/MinuteError.swift:6) captures all failure modes
2. **User-friendly messages:** [`errorDescription`](MinuteCore/Sources/MinuteCore/Domain/MinuteError.swift:32) vs [`debugSummary`](MinuteCore/Sources/MinuteCore/Domain/MinuteError.swift:79)
3. **Consistent error propagation:** Services throw `MinuteError` or map to it at boundaries

### ❌ Issues

#### 4.1 Lost Error Context

**Problem:** Many catch blocks map errors to generic cases without preserving context:

```swift
// MeetingPipelineViewModel.swift:516-520
} catch {
    logger.error("Pipeline failed: \(String(describing: error), privacy: .public)")
    progress = nil
    state = .failed(error: .vaultWriteFailed, debugOutput: String(describing: error))
}
```

If `writeOutputsToVault` throws a filesystem error, it becomes `.vaultWriteFailed` and the original error is only in logs.

**Why This Is Problematic:**
- Error recovery logic can't distinguish between different failure modes
- User sees "vault write failed" for permissions, disk full, and corrupted files
- Impossible to implement retry strategies

**Recommended Solution:**

Extend `MinuteError` to preserve underlying errors:

```swift
public enum MinuteError: Error {
    case vaultWriteFailed(reason: VaultWriteFailureReason)
    
    public enum VaultWriteFailureReason: Sendable {
        case permissionDenied(underlying: Error)
        case diskFull(underlying: Error)
        case corruptedBookmark(underlying: Error)
        case unknown(underlying: Error)
    }
}
```

Or use a recoverable error wrapper:

```swift
public struct RecoverableError: Error {
    public let error: MinuteError
    public let underlying: Error?
    public let recoveryOptions: [RecoveryOption]
}

public enum RecoveryOption {
    case retry
    case skipAndContinue
    case selectDifferentVault
}
```

**Benefits:**
- Precise error diagnosis
- Enables recovery UI ("Disk Full - Free up space and retry")
- Better telemetry and debugging

---

#### 4.2 Inconsistent Error Mapping at Boundaries

**Problem:** Some services throw `MinuteError`, others throw `Error`:

```swift
// DefaultModelManager.swift:131-133
} catch {
    try? fileManager.removeItem(at: tempURL)
    throw MinuteError.modelDownloadFailed(underlyingDescription: String(describing: error))
}
```

vs.

```swift
// DefaultAudioService.swift:151-154
} catch {
    logger.error("Audio export failed: \(String(describing: error), privacy: .public)")
    throw MinuteError.audioExportFailed
}
```

One preserves `underlyingDescription`, the other loses it.

**Recommended Solution:**

Standardize error mapping with a helper:

```swift
extension MinuteError {
    static func wrap(_ error: Error, as minuteError: MinuteError) -> MinuteError {
        if let minuteError = error as? MinuteError {
            return minuteError
        }
        // Attach underlying error for debugging
        return minuteError
    }
}

// Usage:
} catch {
    throw MinuteError.wrap(error, as: .audioExportFailed)
}
```

---

## 5. Cross-Cutting Concerns

### 5.1 Logging

**Current Approach:**
```swift
private let logger = Logger(subsystem: "roblibob.Minute", category: "pipeline")
```

**✅ Strengths:**
- Uses `OSLog` for privacy-preserving logging
- Consistent subsystem identifier

**❌ Issues:**
- No centralized log level configuration
- Privacy tags mixed inconsistently (`.public` vs `.private`)
- No structured logging (can't query by error type or stage)

**Recommended Solution:**

Introduce a logging facade:

```swift
// MinuteCore/Sources/MinuteCore/Logging/MinuteLogger.swift

public struct MinuteLogger: Sendable {
    private let logger: Logger
    
    public static func category(_ category: String) -> MinuteLogger {
        MinuteLogger(logger: Logger(subsystem: "roblibob.Minute", category: category))
    }
    
    public func info(_ message: String, metadata: [String: String] = [:]) {
        // Structured logging with automatic privacy handling
    }
    
    public func error(_ error: Error, context: String) {
        // Log error + context + telemetry
    }
}
```

**Benefits:**
- Centralized privacy policy
- Structured logs queryable in advanced debugging
- Easy to add telemetry/crash reporting hooks

---

### 5.2 Configuration Management

**Problem:** Magic strings and hardcoded values scattered everywhere:

```swift
// ScreenContextCaptureService.swift:101
let collector = ScreenContextEventCollector(maxEvents: 120)

// MeetingPipelineViewModel.swift:63
private let screenContextFrameIntervalSeconds: TimeInterval = 60.0

// WhisperLibraryTranscriptionService.swift:99
params.no_speech_thold = 1.0
```

**Recommended Solution:**

Centralize configuration:

```swift
// MinuteCore/Sources/MinuteCore/Configuration/AppConstants.swift

public enum AppConstants {
    public enum ScreenContext {
        public static let maxEvents = 120
        public static let defaultFrameInterval: TimeInterval = 60.0
    }
    
    public enum Whisper {
        public static let noSpeechThreshold: Float = 1.0
        public static let threads = 4
    }
}
```

---

## 6. SOLID Principle Violations

### 6.1 Single Responsibility Principle (SRP)

**Violations:**

| Class | Responsibilities | Lines | Fix |
|-------|------------------|-------|-----|
| [`MeetingPipelineViewModel`](Minute/Pipeline/MeetingPipelineViewModel.swift:12) | State management, orchestration, permissions, audio levels, screen capture, cleanup | 790 | Extract `PipelineCoordinator`, `PermissionManager`, `AudioLevelMonitor` |
| [`DefaultModelManager`](MinuteCore/Sources/MinuteCore/Services/DefaultModelManager.swift:8) | Download, verification, extraction, checksum, file management | 495 | Extract `ModelDownloader`, `ModelVerifier`, `ModelExtractor` |
| [`LlamaLibrarySummarizationService`](MinuteCore/Sources/MinuteLlama/Services/LlamaLibrarySummarizationService.swift:41) | Tokenization, sampling, chat template, prompt building | 392 | Extract `LlamaTokenizer`, `PromptFormatter` |

---

### 6.2 Open/Closed Principle (OCP)

**Violation:** Adding a new processing stage requires modifying [`MeetingPipelineViewModel.runPipeline`](Minute/Pipeline/MeetingPipelineViewModel.swift:419):

```swift
// To add "diarization" stage, must edit this method
private func runPipeline(context: PipelineContext) async {
    state = .processing(stage: .downloadingModels, ...)
    try await modelManager.ensureModelsPresent(...)
    
    state = .processing(stage: .transcribing, ...)
    let transcription = try await transcriptionService.transcribe(...)
    
    // Need to insert diarization here → violates OCP
    
    state = .processing(stage: .summarizing, ...)
    // ...
}
```

**Recommended Solution:**

Use a **Pipeline Builder** pattern:

```swift
public protocol PipelineStage {
    func execute(context: inout PipelineContext) async throws
    var progress: ClosedRange<Double> { get }
}

public struct PipelineBuilder {
    private var stages: [PipelineStage] = []
    
    public func addStage(_ stage: PipelineStage) -> Self {
        var builder = self
        builder.stages.append(stage)
        return builder
    }
    
    public func build() -> Pipeline {
        Pipeline(stages: stages)
    }
}

// Usage:
let pipeline = PipelineBuilder()
    .addStage(ModelDownloadStage())
    .addStage(TranscriptionStage())
    .addStage(DiarizationStage())  // ← Can be added without modifying existing code
    .addStage(SummarizationStage())
    .build()
```

---

### 6.3 Dependency Inversion Principle (DIP)

**Violation:** High-level [`MeetingPipelineViewModel`](Minute/Pipeline/MeetingPipelineViewModel.swift) depends on low-level `UserDefaults`:

```swift
// MeetingPipelineViewModel.swift:570
let defaults = UserDefaults.standard
```

Should depend on `VaultConfigurationProviding` protocol instead (see Section 1.2).

---

## 7. Concurrency & Performance

### ✅ Strengths

1. **Proper actor usage:** [`DefaultModelManager`](MinuteCore/Sources/MinuteCore/Services/DefaultModelManager.swift:8), [`ScreenContextCaptureService`](MinuteCore/Sources/MinuteCore/Services/ScreenContextCaptureService.swift:30)
2. **Cancellation support:** `try Task.checkCancellation()` throughout
3. **Efficient streaming:** Screen capture uses `minimumFrameInterval` to throttle

### ❌ Issues

#### 7.1 Inconsistent Sendable Conformance

**Problem:** Mix of `@unchecked Sendable` and proper isolation:

```swift
// DefaultModelManager.swift:324
final class Coordinator: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    // Accessing shared mutable state without synchronization
    var continuation: CheckedContinuation<URL, Error>?
}
```

vs.

```swift
// ScreenContextEventCollector.swift:376
private actor ScreenContextEventCollector {
    // Proper actor isolation
    private var events: [ScreenContextEvent] = []
}
```

**Why This Is Problematic:**
- Data races possible in `@unchecked Sendable` types
- Compiler can't verify safety
- Future Swift 6 strict concurrency will flag these

**Recommended Solution:**

Replace `@unchecked Sendable` with proper synchronization:

```swift
final class Coordinator: NSObject, URLSessionDownloadDelegate, Sendable {
    private actor State {
        var continuation: CheckedContinuation<URL, Error>?
        
        func setContinuation(_ cont: CheckedContinuation<URL, Error>) {
            continuation = cont
        }
    }
    
    private let state = State()
    
    func urlSession(_ session: URLSession, ...) {
        Task {
            await state.continuation?.resume(...)
        }
    }
}
```

---

#### 7.2 Potential Memory Issues

**Problem:** Large files loaded into memory:

```swift
// MeetingPipelineViewModel.swift:667
let audioData = try Data(contentsOf: context.audioTempURL)
```

For a 1-hour meeting at 256kbps WAV:
- File size: ~115 MB
- Memory spike during vault write

**Why This Is Problematic:**
- Memory pressure on older Macs
- Crashes possible with long meetings
- Violates "streaming" principle documented in task 08

**Recommended Solution:**

Stream file writes:

```swift
public protocol VaultWriting: Sendable {
    func writeAtomically(
        from sourceURL: URL,
        to destinationURL: URL
    ) async throws
}

// Implementation:
let tempURL = destinationURL.appendingPathExtension("tmp")
try FileManager.default.copyItem(at: sourceURL, to: tempURL)
try FileManager.default.replaceItemAt(destinationURL, withItemAt: tempURL)
```

---

## 8. Testability Assessment

### Current State

**What's Testable:**
- ✅ [`MarkdownRenderer`](MinuteCore/Sources/MinuteCore/Rendering/MarkdownRenderer.swift) — pure function, golden tests
- ✅ [`FilenameSanitizer`](MinuteCore/Sources/MinuteCore/Utilities/FilenameSanitizer.swift) — no dependencies
- ✅ [`MeetingExtraction`](MinuteCore/Sources/MinuteCore/Domain/MeetingExtraction.swift) decoding

**What's Hard to Test:**
- ❌ [`MeetingPipelineViewModel.runPipeline`](Minute/Pipeline/MeetingPipelineViewModel.swift:419) — requires mocking 10+ services
- ❌ [`DefaultModelManager.download`](MinuteCore/Sources/MinuteCore/Services/DefaultModelManager.swift:323) — tightly coupled to `URLSession`
- ❌ Screen context capture — depends on `SCStream` which can't run in tests

**Gap Analysis:**
- Only ~40% of core business logic has unit tests
- No integration tests for full pipeline
- No contract tests for service boundaries

**Recommended Improvements:**

1. **Extract pure business logic from ViewModels** (see Section 1.1)
2. **Add protocol for network layer:**
   ```swift
   public protocol ModelDownloading: Sendable {
       func download(from url: URL, to destination: URL) async throws -> URL
   }
   ```
3. **Create test fixtures:**
   ```swift
   public enum TestFixtures {
       public static let sampleTranscription = TranscriptionResult(...)
       public static let sampleExtraction = MeetingExtraction(...)
   }
   ```

---

## 9. Scalability Considerations

### 9.1 Model Management

**Current Limitation:** [`DefaultModelManager`](MinuteCore/Sources/MinuteCore/Services/DefaultModelManager.swift:230) hardcodes model specs:

```swift
public static func defaultRequiredModels(selectedSummarizationModelID: String? = nil) -> [ModelSpec] {
    // Hardcoded URLs and checksums
}
```

**Future Scalability Issues:**
- Cannot add models without app update
- No A/B testing of model versions
- No server-side kill switch for broken models

**Recommended Solution:**

Fetch model catalog from server:

```json
// https://minute.app/models/catalog.json
{
  "version": "2025-01-01",
  "models": [
    {
      "id": "whisper/base",
      "url": "https://...",
      "sha256": "...",
      "metadata": { "deprecated": false }
    }
  ]
}
```

With local fallback to bundled catalog.

---

### 9.2 Vault Writing Bottleneck

**Problem:** All vault writes go through single [`VaultAccess.withVaultAccess`](MinuteCore/Sources/MinuteCore/Vault/VaultAccess.swift:30):

```swift
public func withVaultAccess<T>(_ work: (URL) throws -> T) throws -> T {
    // Security-scoped access lasts only during this closure
}
```

**Scalability Issue:**
- If writing 3 files (note + audio + transcript), need 3 sequential access scopes
- On slower drives, this adds latency

**Recommended Solution:**

Batch vault operations:

```swift
public func withVaultAccess<T>(_ work: (URL) async throws -> T) async throws -> T {
    let vaultRootURL = try resolveVaultRootURL()
    guard vaultRootURL.startAccessingSecurityScopedResource() else {
        throw MinuteError.vaultUnavailable
    }
    defer { vaultRootURL.stopAccessingSecurityScopedResource() }
    
    return try await work(vaultRootURL)
}

// Usage:
try await vaultAccess.withVaultAccess { vaultRoot in
    // All writes happen within single access scope
    try await writer.writeNote(...)
    try await writer.writeAudio(...)
    try await writer.writeTranscript(...)
}
```

---

## 10. Prioritized Refactoring Roadmap

### Priority 1: Critical (Do First)

1. **Extract `MeetingPipelineCoordinator`** from [`MeetingPipelineViewModel`](Minute/Pipeline/MeetingPipelineViewModel.swift)
   - **Impact:** Improves testability, reduces coupling
   - **Effort:** 2-3 days
   - **Risk:** Medium (touches core flow)

2. **Introduce `VaultConfiguration` protocol**
   - **Impact:** Eliminates UserDefaults coupling
   - **Effort:** 1 day
   - **Risk:** Low

3. **Fix `@unchecked Sendable` violations**
   - **Impact:** Prevents data races, Swift 6 compatibility
   - **Effort:** 1-2 days
   - **Risk:** Low

### Priority 2: High (Do Soon)

4. **Split `AudioServicing` protocol**
   - **Impact:** Better modularity, clearer contracts
   - **Effort:** 0.5 days
   - **Risk:** Low

5. **Implement `ServiceContainer`**
   - **Impact:** Centralized dependency management
   - **Effort:** 1-2 days
   - **Risk:** Medium

6. **Refactor error handling** (preserve underlying errors)
   - **Impact:** Better debugging, recovery options
   - **Effort:** 1 day
   - **Risk:** Low

### Priority 3: Medium (Plan for Later)

7. **Extract pipeline stages** (OCP compliance)
   - **Impact:** Extensibility for new features
   - **Effort:** 2-3 days
   - **Risk:** Medium

8. **Stream vault audio writes** (remove memory loading)
   - **Impact:** Handles longer meetings
   - **Effort:** 1 day
   - **Risk:** Low

9. **Consolidate configuration** into `AppConfiguration` actor
   - **Impact:** Single source of truth
   - **Effort:** 2 days
   - **Risk:** Medium

### Priority 4: Low (Nice to Have)

10. **Add model catalog fetching**
    - **Impact:** Server-side model updates
    - **Effort:** 3 days
    - **Risk:** High (new network dependency)

---

## 11. Recommended Architecture Evolution

### Target Architecture

```
Minute/                              # UI Layer
├─ Views/                            # SwiftUI components
├─ ViewModels/                       # Thin UI state adapters
└─ DependencyInjection/              # ServiceContainer setup

MinuteCore/
├─ Domain/                           # Pure models & business rules
│  ├─ Models/                        # Value types (MeetingExtraction, etc.)
│  ├─ Errors/                        # MinuteError + recovery
│  └─ Contracts/                     # File contracts, protocols
├─ Application/                      # Use cases & coordinators
│  ├─ Coordinators/                  # Pipeline, Model, Vault coordinators
│  └─ Interactors/                   # Single-purpose use cases
├─ Infrastructure/                   # External service adapters
│  ├─ Audio/                         # AVFoundation wrappers
│  ├─ ML/                            # Whisper/Llama wrappers
│  ├─ Vault/                         # Filesystem access
│  └─ Network/                       # Model downloads
└─ Presentation/                     # Shared presentation logic
    └─ Rendering/                    # Markdown, formatters
```

### Migration Path

**Phase 1:** Extract coordinators (Priority 1-2 items)  
**Phase 2:** Refactor protocols and DI (Priority 2-3 items)  
**Phase 3:** Add missing tests and documentation  
**Phase 4:** Consider advanced patterns (CQRS, event sourcing) if complexity grows

---

## 12. Conclusion

Minute has a **solid architectural foundation** with clear module boundaries and thoughtful protocol design. The core issues stem from:

1. **God Objects** (especially [`MeetingPipelineViewModel`](Minute/Pipeline/MeetingPipelineViewModel.swift))
2. **Scattered configuration** across multiple stores
3. **Inconsistent dependency injection**
4. **Missing abstraction layers** for coordinators and use cases

**The good news:** These are refactoring problems, not design flaws. The codebase is well-positioned for incremental improvement without major rewrites.

**Recommended Next Steps:**
1. Review this document with the team
2. Prioritize refactoring items based on upcoming feature work
3. Start with Priority 1 items (pipeline coordinator, vault config)
4. Add tests incrementally as you refactor
5. Revisit architecture every 3 months as codebase grows

**Final Assessment:**
- **Overall Architecture Grade:** B
- **Maintainability:** B-
- **Testability:** C+
- **Scalability:** B
- **Code Quality:** B+

With the recommended refactorings, this could easily become an A-grade architecture suitable for long-term product evolution.

---

**End of Review**

For questions or clarifications, please reference specific sections by number (e.g., "Section 2.1: Lifecycle Management").
