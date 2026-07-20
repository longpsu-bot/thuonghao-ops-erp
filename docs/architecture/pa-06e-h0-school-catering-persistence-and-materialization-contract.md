# PA-06E-H0 — School-Catering Persistence and Materialization Contract

**Status:** Proposed architecture contract; documentation only; product, architecture, security, and migration review required

**Issue:** [#115](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/115)

**Scope:** Physical prerequisites and bounded implementation sequence required before Atlas can persist and materialize one genuine school-catering Confirmed Need line

**Authority:** [OPS ERP Vision and Product Charter](../handbook/01-vision-product-charter.md), [ARCH-001](arch-001-ops-erp-business-architecture.md), [ARCH-002](arch-002-atlas-system-map.md), [PA-01](pa-01-atlas-persistence-contract.md), [PA-02](pa-02-physical-schema-and-constraint-design.md), [PA-03](pa-03-authorization-command-and-transaction-safety-design.md), the Planning domain contracts, merged PA-04/PA-05D migrations and tests, [PA-06D](pa-06d-quantity-truth-rounding-rebalancing-contract.md), and [PA-06E](pa-06e-confirmed-need-review-adjustment-revision-contract.md)

**Decision record:** [Decision PA-06E-H0 — Source Lineage and Decision Evidence](../decisions/decision-pa-06e-h0-source-lineage-and-decision-evidence.md)

**Need Generation decision:** [Decision PA-06E-H0A5 — Need Generation Run and Theoretical Lineage](../decisions/decision-pa-06e-h0a5-need-generation-lineage.md)

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

The corrected proposal is the smallest design that preserves the active operational confirmation intent, atomic calculation trace, typed integrity, and `PA-05D.v1` compatibility:

1. Persist the missing school-catering source and calculation prerequisites in separate H0A tasks. Atomic Theoretical Need lines remain the calculation grain.
2. Select, subject to explicit product-owner approval, one operational Confirmed Need stable line per typed service-date, school/destination, ingredient, controlled-unit, and approved-scope tuple. One atomic contribution is **not** one Confirmed Need line.
3. Give each immutable school-catering line revision a private typed contribution-membership snapshot containing every exact Theoretical Need line included in its theoretical total.
4. Enforce operational identity, exact released-run membership, membership ownership, and total-equals-contributions in PostgreSQL through composite keys/FKs, partial unique indexes, and mandatory deferred constraint triggers. Command checks are defense in depth only.
5. Implement materialization separately in H0C. It groups a complete released run into Draft operational proposals and immutable memberships; it never records a Planning decision, approval, release, handoff, Procurement fact, or Dispatch fact.
6. Create Planning policy roots/revisions in H1A, then create decision-evidence persistence with a mandatory policy FK and current-decision integrity in H1B1. Only H1B2 may expose authorized read, preview, and confirmation.

Every new physical name, function name, capability, event, error, role, and constraint in this document is **proposed for review** unless explicitly identified as an already approved baseline. Nothing here modifies the canonical PA-06A 18-function registry.

## 2. OPS_SYSTEM_MAP placement

| Layer               | PA-06E-H0 placement                                                                                                                                                                                             |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Mission             | Preserve explainable school-catering need from controlled inputs through a Draft Planning review boundary.                                                                                                      |
| Business capability | Persist governed inputs and atomic calculation output; materialize grouped operational requirements with exact contribution membership for Planning review.                                                     |
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

### 3.3 Active OPS v1 operational-grain evidence

The retained active Purchase Planner path was reread from `OPS-v1-retool-app.zip`, and its matching `public` schema/function definitions were reread from the retained-schema-equivalent `schema.sql`. The active controller invokes `q_ppwb_save_actual_need`, not the duplicate master-save query. The exact active family is:

```text
Purchase Planner family_token
= service_date | school_id | ingredient_id

public.actual_need_overrides primary/conflict key
= (service_date, school_id, ingredient_id)

public.purchase_assignments master grouping
= (service_date, school_id, ingredient_id)
```

The active master query constructs that `family_token`, joins `actual_need_overrides` on those three columns, and groups supplier assignments on those same columns. `public.app_upsert_actual_need_overrides_bulk` canonicalizes and upserts one exact operator-entered value with `ON CONFLICT (service_date, school_id, ingredient_id)` before downstream rebalance.

This is evidence that the operational confirmation family is an ingredient requirement total for a school and service date. It is **not** a schema to copy blindly: Atlas must additionally retain typed destination, unit, approved operational scope, immutable revisions, policy binding, source membership, authorization, and audit. The evidence does not approve legacy rounding, hidden rebalance, destructive replacement, public-schema access, or Retool as an authority.

## 4. Prerequisite inventory and dependency matrix

The classification values in this table are the exact Issue #115 categories. “Required in H0” means part of the future H0 program, not implemented by this documentation task.

| Dependency                                                         | Current evidence                                                         | Classification                                                      | Bounded owner/sequence                                                  | H1 consequence                                                                                 |
| ------------------------------------------------------------------ | ------------------------------------------------------------------------ | ------------------------------------------------------------------- | ----------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| Actor, capability, scope, receipt, event, and audit infrastructure | Merged and exercised by PA-04 through PA-05G                             | already merged and reusable                                         | Reuse; extend only through a separately approved security migration     | H1 reuses the same envelope and safe-error model.                                              |
| Ingredient and Unit references                                     | Merged; wholesale-compatible                                             | already merged and reusable                                         | Reuse after active/reference validation                                 | H1 binds exact active unit and policy.                                                         |
| Confirmed Need roots, stable lines, revisions, approval snapshots  | Merged; source FKs are wholesale-only                                    | already merged and reusable                                         | H0B1 generalizes; it does not replace the aggregate                     | H1 operates only after H0B1/H0C.                                                               |
| Admin school/customer/location references                          | H0A1 typed School/customer/location and relational scope merged          | required before H0 implementation but owned by another bounded task | H0A1 — merged reference foundation                                      | H1 reuses the approved typed ownership and relational scope.                                    |
| Recipe/BOM version references                                      | H0A2 immutable Recipe/BOM reference foundation merged                    | required before H0 implementation but owned by another bounded task | H0A2 — merged immutable reference foundation                            | H1 source explanation uses exact stable and revision IDs.                                      |
| Weekly Menu persistence                                            | H0A3a stable root and exact immutable approval snapshots merged          | required before H0 implementation but owned by another bounded task | H0A3a — merged Weekly Menu persistence                                  | Need Generation can bind exact approved Menu evidence.                                         |
| Attendance persistence                                             | H0A3b stable root and exact immutable approval snapshots merged          | required before H0 implementation but owned by another bounded task | H0A3b — merged Attendance persistence                                   | Need Generation can bind exact approved portion evidence.                                      |
| Planning Input Set/readiness persistence                           | H0A4a decision and H0A4b private persistence merged                      | required before H0 implementation but owned by another bounded task | H0A4a decision and merged H0A4b persistence                             | Generation must fail closed without the exact current immutable evaluation and typed snapshots. |
| Need Generation run and theoretical-line persistence               | H0A5a run, calculation, lifecycle, issue, and release decisions accepted | required in H0                                                      | H0A5a accepted decision; H0A5b persistence separately authorized       | H1 cannot use a fake or mutable calculation row.                                               |
| Theoretical-line typed source lineage                              | H0A5a direct typed anchors and bounded typed run-use relations accepted  | required in H0                                                      | H0A5a accepted decision; H0A5b persistence separately authorized       | H1 reads exact authoritative upstream trace.                                                   |
| Stable source-contribution identity                                | H0A5a atomic anchor tuple and one-to-one predecessor rules accepted      | required in H0                                                      | H0A5a accepted decision; H0A5b persistence separately authorized       | H1 corrections cannot match by ingredient/name/order.                                          |
| Operational Confirmed Need identity                                | Active OPS v1 evidence is school/date/ingredient; Atlas design unsettled | required in H0                                                      | H0B1 — typed operational tuple after product approval                   | H1 must review one operational requirement, not one source contribution.                       |
| Revision contribution membership                                   | No physical membership snapshot                                          | required in H0                                                      | H0B1 — immutable typed revision contribution bridge                     | H1 explains every atomic source contributing to the reviewed total.                            |
| Confirmed Need source generalization                               | Three required wholesale FKs                                             | required in H0                                                      | H0B1 — source generalization and enforceable membership constraints     | H1 fixture must use `NEED_GENERATION`, never fake wholesale.                                   |
| Line decision evidence                                             | Logical adjustment only; no complete physical child                      | required only for H1                                                | H1B1 — append-only decision child, mandatory policy FK, current pointer | H1B2 confirmation writes explicit changed or unchanged evidence.                               |
| Planning quantity-policy reference                                 | No production root/revision                                              | required only for H1                                                | H1A — policy root/revision before read/preview/confirm                  | H1 preview and commit fail closed when missing or ambiguous.                                   |
| Materialization command                                            | No school-catering command                                               | required in H0                                                      | H0C — `create_confirmed_needs_from_generation`                          | H1 normally consumes its output; local fixtures may provision the same generalized shape only. |
| Authorized review/readback                                         | No school-catering read                                                  | required only for H1                                                | H1B2 — one exact batch/readback surface                                 | Must expose no private relation.                                                               |
| Backend preview and Planning confirmation                          | No school-catering commands                                              | required only for H1                                                | H1B2 — preview and confirm after H1A/H1B1                               | Must bind policy/source/version and write line decision evidence.                              |
| Complete-batch validation, approval, release                       | Parent lifecycle approved; generic physical commands absent              | later production concern                                            | Later bounded tasks                                                     | H1 does not validate, approve, or release.                                                     |
| School-catering CMD-03 integration                                 | Current CMD-03 is `PA-05D.v1` wholesale-only                             | later production concern                                            | Later contract and migration                                            | H1 cannot create Purchase Handoff.                                                             |
| Removal release policy, split/merge policy, downstream correction  | Unresolved in PA-06E                                                     | later production concern                                            | Separate product/architecture decisions                                 | H0C fails closed; H1 cannot bypass.                                                            |

## 5. Bounded implementation sequence

One migration must not introduce every missing school-catering domain. The proposed sequence is:

```text
H0A1 — Admin school/customer/location reference foundation
H0A2 — Recipe/BOM immutable reference foundation
H0A3a — Weekly Menu persistence and approval snapshots
H0A3b — Attendance persistence and approval snapshots
H0A4a — Planning Input Set/readiness decision closure
H0A4b — Planning Input Set/readiness persistence
H0A5a — Need Generation run, calculation, lifecycle, issue, release, and lineage decision closure
H0A5b — Need Generation private persistence and database invariants
  ↓
H0B1 — operational Confirmed Need identity, source generalization, and revision contribution membership
  ↓
H0C — create_confirmed_needs_from_generation materialization command
  ↓
H1A — versioned Planning quantity-policy root/revision
  ↓
H1B1 — line decision-evidence table, mandatory policy FK, and current-decision integrity
  ↓
H1B2 — authorized read, preview, and confirmation for one synthetic operational line
  ↓
Later — validation, approval, release, school-catering CMD-03, downstream correction
```

The H0A labels are a decomposition contract, not blanket authorization for issues or migrations. H0A1 and H0A2 belong to different business owners and must remain separately reviewable. Weekly Menu and Attendance also retain independent lifecycles and approval snapshots. H0A4a closes the readiness design in [Decision PA-06E-H0A4](../decisions/decision-pa-06e-h0a4-planning-input-readiness.md), and H0A4b has merged its exact private persistence. H0A5a closes the Need Generation design in [Decision PA-06E-H0A5](../decisions/decision-pa-06e-h0a5-need-generation-lineage.md); a separately authorized H0A5b must implement it. Need Generation consumes the exact current immutable evaluation and its typed snapshot bindings but does not edit them. H0B1 intentionally creates no decision table or insert path; decision persistence follows the policy in H1B1 so a decision can never exist without an exact policy revision.

## 6. Calculation grain versus Planning confirmation grain

### 6.1 Alternative A — contribution-grain Confirmed Need

```text
one Confirmed Need line
= one atomic Theoretical Need contribution
```

This was the initial H0 proposal. It preserves simple one-to-one lineage, but it does not match the retained active Purchase Planner family. When several RecipeLine/BOMLine contributions produce the same school/date/ingredient requirement, an operator confirms one operational total. Alternative A would therefore require an authoritative distribution or rebalancing rule that allocates the confirmed total back across contribution lines.

No such Planning distribution, residual, priority, or rebalancing rule is approved. Retool's downstream supplier rebalance is Procurement evidence and cannot authorize a Planning allocation rule. Alternative A is rejected for school-catering Confirmed Need.

### 6.2 Alternative B — operational requirement-grain Confirmed Need

```text
one Confirmed Need stable line
= service date
+ school/destination
+ ingredient
+ controlled unit
+ approved operational scope
```

One immutable line revision records the exact total theoretical quantity derived from a complete immutable set of atomic Theoretical Need contributions. Planning makes one decision on that operational total. The active OPS v1 key supports the service-date/school/ingredient intent; destination, controlled unit, and any additional typed scope remain Atlas requirements rather than copied legacy fields.

### 6.3 Selected direction and approval gate

**Select Alternative B as the proposed school-catering physical direction, subject to explicit product-owner approval of the exact operational identity.** No new aggregate is introduced; this is the stable-line grain inside the existing Confirmed Need aggregate.

H0B1 is blocked until H0A1/H0A5 and product review settle the exact typed identity fields. At minimum, changing service date, school, destination, ingredient, or controlled unit creates or selects a different stable line. Any later approved scope dimension has the same identity effect. Stable identity is never a name, display order, client token, JSON object, or hash.

Atomic Theoretical Need lines remain the calculation grain. Grouping them for confirmation does not merge or erase their source identities:

```text
Atomic Theoretical Need lines
→ immutable contribution-membership snapshot
→ one operational Confirmed Need line revision
→ one Planning decision
```

## 7. Source-membership alternatives

### 7.1 Model A — revision contribution-membership snapshot

Add one private revision-owned typed bridge:

```text
ConfirmedNeedLineRevision
→ ConfirmedNeedLineRevisionContribution[]
→ exact released TheoreticalNeedLine
→ exact source quantity/unit and exact controlled-unit contribution
```

The bridge stores no Menu, Attendance, Recipe, or BOM payload. Those facts remain reachable through the Theoretical Need line's direct typed source anchors and bounded typed run-use relations. The revision snapshot stores only the exact membership and normalized contribution facts necessary to reproduce the reviewed total.

### 7.2 Model B — released generation requirement group

Need Generation could create an immutable grouped operational result with atomic contribution children, and Confirmed Need could reference that result.

This makes grouping relationally explicit upstream, but it makes Need Generation own a Planning confirmation grouping and introduces another grouped object/lifecycle before evidence proves it is reused outside Confirmed Need. It also duplicates the revision snapshot needed to preserve what Planning actually reviewed. Model B is not smaller for the current boundary.

### 7.3 Model C — another typed relational design

A separate source-reference root plus typed wholesale and school-catering children remains possible, but it adds a current child-family protocol without improving membership ownership or total enforcement. Free-text polymorphism, caller-authored object names, generic source registries, and unvalidated JSON remain prohibited.

### 7.4 Selected model

**Select Model A, subject to H0B1 migration review.** It keeps atomic trace, supports many contributions per operational line, makes each revision's complete membership immutable, and leaves direct-wholesale source columns and behavior intact.

The corrected typed mapping is:

| Owner                        | Wholesale path                               | School-catering path                                                               |
| ---------------------------- | -------------------------------------------- | ---------------------------------------------------------------------------------- |
| Confirmed Need batch         | exact existing Wholesale Order               | immutable origin Need Generation run plus controlled current released-run snapshot |
| Stable Confirmed Need line   | exact existing Wholesale Order line          | immutable typed operational identity; no singular origin Theoretical Need line     |
| Confirmed Need line revision | exact existing Wholesale Order line revision | exact released run/snapshot plus one immutable contribution-membership set         |
| Revision contribution        | prohibited for Wholesale                     | exact released Theoretical Need line and controlled-unit contribution              |

The logical `ConfirmedNeedSourceReference` is implemented for school catering by the batch's typed released-run identity plus the revision-owned membership set. Direct-wholesale remains singular and does not manufacture membership rows.

## 8. Operational identity and source-correction behavior

### 8.1 Atomic contribution identity

H0A5 still persists one immutable Theoretical Need line per atomic contribution. Ordinary one-to-one correction uses `predecessor_theoretical_need_line_id` and stable typed anchors such as Weekly Menu line, Attendance line, and RecipeLine/BOMLine. Ingredient, name, display order, array position, generated order, and broad school/date/ingredient coincidence are never contribution identity.

The predecessor chain explains contribution continuity; it no longer defines Confirmed Need stable-line identity. Multiple independent contribution chains may be members of the same operational line revision.

### 8.2 Required correction behavior

| Correction                                                        | Contribution result                                                               | Operational Confirmed Need result                                                                                                                                                                                                                  |
| ----------------------------------------------------------------- | --------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Quantity correction on one RecipeLine/BOMLine                     | Create an immutable successor contribution with the explicit predecessor.         | Recompute the same operational group; create one successor revision and a complete new membership snapshot.                                                                                                                                        |
| New contribution for the same operational ingredient              | Create a new atomic line with no predecessor and unique typed anchors.            | Add it to the same operational line's new membership; create one successor revision.                                                                                                                                                               |
| Removed contribution                                              | Persist an explicit predecessor-linked `REMOVED` result; absence is insufficient. | The proposed next membership excludes it and the total changes, but H0C rejects until zero/removal policy is approved. Prior membership remains immutable.                                                                                         |
| Ingredient correction on the same RecipeLine/BOMLine              | Create a predecessor-linked contribution with the new ingredient.                 | Remove the contribution from the old ingredient group and add it to the new group. Create affected successor revisions; never mutate a stable line's ingredient identity. If the old group becomes empty/zero, fail closed pending removal policy. |
| New ingredient requirement                                        | Create a new atomic contribution with no predecessor.                             | Create a new stable operational line unless an exact same-identity line already exists in the batch.                                                                                                                                               |
| Service date, school, destination, unit, or approved scope change | Preserve the source predecessor trace where factually valid.                      | The contribution leaves the old operational identity and enters a different stable line; the old line is never repurposed.                                                                                                                         |
| Split or merge                                                    | Use an explicit typed mapping only after policy exists.                           | H0C rejects the whole command while mapping/approval policy is missing; no inference or partial materialization.                                                                                                                                   |

H0 never distributes an operator-confirmed total back into contributions. Contributions explain the system-calculated theoretical total; the Planning decision belongs to the operational line revision.

### 8.3 Revision-owned membership shape

The proposed private `confirmed_need_line_revision_contributions` bridge carries at least:

- bridge ID, Confirmed Need batch, stable line, and exact line revision;
- exact Need Generation run/version and immutable release-snapshot identity;
- exact Theoretical Need line;
- exact source contribution quantity and source unit;
- exact normalized contribution quantity in the operational line's controlled unit;
- exact conversion-rule revision when source and controlled units differ;
- service date, typed school/destination, ingredient, controlled unit, and every approved operational-scope identity needed by composite FKs; and
- originating materialization command and creation time.

Membership is nonempty for every school-catering revision, unique by `(confirmed_need_line_revision_id, theoretical_need_line_id)`, immutable after insertion, and protected by `on delete restrict`. Display order is not authoritative membership.

### 8.4 Selected database-enforcement strategy

Command validation alone is insufficient. The selected direction deliberately combines generated/denormalized parent identities, composite unique keys and composite foreign keys, partial unique indexes, and mandatory deferred constraint triggers.

Database-declarative enforcement must include:

1. Row checks enforce exactly one batch source: Wholesale Order or Need Generation origin/current release; exactly one revision source family; and no school-catering membership on a Wholesale revision.
2. A composite unique key on the exact typed operational identity prevents two stable school-catering lines for the same batch/date/school/destination/ingredient/unit/approved scope. Identity columns are immutable.
3. Composite FKs bind every revision to its batch/stable line/source kind and its own exact released-run snapshot, and bind every membership row to that exact revision tuple. The current-source trigger additionally requires the stable line's current revision to use the batch's controlled current released-run snapshot.
4. Composite FKs bind every membership row to one line in the exact immutable Need Generation release snapshot and to the same typed service/date/destination/ingredient/controlled-unit scope. Cross-unit membership also requires the exact conversion-rule revision.
5. The existing partial unique current-revision rule remains database-enforced for every stable line.
6. Existing Wholesale Order/line/revision FKs, source-specific uniqueness, and `PA-05D.v1` tests remain unchanged; Wholesale revisions cannot have contribution-membership rows.

The following constraint triggers are mandatory future H0B1/H1B1 design elements, not optional possibilities:

| Proposed constraint trigger                   | Exact invariant                                                                                                                                                                                                                                                                                                                                                            | Affected tables                                                                                                                                  | Timing                                                                                                                           | Lock assumptions and failure behavior                                                                                                                                                                                                   | Required pgTAP proof                                                                                                                                                                                                                         |
| --------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `confirmed_need_current_source_consistency`   | Batch and stable-line source kinds agree; immutable origin is retained; the controlled current release is a valid same-scope successor in the origin correction chain; the current line revision uses that exact current release; historical revisions retain their own exact releases; Wholesale rows retain the exact Wholesale Order chain and have no membership rows. | Confirmed Need batches, stable lines, line revisions, revision contributions, Need Generation runs/release snapshots                             | `DEFERRABLE INITIALLY DEFERRED`; checked at transaction end after a complete initial/correction write                            | Owning command locks batch, stable lines, and current revisions in deterministic ID order. Failure aborts the whole transaction and is translated to a safe lineage-conflict error; no partial row is visible.                          | Reject mixed kinds, unrelated origin/current runs, current-revision/run mismatch, wrong scope, Wholesale cross-wire, and Wholesale membership; preserve a valid historical revision/release and accept one atomic current-source transition. |
| `confirmed_need_revision_membership_total`    | Every school-catering revision owns one nonempty immutable membership set; every member belongs to its exact released snapshot and operational identity; `theoretical_quantity` equals the exact sum of normalized contributions in the controlled unit.                                                                                                                   | Confirmed Need line revisions, revision contributions, Need Generation release snapshot lines, Theoretical Need lines, conversion-rule revisions | `DEFERRABLE INITIALLY DEFERRED`; fires for revision or membership insert/update/delete and validates the final transaction state | Command locks the revision and referenced theoretical/release rows before inserts. Equality uses exact PostgreSQL `numeric`, never epsilon. Any missing, extra, duplicate, wrong-unit, stale, or unequal member rolls back the command. | Prove one/many members, duplicate rejection, wrong run/scope/unit/conversion rejection, missing member, extra member, update/delete immutability, and exact sum mismatch including fractional values.                                        |
| `confirmed_need_current_decision_consistency` | A non-null current decision belongs to the same stable line and exact current revision and references one existing effective Planning policy revision; no decision can point to a superseded revision.                                                                                                                                                                     | Confirmed Need stable lines, line revisions, line decisions, Planning policy revisions                                                           | Created only by H1B1 as `DEFERRABLE INITIALLY DEFERRED`; checked after successor revision/decision/pointer changes               | Confirmation locks batch, stable line, current revision, policy, and decision chain in that order. Failure aborts revision, decision, pointer, receipt, event, and audit together.                                                      | Reject cross-line/cross-revision pointers, missing/stale policy, superseded-current target, forked evidence correction, and any decision row without the mandatory policy FK.                                                                |

H0C revalidates the applicable H0B1 source/membership conditions under the same locks to return domain-safe errors before constraint failure where possible. H1B2 later revalidates the H1B1 decision/policy condition. These command checks are defense in depth; they are not the integrity boundary.

## 9. Schema-delta catalog without executable DDL

This catalog states physical intent only. It is not migration syntax.

| Object/change                                       | Proposed shape                                                                                                                                                                                 | Constraint/index direction                                                                                  | Status                                                                 |
| --------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| `atlas_admin.schools`                               | Stable school identity linked to the approved customer and delivery-location model                                                                                                             | Typed FKs, active state, no delete when referenced                                                          | **Merged by H0A1**.                                                    |
| Existing customer/location generalization           | Approved school-catering ownership without weakening wholesale relationships                                                                                                                   | Preserves wholesale rows and exact same-customer location ownership                                        | **Merged by H0A1**.                                                    |
| Recipe/BOM physical family                          | Dish, scoped Recipe, immutable Recipe Version, stable RecipeLine, immutable line revision                                                                                                      | Stable line identity; exact revision FKs; no released-row overwrite                                         | **Merged by H0A2**.                                                    |
| Weekly Menu physical family                         | Stable seven-day root, stable lines, approval snapshot, snapshot lines                                                                                                                          | Exact School/date/slot/Dish and approved version ownership                                                  | **Merged by H0A3a**.                                                   |
| Attendance physical family                          | Stable arbitrary inclusive-period root, stable School/date lines, approval snapshot, snapshot lines                                                                                            | Exact School/date portion facts and approved version ownership                                             | **Merged by H0A3b**.                                                   |
| Planning Input Set/readiness                        | One stable exact-period root, positive immutable evaluation versions, two direct typed approval-snapshot bindings, immutable evaluation issues                                                | Unique exact inclusive period; at most one snapshot per source type; exact snapshot/root/version ownership; source periods contain evaluated period | **H0A4a design accepted; H0A4b persistence merged**.                   |
| `need_generation_runs`                              | One accepted attempt for one exact Planning Input Set/current evaluation; local attempt ordinal, predecessor, four-state lifecycle, optimistic version                                         | One linear same-input-set chain; no fork/cycle/cross-period predecessor; released terminal immutable        | **H0A5a selected; H0A5b persistence pending separate authorization**.  |
| `need_generation_input_snapshots`                   | One immutable run header with exact input-set/evaluation and Menu/Attendance triples, plus bounded typed Recipe selection/use relations and one fixed calculation-contract revision             | Exact H0A4b ownership; no generic registry or lineage JSON; complete immutable evidence                     | **H0A5a selected; H0A5b persistence pending separate authorization**.  |
| Need Generation calculation contract                | Stable contract root and immutable positive revision for the fixed proportional Recipe formula and numeric semantics                                                                           | Formula identity and parameters are revisioned; no generic formula engine                                   | **H0A5a selected; H0A5b persistence pending separate authorization**.  |
| `theoretical_need_lines`                            | One immutable atomic Menu × Attendance × RecipeLine contribution with direct typed source anchors, source Unit, disposition, and optional predecessor                                           | Anchor uniqueness per run; at most one same-input-set successor; `ACTIVE >= 0`; `REMOVED = 0`               | **H0A5a selected; H0A5b persistence pending separate authorization**.  |
| Need Generation issues                              | Immutable coded run evidence from the closed H0A5a catalog with typed context where applicable                                                                                                 | Append-only; blockers prevent validation/release; invalid evidence requires a successor run                 | **H0A5a selected; H0A5b persistence pending separate authorization**.  |
| Need Generation release snapshot/lines/issues       | Immutable release header and exact line and issue membership for one exact released run/version                                                                                                | Complete one-run membership; no later row can enter the released boundary                                  | **H0A5a selected; H0A5b persistence pending separate authorization**.  |
| `confirmed_need_batches` generalization             | Add source kind, immutable origin run, and controlled current released-run snapshot; retain Wholesale FK                                                                                       | Exactly one typed source family; origin immutable; current snapshot belongs to its correction chain         | **Selected proposal; pending H0B1 migration approval**.                |
| `confirmed_need_lines` generalization               | Retain Wholesale line FK; for school catering add immutable typed operational identity fields, not one origin theoretical line                                                                 | Composite operational identity unique per batch; source kind consistent; no current-decision pointer yet    | **Selected proposal; product identity approval required before H0B1**. |
| `confirmed_need_line_revisions` generalization      | Retain Wholesale revision FK; school-catering revision binds its exact released snapshot and owns one membership set; the current revision agrees with the batch's controlled current snapshot | Unique revision number; one current; composite ownership/source keys; immutable payload                     | **Selected proposal; pending H0B1 migration approval**.                |
| `confirmed_need_line_revision_contributions`        | Revision-owned typed membership over exact released Theoretical Need lines, quantities, units, normalization rule, and operational identity                                                    | Nonempty/unique/immutable; composite FKs; mandatory deferred exact-total trigger                            | **Selected Model A; pending H0B1 migration approval**.                 |
| Planning policy root/revisions                      | Stable policy scope plus immutable effective revision, unit, positive step, owner/effective period                                                                                             | No overlapping eligible revision in same governed scope; no fallback                                        | **Required H1A; exact scope/precedence pending**.                      |
| `confirmed_need_line_decisions` and current pointer | Append-only line decision evidence described in section 10; pointer added only with the mandatory policy FK                                                                                    | NOT NULL policy FK, unique decision/command rules, mandatory deferred current-decision trigger              | **Required H1B1 after H1A; no H0 insert surface**.                     |

## 10. H1B1 line decision-evidence physical design

H0B1 and H0C create no decision table, current-decision pointer, or decision insert privilege. H1A first creates the policy root/revisions. H1B1 then creates the following decision structure with a mandatory, non-null policy-revision FK before H1B2 exposes any read/preview/confirm function.

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
- exact Need Generation released run/snapshot and exact current revision contribution-membership set;
- exact Planning policy revision;
- batch version before and after;
- reason code and conditional reason note;
- deciding actor and decision time;
- command receipt, command, correlation, and source interface; and
- optional superseded decision ID for an evidence correction.

The decision child is evidence, not an aggregate. The Confirmed Need batch version remains the concurrency boundary.

### 10.3 Current and unique decision rules

H1B1 adds a nullable current-decision pointer to the stable Confirmed Need line in the same bounded migration as the decision child and mandatory policy FK.

- Existing materialized rows receive a null pointer because materialization created no Planning decision.
- H1B2 confirmation appends a decision row and moves the pointer atomically.
- The pointer must reference a decision for the same stable line and its current line revision.
- Decision numbers are positive and unique within the line.
- One command may decide several lines, but `(command_id, confirmed_need_line_id)` is unique.
- A superseding evidence correction must point to the prior current decision; one prior decision cannot fork into two successors.
- Decision rows are never updated or deleted. A correction appends a full replacement evidence row, advances the pointer, and retains the prior row.
- Moving the pointer and any permitted prior-revision `is_current`/status metadata happens only inside the owning command while the batch is locked.

Composite keys/FKs establish local line/revision ownership, and the mandatory deferred `confirmed_need_current_decision_consistency` trigger in section 8.4 proves that the pointer targets the same line's exact current revision and one existing policy revision at transaction end.

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

Every school-catering decision binds the exact current immutable contribution-membership set and exact policy revision. A Draft materialization revision has no decision or policy binding because it is not authoritative. The decision is invalid if any member, release snapshot, line revision, batch version, policy, or scope changes before commit.

This avoids mutating a materialized Draft merely to add a later policy reference. For adjusted confirmation, the successor revision and the decision are created together; for unchanged acceptance, the decision supplies the missing authority and policy binding without quantity duplication.

### 10.6 Logical `ConfirmedNeedAdjustment` read

The existing logical adjustment history is derived from decision rows where `decision_kind = ADJUSTED_QUANTITY_CONFIRMED`. It projects actor/time, reason, before/after quantity, unit, exact revision, source, policy, and command. Unchanged decisions remain visible in the broader line-decision history but do not appear as quantity adjustments.

## 11. Planning quantity-policy dependency

### 11.1 H0/H1 decision

**Selected proposal:** H0 does not create a minimum production Planning policy. H1A creates the versioned, fail-closed policy before H1B1 can create decision persistence and its mandatory policy FK.

H0C copies exact theoretical quantity into the existing `confirmed_quantity` storage field as a clearly non-authoritative Draft proposal. It performs no Planning step quantization, rounding, trimming, or confirmation. Authority is derived from explicit line decision evidence, not from the presence of a numeric value.

No decision row can exist before H1A/H1B1 because H0 has no decision table, H1B1 requires a non-null typed FK to an H1A policy revision, and API/runtime roles receive no decision-table insert privilege. H1B2 preview and commit must refuse to operate until one exact effective Planning policy revision resolves. This keeps fixture values such as `0.01 kg` test-only and prevents an H0 migration from approving production operations policy accidentally.

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
- every released atomic theoretical line, release-snapshot membership, direct typed source anchor, and bounded typed run-use relation;
- every predecessor, explicit removal, and typed mapping needed to prove the complete source-contribution set;
- active ingredients and units;
- every exact conversion rule required to express a contribution in its controlled operational unit;
- the product-approved operational identity definition and deterministic server-side grouping result;
- the target Confirmed Need batch, stable lines, current revisions, and current released-run pointer where correcting; and
- absence of an incompatible batch/materialization for the same origin.

Any missing, stale, ambiguous, cross-scope, split/merge, implicit removal, or fake source fails the complete command.

### 12.4 Initial materialization

For a run with no prior Confirmed Need batch:

1. Consume one exact immutable `RELEASED_FOR_CONFIRMATION` run/version and its complete released-line snapshot.
2. Group all active atomic contributions by the exact product-approved operational identity: service date, typed school/destination, ingredient, controlled unit, and every approved scope field.
3. Create one `NEED_GENERATION` Confirmed Need batch in `DRAFT_REVIEW`, version 1, whose immutable origin and current source are the exact released run/snapshot.
4. Create one stable Confirmed Need line per operational group. Its identity fields are immutable and contain no singular origin Theoretical Need line.
5. Create revision 1 in `DRAFT`, current, with the exact group identity and theoretical total.
6. Create the revision's complete immutable contribution-membership snapshot. Every member references an exact released Theoretical Need line and exact controlled-unit contribution.
7. Require the revision theoretical quantity to equal the exact PostgreSQL `numeric` sum of those controlled-unit contributions through the deferred database constraint.
8. Set the stored candidate confirmed quantity equal to the exact theoretical total without Planning quantization; authorized reads must label it proposed because no decision exists.
9. Create no decision table row, policy fact, approval snapshot, release, Purchase Handoff, Procurement, or Dispatch fact.
10. Append exactly one completed receipt, `ConfirmedNeedsCreated` domain event, and matching audit event atomically.

### 12.5 Corrected materialization

For an exact existing batch in `DRAFT_REVIEW` or explicitly `REOPENED`:

1. Verify the new released run is the allowed corrected successor of the batch's controlled current released run and resolve its complete contribution set.
2. Validate every ordinary contribution predecessor, genuinely new contribution, explicit removal, ingredient move, and any typed split/merge mapping before writing.
3. Regroup the complete new contribution set by the approved operational identity and compare the full group set with current stable operational lines.
4. Reuse a stable line only when the full operational identity is unchanged. Contribution predecessor ancestry explains membership changes but never permits the stable line's date, school, destination, ingredient, unit, or other approved identity field to mutate.
5. Create one successor Draft revision and complete new immutable membership snapshot for every affected existing operational group, including source-only or membership-only changes with an unchanged total.
6. Preserve every prior revision and membership payload; mark only controlled current/status metadata noncurrent/superseded.
7. H1B1/H1B2 decision evidence, when it later exists, remains historical. The new revision has no current decision; its stable-line current-decision pointer is cleared atomically by the H1B1 integrity protocol.
8. Create new stable operational lines and revision 1 for new operational identities, including a new ingredient requirement or the destination line of an ingredient correction when absent.
9. Handle an ingredient correction as an explicit contribution move from the old ingredient group's new membership to the new ingredient group's new membership. Never mutate the old stable line's ingredient.
10. Set each new proposal equal to its exact recomputed theoretical total. Do not carry a prior confirmed value automatically; that product choice remains pending.
11. Reject unresolved zero/empty-group, removal, split, merge, incomplete, duplicate-predecessor, ambiguous conversion, and mixed-scope cases with no partial write.
12. Move the batch's controlled current released-run pointer, increment the batch version exactly once, and make all revisions/memberships/current metadata visible atomically.
13. Append exactly one completed receipt, proposed `ConfirmedNeedsRematerialized` domain event, and matching audit event atomically.

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
affected_aggregate_ids.created_revision_contribution_ids[]
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

Exact source IDs are the immutable membership rows and their referenced Theoretical Need lines. A bounded response may return per-revision membership counts and IDs, but it never accepts or echoes caller-authored membership, grouping, quantities, or lineage as authority.

### 12.7 Safe errors and write certainty

| Proposed error                       | Meaning and write behavior                                                                  |
| ------------------------------------ | ------------------------------------------------------------------------------------------- |
| `VALIDATION_FAILED`                  | Malformed/unknown fields or invalid creation sentinel; no domain write.                     |
| `GENERATION_NOT_RELEASED`            | Run is not exactly released for confirmation; no domain write.                              |
| `SOURCE_LINEAGE_INCOMPLETE`          | Required typed input/source/revision is missing; no domain write.                           |
| `SOURCE_REVISION_STALE`              | Run, input snapshot, source revision, or target source changed; no domain write.            |
| `SOURCE_MAPPING_INCOMPLETE`          | A prior active contribution has no explicit successor/tombstone; no domain write.           |
| `SOURCE_SUCCESSOR_AMBIGUOUS`         | Duplicate or cross-wired predecessor; no domain write.                                      |
| `OPERATIONAL_IDENTITY_UNAPPROVED`    | Exact typed grouping identity is not approved/resolvable; no domain write.                  |
| `CONTRIBUTION_MEMBERSHIP_INVALID`    | Membership is empty, duplicate, wrong-run, cross-scope, or wrong-unit; no domain write.     |
| `CONTRIBUTION_TOTAL_MISMATCH`        | Exact normalized contribution sum differs from revision theoretical total; no domain write. |
| `SOURCE_REMOVAL_POLICY_REQUIRED`     | Explicit removal is present but release behavior is unapproved; no domain write.            |
| `SOURCE_SPLIT_MERGE_POLICY_REQUIRED` | Split/merge cannot be represented by the approved one-to-one chain; no domain write.        |
| `REOPEN_REQUIRED`                    | Approved/released batch must be explicitly reopened; no domain write.                       |
| `DOWNSTREAM_CORRECTION_REQUIRED`     | Existing Handoff or later commitment prevents silent correction; no domain write.           |
| `STALE_VERSION`                      | Expected run/batch version differs; no domain write and no blind retry.                     |
| `CAPABILITY_DENIED` / `SCOPE_DENIED` | Server-owned authorization fails; no domain write and no selector broadening.               |
| `IDEMPOTENCY_CONFLICT`               | Same command/key with different canonical intent; no new write.                             |
| `RETRYABLE_CONCURRENCY_FAILURE`      | Whole transaction rolled back; retry only the exact frozen request.                         |
| `INTERNAL_COMMAND_FAILURE`           | No success may be inferred; reconcile by command ID before retry.                           |

Exact error names are proposed and noncanonical. They must be reconciled with the established safe envelope before implementation.

### 12.8 Idempotency and concurrency

- The scoped idempotency key and canonical request hash are mandatory.
- Exact replay returns the original batch/line/revision/event/audit IDs and creates nothing new.
- Changed reuse returns `IDEMPOTENCY_CONFLICT`.
- A deterministic failure after receipt creation may retain a safe `FAILED_NON_RETRYABLE` receipt under the existing helper contract; it creates no domain or audit event.
- Two initial calls for the same run cannot create two batches.
- Two correction calls for the same batch/version cannot fork any current revision or membership chain.
- One successful correction increments the batch once.
- Serialization/deadlock handling retries or reports the complete transaction only; no partial line result becomes visible.

## 13. Compatibility and migration strategy

### 13.1 Additive-first migration plan

The preferred migration path is staged and forward-compatible:

1. Implement each approved H0A prerequisite in its own migration/task and test it independently.
2. H0B1 adds nullable source-kind, immutable origin/current released-run references, typed operational identity fields, revision ownership keys, and the private revision-contribution bridge. It adds no decision table or current-decision pointer.
3. Classify existing rows as `WHOLESALE` from their required typed FKs; inspect and prove counts in local/approved environments only.
4. Add and validate typed/composite FKs, source-kind checks, row-local exactly-one checks, operational-identity uniqueness, membership indexes, and the mandatory H0B1 deferred constraint triggers.
5. Update internal PA-05D inserts to write explicit `WHOLESALE` classification while preserving its public request, response, capability, events, quantities, and transitions.
6. Only after backfill and validation, remove `not null` from the three wholesale source columns so `NEED_GENERATION` rows can exist.
7. Implement H0C only after H0B1 operational identity, membership, composite constraints, triggers, and compatibility tests pass.
8. H1A separately creates Planning policy roots/revisions and their non-overlap/fail-closed constraints.
9. H1B1 then creates the append-only decision child, mandatory non-null policy FK, nullable stable-line current-decision pointer, and mandatory deferred current-decision trigger. It invents no decision backfill and grants no decision insert path.
10. H1B2 creates the first authorized read/preview/confirm functions and only then grants their exact execution/runtime privileges.

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
- one stable school-catering Confirmed Need line per exact typed operational identity within a batch;
- one line revision number/current revision per stable line and one immutable contribution set per school-catering revision;
- unique `(line_revision_id, theoretical_need_line_id)` membership and indexed membership ownership/released-source/scope composite FKs;
- indexed Need Generation run, release snapshot, predecessor, input snapshot, future conversion rule when approved, direct typed source anchor, and bounded typed run-use FK;
- one unique direct successor for an accepted one-to-one predecessor chain;
- H1B1 decision number uniqueness per line, command/line uniqueness, decision predecessor non-forking, mandatory policy FK, and current pointer integrity; and
- service-period/status indexes only for approved read/command paths.

No index may rely on ingredient name, display order, or an unvalidated source hash as authoritative identity.

### 13.4 Rollback and forward-fix

Before any school-catering row or H0C execution exists, an unshipped migration can be reverted through normal Git review. Once operational school-catering history exists, rollback must not drop generalized columns, source tables, theoretical lines, revision memberships, decisions, receipts, events, or audit evidence.

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
→ Planning Input Set, Need Generation run, and exact release snapshot
→ theoretical lines, predecessors, direct typed source anchors, and bounded typed run-use relations
→ target Confirmed Need batch
→ stable Confirmed Need lines in operational-identity order
→ current line revisions and any existing decision pointers
→ successor revisions and complete contribution memberships
→ controlled current/source metadata
→ one domain event and one audit event
```

The target IDs may be discovered before locking, but their state is not trusted until reread under locks. The command uses `read committed` plus the common parent-lock convention unless the implementation proves an unprotected predicate and separately justifies `serializable`.

### 14.5 Atomicity and safe outcomes

One success transaction includes every batch/line/revision/source classification change, every complete membership snapshot, exact totals, the batch version, the completed receipt, one event, and one audit event. Any invalid group or contribution rolls back all domain writes. External calls, file work, notifications, or client interaction never occur inside the transaction.

Safe errors disclose only public contract fields, current/expected version when authorized, opaque allowed references, write certainty, retryability, and recovery. SQL, table/policy/constraint names, stack traces, JWTs, credentials, and private source payloads remain server-only diagnostics.

## 15. Test blueprint

### 15.1 H0A source and generation persistence

- school/customer/location references satisfy the approved typed ownership model;
- approved Menu and Attendance snapshots are immutable and exact;
- one stable Planning Input Set exists per exact inclusive evaluated period and retains prior immutable evaluation versions;
- each evaluation has at most one direct typed Weekly Menu approval-snapshot binding and at most one direct typed Attendance approval-snapshot binding;
- each `READY` evaluation binds both exact snapshot/root/version families, and both source periods wholly contain the evaluated period;
- blocking and warning issues belong immutably to exactly one evaluation, and the closed lifecycle preserves the exact current evaluation across request/invalidation;
- a released Need Generation run binds exact input, Recipe/BOM, and fixed calculation-contract revisions; the source-unit H0A5b slice has no conversion revision;
- every theoretical line has the required direct typed source anchors and bounded typed run-use evidence;
- theoretical lines are atomic source contributions rather than ingredient-name aggregates;
- quantity and ingredient corrections on the same stable RecipeLine/BOMLine use an explicit predecessor;
- new contribution has no predecessor and receives unique stable anchors;
- explicit removal is a typed/tombstone result, never inferred from absence;
- split/merge remains blocked and explicit; and
- no source identity depends on ingredient name, display name, array order, generated order, or broad school/date/ingredient coincidence.

### 15.2 H0B1 constraints and compatibility

- every batch/revision satisfies exactly one of Wholesale or Need Generation and stable-line source kind agrees;
- the product-approved operational identity is unique and immutable within a batch;
- one atomic contribution is not silently materialized as one school-catering Confirmed Need line;
- each school-catering revision owns one nonempty immutable typed membership snapshot;
- membership rows bind exact released-run lines and the same operational identity through composite FKs;
- revision theoretical total equals the exact controlled-unit contribution sum through the mandatory deferred trigger;
- mixed source kinds, wrong run/snapshot, wrong line/revision ownership, wrong scope/unit/conversion, and cross-wired chains fail at the database boundary;
- a school-catering row cannot use a fake wholesale source;
- a wholesale row cannot use a Need Generation source;
- a Wholesale revision cannot own contribution-membership rows;
- existing wholesale fixtures retain exact `PA-05D.v1` behavior and equality;
- existing PA-05D payloads/responses/events/capabilities remain unchanged;
- theoretical predecessor ancestry remains atomic contribution trace rather than Confirmed Need stable-line identity;
- a stable line is never reused when date, school, destination, ingredient, unit, or approved scope changes;
- one current revision per stable line and valid direct revision predecessors;
- prior revision and membership payloads are immutable while controlled current/status metadata may supersede them; and
- direct constraint failures and command revalidation both roll back the whole transaction.

### 15.3 H0C materialization behavior

- only one exact `RELEASED_FOR_CONFIRMATION` run/version is consumed;
- initial materialization groups the complete released contribution set by approved operational identity;
- it creates one stable line/revision/membership per operational group, not per contribution;
- proposed quantity equals the exact contribution total without rounding and is not authoritative;
- materialization creates no line decision evidence, policy fact, approval snapshot, release, Handoff, Procurement, or Dispatch fact;
- quantity correction and a new same-ingredient contribution update the same operational group through one successor revision and complete new membership;
- ingredient correction moves membership between immutable old/new ingredient stable lines and never mutates stable-line identity;
- new operational identities create new stable lines;
- removed, zero/empty, missing, split, merge, duplicate-predecessor, ambiguous conversion, and mixed-scope cases reject atomically while policy is missing;
- prior revisions, memberships, decisions, approvals, releases, handoffs, POs, Dispatch facts, receipts, events, and audit remain unchanged;
- exact replay returns the same IDs and creates no duplicates;
- changed idempotency reuse conflicts;
- stale run, batch, line, source, and target state reject with no partial write;
- concurrent initial/correction calls create one safe chain; and
- one success creates exactly one completed receipt, one domain event, and one audit event.

### 15.4 H1B1 decision-evidence constraints

- H1A policy roots/revisions exist before the decision table migration;
- every decision has a non-null typed FK to one exact policy revision;
- no H0 function/runtime/API role can insert a decision;
- current decision belongs to the same stable line and exact current revision through composite ownership plus the mandatory deferred trigger;
- `UNCHANGED_PROPOSAL_ACCEPTED` requires no identical successor revision;
- `ADJUSTED_QUANTITY_CONFIRMED` binds exact before/after, actor/time, reason, membership set, policy, versions, and command;
- a superseded decision cannot fork and decision rows remain append-only; and
- adjusted decision rows derive the logical adjustment history exactly.

### 15.5 Authorization and security

- unauthenticated, mismatched subject, inactive actor, inactive membership, missing capability, wrong school/customer/location/date scope, and unsupported delegation fail closed;
- selector broadening and a global fallback are absent;
- `anon`, `authenticated`, and `service_role` retain no direct private relation privileges;
- `authenticated` can execute only explicitly approved signatures;
- materialization runtime is `NOLOGIN`, `NOINHERIT`, owns only approved functions, has no schema create/sequence mutation, and cannot write outside exact Planning/audit rows;
- PA-05D runtime remains bounded to its exact four entry functions;
- every definer has empty fixed `search_path`, fully qualified static SQL, and no public execute;
- forced RLS and revoke-first grants cover every new table; and
- future migration PRs pass Supabase/Postgres advisors and focused pgTAP security checks.

### 15.6 H1B2 gate tests

Before H1B2 begins, tests must prove:

- one genuine operational school/date/destination/ingredient/unit line exists without wholesale lineage and has one or more exact atomic contributions;
- one exact current generation release and immutable membership set exists;
- no Planning decision exists immediately after materialization;
- one effective versioned fixture policy exists only in rolled-back/local test data;
- missing or ambiguous policy fails closed;
- H1 has approved read/preview/confirm contracts and exact relational scope; and
- validation, approval, release, CMD-03, Procurement, PO, Dispatch, Retool, hosted Supabase, and production remain absent.

## 16. H1 gate

PA-06E-H1B2 is blocked until all of these are merged and verified:

1. H0A1 through H0A5 provide genuine typed school-catering sources, atomic theoretical contributions, and one immutable released generation result/snapshot.
2. Product review approves the exact operational Confirmed Need identity.
3. H0B1 provides operational stable lines, revision-owned typed contribution memberships, composite constraints, and mandatory deferred integrity triggers; it provides no decision table.
4. H0C materializes grouped Draft operational lines without a Planning decision.
5. H1A provides one exact effective versioned Planning policy and fail-closed resolution.
6. H1B1 provides append-only line decision evidence, a mandatory policy FK, current-decision pointer/integrity trigger, and no browser/API insert path.
7. H1B2 has approved read/preview/confirm contracts; only its implementation may introduce the first Planning-decision write path.
8. The school/customer/location/date authorization model is approved and tested.
9. API names, capabilities, owners, grants, request/response fields, safe errors, and events are approved for the bounded H1 slice.

A locally inserted synthetic line may replace execution of H0C only in H1 tests after the generalized H0 schema exists. It must use genuine H0 typed source rows and cannot use fake wholesale records.

## 17. Decision status and explicit pending decisions

The first four prerequisite decisions below are retained for provenance and marked with their merged owner. They are no longer open and must not be reopened by a later implementation agent. No implementation agent may guess the unresolved items or unresolved portions that follow.

### 17.1 Physical and ownership decisions

1. **Resolved by H0A1:** School is a typed child of Customer with same-customer default delivery-location ownership and relational `SCHOOL` scope.
2. **Resolved by H0A1:** `customer_type` permits the approved school-catering customer type without weakening wholesale ownership.
3. **Resolved by H0A2:** the exact Dish/Recipe/RecipeVersion/RecipeLine/RecipeLineRevision physical family and stable/revision identity are merged.
4. **Resolved by H0A3a/H0A3b:** exact Weekly Menu and Attendance roots, stable lines, approval snapshots, snapshot lines, and correction-history mechanics are merged.
5. **Resolved by H0A5a:** one generation run is one accepted attempt for one exact Planning Input Set/current evaluation and may include all Schools, dates, and locations contained by those exact typed snapshots.
6. **Resolved by H0A5a:** the first slice uses one fixed versioned calculation contract and preserves the RecipeLineRevision source Unit; no conversion-rule family or generic formula engine is introduced.
7. **Resolved by H0A5a:** a predecessor-linked `REMOVED` line has exact zero quantity and explicit H0A2 removed-revision evidence; silent omission of a prior active contribution blocks the successor.
8. Product-approved operational identity beyond the mandatory service-date/school/destination/ingredient/controlled-unit fields, including any program, meal, service-window, or organizational scope dimension.
9. Exact names and redundant column layout for release-snapshot, operational-identity, composite-FK, and contribution-membership keys. The composite/deferred enforcement direction itself is selected and is not optional.
10. Exact trigger function names, batching/performance limits, and safe error mapping. The three invariant classes and deferred timing in section 8.4 remain mandatory.
11. Exact H1B1 decision-current composite columns/indexes and evidence-correction reason rules within the selected mandatory policy/current-decision constraint direction.
12. Existing environment row counts and whether any non-wholesale data already violates the proposed classification; no production inspection is authorized here.

### 17.2 Product and policy decisions

13. Explicit product-owner approval of Alternative B and the final operational Confirmed Need identity.
14. Zero/empty-line and removed-contribution review, materialization, approval, and release behavior.
15. Split and merge mapping/approval behavior.
16. Whether a prior confirmed quantity may be offered as a corrected-run proposal; H0C defaults to the new exact theoretical total until approved otherwise.
17. Planning policy scope levels, precedence, owner, approver, effective-date semantics, and production step values.
18. Reason-code taxonomy, when a note is mandatory, and decision-evidence correction authority.
19. Separation of duties for materialization, confirmation, later approval, and release.
20. Whether purchase-policy absence blocks Planning confirmation or only later handoff; H0 persists no purchase advisory.

### 17.3 API, security, and operations decisions

21. Canonical function, capability, contract-version, event, and safe-error names.
22. Whether H0C is callable by Planning humans, a dedicated integration actor, or both.
23. Exact school/customer/location/service-date scope predicates and scope-storage extension.
24. Exact runtime-role name and practical least-privilege grant set.
25. Maximum run/contribution/group count, statement timeout, lock timeout, and retry policy for materialization and deferred checks.
26. Deterministic failed-command receipt policy for every proposed H0C error.
27. Registry versioning and how the canonical 18-function boundary is amended, if approved.
28. Event payload and audit before/after minimization rules.
29. Ownership and timing of the focused PD-01.8/PA-02 parent-contract amendment after operational-grain approval.
30. Cutover, rehearsal, production backfill, and deployment plan. None is part of H0 documentation.

## 18. Security, migration, and rollback effect of this task

This contract changes documentation only. It creates no SQL, migration, RPC, RLS policy, role, grant, generated type, React code, Storybook, package, Retool resource, Supabase project state, production row, credential, deployment, API-registry entry, or executable test.

Security and live systems are unchanged. Documentation rollback is a normal Git revert. There is no database or deployment rollback for this task.
