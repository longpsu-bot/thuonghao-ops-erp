# OPS v1 School Fulfilment Closeout Implementation Plan

> **Execution rule:** Apply each task test-first, record focused RED/GREEN evidence,
> and stop at one Draft PR. Do not merge or deploy.

**Goal:** Close the minimum School fulfilment path from direct Ingredient Need
through immutable School PXK while preserving exact history and explicit external
commitments.

**Architecture:** Extend existing typed Pantry, Need Generation, Confirmed Need,
school-catering allocation, and shared PO primitives. Add one bounded School PXK
aggregate. Persist facts and immutable release evidence; derive currentness,
staleness, replacement, and cancellation-required state.

**Baseline:** `origin/main` `606009b6d9afa590a202974394194dd26d44926a`

**Branch:** `feat/ops-v1-school-fulfilment-closeout-01`

## Task 0: Repair truthful baseline regressions

**Files:**

- Modify `src/modules/admin/DishRecipeAdminWorkbench.test.tsx`
- Modify `src/modules/admin/RecipeAdjustmentWorkbench.test.tsx`
- Modify `scripts/verify-local-rmvp04-need-generation.mjs`
- Record diagnosis in
  `docs/implementation-tasks/TASK-OPS-V1-SCHOOL-FULFILMENT-CLOSEOUT-01.md`

1. Retain the already-recorded failing focused runs.
2. Make the Dish Recipe fixture use the actual runtime service date rather than an
   expired hard-coded date; keep the selected-detail assertion.
3. Make the Recipe Adjustment stale-response test select a date guaranteed to differ
   from its runtime default; keep the obsolete-result assertion.
4. Move the RMVP-04 Pantry fixture to the exact service date chosen for generation;
   keep the mixed atomic-evidence assertion unchanged.
5. Run the two focused Vitest files, excluding nested `.worktrees/**` from local test
   discovery.
6. Run RMVP-04 against a disposable local database when available; otherwise preserve
   the exact verifier assertion and obtain final proof in GitHub Full Integration.

## Task 1: Persist direct-Need School/date mode

**Files:**

- Create migration
  `supabase/migrations/20260907090000_direct_need_school_date_mode.sql`
- Create/modify focused Pantry and Need Generation pgTAP suites under
  `supabase/tests/`
- Modify Pantry model/API/workbench/tests under
  `src/modules/atlas/planning-inputs/pantry/`
- Update generated database types if this repository owns them

1. Add failing pgTAP cases for per-School/date `ADDITIVE | COMPLETE`, immutable
   snapshot copying, legacy-null-as-additive, contradictory/missing mode rejection,
   and RLS/grant denial.
2. Add private mode and snapshot-mode relations with restrictive typed keys and
   forced RLS.
3. Extend the existing Pantry save/preview/read contracts. New positive-line saves
   require one mode per represented School/date; preview writes zero rows.
4. Add the smallest mode selector to the common Pantry workbench; do not create a
   second wholesale UI.
5. Run focused Pantry pgTAP, API, domain, and workbench tests.

## Task 2: Compose direct-complete Need Generation

**Files:**

- Extend the same bounded migration
  `supabase/migrations/20260907090000_direct_need_school_date_mode.sql`
- Create/modify focused Need Generation pgTAP suites
- Modify connected Need Generation model/API/workbench tests only as required
- Update Need Generation API documentation

1. Add failing database cases for mixed additive evidence, direct-complete with no
   Menu/Attendance, same School using different modes on different dates, mode-bound
   fingerprints, and no fabricated Recipe provenance.
2. Make input references nullable only under the exact `COMPLETE` predicate and
   enforce that condition in constraints/commands.
3. Amend the existing public generation command/read path: `COMPLETE` suppresses
   Recipe contributions for that School/date; `ADDITIVE` retains current composition.
4. Preserve `RECIPE_DERIVED | PANTRY_DIRECT` lineage and exact source quantities.
5. Run focused pgTAP and `local:rmvp04:verify`. Do not start Task 3 until green.

## Task 3: Permit append-only Confirmed Need correction

**Files:**

- Create migration
  `supabase/migrations/20260907110000_school_need_downstream_correction.sql`
- Modify focused Confirmed Need and school-catering planning-correction pgTAP suites
- Modify connected Confirmed Need API/model UI only if the derived blocker shape
  changes

1. Add failing cases showing a successor correction is allowed after released
   School-catering PO and PXK evidence and that all old evidence is immutable.
2. Narrow School-catering downstream guards in successor/reopen/invalidation paths;
   retain supplier-direct wholesale behavior.
3. Derive allocation stale/current from the exact current Confirmed Need
   contribution set/fingerprint. Do not create a new authoritative allocation until
   explicit Save.
4. Run focused correction, allocation, immutability, and security pgTAP suites.

## Task 4: Add complete replacement supplier POs

**Files:**

- Create migration
  `supabase/migrations/20260907120000_school_catering_po_replacement.sql`
- Modify `supabase/tests/school_catering_purchase_orders.sql` or add one focused
  replacement suite
- Modify Procurement API/model/workbench/tests under
  `src/modules/atlas/procurement/`

1. Add failing cases for quantity correction, unchanged supplier total with changed
   School membership, exact affected suppliers, full replacement content, old-active
   while draft, atomic supersession on release, idempotency, concurrency, and
   removed-supplier cancellation-required.
2. Add direct root lineage `replaces_purchase_order_id` and indexes allowing one
   current released commitment plus one replacement draft while preventing forks.
3. Derive exact supplier/date commitment fingerprints from all School delivery and
   source-lineage facts.
4. Amend draft generation to create complete separate replacement roots only for
   positive current supplier allocations.
5. Amend explicit release to allocate a new number and atomically supersede the old
   root after currentness revalidation.
6. Expose `CANCELLATION_REQUIRED` when a former supplier becomes zero. Leave the old
   PO active, create no zero-line PO, and keep overall Procurement not current.
7. Run focused PO/allocation/security tests. Do not start Task 5 until green.

## Task 5: Add School PXK release

**Files:**

- Create migration
  `supabase/migrations/20260907130000_school_dispatch_release.sql`
- Create `supabase/tests/school_dispatch_release.sql`
- Modify `supabase/tests/atlas_current_platform_security_catalog.sql`
- Add PXK model/API/workbench tests and implementation under
  `src/modules/atlas/dispatch/` or a bounded `school-dispatch` child
- Modify application navigation/router files
- Reuse existing XLSX download support

1. Add failing pgTAP cases for read-only preview, current allocation requirement,
   complete released PO coverage, removed-supplier blocker, catering and direct-
   complete release, immutable lineage, idempotency, replacement, and no stock/trip
   dependency.
2. Add private release header, line, and exact typed lineage relations with forced
   RLS and immutable guards.
3. Add bounded preview/read and release APIs with actor resolution, capabilities,
   deterministic locks, expected fingerprint, official numbering, receipts, events,
   audits, and safe errors.
4. Add `Kho → Phiếu xuất kho` with date/range, School search/filter, readiness,
   preview, explicit release, history, and export.
5. Add component/API/model tests, including unknown-outcome reload behavior and
   immutable export snapshots.
6. Run focused backend and frontend suites.

Focused database acceptance count: 36 pgTAP assertions.
Update the whole-platform catalog by exact table, RLS, policy, capability, function,
owner, authenticated-execute, trigger, and positive-grant identity. Do not replace
exact allowlists or hashes with permissive checks.

## Task 6: Amend authoritative documentation

**Files:**

- Add one narrow decision amendment under `docs/decisions/`
- Update `docs/decisions/decision-register.md`
- Update `docs/business-rules/business-rule-register.md`
- Update relevant Planning, Procurement, Dispatch, system-map, API registry, Pantry,
  Need Generation, Confirmed Need, and school-procurement documents only
- Complete the implementation-task validation record

Record School recipient authority, School/date mode, legacy additive interpretation,
downstream correction, complete PO replacement, removed-supplier safety, and PXK
without stock. Do not rewrite old accepted decisions as though they never existed.

## Task 7: Verify and open one Draft PR

1. Read and follow the verification-before-completion skill.
2. Run touched-file formatting, focused adjacent suites, typecheck/build as warranted,
   and `git diff --check`.
3. Self-review exact migration/API/security boundaries; use the requested code-review
   workflow without a subagent.
4. Commit bounded changes, push the branch, and open one Draft PR titled
   `feat(atlas): close direct need correction and school dispatch release`.
5. Let GitHub Actions own the full routine frontend and integration matrix. Inspect
   exact failing jobs and fix only causal regressions.
6. Report Frontend CI, Full Integration, Smoke, Qodana, and Cloudflare status for the
   exact final head. Do not merge or deploy.
