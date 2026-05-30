# Implementation Plan: Swift Workspace Bootstrap

**Branch**: `001-swift-workspace-bootstrap` | **Date**: 2026-05-30 | **Spec**: [spec.md](spec.md)  
**Input**: Feature specification from `/specs/001-swift-workspace-bootstrap/spec.md`

## Summary

Normalize Gaia around a root-level SwiftPM workspace, archive the earlier web
prototype under `legacy/`, align Speckit templates with the Swift/VS Code
constitution, and add enough executable tooling to prove the new baseline.

## Technical Context

**Language/Version**: Swift 6.1+ manifest, Swift 6.3 local compiler  
**Primary Dependencies**: SwiftPM, Foundation, swift-format  
**Storage**: N/A  
**Testing**: Swift test targets prepared for Swift Testing-compatible environments  
**Target Platform**: macOS 10.15+ for the package manifest; VS Code as primary IDE  
**Project Type**: swift-package  
**Editor Workflow**: VS Code + `swiftlang.swift-vscode` + LLDB DAP  
**Performance Goals**: Fast bootstrap, negligible CLI overhead  
**Constraints**: Root-level build must ignore archived web prototype; local `swift test` may require full Xcode  
**Scale/Scope**: Single-package workspace baseline with one real feature module

## Constitution Check

- [x] Specs-first flow preserved for ongoing work
- [x] Tests designed before or alongside implementation targets
- [x] Structure uses `Package.swift`, `Sources/`, and `Tests/`
- [x] VS Code build, test, debug, format, and lint commands are identified
- [x] Swift API design, concurrency, and type-safety implications are documented
- [x] Security, observability, and failure handling are covered for the feature surface

## Project Structure

### Documentation (this feature)

```text
specs/001-swift-workspace-bootstrap/
├── spec.md
├── plan.md
└── tasks.md
```

### Source Code (repository root)

```text
Package.swift
Sources/
├── GaiaCore/
├── GaiaFeatureCatalog/
└── GaiaCLI/

Tests/
├── GaiaCoreTests/
└── GaiaFeatureCatalogTests/

legacy/
└── web-prototype/
```

**Structure Decision**: Use a Swift package as the only active root-level
implementation surface and archive the earlier Next.js scaffold under `legacy/`.

## Phase 0: Outline & Research

- Decision: Keep CI pinned to a full Xcode toolchain instead of trusting local
  macOS Command Line Tools for test execution.
- Rationale: Local CLT builds and lints successfully but does not reliably
  expose the Swift test runtime modules.
- Alternatives considered: Keep the legacy web root active; rejected because it
  creates structural ambiguity and editor noise.

## Phase 1: Design & Contracts

- Model the workspace baseline through `ProjectBlueprint`.
- Model feature planning conventions through `FeatureDescriptor` and
  `FeatureCatalog`.
- Archive the historical web scaffold into `legacy/web-prototype/` and exclude
  it from active validation.
- Provide executable validation through Swift build, lint, and CLI smoke tests.

## Phase 2: Task Planning Approach

- Create tasks for constitution/template alignment, Swift package setup, legacy
  archival, and validation.
- Keep tasks ordered so structure and archived-path cleanup happen before
  feature module additions and final validation.

## Complexity Tracking

No constitutional deviations required.

## Progress Tracking

**Phase Status**:

- [x] Phase 0: Research complete
- [x] Phase 1: Design complete
- [x] Phase 2: Task planning complete
- [x] Phase 3: Tasks generated
- [x] Phase 4: Implementation complete
- [x] Phase 5: Validation passed for build, lint, and CLI smoke test

**Gate Status**:

- [x] Initial Constitution Check: PASS
- [x] Post-Design Constitution Check: PASS
- [x] All NEEDS CLARIFICATION resolved
- [x] Complexity deviations documented