# Feature Specification: Feature Catalog Discovery

**Feature Branch**: `002-feature-catalog-discovery`  
**Created**: 2026-05-30  
**Status**: Approved  
**Input**: User description: "Discover existing spec folders from disk and scaffold the next feature from the CLI."

## User Scenarios & Testing

### Primary User Story

As a Gaia maintainer, I want the CLI to discover existing feature specs from the
filesystem and scaffold the next feature slot automatically, so new work starts
from the actual repository state instead of hardcoded bootstrap data.

### Acceptance Scenarios

1. **Given** existing numbered feature folders under `specs/`, **When** a
	developer runs `swift run GaiaCLI`, **Then** the CLI reports the discovered
	features and the next free spec slot based on the filesystem.
2. **Given** a developer wants to start a new feature, **When** they run
	`swift run GaiaCLI new-feature <slug> [title]`, **Then** the CLI creates a
	new numbered feature folder containing `spec.md`, `plan.md`, and `tasks.md`.
3. **Given** a feature scaffold is created, **When** a maintainer opens the new
	files, **Then** they find enough structure to continue the Speckit workflow
	without inventing file names or branch conventions.

### Edge Cases

- What happens when `specs/` contains folders that do not follow the numbered
	`NNN-slug` convention?
- What happens when the requested new slug contains spaces, punctuation, or
	uppercase letters?
- What happens when the next scaffold path already exists?

## Requirements

### Functional Requirements

- **FR-001**: The CLI MUST discover existing feature folders by scanning the
	repository `specs/` directory at runtime.
- **FR-002**: Discovered features MUST be sorted by numeric prefix and surfaced
	in the catalog summary.
- **FR-003**: The CLI MUST determine the next free feature slot from the highest
	discovered numeric prefix rather than from hardcoded seed data.
- **FR-004**: The CLI MUST normalize new feature slugs to lowercase
	hyphen-separated values safe for branch and folder naming.
- **FR-005**: The CLI MUST scaffold `spec.md`, `plan.md`, and `tasks.md` for a
	new feature directory using the next free numeric slot.
- **FR-006**: The CLI MUST fail with a clear error when `specs/` is missing,
	when no slug is provided, or when the target scaffold path already exists.
- **FR-007**: Scaffolded files MUST be Speckit-compatible and ready for a human
	to complete, rather than empty placeholders with no structure.

### Key Entities

- **FeatureDescriptor**: Represents one discovered or scaffolded feature with a
	numeric index, slug, title, and derived branch/spec directory names.
- **FeatureCatalog**: Aggregates discovered features, reports the next free slot,
	and owns the scaffold operation for the next feature.
- **FeatureCatalogError**: Represents CLI-facing discovery and scaffold failures.

## Review & Acceptance Checklist

### Content Quality

- [x] No implementation details that are irrelevant to user value
- [x] Focused on workflow clarity and repo maintainability
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