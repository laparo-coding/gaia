---
name: clarify
description: "Klaert unklare Anforderungen, Randbedingungen und Erfolgskriterien vor Implementierung."
argument-hint: "Thema oder unklare Anforderung zum Klaeren"
agent: agent
model: GPT-5 (copilot)
---

Der Nutzertext kommt aus Chat oder als Argument. Nutze ihn immer.

User input:

$ARGUMENTS

Ziel:
- Unklare Punkte schnell und strukturiert klaeren.
- Konkrete, beantwortbare Rueckfragen formulieren.
- Falls genug Kontext vorhanden: Annahmen explizit machen und direkt weiterfuehren.

Pflichten:
- Keine langen Ausfuehrungen; Fokus auf Entscheidungsreife.
- Risiken, offene Abhaengigkeiten und fehlende Daten sichtbar machen.
- Bei mehreren plausiblen Wegen: Optionen mit Trade-offs nennen.

Ausgabeformat:
1. Verstandenes Ziel in 1-2 Saetzen.
2. Offene Punkte als nummerierte Liste.
3. Vorschlag fuer naechsten Schritt (analyze, spec, plan, tasks oder Umsetzung).
