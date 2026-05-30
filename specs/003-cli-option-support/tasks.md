# Tasks: CLI Option Support

**Input**: `/specs/003-cli-option-support/plan.md`

## Phase 3.1: Setup

- [x] T001 Confirm scope and concrete target paths from `plan.md`
- [x] T002 Create or update tests before implementation

## Phase 3.2: Implementation

- [x] T003 Add `-t`, `-s`, `-d`, and `-n` support in `Sources/GaiaCLI/main.swift`
- [x] T004 Extend dry-run output to print rendered `spec.md`, `plan.md`, and `tasks.md`
- [x] T005 Preserve compatibility with positional title input
- [x] T006 Update validation coverage in `Tests/GaiaFeatureCatalogTests/FeatureCatalogTests.swift`

## Phase 3.3: Polish

- [x] T007 Update command examples in `README.md`
- [x] T008 Run `swift build`, `swift format lint`, and a live dry-run command
- [x] T009 Scaffold `specs/003-cli-option-support/` via the live CLI command

## Validation Notes

- `swift build` passed.
- `swift format lint` passed for `Package.swift`, `Sources/`, and `Tests/`.
- Dry run with `-t`, `-s`, `-d`, and `-n` printed full file previews.
- Real scaffold execution created this feature directory under `specs/003-cli-option-support/`.