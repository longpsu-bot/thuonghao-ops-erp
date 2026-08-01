# PANTRY-01 — Planning-Owned Pantry Source Contract

- **Status:** Approved product and architecture direction; documentation only
- **Approved by:** Product owner
- **Approval date:** 2026-07-28
- **Baseline:** `a12099599bb659f8ab754df5bdeb28ce4b0bae14`
- **Implementation:** Separately authorized after this contract is merged
- **Authority amended:** TASK-003 Pantry gap and the Pantry rows in PA-02 section 5.3 only

Related authority:

- [TASK-003 Source-of-Need contract](task-003-source-of-need-contract.md)
- [PA-01 Atlas persistence contract](pa-01-atlas-persistence-contract.md)
- [PA-02 physical schema design](pa-02-physical-schema-and-constraint-design.md)
- [PA-05D bounded Planning command family](pa-05d-planning-command-family-contract.md)
- [RMVP-01 independent Atlas master data](rmvp-01-independent-atlas-master-data.md)
- [Planning Input Readiness contract](planning-domain-input-readiness-contract.md)
- [Need Generation contract](planning-domain-need-generation-contract.md)
- [Confirmed Need contract](planning-domain-confirmed-need-contract.md)
- [Procurement fulfilment-allocation amendment](procurement-fulfilment-allocation-contract-amendment.md)

## 1. Decision

Atlas treats Pantry additions as a first-class Planning-owned demand source.

```text
Pantry source
→ exact approved Pantry snapshot
→ Planning Input evaluation
→ Need Generation direct Ingredient contribution
→ Confirmed Need review
→ Purchase Handoff
→ Procurement fulfilment decision
```

Pantry is not a Wholesale Order, Warehouse stock request, stock adjustment, Recipe override, supplier assignment, Purchase Order, or already generated Requirement.

The current PA-05D direct-wholesale shortcut remains valid only for Wholesale Orders. No Pantry action may call `record_wholesale_source` or `release_wholesale_order`.

An approved Pantry snapshot may contain zero lines only when the batch explicitly records `no_additions_confirmed = true`. That snapshot is affirmative source evidence that the week has no Pantry additions; it is not a zero-quantity Pantry line. Every persisted Pantry line still requires a positive quantity.

## 2. OPS_SYSTEM_MAP placement

```text
Mission
→ capture every operational Ingredient need before purchasing or fulfilment

Business Capability
→ record, validate and approve internal Pantry additions

Business Domain
→ Planning

Business Objects
→ PantryNeedPurpose
→ PantryNeedBatch
→ PantryNeedLine
→ PantryNeedApprovalSnapshot
→ PantryNeedApprovalSnapshotLine

Business Contract
→ Pantry identifies an additional Ingredient quantity for one School, destination and service date
→ a zero-line approval explicitly confirms that no Pantry additions exist for the week
→ approval makes the exact snapshot eligible for later Planning Input evaluation
→ approval does not select supplier or Warehouse fulfilment

Commands / Events
→ save_pantry_draft / PantryDraftSaved
→ validate_pantry / PantryValidated
→ approve_pantry / PantryApproved
→ reopen_pantry / PantryReopened

Read Model
→ get_pantry_source_workbench
→ preview_pantry_source

Application
→ connected Vietnamese Pantry tab using Supabase-returned references and actions

Technology
→ later bounded PostgreSQL/Supabase migration and React connection
```

## 3. Business meaning

A Pantry addition is a direct Ingredient need that supplements the planned Menu/Recipe calculation for a School and service date.

A batch with no additions is also a controlled Planning input. The operator must explicitly set `no_additions_confirmed = true`; an empty row set without that confirmation is incomplete and cannot validate or approve. The flag must be `false` whenever one or more active Pantry lines exist.

Pantry purposes belong to a typed Supabase catalog named `atlas_planning.pantry_need_purposes`. PANTRY-01 does not fix final production codes, labels, descriptions, note rules, or seed rows. Those values require separate product review before production use.

React must not own the purpose vocabulary, numeric mapping, labels, status, or display order. A database catalog change must be reflected after authoritative refresh without requiring a React deployment.

## 4. Aggregate and persistence model

A later bounded implementation may add exactly these five private Planning relations:

1. `atlas_planning.pantry_need_purposes`
2. `atlas_planning.pantry_need_batches`
3. `atlas_planning.pantry_need_lines`
4. `atlas_planning.pantry_need_approval_snapshots`
5. `atlas_planning.pantry_need_approval_snapshot_lines`

This contract supersedes the two deferred PA-02 Pantry rows with this complete typed aggregate and approval-snapshot family. It does not authorize a generic demand-source table or workflow engine.

### 4.1 PantryNeedPurpose

Required concepts:

- stable opaque `pantry_need_purpose_id`;
- immutable stable code after operational use;
- mutable display name and description;
- `ACTIVE` / `INACTIVE` status;
- display order;
- optimistic version and timestamps;
- referenced purposes cannot be hard-deleted.

The catalog is typed business data and must not be replaced by a generic `app_config(key, value)` relation.

### 4.2 PantryNeedBatch

One batch represents one explicit Monday-start service week across authorized Schools.

Required concepts:

- stable `pantry_need_batch_id`;
- `week_start` and derived `week_end = week_start + 6`;
- batch status;
- optimistic-concurrency version;
- source type and source name;
- deterministic source signature;
- required `no_additions_confirmed` working fact;
- requesting Actor;
- authoritative creation/import Actor, method, source evidence and time;
- latest approval Actor, time and snapshot ID;
- created and updated timestamps.

The authenticated Atlas Actor who records the batch is the accountable requester unless a later reviewed import contract supplies a different typed requesting Actor. An optional source request reference or external requester text may be preserved as evidence, but free text never becomes Actor identity.

### 4.3 PantryNeedLine

One stable working line represents:

```text
Pantry batch
+ service date
+ School
+ Delivery Location
+ Ingredient
```

Required current working facts:

- stable `pantry_need_line_id`;
- owning batch ID;
- active School ID;
- active Delivery Location ID belonging to the same School/customer context;
- service date inside the batch week;
- active Ingredient ID;
- authoritative Unit ID resolved server-side through
  `atlas_admin.ingredients.purchase_unit_id → atlas_admin.units.unit_id`;
- active Pantry Purpose ID;
- positive requested quantity;
- optional note;
- optional source request reference;
- optional source-row evidence where relevant;
- line status `ACTIVE` or `INVALID`;
- updated Actor and timestamp.

The active uniqueness grain is:

```text
batch
+ service date
+ School
+ Delivery Location
+ Ingredient
```

Multiple requests for the same active grain are consolidated into one reviewed quantity before save. Separate sub-request lineage is deferred until a proven operational need exists.

Unit display text is not identity, and the client does not select or submit Unit authority. Preview and save resolve the Ingredient's current non-null `purchase_unit_id` and active Unit row on the server, persist that resolved `unit_id`, include it in the canonical signature, and return it for display. Validation and approval re-resolve the same chain; a missing or inactive Unit, or a persisted Unit that is stale against the Ingredient's current purchase Unit, blocks the command until authoritative refresh and reviewed save. PANTRY-01 authorizes no conversion, fallback, or caller override.

A quantity, purpose, note, source reference or source-row correction changes working facts and version without replacing the stable Pantry line ID. A refreshed server-resolved purchase Unit changes the working fact and version without changing stable line identity. Omission invalidates the stable line instead of deleting it.

### 4.4 Approval snapshot

Approval creates one immutable snapshot header and every-and-only active line snapshot rows. The every-and-only line set may be empty only when `no_additions_confirmed = true`.

The snapshot header preserves:

- batch ID and approved batch version;
- approval Actor and timestamp;
- source signature;
- exact `no_additions_confirmed` value;
- line count;
- blocker/warning issue summary;

Each snapshot line, when present, preserves:

- stable line ID;
- School and Delivery Location IDs, codes/names and required display snapshots;
- service date;
- Ingredient ID, code/name and required display snapshot;
- Unit ID, code/name and required display snapshot;
- Pantry Purpose ID, code/name and required display snapshot;
- exact approved quantity;
- note, source request reference and source-row evidence where present.

A valid zero-line approval snapshot has `line_count = 0`, `no_additions_confirmed = true`, and no snapshot-line rows. It must not fabricate a zero-quantity line, Ingredient, Unit, School, Delivery Location, or Pantry Purpose.

A previous approval snapshot is never updated or deleted. Later master-data or purpose-catalog changes do not rewrite its historical meaning.

## 5. Lifecycle

The Pantry capture lifecycle is:

```text
DRAFT
→ VALIDATED
→ APPROVED
→ REOPENED
→ VALIDATED
→ APPROVED
```

Rules:

- `DRAFT` and `REOPENED` are editable working states.
- `VALIDATED` is backend-confirmed and not editable without returning to a working state through the approved command path.
- `APPROVED` means the exact snapshot is eligible for Planning Input evaluation.
- Pantry has no `RELEASED` state in the capture slice.
- approval is not Procurement release, Warehouse reservation, or supplier commitment.
- validation and approval require either one or more positive-quantity active lines with `no_additions_confirmed = false`, or zero active lines with `no_additions_confirmed = true`.
- reopening requires a non-empty reason note and advances the working version.
- reopening never modifies prior snapshots.
- once a snapshot has been referenced by a Planning Input evaluation or Need Generation run, all downstream references remain bound to that exact snapshot.

Omitting a prior working line from a complete replacement invalidates the line; it does not physically delete it. Restoring the same grain reuses the stable line ID.

For a supplied Pantry line, blank, zero, negative, malformed, unknown, inactive, or stale input is rejected or retained as a visible blocker. Atlas never silently converts invalid line input to zero. A valid explicit zero-line batch uses `no_additions_confirmed`; it does not use a zero quantity.

Pantry source approval is distinct from Planning Input readiness, Need Generation release, Confirmed Need approval, and Purchase Handoff release. Each remains a separately controlled business boundary.

## 6. Maximum future PANTRY-02 API proposal

PANTRY-01 authorizes the maximum shape below for later PANTRY-02 design. PANTRY-02 must finalize the exact function names, envelope and contract version before implementation.

The later implementation may expose at most these six functions:

| Function                                     | Capability                | Behavior                                                                                                                                                                  |
| -------------------------------------------- | ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `get_pantry_source_workbench(request jsonb)` | `planning.inputs.read`    | Returns the explicit week, Supabase-backed references, current Pantry batch and no-additions fact, lines, snapshots, history, issues and backend-derived allowed actions. |
| `preview_pantry_source(request jsonb)`       | `planning.inputs.read`    | Canonicalizes proposed rows, resolves Ingredient purchase Units server-side, calculates a deterministic signature and comparison, and performs no write.                  |
| `save_pantry_draft(request jsonb)`           | `planning.pantry.write`   | Creates or completely replaces the working draft transactionally while preserving stable line identity.                                                                   |
| `validate_pantry(request jsonb)`             | `planning.pantry.write`   | Rechecks current references, server-resolved Units, quantities, no-additions consistency and lifecycle and moves the working batch to `VALIDATED`.                        |
| `approve_pantry(request jsonb)`              | `planning.inputs.approve` | Creates the immutable exact approval snapshot and moves the batch to `APPROVED`.                                                                                          |
| `reopen_pantry(request jsonb)`               | `planning.inputs.approve` | Reasoned reopen preserving every prior approval snapshot.                                                                                                                 |

The later implementation reuses:

- `atlas_read_runtime` for shaped reads;
- `atlas_planning_command_runtime` for writes;
- existing Actor resolution, capabilities, scopes, command receipts, idempotency, optimistic concurrency, events, audit and safe errors.

It may add at most one capability:

```text
planning.pantry.write
```

It must not add any role, including a runtime role.

## 7. Preview and save contract

Preview is non-writing and returns:

- normalized week;
- exact `no_additions_confirmed` value;
- canonical rows;
- deterministic source signature;
- source-row count;
- active-line count;
- new, changed, unchanged and omitted prior lines;
- changed School/date pairs;
- blockers and warnings;
- `can_save`.

Proposed row input identifies the Ingredient but contains no caller-authoritative Unit selection. Preview may return the server-resolved Unit for review, and save must re-resolve it rather than trust a client echo.

The canonical signature is independent of row order, harmless whitespace, Vietnamese Unicode representation and source-row labels. It includes `no_additions_confirmed`, exact business identity, quantity, server-resolved Unit, Purpose and normalized note.

Save is one transactional complete replacement. It must:

- verify the preview signature;
- reject active lines combined with `no_additions_confirmed = true`;
- reject zero active lines unless `no_additions_confirmed = true`;
- verify current expected version and expected persisted source signature;
- lock the batch and stable lines deterministically;
- create or update current working facts only in editable states;
- invalidate omitted lines rather than delete them;
- emit one domain event and one audit event for a material change;
- return authoritative readback;
- return `NO_CHANGE` without event/audit writes when canonical business content and source metadata are unchanged;
- support exact replay and reject changed idempotency reuse.

## 8. Validation and issue model

Blocking conditions include:

- invalid or non-Monday week start;
- service date outside the week;
- unknown or inactive School;
- unknown, inactive, or wrong Delivery Location;
- unknown or inactive Ingredient;
- missing or inactive server-resolved Ingredient purchase Unit;
- persisted Unit stale against the Ingredient's current purchase Unit;
- unknown or inactive Pantry Purpose;
- blank, zero, negative, nonnumeric, or nonfinite quantity on a supplied line;
- duplicate active grain;
- zero active lines without `no_additions_confirmed = true`;
- one or more active lines while `no_additions_confirmed = true`;
- stale version or stale source signature;
- invalid lifecycle transition.

Warnings may include only backend-defined, contract-reviewed conditions. React must not invent quantity thresholds or readiness rules.

## 9. Planning Input Readiness boundary

RMVP-03B remains the Planning Input Readiness task. PANTRY-01 does not replace or renumber it.

The current readiness persistence binds Weekly Menu and Attendance directly. A later bounded Pantry-readiness amendment must add a direct typed reference to:

```text
pantry_need_batch_id
+ approved pantry snapshot ID
+ approved batch version
```

The amendment must preserve:

- exact period containment;
- immutable evaluation evidence;
- direct typed ownership;
- acceptance of an exact approved zero-line Pantry snapshot as valid source evidence when `no_additions_confirmed = true`;
- no generic source registry;
- successor evaluation for correction;
- explicit invalidation when a currently selected Pantry snapshot is superseded or reopened.

PANTRY-01 itself changes no Planning Input relation, evaluation, issue, command, API or UI.

## 10. Need Generation boundary

PANTRY-NG-01 now approves the product and architecture direction for each positive-quantity approved Pantry snapshot line to become a direct Ingredient contribution:

```text
Pantry snapshot line
→ Ingredient
→ approved quantity
→ approved Unit
→ Theoretical Need contribution
```

Pantry bypasses Recipe explosion because it already identifies the Ingredient. It does not bypass Planning Input evaluation, immutable run input snapshots, validation, release membership or Confirmed Need review.

The canonical authorities are the [PANTRY-NG-01 direct-ingredient amendment](pantry-ng-01-need-generation-direct-ingredient-amendment.md) and the [PNG-P01 through PNG-P12 decision registry](../decisions/decision-pantry-ng-01-need-generation-direct-ingredient.md). They require one combined Need Generation run and closed `RECIPE_DERIVED` / `PANTRY_DIRECT` atomic contribution families.

For every active Pantry contribution, the later run must retain a direct typed Pantry snapshot-line reference and exact stable Pantry-line lineage. It must not fabricate a Dish, Recipe, RecipeLine, Recipe calculation or generic free-text lineage record.

For an exact approved zero-line Pantry snapshot, the later run must retain the approved snapshot as input evidence and create zero Pantry contribution lines. It must not fabricate a zero-quantity Theoretical Need contribution or treat the controlled absence as a missing Pantry source.

PANTRY-NG-01 is contract and decision authority only. Implementation has not started and requires a separately bounded task. PANTRY-01 capture, validation, approval, zero-line and snapshot behavior remains unchanged; PANTRY-NG-01 does not expand PANTRY-02.

PANTRY-01 creates no Confirmed Need, and PANTRY-NG-01 implements no Need Generation relation, command, API or UI change.

## 11. Procurement, Warehouse and Dispatch boundary

Planning states what Ingredient quantity is needed, where, and by when.

Procurement later decides whether an approved requirement is fulfilled by:

- an external supplier;
- Warehouse stock;
- a mixed allocation;
- another separately approved source.

Pantry does not select the fulfilment source.

Warehouse records physical custody, reservations, picking and stock release only after a Warehouse allocation exists. Procurement creates supplier commitments only after released Planning demand exists. Dispatch consumes released obligations and physical evidence; it does not interpret Pantry rows directly.

## 12. Database-driven React contract

The connected Pantry UI must render from authorized Supabase shaped reads.

Supabase supplies:

- Schools;
- Delivery Locations and School/location relationships;
- Ingredients;
- each Ingredient's authoritative server-resolved `purchase_unit_id` and active Unit;
- Pantry Purpose IDs, codes, labels, status and order;
- current batch, lines, version, status and `no_additions_confirmed`;
- approval snapshots and change history;
- blockers, warnings and allowed actions.

React may own layout, Vietnamese presentation text, loading state, local draft interaction and accessibility. It may display the Unit returned for an Ingredient but must not select, map, submit, or override authoritative Unit identity. It must not own permanent business arrays, numeric mappings, Unit mappings, Purpose mappings, lifecycle transitions, readiness rules, warning thresholds or approval eligibility.

Adding, renaming, reordering, activating or deactivating a Pantry Purpose in Supabase must change the connected UI after authoritative refresh without a React deployment.

Review mode may use deterministic fixtures only when they have the exact connected read shape and make no Supabase call.

## 13. Security contract

All later Pantry relations are private and use forced RLS.

The implementation must use revoke-first privileges and exact verb-specific policies. Browser roles receive no direct private-relation access. `authenticated` may execute only the reviewed API functions. `anon` and `service_role` receive no API execution.

The Planning command runtime receives no Admin, Procurement, Warehouse, Evidence or Dispatch write privilege. The read runtime receives shaped read access only. React receives no service-role credential.

## 14. OPS v1 evidence and migration boundary

The February Retool JSON export with SHA-256
`064D74570F1CA06CD95FF2E46D07F372717ED113B7EFD16B68BFFEEE3D51ED3B`
does not contain the Pantry-labelled objects reviewed below.

The separate Retool export `OPS - Lên đơn, Đặt hàng (1)` is identified by:

- JSON SHA-256
  `6F6FF8D025696D375F354A86126661D20C3E9908D6475D40ECB14EE006B4A371`;
- decomposed ZIP SHA-256
  `728611082382E9146C9456910E6D334B9B8135BD1A1BBEAC4D9C3476BB12C18F`.

That separate export contains Pantry-specific internal components,
controllers, queries and dedicated tab-key logic, including:

- `ctl_pantry_load`;
- `tblPantry`;
- `q_pantry_load`;
- `q_pantry_ingredients`;
- `q_pantry_save_upsert`;
- a Pantry tab key of `7`, including a `not_pantry_tab` result when another
  tab is selected.

Together with OPS v1 schema evidence, the legacy evidence establishes:

- date-range loading;
- School and Ingredient selection;
- quantity and note editing;
- Unit display derived from Ingredient `purchase_unit`;
- effective identity `service_date + school_id + ingredient_id`;
- changed-row save behavior;
- legacy Pantry persistence and contribution to the theoretical-needs flow.

This legacy UI, query and schema structure is operational evidence only. It
does not define Atlas Pantry ownership, stable UUID identity, lifecycle,
approval snapshots, source signatures, Unit authority, deletion semantics,
Need Generation, Confirmed Need, supplier selection, Warehouse routing,
Procurement release or other downstream behavior.

Atlas must not copy Retool temporary state, client-side Unit maps, infer
deletion behavior, use numeric legacy identities as canonical identity, or
couple Pantry directly to legacy theoretical-needs, purchase-assignment or
downstream calculated rows.

A future controlled importer may accept explicit legacy IDs and source references, resolve them to Atlas canonical IDs, preserve the legacy tuple as migration evidence, and reject missing or ambiguous mappings. It may not connect to live OPS v1 during implementation or CI.

## 15. Implementation sequence

```text
PANTRY-01
Planning-owned Pantry product and architecture contract

→ PANTRY-REF-01
mandatory reference-data contract and readiness gate

→ PANTRY-02
bounded persistence, commands, read model and connected capture/approval UI

→ separately named Pantry readiness amendment
exact approved Pantry snapshot admitted to Planning Input evaluation

→ PANTRY-NG-01
accepted direct Ingredient contribution and typed-lineage contract

→ separately bounded Pantry Need Generation implementation
future persistence, pgTAP, command/read and application scope
```

RMVP-03B remains Planning Input Readiness and RMVP-04 remains Need Generation. The later Pantry amendments extend those contracts without renaming or replacing either task.

Direct Ingredient customer-order React connection remains a separate task using the existing PA-05D Wholesale Order aggregate and commands unchanged.

PANTRY-REF-01 must approve the initial Pantry Purpose codes, labels, statuses, display order and note rules, and must define how selectable existing School, Delivery Location, Ingredient and active purchase-Unit references are verified as ready for Pantry. It authorizes no current seed, production-data mutation, new relation, API, capability or role. PANTRY-02 remains limited to the same five Pantry relations, six APIs, one new capability maximum and zero new roles, including runtime roles.

## 16. Explicit exclusions

PANTRY-01 authorizes no:

- migration;
- API implementation;
- React change;
- new role or grant;
- Planning Input mutation;
- Need Generation mutation;
- Confirmed Need creation;
- Purchase Handoff;
- supplier assignment or Purchase Order;
- Warehouse stock action;
- Dispatch action;
- hosted Supabase action;
- production seed, data or credential;
- OPS v1, OPS v2 or Retool mutation.

## 17. Implementation acceptance gate

PANTRY-02 must not begin until this contract is merged and its implementation contract confirms:

1. PANTRY-REF-01 is approved as the mandatory reference-data dependency;
2. exactly five authorized Pantry relations;
3. one new capability maximum;
4. six API functions maximum;
5. zero new roles, including runtime roles;
6. one bounded migration;
7. database-driven React references and actions with server-resolved Ingredient purchase Unit;
8. no direct Confirmed Need, Wholesale, Procurement, Warehouse or Dispatch write;
9. exact approval snapshots, including explicit `no_additions_confirmed` zero-line snapshots, and stable line identity;
10. local-only synthetic acceptance data;
11. no hosted or legacy-system mutation.
