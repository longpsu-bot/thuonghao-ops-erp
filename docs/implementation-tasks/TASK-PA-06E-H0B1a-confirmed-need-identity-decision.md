# TASK-PA-06E-H0B1a — Confirmed Need Identity Decision

**Status:** Documentation decision implemented under Issue #133; governance corrections incorporated; pending independent governance re-review

**Task type:** Product/architecture decision and future persistence decomposition only

**GitHub issue:** [#133](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/133)

**Starting baseline:** `d36b6e119cebd9360a865d20cddb02812d110f34`

**Task branch:** `docs/pa-06e-h0b1a-confirmed-need-identity-decision`

**Decision:** [Decision PA-06E-H0B1 — Confirmed Need Identity and Contribution Membership](../decisions/decision-pa-06e-h0b1-confirmed-need-identity-membership.md)

**Parent contract:** [PA-06E-H0 School-Catering Persistence and Materialization](../architecture/pa-06e-h0-school-catering-persistence-and-materialization-contract.md)

## 1. Objective

Close the operational identity, no-conversion Unit boundary, source-kind generalization, revision source, contribution-membership, database-enforcement, Wholesale compatibility, security, and test-family decisions needed before one later H0B1b migration can be specified.

This task changes documentation only. It implements no SQL, migration, pgTAP, workflow, command, RPC, role, capability, runtime, policy, generated type, React, Retool, hosted Supabase, production data, credential, deployment, H0C materialization, H1 decision, approval/release, Purchase Handoff, Procurement, Warehouse, Dispatch, QA, Production, or Finance behavior.

## 2. Governing method and evidence

The task follows OPS_SYSTEM_MAP in order:

```text
Mission
→ Business Capability
→ Business Domain
→ Business Object
→ Business Contract
→ Command/Event
→ Read Model
→ Application
→ Technology
```

Reviewed authority/evidence includes:

- `AGENTS.md`, `README.md`, product charter, decision register, and business-rule register;
- ARCH-001 and ARCH-002;
- PA-01, PA-02, and PA-03;
- PD-01.6 Need Generation, PD-01.8 Confirmed Need, PA-06E, and PA-06E-H0;
- H0A1 School/customer/location decision, migration, and tests;
- H0A5a Need Generation decision and contract;
- H0A5b decision, migration, four focused suites, exact release membership, and typed theoretical lineage;
- merged PA-04 Confirmed Need relations;
- PA-05D request/response/event contract, migration, tests, exact Wholesale pass-through equality, and its retained RLS policy/grant catalog;
- the canonical PA-06A 18-function registry; and
- retained OPS v1/Retool school/date/ingredient grouping evidence.

OPS v1 remains qualitative evidence only. This task does not copy its public-schema access, client token, UI arithmetic, supplier grouping, rebalance, purchase Unit, rounding, or authority model.

## 3. Deliverables and file boundary

Created exactly:

1. [Decision PA-06E-H0B1](../decisions/decision-pa-06e-h0b1-confirmed-need-identity-membership.md)
2. this task record

Narrow compatibility amendments are limited to:

3. [PA-06E-H0 parent contract](../architecture/pa-06e-h0-school-catering-persistence-and-materialization-contract.md)
4. [TASK-PA-06E-H0 parent decomposition](TASK-PA-06E-H0-school-catering-persistence-materialization.md)
5. [PD-01.8 Confirmed Need](../architecture/planning-domain-confirmed-need-contract.md)
6. [PA-06E revision/source-correction contract](../architecture/pa-06e-confirmed-need-review-adjustment-revision-contract.md)
7. [PA-02 physical schema](../architecture/pa-02-physical-schema-and-constraint-design.md)
8. [Decision register](../decisions/decision-register.md)
9. [Roadmap](../architecture/roadmap.md)

No file outside that nine-document list belongs to this task.

## 4. Closed decisions

### 4.1 Operational stable-line identity

The exact school-catering identity is:

```text
confirmed_need_batch_id
+ service_date
+ customer_id
+ school_id
+ delivery_location_id
+ ingredient_id
+ controlled_unit_id
```

Customer is the legal/commercial owner; School is the operational identity; delivery location is captured historical destination; Ingredient and controlled Unit are immutable identity. Any tuple-member change selects or creates another line. Dish/Menu/Recipe/RecipeLine/Theoretical IDs, order, supplier, purchase Unit, names, tokens, hashes, JSON, UI state, actor scope, role, and capability are excluded.

Authorization remains separate. No generic operational-scope column is approved.

### 4.2 Calculation versus confirmation grain

H0A5b retains one immutable atomic Theoretical Need line per exact calculation contribution. Confirmed Need groups all `ACTIVE` released contributions with the exact operational tuple into one immutable line-revision membership and one exact theoretical total. One contribution is not one stable Confirmed Need line.

For one school-catering batch at its controlled-current release, all current line revisions together form one exact disjoint partition of the complete `ACTIVE` release membership. Every active release line appears exactly once across current operational lines; no line is omitted or duplicated across different stable lines or destinations. Historical and superseded revision memberships remain immutable but do not participate in current-partition counting.

### 4.3 No-conversion first slice

For every member:

```text
controlled_unit_id = source theoretical unit_id
controlled_contribution_quantity = source theoretical_quantity
```

Different Units form different lines. No conversion family, factor, placeholder, chaining, current/name lookup, supplier/purchase Unit, rounding, clamp, residual, or fallback is approved. H0C later fails closed if conversion would be needed.

### 4.4 Aggregate reuse and source kinds

Reuse `confirmed_need_batches`, `confirmed_need_lines`, and `confirmed_need_line_revisions`. Add only `confirmed_need_line_revision_contributions`.

Every aggregate level has one source kind from exactly `WHOLESALE` or `NEED_GENERATION`, with exactly one complete family and the other family null.

### 4.5 Exact source ownership

- Batch: existing Wholesale Order alternative or immutable origin plus controlled-current Need Generation run/released-version/release-snapshot triples.
- Stable line: existing Wholesale Order line alternative or exact operational tuple; never a singular Theoretical Need pointer.
- Revision: existing Wholesale Order line revision alternative or exact released run/version/snapshot plus exact stable identity; the current revision agrees with batch current source while history retains historical source.
- Contribution: exact revision, release-snapshot line, Theoretical Need line, operational identity, source/controlled Units, source/controlled quantities, and creation time.

The merged revision `command_id` owns the materialization intent. Contribution rows do not duplicate command, receipt, event, or audit identity.

### 4.6 Quantity authority

Revision `theoretical_quantity` is the exact PostgreSQL numeric membership sum. Existing `confirmed_quantity` is only a Draft proposal until H1 decision evidence exists. H0B1a/H0B1b creates no decision, policy, adjustment, approval, release, or insert authority.

### 4.7 Deferred integrity

Future H0B1b must implement exactly:

- `confirmed_need_current_source_consistency`; and
- `confirmed_need_revision_membership_total`.

Both are `DEFERRABLE INITIALLY DEFERRED` constraint guards owned by Confirmed Need relations. They read immutable upstream typed evidence but add no trigger to Need Generation, School, location, Ingredient, or Unit. Command validation is defense in depth.

The first guard proves exact source families, origin/current correction-chain behavior, period, current-revision source, operational identity, historical retention, Wholesale lineage, and zero Wholesale membership. The second proves nonempty every-and-only `ACTIVE` membership inside each revision, the exact disjoint partition of all active members across the batch's current line revisions, exact source/identity/quantity/Unit facts, no-conversion equality, uniqueness, exact total, immutability, history, and zero Wholesale membership.

### 4.8 Wholesale compatibility

H0B1b safely defaults/classifies existing and unchanged PA-05D-created rows as `WHOLESALE`, proves their exact source chain, and only then makes the three Wholesale source columns nullable by alternative. Existing keys, lifecycle, revisions, snapshots, events, audit, requests/responses, errors, downstream IDs, exact pass-through equality, relation grants, and named PA-05D RLS policies remain unchanged. No PA-05D migration or test is modified, and its runtime gains no H0A5b or contribution privilege.

### 4.9 Security and API

Future H0B1b preserves the existing relation-specific private posture:

- `confirmed_need_batches`, `confirmed_need_lines`, and `confirmed_need_line_revisions` remain `atlas_owner`-owned with forced RLS and retain the exact existing PA-05D runtime grants and named `pa_05d_planning_select` / `pa_05d_planning_insert` policies;
- H0B1b does not drop, rename, replace, broaden, or duplicate those policies or grants;
- unchanged PA-05D functions continue creating only `WHOLESALE` rows through the source-kind default and exact row-family checks;
- the new contribution relation is `atlas_owner`-owned, forced-RLS, zero-policy, and grants no access to `PUBLIC`, `anon`, `authenticated`, `service_role`, or `atlas_planning_command_runtime`;
- the PA-05D runtime receives no privilege on H0A5b source relations or the contribution relation; and
- no view/RPC/application function/new role/capability/runtime/seed/type/read model is added. `atlas_api` remains exactly 18 functions.

## 5. Future H0B1b implementation boundary

### 5.1 Allowed physical work

A separately approved H0B1b may:

- generalize the three existing Confirmed Need relations with the exact fields and alternative checks in the decision;
- add one contribution relation;
- add minimum supporting composite unique keys to typed Admin/H0A5b parents;
- add restrictive composite FKs and source-specific uniqueness;
- add the two named deferred guards and relation-local immutability protection;
- preserve the exact existing PA-05D policies/grants on the three existing relations;
- apply forced RLS, zero policies, and zero PA-05D/API-role grants only to the new contribution relation; and
- add four new focused pgTAP suites.

It may not add a command, browser/API surface, decision/policy/adjustment structure, conversion family, grouped source aggregate, compatibility view, public relation, generated type, UI, or hosted/production action.

### 5.2 Exact future test ownership

The H0B1b issue must name four independently runnable files and fix exact `plan(N)` counts before coding:

1. structure/security/catalog, including retained PA-05D policies/grants on the three existing relations and zero policies/grants on the new contribution relation;
2. Wholesale compatibility/source-kind classification;
3. school-catering operational identity/current-source consistency; and
4. contribution membership/exact total/disjoint current partition/immutability/history.

Each suite has one exclusive invariant family, its own transaction and deterministic noncolliding fixtures, `finish()`, rollback, one exact-path command, `Files=1`, the exact assertion count, and `Result: PASS`. Existing H0A and PA-05D tests remain unchanged.

## 6. Acceptance criteria

- [x] Exact seven-part stable-line tuple is selected with no additional business dimension.
- [x] Business identity is separated from authorization scope.
- [x] No-conversion source-Unit-equals-controlled-Unit behavior is exact.
- [x] Existing aggregate reuse and exactly one new bridge are selected.
- [x] Closed `WHOLESALE`/`NEED_GENERATION` alternatives exist at batch, line, and revision levels.
- [x] Batch origin/current and correction-chain rules are exact.
- [x] Stable-line and immutable revision source fields are exact.
- [x] Contribution columns, command ownership, complete membership, and exact-total rules are exact.
- [x] Current school-catering memberships form an exact disjoint partition of every active member in the controlled-current release.
- [x] Two deferred guard names, owners, affected relations, transaction-end proofs, and history behavior are exact.
- [x] PA-05D behavior, existing tests, relation grants, and named RLS policies remain unchanged.
- [x] The new contribution relation alone has zero policies and no PA-05D/API-role grants.
- [x] Private security and unchanged 18-function API boundary are exact.
- [x] Four future test families have exclusive ownership.
- [x] Nine required alternatives are explicitly selected/rejected in the decision.
- [x] No material H0B1b decision remains open.

## 7. Validation required for this documentation branch

Run and record:

```text
pnpm install --frozen-lockfile
pnpm format
pnpm typecheck
pnpm test
pnpm build
git diff --check
git diff --cached --check
pnpm ops:workspace
existing Markdown link-target validation
git status --short
git diff --name-status
```

The diff must contain only the nine allowed documentation files.

## 8. Security, migration, and rollback

This task changes documentation only. Security, runtime privileges, RLS, schema, hosted Supabase, and production data are unchanged. There is no database or deployment rollback. Documentation rollback is a normal Git revert.

## 9. Stop boundary

After the draft PR's exact-head workflows pass, apply `atlas:merge-ready` to Issue #133 and the PR, post the required exact-head evidence, and stop. Do not create H0B1b, start H0C/H1, or perform hosted/production work. Merge remains subject to independent governance authorization.
