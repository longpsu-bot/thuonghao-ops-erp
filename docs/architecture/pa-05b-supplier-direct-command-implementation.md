# PA-05B - Supplier-direct command implementation

**Status:** Completed on `main`; execution correction PA-05B-H2 implemented in the current review change
**Scope:** Supplier-direct wholesale Slice 1 evidence-to-delivery command subset  
**Authority:** PA-01 through PA-05A and the approved Planning, Procurement, Evidence, and Dispatch boundaries  
**Next gates after this review change:** PA-05F Dispatch setup, PA-05B-H3 successful trip closure, then PA-05G backend acceptance

## 1. Outcome and boundary

PA-05B turns the highest-risk portion of the PA-05A contract into executable PostgreSQL/Supabase behavior. It adds five authoritative write commands, one shaped read, private helpers, runtime-role RLS policies, explicit grants, and rolled-back pgTAP fixtures.

The implemented callable surface is exactly:

- `atlas_api.record_supplier_receiving_evidence(request jsonb) returns jsonb`
- `atlas_api.apply_supplier_evidence_to_allocation(request jsonb) returns jsonb`
- `atlas_api.confirm_dispatch_load(request jsonb) returns jsonb`
- `atlas_api.record_dispatch_departure(request jsonb) returns jsonb`
- `atlas_api.confirm_successful_delivery(request jsonb) returns jsonb`
- `atlas_api.get_supplier_direct_trace(request jsonb) returns jsonb`

Planning releases, Procurement allocation and purchase-order release, and Dispatch plan/trip/stop setup were prerequisites when PA-05B was implemented. PA-05D and PA-05E now author the Planning and Procurement prerequisites. PA-05F remains responsible for plan/trip/stop setup. The approved PA-05A closure command remains a separately tracked follow-up in Issue #93.

## 2. Callable and private security boundary

`atlas_api` remains the only callable Atlas schema. `authenticated` receives schema usage and execute only on the reviewed functions. `anon` and `service_role` receive neither. None of the three API roles receives direct table, view, sequence, or private-schema access.

After PA-05B-H1, the two Evidence writes are `security definer` functions owned by the no-login `atlas_evidence_command_runtime` role and the three Dispatch writes are owned by `atlas_dispatch_command_runtime`. The shaped trace and PA-05C read wrappers are owned by `atlas_read_runtime`; the former shared `atlas_command_runtime` retains no effective Atlas privilege. Every entry function has an empty fixed `search_path`, fully qualified references, and no dynamic SQL or caller-controlled object name.

Private helpers live in `atlas_core`, are owned by `atlas_owner`, and are executable only by the runtime role that needs them. Runtime table grants are verb-specific and paired with forced-RLS policies named only for the runtime roles. Narrow `UPDATE` grants on reference rows exist solely because PostgreSQL row locks require the privilege; no matching update policy is present, so those reference rows cannot be changed through the runtime path.

## 3. Request, actor, and result handling

The original PA-05B writes accept contract version `PA-05B.v1` and require:

```text
command_id, correlation_id, idempotency_key, expected_version,
requested_by_auth_subject, requested_at, reason_code, reason_note, payload
```

The server reads the authenticated subject from the Supabase request settings, supporting the current JWT-claims object and the compatible subject setting used by local tests. It never trusts `requested_by_auth_subject` by itself. The asserted subject must equal the current request subject and must resolve through PA-04 tables to an active auth subject and active HUMAN or INTEGRATION actor.

Each command then proves an active role membership, the command-specific capability, and a relational typed scope (`GLOBAL`, `CUSTOMER`, `DELIVERY_LOCATION`, or `DISPATCH_TRIP`) against the authoritative target. Caller-supplied actor IDs, editable UI/JWT role metadata, delegation, management override, and approval shortcuts are not accepted. Unsupported delegation or override fields fail closed.

Success responses contain command/correlation IDs, replay status, affected IDs, applicable versions, domain-event IDs, audit-event IDs, and safe operator warnings/blockers. Failure responses contain only the PA-05A safe error fields. SQL text, stack traces, table/policy details, credentials, service-role information, and JWT contents are never returned.

## 4. Receipt and idempotency behavior

The command receipt is scoped to the database environment, initiating actor, command name, aggregate target, and idempotency key. The canonical SHA-256 hash uses stable JSONB fields and excludes volatile `requested_at` and `correlation_id` transport values.

- A first authorized request registers and locks an `IN_PROGRESS` receipt, revalidates locked facts, mutates the domain, appends one domain event and one audit event, stores the safe response, and completes atomically.
- An exact replay returns the stored response and creates no duplicate domain, event, or audit row.
- Reusing a command ID or scoped idempotency key for a different canonical request returns `IDEMPOTENCY_CONFLICT`.
- Stale root versions return `STALE_VERSION` and make no domain write.
- Envelope, authentication, and authorization failures occur before receipt registration.
- Deterministic business validation after receipt registration stores `FAILED_NON_RETRYABLE` with its safe response. A corrected request uses a new key.
- Serialization or deadlock classification returns a retryable safe error. An unexpected SQL failure cannot store a successful receipt because the statement transaction rolls back its writes.

## 5. Transaction, lock, and invariant behavior

Each function is one short authoritative statement transaction under the caller's normal `read committed` transaction. Locks follow receipt, Admin, Planning, Procurement, Evidence, Dispatch, then audit/event order. Multi-row locks use deterministic UUID ordering. Safety-critical state is selected again after locks; the private reporting view is never used by a write command.

### Evidence

`record_supplier_receiving_evidence` requires a released current PO line, exact supplier/allocation supplier, ingredient and unit lineage, positive quantity, a non-future occurrence time, and current purchase-order version. It inserts immutable supplier evidence only; it does not alter Procurement demand, Warehouse stock, load, or delivery.

`apply_supplier_evidence_to_allocation` requires current valid evidence and exact supplier/ingredient/unit lineage to the allocation-line revision. The active sum for one evidence row cannot exceed evidence quantity. The active sum for one allocation-line revision cannot exceed allocated quantity. A duplicate active evidence/allocation pair is rejected. Procurement quantities are not changed.

### Original load and departure boundary

The merged PA-05B implementation validates one load-line request at a time against one evidence application, creates one load root/line/application bridge, and advances the trip and stop. Departure revalidates current evidence coverage for the confirmed loads before advancing the trip and loaded stops.

This was sufficient for the first bounded evidence-to-delivery proof but is not sufficient for the multi-line requirements and allocations now authored by PA-05D and PA-05E. PA-05B-H2 replaces the Dispatch request behavior with one atomic multi-line load per stop requirement, exact full-line departure revalidation, and trip-wide authorization. It does not change Evidence ownership or add a public function.

### Original successful-delivery boundary

The merged `confirm_successful_delivery` command is successful-path-only and reconciles one submitted load line exactly. It rejects a stop containing another current confirmed load line.

PA-05B-H2 replaces that one-line assumption with one atomic stop-level confirmation containing every current confirmed load line. Return, exception, Warehouse, Finance, and QA behavior remain excluded.

### Successful trip closure

The approved catalog includes `close_successful_trip`, which is not implemented by PA-05B or PA-05B-H2. A fully delivered trip currently reaches `DELIVERED` but does not have an authoritative closure command that validates the complete successful path, sets `completed_at`, and emits `SuccessfulDispatchTripClosed`. Issue #93 tracks that separate bounded command so PA-05G can remain acceptance-only.

## 6. Shaped read

`get_supplier_direct_trace` accepts an authorized wholesale-order-line revision and internally reads the private PA-04 trace model plus allowlisted source/status records. It returns public references, opaque lineage IDs, stage statuses, exact quantities, evidence readiness, load/delivery state, and safe blockers/warnings.

It does not expose the underlying view shape, command receipts, request hashes, audit internals, or unauthorized rows. It is advisory only; write commands always lock and re-read authoritative tables.

## 7. Verification

The updated PA-05B pgTAP file contains 66 assertions, and the focused PA-05B-H2 suite contains 128 assertions. Coverage includes:

- private-schema and direct-table denial plus exact RPC grants;
- hardened owners/search paths and direct-insert denial;
- subject mismatch, inactive actor, inactive subject, wrong capability, and wrong scope;
- first execution, exact replay, idempotency conflict, stale version, and deterministic failed receipt;
- positive quantities, evidence/allocation caps, duplicate application, and load-consumption cap;
- pre-departure delivery rejection and departure revalidation after evidence void;
- successful-only delivery reconciliation and return/exception rejection;
- one receipt/event/audit result for success and no misleading mutation/event/audit for failure;
- authorized shaped trace and relational scope denial.
- Planning-owned destination and exact requirement/allocation membership checks for load, every departure stop, and successful delivery;
- retryable SQLSTATE `40001` classification for post-lock departure scope changes without a durable failed receipt;
- private PA-05B-H2 validator ownership by `atlas_owner` and execute-only access for `atlas_dispatch_command_runtime`;
- GLOBAL-scoped negative fixtures proving destination cross-wires create no load, departure, delivery, domain-event, or audit facts.

All synthetic business, authorization, and lifecycle rows are rolled back. PA-05B-H2 updates the three Dispatch request scenarios to the multi-line contract and adds a separate focused multi-line suite; Evidence scenarios remain on the original PA-05B contract.

## 8. Limitations, rollback, and next gates

PA-05B and its follow-ups are forward-only source history. Before deployment, rollback is removal/reversion of the unshipped migration. After deployment, reversal would require a reviewed follow-up migration that revokes execute, replaces functions/policies/helpers in dependency order, and preserves already-written evidence, dispatch, receipt, event, and audit history.

PA-05B intentionally excludes generalized read APIs, production reference/seed data, generated Supabase types, React integration, Edge Functions, Storage/evidence files, credentials, live Supabase projects or branches, Retool changes, OPS v1 mutation, Warehouse stock, school-catering recipes/BOM, delivery exception/return execution, Production/QA, Finance, and a generic workflow engine.

The corrected backend sequence is:

```text
PA-05B-H2 multi-line Dispatch execution
→ PA-05F Dispatch plan/trip/stop setup
→ PA-05B-H3 successful trip closure
→ PA-05G command-authored backend acceptance
→ PA-06 React connection
```
