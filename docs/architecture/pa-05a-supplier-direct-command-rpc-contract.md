# PA-05A — Supplier-direct command/RPC contract

**Status:** Proposed architecture design; documentation only  
**Scope:** Supplier-direct wholesale Slice 1 command and read contract following PA-04  
**Authority:** ARCH-002, PA-01 through PA-04, and approved Planning, Procurement, and Dispatch contracts  
**Next gate:** PA-05B bounded SQL command implementation

## 1. Purpose and boundary

PA-04 created the private Atlas schemas, 52 authoritative tables, forced RLS, revoke-first privileges, private derived views, and command/audit/idempotency storage. It deliberately created no callable functions. PA-05A converts that foundation into the approved command/read contract for PA-05B; it does **not** implement SQL, grants, RLS policies, migrations, or a client connection.

The contract follows the official system map:

```text
Mission → capability → domain → object → contract → command/event → read model → application → technology
```

The supported path is wholesale source → Planning approval/release → Purchase Handoff → Dispatch Requirement → Procurement allocation → PO → supplier receiving evidence → evidence application → Dispatch plan/trip/stop → load → departure → delivery → command/audit/event trace.

Planning owns what, quantity, destination, service date, and release snapshot. Procurement owns supplier-direct fulfilment allocation and PO commitment. Evidence owns physical supplier evidence and application to an allocation-line revision. Dispatch owns plan, trip, stop, load, departure, and delivery confirmation. A downstream command cannot rewrite an upstream owner's fact.

`atlas_api` is the only future callable Atlas surface. Domain schemas remain private: `atlas_core`, `atlas_admin`, `atlas_planning`, `atlas_procurement`, `atlas_evidence`, `atlas_dispatch`, `atlas_audit`, and `atlas_reporting`. React must call only reviewed shaped `atlas_api` functions, never tables, writable views, sequences, audit rows, or private reporting views. Retool remains usable for OPS v1/beta diagnostics but is not an Atlas write route. Management override is explicit, scoped, and audited; it cannot bypass source-owner invariants.

## 2. Conventions and envelopes

### 2.1 Business names

Functions have stable business-command names under `atlas_api`, never generic CRUD names such as `upsert_record`, `update_status`, `mutate_entity`, or `save_data`. Future functions include `release_wholesale_order`, `release_purchase_handoff`, `allocate_supplier_direct_fulfilment`, `release_supplier_purchase_order`, `record_supplier_receiving_evidence`, `apply_supplier_evidence_to_allocation`, `create_dispatch_plan`, `confirm_dispatch_load`, `record_dispatch_departure`, and `confirm_successful_delivery`.

Each write accepts a versioned request envelope and returns a structured result. PA-05B must publish exact PostgreSQL signatures and schemas without changing the behavior below.

### 2.2 Standard command request and result

Every authoritative request contains:

```text
contract_version, command_id, correlation_id, idempotency_key, expected_version,
requested_by_auth_subject, requested_at, reason_code, reason_note, payload
```

`requested_by_auth_subject` is an asserted authentication context, not trusted authorization. The server resolves the actor from the authenticated context. `payload` contains command-specific public fields and opaque business IDs only. Multi-root commands carry a named expected-version set in payload.

A success response contains `success`, `command_id`, `correlation_id`, `idempotency_status`, affected aggregate IDs, new versions, emitted event IDs, audit event IDs, a safe operator message, and safe blockers/warnings if applicable. All are atomic; partial success is prohibited.

A failure returns `success: false` plus:

```text
error_code, safe_message, domain, command_name, retryable, field_errors,
blocking_references, expected_version, actual_version, correlation_id, command_id
```

`field_errors` use public request names and `blocking_references` are safe business references or caller-authorized opaque IDs. SQL text, table/function/policy internals, stack traces, service-role information, RLS details, signed URLs, credentials, and JWT contents are never returned. Server diagnostics retain internal detail by command/correlation ID.

## 3. Shared authoritative behavior

### Authorization

Every command resolves the auth subject to an Atlas actor and verifies an active auth subject, active actor, required capability, typed scope, and valid delegation where applicable. Management override additionally requires an explicit capability, scope, approval record, reason, and audit evidence. UI claims, editable JWT metadata, caller actor IDs, and Retool parameters are not authorization sources.

### Idempotency and expected version

Every authoritative write needs an idempotency key, scoped by environment + initiating/integration actor + command name + aggregate scope + key. PA-05B stores a canonical hash of the contract version and normalized request, excluding volatile transport fields.

| Situation | Required behavior |
| --- | --- |
| First submission | Lock/register receipt, validate, mutate, append event/audit, and commit one result. |
| Exact duplicate replay | Return stored safe response and original command ID; make no new change. |
| Same key, different hash | Fail `IDEMPOTENCY_CONFLICT`; no last-write-wins. |
| Concurrent in-progress command | Wait briefly for the receipt; replay after commit or retry after rollback. No durable partial receipt. |
| Completed command | Replay minimized stored result, IDs, versions, safe warnings/errors, and correlation ID. |
| Failed non-retryable command | A deterministic safe failure may be retained for 30 days; corrected request gets a new key. |
| Transient failure before receipt commit | Commit neither result nor mutation; retry entire transaction with same key. |
| Network failure | Query/retry exact payload and key; receipt decides replay versus execution. |

Each mutable root has `version bigint`; stale expected version returns `STALE_VERSION` and makes no write. Immutable revisions check the owner root and exact upstream revision. A successful command increments each affected root once.

### Transactions, locks, retry, audit

PA-05B uses short `read committed` transactions. Lock order is: (1) command receipt/numbering, (2) Admin references, (3) Planning, (4) Procurement, (5) Warehouse — not in this slice, (6) Evidence, (7) Dispatch, (8) audit/events. Within a class, UUIDs are ascending; lock parent root before children. Re-read safety-critical facts after locks. Commit receipt, domain mutation, event, audit, and response together or roll back all.

`40001`, `40P01`, and an explicitly classified race are retryable whole-transaction failures (maximum three attempts with jitter). Timeout is retryable only for an allowlisted command before an unknown commit. Authorization, stale version, validation, insufficient evidence, over-application, and reconciliation failures are non-retryable.

## 4. Full supplier-direct command catalog

All commands use the preceding envelope, authorization, receipt, expected-version, rollback, retry, event, and audit rules. “Locks” are additional locks after receipt and Admin references; tables are private implementation detail, not a client contract.

| Function / owner | Tables and locks | Validation and event |
| --- | --- | --- |
| `record_wholesale_source` — Planning | wholesale roots, lines/revisions; wholesale root | Active wholesale customer/location/item/unit; draft/revision safety. `WholesaleOrderRecorded`. |
| `release_wholesale_order` — Planning | wholesale and confirmed-need roots/revisions; Planning | Approved source; exact quantity/destination/date; release snapshot. `WholesaleOrderReleased`. |
| `release_purchase_handoff` — Planning | confirmed need, handoff batches/revisions/lines/demand references; Planning | Approved need and no blocker; preserve source revisions. `PurchaseHandoffReleased`. |
| `release_dispatch_requirement` — Planning | handoff, dispatch requirement/revisions/lines; Planning | Released handoff, valid destination/date; Planning release snapshot. `DispatchRequirementReleased`. |
| `revise_or_cancel_planning_release` — Planning, future-safe | Planning root/revision and downstream references; Planning | Explicit lifecycle/reason; preserve history; reject unsafe downstream impact. `PlanningReleaseRevised`/`PlanningReleaseCancelled`. Not PA-05B. |
| `allocate_supplier_direct_fulfilment` — Procurement | allocation roots/revisions/lines, exact requirement revision; Planning → Procurement | Requirement released; active eligible supplier; item/unit match; never redefines demand. `SupplierDirectFulfilmentAllocated`. |
| `release_supplier_purchase_order` — Procurement | allocation and PO roots/revisions/lines; Planning → Procurement | Valid allocation, active eligible supplier, immutable PO snapshot. `PurchaseOrderReleased`. |
| `revise_or_cancel_supplier_commitment` — Procurement, future-safe | allocation/PO roots, revisions, evidence/load references; Planning → Procurement | Reason and lifecycle; no in-place released edit; reject unsafe execution impact. `SupplierCommitmentRevised`/`PurchaseOrderCancelled`. Not PA-05B. |
| `record_supplier_receiving_evidence` — Evidence | released PO line revision, evidence; Procurement → Evidence | Receiving capability/scope; PO/supplier/item/unit match; positive quantity/time. `SupplierReceivingEvidenceRecorded`. |
| `supersede_supplier_receiving_evidence` — Evidence | old/new evidence and applications; Procurement → Evidence | Reason and immutable link; cannot invalidate departed history. `SupplierReceivingEvidenceSuperseded`. Not PA-05B. |
| `void_supplier_receiving_evidence` — Evidence | evidence/applications, allocation, Dispatch state; Procurement → Evidence → Dispatch | Reason; reject post-departure gap, otherwise invalidate safely. `SupplierReceivingEvidenceVoided`. Not PA-05B. |
| `apply_supplier_evidence_to_allocation` — Evidence | allocation line revision, evidence, valid applications; Procurement → Evidence | Exact lineage; positive normalized amount; sums cannot exceed valid evidence or allocation. `EvidenceAppliedToAllocation`. |
| `supersede_or_void_evidence_application` — Evidence, future-safe | allocation revision, applications/evidence, load applications; Procurement → Evidence → Dispatch | Preserve history/reason; reject unsafe dispatched consumption. `EvidenceApplicationSuperseded`/`EvidenceApplicationVoided`. Not PA-05B. |
| `create_dispatch_plan` — Dispatch | requirement/allocation revisions, plan/plan requirements; Planning → Procurement → Dispatch | Released requirement and admissible allocation; no source rewrite. `DispatchPlanCreated`. |
| `admit_requirement_to_dispatch_plan` — Dispatch | plan, requirement/allocation revisions, plan requirement; Planning → Procurement → Dispatch | Compatible release/date/destination; stale/duplicate blocks. `DispatchRequirementAdmittedToPlan`. Not PA-05B. |
| `create_or_assign_dispatch_trip` — Dispatch | plan, trips, stops; Dispatch | Plan eligibility, valid stops, valid assignment/delegation. `DispatchTripAssigned`. Not PA-05B. |
| `confirm_dispatch_load` — Dispatch | allocation revision, evidence/apps, trip/stop/load/lines/load-apps; Procurement → Evidence → Dispatch | Positive load consumes valid applied evidence only; summed consumption cap; trip ready. `DispatchLoadConfirmed`. |
| `record_dispatch_departure` — Dispatch | allocations, evidence/apps, plan/trip/stops/loads; Procurement → Evidence → Dispatch | Re-read evidence/application validity and load readiness under lock. `DispatchDeparted`. |
| `confirm_successful_delivery` — Dispatch | trip/stop/load lines, delivery confirmation/lines; Dispatch | Successful path only; delivered positive and not over loaded; reconcile exact load lines. `SuccessfulDeliveryConfirmed`. |
| `close_successful_trip` — Dispatch | trip, stops, loads, confirmations; Dispatch | All stops/lines reconciled; no exception/return implied. `SuccessfulDispatchTripClosed`. Not PA-05B. |

Validation runs after locks and before writes. The event above and an audit event always contain actor, delegated actor when applicable, command/correlation IDs, source interface, timestamp, reason, affected IDs/versions, and safe before/after summary.

## 5. First PA-05B implementation subset

PA-05B implements only: actor-resolution/command-receipt helpers; `record_supplier_receiving_evidence`; `apply_supplier_evidence_to_allocation`; `confirm_dispatch_load`; `record_dispatch_departure`; `confirm_successful_delivery`; and `get_supplier_direct_trace`.

Planning, Procurement, plan/trip/stop, allocation, and released-PO prerequisites are fixture or separately approved reference records, not opportunistically added commands. This subset proves evidence sufficiency, evidence application caps, load consumption, departure revalidation after a void/supersession race, delivery-to-load reconciliation, and audit/idempotency atomicity. It does not authorize React.

## 6. Read API contract

Future reads are authorized shaped `atlas_api` functions, not exposed views:

| Function | Authorized decision payload |
| --- | --- |
| `get_supplier_direct_trace` | Source-to-delivery public references, released revisions, stage quantities, lineage status. |
| `get_dispatch_evidence_readiness` | Valid applied, consumed, available, and blocking quantities in authorized Dispatch scope. |
| `get_command_audit_timeline` | Filtered command/event/audit status, actor/delegation, reason, and timestamp timeline. |
| `get_operator_blockers` | Action-specific readiness, blockers, and warnings for an authorized aggregate. |

Each read resolves actor/capability/scope server-side, selects only allowlisted columns, and returns a documented shaped payload. Reads are advisory: commands independently re-read and lock authoritative state and never use a reporting view/read response as a safety gate.

## 7. Events, audit, and PA-05B acceptance

Minimum events are `WholesaleOrderReleased`, `PurchaseHandoffReleased`, `DispatchRequirementReleased`, `SupplierDirectFulfilmentAllocated`, `PurchaseOrderReleased`, `SupplierReceivingEvidenceRecorded`, `EvidenceAppliedToAllocation`, `DispatchPlanCreated`, `DispatchLoadConfirmed`, `DispatchDeparted`, and `SuccessfulDeliveryConfirmed`, plus catalogued correction/closure events. Event/audit rows describe state; they are not event sourcing.

Before React integration, PA-05B must prove locally: migration applies; pgTAP/security tests pass; direct table access stays closed; RPC grants are explicit/minimal; unauthorized actor, wrong capability, wrong scope, and stale expected version fail; duplicate replay is safe; same key/different payload fails; evidence over-application fails; load without sufficient valid evidence fails; departure after evidence void fails; delivery exceeding load fails; and receipt/event/audit are atomic.

## 8. Explicit exclusions

PA-05A excludes SQL implementation, migrations, RLS/grants implementation, React integration, generated Supabase types, live Supabase deployment, production/seed data, Retool changes, OPS v1 mutation, Warehouse stock, school catering recipes/BOM, delivery exception/return path, Production/QA, Finance, Edge Functions, Storage/file handling, and a generic workflow engine.

