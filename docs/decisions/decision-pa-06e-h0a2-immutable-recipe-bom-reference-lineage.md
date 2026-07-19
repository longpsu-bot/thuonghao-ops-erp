# Decision PA-06E-H0A2 — Immutable Recipe and BOM Reference Lineage

**Status:** Accepted for the bounded H0A2 model by Issue #119; implementation pending review

**Issue:** [#119](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/119)

**Implementation task:** [TASK-PA-06E-H0A2](../implementation-tasks/TASK-PA-06E-H0A2-recipe-bom-immutable-reference-foundation.md)

**Parent architecture:** [PA-06E-H0 School-Catering Persistence and Materialization](../architecture/pa-06e-h0-school-catering-persistence-and-materialization-contract.md)

## Context

PA-06E-H0 identified immutable recipe and calculation lineage as prerequisites but did not authorize a physical model. The retained Dish/Recipe prototype uses per-version ingredient-shaped lines and edit-oriented replacement behavior that cannot provide stable correction identity. Issue #119 authorizes only the reference foundation needed to close that gap; operational calculation and recipe administration APIs remain separate decisions.

## Decision

1. `Dish` is a private stable UUID reference with a lowercase code, normalized active-name uniqueness, descriptive fields, explicit Need Generation applicability, `DRAFT`/`ACTIVE`/`INACTIVE` lifecycle, positive version, display order, and timestamps.
2. `Recipe` is the stable root for one Dish plus one exact optional SchoolType. Null means the general scope; non-null means that exact SchoolType. Active general and typed uniqueness are enforced separately, without selecting between them.
3. `RecipeVersion` is an exact aggregate composition snapshot with a positive basis and the closed lifecycle `DRAFT → VALIDATED → RELEASED_FOR_PLANNING → LOCKED`. A Recipe has at most one current release. Releasing its direct successor locks the prior current release atomically.
4. `RecipeLine` is the only stable BOM-line business identity. It belongs to one Recipe, is independent of Ingredient identity, and persists through quantity and ingredient correction.
5. `RecipeLineRevision` is an immutable fact owned by one exact Recipe, RecipeVersion, and stable RecipeLine. Its quantity is `numeric(20,6)` and its calculation kind is fixed to `PROPORTIONAL_PER_BASIS`.
6. Corrections preserve the stable line and name an exact predecessor. A new contribution creates a new line with no predecessor. Removal is an explicit zero-quantity `REMOVED` successor. One predecessor has at most one successor; split, merge, cross-owner wiring, and silent omission are invalid.
7. Validation and release require composition completeness in PostgreSQL. A Need-Generation Dish cannot validate or release an empty composition, and every previously present line requires one present-or-removed successor.
8. Composite keys and typed foreign keys establish ownership before the minimum private lifecycle and completeness trigger functions. All operational references use `ON DELETE RESTRICT` and have matching indexes.
9. All five relations and three guard functions are owned by `atlas_owner`, remain private, use forced RLS with zero policies, use hardened function search paths, and grant no direct `PUBLIC`, `anon`, `authenticated`, or `service_role` access.

## Consequences

- Quantity and Ingredient corrections remain traceable without changing RecipeLine identity.
- Released and locked composition facts cannot be edited or deleted; a later valid release preserves its predecessor as locked history.
- Deactivating Dish, Recipe, SchoolType, Ingredient, or Unit reference data does not erase composition history.
- No general-versus-typed selection precedence, operational calculation, conversion, yield, allowance, approval workflow, unlock behavior, API function, capability, role, or seed is implied by this decision.
- The exact existing 18-function `atlas_api` registry remains unchanged.

## Rollback boundary

Before operational use, the additive migration can be reverted as an unshipped change. After released or locked recipe history exists, rollback is forward-only: preserve stable identities and immutable revisions, remove unsafe access if necessary, and correct the model through another reviewed migration.
