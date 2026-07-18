# PA-06D — Quantity Truth, Precision, Rounding, Rebalancing, and Write Fidelity

**Status:** Documentation prerequisite; product and architecture review required

**Scope:** Future Atlas Requirement Planning and Procurement only; no executable behavior

**Authority:** Approved Atlas contracts first, then merged migrations/tests, live OPS evidence, Retool evidence, and finally labeled assumptions

**Related UI:** [PA-06D Requirement and Allocation Workbenches](../ui/pa-06d-requirement-allocation-workbench-spec.md)

**Rules:** [PA-06D Rule Register](../business-rules/pa-06d-rounding-rebalancing-rule-register.md)

**Decisions:** [PA-06D Quantity Truth and Write Fidelity](../decisions/decision-pa-06d-quantity-truth-and-write-fidelity.md)

## 1. Outcome and boundary

This contract establishes the business meanings and invariants that must exist before Atlas implements quantity review, purchase quantization, supplier allocation, rebalancing, or document release. It does not approve a SQL design, RPC, migration, React implementation, Retool change, deployment, or production write.

The approved direction is that Planning owns the reviewed operational need, Procurement owns the purchasable quantity and exact supplier portions, and Dispatch consumes the same committed allocation snapshot. A released document is never silently recalculated.

## 2. Governing system-map path

| OPS_SYSTEM_MAP layer | PA-06D interpretation                                                                                                                                              |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Mission              | Deliver the required ingredients without hiding quantity changes from operators.                                                                                   |
| Business capability  | Review requirement quantity; prepare purchasable quantity; allocate suppliers; release consistent PO and Dispatch facts.                                           |
| Business domain      | Planning owns need truth; Procurement owns purchase and allocation truth; Dispatch consumes committed truth; Warehouse and Dispatch own later physical quantities. |
| Business object      | Confirmed Need, Purchase Handoff, Quantity Decision, Fulfilment Allocation, Purchase Order, Dispatch Requirement, Load and Delivery evidence.                      |
| Business contract    | This document plus the PA-05D/PA-05E lineage and immutability contracts.                                                                                           |
| Command/event        | Future backend preview and commit commands; released revisions and audit events.                                                                                   |
| Read model           | Future authorized quantity review, allocation detail, preview, committed snapshot, and readback views.                                                             |
| Application          | Two future Vietnamese-first workbenches.                                                                                                                           |
| Technology           | React coordinates interaction; PostgreSQL performs authoritative decimal/tick calculation; private tables stay inaccessible to the browser.                        |

## 3. Precision is not one setting

The following separation is approved. Values labeled **pending** are not approved merely because OPS uses them today.

| Concept                        | Meaning                                                        | Contract direction                                                                              | Approval state                                                |
| ------------------------------ | -------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| `calculation_precision`        | Precision retained while deriving quantities and entitlements  | PostgreSQL high-precision `numeric`; do not truncate to display scale during calculation        | Approved direction                                            |
| `comparison_epsilon`           | Technical tolerance for legacy floating-point comparisons      | OPS evidence is `0.000001`; future tick equality should be exact                                | Approved distinction; future use pending                      |
| `ratio_precision`              | Precision of a derived supplier share                          | Up to six decimals when useful; ratios never author supplier quantities                         | Approved direction                                            |
| `planning_operational_step`    | Smallest meaningful Planning confirmation increment for a unit | Proposed default: `0.01 kg`; indivisible/count units: `1`; unit-policy exceptions explicit      | Pending product approval                                      |
| `purchase_order_step`          | Smallest purchasable increment                                 | Ingredient/supplier policy; current OPS data uses `0.1 kg` and `1` for current count-like units | Upward-only direction approved; exact fallback policy pending |
| `persisted_quantity_precision` | Exact operational value stored                                 | Persist integer ticks plus step/rule identity, or an exactly equivalent decimal representation  | Recommended; physical design pending                          |
| `display_precision`            | Digits required to show the entire operational value           | Derived from the applicable step; raw calculation may appear in secondary details               | Approved direction                                            |

Retool's six-decimal convention primarily supports floating-point comparison, proportional arithmetic and deterministic residual handling. It is not an approved six-decimal operational quantity rule for Atlas.

## 4. Quantity truth model

### 4.1 Meanings, ownership, and authority

| English contract term         | Vietnamese UI term                    | Owner                          | Authority                     | Created or changed by                                   | Precision and rounding                             | Persistence and consumers                           |
| ----------------------------- | ------------------------------------- | ------------------------------ | ----------------------------- | ------------------------------------------------------- | -------------------------------------------------- | --------------------------------------------------- |
| Raw Calculated Requirement    | Nhu cầu tính toán                     | Planning                       | Derived                       | Need calculation from versioned source/BOM facts        | High precision; no operational rounding            | Calculation snapshot; explanation only              |
| Planning Operational Quantity | Nhu cầu vận hành                      | Planning                       | Derived proposal              | Apply approved unit-specific Planning step              | Planning step; policy rounding must be named       | Preview/snapshot; feeds confirmation                |
| Confirmed Operational Need    | Nhu cầu đã xác nhận                   | Planning                       | Authoritative Planning fact   | Human confirmation command with reason and versions     | Planning step; no hidden purchase rounding         | Immutable revision; feeds Purchase Handoff          |
| Purchase Order Step           | Bước đặt hàng                         | Procurement/master-data policy | Authoritative rule            | Effective-dated ingredient or supplier rule             | Positive step in the purchase unit                 | Rule-set version; used by preview/commit/documents  |
| Proposed Purchasable Quantity | Số lượng đề xuất đặt mua              | Procurement                    | Derived preview               | Upward quantization of confirmed need to purchase ticks | `ceil(need / step) * step`                         | Preview only until confirmed                        |
| Confirmed Purchase Quantity   | Số lượng mua đã xác nhận              | Procurement                    | Authoritative purchase target | Operator confirms a current preview                     | Exact integer ticks                                | Allocation aggregate; PO/Dispatch source            |
| Current Allocated Quantity    | Số lượng đã phân bổ                   | Procurement                    | Derived total                 | Sum of current authoritative supplier portions          | Exact tick sum                                     | Allocation read model                               |
| Supplier Portion              | Số lượng phân bổ cho nhà cung cấp     | Procurement                    | Authoritative line fact       | Rebalance/manual allocation commit                      | Positive whole ticks; zero rows removed explicitly | Allocation revision; PO source                      |
| Unallocated Balance           | Số lượng chưa phân bổ                 | Procurement                    | Derived                       | Confirmed purchase ticks minus allocated ticks          | Exact ticks                                        | Preview/read model; must be zero to commit/release  |
| Rounding Difference           | Chênh lệch do làm tròn                | Procurement                    | Derived explanation           | Proposed purchase minus confirmed need                  | Same purchase unit; never hidden                   | Preview/audit/document explanation where required   |
| Residual Quantity             | Phần dư phân bổ                       | Procurement                    | Derived explanation           | Residual ticks after provisional entitlements           | Whole ticks                                        | Preview/audit; recipient explicit                   |
| PO Committed Quantity         | Số lượng đã cam kết trên đơn đặt hàng | Procurement                    | Authoritative released fact   | PO release from committed allocation revision           | Exact sum of persisted portions for that PO grain  | Immutable PO revision; supplier and Dispatch source |
| Dispatch Committed Quantity   | Số lượng giao theo cam kết            | Dispatch                       | Authoritative consumed fact   | Copy/reference same committed allocation snapshot       | No second rounding                                 | Dispatch revision, load planning                    |
| Loaded Quantity               | Số lượng đã xếp hàng                  | Dispatch                       | Authoritative physical fact   | Load confirmation                                       | Measurement policy of execution unit               | Load evidence; not a rewrite of committed quantity  |
| Delivered Quantity            | Số lượng đã giao                      | Dispatch                       | Authoritative physical fact   | Delivery confirmation                                   | Measurement policy of execution unit               | Delivery evidence and exceptions                    |

Every persisted state carries stable line identity, aggregate/revision version, source revision, unit, step/rule-set version, actor, time, reason where applicable, and before/after quantities. Derived values identify their authoritative inputs.

### 4.2 Edit and version rules

- Raw Calculated Requirement is never directly edited; source correction or a named Planning adjustment creates a new result.
- Confirmed Operational Need changes only through an explicit Planning revision before downstream release, or through a corrective revision after release.
- Confirmed Purchase Quantity and supplier portions are committed together under one allocation version.
- A manually edited supplier portion is valid only if it is a whole number of the effective purchase ticks and the total remains exact.
- PO and Dispatch released facts are immutable. Correction creates a new revision or compensating action; it never overwrites history.
- Loaded and Delivered quantities may differ from commitment, but the variance is an execution fact with a reason, not a recalculation of Planning or Procurement truth.

## 5. Reviewed OPS v1 current-state flow

The live review was read-only on 2026-07-18 against project `qnthofvccilhnefdcxnz` (`OPS`, healthy). The retained `schema.sql` and four Retool exports were also inspected read-only. The Purchase Planner export SHA-256 was `2714512AB9A47CF9E560305C48192ABD45AB3E99ACC5ADE5C26C5414DD263093`; the retained schema SHA-256 was `1254D4DE81AE0B581B87666F4AA7195932ACB9ED8559B677AE9F0AA95C24DB6D`.

| Transition                     | Legacy quantity/formula                                                                                             | Precision, threshold, residual                                                                                 | Trigger and active path                                                                                           | Persisted/displayed/downstream                              | Difference and risk                                                                                                |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| Source facts → raw theoretical | `qty_theoretical` from effective need view                                                                          | Unrestricted `numeric`; source-specific arithmetic                                                             | `ops_v2.v_actual_needs_effective_live` → `v_actual_needs_effective`                                               | Derived; Retool master                                      | High precision has no approved operational meaning                                                                 |
| Order-step lookup              | `coalesce(order_step, kg ? 0.1 : 1)`                                                                                | Exact decimal step; current live ingredients are explicitly `0.1 kg` or `1` for current other units            | `ingredient_order_step`                                                                                           | Derived `order_step`                                        | Fallback is legacy policy, not approved Planning precision                                                         |
| Theoretical → orderable        | `y=ceil(qty_theoretical/step)*step`; if `y<2`, keep `y`, else `round(y)`                                            | Whole-number half-up threshold at `2`                                                                          | `theoretical_orderable_qty` in orderable view                                                                     | `qty_theoretical_orderable`                                 | Can reduce the result below source need after an initial ceiling                                                   |
| Actual override                | Store exact `qty_actual` entered                                                                                    | Unrestricted `numeric`; Retool equality to baseline uses `EPS=1e-6`                                            | `js_ppwb_save_actual_need` → `q_ppwb_save_actual_need` → `ops_v2.app_upsert_actual_need_overrides_bulk`           | `ops_v2.actual_need_overrides.qty_actual`                   | Exact override and visible orderable value are different truths                                                    |
| Actual → orderable             | `ceil(qty_actual/step)*step`                                                                                        | Upward to order step; no threshold                                                                             | `ops_v2.v_actual_needs_effective_orderable`                                                                       | `qty_actual_orderable`, then `qty_final_orderable`          | Saved override may not equal master quantity                                                                       |
| Master quantity                | `sl=coalesce(qty_actual_orderable,qty_theoretical_orderable)`                                                       | JS `toFixed(6)` and `EPS=1e-6` for delta                                                                       | `q_ppwb_master_load`, seed/merge transformers                                                                     | Optimistic `st_ppwb_master_rows`; displayed by master table | Six decimals leak into operator state                                                                              |
| Save-triggered rebalance       | For all but final sorted row: `round(old_portion*new_total/old_total,6)`; final row receives `new_total-sum(prior)` | Proportional; sort `supplier_id,group_token`; old total `<=0` gives all to first; new total `<=0` deletes rows | Master save RPC transitively calls `ops_v2.fn_rebalance_purchase_assignments_for_keys_planner`                    | `ops_v2.purchase_assignments.split_qty/split_ratio`         | Residual recipient is a technical sort result; no preview                                                          |
| Detail pool/default            | Existing raw portions; if none, propose all to preferred supplier by priority then ID                               | Default row is optimistic and not persisted yet in the active OPS_V2 query                                     | `q_ppwb_detail_pool_load` → pool/detail seed                                                                      | Local state                                                 | Supplier introduction appears without a formal preview/audit decision                                              |
| Manual portion edits           | Exact positive `split_qty`; ratio=`split_qty/total`                                                                 | Ratio may retain JS float; total compare `abs(diff)<=0.000001`                                                 | Detail table → merge transformer                                                                                  | Optimistic detail state                                     | Portion need not be a multiple of order step                                                                       |
| Split/remove                   | Split selected quantity in half using `round6`; remove pushes its quantity to adjacent remaining row                | Six decimals; local residual preserved                                                                         | `js_ppwb_detail_split_line`, `js_ppwb_detail_remove_line`                                                         | Local state only                                            | Row order affects result; supplier identity may be duplicated                                                      |
| Manual “Cân bằng”              | Sequential fill/cap: each prior row gets `min(wanted,remaining)`; final row gets remainder                          | `round6` after every operation; row order is decisive                                                          | `js_ppwb_detail_autobalance`                                                                                      | Local state                                                 | Contradicts proportional server behavior                                                                           |
| Detail save                    | Validate positive exact portions and epsilon total; destructive family replacement                                  | No tick/multiple constraint; exact values passed                                                               | `js_ppwb_detail_save` → `q_ppwb_detail_replace_family` → `ops_v2.app_replace_purchase_assignments_family_planner` | Delete and reinsert family; then optimistic state update    | No authoritative post-write readback; exported JS also contains duplicate declarations requiring live verification |
| Assignment feed                | `ceil_to_step(persisted split_qty,order_step)`                                                                      | Upward per portion                                                                                             | `ops_v2.v_purchase_assignments_feed`                                                                              | Derived feed                                                | Feed can differ from persisted portion and inflate aggregate                                                       |
| PO confirmation                | `sum(persisted split_qty)` by supplier/date/school/effective line                                                   | Unrestricted `numeric`; no new rounding                                                                        | `q_po_confirm` → `ops_v2.app_confirm_purchase_orders`                                                             | `ops_v2.purchase_order_lines.qty`                           | Exact assignment sum, even if portions violate step                                                                |
| Dispatch confirmation          | `ceil_to_step(sum(all supplier portions for school/effective line),order_step)`                                     | Second upward rounding                                                                                         | `q_dispatch_confirm` → `ops_v2.app_confirm_dispatch`                                                              | `ops_v2.dispatch_lines.qty`                                 | May differ from PO/allocation; violates single-snapshot direction                                                  |
| Document/export display        | PO formatter uses whole number or one decimal (`Math.round(x*10)/10`); Dispatch XLSX writes raw numeric             | Client floating-point formatting                                                                               | PO/Dispatch export transformers                                                                                   | Supplier PDF/XLSX; Dispatch XLSX                            | Display precision can hide stored quantity and differs by document                                                 |

### 5.1 Retool arithmetic and state classification

| Evidence                | Exact observed behavior                                                                               | Classification                                      |
| ----------------------- | ----------------------------------------------------------------------------------------------------- | --------------------------------------------------- |
| `EPS`                   | `0.000001` for master status and detail total comparison                                              | Technical comparison only                           |
| `toFixed(6)` / `round6` | Stabilizes deltas, split ratios, half-splits, sequential remaining values                             | Computational convention, not operational precision |
| Split ratio             | Detail seed/merge uses `round6(split_qty/total_qty)`; detail save sends an unrounded JS division      | Derived and inconsistent                            |
| Proportional rebalance  | Active master save reaches OPS_V2 backend planner function                                            | Server-side but hidden and unpreviewed              |
| Sequential fill/cap     | Manual `js_ppwb_detail_autobalance`                                                                   | Client-owned legacy behavior                        |
| Exact manual portions   | Detail save passes entered `split_qty` after epsilon total validation                                 | Persisted but not step-validity enforced            |
| Optimistic local state  | Master/detail transformers and detail save rewrite Retool states                                      | Present; can diverge from backend                   |
| Backend readback        | Master save invokes the refresh controller after save; detail save updates local state without reload | Partial and inconsistent                            |

The active master controller calls `q_ppwb_save_actual_need`; the similarly named `q_ppwb_master_save_and_rebalance` contains a duplicate/transition call and is not the controller target. Activity is therefore established from invocation, not names or comments.

### 5.2 Live function and trigger classification

Classification is scoped to the reviewed Purchase Planner invocation, not to every possible external caller.

| Object                                                                                        | Classification         | Evidence and consequence                                                                                           |
| --------------------------------------------------------------------------------------------- | ---------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `ops_v2.app_upsert_actual_need_overrides_bulk`                                                | ACTIVE / OPS_V2        | Direct target of active master save; persists exact override then invokes OPS_V2 planner rebalance                 |
| `ops_v2.fn_rebalance_purchase_assignments_for_keys_planner`                                   | ACTIVE / OPS_V2        | Transitively invoked; proportional six-decimal provisional values and final-row residual                           |
| `ops_v2.app_replace_purchase_assignments_family_planner`                                      | ACTIVE / OPS_V2        | Direct target of active detail family replacement                                                                  |
| `ops_v2.app_confirm_purchase_orders`                                                          | ACTIVE / OPS_V2        | Direct Retool PO confirmation target                                                                               |
| `ops_v2.app_confirm_dispatch`                                                                 | ACTIVE / OPS_V2        | Direct Retool Dispatch confirmation target; applies a second ceiling                                               |
| Public `app_upsert_actual_need_overrides_bulk` + `fn_rebalance_*_fast`                        | TRANSITIONAL           | Retained functions and comments indicate an older public planner path; not invoked by reviewed active OPS_V2 query |
| Public `app_upsert_*_planner`, `fn_rebalance_*_planner`, and `app_replace_*_planner` variants | TRANSITIONAL / UNKNOWN | Schema comments claim planner intent, but reviewed Retool invokes OPS_V2, so names do not prove activity           |
| Public `*_exact` variants                                                                     | DEPRECATED             | Live comments label them transitional/deprecated-soon; no active Retool invocation                                 |
| Public non-suffixed/exact family replacement                                                  | DEPRECATED             | Live comments direct callers to planner variant; no active invocation                                              |
| Public unsuffixed/school-day rebalance variants                                               | TRANSITIONAL / UNKNOWN | Public legacy triggers/functions exist, but they are outside the traced active OPS_V2 family                       |
| OPS_V2 normalization/touch triggers                                                           | ACTIVE / OPS_V2        | Normalize delivery requirement and timestamps only; no tick or allocation-total enforcement                        |
| Public rebalance/ratio/audit triggers                                                         | TRANSITIONAL           | Attached to public legacy tables, not the active OPS_V2 assignment path                                            |
| Any untraced external callers                                                                 | UNKNOWN                | Must be inventoried before legacy retirement                                                                       |

Named live formulas, views, function variants, triggers, types and constraints materially matched the retained schema during the focused comparison; live definitions remain the current evidence authority. Live quantity and ratio columns reviewed on `actual_need_overrides`, `purchase_assignments`, `purchase_order_lines`, and `dispatch_lines` use unrestricted PostgreSQL `numeric`. Constraints enforce non-negativity in selected OPS_V2 tables, but do not enforce a universal six-decimal scale, step multiples, exact allocation totals, or PO/Dispatch equality.

## 6. Legacy contradictions that Atlas must not copy

1. The exact actual override is persisted while the master shows a different orderable value.
2. The orderable total and supplier total can diverge until hidden server rebalance or manual action occurs.
3. Server save uses proportional rebalance while Retool “Cân bằng” uses sequential fill/cap.
4. Six-decimal calculations are shown or persisted despite meaningful operational steps.
5. PO uses exact portions while Dispatch re-ceils their aggregate.
6. Persisted values may contain more precision than the PO formatter displays; Dispatch formatting follows another rule.
7. A preferred supplier may be proposed automatically, and the older public fast path can insert it automatically, without a formal operator preview.
8. A zero new total deletes allocation rows automatically rather than presenting an explicit removal proposal.
9. The residual goes to a row selected by technical sort order (`supplier_id`, `group_token`) rather than a visible business rule.
10. The assignment feed individually re-ceils persisted portions, so a read model can disagree with storage.
11. Detail replacement is destructive and its optimistic success state is not an authorized readback.

Legacy `theoretical_orderable_qty` can return below the source need. Examples: `2.01` at step `0.1` becomes `2`; `2.01` at step `0.25` becomes `2`; and `10.05` at steps `0.1` or `0.25` becomes `10`. More generally, after step ceiling, any result at or above `2` is rounded to a whole number and can move downward. This threshold must not survive by accident.

## 7. Recommended operational quantization model

### 7.1 Exact ticks

For a positive purchase step `s` and confirmed need `q`:

```text
confirmed_purchase_ticks = ceil(q / s)
confirmed_purchase_quantity = confirmed_purchase_ticks * s
rounding_difference = confirmed_purchase_quantity - q
```

Example: `10.0 kg / 0.1 kg = 100 ticks`. Exact supplier tick equality is the invariant:

```text
sum(persisted supplier ticks) = confirmed purchase ticks
```

The backend must reject missing/non-positive steps and quantities that cannot be represented by the effective unit/step policy. It must not guess a fallback in the command. A fallback, if approved, belongs to a versioned rule set and is visible in preview.

### 7.2 Proportional allocation

1. Identify participating current supplier portions and any explicit operator-fixed portions.
2. Convert the confirmed purchase quantity and fixed portions to integer ticks.
3. Calculate each unlocked supplier's high-precision entitlement from its current proportion of the unlocked total.
4. Assign provisional whole ticks by flooring each entitlement.
5. Distribute remaining ticks by largest fractional remainder.
6. Break equal remainders using a visible, versioned business residual-priority order. If no complete business order exists, preview fails rather than silently using a database row order.
7. Show the exact before/after ticks and quantities, the residual count, recipient sequence, added/changed/removed rows, and rule-set version.
8. Commit exactly the previewed ticks.

For three equal suppliers and `100` ticks, entitlements are `33.333333…`. Provisional portions are `33,33,33`; one residual tick is assigned to the supplier shown first by the approved residual-priority rule. If Supplier C has that priority, the persisted values are `3.3 kg`, `3.3 kg`, `3.4 kg`.

This method is operationally meaningful because every portion is purchasable, equality is exact, internal precision never leaks into supplier commitments, and the residual is explainable.

### 7.3 Rebalancing contract

The recommended default is proportional rebalancing. Sequential fill/cap is legacy evidence and is not an equivalent production choice.

- Existing eligible supplier proportions participate by default.
- A newly selected supplier starts with an explicit operator-entered portion or a visible proposed weight; it never appears silently.
- A removed supplier is shown with before quantity, proposed zero, and removal consequence.
- Manual fixed portions are recommended only as an explicit preview input; whether the first implementation supports them remains pending.
- A total of zero proposes removal of all unreleased allocation rows and requires explicit confirmation.
- Any quantity, supplier eligibility, step, proportion, lock, aggregate version, or rule-set change invalidates preview.
- A released PO blocks in-place modification. Correction starts an explicit revision/cancellation workflow.
- Audit records the rule version, inputs, high-precision entitlements, provisional ticks, residual order, exact before/after ticks, actor, reason, preview identity, and command identity.

## 8. WYSIWYG write-fidelity contract

These are hard invariants for future implementation:

1. React does not authoritatively calculate rounding or rebalancing.
2. Backend preview and backend commit use the same canonical rule implementation and rule-set version.
3. Every persisted operational number appears in final confirmation.
4. Internal six-decimal values never substitute for operational values.
5. Confirmation shows exact supplier portions, residual ticks, recipient, rows added/changed/removed, step, and rule.
6. Preview is bound to `preview_id`, `preview_hash`, aggregate version, source versions, and `rule_set_version`.
7. Any relevant change invalidates preview; a stale preview cannot commit.
8. Commit returns the exact persisted authoritative snapshot.
9. UI discards optimistic proposals and renders that returned snapshot.
10. A separate authorized readback verifies the same persisted values.
11. A readback mismatch is visible, blocks progression and document release, and instructs the operator not to retry blindly.
12. Display precision represents the entire persisted operational value.
13. PO consumes the committed allocation revision; Dispatch references the same revision without re-ceiling.
14. Released facts are revised explicitly, never silently recalculated.
15. Events and audit carry rule version and before/after quantities.

Formal invariant:

```text
Final confirmation snapshot
= command persisted snapshot
= authorized readback snapshot
= PO source quantity snapshot
= Dispatch source quantity snapshot
```

The only exception is a separately approved, named transformation whose exact result is previewed, confirmed, versioned and audited before release.

## 9. Atlas 18-function API gap analysis

### 9.1 What exists

- CMD-01 records wholesale requested quantities.
- CMD-02 releases direct-pass-through theoretical and confirmed quantities for the wholesale slice.
- CMD-03 releases exact Purchase Handoff quantities.
- CMD-04 releases exact Dispatch Requirement quantities.
- CMD-05 allocates exactly one full requirement line to one supplier and requires allocated quantity/unit equality.
- CMD-06 releases one supplier PO from that allocation.
- Shared command receipt, event, audit, stale, idempotency and authorization envelopes are reusable.

### 9.2 What is absent

- No separate Planning Operational Quantity or Quantity Decision aggregate exists.
- No effective-dated quantity rule-set version, Planning step, purchase-step decision, rounding difference, or tick representation exists in the accepted boundary.
- PA-05E cannot represent split supplier portions through its command: it requires one complete line occurrence and exact full-line equality, even though underlying revision shapes contain line identity.
- No backend rounding/rebalancing preview and no commit bound to a preview hash/version exist.
- No residual policy, manual fixed-portion policy, or exact tick invariant exists.
- Authorized requirement queue/detail, supplier eligibility, current allocation detail, and PO release queue reads are absent, as PA-06A classified.
- No authorized post-commit readback exposes the proposed quantity/allocation aggregate.
- Browser access to private Planning/Procurement tables remains prohibited.

### 9.3 Smallest follow-ups

**Smallest backend follow-up:** one bounded, separately approved PA-06D-H1 contract and implementation for a versioned Quantity Decision on one unreleased Purchase Handoff line: authorized detail/discovery read, effective rule resolution, backend preview, preview-bound commit, exact ticks, receipt/event/audit, and authoritative readback. It should not yet add multi-supplier allocation or change the 18-function registry silently.

**Smallest later UI follow-up:** implement only the Requirement Quantity Review workbench against PA-06D-H1, including preview, exact Vietnamese confirmation, stale recovery, returned snapshot and authorized readback. The Supplier Allocation workbench remains non-mutating until a later split-allocation backend contract exists.

## 10. Required conclusion

1. **Approved precision separation:** calculation precision, comparison epsilon, ratio precision, Planning step, purchase step, persisted precision and display precision remain distinct.
2. **Recommended quantity model:** high-precision derivation followed by versioned operational quanta/ticks and exact equality.
3. **Recommended purchase rounding:** upward only to the effective purchase step; remove the legacy whole-number threshold at `2` unless explicitly re-approved.
4. **Recommended rebalancing:** preserve current proportions, calculate precise entitlements, allocate whole ticks by largest remainder and a visible business residual priority, preview, confirm, then persist exact shown values.
5. **WYSIWYG:** final confirmation, commit result, readback, PO source and Dispatch source are the same exact snapshot.
6. **Legacy contradictions:** exact-vs-orderable overrides, hidden proportional-vs-sequential rebalance, six-decimal operational leakage, assignment-feed re-ceiling, PO-vs-Dispatch re-ceiling, document formatting loss, automatic supplier/zero deletion behavior and technical residual ordering are all prohibited carryovers.
7. **Smallest backend follow-up:** PA-06D-H1 Quantity Decision for one unreleased handoff line with preview/commit/readback.
8. **Smallest UI follow-up:** Requirement Quantity Review only after that backend contract is approved and implemented.
9. **Deferred:** multi-supplier command, fixed portions, supplier-specific steps, released-PO correction, document generation and rollout.
10. **Awaiting product approval:** exact Planning steps, fallback purchase steps, removal of threshold `2`, supplier-specific step precedence, fixed portions, residual priority/ties, automatic supplier proposal, zero behavior, released-PO correction path, rule owner and effective-date governance.
