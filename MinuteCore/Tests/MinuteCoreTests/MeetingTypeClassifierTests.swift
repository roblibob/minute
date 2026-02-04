//
//  MeetingTypeClassifierTests.swift
//  MinuteCore
//
//  Created for Feature 003-meeting-type-prompts
//

import XCTest
@testable import MinuteCore

final class MeetingTypeClassifierTests: XCTestCase {

    func testPromptGeneration() {
        let snippet = "Alice: What did you do yesterday?\nBob: I fixed the bug."
        let prompt = MeetingTypeClassifier.prompt(for: snippet)
        
        XCTAssertTrue(prompt.contains(snippet))
        XCTAssertTrue(prompt.contains("Standup"))
        XCTAssertTrue(prompt.contains("Design Review"))
        XCTAssertTrue(prompt.contains("Return ONLY the category name"))
    }
    
    func testResponseParsing() {
        let cases: [(String, MeetingType)] = [
            ("Standup", .standup),
            ("standup", .standup),
            ("This is a Standup", .standup),
            ("Design Review", .designReview),
            ("Design", .designReview),
            ("One-on-One", .oneOnOne),
            ("1:1", .oneOnOne),
            ("Planning", .planning),
            ("Roadmap", .planning),
            ("Presentation", .presentation),
            ("Talk", .presentation),
            ("Unknown", .general),
            ("General", .general)
        ]
        
        for (input, expected) in cases {
            let result = MeetingTypeClassifier.parseResponse(input)
            XCTAssertEqual(result, expected, "Failed to parse input: \(input)")
        }
    }
}
