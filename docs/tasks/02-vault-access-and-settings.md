# 02 — Vault Access and Settings

## Goal
Implement sandbox-safe Obsidian vault folder selection and persistence using security-scoped bookmarks, plus a minimal Settings UI to configure the Meetings folder and Audio folder relative to the vault.

This phase unlocks reliable file I/O in a notarized, sandboxed app.

## Deliverables
- Vault root selection via `NSOpenPanel`
- Persisted security-scoped bookmark for vault root
- Safe access wrapper that ensures `startAccessingSecurityScopedResource()` / `stopAccessing...` correctness
- Settings screen to configure:
  - Meetings folder relative path (default `Meetings/`)
  - Audio folder relative path (default `Meetings/_audio/`)
  - Transcript folder relative path (default `Meetings/_transcripts/`)
- A “Verify access” action that creates required directories (without writing audio/note yet)

## Data model
Create types in `MinuteCore`:
- `VaultConfiguration`
  - `vaultRootBookmark: Data`
  - `meetingsRelativePath: String`
  - `audioRelativePath: String`
  - `transcriptsRelativePath: String`
- `VaultLocation`
  - `vaultRootURL: URL`
  - computed `meetingsFolderURL`, `audioFolderURL`, and `transcriptsFolderURL`

Store user-editable settings in `UserDefaults` (simple, sufficient for v1). Keep the bookmark data in `UserDefaults` too; Keychain is optional and not necessary for security-scoped bookmarks.

## Folder selection flow
1. Present `NSOpenPanel` configured for directories only.
2. After user selects a directory URL:
   - Create a security-scoped bookmark with `.withSecurityScope`.
   - Save to settings store.
3. When accessing the vault:
   - Resolve bookmark to URL.
   - Start security-scoped access.
   - Perform file operations.
   - Stop access.

### Best-practice wrapper
Implement a helper that encapsulates this pattern:
- `VaultAccess.withVaultAccess { vaultRootURL in ... }`

It should:
- Fail fast if bookmark is missing or stale
- Handle stale bookmarks by asking user to reselect (surface a clear UI error)
- Ensure `stopAccessing...` is always called (use `defer`)

## Path safety and constraints
- All reads/writes must be constrained under `vaultRootURL`.
- Resolve relative paths using `URL.appendingPathComponent` (not string concatenation).
- Normalize and validate that resulting URLs are still within the vault root (defense-in-depth).

## Directory creation
Implement `VaultWriter.ensureDirectoriesExist()` that creates:
- Meetings folder hierarchy `Meetings/YYYY/MM/` as needed at write time
- Audio folder `Meetings/_audio/`
- Transcript folder `Meetings/_transcripts/`

For this phase, create only:
- base configured meetings folder, audio folder, and transcript folder

## Settings UI
Add a Settings screen with:
- Vault selection status (selected folder name + path)
- “Choose vault folder…” button
- Text fields for meetings/audio relative paths with defaults
- “Verify access” button that:
  - Resolves vault URL
  - Starts security scope
  - Ensures directories exist
  - Shows success/failure banner

Use `@AppStorage` for simple settings keys, or a small `SettingsStore` observable object.

## Exit criteria checklist
- [ ] User can select vault folder and it persists across relaunch
- [ ] App can create meetings/audio directories inside the vault (sandbox-safe)
- [ ] If bookmark is stale, the app surfaces a clear “reselect vault” flow
