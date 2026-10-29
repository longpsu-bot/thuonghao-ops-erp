# Task 3 report — Operational documents

## Status

PASS — the bounded Purchase Order, Phiếu xuất kho and reconciliation hierarchy
rollout is implemented without hook, controller, model, bridge, calculation,
export-array, API, SQL, provider, registry or backend changes.

## Files changed

- `src/vnext/atlas/procurement/ProcurementWorkbench.tsx`
- `src/vnext/atlas/procurement/ProcurementWorkbench.test.tsx`
- `src/vnext/atlas/procurement/ProcurementOrdersStage.tsx`
- `src/vnext/atlas/procurement/ProcurementOrdersStage.test.tsx`
- `src/vnext/atlas/procurement/ProcurementOrdersStage.exports.test.tsx`
- `src/vnext/atlas/procurement/ProcurementPublishAll.test.tsx`
- `src/vnext/atlas/dispatch/SchoolPxkWorkbench.tsx`
- `src/vnext/atlas/dispatch/SchoolPxkWorkbench.test.tsx`
- `src/vnext/atlas/reconciliation/SchoolFulfilmentWorkbench.tsx`
- `src/vnext/atlas/reconciliation/SchoolFulfilmentWorkbench.test.tsx`
- `.superpowers/sdd/2026-10-29-atlas-workbench-hierarchy-rollout/task-3-report.md`

No shared primitive or design-system file changed.

## User-visible changes

- Purchase Orders retain the established desktop directory/detail rail. On
  narrow screens, loaded-scope release and export controls now live under one
  `Tiện ích đơn mua` disclosure while the visible-result count remains
  immediate. The loaded-period explanation remains adjacent to the commands
  and still states that local search does not limit their scope.
- Phiếu xuất kho now uses the mounted Atlas task context for its real date and
  School scope. Counts stay immediate; loaded-period export mode and commands
  use one narrow `Tiện ích phiếu xuất kho` disclosure and remain persistent on
  desktop.
- A selected PXK replaces the directory below the desktop breakpoint, providing
  one actual document plane. From 992px upward, the directory becomes a bounded
  280–340px rail beside the broad document. Official document, changed preview,
  history and replacement states remain distinct.
- Reconciliation now has an immediate compact search, filter disclosure,
  refresh control and scope summary on narrow screens. The disclosure moves
  focus into the first revealed filter and preserves the established compact
  keyboard order.
- A selected reconciliation record replaces the directory below the desktop
  breakpoint. From 992px upward, the bounded directory rail remains visible
  beside a broad evidence plane, giving PO/PXK references, immutable status and
  ingredient/Unit evidence priority.
- All three compact search slots set the existing Chakra `Field.Root` and
  `Input` to shrink within their grid track at 360px.

## Design-system reuse

The change reuses `AtlasTaskContext`, `AtlasWorkbar`, `AtlasWorkbarActions`,
`AtlasTableViewport`, `focusFirstCompactFilter`,
`preserveCompactFilterFocusOrder`, current Chakra field/input/table recipes,
semantic tokens and Atlas breakpoints. The two loaded-scope disclosures remain
local because their command groups and eligibility contracts differ. No
universal wrapper or new primitive was justified.

## Contract preservation

- Purchase Order release/export commands still receive the complete eligible
  loaded-period arrays and the selected export mode. Local search affects only
  the visible directory.
- PXK exports still receive the complete loaded released-document set and the
  existing date/entity grouping mode.
- School, location, date, Unit, note, immutable document facts, official versus
  preview/history distinction, dirty/exit behavior, UNKNOWN handling and
  backend permission/eligibility decisions remain owned by the existing hooks,
  controllers and backend contracts.
- Reconciliation remains read-only. No Save, release, approve or export command
  was invoked during browser validation.

## Targeted validation

- TDD red: five new disclosure/focus and compact-search containment assertions
  failed against the old structure because the disclosures and `minW=0` field
  contract did not exist.
- Focused green after implementation: 7 targeted assertions passed, 207 were
  skipped, across the directly affected/imported suites in one Vitest process
  with `--maxWorkers=1 --no-file-parallelism`.
- The bounded direct regression then passed 117 tests across the five unchanged
  successful suites. Eight reconciliation assertions exposed legacy assumptions
  that the narrow directory remained accessible after selection; no production
  contract failed.
- The exact reconciliation suite was updated to assert directory evidence before
  selection and visible document evidence after selection. Its bounded rerun
  passed 54/54 tests across two files, exit 0. Loaded-scope callback/array
  assertions were not weakened; their helpers explicitly open the new utility
  disclosure first.
- Prettier passed for all ten changed source/test files; `git diff --check`
  passed.
- Fresh headless Chromium captured default, selected and utility-open states for
  all three workbenches at 1440×900, 1024×900, 390×844 and 360×800: 36 captures,
  no page errors and no document-level horizontal overflow.
- At 360px every measured search input stayed within the viewport, every visible
  owner panel retained `scrollLeft === 0`, selected PXK/reconciliation showed the
  evidence plane instead of the directory, and each narrow disclosure focused a
  control inside its `aria-controls` region.
- Evidence directory:
  `C:/Users/HOME/.codex/visualizations/2026/10/29/atlas-rollout/documents`
  (`geometry.json` contains the deterministic measurements).

## Residual risks

- Physical-device touch/virtual-keyboard behavior and screen-reader speech were
  not certified; DOM labels, focus placement and responsive Chromium behavior
  were checked.
- Wide ingredient/evidence tables intentionally retain local horizontal
  scrolling on narrow screens; the document and owner panel do not drift.
- Full typecheck/build/routine CI were not repeated. Root integration and GitHub
  Actions own rollout-wide gates.

## Round 1 — compact context deduplication

Reviewer feedback identified that the narrow PXK and reconciliation workbars
repeated date and School scope already mounted in `AtlasTaskContext`. Their
collapsed summaries now show only the active status fact (`Tình trạng: …`). The
date range, School selection and all underlying scope values remain unchanged
and appear once in the task context.

- Focused compact-summary regression: 3 passed, 104 skipped across four
  affected/imported files in one Vitest process; exit 0.
- Only the affected PXK/reconciliation states were recaptured at 390×844 and
  360×800 (12 refreshed images). They retained zero page errors, zero document
  overflow, contained search bounds and focus inside each opened disclosure.
- `compact-geometry.json` records the refreshed measurements; the original
  36-state `geometry.json` remains available for the full-width matrix.
