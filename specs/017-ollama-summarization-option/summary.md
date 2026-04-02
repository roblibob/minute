# 017 — Ollama Summarization Option: Summary

**Branch**: `017-ollama-summarization-option`
**Status**: Draft
**Created**: 2026-03-24

## Overview

This feature lets advanced users choose between **Built-in (llama.cpp)** and **Ollama** as the inference provider for both **summarization** and **vision/screen-context** tasks — independently of each other and independently of transcription.

## Key Points

- **Separate controls for summarization and vision**: Users can pick a different provider and model for each capability (e.g., Ollama for summarization, Built-in for vision).
- **Surfaced in both wizard and settings**: Provider/model choices appear during first-run setup and remain editable in Settings at any time.
- **No re-onboarding required**: Changing provider or model later doesn't force users back through the wizard.
- **In-flight safety**: A running summarization or vision task keeps the provider/model it started with, even if settings change mid-task.
- **Upgrade-safe defaults**: Existing users upgrading to this version receive sensible Built-in defaults for both capabilities — no breakage.
- **Local-only**: Ollama is treated as a local runtime; no cloud calls are introduced. The existing three-file vault output contract is preserved.
- **Validation**: If a user picks a vision model that doesn't actually support vision, the app blocks the selection with a clear message.

## User Stories

| # | Story | Priority |
|---|-------|----------|
| 1 | Choose summarization provider/model during setup wizard | P1 |
| 2 | Configure vision separately from summarization | P2 |
| 3 | Adjust AI configuration later in settings with clear feedback on unavailable providers | P3 |

## Core Requirements (25 functional, 5 non-functional)

- Independent provider/model persistence per capability
- Built-in and Ollama offered for both summarization and vision
- Wizard and settings share the same options and current values
- Clear, actionable validation when a provider or model is unavailable
- UI remains responsive; no main-thread blocking
- Deterministic vault output contract (three files per meeting) unaffected

## Key Entities

- **Inference Capability** — summarization or vision
- **Inference Provider** — Built-in or Ollama
- **Inference Configuration Preference** — persisted per-capability setting
- **Capability Availability State** — readiness status of the selected provider/model
- **Inference Run Context** — per-task binding to the provider/model at task start

## Success Criteria

- 100% of clean installs can set both providers in the wizard
- 100% of existing users retain valid Built-in defaults after upgrade
- Settings changes take < 45 seconds
- In-progress tasks are never disrupted by config changes
- 90%+ of advanced test users correctly distinguish summarization, vision, and transcription on first attempt
- Zero regressions to the vault output contract

---
*Auto-generated summary from [[Roblibob/Minute/Specs/017-ollama-summarization-option/spec|full spec]]*