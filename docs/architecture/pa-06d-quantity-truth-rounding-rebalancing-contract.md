# PA-06D — Quantity Truth, Precision, Rounding, Rebalancing, and Write Fidelity

**Status:** Documentation prerequisite; product and architecture review required

**Scope:** Future Atlas Requirement Planning and Procurement only; no executable behavior

**Authority:** Approved Atlas contracts first, then merged migrations/tests, live OPS evidence, Retool evidence, and finally labeled assumptions

**Related UI:** [PA-06D Requirement and Allocation Workbenches](../ui/pa-06d-requirement-allocation-workbench-spec.md)

**Rules:** [PA-06D Rule Register](../business-rules/pa-06d-rounding-rebalancing-rule-register.md)

**Decisions:** [PA-06D Quantity Truth and Write Fidelity](../decisions/decision-pa-06d-quantity-truth-and-write-fidelity.md)

**Confirmed Need resolution:** [PA-06E Confirmed Need Review, Adjustment, Revision, and Source Correction](pa-06e-confirmed-need-review-adjustment-revision-contract.md) resolves the pending insertion-point recommendation by retaining the existing Confirmed Need revision; it adds no Quantity Decision aggregate and authorizes no implementation.

## 1. Outcome and boundary

This contract establishes the business meanings and invariants that must exist before Atlas implements quantity review, purchase quantization, supplier allocation, rebalancing, or document release. It does not approve a SQL design, RPC, migration, React implementation, Retool change, deployment, or production write.

The approved direction is that Planning owns the reviewed operational need, Procurement owns the purchasable quantity and exact supplier portions, and Dispatch consumes the same committed allocation snapshot. A released document is never silently recalculated.

## 2. Governing system-map path

| OPS_SYSTEM_MAP layer | PA-06D interpretation                                                                                                                                                     |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Mission              | Deliver the required ingredients without hiding quantity changes from operators.                                                                                          |
| Business capability  | Review requirement quantity; prepare purchasable quantity; allocate suppliers; release consistent PO and Dispatch facts.                                                  |
| Business domain      | Planning owns need truth; Procurement owns purchase and allocation truth; Dispatch consumes committed truth; Warehouse and Dispatch own later physical quantities.        |
| Business object      | Accepted: Confirmed Need, Purchase Handoff, Fulfilment Allocation, Purchase Order, Dispatch Requirement, Load and Delivery evidence. Future candidate: Quantity Decision. |
| Business contract    | This document plus the PA-05D/PA-05E lineage and immutability contracts.                                                                                                  |
| Command/event        | Future backend preview and commit commands; released revisions and audit events.                                                                                          |
| Read model           | Future authorized quantity review, allocation detail, preview, committed snapshot, and readback views.                                                                    |
| Application          | Two future Vietnamese-first workbenches.                                                                                                                                  |
| Technology           | React coordinates interaction; PostgreSQL performs authoritative decimal/tick calculation; private tables stay inaccessible to the browser.                               |

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
| Planning Operational Quantity | Nhu cầu vận hành (đề xuất)            | Planning                       | Derived proposal              | Apply approved unit-specific Planning step              | Planning step; policy rounding must be named       | Preview/snapshot; feeds confirmation                |
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

`Nhu cầu vận hành` is proposed pending product-owner and operations-language review. PA-06D does not treat that Vietnamese label as final; the terminology comparison and acceptance gate are in the UI specification.

### 4.2 Edit and version rules

- Raw Calculated Requirement is never directly edited; source correction or a named Planning adjustment creates a new result.
- Confirmed Operational Need changes only through an explicit Planning revision before downstream release, or through a corrective revision after release.
- Confirmed Purchase Quantity and supplier portions are committed together under one allocation version.
- A manually edited supplier portion is valid only if it is a whole number of the effective purchase ticks and the total remains exact.
- PO and Dispatch released facts are immutable. Correction creates a new revision or compensating action; it never overwrites history.
- Loaded and Delivered quantities may differ from commitment, but the variance is an execution fact with a reason, not a recalculation of Planning or Procurement truth.

## 5. Reviewed OPS v1 current-state flow

The live review was read-only on 2026-07-18 against project `qnthofvccilhnefdcxnz` (`OPS`, healthy). The retained review artifacts are identified by exact path, file name, type, and SHA-256 so similarly named exports cannot be conflated:

| Retained path and exact file name                  | Artifact type      | SHA-256                                                            |
| -------------------------------------------------- | ------------------ | ------------------------------------------------------------------ |
| `/mnt/data/OPS - Admin (in production).json`       | Retool JSON export | `A6D74CA01F7942687E8639FFEF73DBA5A89C6BCBF653F9454011CEC551549350` |
| `/mnt/data/OPS - Công thức.json`                   | Retool JSON export | `B38C86AC3B1FED985F6BC07D91C0708CF5AACCCC682434BA2498960D1DA1B809` |
| `/mnt/data/OPS - Nguyên liệu và Nhà cung ứng.json` | Retool JSON export | `2FB973CBD6A3900252AA9037A1D4D197551BCCC93DB60E36512D97F27D903648` |
| `/mnt/data/OPS - Lên đơn, Đặt hàng (1).json`       | Retool JSON export | `6F6FF8D025696D375F354A86126661D20C3E9908D6475D40ECB14EE006B4A371` |
| `/mnt/data/schema.sql`                             | PostgreSQL schema  | `1254D4DE81AE0B581B87666F4AA7195932ACB9ED8559B677AE9F0AA95C24DB6D` |

Those exact `/mnt/data` JSON bytes were not mounted during the correction pass on 2026-07-19. The earlier draft had instead hashed differently named or different-byte local exports under `D:\Project\OPS v2`; those hashes are not retained-artifact hashes. The local alternatives and reason for recording them are:

| Local path and exact file name                                 | Artifact type      | SHA-256                                                            | Why different                                                                |
| -------------------------------------------------------------- | ------------------ | ------------------------------------------------------------------ | ---------------------------------------------------------------------------- |
| `D:\Project\OPS v2\OPS - Admin (in production) (1).json`       | Retool JSON export | `8C5BA8205C1DE37966B1ED0A0762DB6B508D634E7EA91E92788308B0AFD2BAE1` | Extra `(1)` suffix; not the retained file name                               |
| `D:\Project\OPS v2\OPS - Công thức.json`                       | Retool JSON export | `E50AB600E98C1AC683BD449C8B2C859846C0BF5E5AE2A5A807BBE827B03852E9` | Same display name but different bytes from the retained artifact             |
| `D:\Project\OPS v2\OPS - Nguyên liệu và Nhà cung ứng (1).json` | Retool JSON export | `0DA3AD9F1C31DC29504B63F711150153C16F09451E2A8D299A9EC61048BC9722` | Extra `(1)` suffix; not the retained file name                               |
| `D:\Project\OPS v2\OPS - Lên đơn, Đặt hàng.json`               | Retool JSON export | `2714512AB9A47CF9E560305C48192ABD45AB3E99ACC5ADE5C26C5414DD263093` | Missing retained `(1)` suffix and different bytes                            |
| `D:\Project\OPS\schema.sql`                                    | PostgreSQL schema  | `1254D4DE81AE0B581B87666F4AA7195932ACB9ED8559B677AE9F0AA95C24DB6D` | Local byte-for-byte checksum matches the retained schema record              |
| `D:\Project\OPS v2\OPS-v1-retool-app.zip`                      | Retool source ZIP  | `1AD49948DECDD7FA1F0AD09C23809D37EEA786E861CBCAD8006DB4CCA902E0B2` | Supplemental invocation evidence; not one of the five retained raw artifacts |

The source ZIP was inspected without extraction during the correction pass. Its linked app query files directly establish the public invocation chain described below. Live object existence and schema comments are supporting evidence, but activity is attributed only from an exported controller or query invocation.

```text
q_ppwb_master_load
→ public.v_actual_needs_effective_orderable
→ public.actual_need_overrides
→ public.purchase_assignments

js_ppwb_save_actual_need
→ q_ppwb_save_actual_need
→ public.app_upsert_actual_need_overrides_bulk
→ public.fn_rebalance_purchase_assignments_for_keys_fast

q_ppwb_detail_pool_load
→ public views and tables

q_ppwb_detail_replace_family
→ public.app_replace_purchase_assignments_family_planner

q_po_confirm
→ public.app_confirm_purchase_orders

q_dispatch_confirm
→ public.app_confirm_dispatch
```

| Transition                     | Legacy quantity/formula                                                                                             | Precision, threshold, residual                                                                                 | Trigger and active path                                                                                           | Persisted/displayed/downstream                              | Difference and risk                                                                                                |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| Source facts → raw theoretical | `qty_theoretical` from effective need view                                                                          | Unrestricted `numeric`; source-specific arithmetic                                                             | Public views culminating in `public.v_actual_needs_effective_orderable`                                           | Derived; Retool master                                      | High precision has no approved operational meaning                                                                 |
| Order-step lookup              | `coalesce(order_step, kg ? 0.1 : 1)`                                                                                | Exact decimal step; current live ingredients are explicitly `0.1 kg` or `1` for current other units            | `ingredient_order_step`                                                                                           | Derived `order_step`                                        | Fallback is legacy policy, not approved Planning precision                                                         |
| Theoretical → orderable        | `y=ceil(qty_theoretical/step)*step`; if `y<2`, keep `y`, else `round(y)`                                            | Whole-number half-up threshold at `2`                                                                          | `theoretical_orderable_qty` in orderable view                                                                     | `qty_theoretical_orderable`                                 | Can reduce the result below source need after an initial ceiling                                                   |
| Actual override                | Store exact `qty_actual` entered                                                                                    | Unrestricted `numeric`; Retool equality to baseline uses `EPS=1e-6`                                            | `js_ppwb_save_actual_need` → `q_ppwb_save_actual_need` → `public.app_upsert_actual_need_overrides_bulk`           | `public.actual_need_overrides.qty_actual`                   | Exact override can bypass the orderable baseline step                                                              |
| Baseline orderable             | Public effective view supplies `qty_final_orderable`                                                                | Legacy theoretical/actual view formulas may apply purchase-step logic                                          | `public.v_actual_needs_effective_orderable`                                                                       | Baseline column in the master query                         | The baseline is orderable, but an exact override takes precedence in the active master and rebalance               |
| Master quantity                | `sl=coalesce(actual_need_overrides.qty_actual,v_actual_needs_effective_orderable.qty_final_orderable)`              | JS `toFixed(6)` and `EPS=1e-6` for selected comparisons                                                        | `q_ppwb_master_load`, seed/merge transformers                                                                     | Optimistic `st_ppwb_master_rows`; displayed by master table | Exact override precision can become an operational total without an explicit purchase-step preview                 |
| Save-triggered rebalance       | For all but final sorted row: `round(old_portion*new_total/old_total,6)`; final row receives `new_total-sum(prior)` | Proportional; sort `supplier_id,group_token`; old total `<=0` gives all to first; new total `<=0` deletes rows | `public.app_upsert_actual_need_overrides_bulk` → `public.fn_rebalance_purchase_assignments_for_keys_fast`         | `public.purchase_assignments.split_qty/split_ratio`         | Residual recipient is a technical sort result; no preview                                                          |
| Detail pool/default            | Existing raw portions; if none, propose all to preferred supplier by priority then ID                               | Default row is optimistic and not persisted yet                                                                | `q_ppwb_detail_pool_load` → public views/tables → pool/detail seed                                                | Local state                                                 | Supplier introduction appears without a formal preview/audit decision                                              |
| Manual portion edits           | Exact positive `split_qty`; ratio=`split_qty/total`                                                                 | Ratio may retain JS float; total compare `abs(diff)<=0.000001`                                                 | Detail table → merge transformer                                                                                  | Optimistic detail state                                     | Portion need not be a multiple of order step                                                                       |
| Split/remove                   | Split selected quantity in half using `round6`; remove pushes its quantity to adjacent remaining row                | Six decimals; local residual preserved                                                                         | `js_ppwb_detail_split_line`, `js_ppwb_detail_remove_line`                                                         | Local state only                                            | Row order affects result; supplier identity may be duplicated                                                      |
| Manual “Cân bằng”              | Sequential fill/cap: each prior row gets `min(wanted,remaining)`; final row gets remainder                          | `round6` after every operation; row order is decisive                                                          | `js_ppwb_detail_autobalance`                                                                                      | Local state                                                 | Contradicts proportional server behavior                                                                           |
| Detail save                    | Validate positive exact portions and epsilon total; destructive family replacement                                  | No tick/multiple constraint; exact values passed                                                               | `js_ppwb_detail_save` → `q_ppwb_detail_replace_family` → `public.app_replace_purchase_assignments_family_planner` | Delete and reinsert family; then optimistic state update    | No authoritative post-write readback; exported JS also contains duplicate declarations requiring live verification |
| Assignment feed                | `ceil_to_step(persisted split_qty,order_step)`                                                                      | Upward per portion                                                                                             | Public assignment feed/views                                                                                      | Derived feed                                                | Feed can differ from persisted portion and inflate aggregate                                                       |
| PO confirmation                | `sum(persisted split_qty)` by supplier/date/school/ingredient                                                       | Unrestricted `numeric`; no new rounding                                                                        | `q_po_confirm` → `public.app_confirm_purchase_orders`                                                             | `public.purchase_order_lines.qty`                           | Exact assignment sum, even if portions violate step                                                                |
| Dispatch confirmation          | `ceil_to_step(sum(all supplier portions for school/ingredient),order_step)`                                         | Second upward rounding                                                                                         | `q_dispatch_confirm` → `public.app_confirm_dispatch`                                                              | `public.dispatch_lines.qty`                                 | May differ from PO/allocation; violates single-snapshot direction                                                  |
| Document/export display        | PO formatter uses whole number or one decimal (`Math.round(x*10)/10`); Dispatch XLSX writes raw numeric             | Client floating-point formatting                                                                               | PO/Dispatch export transformers                                                                                   | Supplier PDF/XLSX; Dispatch XLSX                            | Display precision can hide stored quantity and differs by document                                                 |

### 5.1 Retool arithmetic and state classification

| Evidence                | Exact observed behavior                                                                               | Classification                                      |
| ----------------------- | ----------------------------------------------------------------------------------------------------- | --------------------------------------------------- |
| `EPS`                   | `0.000001` for master status and detail total comparison                                              | Technical comparison only                           |
| `toFixed(6)` / `round6` | Stabilizes deltas, split ratios, half-splits, sequential remaining values                             | Computational convention, not operational precision |
| Split ratio             | Detail seed/merge uses `round6(split_qty/total_qty)`; detail save sends an unrounded JS division      | Derived and inconsistent                            |
| Proportional rebalance  | Active master save reaches the public fast backend rebalance function                                 | Server-side but hidden and unpreviewed              |
| Sequential fill/cap     | Manual `js_ppwb_detail_autobalance`                                                                   | Client-owned legacy behavior                        |
| Exact manual portions   | Detail save passes entered `split_qty` after epsilon total validation                                 | Persisted but not step-validity enforced            |
| Optimistic local state  | Master/detail transformers and detail save rewrite Retool states                                      | Present; can diverge from backend                   |
| Backend readback        | Master save invokes the refresh controller after save; detail save updates local state without reload | Partial and inconsistent                            |

The active master controller calls `q_ppwb_save_actual_need`; both that query and the duplicate `q_ppwb_master_save_and_rebalance` query invoke `public.app_upsert_actual_need_overrides_bulk`, but the duplicate is not the controller target. Activity is therefore established from invocation, not names or comments.

The active public grain is `service_date + school_id + ingredient_id`. The active bulk upsert stores the exact submitted `qty_actual` in `public.actual_need_overrides`, then rebalances the union of existing assignment families and positive baseline families. The public fast rebalance uses the override first and otherwise `qty_final_orderable`, may insert the preferred supplier when no assignment exists, rounds proportional non-final rows to six decimals, gives the final technically sorted row the exact residual, and deletes family rows when the new total is nonpositive.

### 5.2 Live function and trigger classification

Classification is scoped to the reviewed Purchase Planner invocation, not to every possible external caller.

| Object                                                                                         | Classification           | Evidence and consequence                                                                                                                     |
| ---------------------------------------------------------------------------------------------- | ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `public.app_upsert_actual_need_overrides_bulk`                                                 | ACTIVE / RETAINED EXPORT | Direct target of `q_ppwb_save_actual_need`; stores exact override and calls the public fast rebalance                                        |
| `public.fn_rebalance_purchase_assignments_for_keys_fast`                                       | ACTIVE / TRANSITIVE      | Called by the active public bulk upsert; proportional six-decimal non-final rows and exact final-row residual                                |
| `public.app_replace_purchase_assignments_family_planner`                                       | ACTIVE / RETAINED EXPORT | Direct target of `q_ppwb_detail_replace_family`                                                                                              |
| `public.app_confirm_purchase_orders`                                                           | ACTIVE / RETAINED EXPORT | Direct target of `q_po_confirm`                                                                                                              |
| `public.app_confirm_dispatch`                                                                  | ACTIVE / RETAINED EXPORT | Direct target of `q_dispatch_confirm`; applies a second ceiling                                                                              |
| `q_ppwb_master_save_and_rebalance` → `public.app_upsert_actual_need_overrides_bulk`            | DUPLICATE QUERY          | Same backend target as the active save query, but `js_ppwb_save_actual_need` selects `q_ppwb_save_actual_need`                               |
| `ops_v2.app_upsert_actual_need_overrides_bulk` and OPS_V2 planner rebalance                    | OPS_V2 PRESENT           | Present in live/schema evidence at `service_date + school_id + effective_line_key`; no retained-export invocation establishes this as active |
| `ops_v2.app_replace_purchase_assignments_family_planner`                                       | OPS_V2 PRESENT           | Present at the OPS_V2 effective-line grain; no retained-export invocation establishes activity                                               |
| `ops_v2.app_confirm_purchase_orders` and `ops_v2.app_confirm_dispatch`                         | OPS_V2 PRESENT           | Present with OPS_V2 line objects; no retained-export invocation establishes either as the retained app target                                |
| Public `app_upsert_*_planner`, `fn_rebalance_*_planner`, and other unsuffixed/school-day forms | PRESENT / UNTRACED       | Names and schema comments do not establish activity without an invocation                                                                    |
| Public `*_exact` and non-planner family replacement variants                                   | DEPRECATED / UNTRACED    | Live comments label them transitional/deprecated-soon; no retained-export invocation                                                         |
| Public and OPS_V2 triggers                                                                     | PRESENT / SCOPE-SPECIFIC | Trigger attachment identifies schema behavior, not which application path is active                                                          |
| Any untraced external callers                                                                  | UNKNOWN                  | Must be inventoried before legacy retirement                                                                                                 |

The two schema families must remain distinct: public objects use `service_date + school_id + ingredient_id`, while OPS_V2 objects use `service_date + school_id + effective_line_key`. Named live formulas, views, function variants, triggers, types and constraints materially matched the retained schema during the focused comparison; live definitions remain current object evidence, while the retained export establishes the active app path. Reviewed quantity and ratio columns use unrestricted PostgreSQL `numeric`; no reviewed constraint establishes a universal six-decimal scale, step multiples, exact allocation totals, or PO/Dispatch equality.

## 6. Legacy contradictions that Atlas must not copy

1. The active public master and fast rebalance prefer the exact actual override over the orderable baseline, so an override can become the operational total without a visible purchase-step decision.
2. The orderable total and supplier total can diverge until hidden server rebalance or manual action occurs.
3. Server save uses proportional rebalance while Retool “Cân bằng” uses sequential fill/cap.
4. Six-decimal calculations are shown or persisted despite meaningful operational steps.
5. PO uses exact portions while Dispatch re-ceils their aggregate.
6. Persisted values may contain more precision than the PO formatter displays; Dispatch formatting follows another rule.
7. A preferred supplier may be proposed automatically, and the active public fast path can insert it automatically, without a formal operator preview.
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

### 9.1 Accepted lifecycle

The accepted connected lifecycle is:

```text
Wholesale source
→ CMD-02 creates released Confirmed Need Batch/line revisions
→ CMD-03 consumes the current Confirmed Need Batch and creates Purchase Handoff directly in RELEASED_TO_PROCUREMENT, version 1
→ CMD-04 consumes the released Purchase Handoff revision and creates a released Dispatch Requirement
```

CMD-03 creates the handoff already released to Procurement, so the accepted API exposes no pre-release Purchase Handoff line as an insertion point for PA-06D.

### 9.2 What exists

- CMD-01 records wholesale requested quantities.
- CMD-02 releases direct-pass-through theoretical and confirmed quantities for the wholesale slice.
- CMD-03 releases exact Purchase Handoff quantities.
- CMD-04 releases exact Dispatch Requirement quantities.
- CMD-05 allocates exactly one full requirement line to one supplier and requires allocated quantity/unit equality.
- CMD-06 releases one supplier PO from that allocation.
- Shared command receipt, event, audit, stale, idempotency and authorization envelopes are reusable.

### 9.3 What is absent

- No separate Planning Operational Quantity or Quantity Decision aggregate exists.
- No effective-dated quantity rule-set version, Planning step, purchase-step decision, rounding difference, or tick representation exists in the accepted boundary.
- PA-05E cannot represent split supplier portions through its command: it requires one complete line occurrence and exact full-line equality, even though underlying revision shapes contain line identity.
- No backend rounding/rebalancing preview and no commit bound to a preview hash/version exist.
- No residual policy, manual fixed-portion policy, or exact tick invariant exists.
- Authorized requirement queue/detail, supplier eligibility, current allocation detail, and PO release queue reads are absent, as PA-06A classified.
- No authorized post-commit readback exposes the proposed quantity/allocation aggregate.
- Browser access to private Planning/Procurement tables remains prohibited.

### 9.4 Smallest follow-ups

**Insertion-point resolution:** PA-06E retains the versioned Confirmed Need line revision itself as the Planning decision boundary; it does not add a separate Quantity Decision. PA-06E proposes a later authorized review read, backend preview, preview-bound confirmation, receipt/event/audit, and authoritative readback. CMD-03 and the canonical registry remain unchanged until a separate implementation contract is approved.

**Alternative requiring architecture change:** define an explicit new intermediate object between Confirmed Need and Purchase Handoff, then amend the domain lifecycle, command contracts, registry, lineage, authorization, events, audit, tests, and UI. This is not an implementation shortcut and is not approved by PA-06D.

**Smallest later UI follow-up:** after an insertion point and backend contract are explicitly approved, implement only the Requirement Quantity Review workbench, including preview, exact Vietnamese confirmation, stale recovery, returned snapshot and authorized readback. The Supplier Allocation workbench remains non-mutating until a later split-allocation backend contract exists.

## 10. Required conclusion

1. **Approved precision separation:** calculation precision, comparison epsilon, ratio precision, Planning step, purchase step, persisted precision and display precision remain distinct.
2. **Recommended quantity model:** high-precision derivation followed by versioned operational quanta/ticks and exact equality.
3. **Recommended purchase rounding:** upward only to the effective purchase step; remove the legacy whole-number threshold at `2` unless explicitly re-approved.
4. **Recommended rebalancing:** preserve current proportions, calculate precise entitlements, allocate whole ticks by largest remainder and a visible business residual priority, preview, confirm, then persist exact shown values.
5. **WYSIWYG:** final confirmation, commit result, readback, PO source and Dispatch source are the same exact snapshot.
6. **Legacy contradictions:** exact-vs-orderable overrides, hidden proportional-vs-sequential rebalance, six-decimal operational leakage, assignment-feed re-ceiling, PO-vs-Dispatch re-ceiling, document formatting loss, automatic supplier/zero deletion behavior and technical residual ordering are all prohibited carryovers.
7. **Preferred future insertion point:** PA-06D-H1 Quantity Decision preview/confirmation on a Confirmed Need line/revision, with CMD-03 consuming the confirmed decision; recommended, not approved.
8. **Smallest UI follow-up:** Requirement Quantity Review only after the insertion point, backend contract, and any CMD-03 change are approved and implemented.
9. **Deferred:** multi-supplier command, fixed portions, supplier-specific steps, released-PO correction, document generation and rollout.
10. **Awaiting product approval:** exact Planning steps, fallback purchase steps, removal of threshold `2`, supplier-specific step precedence, fixed portions, residual priority/ties, automatic supplier proposal, zero behavior, released-PO correction path, rule owner and effective-date governance.
