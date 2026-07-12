# ADR-001 — Herb and Condiment Batch Allowance

**Status:** Proposed  
**Date:** 2026-07-12  
**Related documents:**

- `docs/handbook/08-calculation-specification.md`
- `docs/business-rules/business-rule-register.md`

---

## Context

Some ingredients are dual-use.

For example, garlic chives / he may be used as a main ingredient in a soup recipe, but the same ingredient may also be used as an herb, garnish, finishing condiment, or decoration.

If the ingredient is used as a main ingredient, exact proportional calculation by recipe basis is operationally meaningful.

If the ingredient is used in a very small herb or garnish quantity, exact per-person proportional calculation can create false precision and operational noise. It is not useful to optimize differences such as 163g versus 173g when kitchen practice is better represented by a practical batch allowance such as 40g per 20 portions.

The existing calculation architecture must therefore support quantity treatment by usage context, not only by ingredient master category.

---

## Decision

OPS ERP will support herb / condiment batch allowance as a configurable calculation treatment.

The calculation method for a recipe line may depend on:

- ingredient;
- ingredient group;
- recipe-line usage class;
- quantity per recipe basis;
- configured threshold;
- effective rule period.

If the quantity is above the configured threshold, the line is treated as a main ingredient and calculated proportionally.

If the quantity is below the configured threshold and the line qualifies as herb / condiment usage, the system may calculate the requirement using:

```text
ceil(actual portions / allowance batch size) × allowance quantity per batch
```

Example:

```text
he as garnish = 40g per 20 portions
```

This is a requirement-calculation treatment, not procurement rounding. Procurement rounding may still apply after the batch allowance result is produced.

---

## Consequences

### Positive

- Reduces meaningless precision for small herbs and condiments.
- Better matches kitchen preparation practice.
- Avoids excessive operational noise in purchasing and requirement review.
- Supports dual-use ingredients without duplicating ingredient records.
- Keeps calculation explainable and configurable.

### Tradeoffs

- Requires additional calculation-rule configuration.
- Requires recipe lines or rules to identify usage context.
- Requires a clear threshold policy for main ingredient versus herb / condiment treatment.
- Requires traceability so staff can explain why exact proportional calculation was not used.

---

## Implementation constraints

Codex must not hard-code ingredient names such as he, scallion, cilantro, or any specific herb.

The implementation must use backend-authoritative configuration and record the applied rule in requirement trace output.

Candidate configuration fields:

- ingredient_id;
- ingredient_group_id;
- usage_class;
- threshold_quantity_per_recipe_basis;
- recipe_basis_portions;
- allowance_batch_size;
- allowance_quantity_per_batch;
- allowance_unit;
- effective_from;
- effective_to;
- priority;
- active flag.

---

## Review required

Product owner review is required for:

1. initial herb / condiment ingredient group;
2. default usage classes;
3. default thresholds;
4. allowed allowance batch sizes;
5. whether recipe-line usage class is required in the recipe editor from MVP-1 or can be inferred from rule configuration initially.
