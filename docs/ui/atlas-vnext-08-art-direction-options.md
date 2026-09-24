# Atlas vNext 08 Art-Direction Options

**Status:** Awaiting Product selection

**Baseline:** PR #315 at `d96e59e82080f0f0091c4cf3e3bfece7427b2e15`

**Branch:** `design/atlas-ui-vnext-08-art-direction`

**Scope:** Presentation exploration only; no production implementation

## Purpose and authority

This document records three intentionally different visual directions for Atlas over the accepted PR #315 responsive and structural foundation. It does not select a direction or authorize production implementation.

The exploration preserves OPS_SYSTEM_MAP v1.0, D-034, D-035, D-045, the approved three-stage operating baseline, current workflows, backend-owned state, commands, lifecycle, permissions, exact quantities, API contracts, RLS, immutable history, and the existing Procurement and Ingredient/Supplier operator jobs.

No prototype connects to a live business command. No production component, backend, Supabase, Retool, Planning, migration, RLS, API, quantity, or lifecycle behavior changed.

## Baseline diagnosis

PR #315 fixed important structural problems: bounded table viewports, keyboard-reachable local overflow, sticky identity behavior, visible Procurement identity, improved mobile shell height, Ingredient result context, and corrected workbench headings. Those improvements remain the starting point.

The remaining problem is art direction rather than correctness:

- workspace, workbench, toolbar, summary, and table surfaces remain too visually similar;
- sparse Procurement is dominated by an unfinished-looking pale work area;
- dense Ingredients lacks strong scan landmarks across 360 rows;
- mobile chrome and stacked controls delay the start of the working table;
- horizontal continuation is technically available but visually quiet;
- selected-row and attached-detail composition feels mechanical rather than intentionally connected.

The concepts therefore change composition, hierarchy, table framing, master/detail geometry, surface use, and mobile prioritization rather than applying another token-level polish pass.

## Evidence

Durable local evidence was generated outside the repository at:

`C:/Users/HOME/.codex/visualizations/2026/09/24/01a0d25d-f073-7a40-b3d2-3e3d202b267d/atlas-vnext-08/`

- Contact sheet: `contact-sheet-4x4.png`
- Browser gallery: `index.html`
- Render audit: `render-audit.json`

The contact sheet has four rows (`#315 baseline`, `Sổ Điều Phối`, `Trạm Điều Hành`, `Làn Nghiệp Vụ`) and four columns (`Procurement 1440×900`, `Procurement 390×844`, `Ingredients 1440×900`, `Ingredients 390×844`). Binary evidence is intentionally not committed.

### Exact #315 baseline

| Archetype   | Desktop                                     | Mobile                                    |
| ----------- | ------------------------------------------- | ----------------------------------------- |
| Procurement | `baseline-procurement-desktop-1440x900.png` | `baseline-procurement-mobile-390x844.png` |
| Ingredients | `baseline-ingredients-desktop-1440x900.png` | `baseline-ingredients-mobile-390x844.png` |

### Concept renders

| Direction      | Procurement desktop                                | Procurement mobile                               | Ingredients desktop                                | Ingredients mobile                               |
| -------------- | -------------------------------------------------- | ------------------------------------------------ | -------------------------------------------------- | ------------------------------------------------ |
| Sổ Điều Phối   | `concept-ledger-procurement-desktop-1440x900.png`  | `concept-ledger-procurement-mobile-390x844.png`  | `concept-ledger-ingredients-desktop-1440x900.png`  | `concept-ledger-ingredients-mobile-390x844.png`  |
| Trạm Điều Hành | `concept-station-procurement-desktop-1440x900.png` | `concept-station-procurement-mobile-390x844.png` | `concept-station-ingredients-desktop-1440x900.png` | `concept-station-ingredients-mobile-390x844.png` |
| Làn Nghiệp Vụ  | `concept-lanes-procurement-desktop-1440x900.png`   | `concept-lanes-procurement-mobile-390x844.png`   | `concept-lanes-ingredients-desktop-1440x900.png`   | `concept-lanes-ingredients-mobile-390x844.png`   |

All 12 concept renders use exact requested viewports. Audit results show zero concept document-wide horizontal overflow, local horizontal overflow at mobile, 360 Ingredient DOM rows, and zero console or page errors. The baseline was regenerated from the exact #315 fixture entry at `/atlas-vnext-review.html?scenario=ready`.

## Direction 1 — Sổ Điều Phối

### Thesis

Atlas becomes a precise operational register: compact, ruled, calm, and trustworthy. Density is treated as a strength, while whitespace sits around the register instead of inside an empty full-height panel.

### Structural model

```text
shell
→ compact context / job masthead
→ single register-control strip
→ attached ledger head
→ ruled operational table
→ selected-row detail
→ dominant command
```

### Typography and surfaces

- Inter with approved fallbacks; compact 22px H1, 15px section identity, 13px table text, 12px labels.
- One crisp paper-like work surface on a visible mineral workspace.
- Internal sections remain flush; radius belongs only at the outer sheet boundary.
- Stronger rules mark semantic column groups without boxing every cell.

### Color strategy

`#243834` navigation, `#FCFDFB` paper, `#EEF3EF` field/toolbar, `#C8D2CD` rule, `#2F5B4D` primary action, and `#B06F49` sparse clay identity.

### Table and master/detail strategy

- 40–44px rows, right-aligned tabular quantities, stronger header rule, and deliberate group separators.
- Sticky identity and a conditional edge shadow communicate concealed horizontal content.
- Selected row and attached detail share the same clay identity marker.
- Sparse Procurement uses a content-height ledger; dense Ingredients fills the available viewport and scrolls locally.

### Mobile strategy

Context, H1, and tabs share a compact masthead. High-frequency scope controls stay visible; secondary filters move behind a labelled disclosure with a visible active-filter summary. The table retains native scrolling and a pinned human identity.

### Principal risk

If every boundary is emphasized, the direction can regress into spreadsheet-era ERP and create visual fatigue across 360 rows.

### Finish-review finding — `BLOCK`

- Procurement lost its explicit allocation-detail action and did not prove selected/open-detail states.
- Sparse desktop Procurement still leaves a large undifferentiated lower workspace.
- Mobile continuation needs a stronger stable cue.
- Prototype labels drifted from authoritative copy (`Ngày phục vụ`, `Trường / điểm giao`), and small secondary metadata did not meet AA contrast.

Production adoption would require restoring the detail path, proving desktop/mobile detail states, intentionally resolving the remaining sparse canvas, preserving authoritative labels, and correcting contrast.

## Direction 2 — Trạm Điều Hành

### Thesis

Atlas becomes a staffed operating station: persistent task context on the left, live work on the right. The inner task spine gives sparse and dense jobs an unmistakable asymmetric silhouette and keeps scope visible without repeating a large header stack.

### Structural model

```text
global navigation
→ contextual task spine
→ live toolbar and data stage
→ selected-row inspector
→ contextual command
```

On mobile, the spine becomes a compact task banner with job, scope, count, current step, and directly adjacent job tabs.

### Typography and surfaces

- 28px desktop identity within the spine, 22px mobile identity, 14px workflow step, 13px table text.
- Dark global shell, mineral canvas, tinted context spine, and white live stage form three flush planes rather than cards.
- The toolbar and table align to one stage edge; no dashboard tiles or invented KPIs appear in the spine.

### Color strategy

`#263330` navigation, `#ECEFEB` canvas, `#DDE7E1` spine, `#FFFFFF` stage, `#214F43` command, and `#C47B4F` identity/exception cue.

### Table and master/detail strategy

- The task spine remains stable while the live stage changes between sparse Procurement and dense Ingredients.
- Count, current scope, and filter summary live in the spine; table width is reserved for working columns.
- A selected row may open a docked inspector only at widths that preserve the table's practical scan area.

### Mobile strategy

The task spine compresses to an 88–104px banner. Active filter summaries remain visible while the filter editor moves into a labelled sheet. Procurement may use a bottom command dock only for the existing backend-authorized next action.

### Principal risk

The inner spine competes with dense table width and can duplicate context already visible in global navigation or the live stage.

### Finish-review finding — `BLOCK`

- Mobile Ingredients omitted the dominant `Tạo nguyên liệu` action.
- Procurement again omitted the explicit row/detail route.
- At 1440px, the combined global navigation and 220px spine force local horizontal scrolling for both archetypes and hide the action column from the initial Ingredient viewport.
- Master/detail geometry was not demonstrated; small spine copy also had contrast failures.

Production adoption would require restoring both missing actions, reducing or collapsing the spine enough to preserve 1440px working width, proving detail behavior, and correcting copy and contrast.

## Direction 3 — Làn Nghiệp Vụ

### Thesis

Atlas reveals how existing information moves through an operation. Current columns form readable lanes—identity, requirement, allocation, state, and action—so the table becomes a deliberate process map instead of a flat matrix.

### Structural model

```text
compact route header
→ existing job navigation
→ filter deck
→ grouped table lanes
→ selected-row bottom inspector
→ contextual command
```

### Typography and surfaces

- 24px H1, 13px job navigation, 12px lane-group labels, 13px table values, and 14px decision-critical quantities.
- A nearly white workbench sits on a cool mineral workspace; restrained lane bands and rules create hierarchy instead of nested panels.
- Two-level headers group only existing columns and preserve valid table semantics.

### Color strategy

`#293638` navigation, `#EEF2F2` workspace, `#FBFCFC` surface, `#E5EEF0` lane tint, `#31594F` action/focus, and `#B87545` route/identity cue.

### Table and master/detail strategy

- Procurement groups existing columns as `Nhận diện`, `Nhu cầu`, `Phân bổ`, and `Trạng thái`.
- Ingredients groups existing columns as `Nhận diện`, `Cơ sở mua`, `Nhà cung ứng`, and `Duy trì`.
- A full-width bottom inspector preserves wide-table geometry while attaching detail to the current selection.

### Mobile strategy

Labelled lane anchors should move the same native horizontal table viewport to an existing column group. They are navigation aids, not workflow stages, a carousel, or a replacement for native scrolling. Human identity stays pinned and an edge shadow signals hidden lanes.

### Principal risk

Grouped headers, anchors, route treatment, and a bottom inspector can stack into too much chrome; presentation labels must never imply new business stages.

### Finish-review finding — `BLOCK`

- The prototype's numbered route line made Ingredient navigation look like an invented two-step lifecycle, contrary to D-035.
- Mobile lane controls looked actionable but did not move the table or expose current-column state.
- The selected row lacked complete selection semantics and the bottom inspector was static; actual open detail remained unproven.
- Stacked route, filter, anchor, two-level header, and inspector bands reduce the mobile work viewport; small metadata contrast also failed.

Production adoption would require removing the invented sequence, implementing accessible lane navigation or restyling it as non-interactive grouping, connecting selection to a real detail state, reducing stacked chrome, and correcting contrast.

## Cross-concept tradeoffs

| Dimension                 | Sổ Điều Phối                                                  | Trạm Điều Hành                                      | Làn Nghiệp Vụ                                            |
| ------------------------- | ------------------------------------------------------------- | --------------------------------------------------- | -------------------------------------------------------- |
| Primary strength          | Compact density and disciplined ledger rhythm                 | Strongest task orientation and sparse-page identity | Strongest wide-table scan landmarks and continuation cue |
| Sparse Procurement        | Content-height register; still needs a stronger canvas ending | Spine gives the sparse task stable visual weight    | Lane flow makes one row read as a decision sequence      |
| Dense Ingredients         | Efficient width; potential rule fatigue                       | Persistent orientation; highest width cost          | Strong column recovery; highest stacked-header cost      |
| Master/detail model       | Right attached detail                                         | Right stage inspector                               | Full-width bottom inspector                              |
| Mobile model              | Compact masthead and filter disclosure                        | Task banner and optional command dock               | Native table plus functional lane anchors                |
| Distinctiveness from #315 | Immediate                                                     | Immediate                                           | Immediate                                                |
| Principal adoption risk   | Old spreadsheet-ERP feel                                      | Duplicate context and reduced table width           | Invented process semantics and excess chrome             |
| Finish verdict            | BLOCK                                                         | BLOCK                                               | BLOCK                                                    |

`BLOCK` here means the prototype is not a production-ready specification. It does not mean Product cannot select the direction. Selection should identify which visual thesis merits a bounded correction/specification round before production implementation.

## Evidence limitations and required follow-up after selection

- The minimum requested 1440×900 and 390×844 renders are complete; 1280px and 768px transfer widths were not required and remain unverified.
- No concept demonstrates loading, empty/no-match, missing prerequisite, stale/uncertain, read-only, disabled, error, success, hover, reduced-motion, or full focus-return behavior.
- No concept demonstrates a complete selected-row → open-detail flow at both required widths.
- The concept fixtures use three Procurement rows dated 24/09/2026 while the exact #315 baseline contains one fixture row dated 07/09/2026. The comparison therefore proves visual direction but is not a strict same-data composition comparison.
- The prototypes import the Atlas Chakra system but use isolated hard-coded prototype CSS. A selected direction must be translated into semantic Chakra tokens/recipes and re-proven; prototype markup must not be copied into production.
- Rendering 360 row actions creates hundreds of tab stops and needs an explicit keyboard-flow decision in the selected direction.

## Product decision gate

No direction is selected in this task. Product may choose one direction, combine explicitly named properties in a new approved specification, or reject all three. Production React work must not begin until that decision is recorded.

`ATLAS_UI_ART_DIRECTION = AWAITING_PRODUCT_SELECTION`
