# Requirements Quality Checklist: Controller Design

Purpose: Validate the quality of requirements across spec, plan, and tasks before implementation.
Created: 2026-05-31
Scope: spec.md + plan.md + tasks.md
Depth: Standard
Audience: Author self-check before PR

## Requirement Completeness

- [ ] CHK001 Are requirements documented for controller lifecycle boundaries (initial load, steady state, and failure state)? [Completeness, Spec §FR-011, Spec §FR-012]
- [ ] CHK002 Are data-source responsibilities fully specified for Gaia bridge vs Aither upstream (including placeholder-notes behavior)? [Completeness, Spec §FR-008, Spec §FR-011, Plan §Summary]
- [ ] CHK003 Are explicit requirements present for external dependency readiness and validation before scenario sign-off? [Completeness, Tasks §Phase 3.5 T029A]

## Requirement Clarity

- [ ] CHK004 Are all timing-related requirements quantified with objective thresholds (for loading and navigation)? [Clarity, Spec §FR-012, Spec §NFR-004, Plan §Performance Goals]
- [ ] CHK005 Is the placeholder-notes rule unambiguous enough to distinguish placeholder vs upstream content? [Clarity, Spec §FR-008, Spec §AC-005]
- [ ] CHK006 Is the allowed interaction surface precisely stated so non-button inputs are clearly excluded? [Clarity, Spec §FR-014, Spec §Non-Goals]

## Requirement Consistency

- [ ] CHK007 Do interaction constraints stay consistent across Non-Goals, FRs, ACs, and task scenarios for navigation inputs? [Consistency, Spec §Non-Goals, Spec §FR-014, Spec §AC-006, Tasks §T013]
- [ ] CHK008 Do loading/error expectations stay consistent between Clarifications, FR-012, NFR-005, and overlay tasks? [Consistency, Spec §Clarifications, Spec §FR-012, Spec §NFR-005, Tasks §T012, Tasks §T027]
- [ ] CHK009 Are task volume expectations consistent with planning estimates and phase scope? [Consistency, Plan §Estimated Output, Tasks §All Phases]

## Acceptance Criteria Quality

- [ ] CHK010 Can each acceptance criterion be verified objectively without relying on subjective terms? [Acceptance Criteria, Spec §AC-001..AC-006]
- [ ] CHK011 Are acceptance criteria traceable to one or more FR/NFR statements without orphan criteria? [Acceptance Criteria, Spec §Requirements, Spec §Acceptance Criteria]
- [ ] CHK012 Are acceptance criteria complete for placeholder behavior, not only normal data-available behavior? [Acceptance Criteria, Spec §AC-005, Spec §FR-008]

## Scenario Coverage

- [ ] CHK013 Are primary scenarios covered by requirements and mirrored by dedicated tasks (initial load, next/previous sync, notes usage)? [Coverage, Spec §User Stories, Tasks §T009, Tasks §T010, Tasks §T011]
- [ ] CHK014 Are alternate scenarios defined for upstream notes unavailable while placeholder mode is active? [Coverage, Spec §FR-008, Spec §FR-011, Tasks §T014]
- [ ] CHK015 Are exception scenarios defined for bridge/upstream failures and mapped to user-visible outcomes? [Coverage, Spec §FR-012, Tasks §T012, Tasks §T019, Tasks §T027]

## Edge Case Coverage

- [ ] CHK016 Are boundary conditions specified for slide-width cap and ratio preservation under different content shapes? [Edge Case, Spec §FR-004, Spec §FR-005, Spec §NFR-004]
- [ ] CHK017 Are requirements explicit for long-text overflow behavior and independent panel scrolling limits? [Edge Case, Spec §FR-013, Tasks §T011, Tasks §T025]
- [ ] CHK018 Are requirements explicit for unavailable or delayed supplemental text while slide HTML is available? [Edge Case, Spec §FR-011, Spec §FR-012, Gap]

## Non-Functional Requirements

- [ ] CHK019 Are performance targets defined consistently across spec and plan, including measurement context? [Non-Functional, Spec §NFR-004, Plan §Performance Goals]
- [ ] CHK020 Are observability and error attribution requirements specified clearly enough to validate telemetry behavior? [Non-Functional, Plan §Constitution Check, Tasks §T019, Gap]
- [ ] CHK021 Are usability constraints for iPad landscape explicitly testable and complete (visibility, stability, reachability)? [Non-Functional, Spec §NFR-001, Spec §NFR-002, Spec §NFR-003]

## Dependencies & Assumptions

- [ ] CHK022 Are external Aither endpoint dependencies documented as assumptions with explicit readiness checks? [Dependencies, Contracts §Gaia Bridge -> Aither, Tasks §T029A]
- [ ] CHK023 Is the assumption about one active presentation at a time explicitly reflected in requirements or intentionally scoped out? [Assumption, Plan §Scale/Scope, Gap]
- [ ] CHK024 Are toolchain/build assumptions for the iPad app target explicitly represented in requirements or acceptance coverage? [Dependencies, Plan §iPad App Buildability, Tasks §T003A, Tasks §T003B]

## Ambiguities & Conflicts

- [ ] CHK025 Is terminology consistent for equivalent concepts (notes vs supplemental text vs placeholder text) across all artifacts? [Ambiguity, Spec §FR-008, Spec §FR-011, Plan §Summary]
- [ ] CHK026 Are there any hidden conflicts between strict button-only navigation and future extensibility expectations? [Conflict, Spec §FR-014, Spec §Non-Goals, Gap]
- [ ] CHK027 Is requirement-to-task traceability explicit enough to avoid interpretation drift during implementation? [Traceability, Spec §FR/NFR, Tasks §All Phases]
