# ATLAS-C-NEED-CORRECTION-ARCHITECTURE-GATE-01

Latest K1 execution: see **K1 source-lock correction — 19 October 2026** below.
Earlier proposal verdicts and failed execution stops are preserved history.

## Executive contract delta — Owner decision page

**Verdict: DECISION REQUIRED. Design only; implementation is not authorized.**

**Authority:** [Issue #400 / 19 October Owner direction](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/400#issuecomment-6258466868), ARCH-002, D-037, D-044 and ATLAS-MODEL-PRINCIPLE-01. Audited SHA: `7ccb148035932891996b660e99d7e8ee67757f18` (#405). All amendments below are **proposed**.

**Decision requested:** let existing Preparation authorize exact corrected Need decisions as Procurement source without recreating whole-day Planning/Handoff history. Reuse typed `CONFIRMED_NEED` allocation contributions and affected-family successors bound to the Preparation receipt. Retain original Handoff evidence and derive applicability. Allocation Save alone confers no transfer authority; official PO release remains independent.

| Boundary                     | Current implementation                                                          | Gap                                                                         | Proposed minimum change                                                                                   |
| ---------------------------- | ------------------------------------------------------------------------------- | --------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| Confirmed Need correction    | Existing Save appends authentic R/D in editable batches.                        | Released Save rejects; source-correction RPCs accept no human quantity.     | Extend the same writer atomically; preserve released history.                                             |
| Decision/revision continuity | Stable IDs, exact predecessors, D-040/D-046 evidence.                           | Reopen leaves mixed released/new revisions.                                 | Prove corrected ancestry; retain untouched R/D and source identities.                                     |
| Validation/re-release        | D-037/RMVP-06/07 complete-batch evidence; DRAFT observation requirement.        | Retained RELEASED revisions block reapproval; prior repair exceeded8 s.     | Separate exact transfer predicate in Preparation; retain compatibility release and corruption guards.     |
| Handoff currentness          | Current whole header owns all members.                                          | Whole invalidation stales unrelated families; partial header loses members. | Retain initial witness; corrected Need masks obsolete family contributions.                               |
| Supplier allocation          | Typed revisions, accepted splits, advisory rebalance.                           | Release requires every family to reenter Confirmed-source allocation.       | Retain untouched families; review affected splits and generate exact transfer support.                    |
| Complete replacement PO      | D-044 complete supplier/date Draft, independent numbering/release/supersession. | Official guards require Handoff-source splits.                              | Admit only proven transferred corrections plus unaffected Handoff splits; preserve B2/cancellation rules. |
| School PXK successor         | Immutable School/date/location snapshot with PO identities.                     | Handoff-only preview; shared PO replacement affects PXK identity.           | Same canonical selector; derive impact and require explicit successor release.                            |

**Acceptance target:** 100→110 yields complete110 PO-002 only on explicit release; immutable PO-001 remains reproducible. Then110→90 supports complete90 PO-003. No supplemental+10 order. Supplier removal remains `CANCELLATION_REQUIRED`.

**Approval boundary:** official PO authority currently requires a complete current Handoff from one Planning release. The proposed revision-bound transfer changes that rule despite adding no aggregate/table/status/permission. D-044 approves the outcome, not this route. Existing source supports a candidate, not executed safety or performance. **Approve this specific transfer/validation amendment before SQL; stop at this gate.**

<!-- End of the executive decision page. The remainder is the evidence appendix and conditional handoff. -->

## A. Scope, baseline and evidence status

This document is a proposal for review, not a replacement for an accepted ADR/API contract. The direct execution brief and latest #400 decision supersede the older B1/B2-only Autopilot baton for this design task only. No ancestor PR, production contract, migration, frontend behavior, hosted data or supplier commitment is changed.

| Checkpoint                  | Expected and verified head                 |
| --------------------------- | ------------------------------------------ |
| `origin/main`               | `3667966a3f6703a6585f07ba619969ec851ca7b8` |
| Draft #392                  | `6f9f288c76cfa48691fca2f4968ce03185502bb2` |
| Draft #401                  | `4419033c2e4637fefb651d4ba395f4993a4e3599` |
| Draft #402                  | `7dd922230be231d81971fbdab6f3c2a61f3056c4` |
| Draft #404                  | `689398e12f3911182862c76a964434c8776b6bec` |
| Draft #405 / audit baseline | `7ccb148035932891996b660e99d7e8ee67757f18` |

Verified remote: `https://github.com/longpsu-bot/thuonghao-ops-erp.git`. The user-authorized E: repository was clean. A native managed independent worktree was created at `C:/Users/HOME/.codex/worktrees/atlas-c-need-po-bridge-gate-01/thuonghao-ops-erp`, pinned to the requested SHA, then branched as `design/atlas-c-need-po-bridge-gate-01`. Fetch, root/remote/head/status and `pnpm ops:workspace` checks passed. The workspace checker retains an older D: path warning; the actual remote and task-authorized checkout were verified. Existing checkouts and stashes were preserved.

Read: AGENTS, README, vision charter, decision/business-rule registers, both Autopilot documents, ARCH-002, authority map, business freeze, D-037 and related RMVP-05/06/07 contracts, D-044 Procurement/PXK contracts, Issue #222 task/adapters, and latest #400 comments. Historical PRs/issues below were read through GitHub. #388/#396 code is **not** installed by this stack and was not imported.

Evidence labels used below:

- **Existing:** inspected contract/migration/application or test source at the pinned SHA. Migration order and later function-body patches matter; a first definition alone is insufficient.
- **Recorded:** a historical result reported in the linked issue/PR, not rerun here.
- **Proposed:** requires approval and new executable proof. No product scenarios, SQL, benchmarks or connected/browser acceptance were executed by this design task.

The two Owner-local files under `C:/Users/hp/.codex/visualizations/2026/10/17/01a14ab2-0956-71c2-8724-4f141839eef5/atlas-product-acceptance/` (`PRODUCT-REVIEW-PR392.md` and `SOP-NGOAI-LE-CUTOVER-DRAFT.md`) are unavailable here. GitHub Owner decisions and the supplied brief were used; no screenshot or SOP approval is inferred.

## B. Source evidence register

Paths below are repository-relative and refer to the pinned audit SHA. Line references identify inspected source, including subsequent patches.

| ID  | Exact source and relevant boundary                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| E01 | [`20260811011339_confirmed_need_save_release_boundary.sql`](../../supabase/migrations/20260811011339_confirmed_need_save_release_boundary.sql):437–684 — Save authorization, editable-state gate, locks, append writer, readback and receipt; :686 onward — composed release.                                                                                                                                                                                                                    |
| E02 | [`20260901181519_procurement_connected_contract_hardening.sql`](../../supabase/migrations/20260901181519_procurement_connected_contract_hardening.sql):136–302 — D-037 eligibility; :304–695 — current release body.                                                                                                                                                                                                                                                                             |
| E03 | [`20260803102941_rmvp_05_connected_confirmed_need_review.sql`](../../supabase/migrations/20260803102941_rmvp_05_connected_confirmed_need_review.sql):791–1120 — canonical decision preview: expected revision/decision, exact quantity, policy, source membership, reason and note.                                                                                                                                                                                                              |
| E04 | [`20260726115324_pa_06e_h1b1_policy_bound_line_decision_persistence.sql`](../../supabase/migrations/20260726115324_pa_06e_h1b1_policy_bound_line_decision_persistence.sql):24–217 — decision fields/constraints; :279–933 — immutability, pointer, chain/policy/quantity guards and triggers.                                                                                                                                                                                                    |
| E05 | [`20260817045218_planning_contract_02b_selective_confirmation_continuity.sql`](../../supabase/migrations/20260817045218_planning_contract_02b_selective_confirmation_continuity.sql):213–241 — `planning_contract_02b_decision_authorizes_revision`; :770–953 — continuity; :1771–2001 — RMVP-06/07 exact-decision and membership amendments.                                                                                                                                                    |
| E06 | [`20260804073753_rmvp_06_connected_confirmed_need_validation.sql`](../../supabase/migrations/20260804073753_rmvp_06_connected_confirmed_need_validation.sql):743–1320 — `rmvp_06_canonical_evaluation`; :451–591 — immutable observation integrity.                                                                                                                                                                                                                                              |
| E07 | [`20260805202517_rmvp_07_connected_confirmed_need_approval_release.sql`](../../supabase/migrations/20260805202517_rmvp_07_connected_confirmed_need_approval_release.sql):1120–1390 — historical and current lifecycle integrity; :1454 onward — validated facts projection; :1933–2043 — `rmvp_07_validation_evidence_complete`, including :2005 `DRAFT` requirement; :2046–2110 — `rmvp_07_snapshot_current_complete`. Apply E05 patches.                                                       |
| E08 | [`20260923041223_planning_operational_proposal.sql`](../../supabase/migrations/20260923041223_planning_operational_proposal.sql):420–507 — D-046 successor Save carries `proposal_rounding_step` and `proposal_rounding_ingredient_version`; does not reopen released batches.                                                                                                                                                                                                                   |
| E09 | [`20260907110000_school_need_downstream_correction.sql`](../../supabase/migrations/20260907110000_school_need_downstream_correction.sql):13–80 — School/Wholesale impact distinction; :84–130 — `issue_222_reopen_confirmed_need` invalidates active School Handoff and clears batch lifecycle pointers.                                                                                                                                                                                         |
| E10 | [`20260823090858_issue_222_closed_loop_planning_corrections.sql`](../../supabase/migrations/20260823090858_issue_222_closed_loop_planning_corrections.sql):765–950 — public source prepare, locks, capabilities and reopening. [`planningCorrectionApi.ts`](../../src/modules/atlas/planning-inputs/planningCorrectionApi.ts):15–18 — only `WEEKLY_MENU`, `ATTENDANCE`, `PANTRY`; see [Issue #222 task](TASK-ISSUE-222-closed-loop-planning-source-corrections.md).                              |
| E11 | [`20260831090000_school_catering_handoff_allocation.sql`](../../supabase/migrations/20260831090000_school_catering_handoff_allocation.sql):673–772 — family/revision/split authority; :774–811 — Handoff-only projection; :1031–1067 — complete current released Need prerequisite; :1093–1147 — full Handoff membership generation.                                                                                                                                                             |
| E12 | [`20260903072648_purchase_review_confirm_release.sql`](../../supabase/migrations/20260903072648_purchase_review_confirm_release.sql):24–45 — typed source XOR; :93–158 — confirmed-source projections; :355–587 — source locks/persistence; :465–474 — released/real-Handoff restriction; :694–716 — whole-batch allocation readiness; :793–847 — promotion; :885–1003 — Preparation; :1013–1106 — contribution integrity and explicit Handoff-only official PO guard; :1113–1137 — PO coverage. |
| E13 | [`20260831120000_school_catering_purchase_orders.sql`](../../supabase/migrations/20260831120000_school_catering_purchase_orders.sql):32–64 — PO line/split references; :183–333 — readiness and bidirectional identity-based stale detection; :757–795 — release locks; :1120 onward — complete document authorization.                                                                                                                                                                          |
| E14 | [`20260907120000_school_catering_po_replacement.sql`](../../supabase/migrations/20260907120000_school_catering_po_replacement.sql):9–34 — replacement identity/uniqueness; :46–145 — commitment/date currentness; :165–236 — atomic predecessor supersession; :260–561 — complete replacement command; :596 onward — history/readback.                                                                                                                                                           |
| E15 | [`20260908225248_purchase_preparation_replacement_frontier.sql`](../../supabase/migrations/20260908225248_purchase_preparation_replacement_frontier.sql):13–224, :278–303 — complete per-supplier preparation coverage and replacement frontier.                                                                                                                                                                                                                                                 |
| E16 | [`20261013082420_atlas_purchase_preparation_release_projection.sql`](../../supabase/migrations/20261013082420_atlas_purchase_preparation_release_projection.sql):69–142 — supplier evidence before family locks, reread after waiting. [`20261019014456_atlas_b2_po_ingredient_code_optional.sql`](../../supabase/migrations/20261019014456_atlas_b2_po_ingredient_code_optional.sql):36–85, :100–178 — latest B2 release/read/snapshot amendment.                                               |
| E17 | [`20260907130000_school_dispatch_release.sql`](../../supabase/migrations/20260907130000_school_dispatch_release.sql):8–114 — PXK/source tables; :156–182 — immutability; :191–420 — exact preview/PO coverage/fingerprint; :503–526 — upstream locks; :599–660 — currentness; :757–854 — explicit release/successor.                                                                                                                                                                             |
| E18 | [`20261014090000_atlas_cutover_auth_scope_alignment.sql`](../../supabase/migrations/20261014090000_atlas_cutover_auth_scope_alignment.sql):7–85, :117–176, :244–274 — whole-PO scope/capabilities. [`20261014120320_atlas_pxk_exact_school_scope.sql`](../../supabase/migrations/20261014120320_atlas_pxk_exact_school_scope.sql):3–57 — exact School authorization.                                                                                                                             |
| E19 | [`20260715105918_pa_05b_supplier_direct_command_subset.sql`](../../supabase/migrations/20260715105918_pa_05b_supplier_direct_command_subset.sql):436–621 — `pa_05b_request_hash`, `pa_05b_begin_command`, `pa_05b_finish_command`; [`20260908154640_scenario_c_confirmed_need_write_certainty_message.sql`](../../supabase/migrations/20260908154640_scenario_c_confirmed_need_write_certainty_message.sql):1 onward — Save exception certainty amendment.                                       |
| E20 | [`confirmedNeedApi.ts`](../../src/modules/atlas/planning-inputs/confirmed-needs/confirmedNeedApi.ts):12–22, :345 onward — existing RPCs/Save envelope; [`useProcurementWorkbench.ts`](../../src/vnext/atlas/procurement/useProcurementWorkbench.ts):307–350 — refresh/UNKNOWN guards; [`purchase_review_confirm_release.sql`](../../supabase/tests/purchase_review_confirm_release.sql):1118–1141, :1536–1541, :1709–1718 — fixture-only reopen bypass and unchanged-family resave.              |

Core approved contracts: [D-037](../decisions/decision-confirmed-need-save-release-boundary.md), [Save/Release v2](../api/confirmed-need-save-release-v2.md), [RMVP-06](../api/rmvp-06-connected-confirmed-need-validation.md), [RMVP-07](../api/rmvp-07-connected-confirmed-need-approval-release.md), [D-044](../decisions/decision-ops-v1-school-fulfilment-closeout.md), [Procurement](../api/school-catering-procurement.md), [School PXK](../api/school-dispatch-release.md), [authority map](../architecture/atlas-authority-map-through-procurement.md), [freeze](../architecture/planning-procurement-business-freeze.md), [model principle](../decisions/decision-atlas-model-convergence.md).

## C. The authoritative fact and the installed gap

### C1. Exact existing authority

All relations in this paragraph are in `atlas_planning`. `confirmed_need_lines.confirmed_need_line_id` is the stable business identity. Its grain includes `service_date`, `customer_id`, `school_id`, `delivery_location_id`, `ingredient_id`, `controlled_unit_id`; `current_confirmed_need_line_decision_id` points to the latest authentic human decision. The current quantity-bearing row is `confirmed_need_line_revisions` with `is_current`; the successor carries `predecessor_revision_id` and incremented `revision_number`.

For 100→110, E01's writer already knows how to create one successor with `confirmed_quantity=110`, preserving `theoretical_quantity`, exact `unit_id`, source/run/version/release snapshot and School/location bindings. It copies only that changed revision's contribution membership into `confirmed_need_line_revision_contributions`, retaining the referenced theoretical/release-line identities. E08 preserves the D-046 rounding snapshot. No new Need Generation run or Recipe/BOM write is needed for a pure human quantity correction.

The matching `confirmed_need_line_decisions` row records `ADJUSTED_QUANTITY_CONFIRMED`, `predecessor_decision_id`, `decision_number`, policy root/revision, `theoretical_quantity_before`, `proposed_quantity_before`, `confirmed_quantity_after`, ticks, `reason_code`, `reason_note`, `decided_by_actor_id`, `decided_at`, `command_id`, and batch version. The example reason is `OPERATIONAL_QUANTITY_ADJUSTMENT` with note “Điều chỉnh nhu cầu thực tế”. A later 110→90 links directly to the 110 revision/decision; it does not restart the chain.

The system's original proposal remains reconstructible from raw theoretical quantity and the snapshotted rounding step. The decision's before quantity is the predecessor quantity considered by the operator; it must not be presented as a newly recalculated theoretical proposal. B1's source evidence remains distinct: R20+B5+H3 gives theoretical28, recipe-associated25 and separate H3; a human30 remains the authoritative final quantity with variance+2.

Untouched lines are omitted from Save and retain their existing stable-line, revision and decision IDs. D-040's `confirmed_need_line_decision_continuity` authorizes carried decisions only through its exact predicate; it is neither a blanket released-status exemption nor another human decision. Historical `confirmed_need_approval_snapshots`, `confirmed_need_snapshot_lines`, `confirmed_need_releases`, Need Generation release snapshots and downstream PO/PXK snapshots remain unchanged. Permitted revision-head/lifecycle metadata transitions do not permit quantity/source payload rewrites. [E01–E09]

### C2. What does not work today

1. E01 rejects Save outside `DRAFT_REVIEW`/`REOPENED`; E02 advertises the same eligibility. The D-044 contract's general “Save/reopen” correction wording does **not** establish a public direct released-batch Save route. This is a concrete coverage limitation; do not make the UI override backend false.
2. `get_planning_source_correction_impact` and `prepare_planning_source_correction` govern upstream Menu/Attendance/Pantry changes. The latter can reopen a released chain, but neither accepts an old/new human confirmed quantity. Calling it as an undocumented quantity-correction API would change its meaning. [E10]
3. Reopening clears current lifecycle pointers; unchanged current revisions remain `RELEASED`, while changed Save successors are `DRAFT`. `rmvp_07_validation_evidence_complete` requires observed revisions to be `DRAFT`; subsequent approval/snapshot/status guards also require a coherent exact set. D-040 changes decision-authority checks, not this lifecycle contract. A status-only relaxation is insufficient. [E05, E07]
4. `issue_222_reopen_confirmed_need` invalidates the whole active School Handoff. Existing release requires every positive allocation family to reenter `CONFIRMED_NEED` source; unchanged promoted families therefore fail readiness. Whole-Handoff regeneration then emits all members again. [E09, E11, E12]
5. Official PO readiness/coverage/staleness and deferred integrity explicitly reject non-Handoff allocation authority. The PO line schema can reference an existing Confirmed-source split, but current business guards correctly forbid using it as an official commitment. [E12–E15]

The existing Scenario C regression uses `session_replication_role=replica` and a private reopen helper before authenticated Save. Its downstream tests are useful; this setup is not acceptance of a lawful public correction command, intact triggers, or full mixed-revision release. [E20]

## D. Three situations and the proposed minimum bridge

| Situation                                           | Existing allowed path / current blocker                                                                                                                                      | Human decision                                                                                                          | Proposed support and downstream effect                                                                                                                             | Contract change?                                                                                           |
| --------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------- |
| 1. Editable Need; no issued supplier commitment     | Save changed decisions → review/save allocations or eligible preferred default → Preparation → independent PO release. Normal D-037 path works when complete/current.        | Confirm quantity; accept changed explicit supplier splits where required; explicitly Prepare and release PO.            | Existing initial Planning release/Handoff/promotion remains unchanged. No post-release bridge.                                                                     | None for the ordinary path.                                                                                |
| 2. Planning/Handoff released; no affected PO issued | Source correction can explicitly reopen applicable upstream chains; no direct public human-quantity correction path, mixed-status reapproval blocks, Draft PO becomes stale. | Reasoned quantity correction; review affected splits; explicitly Prepare updated Draft.                                 | Same approved correction bridge as below, anchored to the prior transfer; regenerate only affected Draft content. No official number or supplier supersession yet. | Yes: released Save entry plus revision-bound transfer. Absence of issued PO does not turn this into case1. |
| 3. Released supplier PO exists                      | D-044 replacement command works once valid current transferred allocations exist; Save/transfer gap remains.                                                                 | Reasoned quantity correction; explicit allocation decision; Prepare/review full replacement; separate official release. | Preserve old issued PO until replacement release. Complete supplier/date closure determines new Draft and PXK impact.                                              | Same bridge approval; reuse D-044 commitment semantics.                                                    |

### D1. Proposed release-authority contract — not installed

Prefer one existing writer and one existing Preparation boundary over a second quantity API or a correction aggregate.

1. **Save owns the correction transaction.** Amend `atlas_api.save_confirmed_needs(jsonb)` through an explicitly versioned post-release branch. Require the conservative union of existing reopen and Save authority: `planning.need_generation.write`, `confirmed_need_quantities.confirm`, `confirmed_need_release.release`, active human Actor and GLOBAL scope. This union is a proposed choice for Owner approval, not current Save behavior. Initial editable Save retains its existing requirements. No new grants or second-person approval are proposed.
2. Lock/revalidate original release and exact current source. Move the working batch to existing `REOPENED`, clearing current validation/approval/release pointers consistently with E07; append the submitted revision/decision through the existing Save logic. Preserve `released_at` and all historical release rows. **Do not call E09 unchanged:** the bridge preserves the original Handoff header and its captured lines. Retaining it while reopening is structurally plausible from inspected guards, not executed proof.
3. Derive a canonical current family from **all current positive Need contributions**, with exact School/customer/location/Unit, decision, policy and underlying generation membership. For unchanged facts, prove their equality to the original released Handoff membership. For corrections, prove the stable identity, authentic linear predecessor decision/revision, unchanged theoretical/source membership and original released ancestry. Old Handoff quantities are a witness, never a competing current total. A changed source composition/policy or ambiguous/missing evidence fails closed to its governed upstream correction route.
4. Only affected families need new accepted supplier decisions. Rebalance is advisory. Existing saved splits must not silently assign an increase, including a one-Supplier prior allocation. Unchanged families keep existing revision/split IDs; shared-family changes still require the whole family to balance. No re-Save of unrelated families is required by the proposed branch.
5. **Preparation owns transfer authorization.** Amend `prepare_school_catering_purchase_orders`, retaining `confirmed_need_release.release` and `procurement.school_catering.write`, exact date and full represented scope. For each affected, balanced, explicitly accepted family, generate an affected-only allocation source-binding successor using existing `CONFIRMED_NEED` columns/contributions. Preserve the accepted split values, notes, decision origin and predecessor family revision; record the generation as transfer support, not a fresh human allocation decision. Its `command_id` belongs to one backend-generated transfer child receipt inside the outer Preparation transaction, following the existing internal-child receipt pattern. No unchanged Need line, decision, allocation family or Handoff is cloned.
6. **Exact witness:** that generated family revision must directly resolve its `command_id` to a completed `atlas_core.command_receipts` row for proposed internal command identity `prepare_corrected_need_transfer`, authorized only inside this approved Preparation branch. The receipt's immutable result must name that exact prepared family revision, its predecessor accepted allocation, current Need revision/decision/member IDs, source fingerprint, batch/version, initial `confirmed_need_release_id`/Handoff witness, parent Preparation command ID and exact positive supplier closure. Require equality against the consumed relational facts. An allocation Save receipt, generic earlier Preparation, batch-level boolean, matching total, hash alone or historical receipt-payload search is insufficient. These proposed receipt fields and their integrity checks require contract review; current receipts do not already supply this proof. If existing receipt/revision immutability cannot enforce it, **stop**; a new evidence relation needs a separate decision, not improvisation.
7. PO creation/replacement/release may consume a complete supplier/date set of unchanged `PURCHASE_HANDOFF` splits and **only the proven transferred** `CONFIRMED_NEED` successors. Strict XOR remains at each contribution; do not blend both sources within one contribution or count a family twice. A later allocation/Need Save changing this family's exact bound facts removes its eligibility until Preparation authorizes those facts again. Captured batch version may be older than current; an unrelated family's version advancement alone must not invalidate an unchanged fingerprint, membership or prepared identity. Normal pre-Handoff Confirmed-source drafts never gain official eligibility from this amendment.
8. Keep the current full-batch RMVP-06/07 compatibility release meaning and public APIs unchanged. The new bridge must apply every relevant current-source, exact quantity, policy, reason, membership and corruption rule; it cannot call mixed observations a legacy full-batch approval or fabricate its validation evidence. Generated transfer evidence belongs to the Preparation receipt, with a separately approved meaning.

**Receipt sequencing choice:** the internal transfer child has a deterministic identity/key derived from the parent command and a closed payload naming all prepared families. It checks the same Actor/release capability and scope, appends the affected-only successors, and completes its exact witness response **before** any Draft/frontier consumer executes. The outer Preparation then creates/checks its Draft support and completes its own receipt. Both receipts and all business writes are in the same PostgreSQL transaction; a later child/coverage/guard failure rolls back the completed transfer child and successors together. No external session can observe the witness before commit. Do not admit a generic `IN_PROGRESS` receipt or complete the outer receipt early and rewrite its response afterward. This is one proposed generated command-receipt identity, not a public RPC, new permission, table, lifecycle or separate staff task. It is needed to avoid circular receipt completion; its private invocation, exact payload, immutable completion and rollback behavior require executable proof. [E12:881–1003; E19]

This proposal creates **no new independently authored business concept**, but it changes authoritative transfer and official-PO validation rules. It therefore requires a Class C freeze amendment to D-037/RMVP-07/Procurement, plus aligned PXK interpretation. No new table, status, permission or public RPC is proposed. A versioned existing envelope and a shared private proof/selector are justified because every consumer must enforce the same boundary.

### D2. Command flow and immutable chains

```mermaid
sequenceDiagram
  actor Staff
  participant Need as Existing Need Save (proposed correction branch)
  participant Allocation as Existing allocation workbench / Save
  participant Prepare as Existing Preparation (proposed transfer branch)
  participant PO as Existing D-044 replacement / release
  Staff->>Need: New quantity + reason + expected predecessor/version
  Need->>Need: Revalidate, append one R+D, retain original release/Handoff
  Need-->>Staff: Saved quantity + affected families/POs + required review
  Staff->>Allocation: Review / explicitly save affected splits
  Allocation-->>Staff: Authoritative exact balance and source
  Staff->>Prepare: Explicit Preparation
  Prepare->>Prepare: Validate current closure; receipt-bound affected source successors
  Prepare-->>Staff: Draft/frontier readiness; no official issuance
  Staff->>PO: Review complete replacement Draft linked to PO-001
  Staff->>PO: Explicit release with expected Draft/source identity
  PO->>PO: Revalidate; issue PO-002; atomically supersede PO-001
  PO-->>Staff: New number, historical link, PXK impact
```

`R1/D1 → R2/D2 → R3/D3` is the Need chain. Unchanged lines stay at their existing R/D. `PO-001 ← PO-002 ← PO-003` uses existing `replaces_purchase_order_id`; each release preserves old number, line/output snapshots and exports. Preparation never issues a number. A PXK successor is its own independent explicit release; no automatic document rewrite follows PO release.

### D3. Required authoritative readback

The versioned Save response and subsequent canonical reads must disclose: saved old/new quantities and variance, exact R/D/predecessor IDs, actor/reason/time, base released evidence, affected families and old/new supplier contributions, affected whole PO identities/status, pending allocation review, pending Preparation, pending replacement issuance, cancellation blocker and exact PXK coverage impact. These are derived outcomes, not independently editable statuses.

A committed Save may truthfully say that allocation review/replacement issuance remains required. It must never claim the supplier order is updated or report an unexplained generic success. Pending calculations or unavailable evidence must be distinguishable from complete zero supplier demand. UNKNOWN or failed authoritative readback disables further writes until refresh. React renders backend results; it calculates neither definitive supplier totals nor impact/currentness.

## E. Impact grain, document closure and PXK

The comparison grain is **service date × School × captured delivery location × Ingredient × controlled Unit × Supplier contribution**. `school_catering_allocation_families` groups date/location/Ingredient/Unit; School remains in its plural contributions. Same location does not merge School authorization or erase source ownership. Supplier contribution comes from exact saved splits, not an automatic assignment of the correction delta. [E11, E12, E18]

Currentness must compare both directions of exact membership: additions, removals, source revisions/decisions, quantities, supplier split IDs/notes and source membership matter. Equal totals are insufficient. Determine impacted supplier/date documents from the union of old issued coverage and new complete accepted contributions. Reconstruct each affected supplier's **entire** date document across all Schools, locations and Ingredients. Do not apply a School filter to trim a replacement document. Unchanged supplier/date PO roots, numbers and snapshots remain untouched where their complete source set remains identical. [E13–E16]

Dependency map:

```text
Menu / Attendance / Pantry source IDs and Need Generation release members
  → current Need R + authentic D + policy / source membership
  → current allocation family (all School contributions) + accepted supplier splits
  → original Handoff witness OR approved exact Preparation transfer witness
  → whole supplier/date PO source set + released immutable PO revision/lines
  → exact School/date/location PXK source set and fingerprint
```

**PXK:** `atlas_dispatch.school_dispatch_releases`, `school_dispatch_release_lines` and `school_dispatch_release_line_sources` preserve Need revision/decision, allocation revision/contribution/split and PO root/revision/line IDs. The existing preview hashes these identities. A stale shared supplier/date PO can block School A after only School B changes. Once its complete replacement is released, A may become ready but require `REPLACEMENT_REQUIRED` because the PO identities in A's frozen PXK differ. Preserve this rule; “unchanged quantity” does not promise “unchanged PXK”. Unrelated supplier/location documents remain excluded where the exact existing contract permits. Existing tests record both shared blocking and unrelated exclusion. [E17; `supabase/tests/school_dispatch_release.sql`:664–682, :1137–1170, :1266–1281, :1366–1494]

The bridge must amend PXK's source selector together with Procurement's; leaving a Handoff-only preview would make the correction unusable. `get_school_dispatch_release_workbench` continues to derive `BLOCKED`, `READY`, `CURRENT` or `REPLACEMENT_REQUIRED`; `release_school_dispatch_document` alone creates a numbered immutable successor. Historical PXK sources/content and exports remain readable. Exact School scope from E18 must not expand to sibling Schools sharing a location.

## F. Transactions, locks, authorization and recovery

### F1. Existing protocol to preserve

E19's receipt identity is Actor + aggregate scope + command name + idempotency key, with a unique command ID. Canonical request hash includes contract, command/key, expected version, requested subject, reason/note and payload; it excludes correlation/request timestamp. Exact completed replay returns stored response; changed payload or scope conflicts. Do not weaken that comparison or invent client numbering.

Existing locks are command-specific, not one proven universal order:

- Save: batch `FOR UPDATE`, submitted stable lines by UUID, controlled Units, canonical preview and deferred guards. [E01]
- Source correction: run advisory key → Need run → batch → Handoff, then recheck. Its whole-Handoff invalidation is not the proposed quantity branch. [E09, E10]
- Confirmed allocation: batch/current Need bindings → Ingredient aggregate → Suppliers/eligibility → applicable Handoff → family/current revision. Later amendments require supplier evidence before family locks and a reread after waiting. [E12, E16]
- Replacement/release: supplier/date advisory key → ordered supplier/eligibility and source-family evidence → family/current revision locks → PO root/current revision; replacement supersession locks its active predecessor in the same transaction. [E13, E14]
- PXK: School/date/location advisory key → upstream allocations and date PO locks → exact current PXK → reread expected version/predecessor/fingerprint. PO read-lock scope may cover all date POs; mutation scope remains exact. [E17]

### F2. Proposed coordinated correction protocol

The bridge must establish and test one compatible order for overlapping writers. Proposed extension: retain receipt serialization; acquire sorted relevant supplier/date advisory keys **before** the common Need-root lock for correction-sensitive commands; then Need batch/current lines and original release witness; then sorted Ingredient/Supplier/eligibility evidence; then family roots/current revisions; then sorted PO roots/predecessors. Units/policies/Need Generation source evidence follow the same relative ordering as the existing canonical Need validator, before family mutations. Acquire PXK roots only in PXK release, last after its upstream locks. No command may acquire a later family/PO lock and then wait for an earlier Need lock.

This is a requirement for the future shared lock protocol, not a claim current commands already comply. Initially discover keys, lock them in canonical order, then reread the complete closure under the common Need root. If source/supplier membership changed during discovery, abort with a source/version conflict; do not dynamically acquire a new earlier-order key. New suppliers, removed suppliers and same-total membership changes participate. Two-session tests must include Save versus allocation, Preparation, PO release and PXK release; incompatible existing helper ordering is an implementation stop, not permission for broad lock refactoring.

| Boundary             | Expected facts / authorization / atomic result                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Correction Save      | Expected batch version and each submitted `expected_current_revision_id` / `expected_current_decision_id`; versioned correction envelope also binds expected base released/Handoff identity and exact source fingerprint. Existing v2 lacks these extra correction fields; do not silently accept them. Conservative capability union in D1 plus GLOBAL; validate every bound School/customer/location. One transaction commits R/D, working pointer change, receipt/event/audit and impact/readback together; no PO mutation. |
| Allocation Save      | Existing family `expected_version`, `expected_source_fingerprint`, `expected_source_batch_id`, `expected_source_batch_version`; `procurement.school_catering.write`, exact represented contribution scopes and eligible Supplier evidence. Conflicting concurrent split Save loses and refreshes.                                                                                                                                                                                                                              |
| Preparation          | Existing expected saved batch version plus versioned exact closure/witness bindings; existing release/write capability union and complete-day scope. Revalidate every current family/Need/source, policy, split, Supplier and date. Complete the internal transfer child receipt before consuming its successors in Draft/frontier support; complete the outer Preparation receipt last. Any child failure rolls all child receipts and new business support back. No partial supplier commitments.                            |
| Replacement creation | Existing predecessor PO expected version/current revision; exact supplier/date and full source set, scoped through every represented School/customer/location. Draft has no official number; reject incomplete/zero sources. Read response identifies entire content and predecessor.                                                                                                                                                                                                                                          |
| Official PO release  | Existing Draft expected version/current revision; revalidate current source closure, prepared witness, Supplier eligibility/document code, quantities/Units, predecessor and absence of competing current commitment. Backend generates distinct official number and atomically supersedes only its direct released predecessor.                                                                                                                                                                                               |
| PXK release          | Existing scope version/predecessor and expected source fingerprint; `dispatch.school_release.release` with exact School/customer/location capability/scope checks. Revalidate whole-PO coverage. Explicit successor only; rollback preserves previous release.                                                                                                                                                                                                                                                                 |

Existing PO capability is `procurement.school_catering.write`; preserve the actual command's capability checks and complete-document relational scope. Confirmed Need GLOBAL authority is not evidence that a narrower Procurement/PXK Actor owns every School in a shared document. No new grants, service-role browser access, RLS bypass, trigger disablement or private-table client access is proposed. [E01, E12–E19]

**Two operators:** same batch/version corrections serialize; at most one wins. A later independent command must use refreshed R/D/source IDs. Exact duplicate replay creates neither duplicate decisions nor official numbers. Changed-payload retries conflict. A correction racing issuance must either precede source revalidation and block stale release, or follow the committed release and expose it as the predecessor requiring replacement.

**UNKNOWN transport:** preserve the original command/key/payload, disable mutations, refresh authoritative Need/allocation/PO/history and receipt-backed results. Do not auto-retry or create a fresh command to guess the outcome. Use an exact retained replay only through the existing deliberate recovery path after certainty/authorization checks; a truly lost response can recover the original number without another release. No new receipt-read RPC is assumed. If readback cannot establish the exact command outcome, remain UNKNOWN. Save's reviewed `NO_COMMITTED_CHANGE` and preauthorization `NO_BUSINESS_WRITE` remain distinct from transport uncertainty; E19's later patch supersedes E01's original exception wording.

## G. Performance architecture and historical negative evidence

Let `k` be submitted changed lines, `c` their source-contribution rows, `n` current day lines, `a` affected allocation families, `s` accepted supplier splits, `p` rows in complete affected supplier/date documents, and `h` retained history depth.

| Work                         | Proposed access / honest limitation                                                                                                                                                                                                                                                                                    |
| ---------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| One corrected line           | One current batch, one stable line, current revision/decision and immediate predecessors, original release/Handoff witness, exact policy/Unit/run/release members and that line's `c` contributions; plus receipt/event/audit. Not “one-row work”. Existing validation/readback may inspect the complete `n`-line set. |
| Preserve unchanged decisions | Zero new decision or revision writes. Current-set validation may read all `n`; retaining an ID is not permission to skip authority proof.                                                                                                                                                                              |
| Affected families            | `a` is distinct changed date/location/Ingredient/Unit keys; a shared key includes all contributor Schools. Only affected accepted allocations receive generated transfer successors.                                                                                                                                   |
| Complete supplier/date PO    | `p` includes every current positive split for each affected Supplier/date, including untouched Schools and Ingredients. Full reconstruction/revalidation is unavoidable at document commitment.                                                                                                                        |
| Historical snapshots         | Operational selector reads direct base/current witnesses and exact current source bindings; it must not replay every past full-day Planning/Handoff snapshot to derive current quantities. Existing historical corruption guards still run and may read retained history.                                              |
| Growth with `h`              | Appended Need decision/revision and PO history grows. H1B1 validates chain history; RMVP-07 integrity scans retained approval/release rows. Deferred checks and complete readbacks can repeat work. No constant-time or history-independent runtime claim is established.                                              |
| Avoided structural work      | No whole-day new validation/approval/release/Handoff generation on every quantity correction, no per-unchanged-line source promotion and no currentness reconstruction by recursive whole-Handoff overlays. This removes a source of new history, not measured existing guard cost.                                    |

E04's decision integrity and E07's historical approval/release guards must remain active. A completed receipt, hash, new current flag or new helper is not permission to trust corrupt/missing history. Avoid reverse-scanning receipt payloads for a witness: prepared revision → `command_id` → exact receipt must be a direct lookup. Existing repeated canonical evaluations, per-row deferred guards and release-projection calls are **risks identified for future measurement**, not authorization to optimize or narrow them here.

| Historical source                                                                                                                 | Recorded positive evidence                                                  | Recorded failure / implication                                                                                                                                 |
| --------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [Draft #388](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/388), head `a443daf15dd9891611b387349268795efbce7d5c`          | 588 focused assertions; one 250-family journey 20/20; Preparation 17.515 s. | Eight-cycle test stopped in cycle2 at >20 s; 1/8 cycles, 0/20 final assertions; Full Integration skipped. Single-cycle success did not certify history growth. |
| [#394 finding](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/394#issuecomment-6230584611)                               | “SIMPLIFY WITHIN MODEL”; scoped architecture review completed.              | 265 validation calls within 253 retained-release calls; inclusive timings overlap. No accepted optimization or exclusive timeout attribution.                  |
| [Draft #396](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/396), evidence head `fad9b3475cff1063a6fad2ac67a75519e94debb5` | 597 focused assertions; two journeys 36/36; Preparation 10.213/15.063 s.    | Eight-cycle failed in cycle4 >20 s; 3/8 cycles, 0/20 final assertions. Frontend/Smoke green, Full skipped. Two cycles do not prove bounded historical cost.    |
| [#397 disposition](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/397#issuecomment-6232963725)                           | B3 accepted; Option B deferred.                                             | “Never reread historical evidence” had no equivalent missing/corrupt-history proof. Do not turn a certificate/hash into an integrity bypass.                   |
| [#398 rejection](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/398#issuecomment-6233516810)                             | Isolated append probe retained genuine predecessors.                        | DRAFT→DRAFT-or-RELEASED alone rejected: complete membership, transitions and deferred guards also participate.                                                 |
| [#399 STOP](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/399#issuecomment-6234682240)                                  | 41 focused +210 regression assertions; 100→110→90 retained earlier facts.   | 236-line mixed approval exceeded unchanged8 s; remaining security/concurrency/CI proof incomplete. Operational acceptance failed.                              |

All numbers are historical reports, not new measurements. The [later #398 Product clarification](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/398#issuecomment-6236478745) and #400 approve the replacement outcome without reviving these strategies.

**Future independent acceptance:** retain public8 s, Preparation20 s and existing1 s entry constraints. For the new contract, propose a separately named 50-School ×5-Ingredient/250-family fixture with at least236 retained mixed revisions,1/25/250 changed-line batches where representable, multi-Supplier whole-document closure, and history depths0/1/3/10/25. Measure individual Save, allocation Save, Preparation, replacement creation/release and PXK commands with intact guards, concurrent-session/rollback/UNKNOWN checks and recorded row/witness counts. No measurement occurs in this gate. This is a proposed independent staff/history envelope, not a rerun or PASS of the failed legacy eight-cycle design. Two same-root failed approaches stop for diagnosis/Owner decision; deadlines are never increased to certify success.

## H. Future acceptance matrix — not executed

| ID    | Fixture / action                                                                                         | Required assertions                                                                                                                                                                                                                                                                                          |
| ----- | -------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| C-01  | Confirmed100→110, reason supplied                                                                        | One genuine R2/D2; exact R1/D1 predecessors, actor/reason/time/receipt; source and original theoretical/proposal evidence retained; untouched IDs unchanged; authoritative110 and required downstream actions disclosed. Run through public API with normal triggers.                                        |
| C-02  | Issued PO-001100; correct to110                                                                          | Old100 content/number/output snapshots and export unchanged; explicit accepted allocations; complete110 replacement Draft; no Draft number; independent release gives distinct PO-002 and atomically supersedes PO-001; no +10 order and no automatic release.                                               |
| C-03  | Then110→90                                                                                               | Genuine R3/D3 direct chain; complete90 PO-003 on separate release; PO-001/002 remain reproducible; no bulk cloning or skipped guards; subsequent correction before prior replacement issuance must also fail closed or preserve the exact unissued chain without stale issuance.                             |
| C-04  | Need100; A60/B40→Need110                                                                                 | Both old/new Supplier/date impact sets disclosed; rebalance proposal remains advisory; Save does not assign the extra10. Explicit accepted full-family splits balance110; affected complete supplier POs include every represented School; unaffected supplier docs retain IDs.                              |
| C-05  | Two Schools share location, shared and separate suppliers                                                | Exact School contributions/location/Unit; no sibling-School scope leakage; complete whole supplier/date PO; shared stale PO may block other School; replacement identity can require other School PXK successor; unrelated School/supplier/date documents retain validity where exact coverage is unchanged. |
| C-06  | Issued Supplier A becomes zero                                                                           | Complete current source/split closure distinguishes proven zero from incomplete review; `CANCELLATION_REQUIRED`, old PO remains active, no empty replacement, no silent cancellation; relevant PXK blocked until a separately approved cancellation process.                                                 |
| C-07  | Same total100, different source membership/composition                                                   | Exact source/member/decision fingerprint changes; old Draft/witness is stale. Quantity-only bridge rejects changed theoretical source/policy until its governed source correction is valid. Equal totals never preserve obsolete authority or conceal scope movement.                                        |
| C-08  | B1 R20/B5/H3, confirm30                                                                                  | Display25+3, theoretical28, final30 and human+2; distinct B/H source IDs/purposes and Recipe evidence preserved; valid transferred PO/PXK consume30; no Recipe/BOM rewrite, source suppression or historical COMPLETE mutation.                                                                              |
| C-09a | Wrong Actor, capability, School/customer/location or shared-document scope                               | Denial before business effects; exact School scope does not authorize siblings. GLOBAL Need access does not silently authorize downstream documents. No new grants.                                                                                                                                          |
| C-09b | Stale batch/revision/decision/family/PO version, stale source fingerprint                                | Explicit conflict plus refresh; zero new business facts; same-total different-membership conflict included.                                                                                                                                                                                                  |
| C-09c | Two corrections; correction versus allocation/Preparation/PO/PXK release                                 | Deterministic lock order; at most one winner per expected state; fresh evidence after waiting; no deadlock-dependent partial result or stale official issuance.                                                                                                                                              |
| C-09d | Duplicate exact replay / changed-payload retry                                                           | Exact original IDs/response/number; no duplicate R/D or commitments; changed payload/key/Actor scope conflicts.                                                                                                                                                                                              |
| C-09e | Failure after each write stage / missing or corrupt old decision, release or contribution                | Full business rollback; no false successful correction, transfer witness, partial supplier commitment or invented approval. All RLS and historical guards remain enabled.                                                                                                                                    |
| C-09f | Supplier deactivation/eligibility/code changes before issuance                                           | Recheck at commitment; missing Supplier code blocks; B2 null Ingredient code remains allowed; no old snapshot relabeling.                                                                                                                                                                                    |
| C-09g | Lost Save, Preparation or release response / successful write with failed readback                       | UNKNOWN blocks writes until authoritative recovery; exact command recovery returns original result; never allocate a second official number.                                                                                                                                                                 |
| C-09h | Missing/extra supplier-date source, arbitrary editable Confirmed allocation or wrong Preparation receipt | Incomplete or unauthorized replacement rejected atomically. Any completed receipt/hash alone is insufficient; prove exact consumed source and scope.                                                                                                                                                         |

Security/corruption acceptance must alter or remove historical evidence in disposable privileged fixtures and then exercise the normal command with guards enabled. Fixture setup privileges are not proof that authenticated commands can bypass them. No production or hosted writes are implied.

## I. OPS v1 workflow evidence and future Receiving boundary

The exact Retool export exists at `C:/Users/HOME/Downloads/OPS - Lên đơn, Đặt hàng (1).json`,2,770,252 bytes, SHA256 `6f6ff8d025696d375f354a86126661d20c3e9908d6475d40ecb14ee006b4a371`. It was inspected read-only; no embedded script/query was executed and no Retool/v1 connection was made.

For reproducible decoded references, let `P = JSON.parse($.page.data.appState)[1][4][62][1]` and `Q(i) = P[i][1][4][18][1]`.

| Evidence                                    | Decoded location                                                           | Meaning and limit                                                                                                                                                                          |
| ------------------------------------------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| “Lưu số lượng” → `js_ppwb_save_actual_need` | Button `Q(347)[15]`/events `[31]`; script `Q(403)[37]`; query `Q(559)[41]` | Saves actual-need overrides through `public.app_upsert_actual_need_overrides_bulk`, then refreshes. Quantity Save does not promise supplier assignment persistence.                        |
| “Lên đơn” → `js_ppwb_assign_defaults`       | `Q(563)[15]`/`[31]`, `Q(557)[37]`, query `Q(555)[41]`                      | Rebalances selected School/date keys through `public.fn_rebalance_purchase_assignments_for_keys_fast`; does not save overrides.                                                            |
| “Lưu đơn” → `js_ppwb_detail_save`           | `Q(351)[15]`/`[31]`, `Q(161)[37]`, query `Q(389)[41]`                      | Reviews positive family splits/balance and calls `public.app_replace_purchase_assignments_family_planner`.                                                                                 |
| PO/PXK exports                              | PO `Q(187)[37]`, `Q(155)[37]`; PXK `Q(195)[37]`, grouped `Q(553)[37]`      | Read persisted PO/dispatch datasets and their quantities. This export alone does not establish deployed stored-function internals, security or immutable new-number replacement semantics. |

Retain the simple staff sequence. Do not copy direct-update overrides, overwrite history, client arithmetic or legacy tolerances as Atlas authority.

Future Receiving must record the supplier-presented PO reference, actual delivered and accepted quantities and discrepancy against the current commitment. A delivery of100 against current110 can still cite old PO-001 and must remain explainable. Payment follows accepted actual receipts and applicable agreements. Receiving, Warehouse, invoicing/payment, communications and contingency SOP approval are outside this gate and the conditional rollout below.

## J. Alternatives and exact Owner choices

| Alternative                                                                   | Decision                                                                                                                                                                         |
| ----------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Existing full-day reopen/reapprove/rerelease/rebuild Handoff                  | Reject for this task: reproduces mixed-revision conflict and retained-history growth; violates the requested ordinary correction boundary. #388/#396/#399 are negative evidence. |
| Permit `DRAFT` or `RELEASED` by status alone                                  | Reject: lacks exact retained decision/release/member authority and does not fix snapshot/transition/PO guards.                                                                   |
| Partial Handoff header or extra changed line inside old header                | Reject: current selector reads the current whole header; unique header/line membership and no line current-head protocol make this a larger new Handoff contract.                |
| Arbitrary saved Confirmed allocation directly produces official PO            | Reject: Save is not Planning transfer release. An exact authorized Preparation witness is mandatory.                                                                             |
| New correction aggregate/state machine, cloned unchanged R/D, supplemental PO | Reject: duplicates existing human authority or violates immutable complete replacement meaning.                                                                                  |
| Existing typed affected-family bridge with exact Preparation witness          | Recommend for approval and bounded proof. No claim of executable safety or speed yet.                                                                                            |

The Owner decision is specific:

1. Approve or reject the revision-bound transfer rule in D1, replacing the **sole current whole-Handoff source requirement only for exact post-release corrections**. Preserve the initial flow and historical commitment meaning.
2. Approve the conservative post-release Save capability union and one-transaction working-reopen/correction semantics; preserve unchanged original Handoff evidence and derive per-family applicability.
3. Approve affected-only generated source-binding successors whose exact Preparation receipt authorizes transfer, with strict exclusion of arbitrary saved drafts and unchanged compatibility APIs. No new schema object is preapproved if the witness cannot be enforced with existing relations.
4. Retain exact PXK shared-PO identity consequences and zero-Supplier cancellation stop; approve the independent acceptance envelope in G without changing legacy deadlines/results.

**Concluded gate: DECISION REQUIRED.** There is a source-supported minimum candidate using existing objects, but it changes an accepted authoritative validation boundary. It is neither `GO — EXISTING AUTHORITY SUFFICIENT` nor a demonstrated impossibility. The documentation can be reviewed as one docs-only Draft; implementation awaits separate explicit Owner approval.

## K. Conditional minimal rollout — do not execute

Each checkpoint requires an independently reviewable bounded task and exact-base verification. Approval of the business outcome or this document's publication is not implementation approval. Execute only one implementation checkpoint at a time. If an allowlist must expand, stop and describe the exact dependency before changes.

Checkpoints1–3 are isolated, unmerged Draft development checkpoints. Do not activate a post-release Save route for operational users before checkpoints1–4 demonstrate the complete transfer/replacement path and receive separate rollout approval. An unfinished Procurement bridge is not an acceptable operational “saved, transfer pending” state; pending review is truthful only when its authorized next commands actually exist. No feature flag, new lifecycle or partial hosted rollout is authorized here.

| Checkpoint                                          | Deliverable and reuse                                                                                                                                    | Amendment and acceptance gate                                                                                                                                                                                                                                                                                         |
| --------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1. Need correction authority and validation         | Reuse existing Save append/preview, H1B1, D-040, D-046, receipts. No alternate quantity writer.                                                          | Versioned released Save branch, exact source/ancestry proof, atomic REOPENED pointers and explicit impact readback. Public authenticated C-01/C-03/C-07/C-08 and negative/security/rollback tests with intact guards. No Procurement official-source expansion yet; readback must state transfer/replacement pending. |
| 2. Procurement transfer and replacement integration | Reuse family/split/contribution relations, D-044 replacement root/numbering/supersession, B2 snapshots. Keep original initial release/Handoff unchanged. | Canonical selector, affected allocation review, successors bound to completed internal transfer receipts, complete mixed-source document coverage/guards, PXK selector alignment and lock protocol. Prove C-02/C-04/C-05/C-06 and normal initial-flow compatibility.                                                  |
| 3. Operator workflow/readback                       | Reuse current controllers, draft/dirty/UNKNOWN handling and exports. No frontend authoritative calculations.                                             | Existing Save → affected allocation → Preparation → complete replacement review → explicit release/history; truthful required-action messages and exact School impact. Focused adapter/controller/browser tests.                                                                                                      |
| 4. Exact SQL, frontend and connected acceptance     | Reuse normal CI and browser-key harnesses.                                                                                                               | Disposable full migration application; focused negative/concurrency/history assertions; exact-head Frontend CI, Smoke and actually executed Full Integration; independent new history envelope; distinguish CI skip from pass. No hosted deployment implied.                                                          |
| 5. OPS v1 parity rehearsal                          | Reuse approved operational inputs, B1/B2, PO/PXK exports.                                                                                                | Representative daily journey and capability matrix `REPRODUCED / DIFFERENT-BUT-ACCEPTED / MISSING / BLOCKED`; shared location, two Pantry sources, quantity changes, splits, PO/PXK history, concurrency/UNKNOWN. Future actual Receiving remains explicit. Stop for Product review.                                  |

### K1. Proposed file/function/test allowlists

Migration names below are descriptive future slugs, not files created by this task. Generate the timestamp through the normal migration tool only after approval. Do not edit any applied migration or import #388/#396 SQL.

**Checkpoint1 file allowlist:** one forward `supabase/migrations/<generated timestamp>_atlas_c_need_correction_authority.sql`; one new `supabase/tests/atlas_c_need_correction_authority.sql`; focused additions to `supabase/tests/d037_confirmed_need_save_release_boundary.sql`; the affected API/decision/task documents named below. Function changes restricted to `atlas_api.save_confirmed_needs(jsonb)`, `atlas_core.d037_validate_command(jsonb,text)`, `atlas_core.d037_extend_workbench(jsonb,uuid)` and existing Save/read integration necessary for the versioned branch. One proposed private exact correction proof, `atlas_core.atlas_c_need_correction_authority(uuid)`, may centralize current line/decision/source/release-witness classification. It is a derived read/validation helper, not a new persisted authority or permission. Keep `issue_222_reopen_confirmed_need`, RMVP-06/07 compatibility commands, decision/approval/release corruption guards unchanged. If their unchanged guards reject the bounded branch, stop with the exact predicate and obtain a narrower amendment; do not relax them.

**Checkpoint2 file allowlist:** one forward `supabase/migrations/<generated timestamp>_atlas_c_procurement_transfer_bridge.sql`; one new `supabase/tests/atlas_c_need_po_bridge.sql`; focused additions to `supabase/tests/purchase_review_confirm_release.sql`, `supabase/tests/school_catering_purchase_orders.sql`, `supabase/tests/school_dispatch_release.sql`. Function amendment candidates, limited to this source path:

- `atlas_core.school_catering_family_projection(date,uuid,uuid,uuid)` and existing `purchase_review_confirmed_sources`, `purchase_review_confirmed_projection`, `purchase_review_persist_allocation`, `purchase_review_allocation_integrity_guard`, `purchase_review_preparation_status`, `purchase_review_po_coverage` for one canonical current-source/witness protocol. Do not broaden `purchase_review_allocation_ready` for the initial/compatibility release path.
- `atlas_api.get_confirmed_supplier_allocation_workbench`, `save_confirmed_supplier_allocation`, `prepare_school_catering_purchase_orders`, `create_school_catering_purchase_order_drafts`, `create_school_catering_purchase_order_replacement`, `release_school_catering_purchase_order`, `get_school_catering_purchase_orders` (all existing `jsonb` signatures). Reuse replacement/number/supersession bodies except the exact required source and locking amendments. Preserve the Handoff allocation writer's original source meaning.
- `atlas_core.school_catering_po_date_readiness`, `school_catering_po_draft_is_stale`, `school_catering_po_commitment_state`, `school_catering_procurement_date_current`, `purchase_order_revision_integrity_guard`, and `school_dispatch_release_preview` for coordinated exact mixed-source acceptance. Reuse `release_school_dispatch_document` unchanged if its preview/lock contract suffices; any lock change must be explicitly reviewed. Existing exact scope helpers, receipt helpers, official-number generator and replacement supersession guard remain unchanged.
- One proposed private `atlas_core.atlas_c_transferred_family_authority(uuid)` may check the consumed family revision's exact completed Preparation witness. No separate public RPC, certificate flag, role, capability, table or grant is allowed by this candidate list.

**Checkpoint3 file allowlist:** existing `src/modules/atlas/planning-inputs/confirmed-needs/confirmedNeedApi.ts`, `confirmedNeedModel.ts`, `confirmedNeedReadAuthority.ts`; `src/modules/atlas/procurement/schoolCateringProcurementApi.ts`, `schoolCateringProcurementModel.ts`; `src/modules/atlas/dispatch/schoolDispatchReleaseApi.ts`, `schoolDispatchReleaseModel.ts`; `src/vnext/atlas/planning-confirmed/useConfirmedNeedWorkbench.ts`, `ConfirmedNeedWorkbench.tsx`, `ConfirmedNeedCommandFeedback.tsx`, `ConfirmedNeedSupportDetail.tsx`; `src/vnext/atlas/procurement/useProcurementWorkbench.ts`, `ProcurementWorkbench.tsx`, `ProcurementOrdersStage.tsx`, `ProcurementCommandFeedback.tsx`; `src/vnext/atlas/dispatch/useSchoolPxkWorkbench.ts`, `SchoolPxkWorkbench.tsx`, `SchoolPxkCommandFeedback.tsx`. Use only the subset needed for authoritative field routing/presentation. Matching existing `.test.ts`/`.test.tsx` files and one proposed connected journey `scripts/verify-local-atlas-c-need-po-bridge.mjs` are allowed. No template restyling, new dependency or business arithmetic in React.

**Documentation allowlist across approved checkpoints:** this gate record plus `docs/api/confirmed-need-save-release-v2.md`, `docs/api/school-catering-procurement.md`, `docs/api/school-dispatch-release.md`, `docs/decisions/decision-confirmed-need-save-release-boundary.md`, `docs/decisions/decision-ops-v1-school-fulfilment-closeout.md`, `docs/architecture/planning-procurement-business-freeze.md` and decision/business-rule registers, only for the exact Owner-approved supersession. Add a dated amendment rather than silently rewriting old evidence. No changes to B1/B2 meaning.

**Required retained test sources:** RMVP-05/06/07, H1B1 chain/policy/security, selective continuity, Issue #222, normal Handoff/allocation/PO, B1 composition/two-source, B2 PO output and School PXK exact-scope suites. New correction acceptance must enter through normal public authenticated commands; no disabled triggers/replication-role bypass in the asserted journey. Run focused development checks; leave the full routine frontend suite to normal GitHub Actions. The current Frontend workflow targets PRs to `main`, so a docs-only stacked-base PR may have no automatic Frontend run; do not report that as PASS.

### K2. Copy-ready next Codex task — conditional checkpoint1 only

```text
ATLAS-C-NEED-CORRECTION-AUTHORITY-01 — execute only after explicit Owner approval

Repository: longpsu-bot/thuonghao-ops-erp. Read AGENTS.md, both Autopilot documents,
Issue #400/latest Owner comments, and the approved version of
docs/implementation-tasks/ATLAS-C-NEED-CORRECTION-ARCHITECTURE-GATE-01.md.

Precondition: record the exact Owner approval of section J, approved gate commit,
and authorized implementation base. If approval/base is absent, STOP with
DECISION REQUIRED; do not infer approval from a Draft PR or green CI.

Use a clean independent worktree at that approved base, preserve all ancestors,
stashes and Drafts, verify root/origin/fetch/head/status/pnpm ops:workspace, and
create one bounded task branch. Do not rebase/merge/deploy or write hosted data.

Implement checkpoint1 ONLY, within K1's checkpoint1 migration/function/test/doc
allowlist. Extend the existing save_confirmed_needs writer, never add another
quantity writer. First add failing public authenticated tests for released
100->110->90, exact predecessor R/D, untouched IDs, initial release/Handoff
retention, R20/B5/H3->confirmed30, stale/current-source conflicts, capability
union, rollback, replay and UNKNOWN readback. Keep all integrity/RLS guards on.

Use versioned expected batch/revision/decision/source/base-release bindings.
Atomically append authentic decisions/revisions and consistent REOPENED working
pointers; preserve original snapshots and Handoff. Return truthful authoritative
impact and allocation/transfer/replacement-pending readback. Save issues no PO.

Do not amend official PO source guards, execute checkpoint2, change Supplier
splits, fabricate lifecycle validation evidence, optimize SQL, clone unchanged
facts or raise deadlines. If unchanged historical guards reject this branch,
STOP with exact evidence and the minimal additional Owner decision; no bypass.

Run only focused local tests, obtain independent source/security review, then
one meaningful Draft PR with normal exact-head CI. Report SHA/file manifest,
fresh proof versus historical evidence, migration/rollback implications and
remaining transfer/PXK integration gates. STOP after checkpoint1 review.
```

### K3. Rollback and release implications

This design has no database migration or operational rollback. A Git revert removes the proposal document only; it does not rescind Owner decisions or alter issued documents.

Future migrations must be forward-only and version-gated, with no backfill or relabeling of old receipts as transfer witnesses. Old PO/PXK readers/exports must reproduce their frozen snapshots. Before operational use, code rollback can remove new routing; after new corrected authority/transfer/PO facts exist, an old Handoff-only reader is unsafe as a rollback target. Disable the new write route and fail closed on unsupported corrected sources while retaining evidence; restore through reviewed forward correction/compatible readers. Never delete receipts, releases, decisions or snapshots to roll back.

**STOP — await separate Product Owner architecture approval. No implementation starts under this gate.**

## K1 execution stop — 19 October 2026

**BLOCKED / DECISION REQUIRED.** The [Owner's K1-only approval](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/400#issuecomment-6258968878)
was investigated from approved design `96a2f048139e92281eb5cebe1421b28b4c1f14d1`
in an independent `feat/atlas-c-need-correction-authority-01` worktree. This
record does not approve K2 or amend the approved execution/access boundary.

The candidate `RMVP-05.v3` branch in the existing Save writer passes genuine
public-command 100→110→90 successor decisions, unchanged School/Ingredient
identities, B1 R20/B5/H3→30 composition, original release/Handoff/issued PO/PXK
retention, capability/GLOBAL denials, completed replay/changed-payload conflict,
lost-response readback and complete forced-deferred-failure rollback. A real
two-Actor concurrent-session proof observes the second session waiting on a
database lock, then receiving `STALE_CONFIRMED_NEED_BATCH`; exactly one new
revision and one decision result. These are bounded development results, not a
passing K1 checkpoint.

### Reproducible source-currentness blocker

The complete rolled-back reproduction is
[`supabase/tests/atlas_c_need_correction_authority.sql`](../../supabase/tests/atlas_c_need_correction_authority.sql),
under `-- A public compatibility source reopen`. Apply the 113 approved baseline
migrations followed by the candidate
[`20261019033321_atlas_c_need_correction_authority.sql`](../../supabase/migrations/20261019033321_atlas_c_need_correction_authority.sql)
to disposable PostgreSQL, then execute that test with `psql -X -qAt -v
ON_ERROR_STOP=1 -f supabase/tests/atlas_c_need_correction_authority.sql`. Inspect
TAP failures as well as the process exit code; `psql` itself does not fail on a
`not ok` assertion. No trigger, RLS or replication-role bypass is used.

1. Public Menu/Attendance/Pantry Save and Need Generation establish real B1
   evidence, public Preparation releases it, and public K1 Save records 28→30.
2. The authenticated operator successfully invokes existing
   `atlas_api.reopen_weekly_menu(jsonb)` (`RMVP-03A.v1`) with the exact current
   Menu version and a nonempty reason. Its existing guard preserves historical
   approval while setting the current Menu header to `REOPENED`.
3. Fresh public `get_planning_input_preflight` reports `readiness_state=BLOCKED`,
   `downstream_currentness=OUTDATED` and
   `MISSING_WEEKLY_MENU_APPROVAL_SNAPSHOT`.
4. `rmvp_06_canonical_evaluation` still reports `VALIDATED`; the SHA-256 of
   `rmvp_07_validated_facts_projection` is identical before and after the reopen.
   Those functions validate captured Need facts, not fresh upstream authority.
5. Public `save_confirmed_needs` accepts 30→31 using current batch/revision/
   decision IDs, original release/Handoff IDs and that unchanged fingerprint.
   Assertion 73 requires rejection and fails (`have: true; want: false`).

The missing predicate is in the candidate Save's `v_evaluation` / `v_facts`
source-proof branch: it must also prove fresh current upstream source authority
under compatible locks. The existing RMVP-06/07 guards remain unchanged; a
fingerprint of the retained snapshot cannot establish that predicate.

### Runtime access boundary and required decision

The Save owner remains `atlas_confirmed_need_review_runtime`. Catalog inspection
reports **false** for its EXECUTE on all of:

- `atlas_core.planning_contract_01_preflight_payload(date,date,jsonb)`;
- `atlas_api.get_planning_input_preflight(jsonb)`;
- `atlas_api.get_need_generation_workbench(jsonb)`;
- `atlas_core.need_generation_effective_current(uuid)`.

Its SELECT privileges on `weekly_menus`, `attendance_batches` and
`pantry_need_batches` are also false. No grants or ownership changes were made.
Calling the existing fresh-source authority therefore crosses the frozen runtime
access boundary; duplicating an incomplete status/fingerprint check is unsafe.

**Owner decision required:** approve a narrow private fresh-source proof with
explicit runtime access/ownership and upstream lock ordering, or explicitly
revise the K1 source-currentness requirement. Do not proceed by granting access,
changing compatibility commands, weakening historical guards or treating a
retained release as current authority under the present approval.

### Verification disposition at STOP

| Check                                                                     | Actual result                                                                                                                                                                                                         |
| ------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Focused K1 SQL                                                            | **FAIL: 72/73**, source-currentness rejection fails                                                                                                                                                                   |
| RMVP-05/06/07, D-037, three H1B1 suites, selective continuity, Issue #222 | **PASS: 459/459** across nine unchanged suites                                                                                                                                                                        |
| Concurrent authenticated operators                                        | **PASS**, one successor; second stale after lock wait                                                                                                                                                                 |
| Fresh candidate migration application                                     | **PASS**, matches candidate database definitions                                                                                                                                                                      |
| Duplicate direct migration execution                                      | **PASS**, baseline checksum rejects it atomically without catalog change; it is a forward-only migration                                                                                                              |
| Function/runtime catalog boundary                                         | **PASS**, exactly the three allowlisted function bodies change out of 472 Atlas functions; all owners, ACLs, security modes, search paths and volatility preserved; relations, roles, triggers and policies unchanged |
| Independent read-only source/security review                              | **FAIL / STOP**, confirmed the source-currentness blocker                                                                                                                                                             |
| GitHub Frontend / Supabase Smoke / Supabase Full Integration              | **BLOCKED: not dispatched**, failed local acceptance prevents a coherent Draft delivery                                                                                                                               |

Only the candidate migration, focused test and this dated gate amendment are
changed. No API/decision contract claims implementation acceptance. No Draft PR,
push, merge, hosted migration or feature activation occurs at this stop. The
approved starting commit and ancestor branches remain unchanged. Candidate
sources are retained locally for review, including the failing assertion; the
whole test transaction rolls back.

Rollback impact: all writes were in task-owned disposable infrastructure. There
is no hosted rollback. The candidate forward migration has no down migration;
any later authorized installation would need an approved forward repair and
must preserve authentic appended decisions. Do not erase released correction
history. K2 transfer receipts, allocation successors, official PO source changes,
replacement Preparation and PXK successors remain unapproved and unimplemented.

## K1 direct-preflight repair — 19 October 2026

**BLOCKED / concurrency FAIL.** The [subsequent Owner decision](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/400#issuecomment-6259578703),
also [recorded on #406](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/406#issuecomment-6259579922),
authorizes one EXECUTE grant on the existing
`atlas_core.planning_contract_01_preflight_payload(date,date,jsonb)` to
`atlas_confirmed_need_review_runtime`, and direct canonical reuse in K1 Save.
It supersedes the earlier permission stop; no new helper or architecture work
was undertaken.

The same uncommitted migration now contains exactly that grant. Before changing
working pointers or quantities, K1 Save calls preflight using the locked batch's
server-owned date as both arguments and `NULL` source candidates. It rejects a
non-single-date batch, unexpected line date, missing/unexpected preflight data,
non-READY readiness, nonzero blockers, non-CURRENT currentness, or a current Need
whose batch/version, run/version or release snapshot differs from the locked
authoritative chain. No browser-supplied date or candidate can override this
check. The previously failing Menu-reopen rejection now passes with
`CORRECTION_SOURCE_NOT_CURRENT`.

### Exact remaining concurrency conflict

`save_confirmed_needs` locks the existing Need run, batch, stable lines, policies
and release/Handoff evidence. Its later quantity update must also lock the old
`confirmed_need_line_revisions` row. The canonical preflight is STABLE and reads
the mutable Menu source without taking a source-row lock.
`atlas_api.reopen_weekly_menu` takes `FOR UPDATE` only on its Menu header before
changing the header status/version; it does not participate in Save's Need/run
locking boundary. These commands therefore have no shared source lock that
establishes the required ordering.

The disposable multi-session reproduction uses the same authenticated envelopes
and real guards; no function, trigger, RLS setting or deadline is changed:

1. Establish the released 100-quantity fixture from the focused test. A fixture
   coordination session holds `FOR UPDATE` on its existing current Need revision
   row, without changing data.
2. Actor A invokes real public Menu reopen in a transaction and holds its result
   uncommitted. Actor B invokes real public K1 Save for 110.
3. Save sees the committed approved Menu, passes canonical preflight and then
   waits updating the held Need revision. `pg_stat_activity` records a
   `transactionid` wait, with the coordination session as its blocker.
4. Actor A commits Menu reopen. Before releasing the revision lock, a separate
   canonical read observes **quantity 100, readiness BLOCKED, currentness
   OUTDATED**. This intervening observation prevents treating Save as a completed
   operation ordered before Menu reopen.
5. Release the existing revision lock. Actor B's Save returns **success** and
   commits **110**, one new revision and one new decision. Fresh canonical
   preflight remains **OUTDATED**. The concurrency acceptance fails.

This is a source-validation race, not an observed deadlock. The one approved
EXECUTE grant allows the fresh read but does not serialize it with Menu reopen.
Clause 3 of the Owner decision requires **STOP** when the existing lock boundary
cannot demonstrate safe ordering. No additional grant, helper, double-check
workaround, source-command amendment or cross-domain lock protocol was added.
The exact conflict above is returned for Owner review; no separate architecture
task was created.

### Results after the approved repair

| Check                                                                                                 | Actual result                                                                                                                                                                                                                 |
| ----------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Focused K1 SQL, including the original stale-source failure, replay, UNKNOWN recovery and rollback    | **PASS: 75/75**                                                                                                                                                                                                               |
| Retained nine RMVP-05/06/07, D-037, H1B1, continuity and Issue #222 suites rerun on repaired database | **PASS: 459/459**                                                                                                                                                                                                             |
| Authenticated Menu-reopen versus correction Save interleaving                                         | **FAIL**, accepted 110 after committed Menu reopen and intervening 100/OUTDATED read                                                                                                                                          |
| Independent read-only source/security review                                                          | **FAIL / STOP**, confirmed the same race                                                                                                                                                                                      |
| Catalog and fresh/duplicate migration application                                                     | **PASS**, exactly three existing function bodies and the one approved preflight EXECUTE grant differ; remaining owners, ACLs, security modes, volatility, search paths, relations, roles, triggers and policies are unchanged |
| Frontend / Supabase Smoke / Supabase Full Integration                                                 | **BLOCKED / not dispatched**, local concurrency acceptance fails                                                                                                                                                              |

Local evidence is retained in the task's `atlas-c-k1-evidence` directory:
`direct-preflight.log`, `direct-preflight-regressions.json`,
`direct-preflight-catalog-replay.json`, `menu-concurrency.mjs` (complete runnable
disposable setup/interleaving), and `menu-concurrency-result.json` (observed
wait, intervening read and failed acceptance). The task container is stopped;
the existing user Supabase containers are untouched.

The three-file candidate remains local and uncommitted on
`feat/atlas-c-need-correction-authority-01`. Starting/final Git HEAD remains
`96a2f048139e92281eb5cebe1421b28b4c1f14d1`. No push, Draft PR, hosted write,
deployment, merge or K2 change occurred. It remains unapproved for installation.

## K1 source-lock correction — 19 October 2026

The Owner's explicit resume instruction authorizes finishing the existing dirty
K1 candidate on `feat/atlas-c-need-correction-authority-01`, using RMVP-04's
established source locks. It supersedes the preceding concurrency STOP for this
bounded fix. This is implementation of that instruction, not another
architecture review or K2 authorization. Earlier failed evidence above remains
historical evidence and is preserved.

The verified registered worktree is
`C:/Users/HOME/.codex/worktrees/atlas-c-need-correction-authority-01/thuonghao-ops-erp`;
its starting HEAD is `96a2f048139e92281eb5cebe1421b28b4c1f14d1`, rooted at
`origin/main` `3667966a3f6703a6585f07ba619969ec851ca7b8` through the approved
ancestor stack. The initial E: checkout is a different, clean documentation
branch and was not edited. The existing dirty candidate and all eight stashes
were retained; pre-fix copies and previous raw evidence remain available.

### Lock sequence and private access

RMVP-04 Need Generation takes the input set/evaluation, terminal run, then Menu →
Attendance → Pantry roots in ID order before checking their current pointers.
Issue #222 source preparation takes advisory → run → Need batch; guarded source
Save takes advisory → Need batch → Handoff before source mutation. Compatibility
Menu/Attendance/Pantry reopen commands take their own source root and do not
wait on Need revisions.

K1 retains run SHARE → batch UPDATE, then resolves the exact current Need's
source IDs from server-canonical preflight and takes Menu → Attendance → Pantry
SHARE locks **before** Need line/revision waits. Source IDs and date are never
request-supplied. The exact canonical preflight is evaluated again under those
locks before working-pointer or quantity writes; READY/zero blockers/CURRENT
and exact batch/run/release identity remain mandatory. Null Menu/Attendance in
a COMPLETE-only captured source require only its Pantry root. SHARE conflicts
with source UPDATE while allowing other readers; all locks survive function
return through transaction completion.

The existing Need runtime gets SELECT and UPDATE only on each source root's
primary-key column, with six role-specific SELECT/lock policies. As in RMVP-04,
UPDATE USING permits locking and `WITH CHECK (false)` rejects every actual
write. No business-attribute grants, public source access, new helper, role,
domain object, generalized framework or historical integrity change is added.
The already approved private canonical-preflight EXECUTE remains the only new
function ACL.

### Focused proof

Fresh development proof on task-owned disposable PostgreSQL 17.6.1.155, 113
baseline migrations plus this candidate, normal authenticated public commands,
forced RLS and all guards enabled; public statement limit remains 8 seconds:

- The new concurrency regression first fails against the retained candidate:
  Menu reopen is held uncommitted but Save waits on the old Need revision.
- All six corrected interleavings pass, for Menu, Attendance and Pantry in both
  commit orders. Source-first Save waits on that source and rejects
  `CORRECTION_SOURCE_NOT_CURRENT` without waiting on the held revision; no new
  decision/revision or working-pointer changes result. Correction-first source
  reopen waits during the revision wait **and after Save returns**, until commit;
  110 is committed before the reopen legitimately derives OUTDATED.
- Original released Need/Handoff/allocation/issued PO/PXK snapshots are identical
  in every case. The independent two-Actor Save race produces one successor
  decision/revision and `STALE_CONFIRMED_NEED_BATCH` for the waiting competitor.
- K1 passes **81/81**, including six new key-only privilege / actual RLS-denial
  assertions; the nine retained core suites pass **459/459**. Source commands,
  Need Generation, B1 composition/two-source, Handoff, PO and PXK regressions
  bring the total to **1,416/1,416 across 19 SQL suites**. The certification
  contract test passes **116/116**; K1 SQL is registered in Smoke and Full
  Integration using the existing fixture-expanding runner.
- Fresh migration application and rejected atomic duplicate replay pass.
  Catalog comparison verifies exactly three changed bodies out of 472 Atlas
  functions, one approved preflight EXECUTE, three changed key-column ACLs and
  six new source-only policies. All other function attributes/owners/ACLs,
  existing policies, relation/role catalogs and triggers are unchanged.

Runnable multi-session proof:
`node scripts/test-local-atlas-c-k1-concurrency.mjs <disposable-container> <idle-applied-template-db> <result.json>`.
The template must contain the baseline plus K1 and no fixture rows; only new
`k1_source_<pid>*` databases are created, and they are retained for inspection.
SQL proof: `node scripts/test-local-purchase-review.mjs atlas_c_need_correction_authority.sql`
with `ATLAS_LOCAL_DB_CONTAINER` pointing at a disposable local PostgreSQL
container whose `postgres` database has the baseline plus K1. No hosted data is
used. The new local evidence directory is
`C:/Users/HOME/.codex/visualizations/2026/10/19/01a152cb-5335-7141-b1a9-8df4ac8ca12e/atlas-c-k1-lock-evidence`;
it preserves pre-fix sources, red/green concurrency, suite logs and catalog proof.

Independent read-only implementation/security review found **no blocking
findings** in the bounded K1 candidate, covering exact source bindings,
authorization, lock ordering/lifetime, historical preservation, rollback,
replay and CI wiring. This source-root proof does not certify serialization
against every mutable Recipe/Admin input; broader preexisting currentness
concurrency is unchanged and was not expanded into another architecture task.

Exact-head GitHub certification is the remaining delivery gate. Its run IDs and
final SHA belong in the Draft PR evidence, rather than treating local source
tests or ancestor CI as certification. The K1 API amendment documents the v3 envelope,
truthful unavailable downstream workflow and forward-only rollback. K2,
Procurement transfer, PO/PXK authority, hosted installation, merge and deployment
remain outside this checkpoint.
