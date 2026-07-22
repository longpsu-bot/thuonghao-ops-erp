# TASK-PA-06E-H0B1b — Confirmed Need persistence

**Status:** Implemented and locally validated; draft PR exact-head validation required

**Issue:** [#135](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/135)

**Baseline:** ba6c2de79cb4e825cb377e37443ae38c6fc96ab9

**Branch:** backend/pa-06e-h0b1b-confirmed-need-persistence

**Decision:** [Decision PA-06E-H0B1b](../decisions/decision-pa-06e-h0b1b-confirmed-need-persistence.md)

## Objective

Implement the accepted H0B1 identity and contribution-membership decision as one bounded PostgreSQL persistence change while preserving the merged PA-05D Wholesale command family.

## Delivered scope

- Generalized exactly confirmed_need_batches, confirmed_need_lines, and confirmed_need_line_revisions.
- Created exactly confirmed_need_line_revision_contributions.
- Added the closed WHOLESALE / NEED_GENERATION source classification with complete, mutually exclusive row families.
- Enforced the exact seven-part stable school-catering identity.
- Added restrictive parent keys and composite foreign keys for exact released source, operational ownership, School/customer, and destination/customer facts.
- Enforced exact no-conversion contribution equality.
- Added exactly three private constraint functions and nine triggers.
- Enforced nonempty every-and-only revision membership, exact numeric totals, immutable history, direct-successor current-source advancement, and the exact current-batch partition.
- Preserved existing PA-05D owners, RLS, policies, grants, functions, behavior, and the 18-function API registry.
- Registered four independent H0B1b pgTAP suites after H0A5b and before PA-05G.

## Changed files

- .github/workflows/supabase-integration.yml
- supabase/migrations/20260722041540_pa_06e_h0b1b_confirmed_need_persistence.sql
- supabase/tests/pa_06e_h0b1b_confirmed_need_structure_security_catalog.sql
- supabase/tests/pa_06e_h0b1b_wholesale_compatibility_source_classification.sql
- supabase/tests/pa_06e_h0b1b_school_catering_identity_current_source.sql
- supabase/tests/pa_06e_h0b1b_contribution_membership_total_partition_history.sql
- docs/decisions/decision-pa-06e-h0b1b-confirmed-need-persistence.md
- docs/implementation-tasks/TASK-PA-06E-H0B1b-confirmed-need-persistence.md

No earlier migration or test, PA-05D implementation, application code, package, lockfile, generated type, Retool export, deployment file, or OPS v1 file is changed.

## Acceptance and proof matrix

Each new suite runs after its own seedless local reset:

| Suite                                                  |    Plan |
| ------------------------------------------------------ | ------: |
| Structure, security, and catalog                       |      52 |
| Wholesale compatibility and source classification      |      56 |
| School-catering identity and current source            |      68 |
| Contribution membership, total, partition, and history |      80 |
| **H0B1b total**                                        | **256** |

The final registered Supabase sequence is 19 files and 1138 assertions and runs after one final seedless reset.

Additional validation covers frozen dependency installation; formatting, typecheck, frontend tests, and build; whitespace checks; workspace verification; affected-schema database lint and structural schema diff; exact schema catalogs; owner/RLS/policy/grant and retained PA-05D compatibility; the unchanged 18-function API; zero upstream triggers; forbidden surfaces; and local security and performance advisors.

## Local validation evidence

- Independent seedless resets: 52/52, 56/56, 68/68, and 80/80; each reports Files=1 and Result: PASS.
- H0B1b total: 4 files and 256/256 assertions.
- Final seedless reset and exact registered sequence: 19 files and 1138/1138 assertions; every file reports Result: PASS.
- Database lint: no affected-schema errors.
- Structural schema diff: no changes between migrations and the local database.
- Catalog audit: 4 affected relations, the exact 19-column contribution relation, 3 functions, 9 triggers with the final 5 deferred, 4 atlas_owner relations with forced RLS, zero contribution policies/grants, zero upstream H0B1b triggers, and 18 unchanged atlas_api functions.
- Local Security Advisor: zero errors and no H0B1b warning. Its 18 warnings are the pre-existing signed-in API command-function findings.
- Local Performance Advisor: zero errors and zero warnings. Informational unused-index suggestions are expected for a freshly reset, empty local database.
- Frozen install, formatting, typecheck, 41 frontend test files/265 assertions, and production build pass. The existing nonblocking Vite chunk-size advisory remains.

## Security review

The contribution relation is private: atlas_owner ownership, enabled and forced RLS, zero policies, and zero API/runtime grants. Constraint functions are security invoker with fixed empty search paths and revoked execution. The PA-05D runtime receives no H0A5b or contribution access. Browser/service-role and UI-only enforcement are not introduced.

## Exclusions

This task does not create H0C materialization, H1 decision or review behavior, Purchase Handoff or downstream changes, Unit conversion, supplier allocation, rounding, new APIs, roles, capabilities, events, receipts, audits, application/UI work, hosted Supabase actions, Retool actions, or production-data changes.

## Migration and rollback

The migration is additive and seeds no rows. Before deployment, revert the commit. After deployment, preserve authoritative history and use a reviewed forward migration; dropping generalized columns, guards, keys, or contribution rows is not an authorized rollback.
