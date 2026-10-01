# ATLAS-UI-TABLE-USABILITY — table usability and shell overlay stability

Status: Implemented on `feat/atlas-ui-table-usability`; final Product review and GitHub Actions remain required.

Starting `origin/main`: `445a646b09e6e2d306af174a889341184fe5d53a`.

## Product defects and bounded result

The desktop rail tooltip previously rendered inside the rail stacking context, so a workbench could paint over it. It now uses Chakra Tooltip positioning and the existing Atlas-scoped portal container. Hover waits 250 ms; focus opens it immediately; pointer leave, blur and Escape close it. Chakra's exit animation can briefly paint a closing label during rapid focus traversal before unmounting it. The 72 px rail, active-module state, click navigation and mobile drawer remain unchanged. The same bounded audit found one compact related risk: the Planning menu source chooser now uses the same portal root.

School Defaults previously used a horizontal-only Box and content-dependent column sizing. It now uses `AtlasTableViewport`, a bounded local vertical and horizontal scroll region, `Table.Root stickyHeader`, and fixed semantic columns. Saving, validation, draft identity and backend commands are unchanged.

Sorting is local derived presentation state. `AtlasSortableColumnHeader` supplies the keyboard-operable button, directional icon and `aria-sort`; `atlasTableSort` supplies the three-state cycle, Vietnamese numeric collation, stable original-index ties and cloned view projection. Exact operational quantities reuse `parseExactQuantity` and compare `bigint` ticks without conversion to `Number`. Procurement issue sorting derives the same exact remainder and Vietnamese issue label shown in the cell, so visible ascending and descending order cannot diverge from raw lifecycle-state order.

## Table audit

| Table                                                              | Classification      | Sortable columns or exclusion reason                                                                      |
| ------------------------------------------------------------------ | ------------------- | --------------------------------------------------------------------------------------------------------- |
| School Defaults                                                    | SORTABLE NOW        | order, School, School type, state, delivery location; editable portions remain static                     |
| Ingredient Catalogue                                               | SORTABLE NOW        | ingredient, state, purchase unit, type/order group, preferred supplier; rounding and action remain static |
| Supplier Catalogue                                                 | SORTABLE NOW        | supplier, state, contact; phone, email and action remain static                                           |
| Procurement Allocation                                             | SORTABLE NOW        | ingredient, School/location, exact need, supplier, issue state; action remains static                     |
| Confirmed Need                                                     | SORTABLE NOW        | identity/context and read-only proposal; confirmation input, delta, reason and note remain static         |
| Planning Menu                                                      | GEOMETRY FIX ONLY   | menu assignment retains authoritative operational School and dish-type order                              |
| Planning Attendance                                                | GEOMETRY FIX ONLY   | active input matrix; sorting could move rows while editing                                                |
| Planning Pantry                                                    | GEOMETRY FIX ONLY   | active multi-field input matrix grouped by School; operational grouping is meaningful                     |
| Purchase Orders                                                    | GEOMETRY FIX ONLY   | supplier document workflow retains backend business order and selected-row context                        |
| Dispatch                                                           | GEOMETRY FIX ONLY   | release workflow retains backend business order and selected-row context                                  |
| Reconciliation                                                     | GEOMETRY FIX ONLY   | comparison workflow retains backend business order and selected-row context                               |
| Dish Catalogue                                                     | GEOMETRY FIX ONLY   | navigator order remains controller-owned while recipe editing is active                                   |
| Recipe editor, effective recipe, change-order authoring/review     | EXPLICITLY EXCLUDED | line order and review order carry authoring/evidence meaning; sorting would disrupt editing or comparison |
| Planning source review and attached document/support detail tables | EXPLICITLY EXCLUDED | bounded evidence/detail surfaces; no user-reported geometry instability and no safe sorting requirement   |

## Column geometry contract

Tables use Chakra `Table.ColumnGroup` / `Table.Column`, `tableLayout="fixed"`, and an explicit table width. Filtering and sorting only change the row projection.

| Table                  | Widths in CSS px                                         |
| ---------------------- | -------------------------------------------------------- |
| School Defaults        | 64 / 240 / 150 / 140 / 260 / 150 / 150 (total 1154)      |
| Ingredient Catalogue   | 220 / 110 / 110 / 200 / 100 / 200 / 110                  |
| Supplier Catalogue     | 220 / 140 / 170 / 150 / 250 / 110                        |
| Procurement Allocation | 200 / 230 / 130 / 190 / 170 / 130                        |
| Confirmed Need         | 260 / 150 / 180 / 130 / 320                              |
| Planning Menu          | 220 plus 180 per dish type                               |
| Planning Attendance    | 300 / 110 / 110 / 110                                    |
| Planning Pantry        | 210 / 210 / 190 / 130 / 190 / 130 / 96 (total 1156)      |
| Purchase Orders        | 180 / 120 / 220 / 90 / 160 / 150 / 120                   |
| Dispatch               | 240 / 100 / 170 / 150 / 150                              |
| Reconciliation         | 110 / 220 / 140 / 180 / 240 / 130                        |
| Dish Catalogue         | 220 / 140 / 130 / 260 / 120; compact navigator 220 / 120 |

Wide tables scroll inside their existing table viewport or scroll area. Procurement Allocation and Confirmed Need keep an opaque frozen identity header/cell above scrolling content. School uses a local maximum height of 55dvh on narrow screens and `calc(100dvh - 350px)` at desktop.

## Validation and evidence

Focused automated coverage proves portal ownership, hover/focus opening, leave/blur closing, unchanged navigation, School viewport/sticky structure, the full three-state cycle, `aria-sort`, draft identity preservation, stable ties, immutable input arrays, Vietnamese numeric text order and `bigint` comparison beyond IEEE-754 precision.

Rendered 1440 px browser measurements for full data, filtered rows, one row, ascending, descending and restored default order show zero width drift across all five sortable tables:

- School: `[64, 240, 150, 140, 260, 150, 150]`;
- Ingredient: `[220, 110, 110, 200, 100, 200, 110]`;
- Supplier: `[220, 140, 170, 150, 250, 110]`;
- Procurement: `[200, 230, 130, 190, 170, 130]`;
- Confirmed Need: `[260, 150, 180, 130, 320]`.

Rendered Chromium checks at DPR 1 and 1440×900, 1280×800, 768×1024 and 390×844 found no document or body horizontal overflow. School keeps local vertical scrolling at every size and local horizontal scrolling at 768 and 390; after vertical scroll its sticky headers remain visible. Tooltip hover and keyboard focus work at desktop widths, with pointer leave and blur closing it. A settled tooltip probe confirmed one `role="tooltip"` beneath `[data-atlas-portal-root]`; `elementFromPoint` at its overlap center returned the Chakra tooltip positioner, proving topmost paint order over the workbench. Evidence JSON is stored outside the repository under the task evidence directory.

## UI review findings and residual backlog

The read-only Atlas UI director scoped five sortable and seven geometry-only tables. The finish reviewer returned **PASS** after corrections to School/Pantry width totals, Procurement's displayed-issue sort order, and School loading/empty/error messaging. Storybook's focus instrumentation emitted `Illegal invocation` errors in the fixture harness; keyboard focus and tooltip behavior still passed in the browser.

The bounded audit fixed the rail tooltip, the small menu-source popover clipping risk, sticky identity/header layering and content-dependent widths for the audited workbench tables. At 390 px, Procurement can show a narrow partial slice of the adjacent state column between its required frozen 200 px identity column and the action reached by horizontal scrolling. This is valid local scroll disclosure; forcing both edges or reducing the semantic identity width would weaken the approved frozen-identity behavior and geometry, so no corrective override was added. School-scope popover portalling remains a candidate for later work because this pass did not demonstrate clipping and a safe change would create a larger focus-sensitive diff. Visual palette, typography scale, radii, shadows, page anatomy and broader density changes also remain for the later Atlas visual-polish review.

No database migration, API/RPC contract, permission, lifecycle, quantity rule, dependency, Retool asset, OPS v1 file or hosted business data changed. Rollback is the removal of these presentation-only component and documentation changes; no data rollback is required.
