import Testing
@testable import Minute

@MainActor
struct SettingsSectionReachabilityTests {
    @Test
    func meetingTypesCategory_isReachableFromCatalog() {
        let categories = SettingsCategoryCatalog.categories(updatesEnabled: true)
        #expect(categories.contains(where: { $0.id == .meetingTypes }))
    }

    @Test
    func fallbackSelection_keepsMeetingTypesWhenAvailable() {
        let categories = SettingsCategoryCatalog.categories(updatesEnabled: true)
        let selection = SettingsCategoryCatalog.fallbackSelection(
            current: .meetingTypes,
            available: categories
        )

        #expect(selection == .meetingTypes)
    }

    @Test
    func knownSpeakerSuggestions_isOwnedBySpeakersCategory() {
        let category = SettingsCategoryCatalog.categoryID(
            for: .knownSpeakerSuggestions,
            updatesEnabled: true
        )

        #expect(category == .speakers)
    }

    @Test
    func representativeSettingsRemainReachableFromTheirCategories() {
        #expect(SettingsCategoryCatalog.categoryID(for: .outputLanguage, updatesEnabled: true) == .general)
        #expect(SettingsCategoryCatalog.categoryID(for: .vaultRoot, updatesEnabled: true) == .storage)
        #expect(SettingsCategoryCatalog.categoryID(for: .microphoneAccess, updatesEnabled: true) == .privacy)
        #expect(SettingsCategoryCatalog.categoryID(for: .summarizationProvider, updatesEnabled: true) == .ai)
        #expect(SettingsCategoryCatalog.categoryID(for: .meetingTypesEditor, updatesEnabled: true) == .meetingTypes)
        #expect(SettingsCategoryCatalog.categoryID(for: .checkForUpdates, updatesEnabled: true) == .updates)
    }
}
