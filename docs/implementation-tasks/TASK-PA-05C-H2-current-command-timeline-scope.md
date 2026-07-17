# TASK-PA-05C-H2 — Current Command Timeline Scope

## Recommended Codex settings

```text
Model: Sol
Reasoning: Medium
Agents: 1
Parallel agents: Off
Subagents: Off
```

This is a bounded read-only compatibility correction with explicit aggregate vocabulary and security acceptance criteria. Upgrade to High only if Codex demonstrates that the existing public timeline body cannot consume corrected scope rows without a security-contract change.

Do not use a broader model run to redesign the read API.

## Objective

Make the existing `atlas_api.get_command_audit_timeline(jsonb)` read correctly authorize and shape events emitted by the complete current Atlas command surface, without adding a public function or weakening strict scope rules.

## Start state

Start from latest `origin/main` after this documentation prerequisite is merged.

Create:

```text
task/pa-05c-h2-current-command-timeline-scope
```

Verify the canonical workspace exactly as required by `AGENTS.md`.

## Mandatory reading

1. `AGENTS.md`
2. `README.md`
3. required handbook, decision-register, and business-rule files from `AGENTS.md`
4. `docs/architecture/arch-001-ops-erp-business-architecture.md`
5. `docs/architecture/arch-002-atlas-system-map.md`
6. `docs/architecture/pa-05c-authorized-read-api-wrappers.md`
7. `docs/decisions/decision-pa-05c-authorized-read-api-boundary.md`
8. `docs/architecture/pa-05c-h2-current-command-timeline-scope-contract.md`
9. `docs/decisions/decision-pa-05c-h2-current-command-timeline-scope.md`
10. GitHub Issue #102 and all comments
11. current PA-05D, PA-05E, PA-05B, PA-05B-H2, PA-05F, and PA-05B-H3 migrations to confirm exact emitted aggregate names
12. PA-05C and PA-05B-H1 pgTAP suites

The H2 contract, decision, and Issue #102 are the detailed sources of truth.

## OPS_SYSTEM_MAP rule

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

PA-05C-H2 changes only the Read Model/Technology mapping needed to authorize existing events. It creates no new business capability, object, command, event, or application behavior.

## Intended implementation

Create one forward-only migration through the supported Supabase CLI workflow:

```text
supabase/migrations/<generated>_pa_05c_h2_current_command_timeline_scope.sql
```

Before using the CLI inspect:

```text
supabase --version
supabase --help
supabase migration --help
supabase migration new --help
```

Do not invent the migration timestamp and do not edit a merged migration.

Replace only:

```sql
atlas_core.pa_05c_aggregate_scope(text, uuid)
```

Keep:

- return columns and types;
- `STABLE`;
- `SECURITY INVOKER`;
- fixed empty `search_path`;
- static fully qualified SQL;
- owner `atlas_owner`;
- execute only for `atlas_read_runtime`.

Do not replace `atlas_api.get_command_audit_timeline(jsonb)` unless the corrected helper demonstrably cannot satisfy the approved contract. If that happens, stop and report before changing the public function body.

## Exact aggregate vocabulary

Support the current emitted values:

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

Retain the existing aliases:

```text
SUPPLIER_RECEIVING_EVIDENCE
EVIDENCE_APPLICATION
DISPATCH_TRIP
DISPATCH_STOP
DISPATCH_LOAD
DELIVERY_CONFIRMATION
DISPATCH_REQUIREMENT
```

Use explicit branches or explicit `IN (...)` aliases. Do not accept arbitrary case-folded or normalized names.

## Scope mapping

For each aggregate, derive authoritative customer/location and every currently linked trip.

Use exact existing relationships. Do not infer from event payload summaries.

### WholesaleOrder

```text
wholesale root
→ confirmed need
→ handoff
→ Dispatch Requirement
→ plan membership
→ stop/trip when present
```

### PurchaseHandoff

The event aggregate ID is `purchase_handoff_batch_id`. Resolve through its current handoff revision to the Dispatch Requirement and downstream plan/trip.

### DispatchRequirement

Resolve the root and current revision. Join exact plan memberships and stops/trips when present.

### FulfilmentAllocation

Resolve the allocation root to its Dispatch Requirement, current allocation revision, exact plan membership, and trip when present.

### PurchaseOrder

Resolve PO lines/revisions through allocation line revisions and root to the Dispatch Requirement and trip.

### SupplierReceivingEvidence

Resolve source Evidence through its released PO line revision and exact allocation line to the requirement/trip.

### EvidenceApplication

Resolve through the exact allocation line revision/root to the requirement/trip.

### DispatchPlan

Return every authoritative membership customer/location/trip tuple represented by the plan.

### DispatchTrip

Return every authoritative stop customer/location tuple for the trip.

### DispatchStop

Return its exact trip and authoritative Planning destination.

### DispatchLoad

Return its exact trip and requirement destination.

### DeliveryConfirmation

Return its stop/trip and authoritative Planning destination.

When no trip exists for an upstream aggregate, return its customer/location with null trip. When more than one tuple exists, return all tuples.

For a fully completed single-trip correlation, every supported aggregate must resolve to the same trip tuple.

## Public reference

Return one safe reference per scope row using existing business references when practical:

- wholesale customer-order reference;
- purchase-order document number;
- supplier Evidence reference;
- Dispatch Plan reference;
- Dispatch Trip reference.

Fallback to existing aggregate ID text when no safer business reference exists.

Do not expose table names, SQL, or internal policy references.

## Runtime security

Reuse:

```text
atlas_read_runtime
```

Inspect current effective privileges before adding anything.

Add only missing:

- schema `USAGE`;
- table `SELECT`;
- SELECT-only RLS policies;
- private helper execute grant after replacement.

Do not add:

- INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, or TRIGGER;
- sequence USAGE or UPDATE;
- schema CREATE;
- role membership into a command runtime;
- direct private access for `authenticated`, `anon`, or `service_role`.

Preserve the 18-function API execute boundary exactly.

## Tests

Add:

```text
supabase/tests/pa_05c_h2_current_command_timeline_scope.sql
```

Use rolled-back synthetic rows. Do not add persistent seed data.

### Required assertions

Surface/security:

- exactly 18 reviewed `atlas_api` functions;
- authenticated executes exactly 18;
- anon and service_role execute none;
- no API-role direct private-table/view/sequence access;
- helper owner, volatility, security mode, search path, and no dynamic SQL;
- helper executable only by read runtime;
- read runtime has no write, sequence, or schema-CREATE authority.

Aggregate mapping:

- one fixture per exact current aggregate type;
- every current aggregate maps to the expected customer/location/trip;
- every retained uppercase alias maps equivalently;
- current CamelCase aggregate selector succeeds;
- unsupported type fails closed.

Correlation:

- one linked same-trip fixture contains domain and audit rows for all 11 current aggregate types under one correlation;
- GLOBAL actor receives the complete bounded timeline;
- matching DISPATCH_TRIP-scoped actor receives it because upstream aggregates resolve to the trip;
- returned domain/audit counts equal inserted selected counts and remain below 100;
- terminal `SuccessfulDispatchTripClosed` appears;
- no unsafe fields are exposed;
- correlation spanning another location or trip fails `AMBIGUOUS_SCOPE` or the established safe equivalent;
- missing required scope fails safely;
- reads create no receipt, event, audit, or domain mutation.

Retain the existing PA-05C suite. Modify it only for narrow current-name or cumulative expectations when necessary.

## Allowed files

Expected files:

```text
supabase/migrations/<generated>_pa_05c_h2_current_command_timeline_scope.sql
supabase/tests/pa_05c_h2_current_command_timeline_scope.sql
supabase/tests/pa_05c_authorized_read_api_wrappers.sql          # narrow only if required
supabase/tests/pa_05b_h1_runtime_role_hardening_test.sql        # narrow only if privilege expectations change
docs/architecture/pa-05c-h2-current-command-timeline-scope-contract.md
docs/decisions/decision-pa-05c-h2-current-command-timeline-scope.md
README.md
docs/architecture/roadmap.md
```

Do not modify command migrations or application code.

## Simplicity gate

Before finalizing, list every:

- relation newly granted to `atlas_read_runtime`;
- SELECT RLS policy added;
- aggregate branch added;
- test-local helper/table added.

For each, state the exact aggregate mapping or security invariant that requires it.

Remove anything not directly required.

Hard constraints:

- no public function;
- no generic aggregate registry;
- no dynamic SQL;
- no persisted scope cache;
- no graph abstraction;
- no new runtime role;
- no application adapter;
- no UI or generated types;
- no seed data.

## Stop conditions

Stop and produce a contract-gap report when:

- a current aggregate cannot resolve using existing persisted relationships;
- full same-trip resolution requires weakening mixed-scope rejection;
- the public signature or response shape must change;
- a table/registry/new public function/runtime role appears necessary;
- direct private access must be granted to an API role;
- a write command or event type must change.

Do not patch PA-05G in this task.

## Validation economy

Follow `AGENTS.md`.

During implementation run only focused SQL checks.

Near completion run locally:

1. one clean local Supabase reset;
2. `supabase/tests/pa_05c_h2_current_command_timeline_scope.sql`;
3. `supabase/tests/pa_05c_authorized_read_api_wrappers.sql`;
4. `supabase/tests/pa_05b_h1_runtime_role_hardening_test.sql` if grants/RLS or cumulative runtime expectations change;
5. `git diff --check`.

Do not run routine frontend checks locally.

Push the branch and let GitHub Actions own frozen install, workspace validation, formatting, typecheck, full application tests, production build, Storybook, review artifacts, diff validation, and Qodana.

Do not wait for GitHub Actions after opening the draft PR.

## Publication

Commit intentionally, push:

```text
task/pa-05c-h2-current-command-timeline-scope
```

Open a draft PR titled:

```text
PA-05C-H2: Extend current command timeline scope
```

Do not mark ready, merge, close Issue #102, start PA-05G, or deploy anything.

## Required final report

Return:

1. branch and commit SHA;
2. draft PR number;
3. files changed;
4. exact aggregate types and aliases supported;
5. exact scope path for each aggregate class;
6. helper ownership/security;
7. grants and SELECT-only policies added;
8. confirmation API remains 18 functions;
9. complete same-trip and mixed-scope tests;
10. pgTAP assertion counts;
11. focused local validation;
12. checks delegated to GitHub Actions;
13. complexity inventory;
14. contract deviations, or explicitly `none`;
15. confirmation that no command, PA-05G, UI, deployment, live Supabase, production data, Retool, OPS v1, Warehouse, Storage, Edge Function, seed, or generic framework change was added.