# School-Catering Procurement V1 — Backend Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the school-catering Planning→Procurement handoff boundary, Allocation Family persistence, supplier recommendation/save/bulk-confirm commands, and the connected allocation read API without changing PA-05E wholesale behavior.

**Architecture:** Planning releases exact Confirmed Need into the existing Purchase Handoff structures through a new school-catering command. Procurement derives candidate Allocation Families from current released handoff lines, lazily persists a family root only when an operator confirms an allocation, and stores immutable accepted revisions with contribution lineage and supplier splits. Recommendations and rebalance suggestions are read-model output only; React or SQL clients never write them implicitly.

**Tech Stack:** PostgreSQL 17/Supabase migrations, PL/pgSQL `SECURITY DEFINER` RPCs, RLS, pgTAP, Atlas command receipts/events/audit conventions, pnpm 11.7.0, Supabase CLI 2.111.0.

**Spec:** `docs/superpowers/specs/2026-08-30-school-catering-procurement-v1-design.md`

## Recommended Codex settings

- Model: **GPT-5.6 Sol**
- Reasoning: **Medium**
- Agents: **1**
- Parallel agents: **Off**
- Subagents: **Off**
- If running through the Superpowers wrapper, use `executing-plans`; do not dispatch subagents for this OPS task.

## Global Constraints

- Start from a fresh fetch of `origin/main`; do not implement on the documentation branch.
- Create implementation branch `feat/sc-proc-01-backend-foundation` from the then-current `origin/main`.
- Read only this plan, the canonical spec, and the exact reference files named below before editing.
- OPS_SYSTEM_MAP v1.0 / ARCH-002 governs domain ownership.
- Supabase Staging is the Atlas authority; **do not mutate Live OPS or Retool**.
- Do not deploy to production.
- Preserve all PA-05D wholesale and PA-05E wholesale command behavior.
- Do not reuse PA-05D `release_purchase_handoff` for school catering.
- Do not use `fulfilment_allocation_*` as the school-catering Allocation Family model.
- No React Procurement workbench in this slice.
- No PO draft/release schema or commands in this slice.
- No Ingredient/Supplier code-numbering changes.
- No Warehouse, Dispatch, supplier acknowledgement, price, Finance, email/message, or generic workflow/numbering engine.
- TDD: add a failing focused test before each production behavior.
- Run focused local pgTAP during development; rely on GitHub Actions for the comprehensive Supabase certification.
- If implementation requires changing a locked business rule or adding another public API, stop and report the architecture drift instead of expanding scope.

---

### Task 1: Establish the school-catering Allocation Family schema and security boundary

**Files:**
- Create via `pnpm exec supabase migration new sc_proc_01_school_catering_allocation_family`; use the generated path `supabase/migrations/<timestamp>_sc_proc_01_school_catering_allocation_family.sql`
- Create: `supabase/tests/sc_proc_01_school_catering_allocation_family.sql`
- Reference only: `supabase/migrations/20260716023909_pa_05e_procurement_command_family.sql`
- Reference only: `supabase/tests/pa_05e_procurement_command_family.sql`
- Reference only: `supabase/tests/atlas_current_platform_security_catalog.sql`

**Interfaces:**
- Produces tables:
  - `atlas_procurement.purchase_allocation_families`
  - `atlas_procurement.purchase_allocation_family_revisions`
  - `atlas_procurement.purchase_allocation_family_contributions`
  - `atlas_procurement.purchase_allocation_supplier_splits`
- Consumed later by the SC-PROC-01 commands/read API and SC-PROC-03 PO lineage.

- [ ] **Step 1: Create the failing structure/security pgTAP assertions**

Add assertions that require the four tables, FKs, root version/current-revision pointer, exact family tuple uniqueness, one-current-revision uniqueness, supplier uniqueness per revision, positive quantities, valid split ratio bounds, no direct `authenticated` table access, RLS enabled, and Procurement runtime write ownership.

The core expectations should express this shape:

```sql
select has_table('atlas_procurement', 'purchase_allocation_families');
select has_table('atlas_procurement', 'purchase_allocation_family_revisions');
select has_table('atlas_procurement', 'purchase_allocation_family_contributions');
select has_table('atlas_procurement', 'purchase_allocation_supplier_splits');

select has_column('atlas_procurement', 'purchase_allocation_families', 'current_purchase_allocation_family_revision_id');
select col_type_is('atlas_procurement', 'purchase_allocation_families', 'version', 'bigint');

select throws_ok(
  $$
  insert into atlas_procurement.purchase_allocation_supplier_splits (
    purchase_allocation_family_revision_id,
    supplier_id,
    split_quantity,
    split_ratio,
    supplier_eligibility_id,
    supplier_eligibility_version
  ) values (
    '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000002',
    0,
    0,
    '00000000-0000-0000-0000-000000000003',
    1
  )
  $$,
  '23514'
);
```

Keep fixture IDs created inside the test transaction; do not depend on hosted IDs.

- [ ] **Step 2: Run the new test and confirm RED**

Run:

```bash
pnpm exec supabase start --exclude edge-runtime,imgproxy,logflare,mailpit,postgres-meta,realtime,storage-api,studio,supavisor,vector
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/sc_proc_01_school_catering_allocation_family.sql --local
```

Expected: FAIL because the four Allocation Family relations do not exist.

- [ ] **Step 3: Generate the migration file**

Run:

```bash
pnpm exec supabase migration new sc_proc_01_school_catering_allocation_family
```

Use the generated timestamp. Do not rename an existing migration or choose a timestamp older than current `main`.

- [ ] **Step 4: Implement only the approved persistence model**

Implement the root/revision/contribution/split tables and constraints from the spec. Use the existing `atlas_procurement_command_runtime` and existing read runtime where practical; do not create another runtime role unless a hard privilege conflict is demonstrated.

The migration must enforce the semantic structure equivalent to:

```sql
create table atlas_procurement.purchase_allocation_families (
  purchase_allocation_family_id uuid primary key default gen_random_uuid(),
  service_date date not null,
  delivery_location_id uuid not null references atlas_admin.delivery_locations(delivery_location_id) on delete restrict,
  ingredient_id uuid not null references atlas_admin.ingredients(ingredient_id) on delete restrict,
  unit_id uuid not null references atlas_admin.units(unit_id) on delete restrict,
  version bigint not null default 1 check (version > 0),
  current_purchase_allocation_family_revision_id uuid null,
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  unique (service_date, delivery_location_id, ingredient_id, unit_id)
);
```

Use a deferred FK or equivalent two-step current-pointer constraint so the root can safely point to a revision that belongs to the same root. For revisions, enforce one current revision per root. Contributions reference exact `purchase_handoff_line_revision_id`. Splits reference exact `supplier_eligibility_id` and store the eligibility version used at confirmation.

Do **not** add triggers for business workflow, generic status tables, queues, or automatic recommendation writes.

- [ ] **Step 5: Add least-privilege RLS/grants**

Follow PA-05E patterns:

```text
authenticated → execute approved atlas_api functions only
atlas_procurement_command_runtime → narrow read Planning/Admin + write new Procurement family tables
read runtime → read new family tables and required Planning/Admin lineage only
anon/service_role → no new atlas_api execute grant unless already governed by repository convention
```

Procurement runtime must not receive Planning write privileges.

- [ ] **Step 6: Run structure/security test GREEN**

Run:

```bash
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/sc_proc_01_school_catering_allocation_family.sql --local
pnpm exec supabase test db supabase/tests/pa_05e_procurement_command_family.sql --local
```

Expected: new test PASS; PA-05E PASS.

- [ ] **Step 7: Commit the schema foundation**

```bash
git add supabase/migrations/*_sc_proc_01_school_catering_allocation_family.sql supabase/tests/sc_proc_01_school_catering_allocation_family.sql
git commit -m "feat: add school catering allocation family schema"
```

---

### Task 2: Add the Planning-owned school-catering Purchase Handoff release command

**Files:**
- Modify: the SC-PROC-01 migration generated in Task 1
- Modify: `supabase/tests/sc_proc_01_school_catering_allocation_family.sql`
- Reference only: `supabase/migrations/20260805202517_rmvp_07_connected_confirmed_need_approval_release.sql`
- Reference only: `supabase/migrations/20260715163344_pa_05d_planning_command_family.sql`
- Reference only: `supabase/tests/rmvp_07_connected_confirmed_need_approval_release.sql`
- Reference only: `supabase/tests/pa_05d_planning_command_family.sql`

**Interfaces:**
- Produces: `atlas_api.release_school_catering_purchase_handoff(request jsonb) returns jsonb`
- Capability: `purchase_handoff.school_catering.release`
- Consumes: current school-catering Confirmed Need batch already in `RELEASED_FOR_PURCHASE_HANDOFF`
- Writes: existing Planning `purchase_handoff_*` and `purchase_demand_references` only
- Produces no Procurement row.

- [ ] **Step 1: Add failing pgTAP for the new Planning command**

Cover:

```text
missing/wrong capability → denied
wrong Confirmed Need state → no write
stale expected version → STALE_VERSION
valid released Confirmed Need → one Purchase Handoff root/current revision + exact lines/references
replay → same IDs
same command identity/different request → IDEMPOTENCY_CONFLICT
existing wholesale release_purchase_handoff behavior unchanged
no Procurement allocation/PO rows created
```

Use a request contract shaped as:

```json
{
  "contract_version": "SC-PROC-01.v1",
  "command_id": "uuid",
  "correlation_id": "uuid",
  "idempotency_key": "text",
  "expected_version": 4,
  "requested_by_auth_subject": "uuid",
  "requested_at": "2026-08-31T00:00:00Z",
  "reason_code": "SCHOOL_CATERING_PURCHASE_HANDOFF_RELEASED",
  "reason_note": null,
  "payload": {
    "confirmed_need_batch_id": "uuid"
  }
}
```

- [ ] **Step 2: Run the focused test and confirm RED**

```bash
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/sc_proc_01_school_catering_allocation_family.sql --local
```

Expected: FAIL because `atlas_api.release_school_catering_purchase_handoff(jsonb)` is absent.

- [ ] **Step 3: Implement the command using existing Planning runtime conventions**

The function must:

```text
validate exact envelope/payload
→ resolve authenticated subject + actor + capability/scope
→ begin idempotent receipt
→ lock/re-read Confirmed Need batch/current release/approval/current line revisions
→ prove source_kind is school-catering NEED_GENERATION and state RELEASED_FOR_PURCHASE_HANDOFF
→ create/reuse one stable Purchase Handoff root for that Confirmed Need batch
→ create current handoff revision and exact line revisions/references
→ preserve quantity/unit/service_date/delivery_location/source lineage
→ event + audit + receipt
→ safe response
```

When a later valid Confirmed Need release for the same batch exists, create a successor handoff revision under the same root; never create a second root. Do not add a new Confirmed Need reopen command.

- [ ] **Step 4: Run Planning boundary regression GREEN**

```bash
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/sc_proc_01_school_catering_allocation_family.sql --local
pnpm exec supabase test db supabase/tests/rmvp_07_connected_confirmed_need_approval_release.sql --local
pnpm exec supabase test db supabase/tests/pa_05d_planning_command_family.sql --local
```

Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/*_sc_proc_01_school_catering_allocation_family.sql supabase/tests/sc_proc_01_school_catering_allocation_family.sql
git commit -m "feat: release school catering purchase handoff"
```

---

### Task 3: Add the backend-derived Allocation Family workbench read

**Files:**
- Modify: SC-PROC-01 migration
- Modify: `supabase/tests/sc_proc_01_school_catering_allocation_family.sql`
- Create: `docs/api/sc-proc-01-school-catering-allocation.md`
- Reference only: `docs/api/rmvp-07-connected-confirmed-need-approval-release.md`
- Reference only: `docs/architecture/admin-master-data-domain-contract.md`

**Interfaces:**
- Produces: `atlas_api.get_school_catering_procurement_workbench(request jsonb) returns jsonb`
- Read input: `date_start`, `date_end`, optional `delivery_location_ids`, optional allocation-state filter, pagination
- Read output: candidate/persisted family rows, current demand/contribution fingerprint, accepted splits/ratios, eligible suppliers/priorities, recommendation, stale/rebalance state, blockers/warnings, allowed actions.

- [ ] **Step 1: Add failing workbench tests**

Create a released school-catering handoff with multiple handoff lines that share one family tuple plus another tuple. Assert the read groups only the identical tuple and preserves total/lineage:

```sql
select is(
  (result #>> '{workbench,families,0,family_demand_quantity}')::numeric,
  100.000000::numeric,
  'read model aggregates current released handoff contributions into one family'
);

select is(
  jsonb_array_length(result #> '{workbench,families,0,contributions}'),
  2,
  'family retains both exact handoff-line contributions'
);
```

Also prove:

```text
read causes zero writes
no eligible supplier → NO_ELIGIBLE_SUPPLIER
single best priority → 100% default recommendation
best-priority tie → AMBIGUOUS_SUPPLIER_PRIORITY
existing accepted allocation/current fingerprint → CURRENT
source fingerprint changed → STALE with rebalance proposal only when all prior suppliers remain eligible
```

- [ ] **Step 2: Run RED**

```bash
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/sc_proc_01_school_catering_allocation_family.sql --local
```

Expected: FAIL because the read function is absent.

- [ ] **Step 3: Implement private family projection/fingerprint helpers and public read**

Keep the public API shaped and decision-oriented. The server owns grouping by:

```sql
(service_date, delivery_location_id, ingredient_id, unit_id)
```

The canonical source fingerprint must be deterministic over sorted current handoff-line revision identity + authoritative quantities/context. A recommended supplier is the unique active/effective eligibility with minimum numeric priority.

The returned family status vocabulary should be exactly:

```text
UNASSIGNED
IMBALANCED
BALANCED
STALE_REBALANCE_AVAILABLE
STALE_REQUIRES_REALLOCATION
```

The read response should carry Vietnamese safe display copy separately from machine codes where existing Atlas patterns support it.

- [ ] **Step 4: Document the exact SC-PROC-01 API contracts**

`docs/api/sc-proc-01-school-catering-allocation.md` must define all four SC-PROC-01 public functions, capability ownership, exact request shapes, response fields, safe errors, events/audit and test files. Do not duplicate the full canonical registry elsewhere.

- [ ] **Step 5: Run read test GREEN**

```bash
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/sc_proc_01_school_catering_allocation_family.sql --local
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add supabase/migrations/*_sc_proc_01_school_catering_allocation_family.sql supabase/tests/sc_proc_01_school_catering_allocation_family.sql docs/api/sc-proc-01-school-catering-allocation.md
git commit -m "feat: add school catering procurement read model"
```

---

### Task 4: Add family-atomic manual allocation save

**Files:**
- Modify: SC-PROC-01 migration
- Modify: `supabase/tests/sc_proc_01_school_catering_allocation_family.sql`
- Modify: `docs/api/sc-proc-01-school-catering-allocation.md`

**Interfaces:**
- Produces: `atlas_api.save_school_catering_supplier_allocation(request jsonb) returns jsonb`
- Capability: `school_catering_allocation.write`
- Payload identifies exact family tuple + backend fingerprint + complete supplier quantities.

- [ ] **Step 1: Add failing command tests**

Use this payload contract:

```json
{
  "service_date": "2026-09-02",
  "delivery_location_id": "uuid",
  "ingredient_id": "uuid",
  "unit_id": "uuid",
  "source_fingerprint": "sha256-hex",
  "splits": [
    {"supplier_id": "uuid-a", "split_quantity": "60.000000"},
    {"supplier_id": "uuid-b", "split_quantity": "40.000000"}
  ]
}
```

Prove:

```text
60/40 of 100 succeeds and stores ratios 0.6/0.4
sum 90 → ALLOCATION_IMBALANCED, no write
sum 110 → ALLOCATION_IMBALANCED, no write
zero/negative split → validation failure
same supplier twice → validation failure
inactive supplier → SUPPLIER_INELIGIBLE
eligibility outside service date → SUPPLIER_INELIGIBLE
wrong unit/tuple → SOURCE_CHANGED
stale source fingerprint → SOURCE_CHANGED
first save lazily creates root version 1/revision 1
successor save creates revision 2, advances root version/current pointer, preserves revision 1
replay returns same revision
```

- [ ] **Step 2: Run RED**

```bash
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/sc_proc_01_school_catering_allocation_family.sql --local
```

- [ ] **Step 3: Implement family-atomic save**

Server algorithm:

```text
resolve current family projection/fingerprint under lock
→ compare request fingerprint
→ resolve/create stable root by tuple
→ lock root + expected_version
→ validate all supplier eligibilities at service date
→ require unique suppliers and exact positive sum
→ calculate ratios server-side from decimal quantities
→ insert one immutable revision + contributions + splits
→ clear prior is_current, set new is_current/current pointer, increment root version
→ emit one Procurement event/audit/receipt
```

Use numeric arithmetic only; do not use floating-point JS-like semantics in SQL.

- [ ] **Step 4: Run GREEN**

```bash
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/sc_proc_01_school_catering_allocation_family.sql --local
```

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/*_sc_proc_01_school_catering_allocation_family.sql supabase/tests/sc_proc_01_school_catering_allocation_family.sql docs/api/sc-proc-01-school-catering-allocation.md
git commit -m "feat: save school catering supplier allocations"
```

---

### Task 5: Add bulk confirmation for untouched priority-1 proposals

**Files:**
- Modify: SC-PROC-01 migration
- Modify: `supabase/tests/sc_proc_01_school_catering_allocation_family.sql`
- Modify: `docs/api/sc-proc-01-school-catering-allocation.md`

**Interfaces:**
- Produces: `atlas_api.confirm_school_catering_supplier_recommendations(request jsonb) returns jsonb`
- Capability: `school_catering_allocation.bulk_confirm`
- Maximum explicit candidate list: 500.
- Each candidate contains tuple, source fingerprint and recommended supplier ID observed by operator.

- [ ] **Step 1: Add failing partial-business-success tests**

Payload candidates:

```json
{
  "candidates": [
    {
      "service_date": "2026-09-02",
      "delivery_location_id": "uuid",
      "ingredient_id": "uuid",
      "unit_id": "uuid",
      "source_fingerprint": "sha256-hex",
      "recommended_supplier_id": "uuid"
    }
  ]
}
```

Prove one call with three candidates can return:

```json
{
  "confirmed_count": 1,
  "skipped_count": 2,
  "results": [
    {"status":"CONFIRMED"},
    {"status":"SKIPPED","error_code":"SOURCE_CHANGED"},
    {"status":"SKIPPED","error_code":"AMBIGUOUS_SUPPLIER_PRIORITY"}
  ]
}
```

and commits the one valid accepted family without committing invalid ones.

Also prove manually allocated families are skipped, list length 0/>500 is rejected, and exact command replay does not duplicate revisions.

- [ ] **Step 2: Run RED**

```bash
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/sc_proc_01_school_catering_allocation_family.sql --local
```

- [ ] **Step 3: Implement bounded bulk confirmation**

Reuse one private family-confirmation primitive from Task 4 only if it remains domain-specific and small. Do not build a generic workflow/batch engine.

For each explicit candidate in deterministic tuple order:

```text
re-read family source
→ verify fingerprint
→ verify no current manual allocation to overwrite
→ recompute unique best eligible supplier
→ require recomputed supplier == requested recommended_supplier_id
→ save 100% as DEFAULT_CONFIRMED revision
→ otherwise append structured SKIPPED result
```

Business skips do not abort other candidates. Unexpected internal SQL errors abort the whole command transaction.

- [ ] **Step 4: Run GREEN**

```bash
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/sc_proc_01_school_catering_allocation_family.sql --local
```

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/*_sc_proc_01_school_catering_allocation_family.sql supabase/tests/sc_proc_01_school_catering_allocation_family.sql docs/api/sc-proc-01-school-catering-allocation.md
git commit -m "feat: confirm default supplier recommendations"
```

---

### Task 6: Prove stale/rebalance behavior and cross-stage continuity

**Files:**
- Modify: SC-PROC-01 migration only if test exposes missing read logic
- Modify: `supabase/tests/sc_proc_01_school_catering_allocation_family.sql`
- Modify: `docs/api/sc-proc-01-school-catering-allocation.md` if read fields need exact clarification
- Reference only: `supabase/tests/issue_222_closed_loop_planning_corrections.sql`
- Reference only: `supabase/tests/pa_06e_h0cb_corrected_materialization_history.sql`

**Interfaces:**
- Produces no new public API.
- Certifies that read-model staleness/rebalance semantics work when a later valid handoff source revision exists.

- [ ] **Step 1: Add a failing 100→120 proportional rebalance test**

Inside the pgTAP transaction, construct the minimum valid successor Planning/Purchase Handoff source revision if the public Planning correction API cannot yet generate it.

Assert:

```text
accepted family revision remains immutable at 100
current source demand becomes 120
workbench state = STALE_REBALANCE_AVAILABLE
proposal A/B = 72/48 for prior 60/40
no successor family revision exists until save command
```

- [ ] **Step 2: Add residual rounding test**

Use a demand and three ratios that do not divide evenly at governed precision. Assert the deterministic final supplier receives the residual and exact split sum equals demand.

- [ ] **Step 3: Add eligibility-break test**

Expire one prior supplier eligibility before the new service/source context and assert:

```text
state = STALE_REQUIRES_REALLOCATION
no proportional quantities are presented as safe confirmation
```

- [ ] **Step 4: Run focused test RED/GREEN**

```bash
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/sc_proc_01_school_catering_allocation_family.sql --local
```

Expected: PASS after minimal read-model corrections.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/*_sc_proc_01_school_catering_allocation_family.sql supabase/tests/sc_proc_01_school_catering_allocation_family.sql docs/api/sc-proc-01-school-catering-allocation.md
git commit -m "test: certify allocation rebalance continuity"
```

---

### Task 7: Register the four APIs and certify SC-PROC-01 without broad local repetition

**Files:**
- Modify: `docs/api/api-contracts.md`
- Modify: `docs/architecture/pa-06a-application-connection-contract.md`
- Modify: `scripts/atlas-staging-contract.mjs` only if it is the current canonical expected API registry at execution time
- Modify: related registry tests next to `scripts/atlas-staging-contract.test.mjs` if the registry changes
- Modify: `.github/workflows/supabase-integration.yml` only to add the new focused pgTAP file to Draft smoke if existing path/filter behavior would otherwise omit it

**Interfaces:**
- Whole-platform public registry becomes current baseline + four SC-PROC-01 functions.
- No extra public helper function is allowed.

- [ ] **Step 1: Update canonical registry/document index**

Add exactly:

```text
release_school_catering_purchase_handoff
get_school_catering_procurement_workbench
save_school_catering_supplier_allocation
confirm_school_catering_supplier_recommendations
```

Do not rename legacy wholesale APIs.

- [ ] **Step 2: Add SC-PROC-01 pgTAP to Draft smoke**

The smoke step should include:

```bash
pnpm exec supabase test db supabase/tests/sc_proc_01_school_catering_allocation_family.sql --local
```

Do not expand Draft smoke to the entire database suite.

- [ ] **Step 3: Run one final bounded local certification**

```bash
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/sc_proc_01_school_catering_allocation_family.sql --local
pnpm exec supabase test db supabase/tests/rmvp_07_connected_confirmed_need_approval_release.sql --local
pnpm exec supabase test db supabase/tests/pa_05d_planning_command_family.sql --local
pnpm exec supabase test db supabase/tests/pa_05e_procurement_command_family.sql --local
git diff --check
```

Expected: all PASS, `git diff --check` clean.

Do **not** run every pgTAP suite locally unless one of these tests exposes a cross-platform regression. Let GitHub Actions run full certification.

- [ ] **Step 4: Commit documentation/CI registry changes**

```bash
git add docs/api/api-contracts.md docs/architecture/pa-06a-application-connection-contract.md docs/api/sc-proc-01-school-catering-allocation.md scripts/atlas-staging-contract.mjs scripts/atlas-staging-contract.test.mjs .github/workflows/supabase-integration.yml
git commit -m "docs: register school catering allocation APIs"
```

Only stage files that actually changed.

- [ ] **Step 5: Push and open a Draft PR**

Recommended title:

```text
SC-PROC-01: Add school-catering allocation backend
```

PR body must state:

```text
Backend only; no connected Procurement UI.
No Live OPS/Retool mutation.
No PA-05E behavior change.
Four new APIs only.
Staging deployment/rehearsal remains a post-CI review gate.
```

- [ ] **Step 6: Use GitHub Actions as the comprehensive gate**

Required before marking technically ready:

```text
Frontend CI → success
Supabase Smoke → success on Draft
Qodana → success or findings triaged to changed files
Supabase Full Integration → run when PR is marked ready/non-Draft after review gate, according to existing workflow
```

Do not merge. Stop for review of SC-PROC-01 before starting SC-PROC-02.
