# PANTRY-01 — Planning-Owned Pantry Source Contract

**Status:** Approved product and architecture direction; documentation only  
**Approved by:** Product owner  
**Approval date:** 2026-07-28  
**Baseline:** `a12099599bb659f8ab754df5bdeb28ce4b0bae14`  
**Implementation:** Separately authorized after this contract is merged  
**Authority amended:** TASK-003 Pantry gap and the Pantry rows in PA-02 section 5.3 only

## 1. Decision

Atlas treats Pantry additions as a first-class Planning-owned demand source.

```text
Approved Pantry source
→ Planning Input evaluation
→ Need Generation direct Ingredient contribution
→ Confirmed Need review
→ Purchase Handoff
→ Procurement fulfilment decision
```

Pantry is not a Wholesale Order, Warehouse stock request, stock adjustment, Recipe override, supplier assignment, Purchase Order, or already generated Requirement.

The current PA-05D direct-wholesale shortcut remains valid only for Wholesale Orders. No Pantry action may call `record_wholesale_source` or `release_wholesale_order`.

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

Accepted initial purposes are database-controlled reference rows:

| Stable code | Vietnamese name | Meaning |
|---|---|---|
| `SUPPLEMENTAL_NEED` | Bổ sung nhu cầu | Additional Ingredient required beyond the planned Menu calculation. |
| `URGENT_OPERATIONAL` | Bổ sung vận hành khẩn cấp | Time-sensitive operational addition. |
| `TEMPORARY_REPLACEMENT` | Hỗ trợ thay thế tạm thời | Temporary Ingredient support without changing the permanent Recipe. |
| `OTHER_REVIEWED` | Khác — đã rà soát | Reviewed exceptional reason; a note is mandatory. |

These rows belong to a typed Supabase catalog. React must not own the list, numeric mapping, labels, status, or display order.

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

### 4.2 PantryNeedBatch

One batch represents one explicit Monday-start service week across authorized Schools.

Required concepts:

- stable `pantry_need_batch_id`;
- `week_start` and derived `week_end = week_start + 6`;
- batch status;
- optimistic-concurrency version;
- source type and source name;
- deterministic source signature;
- authoritative recording Actor and time;
- latest approval Actor, time and snapshot ID;
- created and updated timestamps.

The authenticated Atlas Actor who records the batch is the accountable requester. An optional source request reference or external requester text may be preserved as evidence, but free text never becomes Actor identity.

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
- authoritative Unit ID from the active Ingredient Unit Profile;
- active Pantry Purpose ID;
- positive requested quantity;
- optional note, except `OTHER_REVIEWED` requires a non-empty note;
- optional source request reference;
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

Unit display text is not identity. React stores and submits `unit_id`. The backend validates that the Unit is the current authoritative Planning Unit for the Ingredient or is related by a separately approved conversion contract.

### 4.4 Approval snapshot

Approval creates one immutable snapshot header and every-and-only active line snapshot.

The snapshot preserves:

- batch ID and approved batch version;
- approval Actor and timestamp;
- source signature;
- line count;
- stable line ID;
- School and Delivery Location IDs and required display snapshots;
- service date;
- Ingredient ID and required display snapshot;
- Unit ID and required display snapshot;
- Pantry Purpose ID and required display snapshot;
- exact approved quantity;
- note and source request reference where present.

A previous approval snapshot is never updated or deleted.

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
- reopening requires a non-empty reason note and advances the working version.
- reopening never modifies prior snapshots.
- once a snapshot has been referenced by a Planning Input evaluation or Need Generation run, all downstream references remain bound to that exact snapshot.

Omitting a prior working line from a complete replacement invalidates the line; it does not physically delete it. Restoring the same grain reuses the stable line ID.

Blank, zero, negative, malformed, unknown, inactive, or mismatched input is rejected or retained as a visible blocker. Atlas never silently converts invalid input to zero.

## 6. Canonical future API surface

Contract version: `PANTRY-01.v1`.

The later implementation is authorized to expose at most these six functions:

| Function | Capability | Behavior |
|---|---|---|
| `get_pantry_source_workbench(request jsonb)` | `planning.inputs.read` | Returns the explicit week, Supabase-backed references, current Pantry batch, lines, snapshots, history, issues and backend-derived allowed actions. |
| `preview_pantry_source(request jsonb)` | `planning.inputs.read` | Canonicalizes proposed rows, calculates a deterministic signature and comparison, and performs no write. |
| `save_pantry_draft(request jsonb)` | `planning.pantry.write` | Creates or completely replaces the working draft transactionally while preserving stable line identity. |
| `validate_pantry(request jsonb)` | `planning.pantry.write` | Rechecks current references, units, quantities and lifecycle and moves the working batch to `VALIDATED`. |
| `approve_pantry(request jsonb)` | `planning.inputs.approve` | Creates the immutable exact approval snapshot and moves the batch to `APPROVED`. |
| `reopen_pantry(request jsonb)` | `planning.inputs.approve` | Reasoned reopen preserving every prior approval snapshot. |

The later implementation reuses:

- `atlas_read_runtime` for shaped reads;
- `atlas_planning_command_runtime` for writes;
- existing Actor resolution, capabilities, scopes, command receipts, idempotency, optimistic concurrency, events, audit and safe errors.

It may add one capability only:

```text
planning.pantry.write
```

It must not add a runtime role.

## 7. Preview and save contract

Preview is non-writing and returns:

- normalized week;
- canonical rows;
- deterministic source signature;
- source-row count;
- active-line count;
- new, changed, unchanged and omitted prior lines;
- changed School/date pairs;
- blockers and warnings;
- `can_save`.

The canonical signature is independent of row order, harmless whitespace, Vietnamese Unicode representation and source-row labels. It includes exact business identity, quantity, Unit, Purpose and normalized note.

Save is one transactional complete replacement. It must:

- verify the preview signature;
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
- missing, unknown, inactive, or inconsistent Unit;
- unknown or inactive Pantry Purpose;
- missing note for `OTHER_REVIEWED`;
- blank, zero, negative, nonnumeric, or nonfinite quantity;
- duplicate active grain;
- no active lines;
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
- no generic source registry;
- successor evaluation for correction;
- explicit invalidation when a currently selected Pantry snapshot is superseded or reopened.

PANTRY-01 itself changes no Planning Input relation, evaluation, issue, command, API or UI.

## 10. Need Generation boundary

A later Need Generation amendment may consume an approved Pantry snapshot line as a direct Ingredient contribution:

```text
Pantry snapshot line
→ Ingredient
→ approved quantity
→ approved Unit
→ Theoretical Need contribution
```

Pantry bypasses Recipe explosion because it already identifies the Ingredient. It does not bypass Planning Input evaluation, immutable run input snapshots, validation, release membership or Confirmed Need review.

The later run must retain a direct typed Pantry snapshot-line reference. It must not fabricate a Dish, Recipe, RecipeLine, or generic free-text lineage record.

PANTRY-01 creates no Confirmed Need and does not amend existing Need Generation relations or commands.

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
- authoritative Ingredient Unit Profiles and Units;
- Pantry Purpose IDs, codes, labels, status and order;
- current batch, lines, version and status;
- approval snapshots and change history;
- blockers, warnings and allowed actions.

React may own layout, Vietnamese presentation text, loading state, local draft interaction and accessibility. It must not own permanent business arrays, numeric mappings, Unit mappings, Purpose mappings, lifecycle transitions, readiness rules, warning thresholds or approval eligibility.

Adding, renaming, reordering, activating or deactivating a Pantry Purpose in Supabase must change the connected UI after authoritative refresh without a React deployment.

Review mode may use deterministic fixtures only when they have the exact connected read shape and make no Supabase call.

## 13. Security contract

All later Pantry relations are private and use forced RLS.

The implementation must use revoke-first privileges and exact verb-specific policies. Browser roles receive no direct private-relation access. `authenticated` may execute only the reviewed API functions. `anon` and `service_role` receive no API execution.

The Planning command runtime receives no Admin, Procurement, Warehouse, Evidence or Dispatch write privilege. The read runtime receives shaped read access only. React receives no service-role credential.

## 14. OPS v1 evidence and migration boundary

Reviewed OPS v1 evidence shows:

- date-range loading;
- School and Ingredient selection;
- quantity and note editing;
- Unit display derived from Ingredient `purchase_unit`;
- effective identity `service_date + school_id + ingredient_id`;
- bulk upsert of positive quantities;
- destructive deletion when quantity is nonpositive;
- direct addition to theoretical-needs projections.

Retool export evidence SHA-256:

```text
064D74570F1CA06CD95FF2E46D07F372717ED113B7EFD16B68BFFEEE3D51ED3B
```

This evidence establishes operator intent only. Atlas must not copy Retool temporary state, client-side Unit maps, destructive deletion, numeric legacy identities, direct theoretical-view coupling, purchase assignments or downstream calculated rows.

A future controlled importer may accept explicit legacy IDs and source references, resolve them to Atlas canonical IDs, preserve the legacy tuple as migration evidence, and reject missing or ambiguous mappings. It may not connect to live OPS v1 during implementation or CI.

## 15. Implementation sequence

```text
PANTRY-01
Planning-owned Pantry product and architecture contract

→ PANTRY-02
bounded persistence, commands, read model and connected capture/approval UI

→ RMVP-03B Pantry amendment or a separately named bounded readiness amendment
exact approved Pantry snapshot admitted to Planning Input evaluation

→ RMVP-04 Pantry amendment
Need Generation direct Ingredient contribution and typed lineage
```

Direct Wholesale React connection remains a separate task using the existing PA-05D Wholesale Order aggregate and commands unchanged.

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

PANTRY-02 must not begin until this contract is merged and its implementation task confirms:

1. exactly five authorized Pantry relations;
2. one new capability maximum;
3. six API functions maximum;
4. zero new runtime roles;
5. one bounded migration;
6. database-driven React references and actions;
7. no direct Confirmed Need, Wholesale, Procurement, Warehouse or Dispatch write;
8. exact approval snapshots and stable line identity;
9. local-only synthetic acceptance data;
10. no hosted or legacy-system mutation.
