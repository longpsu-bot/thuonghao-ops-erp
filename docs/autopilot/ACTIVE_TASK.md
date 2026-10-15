# Atlas Autopilot — Active Task

Task: ATLAS-OPERATOR-UNIT-LABELS-A2-01
Status: AUTHORITY RECORDED — implementation paused while PR #385 CI expectations are corrected; separate Draft PR only.
Navigator: Terra/read-only role
Implementer: Sol 6.1
Starting main: d102b2f1b083005d6553867fa5ccdf8c988a0316
Atlas Staging: rnzxmxiiqgtdevzregff — migration 109; no hosted writes or deployment authorized
OPS v1 / Retool / Production: no writes or commitments

## Authority and deferred work — 15 October 2026

The Product Owner's `ATLAS_OPERATOR_FIXES_2026-10-15.md` brief authorizes bounded existing-flow operator corrections. This task implements A2 human Unit labels and the authoritative Draft School projection identified during A3 review. The brief overrides routine integration authority: deliver a Draft PR only; no merge, manual deployment or hosted database write. PR #385 remains frozen at `6db5e86a78e7068df28aa9f0235f299891e88cd2`, independently reviewed without actionable findings; Root monitors its remaining CI separately. Its A1/A3/A4 changes are not copied into this branch.

The [Warehouse receiving packet](../architecture/warehouse-receiving-minimum-design.md) remains READY FOR PRODUCT REVIEW with four UNDECIDED choice groups. No Warehouse implementation is approved. B/C/D operator work is outside this task. Historical 108/109 acceptance and checksums remain unchanged; the closed read gate is not rerun.

## Approved contract boundary

See the [dated Procurement amendment](../api/school-catering-procurement.md#operator-unit-labels-and-draft-school-projection--15-october-2026).

- Current Confirmed Need, Allocation, Generated Review and Draft PO displays prefer a valid human Unit name over a valid human legacy code. UUIDs, technical adoption codes, quantities and scale remain unchanged.
- Add one nullable `unit_name_snapshot` line-revision column in one forward local migration, without backfill. Future ordinary and replacement PO release captures the name under existing Unit locks. Snapshot immutability includes historical nulls.
- Official released/superseded PO display uses only frozen name or valid human frozen legacy code (for example `kg`), never current Master Data. Missing historical human evidence remains readable with a controlled warning and fails the existing official incomplete-evidence export gate. No new release prohibition or export state is introduced.
- Draft School breakdown uses the existing canonical positive-overlap helper for the displayed revision's supplier split, including stale Drafts. It never follows a current successor. Official School breakdown remains snapshot-only.
- The [Shopping List Unit display precedent](../implementation-tasks/TASK-ATLAS-SHOPPING-LIST-UNIT-DISPLAY-01.md) remains unchanged: its code-first resolver is shared by visible export/reference, ambiguity validation and import. A2's name-first operator/PO display must not alter that contract or its helper.
- Preserve task capabilities, exact relational scope, RLS, runtime ownership, ACLs, replay, numbering, currentness, lineage and one-authorized-Actor ordinary operations. No new public API, principal, capability, grant or policy is authorized; report any actual permission gap rather than broadening access.

## Allowed implementation and test reach

One new Supabase CLI-generated migration after 109 may add the nullable column and amend existing Allocation/Generated Review/PO read projections, release snapshot capture and immutable snapshot guard/trigger columns. Relevant existing pgTAP tests and exact catalog expectations may change with precise identity verification, without weakening checks.

TypeScript changes are limited to the existing Confirmed Need, Allocation, Generated Review and PO models/API mappings, active and legacy display callers, review fixtures/simulated capture, generated-review export and PO PDF/XLSX producers, plus a small tested operator Unit-label helper if needed. Preserve ExcelJS as production authority, existing Shopping List resolver/import files and contract, controlled codes/IDs and hidden lineage. No dependency, runtime configuration, unrelated UI redesign or new test framework.

## Test-first sequence and acceptance

1. Record this baton and the dated API amendment in an authority-only commit before code. Then write failing focused label tests: `Cái` alongside its unchanged technical code/UUID, human legacy `kg`, and controlled missing-label warning; preserve the Shopping List's existing code-first regressions.
2. Add rollback-only local database assertions for current reads, ordinary/replacement capture, current rename versus frozen history, exact replay, immutable historical null/backfill denial, incomplete official export denial and unchanged scoped access. Prove stale Draft School breakdown follows its exact split and positive overlaps, while official snapshots remain frozen. Observe RED before applying the migration, then GREEN.
3. Reach all active and legacy callers, including Confirmed Need supporting detail/messages, Allocation split panels, Generated Review and exports, PO screens and shared PDF/XLSX document model. Keep IDs/codes/quantity/currentness unchanged in behavioral assertions.
4. Validate native export layout with actual final production-generated `Cái`, `Miếng` and `Kilogram` on a short-School fixture. Do not abbreviate, shrink fonts or assume all names fit; report any real presentation gap before expanding scope. Native QA is local only, and prior A4 evidence is historical rather than A2 proof. The unchanged-source native layout probe found `Kilogram` wraps and clips at the existing 52.5 pt Unit column. Approved presentation reach is to include Unit-label height in the existing PO XLSX row-height maximum using the existing conservative `wrappedRowHeight` helper (5.25 physical factor), retaining font, columns, total width, canonical text and School measurement algorithm; verify the summary Unit column too.
5. Run focused tests, typecheck, affected formatting and exact-range whitespace checks; preserve RED/GREEN logs. Push a Draft PR and fixed SHA for Terra audit and GitHub CI. Full integration may be dispatched manually on the fixed branch while keeping Draft; no merge/deploy/hosted verification follows automatically.

No actual staff assignments, business commitments, hosted fixtures, historical corrections/backfill, OPS v1/Retool writes, Production, Warehouse or unrelated module changes are authorized.
