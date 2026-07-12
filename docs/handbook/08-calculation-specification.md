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

---

## 3. Calculation pipeline

```text
Source Demand
    ↓
Recipe Resolution or Direct Ingredient Mapping
    ↓
Raw Requirement Generation
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

## 8. Adjustments

Supported adjustment categories:

- ADD;
- REMOVE;
- SUBSTITUTE;
- QUANTITY_OVERRIDE;
- FACTOR_ADJUSTMENT.

Adjustments must be explicit, reasoned, auditable, and tied to a specific business context.

---

## 9. Substitution rule

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

## 10. Quantity override rule

A quantity override changes an effective requirement quantity without redefining the permanent recipe.

Overrides must record:

- original calculated quantity;
- override quantity;
- reason;
- user;
- timestamp;
- scope.

---

## 11. Aggregation

Aggregation may occur across:

- service date;
- customer/school;
- ingredient;
- demand source;
- supplier;
- purchase group.

The exact procurement aggregation scope is still an open question and must be resolved before procurement implementation.

---

## 12. Rounding and orderable quantity

Procurement-facing quantities may require:

- order step rounding;
- package-size rounding;
- minimum order quantity;
- purchase unit conversion;
- supplier-specific purchasing constraints.

Rounding rules must be backend-authoritative and versioned or date-effective if they change over time.

---

## 13. Warning types

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
- released document affected by later change.

---

## 14. Release snapshot

Once a purchase order or dispatch document is released, the system must preserve the effective quantity and calculation context used at that time.

Later changes must create correction records rather than silently rewriting the released result.

---

## 15. Backend authority

The frontend may preview quantities, but backend functions must be authoritative for:

- recipe resolution;
- adjustment application;
- rounding;
- release validation;
- audit creation.

---

## 16. Review questions

1. What is the exact procurement aggregation level?
2. Should wholesale and catering combine before rounding by default?
3. Which quantity changes require approval?
4. What is the tolerance for rounding excess?
5. What warnings should block release versus only notify the user?
6. Which existing v1 calculation rules should be preserved unchanged?

---

## 17. Implementation note

Codex must not implement the requirement engine until this document is reviewed and the blocking review questions are answered.
