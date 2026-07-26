# Decision PA-06E-H0 — Source Lineage and Decision Evidence

**Status:** Historical H0 decision record; implemented H0 directions remain authoritative, while exact H1B1 decision-evidence details are superseded by the approved H1B1 registry

**Issue:** [#115](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/115)

**Architecture contract:** [PA-06E-H0 School-Catering Persistence and Materialization](../architecture/pa-06e-h0-school-catering-persistence-and-materialization-contract.md)

**Implementation decomposition:** [TASK-PA-06E-H0](../implementation-tasks/TASK-PA-06E-H0-school-catering-persistence-materialization.md)

**H1B1 superseding decision:** [Decision PA-06E-H1B1 — Policy-Bound Line Decision Evidence](decision-pa-06e-h1b1-policy-bound-line-decision-evidence.md)

## 1. Context

The approved Planning contracts define Need Generation, Theoretical Need, the existing Confirmed Need aggregate, logical `ConfirmedNeedSourceReference`, logical `ConfirmedNeedAdjustment`, validation, approval snapshots, and release. PA-06E retains that aggregate and prohibits a Planning Quantity Confirmation or generic Quantity Decision aggregate.

The original PA-04/PA-05D physical implementation was bounded to Wholesale. H0A/H0B1/H0C later added the genuine school-catering source, calculation, operational identity, contribution membership, and Draft materialization path while preserving `PA-05D.v1` behavior.

The retained active OPS v1 Purchase Planner provides business evidence: its `family_token`, `public.actual_need_overrides` primary/conflict key, and `public.purchase_assignments` grouping use `service_date + school_id + ingredient_id`. Retained `ops_v2` experiments use `effective_line_key`. These remain operator-workflow evidence only, not Atlas schema or authority.

This record preserves the original H0 decision sequence. The focused H1B1 decision record now owns the exact decision kind, reason, actor, policy, quantity, predecessor, pointer, command, security, and future persistence contract.

## 2. Decision records

| ID         | Decision                              | Alternatives considered                                                                               | Selected direction or retained baseline                                                                                                                            | Rationale and consequence                                                                                  | Status                                                                     |
| ---------- | ------------------------------------- | ----------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| PA06EH0-01 | Business aggregate                    | New Planning confirmation aggregate; generic Quantity Decision; retain Confirmed Need                 | Retain `ConfirmedNeedBatch`, stable line, line revision, logical source/adjustment children, and approval snapshots                                                | Avoids duplicate lifecycle and keeps Planning ownership explicit                                           | **Approved baseline**                                                      |
| PA06EH0-02 | Quantity meanings                     | Collapse calculated and confirmed; infer authority from non-null value; lifecycle-qualified authority | Keep theoretical/calculated evidence separate from Planning-confirmed authority                                                                                    | A materialized Draft value is proposed until explicit decision evidence exists                             | **Approved baseline**                                                      |
| PA06EH0-03 | Direct-wholesale behavior             | Rebuild PA-05D; move wholesale behind a new source hierarchy; preserve existing typed columns         | Preserve `PA-05D.v1`, including pass-through equality and public commands                                                                                          | H0 may alter internal inserts/constraints only to write explicit Wholesale classification                  | **Approved baseline**                                                      |
| PA06EH0-04 | Bounded sequence                      | One broad migration; H1 first; evidence table before policy                                           | H0A1–H0A5 → H0B1 operational identity/membership → H0C Draft materialization → H1A policy → H1B1 decision persistence → H1B2 read/preview/confirm                  | Ensures source, policy, and decision integrity exist in dependency order                                   | **Required sequencing baseline**                                           |
| PA06EH0-05 | Planning confirmation grain           | One Confirmed Need line per atomic contribution; one line per operational requirement                 | Select the operational requirement grain: service date + typed school/destination + ingredient + controlled unit + approved scope                                  | Matches active operator intent while retaining atomic source trace; avoids an unapproved distribution rule | **Implemented by H0B1b**                                                   |
| PA06EH0-06 | Source kinds                          | Free text/table names; JSON lineage; generic source registry; declared types                          | Permit only `WHOLESALE` and `NEED_GENERATION` in this boundary                                                                                                     | Typed FKs reject fake lineage; future kinds require explicit migration                                     | **Implemented by H0B1b**                                                   |
| PA06EH0-07 | Batch source semantics                | Rewrite origin; derive everything; immutable origin plus controlled current release                   | Keep immutable origin run and one controlled current released-run snapshot for school catering                                                                     | Corrections advance current source without rewriting origin                                                | **Implemented by H0B1b**                                                   |
| PA06EH0-08 | Calculation grain                     | Aggregate Theoretical Need upstream; retain atomic contributions                                      | Retain one immutable Theoretical Need line per atomic typed source contribution                                                                                    | Supports exact RecipeLine/BOMLine correction and source explanation                                        | **Implemented by H0A5b**                                                   |
| PA06EH0-09 | Stable operational identity           | Contribution predecessor; ingredient/name/order; operational tuple                                    | Stable Confirmed Need identity is the exact approved operational tuple, never one source contribution                                                              | Multiple contributions can share one decision; identity fields never mutate                                | **Implemented by H0B1b**                                                   |
| PA06EH0-10 | Revision source membership            | Singular theoretical FK; Need Generation grouped result; revision-owned typed membership              | Select Model A: immutable `ConfirmedNeedLineRevisionContribution[]` over exact released Theoretical Need lines                                                     | Smallest boundary that supports many contributions and preserves what Planning reviewed                    | **Implemented by H0B1b**                                                   |
| PA06EH0-11 | Atomic contribution continuity        | Ingredient/name/order key; generic aggregate; explicit predecessor                                    | Use typed stable anchors plus `predecessor_theoretical_need_line_id` for ordinary one-to-one contribution correction                                               | Predecessor explains atomic continuity, not Confirmed Need line identity                                   | **Implemented by H0A5b**                                                   |
| PA06EH0-12 | New/removed/split/merge contributions | Infer from absence; mutate rows; generic graph; explicit typed outcomes                               | New contributions have no predecessor; removal is explicit; H0C fails closed for unresolved zero/removal/split/merge                                               | Prevents silent omission and avoids a generic graph before policy                                          | **Representation implemented; product behavior pending**                   |
| PA06EH0-13 | Line decision evidence                | Append-only child; revision metadata only; hybrid                                                     | Use immutable quantity/membership revision plus append-only decision child                                                                                         | Supports changed and unchanged decisions without redundant revisions                                       | **Approved by H1B1-P01/P03**                                               |
| PA06EH0-14 | Current decision integrity            | Derive chain tip; mutable decision; stable-line pointer                                               | Add one nullable stable-line pointer with composite ownership and mandatory deferred integrity                                                                      | Provides enforceable current authority and retained history                                                | **Approved by H1B1-P06/P07/P12**                                           |
| PA06EH0-15 | Unchanged proposal acceptance         | Infer from approval; identical successor; explicit decision                                           | Append `UNCHANGED_PROPOSAL_ACCEPTED` on the same exact current revision                                                                                            | Makes human authority explicit without fake quantity history                                               | **Approved by H1B1-P02/P03**                                               |
| PA06EH0-16 | Adjusted confirmation                 | Update Draft; append evidence only; successor plus decision                                           | H1B2 creates one immutable successor revision and `ADJUSTED_QUANTITY_CONFIRMED` decision atomically                                                                | Preserves before/after value, membership, and policy                                                       | **Approved by H1B1-P02/P03/P05**                                           |
| PA06EH0-17 | Decision correction                   | Update/delete evidence; append superseding evidence                                                   | Append a complete replacement decision, preserve the business reason, require direct predecessor and correction note, advance the pointer, and reject forks        | Evidence remains auditable without replacing the business meaning                                          | **Approved by H1B1-P06/P08/P11**                                           |
| PA06EH0-18 | Logical adjustment read               | Separate duplicate table; infer from audit; derive from decisions                                     | Derive logical `ConfirmedNeedAdjustment` from adjusted decision rows                                                                                               | Avoids duplicate authority                                                                                 | **Approved direction; H1B2 read model pending**                            |
| PA06EH0-19 | Policy/decision order                 | H0 policy default; decision table before policy; policy first                                         | H0B1/H0C create no decision structure; H1A creates policy; H1B1 creates policy-bound structure; H1B2 first writes                                                  | Database structure makes policy-less authority impossible                                                  | **H1A implemented; H1B1 contract approved**                                |
| PA06EH0-20 | Initial materialization               | Client grouping; one line per contribution; server operational grouping                               | Server consumes one complete released run, groups by approved identity, and creates one Draft revision plus immutable membership per group                         | Restores calculation-to-review boundary without browser authority                                          | **Implemented by H0C/CMD-15**                                              |
| PA06EH0-21 | Corrected materialization             | Ingredient/name matching; contribution-line reuse; complete regroup                                   | Resolve the complete new set, regroup, compare operational identities, create successor revisions/memberships, and move ingredient corrections between lines       | Preserves stable identity and requires fresh review                                                        | **Implemented within the approved H0C boundary**                           |
| PA06EH0-22 | Removal/split/merge in H0C            | Partial materialization; silent omission; fail closed                                                 | Reject the whole command until explicit zero/removal/split/merge policy exists                                                                                     | Prevents incomplete current membership                                                                     | **H0C fail-closed boundary retained**                                      |
| PA06EH0-23 | H0C success evidence                  | Per-line events; no receipt; one atomic result                                                        | One completed receipt, one domain event, and one audit event for the complete grouped materialization                                                              | Matches one-action/one-command and idempotency rules                                                       | **Implemented by H0C/CMD-15**                                              |
| PA06EH0-24 | Runtime ownership                     | Broaden PA-05D runtime; service role; dedicated runtime                                               | Use a dedicated no-login/no-inherit Planning materialization runtime                                                                                                | Preserves PA-05D's exact boundary                                                                           | **Implemented by H0C/CMD-15**                                              |
| PA06EH0-25 | Browser access                        | Direct private reads; service-role client; function-only boundary                                     | Keep all sources, memberships, policies, and decisions private; expose only separately reviewed functions                                                          | Preserves PA-03 and PA-06A boundaries                                                                      | **Approved baseline**                                                      |
| PA06EH0-26 | Migration style                       | Destructive replacement; broad combined migration; additive stages                                    | Add H0B1 identities/membership/constraints, implement H0C, then add H1A/H1B1/H1B2 separately                                                                       | Maintains compatibility and policy ordering                                                                | **Accepted staged direction**                                              |
| PA06EH0-27 | Rollback                              | Drop history; restore wholesale-only constraints; disable/forward-fix                                 | Before use, normal unshipped revert; after use, revoke unsafe command and forward-fix additively                                                                   | History is never deleted to simulate rollback                                                              | **Approved history principle**                                             |
| PA06EH0-28 | H1 gate                               | Fake Wholesale fixture; policy-less decision; full prerequisites                                      | Require H0A, H0B1, H0C, H1A, H1B1, exact scope, then H1B2                                                                                                         | H1 cannot claim a genuine or policy-bound slice prematurely                                                | **Required sequencing baseline**                                           |
| PA06EH0-29 | Active OPS v1 evidence                | Ignore legacy; copy schema literally; use as business evidence                                        | Use the active `service_date + school_id + ingredient_id` family only as operator-intent evidence                                                                  | Grounds the operational grain without copying legacy authority                                             | **Evidence accepted**                                                      |
| PA06EH0-30 | Cross-row constraint strategy         | Command-only checks; optional triggers; composite keys plus mandatory triggers                        | Use denormalized typed identities, composite unique/FKs, partial uniques, and mandatory deferred constraint triggers; commands revalidate only as defense in depth | Makes lineage and pointer invariants database-enforceable                                                  | **Accepted physical direction**                                            |
| PA06EH0-31 | Total-equals-contributions            | Trust application sum; epsilon; exact deferred database sum                                           | Mandatory deferred constraint requires revision theoretical total to equal the exact controlled-unit membership sum                                                | Prevents browser/command drift and preserves reproducibility                                               | **Implemented by H0B1b**                                                   |
| PA06EH0-32 | Parent-contract compatibility         | Treat singular parent field as final; broadly rewrite parents; narrow qualification                   | Use focused bounded contracts and decision records rather than duplicate broad rewrites                                                                            | Keeps authority clear and reviewable                                                                        | **Satisfied by focused H0/H1 records**                                     |
| PA06EH0-33 | Aggregate boundary                    | Create grouped requirement aggregate; reuse Confirmed Need                                            | Operational grouping and decisions remain inside the existing Confirmed Need aggregate                                                                              | Avoids a second Planning lifecycle                                                                         | **Approved baseline**                                                      |

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
→ immutable ingredient, unit, theoretical quantity, proposed/confirmed quantity,
  exact released-run membership set, and revision predecessor

ConfirmedNeedLineDecision
→ append-only decision kind, theoretical/proposal/confirmed evidence,
  exact Planning policy revision and tick count,
  governed business reason and correction note when applicable,
  one accountable decision actor/time, command identity, and predecessor

ConfirmedNeedLine.current_confirmed_need_line_decision_id
→ absent through H0/H1A
→ added nullable in H1B1
→ exact current authoritative decision after H1B2 confirmation
```

H1A creates policy first. H1B1 creates the private decision structure, mandatory policy FK, nullable pointer, and deferred integrity without granting an insert path. `UNCHANGED_PROPOSAL_ACCEPTED` binds the existing current revision. `ADJUSTED_QUANTITY_CONFIRMED` binds the successor revision created by H1B2. Adjustment history is the adjusted subset of decision history.

## 5. H1B1 supersession boundary

The sole complete H1B1 registry is [Decision PA-06E-H1B1 — Policy-Bound Line Decision Evidence](decision-pa-06e-h1b1-policy-bound-line-decision-evidence.md).

It supersedes these earlier pending details:

- exact decision kinds;
- exact policy/revision/quantity binding;
- direct predecessor and non-forking replacement rules;
- pointer monotonicity and no-clear rule;
- exact reason/note vocabulary;
- one accountable actor and no proxy/separation-of-duties rule;
- command and aggregate-version evidence; and
- the bounded one-relation/one-pointer/private-security direction.

It does not reopen H0 source, calculation, materialization, zero/removal/split/merge, or rollout decisions.

## 6. Accepted architectural directions

These inherited directions are not reopened:

1. Retain the existing logical Confirmed Need aggregate and approval snapshots.
2. Keep theoretical/calculated quantity separate from Planning-confirmed authority.
3. Add no Planning Quantity Confirmation or generic Quantity Decision aggregate.
4. Correct the owning source, create new calculation evidence, and require new Planning review.
5. Never silently rewrite prior approval, release, Purchase Handoff, PO, Dispatch, receipt, event, audit, or physical evidence.
6. Preserve direct-wholesale `PA-05D.v1` behavior.
7. Prohibit fake wholesale lineage, free-text polymorphic IDs, caller-authored object names, and unvalidated lineage JSON.
8. Keep React non-authoritative and private tables inaccessible to browser roles.
9. Require H0A/H0B1/H0C, then H1A/H1B1, before H1B2.

## 7. Remaining pending decisions

The following remain outside H1B1A and must not be guessed:

- removed/zero contribution release policy;
- split and merge mapping/approval policy;
- post-H1B2 rematerialization and authority-rebinding lifecycle;
- H1B2 command names, request/response, safe error vocabulary, capability, scope, locking, limits, event, and audit payloads;
- authorized H1B2 review/readback shape;
- complete-batch validation, approval, release, reopen, and CMD-03 school-catering integration;
- production policy administration and seed;
- deployment, production inventory/backfill, reconciliation, cutover, and rollback rehearsal.

## 8. Consequences

The architecture now has a complete sequence from typed source evidence through policy-bound line authority without adding another aggregate or copying OPS v1 override structures.

H1B1 can remain one additive private persistence task with no writer. H1B2 can later implement the first authorized command/read slice without reopening the line decision model.

## 9. Security, migration, and rollback effect

This update changes documentation only. It adds no SQL, migration, relation, column, function, trigger, test, workflow registration, role, capability, grant, RLS policy, registry entry, generated type, React code, Retool change, hosted Supabase change, OPS data, production row, seed, credential, package, lockfile, deployment, or API.

Documentation rollback is a normal Git revert. No live database or operational rollback applies.