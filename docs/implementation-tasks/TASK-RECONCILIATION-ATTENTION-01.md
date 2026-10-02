# TASK-RECONCILIATION-ATTENTION-01

Date: 2026-10-02. Bounded UI/read-model projection correction for audit **AUI-02 (P1 LOCAL)**. Product acceptance remains with the owner; the PR must stay Draft and must not be merged by this task.

## Baseline and preserved evidence

- Authorized checkout: `E:/Project/OPS ERP/thuonghao-ops-erp`.
- Starting `origin/main`, HEAD and merge-base: `7842cf92fd1f083eda5e0780c7b2420907acc6de`.
- Branch: `fix/reconciliation-attention-01`, created directly from exact origin/main.
- Only the authorized audit report and artifact directory were initially untracked. The AUI-02 finding was read before stashing.
- Audit preserved in `stash@{0}`, commit `3e48e6485dc747c53f230c6be0e8117bfe203316`, message `On audit/atlas-cross-module-ui-finish-01: audit: preserve atlas-cross-module-ui-finish-01`. Do not drop or overwrite this stash.
- Implementation started clean after preservation. `ops:workspace` verifies repository identity; its historical D: path warning is superseded by the owner's explicit E: checkout authorization.

## Scope and authority

The reconciliation API explicitly says comparison and operational currentness are independent: `OK` does not overrule procurement or PXK blockers. No conflicting accepted semantics were found. This change follows **FACTS EXPLICIT → STATE DERIVED → SUPPORTING OBJECTS GENERATED**: backend `comparison_status`, `pxk_state`, `blockers` and `warnings` remain authoritative; only presentation attention is derived.

Allowed changes are the Reconciliation hook, workbench, table, shared presentation predicate, regression tests, local review fixtures and this task's documentation/evidence. The detail panel, bridge/model contracts, reconciliation arithmetic, Dispatch lifecycle, database, RLS, RPCs, other modules and dependencies are unchanged.

## Projection correction

Previously, both the default filter and summary defined attention as `row.comparison_status !== "OK"`, hiding an OK row even when operationally blocked.

The shared `needsAttention(row)` predicate is true when any of these facts holds:

```typescript
row.comparison_status !== "OK" ||
  row.blockers.length > 0 ||
  row.pxk_state === "REPLACEMENT_REQUIRED" ||
  row.pxk_state === "BLOCKED";
```

The default Cần xử lý filter and summary use this same predicate. Nonblocking warnings alone do not enter the queue. Khớp still counts `comparison_status === "OK"`; an OK operational exception contributes to both counts. Scope counts retain their existing meaning across local search/status filters. Helper copy explains the independent dimensions.

Tất cả sorts attention first using a stable sort, retaining input order within each group. Explicit comparison filters still compare only `comparison_status` and retain input order. Existing comparison exceptions retain their relative order. No ranking model or persisted status is added.

The existing Đối chiếu cell retains Khớp and adds the existing shared Dispatch label immediately below it: Đang bị chặn or Cần phiếu thay thế. A row with blockers and another PXK state uses the presentation explanation Cần xử lý vận hành. Text conveys the reason independently of color. No extra column is added. Detail continues to show comparison, PXK state and human blocker/warning copy separately.

## Regression evidence

TDD: the new tests were added before production edits. After correcting the warning parameterization in the test harness, the unchanged implementation produced **6 expected failures / 20 passes**: five independent blocked/replacement/blocker combinations and the overlapping count/order case. The fix then passed **53 tests across both Reconciliation test files**.

| Acceptance case                                      | Proof                                                                                                                                                            |
| ---------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| OK + BLOCKED + PROCUREMENT_NOT_CURRENT               | Visible by default and under explicit Khớp; Khớp and Đang bị chặn both exposed in-row.                                                                           |
| OK + REPLACEMENT_REQUIRED + PXK_REPLACEMENT_REQUIRED | Visible by default and under explicit Khớp; Khớp and Cần phiếu thay thế both exposed.                                                                            |
| State-only attention                                 | BLOCKED and REPLACEMENT_REQUIRED still enter attention with empty blockers.                                                                                      |
| Blocker-only attention                               | CURRENT + nonempty blockers enters attention with Cần xử lý vận hành.                                                                                            |
| Clean OK                                             | Hidden by default, visible under Tất cả.                                                                                                                         |
| MISMATCH                                             | Visible by default, existing comparison labels and exact quantities preserved.                                                                                   |
| Warning-only OK                                      | Hidden by default; warning remains in existing detail presentation under Tất cả without raw codes.                                                               |
| Summary and sorting                                  | One clean OK, one blocked OK, one replacement OK, one mismatch gives attention 3 and Khớp 3; attention precedes clean OK under Tất cả, stable within each group. |
| Selection/filter/focus                               | Excluding a selected row closes detail; active filter/search focus remains. Enter opens/focuses detail; close returns focus to the originating action.           |
| Local filters                                        | Search/status changes leave fixture read count at one; no new RPC or command.                                                                                    |

## Browser evidence

[Browser results](../testing/artifacts/reconciliation-attention-01/browser-results.json) record ten production-component fixture runs: five cases at each of **1280×800** and **390×844**, Chromium 151.0.7922.34, vi-VN, reduced motion. Cases cover clean OK + mismatch, blocked OK, replacement OK, Tất cả with mixed attention, and warning-only OK. There are 36 full-page captures: default/all state, reason where applicable, detail, and reachable row action after horizontal panning.

- [Desktop blocked OK](../testing/artifacts/reconciliation-attention-01/blocked-ok-1280.png)
- [Mobile blocked reason](../testing/artifacts/reconciliation-attention-01/blocked-ok-390-reason.png)
- [Mobile replacement reason](../testing/artifacts/reconciliation-attention-01/replacement-ok-390-reason.png)
- [Desktop all rows](../testing/artifacts/reconciliation-attention-01/all-1280.png)
- [Mobile detail](../testing/artifacts/reconciliation-attention-01/blocked-ok-390-detail.png)

Every run asserts zero page-wide horizontal overflow, no overflowing cell text, keyboard selection/detail focus, close focus return, one fixture read, zero page errors and zero external requests. Blocked/replacement runs also verify explicit Khớp and filter exclusion focus. Images were visually inspected for the affected row labels, readable wrapping and usable detail.

The existing 1020px table continues to use local horizontal scrolling at narrow widths. Captures include comparison and action positions after panning. This task does not fix separate AUI-05/AUI-06 findings or claim physical-device/native screen-reader certification. Labels are ordinary accessible text in semantic table cells; automated role/text and keyboard checks support the accessibility result.

Reproduce with `pnpm exec vite --host 127.0.0.1 --port 3011 --strictPort`, then `python -X utf8 docs/testing/artifacts/reconciliation-attention-01/capture.py` from the repository root. The evidence renderer imports the real provider, shell and production workbench with local fixtures only; no connected client is instantiated.

## Validation and review

- Focused: `pnpm exec vitest run src/vnext/atlas/reconciliation --reporter=dot` — 2 files, 53 tests passed.
- `pnpm ui:vnext:check` — passed.
- `pnpm typecheck` — passed.
- Targeted Prettier, `git diff --check`, `pnpm ops:workspace` — passed before commit. Workspace check reports only task-owned changes and the acknowledged historical path warning.
- Browser geometry/visual checks — all ten runs passed.
- Manual bounded diff/security review: shared attention rule covers all four terms; explicit comparison filters, warning semantics, quantities, authoritative read data and detail/focus handlers are preserved. No backend mutation path was added. User requested one agent and no subagents; no delegated review was performed.
- GitHub `Frontend CI / Format, typecheck, test, build` remains the external routine validation gate. CI/preview URLs and final results are reported after the Draft PR is opened. Product/architecture approval remains outstanding; no merge is authorized.

## Security, migration and rollback

No schema/migration, arithmetic, API, authorization, RLS, secret, dependency or backend lifecycle change. All filtering is local presentation over the already authorized read response. Rollback is a frontend revert only; no operational documents or immutable evidence are touched.

Supabase Staging writes = ZERO. Retool writes = ZERO. OPS v1 writes = ZERO. Hosted business writes = ZERO.
