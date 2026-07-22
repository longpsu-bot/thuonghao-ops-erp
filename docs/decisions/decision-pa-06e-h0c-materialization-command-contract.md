# Decision PA-06E-H0C — Materialization Command Contract

**Status:** Accepted architecture decision; documentation only; executable implementation and canonical registry amendment remain H0Cb

**Date:** 2026-07-22

**Issue:** [#137](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/137)

**Baseline:** `68edd07527697113bd9d6c5306d917b66adb88ce`

**Implementation record:** [TASK-PA-06E-H0Ca](../implementation-tasks/TASK-PA-06E-H0Ca-materialization-command-contract.md)

## 1. Decision outcome

Atlas accepts one bounded Planning command contract for the Need Generation to Draft Confirmed Need boundary and reserves the next registry identity:

```text
reserved ID: CMD-15
function: atlas_api.create_confirmed_needs_from_generation(jsonb)
contract version: PA-06E-H0C.v1
capability: confirmed_need_generation.materialize
```

The command consumes one exact immutable Need Generation release and makes one Planning-owned Confirmed Need Batch the authoritative aggregate. It creates Draft operational proposals and immutable contribution membership only. It does not create a Planning decision, policy fact, approval snapshot, release, Purchase Handoff, Procurement fact, Warehouse fact, Dispatch fact, or application workflow state.

H0Ca is the sole pre-implementation source for the reserved CMD-15 contract. H0Cb must atomically implement the function and append its exact application-facing entry to the PA-06A canonical registry in the same reviewed change. After H0Cb merges, PA-06A becomes the sole exact request/response registry and this decision remains the architectural rationale.

## 2. Canonical registry governance

PA-06A remains the canonical registry of executable application functions. It stays exactly:

```text
14 write commands
+ 4 authorized reads
= 18 executable functions
```

H0Ca does not add a non-executable entry to that registry. Publishing a planned function there before its migration, runtime, grants, and tests exist would make the canonical application contract disagree with the database security boundary.

H0Cb must perform one atomic registry transition:

```text
before H0Cb: 14 writes + 4 reads = 18 executable functions
H0Cb implementation: add CMD-15 and its secured function
at H0Cb merge: 15 writes + 4 reads = 19 executable functions
```

CMD-01 through CMD-14 and READ-01 through READ-04 are never renumbered or changed by H0C.

## 3. OPS_SYSTEM_MAP placement

```text
Mission
→ preserve explainable school-catering demand from approved calculation to Planning review

Business Capability
→ materialize one complete released calculation into grouped Draft operational requirements

Business Domain
→ Planning

Business Objects
→ Need Generation Run and Release Snapshot
→ Confirmed Need Batch
→ stable Confirmed Need Line
→ immutable Confirmed Need Line Revision
→ immutable Revision Contribution Membership

Business Contract
→ H0A5 + H0B1 + reserved CMD-15

Command / Event
→ create_confirmed_needs_from_generation
→ ConfirmedNeedsCreated | ConfirmedNeedsRematerialized

Read Model
→ none added in H0C

Application
→ none added in H0C

Technology
→ later H0Cb PostgreSQL command, dedicated runtime, registry amendment, receipt/event/audit, and pgTAP
```

H0C is not a table loader and is not a Retool-style calculation script.

## 4. Exact request contract

The command uses the established Atlas write envelope. Its allowlisted payload is exactly:

```json
{
  "need_generation_run_id": "uuid",
  "need_generation_run_version": 1,
  "confirmed_need_batch_id": null
}
```

Rules:

- `confirmed_need_batch_id = null` selects initial materialization.
- A non-null value selects correction of that exact existing batch.
- Initial materialization requires envelope `expected_version = 1` as a creation sentinel.
- Correction requires `expected_version` equal to the authoritative current Confirmed Need Batch version.
- Initial versus correction mode is derived server-side.
- Unknown envelope or payload fields fail validation.
- The caller never supplies release-snapshot identity, quantities, grouping, membership, source lineage, Ingredient, Unit, Customer, School, destination, actor authority, status, policy, decision, approval, release, or downstream facts.

## 5. Exact success contract

The command returns the shared success envelope with these exact additions:

```text
affected_aggregate_ids.need_generation_run_id
affected_aggregate_ids.confirmed_need_batch_id
affected_aggregate_ids.created_confirmed_need_line_ids[]
affected_aggregate_ids.reused_confirmed_need_line_ids[]
affected_aggregate_ids.created_line_revision_ids[]
affected_aggregate_ids.created_revision_contribution_ids[]
affected_aggregate_ids.current_line_revision_ids[]
affected_aggregate_ids.superseded_line_revision_ids[]
new_versions.need_generation_run_version
new_versions.confirmed_need_batch_version
```

No private source payload, caller-authored grouping, or complete membership array is returned as authority.

## 6. Actor and authorization

H0C v1 is callable only by an active authenticated `HUMAN` Planning actor.

The command requires `confirmed_need_generation.materialize`. Integration actors, shared system actors, delegation, service-role identity, and background automation are outside v1.

Every `ACTIVE` released contribution must be covered by at least one active relational actor scope:

- `GLOBAL`;
- exact owning `CUSTOMER`;
- exact `SCHOOL`; or
- exact captured `DELIVERY_LOCATION`.

Authorization is complete-set authorization. Partial coverage rejects the whole command with `SCOPE_DENIED`; the command never materializes an authorized subset.

Service date remains an authoritative source fact, not an actor-scope column. No date-range scope storage is introduced.

## 7. Destination capture

Initial materialization resolves each School's current `default_delivery_location_id`, proves same-customer ownership and `SCHOOL_CATERING` customer type, and captures the exact Customer and destination into the stable operational identity.

Captured destination is immutable history.

Corrected materialization may reuse a stable line only when all seven stable identity members remain equal. A later School-default change does not silently move an existing requirement. A correction that would move an existing contribution only because the default changed fails with `OPERATIONAL_IDENTITY_UNAPPROVED`. A genuinely new School or operational identity may capture its current valid default.

## 8. Initial materialization

For one exact `RELEASED_FOR_CONFIRMATION` run/version with no prior batch, the command:

1. resolves and locks the run, release snapshot, complete release membership, active Theoretical Need lines, direct typed sources, Admin references, and calculation lineage;
2. rejects an empty active release and any zero-quantity active contribution in v1;
3. groups the complete active set by the accepted seven-part operational identity;
4. creates one `NEED_GENERATION` Confirmed Need Batch in `DRAFT_REVIEW`, version 1, with origin equal to controlled current source;
5. creates one stable line per group;
6. creates one current revision 1 in `DRAFT` per line;
7. copies the exact PostgreSQL numeric membership sum into `theoretical_quantity` and the stored non-authoritative proposal field;
8. creates complete immutable revision-owned contribution membership;
9. relies on merged H0B1 guards for totals, membership completeness, and current-release partition integrity; and
10. completes one receipt, one `ConfirmedNeedsCreated` event, and one audit event.

The stored proposal is not a Planning-authorized quantity.

## 9. Corrected materialization

Correction is allowed only for the exact existing `NEED_GENERATION` batch in `DRAFT_REVIEW` or `REOPENED`.

The requested run must be the direct released successor of the controlled-current run in the same Planning Input Set, period, and linear correction chain.

The command:

- locks and rereads the complete old/new source sets and current Confirmed Need state;
- deterministically regroups the complete new active set;
- reuses a stable line only when the complete seven-part identity is unchanged;
- creates a successor Draft revision for every affected reused line, including source-only or membership-only change with unchanged total;
- preserves prior revision and membership payloads;
- changes only controlled prior current/status metadata;
- creates new stable lines and revision 1 for genuinely new identities;
- permits one exact one-to-one Ingredient correction to move a contribution between immutable old/new Ingredient groups;
- permits genuinely new same-Ingredient contributions to join the matching group;
- sets each new proposal to the new exact theoretical total, never carrying a prior proposal or confirmed value automatically;
- advances the controlled-current source and increments the batch version exactly once; and
- completes one receipt, one `ConfirmedNeedsRematerialized` event, and one audit event.

H0C never reopens a batch automatically.

## 10. Closed first-slice blockers and safe errors

The command rejects the complete transaction for empty/zero source, incomplete or stale lineage, unsupported removal, unresolved empty old group, split/merge, ambiguous predecessor, conversion, changed operational identity, partial scope, approved/released state, downstream commitment, stale version, or accepted limits.

H0C-specific safe codes are exactly:

```text
GENERATION_NOT_RELEASED
SOURCE_LINEAGE_INCOMPLETE
SOURCE_REVISION_STALE
SOURCE_MAPPING_INCOMPLETE
SOURCE_SUCCESSOR_AMBIGUOUS
OPERATIONAL_IDENTITY_UNAPPROVED
CONTRIBUTION_MEMBERSHIP_INVALID
CONTRIBUTION_TOTAL_MISMATCH
EMPTY_ACTIVE_RELEASE
ZERO_ACTIVE_CONTRIBUTION_POLICY_REQUIRED
SOURCE_REMOVAL_POLICY_REQUIRED
SOURCE_SPLIT_MERGE_POLICY_REQUIRED
REOPEN_REQUIRED
DOWNSTREAM_CORRECTION_REQUIRED
MATERIALIZATION_LIMIT_EXCEEDED
```

These supplement common Atlas command errors and disclose no SQL, role, policy, constraint, credential, JWT, or stack-trace detail.

## 11. Runtime and security

The selected future runtime is:

```text
atlas_planning_materialization_runtime
```

It is `NOLOGIN`, `NOINHERIT`, owns only the future CMD-15 function, has no schema `CREATE`, no sequence mutation, and no membership in another runtime.

Its practical privileges are restricted to receipt/auth/capability/scope helpers; read-only H0A source access; required Confirmed Need reads/writes; controlled current/status/version changes; and one Planning domain event and audit event per success.

It receives no Purchase Handoff, Procurement, Evidence, Warehouse, Dispatch, Storage, reporting-write, `public`, `ops_v2`, Retool, or legacy privilege.

`atlas_planning_command_runtime` remains bounded to the four PA-05D functions and is not broadened.

After revoke-first hardening, `authenticated` may execute only the implemented CMD-15 signature. `PUBLIC`, `anon`, and `service_role` receive no execute. API roles receive no direct private-relation access.

## 12. Limits, locks, and retry

| Limit | Value |
|---|---:|
| Inclusive run period | 14 days |
| Distinct Schools | 500 |
| Active release members | 25,000 |
| Operational groups | 15,000 |
| `lock_timeout` | 5 seconds |
| `statement_timeout` | 120 seconds |

Business-size limits are checked before domain mutation and return `MATERIALIZATION_LIMIT_EXCEEDED`.

No internal retry loop is allowed. Serialization, deadlock, lock-timeout, and statement-timeout failures roll back the complete transaction and return `RETRYABLE_CONCURRENCY_FAILURE`. Only the exact frozen request may be retried.

Lock order is: receipt; Admin references; Recipe/source snapshots; Planning Input Set/run/release; Theoretical Need/predecessor/source-use rows; target batch; stable lines; current revisions; new revisions/memberships; controlled current metadata; event/audit.

## 13. Receipt, event, and audit

- Malformed envelope, unresolved subject, or inactive actor fails before accepted command identity and creates no receipt.
- Deterministic nonretryable failure after receipt acquisition stores one `FAILED_NON_RETRYABLE` receipt and creates no event or audit event.
- Retryable transaction failure leaves no completed failure receipt.
- Success stores one completed receipt, one domain event, and one audit event.
- Exact replay returns the original response and IDs.
- Changed command/key reuse returns `IDEMPOTENCY_CONFLICT`.

Event payloads contain the exact source triple, period, aggregate metadata, and created/reused/superseded counts—not complete membership arrays, names, source-owner payloads, or authorization facts.

Audit before/after contains batch status, version, controlled-current source triple, and bounded counts. Detailed lineage remains in immutable relations.

## 14. H0Cb test and registry ownership

H0Cb must:

1. implement and secure the function;
2. add the exact capability/runtime/grants/policies;
3. append CMD-15 to PA-06A only when the executable function exists;
4. prove the canonical registry and physical `atlas_api` surface both equal 19 at the exact head; and
5. create exactly four independent test families:
   - registry/validator/security/runtime/catalog;
   - initial materialization/grouping/receipt/replay/limits;
   - corrected materialization/history/Ingredient move/source advancement;
   - errors/authorization/blockers/stale/concurrency.

Exact `plan(N)` values belong to the H0Cb issue before coding. Existing H0A, H0B1, and PA-05D tests remain unchanged.

## 15. Consequences

H0Ca closes the business and command decisions needed for H0Cb without misrepresenting an unimplemented function as executable. H0Cb is the only task authorized to transition the canonical registry from 18 to 19.

H1 policy, decision evidence, authorized review/preview/confirmation, validation, approval, release, Purchase Handoff, Procurement, Warehouse, Dispatch, application connection, hosted deployment, and production rollout remain separate.

Documentation rollback is a normal Git revert. No database or production rollback exists because H0Ca changes no executable state.
