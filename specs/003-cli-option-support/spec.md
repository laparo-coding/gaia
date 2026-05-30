# Feature Specification: CLI Option Support

**Feature Branch**: `003-cli-option-support`  
**Created**: 2026-05-30  
**Status**: Approved  
**Input**: User description: "Create richer feature scaffolds from CLI arguments."

## User Scenarios & Testing

### Primary User Story

As a Gaia maintainer, I want the feature scaffold CLI to accept explicit title,
summary, and description values and to preview the generated files during a dry
run, so I can create higher-quality Speckit artifacts without immediately
writing to disk.

### Acceptance Scenarios

1. **Given** a developer wants to start a feature with explicit metadata,
	**When** they run `swift run GaiaCLI new-feature <slug> --title <title> --summary <summary> --description <description>`,
	**Then** the created scaffold contains that metadata in the generated spec
	and plan files.
2. **Given** a developer wants to preview the scaffold first, **When** they add
	`--dry-run` or `-n`, **Then** the CLI prints the target directory and the
	full rendered contents of `spec.md`, `plan.md`, and `tasks.md` without
	creating files.
3. **Given** a developer prefers compact flags, **When** they use `-t`, `-s`,
	`-d`, and `-n`, **Then** the CLI behaves identically to the long options.

### Edge Cases

- What happens when short and long options are mixed in one command?
- What happens when an option is present but its value is missing?
- What happens when a user runs `--dry-run` for a slug whose next slot would be
	valid but should not yet write files?

## Requirements

### Functional Requirements

- **FR-001**: The `new-feature` CLI command MUST accept `--title` and `-t` as
	equivalent ways to set the scaffold title.
- **FR-002**: The `new-feature` CLI command MUST accept `--summary` and `-s` as
	equivalent ways to set the scaffold summary.
- **FR-003**: The `new-feature` CLI command MUST accept `--description` and `-d`
	as equivalent ways to set the source description embedded into `spec.md`.
- **FR-004**: The `new-feature` CLI command MUST accept `--dry-run` and `-n` as
	equivalent ways to preview the scaffold without creating files.
- **FR-005**: A dry run MUST print the rendered contents of `spec.md`,
	`plan.md`, and `tasks.md`, not only the target path and metadata summary.
- **FR-006**: The parser MUST return a clear error when an option is unknown or
	when a required option value is missing.
- **FR-007**: Existing positional title support MUST remain compatible for users
	who omit `--title`.

### Key Entities

- **NewFeatureCommand**: Represents parsed CLI input for the `new-feature`
	operation, including slug, title, summary, description, and dry-run mode.
- **FeatureScaffold**: Represents the fully rendered spec, plan, and tasks text
	before files are written to disk.
- **FeatureCatalogError**: Represents CLI-facing usage and scaffold failures.

## Review & Acceptance Checklist

### Content Quality

- [x] No implementation details that are irrelevant to user value
- [x] Focused on workflow quality and maintainability
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