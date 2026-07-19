# TASK-PA-06E-H0A2 — Immutable Dish, Recipe, and BOM Reference Foundation

**Status:** Implemented and locally validated on the task branch; pending draft-PR review

**Issue:** [#119](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/119)

**Task branch:** `backend/pa-06e-h0a2-recipe-bom-foundation`

**Parent task:** [TASK-PA-06E-H0](TASK-PA-06E-H0-school-catering-persistence-materialization.md)

**Decision:** [Decision PA-06E-H0A2 — Immutable Recipe and BOM Reference Lineage](../decisions/decision-pa-06e-h0a2-immutable-recipe-bom-reference-lineage.md)

## Objective

Add the minimum private reference foundation for stable Dish and scoped Recipe identities, versioned composition snapshots, stable RecipeLine identities, and immutable RecipeLineRevision facts. This task establishes authoritative reference lineage only; it does not calculate, select, expose, or operationally consume a recipe.

## Bounded implementation

- add private `atlas_admin.dishes`, `recipes`, `recipe_versions`, `recipe_lines`, and `recipe_line_revisions` relations with database-generated UUID identities;
- model one Recipe as one Dish plus an exact optional SchoolType, with separate active uniqueness for general and typed roots while retaining inactive history;
- enforce the `DRAFT → VALIDATED → RELEASED_FOR_PLANNING → LOCKED` RecipeVersion lifecycle, one current release per Recipe, and atomic locking of the prior release when its direct successor is released;
- retain one stable RecipeLine across quantity and ingredient corrections, with exact immutable predecessor-linked revisions for correction, new contribution, and explicit removal;
- use typed composite foreign keys before private trigger guards to reject cross-Recipe, cross-Version, and cross-Line ownership;
- require complete one-to-one successor lineage before validation or release, including an explicit successor or removal for every previously present line;
- keep the fixed reference calculation kind `PROPORTIONAL_PER_BASIS` and exact `numeric(20,6)` quantity without introducing a calculation engine;
- force RLS on all five relations, create no policies, expose no API function, and grant no direct browser/API-role access.

## Files and acceptance evidence

- Migration: `supabase/migrations/20260719140821_pa_06e_h0a2_recipe_bom_immutable_reference_foundation.sql`
- Focused pgTAP: `supabase/tests/pa_06e_h0a2_recipe_bom_immutable_reference_foundation.sql`
- Supabase Integration workflow command immediately after the H0A1 focused suite
- Decision and minimal dependency/status references in the bounded PA-06E-H0 documentation set

The focused test proves the exact bounded schema, reference uniqueness, typed ownership, lifecycle order, stable-line correction lineage, new contribution, explicit removal, split/merge and omission rejection, release completeness, immutability, retained master-data history, indexed restrictive foreign keys, forced RLS, fail-closed privileges, unchanged API registry, and zero role or capability seeds.

## Exclusions

No Recipe CRUD or release RPC, public read, capability, role, seed, RecipeChangeSet, review workflow, unlock command, QA/Production approval, formula engine, conversion or yield policy, menu, attendance, Need Generation, Confirmed Need, Procurement, Warehouse, Dispatch, React, generated type, package, Retool, OPS v1, `public`, `ops_v2`, hosted Supabase, deployment, credential, production-data, or legacy-data change is part of H0A2. H0A3a and every later task remain unstarted.

## Migration and rollback

The migration is additive and seeds no production row. Before operational data or dependent migrations exist, an unshipped migration may be reverted normally. After use, do not delete released or locked composition history: revoke an unsafe path if necessary and forward-fix through another reviewed migration. Every operational foreign key uses `ON DELETE RESTRICT`; master-data deactivation retains historical references.

## Validation record

- `pnpm install --frozen-lockfile`: pass; dependencies were already current.
- local Supabase reset with `--no-seed`: pass; every migration replayed through H0A2.
- focused `supabase test db supabase/tests/pa_06e_h0a2_recipe_bom_immutable_reference_foundation.sql --local`: pass, 88/88 assertions after the bounded governance correction.
- `supabase db diff --local --schema atlas_admin,atlas_core`: pass; no schema changes found after reset.
- affected-schema database lint: pass; no errors or warnings.
- focused catalog assertions: all 15 H0A2 foreign keys use `ON DELETE RESTRICT` and have matching leading-column indexes; the five relations are owned by `atlas_owner`, have RLS enabled and forced, and have zero policies; exposed relation/function ACL entries and H0A2 sequences are zero; the exact 18-function `atlas_api` registry and zero role/capability seed counts are unchanged.

Formatting, whitespace, publication, and GitHub Actions results are recorded on the draft pull request after they run.
