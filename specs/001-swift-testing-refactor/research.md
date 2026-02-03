# Research: Swift Testing Refactor and Coverage

## Decision: Use Swift Testing as the single test framework
**Rationale**: The constitution mandates Swift Testing and TDD for all features.
Migrating the suite avoids split tooling and keeps behavior consistent.
**Alternatives considered**: Keep a hybrid XCTest + Swift Testing suite (rejected
because it increases maintenance and slows adoption of the preferred workflow).

## Decision: Coverage targets include overall and critical-path minimums
**Rationale**: The spec requires both visibility and stronger guarantees for
output-contract behavior. Separate targets enable balanced enforcement.
**Alternatives considered**: Overall-only or critical-only targets (rejected
because they either mask critical risk or overfit to a narrow set of paths).

## Decision: Coverage summary defaults to human-readable output with optional
machine-readable report
**Rationale**: Maintainers need quick human visibility while still enabling
automation when desired.
**Alternatives considered**: Human-only or machine-only output (rejected because
one of the two audiences is underserved).
