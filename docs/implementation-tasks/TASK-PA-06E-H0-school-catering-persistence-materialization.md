# TASK-PA-06E-H0 — School-Catering Persistence and Materialization

**Status:** Documentation task complete only after review; no implementation is authorized

**Task type:** Architecture, physical-decision, security, compatibility, and future-task decomposition only

**GitHub issue:** [#115](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/115)

**Starting baseline:** `df6205bbea8bb445c52093911a4531add47a76d2` (merged PA-06E / PR #114)

**Task branch:** `docs/pa-06e-h0-persistence-materialization-contract`

**Architecture contract:** [PA-06E-H0 School-Catering Persistence and Materialization](../architecture/pa-06e-h0-school-catering-persistence-and-materialization-contract.md)

**Decision record:** [Decision PA-06E-H0 Source Lineage and Decision Evidence](../decisions/decision-pa-06e-h0-source-lineage-and-decision-evidence.md)

## 1. Objective

Define the exact physical direction and bounded implementation sequence required before Atlas can persist one genuine school-catering Confirmed Need line and later implement PA-06E-H1 review, preview, and confirmation.

This task produces documentation only. It does not add SQL, migrations, functions, RPCs, RLS policies, generated types, React, Storybook, packages, Retool changes, hosted Supabase changes, production data, credentials, deployment, or API-registry entries.

## 2. Governing boundary

The work follows:

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

It does not begin from table names. The retained business object is the existing Confirmed Need aggregate. The physical problem is that the merged implementation is direct-wholesale only and cannot persist school-catering lineage without violating its required FKs.

## 3. Authority and repository evidence reviewed

The task is governed by approved repository documentation first and merged migrations/tests second. The review includes:

- `AGENTS.md`, `README.md`, the product charter, decision register, and business-rule register;
- ARCH-001 and ARCH-002;
- PA-01, PA-02, and PA-03;
- Weekly Menu, Attendance, Planning Input Readiness, Need Generation, Confirmed Need, and Purchase Handoff contracts;
- PA-05D contract, migration, and focused pgTAP suite;
- PA-04 migration and relevant pgTAP evidence;
- the canonical PA-06A 18-function registry and browser security boundary;
- all merged PA-06D architecture, decision, and task records;
- all merged PA-06E architecture, decision, and task records; and
- the architecture roadmap;
- the product/architecture review comment on draft PR #116;
- the retained active `q_ppwb_master_load`, `js_ppwb_save_actual_need`, and `q_ppwb_save_actual_need` Purchase Planner path; and
- the retained-schema-equivalent `public.actual_need_overrides`, `public.purchase_assignments`, and active `public.app_upsert_actual_need_overrides_bulk` definitions.

Verified physical facts:

- `atlas_admin.customers` currently permits only `WHOLESALE`;
- no Atlas school relation is merged;
- no Menu, Attendance, Input Set, Need Generation, theoretical-line, or theoretical-source relation is merged;
- Confirmed Need batch, stable line, and line revision require exact wholesale sources;
- no complete line-level Planning decision child is merged;
- no production Planning quantity-policy root/revision is merged;
- PA-05D releases wholesale quantities as exact pass-through and CMD-03 revalidates the complete wholesale source chain;
- API roles have no direct private-table access and PA-05D uses a no-login/no-inherit hardened runtime; and
- the active OPS v1 operational family, override conflict key, and Purchase Assignment grouping are all `service_date + school_id + ingredient_id`.

The review identified two parent-document qualifications: PD-01.8 and PA-02 contain older singular `theoretical_need_line_id`/source-contribution-grain candidates. This correction adds only narrow compatibility references and records a later focused amendment; it does not broadly rewrite either parent. Unresolved product and physical choices remain blockers rather than assumptions.

## 4. Documentation deliverables

This branch creates exactly:

1. [PA-06E-H0 architecture contract](../architecture/pa-06e-h0-school-catering-persistence-and-materialization-contract.md)
2. [PA-06E-H0 decision record](../decisions/decision-pa-06e-h0-source-lineage-and-decision-evidence.md)
3. this future-task/decomposition record

The original branch also retains its minimal references to:

- [Architecture roadmap](../architecture/roadmap.md)
- [Decision register](../decisions/decision-register.md)

This correction pass adds one compatibility paragraph only to:

- [Planning Confirmed Need contract](../architecture/planning-domain-confirmed-need-contract.md)
- [PA-02 Physical Schema and Constraint Design](../architecture/pa-02-physical-schema-and-constraint-design.md)

No other document or executable file belongs in this change.

## 5. Outcome summary

### 5.1 Prerequisite inventory

The future H0 program requires separate school/reference, Recipe/BOM, Menu, Attendance, readiness, and Need Generation persistence before Confirmed Need generalization can be implemented. Existing actor/receipt/audit/security infrastructure, ingredient/unit references, Confirmed Need roots/revisions/snapshots, and PA-05D wholesale behavior are reusable.

### 5.2 Operational confirmation grain

Retain atomic Theoretical Need lines as the calculation grain. Select, subject to explicit product-owner approval, one school-catering Confirmed Need stable line per exact typed operational identity:

```text
service date
+ school/destination
+ ingredient
+ controlled unit
+ approved operational scope
```

This matches the active OPS v1 school/date/ingredient operational family without copying its schema or legacy rules. One contribution is not one Confirmed Need line. Contribution-grain confirmation is rejected because no authoritative rule exists to distribute one operator-confirmed operational total back across multiple contributions.

### 5.3 Contribution membership and correction

Select a private immutable revision-owned contribution-membership snapshot. Each membership row binds the exact released Theoretical Need line, source quantity/unit, controlled-unit contribution, conversion rule where needed, and operational identity. A mandatory deferred constraint proves the revision theoretical total equals the exact membership sum.

Use stable Menu/Attendance/RecipeLine/BOMLine anchors and an explicit theoretical-line predecessor for ordinary atomic correction. Quantity correction and a new same-ingredient contribution update the same operational line through a successor revision and complete new membership. Ingredient correction moves the contribution between immutable old/new ingredient lines; it never mutates stable-line ingredient identity. Removal/zero and split/merge remain explicit and H0C-blocking until product policy exists.

### 5.4 Database constraint strategy

Use composite unique keys/FKs and redundant typed parent/scope identities for local ownership, exact released-run membership, and operational identity. Retain the one-current-revision partial unique rule. Add mandatory `DEFERRABLE INITIALLY DEFERRED` constraint triggers for current source consistency and revision membership/total equality. H1B1 later adds the mandatory current-decision/line/revision/policy trigger. Command validation repeats these checks only as defense in depth.

### 5.5 Decision evidence and policy order

Use the hybrid model only after policy persistence:

- immutable line revision for ingredient, unit, theoretical/candidate-or-confirmed quantity, exact source, and predecessor;
- append-only `confirmed_need_line_decisions` evidence for changed or unchanged authority; and
- one nullable current-decision pointer on the stable line, added with database current-decision integrity.

H0B1/H0C create no decision structure. H1A creates Planning policy roots/revisions. H1B1 creates the decision table, non-null policy FK, pointer, and deferred integrity trigger without an insert capability. H1B2 is the first task allowed to insert. `UNCHANGED_PROPOSAL_ACCEPTED` uses the current Draft revision without an identical successor. `ADJUSTED_QUANTITY_CONFIRMED` creates a successor revision and decision atomically.

### 5.6 Quantity-policy dependency

H0 materialization performs no Planning rounding or quantization. It copies theoretical quantity as a non-authoritative Draft proposal. A versioned, effective, non-overlapping, fail-closed Planning policy is a strict H1 prerequisite. `0.01 kg` remains fixture data only.

### 5.7 Materialization contract

The proposed noncanonical `atlas_api.create_confirmed_needs_from_generation(request jsonb)`:

- consumes one exact released Need Generation run/version;
- creates or refreshes one Draft Confirmed Need batch;
- groups the complete released contribution set by approved operational identity;
- creates one stable line and immutable Draft revision per group;
- creates the complete immutable typed contribution-membership snapshot;
- proves each revision total equals the exact controlled-unit membership sum;
- creates no Planning decision, policy fact, approval, release, Handoff, Procurement, or Dispatch fact;
- regroups the complete corrected set, preserves old memberships, and handles ingredient moves across stable lines without mutating identity;
- rejects removal, split, merge, incomplete, ambiguous, stale, cross-scope, and fake lineage;
- is idempotent and concurrency-safe; and
- writes one receipt, one domain event, and one audit event on success.

## 6. Future implementation decomposition

This parent documentation did not authorize implementation. Each child requires its own issue, clean branch from then-current `main`, exact allowed files, migration/rollback plan, and review. H0A1 was authorized by Issue #117 and merged; H0A2 by Issue #119 and merged; H0A3a by Issue #121 and merged; H0A3b by Issue #123 and merged. Issue #125 authorized the H0A4a decision record in [TASK-PA-06E-H0A4a](TASK-PA-06E-H0A4a-planning-input-readiness-decision.md), and Issue #127 authorizes the bounded H0A4b persistence in [TASK-PA-06E-H0A4b](TASK-PA-06E-H0A4b-planning-input-readiness-persistence.md). Every later task remains unapproved here.

### H0A1 — Admin school and service-location reference foundation

**Status:** Implemented by [TASK-PA-06E-H0A1](TASK-PA-06E-H0A1-school-customer-location-foundation.md) under Issue #117 and merged into `main`

**Decision:** [Decision PA-06E-H0A1 — School and Delivery-Location Ownership](../decisions/decision-pa-06e-h0a1-school-delivery-location-ownership.md)

**Owner:** Admin / Master Data

**Objective:** Resolve and implement the minimum school/customer/location reference and relational authorization scope needed by one school-catering Planning line.

**Expected physical scope:** approved school/customer/location relations, active/effective controls, scope helpers or exact scope relations, migration tests, no production rows.

**Prohibited:** Menu, Attendance, Recipe, Need Generation, Confirmed Need, commands, production data, hosted changes.

**Resolved for H0A1:** School/Customer relation, customer-type generalization, same-customer default-location ownership, and relational `SCHOOL` scope.

**Still outside H0A1:** service-date scope, downstream operational identity, and every later Planning/materialization decision.

### H0A2 — Recipe/BOM immutable reference foundation

**Status:** Implemented by [TASK-PA-06E-H0A2](TASK-PA-06E-H0A2-recipe-bom-immutable-reference-foundation.md) under Issue #119 and merged into `main`

**Decision:** [Decision PA-06E-H0A2 — Immutable Recipe and BOM Reference Lineage](../decisions/decision-pa-06e-h0a2-immutable-recipe-bom-reference-lineage.md)

**Owner:** Recipe / Admin governance

**Objective:** Persist stable Dish/Recipe/RecipeLine or BOMLine identities and exact immutable revisions required by calculation lineage.

**Expected physical scope:** minimum approved roots, stable lines, revisions, typed FKs, effective/release immutability, focused tests.

**Prohibited:** Planning calculations, Menu/Attendance writes, Confirmed Need, generic formula engine, QA/Production approval.

**Resolved for H0A2:** one stable RecipeLine root, immutable exact predecessor-linked revisions, atomic release-successor locking, composition completeness, and fixed proportional-per-basis reference semantics.

**Still outside H0A2:** recipe selection precedence, commands/APIs, review or unlock workflows, calculation and conversion policy, Planning lineage, and every later materialization decision.

### H0A3a — Weekly Menu persistence

**Status:** Implemented by [TASK-PA-06E-H0A3a](TASK-PA-06E-H0A3a-weekly-menu-persistence-foundation.md) under Issue #121 and merged into `main`

**Decision:** [Decision PA-06E-H0A3a — Controlled Weekly Menu Persistence](../decisions/decision-pa-06e-h0a3a-controlled-weekly-menu-persistence.md)

**Owner:** Planning

**Objective:** Persist one controlled Weekly Menu root, stable lines, approval snapshot, and snapshot lines for a synthetic school/service period.

**Expected physical scope:** parent-contract lifecycle, typed school/dish/date/slot, immutable approved snapshot, issues/events as separately approved.

**Prohibited:** Attendance, Need Generation, Confirmed Need, source-owner cross-writes, production import.

**Resolved for H0A3a:** one stable seven-day Weekly Menu root, typed working lines, locked lifecycle, exact immutable approval snapshots, active-line completeness, and retained prior approvals across reopen/later-version work.

**Still outside H0A3a:** commands, authorization, reasons, issues/events, slot policy, same-signature behavior, Attendance, readiness, Need Generation, API/UI, hosted execution, and production rollout.

### H0A3b — Attendance persistence

**Status:** Implemented by [TASK-PA-06E-H0A3b](TASK-PA-06E-H0A3b-attendance-persistence-foundation.md) under Issue #123 and merged into `main`

**Decision:** [Decision PA-06E-H0A3b — Controlled Attendance Persistence](../decisions/decision-pa-06e-h0a3b-controlled-attendance-persistence.md)

**Owner:** Planning

**Objective:** Persist one controlled Attendance root, stable school/date portions, approval snapshot, and snapshot lines.

**Expected physical scope:** parent-contract lifecycle, typed school/date, nonnegative portions, immutable approved snapshot.

**Prohibited:** Menu mutation, ingredient calculation, Confirmed Need, production import.

**Resolved for H0A3b:** one stable arbitrary inclusive-period Attendance root, typed School/date exact nonnegative integer portions, locked lifecycle and working refresh rules, exact immutable approval snapshots, active-line completeness, and retained prior approvals across reopen/later-version work.

**Still outside H0A3b:** commands, authorization, import behavior, defaults, omitted-School/day and inactive-School policy, reasons, issues/events, Planning Input Set, readiness, Need Generation, ingredient calculation, API/UI, hosted execution, and production rollout.

### H0A4a — Planning Input Set/readiness decision closure

**Status:** Documentation completed by [TASK-PA-06E-H0A4a](TASK-PA-06E-H0A4a-planning-input-readiness-decision.md) under Issue #125; pending independent review

**Decision:** [Decision PA-06E-H0A4 — Planning Input Readiness](../decisions/decision-pa-06e-h0a4-planning-input-readiness.md)

**Owner:** Planning

**Objective:** Close root grain, immutable evaluation/version, typed source binding, period containment, issue classification, lifecycle, invalidation, warning acknowledgement, and downstream handoff decisions before persistence.

**Resolved for H0A4a:** one stable exact-period root; append-only positive evaluation versions; direct typed bindings to at most one exact Weekly Menu and one exact Attendance approval snapshot; containment; immutable evaluation-owned issues; closed lifecycle; explicit invalidation; nonblocking warnings with acknowledgement deferred; handoff-only request state.

**Prohibited:** every database/runtime/API change and all ingredient calculation or downstream materialization.

### H0A4b — Planning Input Set and readiness persistence

**Status:** Implemented and locally validated under Issue #127; pending draft-PR review

**Owner:** Planning

**Objective:** Persist the exact H0A4a model without reopening its accepted decisions.

**Expected physical scope:** exact-period root, immutable evaluation versions, two direct typed snapshot FK families, immutable evaluation issues, current pointer/status, database constraints, security, and focused pgTAP.

**Prohibited:** ingredient calculation, Recipe edits, Confirmed Need, browser-authored readiness.

**Required test decomposition:** independently runnable structure/security, evaluation/source-snapshot integrity, and lifecycle/issues/invalidation suites, each with exclusive invariant ownership and exact evidence declared by the future issue.

**Implemented by H0A4b:** the exact three-relation private persistence model, direct typed snapshot bindings, deferred cross-row integrity, immutable issues/evaluations, closed lifecycle, forced RLS with zero policies, and three independent pgTAP suites totaling 123 assertions.

**Still pending:** commands, authorization, reasons/events, safe errors, read/API contracts, acknowledgement, hosted execution, and every H0A5 or downstream calculation.

### H0A5 — Need Generation and typed theoretical lineage

**Owner:** Planning, consuming Recipe/Admin references read-only

**Objective:** Persist one released calculation run with atomic theoretical contributions, complete typed sources, and explicit predecessor correction identity.

**Expected physical scope:** run, input snapshot, theoretical lines, typed source bridges, predecessor/disposition constraints, issues, RLS/grants, pgTAP.

**Acceptance focus:** no aggregation-based identity; same stable RecipeLine quantity/ingredient correction is one-to-one; new contribution is distinct; removed is explicit; split/merge blocks.

**Prohibited:** Confirmed Need, Planning decision, Procurement, generic source registry, free-text/JSON lineage.

### H0B1 — Confirmed Need operational identity and contribution membership

**Owner:** Planning

**Objective:** Generalize the current wholesale-only Confirmed Need tables without changing `PA-05D.v1`, add the approved operational identity and revision-owned contribution membership, and enforce their cross-row invariants in the database.

**Expected physical scope:** source kinds; immutable origin and controlled current released-run references; classification of existing wholesale rows; immutable school-catering operational identity; revision-owned typed contribution membership; row checks; composite unique keys/FKs; source-specific indexes; mandatory deferred source-consistency and exact-membership-total constraint triggers; RLS/grants; focused compatibility, constraint, and security tests.

**Acceptance focus:** exactly-one-source at every level; one school-catering stable line per approved operational identity, not per atomic contribution; immutable complete membership per revision; exact revision total equals the membership sum; cross-wire rejection; fake wholesale impossible; PA-05D requests/responses/events/quantities unchanged; no decision table, pointer, policy fact, or decision backfill.

**Prohibited:** decision table or pointer, H0C function, H1 read/preview/confirm, policy values, approval/release changes, production backfill.

### H0C — Need Generation materialization command

**Owner:** Planning

**Objective:** Implement only the reviewed materialization contract against the merged H0A/H0B1 schema.

**Expected physical scope:** proposed function/capability/runtime after approval, exact request/response, initial/correction behavior, deterministic locks, idempotency, safe errors, one event/audit/receipt, focused pgTAP.

**Acceptance focus:** one released run; group the complete contribution set by approved operational identity; exact immutable membership; exact total equality; quantity/same-ingredient correction stays on the operational line; ingredient correction moves between immutable identity lines; new operational groups create new lines; unresolved removal/zero/split/merge rejects; Draft proposals only; no decision; no approval/release/Handoff; exact replay; concurrency safety; dedicated least-privilege runtime.

**Prohibited:** read/preview/confirm, Planning policy default, validation, approval, release, CMD-03 change, Procurement, UI, hosted execution.

### H1A — Planning quantity-policy persistence

**Owner:** Planning policy governance, with product-owner approval

**Objective:** Persist the minimum versioned/effective Planning step policy required for fail-closed preview/commit.

**Expected physical scope:** typed scope/unit root, immutable revision, positive step, non-overlap, exact precedence, rolled-back fixture data.

**Prohibited:** production values without approval, generic formula engine, silent fallback.

### H1B1 — Policy-bound line-decision persistence

**Owner:** Planning

**Objective:** After H1A, add the append-only decision child and current-decision integrity without exposing an insert surface.

**Expected physical scope:** append-only line decisions, mandatory non-null Planning policy-revision FK, nullable stable-line current-decision pointer, composite ownership keys, predecessor non-forking, mandatory deferred same-line/current-revision/policy constraint trigger, RLS/grants, focused pgTAP.

**Acceptance focus:** H1A precedes the migration; no decision can exist without one exact policy revision; current decision belongs to the same line and exact current revision; no H0 or API/runtime role can insert; no decision backfill is invented.

**Prohibited:** read/preview/confirm functions, decision insertion, policy defaults, UI, production or hosted changes.

### H1B2 — One-line authorized review, preview, and confirmation

**Owner:** Planning

**Objective:** Implement only the later PA-06E-H1 read/preview/confirm slice after H0, H1A, and H1B1.

**Expected physical scope:** one synthetic typed line, exact actor scope, authorized read/readback, deterministic preview, preview-bound confirmation, changed/unchanged decision evidence, exact replay/stale/security tests.

**Prohibited:** validation, approval, release, CMD-03, multi-school queue, Procurement, React unless separately authorized, production or hosted changes.

### Later tasks

Complete-batch validation, approval, release, school-catering CMD-03, Purchase Handoff correction, Procurement/PO correction, Dispatch correction, deployment, and production rollout remain separate later concerns.

## 7. Future migration acceptance criteria

### 7.1 H0A acceptance

- [ ] Genuine typed school/customer/location references exist under an approved ownership model.
- [ ] Exact immutable Recipe/BOM, Menu, Attendance, and readiness evaluations/snapshots exist.
- [ ] Need Generation releases one immutable run/version with atomic theoretical lines.
- [ ] Every theoretical line has complete typed source lineage.
- [ ] Same-contribution correction uses an explicit predecessor.
- [ ] New, removed, split, and merge cases are explicit and fail closed where policy is missing.
- [ ] No identity is inferred from ingredient/name/order or broad coincidence.

### 7.2 H0B1 acceptance

- [ ] Existing Wholesale rows are explicitly classified without production mutation in the documentation task.
- [ ] Batch, stable line, revision, and contribution membership enforce one valid typed source family through composite keys/FKs and mandatory deferred triggers.
- [ ] School-catering stable identity is the approved operational tuple and is never one atomic contribution.
- [ ] Every school-catering revision owns one complete immutable membership over exact released Theoretical Need lines.
- [ ] Stored theoretical quantity equals the exact controlled-unit membership sum with no epsilon.
- [ ] Fake wholesale and cross-wired source rows are rejected.
- [ ] PA-05D public contract and pass-through equality remain exact.
- [ ] Prior revision payload, snapshots, releases, events, audit, and downstream rows remain immutable.
- [ ] No decision table, current-decision pointer, policy fact, or decision insert surface exists in H0B1.

### 7.3 H0C acceptance

- [ ] Request accepts only the exact reviewed IDs/versions and no caller-authored lineage or authority.
- [ ] Initial materialization groups the complete released contribution set by approved operational identity and creates one Draft batch, stable line/revision per group, and exact revision membership.
- [ ] Proposed quantity is exact theoretical quantity and remains non-authoritative.
- [ ] No decision evidence, approval snapshot, release, Handoff, Procurement, or Dispatch row is created.
- [ ] Quantity correction and new same-ingredient contributions create a successor revision and complete membership on the same operational line.
- [ ] Ingredient correction moves membership from the old immutable ingredient identity line to the new line; it never mutates identity.
- [ ] Every changed source produces new review work even when quantity is unchanged.
- [ ] A contribution with a new operational identity creates a new stable line; a same-identity contribution joins the existing group.
- [ ] Removed/zero, missing, split, merge, duplicate, and ambiguous mappings reject atomically until approved policies exist.
- [ ] Batch version increments once per successful corrected command.
- [ ] Exact replay returns original IDs; changed intent conflicts.
- [ ] Stale run/batch/source and concurrent forks are rejected safely.
- [ ] One success creates exactly one receipt, one domain event, and one audit event.

### 7.4 H1A/H1B1/H1B2 acceptance

- [ ] H1A policy roots/revisions exist before H1B1 decision persistence.
- [ ] H1B1 creates an append-only decision child with a mandatory non-null policy-revision FK and no insert surface.
- [ ] Composite ownership plus the mandatory deferred trigger proves the current decision belongs to the same stable line, exact current revision, and one existing policy revision.
- [ ] H1B2 is the first task allowed to insert changed or unchanged decision evidence.
- [ ] Logical adjustment history derives from adjusted decision rows.

### 7.5 Security acceptance

- [ ] New tables are private with RLS enabled and forced.
- [ ] API roles have no direct relation or sequence access.
- [ ] Proposed runtime is no-login/no-inherit, least privilege, and owns only approved functions.
- [ ] PA-05D runtime retains its exact bounded ownership and no Need Generation privilege.
- [ ] Function uses empty fixed `search_path`, fully qualified static SQL, and revoke-first execute grants.
- [ ] Actor/capability/customer/school/location/date scope resolves server-side and fails closed.
- [ ] No service-role credential, global fallback, selector broadening, or dynamic object name exists.
- [ ] Advisor and focused pgTAP checks pass before any migration PR is ready.

## 8. Test blueprint for later implementation PRs

Each future task runs focused pgTAP appropriate to its migration. Cumulative tests must retain:

- exact API function counts/ownership as intentionally amended by an approved registry change;
- exact `PA-05D.v1` payload/response/event/equality/cross-wire behavior;
- private-schema RLS and API-role denial;
- no dynamic SQL or mutable definer search path;
- typed source exactly-one constraints and FK integrity;
- operational-line identity independent of atomic contribution identity;
- immutable revision contribution membership and exact membership-sum equality;
- mandatory deferred source, membership-total, and later current-decision constraint-trigger failures;
- theoretical predecessor continuity and non-forking;
- source-contribution identity independent of ingredient/name/order;
- explicit new/removed/split/merge handling;
- immutable revision payload and controlled current/status metadata;
- policy-before-decision migration ordering and append-only changed/unchanged decision evidence;
- exact receipt/event/audit atomicity;
- stale/idempotent/concurrent behavior;
- authorization and relational scope denial; and
- H1 blocked until every required H0 and policy prerequisite exists.

No future implementation task may weaken, skip, or replace existing PA-04/PA-05D tests to make the new path pass.

## 9. Documentation-task acceptance criteria

- [x] Start from merged PA-06E commit `df6205bbea8bb445c52093911a4531add47a76d2`.
- [x] State the current wholesale-only physical facts accurately.
- [x] Inventory every required dependency using the Issue #115 classifications.
- [x] Decompose H0A/H0B1/H0C/H1A/H1B1/H1B2 and keep later boundaries explicit.
- [x] Record the active OPS v1 school/date/ingredient operational family as evidence, not a schema to copy.
- [x] Select the operational requirement grain and reject one Confirmed Need line per atomic contribution.
- [x] Define immutable revision-owned typed contribution membership and exact total equality.
- [x] Require cross-row lineage, membership, and current-decision invariants to be database-enforced.
- [x] Evaluate all three source-lineage alternatives and select the smallest typed design.
- [x] Preserve typed relational integrity and direct-wholesale compatibility.
- [x] Define stable contribution identity without ingredient/name/order coincidence.
- [x] Define quantity correction, ingredient correction, new, removed, split, and merge behavior.
- [x] Evaluate decision-evidence alternatives and select the hybrid.
- [x] Represent unchanged proposal acceptance without an identical successor revision.
- [x] Define current decision, correction/supersession, source/policy, reason, and adjustment-read behavior.
- [x] Make versioned Planning policy a strict H1 prerequisite and keep fixture values non-production.
- [x] Define exact initial and corrected materialization behavior, request, response, errors, events, idempotency, and locks.
- [x] Define additive-first migration, PA-05D compatibility, indexes, no-cascade history, and forward-fix strategy.
- [x] Define private-schema, runtime, grant, RLS, browser, scope, safe-error, advisor, and pgTAP requirements.
- [x] List every unresolved physical/product/API/security/operations decision explicitly.
- [x] Limit the correction to the three H0 documents and minimal parent compatibility references; retain the already-reviewed roadmap/register links.
- [x] Make no executable, live-system, production-data, credential, Retool, or deployment change.

## 10. Documentation validation record

The final branch validation record must include:

- `pnpm ops:workspace`;
- `pnpm install --frozen-lockfile`;
- `pnpm format`;
- `git diff --check`;
- relative Markdown-link validation for all changed Markdown files;
- proof that the correction changed only the three H0 documents and two minimal parent compatibility references, while the branch retains the already-reviewed roadmap/register links;
- proof that no SQL, migration, RPC, RLS, generated type, TypeScript, React, Storybook, package, Retool, Supabase project, production-data, credential, or deployment file changed;
- targeted assertions for the active OPS v1 evidence key, operational-versus-contribution grain, typed immutable membership, exact membership total, database-enforced cross-row constraints, ingredient correction without identity mutation, no new aggregate, no fake wholesale lineage, H0/H1 sequencing, exact `PA-05D.v1` compatibility, explicit predecessor identity, unchanged acceptance, no H0 materialization decision, and approved-versus-pending labels; and
- GitHub workflow result for the open draft PR.

This section records requirements rather than claiming validation before commands and workflows complete. The draft PR description and final task report must state the actual results.

## 11. Prohibited changes

Do not add or modify:

- SQL, migration, trigger, view, function, RPC, RLS, policy, grant, runtime role, generated type, or database test;
- React, TypeScript, Storybook, package, lockfile, application configuration, or browser adapter;
- Retool, OPS v1, hosted Supabase, production data, Storage, Edge Functions, credentials, secrets, or deployment;
- canonical PA-06A registry entries;
- a Planning Quantity Confirmation, generic Quantity Decision, generic workflow, generic source registry, generic formula engine, or generic split/merge graph;
- fake Wholesale Orders/lines/revisions, free-text polymorphic source IDs, caller-authored table names, or unvalidated lineage JSON;
- H1 review/preview/confirmation, validation, approval, release, school-catering CMD-03, Procurement, PO, Dispatch, or downstream correction behavior.

Do not combine every missing school-catering domain into one implementation migration. Do not mark a pending physical/product choice approved merely because this document recommends it.

## 12. Publication boundary

Publish this documentation task on branch:

`docs/pa-06e-h0-persistence-materialization-contract`

Open a draft pull request titled:

`PA-06E-H0: Define school-catering persistence and materialization architecture`

The pull request must remain open, draft, unmerged, and undeployed. Its body must state:

- documentation only;
- merged PA-06E is the prerequisite;
- the current database is wholesale-only for Confirmed Need;
- H0 is decomposed before implementation;
- no H1 implementation is authorized; and
- no Supabase, Retool, production, credential, or deployment change occurred.

## 13. Pending-decision stop conditions

Stop the affected future implementation task if any of these remains unresolved:

1. school/customer/location ownership or relational scope;
2. RecipeLine/BOMLine stable physical identity;
3. generation-run batch scope grain; the Planning Input Set root grain is resolved by H0A4a and must not be guessed differently;
4. calculation-rule revision and complete typed source set;
5. removal/zero or split/merge behavior;
6. exact operational identity fields and product-owner approval;
7. exact composite key/FK/constraint-trigger columns, names, lock performance, and migration-validation plan within the selected mandatory database-enforcement direction;
8. decision-current columns/indexes, reason policy, or evidence-correction authority;
9. Planning policy scope/precedence/owner/production step;
10. actor class, capability, service-date scope, runtime grants, or registry approval;
11. request/response/error/event/version contract;
12. focused PD-01.8/PA-02 parent-contract amendment timing;
13. deployment inventory, production backfill, or cutover/rollback procedure.

An implementation agent must report the blocker rather than select a convenient default.

## 14. Migration and rollback effect

This task has no database migration or operational rollback. It changes Markdown only and can be reverted through normal Git history. It does not inspect or mutate hosted or production state.
