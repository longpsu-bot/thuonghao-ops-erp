# Decision - PA-03 Security and Command Boundaries

**Status:** Proposed with PA-03

**Date:** 2026-07-15

**Related design:** `docs/architecture/pa-03-authorization-command-and-transaction-safety-design.md`

## Context

PA-01 defines Atlas persistence ownership, immutable released history, source-owned physical evidence, command transactions, and derived read models. PA-02 maps those rules into private domain schemas, exact revision/line references, evidence applications, stock/evidence constraints, and a supplier-direct first slice.

Before a migration can be authorized, Atlas needs one approved boundary for authentication, authorization, database exposure, grants, RLS, command functions, idempotency, optimistic concurrency, locking, safe errors, reporting, integrations, and emergency access.

Supabase Data API grants and PostgreSQL RLS are separate controls. A user authenticated as the shared `authenticated` database role is not thereby authorized for an Atlas business action. Direct table CRUD also cannot safely represent multi-row release, evidence, stock, departure, delivery, and audit invariants.

## Decision

### Private domain tables and one API namespace

The PA-02 schemas remain private and outside the Supabase Data API:

- `atlas_core`
- `atlas_admin`
- `atlas_planning`
- `atlas_procurement`
- `atlas_evidence`
- `atlas_warehouse`
- `atlas_dispatch`
- `atlas_audit`
- `atlas_reporting`
- `atlas_legacy`

A dedicated `atlas_api` interface schema is the only Atlas schema exposed to the Data API. It contains reviewed command and read functions only. React receives no direct table, view, sequence, domain-schema, audit-table, or storage-locator write privilege.

### Revoke-first grants and RLS

Atlas uses revoke-first privileges and explicit allowlisted grants. `anon` receives no Atlas access. `authenticated` receives only `USAGE` on `atlas_api` and `EXECUTE` on named function signatures. Default privileges are explicitly revoked for `PUBLIC`, `anon`, `authenticated`, and `service_role` before deliberate grants are added.

RLS is enabled and forced where required for exposed or actor/scope-sensitive tables and as defense in depth on private domain tables where practical. No policy grants access merely because a caller is `authenticated`, and no write policy trusts a UI-supplied role, actor, or scope.

### Server-owned actor and capability checks

Atlas resolves the initiating application actor server-side from the authenticated subject. Roles, capabilities, memberships, organization/site/warehouse/trip scopes, delegations, approvals, emergency grants, and deactivation state are stored in controlled relational records.

Authorization does not depend on user-editable JWT metadata. JWT application metadata may be an advisory UI hint only because it may be stale. Delegated actions retain both the initiating actor and delegated actor. Historical/deactivated actors remain attributable.

No role, including Admin, means unrestricted access. Admin governs master data; it does not receive daily Planning, Procurement, evidence, Warehouse, or Dispatch mutation authority.

### Reviewed command functions for every write

Every authoritative write uses a reviewed command function. Security-definer entry functions:

- are owned by a no-login, non-superuser, non-table-owner runtime role with no `BYPASSRLS`;
- use an empty or otherwise fixed safe `search_path` and fully qualified object references;
- revoke execute from `PUBLIC` and grant only named signatures;
- resolve actor/capability/scope/delegation/approval server-side;
- validate expected versions, exact source revisions, lifecycle, quantities, evidence, and scope;
- change only the owning domain;
- append command receipt, domain event, and audit event in the same transaction;
- return a stable safe success/error contract;
- contain no user-controlled schema/object names and no unjustified dynamic SQL.

Direct client mutation of domain tables is forbidden even when the user may read related data.

### Mandatory idempotency and optimistic concurrency

Every authoritative write command requires a scoped idempotency key and canonical request hash. An exact duplicate replays the minimized safe result; the same key with another payload fails. Deterministic non-retryable failures may be retained for replay; transient database failures are not retained as terminal receipts and retry the complete transaction with the same key.

Every mutable root uses optimistic `version` checking. Commands reject stale expected versions. Released revisions and source evidence are immutable; corrections create successors, cancellations, reversals, or compensating records. Atlas does not use last-write-wins for operational aggregates.

### Transactional evidence, stock, and departure safety

The first implementation uses PostgreSQL `read committed` with an explicit parent-lock and deterministic global lock order. `serializable` is reserved for a bounded command whose predicate has no stable lockable parent or whose complete conflict set cannot otherwise be protected.

The lock order is command receipt/number series, Admin references, Planning, Procurement, Warehouse, source evidence/applications, Dispatch, then append-only audit/events. IDs within one class are locked in ascending order.

Evidence application locks the exact allocation revision and evidence source before summing active quantities. Stock reservation/release locks allocation, stock positions, reservations, picks, and release state before recalculating availability. Departure locks and re-reads exact current evidence/applications and its loads before committing.

Evidence void/supersession and departure follow the same order. If void wins, departure is blocked. If departure wins, an unsafe void is rejected and must use an explicit post-departure correction path. No asynchronous read model or React flag authorizes evidence, stock, departure, delivery, or closure.

### Structured safe errors

Commands return a stable error envelope containing a public error code, safe operator message, command/domain context, versions, retryability, field errors, blocker references, correlation ID, and command ID where available.

SQL text, internal table/function/policy/constraint names, credentials, stack traces, raw JWTs, secret configuration, and signed URLs remain server-only.

### Service role, Retool, integrations, and migration

Service-role/secret credentials are prohibited from React, browser-accessible configuration, repositories, and routine Retool use. They are not the normal Atlas command identity.

Retool is diagnostic/read-only by default and consumes allowlisted reporting functions. Integrations use one narrow identity per source and environment, idempotent commands, rate limits, audit, rotation, and revocation. Migration/reconciliation uses separate time-bounded roles, immutable batches, staging/mapping review, domain-owned migration commands, reconciliation, rollback criteria, and privilege revocation.

Only one system owns workflow writes at a time. Dual write is prohibited.

### Emergency access and overrides

Emergency access is time-bounded, approved, reasoned, auditable, and uses normal command functions. It cannot bypass:

- evidence sufficiency or source ownership;
- stock non-negativity;
- quantity reconciliation;
- immutable history;
- trip outcome reconciliation;
- audit/event creation.

Management approval does not transfer the source owner's correction authority. The owning domain still executes the explicit correction, reversal, cancellation, exception, or compensating command.

## Consequences

- React remains a presentation and interaction layer rather than a privileged database client.
- Atlas has one inspectable API namespace and no accidental CRUD surface over domain tables.
- Authentication, capability, row scope, object grants, RLS, and command invariants remain separate reviewable layers.
- Supplier-direct fulfilment does not acquire a fake Warehouse requirement.
- Procurement cannot create physical evidence; Dispatch cannot mutate Planning, Procurement, evidence-source, or Warehouse facts; Return Evidence cannot create stock.
- Every release/evidence/stock/departure/delivery action has deterministic retry, conflict, audit, and safe-failure behavior.
- Migrations must create roles, defaults, functions, grants, policies, and tests together; partial security setup is not acceptable.
- The added runtime roles and `atlas_api` schema are technical boundaries, not new business domains or a generic workflow engine.

## Gates before implementation

Before PA-04, approve:

- exact function signatures and shaped read responses;
- first-slice actor/capability seeds and organization/site data;
- online/offline driver delegation mechanism;
- idempotency and audit retention;
- evidence-file bucket/scanner/retention policy;
- document numbering, service cutoff, and applicable rounding rules;
- executable RLS/grant/function/concurrency acceptance tests against the target Supabase runtime.

Any material unresolved item requires a bounded PA-03.x amendment. The first migration remains separately authorized.

## Rejected alternatives

### Direct authenticated table CRUD plus RLS

Rejected because row policies do not provide the intentional multi-record transaction, idempotency, cross-domain validation, evidence/stock sum locking, safe error contract, and atomic audit required by Atlas.

### One broad Admin or service-role backend

Rejected because it erases domain ownership, expands credential blast radius, and makes attribution/capability review unreliable.

### Exposing every PA-02 domain schema

Rejected because it increases the Data API surface and couples clients to internal tables. Atlas exposes only reviewed functions in `atlas_api`.

### UI authorization or JWT user metadata

Rejected because frontend visibility is advisory and user metadata is caller-editable. Authorization is resolved from current server-owned records.

### Asynchronous safety gates

Rejected because cached/materialized readiness can be stale during evidence, stock, departure, delivery, or closure races.

## Scope and migration effect

This decision adds documentation only. It adds no migration, SQL file, PostgreSQL object, RLS policy, RPC, Edge Function, generated type, Supabase client, backend code, credential, production-data change, Retool change, React behavior, fixture, or domain command.

There is no database rollback effect. Documentation rollback is a normal Git revert.
