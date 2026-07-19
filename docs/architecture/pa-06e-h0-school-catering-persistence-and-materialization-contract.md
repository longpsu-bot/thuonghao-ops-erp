# PA-06E-H0 — School-Catering Persistence and Materialization Contract

**Status:** Proposed architecture contract; documentation only; product, architecture, security, and migration review required

**Issue:** [#115](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/115)

**Scope:** Physical prerequisites and bounded implementation sequence required before Atlas can persist and materialize one genuine school-catering Confirmed Need line

**Authority:** [OPS ERP Vision and Product Charter](../handbook/01-vision-product-charter.md), [ARCH-001](arch-001-ops-erp-business-architecture.md), [ARCH-002](arch-002-atlas-system-map.md), [PA-01](pa-01-atlas-persistence-contract.md), [PA-02](pa-02-physical-schema-and-constraint-design.md), [PA-03](pa-03-authorization-command-and-transaction-safety-design.md), the Planning domain contracts, merged PA-04/PA-05D migrations and tests, [PA-06D](pa-06d-quantity-truth-rounding-rebalancing-contract.md), and [PA-06E](pa-06e-confirmed-need-review-adjustment-revision-contract.md)

**Decision record:** [Decision PA-06E-H0 — Source Lineage and Decision Evidence](../decisions/decision-pa-06e-h0-source-lineage-and-decision-evidence.md)

**Implementation decomposition:** [TASK-PA-06E-H0](../implementation-tasks/TASK-PA-06E-H0-school-catering-persistence-materialization.md)

## 1. Executive outcome

PA-06E-H0 defines the prerequisite architecture; it does not implement it.

Atlas retains the existing Planning-owned logical aggregate:

```text
ConfirmedNeedBatch
→ stable ConfirmedNeedLine
→ immutable ConfirmedNeedLineRevision
→ logical ConfirmedNeedSourceReference
→ logical line adjustment/decision evidence
→ immutable approval snapshots
```

No Planning Quantity Confirmation aggregate, generic Quantity Decision aggregate, editable Purchase Handoff, or fake wholesale source is added.

The merged physical database is not ready for school catering. It has no Atlas school, Weekly Menu, Attendance, Planning Input Set, school-catering Need Generation, theoretical-line source bridge, complete line decision evidence, or production Planning quantity-policy persistence. Its Confirmed Need path requires these three wholesale foreign keys:

```text
confirmed_need_batches.wholesale_order_id
confirmed_need_lines.wholesale_order_line_id
confirmed_need_line_revisions.wholesale_order_line_revision_id
```

The selected proposal is the smallest design that preserves typed integrity and `PA-05D.v1` compatibility:

1. Persist the missing school-catering source and calculation prerequisites in separate H0A tasks.
2. Generalize the existing Confirmed Need batch, stable-line, and revision rows with inline typed source alternatives and row-local exactly-one-source constraints.
3. Give every atomic theoretical source contribution an immutable line and an explicit one-to-one predecessor when corrected.
4. Keep authoritative quantities and exact source on immutable line revisions; append human decision evidence in a private child and retain one current-decision pointer on the stable line.
5. Implement materialization separately in H0C. It writes Draft proposals and source lineage only; it never records a Planning decision, approval, release, handoff, Procurement fact, or Dispatch fact.
6. Make a production Planning precision policy a strict H1 prerequisite, not an H0 materialization default.

Every new physical name, function name, capability, event, error, role, and constraint in this document is **proposed for review** unless explicitly identified as an already approved baseline. Nothing here modifies the canonical PA-06A 18-function registry.

## 2. OPS_SYSTEM_MAP placement

| Layer               | PA-06E-H0 placement                                                                                                                                                                                             |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Mission             | Preserve explainable school-catering need from controlled inputs through a Draft Planning review boundary.                                                                                                      |
| Business capability | Persist governed inputs and calculation output; materialize exact calculated contributions for Planning review.                                                                                                 |
| Business domain     | Admin owns school/customer/location references; Recipe owns Recipe/BOM versions; Planning owns Menu, Attendance, readiness, Need Generation, and Confirmed Need.                                                |
| Business object     | Existing School/reference objects, Weekly Menu, Attendance, Planning Input Set, Need Generation run, Theoretical Need line, existing Confirmed Need aggregate, and existing logical source/adjustment children. |
| Business contract   | This H0 contract plus the approved parent contracts; no lifecycle or aggregate is added.                                                                                                                        |
| Command/event       | Proposed noncanonical `create_confirmed_needs_from_generation` with one receipt, one domain event, and one audit event on success.                                                                              |
| Read model          | H0 adds no public review read. H1 later proposes one authorized review/readback surface.                                                                                                                        |
| Application         | None. No React, Storybook, Retool, or OPS v1 change.                                                                                                                                                            |
| Technology          | Separate private PostgreSQL migrations and pgTAP suites only after each bounded task is approved.                                                                                                               |

The order remains:

```text
Mission
→ Business Capability
→ Business Domain
→ Business Object
→ Business Contract
→ Command/Event
→ Read Model
→ Application
→ Technology
```

## 3. Verified current physical baseline

### 3.1 Already merged and reusable

The merged PA-04 and PA-05D implementation provides reusable infrastructure:

- private `atlas_core`, `atlas_admin`, `atlas_planning`, `atlas_audit`, and `atlas_api` schemas;
- server-owned actors, authentication subjects, roles, capabilities, memberships, relational scopes, command receipts, domain events, and audit events;
- forced RLS, revoke-first privileges, no direct API-role table access, and hardened empty-`search_path` functions;
- opaque UUID identity, exact `numeric(20,6)` quantity storage, explicit units, stable lines, revision numbers, predecessor links, one-current-revision indexes, and `on delete restrict` operational history;
- wholesale customer/location, ingredient, unit, Wholesale Order, Confirmed Need, approval snapshot, Purchase Handoff, and Dispatch Requirement physical records;
- exact command identity, idempotency, optimistic concurrency, safe errors, deterministic locking, one receipt/event/audit result, and exact replay helpers; and
- `PA-05D.v1` direct-wholesale pass-through behavior.

The reusable direct-wholesale invariant is:

```text
requested wholesale quantity
= theoretical quantity
= confirmed quantity
= approved snapshot quantity
= handoff quantity
```

### 3.2 Missing school-catering persistence

The merged database contains none of the following physical capabilities:

- an Atlas `schools` relation or an approved school/customer/location representation;
- a customer type other than `WHOLESALE` in the current `customers` constraint;
- Weekly Menu roots, stable lines, approval snapshots, or snapshot lines;
- Attendance roots, stable lines, approval snapshots, or snapshot lines;
- Dish, Recipe, Recipe Version, stable RecipeLine/BOMLine, or immutable line-revision persistence;
- Planning Input Set/readiness roots, typed input references, readiness snapshots, or issues;
- school-catering Need Generation runs, input snapshots, theoretical lines, or typed theoretical-line sources;
- school-catering Confirmed Need source alternatives;
- complete line-level Planning decision evidence, including unchanged acceptance;
- production Planning quantity-policy roots/revisions; or
- a school-catering materialization command.

The current `atlas_admin.customers.customer_type` check accepts only `WHOLESALE`. A delivery location belongs to a wholesale customer. A school/date/ingredient H1 fixture therefore cannot be made genuine by inserting invented wholesale records or by treating fixture labels as typed lineage.

## 4. Prerequisite inventory and dependency matrix

The classification values in this table are the exact Issue #115 categories. “Required in H0” means part of the future H0 program, not implemented by this documentation task.

| Dependency                                                         | Current evidence                                            | Classification                                                      | Bounded owner/sequence                                              | H1 consequence                                                                                 |
| ------------------------------------------------------------------ | ----------------------------------------------------------- | ------------------------------------------------------------------- | ------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| Actor, capability, scope, receipt, event, and audit infrastructure | Merged and exercised by PA-04 through PA-05G                | already merged and reusable                                         | Reuse; extend only through a separately approved security migration | H1 reuses the same envelope and safe-error model.                                              |
| Ingredient and Unit references                                     | Merged; wholesale-compatible                                | already merged and reusable                                         | Reuse after active/reference validation                             | H1 binds exact active unit and policy.                                                         |
| Confirmed Need roots, stable lines, revisions, approval snapshots  | Merged; source FKs are wholesale-only                       | already merged and reusable                                         | H0B generalizes; it does not replace the aggregate                  | H1 operates only after H0B.                                                                    |
| Admin school/customer/location references                          | No school relation; current customer type is wholesale-only | required before H0 implementation but owned by another bounded task | H0A1 — Admin school and service-location foundation                 | H1 scope and read context cannot be genuine without it.                                        |
| Recipe/BOM version references                                      | Logical contracts/prototypes only; no merged tables         | required before H0 implementation but owned by another bounded task | H0A2 — Recipe/BOM immutable reference foundation                    | H1 source explanation depends on exact stable and revision IDs.                                |
| Weekly Menu persistence                                            | Logical contract/prototype only                             | required before H0 implementation but owned by another bounded task | H0A3a — Weekly Menu persistence                                     | Need Generation cannot claim menu lineage without it.                                          |
| Attendance persistence                                             | Logical contract/prototype only                             | required before H0 implementation but owned by another bounded task | H0A3b — Attendance persistence                                      | Need Generation cannot claim portion lineage without it.                                       |
| Planning Input Set/readiness persistence                           | Logical contract/prototype only                             | required before H0 implementation but owned by another bounded task | H0A4 — Input readiness and immutable input snapshot                 | Generation must fail closed without exact approved inputs.                                     |
| Need Generation run and theoretical-line persistence               | Logical contract/prototype only                             | required in H0                                                      | H0A5 — Need Generation persistence                                  | H1 cannot use a fake or mutable calculation row.                                               |
| Theoretical-line typed source lineage                              | PA-02 candidate only                                        | required in H0                                                      | H0A5 — typed source bridges and predecessor model                   | H1 reads exact authoritative upstream trace.                                                   |
| Stable source-contribution identity                                | No physical predecessor on theoretical lines                | required in H0                                                      | H0A5 — explicit predecessor and atomic contribution grain           | H1 corrections cannot match by ingredient/name/order.                                          |
| Confirmed Need source generalization                               | Three required wholesale FKs                                | required in H0                                                      | H0B — inline typed alternatives and compatibility constraints       | H1 fixture must use `NEED_GENERATION`, never fake wholesale.                                   |
| Line decision evidence                                             | Logical adjustment only; no complete physical child         | required in H0                                                      | H0B — append-only decision child and current pointer                | H1 confirmation must write explicit changed or unchanged evidence.                             |
| Planning quantity-policy reference                                 | No production root/revision                                 | required only for H1                                                | H1A — policy root/revision before read/preview/confirm              | H1 preview and commit fail closed when missing or ambiguous.                                   |
| Materialization command                                            | No school-catering command                                  | required in H0                                                      | H0C — `create_confirmed_needs_from_generation`                      | H1 normally consumes its output; local fixtures may provision the same generalized shape only. |
| Authorized review/readback                                         | No school-catering read                                     | required only for H1                                                | H1B — one exact batch/readback surface                              | Must expose no private relation.                                                               |
| Backend preview and Planning confirmation                          | No school-catering commands                                 | required only for H1                                                | H1B — preview and confirm after H1A                                 | Must bind policy/source/version and write line decision evidence.                              |
| Complete-batch validation, approval, release                       | Parent lifecycle approved; generic physical commands absent | later production concern                                            | Later bounded tasks                                                 | H1 does not validate, approve, or release.                                                     |
| School-catering CMD-03 integration                                 | Current CMD-03 is `PA-05D.v1` wholesale-only                | later production concern                                            | Later contract and migration                                        | H1 cannot create Purchase Handoff.                                                             |
| Removal release policy, split/merge policy, downstream correction  | Unresolved in PA-06E                                        | later production concern                                            | Separate product/architecture decisions                             | H0C fails closed; H1 cannot bypass.                                                            |

## 5. Bounded implementation sequence

One migration must not introduce every missing school-catering domain. The proposed sequence is:

```text
H0A1 — Admin school/customer/location reference foundation
H0A2 — Recipe/BOM immutable reference foundation
H0A3a — Weekly Menu persistence and approval snapshots
H0A3b — Attendance persistence and approval snapshots
H0A4 — Planning Input Set/readiness persistence
H0A5 — Need Generation run, atomic theoretical lines, typed sources, predecessor chain
  ↓
H0B — Confirmed Need typed-source generalization and line decision evidence
  ↓
H0C — create_confirmed_needs_from_generation materialization command
  ↓
H1A — versioned Planning quantity-policy root/revision
  ↓
H1B — authorized review, preview, and confirmation for one synthetic line
  ↓
Later — validation, approval, release, school-catering CMD-03, downstream correction
```

The H0A labels are a decomposition contract, not authorized issues or migrations. H0A1 and H0A2 belong to different business owners and must remain separately reviewable. Weekly Menu and Attendance also retain independent lifecycles and approval snapshots. H0A4 may begin only after the exact upstream snapshot contracts are stable. H0A5 consumes them but does not edit them.

## 6. Source-lineage alternatives

### 6.1 Alternative A — inline typed source columns

Generalize the existing Confirmed Need rows with nullable typed alternatives and exactly-one-source checks:

- batch origin: Wholesale Order or initial Need Generation run;
- stable-line origin: Wholesale Order line or initial Theoretical Need line; and
- revision source: Wholesale Order line revision or exact current Theoretical Need line.

**Strengths:** fewest new records; row-local checks; direct typed FKs; existing wholesale columns and joins remain available; one exact source exists at each existing ownership level.

**Risks:** source-kind consistency across batch, line, and revision also needs transactional validation; the logical `ConfirmedNeedSourceReference` is represented by typed columns rather than one same-named table.

### 6.2 Alternative B — dedicated typed source-reference child records

Add one private child table containing the Confirmed Need owner IDs plus nullable Wholesale and Need Generation FKs.

**Strengths:** represents the logical child explicitly and keeps existing rows narrow.

**Risks:** adds a second current/uniqueness relationship beside every revision; still requires nullable alternatives and exactly-one checks; a batch/line/revision can be cross-wired unless the command and extra constraints validate all levels.

### 6.3 Alternative C — bounded typed child family

Add a logical source-reference root and separate wholesale and Need Generation typed child tables.

**Strengths:** extensible and explicit; each source-family row contains only its own FKs.

**Risks:** at least three new tables; “exactly one child family” is not a simple row check; it needs a deferred constraint trigger, a mutable discriminator protocol, or command-only enforcement across tables. That is more machinery than the two currently approved source families require.

### 6.4 Selected proposal

**Select Alternative A, subject to architecture and migration review.**

The source cardinality is exactly one at each existing owner level, so typed inline alternatives are smaller and easier to constrain than a child hierarchy. This choice does not weaken the logical `ConfirmedNeedSourceReference`; it maps that logical child to declared typed foreign keys on the rows whose identity it qualifies.

The proposal is deliberately bounded to `WHOLESALE` and `NEED_GENERATION`. Adding another source family requires an explicit contract and migration. Free-text polymorphic IDs, caller-authored table names, unvalidated lineage JSON, generic source registries, and fake wholesale rows remain prohibited.

## 7. Selected physical direction

### 7.1 Source ownership at three levels

| Existing owner                  | Wholesale typed source                      | School-catering typed source               | Meaning                                                                          |
| ------------------------------- | ------------------------------------------- | ------------------------------------------ | -------------------------------------------------------------------------------- |
| `confirmed_need_batches`        | existing `wholesale_order_id`               | proposed `origin_need_generation_run_id`   | Immutable aggregate origin. A correction does not rewrite this origin.           |
| `confirmed_need_lines`          | existing `wholesale_order_line_id`          | proposed `origin_theoretical_need_line_id` | Stable source-contribution origin. It never changes to a different contribution. |
| `confirmed_need_line_revisions` | existing `wholesale_order_line_revision_id` | proposed `theoretical_need_line_id`        | Exact source result for this immutable payload revision.                         |

Each level receives a constrained `source_kind` with only `WHOLESALE` and `NEED_GENERATION`. Each row must satisfy the matching exactly-one-source rule. Existing wholesale FKs remain typed and become nullable only after existing rows are classified and constraints are validated.

The batch's generation FK is an **origin**. The exact current corrected run is derived from every current line revision's theoretical line and is revalidated transactionally. It is not written over the origin.

### 7.2 Required consistency invariants

The future migration and command tests must prove:

1. Batch, stable line, and current revision use the same source kind.
2. A wholesale stable line and revision belong to the batch's exact Wholesale Order.
3. A school-catering stable-line origin belongs to the batch's origin run or its explicit correction chain.
4. Every school-catering current revision's Theoretical Need line belongs to one exact released current run.
5. That Theoretical Need line is the stable-line origin or an explicit predecessor-chain successor of it.
6. The revision ingredient, unit, and theoretical quantity exactly equal the referenced Theoretical Need line.
7. One non-additive source contribution appears at most once in one batch.
8. A current school-catering batch cannot mix generation runs, input snapshots, schools, dates, or locations outside its approved batch scope.
9. A wholesale row cannot carry a Need Generation source and a school-catering row cannot carry a wholesale source.
10. All typed FKs use `on delete restrict`; operational history is never cascade-deleted.

Row checks enforce exactly-one-source. Composite uniqueness and typed FKs enforce local identity. Cross-row ancestry, same-run, same-scope, and quantity equality remain authoritative command checks under locks and are covered by pgTAP. Whether a narrowly scoped deferred constraint trigger is also justified is pending migration review; H0 does not assume one.

## 8. Stable source-contribution identity and correction model

### 8.1 Alternatives evaluated

| Alternative                                                                | Assessment                                                                                                                                                         |
| -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Explicit `predecessor_theoretical_need_line_id`                            | Selected for ordinary one-to-one correction. It is typed, direct, auditable, and does not add an aggregate.                                                        |
| New stable governed Source Contribution aggregate                          | Rejected for H0. It duplicates identity already supplied by stable upstream Menu/Attendance/RecipeLine anchors and adds lifecycle/governance with no current need. |
| Recompute a key from ingredient/name/order or broad school/date/ingredient | Rejected. Ingredient correction must retain identity; names and array order are mutable; broad coincidence can conflate different RecipeLine contributions.        |
| Generic split/merge relation aggregate                                     | Deferred. H0 rejects split/merge rather than introducing a general graph before product rules exist.                                                               |

### 8.2 Atomic theoretical-line grain

H0A5 must persist one Theoretical Need line per atomic source contribution. Cross-source or cross-RecipeLine totals are derived read models, not source identity.

For a recipe-derived contribution, the stable identity comparison uses typed stable anchors such as:

```text
stable WeeklyMenuLine
+ stable AttendanceLine
+ stable RecipeLine/BOMLine
+ school/service-date/menu-slot scope
```

Exact approved snapshot IDs and exact RecipeLine revisions are still stored as lineage, but version IDs are not the stable contribution identity. Ingredient ID, display name, calculated quantity, array position, and generated row order are not identity fields. This permits an ingredient or quantity correction on the same stable RecipeLine/BOMLine to remain the same source contribution.

### 8.3 Predecessor rules

The proposed `theoretical_need_lines.predecessor_theoretical_need_line_id` is nullable for an initial or genuinely new contribution and required for an accepted one-to-one correction.

The generation boundary must validate:

- predecessor and successor are different rows;
- predecessor is from the immediately prior accepted calculation chain for the same scope;
- stable typed contribution anchors match;
- exact source revisions may change;
- ingredient and quantity may change when the stable RecipeLine/BOMLine identity remains;
- one accepted direct successor exists per predecessor;
- a genuinely new contribution has no predecessor and no prior stable-anchor match; and
- a line is never linked merely because its ingredient, display name, school/date/ingredient tuple, or position matches.

### 8.4 New, changed, removed, split, and merged contributions

| Case                                                    | Required representation                                                                                                            | H0C behavior                                                                                                                                                |
| ------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Quantity correction on same RecipeLine/BOMLine          | New immutable theoretical line with direct predecessor; same typed stable anchors                                                  | Reuse stable Confirmed Need line; create successor Draft revision.                                                                                          |
| Ingredient correction on same stable RecipeLine/BOMLine | New theoretical line with direct predecessor and changed ingredient                                                                | Reuse stable Confirmed Need line; create successor Draft revision with new ingredient; never carry prior confirmed authority.                               |
| Genuinely new contribution                              | New theoretical line with no predecessor and unique stable anchors                                                                 | Create new stable Confirmed Need line and Draft revision 1.                                                                                                 |
| Removed contribution                                    | Explicit immutable successor/tombstone with `REMOVED` disposition, zero calculated contribution, predecessor, and correction trace | Preserve all history and reject materialization with `SOURCE_REMOVAL_POLICY_REQUIRED` until zero/removal policy is approved. Absence alone is not removal.  |
| Split or merge                                          | Cannot be represented as a normal one-to-one predecessor chain                                                                     | Need Generation remains blocked or H0C rejects typed conflicting predecessor sets with `SOURCE_SPLIT_MERGE_POLICY_REQUIRED`. No inference or partial write. |
| Prior active line missing from corrected result         | No explicit successor/tombstone                                                                                                    | Reject as `SOURCE_MAPPING_INCOMPLETE`; do not infer removal.                                                                                                |

The `REMOVED` disposition is a proposed physical vocabulary on theoretical calculation output, not a new business aggregate or a released zero-demand policy. Its exact table constraint remains pending H0A5 review.

## 9. Schema-delta catalog without executable DDL

This catalog states physical intent only. It is not migration syntax.

| Object/change                                  | Proposed shape                                                                                                                            | Constraint/index direction                                                                                  | Status                                                    |
| ---------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| `atlas_admin.schools` or approved equivalent   | Stable school identity linked to the approved customer and delivery-location model                                                        | Typed FKs, active/effective state, no delete when referenced                                                | **Pending product/physical decision**; H0A1 blocker.      |
| Existing customer/location generalization      | Permit approved school-catering ownership without weakening wholesale relationships                                                       | Preserve current wholesale rows and exact location ownership                                                | **Pending H0A1 decision**.                                |
| Recipe/BOM physical family                     | Dish, Recipe, immutable Recipe Version, stable RecipeLine/BOMLine, immutable line revision                                                | Stable line identity; exact revision FKs; no released-row overwrite                                         | **Pending H0A2 physical decision**.                       |
| Weekly Menu physical family                    | Root, stable lines, approval snapshot, snapshot lines                                                                                     | Exact school/date/slot/dish and approved version                                                            | **Required H0A3a; table details pending its task**.       |
| Attendance physical family                     | Root, stable lines, approval snapshot, snapshot lines                                                                                     | Exact school/date portion facts and approved version                                                        | **Required H0A3b; table details pending its task**.       |
| Planning Input Set/readiness                   | Root, typed input references, immutable readiness snapshot, issues                                                                        | Exactly one approved Menu and Attendance set for the declared scope                                         | **Required H0A4; exact scope pending**.                   |
| `need_generation_runs`                         | Root with input snapshot, calculation-rule revision, status, scope, version                                                               | Released run immutable; unique run number per input set                                                     | **Proposed PA-02-aligned H0A5 direction**.                |
| `need_generation_input_snapshots`              | Exact Menu, Attendance, Recipe/BOM, readiness, conversion, and calculation-rule versions                                                  | Typed relations; no required lineage JSON                                                                   | **Proposed H0A5 direction**.                              |
| `theoretical_need_lines`                       | One atomic contribution; run, school/date, ingredient, quantity/unit, disposition, predecessor                                            | Unique atomic source anchor per run; predecessor indexed; active quantity nonnegative; removed exactly zero | **Selected proposal; pending H0A5 migration approval**.   |
| `theoretical_need_line_sources`                | Typed bridge rows to exact Menu snapshot line, Attendance snapshot line, RecipeLine/BOMLine revision, and other approved source revisions | Exactly one typed source FK per bridge row; required source-kind set per calculation kind                   | **Selected PA-02 direction; pending exact source set**.   |
| `confirmed_need_batches` generalization        | Add source kind and origin Need Generation run; retain wholesale FK                                                                       | Exactly one typed origin; unique wholesale order or generation origin as applicable                         | **Selected proposal; pending H0B migration approval**.    |
| `confirmed_need_lines` generalization          | Add source kind, origin Theoretical Need line, and nullable current decision pointer; retain wholesale line FK                            | Exactly one typed origin; unique source contribution in batch; pointer belongs to same line                 | **Selected proposal; pending H0B migration approval**.    |
| `confirmed_need_line_revisions` generalization | Add source kind and exact Theoretical Need line; retain wholesale revision FK                                                             | Exactly one typed source; unique revision number; one current; predecessor chain; immutable payload         | **Selected proposal; pending H0B migration approval**.    |
| `confirmed_need_line_decisions`                | Append-only line decision evidence described in section 10                                                                                | Unique decision number per stable line; unique command/line; no delete; predecessor/supersession chain      | **Selected proposal; pending H0B migration approval**.    |
| Planning policy root/revisions                 | Stable policy scope plus immutable effective revision, unit, positive step, owner/effective period                                        | No overlapping eligible revision in same governed scope; no fallback                                        | **Required only for H1; exact scope/precedence pending**. |

## 10. Line decision-evidence physical design

### 10.1 Alternatives evaluated

| Alternative                                  | Assessment                                                                                                                                                                      |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| A — append-only adjustment/decision child    | Represents changed and unchanged decisions clearly, but authoritative quantity/source still belongs on the revision.                                                            |
| B — decision metadata only on line revisions | Rejected. Unchanged acceptance would require an identical successor or mutation of an immutable materialized Draft revision.                                                    |
| C — hybrid                                   | **Selected proposal.** Immutable line revision stores quantity/item/unit/source; append-only child stores human authority, policy, before/after, reason, versions, and command. |

### 10.2 Proposed decision child

The private `confirmed_need_line_decisions` child records at least:

- decision ID and decision number within the stable line;
- stable Confirmed Need line and exact quantity-bearing line revision;
- decision kind: `UNCHANGED_PROPOSAL_ACCEPTED` or `ADJUSTED_QUANTITY_CONFIRMED`;
- theoretical before value;
- proposed/prior confirmed before value;
- authoritative confirmed after value;
- exact unit;
- exact Need Generation run and Theoretical Need line;
- exact Planning policy revision;
- batch version before and after;
- reason code and conditional reason note;
- deciding actor and decision time;
- command receipt, command, correlation, and source interface; and
- optional superseded decision ID for an evidence correction.

The decision child is evidence, not an aggregate. The Confirmed Need batch version remains the concurrency boundary.

### 10.3 Current and unique decision rules

The selected proposal adds a nullable current-decision pointer to the stable Confirmed Need line.

- H0C leaves it null because materialization creates no Planning decision.
- H1 confirmation appends a decision row and moves the pointer atomically.
- The pointer must reference a decision for the same stable line and its current line revision.
- Decision numbers are positive and unique within the line.
- One command may decide several lines, but `(command_id, confirmed_need_line_id)` is unique.
- A superseding evidence correction must point to the prior current decision; one prior decision cannot fork into two successors.
- Decision rows are never updated or deleted. A correction appends a full replacement evidence row, advances the pointer, and retains the prior row.
- Moving the pointer and any permitted prior-revision `is_current`/status metadata happens only inside the owning command while the batch is locked.

The exact composite FK/index arrangement for “pointer belongs to same line” is a migration-review detail, but the invariant is mandatory and must be database-tested.

### 10.4 Before/after and reason semantics

For `UNCHANGED_PROPOSAL_ACCEPTED`:

```text
before_theoretical = current revision theoretical quantity
before_proposed = current revision confirmed/proposed field
after_confirmed = before_proposed
```

No identical successor quantity revision is created. A governed reason code identifies explicit acceptance. Whether a free-text note is required is pending reason-policy approval.

For `ADJUSTED_QUANTITY_CONFIRMED`:

```text
before_theoretical = current source calculation
before_proposed = current proposal or prior decision-bound value
after_confirmed = exact preview-bound confirmed value
```

A successor line revision carries the changed quantity and the same exact source unless source correction also applies. A governed reason code is mandatory; note rules remain pending.

### 10.5 Source and policy binding

Every school-catering decision binds the exact current Theoretical Need line and exact policy revision. A Draft materialization revision may have no policy because it is not authoritative. The decision is invalid if source, line revision, batch version, policy, or scope changes before commit.

This avoids mutating a materialized Draft merely to add a later policy reference. For adjusted confirmation, the successor revision and the decision are created together; for unchanged acceptance, the decision supplies the missing authority and policy binding without quantity duplication.

### 10.6 Logical `ConfirmedNeedAdjustment` read

The existing logical adjustment history is derived from decision rows where `decision_kind = ADJUSTED_QUANTITY_CONFIRMED`. It projects actor/time, reason, before/after quantity, unit, exact revision, source, policy, and command. Unchanged decisions remain visible in the broader line-decision history but do not appear as quantity adjustments.

## 11. Planning quantity-policy dependency

### 11.1 H0/H1 decision

**Selected proposal:** H0 does not create a minimum production Planning policy. A versioned, fail-closed policy is a strict H1 prerequisite.

H0C copies exact theoretical quantity into the existing `confirmed_quantity` storage field as a clearly non-authoritative Draft proposal. It performs no Planning step quantization, rounding, trimming, or confirmation. Authority is derived from explicit line decision evidence, not from the presence of a numeric value.

H1 preview and commit must refuse to operate until one exact effective Planning policy revision resolves. This keeps fixture values such as `0.01 kg` test-only and prevents an H0 migration from approving production operations policy accidentally.

### 11.2 Required future policy behavior

The H1A policy design must support:

- a positive exact step by governed typed scope and unit;
- a stable policy root and immutable effective revision;
- half-open effective periods;
- no overlapping eligible revision in the same scope;
- explicit scope precedence if more than one scope level is approved;
- fail-closed behavior when missing, inactive, conflicting, or ambiguous;
- exact policy revision binding in preview, decision evidence, receipt, event, and audit; and
- no generic formula engine or implicit numeric-scale fallback.

Exact production steps, scope levels, precedence, policy owner, approval roles, effective-date semantics, and reason taxonomy remain pending product decisions.

## 12. Materialization command contract

### 12.1 Status and ownership

Proposed noncanonical function:

```text
atlas_api.create_confirmed_needs_from_generation(request jsonb)
```

Proposed capability: `confirmed_need_generation.materialize`.

Both names require later registry/security approval. H0 documentation does not add them to PA-06A.

Planning owns the resulting Confirmed Need. The command consumes an immutable Planning-owned Need Generation output; Recipe, Admin, React, Retool, and the caller cannot write Planning-confirmed authority.

### 12.2 Request

The request uses the established Atlas write envelope. The allowlisted payload is:

```json
{
  "need_generation_run_id": "uuid",
  "need_generation_run_version": 1,
  "confirmed_need_batch_id": null
}
```

Rules:

- `confirmed_need_batch_id` is null for initial materialization.
- It is the exact existing batch selector for corrected materialization.
- Shared `expected_version` is the creation sentinel `1` for initial materialization and the current expected batch version for correction.
- Initial versus correction mode is derived from the target selector and authoritative lineage; the caller does not author a lifecycle status or trusted mode.
- Unknown top-level or payload fields fail validation.

The request never accepts:

- caller-generated batch, line, revision, decision, event, audit, or source-reference IDs;
- actor authority, role, capability, school scope, status, approval, release, or decision kind;
- source schema/table/column names or free-text polymorphic IDs;
- theoretical, calculated, proposed confirmed, confirmed, or policy quantities;
- Menu, Attendance, Recipe/BOM, source lineage, predecessor, ingredient, or unit facts;
- a Planning policy or fallback step; or
- a wholesale order, line, or revision for a school-catering call.

### 12.3 Common preconditions

The command must authoritatively resolve and lock:

- the authenticated subject, active actor, capability, and exact relational school/customer/location/date scope;
- one exact Need Generation run and requested version;
- run status `RELEASED_FOR_CONFIRMATION` and its immutable release evidence;
- one complete input snapshot and approved typed Menu/Attendance/Recipe/BOM/calculation references;
- every active theoretical line and typed source bridge;
- every predecessor and disposition needed to prove the source-contribution set;
- active ingredients and units;
- the target Confirmed Need batch, stable lines, current revisions, and decision pointers where correcting; and
- absence of an incompatible batch/materialization for the same origin.

Any missing, stale, ambiguous, cross-scope, split/merge, implicit removal, or fake source fails the complete command.

### 12.4 Initial materialization

For a run with no prior Confirmed Need batch:

1. Create one `NEED_GENERATION` Confirmed Need batch in `DRAFT_REVIEW`, version 1, whose origin is the exact released run.
2. For every active atomic Theoretical Need line, create one stable `NEED_GENERATION` Confirmed Need line whose origin is that line.
3. Create revision 1 in `DRAFT`, current, with exact ingredient, unit, theoretical quantity, source line, and predecessor metadata.
4. Set the stored candidate confirmed quantity equal to the exact theoretical quantity without rounding; authorized reads must label it proposed because no current decision exists.
5. Leave every current-decision pointer null.
6. Create no approval snapshot, release, Purchase Handoff, Planning policy fact, or decision evidence.
7. Append exactly one completed receipt, `ConfirmedNeedsCreated` domain event, and matching audit event atomically.

### 12.5 Corrected materialization

For an exact existing batch in `DRAFT_REVIEW` or explicitly `REOPENED`:

1. Verify the new released run is the allowed corrected successor of the batch's current exact run.
2. Require an explicit one-to-one theoretical predecessor for every reused contribution.
3. Reuse a stable Confirmed Need line only when the new theoretical line descends from that line's exact prior theoretical source.
4. Create a successor Draft revision for every reused contribution, even when quantity is unchanged, because source binding changed and Planning must review again.
5. Mark only the prior revision's controlled current/status metadata noncurrent/superseded; never change its payload.
6. Clear the stable line's current-decision pointer for the new Draft consequence; old decision rows remain historical.
7. Create a new stable line and revision 1 for a genuinely new contribution.
8. Set every new proposal equal to the new theoretical quantity. Do not carry a prior confirmed value automatically; that product choice remains pending.
9. Reject explicit removed tombstones until removal/zero policy is approved.
10. Reject incomplete, split, merge, duplicate-predecessor, and mixed-scope mappings with no partial write.
11. Increment the batch version exactly once regardless of affected-line count.
12. Append exactly one completed receipt, proposed `ConfirmedNeedsRematerialized` domain event, and matching audit event atomically.

If the batch is `APPROVED` or `RELEASED_FOR_PURCHASE_HANDOFF`, H0C returns `REOPEN_REQUIRED`; it never reopens automatically. If Purchase Handoff exists, H0C cannot mutate it and returns the governed downstream-correction blocker.

### 12.6 Success response

The established success envelope returns exact values:

```text
success
command_id
correlation_id
idempotency_status
affected_aggregate_ids.need_generation_run_id
affected_aggregate_ids.confirmed_need_batch_id
affected_aggregate_ids.created_confirmed_need_line_ids[]
affected_aggregate_ids.reused_confirmed_need_line_ids[]
affected_aggregate_ids.created_line_revision_ids[]
affected_aggregate_ids.current_line_revision_ids[]
affected_aggregate_ids.superseded_line_revision_ids[]
new_versions.need_generation_run_version
new_versions.confirmed_need_batch_version
emitted_event_ids[]
audit_event_ids[]
safe_operator_message
warnings[]
blockers[]
```

Alternative A creates no standalone source-reference ID. Exact source IDs are the returned/current Theoretical Need line IDs reachable from each returned revision and may also be returned in a bounded ordered `source_bindings` array if API review approves that field.

### 12.7 Safe errors and write certainty

| Proposed error                       | Meaning and write behavior                                                           |
| ------------------------------------ | ------------------------------------------------------------------------------------ |
| `VALIDATION_FAILED`                  | Malformed/unknown fields or invalid creation sentinel; no domain write.              |
| `GENERATION_NOT_RELEASED`            | Run is not exactly released for confirmation; no domain write.                       |
| `SOURCE_LINEAGE_INCOMPLETE`          | Required typed input/source/revision is missing; no domain write.                    |
| `SOURCE_REVISION_STALE`              | Run, input snapshot, source revision, or target source changed; no domain write.     |
| `SOURCE_MAPPING_INCOMPLETE`          | A prior active contribution has no explicit successor/tombstone; no domain write.    |
| `SOURCE_SUCCESSOR_AMBIGUOUS`         | Duplicate or cross-wired predecessor; no domain write.                               |
| `SOURCE_REMOVAL_POLICY_REQUIRED`     | Explicit removal is present but release behavior is unapproved; no domain write.     |
| `SOURCE_SPLIT_MERGE_POLICY_REQUIRED` | Split/merge cannot be represented by the approved one-to-one chain; no domain write. |
| `REOPEN_REQUIRED`                    | Approved/released batch must be explicitly reopened; no domain write.                |
| `DOWNSTREAM_CORRECTION_REQUIRED`     | Existing Handoff or later commitment prevents silent correction; no domain write.    |
| `STALE_VERSION`                      | Expected run/batch version differs; no domain write and no blind retry.              |
| `CAPABILITY_DENIED` / `SCOPE_DENIED` | Server-owned authorization fails; no domain write and no selector broadening.        |
| `IDEMPOTENCY_CONFLICT`               | Same command/key with different canonical intent; no new write.                      |
| `RETRYABLE_CONCURRENCY_FAILURE`      | Whole transaction rolled back; retry only the exact frozen request.                  |
| `INTERNAL_COMMAND_FAILURE`           | No success may be inferred; reconcile by command ID before retry.                    |

Exact error names are proposed and noncanonical. They must be reconciled with the established safe envelope before implementation.

### 12.8 Idempotency and concurrency

- The scoped idempotency key and canonical request hash are mandatory.
- Exact replay returns the original batch/line/revision/event/audit IDs and creates nothing new.
- Changed reuse returns `IDEMPOTENCY_CONFLICT`.
- A deterministic failure after receipt creation may retain a safe `FAILED_NON_RETRYABLE` receipt under the existing helper contract; it creates no domain or audit event.
- Two initial calls for the same run cannot create two batches.
- Two correction calls for the same batch/version cannot fork the current revision chain.
- One successful correction increments the batch once.
- Serialization/deadlock handling retries or reports the complete transaction only; no partial line result becomes visible.

## 13. Compatibility and migration strategy

### 13.1 Additive-first migration plan

The preferred migration path is staged and forward-compatible:

1. Implement each approved H0A prerequisite in its own migration/task and test it independently.
2. Add nullable source-kind and Need Generation alternative columns to existing Confirmed Need tables.
3. Classify existing rows as `WHOLESALE` from their required typed FKs; inspect and prove counts in local/approved environments only.
4. Add and validate typed FKs, source-kind checks, row-local exactly-one checks, and source-specific uniqueness/indexes.
5. Update internal PA-05D inserts to write explicit `WHOLESALE` classification while preserving its public request, response, capability, events, quantities, and transitions.
6. Only after backfill and validation, remove `not null` from the three wholesale source columns so `NEED_GENERATION` rows can exist.
7. Add the append-only decision child and nullable stable-line current-decision pointer; do not invent decisions for existing wholesale rows.
8. Implement H0C in a later migration after H0B constraints and tests pass.

Making a current wholesale FK nullable is a controlled compatibility generalization, not destructive data migration. The FK remains and `WHOLESALE` rows still require it. No row is moved behind a compatibility view and no existing public command signature changes.

### 13.2 `PA-05D.v1` compatibility

The following remain exact:

- four PA-05D function names, contract version, capabilities, payloads, success fields, safe-error behavior, idempotency, and events;
- `release_wholesale_order` atomically creates a version-1 Confirmed Need batch already released for Purchase Handoff;
- theoretical, confirmed, approved, and released quantities remain equal;
- one stable Confirmed Need line per Wholesale Order line and one released line revision per source revision;
- one approval snapshot line per current released line;
- CMD-03 consumes the same exact wholesale source chain and creates no Procurement fact; and
- existing PA-05D authorization, cross-wire, replay, stale, privilege, and exact-count tests remain behaviorally unchanged.

Internal PA-05D SQL may need only:

- explicit `source_kind = WHOLESALE` values;
- source-specific predicates on uniqueness/current queries; and
- additional local consistency assertions required by generalized nullable columns.

The public contract must not accept Need Generation fields. The PA-05D runtime must not receive Need Generation writes or H0C ownership.

### 13.3 Index and uniqueness direction

Future migration review must include:

- current partial unique indexes on Wholesale and Confirmed Need line revisions;
- one Confirmed Need batch per non-null Wholesale Order origin;
- one initial Confirmed Need batch per non-null Need Generation origin;
- one stable Confirmed Need line per typed origin within a batch;
- one line revision per exact typed source within its stable line;
- indexed Need Generation run, predecessor, input snapshot, and every typed source bridge FK;
- one unique direct successor for an accepted one-to-one predecessor chain;
- decision number uniqueness per line, command/line uniqueness, decision predecessor non-forking, and current pointer integrity; and
- service-period/status indexes only for approved read/command paths.

No index may rely on ingredient name, display order, or an unvalidated source hash as authoritative identity.

### 13.4 Rollback and forward-fix

Before any school-catering row or H0C execution exists, an unshipped migration can be reverted through normal Git review. Once operational school-catering history exists, rollback must not drop generalized columns, source tables, theoretical lines, decisions, receipts, events, or audit evidence.

The safe operational response is:

1. revoke H0C execute if the command is unsafe;
2. keep private history readable to authorized diagnostics;
3. deploy an additive forward-fix migration and corrective command where required; and
4. never restore `not null` wholesale-only constraints over school-catering rows.

This documentation task performs no production inspection, backfill, migration, or rollback.

## 14. Security and transaction design

### 14.1 Private boundary and runtime ownership

- All new domain tables stay in private `atlas_admin` or `atlas_planning`; none is exposed to the Data API.
- The browser calls only reviewed `atlas_api` functions and receives no table, sequence, view, or domain-schema privilege.
- React never receives a service-role or secret credential.
- Proposed H0C owner: a dedicated `NOLOGIN`, `NOINHERIT` `atlas_planning_materialization_runtime`, subject to naming review.
- The dedicated runtime avoids broadening `atlas_planning_command_runtime`, whose PA-05D evidence requires ownership of exactly four PA-05D entry functions.
- The materialization runtime receives only exact reads of approved Admin/Recipe/Planning sources, exact writes to generalized Confirmed Need rows/receipt/event/audit, and no Procurement, Evidence, Warehouse, Dispatch, Storage, legacy, or reporting write privilege.
- `PUBLIC`, `anon`, `authenticated`, and `service_role` privileges are revoked before an allowlisted `authenticated` execute grant is considered.

### 14.2 RLS and function hardening

- Enable and force RLS on every new table.
- Use verb-specific runtime policies and exact grants; no broad `FOR ALL` or catch-all API-role policy.
- The privileged function uses an empty `search_path`, fully qualified objects, static SQL, and no caller-controlled object name.
- Function owner is not a superuser, table owner, service role, or `BYPASSRLS` role.
- No direct browser read of private Menu, Attendance, Recipe, Generation, Confirmed Need, decision, receipt, event, or audit rows.
- Advisor/lint findings for definer ownership, mutable search path, public execute, RLS, and unindexed FKs are blocking for a future migration PR.

### 14.3 Server-side authorization and unresolved scope dependency

The function resolves the authenticated subject and active actor server-side. It checks the proposed capability plus relational customer/school/location/date scope. It never trusts a caller-supplied actor, school authority, role, or scope.

The current physical scope catalog supports customer/location-oriented PA-05D checks but has no approved general school/service-date scope. H0A1 or a separate security task must approve the relational school/customer/location model and the server-owned service-date/effective-period rule. H0C must not be implemented with a temporary global grant.

Whether H0C is callable by a Planning human, a dedicated integration actor, or both is pending. Each allowed actor class requires its own capability, source scope, and audit attribution; shared `system` or service-role identity is prohibited.

### 14.4 Deterministic lock order

Proposed lock order, within PA-03's global Planning class and ascending by UUID inside each set:

```text
command receipt
→ school/customer/location and ingredient/unit references
→ Recipe/BOM and approved source snapshot references
→ Planning Input Set and Need Generation run
→ theoretical lines, predecessors, and typed source bridges
→ target Confirmed Need batch
→ stable Confirmed Need lines
→ current line revisions and decision pointers
→ inserts and controlled supersession metadata
→ one domain event and one audit event
```

The target IDs may be discovered before locking, but their state is not trusted until reread under locks. The command uses `read committed` plus the common parent-lock convention unless the implementation proves an unprotected predicate and separately justifies `serializable`.

### 14.5 Atomicity and safe outcomes

One success transaction includes every batch/line/revision/source classification change, the batch version, the completed receipt, one event, and one audit event. Any invalid line rolls back all domain writes. External calls, file work, notifications, or client interaction never occur inside the transaction.

Safe errors disclose only public contract fields, current/expected version when authorized, opaque allowed references, write certainty, retryability, and recovery. SQL, table/policy/constraint names, stack traces, JWTs, credentials, and private source payloads remain server-only diagnostics.

## 15. Test blueprint

### 15.1 H0A source and generation persistence

- school/customer/location references satisfy the approved typed ownership model;
- approved Menu and Attendance snapshots are immutable and exact;
- Planning Input Set references one exact compatible approved input set;
- a released Need Generation run binds exact input, Recipe/BOM, conversion, and calculation-rule revisions;
- every theoretical line has the required typed source bridges;
- theoretical lines are atomic source contributions rather than ingredient-name aggregates;
- quantity and ingredient corrections on the same stable RecipeLine/BOMLine use an explicit predecessor;
- new contribution has no predecessor and receives unique stable anchors;
- explicit removal is a typed/tombstone result, never inferred from absence;
- split/merge remains blocked and explicit; and
- no source identity depends on ingredient name, display name, array order, generated order, or broad school/date/ingredient coincidence.

### 15.2 H0B constraints and compatibility

- every source level satisfies exactly one of Wholesale or Need Generation;
- mixed source kinds and cross-wired batch/line/revision chains fail;
- a school-catering row cannot use a fake wholesale source;
- a wholesale row cannot use a Need Generation source;
- existing wholesale fixtures retain exact `PA-05D.v1` behavior and equality;
- existing PA-05D payloads/responses/events/capabilities remain unchanged;
- stable Confirmed Need line continuity occurs only through the exact theoretical predecessor chain;
- a different source contribution cannot reuse a stable Confirmed Need line;
- one current revision per stable line and valid direct revision predecessors;
- prior revision payload is immutable while controlled current/status metadata may supersede it;
- decision rows are append-only, current pointer cannot cross lines/revisions, and a decision predecessor cannot fork;
- `UNCHANGED_PROPOSAL_ACCEPTED` requires no identical successor revision;
- `ADJUSTED_QUANTITY_CONFIRMED` binds exact before/after, actor/time, reason, source, policy, versions, and command; and
- adjusted decision rows derive the logical adjustment history exactly.

### 15.3 H0C materialization behavior

- only one exact `RELEASED_FOR_CONFIRMATION` run/version is consumed;
- initial materialization creates one Draft batch, stable lines, Draft revisions, and exact typed source bindings;
- proposed quantity equals exact theoretical quantity without rounding and is not authoritative;
- materialization creates no line decision evidence, policy fact, approval snapshot, release, Handoff, Procurement, or Dispatch fact;
- correction reuses a stable line only for an exact predecessor-chain successor;
- correction creates a new revision even when only source binding changed;
- new contributions create new stable lines;
- removed, missing, split, merge, duplicate-predecessor, and mixed-scope cases reject atomically;
- prior revisions, decisions, approvals, releases, handoffs, POs, Dispatch facts, receipts, events, and audit remain unchanged;
- exact replay returns the same IDs and creates no duplicates;
- changed idempotency reuse conflicts;
- stale run, batch, line, source, and target state reject with no partial write;
- concurrent initial/correction calls create one safe chain; and
- one success creates exactly one completed receipt, one domain event, and one audit event.

### 15.4 Authorization and security

- unauthenticated, mismatched subject, inactive actor, inactive membership, missing capability, wrong school/customer/location/date scope, and unsupported delegation fail closed;
- selector broadening and a global fallback are absent;
- `anon`, `authenticated`, and `service_role` retain no direct private relation privileges;
- `authenticated` can execute only explicitly approved signatures;
- materialization runtime is `NOLOGIN`, `NOINHERIT`, owns only approved functions, has no schema create/sequence mutation, and cannot write outside exact Planning/audit rows;
- PA-05D runtime remains bounded to its exact four entry functions;
- every definer has empty fixed `search_path`, fully qualified static SQL, and no public execute;
- forced RLS and revoke-first grants cover every new table; and
- future migration PRs pass Supabase/Postgres advisors and focused pgTAP security checks.

### 15.5 H1 gate tests

Before H1 begins, tests must prove:

- one genuine school/date/ingredient line exists without wholesale lineage;
- one exact current generation/source chain exists;
- no Planning decision exists immediately after materialization;
- one effective versioned fixture policy exists only in rolled-back/local test data;
- missing or ambiguous policy fails closed;
- H1 has approved read/preview/confirm contracts and exact relational scope; and
- validation, approval, release, CMD-03, Procurement, PO, Dispatch, Retool, hosted Supabase, and production remain absent.

## 16. H1 gate

PA-06E-H1 is blocked until all of these are merged and verified:

1. H0A1 through H0A5 provide genuine typed school-catering sources and one released generation result.
2. H0B provides typed Confirmed Need sources and append-only line decision evidence.
3. H0C materializes one Draft line without a Planning decision.
4. H1A provides one exact effective versioned Planning policy and fail-closed resolution.
5. The school/customer/location/date authorization model is approved and tested.
6. API names, capabilities, owners, grants, request/response fields, safe errors, and events are approved for the bounded H1 slice.

A locally inserted synthetic line may replace execution of H0C only in H1 tests after the generalized H0 schema exists. It must use genuine H0 typed source rows and cannot use fake wholesale records.

## 17. Explicit pending decisions

No implementation agent may guess the following:

### 17.1 Physical and ownership decisions

1. Whether School is a child of Customer, a distinct service recipient related to Customer, or another approved typed model.
2. How current wholesale-only `customer_type` and delivery-location ownership are generalized.
3. Exact Recipe/BOM table names and whether `RecipeLine` and `BOMLine` are one stable physical family or two typed families.
4. Exact Menu and Attendance approval-snapshot tables and stable-line correction mechanics.
5. Exact Planning Input Set scope grain and whether one generation run may span multiple schools, dates, or locations.
6. Exact calculation-rule and conversion-rule revision roots required by Need Generation.
7. Exact theoretical-line `REMOVED` disposition constraint and correction evidence.
8. Whether cross-row source consistency also warrants a deferred constraint trigger after command enforcement is proven.
9. Exact decision-current composite FK/index design and decision-evidence correction reason rules.
10. Existing environment row counts and whether any non-wholesale data already violates the proposed classification; no production inspection is authorized here.

### 17.2 Product and policy decisions

11. Zero/removal review and release behavior.
12. Split and merge mapping/approval behavior.
13. Whether a prior confirmed quantity may be offered as a corrected-run proposal; H0C defaults to the new theoretical value until approved otherwise.
14. Planning policy scope levels, precedence, owner, approver, effective-date semantics, and production step values.
15. Reason-code taxonomy, when a note is mandatory, and decision-evidence correction authority.
16. Separation of duties for materialization, confirmation, later approval, and release.
17. Whether purchase-policy absence blocks Planning confirmation or only later handoff; H0 persists no purchase advisory.

### 17.3 API, security, and operations decisions

18. Canonical function, capability, contract-version, event, and safe-error names.
19. Whether H0C is callable by Planning humans, a dedicated integration actor, or both.
20. Exact school/customer/location/service-date scope predicates and scope-storage extension.
21. Exact runtime-role name and practical least-privilege grant set.
22. Maximum run/line count, statement timeout, lock timeout, and retry policy for materialization.
23. Deterministic failed-command receipt policy for every proposed H0C error.
24. Registry versioning and how the canonical 18-function boundary is amended, if approved.
25. Event payload and audit before/after minimization rules.
26. Cutover, rehearsal, production backfill, and deployment plan. None is part of H0 documentation.

## 18. Security, migration, and rollback effect of this task

This contract changes documentation only. It creates no SQL, migration, RPC, RLS policy, role, grant, generated type, React code, Storybook, package, Retool resource, Supabase project state, production row, credential, deployment, API-registry entry, or executable test.

Security and live systems are unchanged. Documentation rollback is a normal Git revert. There is no database or deployment rollback for this task.
