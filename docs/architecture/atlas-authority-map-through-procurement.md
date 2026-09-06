# Atlas authority map through Procurement

**Current repository authority:** `11408a0b0ed5d3938321c90f38fd8a2f9c1ad587`.

**Audit baseline:** `a60085163ecbfde8dc5f7c2d97a454bc57ec0f60`.

**Meaning:** A source-backed summary of current approved contracts and the implemented convergence result through Procurement. Repository consumers have adopted this target; Atlas Staging remains a separately controlled environment and is not assumed to match `main`.

**Principle:** [ATLAS-MODEL-PRINCIPLE-01](../decisions/decision-atlas-model-convergence.md).

## 1. Owners and distinctions

| Meaning | Owner | Durable authority | Derived or generated interpretation |
| --- | --- | --- | --- |
| School/party/location/reference availability | Master Data | Explicit governed records and relationships | Eligible references for the current context |
| Base Recipe composition | Recipe / Master Data | Typed RecipeVersion and line evidence | Current authoring selection and ability to Save |
| Effective Recipe composition | Recipe | Released typed evidence plus dated Change Orders | System or School effective BOM for an explicit date |
| Normal base-edit lock | Recipe consumes Planning evidence | Immutable approved Weekly Menu use | `EDITABLE_BASE` / `LOCKED_CHANGE_ORDER` |
| Accepted operational inputs | Planning | Menu, Attendance and Pantry snapshots | Readiness and day-specific currentness |
| Generated Need | Planning | Bound calculation/source/contribution evidence | Theoretical quantity and comparisons |
| Confirmed quantities | Planning | Human decisions and correction/continuity evidence | Completeness and release eligibility |
| Accepted supplier splits | Procurement | Exact saved allocation revisions and source bindings | Balance, currentness and proposals |
| Transfer and preparation | Existing Planning/Procurement command boundaries | Released Need, Handoff and promotion lineage | Supporting structures generated atomically |
| Official supplier commitment | Procurement | Released PO snapshot and official number | Current display; no recalculation of issued content |

A current master-data label is not interchangeable with a historical document label. A copied DRAFT RecipeVersion is persisted authored work but is not yet effective-ready. A saved quantity decision may exist while its batch remains editable and not released. A current revision head may be business-stale.

## 2. Classification register

This compact register preserves the audit's four classifications. “Generate” for a supporting identity does not move authored content out of KEEP EXPLICIT.

| Domain | Concept | Classification | Required disposition |
| --- | --- | --- | --- |
| Master | School Types | KEEP EXPLICIT | Preserve governed classifications and canonical codes. |
| Master | Schools | KEEP EXPLICIT | Preserve identity, relationships and availability. |
| Master | School portion defaults | KEEP EXPLICIT | Separate defaults from accepted daily portions. |
| Master | Customers | KEEP EXPLICIT | No evidence supports collapsing into Schools. |
| Master | Delivery Locations | KEEP EXPLICIT | Preserve destination identity and historical bindings. |
| Master | Units | KEEP EXPLICIT | Preserve dimension, precision and references. |
| Master | Ingredient Types | KEEP EXPLICIT | Normalized catalog authority. |
| Master | Ingredient Order Groups | KEEP EXPLICIT | Governed purchasing grouping. |
| Master | Ingredients | KEEP EXPLICIT | Authored identity, availability, purchase Unit and order step. |
| Master | Suppliers | KEEP EXPLICIT | Authored identity, availability and contacts. |
| Master | Supplier Eligibility and priority | KEEP EXPLICIT | Explicit policy; derive date-specific applicability. |
| Master | Duplicate legacy classification strings | LEGACY / RETIRE CANDIDATE | Do not restore dual editing or competing IDs/text. |
| Recipe | Dish identity and availability | KEEP EXPLICIT | ACTIVE availability is not Recipe readiness. |
| Recipe | Normal Dish DRAFT-to-activation ceremony | LEGACY / RETIRE CANDIDATE | Already removed from approved normal creation; retain historical support only. |
| Recipe | `requires_need_generation` | LEGACY / RETIRE CANDIDATE | Do not let historical metadata silently suppress demand. |
| Recipe | Canonical Recipe-root provisioning | GENERATE | Atomic pair creation beneath `create_dish`. |
| Recipe | RecipeVersion composition and released evidence | KEEP EXPLICIT | Preserve immutable versions and lineage. |
| Recipe | RecipeLine authored content and stable targeting | KEEP EXPLICIT | Preserve exact identity/content relationship. |
| Recipe | Ready for effective use | DERIVE | Released typed evidence, not a new status flag. |
| Recipe | Normal-edit lock | DERIVE | Approved Weekly Menu use, not a manual lock switch. |
| Recipe | Effective BOM and applicable School exceptions | DERIVE | Backend date/context resolution. |
| Recipe | Change Order intent, dates and revision history | KEEP EXPLICIT | Preserve scoped human change and reasons. |
| Recipe | Current Change Order temporal applicability | DERIVE | Use server `temporal_state` and `is_effective_now`. |
| Recipe | Separate initial validation/release operator ceremony | LEGACY / RETIRE CANDIDATE | Normal Save already performs deterministic supporting work. |
| Recipe | Two-scope Dish-copy materialization | GENERATE | Explicit copy intent; backend snapshots effective sources atomically. |
| Recipe | Nullable GENERAL in the normal typed workbench | LEGACY / RETIRE CANDIDATE | Isolate compatibility, never silently fall back. |
| Planning | Menu assignments and accepted snapshots | KEEP EXPLICIT | Preserve exact accepted source membership. |
| Planning | Attendance quantities, including zero | KEEP EXPLICIT | Blank/missing never equals zero. |
| Planning | Default Attendance working rows | GENERATE | Display proposals automatically without accepting them. |
| Planning | Pantry/direct requested quantity and purpose | KEEP EXPLICIT | Do not Recipe-explode or silently omit. |
| Planning | Explicit no-additions confirmation | KEEP EXPLICIT | Distinguish a negative assertion from missing work. |
| Planning | Source batch wrappers and stable identities | GENERATE | Beneath actual Save/import commands. |
| Planning | Current readiness | DERIVE | Canonical read-only preflight. |
| Planning | Historical evaluation observations | GENERATE | Retain execution evidence without another human decision. |
| Planning | Separate evaluate/request ceremony | LEGACY / RETIRE CANDIDATE | Compatibility only for the normal atomic path. |
| Planning | Current theoretical quantity | DERIVE | Backend arithmetic over bound accepted inputs. |
| Planning | Need run, contribution and release membership | GENERATE | Persist bound provenance for reproducibility. |
| Planning | Confirmed Need human decisions | KEEP EXPLICIT | Do not replace with calculated views. |
| Planning | Confirmed Need transfer-ready release | KEEP EXPLICIT | Durable boundary; preparation may compose it. |
| Planning | Semantic currentness/staleness | DERIVE | Relevant daily facts, not all parent-version changes. |
| Planning | Correction/reopen intent and history | KEEP EXPLICIT | Preserve reasons, predecessors and downstream guards. |
| Planning | Carried confirmation continuity evidence | GENERATE | Not a newly authored human decision. |
| Procurement | Purchase Handoff release meaning | KEEP EXPLICIT | Stable transfer evidence across owners. |
| Procurement | Handoff provisioning | GENERATE | No separate normal operator setup job. |
| Procurement | Supplier recommendation | GENERATE | Advisory until accepted. |
| Procurement | Allocation Family identity | GENERATE | Backend grouping by date/location/Ingredient/Unit. |
| Procurement | Confirmed supplier splits | KEEP EXPLICIT | Human acceptance of exact quantities/suppliers. |
| Procurement | Allocation balance/currentness | DERIVE | Compare saved decisions with authoritative sources. |
| Procurement | Rebalance proposal | GENERATE | Apply and Save explicitly; never auto-accept. |
| Procurement | Confirmed-source to Handoff-source promotion | GENERATE | Preserve accepted splits; append source-transition lineage. |
| Procurement | PO draft and regenerated successors | GENERATE | Stable review identity; not an issued commitment. |
| Procurement | PO freshness and release eligibility | DERIVE | Backend source/revision checks. |
| Procurement | PO release and released snapshot | KEEP EXPLICIT | Explicit external commitment and immutable content. |
| Procurement | Official PO number | KEEP EXPLICIT | Initially generated; permanently preserved after release. |
| Shared | Revision heads, optimistic versions and receipts | GENERATE | Justified controlled persistence, not disposable state. |

## 3. Normal command and read routing

These are current normal identities in the merged repository. Verify signatures and environment parity at execution time; catalog existence does not by itself prove hosted human-role authorization.

| Operator intent / read | Normal existing surface | Meaning / important exclusion |
| --- | --- | --- |
| Read School/reference facts | `get_school_master_data`; `get_ingredient_supplier_master_data` | Shaped master data, not browser private-table access. |
| Save School defaults | `update_school_portion_defaults_bulk` | One atomic explicit change; not daily confirmation. |
| Create/edit Ingredient or Supplier | Existing corresponding master-data commands | Preserve existing review and lifecycle semantics. |
| Create Dish | `create_dish` — RMVP-02A.v1 | ACTIVE Dish + two canonical typed roots; no RecipeVersion. |
| Read Recipe catalogs | `get_dish_recipe_workbench` | Reference catalog/base-authoring support; raw versions are not effective truth. |
| Read selected Dish in date/context | `get_dish_recipe_operator_workbench` — RECIPE-EFFECTIVE.v1 | Base authoring, effective readiness/BOM, lock, exceptions, history and actions. |
| Save canonical base Recipe | `save_recipe` — RMVP-02A.v2 | Selected authoring identity/version from backend; no Dish activation. |
| Copy one Dish's two system-effective Recipes | `copy_dish_recipes` — RECIPE-EFFECTIVE.v1 | Source Dish, target Dish, explicit date, target Dish version and reason. No School layers; output DRAFTs. |
| Select a Change Order line | `get_recipe_effective_target_context` — RECIPE-EFFECTIVE.v1 | Exact system or School context; PRESENT effective targets with origin identity. |
| Read system-effective composition | `resolve_system_effective_recipe_composition` | Explicit School Type and date; no representative School. |
| Preview / create / correct / cancel Change Order | `preview_recipe_composition_adjustment`, `create_recipe_composition_adjustment`, `supersede_recipe_composition_adjustment`, `cancel_recipe_composition_adjustment` | SYSTEM_DISH Preview/Create/Supersede uses Dish + canonical School Type; School paths retain exact School context. No proxy School. |
| Read Change Order ledger | `get_recipe_adjustment_operator_workbench` — RMVP-02B.v2 | Server-shaped temporal state/history; per-revision issuance truth; do not replay raw revisions. |
| Review imported Menu / Attendance | Existing `preview_weekly_menu_import` / `preview_attendance_import` | Read-only canonical review. |
| Save Menu / Attendance | `save_weekly_menu` / `save_attendance` — RMVP-03A.v2 | Consequential Save composes deterministic acceptance work. |
| Save Pantry | `save_pantry` | Existing consequential Save; preserve explicit no-additions distinction. |
| Check daily readiness/currentness | `get_planning_input_preflight` — RMVP-03B.v2 with D..D | Read-only selection and semantic currentness. |
| Generate/update one service day | `execute_need_generation` — RMVP-04.v3 | Atomic daily generation/materialization; no browser lifecycle chain. |
| Read/save Confirmed Need | `get_confirmed_need_review`; `save_confirmed_needs` — RMVP-05.v2 | Exact changed human decisions only. |
| Read preliminary purchase review | `get_generated_purchase_review` — PURCHASE-REVIEW.v1 | Not accepted allocation or official PO evidence. |
| Read/save pre-Handoff allocations | `get_confirmed_supplier_allocation_workbench`; `save_confirmed_supplier_allocation` | Accepted exact splits against saved Confirmed Need. |
| Maintain existing Handoff-source allocation | Existing school-catering workbench / `save_school_catering_supplier_allocation` | Preserve source-kind writer routing; not a second authority for the same current source. |
| Prepare orders | `prepare_school_catering_purchase_orders` — PURCHASE-COMMITMENT.v1 | Atomic Need release, real Handoff, promotion and drafts. |
| Read/refresh generated PO drafts | `get_school_catering_purchase_orders`; existing draft generation command where already authorized | No independent lifecycle invention or released-content mutation. |
| Issue official PO | `release_school_catering_purchase_order` | Independent final commitment; backend-only numbering. |

### Closed convergence execution gaps

The A07 and A12 gaps recorded at the original `a600851...` audit baseline are **historical, not current repository gaps**.

Merged PR #258 closed them by incorporating the certified component work from PRs #259 and #260:

- **A07:** SYSTEM_DISH Preview/Create/Supersede now accepts exact Dish + canonical School Type and rejects representative-School or mixed context. The system resolver applies typed released Recipe → SYSTEM_INGREDIENT → SYSTEM_DISH only; School layers and GENERAL fallback are excluded.
- **A12:** effective Recipe history now shapes issuance per exact revision. Legacy-unattributed revisions return `issuance_kind = LEGACY_UNATTRIBUTED`, `issuer = null`, and `issued_at = null`; Atlas-native corrections/cancellations retain their own Actor/time.

The original gap investigation remains preserved in the [execution evidence](atlas-model-convergence-evidence.md#7-execution-contract-mapping), component implementation records, and the [merged convergence report](../implementation-tasks/TASK-ATLAS-MODEL-CONVERGENCE-01.md).

Atlas Staging is still behind this repository authority, so these closed repository gaps must not be confused with hosted readiness.

## 4. Compatibility is not automatically retired code

Retain existing callable low-level Recipe, Planning and Procurement entry points unless a separate, approved compatibility retirement proves that all consumers are addressed. Normal UI must not call older deterministic stages as independent operator obligations or use them to bypass a canonical denial.

Exceptions that remain valid: controlled historical/support callers; internal command composition; source-specific Handoff allocation writers; immutable historical read paths. These are not justification for GENERAL fallback or browser rule reconstruction in the normal canonical Recipe UI.

## 5. Regression boundaries through Procurement

Attendance defaults remain proposals; persisted explicit zero wins. Menu/Attendance/Pantry Save remains authoritative. Daily generation retains day-specific source currentness and existing formula/rounding. Unchanged confirmation carry creates no new human decision. Changed facts retain review obligations. Recommendations remain advisory. Preparation preserves exact saved splits and is atomic. Draft staleness never rewrites issued POs. Downstream commitment rejection retains its existing correction meaning.

These are acceptance obligations, not new implementation work where existing behavior already satisfies them.

## 6. OPS v1 evidence to retain, not copy

Preserve fast search, explicit Save, generated supporting structures, meaningful defaults, visible totals, and direct operator language. Do not copy direct-SQL application authority, blank-to-zero coercion, optimistic success without authoritative readback, automatic rewriting of accepted allocations, destructive replacement of historical BOMs, or rebuilding already issued PO content from current assignments.

The Retool exports inspected are offline workflow evidence. They do not certify the currently deployed Retool UI. The uploaded SQL export is also historical and must not override live observations or accepted Atlas contracts. See the [evidence register](atlas-model-convergence-evidence.md).
