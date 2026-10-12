# Atlas preferred-Supplier defaults and School-first tables

Product-approved correction dated 2026-10-12. Starting main:
`063b40be86dd00a3a26f1a1a8cc0ef8b32964f83` (PRs #368 and #369).
Branch: `fix/atlas-preferred-supplier-default-school-first`.
Delivery status: repository validation complete; Draft PR for Product review,
with no merge or deployment.

The change removes ordinary per-row Supplier confirmation when current master
data already supplies a deterministic default, and makes School identity lead
both operating tables. It implements the approved amendment to
[PA06D-11](../decisions/decision-pa-06d-quantity-truth-and-write-fidelity.md),
[BR-049](../business-rules/business-rule-register.md), and the existing
[Procurement contract](../api/school-catering-procurement.md).

## Product semantics

- Complete current positive Confirmed Need with no persisted allocation and one
  unique ACTIVE/effective lowest non-null priority Supplier has a derived 100%
  default. The read keeps `splits` empty and `state = UNALLOCATED`; the UI presents
  the backend recommendation as the resolved normal case (`Đủ`, default-priority
  label, and `Thay đổi`).
- No eligible Supplier blocks. Missing effective priority and best-priority ties
  remain unresolved; Supplier name, UUID and row order never decide allocation.
- Exact persisted overrides, multi-Supplier splits and supplier notes take
  precedence. Existing stale/rebalance rules remain explicit.
- One-day preparation rechecks authoritative source and current Supplier facts,
  materializes missing defaults atomically through the existing writer, and
  continues through strict Planning release, Handoff promotion and PO drafting.
  It creates no separate operator confirmation action or per-row receipt.
- Priority changes before materialization follow current effective master data.
  Changes afterward do not silently replace accepted allocations or rewrite
  released Supplier commitments. Existing correction/replacement boundaries stay.
- Allocation reads retain 1–7 day context with independent dated defaults.
  Multi-day preparation remains unavailable. Standalone Planning release still
  writes no Procurement fact and retains its persisted-allocation prerequisite.

## Changed files and boundaries

Backend: one forward migration,
`supabase/migrations/20261012101517_atlas_preferred_supplier_default_preparation.sql`,
and the existing purchase-review/security-catalog SQL tests. It adds three private
coverage, materialization and lock helpers; it updates existing allocation
persistence, preparation status, confirmed allocation read and preparation RPC.
No table, enum, public API, capability, dependency or browser table grant is added.

Frontend: the Procurement table, detail and workbench; their tests and review
fixtures/stories; the new shared presentation helper
`src/vnext/atlas/procurement/procurementAllocationPresentation.ts`; Confirmed Need
table/tests/fixtures/stories; and the existing unresolved-exit integration test's
row-action selector. It reuses the Atlas provider, tokens and table contracts.
Supplier selection remains backend-owned. Exact quantity parsing/editing, Save,
reload, Shopping List, reason requirements and unknown-outcome rules are retained.

Documentation updates the existing Procurement/Planning API contracts, convergence
decision/authority map, PA06D-11, QRR-016 and decision/business-rule registers.
There is no parallel architecture or generic workflow.

## Acceptance evidence

| Requirement                                          | Evidence                                                                                                                                                                                       |
| ---------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Workbench read is write-free                         | `complete_positive_read_is_write_free` compares family, revision, receipt, Handoff and PO counts before/after repeated complete positive reads; persisted splits remain empty.                 |
| Unique default progresses to purchase preparation    | `derived_default_prepare` succeeds with exact authoritative quantities; default history carries the outer preparation command and is promoted through real Handoff to PO drafts.               |
| Current Supplier facts win over stale browser advice | `derived_priority_change` and `derived_inactive` begin from earlier advice, change priority/activity, then prove preparation selects the current safe Supplier.                                |
| Manual override wins                                 | `derived_manual_mixed` retains the exact explicit `72.000000 + 48.000000` split and materializes only the other missing family.                                                                |
| Tie/no priority/no eligibility stay unresolved       | `derived_tie`, `derived_no_priority` and `derived_no_eligible` reject preparation with zero partial allocation/Handoff/PO business writes.                                                     |
| Preparation is atomic                                | `derived_po_failure` reaches the final PO write, then proves rollback of materialized defaults, release, Handoff, drafts, events and child receipts.                                           |
| Released PO stays immutable after priority changes   | `released-priority-read` and `released-priority-reprepare` succeed; released roots, revisions/lines and exact grouped Supplier quantities compare byte-for-byte with their original snapshots. |
| Range contract remains                               | One-day reads expose preparation; seven-day reads preserve dated rows and return no preparation authority.                                                                                     |
| School-first tables                                  | Both tables begin with sticky sortable School/location, then an independent Ingredient cell; tests cover default School → Ingredient sorting and exact trimmed name deduplication.             |
| Ordinary 236-row case needs no per-row work          | 12/10 synthetic fixture renders 236 safe defaults, `Cần xử lý 0 · Đã đủ 236`, direct Supplier names, `Mặc định #1`, `Đủ` and `Thay đổi`; search and exception filters retain their behavior.   |
| Keyboard/focus retained                              | At 390px, focused Confirmed Need quantity starts at x=239, exactly beside the pinned School cell's right edge, and fits the visible viewport.                                                  |

## Validation

Focused backend checks pass: purchase review 187/187, platform security 29/29,
Handoff allocation 88/88, purchase orders 135/135, Planning correction 23/23,
Handoff clock skew 6/6, atomic Planning boundaries 258/258, zero-demand 72/72,
allocation convergence 417/417, and final closeout 17/17 plus its authenticated
browser Save/reopen and performance probes.

Formatting, typecheck, build, vNext boundary and diff whitespace checks pass.
`pnpm test --maxWorkers=2` passes all 214 files and 2,962 tests, including the
current Procurement/Confirmed Need, Save/reload, UNKNOWN and exit-lock suites.
`pnpm certify:supabase:full-integration` passes the complete ordered SQL catalog,
both local resets, authenticated browser Save/reopen proof, performance checks,
all local journey verifiers and final stack cleanup. Generation performance p95
is 2,919.908ms against the existing 4,000ms target. No tests or timeouts are
disabled or weakened.

Local test discovery initially included an ignored `.superpowers` baseline copy;
its code/test directories were temporarily preserved under `node_modules` for
repository validation and restored afterward, without changing their contents or
dependency junction. These local snapshots can affect future unfiltered test
discovery; they are not part of the tracked repository or CI. The initial high-parallelism
run exceeded unrelated test time budgets during concurrent validation. The final
full frontend command limits worker concurrency to two and retains all tests and
timeouts. Two deterministic exit-test selectors were updated for the approved
default action label; their UNKNOWN/retryable assertions remain unchanged.

Independent review found and resolved alternate eligible-Supplier search,
exact text deduplication, pinned-cell focus visibility and explicit owner-SET
membership regression coverage. No actionable product/architecture findings remain.

## Browser evidence

All six captures use the actual workbenches and explicitly labeled synthetic
12/10 fixtures through a temporary plain local Vite harness. The Procurement
fixture contains 236 rows; Confirmed Need contains six representative equal and
distinct School/destination identities. These are local acceptance evidence,
not new Staging observations. No hosted RPC was called.

- [Confirmed Need, 1440×900](../testing/artifacts/atlas-preferred-supplier-school-first/confirmed-need-1440x900.png)
- [Supplier Allocation, 1440×900](../testing/artifacts/atlas-preferred-supplier-school-first/procurement-1440x900.png)
- [Confirmed Need, 1366×768](../testing/artifacts/atlas-preferred-supplier-school-first/confirmed-need-1366x768.png)
- [Supplier Allocation, 1366×768](../testing/artifacts/atlas-preferred-supplier-school-first/procurement-1366x768.png)
- [Confirmed Need, 390×844](../testing/artifacts/atlas-preferred-supplier-school-first/confirmed-need-390x844.png)
- [Supplier Allocation, 390×844](../testing/artifacts/atlas-preferred-supplier-school-first/procurement-390x844.png)
- [Browser assertions and geometry](../testing/artifacts/atlas-preferred-supplier-school-first/browser-evidence.json)

Desktop rows remain about 52–53px and narrow rows about 57px. School identity stays
pinned during horizontal scrolling. Both surfaces have separate Ingredient cells,
zero page errors and zero hosted RPC calls. Storybook's existing focus
instrumentation raised `Illegal invocation` in the Confirmed Need story; the
plain Vite harness renders the same components/fixtures without that preview
instrumentation. No dependency or production behavior was changed to suppress it.

## Security, rollback and delivery

Existing owners, empty search paths, forced RLS, capability/scope checks,
fingerprints, exact equality, receipts, replay and retryable/unknown handling
remain authoritative. Private helper execution is limited to the required
runtime owners. The permanent `postgres → atlas_owner` SET membership is retained;
temporary runtime SET/CREATE memberships are removed. The security test now checks
the exact membership catalog row, independently of effective role ability.

Forward rollback restores the four prior function definitions before removing
the three private helpers. Accepted allocation/Handoff/PO facts must be retained;
rollback never deletes materialized history or changes released commitments.
Historical migrations were not edited.

Retool and OPS v1 are untouched. Atlas Staging is not deployed. Mantine retirement,
new tables/dependencies and unrelated module cleanup are outside this task.
Delivery is one Draft PR, unmerged, followed by Product review.
