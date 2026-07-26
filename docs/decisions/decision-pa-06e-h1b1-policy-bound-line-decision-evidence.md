# Decision PA-06E-H1B1 — Policy-Bound Confirmed Need Line Decision Evidence

**Status:** H1B1-P01 through H1B1-P12 approved by the product owner as corrected on 2026-07-26; H1B1 SQL and H1B2 remain separately unauthorized

**Issue:** [#151](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/151)

**Exact documentation baseline:** `0ba89ff8c3434979eb3e8897a6bcf9bb2171c51f`

**Evidence inventory:** [Phase 0 recommendation registry](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/151#issuecomment-5080872730)

**Product approval and corrections:** [Issue #151 approval comment](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/151#issuecomment-5081145875)

**Architecture contract:** [PA-06E-H1B1 — Policy-Bound Confirmed Need Line Decision](../architecture/pa-06e-h1b1-policy-bound-line-decision-contract.md)

**Future persistence task:** [TASK-PA-06E-H1B1 — Policy-Bound Line Decision Persistence](../implementation-tasks/TASK-PA-06E-H1B1-policy-bound-line-decision-persistence.md)

## 1. Decision outcome

The approved first slice adds one append-only `ConfirmedNeedLineDecision` evidence child inside the existing Confirmed Need aggregate. It does not add a new aggregate, generic decision framework, workflow engine, API, read model, writer, or application path.

The approved authority path is:

```text
H0C current Draft line revision
→ H1A exact eligible Planning policy revision
→ H1B2 explicit Planning decision
→ append-only ConfirmedNeedLineDecision
→ stable-line current-decision pointer
→ later batch approval/release
```

H1B1 provides private structure only. H1B2 is the first task allowed to append a decision or advance the pointer.

## 2. OPS_SYSTEM_MAP placement

| Layer               | Approved H1B1 decision                                                                                                                                                             |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Mission             | Preserve explainable Planning authority without rewriting prior calculated, decision, approval, or downstream evidence.                                                          |
| Business Capability | Record the exact line quantity Planning accepted or adjusted, the exact policy that governed it, and every later replacement decision.                                            |
| Business Domain     | Planning owns decision meaning. Source owners own source corrections. Procurement consumes only later approved/released Planning facts.                                           |
| Business Object     | Existing Confirmed Need aggregate plus append-only `ConfirmedNeedLineDecision`.                                                                                                    |
| Business Contract   | This registry and the focused H1B1 architecture contract.                                                                                                                         |
| Command / Event     | None in H1B1; future H1B2 owns command, receipt, event, and audit execution.                                                                                                       |
| Read Model          | None in H1B1; future H1B2 owns authorized review/readback.                                                                                                                        |
| Application         | None in H1B1.                                                                                                                                                                     |
| Technology          | Future one private relation, one nullable line pointer, typed keys, immutable guards, mandatory deferred final-state integrity, forced RLS, zero policies, and no positive grants. |

## 3. Canonical H1B1 decision registry

### H1B1-P01 — Business object and grain

**Question:** What object records authoritative line decisions, and at what grain?

**Evidence:** H0B1b already gives one stable operational line an exact typed identity and gives each revision an immutable quantity/source state. H0C creates proposals only.

**Alternatives:** Batch-only evidence; contribution-grain decisions; a generic or polymorphic decision aggregate; UI-row authority.

**Approved direction:** `ConfirmedNeedLineDecision` is one append-only evidence child inside the existing Confirmed Need aggregate. One row concerns one exact stable line and one exact line revision. The batch remains the aggregate/version boundary.

**Accepted consequence:** One batch command may append multiple decisions while every line retains independently inspectable authority and history.

**Excluded behavior:** No contribution authority, generic Quantity Decision, Planning Quantity Confirmation root, JSON target, free-text object, public override row, or UI-owned state.

**Future impact:** Exactly one new private decision relation is sufficient.

### H1B1-P02 — Decision-kind vocabulary

**Question:** Which first-slice business kinds are valid, and does correction need another kind?

**Evidence:** Unchanged acceptance must be explicit without an identical successor revision. Adjusted confirmation must bind the real successor revision. Correction is append-only replacement evidence.

**Alternatives:** Generic `CONFIRMED`; mutable status; separate correction/cancellation kinds.

**Approved direction:** The exact vocabulary is:

```text
UNCHANGED_PROPOSAL_ACCEPTED
ADJUSTED_QUANTITY_CONFIRMED
```

A replacement keeps the kind that describes its replacement business result. Predecessor linkage identifies correction. There is no third correction kind and no status column.

**Accepted consequence:** Adjustment history is the adjusted-kind subset; replacement history is the predecessor chain.

**Excluded behavior:** No generic confirmed/overridden kind, workflow status, cancellation kind, or equality-based inference.

**Future impact:** One closed CHECK vocabulary.

### H1B1-P03 — Revision binding

**Question:** Which line revision does the decision bind?

**Evidence:** H0B1b revisions are immutable and have one current revision. Quantity change already uses normal revision succession.

**Alternatives:** Bind only the stable line; bind the pre-adjustment revision; create an identical successor for unchanged acceptance; edit a prior revision.

**Approved direction:** A current decision binds the exact line revision that is current at transaction end. Unchanged acceptance binds the already-current revision and creates no revision. Adjusted confirmation binds exactly one direct successor revision created and made current in the same H1B2 transaction.

**Accepted consequence:** The decision supplies missing human/policy authority; revision succession remains quantity/source history.

**Excluded behavior:** No identical unchanged successor, in-place quantity edit, decision on a superseded revision, or source correction disguised as a Planning adjustment.

**Future impact:** Typed revision ownership and deferred current-revision agreement are mandatory.

### H1B1-P04 — Planning-policy binding

**Question:** Which H1A policy evidence is mandatory?

**Evidence:** H1A provides immutable exact-Unit policy roots/revisions, half-open effectivity, and no fallback or conversion.

**Alternatives:** Store step only; store root only; copy policy payload; resolve by transaction date; allow fallback.

**Approved direction:** Store non-null:

```text
planning_quantity_policy_id
planning_quantity_policy_revision_id
unit_id
```

Use the H1A exact-owner composite FK. Do not copy revision number, step, dates, or lifecycle. At transaction end the bound policy revision must be the sole `ACTIVE` or historically `RETIRED` revision eligible for the exact Unit and service date. The confirmed quantity must be exactly representable by its Planning step.

**Accepted consequence:** H1B1 enforces private structural/final-state integrity; H1B2 later re-resolves under lock and returns safe errors.

**Excluded behavior:** No copied step authority, policy JSON, fallback, current-date selection, implicit latest revision, epsilon, rounding, or conversion.

**Future impact:** Deferred integrity must also run when relevant H1A policy revisions change.

### H1B1-P05 — Quantity evidence

**Question:** Which before/after quantities must the decision retain?

**Evidence:** The bound adjusted successor does not by itself preserve the proposal Planning reviewed. Exact tick counts may exceed `bigint` at the approved numeric limits.

**Alternatives:** Store after only; derive everything from the successor; floating ratio; duplicate source membership.

**Approved direction:** Store non-null:

```text
theoretical_quantity_before numeric(20,6)
proposed_quantity_before    numeric(20,6)
confirmed_quantity_after    numeric(20,6)
planning_tick_count         numeric(20,0)
unit_id                     uuid
```

All values are nonnegative. Unchanged acceptance binds the existing revision and requires proposal-before equals confirmed-after. Adjusted confirmation binds the successor; theoretical-before matches its source total, proposal-before matches the direct predecessor proposal, and confirmed-after matches the successor quantity. In both cases:

```text
confirmed_quantity_after
= planning_tick_count × bound_policy_revision.planning_step
```

**Accepted consequence:** Decision intent remains auditable without duplicating contribution or policy payloads.

**Excluded behavior:** No JSON quantities, floating type, epsilon, silent rounding, normalization, conversion, or inferred proposal without typed evidence.

**Future impact:** Local checks plus deferred revision/policy/tick equality.

### H1B1-P06 — Predecessor and supersession

**Question:** How does replacement remain linear and append-only?

**Evidence:** Atlas uses immutable evidence and successor-based correction.

**Alternatives:** Update/delete prior row; point to any ancestor; separate mutable correction relation; infer chain from timestamps.

**Approved direction:** The first decision has decision number 1 and null predecessor. Every later decision names the same line's prior current decision and increments decision number by exactly one. A predecessor has at most one successor. The replacement is a complete row and becomes current atomically.

A metadata/evidence correction may bind the same current revision. A corrected quantity requires one new direct successor revision.

**Accepted consequence:** The chain retains all authority while one pointer identifies the current decision.

**Excluded behavior:** No fork, skipped predecessor, cross-line predecessor, mutable patch, delete, tombstone, or non-current replacement.

**Future impact:** Same-line predecessor FK, non-forking uniqueness, decision-number uniqueness, and deferred prior/current checks.

### H1B1-P07 — Current-decision pointer

**Question:** What pointer identifies current authority, and how may it move?

**Evidence:** H0/H1A rows have no decision authority. Multi-row H1B2 work requires transaction-end checking.

**Alternatives:** Derive maximum row; make pointer non-null during migration; clear authority after rematerialization; use immediate-only checks.

**Approved direction:** Add nullable, no-default:

```text
atlas_planning.confirmed_need_lines.current_confirmed_need_line_decision_id
```

Allowed movement is only:

```text
null → first decision
old current → direct successor decision
```

The pointer must reference a decision on the same line that binds the exact current revision, controlled Unit, eligible policy, and valid quantity evidence. Once non-null, it cannot be cleared in this slice.

**Accepted consequence:** Post-H1B2 rematerialization cannot silently erase authority. A later lifecycle must append/rebind or receive separate approval.

**Excluded behavior:** No inferred current, cross-line pointer, superseded-revision pointer, lateral jump, ancestor rollback, clear-to-null, or direct client update.

**Future impact:** Deferrable composite pointer FK, ordinary transition guard, and deferred final-state integrity on line/decision/revision/policy changes.

### H1B1-P08 — Reason and note policy

**Question:** Which governed reasons and note rules apply?

**Evidence:** Business reason must remain structured; free text is supplemental. A replacement must explain what evidence was corrected without losing the replacement business reason.

**Alternatives:** No reason for unchanged acceptance; arbitrary text; generic adjusted reason; correction or management override as business reason; lookup relation.

**Approved direction as corrected:** Every decision has one of exactly:

```text
PROPOSAL_ACCEPTED
PLANNING_STEP_ADJUSTMENT
OPERATIONAL_QUANTITY_ADJUSTMENT
OTHER
```

Rules:

- `PROPOSAL_ACCEPTED` is valid only for unchanged acceptance.
- The other three are valid only for adjusted confirmation.
- `OPERATIONAL_QUANTITY_ADJUSTMENT` and `OTHER` require a note.
- `PLANNING_STEP_ADJUSTMENT` permits an optional note.
- The first unchanged acceptance has no note.
- Every decision with a predecessor requires a correction note while retaining its business reason.
- Every present note is trimmed, nonblank Unicode text of at most 500 characters.

`DECISION_EVIDENCE_CORRECTION` and `MANAGEMENT_OVERRIDE` are excluded.

**Accepted consequence:** Analytics retain the business reason; predecessor plus correction note retains replacement intent.

**Excluded behavior:** No blank/null reason, unlimited note, free text as sole authority, source correction disguised as Planning adjustment, generic reason JSON, or reason lookup table.

**Future impact:** Local kind/reason/note checks; H1B2 returns safe field errors.

### H1B1-P09 — Actor, authority, and separation of duties

**Question:** Who is accountable for the decision, and are proxy recording or two-person rules required?

**Evidence:** Planning owns the decision. The first slice has no approved delegated-recording workflow or production role assignment.

**Alternatives:** Separate decision and recording actors; mandatory approver/confirmer separation; management override actor; one accountable actor.

**Approved direction as corrected:** Store one authoritative `decided_by_actor_id`, one `decided_at`, and database acceptance `created_at`. Future H1B2 requires the authenticated command actor to equal `decided_by_actor_id` and to satisfy the approved Planning capability and relational scope.

A replacement decision uses the same authority model. No proxy, recording, administration, or management actor is added. No first-slice separation-of-duties rule or production membership is invented.

**Accepted consequence:** Accountability is direct and testable; delegated recording remains a future explicit decision.

**Excluded behavior:** No on-behalf-of write, proxy actor, hidden manager bypass, invented membership, or mandatory two-person workflow.

**Future impact:** Restrictive actor FK and future command actor equality/authorization tests.

### H1B1-P10 — Command, receipt, event, and audit linkage

**Question:** Which command context belongs directly on the decision?

**Evidence:** Existing command receipts have unique command identity; events and audit rows already carry receipt, correlation, actor, version, and trace context.

**Alternatives:** Copy all receipt/event/audit IDs and payload/version fields; store no command link; store one stable command identity plus decision-time aggregate version.

**Approved direction:** Store `command_id` and `confirmed_need_batch_version` directly on each decision. The command ID links to the existing receipt envelope. Correlation, idempotency, receipt ID, event ID, audit ID, request payload, and broader trace remain derived from existing evidence relations.

H1B1 creates no command, receipt, event, or audit row. H1B2 owns the transactional command later.

**Accepted consequence:** Each line decision is traceable without duplicating the complete command envelope.

**Excluded behavior:** No copied event/audit payload, duplicated correlation authority, client-authored command identity, or H1B1 event emission.

**Future impact:** Restrictive command-receipt reference, line/command uniqueness, positive batch-version check, and future H1B2 evidence reconciliation.

### H1B1-P11 — Lifecycle and mutability

**Question:** What lifecycle does decision evidence require?

**Evidence:** A decision row is evidence, not a workflow object. Correction is append-only.

**Alternatives:** Mutable status lifecycle; edit/delete; cancellation; append-only immutable rows.

**Approved direction:** Decision rows are insert-only and have no status. Every business/evidence field is immutable. Delete is prohibited. Correction appends a direct successor. Historical rows remain queryable after pointer advancement.

**Accepted consequence:** No evidence is rewritten to simulate current state.

**Excluded behavior:** No update, delete, status, reopen, cancel, soft-delete, or current flag on the decision row.

**Future impact:** Ordinary immutability/delete guard and historical-chain tests.

### H1B1-P12 — Future physical and security delta

**Question:** What is the smallest implementation-ready persistence shape?

**Evidence:** H0B1b already provides typed identity/revision/source relations; H1A provides typed policy relations; one decision child and one pointer are sufficient.

**Alternatives:** Multiple decision/reason/correction tables; generic helper framework; command/API implementation in H1B1; one bounded private relation.

**Approved direction:** The future target is:

```text
+1 private relation: atlas_planning.confirmed_need_line_decisions
+1 nullable column:  confirmed_need_lines.current_confirmed_need_line_decision_id
+3 private functions: decision guard, pointer guard, deferred integrity
+6 triggers: decision guard, pointer guard, and deferred checks on
             decisions, stable lines, line revisions, and policy revisions
```

Use typed composite keys/FKs, exact decision/predecessor/policy/Unit ownership, restrictive references, non-forking lineage, pointer monotonicity, immutable rows, forced RLS, zero policies, and zero positive runtime/API grants.

H1B1 adds zero roles, capabilities, memberships, runtimes, policies, positive grants, API functions, PA-06A entries, views, writers, commands, events, or seeds.

**Accepted consequence:** H1B2 can later add one authorized transactional command without reopening the evidence model.

**Excluded behavior:** No additional relation, reason table, resolver, generic helper, extension, API, runtime grant, production writer, React, Retool, hosted action, or seed.

**Future impact:** One additive migration, bounded pgTAP suites, canonical catalog update, workflow registration, and separately approved review.

## 4. Superseded H0 proposals

This registry supersedes only the following earlier H0 uncertainties/proposals:

1. H1B1 business kind, reason, note, actor, command, pointer, and physical details are no longer pending.
2. Replacement decisions preserve their business reason; predecessor plus required correction note identifies correction.
3. `DECISION_EVIDENCE_CORRECTION` and `MANAGEMENT_OVERRIDE` are not valid first-slice reason codes.
4. There is one accountable decision actor and no proxy/recording actor or first-slice separation-of-duties rule.
5. The current-decision pointer cannot be cleared after first authority in this slice.
6. The decision stores one command identity and decision-time batch version, not copied receipt/event/audit envelopes.

Every other H0 source, materialization, correction, zero/removal/split/merge, and rollout boundary remains unchanged.

## 5. Approval and implementation gate

The product owner approved all twelve decisions as corrected on 2026-07-26.

This approval authorizes documentation only. A future H1B1 persistence issue must separately:

- name one exact `origin/main` baseline;
- complete a no-edit impact/assertion inventory;
- fix the exact migration filename and allowed files;
- verify the proposed columns, keys, functions, triggers, catalog delta, and test plans;
- preserve H0B1b, H0C/CMD-15, H1A, and PA-05D behavior; and
- remain writerless, private, seedless, and unmerged until independent review.

H1B2 remains separately unauthorized.

## 6. Current effect

This decision changes documentation only. It creates no migration, relation, column, function, trigger, test, workflow registration, role, capability, policy, grant, API, registry entry, read model, command, event, generated type, application code, Retool change, hosted action, production row, seed, credential, package, lockfile, or deployment.

Documentation rollback is a normal Git revert.