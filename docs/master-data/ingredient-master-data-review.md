# Ingredient Master Data Review

**Document ID:** OPS-MD-001  
**Status:** Working checklist  
**Owner:** Product Owner / Planning team  
**Review required:** Yes — staff and product owner review required before table definition is finalized

---

## 1. Purpose

This document defines how staff should review the ingredient master list before OPS ERP table definitions and calculation rules are finalized.

The goal is not only to clean ingredient names. The goal is to make every ingredient usable for:

- recipe calculation;
- purchase planning;
- supplier assignment;
- dispatch preparation;
- traceable calculation rules;
- future audit and reporting.

No requirement engine should be implemented until the ingredient master list is clean enough to support calculation rules without hidden assumptions.

---

## 2. Review principle

Ingredient master data must support this principle:

> Every calculation behavior must come from editable, inspectable, traceable rules, not from hard-coded magic logic.

Therefore, staff review must identify which fields belong to the ingredient itself and which fields belong to configurable rules.

Example:

- `ingredient_name = Hẹ` is master data.
- `Hẹ can be calculated as herb allowance below a threshold` is calculation-rule configuration.
- `Hẹ purchase unit = kg or bó` is purchasing master data.
- `1 bó = X gram` may be an ingredient-specific unit conversion rule.

---

## 3. Required review columns

The ingredient review file should contain at least the following columns.

| Column | Meaning | Required now? | Notes |
|---|---|---:|---|
| ingredient_id | Existing system identifier | Yes | Preserve legacy reference where applicable |
| canonical_name_vi | Official Vietnamese name | Yes | Staff-facing name |
| canonical_name_en | English reference name | Optional | Useful for developers and Codex, not always required |
| alias_names | Common alternate names | Recommended | Helps import/search matching |
| active_status | Active/inactive | Yes | Inactive items should not be selectable for new recipes/orders |
| ingredient_group | Business group | Yes | Needed for filtering and rule inference |
| purchase_unit | Default purchase unit | Yes | Example: kg, g, bó, chai, bịch, thùng |
| recipe_unit | Default recipe input unit | Yes | May differ from purchase unit |
| storage_unit | Storage/counting unit | Later | Required if inventory is implemented |
| order_step | Minimum order increment | Recommended | Example: 0.1 kg, 1 bó, 1 thùng |
| supplier_required | Whether supplier assignment is required | Recommended | Some internal/optional lines may not need supplier |
| default_supplier | Main supplier if known | Optional | Not final supplier assignment logic |
| dual_use_possible | Can be main ingredient and condiment/herb? | Yes for review | Example: hẹ, hành lá, ngò |
| possible_usage_classes | MAIN/HERB/CONDIMENT/GARNISH/SEASONING | Draft | Staff may review after groups are cleaned |
| needs_unit_conversion_rule | Yes/no | Recommended | Example: bó to gram |
| needs_batch_allowance_rule | Yes/no | Recommended | Candidate only, not final threshold |
| notes | Staff notes | Recommended | Capture uncertainty instead of guessing |

---

## 4. Ingredient group guidance

Initial candidate groups:

- MEAT
- SEAFOOD
- VEGETABLE
- HERB
- CONDIMENT
- SEASONING
- DRY_GOODS
- FRUIT
- BEVERAGE
- PACKAGING
- OTHER

These are not final table values yet. They are review categories.

The final table definition should be confirmed after staff review.

---

## 5. Dual-use ingredient review

Staff should mark ingredients that may be used in different calculation roles.

Examples:

| Ingredient | Main use example | Herb/condiment use example | Review note |
|---|---|---|---|
| Hẹ | Soup ingredient | Garnish / rau nêm | Needs threshold and batch allowance review |
| Hành lá | Stir-fry ingredient | Garnish / finishing herb | Likely dual-use |
| Ngò | Rarely main | Garnish | Likely herb allowance |

The review should not force a final threshold yet. Thresholds should be confirmed only after recipe quantities are reviewed.

---

## 6. What staff should not decide yet

Staff do not need to decide the final calculation formula during ingredient review.

Do not ask staff to finalize:

- exact herb/condiment thresholds;
- exact allowance quantities;
- exact batch sizes;
- final SQL table structure;
- final rule precedence.

Staff should only identify candidates and unclear cases.

---

## 7. Output expected from staff review

The reviewed ingredient list should allow the Product Owner to confirm:

1. Which ingredients are active.
2. Which ingredient names are canonical.
3. Which groups should exist.
4. Which purchase and recipe units are valid.
5. Which ingredients need unit conversion rules.
6. Which ingredients may need herb/condiment batch allowance rules.
7. Which items should be merged, split, or deprecated.

---

## 8. Blocking issues

The following issues block final table definition:

- duplicate active ingredient records for the same real ingredient;
- unclear purchase unit;
- unclear recipe unit;
- ingredients used in recipes but inactive or missing;
- supplier-linked ingredients that cannot be mapped back to canonical ingredient records;
- dual-use ingredients with no clear group or review note.

---

## 9. Review status

Current status: staff review pending.

Product Owner confirmation is required before finalizing:

- ingredient table definition;
- ingredient group table definition;
- unit conversion model;
- herb/condiment allowance rule configuration.
