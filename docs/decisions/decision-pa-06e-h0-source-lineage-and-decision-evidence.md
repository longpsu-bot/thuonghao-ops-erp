# Decision PA-06E-H0 — Source Lineage and Decision Evidence

**Status:** Historical H0 decision record; implemented H0 directions remain authoritative, while exact H1B1 decision-evidence details are superseded by the approved H1B1 registry

**Issue:** [#115](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/115)

**Architecture contract:** [PA-06E-H0 School-Catering Persistence and Materialization](../architecture/pa-06e-h0-school-catering-persistence-and-materialization-contract.md)

**Implementation decomposition:** [TASK-PA-06E-H0](../implementation-tasks/TASK-PA-06E-H0-school-catering-persistence-materialization.md)

**H1B1 superseding decision:** [Decision PA-06E-H1B1 — Policy-Bound Line Decision Evidence](decision-pa-06e-h1b1-policy-bound-line-decision-evidence.md)

## 1. Context

The approved Planning contracts already define Need Generation, Theoretical Need, the existing Confirmed Need aggregate, logical `ConfirmedNeedSourceReference`, logical `ConfirmedNeedAdjustment`, validation, approval snapshots, and release. PA-06E retains that aggregate and prohibits a Planning Quantity Confirmation or generic Quantity Decision aggregate.

The merged PA-04/PA-05D physical implementation is narrower. It requires Wholesale Order, Wholesale Order line, and Wholesale Order line-revision foreign keys on the Confirmed Need batch, stable line, and revision. It contains no school, Menu, Attendance, Input Set, school-catering Need Generation, theoretical source bridge, complete line-decision child, or production Planning quantity policy. `PA-05D.v1` creates direct-wholesale pass-through quantities and must remain behaviorally unchanged.

The retained active OPS v1 Purchase Planner provides additional business evidence: its `family_token`, `public.actual_need_overrides` primary/conflict key, and `public.purchase_assignments` grouping all use `service_date + school_id + ingredient_id`. This establishes an operational total family, not an Atlas schema. Atlas must add typed destination, controlled unit, approved scope, immutable revisions, and exact contribution membership.

This record separates inherited approved directions from proposed H0 physical choices and unresolved product/physical decisions. A proposed row is not a migration authorization or a canonical API-registry entry. Exact H1B1 decision kind, reason, actor, policy, quantity, predecessor, pointer, command, and future physical details are now governed only by the approved H1B1 registry linked above.

## 2. Decision records

| ID         | Decision                              | Alternatives considered                                                                               | Selected direction or retained baseline                                                                                                                            | Rationale and consequence                                                                                  | Status                                                                     |
| ---------- | ------------------------------------- | ----------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| PA06EH0-01 | Business aggregate                    | New Planning confirmation aggregate; generic Quantity Decision; retain Confirmed Need                 | Retain `ConfirmedNeedBatch`, stable line, line revision, logical source/adjustment children, and approval snapshots                                                | Avoids duplicate lifecycle and keeps Planning ownership explicit                                           | **Approved baseline**                                                      |
| PA06EH0-02 | Quantity meanings                     | Collapse calculated and confirmed; infer authority from non-null value; lifecycle-qualified authority | Keep theoretical/calculated evidence separate from Planning-confirmed authority                                                                                    | A materialized Draft value is proposed until explicit decision evidence exists                             | **Approved baseline**                                                      |
| PA06EH0-03 | Direct-wholesale behavior             | Rebuild PA-05D; move wholesale behind a new source hierarchy; preserve existing typed columns         | Preserve `PA-05D.v1`, including pass-through equality and public commands                                                                                          | H0 may alter internal inserts/constraints only to write explicit Wholesale classification                  | **Approved baseline**                                                      |
| PA06EH0-04 | Bounded sequence                      | One broad migration; H1 first; evidence table before policy                                           | H0A1–H0A5 → H0B1 operational identity/membership → H0C Draft materialization → H1A policy → H1B1 decision persistence → H1B2 read/preview/confirm                  | Ensures source, policy, and decision integrity exist in dependency order                                   | **Required sequencing baseline; exact task approvals pending**             |
| PA06EH0-05 | Planning confirmation grain           | One Confirmed Need line per atomic contribution; one line per operational requirement                 | Select the operational requirement grain: service date + typed school/destination + ingredient + controlled unit + approved scope                                  | Matches active operator intent while retaining atomic source trace; avoids an unapproved distribution rule | **Proposed direction; exact identity requires product-owner approval**     |
| PA06EH0-06 | Source kinds                          | Free text/table names; JSON lineage; generic source registry; declared types                          | Permit only `WHOLESALE` and `NEED_GENERATION` in this boundary                                                                                                     | Typed FKs reject fake lineage; future kinds require explicit migration                                     | **Proposed physical decision; unsafe alternatives prohibited**             |
| PA06EH0-07 | Batch source semantics                | Rewrite origin; derive everything; immutable origin plus controlled current release                   | Keep immutable origin run and one controlled current released-run snapshot for school catering                                                                     | Corrections advance current source without rewriting origin                                                | **Proposed H0B1 physical decision**                                        |
| PA06EH0-08 | Calculation grain                     | Aggregate Theoretical Need upstream; retain atomic contributions                                      | Retain one immutable Theoretical Need line per atomic typed source contribution                                                                                    | Supports exact RecipeLine/BOMLine correction and source explanation                                        | **Proposed H0A5 physical decision**                                        |
| PA06EH0-09 | Stable operational identity           | Contribution predecessor; ingredient/name/order; operational tuple                                    | Stable Confirmed Need identity is the exact approved operational tuple, never one source contribution                                                              | Multiple contributions can share one decision; identity fields never mutate                                | **Proposed direction; exact scope fields pending product approval**        |
| PA06EH0-10 | Revision source membership            | Singular theoretical FK; Need Generation grouped result; revision-owned typed membership              | Select Model A: immutable `ConfirmedNeedLineRevisionContribution[]` over exact released Theoretical Need lines                                                     | Smallest boundary that supports many contributions and preserves what Planning reviewed                    | **Proposed H0B1 physical decision**                                        |
| PA06EH0-11 | Atomic contribution continuity        | Ingredient/name/order key; generic aggregate; explicit predecessor                                    | Use typed stable anchors plus `predecessor_theoretical_need_line_id` for ordinary one-to-one contribution correction                                               | Predecessor explains atomic continuity, not Confirmed Need line identity                                   | **Proposed H0A5 physical decision**                                        |
| PA06EH0-12 | New/removed/split/merge contributions | Infer from absence; mutate rows; generic graph; explicit typed outcomes                               | New contributions have no predecessor; removal is explicit; H0C fails closed for unresolved zero/removal/split/merge                                               | Prevents silent omission and avoids a generic graph before policy                                          | **Representation proposed; product behavior pending**                      |
| PA06EH0-13 | Line decision evidence                | Append-only child; revision metadata only; hybrid                                                     | In H1B1, select immutable quantity/membership revision plus append-only decision child                                                                             | Supports changed and unchanged decisions without redundant revisions                                       | **Approved by H1B1-P01/P03**                                               |
| PA06EH0-14 | Current decision integrity            | Derive chain tip; mutable decision; stable-line pointer                                               | H1B1 adds a nullable pointer, composite ownership, and mandatory deferred same-line/current-revision/policy trigger                                                | Provides enforceable current authority and retained history                                                | **Approved by H1B1-P06/P07/P12**                                           |
| PA06EH0-15 | Unchanged proposal acceptance         | Infer from approval; identical successor; explicit decision                                           | Append `UNCHANGED_PROPOSAL_ACCEPTED` on the same exact revision/membership/policy                                                                                  | Makes human authority explicit without fake quantity history                                               | **Approved by H1B1-P02/P03**                                               |
| PA06EH0-16 | Adjusted confirmation                 | Update Draft; append evidence only; successor plus decision                                           | H1B2 creates one immutable successor revision and `ADJUSTED_QUANTITY_CONFIRMED` decision atomically                                                                | Preserves before/after value, membership, and policy                                                       | **Approved by H1B1-P02/P03/P05**                                           |
| PA06EH0-17 | Decision correction                   | Update/delete evidence; append superseding evidence                                                   | Append a full replacement decision, preserve prior row, advance pointer, reject forks                                                                              | Evidence remains auditable                                                                                 | **Approved by H1B1-P06/P08/P11**                                           |
| PA06EH0-18 | Logical adjustment read               | Separate duplicate table; infer from audit; derive from decisions                                     | Derive `ConfirmedNeedAdjustment` from adjusted decision rows                                                                                                       | Avoids duplicate authority                                                                                 | **Approved direction; H1B2 read model pending**                            |
| PA06EH0-19 | Policy/decision order                 | H0 policy default; decision table before policy; policy first                                         | H0B1/H0C create no decision structure; H1A creates policy; H1B1 creates decisions with mandatory policy FK; H1B2 first writes                                      | Database structure makes a policy-less authoritative decision impossible                                   | **H1A implemented; H1B1 contract approved**                                |
| PA06EH0-20 | Initial materialization               | Client grouping; one line per contribution; server operational grouping                               | Server consumes one complete released run, groups by approved identity, and creates one Draft revision plus immutable membership per group                         | Restores calculation-to-review boundary without browser authority                                          | **Parent responsibility approved; API/implementation pending**             |
| PA06EH0-21 | Corrected materialization             | Ingredient/name matching; contribution-line reuse; complete regroup                                   | Resolve the complete new set, regroup, compare operational identities, create successor revisions/memberships, and move ingredient corrections between lines       | Preserves stable identity and requires fresh review                                                        | **Proposed H0C decision; prior-proposal behavior pending**                 |
| PA06EH0-22 | Removal/split/merge in H0C            | Partial materialization; silent omission; fail closed                                                 | Reject the whole command until explicit zero/removal/split/merge policy exists                                                                                     | Prevents incomplete current membership                                                                     | **Proposed H0C boundary**                                                  |
| PA06EH0-23 | H0C success evidence                  | Per-line events; no receipt; one atomic result                                                        | One completed receipt, one domain event, and one audit event for the complete grouped materialization                                                              | Matches one-action/one-command and idempotency rules                                                       | **Approved command principle; exact payload/name pending**                 |
| PA06EH0-24 | Runtime ownership                     | Broaden PA-05D runtime; service role; dedicated runtime                                               | Propose a dedicated no-login/no-inherit Planning materialization runtime                                                                                           | Preserves PA-05D's exact four-function boundary                                                            | **Proposed security decision; exact role/grants pending**                  |
| PA06EH0-25 | Browser access                        | Direct private reads; service-role client; function-only boundary                                     | Keep all sources, memberships, and decisions private; expose reviewed functions only                                                                               | Preserves PA-03 and PA-06A boundaries                                                                      | **Approved baseline**                                                      |
| PA06EH0-26 | Migration style                       | Destructive replacement; broad combined migration; additive stages                                    | Add H0B1 identities/membership/constraints, preserve Wholesale rows, implement H0C, then add H1A/H1B1/H1B2 separately                                              | Maintains compatibility and policy ordering                                                                | **Proposed staged migration decision**                                     |
| PA06EH0-27 | Rollback                              | Drop history; restore wholesale-only constraints; disable/forward-fix                                 | Before use, normal unshipped revert; after use, revoke unsafe command and forward-fix additively                                                                   | History is never deleted to simulate rollback                                                              | **Approved history principle; operational procedure pending**              |
| PA06EH0-28 | H1 gate                               | Fake Wholesale fixture; policy-less decision; full prerequisites                                      | Require H0A, approved operational identity, H0B1, H0C, H1A, H1B1, exact scope, then H1B2                                                                           | H1 cannot claim a genuine or policy-bound slice prematurely                                                | **Required sequencing baseline**                                           |
| PA06EH0-29 | Active OPS v1 evidence                | Ignore legacy; copy schema literally; use as business evidence                                        | Record active family/conflict/grouping grain as `service_date + school_id + ingredient_id`, without copying Retool schema or rules                                 | Grounds the operational grain while retaining Atlas destination/unit/scope controls                        | **Evidence accepted; Atlas identity still requires product approval**      |
| PA06EH0-30 | Cross-row constraint strategy         | Command-only checks; optional triggers; composite keys plus mandatory triggers                        | Use denormalized typed identities, composite unique/FKs, partial uniques, and mandatory deferred constraint triggers; commands revalidate only as defense in depth | Makes lineage and pointer invariants database-enforceable                                                  | **Selected physical direction; exact names/performance pending**           |
| PA06EH0-31 | Total-equals-contributions            | Trust application sum; epsilon; exact deferred database sum                                           | Mandatory deferred constraint requires revision theoretical total to equal the exact controlled-unit membership sum                                                | Prevents browser/command drift and preserves reproducibility                                               | **Selected physical invariant**                                            |
| PA06EH0-32 | Parent-contract compatibility         | Treat singular parent field as final; broadly rewrite parents; narrow qualification                   | Add minimal PD-01.8/PA-02 qualification now and require a focused later amendment after grain approval                                                             | Makes the incompatibility explicit without expanding this PR                                               | **Compatibility requirement selected; amendment ownership/timing pending** |
| PA06EH0-33 | Aggregate boundary                    | Create grouped requirement aggregate; reuse Confirmed Need                                            | Operational grouping remains stable lines/revisions inside the existing Confirmed Need aggregate                                                                   | Avoids a second Planning lifecycle                                                                         | **Approved baseline**                                                      |

Rows PA06EH0-13 through PA06EH0-19 are historical summaries only. The focused H1B1 registry is the sole complete authority for their exact vocabulary, evidence, actor, pointer, and future physical semantics.

## 3. Selected source design in one view

```text
ConfirmedNeedBatch
├─ WHOLESALE → exact WholesaleOrder
└─ NEED_GENERATION → immutable origin NeedGenerationRun
                     + controlled current released-run snapshot

ConfirmedNeedLine
├─ WHOLESALE → exact stable WholesaleOrderLine
└─ NEED_GENERATION → immutable operational identity
                     (service date + school/destination + ingredient
                      + controlled unit + approved scope)

ConfirmedNeedLineRevision
├─ WHOLESALE → exact WholesaleOrderLineRevision
└─ NEED_GENERATION → exact current released-run snapshot
                     + immutable ConfirmedNeedLineRevisionContribution[]
                       → exact released TheoreticalNeedLine
                       → exact controlled-unit contribution
```

Exactly one typed source family is valid. A school-catering stable line is not one atomic contribution. Composite keys/FKs and mandatory deferred triggers prove batch/current-run/operational-scope agreement, immutable membership, and exact total equality. Theoretical-line typed source bridges, not duplicated Menu/Attendance/Recipe payloads in Confirmed Need, remain the authoritative upstream trace.

## 4. Selected decision-evidence design in one view

```text
ConfirmedNeedLineRevision
→ immutable ingredient, unit, theoretical quantity, candidate/confirmed quantity,
  exact released-run membership set, and revision predecessor

ConfirmedNeedLineDecision
→ append-only decision kind, before/after, accountable actor/time,
  governed business reason, exact source and Planning policy,
  decision-time batch version and command identity

ConfirmedNeedLine.current_confirmed_need_line_decision_id
→ absent through H0; added nullable in H1B1;
  exact current authoritative decision after H1B2 confirmation
```

H1A creates policy first. H1B1 creates the decision table, mandatory policy FK, pointer, and deferred pointer-integrity trigger without granting an insert path. `UNCHANGED_PROPOSAL_ACCEPTED` points to the existing Draft revision. `ADJUSTED_QUANTITY_CONFIRMED` points to the successor revision created by the H1B2 command. Adjustment history is the adjusted subset of the decision history.

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
9. Require H0A/H0B1/H0C, then H1A/H1B1, before H1B2.

## 6. Explicit pending decisions

The following remain unresolved and must block affected implementation rather than be guessed:

- school/customer/location ownership and scope grain;
- RecipeLine versus BOMLine physical structure and correction identity;
- Menu, Attendance, readiness, and calculation-rule snapshot tables;
- whether one Need Generation/Confirmed Need batch may span multiple schools, dates, or locations;
- explicit product-owner approval of the operational requirement grain and every typed identity field beyond date/school/destination/ingredient/controlled unit;
- exact release-snapshot, composite-key, redundant-scope-column, contribution-bridge, and trigger function names/performance limits; the database-enforcement direction is selected and is not optional;
- exact removed-tombstone vocabulary and zero/release policy;
- split and merge mapping/approval policy;
- prior-confirmed proposal carry behavior;
- production Planning policy administration and seed rows;
- H1B2 command/read contracts, safe errors, capability/scope, events, and audit payloads;
- post-H1B2 rematerialization and current-authority rebinding lifecycle;
- H0C function/capability/contract version/event/error names and canonical registry treatment;
- callable actor classes and exact school/date relational scope;
- runtime-role name, grants, timeouts, maximum contribution/group count, retry rules, and failed-receipt policy;
- ownership and timing of the focused PD-01.8/PA-02 parent-contract amendment;
- deployment, production inventory/backfill, reconciliation, cutover, and rollback rehearsal.

## 7. Consequences

The proposed design requires multiple bounded prerequisites before H0B1. It preserves current Wholesale rows and commands while separating atomic calculation grain from operational confirmation grain. Typed revision membership and deferred database constraints make the reviewed total reproducible without a new aggregate.

H0C can exist without a production Planning step because it creates proposals only. H1A now provides policy persistence, the H1B1 contract fixes the policy-bound evidence structure, a future H1B1 migration will add that writerless structure, and H1B2 remains the first insert capability.

## 8. Security, migration, and rollback effect

This record changes documentation only. It adds no SQL, migration, function, role, grant, RLS policy, registry entry, generated type, React code, Retool change, hosted Supabase change, production data, credential, or deployment.

Documentation rollback is a normal Git revert. No live database or operational rollback applies.