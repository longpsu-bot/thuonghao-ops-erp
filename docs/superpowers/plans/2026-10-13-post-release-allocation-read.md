# Post-release Supplier Allocation read plan

**Goal:** Preserve `CONFIRMED-SUPPLIER-ALLOCATION.v1` while bringing the released
236-family read within the existing authenticated 8-second budget.

**Authority:** Product's 13 October 2026 task, starting at
`d616396cea0c5b076d6ac9f16366165913d39754`, and
[Procurement contract](../../api/school-catering-procurement.md).

**Architecture:** Resolve the current Confirmed Need source set once in the
workbench's local variable. Reuse that same set for its main loop and historical
Handoff exclusion. Retain canonical evaluation, source precedence, scope checks,
Handoff projection, and preparation status without changes.

**Scope:** One forward migration (106), one rolled-back SQL scale regression,
the existing integration test list, and contract/performance evidence. No
frontend, write-path, Supplier semantics, timeout, index, persisted state, or
migration 103–105 edits. Staging diagnostics use read-only transactions with
rollback. No hosted preparation, deployment, merge, Retool, or OPS v1 writes.

- [x] Add `supplier_allocation_released_read.sql` using the existing 236-family
      scale fixture, authenticated local Save/preparation setup, and three reads.
      Assert success, 236 exact rows, Handoff lineage, saved splits/quantities,
      preparation version/readiness, unchanged business facts/receipts, and at most
      three source reconstructions per read. Run it against migration 105 first.
      Expected: the per-row source-call bound fails or the 8-second read times out.
- [x] Create migration 106 with `supabase migration new`. Patch only
      `atlas_api.get_confirmed_supplier_allocation_workbench(jsonb)` to aggregate
      `purchase_review_confirmed_sources` once and iterate/test membership using
      `jsonb_array_elements`. Guard each replacement and compare the function
      catalog before/after excluding `prosrc`. Expected: unchanged security posture.
- [x] Apply locally and rerun the scale regression. Run existing Procurement,
      Planning currentness/zero-demand, and security suites. Expected: all pass with
      repeated reads comfortably below 8 seconds. Stop optimizing at that point.
- [ ] Record hosted baseline and local measurements; add the regression to the
      existing Full Integration list. Run Full Integration once locally, review the
      bounded diff, commit, push, and open one Draft PR. GitHub owns Frontend CI.
      Expected: Draft PR with passing required checks; no deployment or merge.

**Rollback:** A forward correction can restore the prior function body without
changing business data, function privileges, or migration history.

**Review focus:** Exact filter/source precedence equivalence, authenticated scope,
null/empty sources, mixed pre/post-release ranges, and preservation of the
untouched preparation/write paths. Local synthetic timings are not hosted
acceptance; hosted confirmation waits for Product-approved deployment.

Review: one independent read-only review found no production defect; its Important
test-gap finding was addressed with exact identity-set and contribution checks.
The final focused run passes 13/13. Local Full Integration reached an unchanged
browser harness `.git` path failure in this managed worktree; use the existing
GitHub workflow dispatch for ordinary-checkout validation, without changing or
skipping that harness.
