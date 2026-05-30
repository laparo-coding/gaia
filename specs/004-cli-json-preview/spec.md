# Feature Specification: CLI JSON Preview

**Feature Branch**: `004-cli-json-preview`  
**Created**: 2026-05-30  
**Status**: Approved  
**Input**: User description: "Emit JSON status output and allow previewing individual scaffold files."

## User Scenarios & Testing

### Primary User Story

As a Gaia maintainer, I want the CLI to emit machine-readable JSON and to limit
dry-run output to selected scaffold files, so I can automate repository checks
and inspect only the artifact I currently need.

### Acceptance Scenarios

1. **Given** a developer wants to consume workspace status in scripts,
   **When** they run `swift run GaiaCLI --json`, **Then** the CLI returns a
   JSON document containing the workspace summary, discovered feature entries,
   and the next free spec slot.
2. **Given** a developer wants a machine-readable preview of a new feature,
   **When** they run `swift run GaiaCLI new-feature <slug> ... --dry-run --json`,
   **Then** the CLI returns a JSON object with the resolved descriptor and the
   rendered artifact contents.
3. **Given** a developer only wants to inspect one scaffold file,
   **When** they add `--preview spec.md` or `-p spec.md` during a dry run,
   **Then** the CLI outputs only that artifact instead of the full scaffold set.

### Edge Cases

- What happens when `--preview` is used without `--dry-run`?
- What happens when an unsupported preview artifact such as `notes.md` is requested?
- What happens when the user requests multiple preview files in a specific order?

## Requirements

### Functional Requirements

- **FR-001**: The CLI MUST accept `--json` and `-j` as equivalent ways to emit
	machine-readable JSON output.
- **FR-002**: `swift run GaiaCLI --json` MUST serialize the workspace summary,
	discovered feature descriptors, and the next free spec slot.
- **FR-003**: `swift run GaiaCLI new-feature <slug> ... --dry-run --json` MUST
	serialize the resolved feature descriptor and the previewed scaffold files.
- **FR-004**: The `new-feature` command MUST accept `--preview` and `-p` to
	select one or more scaffold files during dry runs.
- **FR-005**: Preview filtering MUST reject unsupported artifact names with a
	clear user-facing error.
- **FR-006**: Preview filtering MUST require `--dry-run` so real scaffold
	creation remains unchanged and unambiguous.
- **FR-007**: The CLI MUST preserve existing human-readable output when `--json`
	is not requested.

### Key Entities

- **WorkspaceSnapshot**: Represents the JSON payload for workspace status,
	including blueprint metadata and the discovered feature catalog.
- **NewFeatureResult**: Represents the JSON payload for scaffold creation or
	dry-run preview results.
- **FeatureScaffold selected artifacts**: Represents the ordered subset of
	scaffold files requested for preview output.

## Review & Acceptance Checklist

### Content Quality

- [x] No implementation details that are irrelevant to user value
- [x] Focused on workflow clarity and automation support
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