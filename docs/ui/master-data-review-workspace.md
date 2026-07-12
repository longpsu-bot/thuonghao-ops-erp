# UI Specification — Master Data Review Workspace

**Document ID:** OPS-UI-001  
**Status:** Baseline draft  
**Authority:** UI-led, contract-constrained design for master-data review  
**Review required:** Yes — product owner and staff review required before Supabase schema design  

---

## 1. Purpose

The Master Data Review Workspace is the first practical OPS ERP UI prototype.

Its purpose is to help staff review and clean the data that will later drive requirement calculation, procurement, and dispatch.

This workspace must not become the owner of business logic. It should expose review states, data gaps, candidate rules, and staff decisions so the later Supabase schema and RPC design are grounded in real workflow needs.

---

## 2. Why this comes before Supabase schema

The requirement engine depends on:

- ingredient identity;
- ingredient grouping;
- purchase units;
- recipe units;
- unit conversions;
- recipe-line quantities;
- dual-use ingredient treatment;
- herb / condiment allowance rules;
- procurement rounding rules.

These are not fully confirmed yet.

Therefore, the UI should help discover and review these issues before database tables and backend functions are finalized.

---

## 3. Intended users

Primary users:

- planning/admin staff reviewing ingredient records;
- kitchen or operations staff validating recipe quantities;
- product owner reviewing rule implications;
- future developer/Codex using the accepted UI contract.

Secondary users:

- purchasing staff reviewing purchase units and supplier implications;
- management reviewing readiness status.

---

## 4. Workspace modules

The workspace should contain five tabs or sections:

```text
1. Ingredient Review
2. Unit & Conversion Review
3. Recipe Line Review
4. Calculation Rule Candidates
5. Review Summary
```

---

## 5. Tab 1 — Ingredient Review

### 5.1 Goal

Review the ingredient master list and classify each ingredient sufficiently for later calculation and procurement.

### 5.2 Main table columns

Candidate columns:

| Field | Purpose |
|---|---|
| ingredient_id | Existing or temporary identifier |
| ingredient_name_vi | Vietnamese display name |
| ingredient_name_normalized | Canonical internal name |
| ingredient_group | Business grouping |
| is_active | Whether ingredient is still used |
| purchase_unit | Unit used for buying |
| recipe_unit_default | Default unit used in recipes |
| order_step | Procurement rounding step |
| supplier_count | Number of linked suppliers |
| dual_use_candidate | Whether ingredient may be both main and condiment/herb |
| review_status | Pending, Reviewed, Needs Owner Decision |
| issue_count | Number of unresolved issues |
| staff_note | Staff review note |

### 5.3 Filters

- Review status
- Ingredient group
- Active/inactive
- Missing purchase unit
- Missing recipe unit
- Missing supplier
- Dual-use candidate
- Possible duplicate name

### 5.4 Row actions

- Mark reviewed
- Flag issue
- Merge candidate duplicate
- Set ingredient group
- Set default units
- Flag as dual-use candidate
- Add staff note

### 5.5 Warning states

Candidate warnings:

- missing purchase unit;
- missing recipe unit;
- ingredient has recipe usage but inactive;
- ingredient has no supplier;
- possible duplicate names;
- purchase unit and recipe unit require conversion but no conversion rule exists;
- ingredient appears in small recipe quantities and may need herb/condiment treatment.

---

## 6. Tab 2 — Unit & Conversion Review

### 6.1 Goal

Review which unit conversions are valid globally and which require ingredient-specific rules.

### 6.2 Main concepts

Global conversions may include:

```text
g ↔ kg
ml ↔ l
```

Ingredient-specific conversions may include:

```text
bó → kg
gói → g
chai → ml
trái → kg
cây → kg
```

### 6.3 Table columns

| Field | Purpose |
|---|---|
| ingredient_id | Ingredient, if conversion is ingredient-specific |
| ingredient_name_vi | Ingredient name |
| from_unit | Source unit |
| to_unit | Target unit |
| conversion_factor | Numeric factor |
| conversion_scope | Global or Ingredient Specific |
| confidence | Confirmed, Estimated, Unknown |
| effective_from | Start date if needed |
| review_status | Pending, Reviewed, Needs Owner Decision |
| note | Staff note |

### 6.4 Warning states

- conversion needed but missing;
- unit appears in recipes but not allowed;
- purchase unit cannot convert to recipe unit;
- ingredient-specific conversion marked estimated;
- inconsistent conversions for the same ingredient.

---

## 7. Tab 3 — Recipe Line Review

### 7.1 Goal

Review recipe-line quantities to identify suspicious values and confirm whether small quantities should remain proportional or become batch allowance candidates.

### 7.2 Main table columns

| Field | Purpose |
|---|---|
| recipe_id | Recipe identifier |
| dish_name | Dish name |
| ingredient_id | Ingredient identifier |
| ingredient_name_vi | Ingredient name |
| quantity_per_basis | Quantity in recipe |
| basis_portions | Usually 100 portions |
| unit | Recipe unit |
| calculated_usage_hint | Proportional, Batch Allowance Candidate, Needs Review |
| ingredient_group | Ingredient group |
| dual_use_candidate | Whether ingredient may have multiple uses |
| review_status | Pending, Reviewed, Needs Owner Decision |
| staff_note | Staff note |

### 7.3 Filters

- Very small quantity
- Very large quantity
- Dual-use ingredient
- Herb/condiment candidate
- Missing unit conversion
- Recipe line uses inactive ingredient
- Needs owner decision

### 7.4 Warning states

- unusually low quantity;
- unusually high quantity;
- quantity unit inconsistent with ingredient default;
- ingredient appears both as main and small-quantity garnish in different recipes;
- small quantity would create false precision if calculated per head.

---

## 8. Tab 4 — Calculation Rule Candidates

### 8.1 Goal

Show candidate calculation rules derived from staff review, without making them authoritative yet.

### 8.2 Candidate rule types

Initial candidate rule types:

```text
PROPORTIONAL
HERB_CONDIMENT_BATCH_ALLOWANCE
PROCUREMENT_ROUNDING
PACKAGE_SIZE_ROUNDING
MINIMUM_ORDER_QUANTITY
INGREDIENT_SPECIFIC_UNIT_CONVERSION
```

### 8.3 Table columns

| Field | Purpose |
|---|---|
| candidate_rule_id | Temporary identifier |
| rule_type | Rule type |
| ingredient_group | Applies to ingredient group if generic |
| ingredient_id | Applies to ingredient if specific |
| threshold_quantity_per_100 | Threshold for treatment |
| allowance_batch_size | Example: 10, 20, 50 portions |
| allowance_quantity | Quantity per batch |
| allowance_unit | Unit |
| priority | Precedence when multiple rules match |
| inferred_from | Source of candidate rule |
| review_status | Draft, Accepted Direction, Needs Owner Decision, Rejected |
| note | Explanation |

### 8.4 Rule preview

The UI should allow sample preview:

```text
Ingredient: Hẹ
Recipe quantity: 80g / 100 portions
Actual portions: 173
Candidate rule: 40g / 20 portions
Preview result: ceil(173 / 20) × 40g = 360g
```

The preview is advisory only. It must not become the authoritative calculation engine.

---

## 9. Tab 5 — Review Summary

### 9.1 Goal

Show readiness for moving from review into data contract and schema design.

### 9.2 Summary cards

Candidate summary cards:

- total ingredients;
- reviewed ingredients;
- ingredients needing owner decision;
- missing purchase units;
- missing recipe units;
- missing conversions;
- dual-use candidates;
- herb/condiment candidates;
- candidate calculation rules;
- blocking issues before requirement engine design.

### 9.3 Export needs

The workspace should support export of:

- unresolved ingredient issues;
- unit conversion issues;
- recipe-line review issues;
- candidate calculation rules;
- product-owner decision list.

---

## 10. State model

Each row should support a clear review state.

Candidate statuses:

```text
PENDING
REVIEWED
NEEDS_STAFF_FIX
NEEDS_OWNER_DECISION
ACCEPTED_DIRECTION
REJECTED
```

The UI must clearly distinguish:

- staff review outcome;
- product-owner decision;
- calculation rule candidate;
- authoritative backend rule.

---

## 11. Data contract draft

This workspace should initially use mock data or exported legacy data.

The eventual read contract should provide:

```text
IngredientReviewRow[]
UnitConversionReviewRow[]
RecipeLineReviewRow[]
CalculationRuleCandidate[]
ReviewSummary
```

The eventual command contracts may include:

```text
markIngredientReviewed
flagIngredientIssue
updateIngredientReviewFields
markUnitConversionReviewed
flagRecipeLineIssue
createCalculationRuleCandidate
updateCalculationRuleCandidateStatus
exportReviewIssues
```

These contracts are draft only and must be reviewed before Supabase RPC implementation.

---

## 12. Non-goals

This workspace must not initially:

- release purchase orders;
- confirm dispatch;
- calculate authoritative requirements;
- modify production OPS v1 records directly;
- silently change recipe definitions;
- hard-code herb or condiment rules;
- replace staff judgment.

---

## 13. UX principles

- Make review work fast.
- Prioritize table scanning, filters, bulk review, and issue flags.
- Show warnings visibly but do not overwhelm users.
- Use Vietnamese labels for staff-facing UI.
- Preserve English internal field names in technical contracts.
- Every inferred warning or candidate rule must be explainable.

---

## 14. Product-owner review questions

1. Should staff review happen directly in OPS ERP prototype, or first in Excel/Google Sheets and later imported?
2. Which staff should review ingredients, units, and recipe lines?
3. Which fields can staff edit, and which require owner approval?
4. Should candidate rules be generated automatically, manually, or both?
5. What export format is needed for staff review sign-off?
6. Should the first prototype use real exported OPS v1 data or synthetic mock data?

---

## 15. Codex implementation note

Codex may build a mock-data UI prototype for this workspace only after this document is accepted as the initial UI contract.

Codex must not create Supabase tables, migrations, or RPCs for this workspace until the data contracts and product-owner review questions are resolved.
