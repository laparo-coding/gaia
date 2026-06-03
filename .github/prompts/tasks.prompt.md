---
name: tasks
description: "Speckit: Erstelle oder aktualisiere specs/<id-slug>/tasks.md auf Basis von spec.md und plan.md."
argument-hint: "Feature-ID/Slug oder Aufgabenpaket fuer tasks.md"
agent: agent
model: GPT-5 (copilot)
---

Der Nutzertext kommt aus Chat oder als Argument. Nutze ihn immer.

User input:

$ARGUMENTS

Ziel:
- Speckit-konforme Aufgabenliste in specs/<id-slug>/tasks.md erstellen oder aktualisieren.

Pflichten:
- spec.md und plan.md als Input verwenden.
- Aufgaben in kleine, pruefbare Einheiten schneiden.
- Reihenfolge nach Abhaengigkeiten definieren.
- Jede Aufgabe mit klarem Ergebnis und Verifikationsfokus formulieren.

Ablauf:
1. Inputs (spec.md, plan.md) lesen und Arbeitsumfang extrahieren.
2. tasks.md mit strukturierten, abhaengigen Schritten schreiben.
3. Entwicklungs-, Test- und Qualitaetsschritte getrennt sichtbar machen.
4. Kurze Ausgabe mit Dateipfad und Startempfehlung fuer Implementierung liefern.
