# Gaia Agent Notes

## Default Workflow

1. Lege neue Anforderungen unter specs/<id-slug>/spec.md an.
2. Erzeuge plan.md und tasks.md, bevor Code geändert wird.
3. Halte Implementierungen klein und validiere sie mit lint, typecheck und Tests.

## Stack Expectations

- Nutze Swift Package Manager als Standard für Build, Targets und Dependencies.
- Nutze VS Code als primäre Entwicklungsumgebung mit `swiftlang.swift-vscode`.
- Nutze `swift-format` für Formatting und Linting.
- Schreibe Unit-Tests mit XCTest oder Swift Testing und halte den Repo-Standard pro Target konsistent.
- Lege neue produktive Swift-Quellen unter `Sources/` und Tests unter `Tests/` an.
- Behandle bestehende Web- oder Prototyp-Strukturen unter `legacy/` als archiviert, außer ein Task verlangt explizit Arbeit daran.

## Caveman Mode

- Referenz: `.github/caveman-mode.md`.

## Codacy Skills

You have access to Codacy skills. Read the relevant `SKILL.md` whenever the user's request matches a skill description below.

| Skill | When to use | Instructions |
|-------|-------------|--------------|
| `codacy-cloud-cli` | User mentions Codacy, asks about code quality metrics, issues, findings, pull request analysis, tools or patterns | [SKILL.md](skills/codacy-cloud-cli/SKILL.md) |
| `codacy-code-review` | User asks to review a PR, check what a pull request introduced, verify coverage, or find new issues | [SKILL.md](skills/codacy-code-review/SKILL.md) |
| `configure-codacy` | User wants to configure Codacy, reduce noise, fix false positives, or enable/disable tools | [SKILL.md](skills/configure-codacy/SKILL.md) |
| `configure-codacy-cloud` | User wants to tune or configure Codacy directly on the cloud, or reduce noise on a repo already on Codacy with a finished analysis | [SKILL.md](skills/configure-codacy-cloud/SKILL.md) |
| `setup-coverage` | User wants to set up coverage, add coverage reporting, or fix missing coverage uploads | [SKILL.md](skills/setup-coverage/SKILL.md) |
| `codacy-analysis-cli` | User wants to run static analysis locally, scan files, or analyze staged changes without pushing to Codacy | [SKILL.md](skills/codacy-analysis-cli/SKILL.md) |

## Requirements

- Codacy CLI: `npm install -g @codacy/codacy-cloud-cli`
- Codacy Analysis CLI: `npm install -g @codacy/analysis-cli`
- `CODACY_API_TOKEN` environment variable, or run `codacy login`
