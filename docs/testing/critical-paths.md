# Critical Paths

## Output Contract + Pipeline

1. Record
   - Capture mic + system audio
   - Mix and convert to contract WAV format
2. Transcribe
   - Run Fluidaudio on WAV
   - Write transcript markdown to Meetings/_transcripts/
3. Summarize
   - Run llama with JSON-only prompt
   - Validate JSON; repair once if invalid
4. Render
   - Convert validated JSON to deterministic Markdown
5. Write
   - Atomically write note + audio into the vault

## Notes

- Critical paths are used to define higher coverage expectations.
