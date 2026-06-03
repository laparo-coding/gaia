---
name: analyze
description: "Analysiert Problem, Ursache, Auswirkungen und moegliche Loesungswege vor einer Aenderung."
argument-hint: "Problem, Beobachtung oder Fragestellung zur Analyse"
agent: agent
model: GPT-5 (copilot)
---

Der Nutzertext kommt aus Chat oder als Argument. Nutze ihn immer.

User input:

$ARGUMENTS

Ziel:
- Eine praezise technische Analyse liefern, bevor implementiert wird.
- Ursache, Auswirkungen und sinnvolle Handlungsoptionen trennen.

Pflichten:
- Relevante Repo-Kontexte einbeziehen (Code, Speckit-Artefakte, Build/Test-Pfade).
- Annahmen klar kennzeichnen.
- Wenn Daten fehlen: gezielte kurze Rueckfragen statt Spekulation.

Ausgabeformat:
1. Problemstatement (kurz).
2. Befunde/Indizien.
3. Wahrscheinliche Ursachen (priorisiert).
4. Optionen mit Vor- und Nachteilen.
5. Konkrete Empfehlung mit naechstem Schritt.
