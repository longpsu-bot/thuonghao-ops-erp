# PA-04 — Supplier-direct Slice 1 migration foundation

**Status:** Implemented in this PR; pending review and merge

**Scope:** First version-controlled Atlas PostgreSQL/Supabase migration foundation for one supplier-direct wholesale happy path

**Authority:** AGENTS.md, ARCH-001, ARCH-002, PA-01, PA-02, PA-03, their companion decisions, the approved Planning, Procurement, Admin, evidence, Dispatch, and Purchase Handoff contracts, and the MVP operator reviews

**Migration:** `supabase/migrations/20260715052252_pa_04_supplier_direct_slice_1_foundation.sql`

**Verification:** `supabase/tests/pa_04_supplier_direct_slice_1_foundation.sql`

**Companion decision:** `docs/decisions/decision-pa-04-first-migration-foundation.md`

## 1. Outcome

PA-04 creates the first real Atlas database objects as new, dedicated Atlas tables. It does not migrate, alter, wrap, or clone OPS v1 tables.

The foundation supports the physical identity and foreign-key trace for this one bounded path:

```text
Wholesale order source and line revision
→ Confirmed Need approval line revision
→ Purchase Handoff release line revision
→ Planning Dispatch Requirement release line revision
→ supplier-direct Fulfilment Allocation line revision
→ Purchase Order line revision
→ supplier receiving evidence
→ mandatory evidence application
→ Dispatch plan / trip / stop / confirmed load
→ load-to-evidence application
→ departure timestamp
→ successful delivery confirmation line
→ command, correlation, event, and audit foundation
```

PA-04 is a table, constraint, grant/RLS, derived-read, and verification foundation. It does not claim that the business commands are implemented.

## 2. Exact scope

Included:

- server-owned actor, authentication-subject registration, role, capability, membership, and typed actor-scope structures;
- idempotency, command ID, correlation ID, request hash, expected-version, and safe response/error receipt storage;
- minimum wholesale customer, location, unit, ingredient, supplier, and supplier-eligibility references;
- stable roots and lines plus immutable release/revision structures for the Slice 1 Planning and Procurement spine;
- source-owned supplier receiving evidence;
- positive, exact evidence application to a fulfilment-allocation-line revision;
- Dispatch planning, independent trip/stop execution, confirmed load, evidence consumption, departure, and successful delivery confirmation;
- append-only domain-event and audit-event envelopes;
- two private `security_invoker` read models for structural verification and future command design;
- local Supabase configuration exposing only `atlas_api` to the Data API;
- pgTAP structural and synthetic happy-path verification.

Excluded:

- Warehouse schema, Warehouse Receiving, stock lots, stock positions, reservations, picks, Warehouse Stock Release, and stock movements;
- school catering recipes, recipe/BOM migration, attendance, Weekly Menu, and recipe calculation;
- delivery exceptions, return evidence, and return-to-stock behavior;
- supplier confirmation as a separate persisted commercial response;
- command/RPC functions and shaped client responses;
- role/capability or master-data seed rows;
- React/Supabase integration and generated database types;
- Storage buckets, evidence files, signed URLs, and malware scanning;
- Edge Functions, Retool changes, legacy extraction, production-data copy, dual write, and operational cutover;
- Production/QA, Finance/Accounting, route optimization, GPS/live tracking, payroll, fleet maintenance, and a generic workflow engine.

## 3. Created schemas

| Schema | Slice 1 purpose | Exposure posture |
| --- | --- | --- |
| `atlas_core` | Actors, authorization relationships, scopes, and command receipts | Private; no API-role usage |
| `atlas_admin` | Minimum wholesale/customer/ingredient/supplier references | Private; no direct client reads or writes |
| `atlas_planning` | Wholesale source through released delivery obligation | Private; command-owned writes are deferred |
| `atlas_procurement` | Supplier-direct allocation and PO commitment | Private; command-owned writes are deferred |
| `atlas_evidence` | Supplier receiving evidence and exact quantity applications | Private and source-owner controlled |
| `atlas_dispatch` | Plan, trip, stop, load, departure, and successful delivery | Private; command-owned writes are deferred |
| `atlas_audit` | Domain events and audit events | Private and append-only by command pattern |
| `atlas_reporting` | Two private derived verification/read views | Private; never a safety gate |
| `atlas_api` | Reserved future function-only Data API boundary | Exposed in local config but empty and ungranted |

`atlas_warehouse`, `atlas_legacy`, and other deferred schemas are not created.

## 4. Created table families

PA-04 creates 52 tables.

### `atlas_core` — 8 tables

- `actors`
- `actor_auth_subjects`
- `roles`
- `capabilities`
- `role_capabilities`
- `actor_role_memberships`
- `actor_scopes`
- `command_receipts`

`actor_auth_subjects` stores a unique registered Supabase Auth subject identifier. It deliberately does not require an unauthorized foreign key into Supabase-owned `auth.users`; future actor resolution must validate the subject server-side.

### `atlas_admin` — 6 tables

- `customers`
- `delivery_locations`
- `units`
- `ingredients`
- `suppliers`
- `supplier_eligibilities`

The Slice 1 customer type and fulfilment source are constrained to `WHOLESALE` and `SUPPLIER_PO`. This is a bounded foundation, not a partial Warehouse implementation hidden in generic fields.

### `atlas_planning` — 17 tables

- wholesale source: `wholesale_orders`, `wholesale_order_lines`, `wholesale_order_line_revisions`;
- Planning approval: `confirmed_need_batches`, `confirmed_need_lines`, `confirmed_need_line_revisions`, `confirmed_need_approval_snapshots`, `confirmed_need_snapshot_lines`;
- Purchase Handoff: `purchase_handoff_batches`, `purchase_handoff_revisions`, `purchase_handoff_lines`, `purchase_handoff_line_revisions`, `purchase_demand_references`;
- delivery obligation: `dispatch_requirements`, `dispatch_requirement_revisions`, `dispatch_requirement_lines`, `dispatch_requirement_line_revisions`.

The Dispatch Requirement revision is the Planning release snapshot for this slice. A separate generic Planning release table is not added because it would duplicate the same bounded release identity without adding a required Slice 1 command.

### `atlas_procurement` — 8 tables

- `fulfilment_allocations`
- `fulfilment_allocation_revisions`
- `fulfilment_allocation_lines`
- `fulfilment_allocation_line_revisions`
- `purchase_orders`
- `purchase_order_revisions`
- `purchase_order_lines`
- `purchase_order_line_revisions`

Supplier confirmations are deferred because the approved happy path does not require a separate commercial-response fact before physical supplier evidence can be represented. Adding that command and table remains a bounded follow-up when its exact response contract is approved.

### `atlas_evidence` — 2 tables

- `supplier_receiving_evidence`
- `evidence_applications`

### `atlas_dispatch` — 9 tables

- `dispatch_plans`
- `dispatch_plan_requirements`
- `dispatch_trips`
- `dispatch_stops`
- `dispatch_loads`
- `dispatch_load_lines`
- `dispatch_load_line_applications`
- `delivery_confirmations`
- `delivery_confirmation_lines`

The delivery tables are intentionally constrained to the successful `DELIVERED` path. Exception and return quantities remain zero until their separate evidence/closure tables and commands are approved.

### `atlas_audit` — 2 tables

- `domain_events`
- `audit_events`

These tables explain commands and changes. They are not an event-sourced replacement for current aggregate state.

## 5. PA-01, PA-02, and PA-03 conformance

PA-01 conformance:

- every root, stable line, revision, evidence fact/application, command receipt, event, and audit row has an opaque UUID primary key;
- released execution links carry exact revision IDs rather than display references;
- mutable roots carry positive `version bigint` values;
- released history uses revision/snapshot rows rather than recalculation from current master data;
- physical evidence remains in `atlas_evidence`, outside Procurement and Dispatch ownership;
- read models remain derived.

PA-02 conformance:

- Atlas uses lowercase `snake_case` and dedicated domain namespaces;
- primary keys use database-generated `gen_random_uuid()` as approved;
- operational quantities use `numeric(20,6)` and explicit unit foreign keys;
- no authoritative column uses binary floating point;
- instants use `timestamptz` and operating dates use `service_date date`;
- statuses use domain-local text columns with named checks;
- operational foreign keys are typed and use `on delete restrict`;
- important joins, status/service-date work, evidence applications, trips, and audit correlation have explicit indexes.

PA-03 conformance:

- no-login owner, future command-runtime, and future read-runtime PostgreSQL roles are created;
- the managed `postgres` migration administrator may set the no-login object-owner role;
- all Atlas domain tables are owned under the private Atlas schemas;
- RLS is enabled and forced on every authoritative table;
- no RLS policy grants blanket authenticated access;
- `PUBLIC`, `anon`, `authenticated`, and `service_role` receive no Atlas schema, table, view, sequence, or function privilege;
- revoke-first default privileges cover future Atlas objects;
- `atlas_api` exists but has no function and no execute grant;
- reporting views use `security_invoker = true` and remain private;
- no service-role credential or client authorization shortcut is added.

## 6. Evidence application design

`supplier_receiving_evidence` records the physical observation owned by the supplier-receiving process. It references the exact released PO line revision, supplier, ingredient, quantity, unit, actor, occurrence time, recording time, command ID, and correlation ID.

`evidence_applications` then applies a strictly positive quantity from exactly one supplier evidence row to exactly one `fulfilment_allocation_line_revision_id`.

Plain SQL enforcement includes:

- mandatory typed evidence and allocation-line-revision foreign keys;
- positive `applied_quantity` and a unit foreign key;
- lifecycle values `VALID`, `SUPERSEDED`, and `VOIDED`;
- a partial unique index preventing two active applications for the same evidence/allocation-line-revision pair;
- immutable correction linkage through `supersedes_evidence_application_id`;
- command, actor, occurrence, recording, and correlation context;
- Dispatch load consumption only through `dispatch_load_line_applications`.

Aggregate over-application cannot be enforced safely by a row check. The next command/RPC task must lock the allocation-line revision, evidence row, and active application rows in the PA-03 order, normalize approved units, sum current applications, reject over-application, and insert the evidence plus applications atomically.

The same command-layer requirement applies to preventing total load consumption from exceeding a valid evidence application. The database foundation supplies positive quantities, exact foreign keys, active-pair uniqueness, and indexes; it does not pretend those aggregate commands already exist.

## 7. Structurally supported commands

The schema supplies identity, versions, exact revision references, command IDs, correlation IDs, idempotency receipts, events, and audit envelopes for future implementations of:

- create, validate, approve, release, reopen, and revise wholesale/Confirmed Need work;
- prepare, validate, release, invalidate, and revise Purchase Handoff;
- release or revise a wholesale Dispatch Requirement;
- allocate or revise supplier-direct fulfilment;
- create, validate, release, revise, or cancel a PO;
- record, supersede, or void supplier receiving evidence and applications;
- create a Dispatch plan, assign a trip, confirm a load, record departure, confirm successful delivery, and close a successful trip.

Structural support means the required identities and columns exist. It does not mean the lifecycle, authorization, locking, idempotency, audit atomicity, and error contract have been implemented as callable functions.

## 8. Commands still not implemented

PA-04 exposes no RPC or command function. PA-05 or a bounded PA-04.x follow-up must define the exact function signatures and response envelopes before implementation.

At minimum, the next supplier-direct command slice must implement and test:

- server-side actor/capability/scope resolution;
- canonical request hashing and command-receipt replay/conflict behavior;
- expected-version rejection;
- exact lock ordering and short transactions;
- supplier eligibility and source/item/unit validation;
- evidence and load aggregate-sum locking;
- departure revalidation against current valid evidence/applications;
- delivery-to-load reconciliation;
- atomic command receipt, domain event, and audit event creation;
- safe error envelopes without internal SQL details.

Until those functions exist and pass security/concurrency tests, no React client may connect for authoritative Atlas work.

## 9. Private read models

`atlas_reporting.dispatch_evidence_readiness` derives valid applied, loaded, and uncovered quantities for each exact allocation-line revision. It is useful for verification and future read-command design, but departure must never trust this view without re-reading and locking authoritative rows.

`atlas_reporting.supplier_direct_slice_trace` composes the exact line spine from the wholesale source revision through successful delivery. It does not persist a duplicate trace table.

Neither view is granted to an API role. Future `atlas_api` read functions must perform current actor/capability/scope checks and return shaped, minimized results.

## 10. Migration and verification

The repository now has a standard local Supabase configuration:

- PostgreSQL major version 17;
- migrations enabled;
- seed execution disabled;
- Data API schema list restricted to `atlas_api`;
- no project reference, credential, or hosted link.

The migration was applied from a clean database using the local Supabase PostgreSQL `17.6.1.005` image. The pgTAP file runs in a transaction and rolls back all synthetic fixture data.

The 20 checks prove:

- exact schema and table bounds;
- no Warehouse schema;
- RLS enabled and forced on all 52 authoritative tables;
- no direct `anon`, `authenticated`, or `service_role` Atlas access;
- empty `atlas_api` function surface;
- no binary floating-point columns;
- evidence application positivity, exact revision linkage, and active duplicate prevention;
- load-to-evidence-application linkage;
- `security_invoker` reporting views;
- no-login database boundary roles;
- required audit and Dispatch indexes;
- one synthetic 10 kg wholesale supplier-direct path with sufficient evidence and one exact source-to-delivery trace row.

Local verification commands:

```bash
supabase db start
supabase db reset --local
supabase test db supabase/tests/pa_04_supplier_direct_slice_1_foundation.sql --local
```

The implementation validation used a disposable local database only. No linked or hosted Supabase command was run.

## 11. Rollback effect

PA-04 is additive and contains no destructive statement or OPS v1 mutation.

Before any environment deployment, rollback is a normal Git revert of the migration, test, config, and documentation.

If this migration is later applied to an approved non-production environment, rollback requires a separately reviewed reverse migration that drops the two derived views, then the new Atlas tables in reverse foreign-key order, then the new schemas and unused no-login roles. That reverse operation would delete Atlas data in those new objects and therefore must not be generated or executed casually.

No production rollback is required for this PR because no live deployment or production data change occurred.

## 12. Remaining gates before React can connect

- approve exact `atlas_api` command signatures and shaped read responses;
- implement command runtime privileges without granting direct domain-table access;
- seed reviewed role/capability vocabulary and first-slice master/reference data through a separately approved task;
- implement actor, membership, capability, and typed-scope authorization;
- implement idempotency, expected-version, locking, evidence/load/departure, delivery, and audit transactions;
- add cross-role, stale-version, replay/conflict, over-application, evidence-void/departure race, and delivery reconciliation tests;
- approve document numbering, service cutoff, unit conversion/rounding, audit retention, and evidence-file policy where affected commands require them;
- generate client types only after the command/read interface is stable;
- complete security and architecture review and obtain an explicit integration task.

PA-04 provides no permission for React, Retool, or another client to write or read authoritative Atlas tables directly.
