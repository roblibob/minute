# Minute App Implementation Priorities

This document outlines the highest priority improvements for the Minute app, with specific implementation details and code examples.

## 1. String Normalization Refactoring

### Current Issue
String normalization logic is duplicated in `MarkdownRenderer` and `MeetingExtractionValidation` classes.

### Implementation Plan

1. Create a new utility class in `MinuteCore/Sources/MinuteCore/Utilities/StringNormalizer.swift`:

```swift
import Foundation

public enum StringNormalizer {
    /// Normalizes paragraph text, preserving line breaks but normalizing line endings and trimming.
    public static func normalizeParagraph(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Normalizes to a single-line, trimmed string.
    public static func normalizeInline(_ value: String) -> String {
        normalizeParagraph(value)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Normalizes a title, ensuring it's never empty.
    public static func normalizeTitle(_ value: String) -> String {
        let title = normalizeInline(value)
        return title.isEmpty ? "Untitled" : title
    }
    
    /// Escapes a string for YAML double-quoted context.
    public static func yamlDoubleQuoted(_ value: String) -> String {
        var escaped = value
        escaped = escaped.replacingOccurrences(of: "\\", with: "\\\\")
        escaped = escaped.replacingOccurrences(of: "\"", with: "\\\"")
        escaped = escaped.replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }
}
```

2. Update `MarkdownRenderer` to use the new utility:

```swift
import Foundation

public struct MarkdownRenderer: Sendable {
    public init() {}
    
    public func render(
        extraction: MeetingExtraction,
        noteDateTime: String,
        audioRelativePath: String?,
        transcriptRelativePath: String?
    ) -> String {
        let title = StringNormalizer.normalizeTitle(extraction.title)
        let date = noteDateTime
        
        var lines: [String] = []
        lines.reserveCapacity(64)
        
        // YAML frontmatter
        lines.append("---")
        lines.append("type: meeting")
        lines.append("date: \(date)")
        lines.append("title: \(StringNormalizer.yamlDoubleQuoted(title))")
        lines.append("source: \"Minute\"")
        lines.append("tags:")
        lines.append("---")
        lines.append("")
        
        // Body
        lines.append("# \(title)")
        lines.append("")
        
        lines.append("## Summary")
        lines.append(StringNormalizer.normalizeParagraph(extraction.summary))
        lines.append("")
        
        // ... rest of the method ...
        
        return lines.joined(separator: "\n") + "\n"
    }
    
    private func appendBullets(_ items: [String], to lines: inout [String]) {
        let cleaned = items
            .map { StringNormalizer.normalizeInline($0) }
            .filter { !$0.isEmpty }
        
        // ... rest of the method ...
    }
    
    // ... other methods ...
}
```

3. Update `MeetingExtractionValidation` to use the new utility:

```swift
import Foundation

public enum MeetingExtractionValidation {
    public static func validated(_ extraction: MeetingExtraction, recordingDate: Date) -> MeetingExtraction {
        var copy = extraction
        
        // Title: normalize to a single line; never allow empty.
        copy.title = StringNormalizer.normalizeTitle(copy.title)
        
        // Date: must match YYYY-MM-DD; otherwise replace with the recording date.
        let date = StringNormalizer.normalizeInline(copy.date)
        if isValidISODate(date) {
            copy.date = date
        } else {
            copy.date = MeetingFileContract.isoDate(recordingDate)
        }
        
        // Summary: normalize line endings and trim.
        copy.summary = StringNormalizer.normalizeParagraph(copy.summary)
        
        // Arrays: normalize items.
        copy.decisions = copy.decisions.map(StringNormalizer.normalizeInline).filter { !$0.isEmpty }
        copy.openQuestions = copy.openQuestions.map(StringNormalizer.normalizeInline).filter { !$0.isEmpty }
        copy.keyPoints = copy.keyPoints.map(StringNormalizer.normalizeInline).filter { !$0.isEmpty }
        
        copy.actionItems = copy.actionItems
            .map { ActionItem(owner: StringNormalizer.normalizeInline($0.owner), task: StringNormalizer.normalizeInline($0.task)) }
            .filter { !$0.owner.isEmpty || !$0.task.isEmpty }
        
        return copy
    }
    
    // ... rest of the class ...
}
```

## 2. MeetingPipelineViewModel Refactoring

### Current Issue
`MeetingPipelineViewModel` is large (800+ lines) with many responsibilities.

### Implementation Plan

1. Split into smaller, focused view models:

#### RecordingViewModel.swift
```swift
import Foundation
import MinuteCore
import Combine

@MainActor
final class RecordingViewModel: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var recordingSession: RecordingSession?
    @Published private(set) var audioLevelSamples: [CGFloat] = Array(repeating: 0, count: 24)
    @Published private(set) var microphoneCaptureEnabled = true
    @Published private(set) var systemAudioCaptureEnabled = true
    @Published private(set) var liveTranscriptionLine: String = ""
    
    private let audioService: any AudioServicing
    private let audioLevelBucketCount = 24
    private let audioLevelUpdateInterval: CFTimeInterval = 1.0 / 24.0
    private var lastAudioLevelUpdate: CFTimeInterval = 0
    private var liveTranscriptionMixer: LiveAudioStreamMixer?
    private var liveTranscriptionTickerTask: Task<Void, Never>?
    
    init(audioService: some AudioServicing) {
        self.audioService = audioService
    }
    
    func startRecording() async throws {
        // Implementation...
    }
    
    func stopRecording() async throws -> AudioCaptureResult {
        // Implementation...
    }
    
    func setMicrophoneCaptureEnabled(_ enabled: Bool) async {
        // Implementation...
    }
    
    func setSystemAudioCaptureEnabled(_ enabled: Bool) async {
        // Implementation...
    }
    
    // Other recording-related methods...
}
```

#### ScreenCaptureViewModel.swift
```swift
import Foundation
import MinuteCore
import AppKit

@MainActor
final class ScreenCaptureViewModel: ObservableObject {
    @Published private(set) var screenCaptureEnabled = false
    @Published private(set) var latestScreenCaptureImage: NSImage? = nil
    @Published private(set) var screenInferenceStatus: ScreenInferenceStatus? = nil
    
    private let screenContextCaptureService: ScreenContextCaptureService
    private let screenContextSettingsStore: ScreenContextSettingsStore
    private var screenCaptureSelection: ScreenContextWindowSelection?
    private var screenContextEvents: [ScreenContextEvent] = []
    private var screenCaptureBaseProcessedCount = 0
    private var screenCaptureBaseSkippedCount = 0
    
    init(
        screenContextCaptureService: ScreenContextCaptureService,
        screenContextSettingsStore: ScreenContextSettingsStore
    ) {
        self.screenContextCaptureService = screenContextCaptureService
        self.screenContextSettingsStore = screenContextSettingsStore
        self.screenCaptureEnabled = screenContextSettingsStore.isEnabled
    }
    
    func setScreenCaptureEnabled(_ enabled: Bool) {
        // Implementation...
    }
    
    func setScreenCaptureSelection(_ selection: ScreenContextWindowSelection) {
        // Implementation...
    }
    
    func startScreenContextCapture(selection: ScreenContextWindowSelection, offsetSeconds: TimeInterval) async {
        // Implementation...
    }
    
    func stopScreenContextCaptureAndAppend() async -> ScreenContextCaptureResult? {
        // Implementation...
    }
    
    // Other screen capture-related methods...
}
```

#### ProcessingViewModel.swift
```swift
import Foundation
import MinuteCore

@MainActor
final class ProcessingViewModel: ObservableObject {
    @Published private(set) var state: ProcessingState = .idle
    @Published private(set) var progress: Double? = nil
    
    private let pipelineCoordinator: MeetingPipelineCoordinator
    private let vaultAccess: VaultAccess
    private var processingTask: Task<Void, Never>?
    
    init(
        pipelineCoordinator: MeetingPipelineCoordinator,
        vaultAccess: VaultAccess
    ) {
        self.pipelineCoordinator = pipelineCoordinator
        self.vaultAccess = vaultAccess
    }
    
    func process(
        audioTempURL: URL,
        durationSeconds: TimeInterval,
        startedAt: Date,
        stoppedAt: Date,
        screenContextEvents: [ScreenContextEvent]
    ) {
        // Implementation...
    }
    
    func cancelProcessing() {
        // Implementation...
    }
    
    // Other processing-related methods...
}
```

#### MeetingPipelineViewModel (Coordinator)
```swift
import Foundation
import MinuteCore
import Combine

@MainActor
final class MeetingPipelineViewModel: ObservableObject {
    @Published private(set) var state: MeetingPipelineState = .idle
    @Published private(set) var progress: Double? = nil
    
    private let recordingViewModel: RecordingViewModel
    private let screenCaptureViewModel: ScreenCaptureViewModel
    private let processingViewModel: ProcessingViewModel
    private var cancellables = Set<AnyCancellable>()
    
    init(
        recordingViewModel: RecordingViewModel,
        screenCaptureViewModel: ScreenCaptureViewModel,
        processingViewModel: ProcessingViewModel
    ) {
        self.recordingViewModel = recordingViewModel
        self.screenCaptureViewModel = screenCaptureViewModel
        self.processingViewModel = processingViewModel
        
        // Set up bindings between view models
        setupBindings()
    }
    
    private func setupBindings() {
        // Bind state changes between view models
        // Implementation...
    }
    
    func send(_ action: MeetingPipelineAction) {
        // Delegate to appropriate view model based on action
        // Implementation...
    }
    
    // Minimal coordination methods...
}
```

## 3. Centralized Configuration Management

### Current Issue
Configuration values are scattered across the codebase.

### Implementation Plan

1. Create a centralized configuration class:

```swift
import Foundation

public struct AppConfiguration {
    public struct VaultPaths {
        public let meetingsRoot: String
        public let audioRoot: String
        public let transcriptsRoot: String
        
        public static let `default` = VaultPaths(
            meetingsRoot: "Meetings",
            audioRoot: "Meetings/_audio",
            transcriptsRoot: "Meetings/_transcripts"
        )
    }
    
    public struct AudioSettings {
        public let sampleRate: Double
        public let bitDepth: Int
        public let channels: Int
        
        public static let `default` = AudioSettings(
            sampleRate: 16000,
            bitDepth: 16,
            channels: 1
        )
    }
    
    public struct ModelSettings {
        public let whisperModel: String
        public let llamaModel: String
        public let modelsDirectory: URL
        
        public static func `default`(appSupportURL: URL) -> ModelSettings {
            let modelsDirectory = appSupportURL.appendingPathComponent("models", isDirectory: true)
            return ModelSettings(
                whisperModel: "base.en",
                llamaModel: "qwen2.5-7b-instruct-q4",
                modelsDirectory: modelsDirectory
            )
        }
    }
    
    public let vaultPaths: VaultPaths
    public let audioSettings: AudioSettings
    public let modelSettings: ModelSettings
    
    public static func load() -> AppConfiguration {
        let defaults = UserDefaults.standard
        
        // Load vault paths from UserDefaults or use defaults
        let meetingsRoot = defaults.string(forKey: "meetingsRelativePath") ?? "Meetings"
        let audioRoot = defaults.string(forKey: "audioRelativePath") ?? "Meetings/_audio"
        let transcriptsRoot = defaults.string(forKey: "transcriptsRelativePath") ?? "Meetings/_transcripts"
        
        let vaultPaths = VaultPaths(
            meetingsRoot: meetingsRoot,
            audioRoot: audioRoot,
            transcriptsRoot: transcriptsRoot
        )
        
        // App Support directory
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Minute", isDirectory: true)
        
        return AppConfiguration(
            vaultPaths: vaultPaths,
            audioSettings: .default,
            modelSettings: .default(appSupportURL: appSupportURL)
        )
    }
}
```

2. Use the configuration throughout the app:

```swift
// In app initialization
let appConfiguration = AppConfiguration.load()

// When creating services
let pipelineCoordinator = MeetingPipelineCoordinator(
    transcriptionService: transcriptionService,
    diarizationService: diarizationService,
    summarizationServiceProvider: summarizationServiceProvider,
    modelManager: DefaultModelManager(
        configuration: appConfiguration.modelSettings
    ),
    vaultAccess: vaultAccess,
    vaultWriter: DefaultVaultWriter()
)

// When creating file contracts
let contract = MeetingFileContract(
    folders: MeetingFileContract.VaultFolders(
        meetingsRoot: appConfiguration.vaultPaths.meetingsRoot,
        audioRoot: appConfiguration.vaultPaths.audioRoot,
        transcriptsRoot: appConfiguration.vaultPaths.transcriptsRoot
    )
)
```

## 4. Error Handling Consistency

### Current Issue
Error handling patterns are inconsistent across the codebase.

### Implementation Plan

1. Create a standardized error handling utility:

```swift
import Foundation
import os

public enum ErrorHandler {
    private static let logger = Logger(subsystem: "roblibob.Minute", category: "errors")
    
    /// Executes a throwing operation and maps any errors to MinuteError.
    /// - Parameters:
    ///   - operation: The operation description for logging
    ///   - defaultError: The default MinuteError to use if the caught error is not already a MinuteError
    ///   - work: The throwing work to perform
    /// - Returns: The result of the work
    /// - Throws: MinuteError
    public static func execute<T>(
        operation: String,
        defaultError: MinuteError,
        work: () throws -> T
    ) throws -> T {
        do {
            return try work()
        } catch is CancellationError {
            logger.info("Operation cancelled: \(operation, privacy: .public)")
            throw CancellationError()
        } catch let minuteError as MinuteError {
            logger.error("Operation failed: \(operation, privacy: .public) with error: \(minuteError.debugSummary, privacy: .public)")
            throw minuteError
        } catch {
            logger.error("Operation failed: \(operation, privacy: .public) with error: \(String(describing: error), privacy: .public)")
            throw defaultError
        }
    }
    
    /// Executes an async throwing operation and maps any errors to MinuteError.
    /// - Parameters:
    ///   - operation: The operation description for logging
    ///   - defaultError: The default MinuteError to use if the caught error is not already a MinuteError
    ///   - work: The async throwing work to perform
    /// - Returns: The result of the work
    /// - Throws: MinuteError
    public static func execute<T>(
        operation: String,
        defaultError: MinuteError,
        work: () async throws -> T
    ) async throws -> T {
        do {
            return try await work()
        } catch is CancellationError {
            logger.info("Operation cancelled: \(operation, privacy: .public)")
            throw CancellationError()
        } catch let minuteError as MinuteError {
            logger.error("Operation failed: \(operation, privacy: .public) with error: \(minuteError.debugSummary, privacy: .public)")
            throw minuteError
        } catch {
            logger.error("Operation failed: \(operation, privacy: .public) with error: \(String(describing: error), privacy: .public)")
            throw defaultError
        }
    }
}
```

2. Use the error handler throughout the codebase:

```swift
// Example usage in DefaultAudioService
public func stopRecording() async throws -> AudioCaptureResult {
    return try await ErrorHandler.execute(
        operation: "Stop recording",
        defaultError: .audioExportFailed
    ) {
        try Task.checkCancellation()
        
        guard let engine else {
            throw MinuteError.audioExportFailed
        }
        
        // Rest of the implementation...
    }
}

// Example usage in MeetingPipelineCoordinator
public func execute(
    context: PipelineContext,
    progress: (@Sendable (PipelineProgress) -> Void)? = nil
) async throws -> PipelineResult {
    return try await ErrorHandler.execute(
        operation: "Pipeline execution",
        defaultError: .vaultWriteFailed
    ) {
        try Task.checkCancellation()
        
        progress?(.downloadingModels(fractionCompleted: 0))
        try await modelManager.ensureModelsPresent { update in
            let clamped = min(max(update.fractionCompleted, 0), 1)
            progress?(.downloadingModels(fractionCompleted: clamped * 0.1))
        }
        
        // Rest of the implementation...
    }
}
```

These implementation priorities address the most critical issues identified in the codebase and provide a solid foundation for further improvements.