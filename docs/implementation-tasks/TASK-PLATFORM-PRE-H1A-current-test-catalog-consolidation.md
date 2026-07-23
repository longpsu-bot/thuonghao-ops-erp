# TASK-PLATFORM-PRE-H1A - Current Test-Catalog Consolidation

**Status:** Future separately authorized platform-maintenance task; required dependency before PA-06E-H1A persistence

**Separation decision:** Approved by the product owner on 2026-07-23 in the Issue #145 task direction

**Consumer:** [TASK-PA-06E-H1A - Planning Quantity Policy Persistence](TASK-PA-06E-H1A-planning-quantity-policy-persistence.md)

**Decision context:** [Decision PA-06E-H1A - Planning Quantity Policy](../decisions/decision-pa-06e-h1a-planning-quantity-policy.md)

## 1. Objective and authorization boundary

Consolidate mutable whole-platform security and API catalog assertions into one dedicated current-state pgTAP suite before H1A adds Planning quantity-policy relations, functions, and triggers.

This task may only:

- create `supabase/tests/atlas_current_platform_security_catalog.sql`;
- move mutable whole-platform assertions out of the exact historical suites listed below;
- adjust only the affected historical `plan(N)` values;
- register the dedicated suite in the Supabase integration workflow; and
- update its own task record and roadmap/decision-register status.

This task must preserve every permanent domain assertion, fixture, command behavior, relation, function, role, capability, RLS policy, grant, API contract, and API-registry entry.

It does not authorize H1A schema work. It creates no migration and changes no production or hosted database.

## 2. Ordering and dependency

The future platform-maintenance issue must start from a clean, freshly fetched exact `origin/main` commit that includes the merged H1A product approval.

The execution order is mandatory:

```text
merged H1A product decision
-> PLATFORM-PRE-H1A test-catalog consolidation
-> PA-06E-H1A Planning quantity-policy persistence
-> PA-06E-H1B1 policy-bound decision persistence
-> PA-06E-H1B2 review/preview/confirmation
```

The platform-maintenance task must merge before the H1A persistence issue is published. H1A must record a baseline that includes the completed consolidation and must not repeat or repair that work in its business-schema PR.

Approval of this separation does not itself authorize implementation. The platform-maintenance issue must still name its exact baseline, exact branch, exact assertion deltas, and exact `plan(N)` changes before editing.

## 3. Exact future allowed-file boundary

### 3.1 New current-state suite and workflow

1. `supabase/tests/atlas_current_platform_security_catalog.sql`
2. `.github/workflows/supabase-integration.yml`
3. `docs/implementation-tasks/TASK-PLATFORM-PRE-H1A-current-test-catalog-consolidation.md`
4. `docs/architecture/roadmap.md`
5. `docs/decisions/decision-register.md`

### 3.2 Historical suites owned only by this maintenance task

At baseline `5987f1fc9711b7bde094a610e598ff92d71e850d`, the repository scan identified mutable whole-platform assertions in these 18 suites:

1. `supabase/tests/pa_04_supplier_direct_slice_1_foundation.sql`
2. `supabase/tests/pa_05b_h1_runtime_role_hardening_test.sql`
3. `supabase/tests/pa_05b_h2_multiline_dispatch_execution.sql`
4. `supabase/tests/pa_05b_h3_successful_trip_closure.sql`
5. `supabase/tests/pa_05c_h2_current_command_timeline_scope.sql`
6. `supabase/tests/pa_05c_h3_evidence_readiness_current_command_context.sql`
7. `supabase/tests/pa_05d_planning_command_family.sql`
8. `supabase/tests/pa_05e_procurement_command_family.sql`
9. `supabase/tests/pa_05f_dispatch_setup_command_family.sql`
10. `supabase/tests/pa_05g_backend_end_to_end_acceptance.sql`
11. `supabase/tests/pa_06e_h0a1_school_customer_location_foundation.sql`
12. `supabase/tests/pa_06e_h0a2_recipe_bom_immutable_reference_foundation.sql`
13. `supabase/tests/pa_06e_h0a3a_weekly_menu_persistence_foundation.sql`
14. `supabase/tests/pa_06e_h0a3b_attendance_structure_security.sql`
15. `supabase/tests/pa_06e_h0a4b_planning_input_readiness_structure_security.sql`
16. `supabase/tests/pa_06e_h0a5b_need_generation_structure_security.sql`
17. `supabase/tests/pa_06e_h0b1b_confirmed_need_structure_security_catalog.sql`
18. `supabase/tests/pa_06e_h0cb_materialization_registry_security_catalog.sql`

The publication-time scan must re-confirm this list against its newer exact baseline. Omit a listed file if it no longer contains a mutable whole-platform assertion. If another affected historical suite appears, stop and amend the task boundary before editing.

No migration, application source, generated type, package file, Retool asset, deployment file, local credential, or earlier migration is allowed.

## 4. Assertion classification

### 4.1 Move to the dedicated current-state suite

Move exact whole-platform assertions for:

- runtime-role catalog;
- capability catalog;
- RLS-policy catalog;
- whole-platform positive and forbidden grants;
- `atlas_api` function signatures and count;
- PA-06A API-registry entries;
- private-schema ownership and forced-RLS posture; and
- whole-platform relation, function, and trigger totals when those totals are intentionally current-state.

The dedicated suite must assert the same or stronger exact current state before the old duplicate is removed.

### 4.2 Keep in historical domain suites

Keep every permanent invariant owned by the historical capability, including:

- domain relation/function/trigger shape;
- domain-specific keys, checks, FKs, indexes, immutability, and lifecycle behavior;
- command authorization and zero-write failure behavior;
- domain-specific privilege denial on the suite's own objects;
- request, response, event, receipt, audit, and API-registry contract for that capability;
- compatibility and regression behavior; and
- all fixtures except changes strictly necessary to keep an unchanged assertion independently runnable.

A historical suite must never become weaker merely to make room for a current-state suite.

## 5. Exact current-state suite responsibility

`atlas_current_platform_security_catalog.sql` is the sole mutable repository-wide catalog suite after this task. It must be independently runnable and transactional.

It owns:

- the exact platform role and capability lists;
- the exact RLS-policy catalog by role, verb, and schema;
- the exact `atlas_api` signature and execute-allowlist catalog;
- exact whole-platform grants and forbidden grants;
- current private-schema ownership and RLS posture; and
- current relation/function/trigger totals intentionally governed at platform level.

It must not duplicate domain behavior, create fixtures that exercise business commands, or become a generic replacement for domain suites.

Later approved schema tasks, including H1A, amend this one suite for their approved current-state deltas. They do not copy new platform totals back into historical suites.

## 6. Implementation and validation workflow

Before coding, the future issue must:

1. record the exact baseline SHA;
2. enumerate every assertion to move and its source suite;
3. classify each assertion as mutable current-state or permanent domain behavior;
4. fix the exact new and changed `plan(N)` values;
5. record the expected zero schema/API/security delta; and
6. authorize every exact changed file.

Focused validation must include:

- the new current-state suite independently;
- all historical suites whose assertions moved;
- workflow registration;
- a repository scan proving no duplicate mutable whole-platform catalog remains in historical suites;
- a diff proving no migration/schema/API/security object changed;
- SQL and Markdown formatting;
- relative Markdown-link validation;
- `git diff --check`; and
- exact changed-file/prohibited-file audits.

GitHub Actions remains authoritative for the complete regression.

## 7. Stop conditions

Stop and amend the task if:

1. any migration, relation, function, trigger, role, capability, policy, grant, API, registry entry, or production row would change;
2. a historical domain assertion or fixture must change behavior;
3. a moved assertion would be weakened, generalized, or dropped;
4. the new suite cannot run independently;
5. another affected file appears outside the approved boundary;
6. H1A business-schema work appears in the same branch or PR;
7. hosted Supabase, production data, credentials, deployment, Retool, React, or generated types become necessary; or
8. the exact platform catalog cannot be reconciled at the selected baseline.

## 8. Handoff contract to H1A

The merged maintenance task must leave:

- one authoritative `atlas_current_platform_security_catalog.sql`;
- all 18 historical suites free of mutable whole-platform catalog assertions that H1A would otherwise need to update;
- unchanged permanent domain behavior;
- exact workflow registration; and
- a clean current-state baseline that H1A can extend.

H1A may later amend the dedicated current-state suite for its approved `+2` relations, `+3` private functions, `+3` triggers, and zero role/capability/policy/API deltas. H1A must not modify any of the 18 historical suites.

If H1A's impact scan proves that a historical suite still requires amendment, H1A stops. The platform-maintenance dependency is incomplete and must be corrected in a separate maintenance PR.

## 9. Rollback and definition of done

This task has no database migration or production rollback. Before H1A begins, the test-only consolidation may be reverted by a normal Git revert.

After H1A or another schema task relies on the dedicated suite, corrections must be forward changes that preserve current catalog coverage and permanent historical domain assertions.

The task is done only when:

- the exact baseline and allowed files are recorded;
- the dedicated current-state suite passes independently;
- every moved assertion remains exact or stronger;
- all affected historical suites pass with domain behavior unchanged;
- no mutable whole-platform catalog duplicate remains in the 18 suites;
- the workflow runs the dedicated suite;
- no schema, API, security, production, or hosted state changed;
- GitHub Actions passes; and
- the PR is merged before H1A persistence is published.
