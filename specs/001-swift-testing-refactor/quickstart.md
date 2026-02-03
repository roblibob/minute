# Quickstart: Swift Testing Refactor and Coverage

## Prerequisites

- macOS 14+
- Xcode 15.x
- Project dependencies installed as usual for local builds

## Run the full test suite

```bash
xcodebuild -workspace Minute.xcworkspace -scheme Minute -configuration Debug test
```

## Run core tests

```bash
xcodebuild -workspace Minute.xcworkspace -scheme MinuteCore -configuration Debug test -destination 'platform=macOS'
```

## Review coverage

- After tests complete, generate a human-readable coverage summary:

```bash
scripts/coverage/generate-coverage-summary.sh --xcresult <path-to.xcresult>
```

- To emit a machine-readable report:

```bash
scripts/coverage/generate-coverage-summary.sh --xcresult <path-to.xcresult> --machine
```
