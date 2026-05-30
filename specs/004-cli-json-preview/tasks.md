# Tasks: CLI JSON Preview

**Input**: `/specs/004-cli-json-preview/plan.md`

## Phase 3.1: Setup

- [x] T001 Confirm scope and concrete target paths from `plan.md`
- [x] T002 Create or update tests before implementation

## Phase 3.2: Implementation

- [x] T003 Add `--json` and `-j` output mode support in `Sources/GaiaCLI/main.swift`
- [x] T004 Add `--preview` and `-p` dry-run filtering in `Sources/GaiaCLI/main.swift`
- [x] T005 Add ordered artifact selection and preview validation in `Sources/GaiaFeatureCatalog/FeatureCatalog.swift`
- [x] T006 Preserve the existing human-readable output paths when JSON mode is not requested

## Phase 3.3: Polish

- [x] T007 Extend validation coverage in `Tests/GaiaFeatureCatalogTests/FeatureCatalogTests.swift`
- [x] T008 Update command examples in `README.md`
- [x] T009 Run `swift build`, `swift format lint`, `swift run GaiaCLI --json`, and a filtered JSON dry run
- [x] T010 Scaffold `specs/004-cli-json-preview/` via the live CLI command

## Validation Notes

- `swift build` passed.
- `swift format lint` passed for `Package.swift`, `Sources/`, and `Tests/`.
- `swift run GaiaCLI --json` returned the workspace and catalog snapshot.
- `swift run GaiaCLI new-feature cli-json-preview ... -n -p spec.md --json` returned a filtered dry-run payload.
- `swift run GaiaCLI new-feature cli-json-preview ... --json` created this feature directory.