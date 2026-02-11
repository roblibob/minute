import Foundation
import Testing
@testable import MinuteCore

struct OutputLanguageTests {
    @Test
    func resolved_whenRawValueMissing_returnsDefault() {
        let resolved = OutputLanguage.resolved(from: nil)
        #expect(resolved == AppConfiguration.Defaults.defaultOutputLanguage)
    }

    @Test
    func resolved_whenRawValueInvalid_returnsDefault() {
        let resolved = OutputLanguage.resolved(from: "invalid")
        #expect(resolved == AppConfiguration.Defaults.defaultOutputLanguage)
    }

    @Test
    func instructions_includeDisplayNameAndCode() {
        let language = OutputLanguage.japaneseJapan
        #expect(language.summarizationSystemInstruction.contains(language.displayName))
        #expect(language.summarizationSystemInstruction.contains(language.rawValue))
        #expect(language.summarizationUserInstruction.contains(language.displayName))
        #expect(language.summarizationUserInstruction.contains(language.rawValue))
    }
}
