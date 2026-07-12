# Ingredient Table Definition Guide

**Document ID:** OPS-MD-002  
**Status:** Draft — depends on staff ingredient review  
**Authority:** Master-data table design guidance  
**Review required:** Yes — product owner confirmation required after ingredient review

---

## 1. Purpose

This document defines the intended shape of ingredient master data for OPS ERP.

It is not a final SQL schema yet. It is a design guide to prevent premature table creation before the ingredient list is reviewed.

---

## 2. Design principle

Ingredient master data should describe the ingredient itself.

Calculation behavior must be stored in editable rule tables, not hidden inside ingredient records unless it is truly an ingredient attribute.

Example:

| Concept | Belongs where? |
|---|---|
| Ingredient official name | Ingredient master |
| Ingredient group | Ingredient master or group mapping |
| Default purchase unit | Ingredient master or purchasing profile |
| Supplier-specific package size | Supplier/ingredient purchasing rule |
| Herb allowance threshold | Calculation-rule config |
| Rounding step | Procurement-rule config |
| Unit conversion | Unit conversion rule |

---

## 3. Candidate ingredient entity

Candidate fields:

```text
ingredient_id
canonical_name_vi
canonical_name_en
search_name
active_status
ingredient_group_id
default_recipe_unit_id
default_purchase_unit_id
default_order_step
requires_supplier_assignment
notes
created_at
updated_at
```

Fields still under review:

```text
default_storage_unit_id
is_inventory_tracked
quality_check_required
allergen_tags
food_safety_category
```

These should not be added unless there is a clear operational use in the first release.

---

## 4. Ingredient groups

Ingredient groups are needed for:

- navigation and filtering;
- purchase review;
- calculation-rule inference;
- reporting;
- staff comprehension.

Candidate group design:

```text
ingredient_group_id
group_code
group_name_vi
group_name_en
parent_group_id
active_status
sort_order
```

The group model should support hierarchy, but the MVP may use a flat list if that is simpler.

---

## 5. Aliases

Ingredient aliases should be separated from canonical ingredient records.

Candidate fields:

```text
alias_id
ingredient_id
alias_name
source
active_status
```

Aliases are useful for:

- legacy import matching;
- recipe cleanup;
- supplier naming differences;
- staff search.

---

## 6. Supplier linkage

Do not overload the ingredient master table with all supplier-specific rules.

Supplier linkage should support:

```text
supplier_id
ingredient_id
supplier_item_name
supplier_purchase_unit
package_size
minimum_order_quantity
order_step
lead_time_days
active_status
```

Final supplier assignment rules belong to procurement configuration, not only supplier linkage.

---

## 7. Dual-use ingredients

The table may include a simple review flag such as:

```text
dual_use_possible
```

However, final calculation treatment must come from calculation rules.

Do not hard-code:

```text
is_herb = true
```

as the sole basis for calculation.

Reason: the same ingredient may be main ingredient in one recipe and herb/condiment in another.

---

## 8. Finalization checklist

Before SQL table implementation, Product Owner must confirm:

1. ingredient group list;
2. canonical naming standard;
3. active/inactive policy;
4. unit model;
5. supplier linkage model;
6. whether inventory fields are needed in MVP;
7. whether dual-use review flag is needed in master data;
8. migration strategy from OPS v1 ingredient records.

---

## 9. Implementation constraint

Codex must not create final ingredient schema until this guide and the staff ingredient review output are confirmed.
