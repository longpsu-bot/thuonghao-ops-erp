# Atlas desktop review fixes

> Execute inline in three bounded commits, with focused checks and independent
> rendered/source review before the PR. Full frontend certification belongs to CI.

## Approved scope

Owner instruction, 26 October 2026: fix PXK loading/error counts and Change Order
footer overlap first, then the remaining findings in small batches, excluding F4
and mobile work. Base: latest `origin/main`, `c9641522`; PO PR #438 is separate.

The PXK truth-of-read correction applies at every width. Layout/style changes are
desktop-only (`lg` and above). F4 Supplier field widths, mobile-only F5 filters and
F7 quantity type remain deferred. Preserve existing narrow geometry/type/copy
for F2/F3/F6/F8. Use existing Atlas tokens and feedback layers. No API, lifecycle,
quantity, permission, provider, dependency, schema, migration or hosted change.

## Batch 1 — counts and usable form

Files under `src/vnext/atlas/`: `dispatch/SchoolPxkWorkbench.tsx`, its existing
test, `recipes/ChangeOrderEditor.tsx`, `recipes/ChangeOrderWorkbench.tsx`.

- [x] Add failing PXK regressions for pending/failed reads, retained previous rows
      and successful empty/read recovery.
- [x] Show loading/unknown instead of counting unconfirmed rows. Loaded empty
      scopes still show real zero counts; action/export guards stay unchanged.
- [x] Separate the desktop form's scrolling body from its action footer. Keep
      narrow layout and every input/submit handler.
- [x] Run focused PXK tests. Browser-check reason focus/hit testing at 1366×768
      and the normal/loading/error summaries.

## Batch 2 — desktop facts and entry guidance

Files: `recipes/ChangeOrderDetail.tsx`, `planning/PlanningPantryStage.tsx`.

- [x] F3: 14px body/label roles for desktop decision values/state; keep 13px
      supporting labels/audit metadata and existing narrow roles.
- [x] F8: visible desktop School chooser label and prerequisite instruction,
      with actual Add/Save conditions unchanged.
- [x] Check desktop typography/entry behavior and narrow preservation.

## Batch 3 — desktop read errors

Files: `planning/PlanningSourcesWorkbench.tsx`,
`recipes/DishRecipeWorkbench.tsx`, `reconciliation/SchoolFulfilmentFeedback.tsx`.

- [x] F6: existing desktop danger anatomy with icon/edge, safe message and retry.
      Preserve notice/lock behavior, live regions, IDs, callbacks and narrow UI.
- [x] Run focused affected checks, TypeScript, changed-file formatting, UI
      boundary and whitespace checks.
- [x] Review 1366/1440/1920px captures and narrow preservation; obtain independent
      rendered/source review, update UI inventory/evidence, push and open a PR.

## Evidence and results

Record results and remaining risks as each batch completes. Restrict local test
discovery to the intended `src` module to avoid historical `.worktrees` copies.
No full local suite rerun is planned. A frontend revert restores prior UI; no
data or migration rollback is needed. No merge/deployment is included.

Batch 1: expected RED was four observable count failures with the known-empty
case already passing. After the fix, both focused PXK suites pass, 70/70 tests.
The desktop reason-field top/bottom hit tests pass at 1366×768, 1440×900 and
1920×1080, including focus and typed text. Normal/loading/error PXK summaries
render correctly. The before/after 360px Change Order capture is pixel-identical;
no narrow layout change is introduced. Formatting and whitespace checks pass.
The field-grid indentation changes only because its existing contents now share
one desktop scrolling container with target blockers.

Batch 2: desktop decision facts compute to 14px at 1366/1440/1920px and remain
13px at 360px. The Pantry label/instruction is visible on desktop; Add is disabled
before School selection and enabled after the existing keyboard selection. The
narrow Pantry before/after capture is pixel-identical. Four focused existing
Pantry source/School/prerequisite tests pass. No overflow is measured.

Batch 3: all five read-error views (Menu, Attendance, Pantry, Recipes and
Reconciliation) have the existing 3px danger edge and visible icon at
1366/1440/1920px with no document overflow. Their 360px error captures remain
pixel-identical to the baseline. Exact 390/768px preservation is not claimed.
TypeScript, the vNext boundary scan, changed-file formatting and whitespace pass.
The pending-read test fixture needed an explicit `Promise<never>` return type;
this changes no runtime behavior or assertion.

Affected-suite evidence: the initial two-worker run has 88 passing cases and six
existing interaction tests exceeding their unchanged five-second budgets. A
focused serial run of exactly those six passes in 14.34s total test time; no
timeout, assertion, test configuration or business code is changed to obtain it.
The 70 PXK and four Pantry checks above remain separate focused evidence.
Normal GitHub Actions owns the fresh complete frontend certificate.

Independent source/render review finds no actionable defect or scope/security
violation. It confirms preserved release/export/preview/recovery guards and
unchanged narrow styles, with only final evidence/commit/CI gates outstanding.
The [portable evidence](../../ui/evidence/atlas-desktop-review-fixes-20261026)
contains the before/after desktop captures and measured preservation checks.
The raw form diff includes field-grid indentation; `git diff -w` isolates the
small container and footer changes. F4/F5/F7 remain deferred, as requested.
