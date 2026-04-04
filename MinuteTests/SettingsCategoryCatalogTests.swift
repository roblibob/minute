import Testing
@testable import Minute

@MainActor
struct SettingsCategoryCatalogTests {
    @Test
    func meetingTypesCategory_isIncludedWhenUpdatesEnabled() {
        let categories = SettingsCategoryCatalog.categories(updatesEnabled: true)
        #expect(categories.contains(where: { $0.id == .meetingTypes }))
    }

    @Test
    func meetingTypesCategory_isOrderedAfterAIAndBeforeUpdates() {
        let categories = SettingsCategoryCatalog.categories(updatesEnabled: true)
        let aiIndex = categories.firstIndex(where: { $0.id == .ai })
        let meetingTypesIndex = categories.firstIndex(where: { $0.id == .meetingTypes })
        let updatesIndex = categories.firstIndex(where: { $0.id == .updates })

        #expect(aiIndex != nil)
        #expect(meetingTypesIndex != nil)
        #expect(updatesIndex != nil)
        #expect(aiIndex! < meetingTypesIndex!)
        #expect(meetingTypesIndex! < updatesIndex!)
    }

    @Test
    func everySettingsEntry_hasExactlyOneCategoryOwner() {
        let entries = SettingsCategoryCatalog.entries(updatesEnabled: true)

        #expect(entries.count == SettingsEntryDefinition.ID.allCases.count)

        for entryID in SettingsEntryDefinition.ID.allCases {
            let matches = entries.filter { $0.id == entryID }
            #expect(matches.count == 1)
        }
    }
}
