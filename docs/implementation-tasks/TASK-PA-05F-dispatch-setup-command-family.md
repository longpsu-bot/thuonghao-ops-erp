# TASK-PA-05F — Bounded Dispatch setup command family

**Status:** Ready after this documentation package is merged  
**Issue:** #95  
**Branch:** `task/pa-05f-dispatch-setup-command-family`  
**Draft PR title:** `PA-05F: Add bounded Dispatch setup command family`

## 1. Recommended Codex settings

```text
Model: Sol
Reasoning: High
Agents: 1
Parallel agents: Off
Subagents: Off
```

Use one primary implementation run. PA-05F is an authoritative write task involving multi-root versions, cross-domain lineage, all-scope authorization, stable parent locks, RLS, and a shared least-privilege runtime. Spark is not the first implementation model.

## 2. Start-state verification

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

## 3. Mandatory reading

Read before making changes:

1. `AGENTS.md`
2. `README.md`
3. `docs/handbook/01-vision-product-charter.md`
4. `docs/decisions/decision-register.md`
5. `docs/business-rules/business-rule-register.md`
6. `docs/architecture/arch-001-ops-erp-business-architecture.md`
7. `docs/architecture/arch-002-atlas-system-map.md`
8. `docs/architecture/dispatch-delivery-domain-contract.md`
9. `docs/architecture/pa-05a-supplier-direct-command-rpc-contract.md`
10. `docs/architecture/pa-05f-dispatch-setup-command-family-contract.md`
11. `docs/decisions/decision-pa-05f-bounded-dispatch-setup.md`
12. GitHub Issue #95 and its comments
13. PA-04, PA-05B-H1, PA-05D, PA-05E, and PA-05B-H2 migrations/tests

The PA-05F architecture contract, decision record, task, and Issue #95 are the sources of truth. Stop if code or schema contradicts them.

## 4. OPS_SYSTEM_MAP placement

```text
Mission
→ complete one authoritative supplier-direct wholesale operating path

Business Capability
→ create an exact Dispatch plan and assign exact plan memberships to a trip

Business Domain
→ Dispatch

Business Objects
→ DispatchPlan
→ DispatchPlanRequirement
→ DispatchTrip
→ DispatchStop

Business Contract
→ upstream Planning and Procurement facts remain immutable
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

## 5. Exact public surface

Add exactly:

```sql
atlas_api.create_dispatch_plan(request jsonb)
atlas_api.create_or_assign_dispatch_trip(request jsonb)
```

Contract version:

```text
PA-05F.v1
```

The reviewed `atlas_api` surface must contain exactly 17 functions afterward.

Do not add, rename, overload, or remove another public function.

## 6. Command 1 — create Dispatch plan

### Exact payload

```json
{
  "plan_reference": "text",
  "dispatch_wave": null,
  "requirements": [
    {
      "dispatch_requirement_revision_id": "uuid",
      "fulfilment_allocation_revision_id": "uuid",
      "expected_dispatch_requirement_version": 1,
      "expected_fulfilment_allocation_version": 1
    }
  ]
}
```

### Input validation

- exact PA-05F.v1 ten-field envelope;
- envelope `expected_version = 1`;
- exact payload allowlist;
- exact nested requirement allowlist;
- plan reference trimmed, non-empty, max 200;
- nullable wave; if present trimmed, non-empty, max 100;
- 1–100 requirement objects;
- valid UUIDs and positive named versions;
- unique requirement revision, allocation revision, and exact pair;
- no caller service date, customer, location, quantity, supplier, status, actor, or generated ID.

### Authorization before receipt

Resolve every exact pair through authoritative Planning and Procurement records and authorize every distinct Planning customer/location tuple using capability:

```text
dispatch_plan.create
```

One unauthorized tuple rejects the whole request before receipt registration.

Do not authorize from a caller-supplied destination or an unvalidated downstream copy.

### Locked authoritative validation

For every pair, prove the complete current chain described in the PA-05F contract:

- released Planning root/current revision and named root version;
- exact raw/stable/valid requirement-line cardinality;
- complete PA-05D wholesale source lineage;
- current ready allocation root/revision and named root version;
- allocation root belongs to the same requirement root;
- exact raw/stable/valid allocation-line cardinality;
- one full `SUPPLIER_PO` portion per requirement line;
- exact ingredient, quantity, and unit equality;
- exactly one current released PO line/revision per allocation line;
- exact supplier, item, quantity, unit, destination, and service date;
- active customer/location/supplier/ingredient/unit references;
- one shared service date across the request;
- no active plan membership for any selected pair;
- unused plan reference.

Physical Evidence is not required.

### Writes

Create:

- one `dispatch_plans` root in `PLANNED`, version 1;
- one `dispatch_plan_requirements` row per selected pair;
- one completed receipt;
- one `DispatchPlanCreated` event;
- one audit event;
- one safe response.

Create no trip, stop, load, Evidence, delivery, or closure record.

## 7. Command 2 — create and assign one trip

### Exact payload

```json
{
  "dispatch_plan_id": "uuid",
  "trip_reference": "text",
  "driver_actor_id": null,
  "vehicle_reference": "text",
  "planned_departure_at": null,
  "stops": [
    {
      "dispatch_plan_requirement_id": "uuid",
      "stop_sequence": 1
    }
  ]
}
```

### Input validation

- exact PA-05F.v1 envelope;
- envelope `expected_version` is the current plan version;
- exact payload and stop allowlists;
- valid plan UUID;
- trip reference trimmed, non-empty, max 200;
- nullable driver UUID;
- nullable vehicle reference; if present trimmed, non-empty, max 200;
- at least one driver or vehicle reference;
- nullable valid planned-departure timestamptz;
- 1–100 stops;
- unique membership IDs;
- unique positive contiguous sequences beginning at 1;
- no caller destination, requirement revision, status, route window, scope, or generated ID.

### Authorization before receipt

Resolve selected memberships through the current plan, Planning requirements, and allocations. Authorize every distinct authoritative customer/location tuple using:

```text
dispatch_trip.assign
```

The target driver is not the initiating authorization source. Delegation and management override remain unsupported.

### Locked authoritative validation

Prove:

- plan exists, is `PLANNED`, and matches expected version;
- every selected membership belongs to the plan;
- every selected membership retains current released Planning, current ready allocation, and released-PO lineage;
- every selected destination remains active and relationally valid;
- every membership service date equals the plan service date;
- selected memberships are not assigned to a non-cancelled/non-voided trip under the plan;
- trip reference is unused;
- driver, when present, is active and type `HUMAN` or `DELEGATED_DRIVER`;
- assignment values remain valid after locks.

Multiple trip commands may consume disjoint membership subsets.

### Writes

Create/update:

- one `dispatch_trips` root under the plan in `ASSIGNED`, version 1;
- one `dispatch_stops` row per selected membership in `PENDING`, version 1;
- stop requirement/customer/location derived from Planning;
- requested sequence only;
- null planned stop windows;
- plan version incremented exactly once, status unchanged;
- one completed receipt;
- one `DispatchTripAssigned` event;
- one audit event;
- one safe response.

Create no load, Evidence, departure, delivery, exception, return, or closure fact. Do not create actor scopes, delegations, HR, fleet, or credential records.

## 8. Runtime and security

Reuse:

```text
atlas_dispatch_command_runtime
```

Do not create another role.

Requirements:

- role remains `NOLOGIN`, `NOINHERIT`;
- own the two new functions plus the three existing Dispatch execution functions;
- fixed empty `search_path`;
- no dynamic SQL;
- revoke execute from `PUBLIC`, `anon`, `authenticated`, and `service_role` before granting the two reviewed signatures to `authenticated`;
- no API-role private relation or sequence access;
- add only missing verb-specific relation grants and RLS policies;
- insert only plan, membership, trip, stop, receipt, event, and audit rows;
- update only the selected Dispatch Plan version for the trip command;
- no Planning, Procurement, Evidence, Warehouse, reporting, Storage, legacy, or OPS v1 mutation;
- no Atlas schema `CREATE` after temporary ownership transfer;
- no sequence `USAGE` or `UPDATE`.

Add capabilities:

```text
dispatch_plan.create
dispatch_trip.assign
```

Both belong to `DISPATCH`.

A private `atlas_core.pa_05f_validate_command_request(jsonb, text)` may be added only if needed. It must:

- preserve prior validator behavior;
- be owned by `atlas_owner`;
- use a fixed empty search path;
- be executable only by `atlas_dispatch_command_runtime`;
- not become a generic framework.

## 9. Concurrency and idempotency

Reuse existing command helpers where appropriate. Do not refactor PA-05B-H2 helpers merely for aesthetic reuse.

### Plan command

- authorize all tuples before receipt;
- lock selected requirement roots by UUID;
- lock selected allocation roots by UUID;
- lock revisions/children/PO lineage deterministically;
- lock existing Dispatch plan memberships for selected pairs;
- re-read named versions, statuses, destinations, exact cardinalities, and absence of active membership;
- rely on stable parent locks to serialize competing plan admission.

### Trip command

- authorize all selected membership tuples before receipt;
- lock plan root first;
- lock selected plan-membership rows by UUID;
- lock existing trips/stops under the plan deterministically;
- re-read plan version, memberships, destinations, assignment, and unassigned set;
- update plan and insert trip/stops atomically.

Exact replay returns the original response. A changed nested payload under the same identity conflicts. Deterministic failure creates no setup/event/audit mutation. `40001`/`40P01` rolls back the receipt and is retryable.

Do not add a generic concurrency harness, queue, or orchestration layer.

## 10. Persistence and simplicity gate

Use existing tables only:

```text
atlas_dispatch.dispatch_plans
atlas_dispatch.dispatch_plan_requirements
atlas_dispatch.dispatch_trips
atlas_dispatch.dispatch_stops
```

Hard constraints:

- no table or column;
- no view, trigger, sequence, queue, or job;
- no generic routing, scheduling, assignment, workflow, document, repository, or event-sourcing abstraction;
- no separate plan-admission command;
- no unassigned trip stage;
- no reassignment, cancellation, resequencing, or route-window command;
- no route optimization, GPS, geography, HR, payroll, fleet, fuel, or vehicle master;
- no read API;
- no Evidence/load/departure/delivery/closure behavior;
- no UI, generated type, deployment, seed, Storage, Edge Function, Retool, or OPS v1 work.

Do not add an index or constraint unless a named tested PA-05F race cannot be protected by existing constraints plus stable parent locks. Stop and report before introducing a new authoritative concept.

Before finalizing, produce a complexity inventory for every new helper, index/constraint, grant, policy, and event:

1. command requiring it;
2. invariant/security boundary protected;
3. failure without it;
4. why an existing object is insufficient.

Remove anything that cannot be justified.

## 11. Migration workflow

Before running Supabase CLI migration commands, inspect:

```bash
supabase --version
supabase --help
supabase migration --help
supabase migration new --help
```

Create one forward-only migration through the supported CLI workflow. Do not edit merged migrations or invent the timestamp manually.

Expected new files:

```text
supabase/migrations/<generated>_pa_05f_dispatch_setup_command_family.sql
supabase/tests/pa_05f_dispatch_setup_command_family.sql
```

Narrow updates are permitted only to:

- cumulative API/function-owner expectations directly changed from 15 to 17;
- PA-05F architecture/task/status documentation;
- README/roadmap status;
- directly affected PA-05B-H1/H2 tests where the expanded function inventory requires it.

Stop if the diff expands beyond the approved file families without a concrete contract reason.

## 12. Focused pgTAP acceptance

The PA-05F suite must prove at least:

### Security and surface

- exactly 17 functions;
- two hardened new definers owned by Dispatch runtime;
- no new role;
- exact API execute boundary;
- no direct API-role table/view/sequence access;
- no mutable search path or dynamic SQL;
- no schema CREATE or sequence mutation;
- no cross-domain Dispatch mutation;
- no unauthorized Dispatch setup insert by other runtimes.

### Plan

- same-date multi-requirement/multi-destination success;
- derived service date;
- exact submitted membership set;
- exact Planning/allocation/released-PO lineage and cardinality;
- all-scope authorization before receipt;
- mixed date, duplicate pair, malformed shape, stale named version, inactive reference, missing/revised PO, cross-wire, pre-existing active membership, and duplicate reference failure;
- exact replay and nested conflict;
- no partial plan/membership/event/audit facts on failure;
- no trip/stop/load/evidence/delivery facts on success.

### Trip

- assigned multi-stop trip from a subset;
- second disjoint trip under same plan;
- plan version increments once per successful trip command;
- exact derived stop destination;
- no assignment, inactive/wrong-type driver, malformed vehicle, duplicate/non-contiguous sequence, duplicate membership, wrong-plan membership, already-assigned membership, stale plan, upstream change, and cross-wire failure;
- exact replay and nested conflict;
- no plan increment or trip/stop/event/audit facts on failure;
- no load/evidence/departure/delivery/closure facts on success.

### Regression

- PA-05B-H1 runtime ownership/effective privilege expectations remain valid;
- PA-05B-H2 accepts command-authored setup records without public behavior changes.

Use rolled-back synthetic fixtures. Prefer PA-05D and PA-05E commands to author upstream prerequisites where practical. Do not add persistent seed data.

## 13. Validation economy

Follow `AGENTS.md`.

During implementation:

- run focused SQL/pgTAP checks required to develop PA-05F;
- do not repeatedly reset the database;
- do not run the full routine frontend suite locally.

Near completion, run locally:

1. one clean local Supabase reset;
2. `supabase/tests/pa_05f_dispatch_setup_command_family.sql`;
3. `supabase/tests/pa_05b_h1_runtime_role_hardening_test.sql`;
4. `supabase/tests/pa_05b_h2_multiline_dispatch_execution.sql`;
5. any predecessor pgTAP file directly edited for cumulative expectations;
6. `git diff --check`.

Push and open the draft PR. GitHub Actions owns:

- frozen install;
- workspace validation;
- formatting;
- typecheck;
- full application tests;
- production build;
- Storybook build;
- review artifacts;
- diff validation;
- Qodana.

Do not wait for GitHub Actions after opening the draft PR. Do not claim checks passed until observed.

## 14. Stop conditions

Stop and produce a contract-gap report if:

- existing tables cannot represent the approved outputs;
- exact Planning/allocation/released-PO lineage cannot be proven;
- stable parent locking cannot serialize active plan admission or one-trip-per-membership safety;
- H2 needs mandatory planned windows or another stop shape;
- a separate admission, unassigned-trip, reassignment, cancellation, or update command is required;
- cross-domain mutation is required;
- a new public function, table, or column appears necessary;
- implementation would change PA-05B-H2 behavior.

The gap report must identify the exact contract rule, conflicting schema/code, smallest documentation amendment, migration effect, and confirmation that no implementation or external mutation was performed.

## 15. Publication rule

When implementation and focused local validation are complete:

1. commit intentionally;
2. push `task/pa-05f-dispatch-setup-command-family`;
3. open a draft PR titled `PA-05F: Add bounded Dispatch setup command family`;
4. do not mark ready;
5. do not merge;
6. do not close Issue #95;
7. do not deploy or mutate any external service.

Return:

1. branch and commit SHA;
2. draft PR number;
3. files changed;
4. exact two-function surface and total API count;
5. exact payloads and outputs;
6. authoritative rows read, locked, inserted, and updated;
7. complete membership, destination, line-cardinality, version, assignment, and scope invariants;
8. runtime ownership, grants, revocations, and RLS;
9. complexity inventory;
10. pgTAP assertion counts;
11. focused local validation performed;
12. checks delegated to GitHub Actions;
13. contract deviations, or explicitly `none`;
14. confirmation that no PA-05B-H3, PA-05G, UI, deployment, live Supabase, production data, Retool, OPS v1, Warehouse, Storage, Edge Function, seed, HR, fleet, or route-optimization behavior was added.