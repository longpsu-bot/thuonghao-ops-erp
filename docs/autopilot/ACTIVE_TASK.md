# Atlas Autopilot — Active Task

Task: ATLAS-OPERATOR-BULK-ALLOCATION-B-01
Status: AUTHORITY PHASE — bounded design recorded for Root/Terra review; hold before SQL/runtime implementation.
Navigator: Terra/read-only role
Implementer: Sol 6.1
Starting main: d102b2f1b083005d6553867fa5ccdf8c988a0316
Atlas Staging: rnzxmxiiqgtdevzregff — accepted migration 109; no hosted write or deployment authorized
OPS v1 / Retool / Production: no writes or commitments

## Authority and deferred work — 15 October 2026

The Product Owner's `ATLAS_OPERATOR_FIXES_2026-10-15.md` brief and subsequent instruction to proceed authorize optional bulk supplier defaults/rebalance within the existing Allocation flow. Root's bounded phase-one instruction authorizes this baton and the [dated Procurement amendment](../api/school-catering-procurement.md#optional-bulk-defaults-and-rebalance--15-october-2026) only. Commit those documents before code, report the proposed interface and locking boundaries, then hold for review. The brief overrides routine Autopilot integration: deliver a separate Draft PR; no merge, manual deployment or live database write.

PR #385 (safe presentation, head `b57dd270da20ca2f348ee6b296253de203967e02`) and PR #386 (A2 Unit labels/Draft School projection, head `775989fc9c7bae2eb10db733b5244e846f31d896`) remain frozen separate Drafts. This branch starts from accepted main, not either PR. Do not copy A2 schema, helpers or projections. Historical 108/109 acceptance, migration packages and checksums remain historical. The [Warehouse packet](../architecture/warehouse-receiving-minimum-design.md) remains READY FOR PRODUCT REVIEW with four UNDECIDED groups and no implementation authority. Operator C/D remain deferred.

Root's read-only environment review reconfirmed Atlas Staging at `20261014120320`, authenticated 8-second budget, and Retool bulk behavior as loaded School-days sent to a v1 backend RPC. Retool detail browser arithmetic is behavioral reference only; no v1 authority is transplanted.

## Bounded design

- Extend the existing active confirmed-allocation read with opt-in backend-derived bulk preview; default reads and the normal derived-default journey remain unchanged. Bulk apply is optional, not a prerequisite to Preparation or a second confirmation authority.
- Filter by selected dates/Schools using ANY contributing School, then deduplicate whole location/date/Ingredient/Unit families. Show every affected School/contribution and full exact family quantity; never save a clipped School slice. Local search/state filtering is not hidden bulk scope.
- Distinguish safe missing defaults, explicitly reviewed stale prior-ratio rebalance, preserved existing/manual decisions, and blocked/zero/no-eligible cases. Preserve retained Supplier notes. Browser selection performs no authoritative arithmetic.
- One new batch command uses the existing Procurement write capability and exact existing location-family predicate. Both current source kinds route to their existing persistence primitives. Preparation's GLOBAL/release requirement and the old Handoff-only confirmation/safe-skip RPC stay unchanged.
- Bind each selected candidate to its source kind/evidence, batch/version where applicable, family version/fingerprint and exact server proposal/context digest. Recompute under canonical locks; any changed authority/proposal fails the entire selected set. Explicitly disclosed preview exclusions are not applied or reported as saved.
- Preserve both canonical lock orders across the whole set: all relevant Confirmed Need batches/lines first, Supplier evidence, Handoff sources, then family roots. Reuse an outer receipt/exception subtransaction, distinct child command identities, audit and exact replay before child generation. Collect safe per-family conflicts and roll back all selected writes on any failure, including errors returned as JSON by a private writer. Never loop independent public Save requests.
- PO impact exposes only documents authorized by the existing whole-PO predicate, with the same authorized-documents-only coverage statement for empty and nonempty lists. No hidden-only flags, inaccessible existence/count/status or assurance of no commitments. Allocation authority remains independent. No PO preparation, regeneration, release or historical rewrite follows bulk apply.
- Existing toolbar/controller plus a bounded review surface provides explicit Apply-and-Save, dirty/context/date/focus protection, exact-request recovery, UNKNOWN lock and one authoritative Allocation readback with accurate saved-family count. One authorized Actor can perform the ordinary task; no second-person rule or new role/capability/scope kind.

## Allowed reach after design review

Phase one changes only this baton and `docs/api/school-catering-procurement.md`.

After explicit Root coding release, expected reach is:

- One Supabase CLI-created forward migration from the accepted main109 baseline: existing confirmed-allocation read extension, one new batch RPC, and only necessary private proposal/orchestration helpers. Identify it by generated version/file, not an assumed ordinal 110. No new derived-state table/status, existing-function retirement, source rewrite, historical correction, broad table grant or policy change. Exact hardened function ownership/EXECUTE changes must be reviewed against the catalog.
- Existing Procurement `purchaseReviewApi.ts`, `schoolCateringProcurementModel.ts`, review simulator and directly affected API tests; active `useProcurementWorkbench.ts`, `ProcurementWorkbench.tsx`, `procurementAllocationPresentation.ts`, review fixtures/stories and focused tests. A small colocated bulk-review component/test is permitted if it keeps the existing workbench readable. Follow existing UI v3/A+, Chakra recipes and Vietnamese copy. Preserve legacy callers and single-family detail behavior.
- Existing `supabase/tests/purchase_review_confirm_release.sql`, `school_catering_handoff_allocation.sql`, `procurement_supplier_line_note.sql`, `school_catering_purchase_orders.sql`, exact `atlas_current_platform_security_catalog.sql`, and the reusable purchase-preparation scale fixture where relevant. A bounded bulk-specific SQL test may isolate the matrix rather than duplicate fixtures. Existing local integration registration may add that exact test if necessary; no workflow/security-gate relaxation.
- One bounded validation/rollback record and sanitized evidence under the existing `docs/testing/` artifact pattern. No new runner, framework or dependency.

Report before any additional API, lock-order/privilege reach or source-authority change beyond the dated contract. No A1/A2/A3/A4 changes, Planning correction, Warehouse, staff assignment, real commitment, OPS v1/Retool write or hosted fixture is in scope.

## Test-first sequence and release gates

1. Review the authority-only commit. Hold runtime edits until Root releases coding.
2. Establish a fresh owned-disposable local main109 database. The existing owned local volume has ledger109 plus unledgered A2 DDL and is not a valid B baseline. Preserve all pre-existing volumes and frozen A2 evidence; never reset an unproven-disposable target.
3. Observe RED for public authenticated mixed-source atomic apply and preview. Prove both writers; exact default/unique priority/ties/ineligible/no eligible/zero; prior-ratio deterministic residual, scale and retained notes; whole-family School dedup; existing allowed/denied location-family scope; whole-PO nondisclosure; source/version/priority/eligibility races; exact/conflicting replay and all-or-nothing rollback with zero partial allocation facts/events.
4. Prove UI/API selection-only payloads, exact request retry, UNKNOWN/readback failure lock, successful authoritative counts, dirty/date/context/focus guards and no write on preview/open. Exclude ignored `.superpowers` reference copies from local focused test collection without changing tracked discovery.
5. Measure read/preview and one batch command on a local 50-School shared-family/mixed-source workload, with actual family/contribution counts and timings recorded under the unchanged authenticated 8-second budget. No timeout increase or claim of hosted scale certification. Verify exact catalog changes and unchanged unrelated PO/replay/currentness/Preparation tests.
6. Run focused tests/typecheck, affected format and exact-range whitespace checks; obtain fixed-SHA Terra audit and exact-head Frontend/local Full Integration CI while keeping Draft. No merge, deployment or hosted acceptance follows automatically.

## Design review questions

The dated amendment proposes opt-in `include_bulk_preview`, a stateless canonical proposal digest and `apply_supplier_allocation_batch`. Verify the proposed combined Confirmed Need batch/lines → Supplier evidence → Handoff source → family ordering against every existing writer. Prefer internal existing public Save commands; any private resolved seam must consume complete canonical backend source evidence including overlapping batches and fresh revalidation after waits. Existing ownership/ACLs must support the private read/proposal reuse; stop on a real permission gap rather than broadening table access. These are technical review points, not new Product-policy choices.
