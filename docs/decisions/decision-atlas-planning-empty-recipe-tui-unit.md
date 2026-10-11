# Atlas Planning catch-up: incomplete Recipe roots and Túi Unit

Status: Accepted by explicit Owner decision on 11 October 2026. Applies to the existing Planning master/range Draft PR. Hosted master apply remains separately gated; Live OPS and Retool changes remain prohibited.

## Incomplete source composition

`ZERO_BOM_RECIPE_POLICY = PRESERVE_RECIPE_ROOT_WITHOUT_RECIPE_VERSION`.

An active OPS_V1 Recipe with no positive valid BoM preserves the Dish and its stable typed Recipe migration identity `dish:<dish_id>:school-type:<school_type_id>`. Preserve the current source `recipe_id` as evidence and report `SOURCE_RECIPE_EMPTY` as INFO. Materialize no Recipe Version, Recipe Line or Recipe Line Revision. Missing or invalid references remain blockers; this policy does not suppress malformed composition facts.

Dish 2034 retains roots evidenced by Recipes 3456/3457. Its composition must not be copied from distinct Dish 2036. Dish 2041 retains roots evidenced by Recipes 3468/3469. The same-name Ingredient 1204 is insufficient authority to synthesize a `100 Cái` composition.

Root-only Master Data is valid and editable. Without a `RELEASED_FOR_PLANNING` Recipe Version it remains operationally not ready under existing backend Recipe/Need Generation behavior. Add no persisted readiness flag and do not release an empty composition. Weekly Menu source resolution identifies the active Dish independently; subsequent readiness checks must expose the missing effective Recipe.

## Exact COUNT Unit

`Túi` is a distinct canonical COUNT Unit, not an alias for Gói, Cái or Bịch. Its code derives through the existing SHA-256 algorithm as `v1-unit-67df33ade68a`, with name `Túi`, dimension `COUNT`, decimal scale `0` and status `ACTIVE`.

Extend mutually consistent source/import/rehearsal/cutover validation and the staging Unit policy. Existing Kg/kg and Hủ/Hũ aliases remain unchanged. Other unapproved labels still return `UNSUPPORTED_UNIT`.

Ingredient 1215 and Dish 2062 source Recipes 3510/3511 reference the same canonical Túi Unit. Preserve each source quantity `100` exactly. No conversion or mismatch successor is justified when new Ingredient and Recipe lines initially agree.

## Implementation and verification

Affected boundaries: OPS_V1 snapshot normalization, controlled master import Unit validation, rehearsal/cutover validation, staging Unit policy, dependency-closed catch-up planning/materialization and their fixtures/tests. Existing API signatures, module boundaries, status lifecycles and operational authority stay unchanged.

Regressions must prove stable root identity and source evidence, absence of fabricated versions/lines, readiness rejection and idempotence; no copy from Dish 2036 or synthesized Ingredient 1204; deterministic distinct Túi identity, unchanged quantities, equal Ingredient/line Unit IDs and no adoption mismatch; and continued rejection of unknown Units and invalid references. An appended migration updates the existing import Unit allowlist; rollback uses a separately reviewed forward migration, without rewriting applied history or deleting materialized identities.
