# Calculation Rule Configuration Model

**Document ID:** OPS-MD-005  
**Status:** Draft — architecture direction accepted, field definitions pending review  
**Authority:** Configurable calculation-rule model  
**Review required:** Yes — product owner review required before requirement-engine implementation

---

## 1. Purpose

This document defines how OPS ERP should represent calculation behavior as editable, inspectable, and traceable rules.

It supports the core principle:

> No calculation behavior may exist as hidden or hard-coded magic logic.

---

## 2. Rule categories

Initial calculation rule categories:

| Rule category | Purpose |
|---|---|
| PROPORTIONAL_RECIPE | Standard recipe quantity per basis portions |
| HERB_CONDIMENT_ALLOWANCE | Batch allowance for small herbs/condiments |
| UNIT_CONVERSION | Convert between recipe, purchase, and storage units |
| PROCUREMENT_ROUNDING | Convert effective requirement into orderable quantity |
| PACKAGE_SIZE | Respect supplier/package constraints |
| MINIMUM_ORDER_QUANTITY | Enforce minimum purchase quantity |
| FACTOR_ADJUSTMENT | Apply approved multipliers where needed |
| MANUAL_OVERRIDE | Authorized manual correction with reason |

---

## 3. Generic rule shape

Each calculation rule should have, at minimum:

```text
rule_id
rule_code
rule_type
rule_name
scope_type
scope_id
priority
effective_from
effective_to
active_status
config_json
created_by
created_at
updated_by
updated_at
```

Where:

- `rule_type` defines the kind of calculation rule.
- `scope_type` defines where the rule applies, for example ingredient, ingredient group, supplier, customer, school type, or global.
- `config_json` holds rule-type-specific parameters, but only for structured config that is validated by backend functions.

---

## 4. Herb/condiment allowance config

Candidate structured fields:

```text
rule_type = HERB_CONDIMENT_ALLOWANCE
scope_type = INGREDIENT_GROUP or INGREDIENT
scope_id = referenced group or ingredient
inferred_usage_class
threshold_quantity_per_recipe_basis
recipe_basis_portions
allowance_batch_size
allowance_quantity_per_batch
allowance_unit
priority
effective_from
effective_to
active_status
```

Example business configuration:

```text
Ingredient group: Rau nêm
Threshold: <= X gram per 100 portions
Allowance: Y gram per 20 portions
```

Final values are pending ingredient and recipe review.

---

## 5. Procurement rounding config

Candidate structured fields:

```text
rule_type = PROCUREMENT_ROUNDING
scope_type = INGREDIENT or INGREDIENT_SUPPLIER
order_step
rounding_method
minimum_order_quantity
purchase_unit
priority
effective_from
effective_to
active_status
```

Candidate `rounding_method` values:

```text
ROUND_UP
ROUND_NEAREST
NO_ROUNDING
PACKAGE_MULTIPLE
```

---

## 6. Unit conversion config

Unit conversion may be represented separately from generic calculation rules if stricter relational modeling is clearer.

However, every conversion still follows the same governance:

- explicit;
- inspectable;
- traceable;
- date-effective where needed;
- not hard-coded except approved global conversions.

---

## 7. Rule precedence

Preliminary precedence:

1. explicit manual override, if authorized and active;
2. explicit recipe-line calculation method, if introduced in a later release;
3. ingredient-specific rule;
4. ingredient-group rule;
5. supplier-specific rule where relevant to procurement/package constraints;
6. global default rule;
7. warning or blocking error if no valid rule exists.

Precedence must be documented in final calculation specification before implementation.

---

## 8. Rule trace output

Every calculated requirement should be able to show:

```text
source_line_id
recipe_line_id or demand_line_id
raw_quantity
raw_unit
applied_rule_ids
calculation_method
effective_quantity
effective_unit
rounding_rule_id
orderable_quantity
orderable_unit
warnings
```

For herb/condiment allowance, trace must include:

```text
original_recipe_quantity
threshold_quantity_per_recipe_basis
allowance_batch_size
allowance_quantity_per_batch
calculated_batch_count
final_allowance_quantity
```

---

## 9. Rule editability

Rules should be editable only by authorized roles.

Potential roles:

- ADMIN;
- MANAGEMENT;
- PLANNING_ADMIN;
- READ_ONLY.

Editing a rule should not silently rewrite released documents.

Changes should affect only new calculation runs unless an authorized recalculation or correction workflow is explicitly triggered.

---

## 10. Rule versioning

Rule versioning can be implemented by:

- effective date ranges;
- immutable historical rule records;
- active/inactive flag;
- created/updated audit fields.

The system must preserve enough information to explain released quantities even after rules change.

---

## 11. Review questions

1. Which rule types must exist in MVP?
2. Which roles may view rules?
3. Which roles may edit rules?
4. Should rule changes require approval?
5. How should rule changes be tested before activation?
6. Should the UI expose a rule-management screen in MVP or rely on admin database maintenance first?

---

## 12. Implementation constraint

Codex must not implement calculation logic directly in React components or hidden helper functions.

Any calculation behavior that affects operational quantities must be represented as backend-authoritative configuration and must produce trace output.
