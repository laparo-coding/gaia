---
name: spec
description: "Speckit: Erstelle oder aktualisiere specs/<id-slug>/spec.md fuer ein neues Feature inklusive User Stories und Anforderungen."
argument-hint: "Feature-Idee oder Scope fuer spec.md"
agent: agent
model: GPT-5 (copilot)
---

Der Nutzertext kommt aus Chat oder als Argument. Nutze ihn immer.

User input:

$ARGUMENTS

Ziel:
- Speckit-konforme Spec-Datei unter specs/<id-slug>/spec.md erstellen oder aktualisieren.
- Falls noch kein Feature-Slot existiert: naechste freie numerische ID + slug vorschlagen und anlegen.

Pflichten:
- Bestehende Repo-Konventionen respektieren.
- Klar zwischen funktionalen Anforderungen und Randbedingungen trennen.
- Akzeptanzkriterien als testbare Punkte formulieren.
- Keine Implementierung starten, nur Spec-Artefakt vorbereiten.

Ablauf:
1. Bestehende Specs in specs/ pruefen, dann Zielordner bestimmen.
2. spec.md erstellen/aktualisieren mit Scope, Stories, Anforderungen, Risiken.
3. Falls Infos fehlen: minimale Rueckfragen stellen, sonst sinnvolle Defaults dokumentieren.
4. Kurze Zusammenfassung mit Dateipfad und naechstem Schritt (plan.md) liefern.
