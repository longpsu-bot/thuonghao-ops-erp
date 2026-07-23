# TASK-PA-06E-H1A - Planning Quantity Policy Persistence

**Status:** Product contract approved; future SQL implementation remains unauthorized until the pre-H1A platform-maintenance dependency is merged

**Preparation issue:** [#145](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/145)

**Preparation baseline:** `5987f1fc9711b7bde094a610e598ff92d71e850d`

**Canonical decision:** [Decision PA-06E-H1A - Planning Quantity Policy](../decisions/decision-pa-06e-h1a-planning-quantity-policy.md)

**Required platform dependency:** [TASK-PLATFORM-PRE-H1A - Current Test-Catalog Consolidation](TASK-PLATFORM-PRE-H1A-current-test-catalog-consolidation.md)

**Migration order:** After merged PA-06E-H0C/CMD-15 and before H1B1 decision persistence

## 1. Objective and authorization boundary

Implement one seedless private persistence slice for the approved Planning quantity-policy contract after the dedicated pre-H1A platform-maintenance task is separately authorized, completed, validated, and merged.

The later implementation may add only:

- one exact controlled-Unit policy root;
- one revision family with positive Planning step, service-date effectivity, bounded lifecycle, and historical preservation;
- the minimum private guards required for immutable-after-activation revisions and deterministic non-overlap;
- rolled-back synthetic pgTAP fixtures; and
- the H1A current-state delta in the already-merged dedicated platform catalog suite.

It must not modify any of the 18 historical suites owned by the platform-maintenance dependency. It also must not implement policy administration commands, runtime authorization, H1B1 decision rows, H1B2 reads/previews/confirmation, validation, approval, release, CMD-03, Procurement, React, Retool, hosted Supabase, production policy rows, credentials, or deployment.

## 2. Future baseline rule

The future implementation issue must name one exact `origin/main` commit before a branch is created. That commit must:

1. include `5987f1fc9711b7bde094a610e598ff92d71e850d` as an ancestor;
2. include the merged product-owner-approved H1A decision record;
3. include the merged PLATFORM-PRE-H1A current test-catalog consolidation;
4. include merged H0C/CMD-15 with the exact 19-function application API surface unless a separately approved intervening change updates the current-state catalog;
5. contain no merged H1B1 or H1B2 implementation;
6. pass `pnpm ops:workspace`; and
7. be clean and equal to the freshly fetched `origin/main` head used by the future issue.

The future issue must record that exact SHA. It must not reuse this documentation branch, the platform-maintenance branch, or the merged H0Cb branch. If current `origin/main` contains a policy, Unit, authorization, test-catalog, or API change that conflicts with this blueprint, stop and amend the decision/task documentation before SQL work.

## 3. Product approval and platform prerequisite

The product owner approved on 2026-07-23:

- H1A-P01 ownership and administration;
- H1A-P02 exact-Unit-only scope;
- H1A-P03 exact precedence;
- H1A-P04 Unit taxonomy and no conversion;
- H1A-P05 exact first-slice step values;
- H1A-P06 exact-tick rejection;
- H1A-P07 service-date/effective-time semantics;
- H1A-P08 revision and stale binding;
- H1A-P09 lifecycle and mutability; and
- H1A-P10 fail-closed behavior; and
- separation of whole-platform test-catalog consolidation into a dedicated pre-H1A maintenance task.

The product-approval gate is satisfied. The future implementation issue must quote the accepted decisions and link this merged decision record.

The SQL gate is not satisfied until the dedicated platform-maintenance task is separately authorized, merged, and green. The H1A issue must link that merged PR and prove that its branch does not modify any of the 18 historical suites.

## 4. Exact future business and physical scope

### 4.1 Business objects

The exact business objects are:

1. `PlanningQuantityPolicy` - stable Planning-owned identity for one exact controlled Unit.
2. `PlanningQuantityPolicyRevision` - one root-local version of the positive Planning step, effective service-date interval, lifecycle, and approval/activation/retirement evidence.

No third scope, generic policy object, policy condition, rule payload, conversion object, priority object, or fallback object is allowed.

### 4.2 Exact relation catalog

The one additive migration creates exactly:

1. `atlas_planning.planning_quantity_policies`
2. `atlas_planning.planning_quantity_policy_revisions`

The exact column direction is controlled by the canonical decision:

#### `planning_quantity_policies`

- `planning_quantity_policy_id`
- `unit_id`
- `created_by_actor_id`
- `created_at`

#### `planning_quantity_policy_revisions`

- `planning_quantity_policy_revision_id`
- `planning_quantity_policy_id`
- `unit_id`
- `revision_number`
- `predecessor_policy_revision_id`
- `planning_step`
- `effective_from`
- `effective_to`
- `policy_revision_status`
- `created_by_actor_id`
- `created_at`
- `approved_by_actor_id`
- `approved_at`
- `activated_by_actor_id`
- `activated_at`
- `retired_by_actor_id`
- `retired_at`

The future issue may refine constraint/index names, but it may not add, remove, or reinterpret a column without an explicit decision amendment.

### 4.3 Exact key, constraint, and index direction

The migration must use:

- database-generated UUID primary keys;
- one unique root per exact `atlas_admin.units.unit_id`;
- restrictive typed Unit and actor FKs;
- composite root/Unit ownership;
- positive contiguous root-local revision numbers;
- one same-root predecessor for every revision after revision 1;
- non-forking predecessor uniqueness;
- `numeric(20,6)` positive `planning_step`;
- exact `DRAFT`, `ACTIVE`, `RETIRED` lifecycle shape;
- `[effective_from, effective_to)` with an optional exclusive end and `effective_to > effective_from`;
- no overlapping Active/Retired interval for one exact Unit;
- `ON DELETE RESTRICT` on every FK;
- no root or revision delete;
- immutable root fields;
- immutable Active payload except the one controlled retirement close;
- fully immutable Retired rows;
- one resolution index ordered by exact Unit/equality fields before effective-date range fields; and
- leading indexes for every operational FK not already covered by a primary/unique key.

Do not add `btree_gist` or another extension merely to implement non-overlap. Use the accepted bounded deferred integrity function unless the future issue separately approves an extension after an impact review.

### 4.4 Exact future function and trigger catalog

The migration creates exactly three private functions:

1. `atlas_planning.pa_06e_h1a_planning_quantity_policy_guard()`
2. `atlas_planning.pa_06e_h1a_planning_quantity_policy_revision_guard()`
3. `atlas_planning.pa_06e_h1a_planning_quantity_policy_effectivity_integrity()`

All three are:

- owned by `atlas_owner`;
- security invoker;
- fixed to an empty `search_path`;
- fully schema-qualified and static;
- inaccessible to `PUBLIC`, `anon`, `authenticated`, `service_role`, and every runtime role.

The migration creates exactly three triggers:

1. one ordinary root immutability/delete guard;
2. one ordinary revision lifecycle/immutability/delete guard; and
3. one `DEFERRABLE INITIALLY DEFERRED` revision effectivity/integrity trigger.

The deferred trigger owns:

- contiguous same-root revision/predecessor integrity;
- non-forking history;
- complete approval/activation/retirement evidence;
- half-open period validity;
- non-overlap for one exact Unit;
- one eligible revision maximum; and
- exact root/revision Unit agreement.

If implementation requires a resolver function, administration function, additional trigger, upstream Unit trigger, extension, or generic helper, stop. That is a contract change, not an implementation convenience.

## 5. Role, capability, runtime, API, and seed decision

H1A creates exactly:

| Catalog                     | Delta |
| --------------------------- | ----: |
| Relations                   |  `+2` |
| Private functions           |  `+3` |
| Triggers                    |  `+3` |
| Roles                       |  `+0` |
| Capabilities                |  `+0` |
| Runtime roles               |  `+0` |
| RLS policies                |  `+0` |
| Positive runtime/API grants |  `+0` |
| `atlas_api` functions       |  `+0` |
| PA-06A API-registry entries |  `+0` |
| Views/read models           |  `+0` |
| Production seed rows        |  `+0` |

Both relations are private, `atlas_owner` owned, RLS-enabled, and forced-RLS with zero policies. Revoke privileges from `PUBLIC`, `anon`, `authenticated`, and `service_role`. Existing runtimes receive no H1A table or function access.

Synthetic Units, actors, policy roots, and revisions may exist only inside independently runnable pgTAP transactions that end in `ROLLBACK`. The migration must contain no `INSERT` into policy relations and must not modify hosted or production data.

## 6. Exact future allowed-file boundary

Before implementation, use the Supabase CLI's `migration new` command to create the one generated migration filename. Replace `<generated-timestamp>` below with that exact CLI-created timestamp in the future issue.

### 6.1 H1A implementation and direct verification

Only these new/changed files are allowed for H1A behavior:

1. `supabase/migrations/<generated-timestamp>_pa_06e_h1a_planning_quantity_policy_persistence.sql`
2. `supabase/tests/pa_06e_h1a_planning_quantity_policy_structure_security.sql`
3. `supabase/tests/pa_06e_h1a_planning_quantity_policy_revision_lifecycle.sql`
4. `supabase/tests/pa_06e_h1a_planning_quantity_policy_effectivity_resolution.sql`
5. `supabase/tests/atlas_current_platform_security_catalog.sql`
6. `.github/workflows/supabase-integration.yml`
7. `docs/decisions/decision-pa-06e-h1a-planning-quantity-policy.md`
8. `docs/implementation-tasks/TASK-PA-06E-H1A-planning-quantity-policy-persistence.md`
9. `docs/architecture/roadmap.md`
10. `docs/decisions/decision-register.md`

### 6.2 Platform-maintenance dependency boundary

The dedicated [PLATFORM-PRE-H1A task](TASK-PLATFORM-PRE-H1A-current-test-catalog-consolidation.md) exclusively owns creation of the current-state suite and relocation of mutable whole-platform assertions from the 18 historical suites.

At the H1A baseline:

- `atlas_current_platform_security_catalog.sql` must already exist and run in CI;
- the platform-maintenance PR must already be merged;
- the 18 historical suites are prohibited H1A files;
- H1A may amend only the dedicated current-state suite for its exact `+2` relation, `+3` function, `+3` trigger, and zero role/capability/policy/API deltas; and
- H1A may not relocate, repair, weaken, or duplicate a whole-platform assertion in a historical suite.

If any historical suite still requires amendment for H1A, stop. The platform-maintenance dependency is incomplete and must be corrected in a separate maintenance PR.

No other file is allowed without an explicit issue amendment. In particular, do not modify PA-06A, package files, generated types, React/TypeScript, Retool, local project credentials, deployment files, or any earlier migration.

## 7. Mandatory pre-publication repository-wide impact scan

Immediately before the future implementation issue is published, scan the then-current repository for every planned catalog delta:

```text
relation
function
role
capability
RLS policy
grant
trigger
API-registry entry
```

The scan must record:

- every migration that creates or grants to the affected schemas/roles;
- every pgTAP assertion that counts or enumerates whole-platform roles, capabilities, policies, grants, triggers, functions, relations, or API entries;
- every workflow that registers a database suite;
- every documentation registry that states an exact catalog count; and
- whether the planned H1A delta is fully expressible in the already-consolidated current-state suite.

The future issue must authorize every affected file and exact expected current-state delta before coding. Discovery of a historical assertion that still needs amendment is a stop condition, not permission to patch that suite in H1A.

## 8. pgTAP decomposition and ownership

Exact `plan(N)` values must be fixed in the future implementation issue after the publication-time impact scan and before code begins.

### 8.1 `pa_06e_h1a_planning_quantity_policy_structure_security.sql`

Permanent H1A domain/security invariants:

- exact two-relation and three-function/three-trigger H1A catalog;
- exact columns, types, database-generated identities, keys, checks, and restrictive typed FKs;
- required FK and effective-resolution indexes;
- `atlas_owner` ownership;
- enabled and forced RLS;
- zero H1A policies;
- no API-role, service-role, or existing-runtime relation/function privilege;
- no public/`ops_v2` copy or compatibility view;
- no role, capability, runtime, `atlas_api` function, PA-06A entry, or production seed attributable to H1A; and
- independently rolled-back fixtures.

The H1A-specific zero-delta assertions above are permanent scope invariants. Whole-platform totals do not belong here.

### 8.2 `pa_06e_h1a_planning_quantity_policy_revision_lifecycle.sql`

Permanent lifecycle/history invariants:

- one root per exact controlled Unit;
- root Unit and identity immutability;
- revision 1 has no predecessor;
- later revisions use contiguous numbers and the direct same-root predecessor;
- predecessor cannot fork or cross roots/Units;
- Draft is never eligible;
- only `DRAFT -> ACTIVE -> RETIRED` succeeds;
- activation requires complete approval and activation evidence;
- Active payload is immutable;
- retirement may close one open interval once and records retirement evidence;
- Retired rows are fully immutable;
- roots and revisions cannot be deleted; and
- historical intervals and actor references remain restrictive and queryable.

### 8.3 `pa_06e_h1a_planning_quantity_policy_effectivity_resolution.sql`

Permanent effectivity/representability invariants:

- positive step;
- exact Unit ownership and no dimension/context scope;
- Asia/Bangkok service-date basis;
- inclusive start and exclusive optional end;
- no overlap for one Unit;
- scheduled future and expired intervals resolve to zero for out-of-range service dates;
- each eligible service date resolves to at most one exact revision;
- no global, Unit-dimension, Customer, School, Ingredient, supplier, or technical fallback;
- exact whole-tick examples pass;
- incompatible precision examples fail without normalization;
- no Unit conversion;
- stale revision binding is detectable by exact re-resolution; and
- approved `0.01 kg` and `1` values are rolled-back fixtures, never migration seed.

H1A has no preview/commit function, so this suite proves physical determinism and exact numeric predicates. H1B2 later owns safe API errors and zero-write command behavior.

### 8.4 `atlas_current_platform_security_catalog.sql`

Current platform assertions only:

- exact Atlas runtime-role catalog;
- exact capability catalog;
- exact RLS-policy catalog by role/verb/schema as approved at the future head;
- exact `atlas_api` function signatures/count and execute allowlist;
- exact whole-platform grants and forbidden grants;
- current private-schema ownership/RLS posture; and
- the H1A delta of two relations, three private functions, three triggers, and zero roles/capabilities/policies/API entries.

This suite must already exist from the merged PLATFORM-PRE-H1A dependency. H1A amends it only for the exact approved H1A delta. Historical PA-04/PA-05/H0 domain suites are prohibited H1A files.

## 9. Assertion classification rule

### Permanent domain invariants

Keep these in the H1A suites:

- positive Planning step;
- exact typed Unit ownership;
- no conversion;
- immutable activated revisions;
- non-overlapping effective periods;
- deterministic exact-Unit resolution;
- exact whole-tick representability;
- stale exact-revision binding;
- fail-closed missing/ambiguous physical state;
- API-role and existing-runtime denial on H1A objects; and
- no production seed.

### Current platform catalog assertions

Keep these only in `atlas_current_platform_security_catalog.sql`:

- exact role count/list;
- exact capability count/list;
- exact whole-platform RLS policy count/list;
- exact whole-platform grant count/list;
- exact `atlas_api` function count/signature list; and
- exact total object deltas at the current head.

Do not copy current-state totals into H0A, H0B1, H0C, PA-04, or PA-05 suites. H1A does not move catalog assertions; the merged platform-maintenance dependency must already have completed that work.

## 10. Migration ordering and execution boundary

The future migration must:

1. follow every merged migration through H0Cb;
2. precede H1B1;
3. be additive and modify no earlier migration;
4. create the two relations, keys, constraints, indexes, three functions, and three triggers in one transaction;
5. apply revoke-first privileges and forced RLS in the same migration;
6. seed no policy, Unit, actor, role, capability, or membership;
7. leave the physical and documented `atlas_api` count unchanged;
8. leave CMD-15 behavior, ownership, grants, policies, request/response, tests, and 19-function registry unchanged; and
9. leave all H0 materialized proposals non-authoritative.

H1A provides persistence only. It has no production writer. Test fixtures use owner-level test setup inside rolled-back transactions.

## 11. Validation workflow

The future implementation should run:

- `git status --short`;
- `pnpm ops:workspace`;
- `pnpm install --frozen-lockfile` only when required;
- seedless local reset;
- the three H1A suites independently;
- the dedicated current platform security/catalog suite independently;
- a prohibited-file audit proving none of the 18 historical suites changed;
- focused H0B1b and H0Cb behavioral compatibility suites;
- migration lint/advisor checks required by the then-current repository workflow;
- changed SQL/Markdown formatting;
- relative Markdown-link validation;
- `git diff --check`; and
- exact changed-file and prohibited-file audits.

The dedicated current-state suite must already be registered by the merged platform-maintenance task. Register only the three new H1A suites in `.github/workflows/supabase-integration.yml`. GitHub Actions remains authoritative for the complete regression.

Do not rerun or weaken unrelated full suites merely to manufacture a local all-green claim. Investigate any focused or CI failure that the bounded change causes.

## 12. Rollback boundary

Before operational policy data or downstream revision bindings exist, the one unshipped additive migration may be reverted normally.

After any activated policy revision or H1B1/H1B2 reference exists:

- do not drop roots or revisions;
- do not delete policy history;
- do not rewrite effective intervals or step values;
- revoke unsafe access if necessary; and
- correct the model through a separately approved forward migration that preserves typed identities and downstream bindings.

No hosted or production rollback is part of H1A. The future PR must state explicitly that it performed no hosted execution and seeded no production policy.

## 13. Stop conditions

Stop the future implementation and apply the repository's blocked workflow if:

1. the implementation conflicts with any approved H1A-P01 through H1A-P10 decision;
2. the exact `0.01 kg` or `1` step is inferred for a Unit outside its approved exact scope;
3. exact-Unit-only scope conflicts with the approved Unit contract;
4. Unit conversion becomes necessary;
5. service-date resolution or half-open effectivity cannot remain deterministic;
6. a generic rule/policy/workflow engine, JSON rule payload, polymorphic scope, or dynamic object name appears necessary;
7. another relation, function, trigger, extension, role, capability, runtime, RLS policy, positive runtime grant, API function, view, or PA-06A entry becomes necessary;
8. a production writer or administration command becomes necessary in H1A;
9. any of the 18 historical suites requires an H1A edit, proving the platform-maintenance dependency is incomplete;
10. a new affected current-state assertion appears outside the exact allowed files;
11. H0C/CMD-15 or PA-05D compatibility would change;
12. production seed, hosted Supabase, Retool, React, generated types, credentials, or deployment becomes necessary; or
13. the task cannot remain one additive migration with rolled-back synthetic fixtures.

Document the exact contradiction and make no further repository change.

## 14. Definition of done for the future task

- Product approval is linked and exact.
- The PLATFORM-PRE-H1A current test-catalog consolidation is merged and linked.
- The branch starts from the recorded future baseline.
- Exactly two private relations, three private functions, and three triggers are implemented.
- Exact-Unit scope, positive step, lifecycle, half-open intervals, non-overlap, immutability, and history pass.
- No role, capability, runtime, policy, API function, registry entry, or production seed is added.
- Permanent H1A invariants and mutable current-state catalog assertions are separated.
- None of the 18 historical suites is modified.
- The publication-time impact scan is recorded and every affected file was pre-authorized.
- H0B1b/H0Cb compatibility remains exact.
- Security implications and rollback boundary are recorded.
- Focused local validation passes and GitHub Actions owns full validation.
- The PR remains unmerged until independent product, architecture, security, and migration review completes.

## 15. Current documentation effect

This file is a blueprint only. It adds no SQL, migration, PostgreSQL object, test, workflow registration, role, grant, policy, generated type, application code, hosted change, seed, credential, or deployment. Documentation rollback is a normal Git revert.
