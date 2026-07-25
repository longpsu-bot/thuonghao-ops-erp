# TASK-PLATFORM-PRE-H1A - Current Test-Catalog Consolidation

**Status:** Implemented and locally validated on Issue #147; pending draft-PR review, exact-head GitHub Actions, and merge before PA-06E-H1A persistence

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

## 10. Issue #147 implementation record

Issue #147 authorized implementation from exact baseline
`35c626adc49d5c09102d8591f42100c0ded8b6c1` on branch
`test/platform-pre-h1a-current-catalog-consolidation`.

The controlling architect amendments are:

1. [Architect amendment and Phase 1 approval](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/147#issuecomment-5056541615) accepted the 60-source-assertion inventory, established the controlling `22 removed = plan(22)` registered relocation rule, approved semantic deduplication of the other 38 unregistered copies, and retained the exact `24 files / 1498 assertions` workflow target.
2. [Architect amendment 2](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/147#issuecomment-5057050349) corrected PA-05C-H2 from SQL-call counting to 42 emitted TAP results and retained the all-candidate arithmetic of 1,042 before, 60 moved, and 982 remaining.
3. [Architect amendment 3](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/147#issuecomment-5077705585) superseded the invalid PA-05D immediate re-enable requirement and approved the rollback-scoped invalid-lineage fixture described below.

The implementation creates one transactional current-state suite at fixed
`plan(22)`, registers it once in the Supabase integration workflow, and removes
only the 60 approved mutable whole-platform copies from the 18 historical
suites. No migration or executable database object changes.

### 10.1 Approved historical plans and validation

| Historical suite                                               |        Registered | Post-move plan |     Local result |
| -------------------------------------------------------------- | ----------------: | -------------: | ---------------: |
| `pa_04_supplier_direct_slice_1_foundation.sql`                 |                No |             16 |       16/16 PASS |
| `pa_05b_h1_runtime_role_hardening_test.sql`                    |                No |              1 |         1/1 PASS |
| `pa_05b_h2_multiline_dispatch_execution.sql`                   |                No |            124 |     124/124 PASS |
| `pa_05b_h3_successful_trip_closure.sql`                        |                No |             44 |       44/44 PASS |
| `pa_05c_h2_current_command_timeline_scope.sql`                 |                No |             42 |       42/42 PASS |
| `pa_05c_h3_evidence_readiness_current_command_context.sql`     |               Yes |             35 |       35/35 PASS |
| `pa_05d_planning_command_family.sql`                           |                No |             69 |       69/69 PASS |
| `pa_05e_procurement_command_family.sql`                        |                No |             74 |       74/74 PASS |
| `pa_05f_dispatch_setup_command_family.sql`                     |                No |             47 |       47/47 PASS |
| `pa_05g_backend_end_to_end_acceptance.sql`                     |               Yes |             78 |       78/78 PASS |
| `pa_06e_h0a1_school_customer_location_foundation.sql`          |               Yes |             56 |       56/56 PASS |
| `pa_06e_h0a2_recipe_bom_immutable_reference_foundation.sql`    |               Yes |             85 |       85/85 PASS |
| `pa_06e_h0a3a_weekly_menu_persistence_foundation.sql`          |               Yes |            100 |     100/100 PASS |
| `pa_06e_h0a3b_attendance_structure_security.sql`               |               Yes |             25 |       25/25 PASS |
| `pa_06e_h0a4b_planning_input_readiness_structure_security.sql` |               Yes |             29 |       29/29 PASS |
| `pa_06e_h0a5b_need_generation_structure_security.sql`          |               Yes |             43 |       43/43 PASS |
| `pa_06e_h0b1b_confirmed_need_structure_security_catalog.sql`   |               Yes |             51 |       51/51 PASS |
| `pa_06e_h0cb_materialization_registry_security_catalog.sql`    |               Yes |             63 |       63/63 PASS |
| **Total**                                                      | **10 registered** |        **982** | **982/982 PASS** |

The dedicated current-platform suite passes 22/22. All 24 workflow-registered
suites pass after one clean database reset. Workflow extraction proves 24 unique
paths, fixed plans in every registered suite, and exactly 1,498 TAP results.

```text
registered total before relocation                 1498
- registered historical results moved                22
+ dedicated current-platform results                  22
                                                    ----
registered total after relocation                  1498

all 18 historical candidates before relocation     1042
- mutable whole-platform results moved                60
                                                    ----
remaining permanent historical results              982
```

### 10.2 PA-05D rollback-scoped invalid fixture

Both valid cross-wire roots are built while normal trigger enforcement is
active. `SET CONSTRAINTS ALL IMMEDIATE` successfully flushes all earlier valid
deferred events, then normal deferred timing is restored. Non-TAP catalog guards
prove both exact triggers start enabled; only
`confirmed_need_lines_h0b1b_guard` is transactionally disabled; and
`confirmed_need_lines_current_source_consistency` remains enabled, a constraint
trigger, deferrable, and initially deferred.

The existing two synthetic lineage updates, command requests, error codes,
assertion labels, and eight zero-write/event/audit assertions are unchanged. A
non-TAP before/after fingerprint proves the rejected Purchase Handoff command
does not further mutate `confirmed_need_lines`. No business command runs after
the final rejection. The existing `finish()` and rollback discard both invalid
states, all pending deferred events, all fixtures, and the temporary trigger
state. A post-rollback non-TAP guard and an independent catalog query prove both
triggers returned to `tgenabled = 'O'`.

The test never alters the deferred consistency trigger, any FK or internal
constraint trigger, any other H0B1 guard, all triggers, or
`session_replication_role`. The 69/69 pass therefore preserves the original
defense-in-depth meaning without a persistent catalog delta.

## 11. Sixty-row semantic coverage matrix

Each source assertion below maps explicitly to equal-or-stronger coverage in
`atlas_current_platform_security_catalog.sql`. `CAT-*` is the stable assertion
label in that suite.

|   ID | Source assertion                                                          | Registered | Canonical destination | Equal-or-stronger proof                                                                 |
| ---: | ------------------------------------------------------------------------- | :--------: | --------------------- | --------------------------------------------------------------------------------------- |
| M-01 | PA-04 #2 — deferred Warehouse schema is absent                            |     No     | CAT-01                | Exact ordered nine-schema allowlist excludes every deferred schema.                     |
| M-02 | PA-04 #3 — complete Atlas table total                                     |     No     | CAT-02                | Replaces stale 52 with the exact selected-baseline total of 82 ordinary tables.         |
| M-03 | PA-04 #4 — complete reporting-view total                                  |     No     | CAT-02                | Exact whole-platform digest retains two views and their catalog fingerprint.            |
| M-04 | PA-04 #5 — all authoritative tables have enabled and forced RLS           |     No     | CAT-03                | Counts all 82 authoritative tables and separately proves 82 enabled and 82 forced.      |
| M-05 | PA-04 #6 — API roles have no private-schema usage                         |     No     | CAT-09                | Scans all three API roles across the exact private-schema allowlist.                    |
| M-06 | PA-04 #7 — API roles have no direct table/view privileges                 |     No     | CAT-10                | Covers every private relation privilege plus sequence privileges.                       |
| M-07 | PA-04 #8 — complete physical Atlas API count                              |     No     | CAT-14                | Replaces stale 15 with the exact selected-baseline count of 19.                         |
| M-08 | PA-05B-H1 #1 — runtime roles have no Atlas schema CREATE                  |     No     | CAT-04                | Exact role catalog includes a zero cross-schema runtime CREATE count.                   |
| M-09 | PA-05B-H1 #2 — retired shared runtime has no relation/sequence privileges |     No     | CAT-11                | Denies schema, relation, sequence, and function privileges across all Atlas schemas.    |
| M-10 | PA-05B-H1 #3 — read runtime is select-only without sequence mutation      |     No     | CAT-12                | Adds zero schema-CREATE and every sequence privilege to the original non-SELECT denial. |
| M-11 | PA-05B-H1 #4 — anon and service role execute no Atlas API                 |     No     | CAT-19/CAT-20         | Separate complete-catalog denials prove zero execution for each forbidden role.         |
| M-12 | PA-05B-H1 #5 — authenticated executes exactly the reviewed API            |     No     | CAT-18                | Exact ordered 19-signature execute allowlist is stronger than a count alone.            |
| M-13 | PA-05B-H1 #6 — API roles have no private relation/sequence privileges     |     No     | CAT-10                | Scans all private relation verbs and all sequence privileges for all API roles.         |
| M-14 | PA-05B-H1 #7 — complete least-privilege function-owner mapping            |     No     | CAT-17                | Exact ordered signature-to-owner mapping covers all 19 functions.                       |
| M-15 | PA-05B-H1 #8 — no API function beyond reviewed surface                    |     No     | CAT-15/CAT-21         | Exact ordered signatures plus an explicit unreviewed-function/overload denial.          |
| M-16 | PA-05B-H1 #10 — no RLS policy exposes API or retired runtime roles        |     No     | CAT-08                | Scans the exact complete current policy catalog for all four forbidden roles.           |
| M-17 | PA-05B-H2 #1 — API roles retain no private-schema usage                   |     No     | CAT-09                | Complete three-role by private-schema denial.                                           |
| M-18 | PA-05B-H2 #2 — only authenticated receives API-schema usage               |     No     | CAT-13                | Exact positive/negative API-schema role allowlist.                                      |
| M-19 | PA-05B-H2 #3 — API roles have no direct table/view access                 |     No     | CAT-10                | Adds every private relation verb and sequence privilege to the original denial.         |
| M-20 | PA-05B-H2 #7 — reviewed API surface has 19 functions                      |     No     | CAT-14/CAT-21         | Exact count plus explicit denial of unreviewed functions and overloads.                 |
| M-21 | PA-05B-H3 #1 — Atlas API contains 19 reviewed functions                   |     No     | CAT-14                | Exact physical function count at the selected baseline.                                 |
| M-22 | PA-05B-H3 #2 — authenticated executes 19 reviewed functions               |     No     | CAT-18                | Exact ordered signature allowlist is stronger than a count.                             |
| M-23 | PA-05C-H2 #1 — complete physical API count                                |     No     | CAT-14                | Exact selected-baseline count of 19.                                                    |
| M-24 | PA-05C-H2 #2 — authenticated executable API count                         |     No     | CAT-18                | Exact ordered 19-signature allowlist.                                                   |
| M-25 | PA-05C-H2 #3 — anon and service role execute no API                       |     No     | CAT-19/CAT-20         | Independent complete-catalog zero-execute denials.                                      |
| M-26 | PA-05C-H2 #4 — API roles have no private relation/sequence access         |     No     | CAT-10                | Complete role/relation/verb and role/sequence/privilege scan.                           |
| M-27 | PA-05C-H3 #1 — reviewed API surface has 19 functions                      |    Yes     | CAT-14                | Exact selected-baseline physical count.                                                 |
| M-28 | PA-05C-H3 #7 — API roles have no private relation access                  |    Yes     | CAT-10                | Adds sequence posture and every private relation privilege.                             |
| M-29 | PA-05D #1 — complete physical API count                                   |     No     | CAT-14/CAT-15         | Replaces stale 17 with exact count 19 and ordered signatures.                           |
| M-30 | PA-05D #10 — authenticated executable API catalog                         |     No     | CAT-18                | Replaces stale 17 with the exact 19-signature allowlist.                                |
| M-31 | PA-05D #11 — anon and service role execute no API                         |     No     | CAT-19/CAT-20         | Separate complete-catalog zero-execute denials.                                         |
| M-32 | PA-05D #12 — API roles have no private relation/sequence access           |     No     | CAT-10                | Complete private relation and sequence privilege denial.                                |
| M-33 | PA-05E #1 — complete physical API count                                   |     No     | CAT-14/CAT-15         | Replaces stale 17 with exact count 19 and ordered signatures.                           |
| M-34 | PA-05E #8 — API roles have no private relation/sequence access            |     No     | CAT-10                | Complete private relation and sequence privilege denial.                                |
| M-35 | PA-05E #9 — authenticated executable API catalog                          |     No     | CAT-18                | Replaces stale 17 with the exact 19-signature allowlist.                                |
| M-36 | PA-05E #10 — anon and service role execute no API                         |     No     | CAT-19/CAT-20         | Separate complete-catalog zero-execute denials.                                         |
| M-37 | PA-05F #1 — complete physical API count                                   |     No     | CAT-14                | Exact selected-baseline count of 19.                                                    |
| M-38 | PA-05F #2 — authenticated executes the reviewed API                       |     No     | CAT-18                | Exact ordered signature allowlist.                                                      |
| M-39 | PA-05F #3 — anon and service role execute no API                          |     No     | CAT-19/CAT-20         | Separate complete-catalog zero-execute denials.                                         |
| M-40 | PA-05F #9 — API roles have no private relation/sequence access            |     No     | CAT-10                | Complete private relation and sequence privilege denial.                                |
| M-41 | PA-05G #79 — complete physical API count                                  |    Yes     | CAT-14                | Exact selected-baseline count of 19.                                                    |
| M-42 | PA-05G #80 — authenticated executes the reviewed API                      |    Yes     | CAT-18                | Exact ordered 19-signature allowlist.                                                   |
| M-43 | PA-05G #81 — anon and service role execute no API                         |    Yes     | CAT-19/CAT-20         | Separate complete-catalog zero-execute denials.                                         |
| M-44 | PA-05G #82 — API roles have no private relation/sequence access           |    Yes     | CAT-10                | Complete private relation and sequence privilege denial.                                |
| M-45 | H0A1 #57 — exact 19-function signature registry                           |    Yes     | CAT-15                | Exact ordered signature catalog retained once.                                          |
| M-46 | H0A1 #58 — application role catalog is empty                              |    Yes     | CAT-04                | Exact database-role posture plus application-role count zero.                           |
| M-47 | H0A1 #59 — exact active Planning capability catalog                       |    Yes     | CAT-05                | Exact code, name, domain, and status retained.                                          |
| M-48 | H0A2 #86 — exact 19-function signature registry                           |    Yes     | CAT-15                | Exact ordered signature catalog retained once.                                          |
| M-49 | H0A2 #87 — application role catalog is empty                              |    Yes     | CAT-04                | Exact database-role posture plus application-role count zero.                           |
| M-50 | H0A2 #88 — exact active Planning capability catalog                       |    Yes     | CAT-05                | Exact code, name, domain, and status retained.                                          |
| M-51 | H0A3a #101 — exact 19-function signature registry                         |    Yes     | CAT-15                | Exact ordered signature catalog retained once.                                          |
| M-52 | H0A3a #102 — application role catalog is empty                            |    Yes     | CAT-04                | Exact database-role posture plus application-role count zero.                           |
| M-53 | H0A3a #103 — exact active Planning capability catalog                     |    Yes     | CAT-05                | Exact code, name, domain, and status retained.                                          |
| M-54 | H0A3b #26 — exact 19-function signature registry                          |    Yes     | CAT-15                | Exact ordered signature catalog retained once.                                          |
| M-55 | H0A3b #27 — application role catalog is empty                             |    Yes     | CAT-04                | Exact database-role posture plus application-role count zero.                           |
| M-56 | H0A3b #28 — exact active Planning capability catalog                      |    Yes     | CAT-05                | Exact code, name, domain, and status retained.                                          |
| M-57 | H0A4b #27 — complete physical API count                                   |    Yes     | CAT-14                | Exact selected-baseline count of 19.                                                    |
| M-58 | H0A5b #37 — complete physical API count                                   |    Yes     | CAT-14                | Exact selected-baseline count of 19.                                                    |
| M-59 | H0B1b #49 — complete physical API count                                   |    Yes     | CAT-14                | Exact selected-baseline count of 19.                                                    |
| M-60 | H0Cb #14 — complete physical API count                                    |    Yes     | CAT-14                | Exact selected-baseline count of 19.                                                    |

The matrix has exactly 60 rows: 22 registered source results and 38
unregistered historical copies. All unique obligations are covered by the 22
canonical assertions without filler, weaker checks, business-fixture
duplication, or executable-platform change.
