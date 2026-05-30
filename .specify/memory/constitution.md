<!--
  Sync Impact Report
  ==================
  Version change: 0.0.0 -> 1.0.0
  Amendment date: 2026-05-29
  Amendment type: MAJOR

  Summary:
  - Replaced an incorrect copied constitution with a Gaia-specific baseline
  - Established a VS Code-first Swift project constitution
  - Preserved relevant Aither principles: test-first work, machine-enforced
    quality, spec-first delivery, security discipline, and observability

  Follow-up:
  - Align repository tooling with this constitution as Swift-specific files are
    introduced
  - Add CI commands and editor tasks once Gaia's Swift toolchain is committed
-->

# Gaia Constitution

## Core Principles

### I. Spec-First Delivery (NON-NEGOTIABLE)

Every change starts as a Speckit artifact before implementation begins.

- Every feature MUST begin with `specs/<id-slug>/spec.md`.
- Implementation planning MUST produce `plan.md` and `tasks.md` before code is
  changed.
- Research findings, tradeoffs, and rejected alternatives MUST be captured in
  `research.md` whenever architecture, dependencies, or platform behavior are
  non-trivial.
- Research SHOULD use Perplexity MCP when it is installed in the workspace; if
  it is unavailable, engineers MUST rely on primary sources such as Swift.org,
  Apple documentation, and official VS Code documentation.
- Public contracts, package boundaries, and configuration surfaces MUST be
  described before implementation, not reverse-engineered after code exists.

**Rationale**: Specs-first work reduces ambiguity, prevents premature coding,
and gives Gaia a stable decision record that survives editor, toolchain, and
team changes.

### II. Test-First Development (NON-NEGOTIABLE)

Gaia follows a strict red-green-refactor workflow.

- New behavior MUST start with failing tests before implementation code is
  written.
- Unit tests MUST cover domain logic, parsing, state transitions, and error
  handling.
- Integration tests MUST cover package boundaries, persistence boundaries,
  network edges, and editor or CLI automation surfaces.
- UI or workflow-critical behavior MUST have end-to-end or executable scenario
  coverage where the stack supports it.
- Swift Testing or XCTest MAY be used, but the repository MUST standardize on a
  primary test framework per target to avoid fragmented test conventions.
- Critical paths MUST maintain meaningful coverage; security-sensitive and data-
  integrity paths require the strongest coverage and regression protection.

**Rationale**: Swift's type system catches many mistakes, but behavior,
integration, and concurrency defects still require executable proof.

### III. VS Code-First Swift Toolchain Discipline

Gaia is a Swift project optimized for Visual Studio Code without sacrificing
compatibility with Apple platform requirements.

- Visual Studio Code is the primary authoring environment for daily development.
- The `swiftlang.swift-vscode` extension, SourceKit-LSP, and LLDB-based
  debugging support are the default editor toolchain.
- Swift Package Manager is the canonical build and dependency system whenever
  the project type allows it; `Package.swift` is authoritative for package-based
  modules, targets, and dependencies.
- Apple-platform targets that still require Xcode-specific assets or signing
  MUST keep core logic, tests, and reusable modules buildable from the command
  line wherever technically possible.
- Repository-owned VS Code tasks and launch configurations MUST remain working
  so build, test, and debug flows are reproducible for every contributor.
- Toolchain selection MUST be explicit and documented; CI and local development
  must not silently depend on different Swift versions.
- When language features depend on indexing, build steps required by the Swift
  extension MUST be documented and automated in workspace tasks.

**Rationale**: A clear editor and toolchain contract removes local setup drift
and keeps Gaia operable across contributors and environments.

### IV. Swift API Design, Concurrency, and Type Safety

Gaia code must feel native to Swift and safe under Swift 6 expectations.

- APIs MUST follow the Swift API Design Guidelines, with clarity at the point
  of use taking priority over brevity.
- Public declarations MUST have documentation comments when exposed outside a
  local implementation boundary.
- Strict typing is required; unchecked casts, force-unwrapping, and force-try
  are forbidden except for tightly scoped invariants that are documented and
  test-covered.
- Structured error types MUST be preferred over stringly typed failure paths.
- Async code MUST use Swift concurrency primitives deliberately: `async/await`,
  actors, task groups, and `Sendable` boundaries where appropriate.
- Complete concurrency checking SHOULD be enabled for all actively maintained
  targets and MUST be part of CI before broad release.
- Data races, main-thread assumptions, and shared mutable state MUST be treated
  as design issues, not debugging afterthoughts.

**Rationale**: Native Swift conventions improve readability, while concurrency
discipline prevents the class of defects that are hardest to reproduce later.

### V. Code Quality, Package Boundaries, and Documentation

Gaia favors small, explicit, machine-checked building blocks.

- Formatting and linting MUST be automated and repository-enforced.
- The repository MUST define one canonical formatter configuration and one
  canonical lint path; style debates are not resolved in review comments.
- Modules and targets MUST have clear ownership and minimal public surface area.
- Shared code MUST live in reusable packages or targets instead of being copied
  between apps, tools, or platform shells.
- Source layout MUST stay predictable. For SwiftPM-based code this means using
  standard `Sources/` and `Tests/` conventions unless a documented exception is
  approved.
- Developer-facing documentation MUST be kept close to the code: README,
  DocC, architecture notes, and spec artifacts must agree.
- Naming, file organization, and package structure MUST optimize comprehension
  for the next maintainer, not local convenience for the current author.

**Rationale**: Machine-enforced quality and disciplined boundaries reduce drift,
lower review cost, and make Swift modules easier to evolve safely.

### VI. Security, Error Handling, and Observability

Reliability and data protection are first-class engineering concerns.

- Secrets, tokens, private keys, and signing material MUST never be committed.
- Missing required configuration MUST fail explicitly; placeholder runtime
  behavior is forbidden for production-critical code paths.
- Logs and telemetry MUST exclude sensitive data and personally identifiable
  information unless explicitly justified and protected.
- Errors MUST be structured, actionable, and attributable to a subsystem,
  request, task, or user journey where relevant.
- Production-impacting failures MUST be observable through centralized logging,
  metrics, tracing, crash reporting, or a documented equivalent stack.
- Network, storage, and platform failures MUST degrade gracefully where
  possible; silent swallowing of errors is forbidden.
- Dependency and toolchain updates MUST include security review for known
  vulnerabilities and breaking runtime changes.

**Rationale**: Swift safety features help, but secure systems still depend on
explicit configuration discipline, measurable failures, and recoverable error
paths.

## Development Standards

### Project Layout

Gaia SHOULD use this baseline structure unless a spec explicitly justifies a
different shape:

- `Package.swift` for package-based targets and dependency declarations
- `Sources/` for production code organized by target
- `Tests/` for unit and integration tests organized by target
- `.vscode/` for shared tasks, launch settings, and workspace guidance
- `Documentation.docc/` or `Docs/` for canonical developer-facing
  documentation
- `specs/` for all Speckit artifacts

Apple-platform app folders, resources, or project metadata MAY exist when the
product requires them, but they must not become an excuse to hide core logic in
editor-specific or IDE-only structures.

### Quality Gates

Every pull request MUST satisfy the smallest applicable executable checks before
merge:

- build
- tests
- formatting and linting
- targeted regression checks for the changed feature
- documentation or contract updates when behavior changed

CI MUST block merges on failing quality gates. Local workflows SHOULD mirror CI
closely enough that a contributor can reproduce failures inside VS Code.

### Review Expectations

- Reviews MUST evaluate correctness, safety, package boundaries, test quality,
  and observability, not just style.
- Large architectural changes MUST cite the relevant spec and plan artifacts.
- Convenience shortcuts that weaken testability, debuggability, or package
  clarity MUST be rejected unless a spec explicitly approves the tradeoff.

## Governance

- This constitution overrides informal local habits and undocumented team
  preferences.
- Every spec, plan, task list, and pull request MUST be checked against these
  principles.
- Amendments require a documented rationale, a version change, and any follow-up
  migration work needed to keep templates and workflows aligned.
- Minor amendments clarify or extend the rules without changing Gaia's core
  engineering model; major amendments change that model and require explicit
  rollout planning.
- If a repository practice conflicts with this constitution, the constitution
  wins until the conflict is resolved in writing.

**Version**: 1.0.0 | **Ratified**: 2026-05-29 | **Last Amended**: 2026-05-29