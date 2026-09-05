# Authoritative effective Recipe workbench

Status: Product and Architecture design approved by `RECIPE-EFFECTIVE-CONTRACT-01`; implementation design recorded 2026-09-05.

Base: `0779daacb49635dab5b40503f5718dd5f577d6f3`. Scope: Recipe selection, effective composition, adjustment targeting/history, operator reads, and Dish-level Recipe copy. No Warehouse, hosted, Retool, or production mutation is authorized.

## Authority and operator outcome

The Dish workbench becomes the normal operator truth for a Dish. For each supported Recipe scope, `TIỂU HỌC` and `TRUNG HỌC`, the normal locked view shows the current system-effective BOM:

```text
released base Recipe
→ SYSTEM_INGREDIENT
→ SYSTEM_DISH
→ system-effective BOM
```

A School drill-down shows the final School-effective BOM:

```text
released School-Type Recipe, with GENERAL fallback
→ SYSTEM_INGREDIENT
→ SYSTEM_DISH
→ SCHOOL
→ SCHOOL_DISH
→ School-effective BOM
```

PostgreSQL owns Recipe selection, precedence, target applicability, effective dates, lifecycle, history, lineage, and copy atomicity. React consumes shaped contracts and does not select a representative School, replay Change Orders, infer temporal applicability, or filter raw Recipe lines by School Type.

## Central Recipe selection

Introduce one smallest private selection helper for `dish_id` plus nullable `school_type_id`. It selects exactly one active `RELEASED_FOR_PLANNING` Recipe in the exact School-Type scope when one exists, otherwise exactly one active general Recipe. More than one candidate in the winning tier is a blocker; no eligible candidate after fallback is a blocker.

The existing School-based resolver derives `school_type_id` from the authoritative School and calls this same helper. The explicit School-Type system resolver calls the same helper directly. There is one precedence implementation, not parallel School and School-Type variants.

## Effective composition contracts

Add a system-effective resolver/read for explicit `as_of_date`, `dish_id`, and `school_type_id`. It returns the same atomic line semantics as RMVP-02B—Ingredient, quantity, Unit, disposition, stable source identity, source layer, applied lineage, warnings, and blockers—but applies only `SYSTEM_INGREDIENT` and `SYSTEM_DISH`. It never applies `SCHOOL` or `SCHOOL_DISH`.

The School resolver remains the Planning/Need Generation semantic authority and applies all four adjustment layers. It derives School Type from the School and uses the centralized base selection helper. No Need Generation formula or released Planning fact changes.

## Stable effective-line target identity

Every present effective line exposes exactly one stable target origin:

- `RECIPE_LINE` with `target_recipe_line_id` for a base Recipe line; or
- `ADJUSTMENT_LINE` with `adjustment_line_id` for a line created by an applicable `ADD` Change Order.

For `SYSTEM_DISH` and `SCHOOL_DISH`, `ADD` continues to create and own an `adjustment_line_id`. `REPLACE`, `ADJUST_QUANTITY`, and `REMOVE` must provide exactly one of `target_recipe_line_id` or `adjustment_line_id`, never both and never neither. The frozen root identity, target lock, overlap/duplicate detection, resolver transformation, preview, Create, Supersede/Correction, and readback/history use the same target-kind-plus-ID contract.

An adjustment-line target is valid only when that origin line is present in the relevant effective context at the proposal date. Therefore a `SCHOOL_DISH` command can target a visible `SYSTEM_DISH ADD`, and a later `SCHOOL_DISH` command can target an earlier applicable `SCHOOL_DISH ADD`. Removed, expired, cancelled, inapplicable, ambiguous, or otherwise non-effective adjustment lines are blockers. Existing optimistic concurrency and overlapping-rule protection remain fail-closed.

## Effective target-context read

Add one shaped target-context read with two explicit modes:

- system Dish: `as_of_date`, `dish_id`, `school_type_id`;
- School-specific: `as_of_date`, `dish_id`, `school_id`.

It returns selected Recipe identity and scope, basis portions, effective lines, Ingredient display name, exact quantity, Unit, stable target kind and ID, useful source layer, warnings, and blockers. `REPLACE`, `ADJUST_QUANTITY`, and `REMOVE` use these rows. `ADD` continues to select a new active Ingredient.

Because the backend selects the Recipe before shaping targets, general-fallback lines are present in a selected School-Type context without React applying `line.school_type_id === selectedSchoolTypeId`.

## Dish Recipe operator read

Add or extend one shaped operator read for PR B. The system view accepts `dish_id`, `school_type_id`, and `as_of_date` and returns:

- Dish identity, name, and type;
- requested Recipe scope and selected base Recipe business identity;
- basis portions and backend-authoritative editable/locked state;
- current system-effective BOM;
- the count of currently applicable School-specific exceptions;
- allowed actions, blockers, and effective Recipe history.

The School drill-down accepts `dish_id`, `school_id`, and `as_of_date`, returning the same business information, the final School-effective BOM, and history including School-specific Change Orders. Technical UUID/version values may remain internal contract fields when required for commands and lineage, but are not exposed merely for operator display.

## Effective Recipe history

The normal history is `Lịch sử công thức`, not a raw RecipeVersion list. PostgreSQL shapes effective-BOM periods:

```json
{
  "history_periods": [
    {
      "period_from": "date",
      "period_to": "date-or-null",
      "effective_bom": [],
      "change_orders": []
    }
  ]
}
```

Boundaries come from authoritative adjustment `effective_from`, finite `effective_to`, supersession, and cancellation periods. Equal boundaries produce one period boundary. Each period contains the full BOM effective throughout that half-open interval. System history includes system-level Change Orders; School history includes applicable `SYSTEM_INGREDIENT`, `SYSTEM_DISH`, `SCHOOL`, and `SCHOOL_DISH` orders.

Each Change Order tag carries internal `adjustment_id`, action kind, `effective_from`, optional `effective_to`, reason, and attributable issuer/issued-at evidence. Corrected and cancelled revisions remain immutable historical evidence. React never replays revisions to construct history.

## Active Change-Order ledger

Retain backend-derived `temporal_state` and expose `is_effective_now` separately from `effective_from` and `effective_to`. `is_effective_now` is true when the current contributing revision is `ACTIVE`, `ACTIVE_RESUMED`, `ACTIVE_CHANGE_SCHEDULED`, or `ACTIVE_CANCELLATION_SCHEDULED`; it is false for `SCHEDULED`, `EXPIRED`, and `CANCELLED`. React does not infer this flag from dates.

## Dish-level copy command

Add one atomic normal-use command accepting `source_dish_id` and `target_dish_id`. For each supported active scope, `TIỂU HỌC` and `TRUNG HỌC`, it uses the centralized selector to resolve the source Dish's current eligible base Recipe and copies basis plus BOM into the corresponding target Recipe scope.

An absent source scope is reported as `SOURCE_NOT_AVAILABLE`; no Recipe is fabricated. A source general fallback is eligible because it is the authoritative selected base for that requested scope. The command is one transaction across every scope it decides to copy: any required write failure rolls back all target writes. The D-038 approved-menu lock is checked by backend authority before target Recipe/BOM mutation. Exact replay returns the original shaped per-scope result, while reuse of the idempotency key with changed payload fails closed. The lower-level `copy_recipe_version` remains callable for controlled/support callers.

## Security, compatibility, and exclusions

Use existing Recipe read/write capabilities, runtimes, private schemas, forced RLS, fixed search paths, authenticated Actor resolution, global-scope authority, revoke-first grants, optimistic concurrency, receipts, events, and audit evidence unless implementation proves a new permission is unavoidable. React receives no private table access or service-role credential.

All RMVP-02A/RMVP-02B v1/v2 contracts remain callable unless an additive replacement is explicitly documented. Weekly Menu, Attendance, Need Generation formulas, Pantry, Confirmed Need, Procurement, PO lifecycle, Warehouse, Dispatch, OPS v1, Retool, hosted Staging, and production data remain unchanged. There is no deployment and no hosted write.

## Acceptance and verification

Test-first backend coverage must prove centralized selection and GENERAL fallback; system-only versus full School precedence; base and adjustment-line targeting across `SYSTEM_DISH` and `SCHOOL_DISH`; exactly-one target validation; stale/non-effective target rejection; overlap/concurrency preservation; target identity round-trip through Preview and Create; full-BOM history periods including shared boundaries, finite end dates, correction, and cancellation; backend-derived ledger effectiveness; and atomic two-scope Dish copy with absent-scope, target-lock, failure, replay, and idempotency-conflict cases.

Preserve affected RMVP-02A and RMVP-02B pgTAP suites. Run new focused contract suites, relevant API/model Vitest, typecheck, Prettier on touched files, and `git diff --check`. GitHub Actions remains the broad validation authority.

## Design self-review

This design records only the approved `RECIPE-EFFECTIVE-CONTRACT-01` behavior. It centralizes an existing precedence rule rather than creating a new one, extends the existing stable adjustment-line identity rather than adding a business concept, keeps history as a backend read model, preserves D-038 lock authority, and leaves every excluded operational domain unchanged.
