# TASK-PA-05C-H2 — Current Command Timeline Scope

## Codex settings

```text
Model: Sol
Reasoning: Medium
Agents: 1
Parallel agents: Off
Subagents: Off
```

Use High only if the existing public timeline cannot consume corrected scope rows without a security-contract change. Stop rather than redesigning the API.

## Objective

Update the existing private command/audit aggregate-scope resolver so `atlas_api.get_command_audit_timeline(jsonb)` can authorize events emitted by the complete current Atlas command surface.

No public API or write behavior changes.

## Start

After this documentation PR is merged, start latest `origin/main` and create:

```text
task/pa-05c-h2-current-command-timeline-scope
```

Read:

1. `AGENTS.md` and its mandatory handbook/register files;
2. `docs/architecture/pa-05c-authorized-read-api-wrappers.md`;
3. `docs/architecture/pa-05c-h2-current-command-timeline-scope-contract.md`;
4. `docs/decisions/decision-pa-05c-h2-current-command-timeline-scope.md`;
5. Issue #102 and all comments;
6. PA-05C and PA-05B-H1 migrations/tests;
7. current PA-05D, PA-05E, PA-05B/H2, PA-05F, and PA-05B-H3 migrations to confirm emitted aggregate names.

## Implement exactly

Create one forward-only migration through the supported Supabase CLI workflow:

```text
supabase/migrations/<generated>_pa_05c_h2_current_command_timeline_scope.sql
```

Inspect first:

```text
supabase --version
supabase --help
supabase migration --help
supabase migration new --help
```

Replace only:

```sql
atlas_core.pa_05c_aggregate_scope(text, uuid)
```

Keep its signature and return columns unchanged. Keep it stable, `SECURITY INVOKER`, fixed `search_path = ''`, static SQL, owned by `atlas_owner`, and executable only by `atlas_read_runtime`.

Do not replace `atlas_api.get_command_audit_timeline(jsonb)` unless the corrected helper demonstrably cannot satisfy the approved contract. Stop and report before changing the public body.

The reviewed API remains exactly 18 functions.

## Aggregate vocabulary

Support exactly:

```text
WholesaleOrder
PurchaseHandoff
DispatchRequirement
FulfilmentAllocation
PurchaseOrder
SupplierReceivingEvidence
EvidenceApplication
DispatchPlan
DispatchTrip
DispatchLoad
DeliveryConfirmation
```

Retain:

```text
SUPPLIER_RECEIVING_EVIDENCE
EVIDENCE_APPLICATION
DISPATCH_TRIP
DISPATCH_STOP
DISPATCH_LOAD
DELIVERY_CONFIRMATION
DISPATCH_REQUIREMENT
```

Do not accept arbitrary normalized names.

## Scope mapping

Derive scope only from current authoritative relationships:

| Aggregate | Resolve through |
| --- | --- |
| Wholesale Order | Confirmed Need → Handoff → Requirement → Plan membership → Stop/Trip |
| Purchase Handoff | current Handoff revision → Requirement → Plan membership → Stop/Trip |
| Dispatch Requirement | current revision → Plan membership → Stop/Trip |
| Fulfilment Allocation | requirement/current allocation revision → exact Plan membership → Stop/Trip |
| Purchase Order | PO lines → allocation lines/root → Requirement → Plan membership → Stop/Trip |
| Supplier Evidence | released PO line → allocation line/root → Requirement → Plan membership → Stop/Trip |
| Evidence Application | allocation line/root → Requirement → Plan membership → Stop/Trip |
| Dispatch Plan | memberships → Requirements → Trips/Stops |
| Dispatch Trip | Stops → Requirements |
| Dispatch Stop alias | Trip → Requirement |
| Dispatch Load | Trip and Requirement |
| Delivery Confirmation | Stop/Trip → Requirement |

Return every tuple. Never sample or use `LIMIT 1`.

Before a trip exists, upstream aggregates may return customer/location with null trip. After admission, return linked trip scope. A completed one-trip correlation must resolve every aggregate to the same tuple. Mixed scopes remain rejected by the existing public read.

Use safe references: customer order reference, PO document number, Evidence reference, plan reference, trip reference, or aggregate ID text.

## Runtime boundary

Reuse `atlas_read_runtime`.

Add only missing schema `USAGE`, table `SELECT`, and SELECT-only forced-RLS policies needed by the joins. Inspect effective privileges before adding grants.

Do not add write privileges, sequence privileges, schema CREATE, command-role membership, or direct private access for `authenticated`, `anon`, or `service_role`.

## Tests

Add:

```text
supabase/tests/pa_05c_h2_current_command_timeline_scope.sql
```

Prove:

- API remains exactly 18 functions with unchanged execute boundary;
- helper ownership, security mode, volatility, search path, static SQL, and private execution;
- read runtime has no write/sequence/schema-CREATE authority;
- every current type and retained alias maps to the expected tuple;
- CamelCase command/correlation/aggregate selectors succeed;
- one correlation containing all current aggregate classes succeeds for GLOBAL and matching DISPATCH_TRIP scope;
- all selected events/audits under 100 are returned and include successful closure;
- missing scope, mixed location/trip, and unsupported aggregate fail closed;
- prohibited fields are absent;
- the read creates no side effect.

Keep the original PA-05C suite intact except narrow cumulative/current-name expectations. Update PA-05B-H1 only if effective read-runtime privilege expectations change.

## Simplicity gate

Expected diff:

```text
one migration replacing one private helper
one focused pgTAP suite
minimum read grants/RLS
narrow docs/test expectation updates
```

No public function, registry, dynamic SQL, graph abstraction, scope cache, materialized view, trigger, job, runtime role, UI, generated type, dependency, or seed data.

Stop if existing relationships cannot derive scope, mixed-scope rejection must weaken, the public shape must change, or a new table/public function/runtime role appears necessary.

## Validation economy

Near completion run locally:

1. one clean local Supabase reset;
2. PA-05C-H2 pgTAP;
3. existing PA-05C pgTAP;
4. PA-05B-H1 pgTAP only if grants/RLS change;
5. `git diff --check`.

Do not run routine frontend checks locally. Push the draft PR and let GitHub Actions own frozen install, workspace, formatting, typecheck, full tests, build, Storybook, artifacts, diff validation, and Qodana. Do not wait for Actions.

## Publication

Open a draft PR titled:

```text
PA-05C-H2: Extend current command timeline scope
```

Do not mark ready, merge, close Issue #102, start PA-05G, or deploy.

Report branch/SHA, PR number, files, mappings, grants/RLS, test counts, focused validation, CI delegation, complexity inventory, deviations, and explicit confirmation that no command, PA-05G, UI, live Supabase, production, Retool, OPS v1, Warehouse, Storage, Edge Function, seed, or framework change was added.