# Feature Specification: Swift Workspace Bootstrap

**Feature Branch**: `001-swift-workspace-bootstrap`  
**Created**: 2026-05-30  
**Status**: Approved  
**Input**: User description: "Establish a GitHub Speckit-compatible constitution and continue Gaia as a VS Code Swift project baseline."

## User Scenarios & Testing

### Primary User Story

As a developer working in VS Code, I want Gaia to behave like a clear SwiftPM
workspace with Speckit artifacts, so I can plan features, build locally, and
run consistent quality gates without inheriting ambiguity from the archived web
prototype.

### Acceptance Scenarios

1. **Given** a fresh checkout of Gaia, **When** a developer opens the workspace,
   **Then** the active root-level project structure is clearly Swift-focused and
   the legacy web scaffold is visibly archived.
2. **Given** a developer starts a new feature, **When** they inspect `specs/`
   and the repository templates, **Then** they find Speckit-compatible Swift/
   VS Code guidance for `spec.md`, `plan.md`, and `tasks.md`.
3. **Given** the Swift baseline is in place, **When** local validation runs,
   **Then** `swift build`, `swift format lint`, and a CLI smoke test succeed.

### Edge Cases

- What happens when local macOS machines have only Command Line Tools and no
  full Xcode installation?
- How does the repo avoid editor noise from the archived legacy web files?

## Requirements

### Functional Requirements

- **FR-001**: The repository MUST expose a root-level Swift Package Manager
  project as the canonical Gaia implementation surface.
- **FR-002**: The repository MUST keep the archived web prototype outside the
  active root-level build and CI path while preserving it for reference.
- **FR-003**: The repository MUST provide Speckit-compatible constitution and
  template guidance aligned with a VS Code-first Swift workflow.
- **FR-004**: The repository MUST provide shared VS Code tasks and CI quality
  gates for Swift build, lint, and test workflows.
- **FR-005**: The repository MUST include at least one real Swift feature module
  that demonstrates how features are organized and surfaced.
- **FR-006**: The repository MUST document the local toolchain limitation when
  `swift test` cannot run without a full Xcode installation.

### Key Entities

- **ProjectBlueprint**: Describes the canonical Gaia workspace directories and
  gives human-readable bootstrap output.
- **FeatureDescriptor**: Represents a Speckit-tracked feature with branch and
  spec directory conventions.
- **FeatureCatalog**: Holds known feature entries and determines the next
  available spec slot.

## Review & Acceptance Checklist

### Content Quality

- [x] No implementation details that are irrelevant to user value
- [x] Focused on developer workflow value and repository clarity
- [x] Written for repo stakeholders and maintainers
- [x] All mandatory sections completed

### Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified
- [x] Security, observability, and failure-state expectations are captured when relevant

## Execution Status

- [x] User description parsed
- [x] Key concepts extracted
- [x] Ambiguities marked
- [x] User scenarios defined
- [x] Requirements generated
- [x] Entities identified
- [x] Review checklist passed