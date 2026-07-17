# PA-05G — Backend End-to-End Acceptance Contract

**Status:** Implemented; 82-assertion focused local acceptance passes; pending review and merge
**Issue:** #100  
**Prerequisite:** PA-05C-H2 merged in PR #104 at `649cb953218bfaea401309c0520c49bbce1ced3b`

## Purpose

PA-05G is the final local backend acceptance gate before PA-06 React connection.

It must prove that the existing 18-function `atlas_api` surface can author and safely read one complete supplier-direct wholesale journey without direct operational-table writes or application-layer business logic.

PA-05G adds no business behavior. A failure identifies a predecessor defect and must not be patched inside the acceptance PR.

Passing PA-05G means the supplier-direct Slice 1 backend is locally command-authored and internally accepted. It does not mean Atlas is deployed, production-ready, connected to React/Vercel, or validated against production data.

## Prerequisite gate

PA-05C-H2 Issue #102 is complete. PR #104 replaced the private timeline scope resolver for the current aggregate vocabulary while preserving the public PA-05C read contract, the 18-function API boundary, and fail-closed mixed-scope behavior.

The remaining start gate is:

```text
merge this PA-05G documentation PR
→ implement PA-05G acceptance only
→ review and merge passing PA-05G
→ begin PA-06 React connection planning
```

PA-05G must not absorb any resolver, command, read, privilege, RLS, or migration correction.

## OPS_SYSTEM_MAP

```text
Mission
→ prove one authoritative supplier-direct operating path

Business Capability
→ execute and verify source-to-successful-trip-closure without operational fixtures

Business Domain
→ cross-domain acceptance; no new domain ownership

Business Object
→ existing Planning, Procurement, Evidence, Dispatch, receipt, event, and audit objects

Business Contract
→ every operational fact is command-authored and exactly traceable

Command / Event
→ reuse the existing 14 command types and events; add none

Read Model
→ verify trace, readiness, blockers, and command/audit timeline

Application
→ none

Technology
→ one rolled-back pgTAP acceptance suite and status docs; no migration
```

## Acceptance-only boundary

Add exactly one executable artifact:

```text
supabase/tests/pa_05g_backend_end_to_end_acceptance.sql
```

Do not add or modify migrations, functions, helpers, roles, capabilities, grants, RLS, schema objects, dependencies, application code, generated types, CI workflows, or persistent seed data.

The reviewed API remains exactly **18 functions**.

## Fixture boundary

Rolled-back direct fixture DML is allowed only for unavailable administration prerequisites:

- Core actor/auth/role/capability/membership/scope rows;
- Admin customer, location, ingredient, unit, supplier, and eligibility rows;
- temporary test tables/functions.

After setup, do not directly insert, update, or delete operational facts in Planning, Procurement, Evidence, Dispatch, Audit, or command receipts.

All operational writes must run through `atlas_api` as `authenticated`. Direct private-table `SELECT` assertions are allowed after commands complete.

## Representative scenario

Use one operator with all required command/read capabilities and GLOBAL scope, one active driver, one customer/location, two ingredients, and two eligible suppliers.

Command-author:

```text
one two-line Wholesale Order
→ released Confirmed Need
→ released Purchase Handoff
→ released Dispatch Requirement
→ one two-line allocation split across two suppliers
→ two released supplier POs
→ two Evidence roots and two exact applications
→ one Evidence-gated Dispatch Plan
→ one Plan Requirement membership
→ one assigned Trip and one derived Stop
→ one atomic two-line Load
→ Departure
→ one atomic two-line successful Delivery
→ successful Trip Closure
```

Use one shared correlation ID and unique command IDs/idempotency keys.

Invoke all 14 write-command types. PO release, Evidence recording, and Evidence application each run twice, producing exactly:

```text
17 completed command receipts
17 domain events
17 audit events
```

## Required assertions

### Authoritative state

Prove exact IDs, revisions, quantities, units, suppliers, customer, destination, service date, snapshots, statuses, and versions across the complete chain.

At minimum prove:

- one released two-line Planning chain from Wholesale Order through Dispatch Requirement;
- one ready two-line allocation with different suppliers;
- exactly two released POs, each containing every and only its supplier line;
- exactly two current valid Evidence roots/applications with exact coverage and no over-application;
- one Plan, membership, Trip, and Planning-derived Stop;
- one confirmed two-line Load with two valid Evidence bridges;
- one two-line successful Delivery Confirmation with zero return/exception quantity;
- final Trip remains `DELIVERED`, has exact `completed_at`, and expected final version;
- no extra, missing, voided, superseding, return, exception, or unresolved operational fact;
- exactly 17 completed receipts/events/audits for the shared correlation;
- every success response carries the shared correlation and safe response shape.

### Authorized reads

Invoke all four reads as `authenticated`:

1. `get_supplier_direct_trace` for each wholesale line revision;
2. `get_dispatch_evidence_readiness` for the completed trip;
3. `get_operator_blockers` for the completed trip;
4. `get_command_audit_timeline` for the shared correlation.

Assert existing response shapes only:

- both traces report exact delivered quantity and `DELIVERED` trip status;
- readiness contains both lines in the existing delivered state;
- blockers reports no unresolved actionable work using current vocabulary;
- timeline represents the complete bounded correlation and includes `SuccessfulDispatchTripClosed`;
- request hashes, stored raw responses, credentials/JWT/service-role data, SQL/policy internals, and stack traces are absent;
- reads create no receipt, event, audit, or domain mutation.

### Surface/security

Keep this small:

- exactly 18 API functions;
- `authenticated` executes exactly 18;
- `anon` and `service_role` execute none;
- API roles retain no direct private relation or sequence access.

Predecessor suites retain responsibility for exhaustive command-specific negative and concurrency matrices.

## Fail/stop rule

If any command cannot consume prior command output, a read cannot represent the completed path, or exact lineage/status/version/security does not reconcile:

1. stop;
2. preserve the failing request, safe response, and authoritative evidence;
3. identify the conflicting approved contracts;
4. open or recommend a separate bounded defect issue;
5. do not modify predecessor migrations, functions, grants, RLS, or behavior in PA-05G.

## Simplicity and validation

Expected diff:

```text
one acceptance SQL file
+ narrow result/status documentation updates
```

No generic fixture/scenario framework, orchestration service, persistent test schema, shared production helper, or new dependency.

Near completion run locally:

1. one clean Supabase reset;
2. PA-05G pgTAP;
3. `git diff --check`.

Do not rerun every predecessor suite or routine frontend checks. GitHub Actions owns repository/frontend validation. Do not wait for Actions after opening the draft implementation PR.

## Result gate

A passing reviewed PA-05G unblocks PA-06 React connection planning only. It does not authorize live deployment, production seed/reference data, Retool/OPS v1 change, Vercel production setup, or rollout.

## Implementation outcome

`supabase/tests/pa_05g_backend_end_to_end_acceptance.sql` passes 82 rolled-back assertions after a clean local Supabase reset. It command-authors all 17 executions under one correlation and proves exact two-line/two-supplier lineage through final Trip status `DELIVERED`, Stop version 4, Trip version 5, departure `2026-07-16T18:00:00Z`, and completion `2026-07-16T18:30:00Z`.

The suite observes exactly 17 completed receipts, 17 domain events, and 17 audit events. Both source-line traces return their exact delivered quantities, readiness returns two `DELIVERED` items, blockers returns only two `DELIVERY_COMPLETED` information items, and the timeline returns all 17 domain plus 17 audit events including `SuccessfulDispatchTripClosed`. Read-side row counts remain unchanged.

No contract deviation, migration, function, privilege, RLS, dependency, application, or persistent-data change was required. This result unblocks PA-06 for planning only after review and merge; the existing exclusions remain unchanged.

## Exclusions

No migration, API/read change, live Supabase, production data, credentials, React/UI, Vercel, generated types, Retool/OPS v1 mutation, Warehouse/mixed fulfilment, school catering, exception/return flow, Finance, Production/QA, Storage, Edge Function, performance test, or generic framework.
