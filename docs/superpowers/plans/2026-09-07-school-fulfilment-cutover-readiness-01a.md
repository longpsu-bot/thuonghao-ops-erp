# School Fulfilment Cutover Readiness 01A Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. The Product Owner requires inline single-agent execution; do not use subagents. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver repository-only, read-only School PO ↔ PXK reconciliation, its connected Atlas workbench, Staging Identity 1.2.0, and a deterministic read-only post-rehearsal verifier without mutating hosted systems.

**Architecture:** PostgreSQL derives reconciliation at School + service date + captured delivery location from current Confirmed Need/allocation, exact School-attributed released-PO coverage, and the current released PXK. Comparison is performed only at Ingredient + Unit detail grain; summaries group quantities by Unit and never add heterogeneous Units. React consumes the shaped read contract, while repository tooling validates the future Staging rehearsal entirely through authenticated reads.

**Tech Stack:** PostgreSQL/Supabase migrations, pgTAP, React 19, TypeScript, Mantine 9, Vitest, Node.js verifier scripts, pnpm.

**Spec:** `docs/superpowers/specs/2026-09-07-ops-v1-school-fulfilment-cutover-readiness-01a-design.md`

## Global Constraints

- Start from approved `origin/main` `7251dc2764b5a91530af250a1cb2b4ce868fc61f` plus approved design head `bb2579a7d9dc8c6d391bafe8fdb3b667830f32b3`.
- Work only on `feat/ops-v1-school-fulfilment-cutover-readiness-01a` in the isolated worktree.
- Use one agent only; no subagents or parallel implementation.
- Follow RED → GREEN → REFACTOR for every behavior change.
- Perform no hosted Atlas Staging mutation, live OPS mutation, Retool mutation, package installation, deployment, or rehearsal-data write.
- Add no reconciliation relation, persisted status, acknowledgement, resolution, approval, override, lifecycle, or write API.
- Reuse `dispatch.school_release.read`; add no reconciliation capability.
- Preserve released PO/PXK history and existing Procurement/PXK blocker semantics.
- Never aggregate quantities across different Units. Preserve exact PostgreSQL numerics as strings at the browser boundary.
- Do not introduce Warehouse, stock, inventory, supplier cancellation, DispatchPlan/Trip/Stop, or generic provenance/currentness infrastructure.
- Run focused tests while developing; run broad certification once after focused checks are green.

## File Structure

- `supabase/migrations/` — the exact `school_fulfilment_reconciliation.sql` migration path returned by `pnpm exec supabase migration new school_fulfilment_reconciliation`; it owns the private derived scope helper plus the one public read API. Do not hand-invent a migration version.
- `supabase/tests/school_fulfilment_reconciliation.sql` — R01–R16 pgTAP authority and security coverage.
- `supabase/tests/atlas_current_platform_security_catalog.sql` — exact API signature/owner/grant catalog update.
- `scripts/certify-supabase-full-integration.mjs` and `scripts/atlas-staging-contract.test.mjs` — register the pgTAP suite exactly once and update deterministic command counts.
- `src/modules/atlas/dispatch/schoolFulfilmentReconciliationModel.ts` — read-contract types and Vietnamese labels.
- `src/modules/atlas/dispatch/schoolFulfilmentReconciliationApi.ts` and `.test.ts` — request builder, route binding, and response extraction.
- `src/modules/atlas/dispatch/SchoolFulfilmentReconciliationWorkbench.tsx` and `.test.tsx` — read-only filters, summary/detail presentation, per-Unit totals, stale-read protection, and operational-state separation.
- `src/modules/atlas/dispatch/reviewSchoolFulfilmentReconciliationApi.ts` — deterministic review-mode adapter with no external calls.
- `src/modules/atlas/connection/atlasRpc.ts` and `.test.ts` — register the new physical RPC.
- `src/modules/atlas/AtlasApp.tsx` and `.test.tsx` — add the second `Kho` route while retaining `Phiếu xuất kho`.
- `supabase/packages/atlas-staging-identity.v1.json`, `scripts/install-atlas-staging-package.mjs`, `scripts/atlas-staging-package.test.mjs`, and `scripts/certify-local-atlas-staging-packages.mjs` — Identity 1.2.0 exact 21-capability authority and local replay/conflict certification.
- `scripts/verify-atlas-staging-school-fulfilment.mjs` and `.test.mjs` — read-only Scenario A/B/C verifier and controlled fake-response tests.
- `package.json` — verifier command and touched-file format coverage.
- `docs/api/school-fulfilment-reconciliation.md` — exact read-contract documentation.
- `docs/runbooks/atlas-staging-deployment.md` and `docs/implementation-tasks/TASK-OPS-V1-SCHOOL-FULFILMENT-CUTOVER-READINESS-01A.md` — 01B sequence, validation evidence, rollback, and hosted-mutation boundary.

## Frontend Design Check

- **Color:** inherit `atlasTheme`; use existing green/blue/orange/red semantic badges. Do not add a new palette.
- **Type:** inherit the Atlas application typography. Exact numeric strings use normal tabular table alignment, not decorative type.
- **Layout:** left-aligned operational workbench with a compact filter card, a full-width summary table, and a selected-row detail card below.

```text
Kho / Đối chiếu PO / Phiếu xuất kho
┌ date start ┬ date end ┬ School scope ┬ search ┬ refresh ┐
└────────────┴──────────┴──────────────┴────────┴─────────┘
┌ Ngày ┬ Trường/điểm giao ┬ PO ┬ PXK ┬ SL theo đơn vị ┬ Đối chiếu ┬ Vận hành ┐
│ ...  │ ...               │... │ ... │ kg ... / cái...│ MISMATCH  │ blocker...│
└──────┴───────────────────┴────┴─────┴────────────────┴───────────┴───────────┘
┌ selected detail: Nguyên liệu | Đơn vị | SL PO | SL PXK | Δ | Nguồn ┐
└──────────────────────────────────────────────────────────────────────┘
```

- **Principles:** quantity comparison and operational safety are adjacent but visibly separate; mixed Units are always separate lines; no action styling suggests a write is possible.
- **Self-review:** a KPI-card/dashboard treatment would be generic and would hide document grain, so the plan deliberately uses the existing Atlas table-first workbench. The only distinctive visual choice is the paired comparison/operation signal with compact per-Unit quantity lines.

---

### Task 1: Record the heterogeneous-Unit design correction

**Files:**

- Modify: `docs/superpowers/specs/2026-09-07-ops-v1-school-fulfilment-cutover-readiness-01a-design.md`

**Interfaces:**

- Consumes: approved design head `bb2579a7d9dc8c6d391bafe8fdb3b667830f32b3`.
- Produces: `quantity_totals_by_unit[]` authority and the mixed-unit false-equality regression.

- [x] **Step 1: Replace scalar PO/PXK/delta summary fields with `quantity_totals_by_unit[]`.**

- [x] **Step 2: State that `comparison_status` derives only from exact Ingredient + Unit details.**

- [x] **Step 3: Add database/frontend acceptance for `10 kg + 20 piece` versus `20 kg + 10 piece` deriving `MISMATCH`.**

- [x] **Step 4: Format, diff-check, and commit the correction.**

Commit: `9e059b1c74f74f13f4ccf90fbf1cc045c2c5fcf4` (`docs(atlas): correct reconciliation unit summaries`).

### Task 2: Build the read-only database reconciliation contract with pgTAP TDD

**Files:**

- Create: `supabase/tests/school_fulfilment_reconciliation.sql`
- Create: the exact timestamped file returned by `pnpm exec supabase migration new school_fulfilment_reconciliation`
- Reference: `supabase/migrations/20260907130000_school_dispatch_release.sql`
- Reference: `supabase/migrations/20260907120000_school_catering_po_replacement.sql`
- Reference: `supabase/migrations/20260903072648_purchase_review_confirm_release.sql`

**Interfaces:**

- Consumes: `atlas_core.purchase_review_confirmed_sources(date,date)`, `atlas_core.school_dispatch_release_preview(date,uuid,uuid)`, `atlas_core.school_dispatch_release_json(uuid)`, current Allocation Family/Contribution/Supplier Split rows, and current released PO/PXK rows.
- Produces: `atlas_core.school_fulfilment_reconciliation_scope(date,uuid,uuid) returns jsonb` for read-runtime use and `atlas_api.get_school_fulfilment_reconciliation_workbench(jsonb) returns jsonb` with contract `SCHOOL-FULFILMENT-RECONCILIATION.v1`.

- [ ] **Step 1: Start the reduced local Supabase stack and reset to the exact migration baseline.**

Run:

```powershell
pnpm exec supabase start --exclude edge-runtime,imgproxy,logflare,mailpit,postgres-meta,realtime,storage-api,studio,supavisor,vector
pnpm exec supabase db reset --local --no-seed
```

- [ ] **Step 2: Write the first RED pgTAP assertion for the missing public function.**

Begin the suite with a transaction, `select plan(1)`, and:

```sql
select has_function(
  'atlas_api',
  'get_school_fulfilment_reconciliation_workbench',
  array['jsonb'],
  'reconciliation read API exists'
);
```

Run:

```powershell
pnpm exec supabase test db supabase/tests/school_fulfilment_reconciliation.sql --local
```

Expected: one failing assertion because the function is absent.

- [ ] **Step 3: Create the migration with the pinned CLI and add the minimal secure function shells.**

Run:

```powershell
pnpm exec supabase migration new school_fulfilment_reconciliation
```

The public shell must be `STABLE SECURITY DEFINER SET search_path=''`, owned by `atlas_read_runtime`, revoked from `PUBLIC`, `anon`, and `service_role`, and granted only to `authenticated`. It must resolve the Actor and require `dispatch.school_release.read`.

- [ ] **Step 4: Run the one-assertion suite GREEN.**

- [ ] **Step 5: Add RED fixture/assertions R01–R08 and R15–R16 for exact quantities and all five statuses.**

The fixture uses two Schools, two locations, two Ingredients, two Units, and two suppliers. Literal expectations prove School contribution—not supplier total—authority; exact multi-supplier sum; `NO_PO`, `NO_PXK`, `INGREDIENT_CHANGED`, `MISMATCH`, `OK`; precision strings; the equal-naive-total mixed-unit mismatch; and two separate `quantity_totals_by_unit` entries.

- [ ] **Step 6: Implement the minimal detail derivation GREEN.**

Build PO details from current, projection-matching Allocation Family revisions and exact contribution/supplier range intersections that are bound to current non-stale `RELEASED_TO_SUPPLIER` PO line revisions. Build PXK details only from the current `RELEASED` School PXK. Full-join by `(ingredient_id, unit_id)`, compare exact numerics, and serialize each quantity/delta as text. Group summary quantities only by `unit_id`/`unit_code`.

- [ ] **Step 7: Add RED fixture/assertions R09–R14 for captured location, history, blockers, and authorization.**

Assert that changing `school.default_delivery_location_id` does not move the row; superseded PO/PXK values do not affect current quantities; `OK` coexists with `PROCUREMENT_NOT_CURRENT` and with `CANCELLATION_REQUIRED`; an out-of-scope Actor is denied; and `anon`/`service_role` cannot execute the API or read private relations.

- [ ] **Step 8: Implement current scope discovery, search, and operational-state reuse GREEN.**

Scope discovery unions current confirmed-source facts, current Allocation contribution lineage, still-active attributable released PO lineage, and current `RELEASED` PXK scopes. It excludes superseded-only history. The API validates the exact request shape, inclusive maximum 31-day range, UUID arrays, nullable search, School scope, and School/location/PO/PXK search terms. Operational blockers come from existing PXK preview/currentness semantics and remain separate from `comparison_status`.

- [ ] **Step 9: Run the focused suite, then existing PO/PXK regressions.**

```powershell
pnpm exec supabase test db supabase/tests/school_fulfilment_reconciliation.sql --local
pnpm exec supabase test db supabase/tests/school_dispatch_release.sql --local
pnpm exec supabase test db supabase/tests/school_catering_purchase_orders.sql --local
```

Expected: all three suites pass with no plan mismatch.

- [ ] **Step 10: Commit the database contract and focused suite.**

```powershell
git add supabase/migrations supabase/tests/school_fulfilment_reconciliation.sql
git commit -m "feat(atlas): derive school fulfilment reconciliation"
```

### Task 3: Update exact database security and Full Integration catalogs

**Files:**

- Modify: `supabase/tests/atlas_current_platform_security_catalog.sql`
- Modify: `scripts/certify-supabase-full-integration.mjs`
- Modify: `scripts/atlas-staging-contract.test.mjs`

**Interfaces:**

- Consumes: actual catalog facts after Task 2.
- Produces: exact API signature/owner/grant counts and one Full Integration command for `school_fulfilment_reconciliation.sql`.

- [ ] **Step 1: Add RED deterministic registry expectations for one new suite and one new API.**

Update the Vitest expectation from 88 to 89 Full Integration commands and assert `school_fulfilment_reconciliation.sql` occurs exactly once.

- [ ] **Step 2: Run the registry test and confirm the expected failure.**

```powershell
pnpm exec vitest run scripts/atlas-staging-contract.test.mjs
```

- [ ] **Step 3: Register the suite exactly once beside the existing School dispatch/PO suites.**

- [ ] **Step 4: Run the security catalog pgTAP suite RED and update only actual function facts.**

Add `get_school_fulfilment_reconciliation_workbench(request jsonb)` to ordered signatures, owner mapping `=atlas_read_runtime`, authenticated execution lists, and counts from 111/110 to 112/111. Do not change policy counts or private-relation grants.

- [ ] **Step 5: Run registry and catalog tests GREEN, then commit.**

```powershell
pnpm exec vitest run scripts/atlas-staging-contract.test.mjs
pnpm exec supabase test db supabase/tests/atlas_current_platform_security_catalog.sql --local
git add supabase/tests/atlas_current_platform_security_catalog.sql scripts/certify-supabase-full-integration.mjs scripts/atlas-staging-contract.test.mjs
git commit -m "test(atlas): certify reconciliation security catalog"
```

### Task 4: Add the typed frontend API/model with TDD

**Files:**

- Create: `src/modules/atlas/dispatch/schoolFulfilmentReconciliationModel.ts`
- Create: `src/modules/atlas/dispatch/schoolFulfilmentReconciliationApi.ts`
- Create: `src/modules/atlas/dispatch/schoolFulfilmentReconciliationApi.test.ts`
- Modify: `src/modules/atlas/connection/atlasRpc.ts`
- Modify: `src/modules/atlas/connection/atlasRpc.test.ts`

**Interfaces:**

- Produces: `SchoolFulfilmentComparisonStatus`, `SchoolFulfilmentQuantityTotalByUnit`, `SchoolFulfilmentReconciliationDetail`, `SchoolFulfilmentReconciliationRow`, `SchoolFulfilmentReconciliationData`, `schoolFulfilmentReconciliationReadRequest`, `schoolFulfilmentReconciliationFromResult`, and `createSchoolFulfilmentReconciliationApi`.
- RPC route: `atlas_api.get_school_fulfilment_reconciliation_workbench` → `get_school_fulfilment_reconciliation_workbench`.

- [ ] **Step 1: Write RED tests for exact request filters and the one reviewed read route.**

Use literal expected request:

```ts
{
  contract_version: "SCHOOL-FULFILMENT-RECONCILIATION.v1",
  requested_by_auth_subject: "subject-1",
  correlation_id: "correlation-1",
  payload: {
    date_start: "2046-09-17",
    date_end: "2046-09-19",
    school_ids: ["school-1"],
    search: "PO-20460917"
  }
}
```

- [ ] **Step 2: Run the API/RPC tests RED.**

- [ ] **Step 3: Implement the minimal types, labels, request builder, response parser, and RPC mapping.**

Quantities remain strings; no parser coerces them to `number`.

- [ ] **Step 4: Run the API/RPC tests GREEN and commit.**

### Task 5: Add the read-only reconciliation workbench and navigation with TDD

**Files:**

- Create: `src/modules/atlas/dispatch/SchoolFulfilmentReconciliationWorkbench.tsx`
- Create: `src/modules/atlas/dispatch/SchoolFulfilmentReconciliationWorkbench.test.tsx`
- Create: `src/modules/atlas/dispatch/reviewSchoolFulfilmentReconciliationApi.ts`
- Modify: `src/modules/atlas/AtlasApp.tsx`
- Modify: `src/modules/atlas/AtlasApp.test.tsx`

**Interfaces:**

- Consumes: Task 4 API/types and existing `SchoolScopeSelector`, `WorkbenchHeader`, `AtlasAuthState`, Mantine components, and Atlas theme.
- Produces: `Kho → Đối chiếu PO / Phiếu xuất kho` route and a read-only table/detail workbench.

- [ ] **Step 1: Write RED component tests for exact strings, five statuses, separated Unit totals, distinct blockers, and no write actions.**

Use a fixture with `1000000000000.123456 kg` and a separate `20.000000 piece`; assert both literal strings render and no combined `1000000000020.123456` text exists. Query for absence of `Resolve|Confirm|Accept|Override|Acknowledge|Giải quyết|Xác nhận|Chấp nhận|Ghi đè` buttons.

- [ ] **Step 2: Write a RED stale-response test.**

Resolve a newer filter request first, then resolve the older promise; assert only the newer School remains rendered.

- [ ] **Step 3: Implement the minimal read-only workbench GREEN.**

Use a monotonic `readIntent` ref like the PXK workbench. Render compact per-Unit lines from `quantity_totals_by_unit`, a separate comparison badge, and a separate operational-state cell/alert. Do not calculate totals or comparison in React.

- [ ] **Step 4: Write RED navigation tests preserving both Kho entries.**

Assert the existing `Phiếu xuất kho` button still opens its workbench and the new button opens heading `Đối chiếu PO / Phiếu xuất kho`.

- [ ] **Step 5: Wire connected and deterministic review APIs GREEN.**

Add `school-fulfilment-reconciliation` to `MasterDataPageId`, navigation, page rendering, connected API creation, and review adapter creation. Do not alter other routes or shell styling.

- [ ] **Step 6: Run focused frontend tests and commit.**

```powershell
pnpm exec vitest run src/modules/atlas/dispatch/schoolFulfilmentReconciliationApi.test.ts src/modules/atlas/connection/atlasRpc.test.ts src/modules/atlas/dispatch/SchoolFulfilmentReconciliationWorkbench.test.tsx src/modules/atlas/AtlasApp.test.tsx
git add src/modules/atlas
git commit -m "feat(atlas): add fulfilment reconciliation workbench"
```

### Task 6: Upgrade Atlas Staging Identity to 1.2.0 with exact package certification

**Files:**

- Modify: `supabase/packages/atlas-staging-identity.v1.json`
- Modify: `scripts/install-atlas-staging-package.mjs`
- Modify: `scripts/atlas-staging-package.test.mjs`
- Modify: `scripts/certify-local-atlas-staging-packages.mjs`

**Interfaces:**

- Produces: package version `1.2.0`, metadata marker `atlas-staging-identity@1.2.0`, and exactly 21 capabilities ending with deterministic IDs `...0029`/`...0030` for `dispatch.school_release.read`/`.release`.

- [ ] **Step 1: Update tests first to expect exact 1.2.0/21 authority and only two additions versus a literal 1.1.0 capability list.**

Also assert unchanged Auth subject, Actor, Role, membership, GLOBAL scope, deterministic IDs, unrelated-capability rejection, first-install/replay behavior, and fail-closed natural-key/content conflict.

- [ ] **Step 2: Run package tests RED.**

```powershell
pnpm exec vitest run scripts/atlas-staging-package.test.mjs
```

- [ ] **Step 3: Update manifest and installer authority GREEN.**

Change `PACKAGE_VERSIONS.identity`, `IDENTITY_CAPABILITY_CODES`, managed metadata, and the two manifest bindings. Do not change Foundation.

- [ ] **Step 4: Add a rolled-back local Identity conflict probe to package certification.**

The probe deliberately alters one managed binding inside a subtransaction, executes the exact package SQL, requires the existing mismatch diagnostic, and proves the subtransaction restores the installed state. It performs no hosted call.

- [ ] **Step 5: Run unit package tests GREEN and the local package certification once.**

```powershell
pnpm exec vitest run scripts/atlas-staging-package.test.mjs
$env:ATLAS_STAGING_TEST_EMAIL='atlas-staging-package@local.test'
$env:ATLAS_STAGING_TEST_PASSWORD='AtlasLocalPackageOnly!2046'
pnpm local:staging-packages:certify
```

- [ ] **Step 6: Commit the exact package upgrade.**

### Task 7: Add the repository-owned read-only post-rehearsal verifier with TDD

**Files:**

- Create: `scripts/verify-atlas-staging-school-fulfilment.mjs`
- Create: `scripts/verify-atlas-staging-school-fulfilment.test.mjs`
- Modify: `package.json`

**Interfaces:**

- Consumes: `validateAtlasStagingProtectedValues`, redaction helpers, `readAtlasStagingPackage('foundation')`, authenticated Supabase browser client, and existing shaped `atlas_api` reads.
- Produces: `planAtlasStagingSchoolFulfilmentVerification`, pure `assertSchoolFulfilmentScenarios`, `verifyAtlasStagingSchoolFulfilment`, and `pnpm atlas:staging:school-fulfilment:verify`.

- [ ] **Step 1: Write RED plan/guard tests.**

Prove dry-run creates no client and performs no fetch/RPC; wrong Atlas project, live OPS project, and missing protected values fail; diagnostics redact URL/key/email/password/token values.

- [ ] **Step 2: Write RED pure-response tests for missing/invalid Scenario A/B/C.**

Use complete literal fake responses for the three fixed dates and managed synthetic School. Mutations of those fixtures must fail for: missing scenario, wrong contribution family, fabricated Menu/Attendance binding in COMPLETE, stale PO or PXK lineage, wrong predecessor/successor chain, reconciliation non-OK, and operational blocker.

- [ ] **Step 3: Implement the pure verifier GREEN.**

Scenario A requires both `RECIPE_DERIVED` and `PANTRY_DIRECT`, exact contribution/Need/allocation/PO/PXK continuity, `OK`, and no blockers. Scenario B requires `PANTRY_DIRECT` COMPLETE authority with absent Menu/Attendance/Recipe bindings. Scenario C requires retained old Need/PO/PXK evidence, explicit replacement predecessor lineage, old PO/PXK superseded only by released successors, current successor PXK, `OK`, and no blockers.

- [ ] **Step 4: Implement the authenticated read orchestration GREEN.**

Use only `.schema('atlas_api').rpc(...)` read calls and `auth.signInWithPassword`/local sign-out. The plan must report `networkWrites: false`; source must contain no command RPC names, Management SQL calls, insert/update/delete/upsert, or automatic retry.

- [ ] **Step 5: Run verifier tests and a dry-run only.**

```powershell
pnpm exec vitest run scripts/verify-atlas-staging-school-fulfilment.test.mjs
pnpm atlas:staging:school-fulfilment:verify -- --dry-run
```

Do not run the non-dry verifier in 01A.

- [ ] **Step 6: Commit the verifier.**

### Task 8: Document the API, 01B runbook, and implementation evidence

**Files:**

- Create: `docs/api/school-fulfilment-reconciliation.md`
- Modify: `docs/api/api-contracts.md`
- Modify: `docs/runbooks/atlas-staging-deployment.md`
- Create: `docs/implementation-tasks/TASK-OPS-V1-SCHOOL-FULFILMENT-CUTOVER-READINESS-01A.md`
- Modify: `package.json`

**Interfaces:**

- Produces: durable contract, exact 01B sequence, rollback statement, validation record, and formatter coverage for every new source/doc file.

- [ ] **Step 1: Document the exact API request/response, authorization, Unit grouping, status order, blockers, and read-only posture.**

- [ ] **Step 2: Freeze the 01B sequence exactly as approved.**

```text
exact merged main
→ guarded Atlas Staging migration deployment
→ platform-only verification
→ Identity 1.2.0 reconciliation
→ Foundation replay
→ normal read-only atlas:staging:verify
→ controlled persistent connected Staging frontend
→ operator authors Scenarios A/B/C
→ atlas:staging:school-fulfilment:verify
→ Product/Architecture cutover decision
```

- [ ] **Step 3: Record forward-only rollback, security review, changed files, and explicit no-hosted-mutation evidence.**

- [ ] **Step 4: Add new files to the repository’s explicit Prettier command and commit documentation.**

### Task 9: Focused completion checks and one broad local certification pass

**Files:** all changed files.

- [ ] **Step 1: Run touched-file formatting, TypeScript, and whitespace checks.**

```powershell
pnpm format
pnpm typecheck
git diff --check
```

- [ ] **Step 2: Run all focused frontend/tooling tests once more.**

```powershell
pnpm exec vitest run src/modules/atlas/dispatch/schoolFulfilmentReconciliationApi.test.ts src/modules/atlas/dispatch/SchoolFulfilmentReconciliationWorkbench.test.tsx src/modules/atlas/connection/atlasRpc.test.ts src/modules/atlas/AtlasApp.test.tsx scripts/atlas-staging-package.test.mjs scripts/verify-atlas-staging-school-fulfilment.test.mjs scripts/atlas-staging-contract.test.mjs
```

- [ ] **Step 3: Run the repository broad gates once.**

```powershell
pnpm certify:frontend
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/atlas_current_platform_security_catalog.sql --local
pnpm exec supabase test db supabase/tests/rmvp_02a_connected_recipes_bom.sql supabase/tests/issue_213_recipe_save_activates_new_dish.sql supabase/tests/ui_quality_03a_recipe_workflow.sql --local
pnpm exec supabase test db supabase/tests/school_catering_handoff_allocation.sql --local
pnpm exec supabase test db supabase/tests/school_catering_planning_correction.sql --local
pnpm exec supabase test db supabase/tests/purchase_handoff_clock_skew.sql --local
node scripts/test-local-purchase-review.mjs purchase_review_confirm_release.sql
pnpm exec supabase test db supabase/tests/pantry_02_connected_pantry_source.sql --local
pnpm exec supabase test db supabase/tests/rmvp_03b_connected_planning_input_readiness.sql --local
pnpm exec supabase test db supabase/tests/planning_contract_01_atomic_planning_boundaries.sql --local
pnpm exec supabase test db supabase/tests/planning_contract_02b_selective_confirmation_continuity.sql --local
pnpm exec supabase db query --local --file supabase/local/pa_06b_synthetic_identity.sql
pnpm exec supabase db query --local --file supabase/local/rmvp_05_browser_fixture.sql
pnpm exec supabase test db supabase/tests/rmvp_06_connected_confirmed_need_validation.sql --local
node scripts/test-local-purchase-review.mjs rmvp_07_connected_confirmed_need_approval_release.sql --existing-fixture
node scripts/test-local-purchase-review.mjs d037_confirmed_need_save_release_boundary.sql --existing-fixture
pnpm exec supabase db reset --local --no-seed
pnpm certify:supabase:full-integration
```

Capture exact pass/fail counts. Do not repeatedly rerun successful suites.

- [ ] **Step 4: Review the full diff against the corrected design and exclusions.**

Confirm there is no hosted target invocation, no reconciliation write, no new table/capability beyond the two Identity bindings, no supplier cancellation, and no Warehouse/stock code.

- [ ] **Step 5: Commit any final documentation-only evidence update and verify a clean worktree.**

### Task 10: Push one branch and open one Draft PR

**Files:** Git/GitHub metadata only.

- [ ] **Step 1: Fetch and verify exact branch ancestry and clean status.**

- [ ] **Step 2: Push `feat/ops-v1-school-fulfilment-cutover-readiness-01a`.**

- [ ] **Step 3: Open one Draft PR titled `feat(atlas): prepare school fulfilment cutover readiness`.**

The body must summarize derived multi-unit-safe reconciliation, the read-only workbench, Identity 1.2.0/21 capabilities, the read-only verifier, 01B activation boundary, exact validation evidence, and explicit confirmation that Atlas Staging/live OPS/Retool were unchanged.

- [ ] **Step 4: Wait for and report Frontend CI, Supabase Smoke, Supabase Full Integration, Qodana, and Cloudflare preview if triggered.**

- [ ] **Step 5: Stop at the Draft PR review gate. Do not merge.**
