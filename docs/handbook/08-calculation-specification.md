# OPS ERP Handbook
## 08 — Calculation Specification

**Document ID:** OPS-HANDBOOK-008  
**Status:** Baseline draft  
**Authority:** Calculation pipeline and quantity rules  
**Review required:** Yes — product owner review required before requirement-engine implementation  

---

## 1. Purpose

This document defines the calculation principles for converting demand into operational ingredient requirements.

It is one of the most important documents in OPS ERP because quantity calculation directly affects purchasing, dispatch, cost, and operational trust.

---

## 2. Calculation principle

Every quantity must be explainable.

For every final requirement, the system must be able to explain:

- source demand;
- recipe or direct ingredient line;
- calculation basis;
- adjustments;
- unit conversion;
- rounding;
- warning state;
- release state.

### 2.1 No hidden calculation logic

No calculation behavior may exist as a hidden heuristic, hard-coded exception, or undocumented magic rule.

Any behavior that changes quantity, classification, rounding, supplier assignment, release eligibility, warning status, or downstream operational output must be represented as a rule that is:

- editable or versioned through backend configuration, migrations, or approved rule tables;
- visible to authorized users or maintainers;
- traceable in calculation outputs;
- explainable during review;
- covered by tests before implementation;
- documented in the relevant handbook, module specification, or business-rule register.

Automatic inference is allowed, but inferred results must still expose the rule that produced the inference. The system must never produce an operational quantity because of an invisible shortcut that cannot be inspected later.

---

## 3. Calculation pipeline

```text
Source Demand
    ↓
Recipe Resolution or Direct Ingredient Mapping
    ↓
Raw Requirement Generation
    ↓
Usage-Specific Quantity Treatment
    ↓
Adjustment Application
    ↓
Effective Requirement
    ↓
Aggregation
    ↓
Unit Normalization
    ↓
Procurement Rounding and Packaging
    ↓
Orderable Requirement
    ↓
Supplier Assignment
    ↓
Release Snapshot
```

---

## 4. Source demand

Source demand may come from:

- catering menu demand;
- wholesale ingredient orders;
- pantry additions;
- manual demand;
- correction demand.

Each source demand line must retain a stable identifier.

---

## 5. Recipe resolution

Catering dish demand must resolve to an applicable recipe version.

Recipe resolution may depend on:

- dish;
- school type;
- customer;
- service date;
- active/locked recipe status;
- future recipe applicability rules.

If no valid recipe exists, the system must produce a blocking warning.

---

## 6. Direct ingredient mapping

Wholesale demand bypasses recipe explosion because it already represents ingredient demand.

Wholesale demand still participates in:

- unit normalization;
- aggregation;
- procurement rounding;
- supplier assignment;
- dispatch.

---

## 7. Raw requirement

A raw requirement is the initial quantity before operational adjustments.

For catering:

```text
raw quantity = portion basis × recipe quantity basis
```

The exact formula depends on recipe structure and unit basis.

For wholesale:

```text
raw quantity = ordered ingredient quantity
```

---

## 8. Usage-specific quantity treatment

Some ingredients may be used in more than one operational role.

Example:

- garlic chives / he may be used as a main ingredient in soup;
- the same ingredient may be used as garnish, herb, seasoning, or finishing condiment.

Therefore, calculation treatment must not be determined solely by the ingredient master record.

The same ingredient may be treated differently depending on the recipe line, usage context, and quantity threshold.

### 8.1 Main-ingredient proportional treatment

If a recipe line quantity is above a configured threshold, the line is treated as a main ingredient.

Main-ingredient lines are calculated proportionally from the recipe basis.

Example principle:

```text
calculated quantity = recipe quantity per 100 portions × actual portions / 100
```

### 8.2 Herb / condiment batch allowance treatment

If a recipe line belongs to a configured herb or condiment usage class and the recipe quantity is below a configured threshold, the system may apply a batch allowance rule instead of exact per-portion proportional calculation.

Purpose:

- avoid false precision for very small garnish or herb quantities;
- reduce operational noise;
- make purchasing and kitchen preparation practical;
- avoid optimizing meaningless differences such as 163g versus 173g of herbs.

Example principle:

```text
batch allowance quantity = ceil(actual portions / allowance batch size) × allowance quantity per batch
```

Example business intent:

```text
he as garnish = 40g per 20 portions
```

In this example, the system does not attempt to calculate every gram exactly from the recipe line once the line is classified as herb / condiment batch allowance.

### 8.3 Required configuration

The rule must be configurable, not hard-coded.

Candidate configuration fields:

- ingredient_id or ingredient_group_id;
- inferred_usage_class, for example MAIN, HERB, CONDIMENT, GARNISH, SEASONING;
- threshold_quantity_per_recipe_basis;
- recipe_basis_portions, usually 100 portions;
- allowance_batch_size, for example 10, 20, or 50 portions;
- allowance_quantity_per_batch;
- allowance_unit;
- effective_from;
- effective_to;
- priority;
- active flag.

### 8.4 Precedence

The preliminary precedence is:

1. explicit recipe-line calculation method, if set in a future release;
2. ingredient-specific herb / condiment allowance rule;
3. ingredient-group herb / condiment allowance rule;
4. default proportional calculation.

This precedence must be reviewed before implementation.

### 8.5 Traceability

The final requirement must record whether it was produced by:

- proportional calculation;
- herb / condiment batch allowance;
- manual override;
- substitution;
- another adjustment.

The trace must preserve:

- original recipe quantity;
- applied threshold;
- allowance batch size;
- allowance quantity;
- resulting quantity;
- rule identifier.

### 8.6 MVP inference rule

For MVP, staff should not be required to manually select a usage class for every recipe line.

The system should infer herb / condiment treatment from backend configuration. Manual recipe-line classification may be introduced later for exceptions, but the initial design should reduce data-entry burden.

Inference must remain inspectable. If the system infers a line as herb / condiment batch allowance, the requirement trace must identify the configuration rule that caused the inference.

---

## 9. Adjustments

Supported adjustment categories:

- ADD;
- REMOVE;
- SUBSTITUTE;
- QUANTITY_OVERRIDE;
- FACTOR_ADJUSTMENT.

Adjustments must be explicit, reasoned, auditable, and tied to a specific business context.

---

## 10. Substitution rule

A one-order substitution must not modify the permanent recipe.

A substitution must preserve traceability from the suppressed requirement to the replacement requirement.

Minimum substitution record:

- original requirement identity;
- replacement ingredient;
- quantity method;
- reason;
- user;
- timestamp;
- affected customer/school/date/demand context.

---

## 11. Quantity override rule

A quantity override changes an effective requirement quantity without redefining the permanent recipe.

Overrides must record:

- original calculated quantity;
- override quantity;
- reason;
- user;
- timestamp;
- scope.

---

## 12. Aggregation

Aggregation may occur across:

- service date;
- customer/school;
- ingredient;
- demand source;
- supplier;
- purchase group.

The exact procurement aggregation scope is still an open question and must be resolved before procurement implementation.

---

## 13. Rounding and orderable quantity

Procurement-facing quantities may require:

- order step rounding;
- package-size rounding;
- minimum order quantity;
- purchase unit conversion;
- supplier-specific purchasing constraints.

Rounding rules must be backend-authoritative and versioned or date-effective if they change over time.

Herb / condiment batch allowance is not the same as procurement rounding. It is an upstream requirement-calculation treatment. Procurement rounding may still apply after the batch allowance result is produced.

---

## 14. Warning types

Candidate calculation warnings:

- missing recipe;
- inactive recipe;
- inactive ingredient;
- missing unit conversion;
- missing supplier;
- invalid quantity;
- unusually high quantity;
- substitution without replacement quantity;
- override without reason;
- rounding excess above tolerance;
- released document affected by later change;
- herb / condiment allowance rule missing for configured usage class;
- ambiguous calculation method for ingredient used as both main ingredient and condiment;
- calculation behavior applied without traceable rule identifier.

---

## 15. Release snapshot

Once a purchase order or dispatch document is released, the system must preserve the effective quantity and calculation context used at that time.

Later changes must create correction records rather than silently rewriting the released result.

---

## 16. Backend authority

The frontend may preview quantities, but backend functions must be authoritative for:

- recipe resolution;
- adjustment application;
- usage-specific quantity treatment;
- rounding;
- release validation;
- audit creation.

---

## 17. Review questions

1. What is the exact procurement aggregation level?
2. Should wholesale and catering combine before rounding by default?
3. Which quantity changes require approval?
4. What is the tolerance for rounding excess?
5. What warnings should block release versus only notify the user?
6. Which existing v1 calculation rules should be preserved unchanged?
7. What herb / condiment usage classes should exist initially?
8. Should herb / condiment batch allowance be configured per ingredient, per ingredient group, or both?
9. What default allowance batch sizes should be supported: 10, 20, 50 portions, or configurable arbitrary values?
10. What threshold determines whether a dual-use ingredient is treated as main ingredient versus herb / condiment?
11. Which calculation rules must be visible to business users versus technical maintainers only?
12. What interface is required for viewing rule traces during requirement review?

---

## 18. Implementation note

Codex must not implement the requirement engine until this document is reviewed and the blocking review questions are answered.

Codex must not implement hidden calculation shortcuts. If a calculation behavior cannot be traced back to a documented rule, configuration record, or approved deterministic function, it is not acceptable for production use.
