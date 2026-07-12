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
