# PA-06E — Confirmed Need Review, Adjustment, Revision, and Source-Correction Contract

**Status:** Proposed architecture contract; documentation only; product and architecture review required

**Scope:** School-catering Confirmed Need review and correction; no executable behavior

**Authority:** Approved Atlas contracts, merged migrations and tests, merged PA-06D findings, and the product decisions stated in the PA-06E task brief

**Related decision:** [Decision PA-06E — Confirmed Need Source Correction](../decisions/decision-pa-06e-confirmed-need-source-correction.md)

**Implementation boundary:** [TASK-PA-06E — Confirmed Need Revision Contract](../implementation-tasks/TASK-PA-06E-confirmed-need-revision-contract.md)

## 1. Executive decision

Atlas will reuse the existing Planning-owned Confirmed Need **business aggregate**: `ConfirmedNeedBatch`, stable `ConfirmedNeedLine`, versioned `ConfirmedNeedLineRevision`, logical `ConfirmedNeedSourceReference`, logical `ConfirmedNeedAdjustment`, and approval snapshots.

```text
Versioned Recipe/BOM/Menu/Attendance source
→ immutable Need Generation calculated result
→ Planning materialization boundary
→ Draft Confirmed Need line revision
   ├─ theoretical_quantity
   └─ confirmed_quantity
→ Planning line confirmation evidence
→ complete-batch validation
→ exact batch approval snapshot
→ batch release
→ CMD-03 creates Purchase Handoff
```

No separate Planning Quantity Confirmation root, generic Quantity Decision aggregate, draft Purchase Handoff, editable pre-CMD-03 Purchase Handoff, or cross-domain workflow object is required.

The retained logical model supplies or requires:

- one stable line identity across revisions;
- exact theoretical and confirmed quantity fields on each line revision;
- governed source-reference and predecessor identity;
- one current revision and retained superseded revisions;
- batch version and lifecycle;
- line-level adjustment/decision evidence;
- immutable approval snapshots and snapshot lines;
- separate validation, approval, and release evidence; and
- the exact released snapshot that CMD-03 can consume.

The PA-06D recommendation to add a separate Quantity Decision was explicitly pending. The approved PA-06E product direction resolves that recommendation by keeping the Planning decision in the existing Confirmed Need revision and decision evidence.

### 1.1 Logical reuse is not current physical readiness

The merged PA-04 supplier-direct physical implementation is bounded to direct wholesale. It currently requires:

```text
confirmed_need_batches.wholesale_order_id
confirmed_need_lines.wholesale_order_line_id
confirmed_need_line_revisions.wholesale_order_line_revision_id
```

It does not contain the PA-02 candidate `confirmed_need_adjustments` table, a physical `ConfirmedNeedSourceReference`, Need Generation tables, or school-catering Recipe/Menu/Attendance source relations. `created_by_actor_id`, `command_id`, approval actor/time, and approval snapshots do not supply complete line-level Planning decision evidence.

Therefore the current database cannot persist a real school-catering Need Generation result or even the proposed synthetic school/date/calculation line without either fake wholesale lineage or a separately approved schema generalization. Fake wholesale orders, fake wholesale lines, and fake wholesale revisions are prohibited.

This distinction reconciles the governing sources:

| Layer                              | PA-06E conclusion                                                                                                                                                     |
| ---------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Approved business contract         | Retain the existing Confirmed Need aggregate, `ConfirmedNeedSourceReference`, `ConfirmedNeedAdjustment`, validation lifecycle, and materialization command semantics. |
| PA-02 physical design              | Use stable lines, exact revisions, typed source bridges, append-only decision evidence, and immutable approval snapshots.                                             |
| Merged PA-04/PA-05D implementation | Direct-wholesale only; all three required Confirmed Need source FKs point to wholesale objects and the bounded command creates pass-through released facts.           |
| PA-06E future school-catering work | Requires PA-06E-H0 persistence/source generalization and materialization design before PA-06E-H1 read/preview/confirm can be implemented.                             |

### 1.2 PA-06E-H0 persistence prerequisite

[Decision PA-06E-H0B1](../decisions/decision-pa-06e-h0b1-confirmed-need-identity-membership.md) closes the H0B1 source-reference alternatives. Atlas reuses the existing batch/stable-line/immutable-revision aggregate with exact `WHOLESALE` or `NEED_GENERATION` source families and adds one revision-owned contribution relation only.

School-catering stable identity is exactly `batch + service date + customer + School + delivery location + Ingredient + controlled Unit`. Calculation-source IDs and authorization scope are excluded. Every immutable school-catering revision binds one exact released Need Generation source and a nonempty every-and-only membership of `ACTIVE` atomic Theoretical Need lines. Source Unit equals controlled Unit, controlled contribution quantity equals source theoretical quantity, and revision theoretical quantity is their exact PostgreSQL numeric sum. Existing `confirmed_quantity` remains a non-authoritative Draft proposal until later decision evidence.

H0B1b must implement this private typed model, the exact deferred guards `confirmed_need_current_source_consistency` and `confirmed_need_revision_membership_total`, and unchanged PA-05D compatibility. It must not use polymorphic free-text IDs, caller-authored table names, generic unvalidated JSON lineage, fake Wholesale records, a second aggregate, conversion, a decision/policy structure, or a compatibility view.

### 1.3 Direct-wholesale compatibility

This contract does not change the PA-05D direct-wholesale path. In that bounded path:

```text
theoretical_quantity
= confirmed_quantity
= released wholesale quantity
```

That equality is a direct-source pass-through rule, not a school-catering rule.

## 2. OPS_SYSTEM_MAP placement

| Layer               | PA-06E placement                                                                                                                                                                            |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Mission             | Deliver explainable school-catering quantities without rewriting a prior Planning decision or downstream commitment.                                                                        |
| Business capability | Review calculated requirements, confirm operational need, approve/release a batch, and handle source corrections.                                                                           |
| Business domain     | Planning owns Confirmed Need; Recipe and Admin own corrected source facts; Procurement consumes only released Planning facts.                                                               |
| Business object     | Existing logical `ConfirmedNeedBatch`, stable `ConfirmedNeedLine`, `ConfirmedNeedLineRevision`, `ConfirmedNeedSourceReference`, `ConfirmedNeedAdjustment`, and approval snapshot.           |
| Business contract   | This contract plus Need Generation, Confirmed Need, Purchase Handoff, PA-01 through PA-05D, and PA-06D.                                                                                     |
| Command/event       | Materialize, preview, confirm quantities, validate, approve, release, and reopen commands with domain events and audit.                                                                     |
| Read model          | One authorized Confirmed Need review/readback surface.                                                                                                                                      |
| Application         | Future Vietnamese-first Requirement Quantity Review workbench; no UI is implemented here.                                                                                                   |
| Technology          | H0B1b must first generalize the Wholesale-only PostgreSQL source lineage and add revision membership; H1 later adds decision evidence. Future PostgreSQL commands own arithmetic, validation, versions, revisions, events, and audit. |

## 3. Authority model and business meanings

### 3.1 Calculated Requirement

A Calculated Requirement is a derived and reproducible result from an exact set of versioned facts, including as applicable:

- service date;
- school/customer and delivery scope;
- attendance or meal count;
- Weekly Menu and menu line;
- dish;
- Recipe, Recipe Version, and RecipeLine/BOMLine revision;
- Ingredient and exact source Unit; H0B1 uses no conversion revision;
- applicable calculation and source rules; and
- the Planning input and Need Generation run versions.

It is not directly edited. A correction changes a source fact or rule and creates a new calculation result.

### 3.2 Need Generation materialization responsibility

The approved parent command `CreateConfirmedNeedsFromGeneration` supplies the missing business boundary between calculation and review. The proposed repository-style API name is `create_confirmed_needs_from_generation`; the exact name remains noncanonical until H0 approval.

```text
Recipe/BOM/Menu/Attendance owner
→ versions its own source fact

Need Generation
→ produces a new immutable calculated result

Planning materialization boundary
→ creates or refreshes a Draft Confirmed Need batch/line revision
→ records governed ConfirmedNeedSourceReference evidence
→ sets theoretical_quantity
→ writes a clearly non-authoritative proposed confirmed_quantity

Planning operator
→ reviews and explicitly confirms the quantity
```

The source owner never writes a Planning-confirmed decision. For a corrected calculation, the same materialization boundary identifies affected stable source contributions, preserves removed/replaced contributions historically, and creates the required successor Draft revisions or explicit new stable lines. It never silently overwrites a current, approved, or released payload.

This capability is required for a complete production school-catering path. It belongs to the H0 persistence/materialization prerequisite and is not part of the H1 read/preview/confirm implementation. An H1 synthetic test fixture may provision one starting line only after the H0-generalized schema exists; it may not satisfy required FKs with fake wholesale records.

### 3.3 Theoretical Quantity

`theoretical_quantity` is the exact Calculated Requirement recorded on one Confirmed Need line revision.

It must bind to one exact calculation revision and its complete source-revision set. A later source correction produces a new calculation revision and a new Confirmed Need line revision; it never overwrites the old theoretical quantity.

PostgreSQL storage capacity such as `numeric(20,6)` does not define the calculation method, Planning step, or operator display precision.

### 3.4 Proposed Confirmed Quantity

A system-created `DRAFT` revision may carry a candidate value for review. Until Planning records a decision, the authorized read and UI must identify it as `proposed_confirmed_quantity`, even if the physical revision field is named `confirmed_quantity`.

The presence of a number in a Draft revision does not by itself make that number a Planning-confirmed business fact or downstream authority.

### 3.5 Confirmed Quantity

Confirmed Quantity is the value Planning has reviewed and authorized on an exact current Confirmed Need line revision.

It may equal or differ from the theoretical quantity. The Planning decision binds:

- stable line ID and current line-revision ID;
- theoretical before value;
- prior confirmed/proposed before value;
- confirmed after value;
- unit and effective Planning rule-set version;
- calculation/source revision IDs;
- reason code;
- reason note when required by the reason policy;
- actor and time;
- batch and aggregate versions; and
- command, correlation, event, and audit IDs.

If the value differs from theoretical quantity, a line-level reason code is mandatory. The effective reason policy decides whether a note is also mandatory. The normal command envelope still carries an action-level reason under existing Atlas conventions.

### 3.6 Line-level Planning decision evidence gap

`ConfirmedNeedAdjustment` is an existing logical child business object, not a new aggregate root. PA-02 proposes append-only `confirmed_need_adjustments`, but the merged PA-04 schema did not create that table or another complete decision-evidence child.

The current `confirmed_need_line_revisions.created_by_actor_id` identifies who created a revision; it does not prove who reviewed or accepted a materialized proposal. `command_id` identifies an originating command; it does not by itself record reason, before/after intent, rule version, source set, or explicit unchanged acceptance. Approval snapshots prove a batch approval and exact approved quantities; they do not replace line-level decision evidence.

H0 must choose a bounded physical direction:

| Alternative                                      | Persistence direction                                                                                                                                               | Assessment                                                                                                                                                                          |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| A — append-only adjustment/decision child        | Persist actor/time, reason, before/after, unit, exact revision, rule/source versions, batch version, command, and acceptance kind in child evidence.                | Strongest explicit trace and supports unchanged acceptance; exact use of the logical adjustment name versus a bounded decision-evidence child remains pending.                      |
| B — bounded metadata on every successor revision | Put decision metadata on the quantity-bearing revision.                                                                                                             | Fewer joins, but cannot represent unchanged acceptance without a redundant identical successor or nullable semantics.                                                               |
| C — hybrid                                       | Revision holds authoritative quantities plus source/rule binding; append-only child evidence holds actor/time, reason, before/after, command, and acceptance trace. | Recommended pending H0 implementation review; smallest model that preserves explicit decisions, immutable payload, unchanged acceptance, replay, and audit without a new aggregate. |

When Planning accepts an unchanged system proposal:

```text
current Draft revision remains the quantity-bearing revision
confirm_need_quantities
→ appends line decision evidence
→ binds the exact revision, batch version, rule version and source revision set
→ records actor/time and explicit UNCHANGED_PROPOSAL_ACCEPTED intent
→ increments the batch version once
```

No successor quantity revision is required because no quantity, item, unit, source, or policy payload changed. The append-only decision evidence is what converts the proposal into an authoritative Planning decision. Exact evidence naming and reason requirements remain pending H0/H1 implementation review.

### 3.7 Released Confirmed Quantity

Released Confirmed Quantity is the exact confirmed value in the immutable approved snapshot that the batch release identifies for Purchase Handoff.

Procurement does not consume a mutable latest calculation, a browser proposal, or an unapproved current line. CMD-03 consumes only the exact released approval snapshot and line-revision set.

### 3.8 Lifecycle-qualified authority

| Line/batch state                               | Meaning of the quantity value                   | Downstream authority                 |
| ---------------------------------------------- | ----------------------------------------------- | ------------------------------------ |
| System-created Draft                           | Proposed value awaiting Planning review         | None                                 |
| Decision-bound current Draft/Reopened revision | Planning-reviewed value awaiting batch approval | None                                 |
| Approved snapshot line                         | Exact batch-approved confirmed quantity         | Approval evidence only until release |
| Released snapshot line                         | Released Confirmed Quantity                     | Eligible source for CMD-03           |
| Superseded revision                            | Historical prior calculation/decision           | Historical references only           |

## 4. Existing lifecycle and minimum revision invariants

The existing batch lifecycle remains:

```text
DRAFT_REVIEW
→ VALIDATED
→ APPROVED
→ RELEASED_FOR_PURCHASE_HANDOFF

APPROVED or RELEASED_FOR_PURCHASE_HANDOFF
→ REOPENED
→ VALIDATED after corrected materialization/review
```

The existing line-revision lifecycle remains:

```text
DRAFT
→ APPROVED
→ RELEASED
→ SUPERSEDED
```

PA-06E does not add a status.

The approved lifecycle requires a validation transition. The proposed `validate_confirmed_needs` command therefore remains separate:

1. It accepts an exact `DRAFT_REVIEW` or `REOPENED` batch version and the complete current line set.
2. It locks and authoritatively rereads the batch, current revisions, governed source references, line decision evidence, policies, and issues.
3. Success records validation evidence, emits `ConfirmedNeedsValidated`, increments the batch version once, and transitions the batch to `VALIDATED`.
4. Failure leaves the batch unapproved in its current working state, returns and persists governed blocking/warning issue evidence as approved later, and emits `ConfirmedNeedValidationFailed` under the parent contract. Exact failed-command receipt/event atomicity remains an H0/later-command design detail.
5. Any later materialization or confirmation that changes the validated version/line set invalidates that validation and returns the batch to the appropriate `DRAFT_REVIEW` or correction `REOPENED` working state.
6. Approval accepts only the exact validated batch version and current line set, then rechecks critical authorization, source, policy, issue, and concurrency invariants under locks.

Validation is outside H1. Keeping `VALIDATED` while omitting its command would conflict with the approved parent contract; PA-06E does not do so.

The minimum invariants are:

1. Stable Confirmed Need line identity survives revisions of the same source contribution.
2. Every line revision has a positive revision number unique within its stable line.
3. Only one current revision exists per stable line.
4. Every noninitial revision references its direct predecessor.
5. Creating a successor may atomically change only the prior current revision's controlled lifecycle metadata: `is_current` from true to false and `revision_status` to `SUPERSEDED`.
6. Revision payload is immutable after creation: theoretical quantity, confirmed quantity, ingredient, unit, source/calculation reference, predecessor, created actor/time, and originating command never change.
7. Theoretical quantity binds to one exact calculation/source revision.
8. Confirmed quantity binds to one exact Planning decision before it can be approved.
9. A changed theoretical quantity always requires Planning review, even when a prior confirmed quantity is proposed unchanged.
10. A confirmed quantity different from theoretical requires line-level reason evidence.
11. Every material persisted Planning quantity change creates a successor revision; browser keystrokes do not.
12. One line-level confirmation command increments the owning batch version exactly once, regardless of how many lines change.
13. Validation binds one exact batch version and complete current line/source/decision set.
14. Approval requires that exact validated version and line set and creates a new immutable approval snapshot.
15. Release binds one exact approval snapshot; it does not rebuild the line set.
16. CMD-03 consumes only that released snapshot and rejects stale, reopened, mismatched, or incomplete lineage.
17. Approval snapshots, snapshot lines, release evidence, receipts, domain events, audit events, and downstream references are fully immutable.
18. Direct-wholesale PA-05D continues to require pass-through equality in its bounded `PA-05D.v1` implementation.

The old line revision remains historically and downstream traceable after lifecycle metadata marks it superseded. Snapshot and downstream foreign keys continue to identify that exact revision; current-work queries may filter on current/status metadata, but history queries must not.

For school catering, stable identity is the exact operational tuple selected by H0B1a, not source-contribution identity. A source-only correction may produce a successor revision on the same stable line only when batch, service date, customer, School, delivery location, Ingredient, and controlled Unit all remain identical. An Ingredient or any other tuple-member correction selects or creates another stable line while predecessor-linked atomic contributions preserve source continuity. Prior revisions and memberships remain historical. Split, merge, removal, and zero-release policy remain explicit and are never inferred from missing rows. Direct Wholesale retains its singular source-line identity.

## 5. Planning adjustment strategy

### 5.1 Alternatives

| Alternative                                                  | Behavior                                                                                      | Strength                                                                              | Cost/risk                                                                                                                                |
| ------------------------------------------------------------ | --------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| A — update current Draft revision                            | A controlled command updates the current Draft row before approval.                           | Small physical write surface.                                                         | Weakens immutable before/after lineage and conflicts with the PA-06E rule that a prior persisted revision never receives new quantities. |
| B — revision for every reviewed change                       | Every material Planning change creates a successor, including before approval.                | Strong predecessor history and concurrency identity.                                  | Creates noise if interpreted as every keystroke or transient browser edit.                                                               |
| C — local Draft, backend preview, one persisted confirmation | Browser edits remain local; backend previews; confirmation persists the authoritative result. | Strong WYSIWYG, audit, concurrency, and usable interaction without keystroke history. | Requires a dedicated preview and clear stale handling.                                                                                   |

### 5.2 Recommendation

Use Alternative C for interaction and Alternative B only at material persistence boundaries:

1. Browser input is not a domain revision.
2. Backend preview normalizes and validates without persistence.
3. Confirmation binds the exact preview.
4. If the confirmed value, source binding, unit, or applicable rule differs from the current revision, confirmation creates one successor revision and changes only the prior revision's controlled current/status metadata.
5. If Planning accepts an unchanged system proposal, the command appends explicit line decision evidence bound to the exact current Draft revision, batch/rule/source versions, actor/time, and command without creating an identical quantity revision.
6. Every command still appends its receipt, event, and audit evidence atomically.

This preserves every material business decision, not every keystroke.

## 6. Line review and batch authority

The default and recommended authority is:

```text
line-level review
+ complete-batch validation
+ batch-level approval and release
```

- Planning reviews theoretical, proposed, and confirmed values at line level.
- One invalid, stale, unreviewed, or source-mismatched line blocks complete-batch validation and approval.
- Partial approval and partial release are not allowed without separate business evidence and a new contract.
- A batch may contain different positive revision numbers because revision numbers are local to each stable line.
- A batch may not contain a noncurrent revision, two current revisions for one line, or revisions from incompatible source/calculation scopes.
- When one or more lines change, the batch version increments once.
- Unchanged lines keep their current revision IDs and are included in the next approval snapshot.
- Validation evaluates the complete current batch and produces the exact `VALIDATED` batch version required by approval.
- Each new approval snapshot creates one immutable snapshot line per included stable line and names the exact selected line revision.
- Approval does not create Purchase Handoff.
- Release names the exact approval snapshot but still does not create Purchase Handoff.
- CMD-03 creates Purchase Handoff from the released snapshot in a separate transaction and command identity.

Validation, approval, and release remain separate transitions. Validation answers whether the complete current batch satisfies governed rules; approval answers whether Planning accepts that exact validated batch; release answers whether that exact approval is authorized for downstream handoff. H1 implements none of these transitions.

## 7. Source-correction contract

The following table answers the required correction questions by column:

1. source object/revision;
2. recalculation required;
3. new calculation revision;
4. new Confirmed Need revision behavior;
5. prior confirmed quantity as starting proposal;
6. mandatory Planning review;
7. prior approval stale;
8. reopening requirement;
9. downstream blocking; and
10. audit/lineage.

| Correction                   | 1. Source object/revision                                                                          | 2. Recalculate?                                                                                   | 3. New calculation revision?                                                                    | 4. Confirmed Need revision                                                                                                 | 5. Prior confirmed proposal?                                                            | 6. Review?                   | 7. Approval stale? | 8. Reopen?        | 9. Downstream block                                                              | 10. Required lineage                                                                           |
| ---------------------------- | -------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- | ---------------------------- | ------------------ | ----------------- | -------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| Recipe quantity              | Exact `RecipeVersion` and `RecipeLineRevision`/BOMLine revision                                    | Yes, for every affected source contribution                                                       | Yes; never replace the prior run/result                                                         | Successor on the same stable Confirmed Need line                                                                           | Allowed only as a visibly carried proposal when item, unit, and scope remain compatible | Mandatory                    | Yes after approval | Per timing window | Approval/release/CMD-03 block while source and current revision disagree         | Old/new recipe and line revisions, calculation runs, quantities, actor/reason, predecessor     |
| Recipe ingredient            | Exact RecipeVersion and stable RecipeLine plus its ingredient-changing revision                    | Yes                                                                                               | Yes                                                                                             | Ingredient identity changed: move membership between old/new operational Ingredient lines; never reuse or mutate the old line | No automatic carry when Ingredient changes                                              | Mandatory                    | Yes after approval | Per timing window | Structural mismatch blocks; no silent removal/addition                           | Old/new Ingredient, RecipeLine revisions, predecessor trace, old/new calculated contributions |
| BOM quantity                 | Exact BOM/RecipeLine revision and owning RecipeVersion                                             | Yes                                                                                               | Yes                                                                                             | Successor for each affected stable line                                                                                    | Allowed only as a labeled proposal under compatible context                             | Mandatory                    | Yes after approval | Per timing window | Same as recipe quantity                                                          | BOM predecessor, quantity/unit, calculation trace, decision evidence                           |
| BOM ingredient               | Exact BOM/RecipeLine ingredient revision and owning RecipeVersion                                  | Yes                                                                                               | Yes                                                                                             | Ingredient identity changed: explicit old/new operational lines and immutable memberships; never mutate stable identity    | No automatic carry when item changes                                                    | Mandatory                    | Yes after approval | Per timing window | No missing-row inference; corrected structural set must be complete              | Old/new BOM and Ingredient IDs, predecessor trace, split/merge/add/remove mapping, calculation trace |
| Menu dish                    | Exact Weekly Menu approved version/snapshot and stable menu-line revision                          | Yes, for the affected school/date/menu slot and downstream ingredients                            | Yes                                                                                             | Successors for affected contributions; explicit new lines for genuinely new contributions                                  | Only for same compatible ingredient/unit/school/date line                               | Mandatory                    | Yes after approval | Per timing window | Batch approval/release and CMD-03 block for affected scope                       | Menu before/after dish, approved versions, recipe resolution, affected line set                |
| Attendance or meal count     | Exact Attendance approved snapshot/version and stable attendance-line revision                     | Yes, for the affected school/date and all dependent dish/ingredient lines                         | Yes                                                                                             | Successors for every affected current line                                                                                 | Allowed as a visible proposal for the same line, never silently accepted                | Mandatory                    | Yes after approval | Per timing window | Affected batch cannot approve/release/hand off                                   | Attendance before/after counts, source signature, run, formulas, affected lines                |
| Unit conversion              | No H0B1 conversion family exists; exact H0A5b source Unit is the controlled Unit                    | A conversion requirement blocks first-slice materialization                                       | No converted result is permitted in H0/H0B1                                                   | Different Units select different operational lines; conversion-required grouping fails closed                            | No                                                                                       | Mandatory only after a separately approved future conversion contract | N/A | No converted H0B1 consequence may be persisted                                  | Exact source Unit and fail-closed evidence only                                                   |
| School/date/source mapping   | Exact WeeklyMenuLine, AttendanceLine, Planning input reference, or controlled source-line revision | Yes                                                                                               | Yes                                                                                             | Any batch/date/customer/School/destination/Ingredient/Unit change selects another stable line; source-only changes retain identity only when the complete tuple is unchanged | No automatic carry when an operational tuple member changes | Mandatory | Yes after approval | Per timing window | Cross-customer or destination mismatch blocks all downstream creation            | Old/new typed mappings, operational tuples, releases, and immutable memberships                  |
| Ingredient activation/status | Exact Ingredient version/status-change event plus referenced recipe/source revisions               | Recalculate or revalidate every affected current reference; no work for a proven unrelated change | Yes for an affected result/eligibility change; otherwise an audited no-impact result            | Successor when quantity, item validity, or blocker state changes                                                           | Only for the same reactivated item and compatible context                               | Mandatory for affected lines | Yes after approval | Per timing window | Inactive or newly invalid reference blocks; activation alone never auto-approves | Status before/after, effective time, affected-source query/result, blocker resolution          |

Source correction does not grant the source owner authority to write Confirmed Need or confirm a Planning quantity. Recipe/Admin/Planning source owners version only their own facts; Need Generation produces the new immutable calculated result; the Planning-owned or integration-authorized materialization boundary creates the Draft Confirmed Need consequence and governed source reference; Planning alone records the confirmed decision.

## 8. Timing matrix

| Window                                     | Required behavior                                                                                                                                                                                                                                   | Approval/release effect                                                                                                            | Downstream behavior                                                                                                                                                                                                                   |
| ------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1 — before Planning approval               | Create or refresh the Draft calculation and Draft Confirmed Need revision. Preserve prior revisions. Planning reviews current theoretical and proposed confirmed values.                                                                            | No approved fact is overwritten. Batch version increments when a material current revision changes.                                | Approval is blocked until every affected line has current source, decision evidence, and no blocker.                                                                                                                                  |
| 2 — after approval, before release         | Record the new calculation separately. Mark the current approval stale in the authorized read. An authorized explicit reopen is required before a corrective Confirmed Need revision can become current. Review, validation, and reapproval repeat. | Old approval snapshot remains immutable historical evidence. It is not reused for release.                                         | Release is blocked until a new approval snapshot matches the current batch version and line set.                                                                                                                                      |
| 3 — after release, before Purchase Handoff | New calculation may exist without changing the released fact. The batch must be explicitly reopened with reason before a corrective Confirmed Need revision is created/current.                                                                     | Prior released approval snapshot remains historical. Reopen makes the batch ineligible for CMD-03 until reapproved and rereleased. | CMD-03 is blocked whenever released snapshot, current line set, source revisions, or batch state disagree.                                                                                                                            |
| 4 — after Purchase Handoff exists          | Reopening may create pending Planning correction work but never changes the existing Purchase Handoff. The corrected batch cannot silently replace or cascade into Procurement.                                                                     | Original Confirmed Need release and Purchase Handoff remain immutable.                                                             | A future Planning-to-Procurement correction contract must explicitly reference the old Confirmed Need snapshot and Handoff revision and create an invalidating, superseding, additive, or cancellation result. Variants are deferred. |
| 5 — after PO or Dispatch commitment        | Planning may record the corrected source and pending review, but no Confirmed Need edit can rewrite a PO, allocation, Dispatch Requirement, load, or delivery fact.                                                                                 | Historical Planning approval/release remains explainable beside the pending correction.                                            | A later cross-domain correction contract must coordinate domain-owned revisions or compensating actions. No implementation is authorized by PA-06E.                                                                                   |

An upstream source event may make the read model stale immediately. It does not silently execute `reopen_confirmed_need_batch`; reopening is an explicit Planning command with actor, reason, expected version, source-correction reference, and downstream consequence confirmation.

## 9. Worked recipe-correction example

Initial controlled facts:

```text
Recipe revision 7
Calculated quantity: 10.234 kg

Planning review
Confirmed quantity: 10.20 kg
Reason: operational adjustment

Confirmed Need stable line: CNL-42
Confirmed Need line revision 3
theoretical_quantity: 10.234 kg
confirmed_quantity: 10.20 kg
status: RELEASED
```

Batch approval snapshot `CNS-9` names line revision 3 and approved quantity `10.20 kg`. Batch release names `CNS-9`. Any Purchase Handoff or later reference points to that immutable snapshot/revision.

Later:

```text
Recipe revision 8
Correction: ingredient quantity fixed
New calculated quantity: 10.654 kg
```

Required behavior:

1. Recipe revision 7 and RecipeLine/BOM evidence remain unchanged.
2. The old calculation result `10.234 kg` remains unchanged.
3. Confirmed Need revision 3 keeps its immutable payload: `10.234 kg` theoretical, `10.20 kg` confirmed, ingredient, unit, source/predecessor, created actor/time, and originating command.
4. Approval snapshot `CNS-9`, batch release evidence, and downstream references remain unchanged.
5. Recipe revision 8 creates a new calculation revision containing `10.654 kg` and exact source lineage.
6. The affected batch is shown as `Dữ liệu nguồn đã thay đổi` / `Cần rà soát lại`.
7. If the batch was approved or released, Planning explicitly reopens it before making a corrective revision current.
8. The materialization boundary creates a new current Draft Confirmed Need revision for stable line `CNL-42`. In the current-schema-compatible pattern, the correction command may set revision 3 `is_current = false` and `revision_status = SUPERSEDED`; no revision-3 payload changes, and the old snapshot/downstream references still identify revision 3 exactly.
9. `10.20 kg` may be shown as a prior confirmed proposal only if the current rule, item, unit, and scope remain compatible. It is not automatically accepted.
10. Planning must explicitly decide the new confirmed quantity. No value is released until review, approval, and release complete again.

The new `10.654 kg` theoretical value never silently replaces the prior `10.20 kg` confirmed/released value.

## 10. Preview and commit contract

### 10.1 Backend authority

React may check input syntax for immediate feedback. It cannot author:

- source or theoretical quantity;
- effective Planning step;
- normalized confirmed quantity;
- rounding or excessive-precision outcome;
- source-stale state;
- persisted quantity;
- revision identity;
- batch version; or
- release eligibility.

PostgreSQL preview and commit must use one canonical implementation.

### 10.2 Preview binding

Preview binds at least:

- authenticated actor and resolved scope;
- Confirmed Need batch ID and expected batch version;
- every selected stable line ID;
- every current line-revision ID;
- exact calculation revision and all material source revision IDs;
- effective Planning rule-set ID/version/effective time;
- normalized proposed quantities;
- line reason codes and notes;
- current approval/release state;
- downstream Purchase Handoff/PO/Dispatch state;
- blockers and warnings; and
- deterministic preview hash.

The hash covers canonical normalized values and ordered identities, not volatile transport fields.

### 10.3 Commit behavior

Commit must:

1. use the established Atlas command envelope and command receipt;
2. resolve actor, capability, scope, source, and current versions server-side;
3. lock in deterministic order;
4. recompute with the same canonical implementation;
5. reject stale batch version;
6. reject stale line revision;
7. reject changed calculation/source revision;
8. reject changed Planning rule version;
9. reject changed normalized quantity or reason input;
10. reject changed downstream release state;
11. reject changed preview hash;
12. create only required successor revisions and append explicit line decision/adjustment evidence, including unchanged-proposal acceptance;
13. supersede prior current revisions atomically by changing only controlled `is_current`/status metadata;
14. increment the batch version once;
15. append one domain event and one audit event;
16. store and return the exact safe result in the command receipt;
17. support exact idempotent replay; and
18. return the exact persisted current-revision snapshot.

The client discards optimistic values, renders the result, and uses the authorized review read for readback.

### 10.4 Hard WYSIWYG invariant

After approval and release are complete:

```text
Final Planning confirmation
= persisted current Confirmed Need revision
= authorized readback
= approved snapshot quantity
= Released Confirmed Quantity consumed by CMD-03
```

Before approval/release, the command result and readback must already match, but they are not downstream authority. A later source correction creates a new pending revision and does not retroactively alter the prior equality.

## 11. Planning precision and effective policy

Planning policy and storage capacity are separate.

| Context                            | Rule                                                                                                              |
| ---------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| Future deterministic local fixture | May use `0.01 kg` Planning step and show advisory `0.1 kg` purchase step, clearly labeled as fixture-only values. |
| Production                         | Must resolve an effective, immutable/versioned Planning policy by unit and approved scope.                        |
| Missing/inactive/ambiguous policy  | Preview and commit fail closed; no fallback is guessed.                                                           |
| Excess input precision             | Reject with a safe field error; never silently trim or round.                                                     |
| PostgreSQL six-decimal scale       | Storage capacity only; not operator precision or an approved step.                                                |

The exact production Planning steps, unit taxonomy, policy owner, and effective-date governance remain pending unless separately approved.

## 12. Advisory purchase consequence boundary

The Planning review may return read-only explanation:

- current confirmed need;
- effective purchase step;
- advisory proposed purchase quantity; and
- advisory rounding difference.

This is not Procurement approval, Confirmed Purchase Quantity, supplier allocation, or PO commitment. It does not persist a Procurement fact. Missing purchase policy may prevent the advisory calculation but must not cause Planning to invent a fallback. Whether purchase-policy absence blocks Planning confirmation or only the later handoff is a pending product decision; the first slice may omit the advisory field if its policy source is not yet approved.

## 13. Authorization contract

Proposed capabilities follow existing lower-case business-object/action conventions:

```text
confirmed_need_generation.materialize
confirmed_need_review.read
confirmed_need_quantities.preview
confirmed_need_quantities.confirm
confirmed_need_batch.validate
confirmed_need_batch.approve
confirmed_need_batch.release
confirmed_need_batch.reopen
```

The materialization capability belongs to H0. The seven review/lifecycle capabilities begin with `confirmed_need_review.read`; none is canonical or granted by PA-06E.

Every read, preview, and command must enforce:

- authenticated Supabase subject;
- server-side active Atlas actor mapping;
- active role membership and active capability;
- customer/school/delivery-location relational scope;
- service-date scope when an approved server-owned date-scope policy applies;
- exact Confirmed Need batch and source/calculation scope;
- no selector broadening after a denial or not-found result;
- no caller-supplied actor authority, management override, approval, status, table, or generated ID;
- no browser service-role/secret credential; and
- no browser access to private Atlas tables or reporting views.

The current physical actor-scope catalog has no general service-date scope kind. A production implementation must either use an approved server-owned assignment/effective-period rule or add a separately reviewed scope design. It must fail closed rather than treating this documentation as a database grant.

## 14. Smallest authorized review read

This read cannot be implemented for a genuine school-catering line against the current Wholesale-only PA-04 schema. H0B1b must first supply governed source/revision membership, H0C must materialize a Draft line, and H1B1 must supply line decision evidence before H1B2 exposes the read.

The review/readback surface returns one authorized batch context:

- batch ID, version, lifecycle, service scope, customer/school/location;
- calculation run/revision and material source revisions;
- ingredient and unit;
- stable line ID and current line-revision ID/number;
- theoretical quantity;
- current decision-bound confirmed quantity;
- proposed confirmed quantity where applicable;
- difference and reason requirement;
- Planning policy and rule-set version;
- approval snapshot/state and release state;
- stale-source state and changed-source references;
- downstream Purchase Handoff/PO/Dispatch state;
- blockers and warnings;
- prior revision and decision history references; and
- command/event/audit references.

It is point-in-time advisory data for review and readback. Commands still lock and re-read authoritative private tables.

## 15. Proposed command family

The approved parent materialization responsibility is represented by the separate H0 candidate `create_confirmed_needs_from_generation`. It creates no Planning decision and is not counted as one of the seven review/lifecycle functions below.

The smallest complete review/lifecycle family is seven functions:

1. `get_confirmed_need_review` — authorized batch review and post-command readback;
2. `preview_confirmed_need_confirmation` — required because user-proposed quantities need authoritative normalization, policy resolution, source-stale checks, and a deterministic hash;
3. `confirm_need_quantities` — persists material line decisions/revisions;
4. `validate_confirmed_needs` — validates the complete exact current batch and transitions it to `VALIDATED`;
5. `approve_confirmed_need_batch` — separately approves the exact validated batch version and line set;
6. `release_confirmed_need_batch` — separately releases the exact approval snapshot for CMD-03; and
7. `reopen_confirmed_need_batch` — explicitly opens correction work after approval/release.

Preview and confirmation validate line input; `validate_confirmed_needs` evaluates the complete batch; approval requires the exact validated version and rechecks critical invariants under locks. There is no separate post-command result read because `get_confirmed_need_review` supplies readback.

Materialization, confirmation, validation, approval, and release remain separate because they answer different business questions and bind different evidence. Reopen is required for the complete correction lifecycle. Only read, preview, and confirm belong to H1.

### 15.1 Dependency and API-gap map

| Sequence  | Required contract/implementation boundary                                                                                                                  | Candidate API gap                                                                                                                                                        | PA-06E authorization                                                                |
| --------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------- |
| PA-06E-H0 | School-catering Confirmed Need source-reference generalization, line decision-evidence persistence, security, and Need Generation materialization contract | `create_confirmed_needs_from_generation` plus private persistence required by the logical children                                                                       | Required prerequisite; neither contract nor implementation is authorized by this PR |
| PA-06E-H1 | One-line authorized read, backend preview, and explicit confirmation against the H0-generalized schema                                                     | `get_confirmed_need_review`, `preview_confirmed_need_confirmation`, `confirm_need_quantities`                                                                            | Proposed later slice; not authorized by this PR                                     |
| Later     | Complete-batch validation, approval, release, school-catering CMD-03, and downstream correction                                                            | `validate_confirmed_needs`, `approve_confirmed_need_batch`, `release_confirmed_need_batch`, `reopen_confirmed_need_batch`, then separately contracted CMD-03 integration | Deferred and noncanonical                                                           |

H0 precedes H1. A local H1 fixture may omit executing materialization only by provisioning a starting line in the already generalized, test-only H0 schema; it cannot run against the wholesale-only PA-04 shape or invent wholesale lineage.

## 16. Proposed API registry delta

This is a proposal only. The canonical PA-06A registry is not modified by PA-06E.

### 16.1 `create_confirmed_needs_from_generation`

- **Type / owner:** command or controlled integration boundary / Planning, consuming Need Generation output.
- **Purpose:** Materialize one exact released Need Generation result into a Draft Confirmed Need batch/line set and create governed source references and non-authoritative proposals.
- **Capability:** proposed `confirmed_need_generation.materialize`.
- **Scope:** Exact Need Generation run, service period, school/destination scope, and resulting Confirmed Need aggregate.
- **Request:** Standard command envelope, exact released generation run/version, expected target state/version when refreshing correction work, and governed materialization mode. It accepts no caller-authored source table/name, confirmed decision, status, actor, or fake wholesale identity.
- **Response:** Created/refreshed batch, stable lines, Draft revisions, exact source-reference IDs, theoretical/proposed quantities, versions, blockers, receipt/event/audit IDs, and replay classification.
- **Safe errors:** Generation not released, missing/ambiguous typed source lineage, unsupported source family, incompatible stable identity, approved/released batch not reopened, stale version, authorization, idempotency, concurrency, and safe internal errors.
- **Events/audit:** Parent event `ConfirmedNeedsCreated` for initial materialization; a separately reviewed correction/materialization event name for successor Draft revisions. Actor, run, sources, affected stable lines, before/after calculation references, and versions are audited.
- **Idempotency:** Mandatory exact replay; changed source or intent under the same key conflicts.
- **Stale behavior:** No partial materialization; refresh generation and Confirmed Need state, then submit a new exact intent.
- **Why existing functions cannot provide it:** PA-05D materializes only direct-wholesale pass-through rows and requires wholesale FKs; it cannot consume school-catering Need Generation without fake lineage.
- **First backend slice:** No. H0 must define and implement the generalized persistence boundary first; an H1 synthetic fixture may locally provision its starting line afterward.

### 16.2 `get_confirmed_need_review`

- **Type / owner:** read / Planning.
- **Purpose:** Return one authorized current review/readback context.
- **Capability:** `confirmed_need_review.read`.
- **Scope:** Exact batch plus resolved customer/school/location/service period.
- **Request:** Auth context and `confirmed_need_batch_id`; optional exact stable line IDs for a bounded subset, never an unbounded queue.
- **Response:** Section 14 shape plus `advisory_only = true`.
- **Safe errors:** validation, authentication/actor/capability/scope denial, not found, ambiguous/current-lineage conflict, safe internal read failure.
- **Events/audit/idempotency:** None; repeated reads may observe newer committed state.
- **Stale behavior:** Returns current point-in-time state and stale-source flags; it never authorizes a write.
- **Why existing functions cannot provide it:** READ-01 requires a completed wholesale trace; READ-02/03 are Evidence/Dispatch views; READ-04 is audit history and does not return current Confirmed Need lines or source/policy detail.
- **First backend slice:** Yes.

### 16.3 `preview_confirmed_need_confirmation`

- **Type / owner:** preview / Planning.
- **Purpose:** Normalize and validate proposed confirmed quantities with the same canonical logic used by commit.
- **Capability:** `confirmed_need_quantities.preview`.
- **Scope:** Exact batch, expected batch version, selected stable/current line revisions, and resolved source scope.
- **Request:** Batch/version, ordered line proposals containing stable line ID, current line-revision ID, calculation/source revision IDs, proposed quantity, reason values, and expected Planning rule-set version.
- **Response:** Exact before/proposed normalized values, differences, reason requirements, policy version, blockers/warnings, downstream state, optional advisory purchase consequence, and deterministic preview hash.
- **Safe errors:** Invalid/nonrepresentable quantity, excessive precision, missing/inactive policy, stale source/line/batch, released/downstream blocker, authorization denial, safe internal preview failure.
- **Events/audit/idempotency:** No domain mutation, receipt, event, or audit; the deterministic hash is not a command receipt.
- **Stale behavior:** Any bound identity/version/state change makes the preview unusable.
- **Why existing functions cannot provide it:** Existing reads accept no proposal and do not resolve Planning policy or compute a preview hash.
- **First backend slice:** Yes.

### 16.4 `confirm_need_quantities`

- **Type / owner:** command / Planning.
- **Purpose:** Persist the exact previewed Planning decisions and required successor line revisions.
- **Capability:** `confirmed_need_quantities.confirm`.
- **Scope:** Exact batch and line/source scope resolved under locks.
- **Request:** Standard command envelope plus batch ID/version, the complete preview-bound ordered line proposal, expected rule/source/current-line IDs, and preview hash.
- **Response:** Exact persisted batch/current-line snapshot, new batch version, created/superseded revision IDs, decision/adjustment evidence IDs, event/audit IDs, warnings/blockers, and replay classification.
- **Safe errors:** All preview errors plus preview mismatch, idempotency conflict, retryable concurrency, session expiry mapping, and safe internal command failure.
- **Events/audit:** `ConfirmedNeedQuantitiesConfirmed`; audit contains before/after quantities, source/rule versions, actor/reason, and preview hash.
- **Idempotency:** Mandatory exact replay; changed request under the same command/key fails.
- **Stale behavior:** No write; refresh `get_confirmed_need_review`, preserve safe local draft, and require new preview/review/intent.
- **Why existing functions cannot provide it:** PA-05D only creates pass-through wholesale quantities and has no school-catering manual confirmation command.
- **First backend slice:** Yes.

### 16.5 `validate_confirmed_needs`

- **Type / owner:** command / Planning.
- **Purpose:** Evaluate the complete current batch under authoritative reads/locks and transition one exact eligible version to `VALIDATED`.
- **Capability:** `confirmed_need_batch.validate`.
- **Scope:** Exact batch/service scope, all stable/current lines, source references, line decisions, effective policies, and governed issues.
- **Request:** Standard command envelope, batch ID/version, exact ordered current line-revision and decision-evidence IDs, expected source/rule versions, and acknowledged warnings where policy permits.
- **Response:** Validated batch/new version and exact validated line/source/decision set, or governed blocking/warning issue evidence; event/audit/receipt IDs and replay classification.
- **Safe errors:** Missing/unconfirmed line, source/policy mismatch, blocking issue, stale batch/line/source/decision set, authorization, idempotency/concurrency, and safe internal errors.
- **Events/audit:** `ConfirmedNeedsValidated` on success; `ConfirmedNeedValidationFailed` and governed issue evidence on a completed failed validation outcome as the later command contract defines.
- **Idempotency:** Mandatory exact replay.
- **Stale behavior:** No validation transition; refresh the review, correct/materialize/confirm affected lines, and validate a new exact version.
- **Why existing functions cannot provide it:** The approved parent contract requires a persisted `VALIDATED` transition; preview/confirmation are line-oriented and PA-05D deliberately collapses validation only for direct wholesale.
- **First backend slice:** No.

### 16.6 `approve_confirmed_need_batch`

- **Type / owner:** command / Planning.
- **Purpose:** Approve one exact validated batch version and current line-revision/decision set.
- **Capability:** `confirmed_need_batch.approve`.
- **Scope:** Exact batch/service scope and approver authority.
- **Request:** Standard envelope, exact validated batch ID/version, validated-set identity, exact ordered current line-revision/decision-evidence IDs, acknowledged warnings, and optional separation-of-duties evidence when approved later.
- **Response:** Immutable approval snapshot and snapshot-line IDs/values, batch state/version, event/audit IDs.
- **Safe errors:** Nonvalidated or changed batch, invalid/unreviewed/stale line, blocker, source/policy/decision mismatch, snapshot conflict, authorization, stale/idempotency/concurrency/internal errors.
- **Events/audit:** `ConfirmedNeedsApproved`.
- **Idempotency:** Mandatory.
- **Stale behavior:** No snapshot; refresh review and reapprove only after review.
- **Why existing functions cannot provide it:** PA-05D performs wholesale approval/release atomically and is explicitly not the generic school-catering lifecycle.
- **First backend slice:** No.

### 16.7 `release_confirmed_need_batch`

- **Type / owner:** command / Planning.
- **Purpose:** Release the exact current approval snapshot for Purchase Handoff.
- **Capability:** `confirmed_need_batch.release`.
- **Scope:** Exact batch/service scope and release authority.
- **Request:** Standard envelope, batch ID/version, approval snapshot ID/version, and expected downstream state.
- **Response:** Released batch state, exact released snapshot identity/lines, event/audit IDs.
- **Safe errors:** Nonapproved/stale/reopened batch, snapshot mismatch, stale source, existing incompatible handoff, authorization, idempotency/concurrency/internal errors.
- **Events/audit:** `ConfirmedNeedsReleasedForPurchaseHandoff`.
- **Idempotency:** Mandatory.
- **Stale behavior:** No release; refresh and require review/reapproval as appropriate.
- **Why existing functions cannot provide it:** PA-05D wholesale release is a bounded pass-through shortcut; school catering needs an explicit generic release before CMD-03.
- **First backend slice:** No.

### 16.8 `reopen_confirmed_need_batch`

- **Type / owner:** command / Planning.
- **Purpose:** Explicitly open correction work while preserving prior approval/release evidence.
- **Capability:** `confirmed_need_batch.reopen`.
- **Scope:** Exact batch/source/downstream context and correction authority.
- **Request:** Standard envelope, batch ID/version, source-correction reference, affected line/source IDs, and acknowledged downstream state.
- **Response:** Reopened batch/new version, preserved approval/release references, affected lines, blockers, and event/audit IDs.
- **Safe errors:** Invalid lifecycle, stale source/batch, existing Handoff/PO/Dispatch correction boundary unavailable, authorization, idempotency/concurrency/internal errors.
- **Events/audit:** `ConfirmedNeedsReopened`.
- **Idempotency:** Mandatory.
- **Stale behavior:** No reopen; refresh current review/downstream state.
- **Why existing functions cannot provide it:** PA-05D explicitly deferred reopening and correction.
- **First backend slice:** No.

## 17. Errors and operator recovery

`get_confirmed_need_review` is the authorized refresh named below. For ambiguous command transport, the client should first query the known command through READ-04 when possible, then refresh the review; it must not create a new intent blindly.

| Error/state                 | Anything persisted?                                                        | Preserve local Draft?        | Exact retry safe?                                                                | New review required?                             | Authorized refresh/recovery                                        |
| --------------------------- | -------------------------------------------------------------------------- | ---------------------------- | -------------------------------------------------------------------------------- | ------------------------------------------------ | ------------------------------------------------------------------ |
| Invalid quantity            | No                                                                         | Yes                          | No; correct input and create a new preview                                       | Yes                                              | Current review, then preview                                       |
| Excessive input precision   | No; never silently rounded                                                 | Yes                          | No                                                                               | Yes                                              | Current review and effective Planning step                         |
| Missing Planning rule       | No                                                                         | Yes                          | No until rule is governed                                                        | Yes                                              | Current review after rule correction                               |
| Inactive/ambiguous rule     | No                                                                         | Yes                          | No                                                                               | Yes                                              | Current review after rule correction                               |
| Missing calculation lineage | No                                                                         | Yes                          | No                                                                               | Yes                                              | Current review; owning source/calculation team resolves blocker    |
| Validation blocking issues  | Governed validation outcome/issue evidence only; no `VALIDATED` transition | Yes                          | Exact replay only for the same validation intent                                 | Yes after issues are corrected                   | Current review and issue list, then materialize/confirm/revalidate |
| Stale source revision       | No command write; corrected source/calculation may already exist           | Yes                          | No blind retry                                                                   | Yes                                              | Current review with changed-source references                      |
| Stale line revision         | No                                                                         | Yes                          | No blind retry                                                                   | Yes                                              | Current review and new preview/intent                              |
| Stale batch version         | No                                                                         | Yes                          | No blind retry                                                                   | Yes                                              | Current review and new preview/intent                              |
| Preview/hash mismatch       | No                                                                         | Yes                          | No                                                                               | Yes                                              | Current review and new preview                                     |
| Approval snapshot mismatch  | No                                                                         | Yes where relevant           | No                                                                               | Yes                                              | Current review and approval history/readback                       |
| Released batch              | No in-place confirmation                                                   | Yes                          | No                                                                               | Yes; reopen decision required                    | Current review; `reopen_confirmed_need_batch` when available       |
| Existing Purchase Handoff   | No silent Planning-to-Procurement mutation                                 | Yes                          | No                                                                               | Yes; cross-domain correction review              | Current review plus READ-04 for known Handoff                      |
| Capability denied           | No                                                                         | Yes if safe and nonsensitive | No                                                                               | Not until authority changes                      | Reauthenticate/role administration; same bounded read only         |
| Scope denied                | No                                                                         | Yes if safe                  | No                                                                               | Not in broader scope                             | Stop; do not broaden selector or query private tables              |
| Retryable concurrency       | No durable success/failure may be assumed from transport alone             | Lock Draft/intent            | Yes, only the exact frozen request when backend classifies retryable             | No if exact retry succeeds; otherwise refresh    | READ-04 command outcome then current review                        |
| Idempotency conflict        | No new mutation from conflicting request                                   | Yes                          | No                                                                               | Yes; create new intent after inspecting original | READ-04 original command plus current review                       |
| Ambiguous transport         | Unknown until reconciled                                                   | Yes; lock editing            | Only the exact frozen request after outcome cannot be resolved and policy allows | Yes before any new intent                        | READ-04 by command ID, then current review                         |
| Session expiry              | No new authenticated submission; prior transport outcome may be unknown    | Yes if nonsensitive          | No automatic retry after sign-in                                                 | Yes                                              | Reauthenticate, reconcile command, reload current review           |
| Safe internal failure       | No success may be inferred                                                 | Yes                          | Only if explicitly returned retryable; otherwise no                              | Usually yes                                      | READ-04 when command ID exists, then current review/support        |

Every safe error response must state write certainty, Draft preservation, retry rule, review requirement, and the authorized refresh action in operator-facing terms.

## 18. Corrected backend sequence

### 18.1 PA-06E-H0 — persistence/source generalization and materialization contract

H0 is the prerequisite architecture/security/migration contract. H0B1a has closed identity and membership; H0B1b/H0C remain separately authorized implementation work for:

- removing the school-catering dependency on required wholesale-only source FKs without breaking `PA-05D.v1`;
- physically representing governed school-catering source lineage through exact batch/revision release bindings and one revision-owned contribution relation;
- retaining `confirmed_quantity` as a non-authoritative Draft proposal while deferring all confirmation/adjustment evidence to H1;
- defining `create_confirmed_needs_from_generation` for initial and corrected Need Generation results;
- migration/backfill/compatibility, RLS/grants/runtime ownership, idempotency, concurrency, events/audit, and focused database tests.

PA-06E and H0B1a do not authorize H0B1b DDL or H0C commands. H0B1b must explicitly prove that direct Wholesale remains exact and that no fake Wholesale record can satisfy a school-catering path.

### 18.2 PA-06E-H1 — one-line review/preview/confirm

Only after H0's generalized persistence exists, H1 may contain exactly:

- one synthetic school/date/ingredient Confirmed Need stable line provisioned locally without wholesale lineage;
- one deterministic calculation/source revision and theoretical quantity;
- one governed source-reference set;
- one synthetic Planning actor with exact scope/capabilities;
- one effective versioned fixture Planning rule;
- one proposed confirmed quantity and one explicit decision-evidence outcome;
- `get_confirmed_need_review`;
- `preview_confirmed_need_confirmation`;
- `confirm_need_quantities`;
- exact command result and authorized readback;
- one domain event, one audit event, one command receipt, and append-only line decision evidence; and
- exact replay/stale/auth/security evidence.

H1 may omit execution of the materialization command only because its test fixture provisions this starting line against the already generalized H0 schema. It does not validate, approve, release, call or change CMD-03, create Purchase Handoff, process a production queue, approve multiple schools, apply Procurement purchase rounding, allocate suppliers, create a PO/Dispatch fact, change direct-wholesale behavior, use production data, or mutate hosted Supabase.

### 18.3 Later sequence

After H1, separate approved tasks may implement complete-batch validation, approval, release, school-catering CMD-03 integration, and downstream correction. Each remains noncanonical and unauthorized here.

## 19. Test blueprint

### 19.1 H0 persistence and materialization

- current PA-04 schema evidence proves all three required Confirmed Need source FKs are wholesale-specific;
- a school-catering source cannot be persisted with a fake wholesale order/line/revision;
- batch/revision source rows and immutable contribution memberships bind exact released generation evidence; upstream Recipe/Menu/Attendance facts remain reachable through typed Theoretical Need anchors;
- no caller-authored table name, polymorphic free-text ID, or generic unvalidated JSON lineage is accepted;
- H0B1b proves exact operational identity, current-source consistency, `ACTIVE` every-and-only membership, source-Unit-equals-controlled-Unit behavior, and exact numeric membership totals before H0C;
- `create_confirmed_needs_from_generation` later materializes exact theoretical and proposed values but creates no Planning-confirmed authority;
- a corrected released generation result produces predecessor-linked Draft successors or explicit new stable lines without changing prior payloads;
- H1 line decision evidence later records actor/time, reason, before/after, rule/source set, revision, batch version, command, and unchanged acceptance; and
- direct-wholesale PA-05D fixtures and equality assertions remain unchanged.

### 19.2 Quantity authority

- theoretical and confirmed values remain distinct;
- Draft proposal is not downstream authority;
- direct wholesale remains pass-through equal;
- manual adjustment changes confirmed but not theoretical quantity;
- recipe/BOM correction creates a new calculation/source revision;
- prior confirmed/released revision payload remains unchanged even when controlled current/status metadata later marks it superseded;
- new source revision requires a new Planning review; and
- missing/invalid Planning policy fails closed.

### 19.3 Revision history

- one current revision per stable line;
- every noninitial predecessor chain is valid;
- prior current may become `is_current = false` / `SUPERSEDED` atomically;
- no previous revision receives new quantity, item, unit, source, predecessor, creation, or command payload values;
- batch version increments once per material confirmation command;
- unchanged current lines remain in the next full approval snapshot;
- approval snapshot binds exact revisions;
- released snapshot remains immutable; and
- mixed per-line revision numbers are allowed only when each is current and source-compatible.

### 19.4 Validation, concurrency, and idempotency

- successful complete-batch validation creates the exact `VALIDATED` version and emits `ConfirmedNeedsValidated`;
- failed validation leaves the batch unapproved and records/returns governed issue evidence with `ConfirmedNeedValidationFailed` as the later command contract defines;
- approval rejects a nonvalidated or changed batch/line/decision set and rechecks critical invariants;
- stale batch, line, source, and rule versions are rejected;
- changed preview/hash is rejected;
- exact replay returns the same revision/result/event/audit IDs;
- changed request under the same command/key fails;
- ambiguous transport creates no duplicate; and
- concurrent confirmations produce one safe current-revision chain.

### 19.5 Authorization

- unauthenticated and unmapped actors are denied;
- inactive subject/actor/membership/capability is denied;
- wrong customer/school/location/date scope is denied;
- selector broadening is denied;
- browser roles cannot read or write private tables; and
- no service-role credential appears in frontend artifacts.

### 19.6 Downstream safety

- CMD-03 consumes only an exact released approval snapshot;
- stale, reopened, source-mismatched, or snapshot-mismatched Confirmed Need blocks handoff;
- existing Handoff prevents silent in-place rewrite;
- recipe correction after Handoff does not mutate Handoff;
- PO/Dispatch commitments remain unchanged; and
- direct-wholesale CMD-03 behavior and registry entry remain unchanged by the first slice.

## 20. Vietnamese terminology status

No UI is implemented. Future normal operator content follows PA-06D:

- Vietnamese decimal commas;
- `dd/mm/yyyy` dates;
- no raw enum as a primary label;
- no unexplained English identifier;
- no generic `Số lượng` when several quantity meanings are visible.

Stable concepts may continue using:

- `Nhu cầu tính toán`;
- `Nhu cầu đã xác nhận`;
- `Chênh lệch do điều chỉnh`;
- `Lý do điều chỉnh`;
- `Phiên bản`;
- `Dữ liệu nguồn đã thay đổi`; and
- `Cần rà soát lại`.

The following remain alternatives pending explicit product-owner and Vietnamese-speaking operations review:

- `Nhu cầu vận hành`;
- `Nhu cầu đề xuất xác nhận`; and
- `Số lượng đề xuất xác nhận`.

PA-06E does not mark any of the three final.

## 21. Required conclusion

1. **Business-object choice:** retain the existing logical Confirmed Need aggregate, stable lines, line revisions, source-reference/adjustment children, and snapshots; add no Planning confirmation aggregate. The merged physical schema remains wholesale-only and is not ready for school catering.
2. **Theoretical quantity:** exact calculated value bound to one reproducible calculation/source revision.
3. **Confirmed quantity:** Planning-reviewed, decision-bound value on an exact line revision; it may differ from theoretical with reason evidence.
4. **Source-correction lifecycle:** the source owner versions its fact, Need Generation creates an immutable result, the Planning materialization boundary creates a Draft consequence/source reference, Planning reviews, and an approved/released batch is explicitly reopened; nothing cascades silently.
5. **Revision strategy:** local Drafts plus backend preview; one successor per material payload change; unchanged acceptance appends decision evidence without a redundant revision; payload is immutable while controlled current/status metadata may supersede it.
6. **Batch strategy:** line review followed by complete-batch validation, exact validated-version approval, and separate release; no partial release.
7. **CMD-03 compatibility:** CMD-03 continues to consume a released exact snapshot; PA-05D direct wholesale remains unchanged. School-catering implementation must be separately contracted without silently changing `PA-05D.v1`.
8. **Proposed API:** one separate H0 materialization gap plus a seven-function review/lifecycle family; only read/preview/confirm belong in H1, and every name remains noncanonical.
9. **First backend boundary:** H0B1b must first generalize exact source lineage and revision membership with no decision evidence; H0C later materializes Draft proposals; H1 then proves one synthetic line, policy, preview, confirmation, result, readback, line evidence, event/audit/receipt, with no validation, approval, release, handoff, Procurement, or production queue.
10. **Deferred downstream work:** Handoff invalidation/supersession, allocation/PO correction, Dispatch correction, and cross-domain compensation.
11. **Vietnamese terminology:** stable terms continue; the three Planning proposal labels remain pending.
12. **Remaining product/architecture decisions:** H0B1 identity/source/membership decisions are closed. H0C command details; line decision-evidence physical shape; unchanged-acceptance reason rules; exact Planning policy/steps and owner; zero-line release behavior; prior-confirmed carry proposal; separation of duties; service-date authorization; purchase-advisory blocking; API names/capabilities; downstream correction variants; and final Vietnamese terms remain later work.

## 22. Security, migration, and rollback effect

PA-06E adds no migration, SQL, RPC, grant, RLS policy, generated type, React code, package, Retool change, Supabase project change, credential, production data, deployment, or API-registry modification.

Security remains unchanged. The contract requires future backend authorization, function-only browser access, private tables, exact scope, idempotency, concurrency, audit, and immutable history.

Documentation rollback is a normal Git revert. No database rollback or deployment rollback applies.
