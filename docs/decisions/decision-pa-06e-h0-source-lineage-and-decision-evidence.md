# Decision PA-06E-H0 — Source Lineage and Decision Evidence

**Status:** Proposed decision set; only inherited rows marked **Approved baseline** are already settled; every H0 physical/API selection remains subject to review

**Issue:** [#115](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/115)

**Architecture contract:** [PA-06E-H0 School-Catering Persistence and Materialization](../architecture/pa-06e-h0-school-catering-persistence-and-materialization-contract.md)

**Implementation decomposition:** [TASK-PA-06E-H0](../implementation-tasks/TASK-PA-06E-H0-school-catering-persistence-materialization.md)

## 1. Context

The approved Planning contracts already define Need Generation, Theoretical Need, the existing Confirmed Need aggregate, logical `ConfirmedNeedSourceReference`, logical `ConfirmedNeedAdjustment`, validation, approval snapshots, and release. PA-06E retains that aggregate and prohibits a Planning Quantity Confirmation or generic Quantity Decision aggregate.

The merged PA-04/PA-05D physical implementation is narrower. It requires Wholesale Order, Wholesale Order line, and Wholesale Order line-revision foreign keys on the Confirmed Need batch, stable line, and revision. It contains no school, Menu, Attendance, Input Set, school-catering Need Generation, theoretical source bridge, complete line-decision child, or production Planning quantity policy. `PA-05D.v1` creates direct-wholesale pass-through quantities and must remain behaviorally unchanged.

This record separates inherited approved directions from proposed H0 physical choices and unresolved product/physical decisions. A proposed row is not a migration authorization or a canonical API-registry entry.

## 2. Decision records

| ID         | Decision                             | Alternatives considered                                                                               | Selected direction or retained baseline                                                                                              | Rationale and consequence                                                                                     | Status                                                                                 |
| ---------- | ------------------------------------ | ----------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| PA06EH0-01 | Business aggregate                   | New Planning confirmation aggregate; generic Quantity Decision; retain Confirmed Need                 | Retain `ConfirmedNeedBatch`, stable line, line revision, logical source/adjustment children, and approval snapshots                  | Avoids duplicate lifecycle and keeps Planning ownership explicit                                              | **Approved baseline**                                                                  |
| PA06EH0-02 | Quantity meanings                    | Collapse calculated and confirmed; infer authority from non-null value; lifecycle-qualified authority | Keep theoretical/calculated evidence separate from Planning-confirmed authority                                                      | A materialized Draft value is proposed until explicit decision evidence exists                                | **Approved baseline**                                                                  |
| PA06EH0-03 | Direct-wholesale behavior            | Rebuild PA-05D; move wholesale behind a new source hierarchy; preserve existing typed columns         | Preserve `PA-05D.v1`, including pass-through equality and public commands                                                            | H0 may alter internal inserts/constraints only to write explicit Wholesale classification                     | **Approved baseline**                                                                  |
| PA06EH0-04 | H0 sequence                          | One broad migration; H1 first with fake lineage; bounded prerequisites                                | H0A source/generation prerequisites, then H0B source/evidence generalization, then H0C materialization, then H1                      | Keeps domains, security, compatibility, and commands separately reviewable                                    | **Required sequencing baseline; exact task approvals pending**                         |
| PA06EH0-05 | Confirmed Need source-lineage design | A inline typed columns; B dedicated source child; C typed child family                                | Select Alternative A: inline typed source alternatives at batch, stable-line, and revision levels                                    | Fewest records, row-local exactly-one checks, existing wholesale joins remain; bounded to two source families | **Proposed H0 physical decision**                                                      |
| PA06EH0-06 | Source kinds                         | Free text/table names; JSON lineage; generic source registry; declared types                          | Permit only `WHOLESALE` and `NEED_GENERATION` in H0                                                                                  | Typed FKs reject fake and cross-wired lineage; future kinds require migration                                 | **Proposed H0 physical decision; unsafe alternatives prohibited by approved baseline** |
| PA06EH0-07 | Batch source semantics               | Mutate batch source to latest run; store no run; immutable origin plus revision sources               | Keep immutable origin run on the batch; derive/revalidate exact current run from current revisions                                   | Source corrections do not rewrite aggregate origin                                                            | **Proposed H0 physical decision**                                                      |
| PA06EH0-08 | Theoretical-line grain               | Aggregate by ingredient/school/date; one row per atomic source contribution                           | Persist atomic contribution lines; derive aggregate totals as read models                                                            | Enables deterministic correction and prevents broad-coincidence matching                                      | **Proposed H0 physical decision**                                                      |
| PA06EH0-09 | Stable contribution identity         | Ingredient/name/order key; generic stable-contribution aggregate; explicit predecessor                | Use typed stable Menu/Attendance/RecipeLine anchors plus `predecessor_theoretical_need_line_id` for one-to-one correction            | Ingredient and quantity may change on the same stable RecipeLine without losing identity; no new aggregate    | **Proposed H0 physical decision**                                                      |
| PA06EH0-10 | New contribution                     | Infer from missing ingredient match; explicit no-predecessor line                                     | A genuinely new atomic contribution has no predecessor and a unique typed stable-anchor set                                          | Prevents reuse of an old Confirmed Need line for a different contribution                                     | **Proposed H0 physical decision**                                                      |
| PA06EH0-11 | Removed contribution                 | Infer from absence; delete old line; zero/tombstone successor                                         | Require explicit removed theoretical successor/tombstone and preserve history; H0C rejects pending zero/removal policy               | Absence is never treated as a business decision                                                               | **Proposed representation; product release behavior pending**                          |
| PA06EH0-12 | Split/merge                          | Infer many-to-many relation; add generic graph; block                                                 | Do not add a generic graph in H0; Need Generation/H0C fail closed with typed affected references                                     | One-to-one predecessor is sufficient for the bounded slice; product rules are missing                         | **Proposed H0 boundary; split/merge product decision pending**                         |
| PA06EH0-13 | Line decision evidence               | A append-only child; B revision metadata only; C hybrid                                               | Select C: immutable quantity/source revision plus append-only `confirmed_need_line_decisions`                                        | Supports changed and unchanged decisions without redundant quantity revisions                                 | **Proposed H0 physical decision**                                                      |
| PA06EH0-14 | Current decision                     | Derive chain tip only; mutable decision row; stable-line pointer                                      | Add one nullable current-decision pointer on the stable line; decision rows remain append-only                                       | Provides enforceable current authority while retaining evidence history                                       | **Proposed H0 physical decision**                                                      |
| PA06EH0-15 | Unchanged proposal acceptance        | Infer from approval; create identical revision; explicit decision on same revision                    | Append `UNCHANGED_PROPOSAL_ACCEPTED` bound to exact revision/source/policy/actor/command; no successor revision                      | Makes human authority explicit without fake quantity history                                                  | **Approved evidence requirement; physical pointer/constraint pending review**          |
| PA06EH0-16 | Adjusted confirmation                | Update Draft revision; append decision only; successor revision plus decision                         | Create one immutable successor revision and `ADJUSTED_QUANTITY_CONFIRMED` decision atomically                                        | Preserves before/after payload and exact decision evidence                                                    | **Approved revision direction; proposed physical implementation**                      |
| PA06EH0-17 | Decision correction                  | Update/delete evidence; append superseding evidence                                                   | Append a full superseding decision, preserve prior row, advance current pointer                                                      | Evidence remains auditable; branching predecessor is rejected                                                 | **Proposed H0 physical decision; reason/authority pending**                            |
| PA06EH0-18 | Logical adjustment read              | Separate adjustment table plus decision table; infer from audit; derive from decisions                | Derive `ConfirmedNeedAdjustment` from adjusted decision rows                                                                         | Avoids duplicate sources of truth and retains unchanged acceptance separately                                 | **Proposed H0 read-model decision**                                                    |
| PA06EH0-19 | Planning quantity policy timing      | H0 production default; numeric scale; H1 prerequisite                                                 | H0 performs no Planning quantization; versioned fail-closed policy is a strict H1 prerequisite                                       | Materialization can create a non-authoritative exact proposal without approving production values             | **Proposed H0/H1 dependency decision; policy values/owner pending**                    |
| PA06EH0-20 | Initial materialization              | Client copies lines; source owner writes Confirmed Need; controlled Planning command                  | Proposed `create_confirmed_needs_from_generation` consumes one exact released run and creates Draft proposals only                   | Restores the approved calculation-to-review boundary                                                          | **Parent responsibility approved; API/implementation pending**                         |
| PA06EH0-21 | Corrected materialization            | Match by ingredient/name/order; carry prior confirmed automatically; predecessor mapping              | Reuse stable lines only through exact theoretical predecessor; create successors for source changes; new contributions get new lines | Planning must review every corrected source; no prior authority is carried silently                           | **Proposed H0 command decision; prior-proposal product choice pending**                |
| PA06EH0-22 | Removal/split/merge in H0C           | Partial materialization; silent omission; fail closed                                                 | Reject the complete command until explicit policies exist                                                                            | Prevents an incomplete current batch and preserves old history                                                | **Proposed H0 command boundary**                                                       |
| PA06EH0-23 | H0C success evidence                 | Per-line events; no receipt; one atomic result                                                        | One completed receipt, one domain event, and one audit event for the whole materialization command                                   | Matches Atlas one-action/one-command and idempotency conventions                                              | **Approved command principle; exact event payload/name pending**                       |
| PA06EH0-24 | Runtime ownership                    | Broaden PA-05D runtime; service role; dedicated runtime                                               | Propose dedicated no-login/no-inherit Planning materialization runtime                                                               | Preserves PA-05D's exact four-function least-privilege boundary                                               | **Proposed security decision; exact role/grants pending**                              |
| PA06EH0-25 | Browser access                       | Direct private table reads; service-role client; function-only boundary                               | Keep all sources and decisions private; expose reviewed functions only                                                               | Preserves PA-03 and PA-06A security boundaries                                                                | **Approved baseline**                                                                  |
| PA06EH0-26 | Migration style                      | Destructive replacement; typed-child data move; additive generalization                               | Add alternatives, classify Wholesale rows, validate constraints, then relax only wholesale-column nullability; no row deletion       | Existing wholesale rows remain valid and visible; school rows become possible                                 | **Proposed H0 migration decision**                                                     |
| PA06EH0-27 | Rollback                             | Drop school history; restore wholesale-only constraints; disable/forward-fix                          | Before use, normal unshipped revert; after use, revoke unsafe command and forward-fix additively                                     | Operational history is never deleted to simulate rollback                                                     | **Approved history principle; operational procedure pending deployment task**          |
| PA06EH0-28 | H1 gate                              | Start from synthetic fake wholesale line; start after generalized source and policy                   | Require H0A/H0B/H0C plus H1 policy and exact scope before H1                                                                         | H1 cannot claim a genuine school-catering fixture prematurely                                                 | **Required sequencing baseline**                                                       |

## 3. Selected source design in one view

```text
ConfirmedNeedBatch
├─ WHOLESALE → exact WholesaleOrder
└─ NEED_GENERATION → immutable origin NeedGenerationRun

ConfirmedNeedLine
├─ WHOLESALE → exact stable WholesaleOrderLine
└─ NEED_GENERATION → exact origin TheoreticalNeedLine

ConfirmedNeedLineRevision
├─ WHOLESALE → exact WholesaleOrderLineRevision
└─ NEED_GENERATION → exact current TheoreticalNeedLine
```

Exactly one typed branch is valid at each level. Batch/line/revision source kinds must agree. For Need Generation, the current theoretical line must be the origin or an explicit predecessor-chain successor. Theoretical-line typed source bridges, not duplicated Menu/Attendance/Recipe payloads in Confirmed Need, remain the authoritative upstream trace.

## 4. Selected decision-evidence design in one view

```text
ConfirmedNeedLineRevision
→ immutable ingredient, unit, theoretical quantity, candidate/confirmed quantity,
  exact theoretical source, and revision predecessor

ConfirmedNeedLineDecision
→ append-only decision kind, before/after, actor/time, reason,
  exact source and Planning policy, batch versions, command/receipt/event context

ConfirmedNeedLine.current_decision_id
→ nullable after materialization; exact current authoritative decision after H1 confirmation
```

`UNCHANGED_PROPOSAL_ACCEPTED` points to the existing Draft revision. `ADJUSTED_QUANTITY_CONFIRMED` points to the successor revision created by the same command. Adjustment history is the adjusted subset of the decision history.

## 5. Accepted architectural directions

These inherited directions are not reopened:

1. Retain the existing logical Confirmed Need aggregate and approval snapshots.
2. Keep theoretical/calculated quantity separate from Planning-confirmed quantity.
3. Add no Planning Quantity Confirmation or generic Quantity Decision aggregate.
4. Correct the owning source, create new calculation evidence, and require new Planning review.
5. Never silently rewrite prior approval, release, Purchase Handoff, PO, Dispatch, receipt, event, audit, or physical evidence.
6. Preserve direct-wholesale `PA-05D.v1` behavior.
7. Prohibit fake wholesale lineage, free-text polymorphic IDs, caller-authored object names, and unvalidated lineage JSON.
8. Keep React non-authoritative and private tables inaccessible to browser roles.
9. Require H0 before H1.

## 6. Explicit pending decisions

The following remain unresolved and must block affected implementation rather than be guessed:

- school/customer/location ownership and scope grain;
- RecipeLine versus BOMLine physical structure and correction identity;
- Menu, Attendance, readiness, and calculation-rule snapshot tables;
- whether one Need Generation/Confirmed Need batch may span multiple schools, dates, or locations;
- exact removed-tombstone vocabulary and zero/release policy;
- split and merge mapping/approval policy;
- prior-confirmed proposal carry behavior;
- exact decision reason taxonomy, note thresholds, evidence-correction authority, and separation of duties;
- Planning policy scope, precedence, owner, approval, effective dates, and production values;
- cross-row constraint-trigger necessity after command checks are designed;
- exact current-decision composite constraint arrangement;
- H0C function/capability/contract version/event/error names and canonical registry treatment;
- callable actor classes and exact school/date relational scope;
- runtime-role name, grants, timeouts, maximum line count, retry rules, and failed-receipt policy;
- deployment, production inventory/backfill, reconciliation, cutover, and rollback rehearsal.

## 7. Consequences

The proposed design is smaller than a typed source child hierarchy, but it still requires multiple bounded prerequisite migrations before H0B. It preserves current wholesale rows and commands while making school-catering source identity typed and explicit. It makes unchanged human acceptance independently auditable and prevents a numeric Draft value from becoming authority by implication.

H0C can exist without a production Planning step because it creates proposals only. H1 cannot: policy resolution, exact scope, read/preview/confirm APIs, and decision evidence must all be present and fail closed.

## 8. Security, migration, and rollback effect

This record changes documentation only. It adds no SQL, migration, function, role, grant, RLS policy, registry entry, generated type, React code, Retool change, hosted Supabase change, production data, credential, or deployment.

Documentation rollback is a normal Git revert. No live database or operational rollback applies.
