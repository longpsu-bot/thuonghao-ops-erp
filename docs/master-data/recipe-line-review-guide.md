# Recipe Line Review Guide

**Document ID:** OPS-MD-004  
**Status:** Draft — depends on ingredient and recipe review  
**Authority:** Recipe/BOM line cleanup before calculation-engine implementation  
**Review required:** Yes — product owner and planning team review required

---

## 1. Purpose

This document defines how staff should review recipe lines before OPS ERP implements the requirement engine.

The goal is to identify recipe data problems and calculation-rule needs before they become software bugs.

---

## 2. Review principle

A recipe line must be clear enough to answer:

1. Which dish uses the ingredient?
2. Which ingredient is used?
3. What quantity is required?
4. What unit is the quantity expressed in?
5. What recipe basis does the quantity refer to?
6. Should the line be calculated proportionally or by a special rule?
7. If special, which visible rule explains it?

---

## 3. Required review columns

| Column | Meaning | Required now? |
|---|---|---:|
| recipe_id | Existing or target recipe identifier | Yes |
| dish_id | Dish identifier | Yes |
| dish_name | Staff-facing dish name | Yes |
| school_type_or_customer_scope | Scope where recipe applies | Yes if applicable |
| ingredient_id | Canonical ingredient identifier | Yes |
| ingredient_name | Staff-facing ingredient name | Yes |
| quantity_per_basis | Quantity per recipe basis | Yes |
| unit | Recipe unit | Yes |
| recipe_basis_portions | Usually 100 portions | Yes |
| active_status | Whether line is active | Yes |
| locked_status | Whether production recipe is locked | Recommended |
| review_flag | OK / CHECK / FIX / REMOVE | Yes |
| possible_calculation_issue | Optional notes | Recommended |

---

## 4. Suspicious line checks

Staff should flag recipe lines where:

- quantity is blank or zero;
- unit is missing;
- ingredient is inactive;
- ingredient name is not canonical;
- quantity looks too small for a main ingredient;
- quantity looks too large for an herb/condiment;
- ingredient is dual-use and may need threshold logic;
- unit is a package/bundle but no conversion is known;
- recipe line duplicates another line;
- line belongs to old/deprecated recipe version.

---

## 5. Dual-use ingredient checks

For ingredients such as hẹ, hành lá, ngò, or similar items, staff should flag whether the line appears to be:

```text
MAIN
HERB
CONDIMENT
GARNISH
SEASONING
UNKNOWN
```

This is a review aid only. MVP should infer usage treatment from backend configuration to reduce staff data-entry burden.

---

## 6. Herb/condiment allowance review

For candidate herb/condiment lines, staff should capture:

| Field | Meaning |
|---|---|
| current_quantity_per_100 | Current recipe quantity |
| current_unit | Current unit |
| suggested_batch_size | 10, 20, 50 portions, or other |
| suggested_allowance_quantity | Practical kitchen quantity per batch |
| reason | Why exact per-portion calculation is not useful |

Example:

```text
Ingredient: Hẹ
Use: Garnish / rau nêm
Current issue: exact per-person calculation creates meaningless gram differences
Candidate rule: 40g per 20 portions
```

---

## 7. What not to change casually

Staff should not change production recipe quantities only to make the software easier.

Changes to recipe lines should represent real operational practice.

Software should adapt to true kitchen logic, not force kitchen logic into convenient code.

---

## 8. Review outcomes

Each recipe line should end with one of these statuses:

```text
OK
FIX_INGREDIENT
FIX_UNIT
FIX_QUANTITY
NEEDS_CONVERSION_RULE
NEEDS_BATCH_ALLOWANCE_RULE
NEEDS_PRODUCT_OWNER_DECISION
DEPRECATED
```

---

## 9. Blocking conditions

The following block calculation-engine implementation:

- active recipe lines with missing ingredient IDs;
- active recipe lines with missing units;
- package/bundle units without conversion rules;
- dual-use ingredient patterns with no rule strategy;
- no agreed recipe basis;
- no way to identify active recipe versions.

---

## 10. Implementation constraint

Codex must not implement special-case recipe-line logic based on ingredient names, dish names, or assumptions from sample data.

All calculation behavior must come from approved rules, configuration, or explicitly reviewed recipe-line data.
