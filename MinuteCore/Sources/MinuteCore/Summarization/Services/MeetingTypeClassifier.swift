//
//  MeetingTypeClassifier.swift
//  MinuteCore
//
//  Created for Feature 003-meeting-type-prompts
//

import Foundation

public enum MeetingTypeClassifier {
    
    /// Generates the prompt for the first-pass classification.
    /// - Parameter transcript: A representative snippet of the transcript (e.g. first 2000 tokens).
    /// - Returns: The classification prompt string.
    public static func prompt(for transcript: String) -> String {
        return """
        Analyze the following meeting transcript snippet and classify it into exactly one of these categories:
        - General
        - Standup
        - Design Review
        - One-on-One
        - Presentation
        - Planning
        
        Return ONLY the category name. Do not add markdown or explanations.
        
        Snippet:
        \(transcript)
        """
    }
    
    /// Parses the LLM response into a MeetingType.
    /// - Parameter response: The raw string response from the LLM.
    /// - Returns: The determined MeetingType, defaulting to .general if ambiguous.
    public static func parseResponse(_ response: String) -> MeetingType {
        let normalized = response.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Simple heuristic matching
        if normalized.contains("standup") { return .standup }
        if normalized.contains("design") || normalized.contains("review") { return .designReview }
        if normalized.contains("one") || normalized.contains("1:1") { return .oneOnOne }
        if normalized.contains("presentation") || normalized.contains("talk") { return .presentation }
        if normalized.contains("planning") || normalized.contains("roadmap") || normalized.contains("sprint") { return .planning }
        
        return .general
    }
}
