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
- the architecture roadmap.

Verified physical facts:

- `atlas_admin.customers` currently permits only `WHOLESALE`;
- no Atlas school relation is merged;
- no Menu, Attendance, Input Set, Need Generation, theoretical-line, or theoretical-source relation is merged;
- Confirmed Need batch, stable line, and line revision require exact wholesale sources;
- no complete line-level Planning decision child is merged;
- no production Planning quantity-policy root/revision is merged;
- PA-05D releases wholesale quantities as exact pass-through and CMD-03 revalidates the complete wholesale source chain;
- API roles have no direct private-table access and PA-05D uses a no-login/no-inherit hardened runtime.

No approved document conflicts with the selected proposal. The unresolved product and physical choices are carried as blockers rather than assumptions.

## 4. Documentation deliverables

This branch creates exactly:

1. [PA-06E-H0 architecture contract](../architecture/pa-06e-h0-school-catering-persistence-and-materialization-contract.md)
2. [PA-06E-H0 decision record](../decisions/decision-pa-06e-h0-source-lineage-and-decision-evidence.md)
3. this future-task/decomposition record

It adds only minimal references to:

- [Architecture roadmap](../architecture/roadmap.md)
- [Decision register](../decisions/decision-register.md)

No other document or executable file belongs in this change.

## 5. Outcome summary

### 5.1 Prerequisite inventory

The future H0 program requires separate school/reference, Recipe/BOM, Menu, Attendance, readiness, and Need Generation persistence before Confirmed Need generalization can be implemented. Existing actor/receipt/audit/security infrastructure, ingredient/unit references, Confirmed Need roots/revisions/snapshots, and PA-05D wholesale behavior are reusable.

### 5.2 Selected source-lineage proposal

Use inline typed source alternatives on existing Confirmed Need rows:

| Owner       | Existing Wholesale source     | Proposed Need Generation source     |
| ----------- | ----------------------------- | ----------------------------------- |
| Batch       | Wholesale Order               | origin Need Generation run          |
| Stable line | Wholesale Order line          | origin Theoretical Need line        |
| Revision    | Wholesale Order line revision | exact current Theoretical Need line |

Each row permits exactly one typed source and only the two approved H0 source kinds. This is proposed for review; it is not executable approval.

### 5.3 Stable source contribution

Persist one atomic Theoretical Need line per typed source contribution. Use stable Menu/Attendance/RecipeLine/BOMLine anchors and an explicit theoretical-line predecessor for ordinary one-to-one corrections. Never match by ingredient/name/order or broad school/date/ingredient coincidence.

Explicit removal is represented as a typed predecessor-linked removed/tombstone result but H0C rejects it until product policy exists. Split/merge remains explicit and blocked; H0 adds no generic relation aggregate.

### 5.4 Decision evidence

Use the hybrid model:

- immutable line revision for ingredient, unit, theoretical/candidate-or-confirmed quantity, exact source, and predecessor;
- append-only `confirmed_need_line_decisions` evidence for changed or unchanged authority; and
- one nullable current-decision pointer on the stable line.

`UNCHANGED_PROPOSAL_ACCEPTED` uses the current Draft revision without an identical successor. `ADJUSTED_QUANTITY_CONFIRMED` creates a successor revision and decision atomically. Adjusted decision rows derive the logical `ConfirmedNeedAdjustment` history.

### 5.5 Quantity-policy dependency

H0 materialization performs no Planning rounding or quantization. It copies theoretical quantity as a non-authoritative Draft proposal. A versioned, effective, non-overlapping, fail-closed Planning policy is a strict H1 prerequisite. `0.01 kg` remains fixture data only.

### 5.6 Materialization contract

The proposed noncanonical `atlas_api.create_confirmed_needs_from_generation(request jsonb)`:

- consumes one exact released Need Generation run/version;
- creates or refreshes one Draft Confirmed Need batch;
- creates stable lines and immutable Draft revisions;
- binds exact typed source lineage;
- creates no Planning decision, policy fact, approval, release, Handoff, Procurement, or Dispatch fact;
- uses explicit predecessor mapping for corrections;
- rejects removal, split, merge, incomplete, ambiguous, stale, cross-scope, and fake lineage;
- is idempotent and concurrency-safe; and
- writes one receipt, one domain event, and one audit event on success.

## 6. Future implementation decomposition

None of the tasks below is authorized by this documentation PR. Each requires its own issue, clean branch from then-current `main`, exact allowed files, migration/rollback plan, and review.

### H0A1 — Admin school and service-location reference foundation

**Owner:** Admin / Master Data

**Objective:** Resolve and implement the minimum school/customer/location reference and relational authorization scope needed by one school-catering Planning line.

**Expected physical scope:** approved school/customer/location relations, active/effective controls, scope helpers or exact scope relations, migration tests, no production rows.

**Prohibited:** Menu, Attendance, Recipe, Need Generation, Confirmed Need, commands, production data, hosted changes.

**Blocking decisions:** School/Customer relation, customer-type generalization, location ownership, service-date scope, organization/site ownership.

### H0A2 — Recipe/BOM immutable reference foundation

**Owner:** Recipe / Admin governance

**Objective:** Persist stable Dish/Recipe/RecipeLine or BOMLine identities and exact immutable revisions required by calculation lineage.

**Expected physical scope:** minimum approved roots, stable lines, revisions, typed FKs, effective/release immutability, focused tests.

**Prohibited:** Planning calculations, Menu/Attendance writes, Confirmed Need, generic formula engine, QA/Production approval.

**Blocking decisions:** RecipeLine/BOMLine physical relationship, version release mechanics, correction identity, calculation-rule reference.

### H0A3a — Weekly Menu persistence

**Owner:** Planning

**Objective:** Persist one controlled Weekly Menu root, stable lines, approval snapshot, and snapshot lines for a synthetic school/service period.

**Expected physical scope:** parent-contract lifecycle, typed school/dish/date/slot, immutable approved snapshot, issues/events as separately approved.

**Prohibited:** Attendance, Need Generation, Confirmed Need, source-owner cross-writes, production import.

### H0A3b — Attendance persistence

**Owner:** Planning

**Objective:** Persist one controlled Attendance root, stable school/date portions, approval snapshot, and snapshot lines.

**Expected physical scope:** parent-contract lifecycle, typed school/date, nonnegative portions, immutable approved snapshot.

**Prohibited:** Menu mutation, ingredient calculation, Confirmed Need, production import.

### H0A4 — Planning Input Set and readiness persistence

**Owner:** Planning

**Objective:** Persist one exact compatibility/readiness evaluation over approved Menu and Attendance snapshots.

**Expected physical scope:** root, typed input references, immutable readiness snapshot, blocking issues, exact version invalidation.

**Prohibited:** ingredient calculation, Recipe edits, Confirmed Need, browser-authored readiness.

**Blocking decisions:** input-set scope grain, warning acknowledgement, exact source snapshot relation.

### H0A5 — Need Generation and typed theoretical lineage

**Owner:** Planning, consuming Recipe/Admin references read-only

**Objective:** Persist one released calculation run with atomic theoretical contributions, complete typed sources, and explicit predecessor correction identity.

**Expected physical scope:** run, input snapshot, theoretical lines, typed source bridges, predecessor/disposition constraints, issues, RLS/grants, pgTAP.

**Acceptance focus:** no aggregation-based identity; same stable RecipeLine quantity/ingredient correction is one-to-one; new contribution is distinct; removed is explicit; split/merge blocks.

**Prohibited:** Confirmed Need, Planning decision, Procurement, generic source registry, free-text/JSON lineage.

### H0B — Confirmed Need source generalization and decision evidence

**Owner:** Planning

**Objective:** Generalize the current wholesale-only Confirmed Need tables without changing `PA-05D.v1`, then add append-only line-decision evidence and the nullable current pointer.

**Expected physical scope:** source kinds, typed Need Generation alternatives, classification of existing wholesale rows, row checks, typed FKs, source-specific indexes, decision child, pointer, RLS/grants, focused compatibility/security tests.

**Acceptance focus:** exactly-one-source at every level; cross-wire rejection; fake wholesale impossible; PA-05D requests/responses/events/quantities unchanged; no invented decision backfill.

**Prohibited:** H0C function, H1 read/preview/confirm, policy values, approval/release changes, production backfill.

### H0C — Need Generation materialization command

**Owner:** Planning

**Objective:** Implement only the reviewed materialization contract against the merged H0A/H0B schema.

**Expected physical scope:** proposed function/capability/runtime after approval, exact request/response, initial/correction behavior, deterministic locks, idempotency, safe errors, one event/audit/receipt, focused pgTAP.

**Acceptance focus:** one released run; exact source bindings; Draft proposals only; explicit predecessor reuse; no decision; no approval/release/Handoff; exact replay; concurrency safety; dedicated least-privilege runtime.

**Prohibited:** read/preview/confirm, Planning policy default, validation, approval, release, CMD-03 change, Procurement, UI, hosted execution.

### H1A — Planning quantity-policy persistence

**Owner:** Planning policy governance, with product-owner approval

**Objective:** Persist the minimum versioned/effective Planning step policy required for fail-closed preview/commit.

**Expected physical scope:** typed scope/unit root, immutable revision, positive step, non-overlap, exact precedence, rolled-back fixture data.

**Prohibited:** production values without approval, generic formula engine, silent fallback.

### H1B — One-line authorized review, preview, and confirmation

**Owner:** Planning

**Objective:** Implement only the later PA-06E-H1 read/preview/confirm slice after H0 and H1A.

**Expected physical scope:** one synthetic typed line, exact actor scope, authorized read/readback, deterministic preview, preview-bound confirmation, changed/unchanged decision evidence, exact replay/stale/security tests.

**Prohibited:** validation, approval, release, CMD-03, multi-school queue, Procurement, React unless separately authorized, production or hosted changes.

### Later tasks

Complete-batch validation, approval, release, school-catering CMD-03, Purchase Handoff correction, Procurement/PO correction, Dispatch correction, deployment, and production rollout remain separate later concerns.

## 7. Future migration acceptance criteria

### 7.1 H0A acceptance

- [ ] Genuine typed school/customer/location references exist under an approved ownership model.
- [ ] Exact immutable Recipe/BOM, Menu, Attendance, and readiness snapshots exist.
- [ ] Need Generation releases one immutable run/version with atomic theoretical lines.
- [ ] Every theoretical line has complete typed source lineage.
- [ ] Same-contribution correction uses an explicit predecessor.
- [ ] New, removed, split, and merge cases are explicit and fail closed where policy is missing.
- [ ] No identity is inferred from ingredient/name/order or broad coincidence.

### 7.2 H0B acceptance

- [ ] Existing Wholesale rows are explicitly classified without production mutation in the documentation task.
- [ ] Batch, stable line, and revision each enforce exactly one typed source.
- [ ] Source kind and ancestry are consistent across all three levels.
- [ ] Fake wholesale and cross-wired source rows are rejected.
- [ ] PA-05D public contract and pass-through equality remain exact.
- [ ] Prior revision payload, snapshots, releases, events, audit, and downstream rows remain immutable.
- [ ] Line decisions are append-only and current pointer integrity is proven.
- [ ] Changed and unchanged decision evidence can both be represented.
- [ ] Logical adjustment history derives from adjusted decision rows.

### 7.3 H0C acceptance

- [ ] Request accepts only the exact reviewed IDs/versions and no caller-authored lineage or authority.
- [ ] Initial materialization creates one Draft batch, stable lines, and Draft revisions.
- [ ] Proposed quantity is exact theoretical quantity and remains non-authoritative.
- [ ] No decision evidence, approval snapshot, release, Handoff, Procurement, or Dispatch row is created.
- [ ] Corrected materialization reuses a stable line only through exact predecessor ancestry.
- [ ] Every changed source produces new review work even when quantity is unchanged.
- [ ] New contributions receive new stable lines.
- [ ] Removed, missing, split, merge, duplicate, and ambiguous mappings reject atomically.
- [ ] Batch version increments once per successful corrected command.
- [ ] Exact replay returns original IDs; changed intent conflicts.
- [ ] Stale run/batch/source and concurrent forks are rejected safely.
- [ ] One success creates exactly one receipt, one domain event, and one audit event.

### 7.4 Security acceptance

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
- theoretical predecessor continuity and non-forking;
- source-contribution identity independent of ingredient/name/order;
- explicit new/removed/split/merge handling;
- immutable revision payload and controlled current/status metadata;
- append-only changed/unchanged decision evidence;
- exact receipt/event/audit atomicity;
- stale/idempotent/concurrent behavior;
- authorization and relational scope denial; and
- H1 blocked until every required H0 and policy prerequisite exists.

No future implementation task may weaken, skip, or replace existing PA-04/PA-05D tests to make the new path pass.

## 9. Documentation-task acceptance criteria

- [x] Start from merged PA-06E commit `df6205bbea8bb445c52093911a4531add47a76d2`.
- [x] State the current wholesale-only physical facts accurately.
- [x] Inventory every required dependency using the Issue #115 classifications.
- [x] Decompose H0A/H0B/H0C and keep H1/later boundaries explicit.
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
- [x] Create only three documents and two minimal register links.
- [x] Make no executable, live-system, production-data, credential, Retool, or deployment change.

## 10. Documentation validation record

The final branch validation record must include:

- `pnpm ops:workspace`;
- `pnpm install --frozen-lockfile`;
- `pnpm format`;
- `git diff --check`;
- relative Markdown-link validation for all changed Markdown files;
- proof that only the three requested documents and two minimal register files changed;
- proof that no SQL, migration, RPC, RLS, generated type, TypeScript, React, Storybook, package, Retool, Supabase project, production-data, credential, or deployment file changed;
- targeted assertions for no new aggregate, no fake wholesale lineage, H0 decomposition, exact `PA-05D.v1` compatibility, explicit predecessor identity, unchanged acceptance, no materialization decision, and approved-versus-pending labels; and
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
3. input/run batch scope grain;
4. calculation-rule revision and complete typed source set;
5. removal/zero or split/merge behavior;
6. source-kind cross-row enforcement strategy;
7. decision-current constraint, reason policy, or evidence-correction authority;
8. Planning policy scope/precedence/owner/production step;
9. actor class, capability, service-date scope, runtime grants, or registry approval;
10. request/response/error/event/version contract;
11. deployment inventory, production backfill, or cutover/rollback procedure.

An implementation agent must report the blocker rather than select a convenient default.

## 14. Migration and rollback effect

This task has no database migration or operational rollback. It changes Markdown only and can be reverted through normal Git history. It does not inspect or mutate hosted or production state.
