# Decision D-034 — Atlas Modern Operations UI Visual Architecture

**Status:** Accepted

**Date:** 07/08/2026

## Decision

Atlas uses the **Atlas Modern Operations UI** visual architecture: modern premium B2B operations software for institutional catering. The Application layer presents a dark ink-navy navigation level, a clean white/light global header, a warm-neutral page workspace and a white rounded operational workbench with a subtle border and restrained elevation. These layers remain visibly distinct.

Operational composition is table-first. The dominant table or form belongs inside one primary workbench, supported by tabs, compact toolbars, section dividers and bounded evidence detail. Cards are signals, not generic layout containers: they may show authoritative completeness, attention, blocking or a critical decision total, normally zero to three and never browser-invented statistics or trading-dashboard metrics.

Surfaces use controlled 6 px control radii and approximately 8–10 px workbench/overlay radii. Elevation is quiet and subordinate to surface contrast, spacing, typography, borders and layout. The palette grammar is corporate ink navy for structure and primary authority, restrained copper for brand/active cues, warm neutrals for ordinary presentation, green only for success, amber/orange for warning, red for blocking/destructive consequence and restrained blue for information/focus.

Atlas retains Inter, Segoe UI and Arial fallbacks, compact 32–36 px operational controls, readable Vietnamese text and dense tables where scanning benefits. Phosphor regular-outline icons from the single `@phosphor-icons/react` dependency form the icon vocabulary; icons support scanning, inherit color and never replace business text or accessible names.

Responsive layouts preserve the navigation → page context → attention → workbench → action hierarchy at 360 px, 768 px and 1280 px. Mobile reorganizes priority without reducing the application to cards or permitting page-wide overflow.

Focus must remain visible on white, warm-neutral, navy and selected-navigation surfaces. Status never relies on color alone; warning text uses a dark readable shade; icon-only controls require accessible naming; reduced motion, semantic headings, labels and keyboard order remain required.

No corporate logo artwork is authorized. The existing text/product identity remains until official transparent or SVG artwork is provided in a separate branding task.

Mantine 9 continues to own generic presentation mechanics. Atlas and its backend contracts continue to own business semantics, authoritative state, command eligibility, safe messages, permissions, lifecycle, quantities and evidence. This decision creates no business capability, object, contract, command, event, read model, calculation, persistence or permission, and it does not authorize a generic design-system programme.
