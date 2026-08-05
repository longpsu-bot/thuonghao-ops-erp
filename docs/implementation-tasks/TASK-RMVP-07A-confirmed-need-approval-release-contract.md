# TASK-RMVP-07A — Confirmed Need Approval and Release Contract

**Status:** Completed architecture task; implementation not started

**Accepted baseline:** `c4d7970399f6b1c147700925f03e84efdafb0747`

**Architecture:** [RMVP-07 Confirmed Need Approval and Release Contract](../architecture/rmvp-07-confirmed-need-approval-release-contract.md)

**Decision:** [Decision RMVP-07 — Confirmed Need Approval and Release](../decisions/decision-rmvp-07-confirmed-need-approval-release.md)

## 1. Objective

Close the Product and Architecture authority required after RMVP-06 validation and before any approval/release implementation.

This task defines:

- full-batch approval of one exact successful validation;
- an immutable every-and-only approval snapshot;
- separate release of that exact snapshot;
- one append-only Planning release record for future CMD-03 consumption;
- separate approval and release capabilities;
- additive read-model and Vietnamese workbench behavior; and
- the exact ceiling for a future RMVP-07B implementation.

## 2. Completed documentation deliverables

- `docs/architecture/rmvp-07-confirmed-need-approval-release-contract.md`
- `docs/decisions/decision-rmvp-07-confirmed-need-approval-release.md`
- this implementation handoff
- RMVP-06 merged-state and RMVP-07A status update in `docs/architecture/roadmap.md`
- accepted D-031 registration in `docs/decisions/decision-register.md`
- merged-state correction in `docs/api/rmvp-06-connected-confirmed-need-validation.md`
- merged-state correction in `docs/implementation-tasks/TASK-RMVP-06B-connected-confirmed-need-validation.md`

The exact RMVP-07A documentation manifest is therefore seven Markdown files.

## 3. Accepted future implementation boundary

A separately authorized RMVP-07B implementation may add exactly:

### Public APIs

```text
atlas_api.approve_confirmed_needs(request jsonb) returns jsonb
atlas_api.release_confirmed_needs_for_purchase_handoff(request jsonb) returns jsonb
```

Both use:

```text
contract version: RMVP-07.v1
source kind: NEED_GENERATION only
aggregate: ConfirmedNeedBatch
```

### Capabilities

```text
confirmed_need_approval.approve
confirmed_need_release.release
```

Both are active and unbound. No production Actor or role binding is allowed in the migration.

### Runtime and role ceiling

- reuse `atlas_confirmed_need_review_runtime`;
- add zero database roles;
- add zero runtime roles;
- add zero application roles;
- add zero scope kinds.

### Persistence ceiling

- reuse `confirmed_need_approval_snapshots`;
- reuse `confirmed_need_snapshot_lines`;
- add source-qualified approval-snapshot ownership;
- add the exact successful-validation-attempt binding and lifecycle-neutral `validated_fact_fingerprint` to `NEED_GENERATION` approval snapshots;
- add the minimum current approval/release pointers to `confirmed_need_batches`;
- add exactly one new private relation: `confirmed_need_releases`, constrained to `source_kind = NEED_GENERATION` through typed composite ownership;
- add only required restrictive FKs, unique constraints, check constraints, indexes, forced-RLS policies, immutable guards and deferred integrity guards;
- add zero views, materialized views, sequences or generic registries.

### Application ceiling

- add approval and release client calls;
- extend existing Confirmed Need models and review API additively;
- update only the existing Vietnamese `Xác nhận nhu cầu` workbench;
- add no new route, navigation item, dashboard or generic workflow component.

### Business boundary

Approval:

```text
exact current successful validation
+ equal lifecycle-neutral RMVP-07 validated-fact projection
+ complete current line set
→ immutable approval snapshot
→ APPROVED
```

Release:

```text
exact current approval snapshot
+ current lifecycle-neutral projection equal to the fingerprint accepted by approval
→ immutable Confirmed Need release record
→ RELEASED_FOR_PURCHASE_HANDOFF
```

Neither command creates Purchase Handoff or downstream facts.

The implementation must preserve this exact alternative-family rule:

```text
WHOLESALE approval snapshot
→ validation-attempt binding NULL
→ validated_fact_fingerprint NULL
→ no RMVP-07 current approval/release pointer required
→ no RMVP-07 release record required or permitted
→ existing PA-05D atomic version-1 behavior remains valid

NEED_GENERATION approval snapshot
→ validation-attempt binding and validated_fact_fingerprint non-NULL
→ current approval pointer required in APPROVED and RELEASED states
→ RMVP-07 release record and current release pointer required in RELEASED_FOR_PURCHASE_HANDOFF
```

## 4. Required transaction semantics

Both future commands must:

1. use standard command receipts and exact idempotent replay;
2. resolve the Actor from the authenticated JWT subject;
3. enforce active `GLOBAL` scope and the exact capability;
4. reject `WHOLESALE` for the first connected slice;
5. lock the batch and dependent facts in deterministic order;
6. enforce optimistic concurrency through `expected_version`;
7. preserve the RMVP-06 attempt fingerprint as immutable lifecycle-bound history and never recompute it after lifecycle advancement;
8. reconstruct/recompute `RMVP-07-VALIDATED-FACTS.v1`, compare the lifecycle-neutral fingerprints, and fail closed on changed source, policy, decision, Unit, quantity, tick, membership, blocker or warning facts;
9. increment the batch version exactly once on success;
10. change only controlled lifecycle metadata on included line revisions;
11. persist receipt, domain event and audit atomically; and
12. return the exact frozen success/failure fields and authoritative additive workbench readback.

Approval accepts only `reason_code = CONFIRMED_NEED_APPROVAL_REQUESTED`; release accepts only `reason_code = CONFIRMED_NEED_RELEASE_REQUESTED`. `reason_note` is null or trimmed 1–500 characters. Exact replay returns the byte-for-byte stored response and creates no alternate replay shape.

No automatic frontend retry is allowed after an unknown mutation outcome.

## 5. Required approval evidence

Approval must prove:

- source batch was exactly `VALIDATED`;
- current batch version equals the successful validation resulting version;
- blocker count is zero;
- observed line count equals the complete current stable-line count;
- each line has exactly one current revision and decision;
- validation bindings still match current revision, policy, Unit, source release, quantity and planning ticks;
- lifecycle-neutral current projection matches the projection reconstructed from validation evidence;
- approval stores the exact `validated_fact_fingerprint`, while the RMVP-06 attempt fingerprint remains unchanged and audit-only;
- snapshot includes every-and-only one line per current stable line;
- snapshot line binds exact revision and approved quantity; and
- no approval or snapshot line is editable or deletable.

## 6. Required release evidence

Release must prove:

- source batch was exactly `APPROVED`;
- expected version equals the current approved version;
- one current approval snapshot exists and belongs to that version;
- approval snapshot is bound to the exact successful validation attempt;
- snapshot membership is complete;
- every snapshot line still names the exact current `APPROVED` revision and quantity;
- approval-bound lifecycle-neutral facts remain unchanged;
- one immutable release record is created for that snapshot; and
- no Purchase Handoff, Procurement, Warehouse or Dispatch relation changes.

## 7. Test requirements for RMVP-07B

The implementation task must create a focused exact-plan pgTAP suite and register it in ready-state Full Integration.

Minimum database coverage:

### Catalog/security

- two exact APIs and no overloads;
- fixed empty search paths;
- exact runtime owners;
- execute only for `authenticated`;
- exact revokes;
- two exact capabilities and zero production bindings;
- one exact release relation;
- source-qualified snapshot/release ownership and the exact WHOLESALE/NEED_GENERATION alternative-family constraints;
- forced RLS and direct browser denial;
- exact role/runtime/view/state/scope ceilings; and
- current platform-catalog reconciliation.

### Approval

- authorization denial;
- source-kind denial;
- invalid lifecycle;
- stale expected version;
- missing/failed/noncurrent validation;
- incomplete validation evidence;
- changed lifecycle-neutral projection;
- explicit proof that the RMVP-06 attempt fingerprint is not the approval/release recomputation target;
- exact lifecycle-neutral projection/fingerprint storage;
- successful complete approval;
- exact snapshot and snapshot lines;
- exact validation-attempt binding;
- line lifecycle metadata transition;
- single batch version increment;
- receipt/event/audit atomicity;
- exact replay; and
- idempotency conflict.

### Release

- authorization denial;
- invalid lifecycle;
- stale expected version;
- missing/noncurrent approval;
- incomplete snapshot membership;
- changed approval facts;
- successful exact release record;
- line lifecycle metadata transition;
- single batch version increment;
- zero Purchase Handoff/downstream delta;
- receipt/event/audit atomicity;
- exact replay; and
- idempotency conflict.

### Compatibility

- RMVP-05 remains exact and additive;
- RMVP-06 remains exact and additive;
- H1B1 decision evidence remains immutable;
- direct-wholesale PA-05D tests remain unchanged and prove its approval snapshot has null validation binding/fingerprint, null RMVP-07 pointers and no RMVP-07 release row;
- CMD-15 materialization remains unchanged; and
- all registered suites pass after a fresh seedless reset.

Minimum frontend/browser coverage:

- backend-derived action eligibility;
- exact Vietnamese labels;
- approval from validated readback;
- approved readback and release action;
- released readback and read-only state;
- stale failure refresh;
- late-response suppression;
- unknown-outcome refresh-before-retry; and
- complete RMVP-04 → CMD-15 → RMVP-05 → RMVP-06 → RMVP-07 journey.

The implementation must also prove the exact request reason/note rules, approval/release response fields, byte-for-byte replay shape, additive read field names/types, both closed machine-readable disabled-code registries and their first-match precedence.

## 8. Required changed-path discipline for RMVP-07B

The implementation prompt must pin the exact post-RMVP-07A merged `main` SHA and list an exact changed-path manifest before work begins.

Expected categories are limited to:

- one migration;
- one focused pgTAP suite plus unavoidable registered historical catalog updates;
- existing Supabase integration workflow registration;
- existing local browser fixture/verifier where required;
- existing Confirmed Need connection/model/API/workbench/test files;
- one exact API contract;
- one implementation record;
- roadmap/status updates.

Unrelated formatting, refactoring, dependency updates and broad documentation rewrites are prohibited.

## 9. Explicit exclusions

RMVP-07B must not include:

- reopen;
- source correction or corrected rematerialization;
- CMD-03 or Purchase Handoff creation;
- supplier allocation or PO creation;
- Procurement, Warehouse or Dispatch mutation;
- partial approval or release;
- mandatory distinct approving/releasing Actors;
- warning acknowledgement infrastructure;
- production capability binding;
- production Planning-policy seed;
- hosted Supabase mutation;
- Retool or OPS v1/v2 change;
- Edge Function or deployment;
- generic workflow, task, case or notification infrastructure;
- runtime AI decision-making; or
- direct-wholesale behavior changes.

## 10. Validation for this architecture task

RMVP-07A is documentation only. Review is limited to:

- merged authority and exact baseline;
- OPS_SYSTEM_MAP alignment;
- API/capability uniqueness;
- approval/release state and snapshot consistency;
- implementation ceiling and exclusions;
- roadmap and decision-register consistency;
- exact seven-file Markdown manifest, including both corrected RMVP-06 merged-status files;
- relative document links;
- Markdown formatting and diff whitespace; and
- unchanged hosted Supabase and Retool boundaries.

No local database reset, pgTAP, browser journey or frontend build is required solely for this architecture task.

## 11. Completion gate

RMVP-07A is complete when its documentation PR is independently reviewed and merged.

RMVP-07B may begin only from the exact resulting `main` SHA and under a separate explicit implementation authorization.
