# RMVP-02B Recipe adjustment rules and effective BOM

## Decision and ownership

RMVP-02B adds one Admin / Recipe business object, `RecipeCompositionAdjustment`, with an immutable revision chain. Admin owns rule scope, action, effective period, correction lifecycle, what-if preview, effective-composition policy, and source audit.

Planning still owns Planning Input approval, Need Generation, and immutable per-run evidence of the exact Recipe, Recipe Version, Recipe Line, and future adjustment revisions used. RMVP-02B does not generate theoretical need, rewrite a Need Generation run, mutate Confirmed Need or Purchase Handoff, or write Planning, Procurement, Evidence, Dispatch, or Warehouse facts. Rules affect only a future effective-composition resolution requested with an explicit date.

## Closed business model

The model uses typed nullable foreign keys and exactly four scopes:

| Scope               | Typed target                                                                                                                                                            | Allowed actions                               |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------- |
| `SYSTEM_INGREDIENT` | one Ingredient across Recipes                                                                                                                                           | `REPLACE`                                     |
| `SYSTEM_DISH`       | one Dish; current normal commands require one canonical School Type; stable Recipe Line for an existing contribution or stable adjustment-line identity for an addition | `ADD`, `REPLACE`, `ADJUST_QUANTITY`, `REMOVE` |
| `SCHOOL`            | one School and one Ingredient across Dishes                                                                                                                             | `REPLACE`, `REMOVE`                           |
| `SCHOOL_DISH`       | one School and Dish; stable Recipe Line for an existing contribution or stable adjustment-line identity for an addition                                                 | `ADD`, `REPLACE`, `ADJUST_QUANTITY`, `REMOVE` |

There is no relation, page, or command per legacy Retool layer and no generic rule or workflow engine.

The resolver applies authority in one fixed sequence:

```text
released RecipeVersion base composition
→ SYSTEM_INGREDIENT
→ SYSTEM_DISH
→ SCHOOL
→ SCHOOL_DISH
```

Creation time, UUID order, UI order, and caller choice never decide precedence. A duplicate final Ingredient, overlapping exact target, self-replacement, replacement cycle, missing target, removed target, or ambiguous target blocks the result.

## Recipe selection and effective resolution

For an exact School and Dish, the retained `RMVP-02B.v1` compatibility resolution selects:

```text
one active released Recipe for the School's exact SchoolType
→ otherwise one active released general Recipe
→ otherwise a blocking result
```

The Dish must be active. The selected Recipe is active and its version is `RELEASED_FOR_PLANNING`. Multiple candidates in the selected tier block. A caller cannot choose an arbitrary version for a current result. The historical `requires_need_generation` flag is not Recipe eligibility authority.

An explicitly named materialized `VALIDATED`, `RELEASED_FOR_PLANNING`, or `LOCKED` version is accepted only by the support/audit path. Its result is labeled `historical` and includes a warning that it is not current authority.

Each atomic effective line retains selected Dish, Recipe, Recipe Version, basis portions, stable base Recipe Line or adjustment-line identity, base values, final values and disposition, highest source layer, every applied adjustment and revision, before/after values, reason, period, actor, warnings, and blockers. Removed lines remain in audit output with `REMOVED`; the resolver does not aggregate away stable identity and performs no theoretical-need calculation.

RECIPE-EFFECTIVE-CONTRACT-01 centralizes its first step in `atlas_core.recipe_effective_select_base_recipe(dish_id, school_type_id)`. The selector accepts only the active canonical codes `v1-school-type-1` and `v1-school-type-2`, requires the exact typed active Recipe root and released version, never reads a nullable GENERAL Recipe, and blocks ambiguity or absence. Both explicit School-Type resolution and School resolution call the same selector; the latter first derives School Type from the authoritative active School. The renamed legacy resolver isolates the older RMVP-02B fallback behavior from this contract.

The shared composition helper then has two closed layer sets:

```text
system context: base → SYSTEM_INGREDIENT → SYSTEM_DISH
School context: base → SYSTEM_INGREDIENT → SYSTEM_DISH → SCHOOL → SCHOOL_DISH
```

No fake or representative School is used for system context. Need Generation keeps backend-owned School resolution semantics; React consumes shaped reads rather than reconstructing selection or precedence.

RECIPE-SYSTEM-COMMAND-CONTEXT-01 applies that same authority to the existing `RMVP-02B.v1` command family. A normal `SYSTEM_DISH` Preview names the Dish, one active canonical School Type, and the explicit as-of date; Create and Supersede bind the reviewed context with `preview_dish_id` plus `preview_school_type_id`. A School identity is invalid for this path. The proposal and reviewed context must identify the same Dish and School Type, and command-time revalidation calls the shared strict resolver for both current and hypothetical composition. `SCHOOL` and `SCHOOL_DISH` retain their School-based context, while `SYSTEM_INGREDIENT` retains its explicitly named impact-preview behavior.

This is an additive amendment to three existing JSONB RPCs. It adds no business object, lifecycle, table, role, capability, policy, module, or alternate precedence engine. Existing request hashing automatically binds the new context fields; the existing target locks, root lock, optimistic version, immutable revisions, idempotency receipts, events, audit, and safe errors remain authoritative. Legacy nullable GENERAL evidence stays isolated behind the compatibility resolver and is never used for a typed `SYSTEM_DISH` command.

For Dish-scoped non-ADD rules, stable target identity is an XOR between the base `target_recipe_line_id` and an ADD-owned `adjustment_line_id`. The same identity is used by validation, locks, overlap and duplicate detection, transformation, Preview, Create, Supersede, and history. This preserves targetability through the layered BOM, including a School rule acting on a system-added line.

## Lifecycle and correction

The stable root carries typed scope identity, current revision pointer, current revision number, lifecycle, and optimistic version. Accepted revision rows are immutable and append-only:

```text
ACTIVE → SUPERSEDED
ACTIVE → CANCELLED
```

Every successor has one exact predecessor and a positive next revision number. Branching, update, delete, and root hard deletion are rejected. Revisions record actor, timestamp, reason code, required reason note, source evidence, `effective_from`, and optional half-open `effective_to`.

Supersession and cancellation are date-aware. The resolver chooses the highest revision number applicable on the requested date. A dated successor masks its predecessor only during the successor's own half-open period; after a finite successor `effective_to`, the predecessor resumes when its own period still covers the requested date. A dated cancellation stops effect from its cancellation date. Earlier dates continue to resolve the prior immutable revision. Overlap validation derives these same authoritative periods across the complete immutable chain. No authoritative function uses `CURRENT_DATE`.

## Persistence, security, and API

The single migration adds:

- two private Admin relations: one stable root and one immutable revision relation;
- seven adjustment indexes;
- two immutability triggers;
- twelve private guard, validation, authorization, read-model, resolver, transformation, locking, and command helpers;
- three reads and three commands in `atlas_api`;
- one local-only explicit snapshot importer in `atlas_legacy`;
- seven least-privilege RLS policies over the two forced-RLS relations.

It adds no runtime role. `atlas_read_runtime` owns shaped reads and preview; `atlas_master_data_command_runtime` owns writes. The only new capabilities are:

- `master_data.recipe_adjustments.read`
- `master_data.recipe_adjustments.write`
- `master_data.recipe_adjustments.cancel`

Browser roles have no private-schema usage or table access. Public, `anon`, and `service_role` execution is revoked. Every accepted command resolves the authenticated Actor internally, uses global scope authorization, optimistic versioning and command receipts, appends one Admin domain event and audit event, and returns authoritative readback. The callable contract is recorded once in [RMVP-02B Recipe adjustment and effective BOM API](../api/rmvp-02b-recipe-adjustments-effective-bom.md).

The RECIPE-EFFECTIVE-CONTRACT-01 extension adds no relation, role, runtime role, capability, RLS policy vocabulary, major dependency, or module boundary. It adds shaped reads under the existing adjustment-read capability and one Dish-level command under the existing Recipe-write capability. New public functions have fixed empty `search_path`, least-privilege runtime ownership, authenticated execution only, and revoked `PUBLIC`, `anon`, and `service_role` execution.

The corrected Dish model persists each normally created Dish as `ACTIVE` at version 1 and provisions exactly two active typed Recipe roots in the same `create_dish` transaction, one per canonical School-Type code, without creating a RecipeVersion. The invariant is command-scoped for new and contract-valid Dishes; legacy nullable/synthetic data is neither backfilled nor subjected to a new global constraint. Unlocked roots remain base-authoring contexts through no-version, DRAFT, VALIDATED, and released states. Effective readiness is a distinct released-Recipe requirement. Recipe Save never activates or lifecycle-versions the Dish. Approved-Menu evidence derives the operator path as read-only `LOCKED_CHANGE_ORDER` without mutating the Dish or persisting a separate lock flag.

The Dish-level copy command is one outer transactional boundary. At the explicit `as_of_date`, it resolves both exact typed source scopes through `SYSTEM_INGREDIENT` and `SYSTEM_DISH`, excludes School-specific layers, and materializes each effective BOM into the corresponding pre-provisioned target root using stable version/line lineage. It preserves prior target history, stores source and system-adjustment provenance, never mutates the source, and does not invoke the support-level `copy_recipe_version` API. A missing source/target scope, unfinished target version, write failure, or approved-Menu target lock rolls back both scopes. No Weekly Menu, Attendance, Need Generation, Pantry, Confirmed Need, Procurement, PO, Warehouse, Dispatch, hosted data, or deployment contract changes.

## Operator history and temporal ledger

Normal Recipe history is an immutable sequence of effective-BOM periods, not a raw Recipe Version list. Period boundaries are derived from release and potentially applicable revision start/end dates, but a Change Order belongs to a Dish history only when its adjustment identity occurs in actual resolver lineage for that Dish in at least one period. Each panel contains a complete backend-resolved BOM and relevant Change Order business tags. Adjacent identical BOM states may be coalesced; correction/cancellation evidence remains immutable and reachable in the Lệnh điều chỉnh ledger/detail even when it does not require a duplicate BOM panel. `school_exception_count` likewise counts distinct currently applicable School-layer roots that materially occur in this Dish's resolved lineage, not all School adjustments of the same School Type.

The adjustment ledger retains `temporal_state`, exposes `effective_from` and `effective_to`, and adds backend-derived `is_effective_now`. The boolean is true only for states whose current revision contributes on the requested date. The frontend displays these fields and never calculates applicability.

## Preview and connected UI

Preview is a no-write backend read. It validates one proposal, resolves current composition and hypothetical composition with the same resolver, and returns before/after atomic lines, affected-line count, warnings, blockers, and `can_save`. The final command repeats validation and resolution under transaction protection so stale or newly conflicting inputs fail closed.

The existing Vietnamese `Công thức` workbench now contains:

```text
Món ăn
Phiên bản & BOM
Quy tắc điều chỉnh
BOM hiệu lực
Sao chép
Nhập workbook
```

The normal adjustment ledger automatically uses the current Vietnam-local business date and filters scope, lifecycle, and School/Dish/Ingredient text. It conditionally displays typed fields, requires preview and explicit confirmation, shows revision predecessor, actor, reason, and business effective period, and offers successor or cancellation but no delete. Secondary read-only effective-BOM inspection owns historical `Xem tại ngày` navigation; it compares base and final values, labels source layer, expands lineage and removed lines, reports blockers/warnings, and copies bounded support evidence.

Production uses the authenticated adapter. Review mode is deterministic, browser-only, visibly nonpersistent, and covers every scope/action, full precedence, replacement chain, superseded/cancelled history, removed lines, duplicate and cycle blockers, stale state, permission denial, retry, and session loss.

## Controlled OPS v1 migration

The importer accepts only an explicitly supplied JSON file with source identity, export time, importing Atlas Actor, canonical SHA-256, and exactly four arrays:

- `ingredient_change_orders`
- `system_bom_change_orders`
- `school_overrides`
- `school_dish_overrides`

It never connects to live OPS v1. It maps business intent into the closed Atlas model, resolves typed School, Dish, School Type, Ingredient, Unit, and stable Recipe Line references, preserves dates and legacy layer/record identity, interprets inactive rows as a cancellation revision, and never imports `v_effective_bom*` view rows as facts. It does not claim a historical Atlas approver.

Validation is all-or-nothing and reports source/target/mapping counts, inserted/updated/skipped/rejected counts, missing references, ambiguity, cycles, reconciliation, and explicit limitations. An identical snapshot identity and checksum replays without duplicate writes; reuse with different content is rejected. The repository contains only an empty contract example, never production data.

The retained task workspace did not contain the referenced OPS v1 adjustment export or live legacy schema. Implementation therefore uses the approved four-array behavior in the bounded task, the merged RMVP-02A legacy evidence, and an explicit-export-only contract; no dataset-specific assumption or live access was introduced. Legacy hard-deleted history cannot be reconstructed and is always reported.

## Reconciliation matrix

The focused pgTAP suite, authenticated browser-key script, and deterministic review fixtures cover the intended v1 cases:

| Case                                      | Evidence                                                       |
| ----------------------------------------- | -------------------------------------------------------------- |
| Base only                                 | post-cancellation resolver returns released base               |
| Global Ingredient replacement             | authenticated preview/save plus precedence lineage             |
| `SYSTEM_DISH` add/replace/quantity/remove | authenticated preview/save for all four actions                |
| `SCHOOL` replace/remove                   | authenticated preview/save for both actions                    |
| `SCHOOL_DISH` add/replace/quantity/remove | authenticated preview/save for all four actions and precedence |
| Multi-step global chain                   | review replacement-chain fixture                               |
| Cancelled rule                            | pgTAP and browser-key dated cancellation                       |
| Future rule                               | dated revision tests and review fixture                        |
| Overlap/ambiguity rejection               | proposal validation tests                                      |
| Replacement cycle                         | pgTAP and review blocker fixture                               |
| Duplicate final Ingredient                | pgTAP and review blocker fixture                               |

Comparison evidence retains Recipe selection scope, Ingredient, quantity per basis, Unit, removed/additional identity, source layer, and rule lineage. No legacy effective-view row becomes Atlas authority.

## Rollback

Before cutover, discard and reset the disposable Atlas database, correct the explicit snapshot or mapping, and rerun reconciliation.

After adjustment history or a future Planning reference exists, do not drop, delete, or rewrite stable roots and revisions. Correct business history with a successor or dated cancellation. Correct schema or importer defects with a reviewed forward migration or whole-database restore. Hosted Supabase, OPS v1, OPS v2, and Retool are outside this migration and remain unchanged.

The RECIPE-EFFECTIVE-CONTRACT-01 migration follows the same forward-only rule once copy receipts/events or effective-history evidence exists. Before any business use, a disposable local database may be reset. After use, rollback means a reviewed forward migration or full restore—not deleting Recipe, adjustment, receipt, event, or audit history. This implementation performs no deployment and no hosted write.
