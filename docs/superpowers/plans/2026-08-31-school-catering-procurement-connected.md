# School-Catering Procurement Connected Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Connect the approved school-catering Planning → Procurement path from released Confirmed Need through Purchase Handoff, Allocation Families, balanced supplier splits, PO drafts, and immutable supplier PO release.

**Architecture:** Keep Planning authoritative for released demand and Procurement authoritative for supplier allocation and supplier commitments. Add a school-catering Allocation Family aggregate beside, not inside, the existing PA-05E wholesale fulfilment-allocation aggregate; reuse the shared Purchase Order aggregate with narrow source-kind extensions. React consumes shaped `atlas_api` reads and backend-authorized actions only; it never reconstructs family totals, supplier eligibility, lifecycle authority, or official document numbers.

**Tech Stack:** PostgreSQL/Supabase migrations, pgTAP, SECURITY DEFINER RPCs, forced RLS, React 19, TypeScript 7, Mantine 9, Supabase JS 2, Vitest 4, Vite 8, pnpm 11.

**Spec:** `docs/superpowers/specs/2026-08-31-school-catering-procurement-connected-design.md`

**Approval:** The user explicitly approved the written spec as the implementation authority on 2026-08-31.

**Repository baseline for planning:** `main` at `9928ced99e9d0430801140ad29f86b716d594e59` (`Planning: polish responsive workbench composition (#237)`). At implementation time, fetch `origin/main` and stop if the relevant Planning, Procurement, or Supabase contracts have materially changed; rebase the docs/spec branch before code work.

## Global Constraints

- OPS_SYSTEM_MAP v1.0 / ARCH-002 is the governing architecture.
- Supabase Staging is backend/domain authority. Retool is workflow-density and operator-vocabulary evidence only.
- Do not mutate Live OPS, Retool, production data, credentials, or production Supabase.
- Preserve PA-05E supplier-direct wholesale behavior, command names, lineage, tests, and one-supplier-per-wholesale-requirement-line simplification.
- School-catering operator allocation grain is the Allocation Family: `service_date + delivery_location_id + ingredient_id + unit_id`.
- Exact Purchase Handoff contribution lineage remains beneath each Allocation Family.
- Multiple suppliers may split one family; every accepted split is positive and the split sum must equal authoritative family demand exactly.
- Supplier priority produces only an uncommitted 100% recommendation for one unambiguous best eligible supplier. Priority is never interpreted as a split percentage.
- Server calculates and persists split ratios; React does not author authoritative ratios.
- PO aggregate grain for school catering is one supplier + one service date, with multiple school/delivery-location lines.
- `Tạo đơn mua` creates DRAFT PO snapshots. It does not create an external supplier commitment.
- `Phát hành cho NCC` releases exactly one PO transactionally. Bulk release is only application orchestration over independent PO release commands.
- Official PO number is generated server-side only during release. The request must not accept `document_number`.
- Released POs are immutable in this slice. Amendment, cancellation, replacement supplier, acknowledgement, partial rejection, Warehouse, Dispatch, QA, Finance, and payment are excluded.
- Planning source correction must remain possible for school catering before a supplier PO is released, so v1-style supplier-ratio rebalance remains operationally useful. Wholesale correction behavior remains unchanged.
- No new generic workflow engine, allocation engine, event-sourcing layer, queue, broad repository abstraction, or cross-domain numbering service.
- No new database/runtime role. Reuse `atlas_planning_command_runtime`, `atlas_procurement_command_runtime`, and `atlas_read_runtime` with least privilege.
- Add exactly two connected capabilities: `procurement.school_catering.read` and `procurement.school_catering.write`.
- Use existing `confirmed_need_release.release` for the Planning-owned school-catering Purchase Handoff release.
- Contract version for the Planning handoff command: `SCHOOL-CATERING-HANDOFF.v1`.
- Contract version for all school-catering Procurement commands/reads: `SCHOOL-CATERING-PROCUREMENT.v1`.
- Final public `atlas_api` registry after all three PRs: 99 functions (current 92 + 7 new names).
- Final authoritative ordinary-table count after backend work: 107 (current 103 + 4 Allocation Family tables).
- Final capability count: 29 (current 27 + 2 school-catering Procurement capabilities).
- Keep the existing staging role code `atlas_staging_admin_planning_operator`; add the two Procurement capabilities to that synthetic staging role rather than creating a new staging role.
- No dependency additions are required.
- Use TDD for every behavioral change: failing focused test → minimal implementation → passing focused test.
- Keep local work focused. GitHub Actions is authoritative for frozen install, full format/typecheck/test/build, full Supabase integration, Qodana, and deployment checks.
- Before each PR: `git diff --check`, focused tests, changed-file Prettier where relevant, and only the typecheck/build checks materially needed for the changed layer.
- Keep every PR draft until its exact-head CI and requested review gate are complete.

---

# Delivery Strategy

Implement as three sequential PRs. Do not combine them unless a concrete contract dependency makes independent review impossible.

| PR | Purpose | Primary review gate |
| --- | --- | --- |
| A | Planning Purchase Handoff + Allocation Family persistence/commands/read + D-042 correction reconciliation | Backend lineage, security, family balance/rebalance, wholesale regression |
| B | Shared PO extension + school-catering draft/release + automated numbering + PO read | PO source XOR, supplier/date grouping, immutable release, PA-05E regression |
| C | Connected Planning transition + Procurement UI + review fixtures + cross-stage/browser certification | Operator flow, failure recovery, responsive UI, hosted exact-head review |

**Codex settings for every PR:** GPT-5.6 Sol; Medium reasoning; one agent; parallel agents off; subagents off. Increase reasoning only if a failing invariant cannot be explained from the focused tests and contract files.

---

# PR A — School-Catering Handoff, Allocation Families, and Correction Bridge

**Proposed branch:** `feat/school-catering-procurement-allocation`

**Proposed draft PR title:** `Procurement: connect school-catering handoff and allocation families`

**Expected public API delta:** 92 → 96 functions.

**Expected table delta:** 103 → 107 authoritative ordinary tables.

**Expected capability delta:** 27 → 29 capabilities.

## PR A file map

**Create:**
- `supabase/migrations/20260831090000_school_catering_handoff_allocation.sql`
- `supabase/tests/school_catering_handoff_allocation.sql`
- `supabase/tests/school_catering_planning_correction.sql`
- `docs/api/school-catering-procurement.md`
- `scripts/verify-local-school-catering-procurement.mjs`

**Modify:**
- `docs/api/api-contracts.md`
- `docs/ui/pa-06a-operator-workflow-matrix.md`
- `docs/architecture/roadmap.md`
- `supabase/tests/atlas_current_platform_security_catalog.sql`
- `supabase/tests/issue_222_closed_loop_planning_corrections.sql`
- `supabase/packages/atlas-staging-identity.v1.json`
- `scripts/atlas-staging-contract.mjs`
- `scripts/atlas-staging-contract.test.mjs`
- `scripts/certify-supabase-full-integration.mjs`
- `.github/workflows/supabase-integration.yml`
- `package.json`

## Task A1: Freeze the school-catering API/security contract in failing pgTAP

**Interfaces:**
- Consumes: approved spec and current 92-function Atlas registry.
- Produces: executable expectations for PurchaseDemandReference source-kind compatibility, four Allocation Family relations, two capabilities, four PR-A APIs, runtime ownership, RLS, idempotency, lineage, balance, and wholesale non-regression.

- [ ] **Step 1: Write `supabase/tests/school_catering_handoff_allocation.sql` with the exact PR-A contract.**

The suite must begin with a fixed plan and cover at least these named assertions:

```sql
begin;
create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

-- Keep the exact plan count synchronized with the concrete assertions below.
-- Do not use no_plan().
select plan(48);

select has_table('atlas_procurement', 'school_catering_allocation_families');
select has_table('atlas_procurement', 'school_catering_allocation_family_revisions');
select has_table('atlas_procurement', 'school_catering_allocation_family_contributions');
select has_table('atlas_procurement', 'school_catering_allocation_supplier_splits');

select has_function('atlas_api', 'release_school_catering_purchase_handoff', array['jsonb']);
select has_function('atlas_api', 'save_school_catering_supplier_allocation', array['jsonb']);
select has_function('atlas_api', 'confirm_school_catering_supplier_recommendations', array['jsonb']);
select has_function('atlas_api', 'get_school_catering_procurement_workbench', array['jsonb']);

select ok(
  exists (
    select 1 from atlas_core.capabilities
    where capability_code = 'procurement.school_catering.read'
      and owning_domain = 'PROCUREMENT'
      and capability_status = 'ACTIVE'
  ),
  'school-catering Procurement read capability is explicit'
);
select ok(
  exists (
    select 1 from atlas_core.capabilities
    where capability_code = 'procurement.school_catering.write'
      and owning_domain = 'PROCUREMENT'
      and capability_status = 'ACTIVE'
  ),
  'school-catering Procurement write capability is explicit'
);
```

Add concrete assertions for:
- `purchase_demand_references.source_kind` and nullable wholesale source;
- WHOLESALE rows still require a wholesale line revision;
- NEED_GENERATION rows require no wholesale line revision and retain snapshot-line lineage;
- family-key uniqueness;
- one current family revision per family;
- contribution uniqueness by family revision + Purchase Handoff line revision;
- split uniqueness by family revision + supplier;
- positive family/contribution/split quantities;
- split ratios `(0, 1]`;
- all four new relations have forced RLS;
- Planning command owned by `atlas_planning_command_runtime`;
- Procurement commands owned by `atlas_procurement_command_runtime`;
- read owned by `atlas_read_runtime`;
- authenticated execute and direct private-table denial;
- `anon`/`service_role` no execute;
- exact replay, idempotency conflict, stale source/version, inactive supplier, ineligible supplier, ambiguous best priority, no eligible supplier, duplicate supplier split, non-positive split, and imbalanced split failure behavior;
- successful manual split `60/40` persists a complete family revision with server-derived ratios;
- bulk recommendation confirms only explicit current candidates and returns skipped stale/ambiguous candidates;
- read returns one family row per date/location/ingredient/unit and retains contribution lineage;
- PA-05E wholesale allocation objects remain untouched by school-catering allocation commands.

- [ ] **Step 2: Run the new test and verify it fails because the new relations/APIs do not exist.**

Run:

```bash
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/school_catering_handoff_allocation.sql --local
```

Expected: non-zero test result with missing relation/function/capability assertions; the reset itself must succeed.

- [ ] **Step 3: Add a second failing suite for D-042 reconciliation.**

Create `supabase/tests/school_catering_planning_correction.sql` with explicit scenarios:

```text
WHOLESALE active Purchase Handoff -> correction remains BLOCKED_BY_PURCHASE_HANDOFF
SCHOOL_CATERING active Purchase Handoff + no released PO -> correction is permitted
permitted correction -> current school-catering Handoff becomes INVALIDATED, history retained
correction -> Confirmed Need is reopened through existing D-042 authority
new corrected Planning release -> same Handoff batch receives one SUPERSEDING current revision
old family allocation remains historical and workbench derives stale/rebalance state
```

Use fixed deterministic fixtures and exact assertions; do not create a new public correction API.

- [ ] **Step 4: Run the D-042 suite and verify current behavior fails the school-catering case while wholesale still blocks.**

```bash
pnpm exec supabase test db supabase/tests/school_catering_planning_correction.sql --local
```

Expected: school-catering correction assertion fails on current `BLOCKED_BY_PURCHASE_HANDOFF`; wholesale blocker assertion remains green.

- [ ] **Step 5: Commit only the failing contract tests.**

```bash
git add supabase/tests/school_catering_handoff_allocation.sql supabase/tests/school_catering_planning_correction.sql
git commit -m "test: define school-catering procurement allocation contract"
```

## Task A2: Add the Planning school-catering Purchase Handoff boundary

**Interfaces:**
- Consumes: current `RELEASED_FOR_PURCHASE_HANDOFF` Confirmed Need batches and current approval/release evidence.
- Produces: `atlas_api.release_school_catering_purchase_handoff(request jsonb)` under `SCHOOL-CATERING-HANDOFF.v1`, current released Purchase Handoff revisions, NEED_GENERATION purchase-demand references.

- [ ] **Step 1: In `20260831090000_school_catering_handoff_allocation.sql`, extend PurchaseDemandReference source qualification.**

Implement exactly:

```sql
alter table atlas_planning.purchase_demand_references
  add column source_kind text not null default 'WHOLESALE';

alter table atlas_planning.purchase_demand_references
  alter column wholesale_order_line_revision_id drop not null;

alter table atlas_planning.purchase_demand_references
  add constraint purchase_demand_references_source_kind_check
  check (source_kind in ('WHOLESALE', 'NEED_GENERATION'));

alter table atlas_planning.purchase_demand_references
  add constraint purchase_demand_references_source_shape_check
  check (
    (source_kind = 'WHOLESALE' and wholesale_order_line_revision_id is not null)
    or
    (source_kind = 'NEED_GENERATION' and wholesale_order_line_revision_id is null)
  );
```

Backfill existing rows as WHOLESALE before enforcing the shape when required by migration ordering. Preserve the existing snapshot-line, handoff-line, quantity, and unit FKs.

- [ ] **Step 2: Implement `release_school_catering_purchase_handoff`.**

Required request shape:

```json
{
  "contract_version": "SCHOOL-CATERING-HANDOFF.v1",
  "command_id": "uuid",
  "correlation_id": "uuid",
  "idempotency_key": "school-catering-handoff:<command-id>",
  "expected_version": 7,
  "requested_by_auth_subject": "uuid",
  "requested_at": "ISO-8601",
  "reason_code": "SCHOOL_CATERING_PURCHASE_HANDOFF_RELEASED",
  "reason_note": null,
  "payload": {
    "confirmed_need_batch_id": "uuid"
  }
}
```

Use existing Atlas helper patterns for strict payload allowlisting, actor resolution, `confirmed_need_release.release`, GLOBAL/customer/location scope checks, command receipt, exact replay, idempotency conflict, stale version, deterministic locking, safe failures, one domain event, one audit event, and authoritative readback.

For first release:
- require `source_kind = NEED_GENERATION`;
- require current Confirmed Need status `RELEASED_FOR_PURCHASE_HANDOFF`;
- bind the current immutable approval snapshot and Confirmed Need release;
- create one Purchase Handoff batch and BASE current revision in `RELEASED_TO_PROCUREMENT`;
- create stable Handoff lines and current line revisions from the exact released Confirmed Need snapshot;
- create `purchase_demand_references` with `source_kind='NEED_GENERATION'`, `wholesale_order_line_revision_id=NULL`, exact snapshot line, quantity, and unit;
- create no Procurement rows.

For a previously invalidated school-catering Handoff after an approved Planning correction:
- reuse the existing batch because `purchase_handoff_batches_confirmed_need_key` is unique;
- lock the batch/current revision/lines;
- set the previous current revision `is_current=false` and retain it;
- create one `SUPERSEDING` revision with the next revision number and `RELEASED_TO_PROCUREMENT`;
- reuse stable Handoff lines for still-present Confirmed Need lines, add stable lines for new current lines, and omit removed lines from the new revision without deleting history;
- create new line revisions and new NEED_GENERATION purchase-demand references;
- increment batch version and restore batch status to `RELEASED_TO_PROCUREMENT`.

- [ ] **Step 3: Add immutable/source integrity checks for school-catering Handoff rows.**

Use the existing handoff status/revision-kind vocabulary. Do not add lifecycle statuses. Add only constraints/triggers needed to prove:
- current Handoff revision every-and-only current line revisions;
- quantities/ingredient/unit/date/location equal the released Confirmed Need snapshot and current line revision;
- NEED_GENERATION PurchaseDemandReference points to the same current approval snapshot line;
- wholesale rows retain their current PA-05D invariants.

- [ ] **Step 4: Run the focused Handoff assertions until the Handoff subset passes.**

```bash
pnpm exec supabase test db supabase/tests/school_catering_handoff_allocation.sql --local
pnpm exec supabase test db supabase/tests/rmvp_07_connected_confirmed_need_approval_release.sql --local
pnpm exec supabase test db supabase/tests/pa_05d_planning_command_family.sql --local
```

If the PA-05D filename differs on current `main`, use the existing PA-05D pgTAP file returned by `git ls-files 'supabase/tests/*pa_05d*'`; do not rename historical tests.

- [ ] **Step 5: Commit the Handoff boundary.**

```bash
git add supabase/migrations/20260831090000_school_catering_handoff_allocation.sql supabase/tests/school_catering_handoff_allocation.sql
git commit -m "feat: release school-catering purchase handoff"
```

## Task A3: Add Allocation Family persistence and supplier decision commands

**Interfaces:**
- Consumes: current `RELEASED_TO_PROCUREMENT` school-catering Purchase Handoff line revisions and active Supplier eligibility/priority.
- Produces: four immutable/revision-safe Procurement tables, manual family save, bulk recommendation confirmation, shaped family workbench read.

- [ ] **Step 1: Add exactly four Procurement relations.**

Use these exact table names:

```text
atlas_procurement.school_catering_allocation_families
atlas_procurement.school_catering_allocation_family_revisions
atlas_procurement.school_catering_allocation_family_contributions
atlas_procurement.school_catering_allocation_supplier_splits
```

Minimum physical contract:

```sql
-- Root: one stable family identity.
service_date date not null
delivery_location_id uuid not null references atlas_admin.delivery_locations
ingredient_id uuid not null references atlas_admin.ingredients
unit_id uuid not null references atlas_admin.units
version bigint not null check (version > 0)
unique(service_date, delivery_location_id, ingredient_id, unit_id)

-- Revision: accepted decision snapshot.
revision_number integer not null check (revision_number > 0)
is_current boolean not null
predecessor_revision_id uuid null
source_purchase_handoff_revision_id uuid not null
source_fingerprint text not null
family_quantity numeric not null check (family_quantity > 0)
unit_id uuid not null
accepted_by_actor_id uuid not null
accepted_at timestamptz not null
command_id uuid not null
decision_origin text not null check (decision_origin in ('MANUAL','PRIORITY_RECOMMENDATION','REBALANCED'))
unique(family_id, revision_number)
unique current revision per family

-- Contribution: every exact Handoff line in the accepted family source.
purchase_handoff_line_revision_id uuid not null
contribution_quantity numeric not null check (contribution_quantity > 0)
unique(family_revision_id, purchase_handoff_line_revision_id)

-- Supplier split: accepted Procurement allocation.
supplier_id uuid not null
allocated_quantity numeric not null check (allocated_quantity > 0)
split_ratio numeric not null check (split_ratio > 0 and split_ratio <= 1)
decision_origin text not null check (decision_origin in ('MANUAL','PRIORITY_RECOMMENDATION','REBALANCED'))
unique(family_revision_id, supplier_id)
```

Enable and force RLS on all four tables. Runtime write policies must be verb-specific and restricted to `atlas_procurement_command_runtime`; read runtime receives only required SELECT. Add immutability/current-revision integrity triggers using established Atlas patterns; do not add generic helpers unless used by more than one of the three school-catering Procurement commands in this PR.

- [ ] **Step 2: Add the two capabilities and least-privilege grants.**

Insert exact catalog values:

```text
procurement.school_catering.read  | Read school-catering Procurement workbench | PROCUREMENT
procurement.school_catering.write | Maintain school-catering supplier allocation | PROCUREMENT
```

Do not bind the capabilities to a new application role in the migration. Runtime role ownership/grants are database security, while staging synthetic role binding belongs to the staging package.

- [ ] **Step 3: Implement one private canonical family projection/fingerprint helper.**

Given `service_date + delivery_location_id + ingredient_id + unit_id`, the helper must:
- select only current `RELEASED_TO_PROCUREMENT` school-catering Handoff revision lines;
- return ordered contribution IDs/quantities;
- return the authoritative family quantity as exact numeric sum;
- return one deterministic fingerprint over current Handoff revision IDs, line-revision IDs, quantities, ingredient, unit, date, and location.

Do not let React or command payloads author the family total.

- [ ] **Step 4: Implement `save_school_catering_supplier_allocation`.**

Use payload:

```json
{
  "family": {
    "service_date": "2026-09-02",
    "delivery_location_id": "uuid",
    "ingredient_id": "uuid",
    "unit_id": "uuid",
    "expected_source_fingerprint": "sha256-text"
  },
  "splits": [
    { "supplier_id": "uuid-a", "allocated_quantity": "60.000000" },
    { "supplier_id": "uuid-b", "allocated_quantity": "40.000000" }
  ]
}
```

Top-level `expected_version` is the family root version, with `0` meaning no persisted family root yet. The command must:
- lock active supplier rows in UUID order, relevant eligibility rows, Handoff source rows, then the family root/current revision;
- re-read the canonical family projection/fingerprint;
- fail `SOURCE_CHANGED` if fingerprint differs;
- require every supplier active and eligible on the service date;
- reject duplicate suppliers and non-positive quantities;
- require exact split sum = family quantity;
- create root+revision when expected version is 0 and no root exists;
- otherwise require root version match, create successor revision, set previous current false, increment root version;
- copy the exact current contributions into immutable contribution rows;
- calculate each `split_ratio = allocated_quantity / family_quantity` server-side using the governed numeric scale;
- emit one Procurement domain event and one audit event;
- return authoritative family readback.

- [ ] **Step 5: Implement `confirm_school_catering_supplier_recommendations`.**

Payload must contain an explicit `candidates` array; do not accept an unbounded date-only command that can confirm rows the operator never reviewed.

Each candidate carries:

```json
{
  "service_date": "2026-09-02",
  "delivery_location_id": "uuid",
  "ingredient_id": "uuid",
  "unit_id": "uuid",
  "expected_family_version": 0,
  "expected_source_fingerprint": "sha256-text"
}
```

For each candidate, re-read the source and active eligibility. Confirm only when exactly one active eligible supplier has the lowest numeric `priority`. Persist a 100% split with decision origin `PRIORITY_RECOMMENDATION`. Skip and report candidates that are stale, already manually changed, have no eligible supplier, or have tied best priority. The command writes all successful candidate decisions atomically within its request; skipped candidates are not failures and must be listed in the safe response.

- [ ] **Step 6: Implement `get_school_catering_procurement_workbench`.**

Read request payload:

```json
{
  "date_start": "2026-08-31",
  "date_end": "2026-09-06",
  "school_ids": [],
  "states": [],
  "search": null
}
```

Return shaped rows with:
- family key and persisted family ID/version when present;
- school/delivery-location display;
- ingredient/unit display;
- authoritative family total;
- contribution count and trace summary;
- current accepted splits/ratios;
- eligible suppliers ordered by priority;
- one uncommitted 100% recommendation when unambiguous;
- derived state exactly one of `UNALLOCATED`, `BALANCED`, `STALE_REBALANCE_AVAILABLE`, `NEEDS_REALLOCATION`, `BLOCKED`;
- rebalance proposal using prior ratios when all prior suppliers remain eligible;
- blockers/warnings;
- `allowed_actions` and `disabled_reasons` governed server-side.

Rounding for a rebalance proposal: calculate all but the final supplier at governed precision, then give the final supplier the exact residual so the proposed sum equals current family demand.

- [ ] **Step 7: Run focused pgTAP and verify all Allocation Family contract assertions pass.**

```bash
pnpm exec supabase test db supabase/tests/school_catering_handoff_allocation.sql --local
```

Expected: all 48 assertions pass after updating the fixed plan count only if the concrete assertion list is larger than 48. Never switch to `no_plan()`.

- [ ] **Step 8: Commit Allocation Family implementation.**

```bash
git add supabase/migrations/20260831090000_school_catering_handoff_allocation.sql supabase/tests/school_catering_handoff_allocation.sql
git commit -m "feat: add school-catering allocation families"
```

## Task A4: Reconcile D-042 so school-catering allocations can rebalance before PO release

**Interfaces:**
- Consumes: existing `get_planning_source_correction_impact`, `prepare_planning_source_correction`, current Handoff and Allocation Family history.
- Produces: source-kind-aware correction behavior with no new public API.

- [ ] **Step 1: Add source-kind discrimination to the existing private D-042 chain helpers.**

The helper/read must distinguish:

```text
WHOLESALE Handoff
SCHOOL_CATERING Handoff with no released PO
SCHOOL_CATERING Handoff with DRAFT PO only (supported after PR B)
SCHOOL_CATERING Handoff with RELEASED_TO_SUPPLIER PO
```

In PR A, implement the first two states and preserve hooks/queries that PR B can extend for DRAFT/released PO classification without changing public response keys unnecessarily.

- [ ] **Step 2: Preserve current wholesale behavior exactly.**

A WHOLESALE active Purchase Handoff still returns `BLOCKED_BY_PURCHASE_HANDOFF`. Do not relax PA-05D/PA-05E correction safety.

- [ ] **Step 3: Permit school-catering correction before supplier commitment.**

When the chain is school catering and has no released supplier PO:
- authorize through the existing Planning correction capabilities;
- lock Confirmed Need and current Handoff root/revision;
- set current Handoff revision to `INVALIDATED` and `is_current=false` only through a reasoned Planning-owned correction path;
- set Handoff batch status `INVALIDATED` and increment its version;
- retain all Handoff lines, line revisions, purchase-demand references, Allocation Family revisions, and events as history;
- reopen Confirmed Need using the current D-042 behavior;
- do not mutate Procurement Allocation Family history.

- [ ] **Step 4: Ensure the next corrected release creates a SUPERSEDING Handoff revision.**

Use the A2 command behavior; do not create a second Handoff batch for the same Confirmed Need batch.

- [ ] **Step 5: Verify the family read derives stale/rebalance state from the new Handoff fingerprint.**

Test both:

```text
prior suppliers all eligible -> STALE_REBALANCE_AVAILABLE with preserved ratios
one prior supplier ineligible -> NEEDS_REALLOCATION and no automatic redistribution
```

- [ ] **Step 6: Run D-042 regression suites.**

```bash
pnpm exec supabase test db supabase/tests/school_catering_planning_correction.sql --local
pnpm exec supabase test db supabase/tests/issue_222_closed_loop_planning_corrections.sql --local
```

Expected: new school-catering cases pass; existing wholesale/downstream-commitment cases remain unchanged.

- [ ] **Step 7: Commit the correction bridge.**

```bash
git add supabase/migrations/20260831090000_school_catering_handoff_allocation.sql supabase/tests/school_catering_planning_correction.sql supabase/tests/issue_222_closed_loop_planning_corrections.sql
git commit -m "fix: preserve school-catering procurement rebalance path"
```

## Task A5: Register APIs, staging capability binding, verifier, and exact catalog expectations

**Interfaces:**
- Consumes: PR-A database objects.
- Produces: current-platform catalog at 107 tables / 96 APIs / 29 capabilities, synthetic Staging role authorized for connected Procurement, repeatable local verification.

- [ ] **Step 1: Add the four PR-A names to documentation/API registry contracts.**

Create `docs/api/school-catering-procurement.md` with exact request/response/capability/security/error/test contracts for all seven final APIs, clearly marking the three PR-B APIs as the next sequential implementation slice rather than callable in PR A.

Add a new implemented/connected school-catering Procurement entry to `docs/api/api-contracts.md`. Amend `docs/ui/pa-06a-operator-workflow-matrix.md` so CMD-05/CMD-06 are explicitly **supplier-direct wholesale**, and add the separate school-catering family/split flow. Update `docs/architecture/roadmap.md` with the connected school-catering Procurement boundary.

- [ ] **Step 2: Bind the two Procurement capabilities to the existing synthetic Staging role package.**

Append to `supabase/packages/atlas-staging-identity.v1.json`:

```json
{
  "role_capability_id": "a1010000-0000-4000-8000-000000000025",
  "capability_code": "procurement.school_catering.read"
},
{
  "role_capability_id": "a1010000-0000-4000-8000-000000000026",
  "capability_code": "procurement.school_catering.write"
}
```

Keep the role code unchanged. Update staging-contract/package tests to expect 17 capabilities for that role after install.

- [ ] **Step 3: Add `scripts/verify-local-school-catering-procurement.mjs` and package script.**

Add:

```json
"local:school-catering-procurement:verify": "node scripts/verify-local-school-catering-procurement.mjs"
```

The verifier must use the existing authenticated local identity flow and perform a bounded school-catering journey through Handoff release, workbench read, 100% recommendation/manual split, and exact readback. It must not create PO drafts in PR A.

- [ ] **Step 4: Register new tests/verifier in Supabase CI.**

Add both new pgTAP files to the smoke/full integration registry where appropriate and include `scripts/verify-local-school-catering-procurement.mjs` in workflow path triggers. Do not duplicate the full-integration runner; extend the existing certification script.

- [ ] **Step 5: Reconcile exact current-platform catalog values from the freshly reset database.**

Update `atlas_current_platform_security_catalog.sql` to assert:

```text
authoritative ordinary tables = 107
capability count/catalog includes the exact two new capability rows
public atlas_api count = 96
new API ownership/grants are exact
all 107 authoritative tables have RLS enabled and forced
```

For policy/RLS digest assertions, compute the actual deterministic catalog from a fresh reset using the same query already embedded in the test and replace the literal expected count/hash with that fresh result. Do not weaken exact catalogs into pattern-only checks.

- [ ] **Step 6: Run focused PR-A certification.**

```bash
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/school_catering_handoff_allocation.sql --local
pnpm exec supabase test db supabase/tests/school_catering_planning_correction.sql --local
pnpm exec supabase test db supabase/tests/atlas_current_platform_security_catalog.sql --local
pnpm local:school-catering-procurement:verify
git diff --check
```

Run only changed-file formatting for JSON/Markdown/JS files if needed. Do not spend Codex time running the entire repository suite locally.

- [ ] **Step 7: Commit PR-A integration metadata.**

```bash
git add docs/api docs/ui/pa-06a-operator-workflow-matrix.md docs/architecture/roadmap.md supabase/tests/atlas_current_platform_security_catalog.sql supabase/packages/atlas-staging-identity.v1.json scripts package.json .github/workflows/supabase-integration.yml
git commit -m "chore: register school-catering procurement allocation"
```

- [ ] **Step 8: Push a draft PR and stop at CI/review gate.**

Do not deploy Staging manually. Push the branch, open the draft PR, and let GitHub Actions run Supabase Smoke, Frontend CI if triggered, Qodana, and the normal checks. Mark ready only after focused review confirms PA-05E wholesale behavior and D-042 reconciliation.

---

# PR B — School-Catering PO Drafts, Release, and Automated Numbering

**Base:** fresh `main` after PR A merge.

**Proposed branch:** `feat/school-catering-procurement-orders`

**Proposed draft PR title:** `Procurement: add school-catering PO drafts and release`

**Expected public API delta:** 96 → 99 functions.

**Expected table delta:** none; alter/reuse shared PO tables only.

**Expected capability delta:** none.

## PR B file map

**Create:**
- `supabase/migrations/20260831120000_school_catering_purchase_orders.sql`
- `supabase/tests/school_catering_purchase_orders.sql`

**Modify:**
- `docs/api/school-catering-procurement.md`
- `docs/api/api-contracts.md`
- `docs/architecture/roadmap.md`
- `supabase/tests/atlas_current_platform_security_catalog.sql`
- `supabase/tests/school_catering_planning_correction.sql`
- the existing PA-05E/PA-05G pgTAP files that pin exact PO column/constraint/API catalogs
- `scripts/verify-local-school-catering-procurement.mjs`
- `scripts/certify-supabase-full-integration.mjs`
- `.github/workflows/supabase-integration.yml`

## Task B1: Freeze the shared-PO compatibility contract in failing tests

**Interfaces:**
- Consumes: PR-A balanced Allocation Family revisions/splits and existing PA-05E Purchase Order tables.
- Produces: failing tests for school-catering PO kind/source XOR, supplier/date DRAFT creation, stale draft regeneration, release numbering, and wholesale compatibility.

- [ ] **Step 1: Create `supabase/tests/school_catering_purchase_orders.sql` with a fixed plan.**

Cover at least:

```text
purchase_orders.purchase_order_kind exists and defaults existing/wholesale inserts to SUPPLIER_DIRECT_WHOLESALE
school-catering root stores service date for supplier/date identity
one current non-cancelled SCHOOL_CATERING PO root per supplier + service date
purchase_order_lines supports exactly one source: wholesale allocation line XOR school-catering Allocation Family
purchase_order_line_revisions supports exactly one source revision: wholesale allocation revision XOR school-catering Supplier Split
school-catering PO revision permits null header delivery_location_id but every line retains location/date
PA-05E wholesale release still writes its original single-destination shape
create drafts only from BALANCED current family revisions
one supplier/date PO contains multiple schools/delivery locations
blocked service date creates no incomplete PO for that date
ready dates in a range can materialize while blocked dates are reported as skipped
allocation change makes only affected supplier/date draft stale
regenerate creates successor DRAFT revision and preserves old draft revision
release rejects stale draft and inactive/ineligible supplier
release generates document number server-side and request has no document-number field
release creates successor RELEASED_TO_SUPPLIER revision, not in-place mutation of DRAFT revision
released PO number is unique and immutable
exact replay returns same released IDs/number
concurrent release produces one valid commitment
```

- [ ] **Step 2: Run the new test and verify failure on missing PO extensions/APIs.**

```bash
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/school_catering_purchase_orders.sql --local
```

- [ ] **Step 3: Run the current PA-05E Procurement suite before schema changes and record its green baseline.**

Use the exact file returned by:

```bash
git ls-files 'supabase/tests/*pa_05e*'
```

Then run each returned PA-05E pgTAP file with `pnpm exec supabase test db <file> --local`. This is the regression baseline; do not modify PA-05E semantics to make the school-catering tests easier.

- [ ] **Step 4: Commit failing PR-B test.**

```bash
git add supabase/tests/school_catering_purchase_orders.sql
git commit -m "test: define school-catering purchase order contract"
```

## Task B2: Extend the shared Purchase Order aggregate without breaking wholesale

**Interfaces:**
- Consumes: current PO root/revision/line tables.
- Produces: explicit PO kind, school-catering root date, source XOR FKs, multi-destination school-catering revision support.

- [ ] **Step 1: Add PO kind and school-catering root service date.**

In `20260831120000_school_catering_purchase_orders.sql`:

```sql
alter table atlas_procurement.purchase_orders
  add column purchase_order_kind text not null default 'SUPPLIER_DIRECT_WHOLESALE',
  add column school_catering_service_date date;

alter table atlas_procurement.purchase_orders
  add constraint purchase_orders_kind_check
  check (purchase_order_kind in ('SUPPLIER_DIRECT_WHOLESALE','SCHOOL_CATERING'));

alter table atlas_procurement.purchase_orders
  add constraint purchase_orders_school_catering_date_check
  check (
    (purchase_order_kind = 'SCHOOL_CATERING' and school_catering_service_date is not null)
    or
    (purchase_order_kind = 'SUPPLIER_DIRECT_WHOLESALE' and school_catering_service_date is null)
  );
```

Add a partial unique index enforcing one active school-catering PO root per supplier/date for statuses that are not terminal cancellation/supersession. Existing PA-05E insert statements omit both columns and must continue to succeed via the wholesale default.

- [ ] **Step 2: Add explicit source XOR to PO stable lines.**

```sql
alter table atlas_procurement.purchase_order_lines
  alter column fulfilment_allocation_line_id drop not null,
  add column school_catering_allocation_family_id uuid
    references atlas_procurement.school_catering_allocation_families on delete restrict;

alter table atlas_procurement.purchase_order_lines
  add constraint purchase_order_lines_source_xor_check
  check (num_nonnulls(fulfilment_allocation_line_id, school_catering_allocation_family_id) = 1);
```

Add a narrow uniqueness rule preventing duplicate school-catering family lines within one PO root.

- [ ] **Step 3: Add explicit source XOR to PO line revisions.**

```sql
alter table atlas_procurement.purchase_order_line_revisions
  alter column fulfilment_allocation_line_revision_id drop not null,
  add column school_catering_allocation_supplier_split_id uuid
    references atlas_procurement.school_catering_allocation_supplier_splits on delete restrict;

alter table atlas_procurement.purchase_order_line_revisions
  add constraint purchase_order_line_revisions_source_xor_check
  check (num_nonnulls(fulfilment_allocation_line_revision_id, school_catering_allocation_supplier_split_id) = 1);
```

Keep ingredient, ordered quantity, unit, delivery location, and service date non-null.

- [ ] **Step 4: Allow school-catering PO revision header location to be null while preserving wholesale location authority.**

Drop NOT NULL from `purchase_order_revisions.delivery_location_id`. Keep `delivery_location_snapshot` non-null; use the server-generated display summary `Nhiều điểm giao` for school-catering multi-destination drafts/releases. Add a deferred integrity constraint trigger or equivalent exact check that:
- wholesale PO revisions still have non-null header location matching every line location;
- school-catering PO revision kind is consistent with its root;
- every school-catering line service date equals root/revision service date.

- [ ] **Step 5: Re-run PA-05E tests before adding new commands.**

Expected: all historical wholesale assertions continue to pass after only schema extension/catalog updates.

## Task B3: Implement week/range PO draft materialization and stale draft regeneration

**Interfaces:**
- Consumes: BALANCED current Allocation Family revisions and Supplier Splits.
- Produces: `create_school_catering_purchase_order_drafts(request jsonb)`, DRAFT roots/revisions/lines grouped by supplier + service date.

- [ ] **Step 1: Implement strict request contract.**

Use:

```json
{
  "contract_version": "SCHOOL-CATERING-PROCUREMENT.v1",
  "command_id": "uuid",
  "correlation_id": "uuid",
  "idempotency_key": "school-catering-po-drafts:<command-id>",
  "expected_version": 1,
  "requested_by_auth_subject": "uuid",
  "requested_at": "ISO-8601",
  "reason_code": "SCHOOL_CATERING_PO_DRAFTS_CREATED",
  "reason_note": null,
  "payload": {
    "date_start": "2026-08-31",
    "date_end": "2026-09-06"
  }
}
```

`expected_version=1` is an envelope sentinel for this range command; actual currentness is proven from every family/root/split revision under locks.

- [ ] **Step 2: Compute date readiness before any writes.**

For each submitted service date, derive every current family from Handoff truth. A date is ready only if every family is BALANCED and source-current. Return blocked dates with exact family references/reasons. Do not create incomplete supplier POs for a blocked date.

- [ ] **Step 3: Materialize supplier/date DRAFT roots and current revisions for ready dates.**

For each ready supplier/date:
- reuse the existing SCHOOL_CATERING root when one exists and is still draftable;
- otherwise create one root `purchase_order_kind='SCHOOL_CATERING'`, `school_catering_service_date=<date>`, `purchase_order_status='DRAFT'`, `document_number=NULL`, `version=1`;
- create one DRAFT current revision with `delivery_location_id=NULL`, `delivery_location_snapshot='Nhiều điểm giao'`, no release actor/time;
- create one stable PO line per family supplying that supplier/date;
- create one line revision per current accepted Supplier Split, copying exact ingredient, split quantity, unit, delivery location, and service date;
- link stable line to Allocation Family and line revision to Supplier Split.

- [ ] **Step 4: Implement stale-draft successor regeneration.**

If a current DRAFT revision references non-current family/split revisions:
- lock root/current draft;
- set previous revision `is_current=false` and preserve all rows;
- create one successor DRAFT revision with next revision number and predecessor;
- create the current set of line revisions from current accepted splits;
- increment root version;
- never regenerate a root already `RELEASED_TO_SUPPLIER`.

- [ ] **Step 5: Ensure command response lists created/updated/skipped dates and POs.**

Return safe structured results for:
- `created_purchase_order_ids`;
- `regenerated_purchase_order_ids`;
- `ready_dates`;
- `skipped_dates` with blockers;
- emitted/audit IDs;
- authoritative readback summary.

- [ ] **Step 6: Run draft-focused pgTAP until green.**

```bash
pnpm exec supabase test db supabase/tests/school_catering_purchase_orders.sql --local
```

- [ ] **Step 7: Commit draft materialization.**

```bash
git add supabase/migrations/20260831120000_school_catering_purchase_orders.sql supabase/tests/school_catering_purchase_orders.sql
git commit -m "feat: create school-catering purchase order drafts"
```

## Task B4: Implement per-PO release with backend-generated official number

**Interfaces:**
- Consumes: one current source-current SCHOOL_CATERING DRAFT PO.
- Produces: `release_school_catering_purchase_order(request jsonb)` and immutable released successor snapshot.

- [ ] **Step 1: Define strict release payload without a document number.**

```json
{
  "contract_version": "SCHOOL-CATERING-PROCUREMENT.v1",
  "command_id": "uuid",
  "correlation_id": "uuid",
  "idempotency_key": "school-catering-po-release:<command-id>",
  "expected_version": 2,
  "requested_by_auth_subject": "uuid",
  "requested_at": "ISO-8601",
  "reason_code": "SCHOOL_CATERING_PO_RELEASED",
  "reason_note": null,
  "payload": {
    "purchase_order_id": "uuid",
    "expected_purchase_order_revision_id": "uuid"
  }
}
```

Reject unknown fields, especially `document_number`, supplier IDs, lifecycle statuses, or actor overrides.

- [ ] **Step 2: Revalidate every source under deterministic locks.**

Lock supplier, PO root/current revision, school-catering line/split/family revisions, active eligibility rows, and official-number uniqueness guard in deterministic order. Fail closed for stale draft, source-changed family, supplier inactive/ineligible, wrong supplier/date grouping, already released PO, or stale expected version.

- [ ] **Step 3: Generate the official number only inside the release transaction.**

Use this deterministic v1 format with no sequence and no user input:

```sql
format(
  'PO-%s-%s',
  to_char(v_service_date, 'YYYYMMDD'),
  upper(substr(replace(v_purchase_order_id::text, '-', ''), 1, 16))
)
```

The existing unique partial index on non-null `document_number` remains the final collision guard. Do not add a numbering sequence/table or grant sequence mutation.

- [ ] **Step 4: Create a released successor revision instead of mutating the draft snapshot.**

On success:
- set current DRAFT revision `is_current=false`;
- create successor `RELEASED_TO_SUPPLIER` revision with predecessor, actor/time, same service date and multi-destination header summary;
- create successor line revisions that reference the same current Supplier Splits and copy exact quantities/locations/units;
- set PO root `document_number`, `purchase_order_status='RELEASED_TO_SUPPLIER'`, increment version;
- emit one `SchoolCateringPurchaseOrderReleased` domain event and one audit event;
- return the generated number and authoritative PO readback.

- [ ] **Step 5: Prove replay/concurrency/immutability.**

The pgTAP suite must show:
- exact replay returns the identical PO/revision/number;
- same command identity with changed payload returns idempotency conflict;
- two concurrent release attempts produce one supplier commitment;
- released PO cannot be regenerated by draft command;
- upstream family change does not rewrite released PO.

- [ ] **Step 6: Commit release behavior.**

```bash
git add supabase/migrations/20260831120000_school_catering_purchase_orders.sql supabase/tests/school_catering_purchase_orders.sql
git commit -m "feat: release school-catering supplier purchase orders"
```

## Task B5: Add the PO read, D-042 released-commitment gate, exact final catalog, and backend certification

**Interfaces:**
- Consumes: shared PO DRAFT/released data.
- Produces: `get_school_catering_purchase_orders`, D-042 school-catering DRAFT-vs-released correction distinction, final 99-function backend registry.

- [ ] **Step 1: Implement `get_school_catering_purchase_orders`.**

Read payload:

```json
{
  "date_start": "2026-08-31",
  "date_end": "2026-09-06",
  "supplier_ids": [],
  "statuses": [],
  "search": null
}
```

Return supplier/date rows and selected detail with:
- PO root/revision/version;
- DRAFT/released status;
- server-derived stale state;
- supplier display;
- multi-school/destination line detail;
- source family/split revision references;
- official number only after release;
- export readiness;
- blockers/warnings;
- allowed actions/disabled reasons.

- [ ] **Step 2: Extend D-042 classification for DRAFT vs released school-catering POs.**

Required behavior:

```text
school-catering Handoff + Allocation Family + DRAFT PO only -> Planning correction permitted; Handoff invalidated; DRAFT PO becomes derived-stale
school-catering RELEASED_TO_SUPPLIER PO -> BLOCKED_BY_DOWNSTREAM_COMMITMENT
WHOLESALE active Handoff -> existing blocker unchanged
```

Do not mutate DRAFT PO during Planning correction; its stale state derives from non-current source family/split revisions.

- [ ] **Step 3: Update final exact catalogs.**

The final backend after PR B must assert:

```text
authoritative ordinary tables = 107
capabilities = 29
atlas_api functions = 99
```

Add the exact three PR-B names to API ownership/execute catalogs. Recompute exact RLS/policy hashes after a seedless reset rather than weakening them.

- [ ] **Step 4: Extend the local verifier through PO draft and release.**

`pnpm local:school-catering-procurement:verify` must now execute:

```text
released school-catering Handoff
→ workbench family
→ accepted allocation
→ DRAFT PO
→ generated official PO number on release
→ authoritative PO readback
```

Add a separate verifier scenario proving a Planning correction before release makes the old allocation/draft stale and can be rebalanced; do not alter the released-PO case.

- [ ] **Step 5: Run focused PR-B certification.**

```bash
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/school_catering_handoff_allocation.sql --local
pnpm exec supabase test db supabase/tests/school_catering_planning_correction.sql --local
pnpm exec supabase test db supabase/tests/school_catering_purchase_orders.sql --local
pnpm exec supabase test db supabase/tests/atlas_current_platform_security_catalog.sql --local
pnpm local:school-catering-procurement:verify
git diff --check
```

Then run the existing PA-05E and PA-05G pgTAP suites returned by `git ls-files 'supabase/tests/*pa_05e*' 'supabase/tests/*pa_05g*'`.

- [ ] **Step 6: Update API docs/roadmap and commit integration metadata.**

Document all seven APIs as implemented after PR B. Ensure `pa-06a-operator-workflow-matrix.md` continues to separate wholesale and school catering.

```bash
git add docs supabase/tests scripts .github/workflows/supabase-integration.yml
git commit -m "chore: certify school-catering procurement backend"
```

- [ ] **Step 7: Push draft PR and stop for CI/backend review.**

Do not start frontend work until PR B exact-head backend review is accepted and merged.

---

# PR C — Connected Procurement UI and Cross-Stage Certification

**Base:** fresh `main` after PR B merge.

**Proposed branch:** `feat/connected-school-catering-procurement-ui`

**Proposed draft PR title:** `Procurement: connect school-catering allocation and purchase orders`

**Database delta:** none.

**Public API delta:** none; connect the seven reviewed APIs only.

## PR C file map

**Create under `src/modules/atlas/procurement/`:**
- `schoolCateringProcurementModel.ts`
- `schoolCateringProcurementApi.ts`
- `schoolCateringProcurementApi.test.ts`
- `reviewSchoolCateringProcurementApi.ts`
- `SchoolCateringProcurementWorkbench.tsx`
- `SchoolCateringProcurementWorkbench.test.tsx`
- `AllocationFamilyTable.tsx`
- `SupplierSplitPanel.tsx`
- `PurchaseOrderStage.tsx`
- `ProcurementCommandResult.tsx`

**Modify:**
- `src/modules/atlas/connection/atlasRpc.ts`
- `src/modules/atlas/connection/atlasRpc.test.ts`
- `src/modules/atlas/AtlasApp.tsx`
- `src/modules/atlas/AtlasApp.test.tsx`
- `src/modules/atlas/AtlasApp.stories.tsx`
- `src/modules/atlas/review/reviewMode.ts`
- `src/modules/atlas/planning-inputs/PlanningInputsWorkbench.tsx`
- `src/modules/atlas/planning-inputs/confirmed-needs/confirmedNeedApi.ts`
- `src/modules/atlas/planning-inputs/confirmed-needs/confirmedNeedApi.test.ts`
- `src/modules/atlas/planning-inputs/confirmed-needs/ConfirmedNeedReviewWorkbench.tsx`
- `src/modules/atlas/planning-inputs/confirmed-needs/ConfirmedNeedReviewWorkbench.test.tsx`
- `src/modules/atlas/planning-inputs/confirmed-needs/PlanningInputsConfirmedNeedTab.test.tsx`
- `src/styles.css`
- `docs/ui/atlas-current-ui-inventory.md`
- `docs/ui/pa-06a-operator-workflow-matrix.md`
- `scripts/certify-frontend.mjs` only if its explicit module/path inventory requires Procurement registration
- `.github/workflows/supabase-integration.yml` path triggers to include `src/modules/atlas/procurement/**`

## Task C1: Register the seven reviewed APIs in the typed transport

**Interfaces:**
- Consumes: final 99-function backend registry.
- Produces: frontend allowlist entries and typed Procurement API builders.

- [ ] **Step 1: Write failing `atlasRpc.test.ts` assertions for the exact seven names.**

Add expected names:

```ts
"atlas_api.release_school_catering_purchase_handoff"
"atlas_api.save_school_catering_supplier_allocation"
"atlas_api.confirm_school_catering_supplier_recommendations"
"atlas_api.create_school_catering_purchase_order_drafts"
"atlas_api.release_school_catering_purchase_order"
"atlas_api.get_school_catering_procurement_workbench"
"atlas_api.get_school_catering_purchase_orders"
```

Run:

```bash
pnpm exec vitest run src/modules/atlas/connection/atlasRpc.test.ts
```

Expected: FAIL until allowlist is extended.

- [ ] **Step 2: Add exactly those seven entries to `ATLAS_RPC_FUNCTIONS`.**

Do not expose private tables or add generic dynamic RPC invocation.

- [ ] **Step 3: Create `schoolCateringProcurementModel.ts`.**

Define frontend read-model types that mirror shaped backend responses, including:

```ts
type AllocationFamilyState =
  | "UNALLOCATED"
  | "BALANCED"
  | "STALE_REBALANCE_AVAILABLE"
  | "NEEDS_REALLOCATION"
  | "BLOCKED";

type ProcurementStage = "allocation" | "orders";
```

Use string quantities from JSON where precision matters; convert for display only at component boundaries.

- [ ] **Step 4: Create `schoolCateringProcurementApi.ts` with exact request builders.**

Define `SCHOOL_CATERING_PROCUREMENT_RPC_FUNCTIONS` and builders for the two reads and four Procurement commands. Add the Planning handoff request builder to the existing Confirmed Need API module because Planning owns that command.

All command builders generate fresh `command_id`, `correlation_id`/idempotency intent consistent with current Atlas patterns and never accept a document number.

- [ ] **Step 5: Write API unit tests for request shape and prohibited fields.**

Assert:
- exact contract versions;
- exact payload allowlists;
- family manual save carries source fingerprint and complete split set;
- bulk confirm carries explicit candidate list;
- PO release request contains only PO identity/current revision and no `document_number`.

- [ ] **Step 6: Run focused API tests and commit.**

```bash
pnpm exec vitest run src/modules/atlas/connection/atlasRpc.test.ts src/modules/atlas/procurement/schoolCateringProcurementApi.test.ts src/modules/atlas/planning-inputs/confirmed-needs/confirmedNeedApi.test.ts
git add src/modules/atlas/connection src/modules/atlas/procurement src/modules/atlas/planning-inputs/confirmed-needs/confirmedNeedApi.ts src/modules/atlas/planning-inputs/confirmed-needs/confirmedNeedApi.test.ts
git commit -m "feat: register school-catering procurement API"
```

## Task C2: Connect Planning’s `Chuyển sang lên đơn` to the durable two-command boundary

**Interfaces:**
- Consumes: current Confirmed Need release and new Planning Handoff release.
- Produces: one visible operator action with recoverable intermediate state and navigation callback after Handoff success.

- [ ] **Step 1: Write failing workbench tests for the three transition outcomes.**

Required cases:

```text
Confirmed Need release fails -> no Handoff command is attempted
Confirmed Need release succeeds, Handoff release fails -> show valid intermediate state and retry Handoff only
both succeed -> authoritative state refresh + invoke onPurchaseHandoffReleased
```

Also preserve current service-date/no-demand safety tests from PR #235 and the current stage-local dirty behavior.

- [ ] **Step 2: Extend Confirmed Need API with `releasePurchaseHandoff`.**

Use exact RPC `atlas_api.release_school_catering_purchase_handoff` and contract `SCHOOL-CATERING-HANDOFF.v1`.

- [ ] **Step 3: Implement the two-command handler in `ConfirmedNeedReviewWorkbench`.**

Do not create a backend transaction spanning the two commands. Treat first-command success as durable. Persist no fake local rollback state.

When the batch is already `RELEASED_FOR_PURCHASE_HANDOFF` and no Handoff exists, show `Chuyển sang lên đơn` as retry of Handoff creation only.

- [ ] **Step 4: Thread `onPurchaseHandoffReleased` through `PlanningInputsWorkbench` to Atlas shell.**

The callback navigates to Procurement after successful Handoff release. Do not move Procurement authority into Planning components.

- [ ] **Step 5: Run focused Planning tests.**

```bash
pnpm exec vitest run \
  src/modules/atlas/planning-inputs/confirmed-needs/ConfirmedNeedReviewWorkbench.test.tsx \
  src/modules/atlas/planning-inputs/confirmed-needs/PlanningInputsConfirmedNeedTab.test.tsx
```

- [ ] **Step 6: Commit the Planning transition.**

```bash
git add src/modules/atlas/planning-inputs src/modules/atlas/AtlasApp.tsx src/modules/atlas/AtlasApp.test.tsx
git commit -m "feat: hand Planning demand to Procurement"
```

## Task C3: Build the `Phân bổ nhà cung ứng` workbench stage

**Interfaces:**
- Consumes: `get_school_catering_procurement_workbench`, manual save, bulk recommendation confirm.
- Produces: dense Allocation Family master table, attached split editor, backend-governed states/actions.

- [ ] **Step 1: Create a review fixture API before the UI.**

`reviewSchoolCateringProcurementApi.ts` must provide deterministic scenarios for:
- ready/default recommendations;
- balanced manual split;
- unallocated;
- stale rebalance available;
- needs reallocation due to ineligible supplier;
- permission denied;
- retryable transport failure;
- stale version;
- replay success;
- empty scope.

The fixture must implement the same API interface as connected mode; do not reuse the old `src/modules/procurement` fixture domain as authority.

- [ ] **Step 2: Write failing `SchoolCateringProcurementWorkbench.test.tsx` for the allocation stage.**

Assert:
- one visible row per Allocation Family, not per raw Handoff contribution;
- columns: `Ngày giao`, `Trường / điểm giao`, `Nguyên liệu`, `Nhu cầu`, `Đã phân bổ`, `Còn lại / chênh lệch`, `NCC`, `Trạng thái`;
- selecting a row opens an attached contextual split panel;
- priority-1 recommendation is visible but not persisted until action;
- two-supplier split quantities must submit the complete family snapshot;
- bulk confirmation only submits explicitly selected/current recommendation candidates;
- technical IDs/trace are hidden behind disclosure;
- one dominant action for the current operator job;
- persistent command result remains after success/failure instead of toast-only feedback.

- [ ] **Step 3: Implement `AllocationFamilyTable.tsx`.**

Use 14px practical table text and local table overflow only where necessary. Ingredient, school/location, and supplier names visually dominate IDs. Search covers school, destination, ingredient, supplier. Filters include:

```text
Chưa phân bổ
Chưa đủ / lệch
Đã đủ
Cần phân bổ lại
NCC không phù hợp
```

Do not add summary-card walls or per-row action toolbars.

- [ ] **Step 4: Implement `SupplierSplitPanel.tsx`.**

The panel shows family total/unit, eligible suppliers ordered by priority, current/previous ratios, editable quantities, rebalance proposal when supplied by backend, and exact running total/difference for operator feedback. The backend remains final authority; client arithmetic is presentation-only.

Actions:
- `Lưu phân bổ` for one edited family;
- `Xác nhận phân bổ đề xuất` at workbench scope for explicit untouched recommendation candidates.

- [ ] **Step 5: Implement `ProcurementCommandResult.tsx`.**

Persistent panel fields:
- safe result message;
- affected family/PO/supplier objects;
- returned current versions;
- warnings/blockers;
- retry/stale/replay/unknown-outcome classification;
- next permitted action.

Unknown write outcome must require authoritative reload before a new mutation intent.

- [ ] **Step 6: Implement shared light Procurement context strip.**

Show only date/week, multi-school/location scope, search, exception filters, refresh/currentness. Keep stage tabs and primary action out of an overcrowded Planning-style rail.

- [ ] **Step 7: Run focused allocation UI tests and commit.**

```bash
pnpm exec vitest run src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.test.tsx
git add src/modules/atlas/procurement src/styles.css
git commit -m "feat: add supplier allocation workbench"
```

## Task C4: Build the `Đơn mua` stage

**Interfaces:**
- Consumes: PO read, draft creation, per-PO release.
- Produces: supplier/date DRAFT/released list, selected PO detail, automated-number release, export-ready surface.

- [ ] **Step 1: Add failing tests for PO-stage behavior.**

Assert:
- stage selector has only `Phân bổ nhà cung ứng` and `Đơn mua`;
- `Tạo đơn mua` materializes a selected date/week through one backend command;
- blocked dates are rendered as persistent exceptions without hiding ready-date results;
- PO list groups by supplier + service date;
- selected PO shows multi-school line detail;
- no editable supplier/quantity controls in PO detail;
- no official-number input exists anywhere;
- stale draft disables `Phát hành cho NCC` and offers `Tạo lại đơn cần cập nhật` through draft materialization;
- release result shows generated official number;
- released PO is read-only;
- bulk release invokes independent per-PO commands and preserves successful results when another PO fails.

- [ ] **Step 2: Implement `PurchaseOrderStage.tsx`.**

Primary supplier/date table/list fields:
- supplier;
- service date;
- line count;
- destinations/schools summary;
- status;
- official number if released;
- blocker/stale indicator.

Selected detail shows ingredient, school/destination, quantity, unit, and release context. Export controls are secondary and visible only when backend read says export-ready.

- [ ] **Step 3: Implement draft/release handlers with late-result safety.**

Follow current Planning patterns:
- discard late async results after scope/stage reload;
- never automatically retry a write;
- exact replay is safe success;
- retryable transport errors present explicit retry;
- unknown mutation outcome requires readback before another command.

- [ ] **Step 4: Run focused PO-stage tests and commit.**

```bash
pnpm exec vitest run src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.test.tsx
git add src/modules/atlas/procurement src/styles.css
git commit -m "feat: add school-catering purchase order stage"
```

## Task C5: Enable Procurement navigation and connected/review mode

**Interfaces:**
- Consumes: connected/review Procurement API implementations.
- Produces: routed `Kế hoạch mua hàng` page in Atlas shell.

- [ ] **Step 1: Add `procurement` to the Atlas page ID union and enable sidebar navigation.**

Replace the disabled `Kế hoạch mua hàng · Chưa triển khai` item with an active route. Keep Warehouse disabled.

If changing the legacy type name `MasterDataPageId` would create widespread unrelated churn, retain the type name in this PR and add `"procurement"`; record renaming as non-blocking cleanup outside this slice.

- [ ] **Step 2: Wire connected mode.**

Create one `createSchoolCateringProcurementApi(transport)` in the shell and pass the authenticated `authState` to the new workbench. No direct Supabase table calls are permitted in Procurement components.

- [ ] **Step 3: Wire review mode and Storybook scenarios.**

Add review-mode scenarios necessary to inspect allocation, rebalance, PO draft, stale PO, released PO, denied, and failure states. Do not add dozens of backend-status stories; prioritize operator-visible states.

- [ ] **Step 4: Update AtlasApp tests.**

Assert Procurement navigation is enabled and renders the connected/review workbench. Assert old `src/modules/procurement/ProcurementWorkbench.tsx` is not imported into AtlasApp.

- [ ] **Step 5: Update UI inventory/operator matrix.**

`docs/ui/atlas-current-ui-inventory.md` should move Procurement from dormant prototype to connected UI only when this PR provides it. Preserve the explicit wholesale-vs-school-catering distinction in the operator matrix.

- [ ] **Step 6: Run focused shell/UI tests and commit.**

```bash
pnpm exec vitest run \
  src/modules/atlas/AtlasApp.test.tsx \
  src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.test.tsx \
  src/modules/atlas/procurement/schoolCateringProcurementApi.test.ts

git add src/modules/atlas docs/ui .github/workflows/supabase-integration.yml
git commit -m "feat: connect Procurement in Atlas shell"
```

## Task C6: Cross-stage operational regression and hosted visual certification

**Interfaces:**
- Consumes: complete connected Planning → Procurement flow.
- Produces: evidence that upstream edits propagate safely, v1 family behavior is preserved, and the new UI meets the hosted review bar.

- [ ] **Step 1: Add a cross-stage integration test focused on realistic back-and-forth changes.**

The test journey must cover:

```text
Planning Confirmed Need release
→ school-catering Handoff release
→ family workbench shows correct aggregate
→ confirm priority-1 or manual split
→ create DRAFT PO
→ upstream Planning correction before PO release
→ Handoff invalidated and corrected/re-released
→ family shows STALE_REBALANCE_AVAILABLE
→ accept ratio-preserving rebalance
→ only affected supplier/date DRAFT becomes stale/regenerated
→ release one PO
→ subsequent upstream correction is blocked by downstream supplier commitment
```

Do not replace local unit/contract tests; this cross-stage test proves propagation/preservation across module boundaries.

- [ ] **Step 2: Add frontend regression for the exact v1 family reason.**

Use a fixture where 100 kg is split 60/40, source becomes 120 kg, read model proposes 72/48, operator confirms, and UI renders exact 120/120 balance. Add a separate supplier-ineligible case that produces `Cần phân bổ lại` rather than automatic redistribution.

- [ ] **Step 3: Run focused frontend certification.**

```bash
pnpm exec vitest run \
  src/modules/atlas/connection/atlasRpc.test.ts \
  src/modules/atlas/planning-inputs/confirmed-needs/ConfirmedNeedReviewWorkbench.test.tsx \
  src/modules/atlas/procurement/schoolCateringProcurementApi.test.ts \
  src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.test.tsx \
  src/modules/atlas/AtlasApp.test.tsx
pnpm typecheck
pnpm build:review
git diff --check
```

Do not run full `pnpm test` locally unless a focused failure suggests a broader regression. GitHub Actions owns the full suite.

- [ ] **Step 4: Push a draft PR and let GitHub Actions certify exact head.**

Required external checks:
- Frontend CI;
- Supabase Smoke because `src/modules/atlas/procurement/**` and connection/planning paths are connected to backend APIs;
- Supabase Full Integration when PR is marked ready after review;
- Qodana;
- Cloudflare Pages preview.

- [ ] **Step 5: Chrome-review the exact-head Cloudflare preview at 1366×768 and 1920×1080.**

Inspect:
- lighter Procurement context strip does not repeat Planning rail crowding;
- family table is the dominant work surface;
- split panel remains attached/contextual;
- no summary-card wall;
- no nested tabs;
- no manual document-number field;
- one dominant action at a time;
- no page/workbench horizontal overflow;
- local table scrolling only where intentional;
- Vietnamese copy is natural and backend codes are not primary labels;
- result panels remain visible after commands;
- empty, denied, stale/rebalance, retryable, replay, DRAFT, stale-DRAFT, and released states are visually coherent;
- browser console has no new warnings/errors.

- [ ] **Step 6: Fix only defects found in hosted review, using focused tests first.**

Do not redesign the approved two-stage workbench during polish. Any change to Allocation Family authority, supplier/date PO grain, numbering, or release lifecycle requires a new architecture decision rather than a CSS pass.

- [ ] **Step 7: Final exact-head verification and review gate.**

After the last hosted correction:
- confirm branch exact head;
- confirm required GitHub checks on that head;
- review changed-file boundary for no Retool/Live OPS/credentials/unrelated domains;
- keep PR unmerged until user accepts the hosted Procurement workflow.

---

# Implementation-Plan Self-Review Checklist

Before handing any PR prompt to Codex, verify these exact coverage points:

- [ ] Spec Section 2: PA-05E wholesale contract remains untouched semantically.
- [ ] Spec Sections 4–5: Planning Handoff release and Allocation Family key/lineage implemented.
- [ ] Spec Sections 6–8: priority recommendation, exact splits, ratios, and rebalance implemented backend-first.
- [ ] Spec Section 9: shared PO aggregate extended with explicit source XOR, not duplicated.
- [ ] Spec Sections 10–11: DRAFT generation, stale regeneration, backend numbering, and immutable release implemented.
- [ ] Spec Sections 12–13: exact five commands + two reads registered; final API count 99.
- [ ] Spec Sections 14–15: two-stage UI, lighter context, dense master/detail, persistent outcomes, recovery states implemented.
- [ ] D-042 reconciliation: school-catering correction allowed before released PO; wholesale behavior unchanged; released PO blocks correction.
- [ ] Staging package: existing synthetic role has 17 capabilities after Procurement binding; no new role.
- [ ] Exact platform catalog: 107 authoritative ordinary tables, 29 capabilities, 99 APIs after PR B.
- [ ] No manual official PO number field in backend request or UI.
- [ ] No direct table access from React.
- [ ] No Retool, Live OPS, Warehouse, Dispatch, Finance, or released-PO correction behavior added.
- [ ] Cross-stage test proves Planning edit → stale/rebalance → DRAFT regeneration → release → downstream correction block.

---

# Codex Execution Prompts

Use one fresh Codex thread per PR to minimize context and credit usage. Do not paste the entire repository history; point Codex to the approved spec and this plan.

## Codex Prompt — PR A

**Recommended settings:** GPT-5.6 Sol · Medium reasoning · one agent · parallel agents off · subagents off.

```text
Implement PR A from the approved School-Catering Procurement design.

Repository: longpsu-bot/thuonghao-ops-erp
Authority:
- OPS_SYSTEM_MAP v1.0 / ARCH-002
- docs/superpowers/specs/2026-08-31-school-catering-procurement-connected-design.md
- docs/superpowers/plans/2026-08-31-school-catering-procurement-connected.md

Scope: PR A only — Planning school-catering Purchase Handoff, Allocation Family persistence/commands/read, and D-042 correction reconciliation.

Before edits:
1. Fetch origin/main.
2. Verify the approved spec/plan are present; if they are not yet on main, start from the docs branch containing them rather than re-deriving architecture.
3. Confirm current Atlas catalog baseline; stop if Planning/Procurement contracts materially differ from the plan.

Implement Tasks A1–A5 exactly with TDD. Preserve PA-05E wholesale behavior. Do not implement PO drafts/UI yet. Do not mutate hosted Staging, Live OPS, Retool, credentials, or production data.

Critical invariant: school-catering upstream Planning correction remains possible before supplier PO release. D-042 must remain blocking for WHOLESALE active Handoff. School-catering correction invalidates the current Handoff revision/history safely; corrected release creates a SUPERSEDING current Handoff revision; Allocation Family history becomes stale/rebalanceable rather than being rewritten.

Use targeted local pgTAP/verifier checks only. GitHub Actions owns the full suite. Keep the PR Draft and stop after exact-head CI/review evidence. Report changed files, focused test results, catalog deltas, PA-05E regression result, and any deviation from the approved plan.
```

## Codex Prompt — PR B

**Recommended settings:** GPT-5.6 Sol · Medium reasoning · one agent · parallel agents off · subagents off.

```text
Implement PR B from the approved School-Catering Procurement design after PR A is merged.

Repository: longpsu-bot/thuonghao-ops-erp
Authority:
- OPS_SYSTEM_MAP v1.0 / ARCH-002
- docs/superpowers/specs/2026-08-31-school-catering-procurement-connected-design.md
- docs/superpowers/plans/2026-08-31-school-catering-procurement-connected.md

Scope: PR B only — shared Purchase Order extensions, school-catering supplier/date DRAFT materialization, stale-DRAFT successor regeneration, per-PO release with backend-generated official number, PO read, and final backend catalog/correction gates.

Implement Tasks B1–B5 with TDD. Reuse the existing PO aggregate. Preserve PA-05E wholesale PO behavior and exact tests. Do not add a second PO subsystem, a numbering sequence/service, supplier acknowledgement, released-PO amendment/cancellation, UI, Warehouse, Dispatch, Finance, Retool, or hosted mutations.

Official PO number must be generated in the release transaction; the request accepts no document number. Released PO is immutable. A school-catering DRAFT PO does not block Planning correction; a RELEASED_TO_SUPPLIER PO does.

Use targeted local pgTAP/verifier checks only. GitHub Actions owns full certification. Keep Draft until backend exact-head CI and review are accepted. Report final exact catalog totals (107 tables, 29 capabilities, 99 APIs), PA-05E/PA-05G regression results, and any deviation.
```

## Codex Prompt — PR C

**Recommended settings:** GPT-5.6 Sol · Medium reasoning · one agent · parallel agents off · subagents off.

```text
Implement PR C from the approved School-Catering Procurement design after PR B is merged.

Repository: longpsu-bot/thuonghao-ops-erp
Authority:
- OPS_SYSTEM_MAP v1.0 / ARCH-002
- docs/superpowers/specs/2026-08-31-school-catering-procurement-connected-design.md
- docs/superpowers/plans/2026-08-31-school-catering-procurement-connected.md

Scope: PR C only — connect the seven reviewed APIs, make Planning's “Chuyển sang lên đơn” execute the durable two-command boundary with recoverable intermediate state, enable Kế hoạch mua hàng, and build the two-stage connected Procurement UI: “Phân bổ nhà cung ứng” and “Đơn mua”.

Do not reuse the dormant src/modules/procurement/ProcurementWorkbench.tsx as authority. Use a new src/modules/atlas/procurement connected module. The visible allocation row is one Allocation Family, not one raw Purchase Handoff line. Preserve v1 family split/rebalance behavior through backend-shaped reads.

Visual direction: lighter than Planning's rail; dense table-first master/detail; 14px practical table text; row selection + contextual split panel; no summary-card wall; no nested tabs; no manual PO-number field; technical trace behind disclosure; persistent command outcomes and recovery guidance; natural Vietnamese; one dominant action at a time.

Implement Tasks C1–C6 with TDD. Use focused Vitest/typecheck/build checks locally; GitHub Actions owns the full suite. After exact-head Cloudflare deploy, Chrome-review 1366x768 and 1920x1080 and fix only concrete hosted defects. Keep Draft and do not merge until user accepts the hosted UI.
```

---

# Execution Handoff

The implementation sequence is strictly **PR A → PR B → PR C**. Do not start PR B before PR A is merged; do not start PR C before PR B is merged. Each PR must re-fetch `origin/main`, verify its expected predecessor is present, and stop on material contract drift rather than improvising a new architecture.
