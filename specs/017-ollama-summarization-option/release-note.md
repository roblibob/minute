# Release Note: Advanced Inference Provider Options

More flexible local AI configuration, with independent model controls for summaries and screen context.

Minute now gives advanced users separate local inference controls for summarization and screen-context vision. You can choose `Built-in` or `Ollama` for each capability independently, both during setup and later in Settings.

## What's New

- Separate provider and model selection for summarization and vision.
- `Built-in` and `Ollama` are available in both onboarding and Settings.
- Existing installs keep safe built-in defaults after upgrade.
- Active summarization and vision tasks keep the provider/model they started with, even if settings change mid-run.
- Ollama model discovery uses the local daemon's installed models.
- Vision selections are validated so non-vision Ollama models are rejected with a clear message.

## Why It Matters

This update gives advanced users tighter control over their local runtime setup without changing Minute's core behavior. You can keep the built-in path, switch only summarization to Ollama, use a different Ollama model for vision, or mix providers based on your hardware and preferences.

## Privacy and Compatibility

- Processing remains local-first.
- No cloud account is required.
- The deterministic vault contract is unchanged: each processed meeting still writes exactly three files.
- Transcription behavior is unchanged.

## Notes for Existing Users

If you are upgrading from an earlier version, Minute will keep working with built-in defaults for both summarization and vision until you choose otherwise. If an Ollama model is unavailable or does not support vision, Minute keeps the rest of your configuration intact and shows actionable readiness feedback.
