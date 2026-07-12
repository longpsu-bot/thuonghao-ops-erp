# ADR-001 — Herb and Condiment Batch Allowance

**Status:** Accepted direction; configuration details pending ingredient and recipe review  
**Date:** 2026-07-12  
**Related documents:**

- `docs/handbook/08-calculation-specification.md`
- `docs/business-rules/business-rule-register.md`
- `docs/open-questions/open-questions-register.md`

---

## Context

Some ingredients are dual-use.

For example, garlic chives / he may be used as a main ingredient in a soup recipe, but the same ingredient may also be used as an herb, garnish, finishing condiment, or decoration.

If the ingredient is used as a main ingredient, exact proportional calculation by recipe basis is operationally meaningful.

If the ingredient is used in a very small herb or garnish quantity, exact per-person proportional calculation can create false precision and operational noise. It is not useful to optimize differences such as 163g versus 173g when kitchen practice is better represented by a practical batch allowance such as 40g per 20 portions.

The calculation architecture must therefore support quantity treatment by usage context, not only by ingredient master category.

This must still follow the OPS ERP calculation-governance principle: every calculation behavior must be editable or versioned, visible to authorized users or maintainers, traceable in outputs, and explainable during review. Herb / condiment treatment must not become a hidden heuristic or magic rule.

---

## Decision

OPS ERP will support herb / condiment batch allowance as a configurable calculation treatment.

The calculation method for a recipe line may depend on:

- ingredient;
- ingredient group;
- inferred usage class;
- recipe-line usage class when explicitly provided in the future;
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

The system must record which rule caused the treatment. A final requirement produced by herb / condiment batch allowance must be traceable back to the applied configuration record or approved deterministic rule.

---

## Product-owner review outcome on 2026-07-12

The following implementation direction is accepted:

1. Staff are reviewing the ingredient master list. Initial herb / condiment groups will be confirmed after this review.
2. Default usage classes will be confirmed after ingredient review.
3. Thresholds must be determined after both ingredient review and recipe quantity review.
4. The architecture should support a generic configuration-driven rule first, not one hard-coded rule per herb. Ingredient-specific overrides may be added later only where operational evidence requires them.
5. For MVP, the system should infer herb / condiment treatment from configuration to reduce staff data-entry burden. Recipe editors should not require manual usage-class entry for every line at the beginning.
6. No inference may operate as an invisible shortcut. Inference rules must be inspectable and traceable.

---

## Consequences

### Positive

- Reduces meaningless precision for small herbs and condiments.
- Better matches kitchen preparation practice.
- Avoids excessive operational noise in purchasing and requirement review.
- Supports dual-use ingredients without duplicating ingredient records.
- Keeps calculation explainable and configurable.
- Reduces recipe-entry burden by allowing inference from backend configuration.
- Preserves operational trust by making automatic inference auditable.

### Tradeoffs

- Requires additional calculation-rule configuration.
- Requires careful master-data review before thresholds are finalized.
- Requires a clear threshold policy for main ingredient versus herb / condiment treatment.
- Requires traceability so staff can explain why exact proportional calculation was not used.
- Auto-inference may occasionally classify a line incorrectly; therefore manual override capability should remain available for exceptional cases.

---

## Implementation constraints

Codex must not hard-code ingredient names such as he, scallion, cilantro, or any specific herb.

The implementation must use backend-authoritative configuration and record the applied rule in requirement trace output.

MVP implementation should infer treatment from configuration. It may expose explicit recipe-line calculation method later, but this should not be required for every recipe line at launch.

Candidate configuration fields:

- ingredient_id;
- ingredient_group_id;
- inferred_usage_class;
- threshold_quantity_per_recipe_basis;
- recipe_basis_portions;
- allowance_batch_size;
- allowance_quantity_per_batch;
- allowance_unit;
- effective_from;
- effective_to;
- priority;
- active flag.

Every automatic inference result must expose:

- applied rule identifier;
- matched ingredient or ingredient group;
- threshold used;
- recipe-line quantity basis;
- allowance batch size;
- allowance quantity;
- effective rule date;
- whether an ingredient-specific or group-level rule was used.

---

## Deferred configuration decisions

Product owner confirmation is still required for:

1. initial herb / condiment ingredient group after ingredient-list review;
2. default usage classes after ingredient-list review;
3. default thresholds after ingredient and recipe-quantity review;
4. default allowance batch sizes and allowance quantities after recipe review;
5. whether exceptional recipe lines need explicit manual classification in a later release.
