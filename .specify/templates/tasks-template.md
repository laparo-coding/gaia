# Tasks: [FEATURE NAME]

**Input**: Design documents from `/specs/[###-feature-name]/` **Prerequisites**: plan.md (required),
research.md, data-model.md, contracts/

## Execution Flow (main)

```
1. Load plan.md from feature directory
   → If not found: ERROR "No implementation plan found"
   → Extract: tech stack, libraries, structure
2. Load optional design documents:
   → data-model.md: Extract entities → model tasks
   → contracts/: Each file → contract test task
   → research.md: Extract decisions → setup tasks
3. Generate tasks by category:
   → Setup: project init, dependencies, linting
   → Tests: contract tests, integration tests
   → Core: models, services, CLI commands
   → Integration: DB, middleware, logging
   → Polish: unit tests, performance, docs
4. Apply task rules:
   → Different files = mark [P] for parallel
   → Same file = sequential (no [P])
   → Tests before implementation (TDD)
5. Number tasks sequentially (T001, T002...)
6. Generate dependency graph
7. Create parallel execution examples
8. Validate task completeness:
   → All contracts have tests?
   → All entities have models?
   → All endpoints implemented?
9. Return: SUCCESS (tasks ready for execution)
```

## Format: `[ID] [P?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions

## Path Conventions

- **Swift package**: `Sources/<Target>/`, `Tests/<Target>Tests/`
- **Apple platform app**: `Apps/<AppName>/`, shared logic in `Sources/`
- **Hybrid workspace**: shared packages in `Sources/`, app shells in `Apps/`
- Paths shown below assume a Swift package layout - adjust based on plan.md structure

## Phase 3.1: Setup

- [ ] T001 Create or update `Package.swift` for the planned targets and dependencies
- [ ] T002 Create the feature folders in `Sources/` and `Tests/` per implementation plan
- [ ] T003 [P] Configure shared formatting, linting, VS Code tasks, and debug settings

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3

**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**

- [ ] T004 [P] Contract or protocol test in `Tests/<Feature>ContractTests/`
- [ ] T005 [P] Unit test for core feature logic in `Tests/<Feature>Tests/`
- [ ] T006 [P] Integration test for storage, transport, or platform boundary in `Tests/<Feature>IntegrationTests/`
- [ ] T007 [P] CLI or workflow test for the user-facing path when applicable

## Phase 3.3: Core Implementation (ONLY after tests are failing)

- [ ] T008 [P] Core types and models in `Sources/<Feature>/`
- [ ] T009 [P] Service or use-case implementation in `Sources/<Feature>/`
- [ ] T010 [P] CLI, app adapter, or integration entry point in `Sources/<Target>/`
- [ ] T011 Validation and decoding rules
- [ ] T012 Error handling and structured failure mapping
- [ ] T013 Concurrency safety updates (`async/await`, actors, `Sendable`) where needed
- [ ] T014 Logging or observability hooks for the changed feature

## Phase 3.4: Integration

- [ ] T015 Connect the feature to persistence, network, or system APIs
- [ ] T016 Add platform or package boundary wiring
- [ ] T017 Add request, task, or domain-level logging where required
- [ ] T018 Apply security and configuration guards

## Phase 3.5: Polish

- [ ] T019 [P] Add missing regression tests for validation and edge cases
- [ ] T020 Verify performance goals and concurrency expectations
- [ ] T021 [P] Update `README.md`, `Documentation.docc/`, or feature docs
- [ ] T022 Remove duplication and tighten naming/API clarity
- [ ] T023 Run `swift build`, `swift test`, and `swift format lint` before review

## Dependencies

- Tests (T004-T007) before implementation (T008-T014)
- T008 blocks T009, T015
- T016 blocks T018
- Implementation before polish (T019-T023)

## Parallel Example

```
# Launch T004-T007 together:
Task: "Contract test in Tests/<Feature>ContractTests/"
Task: "Unit test in Tests/<Feature>Tests/"
Task: "Integration test in Tests/<Feature>IntegrationTests/"
Task: "Workflow test for CLI or app path"
```

## Notes

- [P] tasks = different files, no dependencies
- Verify tests fail before implementing
- Commit after each task
- Avoid: vague tasks, same file conflicts

## Task Generation Rules

_Applied during main() execution_

1. **From Contracts**:
   - Each contract file → contract test task [P]
   - Each endpoint → implementation task
2. **From Data Model**:
   - Each entity → model creation task [P]
   - Relationships → service layer tasks
3. **From User Stories**:
   - Each story → integration test [P]
   - Quickstart scenarios → validation tasks

4. **Ordering**:
   - Setup → Tests → Models → Services/Use Cases → Integration → Polish
   - Dependencies block parallel execution

## Validation Checklist

_GATE: Checked by main() before returning_

- [ ] All contracts have corresponding tests
- [ ] All entities have model tasks
- [ ] All tests come before implementation
- [ ] Parallel tasks truly independent
- [ ] Each task specifies exact file path
- [ ] No task modifies same file as another [P] task
