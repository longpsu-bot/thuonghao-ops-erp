# PA-06E-H1B1 — Policy-Bound Confirmed Need Line Decision Contract

**Status:** Product-approved contract; H1B1 private persistence implemented under Issue #153 and pending independent PR review; H1B2 commands remain separately unauthorized

**Issue:** [#151](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/151)

**Exact documentation baseline:** `0ba89ff8c3434979eb3e8897a6bcf9bb2171c51f`

**Product approval:** [Phase 0 registry](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/151#issuecomment-5080872730) and [approval/corrections](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/151#issuecomment-5081145875)

**Canonical decision registry:** [Decision PA-06E-H1B1 — Policy-Bound Line Decision Evidence](../decisions/decision-pa-06e-h1b1-policy-bound-line-decision-evidence.md)

**Persistence implementation record:** [TASK-PA-06E-H1B1 — Policy-Bound Line Decision Persistence](../implementation-tasks/TASK-PA-06E-H1B1-policy-bound-line-decision-persistence.md)

**Parent contracts:** [PA-06E Confirmed Need Review, Adjustment, Revision, and Source Correction](pa-06e-confirmed-need-review-adjustment-revision-contract.md), [PA-06E-H0 School-Catering Persistence and Materialization](pa-06e-h0-school-catering-persistence-and-materialization-contract.md), [Planning Confirmed Need](planning-domain-confirmed-need-contract.md), and [PA-06E-H1A Planning Quantity Policy](../decisions/decision-pa-06e-h1a-planning-quantity-policy.md)

## 1. Executive outcome

H1B1 retains the existing Planning-owned aggregate:

```text
ConfirmedNeedBatch
→ ConfirmedNeedLine
→ ConfirmedNeedLineRevision
→ ConfirmedNeedLineDecision
```

`ConfirmedNeedLineDecision` is an append-only evidence child, not a new aggregate root. One decision concerns one exact stable line and one exact quantity-bearing line revision.

The authority split is:

```text
ConfirmedNeedLineRevision
→ immutable source membership, theoretical quantity, proposed/confirmed quantity,
  controlled Unit, predecessor, and current-revision state

ConfirmedNeedLineDecision
→ explicit Planning intent, reviewed before values, confirmed after value,
  exact Planning-policy revision, tick evidence, governed reason,
  accountable actor/time, command identity, and append-only predecessor

ConfirmedNeedLine.current_confirmed_need_line_decision_id
→ nullable until the first authoritative decision
→ points to the one current append-only decision after H1B2
```

H1B1 provides persistence structure only. It creates no command, writer, read model, API, runtime grant, React path, Retool path, production decision, or seed. H1B2 remains the first task allowed to append decisions or advance the pointer.

## 2. OPS_SYSTEM_MAP placement

| Layer               | H1B1 placement                                                                                                                                                                                   |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Mission             | Preserve explainable Planning authority without silently rewriting calculated evidence or downstream commitments.                                                                                |
| Business Capability | Record which exact operational quantity Planning accepted or adjusted, under which exact Planning policy, and retain every replacement decision.                                                 |
| Business Domain     | Planning owns the decision meaning. Source owners retain source corrections. Procurement consumes only later approved and released Planning facts.                                               |
| Business Object     | Existing Confirmed Need aggregate plus append-only `ConfirmedNeedLineDecision`.                                                                                                                  |
| Business Contract   | This contract, the canonical H1B1 decision registry, PA-06E, H0B1b/H0C, H1A, PA-01, PA-02, and PA-03.                                                                                            |
| Command / Event     | None in H1B1. Future H1B2 owns preview/confirmation commands, one receipt, one domain event, and one audit event per transactional action.                                                       |
| Read Model          | None in H1B1. Future H1B2 owns authorized review/readback and derives logical adjustments from adjusted decisions.                                                                               |
| Application         | None in H1B1. React and Retool remain non-authoritative.                                                                                                                                         |
| Technology          | Future private PostgreSQL relation, one nullable stable-line pointer, typed keys, immutable guards, mandatory deferred integrity, forced RLS, zero policies, and rolled-back synthetic fixtures. |

The governing sequence remains:

```text
H0B1b typed line/revision/source membership
→ H0C non-authoritative Draft materialization
→ H1A Planning policy persistence
→ H1B1 policy-bound decision structure
→ H1B2 authorized preview and confirmation
```

## 3. Business meanings

### 3.1 Proposed quantity is not authority

H0C may create a `DRAFT` current revision with `theoretical_quantity` and a proposed value in the existing `confirmed_quantity` field. The field name does not make that value authoritative.

Before the stable line has a current decision pointer, the value is a proposal only.

### 3.2 Unchanged proposal acceptance

`UNCHANGED_PROPOSAL_ACCEPTED` means Planning explicitly accepted the already-current proposal.

It:

- binds the existing current revision;
- creates no identical successor revision;
- records the exact theoretical-before, proposed-before, and confirmed-after values;
- requires all three relevant proposal/confirmed values to agree as defined by the decision registry;
- binds one exact eligible H1A policy revision; and
- records `PROPOSAL_ACCEPTED` as the business reason.

### 3.3 Adjusted quantity confirmation

`ADJUSTED_QUANTITY_CONFIRMED` means Planning confirmed a value different from the reviewed proposal.

Future H1B2 must atomically:

1. create one direct successor line revision;
2. preserve the exact source and contribution membership unless a separately authorized source-correction workflow has already changed the source evidence;
3. make that successor the current revision;
4. append one adjusted decision bound to the successor; and
5. advance the stable-line pointer to that decision.

A Planning adjustment is never an in-place revision update and never a source correction.

### 3.4 Replacement decision

A correction to decision evidence appends a complete replacement row. It does not update or delete the earlier decision.

The replacement:

- keeps the business decision kind that describes the replacement result;
- keeps the governed business reason for that result;
- names the prior current decision as its direct predecessor;
- increments the line-local decision number by one;
- requires a nonblank correction note; and
- becomes current atomically.

A metadata/evidence correction may bind the same current revision. A corrected quantity must bind one new direct successor revision.

## 4. Exact first-slice decision vocabulary

The business decision kinds are exactly:

```text
UNCHANGED_PROPOSAL_ACCEPTED
ADJUSTED_QUANTITY_CONFIRMED
```

There is no generic confirmation kind, correction kind, status workflow, cancellation kind, or UI-authored kind.

The business reason codes are exactly:

```text
PROPOSAL_ACCEPTED
PLANNING_STEP_ADJUSTMENT
OPERATIONAL_QUANTITY_ADJUSTMENT
OTHER
```

Rules:

- `PROPOSAL_ACCEPTED` belongs only to `UNCHANGED_PROPOSAL_ACCEPTED`.
- `PLANNING_STEP_ADJUSTMENT`, `OPERATIONAL_QUANTITY_ADJUSTMENT`, and `OTHER` belong only to `ADJUSTED_QUANTITY_CONFIRMED`.
- `OPERATIONAL_QUANTITY_ADJUSTMENT` and `OTHER` require a note.
- `PLANNING_STEP_ADJUSTMENT` permits an optional note.
- The first unchanged acceptance has no note.
- Every decision with a predecessor requires a correction note, including a replacement unchanged acceptance.
- A present note is trimmed, nonblank Unicode text with a maximum length of 500 characters.

`DECISION_EVIDENCE_CORRECTION` and `MANAGEMENT_OVERRIDE` are excluded. Predecessor linkage and the required correction note identify correction without replacing the business reason.

## 5. Revision and source binding

Every decision binds:

- one exact Confirmed Need batch;
- one exact stable line;
- one exact line revision owned by that line;
- the line's exact `NEED_GENERATION` operational identity;
- the exact controlled Unit; and
- one exact H1A policy root and policy revision.

When a decision becomes current, its bound line revision must be the stable line's current revision at transaction end.

The decision does not duplicate contribution membership or source payload. The revision and its immutable contribution rows remain source authority.

H1B1 is school-catering decision structure only. It does not change the PA-05D direct-wholesale pass-through path.

## 6. Planning-policy binding

Every decision stores non-null:

```text
planning_quantity_policy_id
planning_quantity_policy_revision_id
unit_id
```

The exact H1A composite ownership key proves policy root, policy revision, and Unit agreement.

The decision does not copy:

- policy revision number;
- Planning step;
- effective dates; or
- policy lifecycle fields.

Those remain authoritative on the immutable H1A policy revision.

At transaction end, the bound policy revision must be the sole eligible revision for the line's exact Unit and service date:

```text
policy_revision_status in (ACTIVE, RETIRED)
effective_from <= service_date
and (effective_to is null or service_date < effective_to)
```

Draft, missing, future-only, expired, ambiguous, stale, wrong-Unit, or nonrepresentable bindings fail closed. H1B1 exposes no resolver or operator-facing error envelope; future H1B2 re-resolves under lock and maps failures to safe command errors.

## 7. Quantity evidence

Every decision stores exact PostgreSQL numeric evidence:

```text
theoretical_quantity_before numeric(20,6)
proposed_quantity_before    numeric(20,6)
confirmed_quantity_after    numeric(20,6)
planning_tick_count         numeric(20,0)
unit_id                     uuid
```

All quantities and tick counts are nonnegative.

For unchanged acceptance:

- theoretical-before equals the bound revision's theoretical quantity;
- proposed-before equals the bound revision's proposal/confirmed quantity;
- confirmed-after equals proposed-before; and
- the decision binds the existing current revision.

For adjusted confirmation:

- theoretical-before equals the successor revision's unchanged theoretical/source total;
- proposed-before equals the direct predecessor revision's confirmed proposal;
- confirmed-after equals the successor revision's confirmed quantity; and
- the decision binds the successor revision.

For both kinds:

```text
confirmed_quantity_after
= planning_tick_count × bound_policy_revision.planning_step
```

The equality is exact. There is no floating type, epsilon, silent rounding, truncation, client normalization, or Unit conversion.

## 8. Actor and command evidence

Every decision stores:

```text
decided_by_actor_id
decided_at
command_id
confirmed_need_batch_version
created_at
```

`decided_by_actor_id` is the one accountable Planning decision actor. In future H1B2, the authenticated command actor must equal this actor and satisfy the separately approved Planning capability and relational scope.

There is no proxy actor, recording actor, administration actor, production membership, or first-slice separation-of-duties rule.

`command_id` links the decision to the existing command receipt/evidence envelope. Correlation, idempotency, receipt ID, domain-event ID, audit-event ID, request payload, and broader trace remain authoritative in existing receipt/event/audit relations and are not duplicated on every line decision.

`confirmed_need_batch_version` records the exact post-command aggregate version at which the decision became authoritative. Later approval or release versions do not rewrite it.

## 9. Append-only chain and current pointer

The first decision for one line has:

```text
decision_number = 1
predecessor_decision_id = null
```

Every later decision:

- belongs to the same line;
- has decision number exactly one greater than its predecessor;
- names the line's prior current decision as direct predecessor;
- cannot fork an existing predecessor; and
- must become current in the same transaction.

The stable-line pointer is:

```text
atlas_planning.confirmed_need_lines.current_confirmed_need_line_decision_id uuid null
```

It has no default and remains null for H0/H1A rows and new Draft materialization.

Allowed pointer movement is only:

```text
null → first decision
old current → direct successor decision
```

Once non-null, the pointer cannot be cleared, moved laterally, moved to an ancestor, or pointed to another line.

A prior H0 proposal that rematerialization could clear the pointer is superseded for this first slice. Any post-H1B2 rematerialization lifecycle must append or rebind authority atomically, or receive separate product and architecture approval.

## 10. Future bounded physical direction

The smallest approved direction is one new private relation:

```text
atlas_planning.confirmed_need_line_decisions
```

and one nullable column added to the existing stable line:

```text
atlas_planning.confirmed_need_lines.current_confirmed_need_line_decision_id
```

### 10.1 Proposed decision columns

The future persistence task should implement exactly the approved meanings through columns in these groups:

**Identity and ownership**

- `confirmed_need_line_decision_id`
- `confirmed_need_batch_id`
- `confirmed_need_line_id`
- `confirmed_need_line_revision_id`
- `source_kind`
- `service_date`
- `customer_id`
- `school_id`
- `delivery_location_id`
- `ingredient_id`
- `unit_id`

**Decision chain**

- `decision_number`
- `predecessor_decision_id`
- `decision_kind`

**Policy and quantity evidence**

- `planning_quantity_policy_id`
- `planning_quantity_policy_revision_id`
- `theoretical_quantity_before`
- `proposed_quantity_before`
- `confirmed_quantity_after`
- `planning_tick_count`

**Reason, actor, and command evidence**

- `reason_code`
- `reason_note`
- `decided_by_actor_id`
- `decided_at`
- `command_id`
- `confirmed_need_batch_version`
- `created_at`

Issue #153 fixed the constraint and index names before implementation. No business-evidence column may be added, removed, renamed, or reinterpreted without an explicit decision amendment.

### 10.2 Key and constraint direction

The H1B1 migration provides:

- database-generated UUID decision identity;
- positive line-local decision number;
- one unique decision number per line;
- first/null and later/non-null predecessor shape;
- direct same-line predecessor ownership;
- non-forking predecessor uniqueness;
- exact line operational-identity ownership;
- exact revision ownership through a bounded revision decision-owner key;
- exact H1A policy root/revision/Unit ownership;
- exact kind/reason/note compatibility;
- nonnegative quantity and tick checks;
- one command decision per line;
- restrictive actor and receipt-command references;
- immutable decision rows and no delete; and
- a deferrable same-line pointer FK.

### 10.3 Function and trigger direction

The bounded implementation target is exactly three private functions:

1. one decision immutability/delete guard;
2. one stable-line pointer-transition guard; and
3. one deferred final-state decision/pointer/policy integrity function.

The bounded trigger target is exactly six triggers:

1. ordinary decision guard;
2. ordinary stable-line pointer guard;
3. deferred integrity on decisions;
4. deferred integrity on stable lines;
5. deferred integrity on line revisions; and
6. deferred integrity on H1A policy revisions.

The deferred function must prove transaction-end:

- direct linear decision lineage;
- pointer monotonicity;
- pointed decision and current revision agreement;
- line/revision/Unit/operational-identity agreement;
- sole eligible exact policy revision;
- exact quantity evidence and tick multiplication;
- unchanged versus adjusted revision semantics; and
- current decision command/batch-version evidence shape.

If implementation requires another relation, a generic helper, resolver, extension, role, capability, runtime, policy, positive grant, API, view, or writer, stop and amend the contract.

## 11. Security boundary

The future decision relation must be:

- owned by `atlas_owner`;
- private in `atlas_planning`;
- RLS-enabled and forced;
- protected by zero RLS policies; and
- inaccessible to `PUBLIC`, `anon`, `authenticated`, `service_role`, and every existing runtime role.

All private functions must be:

- `atlas_owner` owned;
- security invoker;
- fixed to an empty `search_path`;
- fully schema-qualified and static; and
- revoked from public, API, service, and runtime roles.

H1B1 creates zero:

- roles;
- capabilities;
- memberships;
- runtimes;
- RLS policies;
- positive runtime/API grants;
- `atlas_api` functions;
- PA-06A registry entries;
- views/read models;
- commands/events;
- production writers; or
- seed rows.

## 12. OPS v1 and Retool boundary

The active OPS project remains the healthy hosted Supabase project `qnthofvccilhnefdcxnz` in `ap-southeast-1`. Its current Purchase Planner persists mutable manual overrides through server-side functions and groups operational work around service date, School, and Ingredient. Retained `ops_v2` experiments additionally use `effective_line_key`.

That evidence confirms operator intent but is not the target persistence contract. H1B1 does not copy:

- `actual_need_overrides`;
- `purchase_assignments`;
- `effective_line_key` as decision authority;
- Retool component state;
- public-schema RPC conventions; or
- mutable overwrite semantics.

No hosted Supabase, OPS v1/v2, or Retool change is authorized by this contract.

## 13. Compatibility and supersession

This contract preserves:

- PA-05D direct-wholesale behavior;
- H0B1b source-family, stable-line, revision, and contribution invariants;
- H0C Draft-only materialization and CMD-15 behavior;
- H1A policy ownership, lifecycle, and security; and
- the current 19-function `atlas_api` / 15-write / four-read PA-06A registry.

It supersedes only these earlier H0 proposals:

1. the exact H1B1 reason vocabulary and authority were pending;
2. a replacement decision now preserves its business reason and uses predecessor plus required correction note;
3. `DECISION_EVIDENCE_CORRECTION` and `MANAGEMENT_OVERRIDE` are excluded;
4. one accountable decision actor replaces any proxy/recording-actor possibility; and
5. the current-decision pointer cannot be cleared after first authority in this slice.

## 14. Validation ownership for H1B1 persistence

Issue #153 fixed the pgTAP plans before coding. Test ownership is separated into:

1. structure, keys, security, and catalog delta — `plan(64)`;
2. append-only chain, reason policy, actor, command, and pointer transitions — `plan(48)`; and
3. revision, policy, service-date, and exact quantity/tick integrity — `plan(48)`.

The canonical current-platform catalog must own mutable whole-platform totals. Historical H0/H1A suites must not be edited merely to absorb current totals.

## 15. Current effect

Issue #153 implements this contract in
`20260726115324_pa_06e_h1b1_policy_bound_line_decision_persistence.sql`:
one private relation, one nullable pointer, three private functions, and six
triggers. The three focused suites provide 160 assertions, and the registered
workflow is 30 suites / 1,808 TAP assertions.

The implementation remains writerless and seedless. It adds zero role,
capability, membership, runtime, RLS policy, positive grant, API, PA-06A
entry, view, read model, command, event, application path, hosted action, or
deployment. H1B2 remains the first task allowed to append decisions, advance
the pointer, or expose review, preview, or confirmation.
