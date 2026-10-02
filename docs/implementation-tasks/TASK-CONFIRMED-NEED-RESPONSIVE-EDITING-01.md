# CONFIRMED-NEED-RESPONSIVE-EDITING-01

Baseline: `d11c09efda974e7c8e4478d956e8011a24c1ddb6`.
Branch: `fix/confirmed-need-responsive-editing-01`.
Finding: **AUI-01**, recovered read-only from
`3e48e6485dc747c53f230c6be0e8117bfe203316^3:docs/implementation-tasks/AUDIT-ATLAS-CROSS-MODULE-UI-FINISH-01.md`.
The audit stash commit `3e48e6485dc747c53f230c6be0e8117bfe203316` remains intact; it was not applied, dropped or rewritten.

## Scope and acceptance

This is a bounded Confirmed Need presentation correction. Production changes are
limited to `ConfirmedNeedTable.tsx`; the workbench, draft/controller, shared table
viewport, sortable header, system, contracts and fixtures were inspected and remain
unchanged. Tests, a local browser harness, evidence and this record support review.
One agent performed all work sequentially; no subagents were used.

Preserve all five operational columns, exact text quantity parsing/serialization,
mandatory reason/note rules, generated proposal and decision authority, local
sorting/filtering, dirty state, persistent actions, released locks and progressive
support disclosure. No dependency, backend, migration, RPC, lifecycle, Shopping List
error-copy, other module or hosted business change is authorized.

Acceptance: identity scrolls with the table below `xl`, remains horizontally pinned
at desktop widths, and does not obscure authoring. Quantity/reason/note fit in the
local viewport after focus; vertical sticky headers, exact drafts and reachable
Save remain. Page-level horizontal overflow is absent. Focused automated tests,
browser geometry, visual and accessibility review and required local checks pass.
Required GitHub Frontend CI and owner product review remain PR gates; do not merge.

## Reproduced root cause and RED evidence

The production table has a 1040px minimum width, with nominal identity/proposal/
quantity/delta/reason columns of 260/150/180/130/320px. Identity header and body cells
previously used unconditional `position: sticky; left: 0` with opaque surfaces.
Chakra also makes the header **row** vertically sticky independently of these cells.

Before production edits, Chromium measured:

| CSS viewport | Table client / scroll width | Identity       | Focused quantity bounds    | Result                                                           |
| ------------ | --------------------------- | -------------- | -------------------------- | ---------------------------------------------------------------- |
| 390×844      | 368 / 1040                  | 11–271; sticky | 127–263.97; scrollLeft 306 | Entire input behind identity                                     |
| 360×800      | 338 / 1040                  | 11–271; sticky | 112–248.97; scrollLeft 321 | Entire input behind identity                                     |
| 768×1024     | 734 / 1040                  | 17–277; sticky | 439–575.97                 | Quantity initially fits; reason 749–1045 exceeds right edge 751  |
| 1024×768     | 918 / 1040                  | 89–349; sticky | 511–647.97                 | Quantity initially fits; reason 821–1117 exceeds right edge 1007 |

At 390/360px, native reason focus pans to scrollLeft 672/702, but the pinned
identity still overlaps the reason select at 71–367 / 41–337. The exposed bands
are only 108/78px, narrower than the 136.97px quantity input.

The focused narrow-identity regression failed before production edits: expected
`static`/automatic inset, received `sticky`/zero inset. After the CSS change it
passed. A second focused test failed before the reveal handler: a partially clipped
reason required local scrollLeft 238 but remained at zero. It passes after the
handler and additionally verifies left-edge reveal, no movement for an already
visible control, unchanged vertical scroll and exact draft preservation.

## Responsive correction and focus evidence

Use Atlas/Chakra `xl` (80rem, 1280 CSS px): identity header/cell position is `static`
below it, with the Atlas structural automatic inset; at/above it position is
`sticky` with zero inset. No column width, type size or field changed.

Evidence supports this existing breakpoint: at 1280px the local viewport is 1158px
wide and all authoring geometry fits; 1366/1440px provide 1244/1318px. At 1024px the
viewport is 918px, so the complete 1040px geometry requires local scrolling. The
breakpoint is deliberately conservative and matches the existing desktop workbench
transition. The header row retains `stickyHeader` and its vertical top behavior.

CSS-only measurements remove identity overlap, but native programmatic focus still
leaves the reason select partly clipped at 1024 and 768px. Therefore this table's
`onFocusCapture` checks input/select bounds and adjusts only its own `scrollLeft`
to the nearest visible horizontal edge. It does not scroll the document vertically,
move focus, persist anything or alter business state. No generic reveal framework
or overlay was added. Existing ingredient-specific accessible names are adequate.

The intermediate CSS-only evidence is retained. Its old checker also over-required
the entire identity to leave the viewport at 1024px (maximum pan is only 122px);
the final assertion correctly checks that identity moves with actual local pan.
Invalid entry in the final probe uses keyboard focus/select/type, avoiding
Playwright's own `fill` selection-scroll behavior.

## Final browser geometry and visual review

Chromium 151.0.7922.34, Windows, vi-VN, reduced motion. DPR 1 normally; equivalent
200% desktop reflow is **720×450 CSS px at DPR 2**, matching the existing project
convention. It is layout equivalence, not native browser zoom or touch certification.

| CSS viewport   | Local bounds | client / scroll width | Quantity focus: pan; bounds | Reason focus: pan; bounds | Identity       |
| -------------- | ------------ | --------------------- | --------------------------- | ------------------------- | -------------- |
| 1440×900       | 97–1415      | 1318 / 1318           | 0; 628.59–813.67            | 0; 1021.45–1403           | sticky; left 0 |
| 1366×768       | 97–1341      | 1244 / 1244           | 0; 599.42–771.69            | 0; 970.22–1329            | sticky; left 0 |
| 1280×800       | 97–1255      | 1158 / 1158           | 0; 565.52–722.91            | 0; 910.69–1243            | sticky; left 0 |
| 1024×768       | 89–1007      | 918 / 1040            | 0; 511–647.97               | 110; 711–1007             | static         |
| 768×1024       | 17–751       | 734 / 1040            | 0; 439–575.97               | 294; 455–751              | static         |
| 390×844        | 11–379       | 368 / 1040            | 306; 127–263.97             | 672; 71–367               | static         |
| 360×800        | 11–349       | 338 / 1040            | 321; 112–248.97             | 702; 41–337               | static         |
| 720×450, DPR 2 | 11–709       | 698 / 1040            | 0; 433–569.97               | 342; 401–697              | static         |

Final geometry assertions pass for all 65 measured states, plus two sorting/filter/
dirty-cancel/fixture-save browser smoke cases. Authoring bounds fit with 1px
tolerance; no sticky identity overlaps focused controls. Note fields fit too.
Local horizontal scrolling is retained below desktop width, with no body/document
horizontal overflow. Vertical header geometry remains sticky during local scrolling.
Save fits vertically after normal local/page navigation; the prior dirty mobile
28dvh table-height behavior is preserved. No page errors or external requests
were recorded in the main/smoke runs.

Full-resolution screenshots and JSON are in
[the evidence directory](../testing/artifacts/confirmed-need-responsive-editing-01/).
`before/geometry.json`, `css-only/geometry.json` and `after/geometry.json` retain
viewport/client/scroll dimensions, scroll position, identity/header/quantity/reason/
note rectangles, computed position and overlap results. Final evidence contains
65 named full-page PNGs, including normal, quantity focus, dirty quantity, reason
focus, note edit, dirty Save, invalid, local scroll and released, plus two
saved/filter/sort smoke PNGs at 1366 and 390px. Twelve selected baseline PNGs
demonstrate desktop geometry and narrow quantity/reason failure; intermediate
CSS-only geometry is retained without duplicate screenshots. No contact sheet is
used as the acceptance source.

Sequential screenshot review covers desktop normal/dirty, tablet quantity/reason,
mobile quantity/reason/Save and reflow. Desktop information relationships and
density remain; mobile controls no longer disappear under identity. Conditional
reason chrome and validation surfaces remain visible. No new visible identity
panel is needed.

## Functional and accessibility regressions

- Exact quantity: `12,5` stays exact through edits, panning, sorting, filtering,
  dirty cancel and local fixture Save/readback (`12.500000`). Existing six-place
  and beyond-binary-precision tests pass. No numeric conversion changed.
- Reason/note: required reason still disables Save until supplied; `OTHER` plus
  `Bếp yêu cầu` survives Save/readback. Proposal acceptance and conditional chrome
  retain existing semantics.
- Dirty/actions: dirty marker, hidden dirty count, differences-only filter,
  persistent Save, dirty-exit cancel and Continue navigation retain their behavior.
- Search, School/status scope and sorting remain local under existing semantics;
  new regression verifies both sort keys plus panning/search/differences-only do
  not discard draft quantity/reason/note.
- Released/read-only: quantity remains disabled, Save absent; no new mutation
  controls. Existing historical precision remains read-only.
- Accessibility: semantic five-column table, ingredient quantity/reason/note names,
  Tab quantity→reason→note, retained active element, visible focus ring, linked
  validation error and dirty-dialog focus behavior preserved. Header row remains
  vertically sticky even though narrow identity header is horizontally static.
- Support detail and Shopping List behavior are untouched.

## Reproduce and validate

The saved harness imports actual production provider/shell/workbench and existing
in-memory fixtures; it never initializes hosted services. Run from the repository:

```sh
pnpm exec vite docs/testing/artifacts/confirmed-need-responsive-editing-01/harness --config vite.config.ts --port 3018 --host 127.0.0.1
python scripts/confirmed_need_responsive_browser_test.py --url http://127.0.0.1:3018 --phase after
pnpm exec vitest run src/vnext/atlas/planning-confirmed/ConfirmedNeedWorkbench.test.tsx src/vnext/atlas/planning-confirmed/confirmedNeedDraft.test.ts src/vnext/atlas/planning-confirmed/useConfirmedNeedWorkbench.test.tsx
pnpm ui:vnext:check
pnpm typecheck
git diff --check
pnpm ops:workspace
```

Final focused tests: **103 tests passed across three files**. The saved production-
component harness passed 65 geometry states and two browser smoke cases.
`ui:vnext:check`, `pnpm typecheck`, targeted Prettier and `git diff --check` pass.
Prettier covers production/test/docs/harness. The first typecheck rejected raw
`auto` under strict Chakra spacing types; replacing it with Atlas's existing
`var(--atlas-layout-auto, auto)` structural fallback resolved it.

`ops:workspace` verifies this authorized E: checkout and correct origin; its
historical D: path warning is informational under the explicit task authorization.
Full routine validation belongs to GitHub
`Frontend CI / Format, typecheck, test, build`. A Draft PR is required; no merge.

## Security, boundaries and rollback

FACTS EXPLICIT → STATE DERIVED → SUPPORTING OBJECTS GENERATED is unchanged.
Backend proposal, exact confirmed facts, decision reason/note, confirmation state,
allowed actions and save/readback/currentness remain authoritative. Scroll geometry
is transient presentation only. No credential, grant, RLS, API or domain changes.

No migration or database rollback applies. Rollback is a frontend/presentation
revert of this change. Remaining review risk is browser diversity: validation uses
Chromium and equivalent reflow, not every browser or physical device.

Supabase Staging writes = ZERO. Retool writes = ZERO. OPS v1 writes = ZERO.
Hosted business writes = ZERO. Local fixture saves change browser memory only.
