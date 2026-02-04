//
//  PromptStrategy.swift
//  MinuteCore
//
//  Created for Feature 003-meeting-type-prompts
//

import Foundation

/// Defines the contract for generating AI prompts based on specific meeting types.
public protocol PromptStrategy {
    /// The specific meeting type this strategy serves.
    var meetingType: MeetingType { get }
    
    /// Generates the system prompt that defines the AI's persona and output constraints.
    /// - Returns: A string containing the system instructions and JSON schema.
    func systemPrompt() -> String
    
    /// Generates the user prompt containing the transcript to be processed.
    /// - Parameter transcript: The full text of the meeting transcript.
    /// - Returns: A formatted string instructing the model to process the specific transcript.
    func userPrompt(for transcript: String) -> String
}
