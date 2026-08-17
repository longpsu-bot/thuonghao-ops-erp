# PLANNING-CONTRACT-02B — Selective Confirmed Need Decision Continuity

**Status:** Accepted and implemented locally; draft PR review pending

**Decision:** [D-040](../decisions/decision-register.md)

**Implementation:** [TASK-PLANNING-CONTRACT-02B](../implementation-tasks/TASK-PLANNING-CONTRACT-02B-selective-confirmation-continuity.md)

## 1. Boundary

An upstream Planning successor makes the generated Need `OUTDATED`. Human confirmation validity is evaluated separately and proportionally for each current Confirmed Need business fact. PLANNING-CONTRACT-02B changes no source ownership, Recipe replacement semantics, lifecycle state, public command, operator capability, downstream release model, or production deployment boundary.

The existing atomic `RMVP-04.v2` correction remains the sole normal write boundary:

```text
source successor
→ generated Need OUTDATED
→ one atomic successor generation and Confirmed Need rematerialization
→ backend classifies each current line
→ operator reviews only facts that lost human authority
```

## 2. Stable identity and exact eligibility

Comparison is scoped to the same correction-eligible Confirmed Need batch and direct Need Generation successor. Stable identity is exactly:

```text
service_date
+ customer_id
+ school_id
+ delivery_location_id
+ ingredient_id
+ controlled_unit_id
```

Generated quantity is not identity. Carry eligibility is:

```text
same stable identity
+ successor theoretical_quantity IS NOT DISTINCT FROM predecessor theoretical_quantity
+ the sole effective policy revision equals the prior decision's planning_quantity_policy_revision_id
+ the direct predecessor line currently points to that valid human decision
= CARRIED_FORWARD
```

Quantities use PostgreSQL exact `numeric(20,6)` equality. There is no text formatting, extra rounding, epsilon, or JavaScript comparison. Effective policy resolution uses the existing RMVP-05/H1B1 semantics: exact controlled Unit and service date; revision status `ACTIVE` or historically eligible `RETIRED`; `effective_from <= service_date`; and `effective_to is null or service_date < effective_to`. Missing or multiple eligible revisions fail closed and retain the established policy blocker.

Dish, Recipe, Recipe version, Recipe line/revision, Need Generation run, release snapshot, source signature, source membership composition, and fingerprints are explicitly excluded from the carry predicate. They remain immutable audit and lineage evidence. D-039/PLANNING-CONTRACT-02A continues to answer which source facts changed; D-040 answers whether the aggregate business fact already confirmed by a human materially changed.

## 3. Immutable continuity evidence

The private relation is:

```text
atlas_planning.confirmed_need_line_decision_continuity
```

It records one source human decision, stable line and batch, predecessor revision/source context, successor revision/source context when present, exact command, initiating Actor, system timestamp, and one closed kind:

- `CARRIED_FORWARD`
- `INVALIDATED_PROPOSAL_CHANGE`
- `INVALIDATED_POLICY_INCOMPATIBLE`
- `INVALIDATED_LINE_REMOVED`

Rows are insert-only, cannot be updated or deleted, use typed foreign keys, and are protected by deferred relational integrity. The initiating Actor is the human who requested generation and is not represented as decision authorship. No new `confirmed_need_line_decisions` row is created by system carry or invalidation.

## 4. Materialization outcomes

For an eligible carried line, the predecessor current revision becomes historical, a new current revision binds the new released generation and its current contribution membership, `theoretical_quantity` is the new exact total, and `confirmed_quantity` is the source human decision's `confirmed_quantity_after`. The line retains the same current decision pointer. Exact `CARRIED_FORWARD` evidence authorizes that older decision for only this direct successor revision.

For a proposal change, the successor revision contains the new proposal, the prior decision remains historical, `INVALIDATED_PROPOSAL_CHANGE` evidence is inserted, and the current pointer is cleared atomically. Equal quantity under a different or ambiguous effective policy is not carry; exact `INVALIDATED_POLICY_INCOMPATIBLE` evidence clears authority. A removed fact receives no fake zero current revision; its old current revision is superseded and a prior human decision, if any, receives `INVALIDATED_LINE_REMOVED` evidence. A new or already-unreviewed fact has no prior human authority and therefore no fake continuity row. Removal counting is deliberately independent: it counts distinct direct-predecessor Confirmed Need business identities absent from the exact current successor set, whether or not those identities carried human authority.

## 5. Decision pointer and human chain

A current decision pointer is valid only when the human decision either directly binds the current revision or an exact `CARRIED_FORWARD` row connects that decision from the direct predecessor revision to the current successor revision. Arbitrary old-revision pointers remain invalid.

Once set, a pointer can become null only when exact proposal-change, policy-incompatible, or removal evidence authorizes the same atomic transition. There is no session bypass or general nullable reset. Because carry reads only the direct predecessor's current valid authority, a decision invalidated in one generation cannot resurrect if a later proposal happens to return to an older number.

When a human reviews an invalidated stable line again, the new decision binds the current revision, uses the latest historical decision as `predecessor_decision_id`, and increments `decision_number`. A truly new line still starts at decision `1` with no predecessor. Accepting the new source-driven proposal unchanged keeps `reason_note = null`; manual adjustments retain the existing governed reason/note rules.

## 6. Read, save, validation, and release

RMVP-05 current lines add backend-owned `confirmation_state` values:

- `CARRIED_FORWARD`
- `CHANGED`
- `NEW`
- `UNREVIEWED`
- `CONFIRMED_CURRENT`

Compatibility counts `total`, `unreviewed`, `confirmed`, and `adjusted` remain. Additive authoritative counts are `carried_forward`, `needs_review`, `changed`, `new`, and `removed`. Removed facts are historical and are not part of current total or `needs_review`. RMVP-04 command results and RMVP-05 readback use the same private business-fact removal definition; continuity rows remain decision evidence and are never used as a removal-count proxy.

Untouched carried lines are omitted from Save and manufacture no human decisions. If later edited, the ordinary preview/save path appends a direct human successor decision. RMVP-06 and RMVP-07 accept a current decision only through direct revision binding or exact carry evidence. Validation, approval, and release snapshot the current successor revision and quantity, not stale predecessor membership. Changed, new, or unreviewed lines without valid authority block release; carried lines count as valid authority.

The existing released boundary is unchanged:

```text
RELEASED_FOR_PURCHASE_HANDOFF + upstream OUTDATED
→ DOWNSTREAM_CORRECTION_REQUIRED
```

No rematerialization, carry, invalidation, release mutation, or downstream mutation occurs there.

## 7. Application presentation

React renders backend state and never matches identities, compares quantity, resolves policy, validates continuity, or derives counts. After a successful correction with complete result counts, Need Generation shows:

```text
Nhu cầu đã được cập nhật. {needs_review_count} dòng cần rà soát; {carried_forward_count} xác nhận trước đó được giữ nguyên.
```

Initial creation remains `Đã tạo nhu cầu.` The Confirmed Need workbench offers authoritative state filtering and quiet row labels `Giữ nguyên`, `Cần rà soát`, `Mới`, and `Đã lưu` without adding another workflow ceremony.

## 8. Security and rollback

The continuity relation is private, forced-RLS persistence. Only the bounded materialization runtime can insert; bounded Need Generation and Confirmed Need review runtimes can read for authoritative processing. Browser, `anon`, `service_role`, generic retired runtimes, and public schemas receive no table write or public helper access. The private policy-compatibility predicate is owned by the materialization runtime with empty `search_path`; it is callable only by the exact internal runtimes needed by the atomic command.

Rollback is a normal forward migration: remove additive read fields/UI presentation only after consumers are reverted, restore the prior function definitions, and remove the continuity relation only when no deployed history depends on it. Existing human decisions, source revisions, approvals, releases, events, receipts, and audit evidence are never deleted as rollback cleanup.
