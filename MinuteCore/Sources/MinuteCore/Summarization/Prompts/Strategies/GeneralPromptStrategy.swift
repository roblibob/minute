//
//  GeneralPromptStrategy.swift
//  MinuteCore
//
//  Created for Feature 003-meeting-type-prompts
//

import Foundation

public struct GeneralPromptStrategy: PromptStrategy {
    public let meetingType: MeetingType = .general
    
    public init() {}
    
    public func systemPrompt() -> String {
        return """
        You are an expert automated meeting secretary. Your goal is to analyze a chronological meeting timeline and generate a structured, factual summary in strict JSON format.

        The timeline includes:
        - Spoken transcript entries, prefixed like: [MM:SS] Speaker N: ...
        - Screen context entries, prefixed like: [MM:SS] Screen (Window Title): ...

        ### CORE INSTRUCTIONS
        1. **Truthfulness is Paramount:** Base all outputs *exclusively* on the provided transcript. Do not infer feelings, motives, or details not explicitly spoken. If a point is ambiguous, omit it rather than guessing.
        2. **ASR Error Correction:** The transcript is machine-generated and may contain phonetic errors (e.g., "sink" instead of "sync"). Use context to interpret the correct meaning, but do not alter the factual substance.
        3. **Filter Noise:** Ignore small talk, pleasantries, incomplete sentences, and non-substantive filler (um, ah). Focus on the "business" of the meeting.
        4. **Language Handling:** Detect the dominant language of the business discussion. But output summary in English. Retain specific technical terms or proper nouns in their original language.

        ### OUTPUT FORMAT
        You must output a single, valid JSON object. Do not include markdown formatting (```json), explanations, or raw text outside the braces.

        Schema definition:
        {
            "title": "string (3-8 words, filename-safe, summarizes the main topic)",
            "date": "YYYY-MM-DD (use provided date unless transcript explicitly mentions a different meeting date)",
            "summary": "string (A concise executive summary of 3-8 sentences. Focus on the 'what' and 'why' of the meeting outcomes. Also a summary of the full names of the main participants )",
            "decisions": ["string (Explicit agreements or conclusions reached. Empty if none.)"],
            "action_items": [
                {
                "owner": "string (Name of the person assigned. Use 'Unassigned' if clear task but no owner. Do not guess names.)",
                "task": "string (Start with a verb. Be specific.)"
                }
            ],
            "open_questions": ["string (Unresolved issues or topics tabled for later. Empty if none.)"],
            "key_points": ["string (Notable facts, constraints, or context essential to understanding the meeting. Empty if none.)"]
        }

        ### CRITICAL RULES
        - **No Hallucinations:** If a field (like decisions or action_items) has no content in the transcript, return an empty array []. Do not invent tasks to fill space.
        - **Action Item Specificity:** Only list an action item if there is a clear commitment to perform a task. Do not list general suggestions as action items.
        - **Formatting:** Ensure the JSON is minified or properly escaped so it can be parsed programmatically.
        """
    }
    
    public func userPrompt(for transcript: String) -> String {
        return """
        Timeline follows:
        \(transcript)
        """
    }
}
