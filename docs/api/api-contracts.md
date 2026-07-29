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

---

## 4A. Implemented connected recipe contract

RMVP-02A implements one shaped Dish/Recipe/BOM workbench read and eleven transactional commands for Dish lifecycle, Recipe-root lifecycle, draft creation, successor correction, full BOM replacement, validation, Planning release, copy, and reviewed workbook import. The exact `RMVP-02A.v1` envelope, permissions, validation, responses, and safe errors are specified in [RMVP-02A Recipe and BOM API contract](rmvp-02a-recipes-bom.md).

## 4B. Implemented connected Pantry contract

PANTRY-02 implements exactly six reviewed APIs for one Planning-owned manual Pantry source: shaped workbench read, non-writing preview, complete draft replacement, validation, immutable approval, and reasoned reopen. The exact `PANTRY-02.v1` registry, capabilities, global scope, envelopes, derived reference authority, signature, side effects, events, audit evidence, safe blocker catalog, and tests are specified in [PANTRY-02 Pantry Source API Contract](pantry-02-source.md).

The planned generic `adjustments_add_pantry_need` item below is not the PANTRY-02 implementation command and remains unimplemented.

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
