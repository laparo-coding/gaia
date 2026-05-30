# Gaia Project Governance Overview

This document summarizes governance for the Swift-first Gaia repository.

## Governance Documents

### Constitution

See `./constitution.md` for mandatory standards:

- test-first development and review discipline
- Swift code quality and formatting requirements
- feature workflow (`spec.md` -> `plan.md` -> `tasks.md`)
- security and observability requirements

### Testing Standards

See `./testing-standards.md` for detailed testing expectations.

## Quick Reference

### Daily Developer Checklist

1. Before coding:

```bash
swift format lint --configuration .swift-format --strict Package.swift
swift format lint --configuration .swift-format --strict --recursive Sources Tests app/authentication
```

2. During development:
- follow Red -> Green -> Refactor (TDD)
- keep feature scope aligned with the active spec/tasks
- use VS Code Swift extension diagnostics continuously

3. Before commit:

```bash
swift build
swift test
swift format lint --configuration .swift-format --strict Package.swift
swift format lint --configuration .swift-format --strict --recursive Sources Tests app/authentication
```

## Quality Gates

All changes must pass:

- `swift format lint` on package manifest and source trees
- `swift build`
- `swift test`
- CI workflow status checks in GitHub Actions

## Tooling and Editor Setup

- Package manager: Swift Package Manager (`Package.swift`)
- Formatter/linter: `swift-format` with repository `.swift-format`
- Editor: VS Code + `swiftlang.swift-vscode`
- Tests: Swift Testing / XCTest-compatible targets under `Tests/`

## CI Enforcement

CI must run at minimum:

```bash
swift format lint --configuration .swift-format --strict Package.swift
swift format lint --configuration .swift-format --strict --recursive Sources Tests app/authentication
swift build
swift test
```

## Pre-commit Guidance

Prefer automated checks in pre-commit hooks when configured:

- format/lint checks for touched Swift files
- fast test subset where practical
- full test run before merge

## Onboarding

1. Install the Swift toolchain (Xcode toolchain for full test compatibility on macOS).
2. Open the repository in VS Code.
3. Install `swiftlang.swift-vscode`.
4. Run baseline validation:

```bash
swift build
swift test
swift format lint --configuration .swift-format --strict Package.swift
swift format lint --configuration .swift-format --strict --recursive Sources Tests app/authentication
```
