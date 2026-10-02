# CONFIRMED-NEED-SHOPPING-LIST-ERROR-UX-01

Starting SHA: `d81b60ca63349794d28b0dcc5d34f5fd3e1ebfa1` (fetched current `origin/main`).
Branch: `fix/confirmed-need-shopping-list-error-ux-01`.

## Authority and bounded plan

Authority: OPS_SYSTEM_MAP v1.0 / [ARCH-002](../architecture/arch-002-atlas-system-map.md),
[model convergence](../decisions/decision-atlas-model-convergence.md),
[RMVP-05](../api/rmvp-05-connected-confirmed-need-review.md),
[AUD-003 Shopping List precision](TASK-AUD-003-shopping-list-precision.md), and
[#345 responsive Confirmed Need behavior](TASK-CONFIRMED-NEED-RESPONSIVE-EDITING-01.md).
FACTS EXPLICIT — STATE DERIVED — SUPPORTING OBJECTS GENERATED.

Recovered read-only from
`3e48e6485dc747c53f230c6be0e8117bfe203316^3:docs/implementation-tasks/AUDIT-ATLAS-CROSS-MODULE-UI-FINISH-01.md`:
**AUI-09 — unexpected Shopping List parser error leaks library English; P2 LOCAL**.
The stash is not applied, popped, dropped, rewritten or otherwise disturbed.

- [x] Verify clean authorized checkout and branch from current main; read authorities.
- [x] Reproduce corrupt XLSX and arbitrary callback text before production changes.
- [x] Explicitly mark known workbook validation errors safe for operator display.
- [x] Normalize unexpected parser/file/callback failures to stable Vietnamese copy.
- [x] Regress exact precision, local-only import, retry, released/export locks and #345.
- [x] Review production-component fixtures at 1440×900 and 390×844 in four import states.
- [x] Run focused tests, required checks and review the bounded diff.

Publication: commit and push this bounded task as a Draft PR only; do not merge.

Allowed production files: Shopping List parser, existing confirmed-need bridge and
ConfirmedNeedWorkbench error handler. Tests, bounded browser evidence and this
record support acceptance. No controller, workbook layout, arithmetic, backend,
API, migration, RLS, lifecycle, navigation, shell, responsive table or dependency change.

## Reproduction and RED evidence

Before correction the UI forwarded arbitrary `Error.message` to its Shopping List
alert. Parser/domain validation and ExcelJS exceptions both used ordinary Error.
Corrupt bytes `[80, 75, 3, 4, 0]` produced
`Corrupted zip: can't find end of central directory` instead of safe copy.
The UI callback regression displayed
`End of data reached (data length = 5). JSZip parser` verbatim. A non-Error
rejection used the old non-actionable fallback. These three regression assertions
failed before production edits. Known validation copy and released/export controls
were retained as controls. Initial control assertions incorrectly expected a clean
Save button; they were corrected to the existing clean-state absence without
changing production behavior or test timeouts.

## Implementation decision

Use a narrow, non-persisted Shopping List validation Error subclass and message
helper. Only explicitly marked workbook validation failures may supply operator
text. Any other failure receives:
“Không thể đọc Phiếu đi chợ. Hãy kiểm tra tệp .xlsx và thử lại.”
No string matching of third-party exceptions, generic framework or backend/state
model is required. Import updates local drafts only; explicit Save remains the
sole authoritative write. Business facts, calculations and decisions remain backend-owned.

The parser marks stale identity, duplicate line, quantity/baseline, missing note,
missing draft, invalid reason and incomplete workbook checks explicitly. Currentness,
duplicate and missing-draft copy references workbook rows or recovery instead of
internal line IDs. Error causes retain technical diagnostics for support without
exposing them in the alert. The UI applies the same safe-message helper even when
an import callback fails outside the parser. The existing approved bridge exposes
the helper and workbook functions; direct legacy module imports remain forbidden.

## Files changed

- `src/modules/atlas/planning-inputs/confirmed-needs/confirmedNeedShoppingList.ts`:
  narrow validation error, safe-message helper and parser/file error normalization.
- `src/vnext/atlas/bridges/confirmedNeed.ts`: existing business-only bridge exports.
- `src/vnext/atlas/planning-confirmed/ConfirmedNeedWorkbench.tsx`: safe import alert.
  The actual hidden file input shares the visible button's released/busy lock.
- `confirmedNeedShoppingList.test.ts` and `ConfirmedNeedWorkbench.test.tsx`:
  corrupt bytes/file-read failure, missing current draft, technical/non-Error callback,
  real XLSX validation copy, same-file retry, released/export controls and dirty gate.
- `scripts/confirmed_need_shopping_list_error_browser_test.py` and
  `docs/testing/artifacts/confirmed-need-shopping-list-error-ux-01/`: bounded
  production-component fixture harness, 12 screenshots and geometry evidence.
- This implementation record. No other production file changes.

## Verification

Initial required three-file GREEN: **83/83 PASS**. Final focused command:
`pnpm exec vitest run src/modules/atlas/planning-inputs/confirmed-needs src/vnext/atlas/planning-confirmed`
passed **217/217 tests in eight files**. This includes unchanged AUD-003 precision,
API/controller tests and #345 table/focus/dirty regressions. The existing legacy
test emits jsdom's non-failing `Window.confirm()` diagnostic; tests/timeouts are unchanged.

`pnpm ui:vnext:check`, `pnpm typecheck` (including repository Chakra typegen),
targeted Prettier, `git diff --check` and `pnpm ops:workspace` pass. The workspace
checker retains its historical D: path warning; the current E: checkout is
explicitly user-authorized and its real root/origin were verified. An initial
direct test import was corrected through the existing approved bridge; no checker
allowlist or validation rule was weakened. Full routine validation is GitHub-owned.

Independent GPT-5.6 Extra High review confirmed the narrow error boundary and
identified one acceptance gap: the released/busy visible trigger was disabled,
but the native file input remained enabled. Two focused RED assertions reproduced
that bypass. The input now uses the same disabled condition and its change handler
guards released/busy events after resetting the file selection. Tests prove direct
released input events invoke no callback, overlapping selections invoke only one
callback, and the input becomes available again after failure. This enforces the
existing lock; it adds no lifecycle or business state.
Re-review reports no remaining findings. The final eight-file focused run passes
217 tests and the final 12-capture browser rerun passes after this correction.

## Browser and visual evidence

Reuses the #345 local fixture/provider/shell approach, adding real Shopping List
export/import callbacks and test-only workbook-byte generation. Chromium
151.0.7922.34, Windows, vi-VN, reduced motion; **1440×900 and 390×844**, DPR 1.
See [geometry.json](../testing/artifacts/confirmed-need-shopping-list-error-ux-01/geometry.json).

Each size covers normal, corrupt error, specific stale error, successful dirty
import, reason focus and corrupt import after a successful dirty draft: **12 captures**.
Real corrupt and tampered XLSX files traverse the production File/ExcelJS/parser/UI
boundaries. Same-file retry succeeds in reaching the boundary twice; hidden input
value is reset. Error copy is visible and wraps naturally on mobile. Quantity and
reason focus remain intact; reason fits after local panning. Desktop identity
remains pinned, mobile identity unpinned and the vertical header sticky. No page-level
horizontal overflow, page errors or external requests occur. Save is available for
the valid imported draft, Continue is disabled, and the footer remains reachable
through ordinary vertical scrolling on mobile. A failed later import preserves
`12,5` and its note/reason; **fixture Save calls remain ZERO** throughout.

Visual review inspected desktop/mobile errors and mobile dirty authoring. No theme,
layout or responsive production adjustment was needed. This verifies local fixture
presentation and real XLSX behavior, not authenticated staging, physical-device
interaction or hosted data volume.

## Security, writes and rollback

Only curated application validation errors supply text. Unexpected exceptions are
normalized without exposing library messages, stacks, paths or documentation URLs.
Existing backend authorization, RLS and Save/readback authority remain unchanged.

Supabase writes = **ZERO**. Retool writes = **ZERO**. OPS v1 writes = **ZERO**.
Hosted business writes = **ZERO**. Migrations, RLS/RPC/API changes and dependencies
= **ZERO**. No deploy or merge is performed; the PR remains Draft for owner
Product/Architecture review.

Rollback is a code-only revert of this task commit. There is no schema/data rollback
and no persisted error/status model. Existing imported browser drafts remain local.
Residual limitations: trusted validation errors are an in-process application
boundary, not an external serialized error protocol; live authenticated staging
acceptance remains outside this task. Detailed technical causes are retained on
the Error object; this task introduces no new telemetry/reporting system.
