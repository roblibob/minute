import Foundation

public enum MeetingTypeLibraryStoreError: Error, Sendable, Equatable {
    case unknownTypeID(String)
    case typeIsNotBuiltIn(String)
    case typeIsNotEditable(String)
    case typeIsNotCustom(String)
    case typeAlreadyDeleted(String)
    case duplicateDisplayName(String)
}

// `@unchecked Sendable` is safe here because all mutable state access is serialized by `lock`.
public final class MeetingTypeLibraryStore: MeetingTypeLibraryStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let libraryKey: String
    private let lock = NSRecursiveLock()

    public init(
        defaults: UserDefaults = .standard,
        libraryKey: String = "meetingTypeLibrary"
    ) {
        self.defaults = defaults
        self.libraryKey = libraryKey
        lock.name = "MeetingTypeLibraryStore.lock"
    }

    public func load() -> MeetingTypeLibrary {
        withLock {
            loadUnlocked()
        }
    }

    public func save(_ library: MeetingTypeLibrary) {
        withLock {
            _ = try? saveValidatedUnlocked(library)
        }
    }

    @discardableResult
    public func saveValidated(_ library: MeetingTypeLibrary) throws -> MeetingTypeLibrary {
        try withLock {
            try saveValidatedUnlocked(library)
        }
    }

    public func clear() {
        withLock {
            defaults.removeObject(forKey: libraryKey)
        }
    }

    public func listActiveDefinitions() -> [MeetingTypeDefinition] {
        withLock {
            loadUnlocked().activeDefinitions
        }
    }

    public func activeDefinition(typeID: String) -> MeetingTypeDefinition? {
        withLock {
            let normalizedTypeID = typeID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedTypeID.isEmpty else { return nil }
            guard let definition = loadUnlocked().definition(for: normalizedTypeID) else { return nil }
            guard definition.status == .active else { return nil }
            return definition
        }
    }

    public func isTypeAvailable(typeID: String) -> Bool {
        activeDefinition(typeID: typeID) != nil
    }

    public func builtInOverride(for typeID: String) -> BuiltInPromptOverride? {
        withLock {
            let library = loadUnlocked()
            guard let definition = library.definition(for: typeID), definition.source == .builtIn else {
                return nil
            }
            guard let meetingType = MeetingType(rawValue: typeID) else {
                return nil
            }
            let baseline = MeetingTypeLibrary.builtInDefinition(for: meetingType).promptComponents
            let isOverridden = definition.promptComponents != baseline

            return BuiltInPromptOverride(
                typeId: typeID,
                defaultComponents: baseline,
                overrideComponents: definition.promptComponents,
                isOverridden: isOverridden,
                updatedAt: definition.updatedAt
            )
        }
    }

    @discardableResult
    public func saveBuiltInOverride(
        typeID: String,
        promptComponents: PromptComponentSet,
        updatedAt: Date = Date()
    ) throws -> BuiltInPromptOverride {
        try withLock {
            var library = loadUnlocked()
            guard let index = library.definitions.firstIndex(where: { $0.typeId == typeID }) else {
                throw MeetingTypeLibraryStoreError.unknownTypeID(typeID)
            }
            guard library.definitions[index].source == .builtIn else {
                throw MeetingTypeLibraryStoreError.typeIsNotBuiltIn(typeID)
            }
            guard let meetingType = MeetingType(rawValue: typeID) else {
                throw MeetingTypeLibraryStoreError.typeIsNotBuiltIn(typeID)
            }
            guard meetingType != .autodetect else {
                throw MeetingTypeLibraryStoreError.typeIsNotEditable(typeID)
            }

            let updatedPrompt = try promptComponents.validated(typeID: typeID)
            var definition = library.definitions[index]
            definition.promptComponents = updatedPrompt
            definition.updatedAt = updatedAt
            library.definitions[index] = definition
            library.updatedAt = updatedAt
            library.libraryVersion = max(library.libraryVersion + 1, 1)

            let saved = try saveValidatedUnlocked(library)
            let savedDefinition = saved.definition(for: typeID) ?? definition
            let baseline = MeetingTypeLibrary.builtInDefinition(for: meetingType).promptComponents

            return BuiltInPromptOverride(
                typeId: typeID,
                defaultComponents: baseline,
                overrideComponents: savedDefinition.promptComponents,
                isOverridden: savedDefinition.promptComponents != baseline,
                updatedAt: savedDefinition.updatedAt
            )
        }
    }

    @discardableResult
    public func restoreBuiltInDefault(
        typeID: String,
        updatedAt: Date = Date()
    ) throws -> BuiltInPromptOverride {
        try withLock {
            guard let meetingType = MeetingType(rawValue: typeID) else {
                throw MeetingTypeLibraryStoreError.typeIsNotBuiltIn(typeID)
            }
            guard meetingType != .autodetect else {
                throw MeetingTypeLibraryStoreError.typeIsNotEditable(typeID)
            }
            let defaultComponents = MeetingTypeLibrary.builtInDefinition(for: meetingType).promptComponents
            return try saveBuiltInOverride(typeID: typeID, promptComponents: defaultComponents, updatedAt: updatedAt)
        }
    }

    @discardableResult
    public func createCustomType(
        displayName: String,
        promptComponents: PromptComponentSet,
        autodetectEligible: Bool = false,
        classifierProfile: ClassifierProfile? = nil,
        updatedAt: Date = Date()
    ) throws -> MeetingTypeDefinition {
        try withLock {
            var library = loadUnlocked()
            let normalizedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if library.containsDisplayName(normalizedName) {
                throw MeetingTypeLibraryStoreError.duplicateDisplayName(normalizedName)
            }

            let typeID = makeUniqueCustomTypeID(
                displayName: normalizedName,
                existingTypeIDs: Set(library.definitions.map(\.typeId))
            )
            let definition = MeetingTypeDefinition(
                typeId: typeID,
                displayName: normalizedName,
                source: .custom,
                isDeletable: true,
                isEditableName: true,
                autodetectEligible: autodetectEligible,
                promptComponents: promptComponents,
                classifierProfile: classifierProfile,
                updatedAt: updatedAt,
                status: .active
            )
            let validated = try definition.validated()

            library.definitions.append(validated)
            library.libraryVersion = max(library.libraryVersion + 1, 1)
            library.updatedAt = updatedAt
            _ = try saveValidatedUnlocked(library)
            return validated
        }
    }

    @discardableResult
    public func updateCustomType(
        typeID: String,
        displayName: String? = nil,
        promptComponents: PromptComponentSet? = nil,
        autodetectEligible: Bool? = nil,
        classifierProfile: ClassifierProfile? = nil,
        updatedAt: Date = Date()
    ) throws -> MeetingTypeDefinition {
        try withLock {
            var library = loadUnlocked()
            guard let index = library.definitions.firstIndex(where: { $0.typeId == typeID }) else {
                throw MeetingTypeLibraryStoreError.unknownTypeID(typeID)
            }
            guard library.definitions[index].source == .custom else {
                throw MeetingTypeLibraryStoreError.typeIsNotCustom(typeID)
            }
            guard library.definitions[index].status == .active else {
                throw MeetingTypeLibraryStoreError.typeAlreadyDeleted(typeID)
            }

            var definition = library.definitions[index]
            if let displayName {
                let normalizedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                if library.containsDisplayName(normalizedName, excludingTypeID: typeID) {
                    throw MeetingTypeLibraryStoreError.duplicateDisplayName(normalizedName)
                }
                definition.displayName = normalizedName
            }
            if let promptComponents {
                definition.promptComponents = promptComponents
            }
            if let autodetectEligible {
                definition.autodetectEligible = autodetectEligible
            }
            if let classifierProfile {
                definition.classifierProfile = classifierProfile
            } else if autodetectEligible == false {
                definition.classifierProfile = nil
            }
            definition.updatedAt = updatedAt

            let validated = try definition.validated()
            library.definitions[index] = validated
            library.libraryVersion = max(library.libraryVersion + 1, 1)
            library.updatedAt = updatedAt
            _ = try saveValidatedUnlocked(library)
            return validated
        }
    }

    @discardableResult
    public func deleteCustomType(
        typeID: String,
        updatedAt: Date = Date()
    ) throws -> MeetingTypeDefinition {
        try withLock {
            var library = loadUnlocked()
            guard let index = library.definitions.firstIndex(where: { $0.typeId == typeID }) else {
                throw MeetingTypeLibraryStoreError.unknownTypeID(typeID)
            }
            guard library.definitions[index].source == .custom else {
                throw MeetingTypeLibraryStoreError.typeIsNotCustom(typeID)
            }
            guard library.definitions[index].status == .active else {
                throw MeetingTypeLibraryStoreError.typeAlreadyDeleted(typeID)
            }

            var definition = library.definitions[index]
            definition.status = .deleted
            definition.updatedAt = updatedAt
            library.definitions[index] = definition
            library.libraryVersion = max(library.libraryVersion + 1, 1)
            library.updatedAt = updatedAt
            _ = try saveValidatedUnlocked(library)
            return definition
        }
    }

    private func makeUniqueCustomTypeID(displayName: String, existingTypeIDs: Set<String>) -> String {
        let normalizedBase: String = {
            let lowercase = displayName.lowercased()
            let scalars = lowercase.unicodeScalars.map { scalar -> Character in
                if CharacterSet.alphanumerics.contains(scalar) {
                    return Character(scalar)
                }
                return "-"
            }
            let raw = String(scalars)
            let collapsed = raw.replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            let trimmed = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
            return trimmed.isEmpty ? "custom-meeting" : trimmed
        }()

        let baseID = "custom-\(normalizedBase)"
        if !existingTypeIDs.contains(baseID) {
            return baseID
        }

        var suffix = 2
        while existingTypeIDs.contains("\(baseID)-\(suffix)") {
            suffix += 1
        }
        return "\(baseID)-\(suffix)"
    }

    private func loadUnlocked() -> MeetingTypeLibrary {
        guard let data = defaults.data(forKey: libraryKey) else {
            return .default
        }
        do {
            let decoded = try JSONDecoder().decode(MeetingTypeLibrary.self, from: data)
            let reconciled = reconcileBuiltInDefinitions(in: decoded)
            return try reconciled.validated()
        } catch {
            return .default
        }
    }

    /// Merges built-in meeting types added in newer app versions into a
    /// previously saved library, so users who stored a library before an
    /// update still see the full built-in catalog. Existing definitions
    /// (including built-in overrides) are left untouched.
    private func reconcileBuiltInDefinitions(in library: MeetingTypeLibrary) -> MeetingTypeLibrary {
        let knownTypeIDs = Set(library.definitions.map(\.typeId))
        let missing = MeetingType.allCases
            .filter { !knownTypeIDs.contains($0.rawValue) }
            .map(MeetingTypeLibrary.builtInDefinition(for:))
        guard !missing.isEmpty else { return library }

        var updated = library
        updated.definitions.append(contentsOf: missing)
        return updated
    }

    @discardableResult
    private func saveValidatedUnlocked(_ library: MeetingTypeLibrary) throws -> MeetingTypeLibrary {
        let validated = try library.validated()
        let data = try JSONEncoder().encode(validated)
        defaults.set(data, forKey: libraryKey)
        return validated
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}
