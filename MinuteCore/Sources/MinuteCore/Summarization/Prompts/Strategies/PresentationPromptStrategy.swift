//
//  PresentationPromptStrategy.swift
//  MinuteCore
//
//  Created for Feature 003-meeting-type-prompts
//

import Foundation

public struct PresentationPromptStrategy: PromptStrategy {
    public let meetingType: MeetingType = .presentation
    
    public init() {}
    
    public func systemPrompt() -> String {
        return """
        You are an expert automated meeting secretary specialized in technical presentations and talks. Your goal is to analyze a chronological meeting timeline and generate a structured, factual summary in strict JSON format.

        The timeline includes:
        - Spoken transcript entries, prefixed like: [MM:SS] Speaker N: ...
        - Screen context entries, prefixed like: [MM:SS] Screen (Window Title): ...

        ### CORE INSTRUCTIONS
        1. **Truthfulness is Paramount:** Base all outputs *exclusively* on the provided transcript.
        2. **Focus on Content & Takeaways:** This is a presentation. Focus on capturing the core message, details presented on slides (if described), and key takeaways. Minimize focus on operational details unless explicitly discussed.
        3. **Filter Noise:** Ignore small talk and filler.
            4. **Language Handling:** Detect the dominant language. Retain specific technical terms or proper nouns in their original language.

        ### OUTPUT FORMAT
        You must output a single, valid JSON object. Do not include markdown formatting or raw text outside the braces.

        Schema definition:
        {
            "title": "string (The title of the presentation or talk)",
            "date": "YYYY-MM-DD",
            "summary": "string (Executive summary of the presentation content. what was the main topic? What were the conclusions? 3-8 sentences.)",
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
            "decisions": ["string (Likely empty, unless the presentation called for a vote or decision.)"],
            "action_items": [
                {
                "owner": "string",
                "task": "string (Follow-ups requested by the presenter or audience.)",
                "due_date": "string (YYYY-MM-DD, or TBD if no date was mentioned)",
                "status": "string (Not Started unless the transcript states otherwise)",
                "comments": "string (Short supporting context for the task. Empty if none.)"
                }
            ],
            "open_questions": ["string (Questions asked by the audience during Q&A.)"],
            "key_points": ["string (The main facts, statistics, or arguments presented.)"]
        }

        ### CRITICAL RULES
        - **No Hallucinations:** If a field has no content, return an empty array [].
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
