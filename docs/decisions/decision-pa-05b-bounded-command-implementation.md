# Decision - PA-05B bounded command implementation

**Status:** Proposed with the PA-05B implementation; pending review and merge
**Date:** 2026-07-15
**Related design:** `docs/architecture/pa-05b-supplier-direct-command-implementation.md`

## Context

PA-04 provides the private supplier-direct persistence foundation and PA-05A defines the command/RPC behavior. Atlas now needs an executable, reviewable subset that proves the most important evidence, loading, departure, delivery, authorization, idempotency, and audit invariants without broadening into UI, deployment, Warehouse, or the full command catalog.

## Decisions

1. PA-05B implements only the bounded supplier-direct evidence-to-delivery commands named in PA-05A, plus the single supplier-direct trace read.
2. JSONB command request/response envelopes with contract version `PA-05B.v1` are accepted for this first implementation.
3. `atlas_api` remains the only callable surface. Private domain schemas and helpers remain closed to API roles.
4. Only `authenticated` receives execute, and only on the five approved writes and one approved shaped read. `anon` and `service_role` receive no Atlas function or table access.
5. Entry functions use hardened `security definer`, approved no-login runtime owners, empty fixed search paths, fully qualified references, no dynamic SQL, and safe error responses.
6. Server-side auth-subject resolution plus active actor, capability, typed relational scope, and delegation/override rejection are mandatory.
7. Canonical request hashing, scoped command receipts, exact replay, idempotency conflict, and optimistic expected-version checks are mandatory for every write.
8. Evidence sufficiency and application caps, load consumption, departure revalidation, and successful delivery reconciliation are enforced under deterministic locks in the authoritative transaction.
9. Receipt result, domain mutation, domain event, audit event, and safe response succeed or roll back together. Deterministic post-receipt validation failures may be stored as non-retryable receipts.
10. Private reporting views and shaped read functions are never write safety gates; commands lock and re-read authoritative records.
11. React remains disconnected. PA-05C must complete authorized read wrappers before PA-06 may add a separately reviewed read-only connection.
12. Warehouse, school catering recipes/BOM, delivery exception/return execution, Production/QA, Finance, Retool writes, OPS v1 mutation, live deployment, production data, credentials, Edge Functions, Storage, and generated Supabase types remain deferred.

## Consequences

Atlas gains a small executable API with explicit privileges and test-proven business safety. API callers cannot bypass command authorization with direct CRUD or service credentials. Exact retries are safe, stale or conflicting commands fail closed, and downstream Dispatch behavior cannot silently manufacture or outgrow upstream Evidence facts.

The subset is not a complete operational application. Planning and Procurement authoring, Dispatch setup, exception/return handling, broad read APIs, client types, UI integration, data rollout, and deployment require later decisions and bounded changes.

## Rejected alternatives

- Direct table CRUD from React, Retool, or another client.
- A generic mutation RPC or generic workflow engine.
- A broad service-role or admin API.
- Trusting UI role claims, editable JWT metadata, or caller actor IDs for authorization.
- Using reporting views or read responses as authoritative write safety gates.
- Skipping command receipts, canonical request hashes, or idempotent replay.
- Last-write-wins updates without expected-version checks.
- Implementing the full PA-05A command catalog in one pull request.
- Adding Warehouse stock behavior to supplier-direct Slice 1.
- Adding exception/return execution to the successful-only delivery command.
- Connecting React before command and authorization tests pass and shaped reads are approved.

## Rollback effect

Before deployment, rollback is a Git revert/removal of the unshipped PA-05B migration and related tests/docs. No hosted system or production data is changed by this decision. If the migration is deployed later, rollback must be a new reviewed migration that revokes the callable surface and removes runtime objects without deleting operational, receipt, event, or audit history.
