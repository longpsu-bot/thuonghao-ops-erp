# TASK-PA-05F — Bounded Dispatch setup command family

**Status:** Ready after this documentation package is merged  
**Issue:** #95  
**Branch:** `task/pa-05f-dispatch-setup-command-family`  
**Draft PR title:** `PA-05F: Add bounded Dispatch setup command family`

## 1. Codex settings

```text
Model: Sol
Reasoning: High
Agents: 1
Parallel agents: Off
Subagents: Off
```

Use one primary implementation run. This is an authoritative multi-root write task with cross-domain Planning, Procurement, PO, and Evidence lineage; all-scope authorization; optimistic versions; stable parent locks; RLS; and a shared least-privilege runtime.

## 2. Verify the workspace

Follow `AGENTS.md` before editing:

```bash
git rev-parse --show-toplevel
git remote -v
git fetch origin
git branch --show-current
git status --short
pnpm ops:workspace
```

Proceed only from the user-authorized real checkout, with a clean tree, correct origin, and latest `origin/main` after the PA-05F documentation package is merged.

Create:

```text
task/pa-05f-dispatch-setup-command-family
```

Do not amend the documentation branch.

## 3. Read before implementation

Read:

1. `AGENTS.md`
2. `README.md`
3. the mandatory handbook, decision-register, and business-rule files named by `AGENTS.md`
4. `docs/architecture/arch-001-ops-erp-business-architecture.md`
5. `docs/architecture/arch-002-atlas-system-map.md`
6. `docs/architecture/dispatch-delivery-domain-contract.md`
7. `docs/architecture/pa-05a-supplier-direct-command-rpc-contract.md`
8. `docs/architecture/pa-05f-dispatch-setup-command-family-contract.md`
9. `docs/decisions/decision-pa-05f-bounded-dispatch-setup.md`
10. Issue #95 and its comments
11. relevant PA-04, PA-05B, PA-05B-H1, PA-05D, PA-05E, and PA-05B-H2 migrations/tests

The PA-05F architecture contract and Issue #95 contain the exact payloads, invariants, outputs, tests, and exclusions. Do not restate or reinterpret them into a broader design. Stop when code or schema contradicts them.

## 4. OPS_SYSTEM_MAP placement

```text
Mission
→ complete one authoritative supplier-direct wholesale operating path

Business Capability
→ group physically ready obligations into an exact Dispatch plan
→ assign exact plan memberships to one executable trip and ordered stops

Business Domain
→ Dispatch

Business Objects
→ DispatchPlan
→ DispatchPlanRequirement
→ DispatchTrip
→ DispatchStop

Business Contract
→ Planning and Procurement remain authoritative upstream owners
→ the physical source remains authoritative for supplier Evidence/applications
→ Dispatch owns grouping, assignment references, and stop order

Commands / Events
→ create_dispatch_plan / DispatchPlanCreated
→ create_or_assign_dispatch_trip / DispatchTripAssigned

Read Model
→ none added

Application
→ none added

Technology
→ one forward-only migration, existing Dispatch runtime, focused pgTAP
```

## 5. Exact implementation scope

Add exactly:

```sql
atlas_api.create_dispatch_plan(request jsonb)
atlas_api.create_or_assign_dispatch_trip(request jsonb)
```

Use:

```text
contract_version = PA-05F.v1
```

The reviewed `atlas_api` surface must contain exactly 17 functions afterward.

Do not add, rename, overload, or remove another public function.

### `create_dispatch_plan`

Implement sections 6 and 9 of the PA-05F contract exactly:

- exact nested request allowlists and named upstream versions;
- authorization for every authoritative Planning destination before receipt registration;
- deterministic locking and post-lock revalidation of the complete PA-05D/PA-05E/released-PO chain;
- current valid source-owned evidence/application coverage for every selected allocation line;
- exact full evidence quantity, source/PO/supplier/item/unit lineage, supersession, and over-application checks;
- one shared service date derived from Planning;
- no non-voided load or valid load-application bridge already consuming the selected pair;
- no active plan membership for a selected exact requirement/allocation pair;
- one `PLANNED` plan plus all submitted memberships atomically;
- one receipt, `DispatchPlanCreated` event, audit event, and safe response;
- no trip, stop, Evidence mutation, load, delivery, or closure fact.

The caller must not choose Evidence IDs. Discover and validate current Evidence from authoritative tables.

### `create_or_assign_dispatch_trip`

Implement sections 7 and 9 of the PA-05F contract exactly:

- exact nested request allowlists;
- current plan expected version;
- active driver and/or non-empty vehicle reference;
- authorization for every authoritative selected-stop destination before receipt registration;
- deterministic upstream Evidence and plan/membership/trip/stop locks with post-lock revalidation;
- current valid Evidence readiness retained for every selected membership;
- disjoint membership subsets so one plan may contain multiple trips;
- unique contiguous stop sequence beginning at 1;
- stop requirement/customer/location derived from Planning;
- null planned stop windows in PA-05F.v1;
- one `ASSIGNED` trip and all `PENDING` stops atomically;
- one plan-version increment, one receipt, `DispatchTripAssigned` event, audit event, and safe response;
- no Evidence mutation, load, departure, delivery, exception, return, or closure fact.

Do not create actor scopes, delegations, HR, fleet, or credential records.

## 6. Runtime and security

Reuse:

```text
atlas_dispatch_command_runtime
```

Do not create another runtime role.

Required posture:

- `NOLOGIN`, `NOINHERIT` retained;
- two new functions owned by the Dispatch runtime;
- fixed empty `search_path`;
- static SQL only;
- revoke-first API execute boundary;
- `authenticated` executes the reviewed 17-function allowlist only;
- `anon` and `service_role` execute no Atlas function;
- API roles retain no direct private relation or sequence access;
- add only missing verb-specific grants and forced-RLS policies;
- Dispatch runtime may read and row-lock approved Planning, Procurement, PO, and Evidence lineage;
- Dispatch runtime may insert plan, membership, trip, stop, receipt, event, and audit rows;
- Dispatch runtime may update only the selected plan root for the PA-05F trip command;
- no Planning, Procurement, Evidence, Warehouse, reporting, Storage, legacy, Retool, or OPS v1 mutation;
- no Atlas schema `CREATE` after ownership transfer;
- no sequence `USAGE` or `UPDATE`.

Add capabilities:

```text
dispatch_plan.create
dispatch_trip.assign
```

Both belong to `DISPATCH`.

A PA-05F validator is allowed only when required for the versioned nested shapes. It must remain command-specific, use an empty search path, be owned by `atlas_owner`, and be executable only by `atlas_dispatch_command_runtime`.

## 7. Simplicity gate

Use only the existing PA-04 Dispatch setup tables:

```text
dispatch_plans
dispatch_plan_requirements
dispatch_trips
dispatch_stops
```

Use existing typed Evidence/application tables as read-only authoritative inputs. Do not copy their state into a new table or JSON snapshot.

Do not add:

- a table, column, view, trigger, sequence, queue, or job;
- a generic routing, scheduling, assignment, evidence, workflow, document, repository, or event-sourcing abstraction;
- a separate plan-admission command;
- an unassigned-trip persistence stage;
- reassignment, cancellation, resequencing, or route-window commands;
- route optimization, GPS, geography, HR, payroll, fleet, fuel, or vehicle master data;
- a read API;
- any Evidence command or Evidence mutation;
- load, departure, delivery, exception, return, or closure behavior;
- UI, generated types, deployment, seed data, Storage, Edge Functions, Retool, or OPS v1 work.

Do not add an index or constraint unless a named, tested PA-05F race cannot be protected by existing constraints and stable parent locks. Stop before introducing a new authoritative concept.

Before finalizing, inventory every new helper, index/constraint, grant, policy, and event:

1. command requiring it;
2. invariant or security boundary protected;
3. failure without it;
4. why an existing object is insufficient.

Remove anything that cannot be justified.

## 8. Migration and permitted files

Before creating the migration, inspect:

```bash
supabase --version
supabase --help
supabase migration --help
supabase migration new --help
```

Create one forward-only migration through the supported Supabase CLI workflow. Do not edit merged migrations or invent the timestamp manually.

Expected new files:

```text
supabase/migrations/<generated>_pa_05f_dispatch_setup_command_family.sql
supabase/tests/pa_05f_dispatch_setup_command_family.sql
```

Narrow updates are permitted only for:

- cumulative API/function-owner expectations changed from 15 to 17;
- PA-05F implementation status and documentation;
- README/roadmap status;
- directly affected PA-05B, PA-05B-H1, and PA-05B-H2 tests.

Stop and explain an unexpectedly broad diff.

## 9. Focused pgTAP acceptance

Implement every test group in section 11 of the PA-05F contract and Issue #95.

At minimum prove:

- exactly 17 reviewed functions and exact runtime ownership/execute boundaries;
- no direct API-role private access, schema `CREATE`, sequence mutation, or cross-domain write authority;
- same-date multi-requirement/multi-destination fully evidenced plan success;
- exact Planning/allocation/released-PO/Evidence lineage and child cardinality;
- full current valid evidence application coverage and source non-over-application;
- all-scope authorization before receipt;
- derived service date and exact membership set;
- mixed date, duplicate, stale, inactive, missing/revised PO, missing/partial/voided/superseded/over-applied/cross-wired Evidence, existing load, already-planned, malformed, and duplicate-reference failures;
- assigned multi-stop trip success from a fully evidenced subset and a second disjoint trip;
- exact Planning-derived stop destinations;
- evidence invalidation after planning blocks trip creation;
- assignment, driver, sequence, membership, stale-plan, lineage, and destination failures;
- replay, nested conflict, atomic failure, one event/audit per success, and exact plan version increments;
- no excluded downstream or Evidence mutations;
- PA-05B, PA-05B-H1, and PA-05B-H2 compatibility.

Use rolled-back synthetic fixtures. Prefer PA-05D, PA-05E, and PA-05B Evidence commands for upstream prerequisites where practical. Add no persistent seed data.

## 10. Validation economy

Follow `AGENTS.md` validation ownership.

During implementation, run only focused checks required to develop and debug PA-05F.

Near completion, run locally:

1. one clean local Supabase reset;
2. PA-05F pgTAP;
3. PA-05B supplier-direct pgTAP because PA-05F consumes Evidence/application semantics;
4. PA-05B-H1 runtime-hardening pgTAP;
5. PA-05B-H2 pgTAP;
6. any predecessor pgTAP directly edited for cumulative expectations;
7. `git diff --check`.

Do not run the routine full frontend suite locally.

Push the branch and open the draft PR. GitHub Actions owns frozen install, workspace validation, formatting, typecheck, full application tests, production build, Storybook build, review artifacts, diff validation, and Qodana.

Do not wait for GitHub Actions after opening the draft PR. Do not claim checks passed until completed results are observed.

## 11. Stop conditions

Stop and produce a contract-gap report when:

- existing tables cannot represent the approved output;
- exact Planning/allocation/released-PO/current-Evidence lineage cannot be proven;
- stable parent locks cannot serialize active plan admission or one-trip-per-membership safety;
- PA-05B-H2 requires mandatory planned windows or another stop shape;
- a separate admission, unassigned-trip, reassignment, cancellation, or update command is required;
- cross-domain or Evidence mutation is required;
- a new public function, table, or column appears necessary;
- implementation would change PA-05B or PA-05B-H2 behavior.

Do not improvise a workaround.

## 12. Publication and report

When focused validation passes:

1. commit intentionally;
2. push `task/pa-05f-dispatch-setup-command-family`;
3. open a draft PR titled `PA-05F: Add bounded Dispatch setup command family`;
4. do not mark ready;
5. do not merge;
6. do not close Issue #95;
7. do not deploy or mutate an external service.

Return:

- branch, commit SHA, and draft PR number;
- files changed;
- exact two-function surface and total API count;
- inputs, outputs, rows read/locked/written/updated, and complete invariants;
- exact Evidence readiness and non-mutation behavior;
- runtime ownership, grants, revocations, and RLS;
- complexity inventory;
- pgTAP counts and focused local validation;
- checks delegated to GitHub Actions;
- contract deviations, or explicitly `none`;
- confirmation that no Evidence command change, PA-05B-H3, PA-05G, UI, deployment, live Supabase, production data, Retool, OPS v1, Warehouse, Storage, Edge Function, seed, HR, fleet, or route-optimization behavior was added.