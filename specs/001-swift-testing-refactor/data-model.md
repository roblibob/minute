# Data Model: Swift Testing Refactor and Coverage

## Entities

### Test Suite
- **Description**: The full set of automated tests across all targets.
- **Key fields**: name, target, total_tests, migrated_tests, migration_status.
- **Relationships**: contains many Test Cases; produces Coverage Summaries.

### Test Case
- **Description**: An individual automated test.
- **Key fields**: id, name, target, intent, migrated (bool), exception_reason
  (optional), follow_up_issue (optional).
- **Relationships**: belongs to Test Suite.

### Coverage Summary
- **Description**: Human-readable coverage report with optional machine output.
- **Key fields**: overall_coverage_percent, critical_path_coverage_percent,
  generated_at, human_report_path, machine_report_path (optional).
- **Relationships**: produced by a Test Run; references Coverage Targets.

### Coverage Target
- **Description**: Expected coverage thresholds for validation.
- **Key fields**: overall_min_percent, critical_min_percent.
- **Relationships**: applies to Coverage Summary.

### Test Run
- **Description**: A single execution of the test suite.
- **Key fields**: started_at, completed_at, status (pending|running|passed|failed),
  failure_summary (optional).
- **Relationships**: produces Coverage Summary.

## Validation Rules

- All tests MUST be either migrated or documented as exceptions with rationale
  and a follow-up issue.
- Coverage Summary MUST include overall and critical-path coverage values.
- Coverage targets MUST be applied consistently across all targets.

## State Transitions

- **Test Run**: pending → running → passed | failed
- **Test Case migration**: not_migrated → migrated | exception
