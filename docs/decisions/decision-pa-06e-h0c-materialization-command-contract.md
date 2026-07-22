# Decision PA-06E-H0C — Materialization Command Contract

**Status:** Implemented under Issue #143; focused H0Cb validation complete; pending independent governance review

**Date:** 2026-07-22

**Issue:** [#137](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/137)

**Baseline:** `68edd07527697113bd9d6c5306d917b66adb88ce`

**Architecture record:** [TASK-PA-06E-H0Ca](../implementation-tasks/TASK-PA-06E-H0Ca-materialization-command-contract.md)

**Implementation record:** [TASK-PA-06E-H0Cb](../implementation-tasks/TASK-PA-06E-H0Cb-confirmed-need-materialization-command.md)

## 1. Decision outcome

Atlas accepts one bounded Planning command contract for the Need Generation to Draft Confirmed Need boundary and reserves the next registry identity:

```text
reserved ID: CMD-15
function: atlas_api.create_confirmed_needs_from_generation(jsonb)
contract version: PA-06E-H0C.v1
capability: confirmed_need_generation.materialize
```

The command consumes one exact immutable Need Generation release and makes one Planning-owned Confirmed Need Batch the authoritative aggregate. It creates Draft operational proposals and immutable contribution membership only. It does not create a Planning decision, policy fact, approval snapshot, release, Purchase Handoff, Procurement fact, Warehouse fact, Dispatch fact, or application workflow state.

H0Ca is the sole pre-implementation source for the reserved CMD-15 contract. H0Cb must atomically implement the function and append its exact application-facing entry to the PA-06A canonical registry in the same reviewed change. After H0Cb merges, PA-06A becomes the sole exact executable request/response registry and this decision remains the architectural rationale.

## 2. Canonical registry governance

PA-06A remains the canonical registry of executable application functions. At the H0Cb exact head it is exactly:

```text
15 write commands
+ 4 authorized reads
= 19 executable functions
```

H0Ca did not add a non-executable entry to that registry. H0Cb now publishes CMD-15 atomically with its migration, dedicated runtime, grants/policies, and four focused suites, so the canonical registry and physical catalog agree at 19.

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

## 5. Exact bounded success contract

The command returns the shared success envelope with exactly these additions:

```text
affected_aggregate_ids.need_generation_run_id
affected_aggregate_ids.confirmed_need_batch_id

new_versions.need_generation_run_version
new_versions.confirmed_need_batch_version

result_counts.created_confirmed_need_line_count
result_counts.reused_confirmed_need_line_count
result_counts.retired_confirmed_need_line_count
result_counts.created_line_revision_count
result_counts.created_revision_contribution_count
result_counts.current_line_revision_count
result_counts.superseded_line_revision_count
```

`result_counts` is one allowlisted top-level object. Counts are nonnegative integers derived from committed rows.

The response does not return arrays of every line, revision, or contribution UUID. A valid H0C transaction may create up to 25,000 membership rows and 15,000 operational groups; returning every private ID would violate the bounded-response and minimum-disclosure boundary. Detailed IDs and source evidence remain in private immutable relations for later authorized reads.

No private source payload, caller-authored grouping, complete membership array, Menu/Attendance/Recipe payload, or authorization fact is returned as authority.

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

- locks and rereads the complete old and new source sets and current Confirmed Need state;
- deterministically regroups the complete new active set;
- reuses a stable line only when the complete seven-part identity is unchanged;
- creates one successor Draft revision with complete new membership for **every operational group retained in the new release**, even when quantity and membership facts are otherwise unchanged, because every current revision must bind the batch's new controlled-current source triple;
- preserves every prior revision and membership payload;
- marks each replaced prior current revision `SUPERSEDED` and noncurrent;
- creates new stable lines and revision 1 for genuinely new identities;
- permits a direct one-to-one Ingredient correction only when exact H0A5 predecessor evidence maps one prior active contribution to one new active contribution with a changed Ingredient and no split or merge;
- moves the corrected contribution to the new Ingredient group without mutating the old stable line's identity;
- when that matched move empties the old Ingredient group, supersedes its old current revision and leaves the historical stable line with no current revision rather than creating a prohibited empty or zero-membership revision;
- when an old group remains nonempty after matched moves, creates its required successor revision from the remaining complete active membership;
- permits genuinely new same-Ingredient contributions to join the matching retained or new group;
- rejects any empty old group not explained entirely by accepted direct one-to-one Ingredient moves as `SOURCE_REMOVAL_POLICY_REQUIRED`;
- sets each new proposal to the new exact theoretical total, never carrying a prior proposal or confirmed value automatically;
- advances the controlled-current source and increments the batch version exactly once; and
- completes one receipt, one `ConfirmedNeedsRematerialized` event, and one audit event.

A retired stable line is historical, not deleted or cancelled. Its revisions and memberships remain immutable, it has no current revision, and it is excluded from the current-release partition by the merged H0B1 rules.

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
- Exact replay returns the original bounded response and IDs.
- Changed command/key reuse returns `IDEMPOTENCY_CONFLICT`.

Event payloads contain the exact source triple, period, aggregate metadata, and the same bounded created/reused/retired/superseded counts—not UUID arrays, complete memberships, names, source-owner payloads, or authorization facts.

Audit before/after contains batch status, version, controlled-current source triple, and bounded counts. Detailed lineage remains in immutable relations.

## 14. H0Cb test and registry ownership

H0Cb must:

1. implement and secure the function;
2. add the exact capability/runtime/grants/policies;
3. append CMD-15 to PA-06A only when the executable function exists;
4. prove the canonical registry and physical `atlas_api` surface both equal 19 at the exact head; and
5. create exactly four independent test families:
   - registry/validator/security/runtime/catalog and bounded response schema;
   - initial materialization/grouping/receipt/replay/limits;
   - corrected materialization with a successor revision for every retained group, historical-line retirement for an exact Ingredient move, and source advancement;
   - errors/authorization/blockers/stale/concurrency.

Issue #143 fixes the four H0Cb plans at `64`, `80`, `104`, and `112`, for exactly `360/360` focused assertions. Prior H0A/H0B1/PA-05 behavioral plans and fixtures remain unchanged. The only prior-test compatibility amendment is the explicitly authorized executable `atlas_api` catalog expectation from 18 to 19 (including CMD-15 in exact signature arrays); existing `plan(N)` values do not change.

## 15. Consequences

H0Ca closed the business and command decisions without misrepresenting an unimplemented function as executable. H0Cb implements that accepted contract and performs the single authorized canonical/physical transition from 18 to 19.

H1 policy, decision evidence, authorized review/preview/confirmation, validation, approval, release, Purchase Handoff, Procurement, Warehouse, Dispatch, application connection, hosted deployment, and production rollout remain separate.

Documentation rollback is a normal Git revert. The H0Cb migration is additive and has not been applied to hosted or production systems in this task. Before any future deployment/use, rollback may remove CMD-15, its capability, policies/grants, and dedicated runtime together; after operational receipts or Confirmed Need rows exist, rollback requires a separately approved data-preserving procedure rather than silent deletion.
