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
