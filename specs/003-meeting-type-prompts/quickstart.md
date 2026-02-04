# Quickstart Guide: Meeting Type Prompts

**Feature Branch**: `003-meeting-type-prompts`
**Date**: 2026-02-04

This guide outlines the development steps to implement tailored meeting prompts.

## 1. Core Logic (MinuteCore)

1.  **Define Enum**: Create `MeetingType.swift` in `MinuteCore/Domain`.
    -   Include cases: `general`, `standup`, `designReview`, `oneOnOne`, `presentation`, `planning`, `autodetect`.
    -   Conform to `Codable`, `CaseIterable`.

2.  **Define Strategy**: Create `PromptStrategy.swift` in `MinuteCore/Summarization/Prompts`.
    -   Protocol with `func systemPrompt(...) -> String`.

3.  **Implement Strategies**: Create concrete classes for each type.
    -   `GeneralPromptStrategy` (Move existing prompt here).
    -   `PresentationPromptStrategy` (New).
    -   `StandupPromptStrategy` (New).
    -   ...etc.

4.  **Prompt Factory**: Create `PromptFactory` to return the correct strategy for a `MeetingType`.

5.  **Autodetect Logic**:
    -   Implement `func detectMeetingType(transcript: String) async throws -> MeetingType`.
    -   Use a lightweight prompt asking Llama to classify the first N tokens.

6.  **Update Service**: Update `LlamaLibrarySummarizationService`.
    -   Accept `meetingType`.
    -   If `autodetect`, call detection logic first.
    -   Use `PromptFactory` to get prompt.

## 2. UI Implementation (Minute)

1.  **ViewModel**: Update `RecorderViewModel`.
    -   Add `published var selectedMeetingType: MeetingType = .autodetect`.
    -   On `init`, default to `.autodetect` (per spec reset requirement).
    -   Add persistence logic: save to meeting metadata when changed.

2.  **View**: Update `RecorderView`.
    -   Add a `Picker` or `Menu` displaying specific icons/names for types.
    -   Bind to `viewModel.selectedMeetingType`.

## 3. Wiring & Tests

1.  **Unit Tests**:
    -   Test `PromptFactory` returns correct type.
    -   Test each `PromptStrategy` outputs expected JSON structure instruction.
    -   Test `detectMeetingType` logic (mocking Llama output).

2.  **Integration**:
    -   Run app, record, switch types.
    -   Verify "Presentation" yields a presentation-focused summary.
    -   Verify "Autodetect" works on a known sample.
