# Effective Recipe composition owns Need Generation inputs

**Decision:** ATLAS-EFFECTIVE-COMPOSITION-GENERATION-01

**Status:** Product-approved amendment; implementation awaits Draft PR review

**Correction date:** 14 October 2026

**Baseline:** main `0934f4dcc19a36f47d0f1eb79f889405039c66fc`, migration 106

## Correction

Need Generation previously selected released base RecipeLineRevision values even when effective Recipe reads showed applicable native Change Orders. That implementation gap could show an effective 10 kg line while generating from its 9.5 kg base. This decision explicitly supersedes the base-only composition wording in H0A5 and RMVP-04; it does not claim the older implementation already used effective composition.

For each approved Menu assignment's exact service date, School, Dish and School Type, Planning retains its existing released-base selection semantics, then calls `atlas_core.recipe_effective_resolve_composition` with that exact selected version. Its selected-version support argument pins the backend-selected base rather than allowing caller selection. School Type is passed explicitly to the accepted rule matcher. A non-`READY` resolution blocks the complete generation command.

Only final `PRESENT` lines create active Recipe contributions. The unchanged formula is Attendance portions multiplied by final effective quantity per basis, divided by selected base basis portions, with existing operand order and one `numeric(20,6)` coercion. Resolver precedence stays released base → SYSTEM_INGREDIENT → SYSTEM_DISH → SCHOOL → SCHOOL_DISH. Planning does not rewrite base Recipes, materialize replacement base versions, or implement another effective resolver.

## Smallest coherent evidence correction

Generalize the existing `need_generation_recipe_line_uses` relation and retain its existing theoretical-line FK. This avoids a second contribution authority, a new source family, duplicated composition evidence writers or a generic polymorphic framework. Existing rows are not backfilled or rewritten.

Each new Recipe selection captures the complete exact effective line array. Each use captures its exact member, including final Ingredient, Unit, quantity, disposition, base values, applied revision IDs and ordered before/after provenance. Generated typed Ingredient/Unit columns retain private master-data FKs. Immediate capture guards prove equality with the canonical READY resolution and exact member identity; deferred every-and-only membership and numeric guards remain mandatory.

- **Base line:** selected Recipe/version plus the existing exact stable RecipeLine and RecipeLineRevision FKs. Applicable transformation lineage is captured without changing that base identity.
- **ADD line:** selected base Recipe/version; null base line IDs; stable adjustment-line ID; exact creator Adjustment and AdjustmentRevision composite FK; complete applied revision lineage. The guard proves the creator is the exact ADD root and each lineage step references its exact immutable adjustment revision. No dummy RecipeLine is created.
- **Disappeared ADD:** an explicit zero `REMOVED` successor uses the existing governed predecessor/successor selection evidence. Its exact prior contribution and use permanently retain the ADD creator and applied lineage. The successor selection proves the stable effective line is absent. Native dated REMOVE can be reversed; permanent base removed-line governance remains unchanged.

The JSON capture is supporting generated evidence, not authored adjustment authority. Exact typed selection, base/ADD identities, master-data FKs, canonical capture equality, ordered immutable revision references, unique effective membership and deferred numeric checks jointly constrain it.

## Currentness and compatibility

The existing preflight derives `OUTDATED` when captured effective composition/provenance differs from current exact-context resolution on its exact selected base, including creation, dated supersession, cancellation and period expiry. Existing base-version and D-047 currentness policies remain separate and unchanged. V1 validation/release and Confirmed Need materialization reject stale composition with existing `STALE_SOURCE_BINDING`. The atomic command uses its existing safe invalidation, direct successor and Confirmed Need correction path. No operator lifecycle state is added.

Pre-107 base-only captures remain current only when their exact base values and absence of adjustment provenance still match resolution. Later changes never rewrite any historical source snapshot, composition capture, theoretical line, release membership or downstream commitment. Approved/released downstream correction gates remain in force.

Public API names, request/response versions, authorization, capabilities and browser table privileges remain unchanged. The forward schema admits null base line IDs only alongside exact ADD evidence. Frontend generated types and shaped contracts are untouched. Pantry/direct Need, zero-demand policy, Planning rounding, human confirmation, Procurement and D-047 Unit adoption remain unchanged; native cross-Unit corrections still fail the existing no-conversion boundary.

## Migration and rollback

Forward migration 107 is `20261014052605_atlas_need_generation_effective_composition.sql`. It adds capture/ADD columns and FKs on existing private evidence, two unique indexes, two private immediate capture triggers, four private helpers/guards, and two SELECT-only adjustment policies for the existing Need runtime. It amends generator, deferred generation integrity, governed removal, preflight, V1 validate/release and shared Confirmed Need materialization functions. No table, API, role, capability, timeout or lifecycle is added.

Migrations 1–106 remain historical. Before deployment, this migration can be discarded with its branch. After any deployment, rollback must be a reviewed forward migration preserving ADD captures, source traceability and all released evidence; dropping columns or returning currentness to base-only logic would lose correctness. Hosted apply requires separate Product approval.
