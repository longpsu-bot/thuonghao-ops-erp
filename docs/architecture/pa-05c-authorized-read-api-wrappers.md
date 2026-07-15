# PA-05C - Authorized read API wrappers

**Status:** Proposed implementation; pending review and merge

**Scope:** Bounded, authorized, shaped reads around the PA-05B supplier-direct wholesale command spine

**Migration:** `supabase/migrations/20260715130617_pa_05c_authorized_read_api_wrappers.sql`

**Verification:** `supabase/tests/pa_05c_authorized_read_api_wrappers.sql`

**Companion decision:** `docs/decisions/decision-pa-05c-authorized-read-api-boundary.md`

## 1. Purpose and boundary

PA-05B implemented the bounded supplier evidence-to-delivery command spine and one completed-path trace. PA-05C adds safe operational visibility around that spine without adding a command, lifecycle, task engine, workflow engine, or client connection.

PA-05C is read-only because each new function performs only bounded `SELECT` work and returns allowlisted JSONB. The functions insert no command receipt, domain event, audit event, or domain row and update or delete nothing. They are advisory read models, never command safety gates. PA-05B commands continue to lock and re-read authoritative tables inside their transactions.

Issue #82 (`PA-05B-H1`) remains open. PA-05C may proceed before it because this migration grants `atlas_read_runtime` only minimum `SELECT` privileges and select-only RLS policies. It adds no capability to `atlas_command_runtime` and no write-command behavior. Broader write-command expansion remains blocked by #82.

The implementation follows the Atlas system map:

```text
Mission
-> Business capability
-> Business domain
-> Business object
-> Business contract
-> Command / event
-> Read model
-> Application
-> Technology
```

No React or Retool surface is connected by PA-05C.

## 2. Callable read functions

Only these new `atlas_api` functions are added:

1. `atlas_api.get_dispatch_evidence_readiness(request jsonb) returns jsonb`
2. `atlas_api.get_operator_blockers(request jsonb) returns jsonb`
3. `atlas_api.get_command_audit_timeline(request jsonb) returns jsonb`

The existing PA-05B function `atlas_api.get_supplier_direct_trace(request jsonb)` remains stable.

`get_dispatch_evidence_readiness` returns shaped trip, stop, requirement, allocation, evidence, application, and quantity references. Each item derives one of `READY`, `MISSING_EVIDENCE`, `PARTIAL_EVIDENCE`, `VOIDED_OR_SUPERSEDED_EVIDENCE`, `NOT_LOADED`, or `DELIVERED`, plus safe blockers and warnings.

`get_operator_blockers` derives operator-facing facts for a bounded context. It may return `NO_SUPPLIER_EVIDENCE`, `EVIDENCE_PARTIAL`, `EVIDENCE_VOIDED`, `NOT_LOADED`, `DEPARTURE_BLOCKED`, `DELIVERY_PENDING`, and `DELIVERY_COMPLETED`. Each blocker identifies a safe source domain, severity, opaque affected IDs, public references where available, observation time, and owning team. These rows are derived observations, not persisted tasks.

`get_command_audit_timeline` returns a safe command receipt summary plus domain and audit events for one authorized context. A combined deterministic limit of 100 events is applied. It excludes request hashes, raw response payloads, before/after payload summaries, SQL or policy internals, credentials, JWT content, service-role information, and stack traces.

## 3. Request envelope

All PA-05C functions accept:

```json
{
  "contract_version": "PA-05C.v1",
  "requested_by_auth_subject": "<uuid>",
  "correlation_id": "<optional uuid>",
  "payload": {}
}
```

The asserted subject is not trusted. The function resolves the current JWT subject server-side through the PA-05B helper pattern, requires an active Supabase Auth subject and active Atlas actor, rejects subject mismatch and unsupported delegation/override fields, then verifies the required capability and a current relational scope.

Authorization applies to every relational tuple selected for a read, before JSON shaping. A selector that spans any tuple outside the actor's current scope fails closed with a safe scope error; it never authorizes one sampled row and then returns a wider result set. Per-row scope checks remain in the read CTEs as defence in depth.

Capabilities are:

- `dispatch_evidence_readiness.read`
- `operator_blockers.read`
- `command_audit_timeline.read`

`supplier_direct_trace.read` is unchanged.

## 4. Bounded selectors

Unbounded and ambiguous requests fail closed.

Evidence readiness requires exactly one of `dispatch_trip_id`, `dispatch_requirement_revision_id`, or `wholesale_order_line_revision_id`.

Operator blockers requires exactly one selector form: `dispatch_trip_id`, `service_date` plus `customer_id`, or `service_date` plus `delivery_location_id`.

Audit timeline requires exactly one selector form: `command_id`, `correlation_id`, or `aggregate_type` plus `aggregate_id`.

Unknown, unsupported, mixed-scope, empty, and malformed selectors return safe errors. Timeline correlation selectors spanning more than one relational scope are rejected.

## 5. Authorization and database security

The functions are `SECURITY DEFINER`, owned by the no-login `atlas_read_runtime` role, and use an empty fixed `search_path`. All object references are fully qualified. The source contains no dynamic SQL and accepts no caller-controlled object name.

`atlas_read_runtime` receives only the additional schema usage, table `SELECT`, and select-only RLS policies needed to shape the three responses. It receives no insert, update, delete, truncate, sequence, or create privilege after migration setup. `atlas_command_runtime` receives no new privilege.

`authenticated` receives execute only on the reviewed `atlas_api` functions. `anon` and `service_role` do not receive execute. None of those API roles receives direct private schema, table, view, or sequence access.

## 6. Response model

Successful responses include the contract version, bounded selector, authorized scope, allowlisted opaque IDs and public references, deterministic shaped results, and a safe operator message. No response is a raw row or `select *` projection. Internal authorization vocabulary, database structure, unsafe payload JSON, credentials, and exception text are not exposed.

## 7. Relationship to PA-05B

PA-05C reads the same authoritative Planning, Procurement, Evidence, Dispatch, Core, and Audit records written or referenced by PA-05B. It does not replace or mutate any PA-05B function. The existing supplier-direct trace remains the completed source-to-delivery trace; PA-05C adds readiness, blocker, and audit visibility for incomplete and operational contexts.

Read wrappers are deliberately not used by write commands. A read can be stale immediately after it is returned, so authoritative writes must continue to validate current rows, versions, evidence, quantities, and locks within their own transaction.

## 8. Verification

The PA-05C pgTAP file contains 31 rolled-back assertions. Together with PA-04's 23 and PA-05B's 64 assertions, the local database suite contains 118 passing assertions.

Coverage proves exact execute boundaries, direct-object denial, unchanged PA-05B functions, no new write function, function hardening, select-only read-runtime grants, authorization failures and success, bounded readiness/blocker/timeline behavior, unbounded-read rejection, prohibited-field exclusion, and no receipt/event/domain mutation side effect.

All fixture data is synthetic and rolled back. Verification uses only a disposable local Supabase database.

## 9. Limitations and exclusions

PA-05C adds no write command, broader command-runtime privilege, React integration, generated Supabase type, Edge Function, Storage bucket or evidence file, live deployment, production data, seed data, credential, Retool change, OPS v1 mutation, Warehouse or stock workflow, school recipe/BOM, delivery exception/return execution, Production/QA, Finance, or generic workflow engine.

The read shapes are limited to supplier-direct Slice 1 and the aggregate types explicitly mapped by the audit scope resolver. Unsupported aggregates fail closed instead of returning cross-scope data.

## 10. Rollback and next gates

Before deployment, rollback is a Git revert/removal of the unshipped migration and related tests/docs. No hosted database or production data is changed by this PR. If deployed later, reversal requires a reviewed forward migration that revokes execute, removes the PA-05C functions/helpers and select-only policies/grants, and preserves operational history.

Issue #82 remains the gate before broader write-command expansion. PA-06 may propose a read-only React connection only after PA-05C review and an explicit security-posture acceptance. React write integration, generated client types, seed/reference data, deployment, and production rollout remain separate approvals.
