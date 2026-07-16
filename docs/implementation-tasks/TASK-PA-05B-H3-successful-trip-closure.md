# TASK-PA-05B-H3 — Successful Dispatch Trip Closure

## Model and execution settings

- Model: Sol
- Reasoning: High
- Agents: 1
- Parallel agents: Off
- Subagents: Off

## Goal

Implement one bounded Dispatch command that closes a fully delivered and fully reconciled trip without changing earlier Planning, Procurement, Evidence, setup, load, departure, or delivery semantics.

## Branch

Create:

```text
task/pa-05b-h3-successful-trip-closure
```

Start from latest `main` after the PA-05B-H3 documentation prerequisite is merged.

## Read first

Read and follow:

1. `AGENTS.md`
2. `README.md`
3. mandatory handbook, decision-register, and business-rule files required by `AGENTS.md`
4. `docs/architecture/arch-001-ops-erp-business-architecture.md`
5. `docs/architecture/arch-002-atlas-system-map.md`
6. `docs/architecture/dispatch-delivery-domain-contract.md`
7. `docs/architecture/pa-05a-supplier-direct-command-rpc-contract.md`
8. `docs/architecture/pa-05b-h3-successful-trip-closure-contract.md`
9. `docs/decisions/decision-pa-05b-h3-bounded-successful-trip-closure.md`
10. GitHub Issue #93 and all comments
11. relevant PA-04, PA-05B, PA-05B-H1, PA-05B-H2, and PA-05F migrations and tests

The PA-05B-H3 architecture contract, decision, this task, and Issue #93 are the approved sources of truth.

## OPS_SYSTEM_MAP

```text
Mission
→ complete one authoritative supplier-direct wholesale operating path

Business Capability
→ close a successful fully reconciled Dispatch Trip

Business Domain
→ Dispatch

Business Object
→ DispatchTrip

Business Contract
→ all admitted obligations and all current load lines are successfully delivered

Command / Event
→ close_successful_trip / SuccessfulDispatchTripClosed

Read Model
→ no new read API

Application
→ none

Technology
→ one migration, existing Dispatch runtime, exact RLS/grants, focused pgTAP
```

## Required public surface

Add exactly:

```sql
atlas_api.close_successful_trip(request jsonb) returns jsonb
```

Use:

```text
contract_version = PA-05B-H3.v1
```

The reviewed `atlas_api` surface must become exactly 18 functions.

Do not add, rename, overload, or remove another public function.

## Exact payload

```json
{
  "dispatch_trip_id": "uuid",
  "completed_at": "timestamp"
}
```

Use the established ten-field command envelope and exact top-level and payload allowlists.

## Required behavior

The command must:

- resolve the authenticated subject and active actor server-side;
- require `dispatch_trip.close_successful` in `DISPATCH`;
- authorize every authoritative Planning customer/location represented by the trip before receipt registration;
- reject unsupported delegation and management override paths;
- use the current trip version as `expected_version`;
- require trip status `DELIVERED`, non-null departure, and null current completion;
- require valid non-future `completed_at` not earlier than departure or any successful delivery confirmation;
- require at least one stop and every stop `DELIVERED`;
- reconnect every stop to its PA-05F plan membership, current Planning requirement, current allocation, and Planning-owned destination;
- require one exact current confirmed load per stop membership;
- require one exact successful delivery confirmation per current load;
- require every current load line to have exactly one successful confirmation line with exact ingredient, unit, and quantity;
- reject missing, extra, duplicate, cross-wired, partial, excess, wrong-unit, wrong-item, voided, returned, excepted, or unresolved lineage;
- compare raw and valid cardinalities at trip, stop, load, and confirmation-line levels;
- lock deterministically and repeat complete authorization, identity, and reconciliation after locks;
- update only the selected trip;
- preserve `trip_status = DELIVERED`;
- set `completed_at` exactly;
- increment trip version exactly once;
- emit one completed receipt, one `SuccessfulDispatchTripClosed` domain event, and one audit event;
- return one safe success response with IDs, completion time, and new version.

Exact replay must return the stored result without duplicate mutation or facts. Changed command/idempotency reuse must conflict.

Serialization, deadlock, or post-lock scope/identity races must roll back the in-progress receipt and return retryable failure. Do not persist a non-retryable receipt for a transient race.

## Runtime and security

Reuse:

```text
atlas_dispatch_command_runtime
```

Do not create a runtime role.

The function must be:

- `SECURITY DEFINER`;
- volatile;
- owned by `atlas_dispatch_command_runtime`;
- fixed empty `search_path`;
- static SQL only.

Use only exact missing grants and forced-RLS policies. Retain revoke-first API execution.

The runtime may read/lock the required Admin, Planning, Procurement, Evidence, and Dispatch lineage, but may mutate only the selected Dispatch Trip plus receipts/events/audit.

It must have no Planning, Procurement, Evidence, Warehouse, reporting, Storage, legacy, Retool, or OPS v1 mutation authority; no schema `CREATE` after transfer; and no sequence mutation privilege.

## Simplicity gate

Use existing schema objects. Do not add:

- authoritative table, column, view, trigger, sequence, queue, or job;
- another public command;
- another runtime role;
- generic lifecycle, reconciliation, state-machine, workflow, repository, or event-sourcing framework;
- exception, return, cancellation, reopening, trip amendment, or plan closure;
- Finance, payroll, fleet, GPS, fuel, or route optimization;
- read API, UI, generated types, deployment, Storage, Edge Function, seed data, Retool, or OPS v1 changes.

At most one command-specific private validator/reconciliation helper may be added if direct command SQL would otherwise duplicate a large exact proof. Do not refactor PA-05B, H2, or PA-05F helpers merely for reuse.

Before finalizing, inventory every new function, helper, grant, policy, index, constraint, event type, or other mechanism and justify it against one approved closure invariant. Remove anything without a direct justification.

## Migration workflow

Before using Supabase CLI, inspect:

```text
supabase --version
supabase --help
supabase migration --help
supabase migration new --help
```

Create one forward-only migration using the supported CLI workflow. Do not invent the timestamp and do not edit merged migrations.

Expected migration:

```text
supabase/migrations/<generated>_pa_05b_h3_successful_trip_closure.sql
```

## Tests

Add:

```text
supabase/tests/pa_05b_h3_successful_trip_closure.sql
```

Follow every acceptance condition in the architecture contract and Issue #93.

Use command-authored PA-05D, PA-05E, Evidence, PA-05F, and PA-05B-H2 prerequisites where practical. Rolled-back synthetic fixtures are permitted only for narrowly isolated negative corruption cases that cannot be produced through approved commands.

Update cumulative tests only where the reviewed API count, Dispatch runtime owner count, capability inventory, or exact execute boundary changes from 17 to 18.

## Validation economy

Follow `AGENTS.md` validation ownership.

During implementation run only focused SQL checks needed to develop and debug PA-05B-H3.

Near completion run locally:

1. one clean local Supabase reset;
2. PA-05B-H3 pgTAP;
3. PA-05B supplier-direct suite only if shared helpers or cumulative surface checks are changed;
4. PA-05B-H1 runtime hardening;
5. PA-05B-H2 multi-line Dispatch execution;
6. PA-05F Dispatch setup;
7. any predecessor suite directly edited for cumulative expectations;
8. `git diff --check`.

Do not run the full routine frontend suite locally.

After focused database validation:

1. commit intentionally;
2. push the branch;
3. open the draft PR.

GitHub Actions owns frozen install, workspace validation, formatting, typecheck, full application tests, production build, Storybook build, review artifacts, diff validation, and Qodana.

Do not wait for GitHub Actions after opening the draft PR and do not claim checks passed unless completed results were observed.

## Stop conditions

Stop and report instead of improvising if:

- existing trip/load/delivery tables cannot represent the approved closure proof;
- a new authoritative table or column is required;
- trip status must change to a value not already approved;
- delivery semantics or existing H2 functions must change;
- exception, return, cancellation, reopening, or plan closure is required;
- exact trip-wide child cardinality cannot be proven;
- Planning, Procurement, or Evidence mutation is required;
- another public function or runtime role is required.

## Publication

When complete:

1. commit and push `task/pa-05b-h3-successful-trip-closure`;
2. open a draft PR titled:

```text
PA-05B-H3: Add successful Dispatch trip closure
```

3. do not mark ready;
4. do not merge;
5. do not close Issue #93;
6. do not deploy or mutate any external service.

## Final report

Return:

- branch and commit SHA;
- draft PR number;
- files changed;
- exact new public function and total API count;
- request and response shapes;
- rows read, locked, updated, and inserted;
- trip, stop, load, confirmation, quantity, time, authorization, version, and cardinality invariants;
- runtime ownership, grants, revocations, and RLS;
- complexity inventory;
- pgTAP counts and focused local validation;
- checks delegated to GitHub Actions;
- contract deviations, or explicitly `none`;
- confirmation that no PA-05G, UI, deployment, live Supabase, production data, Retool, OPS v1, Warehouse, Storage, Edge Function, seed, exception/return, Finance, HR, fleet, or route-optimization behavior was added.
