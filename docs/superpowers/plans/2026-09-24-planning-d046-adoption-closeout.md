# Planning D-046 Adoption Closeout Implementation Plan

> Closeout execution clarification (26/09/2026): the historical `OUTDATED` and
> pristine two-receipt assumptions below are superseded by the
> [current-source recovery contract](../../implementation-tasks/TASK-PLANNING-HOSTED-CLOSEOUT.md#final-d-046--d-047-current-source-recovery--26092026).
> Source currentness remains `CURRENT`; exact D-047 predecessor evidence derives
> regeneration independently. Receipt proof accepts one original, at most one
> qualified benign `NO_CHANGE`, and exactly one successful correction.

> **For the implementing agent:** REQUIRED SUB-SKILL: Use superpowers:executing-plans with one lead agent. Do not dispatch implementation subagents. One independent whole-branch review is allowed only after implementation is complete. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repair the proven OPS-v1 Recipe Unit adoption defect through immutable successors, keep D-046 fail-closed, and make the protected 17/09 closeout certify the corrected D-046 state.

**Architecture:** Preserve each raw BoM Unit as source evidence while deriving the adopted operational Recipe Unit from the mapped Ingredient purchase Unit. Record every allowed Unit transition in a private immutable provenance relation, require that evidence for the sole Planning cross-Unit exception, and use the existing Need Generation correction command to rematerialize the preserved batch. The native Cánh gà mismatch receives no evidence and remains blocked.

**Tech Stack:** PostgreSQL 17/Supabase migrations and pgTAP, Node.js 24 ESM, Vitest 4, GitHub Actions, existing RMVP-04/RMVP-05 contracts.

**Spec:** `docs/implementation-tasks/TASK-PLANNING-D046-ADOPTION-CLOSEOUT.md`

## Global Constraints

- Start from exact `origin/main` SHA `55a9fb2702043fba7c8f3a7d8cdcc43a76577808` on `fix/planning-d046-adoption-closeout`.
- Use one lead agent and Native/inline execution; do not dispatch subagents.
- Live OPS v1 and Retool are strictly read only; PR #286 and Procurement are untouched.
- Do not merge, deploy, run protected workflows, or perform Staging business writes.
- Preserve exact quantities, immutable history, source fingerprints, RLS, idempotency, optimistic concurrency, and unknown-outcome protection.
- Do not add conversion, alias inference, a generic bypass flag, a new public command, a new business lifecycle, a major dependency, a timeout increase, or a retry.
- Run each RED test and observe the named failure before implementing its GREEN change.
- Create the migration with `pnpm exec supabase migration new planning_legacy_adoption_unit_repair`; use the exact generated path in all later commands and commits.

## Review Focus

- A mapped OPS-v1 line whose raw Unit differs but quantity is equal must pass only when every mapping and predecessor fact agrees; delete one mapping in the fixture and assert fail-closed behavior.
- A Recipe version containing two repaired lines must receive one successor containing all siblings exactly once; assert version and line cardinalities, not just values.
- A native or partially mapped Recipe must never enter the repair or Planning exception; keep the Cánh-style fixture blocked through release and D-046.
- A correction that changes Unit and merges groups must not carry a human decision across the changed identity; assert zero fabricated/carry evidence for the changed groups.
- An uncertain one-shot hosted correction outcome must trigger readback only and never a second RPC; inject a transport failure after dispatch and assert one call.

---

### Task 1: Lock the defect with extractor and adoption RED tests

**Files:**

- Modify: `scripts/ops-v1-master-snapshot-contract.test.mjs`
- Modify: `supabase/tests/master_data_rehearsal_recipe_import.sql`

**Interfaces:**

- Consumes: existing `normalizeOpsV1MasterSnapshot(raw, options)` and `atlas_legacy.preview_master_data_snapshot(jsonb)`.
- Produces: fixtures proving raw `unit_legacy_id` remains source evidence while the planned Atlas `unit_id` equals the Ingredient purchase Unit.

- [ ] **Step 1: Add the raw-versus-operational snapshot regression**

Add a fixture with Ingredient `956`, Ingredient purchase Unit `Kg`, BoM label
`Cái`, and usable quantity `12`. Assert the normalized line retains `Cái`, the
Ingredient retains `Kg`, and both facts participate in deterministic output:

```js
assert.equal(snapshot.records.ingredients[0].purchase_unit_legacy_id, "kg");
assert.equal(snapshot.records.recipe_lines[0].unit_legacy_id, "Cái");
assert.equal(snapshot.records.recipe_lines[0].quantity_per_basis, "12");
assert.notEqual(
  snapshot.records.ingredients[0].purchase_unit_legacy_id,
  snapshot.records.recipe_lines[0].unit_legacy_id,
);
```

Repeat with `Quả → Trái` and `Bịch → Chai`; do not add aliases.

- [ ] **Step 2: Add failing pgTAP adoption assertions**

Extend the rehearsal fixture with one mismatched and one already-correct line.
After apply, assert operational Unit authority, unchanged quantity, raw evidence,
one successor only, correct-row stability, and replay:

```sql
select is(corrected.unit_id, ingredient.purchase_unit_id,
  'legacy adoption uses Ingredient purchase Unit operationally');
select is(corrected.quantity_per_basis, 12.000000::numeric,
  'legacy adoption performs no numeric conversion');
select is(raw_line->>'unit_legacy_id', 'legacy-unit-cai',
  'raw BoM Unit remains auditable');
select is((replay->>'status'), 'REPLAYED',
  'same snapshot replay is idempotent');
select is(unchanged_successor_count, 0::bigint,
  'already-correct Recipes are not unnecessarily revised');
```

Add a partially mapped/native row and assert it is blocked rather than repaired.

- [ ] **Step 3: Run the RED tests**

Run:

```powershell
pnpm vitest run scripts/ops-v1-master-snapshot-contract.test.mjs
pnpm exec supabase test db supabase/tests/master_data_rehearsal_recipe_import.sql --local
```

Expected: the Node source-evidence assertions pass; pgTAP fails because the
current importer materializes the raw BoM Unit as `recipe_line_revisions.unit_id`.

- [ ] **Step 4: Commit the RED tests**

```powershell
git add scripts/ops-v1-master-snapshot-contract.test.mjs supabase/tests/master_data_rehearsal_recipe_import.sql
git commit -m "test(planning): expose legacy recipe unit adoption defect"
```

### Task 2: Add private transition evidence and repair future/current adoption

**Files:**

- Create: the exact migration path returned by Step 1 and stored in `$migrationPath`
- Modify: `supabase/tests/master_data_rehearsal_recipe_import.sql`
- Modify: `supabase/tests/atlas_current_platform_security_catalog.sql`

**Interfaces:**

- Consumes: `atlas_legacy.master_data_mappings`, completed import reconciliation, `atlas_admin.recipe_versions`, and mapped Ingredient purchase Units.
- Produces: `atlas_legacy.recipe_unit_adoption_evidence` and corrected definitions of `master_recipe_composition`, `master_import_recipe_plan`, `master_import_apply_recipes`, and the Recipe release integrity guard.

- [ ] **Step 1: Generate the forward migration**

Run:

```powershell
pnpm exec supabase migration new planning_legacy_adoption_unit_repair
```

Record the returned filename as `$migrationPath`; do not edit an older
migration.

- [ ] **Step 2: Create the private immutable evidence relation**

Implement the exact relation and indexes described by the spec. The core shape
must include these constraints:

```sql
evidence_kind text not null check (
  evidence_kind in (
    'OPS_V1_INGREDIENT_PURCHASE_UNIT_ADOPTION',
    'OPS_V1_BOM_UNIT_TO_INGREDIENT_PURCHASE_UNIT_CORRECTION'
  )
),
source_system text not null check (source_system = 'OPS_V1'),
quantity_per_basis numeric(20,6) not null check (quantity_per_basis > 0),
check (source_unit_id <> corrected_unit_id),
unique (target_recipe_line_revision_id),
unique nulls not distinct (
  predecessor_recipe_line_revision_id,
  target_recipe_line_revision_id
)
```

Enable and force RLS; revoke all from `public`, `anon`, `authenticated`, and
`service_role`. Grant only INSERT/SELECT needed by the existing private
master-data runtime and SELECT needed by the private Planning materialization
runtime, with matching explicit RLS policies; grant no UPDATE or DELETE. Add an
immutable insert guard that verifies direct version and line-revision
predecessors, same Recipe/stable line/Ingredient/quantity, raw mapped Unit,
completed import evidence, and current Ingredient purchase Unit.

- [ ] **Step 3: Change future import Unit authority without changing raw facts**

Replace the operational Unit expression in both composition and planned line
revision values with the mapped Ingredient purchase Unit:

```sql
select ingredient.purchase_unit_id
from atlas_admin.ingredients ingredient
where ingredient.ingredient_id =
  atlas_legacy.master_import_target_id(
    snapshot, 'INGREDIENT', source_line->>'ingredient_legacy_id'
  )
```

Continue resolving `source_line->>'unit_legacy_id'` independently for raw
evidence and validation. When it differs from the adopted Unit,
`master_import_apply_recipes` writes an immutable
`OPS_V1_INGREDIENT_PURCHASE_UNIT_ADOPTION` evidence row for the new revision. A
missing raw Unit or purchase Unit blocks the plan.

Keep the ordinary `RECIPE_COMMITTED_USE` guard in
`master_import_recipe_plan`/`master_import_apply_recipes`. Only the private
migration-owned reconciliation block may cross that guard, and only for the
exact provenance-qualified Unit repair. It exposes no callable edit endpoint.

- [ ] **Step 4: Implement deterministic current-data reconciliation**

Build the candidate set entirely from authoritative mappings and completed
import evidence. An empty database/no completed OPS-v1 import is a no-op. When
eligible rows exist, assert before commit:

```sql
transitioned_line_count = eligible_line_count
and transitioned_recipe_count = eligible_recipe_count
and successor_present_line_count = corrected_line_count + copied_line_count
```

Lock in Recipe/version/line identifier order. Insert one successor version per
affected released version, copy all line revisions with direct predecessor
links, alter only eligible proven Units, insert one transition row per
correction, validate, lock each predecessor, and release each successor. Use
deterministic UUID derivation so a failed deployment can be diagnosed without
duplicate identities. Update only the existing predecessor mapping's recorded
target version when its lifecycle lock requires drift bookkeeping; do not remap
the source fact to the correction successor or change the original import
batch/source fingerprint. Invoke this private reconciler once at the end of the
migration; expose no public endpoint.

- [ ] **Step 5: Enforce the release boundary**

Patch `atlas_admin.pa_06e_h0a2_recipe_version_integrity_guard()` so a transition
to `RELEASED_FOR_PLANNING` rejects any PRESENT revision where:

```sql
revision.unit_id is distinct from ingredient.purchase_unit_id
```

Use a safe `23514` message. Do not scan or rewrite existing released rows unless
their version is being transitioned by this migration.

- [ ] **Step 6: Extend GREEN and security assertions**

Assert fixture-relative eligible/transitioned equality, exact copied facts,
direct lineage, replay `NO_CHANGE`, immutable predecessor rows, one evidence
row per fixture mismatch, no evidence for the native fixture, clean-reset
no-op installation, forced RLS, no public grants, empty function search paths,
and blocked update/delete attempts. Include a Recipe with two mismatched lines
and prove it gets one successor containing every sibling exactly once. The
protected Staging readback later owns the production-specific 76/74/322/246
assertion.

Also create an operationally used unrelated Recipe change and prove preview or
apply still returns `RECIPE_COMMITTED_USE`; the private reconciler must not
become an alternate post-use Recipe editor.

- [ ] **Step 7: Run focused GREEN tests**

```powershell
pnpm exec supabase db reset --local --no-seed
pnpm exec supabase test db supabase/tests/master_data_rehearsal_recipe_import.sql --local
pnpm exec supabase test db supabase/tests/atlas_current_platform_security_catalog.sql --local
pnpm vitest run scripts/ops-v1-master-snapshot-contract.test.mjs
```

Expected: PASS with fixture-relative eligible = transitioned cardinality, one
successor per affected fixture version, corrected + copied = complete successor
composition, clean-reset no-op behavior, and native/post-use exclusions. Exact
76/74/322/246 is not a local-fixture assertion.

- [ ] **Step 8: Commit the adoption contract**

```powershell
git add $migrationPath supabase/tests/master_data_rehearsal_recipe_import.sql supabase/tests/atlas_current_platform_security_catalog.sql scripts/ops-v1-master-snapshot-contract.test.mjs
git commit -m "fix(master-data): reconcile adopted recipe units"
```

### Task 3: Gate the sole Planning Unit transition by provenance

**Files:**

- Modify: `$migrationPath` from Task 2
- Create: `supabase/tests/planning_legacy_adoption_unit_transition.sql`
- Modify: `supabase/tests/planning_contract_01_atomic_planning_boundaries.sql`
- Modify: `supabase/tests/planning_operational_proposal.sql`

**Interfaces:**

- Consumes: correction rows in `atlas_legacy.recipe_unit_adoption_evidence` and the existing direct theoretical predecessor chain.
- Produces: an internal predicate `atlas_core.planning_legacy_adoption_unit_transition_allowed(predecessor_line_id uuid, successor_line_id uuid)` used by the current materializer definition.

- [ ] **Step 1: Write the failing transition suite**

Create pgTAP fixtures for one fully mapped `Cái → Kilogram` successor with
quantity `12`, one `Quả → Trái`, one `Bịch → Chai`, one native Cánh-style row,
and mutations of each required anchor. Assert:

```sql
select ok(atlas_core.planning_legacy_adoption_unit_transition_allowed(old_id,new_id),
  'proven OPS-v1 transition is eligible');
select throws_ok(native_materialize_sql,
  'SOURCE_SPLIT_MERGE_POLICY_REQUIRED',
  'native mismatch remains blocked');
select is(new_line.theoretical_quantity, old_line.theoretical_quantity,
  'no theoretical quantity conversion occurs');
select is(changed_group_carried_decisions, 0::bigint,
  'changed Unit identity fabricates or carries no decision');
```

For each of mapping, Ingredient, quantity, school, date, customer, location,
predecessor, raw Unit, corrected Unit, and evidence kind, change one fact and
assert false/fail-closed.

- [ ] **Step 2: Run the transition suite RED**

```powershell
pnpm exec supabase test db supabase/tests/planning_legacy_adoption_unit_transition.sql --local
```

Expected: FAIL because the predicate does not exist and the materializer still
rejects every cross-Unit successor.

- [ ] **Step 3: Implement the private exact predicate**

Use one SQL `exists` query joining predecessor/successor theoretical lines,
their Recipe-line revisions, transition evidence, old Confirmed Need
contribution identity, and School customer/default location. Require direct
run and Recipe lineage plus exact equality of:

```sql
predecessor.ingredient_id = successor.ingredient_id
and predecessor.theoretical_quantity = successor.theoretical_quantity
and predecessor.school_id = successor.school_id
and predecessor.service_date = successor.service_date
and evidence.source_unit_id = predecessor.unit_id
and evidence.corrected_unit_id = successor.unit_id
and evidence.quantity_per_basis = successor_revision.quantity_per_basis
```

The function is private, `stable`, `security invoker`, and `search_path = ''`.
Revoke execution from browser roles.

- [ ] **Step 4: Patch the current materializer with a guarded definition replacement**

Hash-check the exact post-D-046 function baseline. Keep the existing tuple guard
and exempt only the Unit inequality when the predicate returns true. School,
date, Ingredient, customer, location, quantity, source membership, and direct
successor checks remain unconditional. Preserve function owner, grants,
security-definer posture, empty search path, volatility, and signature.

- [ ] **Step 5: Extend correction and D-046 assertions**

Prove initial materialization uses corrected Units, correction rematerializes
the same batch, old revisions remain immutable, new revisions snapshot the
corrected Ingredient `order_step`/version, raw totals and membership remain
exact, native mismatches still return
`INGREDIENT_ROUNDING_CONFIGURATION_INVALID`, and no Purchase Handoff appears.

- [ ] **Step 6: Run focused Planning GREEN tests**

```powershell
pnpm exec supabase test db supabase/tests/planning_legacy_adoption_unit_transition.sql --local
pnpm exec supabase test db supabase/tests/planning_operational_proposal.sql --local
pnpm exec supabase test db supabase/tests/planning_contract_01_atomic_planning_boundaries.sql --local
pnpm exec supabase test db supabase/tests/planning_contract_02b_selective_confirmation_continuity.sql --local
pnpm exec supabase test db supabase/tests/rmvp_04_connected_need_generation.sql --local
pnpm exec supabase test db supabase/tests/rmvp_05_connected_confirmed_need_review.sql --local
```

Expected: PASS with the provenance transition accepted and every unproven Unit
change rejected.

- [ ] **Step 7: Commit the Planning transition**

```powershell
git add $migrationPath supabase/tests/planning_legacy_adoption_unit_transition.sql supabase/tests/planning_contract_01_atomic_planning_boundaries.sql supabase/tests/planning_operational_proposal.sql
git commit -m "fix(planning): allow proven adoption unit successors"
```

### Task 4: Prove the corrected protected-date cardinalities

**Files:**

- Modify: `scripts/verify-staging-planning-performance.mjs`
- Modify: `scripts/staging-planning-performance.test.mjs`

**Interfaces:**

- Consumes: rollback-only generated contributions plus transition evidence.
- Produces: `planningAdoptionMergeProofAccepted(row)` and probe rows containing `legacy_group_count`, `corrected_group_count`, `contribution_count_before`, `contribution_count_after`, `merge_count`, `split_count`, and `lost_contribution_count`.

- [ ] **Step 1: Write the 231 RED regression**

Change neither constant initially. Add a behavioral fixture where two old Unit
keys map to one corrected operational key and all remaining groups map 1:1:

```js
assert.deepEqual(projectAdoptionGroups(fixture), {
  legacyGroupCount: 232,
  correctedGroupCount: 231,
  mergeCount: 1,
  splitCount: 0,
  lostContributionCount: 0,
});
```

Add negative cases for one missing contribution, a second merge, a split, and
a constant-only row lacking proof.

- [ ] **Step 2: Run the verifier tests RED**

```powershell
pnpm vitest run scripts/staging-planning-performance.test.mjs
```

Expected: FAIL because merge projection/proof does not exist and 14/09 still
expects 232.

- [ ] **Step 3: Add rollback SQL proof and update approved counts**

Inside the same transaction as each probe, project each active contribution
twice: once with its proven raw adoption Unit and once with its actual corrected
Unit. Aggregate by the full Confirmed Need operational identity. Return bounded
counts only; do not log school, Recipe, Ingredient, or line payloads.

Set probe expectations to:

```js
[
  { date: "2026-09-14", expectedLineCount: 231, requireOneMergeProof: true },
  { date: "2026-09-14", expectedLineCount: 231, requireOneMergeProof: true },
  { date: "2026-09-15", expectedLineCount: 225 },
  { date: "2026-09-16", expectedLineCount: 213 },
  { date: "2026-09-18", expectedLineCount: 210 },
];
```

Require exact 232→231, one merge, zero splits, equal contribution counts, and
zero loss for both 14/09 probes.

- [ ] **Step 4: Run verifier tests GREEN**

```powershell
pnpm vitest run scripts/staging-planning-performance.test.mjs
```

Expected: PASS; timeout remains 8 seconds, threshold remains strictly below 7
seconds, rollback remains mandatory, and failure still stops without retry.

- [ ] **Step 5: Commit the cardinality proof**

```powershell
git add scripts/verify-staging-planning-performance.mjs scripts/staging-planning-performance.test.mjs
git commit -m "test(planning): prove corrected 14 September merge"
```

### Task 5: Gate deployment and prepare the one-shot 17/09 correction

**Files:**

- Create: `scripts/verify-staging-planning-adoption-manifest.mjs`
- Create: `scripts/staging-planning-adoption-manifest.test.mjs`
- Create: `scripts/correct-staging-planning-d046.mjs`
- Create: `scripts/staging-planning-d046-correction.test.mjs`
- Modify: `scripts/verify-staging-planning-closeout.mjs`
- Modify: `scripts/staging-planning-closeout.test.mjs`
- Modify: `scripts/staging-planning-browser.mjs`
- Modify: `scripts/staging-planning-browser.test.mjs`

**Interfaces:**

- Consumes: current OPS-v1 mappings/import reconciliation, the post-migration evidence relation, exact preserved run/batch IDs, existing `execute_need_generation`, authoritative snapshot SQL, and immutable frontend SHA verification.
- Produces: `planningAdoptionManifestSql(phase)`, `classifyPlanningAdoptionManifest(snapshot, phase)`, `classifyD046CorrectionBaseline(snapshot)`, `buildD046CorrectionRequest(snapshot, commandId)`, one-shot `executeD046Correction(...)`, and closeout mode `D046_CORRECTED_RESUME`.

- [ ] **Step 1: Write pre/post-deployment manifest RED tests**

Create bounded fixtures for `pre-deploy` and `post-deploy`. The pre-deploy
classifier must require exactly:

```js
{
  eligibleLineCount: 76,
  affectedReleasedVersionCount: 74,
  projectedSuccessorPresentCount: 322,
  correctedLineCount: 76,
  copiedSiblingCount: 246,
  legacyIngredientIds: ["956", "1012", "1045", "1057"],
  excludedNativeMismatchCount: 1,
  excludedNativeSourceKind: "UIQ03A_SAVE",
}
```

Each candidate must have complete import-batch, mapping, fingerprint, raw Unit,
current Unit, Ingredient purchase Unit, quantity, Recipe version, and stable
line evidence. Reject one extra/missing Ingredient, line, version, sibling,
mapping, or native candidate.

The post-deploy classifier must require the same manifest represented by 76
correction-evidence rows, 74 direct Recipe successors, 322 successor PRESENT
rows, 246 exact sibling copies, locked immutable predecessors, and the same one
excluded native mismatch. It must reject duplicate, missing, or remapped source
evidence.

- [ ] **Step 2: Run the manifest tests RED**

```powershell
pnpm vitest run scripts/staging-planning-adoption-manifest.test.mjs
```

Expected: FAIL because the read-only manifest verifier does not exist.

- [ ] **Step 3: Implement the read-only hosted manifest verifier**

`planningAdoptionManifestSql("pre-deploy")` must use only relations that exist
before this migration and derive the candidate projection from current released
Recipes plus OPS-v1 mappings/import reconciliation. It must not reference the
new evidence table. `planningAdoptionManifestSql("post-deploy")` may query the
new evidence relation and immutable successor lineage. Both SQL variants use
`begin read only` and `rollback`, return bounded counts/IDs rather than payloads,
and perform no RPC or DML.

The CLI requires `--phase pre-deploy|post-deploy`, verifies the exact checkout
SHA, and exits nonzero on any manifest drift. It never applies a migration or
authorizes deployment itself.

- [ ] **Step 4: Write one-shot correction RED tests**

Assert exact preflight IDs/status/version/counts, one RPC at most, no automatic
retry, stable idempotency key for the single logical attempt, and authoritative
readback on a thrown/unknown response:

```js
const result = await executeD046Correction({ invoke, readSnapshot, commandId });
assert.equal(invoke.mock.calls.length, 1);
assert.equal(readSnapshot.mock.calls.length, 2);
assert.equal(result.mode, "D046_CORRECTED_RESUME");
```

Reject any pre-existing decision, Save receipt, Handoff, second correction
receipt, source fingerprint drift, wrong current run, or non-248 current count.
The eligible pre-correction fixture must be `OUTDATED` solely because the
current Recipe successor differs, while selected/current Menu, Attendance, and
Pantry fingerprints remain equal. It must also consume a successful
`post-deploy` adoption manifest; correction is blocked if post-deploy evidence
does not exactly match the pre-deploy authority.

- [ ] **Step 5: Write corrected-checkpoint RED tests**

Replace acceptance of `PRISTINE_GENERATED_RESUME` with a two-run fixture:

```js
assert.deepEqual(classifyPlanningCloseoutBaseline(snapshot), {
  mode: "D046_CORRECTED_RESUME",
  predecessorRunId: RETAINED_RUN,
  currentRunId: successorRunId,
  batchId: RETAINED_BATCH,
  currentLineCount: 248,
  fingerprints,
});
```

Assert predecessor v4 INVALIDATED, direct successor v3 released, both immutable
release snapshots retain 304 contributions, batch v2, origin/current pointers,
two completed generation receipts, 248 current D-046 snapshot pairs, exact
proposal arithmetic, retained null-pair old revisions, zero
decisions/Saves/Handoffs, and one allowed `Quả → Trái` transition.

- [ ] **Step 6: Run correction/closeout tests RED**

```powershell
pnpm vitest run scripts/staging-planning-adoption-manifest.test.mjs scripts/staging-planning-d046-correction.test.mjs scripts/staging-planning-closeout.test.mjs scripts/staging-planning-browser.test.mjs
```

Expected: FAIL because the manifest verifier, one-shot tool, and corrected
classifier do not exist.

- [ ] **Step 7: Implement the one-shot tool**

Default invocation is read-only and reports whether the preserved predecessor
is eligible. Only explicit `--persist-correction` sends one authenticated
`RMVP-04.v3` request using expected predecessor version 3 and
`expected_current_need_generation_run_id = RETAINED_RUN`. Never retry. On an
unknown response, read the authoritative checkpoint and accept only the exact
single-successor state.

- [ ] **Step 8: Extend checkpoint SQL and classifier**

Return ordered run lineage, total and current Recipe/Confirmed Need counts,
proposal snapshot validity counts, exact-rounding validity counts, retained
pre-D-046 null-pair count, transition count, receipt command IDs/outcomes, and
source fingerprints. Before allowing the correction, the read-only classifier
must also prove 76 correction evidence rows across 74 Recipe successors, 322
successor PRESENT rows, 76 corrected rows, and 246 exact sibling copies. Keep
the SQL `begin read only ... rollback`.

Require `D046_CORRECTED_RESUME` before browser Save. Remove the old pristine
mode from protected acceptance; retain it only as an explicitly rejected
diagnostic if useful.

- [ ] **Step 9: Update final browser proof**

After Save require the same predecessor/successor run lineage, batch v3, 248
current decisions, one adjustment, 247 proposal acceptances, one Save receipt,
zero Generate clicks, one Save click, unchanged fingerprints/raw/proposals, and
zero Purchase Handoffs. Browser selectors remain semantic and the immutable
candidate SHA check remains mandatory.

- [ ] **Step 10: Run manifest/correction/closeout tests GREEN**

```powershell
pnpm vitest run scripts/staging-planning-adoption-manifest.test.mjs scripts/staging-planning-d046-correction.test.mjs scripts/staging-planning-closeout.test.mjs scripts/staging-planning-browser.test.mjs
node --check scripts/verify-staging-planning-adoption-manifest.mjs
node --check scripts/correct-staging-planning-d046.mjs
node --check scripts/verify-staging-planning-closeout.mjs
```

Expected: PASS with no hosted call executed.

- [ ] **Step 11: Commit deployment/correction readiness**

```powershell
git add scripts/verify-staging-planning-adoption-manifest.mjs scripts/staging-planning-adoption-manifest.test.mjs scripts/correct-staging-planning-d046.mjs scripts/staging-planning-d046-correction.test.mjs scripts/verify-staging-planning-closeout.mjs scripts/staging-planning-closeout.test.mjs scripts/staging-planning-browser.mjs scripts/staging-planning-browser.test.mjs
git commit -m "fix(planning): gate adoption deployment and closeout"
```

### Task 6: Register authority, test coverage, and owner runbook

**Files:**

- Create: `docs/decisions/decision-planning-legacy-adoption-unit-repair.md`
- Modify: `docs/decisions/decision-register.md`
- Modify: `docs/business-rules/business-rule-register.md`
- Modify: `docs/implementation-tasks/TASK-PLANNING-D046-ADOPTION-CLOSEOUT.md`
- Modify: `docs/implementation-tasks/TASK-PLANNING-HOSTED-CLOSEOUT.md`
- Modify: `docs/api/rmvp-04-connected-need-generation.md`
- Modify: `docs/api/rmvp-05-connected-confirmed-need-review.md`
- Modify: `docs/runbooks/master-data-rehearsal-import.md`
- Modify: `docs/architecture/rmvp-02a-connected-recipes-bom.md`
- Modify: `docs/architecture/pa-06e-h0-school-catering-persistence-and-materialization-contract.md`
- Modify: `docs/superpowers/specs/2026-09-15-master-data-rehearsal-import-design.md`
- Modify: `scripts/certify-supabase-full-integration.mjs`
- Modify: `.github/workflows/supabase-integration.yml`
- Modify: `scripts/atlas-staging-contract.test.mjs`

**Interfaces:**

- Consumes: implemented migration/test/script names and observed local results.
- Produces: D-047/BR-047 authority, discoverable test execution, and the exact unexecuted post-merge sequence.

- [ ] **Step 1: Register D-047 and BR-047**

Record that only proven OPS-v1 adoption lineage may reinterpret the unchanged
legacy numeric quantity in the Ingredient purchase Unit through immutable
successor evidence; every other cross-Unit Recipe is blocked. Link D-046,
D-039, D-040, D-042, and the task spec. State explicitly that persistent
line-level evidence is required because Atlas retains snapshot identity and
mapping fingerprints but does not persist the raw master snapshot; the relation
is therefore a generated supporting object needed for later proof, not a
generic bypass flag or duplicate business authority.

- [ ] **Step 2: Update API/import contracts**

Document the private provenance predicate, no-conversion rule, Recipe release
invariant, unchanged public signatures, correction behavior, decision
continuity behavior, and safe error codes. State that old snapshots and
pre-D-046 revisions are not backfilled.

- [ ] **Step 3: Register the new pgTAP suite**

Insert `planning_legacy_adoption_unit_transition.sql` immediately before
`planning_operational_proposal.sql` in full integration and the matching CI
group. Extend contract tests to assert both registrations and the unchanged
protected-workflow separation.

- [ ] **Step 4: Write the unexecuted owner sequence**

Document exactly:

```text
merge reviewed PR
→ run read-only pre-deploy adoption manifest against Atlas Staging
→ if and only if exact 76/74/322/246 + four-Ingredient + Cánh exclusion PASS, authorize deployment
→ deploy exact merged SHA/migration to Atlas Staging
→ run read-only post-deploy adoption manifest and catalog/preflight proof
→ protected Planning Performance
→ if and only if PASS, separately authorize and run one 17/09 correction
→ read-only D046_CORRECTED_RESUME proof
→ pin immutable frontend deployment for exact certified SHA
→ protected Planning Browser Closeout
→ final read-only proof
→ declare certified only when both independent statuses PASS
```

Include forward-fix rollback and the prohibition on running any step from this
implementation task.

- [ ] **Step 5: Run documentation/registration tests**

```powershell
pnpm vitest run scripts/atlas-staging-contract.test.mjs
pnpm prettier --check docs/implementation-tasks/TASK-PLANNING-D046-ADOPTION-CLOSEOUT.md docs/decisions/decision-planning-legacy-adoption-unit-repair.md docs/decisions/decision-register.md docs/business-rules/business-rule-register.md docs/api/rmvp-04-connected-need-generation.md docs/api/rmvp-05-connected-confirmed-need-review.md docs/runbooks/master-data-rehearsal-import.md docs/architecture/rmvp-02a-connected-recipes-bom.md docs/architecture/pa-06e-h0-school-catering-persistence-and-materialization-contract.md docs/superpowers/specs/2026-09-15-master-data-rehearsal-import-design.md docs/implementation-tasks/TASK-PLANNING-HOSTED-CLOSEOUT.md
```

Expected: PASS.

- [ ] **Step 6: Commit documentation and registration**

```powershell
git add docs scripts/certify-supabase-full-integration.mjs scripts/atlas-staging-contract.test.mjs .github/workflows/supabase-integration.yml
git commit -m "docs(planning): govern legacy adoption unit repair"
```

### Task 7: Verify, adversarially review, and open the Draft PR

**Files:**

- Modify only if a verification failure proves a scoped defect in the files above.

**Interfaces:**

- Consumes: all prior task outputs.
- Produces: verified branch, final evidence report, and Draft PR.

- [ ] **Step 1: Run the focused suites in dependency order**

```powershell
pnpm vitest run scripts/ops-v1-master-snapshot-contract.test.mjs scripts/staging-planning-performance.test.mjs scripts/staging-planning-adoption-manifest.test.mjs scripts/staging-planning-d046-correction.test.mjs scripts/staging-planning-closeout.test.mjs scripts/staging-planning-browser.test.mjs scripts/atlas-staging-contract.test.mjs
pnpm exec supabase test db supabase/tests/master_data_rehearsal_recipe_import.sql --local
pnpm exec supabase test db supabase/tests/planning_legacy_adoption_unit_transition.sql --local
pnpm exec supabase test db supabase/tests/planning_operational_proposal.sql --local
pnpm exec supabase test db supabase/tests/rmvp_04_connected_need_generation.sql --local
pnpm exec supabase test db supabase/tests/rmvp_05_connected_confirmed_need_review.sql --local
pnpm exec supabase test db supabase/tests/planning_contract_02b_selective_confirmation_continuity.sql --local
pnpm exec supabase test db supabase/tests/planning_contract_01_atomic_planning_boundaries.sql --local
```

Expected: all PASS.

- [ ] **Step 2: Run security/advisor and execution-shape checks**

Run the repository's local Supabase security catalog/advisor commands and
inspect `EXPLAIN (ANALYZE, BUFFERS)` for transition lookup and 322-line repair
fixtures. Confirm indexed successor/predecessor lookups, set-wise
materialization, stable lock order, forced RLS, least privilege, and no
per-contribution N+1 resolver.

- [ ] **Step 3: Run broad local authority once near finalization**

```powershell
pnpm typecheck
pnpm exec prettier --check scripts docs/implementation-tasks/TASK-PLANNING-D046-ADOPTION-CLOSEOUT.md docs/decisions/decision-planning-legacy-adoption-unit-repair.md
git diff --check
pnpm certify:supabase:full-integration
pnpm certify:frontend
```

Expected: PASS. Do not rerun successful broad suites merely for reporting.

- [ ] **Step 4: Perform the required adversarial review**

Read the final extractor, importer, migration, release guard, Need Generation,
materializer, continuity, performance, correction, closeout, and browser paths.
Check every review dimension from the task: Unit authority, quantity dimension,
replay, Recipe/Menu/Pantry history, contribution membership, grouping,
proposal/H1A, v1/v2 Save, unknown outcome, performance threshold, fingerprints,
Handoff absence, RLS/grants, rollback, resumability, rehearsal preservation,
and PR #286 isolation.

- [ ] **Step 5: Verify repository state and commit any evidence-only final edits**

```powershell
git status --short
git diff --stat origin/main...HEAD
git log --oneline origin/main..HEAD
```

Expected: only the bounded files in this plan differ; no stash was applied and
no unrelated Procurement file changed.

- [ ] **Step 6: Push and open a Draft PR**

```powershell
git push -u origin fix/planning-d046-adoption-closeout
gh pr create --draft --base main --head fix/planning-d046-adoption-closeout --title "fix(planning): reconcile legacy recipe units with D-046 closeout" --body "Repairs proven OPS-v1 Recipe Unit adoption through immutable successors, preserves D-046 fail-closed behavior, and prepares the corrected 17/09 closeout. No deployment or Staging business write was performed."
```

Attach the created PR to the task. Do not merge or deploy.

- [ ] **Step 7: Report final evidence**

Report all 22 requested deliverables from the task spec, including starting and
final SHA, exact 76/4/74/24 matrix, 231/231/225/213/210 and 248 counts, test/CI
status, security result, corrected checkpoint shape, unexecuted post-merge
sequence, rollback, and explicit confirmation that OPS v1, Retool, PR #286,
Procurement, protected workflows, and Staging business data were untouched.
