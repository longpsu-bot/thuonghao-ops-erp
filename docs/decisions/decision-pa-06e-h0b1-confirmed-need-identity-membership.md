# Decision PA-06E-H0B1 — Confirmed Need Identity and Contribution Membership

**Status:** Accepted architecture decision for the later H0B1b private-persistence task; governance corrections incorporated; documentation only

**Date:** 2026-07-22

**Issue:** [#133](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/133)

**Authority:** [OPS ERP Vision and Product Charter](../handbook/01-vision-product-charter.md), [ARCH-001](../architecture/arch-001-ops-erp-business-architecture.md), [ARCH-002](../architecture/arch-002-atlas-system-map.md), [PA-01](../architecture/pa-01-atlas-persistence-contract.md), [PA-02](../architecture/pa-02-physical-schema-and-constraint-design.md), [PA-03](../architecture/pa-03-authorization-command-and-transaction-safety-design.md), [PD-01.6 Need Generation](../architecture/planning-domain-need-generation-contract.md), [PD-01.8 Confirmed Need](../architecture/planning-domain-confirmed-need-contract.md), [PA-06E](../architecture/pa-06e-confirmed-need-review-adjustment-revision-contract.md), [PA-06E-H0](../architecture/pa-06e-h0-school-catering-persistence-and-materialization-contract.md), and merged H0A1/H0A5b/PA-04/PA-05D migrations and tests

**Implementation task:** [TASK-PA-06E-H0B1a](../implementation-tasks/TASK-PA-06E-H0B1a-confirmed-need-identity-decision.md)

## 1. Decision outcome

Atlas will reuse and generalize exactly the existing private Planning aggregate:

```text
atlas_planning.confirmed_need_batches
→ atlas_planning.confirmed_need_lines
→ atlas_planning.confirmed_need_line_revisions
→ atlas_planning.confirmed_need_line_revision_contributions
```

The first three relations already exist. H0B1b may add exactly the fourth relation. It may not create another Confirmed Need aggregate, generic source root, source registry, polymorphic source pair, JSON/hash lineage registry, compatibility view, public table, source-name field, decision table, policy table, adjustment table, grouped-generation result, or materialization command.

Every batch, stable line, and line revision has one explicit source kind from this closed set:

```text
WHOLESALE
NEED_GENERATION
```

At each aggregate level exactly one complete typed source family is present. `WHOLESALE` preserves the merged PA-05D path exactly. `NEED_GENERATION` represents school-catering operational totals whose immutable atomic membership is owned by each line revision.

This record closes every product and physical decision required for H0B1b. H0C materialization and all H1 decision, policy, review, approval, release, API, and UI work remain separate and unauthorized.

## 2. Stable operational identity

### 2.1 Selected tuple

One school-catering stable Confirmed Need line is unique within one batch by exactly:

```text
confirmed_need_batch_id
+ service_date
+ customer_id
+ school_id
+ delivery_location_id
+ ingredient_id
+ controlled_unit_id
```

Interpretation:

- `customer_id` is the legal/commercial customer identity.
- `school_id` is the operational school identity.
- `delivery_location_id` is the exact destination captured at materialization time. It remains historical fact and does not follow a later School default-location change.
- `ingredient_id` and `controlled_unit_id` are immutable stable-line identity.
- Changing any tuple member selects or creates a different stable line.
- Several released atomic Theoretical Need contributions may belong to one line revision.
- One atomic contribution is not one Confirmed Need line.

The tuple is relational, not derived. H0B1b must make same-customer School and location ownership enforceable with typed keys: a supporting unique key on `atlas_admin.schools (customer_id, school_id)`, the merged `atlas_admin.delivery_locations (customer_id, delivery_location_id)` key, and restrictive composite FKs from the stable line. H0B1b adds no Admin trigger and does not change the stored School default.

### 2.2 Explicit exclusions

Stable identity excludes Dish, Menu slot or line, Recipe, RecipeVersion, RecipeLine, RecipeLineRevision, Theoretical Need line ID, source order, display order, region, supplier, purchase Unit, family/group token, name, hash, JSON, UI grouping state, actor scope, authorization role, capability, and decision/policy identity.

Authorization scope is a command/security predicate. It is not business identity. The first slice adds no generic `operational_scope` column.

## 3. Controlled Unit boundary

H0B1b is a no-conversion slice:

- every member's `controlled_unit_id` equals its exact Theoretical Need `unit_id`;
- `controlled_contribution_quantity` equals the exact source `theoretical_quantity`;
- `source_unit_id` and `controlled_unit_id` remain separate only for typed explanation and are equal;
- different source Units produce different operational lines;
- the existing line-revision `unit_id` is the quantity-bearing operational Unit and equals the stable line's `controlled_unit_id`; and
- the revision `theoretical_quantity` is the exact PostgreSQL numeric sum of controlled contributions.

No implicit, chained, name-based, current-row, supplier, purchase-unit, rounding, clamp, residual, or fallback conversion is allowed. H0B1b adds no conversion root, revision, placeholder ID, generic conversion field, production conversion value, or conversion lookup. H0C must later fail closed whenever desired grouping would require conversion.

## 4. Exact typed source families

### 4.1 Batch

H0B1b adds these batch concepts/columns:

- `source_kind`;
- existing nullable-by-alternative `wholesale_order_id`;
- `origin_need_generation_run_id`;
- `origin_need_generation_run_version`, holding the exact released run version;
- `origin_need_generation_release_snapshot_id`;
- `current_need_generation_run_id`;
- `current_need_generation_run_version`, holding the exact released run version; and
- `current_need_generation_release_snapshot_id`.

Row families are exact:

| Source kind       | Wholesale family                                                             | Need Generation family                                                                         |
| ----------------- | ---------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `WHOLESALE`       | `wholesale_order_id` is present and retains its exact existing FK/uniqueness | all six Need Generation fields are null                                                        |
| `NEED_GENERATION` | `wholesale_order_id` is null                                                 | all origin/current fields are present and typed to exact run/version/release-snapshot evidence |

For `NEED_GENERATION`:

- origin is immutable;
- current initially equals origin;
- batch period equals the exact origin/current run period;
- one origin release snapshot creates at most one initial batch;
- current may advance only from the previous current release to its direct released successor run in the same Planning Input Set, period, and linear correction chain;
- forked, unrelated, cross-period, cross-input-set, nonreleased, skipped, arbitrary historical, or mismatched release snapshots are invalid; and
- advancing current never rewrites a historical revision or membership.

The existing H0A5b run and release keys are the typed targets. Current advancement is controlled state, not a replacement for origin history.

### 4.2 Stable line

H0B1b adds or retains:

- `source_kind`;
- existing nullable-by-alternative `wholesale_order_line_id`;
- `service_date`;
- `customer_id`;
- `school_id`;
- `delivery_location_id`;
- `ingredient_id`; and
- `controlled_unit_id`.

Row families are exact:

- `WHOLESALE` requires the existing Wholesale Order line and all school-catering identity fields null.
- `NEED_GENERATION` requires the Wholesale field null and every operational tuple field present.
- line source kind equals its owning batch source kind.
- the existing Wholesale uniqueness remains source-specific.
- the complete school-catering tuple is unique within its batch.
- all identity fields are immutable.

A school-catering stable line has no singular Theoretical Need origin and no current-decision pointer.

### 4.3 Line revision

H0B1b adds or retains:

- `source_kind`;
- redundant `confirmed_need_batch_id` for restrictive composite ownership;
- existing nullable-by-alternative `wholesale_order_line_revision_id`;
- `need_generation_run_id`;
- `need_generation_run_version`, holding the exact released version;
- `need_generation_release_snapshot_id`;
- `service_date`, `customer_id`, `school_id`, and `delivery_location_id`;
- existing `ingredient_id` as the revision's exact Ingredient identity; and
- existing `unit_id` as the revision's exact controlled Unit identity.

Row families are exact:

- `WHOLESALE` requires its exact Wholesale Order line revision, all Need Generation and school-catering identity fields null, and zero contribution rows. Existing Ingredient, Unit, quantity, revision, lifecycle, actor, command, current-row, and history behavior is unchanged.
- `NEED_GENERATION` requires the Wholesale revision field null and the complete run/version/release and operational identity family present.
- a restrictive composite FK binds a school-catering revision to the exact owning batch, stable line, source kind, and stable identity tuple.
- the source triple is an exact immutable released H0A5b snapshot.
- a current revision's source triple equals the batch controlled-current triple.
- historical revisions retain the exact release that produced them.
- source and operational identity fields are immutable.
- `unit_id = controlled_unit_id` from the owning line.
- `theoretical_quantity` is the exact membership total.
- existing `confirmed_quantity` is only a non-authoritative Draft proposal until later decision evidence exists.

H0B1b adds no decision/policy FK, decision pointer, adjustment evidence, approval behavior, insert surface, event, receipt, or command.

## 5. Revision-owned contribution membership

### 5.1 Exact relation and columns

`atlas_planning.confirmed_need_line_revision_contributions` is an immutable child of one exact `NEED_GENERATION` line revision. Its columns/concepts are exactly:

- `confirmed_need_line_revision_contribution_id`;
- `confirmed_need_batch_id`;
- `confirmed_need_line_id`;
- `confirmed_need_line_revision_id`;
- `need_generation_run_id`;
- `need_generation_run_version`;
- `need_generation_release_snapshot_id`;
- `need_generation_release_snapshot_line_id`;
- `theoretical_need_line_id`;
- `service_date`;
- `customer_id`;
- `school_id`;
- `delivery_location_id`;
- `ingredient_id`;
- `source_unit_id`;
- `controlled_unit_id`;
- `source_theoretical_quantity`;
- `controlled_contribution_quantity`; and
- `created_at`.

The originating `command_id` remains on the owning Confirmed Need line revision under the merged convention. It is not duplicated as a contribution command, receipt, event, or audit identity. H0C may later create one revision and its complete membership atomically under one command.

### 5.2 Relational proof direction

H0B1b must provide the minimum supporting composite unique keys needed for restrictive FKs:

- batch identity plus source kind;
- stable-line ID, batch ID, source kind, and exact operational tuple;
- revision ID, stable-line ID, batch ID, source kind, exact released-source triple, and exact operational tuple, using existing revision `ingredient_id`/`unit_id` for Ingredient/controlled Unit;
- release-snapshot-line ID plus release snapshot, run, released version, and Theoretical Need line ID; and
- Theoretical Need line ID plus run, service date, School, Ingredient, Unit, disposition, and exact theoretical quantity.

The last two are supporting keys on already merged H0A5b relations, not new source concepts. They allow one contribution row to prove both exact release membership and exact immutable Theoretical Need facts without an upstream trigger. No Menu, Attendance, Dish, Recipe, RecipeLine, or display payload is copied into this bridge.

Customer and destination are captured operational identity, not H0A5b calculation columns. Their same-customer validity is proven through Admin composite FKs; every contribution repeats them only to bind through the revision composite FK. Every member therefore shares the revision's exact captured destination while retaining its own atomic calculation trace through `theoretical_need_line_id`.

### 5.3 Mandatory membership invariants

At transaction end:

1. Membership exists only for `NEED_GENERATION` revisions; Wholesale revisions have zero rows.
2. Every school-catering revision has a nonempty membership set.
3. `(confirmed_need_line_revision_id, theoretical_need_line_id)` is unique.
4. Every member is an exact row of the revision's release snapshot and exact released run/version.
5. Every referenced Theoretical Need line is `ACTIVE`, not `REMOVED`.
6. Every member matches the revision/stable line's service date, School, captured customer/destination, Ingredient, and Unit identity.
7. The membership is complete within its revision: it contains every-and-only `ACTIVE` release member in the revision source snapshot that belongs to that service-date/School/Ingredient/source-Unit operational group. The captured customer/destination is common to the group and is proven by revision ownership.
8. `source_theoretical_quantity` equals the exact Theoretical Need quantity.
9. `source_unit_id` equals the exact Theoretical Need Unit.
10. `controlled_contribution_quantity = source_theoretical_quantity`.
11. `controlled_unit_id = source_unit_id = revision.unit_id = stable_line.controlled_unit_id`.
12. `revision.theoretical_quantity` equals the exact PostgreSQL `numeric` sum of all controlled contribution quantities.
13. There is no epsilon, rounding, clamp, residual, supplier allocation, rebalance, or hidden adjustment.
14. Membership rows are immutable and nondeletable. Display or insertion order is non-authoritative.
15. For each `NEED_GENERATION` batch at its controlled-current run/version/release snapshot, the memberships of all current line revisions form one exact disjoint partition of the release snapshot's complete `ACTIVE` Theoretical Need membership: every active release line appears in exactly one current revision, none is omitted, and none is duplicated across stable lines, operational groups, or captured destinations.
16. Historical, noncurrent, and superseded revisions retain immutable memberships but are excluded from current-partition counting.

The revision-complete rule prevents a caller from manufacturing a matching total by omitting or substituting released atomic lines inside a group. The batch-current partition rule prevents one authoritative release line from being claimed by two current operational lines or from disappearing between current operational groups.

## 6. Mandatory deferred enforcement

H0B1b owns exactly these cross-row guards as PostgreSQL `DEFERRABLE INITIALLY DEFERRED` constraint triggers:

### 6.1 `confirmed_need_current_source_consistency`

**Installed on:** `confirmed_need_batches`, `confirmed_need_lines`, and `confirmed_need_line_revisions` for relevant insert/update/delete events. It reads H0A5b run/release facts but installs no upstream trigger.

**Proves at transaction end:**

- batch, line, and current revision source kinds agree;
- exactly one complete source family exists at each level;
- Need Generation origin is immutable;
- initial current equals origin;
- a changed current is the direct released successor in the same Planning Input Set, period, and correction chain;
- the batch period equals the source run period;
- the current revision uses the exact batch controlled-current release;
- historical revisions retain their historical releases and source/identity facts;
- the exact operational identity agrees across stable line and revision; and
- Wholesale lineage is exact and owns no contribution membership.

### 6.2 `confirmed_need_revision_membership_total`

**Installed on:** `confirmed_need_line_revisions` and `confirmed_need_line_revision_contributions` for relevant insert/update/delete events. It reads immutable H0A5b release-snapshot lines and Theoretical Need lines but installs no upstream trigger.

**Proves at transaction end:** every invariant in section 5.3, including source-kind eligibility, nonempty every-and-only released membership within each revision, the exact disjoint current-batch partition of all active release members, exact active source facts, exact operational identity, no-conversion equality, uniqueness, exact numeric total, Wholesale zero-membership, and immutable history.

Both guards are database integrity boundaries. Later command checks repeat them only for safe domain errors. Deferral permits one transaction to insert or advance the batch, create successor revisions, and create complete memberships in dependency order; it does not permit a partially valid commit.

H0C must later lock the target batch/current revision and exact source run/release rows in deterministic identifier order before mutation. If ownership, source state, membership, current-partition completeness, totals, or lock assumptions cannot be proven, the command and database guard fail closed. No history row is repaired, deleted, or rewritten.

## 7. Wholesale compatibility and migration direction

H0B1b must preserve PA-05D without editing its migration, focused tests, API registry entries, functions, requests, responses, events, errors, grants, lifecycle, quantities, snapshots, audit, downstream IDs, or runtime ownership.

Migration direction:

1. Add `source_kind` with a safe retained `WHOLESALE` default so all existing rows and unchanged PA-05D inserts classify as Wholesale.
2. Prove existing rows have the complete exact Wholesale source chain.
3. Add Need Generation columns and row-family checks.
4. Make the three Wholesale source columns nullable only after the mutually exclusive family checks are valid.
5. Preserve existing Wholesale unique/FK behavior with source-specific constraints/indexes.
6. Add the school-catering keys, bridge, deferred guards, and focused new tests.

No hosted or production inspection, backfill application, compatibility view, or data edit is authorized. Fake Wholesale remains impossible. Direct-wholesale equality remains exactly:

```text
requested wholesale quantity
= Confirmed Need theoretical quantity
= Confirmed Need confirmed quantity
= approved snapshot quantity
= released Purchase Handoff quantity
```

The PA-05D runtime receives no Need Generation or contribution privilege.

## 8. Security and API boundary

The future H0B1b persistence retains the existing mixed private posture exactly:

- the three generalized existing relations remain owned by `atlas_owner`, retain forced RLS, and preserve the exact existing PA-05D runtime grants and named `pa_05d_planning_select` / `pa_05d_planning_insert` policies required by unchanged direct-Wholesale commands;
- H0B1b must not drop, rename, replace, broaden, or duplicate those PA-05D policies or grants;
- unchanged PA-05D functions continue to create only `WHOLESALE` rows through the retained default and exact row-family checks;
- the new `confirmed_need_line_revision_contributions` relation is `atlas_owner`-owned, has RLS enabled and forced, has zero policies, and grants no relation or sequence privilege to `PUBLIC`, `anon`, `authenticated`, `service_role`, or `atlas_planning_command_runtime`;
- the PA-05D runtime receives no privilege on H0A5b Need Generation relations or the new contribution relation;
- no browser view, RPC, application function, new role, capability, runtime, seed, generated type, event, or read model is added;
- no service-role credential or hosted Supabase action occurs; and
- the canonical `atlas_api` registry remains exactly 18 functions.

H0B1b may add owner-only constraint functions required by the two named guards. Such functions use fixed empty `search_path`, fully qualified static SQL, have execute revoked from `PUBLIC` and API roles, and are not application commands.

## 9. Alternatives selected and rejected

| Question                                 | Selected                                                     | Rejected and reason                                                                                              |
| ---------------------------------------- | ------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------- |
| Atomic versus operational stable line    | Operational aggregate tuple                                  | Atomic stable lines do not match the Planning review total and would require an unapproved allocation-back rule. |
| Source identities inside stable identity | Exact operational tuple only                                 | Dish/Recipe/Menu/RecipeLine/Theoretical IDs describe calculation trace, not the operational obligation.          |
| Authorization scope as identity          | Separate security predicate                                  | Actor scope, role, and capability are mutable authorization facts, not business identity.                        |
| Unit treatment                           | Source Unit equals controlled Unit                           | Automatic or implicit conversion lacks an approved immutable conversion family and would hide arithmetic.        |
| Source polymorphism                      | Closed explicit source kind on each existing aggregate level | A generic registry/pair/JSON weakens typed integrity and adds an unnecessary source aggregate.                   |
| Batch-only source                        | Batch origin/current plus immutable revision source          | Batch-only binding would rewrite history or make historical revisions unexplained after correction.              |
| Membership owner                         | Immutable line revision                                      | Stable-line membership cannot explain which exact source set produced each historical quantity revision.         |
| Enforcement                              | Relational keys plus mandatory deferred database guards      | Command-only validation permits cross-wire writes outside a command and is not the integrity boundary.           |
| PA-05D behavior                          | Exact compatibility                                          | Changing PA-05D would expand the task and risk the already released direct-wholesale contract.                   |

## 10. Future H0B1b test ownership

H0B1b must create four independently runnable files/families and must fix each exact `plan(N)` in its issue before coding:

1. H0B1 structure/security/catalog, including the unchanged 18-function API registry, retained PA-05D relation-policy/grant catalog on the three existing relations, and zero-policy/zero-grant posture on the new contribution relation.
2. H0B1 Wholesale compatibility and exact source-kind classification, including unchanged PA-05D inserts and behavior.
3. H0B1 school-catering operational identity and current-source consistency.
4. H0B1 contribution membership, exact total, exact disjoint current-batch partition, immutability, and history.

Each suite owns one family only, opens its own transaction, uses deterministic noncolliding fixtures, calls `finish()`, rolls back, has one exact-path command, reports `Files=1`, its exact assertion count, and `Result: PASS`. H0A and PA-05D tests remain unchanged and are not repartitioned.

## 11. Consequences and remaining boundaries

H0B1b is now implementable without inventing a material decision. Its allowed database scope is the three generalized Confirmed Need relations, one new contribution relation, minimum supporting keys on already merged typed parents, the two named guards, exact PA-05D compatibility, relation-specific private security, and four focused test families.

The following remain later decisions or tasks and do not block H0B1b:

- H0C command/API/runtime, grouping execution, idempotency, errors, receipts, events, and audit;
- zero/removed materialization behavior beyond the first-slice exclusion;
- split/merge and prior-confirmed proposal policy;
- H1 Planning quantity policy, decision evidence, review/confirmation, approval, release, and reopening;
- Purchase Handoff, Procurement, Warehouse, Dispatch, QA, Production, and Finance changes; and
- hosted deployment, production data, and final Vietnamese terminology.

This decision changes documentation only. It has no migration or deployment rollback. Documentation rollback is a normal Git revert.
