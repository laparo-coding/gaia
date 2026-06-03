---
name: plan
description: "Speckit: Erstelle oder aktualisiere specs/<id-slug>/plan.md auf Basis einer vorhandenen spec.md."
argument-hint: "Feature-ID/Slug oder Planungsauftrag fuer plan.md"
agent: agent
model: GPT-5 (copilot)
---

Der Nutzertext kommt aus Chat oder als Argument. Nutze ihn immer.

User input:

$ARGUMENTS

Ziel:
- Speckit-konformen Umsetzungsplan in specs/<id-slug>/plan.md erzeugen oder aktualisieren.

Pflichten:
- Vorher pruefen, dass specs/<id-slug>/spec.md existiert.
- Plan in umsetzbare Phasen aufteilen (Analyse, Implementierung, Validierung).
- Konkrete Risiken, Abhaengigkeiten und Validierungsschritte nennen.
- Keine finalen Codeaenderungen ausfuehren, Fokus bleibt auf Planung.

Ablauf:
1. Relevante spec.md lesen und offene Annahmen markieren.
2. plan.md mit klaren Schritten, Reihenfolge und Verifikation schreiben.
3. Auf bestehende Repo-Standards (SwiftPM, Tests, Lint) Bezug nehmen.
4. Kurzbericht mit Dateipfad und naechstem Schritt (tasks.md) liefern.
