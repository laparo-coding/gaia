# Tasks: Swift Workspace Bootstrap

**Input**: Design documents from `/specs/001-swift-workspace-bootstrap/`  
**Prerequisites**: plan.md, spec.md

## Phase 3.1: Setup

- [x] T001 Create the root-level SwiftPM workspace in `Package.swift`
- [x] T002 Add shared formatting and linting configuration in `.swift-format`
- [x] T003 Add shared VS Code tasks and launch configuration under `.vscode/`

## Phase 3.2: Tests First (TDD)

- [x] T004 Add initial package tests in `Tests/GaiaCoreTests/`
- [x] T005 Add feature-catalog tests in `Tests/GaiaFeatureCatalogTests/`

## Phase 3.3: Core Implementation

- [x] T006 Implement workspace bootstrap primitives in `Sources/GaiaCore/`
- [x] T007 Implement the feature-catalog module in `Sources/GaiaFeatureCatalog/`
- [x] T008 Wire the executable entry point in `Sources/GaiaCLI/main.swift`

## Phase 3.4: Integration

- [x] T009 Align Speckit constitution and templates for the Swift workflow
- [x] T010 Pin CI to a concrete Xcode toolchain in `.github/workflows/swift-quality.yml`
- [x] T011 Archive the earlier web scaffold under `legacy/web-prototype/`
- [x] T012 Silence archived legacy type-check noise in `legacy/web-prototype/tsconfig.json`

## Phase 3.5: Polish

- [x] T013 Update `README.md` and `AGENTS.md` to reflect the active Swift baseline
- [x] T014 Add documentation stub under `Documentation.docc/`
- [x] T015 Validate `swift build`, `swift format lint`, and `swift run GaiaCLI`

## Validation Notes

- Local `swift test` remains blocked until a full Xcode installation is present.
- Active local validation is currently build + lint + CLI smoke test.