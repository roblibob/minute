# 08 — Atomic Vault Writing and Output Contract

## Goal
Implement writing to the Obsidian vault in a way that is:
- Atomic (no partial files)
- Deterministic (fixed paths and template)
- Constrained (writes only inside the selected vault)
- Produces exactly three artifacts per processed meeting (two `.md`, one `.wav`)

## Deliverables
- `MeetingFileContract` that computes output paths
- `VaultWriter` that performs atomic writes
- Directory creation for `Meetings/YYYY/MM/`, `Meetings/_audio/`, and `Meetings/_transcripts/`
- Collision strategy for duplicate titles
- End-to-end pipeline writes all three artifacts correctly

## Output paths (fixed contract)
### Markdown note
- `Meetings/YYYY/MM/YYYY-MM-DD HH.MM - <Title>.md`

### Audio
- `Meetings/_audio/YYYY-MM-DD HH.MM - <Title>.wav`

### Transcript Markdown
- `Meetings/_transcripts/YYYY-MM-DD HH.MM - <Title>.md`

Where `<Title>` is derived from the validated extraction (phase 07), sanitized for filenames.

## Contract enforcement rules
- Exactly three final artifacts are written to the vault: meeting note, audio WAV, transcript Markdown.
- Transcript is written as its own Markdown file (not embedded into the meeting note body).
- Intermediate/temporary files remain in app temp directories.

## Atomic write strategy (macOS)
Use “write temp then rename” in the same directory:
1. Ensure parent directory exists.
2. Write to `.<filename>.tmp` in the same folder.
3. Call `FileManager.replaceItemAt` or `moveItem` to the final name.

For the WAV:
- If WAV export occurs in temp, copy into a temp destination within the vault folder, then replace/move to final name.

This avoids partially-written files if the app crashes.

## Collision handling
If the target filename already exists:
- Append a suffix: `YYYY-MM-DD HH.MM - <Title> (2).md` and similarly for WAV
- Ensure both artifacts share the same suffix so links remain correct

Implement this as a single “reservation” step that determines final URLs for both note and audio.

## Vault access boundary
All `VaultWriter` operations must be executed inside the `VaultAccess.withVaultAccess {}` scope to ensure security-scoped access is active.

Add a defense check:
- Assert final output URLs are descendants of `vaultRootURL`.

## Links in the note
Render links as required:
- Audio: `[[Meetings/_audio/YYYY-MM-DD HH.MM - <Title>.wav]]`
- Transcript: `[[Meetings/_transcripts/YYYY-MM-DD HH.MM - <Title>.md]]`

Ensure that paths stored in frontmatter (`audio:` and `transcript:`) match exactly.

## End-to-end integration
At the end of processing:
1. Determine final title/date from validated extraction.
2. Compute final output URLs.
3. Copy WAV into vault audio path atomically.
4. Write transcript Markdown atomically.
5. Render meeting-note Markdown using the final audio + transcript paths.
6. Write meeting-note Markdown atomically.
7. Return success state with URLs for note + audio (and transcript, if tracked).

## Exit criteria checklist
- [ ] After Process, exactly 3 new files appear in the vault
- [ ] Files are placed in the correct folders with correct names
- [ ] Markdown frontmatter and links match the WAV + transcript paths
- [ ] Duplicate titles don’t overwrite; they suffix consistently
- [ ] No temporary artifacts remain in the vault
