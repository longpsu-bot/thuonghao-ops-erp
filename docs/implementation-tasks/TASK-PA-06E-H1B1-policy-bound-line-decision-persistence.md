# TASK-PA-06E-H1B1 — Policy-Bound Confirmed Need Line Decision Persistence

**Status:** Product contract approved; future SQL implementation remains separately unauthorized

**Decision issue:** [#151](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/151)

**Documentation baseline:** `0ba89ff8c3434979eb3e8897a6bcf9bb2171c51f`

**Canonical decision:** [Decision PA-06E-H1B1 — Policy-Bound Line Decision Evidence](../decisions/decision-pa-06e-h1b1-policy-bound-line-decision-evidence.md)

**Architecture contract:** [PA-06E-H1B1 — Policy-Bound Confirmed Need Line Decision](../architecture/pa-06e-h1b1-policy-bound-line-decision-contract.md)

**Required predecessor:** merged PA-06E-H1A Planning quantity-policy persistence

**Required successor:** H1B2 authorized review, preview, and confirmation

## 1. Objective

Implement one additive, private, seedless, writerless persistence slice for the approved policy-bound Confirmed Need line-decision contract.

The future implementation may add only:

- one append-only private decision relation;
- one nullable current-decision pointer on `atlas_planning.confirmed_need_lines`;
- the minimum typed keys, checks, restrictive FKs, indexes, and private guards required for decision immutability, linear predecessor history, pointer monotonicity, revision/policy binding, and exact quantity evidence;
- rolled-back synthetic pgTAP fixtures;
- the exact H1B1 delta in the canonical current-platform catalog; and
- workflow registration for the new H1B1 suites.

It must not implement:

- H1B2 preview or confirmation;
- an insert/update writer;
- an `atlas_api` function;
- a read model;
- a role, capability, runtime, membership, policy, or positive grant;
- a generic decision/workflow engine;
- batch validation, approval, release, reopen, or CMD-03 integration;
- React, Retool, hosted Supabase, OPS v1/v2, production data, credentials, generated types, packages, deployment, or seed rows.

## 2. Future baseline rule

The future H1B1 implementation issue must name one exact freshly fetched `origin/main` commit before a branch is created.

That commit must:

1. contain this merged decision and task blueprint;
2. contain merged H0B1b typed Confirmed Need identity/revision contribution membership;
3. contain merged H0C/CMD-15 Draft materialization;
4. contain merged H1A policy roots/revisions;
5. retain the canonical current-platform catalog suite;
6. retain exactly 19 physical `atlas_api` functions and the 15-write/four-read PA-06A registry unless a separately approved intervening change updates both;
7. contain no H1B1 relation, pointer, migration, test, writer, or H1B2 API;
8. pass `pnpm ops:workspace`; and
9. be clean and equal to the `origin/main` head used by the future issue.

If `main` advances with a Confirmed Need, H1A policy, authorization, API, current-catalog, or workflow change that conflicts with this blueprint, stop and amend the documentation before SQL work.

## 3. Approved business and physical scope

### 3.1 Business object

The only new business object is:

```text
ConfirmedNeedLineDecision
```

It is one append-only evidence child inside the existing Confirmed Need aggregate.

Do not add:

- a Planning Quantity Confirmation aggregate;
- a generic Quantity Decision aggregate;
- a Decision Correction aggregate;
- a reason-code aggregate;
- a polymorphic target;
- a workflow/status object; or
- a UI-owned decision object.

### 3.2 Relation and pointer catalog

The one additive migration should create exactly:

```text
atlas_planning.confirmed_need_line_decisions
```

and add exactly one business column to an existing relation:

```text
atlas_planning.confirmed_need_lines.current_confirmed_need_line_decision_id uuid null
```

The pointer has no default. Existing and newly materialized Draft lines remain null until future H1B2 creates authority.

### 3.3 Exact proposed decision columns

The future implementation issue must verify the following exact column catalog before coding.

#### Identity and typed ownership

- `confirmed_need_line_decision_id uuid`
- `confirmed_need_batch_id uuid`
- `confirmed_need_line_id uuid`
- `confirmed_need_line_revision_id uuid`
- `source_kind text`
- `service_date date`
- `customer_id uuid`
- `school_id uuid`
- `delivery_location_id uuid`
- `ingredient_id uuid`
- `unit_id uuid`

#### Decision chain

- `decision_number bigint`
- `predecessor_decision_id uuid`
- `decision_kind text`

#### Policy and quantity evidence

- `planning_quantity_policy_id uuid`
- `planning_quantity_policy_revision_id uuid`
- `theoretical_quantity_before numeric(20,6)`
- `proposed_quantity_before numeric(20,6)`
- `confirmed_quantity_after numeric(20,6)`
- `planning_tick_count numeric(20,0)`

#### Reason, actor, and command evidence

- `reason_code text`
- `reason_note text`
- `decided_by_actor_id uuid`
- `decided_at timestamptz`
- `command_id uuid`
- `confirmed_need_batch_version bigint`
- `created_at timestamptz`

The future issue may refine only physical constraint/index names. It may not add, remove, rename, or reinterpret a business-evidence column without an explicit decision amendment.

## 4. Approved evidence rules

### 4.1 Decision kinds

Exactly:

```text
UNCHANGED_PROPOSAL_ACCEPTED
ADJUSTED_QUANTITY_CONFIRMED
```

No status column or correction kind exists.

### 4.2 Reason codes

Exactly:

```text
PROPOSAL_ACCEPTED
PLANNING_STEP_ADJUSTMENT
OPERATIONAL_QUANTITY_ADJUSTMENT
OTHER
```

Kind/reason/note compatibility must follow the canonical decision.

A replacement decision retains the business reason and requires a correction note because `predecessor_decision_id` is non-null.

### 4.3 Accountable actor

Use one `decided_by_actor_id` and `decided_at`, plus database acceptance `created_at`.

No proxy/recording actor or first-slice separation-of-duties rule is allowed.

### 4.4 Command linkage

Store `command_id` and `confirmed_need_batch_version` only.

Do not copy receipt ID, correlation ID, event ID, audit ID, idempotency payload, or complete command envelope into each decision.

### 4.5 Quantities and ticks

All quantities/ticks are exact nonnegative PostgreSQL numeric values.

The future deferred guard must prove exact revision values and:

```text
confirmed_quantity_after
= planning_tick_count × planning_quantity_policy_revision.planning_step
```

No epsilon, rounding, truncation, conversion, or client normalization is allowed.

## 5. Key, constraint, and index direction

The migration must use:

- database-generated UUID primary key;
- positive line-local `decision_number`;
- unique `(confirmed_need_line_id, decision_number)`;
- first-decision/null-predecessor and later/non-null-predecessor shape;
- same-line direct predecessor ownership;
- non-forking predecessor uniqueness;
- exact school-catering `NEED_GENERATION` line operational identity;
- exact line-revision ownership through the minimum bounded revision decision-owner key;
- exact H1A `(planning_quantity_policy_id, planning_quantity_policy_revision_id, unit_id)` ownership;
- exact decision-kind vocabulary;
- exact reason vocabulary and kind/reason/note compatibility;
- nonnegative quantity/tick checks;
- positive decision-time batch version;
- restrictive actor and command-receipt references;
- no decision update or delete;
- one decision per line per command;
- deferrable same-line pointer FK;
- pointer movement only null-to-first or current-to-direct-successor; and
- leading indexes for every operational FK not already covered by a primary/unique key.

Do not add a reason lookup table, generic evidence JSON, generic target fields, an extension, or a generic helper function.

## 6. Function and trigger direction

The future migration target is exactly three private functions:

1. `atlas_planning.pa_06e_h1b1_confirmed_need_line_decision_guard()`
2. `atlas_planning.pa_06e_h1b1_confirmed_need_line_pointer_guard()`
3. `atlas_planning.pa_06e_h1b1_confirmed_need_line_decision_integrity()`

All three should be:

- owned by `atlas_owner`;
- security invoker;
- fixed to empty `search_path`;
- fully schema-qualified and static; and
- inaccessible to `PUBLIC`, API roles, `service_role`, and all runtime roles.

The future trigger target is exactly six triggers:

1. ordinary immutability/delete guard on `confirmed_need_line_decisions`;
2. ordinary current-pointer transition guard on `confirmed_need_lines`;
3. deferred decision integrity trigger on `confirmed_need_line_decisions`;
4. deferred pointer integrity trigger on `confirmed_need_lines`;
5. deferred revision-current-state trigger on `confirmed_need_line_revisions`; and
6. deferred policy-eligibility trigger on `planning_quantity_policy_revisions`.

The deferred function must evaluate final transaction state and prove:

- linear decision numbers and predecessor chain;
- prior current decision equals replacement predecessor;
- no predecessor fork;
- pointed decision belongs to the same exact line/identity;
- pointed decision binds the line's current revision;
- unchanged and adjusted revision semantics;
- exact theoretical/proposed/confirmed evidence;
- sole eligible exact policy revision for Unit and service date;
- exact tick multiplication;
- reason/note correction rules;
- decision actor/command/batch-version evidence shape; and
- no pointer clear, lateral movement, ancestor movement, or cross-line movement.

If executable design requires another relation, function, trigger, extension, resolver, role, capability, runtime, policy, grant, API, view, or writer, stop and amend the contract.

## 7. Security and exposure

The decision relation must be:

- private in `atlas_planning`;
- owned by `atlas_owner`;
- RLS-enabled and forced;
- protected by zero policies; and
- inaccessible to `PUBLIC`, `anon`, `authenticated`, `service_role`, and every existing runtime role.

The migration adds zero:

- database roles;
- capabilities;
- memberships;
- runtimes;
- RLS policies;
- positive runtime/API grants;
- `atlas_api` functions;
- PA-06A entries;
- views/read models;
- commands/events;
- production writers; or
- seed rows.

The existing `confirmed_need_lines` RLS/policies/grants must not be broadened merely because the nullable pointer column exists.

## 8. PA-05D, H0B1b, H0C, and H1A compatibility

The future implementation must preserve exactly:

- PA-05D direct-wholesale behavior and command surface;
- H0B1b exact source family, operational identity, revision, contribution membership, and deferred source/membership guards;
- H0C/CMD-15 Draft-only materialization, runtime, receipt/event/audit behavior, and no-decision invariant;
- H1A policy relation/function/trigger behavior and private security;
- the current 19 physical `atlas_api` functions;
- the 15-write/four-read PA-06A registry; and
- the active OPS v1/Retool operational system untouched.

H1B1 may add a deferred trigger to H1A policy revisions solely to prevent a policy transition from invalidating an existing current decision. With no decision rows and null pointers, that trigger must have no behavioral effect on valid H1A operations.

## 9. Mandatory publication-time impact scan

Before the future implementation issue is published, scan the then-current repository for every planned delta:

```text
relation
column
constraint
index
function
trigger
role
capability
RLS policy
grant
atlas_api function
PA-06A registry entry
workflow suite
whole-platform catalog assertion
documentation count
```

The scan must identify:

- every existing unique/composite key needed by the decision and pointer FKs;
- whether a bounded new revision decision-owner key is required;
- every migration/test that asserts the exact `confirmed_need_lines`, line-revision, H1A policy, function, trigger, grant, or table catalog;
- every workflow path and current TAP total;
- every document that states H1B1 is unapproved; and
- the exact canonical current-platform before/after fingerprints.

Discovery that an earlier domain suite must be changed is a stop condition unless that exact file is explicitly approved after semantic review. Whole-platform totals belong in the canonical catalog suite only.

## 10. Future allowed-file direction

The future implementation issue should authorize only:

1. one CLI-generated H1B1 migration;
2. bounded H1B1 structure/security suite;
3. bounded H1B1 decision-chain/pointer suite;
4. bounded H1B1 policy/quantity-integrity suite;
5. `supabase/tests/atlas_current_platform_security_catalog.sql`;
6. `.github/workflows/supabase-integration.yml`;
7. this task record;
8. the canonical H1B1 decision record;
9. the focused H1B1 architecture contract;
10. `docs/architecture/roadmap.md`; and
11. `docs/decisions/decision-register.md`.

The exact list, migration filename, object counts, fingerprints, and fixed `plan(N)` values must be approved in the future issue before coding.

Do not edit H0B1b, H0C, H1A, PA-05D, PA-06A, React, Retool, package, lockfile, generated-type, credential, or deployment files merely to make implementation convenient.

## 11. pgTAP ownership

Exact plans remain unset until the complete publication-time assertion inventory is proven.

### 11.1 Structure and security

Permanent H1B1 invariants:

- exact decision relation and pointer column;
- exact columns/types/defaults/nullability;
- exact keys/checks/FKs/indexes;
- exact three functions/six triggers;
- ownership, empty search paths, forced RLS, zero policies;
- zero public/API/service/runtime privileges;
- zero role/capability/runtime/API/view/writer/seed delta; and
- exact current-platform catalog delta.

### 11.2 Decision chain and pointer

Permanent evidence invariants:

- exact two-kind vocabulary;
- exact four-reason vocabulary;
- note rules, including mandatory replacement note;
- first and successor decision numbers/predecessors;
- non-forking chain;
- one decision per line per command;
- immutable/no-delete rows;
- one accountable actor;
- pointer null-to-first/direct-successor-only;
- no clear, cross-line, lateral, or ancestor pointer movement; and
- retained historical decisions after pointer advancement.

### 11.3 Revision, policy, and quantity integrity

Permanent authority invariants:

- unchanged acceptance binds current existing revision with no identical successor;
- adjusted decision binds one current direct successor revision;
- exact operational identity/Unit agreement;
- exact H1A policy root/revision binding;
- service-date eligibility and Draft/future/expired/stale/wrong-Unit rejection;
- theoretical/proposal/confirmed quantity equality rules;
- exact numeric tick multiplication;
- no conversion or normalization; and
- policy transition cannot invalidate a current decision.

All fixtures must be synthetic, independently runnable, transactional, and rolled back.

## 12. Validation workflow

The future implementation should run:

- exact baseline/worktree verification;
- `pnpm ops:workspace`;
- clean seedless local reset;
- each H1B1 suite independently;
- canonical current-platform suite independently;
- focused H0B1b suites;
- focused H0C suites;
- all three H1A suites;
- PA-05D compatibility;
- all workflow-registered suites after one reset;
- migration lint and advisors;
- changed SQL/Markdown formatting;
- relative-link validation;
- `git diff --check`;
- exact changed-file and prohibited-file audits; and
- exact catalog and privilege fingerprints.

GitHub Actions at the exact PR head remains authoritative.

## 13. Rollback boundary

Before any decision row or downstream H1B2 reference exists, the one unshipped additive migration may be reverted normally.

After a decision exists:

- do not drop the decision relation;
- do not clear current pointers;
- do not delete or rewrite decisions;
- do not rewrite bound revisions or policy identities; and
- correct defects through a separately reviewed forward migration that preserves all identities and history.

No hosted or production rollback is part of H1B1.

## 14. Stop conditions

Stop the future implementation if:

1. another aggregate, relation, function, trigger, extension, role, capability, runtime, policy, positive grant, API, view, or writer becomes necessary;
2. a generic workflow, polymorphic target, JSON evidence authority, reason table, Unit conversion, fallback, epsilon, or silent normalization appears necessary;
3. current-decision integrity cannot remain bounded and deferred;
4. correction requires update/delete of prior decisions;
5. a proxy actor or unapproved separation-of-duties rule becomes necessary;
6. PA-05D, H0B1b, H0C/CMD-15, or H1A behavior must change;
7. H1B2 command/read behavior becomes necessary to complete H1B1;
8. production writer, seed, hosted Supabase, OPS v1/v2, Retool, React, generated types, credentials, packages, lockfiles, or deployment becomes necessary; or
9. the task cannot remain one additive migration with rolled-back fixtures.

Document the exact contradiction and make no further repository change.

## 15. Definition of done for the future task

- Product approval and canonical registry are linked.
- The branch starts from the exact approved future baseline.
- Exactly one private decision relation and one nullable pointer are implemented.
- Exactly three private functions and six triggers are implemented, unless a separately approved amendment changes the count before coding.
- Decision kinds, reasons, notes, actor, command, quantities, policy, predecessor, and pointer semantics pass.
- No writer, API, runtime access, policy, positive grant, view, or seed is added.
- H0B1b, H0C, H1A, and PA-05D compatibility remains exact.
- The publication-time impact scan and fixed TAP plans are recorded before coding.
- Focused local validation and exact-head CI pass.
- The PR remains unmerged until independent product, architecture, security, and migration review completes.

## 16. Current documentation effect

This file is a future implementation blueprint only. It adds no migration, relation, column, function, trigger, test, workflow registration, role, capability, policy, grant, API, registry entry, read model, command, event, application code, Retool change, hosted action, production row, seed, credential, package, lockfile, or deployment.

Documentation rollback is a normal Git revert.