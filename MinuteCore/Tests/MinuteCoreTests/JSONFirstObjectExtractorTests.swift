import Testing
import Foundation
@testable import MinuteCore

struct JSONFirstObjectExtractorTests {
    @Test
    func extractsSimpleObject() {
        let input = "{\"a\":1}"
        let result = JSONFirstObjectExtractor.extractFirstJSONObject(from: input)
        expectEqual(result?.jsonObject, input)
        expectEqual(result?.hasNonWhitespaceOutsideObject, false)
    }

    @Test
    func extractsObjectWithWhitespaceOutside() {
        let input = "\n  {\"a\":1}\n"
        let result = JSONFirstObjectExtractor.extractFirstJSONObject(from: input)
        expectEqual(result?.jsonObject, "{\"a\":1}")
        expectEqual(result?.hasNonWhitespaceOutsideObject, false)
    }

    @Test
    func extractsObjectWhenPrefixedByLogs() {
        let input = "llama: loading model\n{\"a\":1}"
        let result = JSONFirstObjectExtractor.extractFirstJSONObject(from: input)
        expectEqual(result?.jsonObject, "{\"a\":1}")
        expectEqual(result?.hasNonWhitespaceOutsideObject, true)
    }

    @Test
    func extractsNestedObject() {
        let input = "prefix {\"a\":{\"b\":2}} suffix"
        let result = JSONFirstObjectExtractor.extractFirstJSONObject(from: input)
        expectEqual(result?.jsonObject, "{\"a\":{\"b\":2}}")
        expectEqual(result?.hasNonWhitespaceOutsideObject, true)
    }

    @Test
    func balancesBracesInsideStrings() {
        let input = "{\"a\":\"} not a brace\",\"b\":{\"c\":\"{\"}}"
        let result = JSONFirstObjectExtractor.extractFirstJSONObject(from: input)
        expectEqual(result?.jsonObject, input)
        expectEqual(result?.hasNonWhitespaceOutsideObject, false)
    }

    @Test
    func returnsNilWhenNoObjectExists() {
        let input = "no json here"
        let result = JSONFirstObjectExtractor.extractFirstJSONObject(from: input)
        #expect(result == nil)
    }
}
