# API Contracts Catalogue

**Status:** Baseline draft  
**Authority:** API inventory and contract index  
**Review required:** No until specific APIs are implemented

---

## 1. Purpose

This file indexes OPS ERP API contracts. Detailed contract definitions should be added before implementation of any business-write operation.

---

## 2. API contract rule

No business-write command should be implemented without documenting:

- owning module;
- purpose;
- request payload;
- response payload;
- permissions;
- validation rules;
- side effects;
- audit events;
- error cases;
- tests.

---

## 3. Planned command contracts

### Demand

- `demand_create_wholesale_order`
- `demand_update_wholesale_order`
- `demand_submit_document`
- `demand_cancel_document`

### Adjustments

- `adjustments_apply_substitution`
- `adjustments_apply_quantity_override`
- `adjustments_add_pantry_need`
- `adjustments_remove_adjustment`

### Requirements

- `requirements_recalculate_for_date`
- `requirements_mark_ready_for_procurement`
- `requirements_get_review_rows`

### Procurement

- `procurement_assign_supplier`
- `procurement_release_purchase_order`
- `procurement_cancel_purchase_order`
- `procurement_correct_released_order`

### Fulfilment

- `fulfilment_create_dispatch_draft`
- `fulfilment_release_dispatch`
- `fulfilment_confirm_delivery`
- `fulfilment_record_shortage`

---

## 4. Planned read models

- requirement review rows;
- procurement planning rows;
- dispatch planning rows;
- warning and exception lists;
- audit timeline;
- legacy master-data adapter views.

## 4.0 Implemented RMVP-01 master-data compatibility

`RMVP-01.v1` retains the existing School, Ingredient, Supplier, Unit and Supplier-priority function names. UI-QUALITY-03C-B additively shapes `get_ingredient_supplier_master_data` with active authoritative Ingredient Type and Ingredient Order Group catalogs and per-Ingredient IDs/display names. `create_ingredient` and `update_ingredient` accept those IDs while retaining exact canonical legacy-name resolution; invalid, inactive-new, unknown or conflicting classification inputs are rejected. The private catalogs are never exposed as browser tables, and no capability, role or public API name is added. The exact authority and importer behavior are specified in [RMVP-01 independent Atlas master data](../architecture/rmvp-01-independent-atlas-master-data.md).

---

## 4A. Implemented connected recipe contract

RMVP-02A implements one shaped Dish/Recipe/BOM workbench read and eleven transactional commands for Dish lifecycle, Recipe-root lifecycle, draft creation, successor correction, full BOM replacement, validation, Planning release, copy, and reviewed workbook import. The exact `RMVP-02A.v1` envelope, permissions, validation, responses, and safe errors are specified in [RMVP-02A Recipe and BOM API contract](rmvp-02a-recipes-bom.md).

## 4B. Implemented connected Pantry contract

PANTRY-02 implements exactly six reviewed APIs for one Planning-owned manual Pantry source: shaped workbench read, non-writing preview, complete draft replacement, validation, immutable approval, and reasoned reopen. The exact `PANTRY-02.v1` registry, capabilities, global scope, envelopes, derived reference authority, signature, side effects, events, audit evidence, safe blocker catalog, and tests are specified in [PANTRY-02 Pantry Source API Contract](pantry-02-source.md).

The planned generic `adjustments_add_pantry_need` item below is not the PANTRY-02 implementation command and remains unimplemented.

## 4C. Implemented connected Planning Input Readiness contract

RMVP-03B implements exactly four reviewed APIs: one shaped exact-period readiness workbench read, one immutable evaluation command, one handoff-only Need Generation request, and one reasoned invalidation command. The surface adds one unbound write capability, reuses existing Planning runtimes and `GLOBAL` scope, and creates no relation, view, role, source trigger, lifecycle state, Need Generation run, or downstream fact. The exact `RMVP-03B.v1` envelopes, candidate matrix, history cursor, receipts, events, audit evidence, safe errors, and non-mutation rules are specified in [RMVP-03B Planning Input Readiness API Contract](rmvp-03b-planning-input-readiness.md).

## 4D. Implemented connected Need Generation contract

RMVP-04 implements exactly five reviewed APIs: one shaped exact-period Need Generation workbench read plus transactional create, validate, release, and invalidate commands. It adds capability `planning.need_generation.write`, dedicated runtime `atlas_need_generation_runtime`, and no relation, view, lifecycle state, source trigger, sequence, or downstream operational record. Confirmed Need creation continues through existing CMD-15. The exact `RMVP-04.v1` envelopes, backend-authoritative calculation and grouping rules, security, actions, safe errors, and materialization connection are specified in [RMVP-04 Connected Need Generation API Contract](rmvp-04-connected-need-generation.md).

## 4E. Implemented connected Confirmed Need review contract

RMVP-05 implements exactly three reviewed APIs: one shaped current Confirmed Need review, one authoritative write-free preview, and one transactional exact quantity-confirmation command. It adds three unbound capabilities and dedicated runtime `atlas_confirmed_need_review_runtime`, while reusing H0B1/H1A/H1B1 and receipt/event/audit persistence with no new business relation, view, lifecycle state, scope kind, sequence, trigger, downstream fact, or production policy seed. The sole exact `RMVP-05.v1` registry is [RMVP-05 Connected Confirmed Need Review API Contract](rmvp-05-connected-confirmed-need-review.md).

## 4F. Implemented connected Confirmed Need validation contract

RMVP-06 implements exactly one new command, `atlas_api.validate_confirmed_needs(jsonb)`, over the existing additive RMVP-05 review. It adds one unbound capability, reuses `atlas_confirmed_need_review_runtime`, persists append-only complete-batch attempts/line observations/issues, commits governed `BLOCKED` evidence without lifecycle/version mutation, and advances a zero-blocker batch exactly once to `VALIDATED`. The exact `RMVP-06.v1` envelope, complete 19-blocker and two-warning registry, cardinality rules, persistence, read shaping, security, and verification are specified in [RMVP-06 Connected Confirmed Need Validation API Contract](rmvp-06-connected-confirmed-need-validation.md).

## 4G. Implemented connected Confirmed Need approval and release contract

RMVP-07 implements exactly two separate complete-batch commands, `atlas_api.approve_confirmed_needs(jsonb)` and `atlas_api.release_confirmed_needs_for_purchase_handoff(jsonb)`, over the existing additive RMVP-05 review. It adds two unbound capabilities, reuses `atlas_confirmed_need_review_runtime`, binds approval to the exact immutable RMVP-06 success through the lifecycle-neutral `RMVP-07-VALIDATED-FACTS.v1` fingerprint, and persists one immutable Planning release for later CMD-03 use. Release creates no Purchase Handoff or downstream fact. The exact `RMVP-07.v1` envelopes, response/replay contracts, persistence, WHOLESALE compatibility, read shaping, security, and verification are specified in [RMVP-07 Connected Confirmed Need Approval and Release API Contract](rmvp-07-connected-confirmed-need-approval-release.md).

## 4H. Confirmed Need two-action v2 boundary

D-037 adds `atlas_api.save_confirmed_needs(jsonb)` (`RMVP-05.v2`) and `atlas_api.release_confirmed_needs(jsonb)` (`RMVP-07.v2`). Save preserves editable work without a 250-line business ceiling. Release internally performs deterministic validation and approval evidence creation before atomic Planning release under the distinct Release capability. Existing v1 functions remain callable; React calls no lifecycle chain. The exact delta is [Confirmed Need Save and Release v2](confirmed-need-save-release-v2.md).

## 4I. Additive atomic Planning completion contracts

PLANNING-CONTRACT-01 implements D-036 with five additive APIs: consequential Weekly Menu, Attendance, and Pantry Saves; automatic Planning preflight; and one atomic Need Generation/materialization command. The versions are `RMVP-03A.v2`, `PANTRY-02.v2`, `RMVP-03B.v2`, and `RMVP-04.v2`. Existing v1 APIs remain callable during UI coexistence. The canonical cross-family implementation, security, persistence, correction, compatibility, and retirement record is [PLANNING-CONTRACT-01 Atomic Planning completion boundaries](../implementation-tasks/TASK-PLANNING-CONTRACT-01-atomic-planning-boundaries.md); family payload detail remains in the four existing API documents.

## 4J. Recipe two-action v2 boundary

D-038 adds `atlas_api.save_recipe(jsonb)` and retains `atlas_api.release_recipe(jsonb)` as a compatibility/support entry point under `RMVP-02A.v2`. Normal `Tạo`/`Lưu` validates, materializes, and makes a pre-commit Dish/Recipe available for future Planning atomically. A Dish appearing in immutable approved Weekly Menu snapshot lines has crossed the committed-use boundary; readback marks it locked and Save denies before creating any successor. Existing RMVP-02A.v1 functions remain callable; React invokes no lifecycle chain or release action. The exact delta is specified in [RMVP-02A Recipe and BOM API contract](rmvp-02a-recipes-bom.md).

## 5. Contract template

```md
## API: command_name

### Owning module

### Purpose

### Request

### Response

### Permissions

### Validation

### Side effects

### Audit

### Errors

### Tests
```
