# ATLAS-WORKBENCH-COMPOSITION-02

Baseline: `06671452d36a916cee61d00c8ef9fe4f328dc3d5` (#342 and #341 included).
Branch: `feat/atlas-workbench-composition-02`.
Scope: Recipe and Procurement presentation, local review fixtures, focused tests and evidence. One agent performed diagnosis, implementation and finish review sequentially.

## Diagnosis and geometry decisions

The selected Recipe catalogue used a 340px fixed table inside a 290px column. Chromium measured `clientWidth=290`, `scrollWidth=340` at 1440, 1280 and 1024px. This required horizontal navigation to reach the action column. Browse mode remains the full catalogue table; selected mode now uses a wrapping list of native buttons with full dish identity, classification, status and explicit pressed state. The desktop navigator is 320px. Search and filters remain reachable through the expanded chooser on narrow screens. Closing reconstructs and focuses the corresponding browse trigger, since the compact list replaces the original table DOM.

Recipe authoring is the primary surface: identity and utilities lead, type/date form a tinted context band, the base composition table has stable ingredient/quantity/unit/note/action geometry, effective composition is subordinate, and the action footer has a terminating rule. The base table keeps its own horizontal scroll on narrow screens; the navigator never needs horizontal scroll.

Procurement originally used a 320px editor, only an attached left/top separator, grid `align-self:auto`, and a body with `flex:1`. Grid stretching supplied the table row's height to short content; the growing body consumed the remainder. The desktop ceiling also reused the table's `calc(100dvh - 400px)` limit, leaving little note space. The replacement uses a 390px editor, a complete subtle border, `align-self:start`, a non-growing/shrinking body (`0 1 auto`), and a non-shrinking header, reconciliation and footer. Long bodies scroll within `max(360px, calc(100dvh - 320px))`; mobile uses the existing 80dvh ceiling. Footer background and top rule terminate the frame; there is only a 1px frame border after the footer.

Both selected layouts stack below 1280px. At 1280px this leaves a useful ~732px Procurement table viewport with local horizontal scrolling and a ~802px Recipe editor. At 1024px a full-width table/editor is preferable to competing narrow columns. Widths are based on the operator jobs, not a uniform master/detail ratio.

## Evidence

Browser harness: `scripts/atlas_workbench_composition_browser_test.py`; local Storybook fixture APIs only. Chromium, DPR 1, reduced motion, full-page PNGs; 200% equivalent desktop reflow uses a 720×450 CSS viewport at DPR 2.

Full-resolution before/after evidence is under [the evidence directory](../testing/artifacts/atlas-workbench-composition-02/). Each phase contains selected Recipe and Procurement screenshots at **1440×900, 1280×800, 1024×768 and 390×844**, plus `geometry.json` with actual DOM rectangles. After evidence also contains named scenario screenshots at 1280×800 and 390×844. These are full-size review sources; any contact sheet is supplementary.

| Acceptance scenario         | Evidence / regression coverage                                              |
| --------------------------- | --------------------------------------------------------------------------- |
| A: Recipe browse            | `recipe-browse-*`; full catalogue restoration test                          |
| B: short Dish               | `recipe-short-*`; native button selected with Enter                         |
| C: long Vietnamese Dish     | `recipe-long-*`; full wrapping navigator/header name                        |
| D: multiple ingredients     | `recipe-long-*`; four fixture ingredients                                   |
| E: long ingredient and note | `recipe-long-*`; fixed base table geometry and local scrolling              |
| F: Recipe review            | `recipe-review-*`; review/save and dirty guard tests                        |
| G: Recipe save              | `recipe-saved-*`; fixture save and authoritative readback tests             |
| H: locked Recipe            | `recipe-locked-*`; existing lock and change-order behavior tests            |
| I: no supplier              | `procurement-none-*`                                                        |
| J: one supplier             | `procurement-one-*`; apply existing proposal                                |
| K: multiple suppliers       | selected `procurement-*`; saved manual split                                |
| L: long supplier name/note  | `procurement-long-*`; wrapping labels and bounded body                      |
| M: rebalance                | `procurement-rebalance-*`; proposal/note retention tests                    |
| N: note-only dirty          | `procurement-note-dirty-*`; save, dirty close, authoritative readback tests |
| O: one allocation row       | `procurement-one-row-*`                                                     |
| P: dense allocation table   | `procurement-dense-*`; 248 fixture rows, local table scroll                 |

## Acceptance gates

**FUNCTIONAL:** Focused workbench, supplier detail, order-stage and immutable export tests must pass. Keep all #341 supplier-note save/dirty-close/readback/export behavior. No controller, hook, bridge, backend contract, quantity precedence, lifecycle or permission changes.

**VISUAL:** Inspect full-resolution screenshots separately from functional checks. Navigator `scrollWidth <= clientWidth`; all visible selection controls fit. Procurement frame, notes and actions fit; the footer meets the bottom frame with <=2px trailing space. Page-level horizontal overflow is absent at all four sizes. Short content uses its natural height; long content has a bounded scroll body.

**ACCESSIBILITY:** Native keyboard buttons, selected `aria-pressed`, accessible action names, narrow-screen chooser/search/filter disclosure, Recipe focus transfer/return, dirty guards, locked controls, existing mobile target sizes and reduced-motion behavior remain available. Table scrolling stays local and keyboard-accessible through existing viewport components.

### Verified local results

- 89 focused tests passed across Recipe workbench, Procurement workbench, supplier detail, order stage and immutable purchase-order exports. The final Recipe visibility correction passed all 17 Recipe tests again; the allocation-table correction passed its focused test.
- TypeScript (`pnpm typecheck`, followed by direct `tsc -b` after type generation), `ui:vnext:check`, targeted Prettier and `git diff --check` passed.
- `ops:workspace` passed identity checks, with the historical D: path warning; the user explicitly authorized this E: checkout.
- Browser assertions passed 39 geometry cases, including 360px, 768px and 200% equivalent reflow in addition to the four requested sizes. The last catalogue Dish remains visible after selection at desktop and mobile.
- Storybook's preview runtime reports `Illegal invocation` while intercepting `HTMLElement.focus` for Chakra focus tracking, also before opening a detail surface. This is a harness limitation; it was not silently treated as an application pass. A temporary plain Vite renderer of the same components and fixture APIs passed Recipe keyboard selection/focus return and Procurement note dirty-close/cancel at 1280px and 390px, with **zero console or page errors** (`after/application-console.json`). Supplier-note authoritative save/readback and export are covered by the focused automated tests. The temporary renderer is excluded from the change.
- The short Procurement editor measures **322.8px** beside a **400px** table. A controlled browser CSS probe restoring `align-self:auto` and body `flex:1` expands that same editor to **400px**. Dense saved content instead uses the bounded body: at 1280px the frame is 480px, with a 299px body viewport for 416px content. Every measured footer terminates within 1px of the editor frame.
- Baseline dense screenshots measured **zero** surface below the footer. The supplied hypothesis of trailing space beneath the footer was not reproduced there: stretch inflated the editing surface/body. The complete frame and content sizing address the confirmed defect without claiming a different cause.

Sequential finish review: **PASS** for this bounded implementation. FUNCTIONAL, VISUAL and ACCESSIBILITY gates were assessed separately. No blocking or major findings remain in the reviewed scenarios. Product review and required GitHub CI remain the Draft PR gates. Full routine frontend validation belongs to `Frontend CI / Format, typecheck, test, build` on that PR.

## Boundaries, security and rollback

No migration or database rollback applies. Security implications reviewed: no change to RLS, backend grants, credential usage, API permissions or authoritative business outcomes. Frontend rollback is a revert of this bounded PR. Existing shared provider, system, tokens and dependencies are unchanged.

Supabase Staging writes = ZERO. Retool writes = ZERO. OPS v1 writes = ZERO. Hosted business writes = ZERO. Fixture edits and saves affect local in-memory review data only.
