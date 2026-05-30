# Implementation Plan: Feature Catalog Discovery

**Branch**: `002-feature-catalog-discovery` | **Date**: 2026-05-30 | **Spec**: [spec.md](spec.md)

## Summary

Replace hardcoded bootstrap feature data with filesystem-backed discovery of
`specs/NNN-slug/` folders and expose a `new-feature` CLI command that creates a
Speckit-compatible scaffold for the next available feature slot.

## Technical Context

**Language/Version**: Swift 6.x  
**Primary Dependencies**: Foundation, SwiftPM  
**Storage**: Filesystem under the repository root  
**Testing**: Swift test targets prepared with `Testing`-based test sources  
**Target Platform**: macOS development machine, CI on pinned Xcode toolchain  
**Project Type**: swift-package  
**Editor Workflow**: VS Code + swiftlang.swift-vscode

## Constitution Check

- [x] Specs-first flow preserved
- [x] Tests planned before implementation
- [x] Structure uses active Swift package layout
- [x] Security, observability, and failure handling are covered

## Project Structure

```text
Sources/
├── GaiaFeatureCatalog/FeatureCatalog.swift
└── GaiaCLI/main.swift

Tests/
└── GaiaFeatureCatalogTests/FeatureCatalogTests.swift

specs/
├── 001-swift-workspace-bootstrap/
└── 002-feature-catalog-discovery/
```

## Phase 0: Outline & Research

- Decision: Scan `specs/` directly instead of storing feature metadata in code.
- Rationale: The repository filesystem is the source of truth for Speckit
	feature folders.
- Alternatives considered: Keep bootstrap features hardcoded; rejected because
	the catalog would drift from the actual repo state.

## Phase 1: Design & Contracts

- Add discovery logic that parses numbered directories and reads titles from
	`spec.md` when available.
- Add scaffold logic that normalizes slugs and writes initial `spec.md`,
	`plan.md`, and `tasks.md` files.
- Add CLI argument handling for `new-feature` while preserving the summary mode.

## Phase 2: Task Planning Approach

- Update catalog and CLI logic first.
- Add or update tests for discovery and scaffold behavior.
- Validate with build, lint, and live scaffold execution.

## Complexity Tracking

No constitutional deviations required.

## Progress Tracking

**Phase Status**:

- [x] Phase 0: Research complete
- [x] Phase 1: Design complete
- [x] Phase 2: Task planning complete
- [x] Phase 3: Tasks generated
- [x] Phase 4: Implementation complete
- [x] Phase 5: Validation passed for build, lint, and live CLI scaffold execution

**Gate Status**:

- [x] Initial Constitution Check: PASS
- [x] Post-Design Constitution Check: PASS
- [x] All NEEDS CLARIFICATION resolved
- [x] Complexity deviations documented