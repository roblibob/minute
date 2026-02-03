# Contributing

Thanks for helping improve Minute. This project focuses on a local-first, deterministic pipeline for meeting capture and note generation. Please keep those constraints in mind as you contribute.

## Getting started
1. Fork and clone the repo.
2. Open `Minute.xcworkspace` in Xcode.
3. Build the app target or run from Xcode.

## Build and test
Build:
```
xcodebuild -project Minute.xcodeproj -scheme Minute -configuration Debug build
```

Test (Minute app target):
```
xcodebuild -workspace Minute.xcworkspace -scheme Minute -configuration Debug test -destination 'platform=macOS'
```

Test (MinuteCore):
```
xcodebuild -workspace Minute.xcworkspace -scheme MinuteCore -configuration Debug test -destination 'platform=macOS'
```

Make targets:
```
make test
```

## Guidelines
- Keep the output contract stable. Any change to note format, paths, or frontmatter must update tests and `docs/overview.md`.
- No outbound network calls except model downloads.
- Prefer Swift concurrency (`async`/`await`) and keep long-running operations cancellable.
- UI stays thin; business logic lives in `MinuteCore`.
- Add tests for new features, especially around file contracts and Markdown rendering.

## Pull requests
- Describe the problem, approach, and any tradeoffs.
- Include tests and docs updates when behavior changes.
- Keep changes focused and incremental.
