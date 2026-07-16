# TASK-PA-05B-H2 — Multi-line Dispatch execution correction

## Recommended Codex settings

```text
Model: Sol
Reasoning: High
Agents: 1
Parallel agents: Off
Subagents: Off
```

Use one implementation run. This task modifies three authoritative security-definer commands, nested line/evidence reconciliation, trip-wide authorization, versions, locks, and RLS. Spark is not appropriate for the primary implementation.

## Objective

Correct the existing PA-05B Dispatch execution commands so the authoritative multi-line outputs of PA-05D and PA-05E can be loaded, departed, and successfully delivered.

This task adds no public function, business domain, table, UI, deployment, or PA-05F plan/trip/stop authoring.

Authoritative sources:

1. `AGENTS.md`
2. `docs/architecture/arch-001-ops-erp-business-architecture.md`
3. `docs/architecture/arch-002-atlas-system-map.md`
4. `docs/architecture/dispatch-delivery-domain-contract.md`
5. `docs/architecture/pa-05b-h2-multiline-dispatch-execution-contract.md`
6. `docs/decisions/decision-pa-05b-h2-atomic-multiline-dispatch-execution.md`
7. GitHub Issue #91
8. PA-04, PA-05B, PA-05B-H1, PA-05D, and PA-05E migrations/tests

Use OPS_SYSTEM_MAP v1.0:

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

## Branch and publication

Start from latest `main` after the PA-05B-H2 documentation contract is merged.

Create:

```text
task/pa-05b-h2-multiline-dispatch-execution
```

Open one draft PR titled:

```text
PA-05B-H2: Add atomic multi-line Dispatch execution
```

Do not mark ready, merge, close Issue #91, or deploy.

## Exact public surface

Replace the behavior of exactly these existing functions:

```sql
atlas_api.confirm_dispatch_load(request jsonb)
atlas_api.record_dispatch_departure(request jsonb)
atlas_api.confirm_successful_delivery(request jsonb)
```

Do not add, rename, overload, or remove any public function.

The reviewed `atlas_api` function count must remain exactly 15.

The revised Dispatch execution requests use:

```text
PA-05B-H2.v1
```

The two PA-05B Evidence commands continue to use `PA-05B.v1` unchanged.

## Migration rule

Create one new forward-only migration through the supported Supabase CLI workflow.

Before running commands, inspect:

```text
supabase --version
supabase --help
supabase migration --help
supabase migration new --help
```

Do not edit any merged migration.

The migration may:

- add one private PA-05B-H2 request validator;
- replace the three existing function bodies;
- add only narrowly required grants and forced-RLS policies;
- update function comments.

It must not add a public function, table, view, trigger, sequence, queue, job, extension, or runtime role.

## Command 1 — `confirm_dispatch_load`

### Exact payload

```json
{
  "dispatch_trip_id": "uuid",
  "dispatch_stop_id": "uuid",
  "dispatch_requirement_revision_id": "uuid",
  "fulfilment_allocation_revision_id": "uuid",
  "loaded_at": "timestamptz",
  "lines": [
    {
      "dispatch_requirement_line_revision_id": "uuid",
      "fulfilment_allocation_line_revision_id": "uuid",
      "loaded_quantity": 10,
      "unit_id": "uuid",
      "evidence_applications": [
        {
          "evidence_application_id": "uuid",
          "applied_to_load_quantity": 10,
          "unit_id": "uuid"
        }
      ]
    }
  ]
}
```

### Validation

Enforce exact allowlists at envelope, payload, line, and evidence-application levels.

Bounds:

- 1–100 load lines;
- 1–100 evidence applications per load line;
- positive quantities;
- unique requirement-line revision IDs;
- unique allocation-line revision IDs;
- unique evidence-application IDs across the full request.

Reject the old single-line payload shape.

### Authorization and expected version

- resolve active auth subject and actor server-side;
- require `dispatch_load.confirm` in `DISPATCH`;
- authorize the selected customer/location/trip tuple;
- reject delegation and management override;
- `expected_version` is the current Dispatch Trip version.

### Lock and state behavior

Lock in established order:

1. command receipt;
2. Admin references;
3. complete Planning source lineage;
4. Procurement allocation and supplier-PO lineage;
5. Evidence rows and applications;
6. Dispatch plan, trip, stop, existing loads/lines/applications;
7. audit/event rows.

Use deterministic UUID ordering for multi-row locks.

Allow:

```text
trip status = ASSIGNED or LOADED
selected stop status = PENDING
```

The first successful stop load changes the trip from `ASSIGNED` to `LOADED`. Later stop loads keep the trip `LOADED`. Every successful load command increments the trip version once and the selected stop version once.

### Raw cardinality and lineage

After locks, independently count and require equality across:

```text
stable requirement-root lines
raw children under selected requirement revision
stable allocation-root lines
raw children under selected allocation revision
submitted load lines
fully valid exact-lineage rows
```

Every revision child must point to a stable child owned by its selected root.

For each line prove the complete current PA-05D/PA-05E chain, including:

- requirement root/revision/stable line/line revision;
- handoff revision/line/revision;
- Confirmed Need batch/line/revision/snapshot;
- wholesale order/line/revision;
- allocation root/revision/stable line/line revision;
- current released supplier PO root/revision/stable line/line revision;
- exact customer, location, service date, supplier, ingredient, unit, and quantity.

Require:

```text
requested
= theoretical
= confirmed
= snapshot approved
= demand-reference approved
= handoff
= required
= allocated
= loaded
```

Require allocation source `SUPPLIER_PO`, line status `READY_FOR_EVIDENCE`, and active references.

### Evidence application reconciliation

For every submitted evidence application prove:

- application is current `VALID`;
- supplier evidence is current `VALID`;
- application points to the selected allocation line revision;
- evidence PO line revision belongs to that allocation line revision;
- supplier, ingredient, unit, and service/destination lineage match;
- existing valid load consumption plus submitted bridge quantity does not exceed application quantity.

For each load line require:

```text
sum(submitted evidence bridge quantities)
= loaded quantity
= allocation quantity
```

Reject partial, excess, duplicate, missing, split, cross-wired, converted, rounded, substituted, under-evidenced, invalid-evidence, or over-consumed loads.

### Atomic output

Create:

- one confirmed `dispatch_loads` root;
- one `dispatch_load_lines` row per selected allocation line;
- exact `dispatch_load_line_applications` bridges;
- one completed receipt;
- one `DispatchLoadConfirmed` event;
- one audit event;
- one safe response with all created IDs and versions.

Do not mutate Planning, Procurement, or Evidence facts.

## Command 2 — `record_dispatch_departure`

### Payload

Keep the exact payload:

```json
{
  "dispatch_trip_id": "uuid",
  "departed_at": "timestamptz"
}
```

Reject unknown fields. `departed_at` must not precede any confirmed load time and must not be in the future.

### Trip-wide authorization before receipt

Do not authorize from one sampled stop.

Before receipt registration:

1. retrieve every distinct customer/location tuple for the trip;
2. require at least one stop;
3. call the existing authorization boundary for every tuple with the selected trip ID;
4. fail the whole command when any tuple is unauthorized.

A trip-scoped actor may authorize all tuples. Customer- or location-scoped actors must independently cover every stop.

### Revalidation

After locks, require:

- trip is `LOADED`, not departed, and expected version matches;
- every stop in the selected trip is `LOADED`;
- every stop points to exactly one compatible plan requirement membership;
- every current confirmed load on the trip belongs to one selected-trip stop and its exact requirement/allocation membership;
- every stop has exactly one current confirmed load for its requirement/allocation membership;
- no extra load root exists for the trip outside its stops/memberships;
- for each load, raw load-line count = current allocation-line count = fully valid exact-lineage load-line count;
- every allocation line is loaded exactly once at full quantity and unit;
- every load line has valid bridges whose current valid quantity sums exactly to the loaded quantity;
- every source evidence/application remains valid and exact;
- no evidence application is over-consumed across confirmed loads.

Do not require every plan membership to be on this trip; one plan may contain multiple trips. Validate the selected trip and its stops only.

### Atomic output

- trip `LOADED` → `IN_TRANSIT`, departed timestamp, version +1;
- every trip stop `LOADED` → `IN_TRANSIT`, version +1;
- one completed receipt;
- one `DispatchDeparted` event;
- one audit event;
- one safe response.

## Command 3 — `confirm_successful_delivery`

### Exact payload

```json
{
  "dispatch_trip_id": "uuid",
  "dispatch_stop_id": "uuid",
  "confirmed_at": "timestamptz",
  "received_by_reference": null,
  "notes": null,
  "lines": [
    {
      "dispatch_load_line_id": "uuid",
      "delivered_quantity": 10,
      "returned_quantity": 0,
      "exception_quantity": 0,
      "unit_id": "uuid"
    }
  ]
}
```

Require all top-level fields, allowing `received_by_reference` and `notes` to be null. Enforce exact line allowlists, 1–100 lines, unique load-line IDs, and positive delivered quantities.

Reject the old single-load-line payload shape.

### Authorization and expected version

- require `delivery_success.confirm` in `DISPATCH`;
- authorize selected customer/location/trip;
- `expected_version` is the current Dispatch Trip version.

### Revalidation

After locks, require:

- trip is `IN_TRANSIT` or `PARTIALLY_DELIVERED` and has departed;
- stop belongs to trip and is `IN_TRANSIT`;
- no current valid delivery confirmation exists;
- confirmed time is not before departure and not in the future;
- raw current confirmed load lines for the stop = submitted lines = fully valid exact-lineage lines;
- each submitted line belongs to a current confirmed load on the selected trip and stop;
- no extra, missing, duplicate, cross-wired, or already-confirmed line exists;
- delivered quantity equals loaded quantity exactly;
- unit equals loaded unit exactly;
- returned quantity = 0;
- exception quantity = 0.

### Atomic output

Create:

- one valid delivery confirmation root;
- one delivery confirmation line per current confirmed load line;
- one completed receipt;
- one `SuccessfulDeliveryConfirmed` event;
- one audit event;
- one safe response with all confirmation-line IDs.

Update once:

- selected stop → `DELIVERED`, version +1;
- trip version +1;
- trip status → `DELIVERED` when every stop is delivered, otherwise `PARTIALLY_DELIVERED`.

## Security boundary

Retain:

```text
atlas_dispatch_command_runtime
```

Requirements:

- `NOLOGIN`, `NOINHERIT`;
- owns the same three Dispatch execution functions only within its existing command family;
- fixed empty `search_path`;
- no dynamic SQL;
- no schema `CREATE` after any temporary ownership operation;
- no sequence mutation;
- no new runtime role;
- no Planning, Procurement, or Evidence mutation;
- no Warehouse, Storage, reporting-write, legacy, Retool, or external-service authority;
- extend read/lock grants and forced-RLS policies only when required for exact PO/evidence lineage.

Keep existing capabilities:

```text
dispatch_load.confirm
dispatch_departure.record
delivery_success.confirm
```

Do not add a generic batch capability.

## Command safety

Reuse the existing command receipt, request hash, actor resolution, authorization, safe-error, event, and audit infrastructure.

Required behavior:

- exact nested-payload replay returns original IDs;
- changed nested lines/applications with the same identity returns `IDEMPOTENCY_CONFLICT`;
- stale trip version returns `STALE_VERSION`;
- deterministic post-receipt failures retain one safe failed receipt;
- failed commands create no load, delivery, event, or audit facts;
- serialization and deadlock errors remain retryable whole-command failures.

## Simplicity gate

Before finalizing, inventory every new:

- private helper;
- grant;
- RLS policy;
- index or constraint;
- event change;
- test-only mechanism.

For each, identify:

1. command requiring it;
2. invariant or security boundary protected;
3. failure without it;
4. why existing behavior is insufficient.

Remove anything without a direct PA-05B-H2 invariant.

Hard prohibitions:

- no public function;
- no authoritative table/view/trigger/sequence/queue/job;
- no generic batch, workflow, load, delivery, repository, or event framework;
- no partial load or partial delivery;
- no return/exception/cancellation/closure command;
- no PA-05F plan/trip/stop authoring;
- no Warehouse or mixed-source implementation;
- no UI, generated types, seed data, deployment, or live-system change.

## Required tests

Add:

```text
supabase/tests/pa_05b_h2_multiline_dispatch_execution.sql
```

Update the existing PA-05B pgTAP requests for the three revised Dispatch functions to use `PA-05B-H2.v1` and array payloads. Keep the PA-05B Evidence requests on `PA-05B.v1`.

### Surface/security

Prove:

- exactly 15 reviewed API functions;
- no new public function or runtime role;
- the three functions remain hardened definers owned by Dispatch runtime;
- fixed empty search path and no dynamic SQL;
- exact API-role execute boundary and no direct private access;
- no new cross-domain write privilege.

### Multi-line load

Prove:

- one three-line requirement loads atomically into one root and three lines;
- one line can consume two evidence applications exactly;
- line/bridge counts and quantities reconcile;
- trip/stop versions increment once;
- a second stop can load while trip remains `LOADED` and increments trip once;
- replay adds no rows;
- changed nested payload conflicts;
- old single-line payload fails;
- empty/oversized/unknown-field/duplicate IDs fail;
- missing/extra/cross-wired child cardinality fails;
- partial/excess/wrong unit fails;
- invalid/voided/under-applied/over-consumed evidence fails;
- failure creates no load/event/audit facts.

### Departure

Prove:

- fully loaded multi-stop trip departs;
- missing load, incomplete line coverage, extra load line/root, missing bridge, invalidated evidence, under-coverage, and over-consumption block departure;
- first-stop-only authorization is rejected;
- trip scope or complete relational scope succeeds;
- trip and all stops update exactly once.

### Successful delivery

Prove:

- one multi-line stop creates one confirmation and all exact lines;
- multiple stops confirm sequentially using current trip versions;
- final stop changes trip to `DELIVERED`;
- replay adds no rows;
- old single-line payload fails;
- missing/extra/duplicate/cross-wired load lines fail;
- wrong unit, non-exact quantity, return quantity, and exception quantity fail;
- pre-departure and duplicate confirmation fail;
- failure creates no confirmation/event/audit facts.

### Regression

Run and pass:

- PA-04 pgTAP;
- updated PA-05B pgTAP;
- PA-05C pgTAP;
- PA-05B-H1 pgTAP;
- PA-05D pgTAP;
- PA-05E pgTAP;
- PA-05B-H2 pgTAP.

## Validation

During development run focused H2 tests. Near completion run once:

- full local database reset;
- all pgTAP suites listed above;
- database lint;
- `pnpm ops:workspace`;
- `pnpm format`;
- `pnpm typecheck`;
- `pnpm test`;
- `pnpm build`;
- `git diff --check`.

## Stop conditions

Stop and produce a contract-gap report rather than improvising when:

- existing PA-04 load/confirmation tables cannot represent the atomic multi-line output;
- exact PA-05D/PA-05E/PO/evidence lineage cannot be proven;
- updating the three functions requires changing Evidence command behavior;
- one trip may legitimately require partial stop loading in the immediate Slice 1 path;
- a plan/trip/stop ownership decision is required to implement execution safely;
- current uniqueness constraints make exact multi-line inserts impossible;
- a new authoritative table or public function appears necessary.

## Final report

Return:

1. branch and commit hash;
2. draft PR number;
3. files changed;
4. confirmation that API count remains 15;
5. exact revised payloads;
6. authoritative rows read, locked, written, and updated by each command;
7. cardinality, quantity, lineage, and authorization invariants;
8. runtime grants/RLS changes;
9. complexity inventory;
10. pgTAP counts and full validation results;
11. contract deviations, or `none`;
12. confirmation that no PA-05F behavior, UI, deployment, live system, Retool, OPS v1, Warehouse, Storage, seed, or production data was changed.
