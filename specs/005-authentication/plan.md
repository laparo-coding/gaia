## Implementation Plan: Authentication

**Branch**: `005-authentication` | **Date**: 2026-05-30 | **Spec**: [spec.md](spec.md) | **Input**: Feature specification from `/specs/005-authentication/spec.md`

## Summary

Define Gaia's first authentication foundation for both interactive users and
server-to-server integrations by mirroring Aither's Hemera access pattern where
it actually applies: Hemera requests use a shared `X-API-Key`, protected Aither
sync requests use `Authorization: Bearer`, both use dedicated server-side
credentials with per-service token caching and one retry on expiry, and the
route model keeps UI auth and downstream service auth separate.

## Technical Context

**Language/Version**: Swift 6.1 package manifest with Swift 6.x code targets  
**Primary Dependencies**: Foundation, SwiftPM modules (`GaiaCore`, `GaiaFeatureCatalog`), future authentication provider integration, server-side Bearer service credentials for Hemera and Aither  
**Storage**: In-memory token cache in development, pluggable shared cache for production, plus ephemeral user session state  
**Testing**: Swift Testing-style target conventions with targeted auth, service-token, and retry scenario coverage; local `swift test` expects a full Xcode toolchain  
**Target Platform**: Hybrid workspace with SwiftPM modules and a file-based user-facing surface under `app/authentication/` for authentication routes and pages  
**Project Type**: hybrid  
**Editor Workflow**: VS Code + `swiftlang.swift-vscode` + LLDB DAP with shared tasks for `swift build`, `swift test`, `swift format`, `swift lint`, and `swift run GaiaCLI`  
**Performance Goals**: Auth guard decisions should resolve within a single request cycle; cached service credentials should avoid repeated downstream auth handshakes during normal operation  
**Constraints**: No interactive session tokens for service-to-service calls, no secrets in logs, one retry on expiry only, explicit degraded states when Hemera or Aither auth fails  
**Scale/Scope**: One Gaia workspace with interactive user auth plus two downstream service integrations (Hemera data access and Aither control operations)

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-check after Phase 1 design._

- [x] Specs-first flow preserved: `spec.md` → `plan.md` → `tasks.md` before implementation
- [x] Tests are designed to fail before implementation begins
- [x] Structure uses `Package.swift`, `Sources/`, and `Tests/` with a documented hybrid `app/` surface for future UI work
- [x] VS Code build, test, debug, format, and lint commands are identified
- [x] Swift API design, concurrency, and type-safety implications are documented
- [x] Security, observability, and failure handling are covered for the feature surface

## Project Structure

```
Package.swift
Sources/
├── GaiaCLI/
├── GaiaCore/
└── GaiaFeatureCatalog/

Tests/
├── GaiaCoreTests/
└── GaiaFeatureCatalogTests/

app/
└── authentication/

.vscode/
├── launch.json
└── tasks.json

specs/005-authentication/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── openapi.yaml
└── tasks.md
```

**Structure Decision**: Hybrid workspace. Gaia keeps domain logic, CLI tooling,
and contract-driven auth logic in SwiftPM targets under `Sources/` and `Tests/`,
and implements the authentication-facing route and page surface under
`app/authentication/`.

## Phase 0: Outline & Research

All former template unknowns are resolved in `research.md`. Phase 0 focuses on:

1. Confirming the workspace structure for an auth feature that spans SwiftPM
    targets and a future `app/` surface.
2. Locking Gaia onto the real downstream wire contracts: `X-API-Key` for
    Hemera service APIs and `Authorization: Bearer` for protected Aither sync
    operations.
3. Choosing per-service token caching and a single retry-on-expiry policy.
4. Capturing the auth-related environment and contract surfaces before coding.

## Phase 1: Design & Contracts

Phase 1 produces:

1. `data-model.md` with the interactive auth and service-auth entities,
    validation rules, and state transitions.
2. `contracts/openapi.yaml` describing Gaia's planned session lifecycle and
    internal service-auth orchestration endpoints.
3. `quickstart.md` with implementation-time validation scenarios for user auth,
    Hemera auth, Aither auth, and retry-on-expiry behavior.
4. An updated agent context file via `.specify/scripts/bash/update-agent-context.sh copilot`.

## Phase 2: Task Planning Approach

**Task Generation Strategy**:

- Start with failing tests for session state, route protection, service token
   caching, and retry-on-expiry behavior.
- Derive contract tests from `contracts/openapi.yaml` for session and internal
   service-auth endpoints.
- Create implementation tasks in dependency order: auth models → service
    credential manager → Hemera/Aither connectors with target-specific header
    mapping → `app/authentication/`
    session routes, service-authorization routes, and protected auth shell.
- Keep Hemera and Aither integration tasks distinct where credentials,
   audiences, or failure paths differ.

**Ordering Strategy**:

- TDD order first: tests before implementation.
- Shared domain types and credential caching before downstream integrations.
- Interactive UI/auth shell after server-side auth and permission boundaries.

**Estimated Output**: 25-30 ordered tasks in `tasks.md`.

## Complexity Tracking

_Fill ONLY if Constitution Check has violations that must be justified_

No constitutional violations currently require justification.

## Progress Tracking

_This checklist is updated during execution flow_

**Phase Status**:

- [x] Phase 0: Research complete (/plan command)
- [x] Phase 1: Design complete (/plan command)
- [x] Phase 2: Task planning complete (/plan command - describe approach only)
- [x] Phase 3: Tasks generated (/tasks command)
- [x] Phase 4: Implementation complete
- [x] Phase 5: Validation passed

**Gate Status**:

- [x] Initial Constitution Check: PASS
- [x] Post-Design Constitution Check: PASS
- [x] All NEEDS CLARIFICATION resolved
- [x] Complexity deviations documented

---

_Based on the active repository constitution - See `/.specify/memory/constitution.md`_
