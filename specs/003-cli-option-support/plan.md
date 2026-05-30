# Implementation Plan: CLI Option Support

**Branch**: `003-cli-option-support` | **Date**: 2026-05-30 | **Spec**: [spec.md](spec.md)

## Summary

Add summary, description, and dry-run support.

## Technical Context

**Language/Version**: Swift 6.x  
**Primary Dependencies**: Foundation, SwiftPM  
**Storage**: Filesystem scaffold generation under `specs/`  
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
└── 003-cli-option-support/
```

## Phase 0: Outline & Research

- Decision: Keep positional title support while adding explicit long and short
	options.
- Rationale: This preserves the older scaffold command shape while making the
	new metadata controls clearer and more scriptable.
- Alternatives considered: Break positional title support and force named
	options; rejected because it would unnecessarily regress the existing CLI UX.

## Phase 1: Design & Contracts

- Extend the `new-feature` parser to understand `-t`, `-s`, `-d`, and `-n`.
- Reuse `FeatureScaffold` to preview exact file contents during dry runs.
- Keep the existing scaffold write path untouched for the non-dry-run case.

## Phase 2: Task Planning Approach

- Update parser behavior first.
- Reuse and extend scaffold rendering for full preview output.
- Validate with a real dry run and a real scaffold execution for feature 003.

## Complexity Tracking

No constitutional deviations required.

## Progress Tracking

**Phase Status**:

- [x] Phase 0: Research complete
- [x] Phase 1: Design complete
- [x] Phase 2: Task planning complete
- [x] Phase 3: Tasks generated
- [x] Phase 4: Implementation complete
- [x] Phase 5: Validation passed for build, lint, dry-run preview, and real scaffold execution

**Gate Status**:

- [x] Initial Constitution Check: PASS
- [x] Post-Design Constitution Check: PASS
- [x] All NEEDS CLARIFICATION resolved
- [x] Complexity deviations documented