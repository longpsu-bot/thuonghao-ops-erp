# Atlas Model Convergence — Evidence register

**Prepared:** 6 September 2026.

**Purpose:** Distinguish approved direction, repository evidence, dated hosted observation and implementation recommendations. This register is not a new business authority and not evidence of implementation completion.

## 1. User-authorized basis

The attached architecture-audit brief required the exact four classifications and the principle **FACTS EXPLICIT — STATE DERIVED — SUPPORTING OBJECTS GENERATED**, through Procurement, with OPS_SYSTEM_MAP v1.0 and no Warehouse design. The subsequent user message approved the audit direction and requested implementation documents and a Codex prompt, explicitly permitting extra-high reasoning and sub-agents.

The original audit-only instruction not to create a Codex prompt is superseded by this newer request. No merge/deployment permission was added. The packet adds execution controls and acceptance detail; these are recommendations for the bounded handoff, not claims that the new documents are already merged ADRs.

## 2. Repository baseline

Repository: `longpsu-bot/thuonghao-ops-erp`.

Rechecked main: `a60085163ecbfde8dc5f7c2d97a454bc57ec0f60`.

Parent: `0779daacb49635dab5b40503f5718dd5f577d6f3`.

Merge: PR #257, `RECIPE-EFFECTIVE-CONTRACT-01`.

- Main metadata: https://api.github.com/repos/longpsu-bot/thuonghao-ops-erp/branches/main
- Pinned commit: https://github.com/longpsu-bot/thuonghao-ops-erp/commit/a60085163ecbfde8dc5f7c2d97a454bc57ec0f60
- PR: https://github.com/longpsu-bot/thuonghao-ops-erp/pull/257

The original audit inspected the relevant implementation at that commit. Packet preparation rechecked main, Staging metadata, the superseding Recipe specification, current Recipe model/API interfaces, AGENTS.md, package scripts and CI trigger policy. It did not rerun application tests or execute a mutating business journey.

## 3. Pinned repository sources

All paths below refer to the pinned commit, not a moving branch. Prefix each path with:

`https://github.com/longpsu-bot/thuonghao-ops-erp/blob/a60085163ecbfde8dc5f7c2d97a454bc57ec0f60/`

| ID  | Path                                                                                    | Supports                                                                                                                                       |
| --- | --------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| E01 | `docs/architecture/arch-002-atlas-system-map.md`                                        | Authority ordering, ownership, shaped reads and released history.                                                                              |
| E02 | `AGENTS.md`                                                                             | Workspace verification, bounded branches, mandatory reading, validation and change control.                                                    |
| E03 | `docs/superpowers/specs/2026-09-05-recipe-effective-product-model-correction-design.md` | Final ACTIVE-on-create amendment, canonical roots, base/effective distinction, typed-only selection, snapshot copy and compatibility boundary. |
| E04 | `docs/superpowers/specs/2026-09-05-recipe-effective-workbench-design.md`                | Original effective-target/history intent; conflicting GENERAL/base-copy statements are superseded by E03.                                      |
| E05 | `docs/api/rmvp-02a-recipes-bom.md`                                                      | Recipe Save, copy, lock and released-evidence contracts.                                                                                       |
| E06 | `docs/api/rmvp-02b-recipe-adjustments-effective-bom.md`                                 | Explicit contexts, effective targets, temporal state, full-BOM history and attribution.                                                        |
| E07 | `src/modules/admin/DishRecipeAdminWorkbench.tsx`                                        | Audited local released-version selection, nullable authoring context and browser-only copy path.                                               |
| E08 | `src/modules/admin/RecipeAdjustmentWorkbench.tsx`                                       | Audited raw line filtering and representative-School helpers.                                                                                  |
| E09 | `src/modules/atlas/recipes/recipeApi.ts`                                                | Existing effective-workbench and atomic-copy builders/methods.                                                                                 |
| E10 | `src/modules/atlas/recipes/recipeModel.ts`                                              | `base_authoring`, effective readiness, target/history shape and guarded parsers.                                                               |
| E11 | `src/modules/atlas/recipe-adjustments/recipeAdjustmentApi.ts`                           | `RecipeEffectiveContext` and effective-target request builder.                                                                                 |
| E12 | `docs/implementation-tasks/TASK-PLANNING-UX-01B-menu-attendance-operator-correction.md` | Automatic working defaults, explicit zero and review-before-Save behavior.                                                                     |
| E13 | `docs/api/rmvp-03a-planning-inputs.md`                                                  | Consequential source Save and immutable accepted snapshots.                                                                                    |
| E14 | `docs/api/rmvp-04-connected-need-generation.md`                                         | Atomic daily generation, semantic currentness, legacy demand metadata and continuity.                                                          |
| E15 | `docs/api/confirmed-need-save-release-v2.md`                                            | Human decisions, release boundary, correction and allocation prerequisite.                                                                     |
| E16 | `docs/api/school-catering-procurement.md`                                               | Advisory review, exact allocation, atomic preparation, typed promotion and official release.                                                   |
| E17 | `src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.tsx`                  | Existing source-specific allocation routing and authoritative uncertainty/readback handling.                                                   |
| E18 | `docs/current-context.md`                                                               | Living guidance containing dated context and superseded workflow descriptions.                                                                 |
| E19 | `docs/api/rmvp-03b-planning-input-readiness.md`                                         | Automatic preflight plus an older demand-flag statement requiring precedence correction.                                                       |
| E20 | `package.json`                                                                          | Actual toolchain pins, focused scripts and existing CI/certification tooling.                                                                  |
| E21 | `.github/workflows/supabase-integration.yml`                                            | Draft smoke; `workflow_dispatch` and Ready-state/push Full Integration triggers, using a disposable local stack on the runner.                 |
| E22 | `supabase/migrations/20260906000923_recipe_active_on_create_lifecycle_correction.sql`   | ACTIVE Dish creation and Recipe-only Save finalizer; no Dish activation event/version bump.                                                    |

The packet does not claim a rendered UI fault or exploit solely from static code evidence. Its tests require the behavior to be demonstrated at the actual implementation baseline.

## 4. Dated Staging observation

Read-only query returned timestamp `2026-09-06T01:36:35.770533+00:00` for project `rnzxmxiiqgtdevzregff`.

```json
{
  "migration_tip": {
    "version": "20260904081048",
    "name": "master_data_creation_ux_02"
  },
  "checked_effective_recipe_apis_present": [],
  "atlas_tables": { "count": 107, "rls_enabled": 107, "rls_forced": 107 },
  "recipe_roots": { "GENERAL": 2, "TYPED": 1 }
}
```

The four checked identities were `get_dish_recipe_operator_workbench`, `get_recipe_effective_target_context`, `resolve_system_effective_recipe_composition`, and `copy_dish_recipes`. This supports the report of environment mismatch at the observation time. It does not justify an automatic migration, deployment or data repair.

Earlier audit observations about existing live OPS functions and revision-head consistency are historical supporting evidence. They were not all repeated for packet preparation and must not be presented as new comprehensive checks.

## 5. Retool / uploaded source evidence

The following supplied offline JSON exports were re-opened and selected workflow queries inspected during packet preparation. Their identity with currently deployed Retool apps was not verified.

| File                                     | SHA-256                                                            | Sample verified evidence                                                    |
| ---------------------------------------- | ------------------------------------------------------------------ | --------------------------------------------------------------------------- |
| `OPS - Admin (in production).json`       | `a6d74ca01f7942687e8639ffef73dba5a89c6bcbf653f9454011cec551549350` | School-default read and explicit Save payload construction.                 |
| `OPS - Công thức.json`                   | `b38c86ac3b1fed985f6bc07d91c0708cf5aacccc682434ba2498960d1da1b809` | System-effective view use and legacy Recipe/BOM import logic.               |
| `OPS - Nguyên liệu và Nhà cung ứng.json` | `2fb973cbd6a3900252aa9037a1d4d197551bccc93db60e36512d97f27d903648` | Ingredient creation and browser-side toggle interpretation.                 |
| `OPS - Lên đơn, Đặt hàng (1).json`       | `6f6ff8d025696d375f354a86126661d20c3e9908d6475d40ecb14ee006b4a371` | Exact-family allocation Save, PO confirmation and Attendance refresh paths. |

The uploaded `schema.sql` is an export, not proof of current live definitions. Do not import these exports or raw operational data into the implementation branch. Retain behavioral lessons, not Retool-owned authority or legacy destructive writes.

## 6. Codex configuration documentation

Official documentation checked during preparation:

- Models: https://developers.openai.com/codex/models/
- Subagents: https://developers.openai.com/codex/subagents
- Configuration reference: https://developers.openai.com/codex/config-reference/

The recommended session is Sol with extra-high reasoning and explicit bounded delegation. Set supported options in the actual installed client; verify availability rather than pretending a prompt changed runtime configuration. Agent-count limits in this packet are task policy, not an assertion about a particular release's TOML key. Do not enable unrestricted access or disable approval/sandbox protections to obtain sub-agents.

## 7. Execution contract mapping

Task execution reverified baseline `a60085163ecbfde8dc5f7c2d97a454bc57ec0f60`
and confirmed PR #257 is merged. The following are implementation gaps against
the intended accepted behavior, not amendments weakening that behavior:

- **A07:** `20260727120000_rmvp_02b_recipe_adjustments_effective_bom.sql`
  retains School-based Preview and mandatory `preview_school_id` in
  Create/Supersede (Preview at lines 2727–2823; command validation and resolution
  at 2957–3186 and 3332–3563).
  `20260905161348_recipe_effective_product_model_correction.sql` lines 194–218
  explicitly preserve the legacy resolver behind that compatibility path.
  New system-effective/target reads do not supply a matching system-only command
  envelope. Normal system mutation must remain blocked without a separately
  approved backend amendment.
- **A12:** `20260905105253_recipe_effective_contract_01.sql` lines 1306–1355
  shape effective-history tags from Actor display name and revision `created_at`
  without a legacy-issuance discriminator.
  `20260814010928_ui_quality_03b_recipe_adjustment_operator_workbench.sql`
  lines 107–149 and 229–275 identifies legacy unattributed ledger evidence and
  nulls issuer name but still returns stored creation time. Original legacy
  issuer/time cannot be certified by these outputs. React must preserve unknown
  attribution rather than present the importer or import time as original
  business issuance.
- **Catalog:** the existing catalog supports identity/reference/base search;
  canonical effective detail is available per selected Dish/context. No existing
  read provides whole-catalog effective-Ingredient search. Truthfully labelled
  base search and lazy selected detail are within this delivery.

The exact acceptance outcomes, independent review, CI and separately rechecked
Staging readiness are recorded in the
[implementation report](../implementation-tasks/TASK-ATLAS-MODEL-CONVERGENCE-01.md).
The dated preparation observations above remain historical evidence.
