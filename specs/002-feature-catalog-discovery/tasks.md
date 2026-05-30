# Tasks: Feature Catalog Discovery

**Input**: `/specs/002-feature-catalog-discovery/plan.md`

## Phase 3.1: Setup

- [x] T001 Confirm scope and concrete target paths from `plan.md`
- [x] T002 Create or update tests before implementation

## Phase 3.2: Implementation

- [x] T003 Implement filesystem-backed discovery in `Sources/GaiaFeatureCatalog/FeatureCatalog.swift`
- [x] T004 Implement `new-feature` CLI scaffolding in `Sources/GaiaCLI/main.swift`
- [x] T005 Add slug normalization and user-facing scaffold errors

## Phase 3.3: Polish

- [x] T006 Update docs with the new CLI command in `README.md`
- [x] T007 Run `swift build`, `swift format lint`, and `swift run GaiaCLI`
- [x] T008 Scaffold `specs/002-feature-catalog-discovery/` via the live CLI command

## Validation Notes

- `swift build` passed.
- `swift format lint` passed for `Package.swift`, `Sources/`, and `Tests/`.
- `swift run GaiaCLI` correctly reports discovered features and the next free slot.
- `swift run GaiaCLI new-feature feature-catalog-discovery "Feature Catalog Discovery"` created this feature directory.