//
//  StandupPromptStrategy.swift
//  MinuteCore
//
//  Created for Feature 003-meeting-type-prompts
//

import Foundation

public struct StandupPromptStrategy: PromptStrategy {
    public let meetingType: MeetingType = .standup
    
    public init() {}
    
    public func systemPrompt() -> String {
        return """
        You are an expert automated meeting secretary specialized in daily standups. Your goal is to analyze a chronological standup meeting timeline and generate a structured, factual summary in strict JSON format.

        The timeline includes:
        - Spoken transcript entries, prefixed like: [MM:SS] Speaker N: ...
        - Screen context entries, prefixed like: [MM:SS] Screen (Window Title): ...

        ### CORE INSTRUCTIONS
        1. **Truthfulness is Paramount:** Base all outputs *exclusively* on the provided transcript. Do not infer feelings, motives, or details not explicitly spoken.
        2. **Focus on Progress & Blockers:** This is a standup. Prioritize extracting what was achieved, what is planned next, and any blockers.
        3. **Filter Noise:** Ignore small talk, pleasantries, incomplete sentences, and non-substantive filler.
            4. **Language Handling:** Detect the dominant language. Retain specific technical terms or proper nouns in their original language.

        ### OUTPUT FORMAT
        You must output a single, valid JSON object. Do not include markdown formatting or raw text outside the braces.

        Schema definition:
        {
            "title": "string (defaults to 'Daily Standup - YYYY-MM-DD' unless a specific topic is mentioned)",
            "date": "YYYY-MM-DD",
            "summary": "string (Concise summary of team progress, major blockers, and announcements. 3-8 sentences.)",
            "participants": [
                {
                "name": "string (Participant name; use Speaker N if the real name is not inferable. Never guess names.)",
                "role": "string (Role or relationship if identifiable, e.g. Manager, Presenter, Candidate. Empty if unknown.)"
                }
            ],
            "topics": [
                {
                "title": "string (Short topic title)",
                "points": ["string (Detail points for this topic: context, key points raised by each participant, data or specifics mentioned.)"]
                }
            ],
            "decisions": ["string (Usually empty for standups, unless a process change is agreed upon.)"],
            "action_items": [
                {
                "owner": "string",
                "task": "string (Focus on blockers intended to be resolved or follow-ups.)",
                "due_date": "string (YYYY-MM-DD, or TBD if no date was mentioned)",
                "status": "string (Not Started unless the transcript states otherwise)",
                "comments": "string (Short supporting context for the task. Empty if none.)"
                }
            ],
            "open_questions": ["string"],
            "key_points": ["string (Notable updates or status changes.)"]
        }

        ### CRITICAL RULES
        - **No Hallucinations:** If a field has no content, return an empty array [].
        - **Action Item Specificity:** Only list real commitments.
        - **Formatting:** Ensure the JSON is minified or properly escaped.
        """
    }
    
    public func userPrompt(for transcript: String) -> String {
        return """
        Timeline follows:
        \(transcript)
        """
    }
}
