import XCTest
@testable import MinuteCore

final class JSONFirstObjectExtractorTests: XCTestCase {
    func test_extractsSimpleObject() {
        let input = "{\"a\":1}"
        let result = JSONFirstObjectExtractor.extractFirstJSONObject(from: input)
        XCTAssertEqual(result?.jsonObject, input)
        XCTAssertEqual(result?.hasNonWhitespaceOutsideObject, false)
    }

    func test_extractsObjectWithWhitespaceOutside() {
        let input = "\n  {\"a\":1}\n"
        let result = JSONFirstObjectExtractor.extractFirstJSONObject(from: input)
        XCTAssertEqual(result?.jsonObject, "{\"a\":1}")
        XCTAssertEqual(result?.hasNonWhitespaceOutsideObject, false)
    }

    func test_extractsObjectWhenPrefixedByLogs() {
        let input = "llama: loading model\n{\"a\":1}"
        let result = JSONFirstObjectExtractor.extractFirstJSONObject(from: input)
        XCTAssertEqual(result?.jsonObject, "{\"a\":1}")
        XCTAssertEqual(result?.hasNonWhitespaceOutsideObject, true)
    }

    func test_extractsNestedObject() {
        let input = "prefix {\"a\":{\"b\":2}} suffix"
        let result = JSONFirstObjectExtractor.extractFirstJSONObject(from: input)
        XCTAssertEqual(result?.jsonObject, "{\"a\":{\"b\":2}}")
        XCTAssertEqual(result?.hasNonWhitespaceOutsideObject, true)
    }

    func test_balancesBracesInsideStrings() {
        let input = "{\"a\":\"} not a brace\",\"b\":{\"c\":\"{\"}}"
        let result = JSONFirstObjectExtractor.extractFirstJSONObject(from: input)
        XCTAssertEqual(result?.jsonObject, input)
        XCTAssertEqual(result?.hasNonWhitespaceOutsideObject, false)
    }

    func test_returnsNilWhenNoObjectExists() {
        let input = "no json here"
        let result = JSONFirstObjectExtractor.extractFirstJSONObject(from: input)
        XCTAssertNil(result)
    }
}
