## Implementation Plan: Controller Design

**Branch**: `007-controller-design` | **Date**: 2026-05-31 | **Spec**: [spec.md](spec.md) | **Input**: Feature specification from `/specs/007-controller-design/spec.md`

## Summary

Build Gaia's first iPad controller stack for course-day slide playback: a landscape-only controller UI with a 16:9 HTML slide viewport capped at 75% width, a right-hand supplemental text panel that may initially render placeholder notes, button-only navigation, and a Gaia-managed bridge that keeps Aither credentials off the iPad client while mirroring the active presentation state.

## Technical Context

**Language/Version**: Swift 6.1 package manifest with Swift 6.x code targets, plus an iPadOS SwiftUI host surface and WebKit-backed HTML rendering  
**Primary Dependencies**: Foundation, GaiaCore, existing Gaia Aither service-auth infrastructure, SwiftUI, WebKit, URLSession  
**Storage**: In-memory presentation manifest cache, ephemeral active-slide/navigation state, and no new database or persistent on-device store  
**Testing**: Swift Testing-style unit and integration coverage for controller models, bridge services, and contract validation, plus Xcode-backed iPad UI scenario verification for the controller shell  
**Target Platform**: iPad in landscape mode with a Gaia server-side bridge between the controller client and Aither slide APIs  
**Project Type**: hybrid  
**Editor Workflow**: VS Code + `swiftlang.swift-vscode` + LLDB for shared SwiftPM code, with documented Xcode-backed simulator/device commands for the iPad shell  
**iPad App Buildability**: The iPad controller host MUST be buildable as a concrete Apple-platform app target and validated for iPad landscape configuration before implementation is considered complete  
**Performance Goals**: First controller payload and initial slide visible within 2 seconds on a local network; next/previous navigation reflected without layout shift and targeted at sub-150 ms when adjacent slides are prefetched  
**Constraints**: iPad landscape only, slide viewport never exceeds 75% width, 16:9 slide ratio must match Aither's 4K player, navigation is button-only, Aither credentials stay server-side, no stale-slide fallback after load failure  
**Scale/Scope**: One coach, one active presentation at a time, and a presentation deck on the order of tens of slides with one supplemental-text panel for the active slide, including placeholder content until final notes are defined

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

- [x] Specs-first flow preserved: `spec.md` → `plan.md` → `tasks.md` before implementation
- [x] Tests are designed to fail before implementation begins
- [x] Structure keeps reusable logic in `Package.swift`, `Sources/`, and `Tests/` with documented Apple-platform app/bridge surfaces
- [x] VS Code build, test, lint, and debug expectations are identified, with explicit note where Xcode-backed validation is additionally required
- [x] Swift API design, concurrency, and type-safety implications are captured for controller state, networking, and UI coordination
- [x] Security, observability, and failure handling are covered for Aither integration and controller loading states

## Project Structure

### Documentation (this feature)

```text
specs/007-controller-design/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── controller-api.md
└── tasks.md
```

### Source Code (planned)

```text
Package.swift
Sources/
├── GaiaCLI/
├── GaiaCore/
│   └── Controller/
└── GaiaFeatureCatalog/

Tests/
├── GaiaCoreTests/
│   └── Controller/
├── GaiaFeatureCatalogTests/
├── contracts/
└── integration/

app/
├── authentication/
├── controller/
└── controller-bridge/
```

**Structure Decision**: Hybrid workspace. Shared controller state, Aither integration, navigation orchestration, and bridge logic live in SwiftPM-managed code under `Sources/` and `Tests/`. The actual iPad controller shell lives under `app/controller/`, while the server-side bridge that protects Aither credentials lives under `app/controller-bridge/`.

## Phase 0: Outline & Research

Research focuses on:

1. Choosing the secure split between the iPad controller client, Gaia bridge, and Aither integration.
2. Defining how Gaia receives slide HTML metadata from Aither and how Gaia fills the supplemental text panel with either upstream notes or a temporary placeholder.
3. Locking the viewport rendering strategy so the iPad preview matches Aither's 16:9 4K HTML player.
4. Choosing a preload and navigation strategy that satisfies the clarified button-only interaction model.
5. Capturing loading, error, and observability behavior before implementation begins.

## Phase 1: Design & Contracts

Phase 1 produces:

1. `data-model.md` for controller session, slide manifest, slide payload, supplemental text fallback, and navigation command entities.
2. `contracts/controller-api.md` describing the Gaia bridge surface and the required Aither-side upstream contract.
3. `quickstart.md` with executable validation scenarios for initial load, navigation, notes overflow, loading/error states, and button-only input handling.
4. `tasks.md` generated from these design artifacts.

## Phase 2: Task Planning Approach

**Task Generation Strategy**:

- Start with failing tests for the contract, controller models, bridge client, navigation behavior, and error-state handling.
- Implement shared SwiftPM entities and controller services before bridge routes or iPad UI code.
- Add the Gaia bridge integration before the iPad shell so client UI is built against a stable internal contract.
- Finish with documentation, VS Code workflow updates, and targeted validation commands.

**Ordering Strategy**:

- TDD first: all model, contract, and scenario tests precede implementation.
- Shared controller data and Aither bridge logic before UI composition.
- iPad shell integration after the bridge contract is available.
- Documentation and operator validation last.

**Estimated Output**: 32-36 ordered tasks in `tasks.md`, including explicit iPad app-target bootstrap/validation and external dependency/performance validation tasks.

## Complexity Tracking

No constitutional violations require justification.

## Progress Tracking

**Phase Status**:

- [x] Phase 0: Research complete (/plan command)
- [x] Phase 1: Design complete (/plan command)
- [x] Phase 2: Task planning complete (/plan command)
- [x] Phase 3: Tasks generated (/plan command)
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:

- [x] Initial Constitution Check: PASS
- [x] Post-Design Constitution Check: PASS
- [x] All NEEDS CLARIFICATION resolved
- [x] Complexity deviations documented

---

_Based on the active repository constitution - See `/.specify/memory/constitution.md`_
