# Atlas vNext 08 Art-Direction Options

**Status:** Product-selected direction refined; awaiting implementation approval

**Baseline:** PR #315 at `d96e59e82080f0f0091c4cf3e3bfece7427b2e15`

**Branch:** `design/atlas-ui-vnext-08-art-direction`

**Scope:** Presentation exploration only; no production implementation

## Purpose and authority

This document records the three original visual directions for Atlas over the accepted PR #315 responsive and structural foundation, the subsequent Product selection, and the implementation-ready visual specification produced by the required refinement round. It records a direction but does not authorize production implementation.

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

## Product selection — Refined Trạm Điều Hành

Product selected the **Trạm Điều Hành** structural thesis and explicitly borrowed only the table density and restraint of **Sổ Điều Phối**. This is a refinement of the selected direction, not a fourth concept and not a return to Ledger.

### Refined thesis

Atlas is a staffed operating station with four readable layers:

```text
module / global navigation
→ durable current-job context
→ active work surface
→ current decision and one authoritative action
```

The task-context plane provides persistent orientation without becoming another navigation sidebar. The live table remains the dominant working surface. Dense table treatment, natural content height, and restrained rules come from Sổ Điều Phối; the asymmetric task-context hierarchy remains the defining Trạm Điều Hành idea.

### Exact geometry and hierarchy

| Element                                 | Refined specification                                                                                       |
| --------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Desktop task spine                      | Exactly `196px`                                                                                             |
| Mobile task-context block               | Exactly `88px` before the workbar                                                                           |
| Desktop attached detail                 | Exactly `320px`                                                                                             |
| Desktop master area when detail is open | Remaining flexible width; approximately `670px` in the 1440px evidence fixture                              |
| Table header                            | Approximately `38px`                                                                                        |
| Table row                               | Approximately `42px`                                                                                        |
| Sticky identity region                  | Approximately `178px`; retain the existing table viewport contract rather than fixing every column globally |
| Mobile interactive targets              | At least `44px`                                                                                             |

Desktop, no selection:

```text
global navigation → 196px task context → compact workbar
→ natural-height master table → calm canvas → one current command
```

Desktop, selected:

```text
global navigation → 196px task context
→ master table / selected row → attached 320px detail
→ one action that is valid for the current state
```

Mobile:

```text
shell → 88px task-context block → tabs / workbar
→ horizontally scrollable master table → selected detail below the table
```

Typography must make the hierarchy legible without marketing scale: module context approximately `12–13px/600`, active-job H1 `24px/700` on desktop and compacted on mobile, work-surface identity `14–15px/650`, table primary identity `13px/700`, and supporting metadata `12px/450`. Supporting metadata must retain WCAG AA contrast.

### Color and production token translation

The refined prototype remains in the Atlas Soft Mineral family. Production should use the current semantic system rather than copy prototype CSS:

- reuse `bg.navigation` (`#31413E`), `bg.workspace` (`#F2F4F2`), `bg.workbench` (`#FAFBFA`), and `bg.toolbar` (`#F0F4F1`);
- reuse `action.primary.default` (`#35564C`) for the authoritative command;
- reuse `border.default` (`#D8DFDB`) and `border.subtle` (`#E4E9E6`) for quiet table structure;
- reuse `border.accent` (`#B47A56`) only for selection or identity, never focus;
- reuse `focus.ring` (`#567A71`) as a `2px` keyboard-focus ring;
- add one semantic `bg.context` token mapped to `#DDE7E1` if the existing selected/background token cannot represent the durable task-context plane without semantic collision;
- introduce no new brand palette and no raw component-local production colors.

Disabled controls remain legible and neutral rather than faded: full opacity with neutral background, foreground, and border. The prototype reference values are `#E5EBE7`, `#64756E`, and `#BAC7C1`; production should expose those through the existing disabled-state recipe or its semantic-token equivalent.

### Table and selection strategy

- Use a quiet but stronger header, compact 38px/42px header-row rhythm, restrained horizontal separators, tabular quantities, and Unit directly adjacent to quantity.
- Keep Ingredient name as the dominant scanning anchor. Unit, status, and supplier-priority information remain subordinate.
- Use no zebra striping, heavy grid, excess badges, or decorative fill.
- Mark the selected row with the clay identity rail and selection semantics; keep keyboard focus eucalyptus.
- Preserve the existing bounded `AtlasTableViewport`, sticky identity, and native local horizontal scrolling. Mobile retains a visible continuation cue.
- Sparse Procurement is intentionally natural-height. The remaining canvas stays calm; it is not filled with KPIs, stretched rows, empty cards, or decoration.

### Procurement states

The no-selection state shows the current fixture row—`Gạo thơm`, `Trường Tiểu học Nguyễn Du`, `Bếp chính Nguyễn Du`, and `100 kg`—as a complete, natural-height master table. One current command is present without manufacturing status or freshness copy.

Selecting the row opens an attached supplier decision surface. It shows Ingredient identity, confirmed quantity and Unit, participating suppliers, allocated quantities, and exact remaining/difference. Saved participating splits are `NCC An Phú — 60 kg` and `NCC Bình Minh — 40 kg`. Eligible `NCC Thành Công` appears only through the add-supplier disclosure; its draft starts blank and explicitly non-participating.

The allocation must remain positive and total exactly `100 kg` before `Lưu phân bổ` is enabled. The draft has a remove/reset path. While detail is open, `Lưu phân bổ` is the sole dominant action and `Tiếp tục lên đơn` is not presented as a competing action. The prototype models interaction locally only; production continues to use the authoritative backend command and existing exact-quantity helpers.

### Ingredients states

The catalogue retains the 360-row proof and visible, quiet result count. The task spine does not materially reduce scanning width. Ingredient identity remains easy to track, priority suppliers are condensed to the first one or two names plus `+N`, and every row exposes a uniquely named `Xem / sửa` action.

Selecting an Ingredient opens the attached 320px detail on desktop and a complete detail below the table on mobile. Create is demoted while editing. Local field edits make `Xem thay đổi` dominant; `Ưu tiên NCC` remains secondary and `Ngừng dùng` remains destructive. Production must retain the current permission guards, dirty-exit confirmation, controller behavior, and authoritative commands.

### Mobile prioritization

At 390px the desktop spine is not reproduced as a vertical column. The 88px task-context block presents only durable, available context, followed immediately by tabs/workbar and the working table. No technical IDs, fake metrics, disabled future actions, or explanatory filler appear. Selected detail follows the master table without silently dropping fields. Native horizontal scrolling and the continuation cue remain available.

### Interaction and accessibility contract

- Row actions expose unique accessible names and open detail with `aria-selected` and `aria-expanded` synchronized to the selected row.
- Opening detail moves focus to that surface; closing returns focus to the exact initiating action.
- Job tabs support click, ArrowLeft/ArrowRight, Home, End, and roving focus.
- Disabled states remain full-opacity neutral and retain their disabled semantics.
- The eucalyptus focus ring and clay selection rail remain visually distinct.
- Existing exact-quantity parsing must continue accepting both `.` and `,`; do not port the prototype's local number-input parser.
- Secondary prototype tabs are navigation shells only. Production must show the real existing content rather than introduce an empty panel.

### Refined evidence

All refined evidence lives beside the original exploration and remains intentionally uncommitted:

| Required state                                  | Evidence                                                           |
| ----------------------------------------------- | ------------------------------------------------------------------ |
| Procurement desktop, no selection — 1440×900    | `refined-station-procurement-desktop-no-selection-1440x900.png`    |
| Procurement desktop, selected/detail — 1440×900 | `refined-station-procurement-desktop-selected-detail-1440x900.png` |
| Procurement mobile, no selection — 390×844      | `refined-station-procurement-mobile-no-selection-390x844.png`      |
| Procurement mobile, selected/detail — 390×844   | `refined-station-procurement-mobile-selected-detail-390x844.png`   |
| Ingredients desktop — 1440×900                  | `refined-station-ingredients-desktop-1440x900.png`                 |
| Ingredients desktop, selected/detail — 1440×900 | `refined-station-ingredients-desktop-selected-detail-1440x900.png` |
| Ingredients mobile — 390×844                    | `refined-station-ingredients-mobile-390x844.png`                   |
| Ingredients mobile, selected/detail — 390×844   | `refined-station-ingredients-mobile-selected-detail-390x844.png`   |

Comparison and audit artifacts:

- baseline → original Station → refined Station contact sheet: `contact-sheet-station-refinement.png`;
- refined browser gallery: `station-refinement.html`;
- render audit: `refined-render-audit.json`;
- interaction audit: `refined-interaction-audit.json`.

The final `atlas-ui-finish-reviewer` verdict is **PASS**, with no BLOCK, MAJOR, or MINOR findings in the refined prototype scope. The interaction audit passes all 22 checks; all eight renders use exact requested viewports, show no document-wide x/y overflow or browser errors, retain local mobile table overflow and its cue, and preserve all 360 Ingredient rows.

### Proposed production implementation boundary

The future implementation should remain a presentation-only, bounded transfer into the existing Atlas vNext frontend:

- `src/vnext/atlas/system.ts`: add `bg.context` only if required; otherwise reuse current semantic tokens and recipes;
- a small presentation-only task-context component such as `src/vnext/atlas/AtlasTaskContext.tsx`;
- `src/vnext/atlas/procurement/ProcurementWorkbench.tsx`, `ProcurementAllocationTable.tsx`, and `ProcurementSupplierDetail.tsx` for composition, table treatment, and attached-detail geometry;
- `src/vnext/atlas/master-data/IngredientSupplierWorkbench.tsx`, `IngredientCatalogue.tsx`, and `IngredientDetail.tsx` for the equivalent catalogue/detail transfer;
- focused component tests, fixtures, and review-only stories/pages needed to prove the specified states.

Reuse existing `businessPrimary`, secondary, destructive, disabled, focus, and table recipes; the existing workbench/controllers; focus and dirty-exit behavior; permission guards; and all current business/read models. Exact file names must be reconfirmed against the implementation branch before editing.

The implementation boundary explicitly excludes hooks, bridges, business/read models, APIs, contracts, Supabase, RLS, migrations, quantities, statuses, lifecycles, Planning, recipes, schools, and any backend or production-data change. It must not modify PR #315.

### Transfer verification and unresolved Product decisions

Production transfer must prove Procurement and Ingredients at 1440px, 1280px, 768px, and 390px; selected and no-selection states; loading, empty/no-match, error, permission/read-only, stale/uncertain, and reduced-motion behavior; accessible keyboard and focus-return behavior; local table overflow; and unchanged authoritative actions.

Two Product decisions remain before or during implementation approval:

1. Keep the desktop detail fixed at `320px`, as proven, or allow it to expand toward `36–42%` on wider viewports.
2. Include secondary-job surfaces in the same visual-polish implementation slice, or preserve their current production composition until a later transfer.

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

### Original concept finish-review finding — historical `BLOCK`

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

### Original concept finish-review finding — historical `BLOCK`

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

### Original concept finish-review finding — historical `BLOCK`

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
| Finish verdict            | BLOCK                                                         | Original: BLOCK; refined selection: PASS            | BLOCK                                                    |

The two remaining `BLOCK` verdicts apply only to the unselected original concepts. Trạm Điều Hành's original concept was blocked at first review and then resolved through the Product-directed refinement documented above.

## Original exploration limitations and transfer follow-up

- The minimum requested 1440×900 and 390×844 renders are complete; 1280px and 768px transfer widths were not required and remain unverified.
- The original concepts did not demonstrate loading, empty/no-match, missing prerequisite, stale/uncertain, read-only, disabled, error, success, hover, reduced-motion, or full focus-return behavior. The refined evidence adds disabled-state and focus-return coverage; the other states remain production-transfer requirements.
- The original concepts did not demonstrate a complete selected-row → open-detail flow at both required widths; the refined Station evidence now does.
- The concept fixtures use three Procurement rows dated 24/09/2026 while the exact #315 baseline contains one fixture row dated 07/09/2026. The comparison therefore proves visual direction but is not a strict same-data composition comparison.
- The prototypes import the Atlas Chakra system but use isolated hard-coded prototype CSS. A selected direction must be translated into semantic Chakra tokens/recipes and re-proven; prototype markup must not be copied into production.
- Rendering 360 row actions creates hundreds of tab stops and needs an explicit keyboard-flow decision in the selected direction.

## Implementation approval gate

Product has selected and refined **Trạm Điều Hành**, borrowing only Sổ Điều Phối's table density and restraint. This document and Draft PR #317 are the specification artifact. Production React work must not begin until Product explicitly approves implementation and resolves or accepts the two decisions above.

`ATLAS_UI_SELECTED_DIRECTION = AWAITING_IMPLEMENTATION_APPROVAL`
