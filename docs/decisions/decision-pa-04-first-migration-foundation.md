# Decision — PA-04 first migration foundation

**Status:** Proposed with PA-04

**Date:** 2026-07-15

**Related design:** `docs/architecture/pa-04-supplier-direct-slice-1-migration-foundation.md`

## Context

PA-01 established canonical identity, released snapshots, source-owned evidence, transactional commands, audit, and a legacy boundary. PA-02 mapped those rules into private PostgreSQL namespaces, exact line/revision foreign keys, mandatory evidence applications, and a supplier-direct first slice. PA-03 established a function-only `atlas_api` boundary, server-owned authorization, revoke-first access, RLS defense, idempotency, optimistic concurrency, deterministic locking, safe errors, and security tests.

Atlas now needs a first executable database foundation without turning that step into a full ERP migration or pretending that unresolved business commands are complete.

## Decision

### First real Atlas tables are new Atlas tables

The first Atlas migration creates dedicated `atlas_*` schemas and new canonical tables. It does not rename, alter, import, wrap, or treat OPS v1 tables as Atlas authority.

OPS v1 and Retool remain operational evidence and are outside PA-04.

### Supplier-direct wholesale is the first connected slice

The first physical line spine is a direct wholesale ingredient order through Planning approval/release, Purchase Handoff, supplier-direct fulfilment allocation, PO, supplier receiving evidence/application, Dispatch load/departure, and successful delivery confirmation.

This slice proves canonical identity, exact revisions, source-owned evidence, mandatory quantity application, load evidence consumption, and source-to-outcome trace without recipe or stock migration.

### Warehouse stock is the second slice

PA-04 creates no Warehouse schema or placeholder stock tables. Warehouse Receiving, lots, stock positions, reservation, pick, release, evidence application, and atomic movement remain a separately approved second slice.

Supplier-direct fulfilment must not acquire a fake Warehouse release.

### Domain tables remain private

All authoritative Atlas tables are private, have RLS enabled and forced, and grant no direct access to `PUBLIC`, `anon`, `authenticated`, or `service_role`.

Revoke-first default privileges apply to future Atlas objects. No role, including Admin, receives broad domain access.

### `atlas_api` is the only future interface schema

The local Supabase Data API configuration lists only `atlas_api`. The schema is intentionally empty in PA-04.

Future clients may call only reviewed, explicitly granted functions in `atlas_api`. They may not use direct table CRUD or writable views.

### Evidence application is mandatory

A supplier receiving evidence row is not enough to authorize loading or departure. A positive `atlas_evidence.evidence_applications` row must link that physical quantity to one exact fulfilment-allocation-line revision.

Dispatch load lines then consume evidence only through `dispatch_load_line_applications`.

Plain constraints enforce typed links, positive quantities, lifecycle vocabulary, and duplicate-active-pair prevention. Aggregate over-application, double consumption, evidence void/departure races, and unit normalization remain transactionally enforced command responsibilities.

### Command/RPC implementation is deferred

PA-04 creates command receipts, expected-version fields, command/correlation IDs, actor/capability/scope structures, events, audit envelopes, and the line/revision spine. It implements no command function or API response.

PA-05 or a bounded PA-04.x task must document exact function contracts, grant minimal runtime access, implement server-side authorization and deterministic locks, and pass security/concurrency tests before any client integration.

### No operational migration or cutover occurs

PA-04 adds no seed data, production data, legacy extraction, Retool change, React connection, credential, Edge Function, Storage object, generated type, dual write, deployment, or cutover.

## Consequences

- Atlas has a reviewable first migration history and local Supabase configuration.
- The exact wholesale source-to-delivery line spine can be queried without a denormalized authoritative trace table.
- Supplier physical evidence cannot be mistaken for Procurement commercial confirmation.
- One physical evidence fact cannot have duplicate active application to the same allocation-line revision.
- Aggregate quantity and concurrency safety remains visibly incomplete until command functions are implemented; the schema does not hide that gate.
- The successful delivery path is physically represented while exceptions and returns remain deferred rather than partially modeled.
- React remains disconnected and receives no database privilege.

## Rejected alternatives

- Migrating or modifying OPS v1 tables as the first Atlas schema.
- Adding Warehouse stock placeholders to make the slice appear more complete.
- Treating supplier confirmation as physical evidence.
- Linking evidence directly to a load without an allocation-line quantity application.
- Using generic untyped operational `source_type/source_id` lineage.
- Granting direct authenticated CRUD and relying on RLS alone.
- Exposing all Atlas schemas to PostgREST.
- Implementing skeletal business RPCs without approved signatures, locking, authorization, and error behavior.
- Seeding provisional roles, capabilities, customers, suppliers, or other production-like data.
- Building delivery exception/return tables without an acceptance scenario and closure command.

## Migration and rollback

The migration is additive and creates only new Atlas roles, schemas, tables, indexes, views, comments, RLS settings, and revokes. It changes no existing public or OPS v1 object and inserts no row.

The migration was applied and tested on a disposable local PostgreSQL 17 database only. No live Supabase project was linked or changed.

Before deployment, rollback is a Git revert. After a future approved non-production deployment, reversal requires an explicit reviewed reverse migration because dropping the new Atlas objects would delete their data. No production rollback applies to this PR.
