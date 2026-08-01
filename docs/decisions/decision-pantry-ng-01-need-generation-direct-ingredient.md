# Decision PANTRY-NG-01 — Direct Pantry Ingredient Contributions to Need Generation

- **Status:** Accepted
- **Product Owner approval date:** 01/08/2026
- **Decision register ID:** D-028
- **Exact baseline:** `b7b44923769dc690a51871365a8ef81eed396946`
- **Domain:** Planning
- **Implementation:** Not started; separately bounded implementation required
- **Architecture amendment:** [PANTRY-NG-01 direct-ingredient amendment](../architecture/pantry-ng-01-need-generation-direct-ingredient-amendment.md)
- **Task record:** [TASK-PANTRY-NG-01](../implementation-tasks/TASK-PANTRY-NG-01-need-generation-direct-ingredient-amendment.md)

## 1. Decision outcome

Atlas accepts Pantry as a direct Ingredient contribution inside the existing Need Generation run and atomic `TheoreticalNeedLine` model. Pantry bypasses Recipe explosion because an approved Pantry line already identifies its exact Ingredient, quantity, Unit, School, Delivery Location, service date and stable source line. It does not bypass Planning Input Readiness, immutable run evidence, validation, release or Confirmed Need review.

This document is the sole complete registry for `PNG-P01` through `PNG-P12`. Other documents summarize these decisions and link here; they do not create a second registry.

## 2. Decision table

| ID      | Accepted decision                                                                                            |
| ------- | ------------------------------------------------------------------------------------------------------------ |
| PNG-P01 | Admit exactly the closed contribution source families `RECIPE_DERIVED` and `PANTRY_DIRECT`.                  |
| PNG-P02 | Generate both families in one exact-period Need Generation run.                                              |
| PNG-P03 | Bind the exact Pantry batch, version and approval snapshot on every new run input snapshot.                  |
| PNG-P04 | Extend the existing atomic theoretical-line relation with mutually exclusive typed lineage families.         |
| PNG-P05 | Copy the exact approved Pantry quantity and Unit without Recipe calculation, conversion or rounding.         |
| PNG-P06 | Generate one unaggregated atomic contribution per positive in-period approved Pantry snapshot line.          |
| PNG-P07 | Retain Pantry header evidence when explicit zero-line or no positive line is in the exact run period.        |
| PNG-P08 | Scope stable Pantry-line predecessor, correction and removal completeness to exact in-period membership.     |
| PNG-P09 | Block first-slice reintroduction of a stable Pantry line after `REMOVED`.                                    |
| PNG-P10 | Reuse precise H0A5 issues and add only three exact Pantry-specific blockers.                                 |
| PNG-P11 | Keep one release boundary and preserve compatibility with contribution-based Confirmed Need materialization. |
| PNG-P12 | Create product and architecture authority only; all executable scope remains separately unauthorized.        |

## 3. Canonical decisions

### PNG-P01 — Closed contribution source families

The Need Generation atomic contribution model admits exactly:

```text
RECIPE_DERIVED
PANTRY_DIRECT
```

This is a closed typed classification, not a generic source registry. Existing Recipe-derived semantics remain unchanged. Adding another family requires a separately approved decision; it is not accomplished by inserting a generic catalog row or authoring a source token.

### PNG-P02 — One shared Need Generation run

Menu/Recipe and Pantry contributions belong to the same exact-period `NeedGenerationRun`, bound to the same exact Planning Input Set and current `READY` evaluation. The run is not split by source family.

`generated_line_count`, blocker count, warning count, validation and release apply to the combined run and its complete contribution set. Atlas introduces no Pantry-only run aggregate, second release lifecycle or generic demand-source workflow engine.

### PNG-P03 — Exact Pantry input-snapshot binding

Every new `NeedGenerationInputSnapshot` retains the exact Pantry triple inherited from its exact readiness evaluation:

```text
pantry_need_batch_id
pantry_need_batch_version
pantry_need_approval_snapshot_id
```

The future authoritative transaction must verify that:

- the triple exactly equals the current expected readiness evaluation binding;
- the Pantry batch remains at the permitted current status;
- batch version and latest approval pointer still match the exact snapshot;
- the Pantry batch week wholly contains the Need Generation period; and
- snapshot ownership and header invariants remain valid.

The complete header triple is mandatory even when the exact approved snapshot has zero lines. A missing, partial, substituted or stale triple cannot authorize generation.

### PNG-P04 — One existing atomic contribution relation

Future persistence extends the existing atomic `TheoreticalNeedLine` model. It does not create a parallel Pantry requirement aggregate or a second theoretical-line relation.

The physical model must have one closed contribution-family discriminator and mutually exclusive typed lineage families.

For `RECIPE_DERIVED`:

- all existing exact Menu, Attendance, Dish, Recipe, RecipeVersion, RecipeLine, RecipeLineRevision and calculation-contract requirements remain present;
- all existing Recipe selection, proportional calculation, source-Unit and correction invariants remain unchanged; and
- Pantry line-level references are absent.

For `PANTRY_DIRECT`:

- the exact Pantry batch, batch version, approval snapshot and stable Pantry line are present;
- an `ACTIVE` contribution binds its exact Pantry approval-snapshot line;
- School, Delivery Location, service date, Ingredient, Unit and positive quantity equal the exact approved Pantry line facts;
- Pantry Purpose and other approved line evidence remain reachable through that typed snapshot-line lineage; and
- Recipe-derived line anchors, Recipe selection/use evidence and Recipe calculation-contract provenance are absent.

A future migration may make currently Recipe-mandatory line columns nullable only with strict contribution-family checks that preserve every Recipe-derived invariant. Generic owner type/ID pairs, JSON-only lineage, source tokens, concatenated identity and caller-authored labels are rejected.

### PNG-P05 — Pantry quantity and Unit truth

For one `ACTIVE` `PANTRY_DIRECT` contribution:

```text
theoretical_quantity
= exact approved Pantry snapshot-line requested_quantity
```

The contribution uses the exact approved Unit carried by that snapshot line. PostgreSQL copies the approved quantity exactly into the existing `numeric(20,6)` storage semantics.

Pantry direct contribution performs no Attendance multiplication, Recipe basis division, Recipe explosion, quantity-per-basis calculation, yield or waste adjustment, purchase rounding, conversion, supplier rule, Warehouse rule or client arithmetic. It does not claim that the Recipe calculation-contract revision produced its quantity.

Each active source line and contribution is strictly positive. Zero and negative Pantry line evidence remain invalid; an approved zero-line snapshot is governed by `PNG-P07` instead.

### PNG-P06 — Atomicity and coexistence

Every-and-only positive approved Pantry snapshot line whose `service_date` is between the exact run `period_start` and `period_end`, inclusive, produces exactly one `ACTIVE` atomic Pantry-direct theoretical contribution. Its source anchor is:

```text
Need Generation run
+ exact Pantry approval snapshot
+ exact Pantry approval-snapshot line
```

Positive approved Pantry snapshot lines outside that exact period remain historical source evidence through the bound Pantry snapshot header. They create no theoretical line or Need Generation issue for the run, do not increment `generated_line_count` and are not release members.

Need Generation does not aggregate eligible Pantry contributions by Ingredient, School, Delivery Location, service date, Unit or Pantry Purpose. Recipe-derived and Pantry-direct contributions that later share one downstream operational identity remain separate atomic facts. Later Confirmed Need materialization may group them only through immutable contribution membership.

### PNG-P07 — Zero-contribution Pantry header behavior

A valid approved zero-line Pantry snapshot requires all of:

```text
line_count = 0
no_additions_confirmed = true
no Pantry approval-snapshot-line rows
```

Need Generation retains the exact Pantry header in `NeedGenerationInputSnapshot` and creates zero Pantry-direct theoretical lines. It creates no zero-quantity placeholder and fabricates no Ingredient, Unit, School, Delivery Location or Purpose. Controlled absence is neither missing Pantry nor a Need Generation issue.

Separately, an approved Pantry snapshot may contain positive lines while containing zero positive lines inside the exact inclusive run period. This is valid period-filtered membership, not a missing Pantry source and not the explicit zero-line form above. Need Generation retains the same exact header and creates zero `ACTIVE` Pantry-direct contributions from those out-of-period lines, with no placeholder, issue, `generated_line_count` increment or release member.

Absent an in-period predecessor obligation, either valid zero-contribution case creates zero Pantry-direct theoretical lines. If a directly linked predecessor has an active in-period Pantry line, only the exact `REMOVED` successor evidence required by `PNG-P08` may still be created; an out-of-period line never creates that obligation. The run may still contain Recipe-derived contributions. The exact Pantry header remains part of immutable run and release explainability.

### PNG-P08 — Successor and predecessor lineage

Across directly linked successor Need Generation runs for the same Planning Input Set and immutable period, predecessor and removal membership is limited to stable Pantry lines represented by positive approved snapshot lines whose `service_date` is inside that exact inclusive period:

1. The same stable `PantryNeedLine` appearing in the successor's in-period approved-line set has exactly one compatible predecessor Pantry-direct contribution.
2. Quantity, Purpose, note, source reference or server-resolved Unit corrections may change the current facts while preserving the stable Pantry line identity and predecessor chain.
3. A genuinely new stable Pantry line in the successor's in-period approved-line set creates one `ACTIVE` contribution without a predecessor.
4. A stable Pantry line that was active inside the exact period in the direct predecessor but is omitted from the successor's in-period approved-line set creates exactly one `REMOVED` zero contribution. It has exactly one predecessor, retains the same stable Pantry line, uses the successor Pantry approval snapshot as controlled absence evidence and has no fabricated current snapshot-line row.
5. A predecessor cannot fork, split, merge, cross a Planning Input Set, cross a period or attach to an unrelated stable Pantry line.
6. Every prior active Pantry-direct contribution inside that immutable run-period scope has exactly one compatible active or removed successor. Silent omission inside that scope is blocking.

The exact current snapshot-line fact is required for `ACTIVE` and absent for the valid `REMOVED` form. The successor snapshot header and stable line provide the typed removal evidence.

Positive snapshot lines outside the exact immutable run period do not participate in predecessor or removal completeness. They are not omissions, do not require predecessors, create neither `ACTIVE` nor `REMOVED` successors and do not trigger silent-omission or removal issues.

### PNG-P09 — Reintroduction boundary

`REMOVED → ACTIVE` reintroduction of the same stable Pantry line is unsupported in the first Pantry Need Generation implementation slice.

The reappearing line is not genuinely new, cannot become active without a predecessor and cannot receive an inferred unapproved removed-to-active link. The run records the existing blocking classification `UNSUPPORTED_REINTRODUCTION_AFTER_REMOVAL`, remains unreleasable and requires explicit invalidation plus a separately approved extension.

### PNG-P10 — Closed issue and validation effects

The combined design reuses existing H0A5 codes when they state the exact failure. In particular:

| Failure                                                                                                            | Reused code                                                                                                                                                                                                                     | Severity   |
| ------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- |
| The readiness-bound Pantry triple is stale at generation entry.                                                    | `STALE_READINESS_SOURCE_SNAPSHOT`                                                                                                                                                                                               | `BLOCKING` |
| Mandatory typed Pantry line lineage is absent or cross-wired.                                                      | `MISSING_TYPED_SOURCE_TRACE`                                                                                                                                                                                                    | `BLOCKING` |
| Pantry predecessor, fork, split, merge, omission or removal evidence is invalid.                                   | `INVALID_PREDECESSOR`, `PREDECESSOR_FORK`, `UNSUPPORTED_SPLIT`, `UNSUPPORTED_MERGE`, `SILENT_PREDECESSOR_OMISSION` or `INVALID_REMOVAL_EVIDENCE`                                                                                | `BLOCKING` |
| A stable Pantry line is reintroduced after removal.                                                                | `UNSUPPORTED_REINTRODUCTION_AFTER_REMOVAL`                                                                                                                                                                                      | `BLOCKING` |
| Released membership is missing, extra, altered, duplicated, cross-run, wrong-version or has a wrong issue summary. | `RELEASE_MEMBERSHIP_MISSING`, `RELEASE_MEMBERSHIP_EXTRA`, `RELEASE_MEMBERSHIP_ALTERED`, `RELEASE_MEMBERSHIP_DUPLICATED`, `RELEASE_MEMBERSHIP_CROSS_RUN`, `RELEASE_MEMBERSHIP_WRONG_VERSION` or `RELEASE_ISSUE_SUMMARY_MISMATCH` | `BLOCKING` |

Exactly these three Pantry-specific codes are added by this decision:

| Added issue code                         | Severity   | Exact condition                                                                                                                                                                                                            |
| ---------------------------------------- | ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `MISSING_PANTRY_INPUT_BINDING`           | `BLOCKING` | A new run or input snapshot lacks any member of the exact mandatory Pantry batch/version/approval-snapshot triple inherited from the readiness evaluation.                                                                 |
| `INVALID_PANTRY_SNAPSHOT_MEMBERSHIP`     | `BLOCKING` | The claimed Pantry snapshot does not own the claimed batch/version, an active contribution's snapshot line is not an exact member of that input snapshot, or typed stable-line/snapshot ownership is otherwise mismatched. |
| `PANTRY_APPROVED_QUANTITY_UNIT_MISMATCH` | `BLOCKING` | An active Pantry-direct contribution quantity or Unit differs from its exact approved Pantry snapshot-line quantity or Unit.                                                                                               |

No Pantry warning is added. `ZERO_ACTIVE_THEORETICAL_QUANTITY` remains the Recipe-derived warning and does not authorize a zero Pantry line. Messages must be operator-safe and must not expose SQL, schema, constraint, role or policy details.

Validation and release require complete every-and-only Pantry contribution evidence in addition to the unchanged Recipe-derived evidence.

### PNG-P11 — Release and Confirmed Need compatibility

The existing `NeedGenerationReleaseSnapshot` remains the sole release boundary. Its complete membership includes every-and-only:

- Recipe-derived theoretical contributions;
- Pantry-direct active contributions;
- valid Pantry-direct removed contributions; and
- applicable immutable Need Generation issue membership.

For Pantry direct lines, release evidence preserves the contribution family, exact Pantry snapshot and stable line, exact current snapshot line when active, exact Ingredient, Unit, School, Delivery Location, service date, quantity, disposition and predecessor evidence. Pantry Purpose remains reachable through the exact snapshot-line lineage.

Confirmed Need materialization continues to consume the released contribution through its existing `NEED_GENERATION` source family. For `PANTRY_DIRECT`, it must use the exact Pantry Delivery Location; it must not silently replace it with the School's current default. Pantry and Recipe-derived contributions may be grouped only when the complete existing operational identity matches, with immutable membership and exact PostgreSQL quantity totals.

This decision authorizes no Confirmed Need approval or quantity adjustment, supplier assignment, Warehouse allocation, Purchase Handoff release, Procurement behavior or Dispatch behavior.

### PNG-P12 — Implementation and application boundary

PANTRY-NG-01 creates product and architecture authority only. It creates no executable authority.

A later bounded implementation task must separately define the exact migration path, altered relations and columns, conditional constraints and indexes, guard/integrity changes, issue-catalog changes, release-membership changes, H0C compatibility changes, pgTAP ownership and exact plan counts, command/read API scope, React scope and security/grant delta.

No Pantry Need Generation API name is approved here. Connected commands and UI require a separately authorized task after this contract merges. This task does not implement or revive `adjustments_add_pantry_need`, `createPantryNeed`, a generic source registry or a generic calculation engine.

## 4. Rationale

The Pantry approval snapshot already contains the exact Ingredient-level facts required for theoretical demand. Fabricating Recipe evidence would corrupt quantity provenance, while a parallel Pantry aggregate would duplicate Need Generation lifecycle, validation and release behavior. A closed discriminator over one atomic contribution model preserves typed lineage, combined run completeness and existing downstream contribution membership.

Stable Pantry line identity supports correction without treating mutable quantity, Unit, Purpose or note as identity. Explicit `REMOVED` successors make absence explainable, while blocking reintroduction keeps the first slice aligned with the already accepted H0A5 correction boundary.

## 5. Rejected alternatives

- Fabricated Dish, Recipe, RecipeVersion, RecipeLine or RecipeLineRevision evidence.
- Pantry as a Recipe override, Wholesale Order, Warehouse request, supplier assignment or fulfilment decision.
- One run, aggregate or release lifecycle per source family.
- Ingredient-, School-, location-, date-, Unit- or Purpose-level aggregation during Need Generation.
- A generic source registry, polymorphic owner pair, JSON-only lineage, token, hash, label or concatenated identity.
- Zero-quantity Pantry placeholders for controlled absence.
- Client arithmetic, Recipe-formula attribution, conversion, rounding, yield, waste, supplier or Warehouse rules.
- Silent predecessor omission, inferred split/merge or first-slice removed-to-active reintroduction.

## 6. Affected contracts

This decision amends the approved direction of:

- [PD-01.6 Need Generation](../architecture/planning-domain-need-generation-contract.md);
- [PANTRY-01 Planning-owned Pantry source](../architecture/pantry-01-planning-owned-pantry-source-contract.md);
- [H0A5 Need Generation lineage](decision-pa-06e-h0a5-need-generation-lineage.md); and
- the historical [TASK-003 source-of-need contract](../architecture/task-003-source-of-need-contract.md) where its generic Pantry lineage conflicts.

It preserves PANTRY-01/PANTRY-02 capture and approval behavior, RMVP-03B readiness behavior, existing Recipe-derived H0A5 semantics and the existing Confirmed Need `NEED_GENERATION` source family.

## 7. Implementation boundary

Current H0A5b SQL remains Recipe-only. Current RMVP-03B binds exact Pantry readiness evidence but creates no Need Generation run or quantity. Current H0C materialization is compatible with released atomic contribution membership but requires a separately approved Pantry-aware destination and lineage amendment before it can consume Pantry-direct lines safely.

This decision changes no migration, SQL, pgTAP, command, RPC, API registry, role, capability, policy, grant, read model, generated type, React, package, workflow, seed, deployment, hosted Supabase project, Retool application, OPS v1/v2 system or production data.

## 8. Supersession rules

`PNG-P01` through `PNG-P12` may be amended or superseded only by a later Product Owner-approved decision that identifies the affected IDs and contracts. A later SQL migration cannot silently redefine these decisions.

This decision supersedes only conflicting generic Pantry lineage, provisional Pantry command examples and Recipe-only universal statements. It does not supersede Recipe-derived H0A5 decisions, PANTRY-01 capture/approval rules, readiness authority, Confirmed Need approval governance or Procurement/Warehouse ownership.
