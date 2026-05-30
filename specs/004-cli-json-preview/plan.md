# Implementation Plan: CLI JSON Preview

**Branch**: `004-cli-json-preview` | **Date**: 2026-05-30 | **Spec**: [spec.md](spec.md)

## Summary

Add machine-readable output and focused dry-run previews.

## Technical Context

**Language/Version**: Swift 6.x  
**Primary Dependencies**: Foundation, SwiftPM  
**Storage**: Filesystem-backed scaffold generation under `specs/`  
**Testing**: Swift test targets prepared with `Testing`-based sources  
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
├── GaiaCLI/main.swift
└── GaiaFeatureCatalog/FeatureCatalog.swift

Tests/
└── GaiaFeatureCatalogTests/FeatureCatalogTests.swift

specs/
├── 001-swift-workspace-bootstrap/
├── 002-feature-catalog-discovery/
├── 003-cli-option-support/
└── 004-cli-json-preview/
```

## Phase 0: Outline & Research

- Decision: Add JSON output as a global formatting mode instead of introducing a
	separate command.
- Rationale: The same commands should remain usable interactively and in shell
	automation, with only the output format changing.
- Alternatives considered: Add a dedicated `status-json` command; rejected
	because it would duplicate existing command routing and increase maintenance.

## Phase 1: Design & Contracts

- Strip `--json` and `-j` from the raw argument list before command dispatch so
	the existing command routing can stay narrow.
- Serialize summary and scaffold results through dedicated encodable payloads.
- Extend `FeatureScaffold` with ordered artifact selection so preview filtering
	stays close to the rendered scaffold data.

## Phase 2: Task Planning Approach

- Update the CLI parser and output branches first.
- Add artifact selection helpers and focused tests for valid and invalid preview requests.
- Validate with build, lint, human-readable CLI calls, and JSON CLI calls.

## Complexity Tracking

No constitutional deviations required.

## Progress Tracking

**Phase Status**:

- [x] Phase 0: Research complete
- [x] Phase 1: Design complete
- [x] Phase 2: Task planning complete
- [x] Phase 3: Tasks generated
- [x] Phase 4: Implementation complete
- [x] Phase 5: Validation passed for build, lint, JSON output, and filtered dry-run preview

**Gate Status**:

- [x] Initial Constitution Check: PASS
- [x] Post-Design Constitution Check: PASS
- [x] All NEEDS CLARIFICATION resolved
- [x] Complexity deviations documented