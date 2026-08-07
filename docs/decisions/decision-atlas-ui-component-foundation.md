# Decision D-033 — Atlas UI Component Foundation

**Status:** Accepted

**Accepted on:** 07/08/2026

## Decision

Adopt Mantine 9 as the UI component foundation for the connected Atlas React application. The approved initial packages are `@mantine/core` and `@mantine/hooks`, kept on the same exact version, plus the official Vite/PostCSS build support required by Mantine.

Mantine owns generic presentation and interaction mechanics. Atlas continues to own business semantics, backend-authoritative state, command eligibility, safe messages, quantities, permissions and lifecycle behavior.

The intended layering is:

```text
Business Contract / backend-authoritative state
→ existing Atlas API/model result
→ thin Atlas semantic presentation where needed
→ Mantine presentation primitive
→ Atlas visual theme
```

## Relationship to D-032

D-032 prohibited speculative framework adoption and premature design-system work. D-033 is the Product Owner-approved foundation for the connected Admin and Planning UI now entering its bounded quality phase. It does not authorize a generic design-system programme, a full repository rewrite, downstream prototype polish or browser-owned business behavior.

## Constraints

- Adopt Mantine gradually in bounded connected surfaces.
- Retain Atlas semantic wrappers only where shared business meaning exists.
- Do not add another Mantine package without demonstrated need and a bounded decision.
- Do not add a third-party grid without a separate decision.
- Mantine must not infer lifecycle, capability or command eligibility; calculate authoritative quantities; reinterpret safe backend messages; retry writes automatically; or own business state.
