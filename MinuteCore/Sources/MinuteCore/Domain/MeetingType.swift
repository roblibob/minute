//
//  MeetingType.swift
//  MinuteCore
//
//  Created for Feature 003-meeting-type-prompts
//

import Foundation

/// Represents the nature of the meeting to guide AI summarization strategies.
public enum MeetingType: String, CaseIterable, Codable, Sendable {
    /// The system will analyze the transcript to determine the best fit strategy
    case autodetect
    
    /// A balanced summary suitable for most standard business meetings
    case general
    
    /// Optimized for daily status updates, progress, and blockers
    case standup
    
    /// Focuses on design decisions, visual feedback, and critiques
    case designReview = "design_review"
    
    /// Focused on career development, personal feedback, and alignment
    case oneOnOne = "one_on_one"
    
    /// Optimized for technical talks, demos, or slides; focusing on key takeaways
    case presentation
    
    /// Focused on task allocation, timelines, and roadmap discussions
    case planning

    /// You are the interviewer evaluating a candidate; focuses on questions, responses, and hiring signals
    case interviewTaken = "interview_taken"

    /// You are the candidate being interviewed; focuses on questions asked, your approach, and learnings
    case interviewGiven = "interview_given"

    /// Org-wide updates and leadership Q&A; focuses on announcements, metrics, and key messages
    case allHands = "all_hands"

    /// Sprint retro or post-mortem; focuses on what went well, what didn't, and improvements
    case retrospective
}

extension MeetingType {
    public var displayName: String {
        switch self {
        case .autodetect: return "Autodetect"
        case .general: return "General"
        case .standup: return "Standup"
        case .designReview: return "Design Review"
        case .oneOnOne: return "One-on-One"
        case .presentation: return "Presentation"
        case .planning: return "Planning"
        case .interviewTaken: return "Interview — Taken"
        case .interviewGiven: return "Interview — Given"
        case .allHands: return "All Hands"
        case .retrospective: return "Retrospective"
        }
    }
}
