# PANTRY-02 — Connected Planning-Owned Pantry Source

## Outcome

PANTRY-02 connects Pantry as the third source tab inside the existing Vietnamese `Nguồn kế hoạch` workbench. It implements manual Atlas capture, authoritative preview, complete draft replacement, validation, immutable approval, reasoned reopen, and reapproval for one explicit Monday-start week.

The slice ends at an exact approved Pantry snapshot. It creates no Planning Input evaluation, Need Generation contribution, Confirmed Need, Purchase Handoff, Procurement, Warehouse, Dispatch, or Wholesale fact.

## Authority and bounded scope

The implementation follows the approved [PANTRY-01 source contract](pantry-01-planning-owned-pantry-source-contract.md) and [PANTRY-REF-01 reference-data contract](pantry-ref-01-reference-data-contract.md).

- Exactly five private `atlas_planning` relations store the Purpose catalog, weekly batch, stable working lines, immutable snapshot headers, and immutable snapshot lines.
- Exactly six `atlas_api` functions expose shaped read, non-writing preview, and four transactional commands.
- Exactly one capability, `planning.pantry.write`, is added.
- No database role, runtime role, scope kind, module boundary, operating stage, dependency, generic source framework, or Purpose-administration API is added.
- The existing `atlas_read_runtime` owns the read and preview APIs.
- The existing `atlas_planning_command_runtime` owns all four command APIs and the deferred snapshot-integrity guard.
- Source method is backend-owned and fixed to direct manual Atlas capture.
- The migration creates an empty typed Purpose catalog. The accepted first Purpose registry remains canonical in PANTRY-REF-01 and is not duplicated here.

## Persistence

### `pantry_need_purposes`

The typed catalog retains stable UUID/code identity, Vietnamese display metadata, `OPTIONAL`/`REQUIRED`/`PROHIBITED` note rules, `ACTIVE`/`INACTIVE` lifecycle, display order, optimistic version, and timestamps. Operationally used codes are immutable, and referenced rows cannot be deleted.

No Purpose row is inserted by the migration. Exact accepted rows exist only in rolled-back pgTAP data, deterministic review fixtures, and the loopback-guarded local fixture.

### `pantry_need_batches`

One stable batch exists per explicit Monday-start week. `week_end` is generated as `week_start + 6`. The batch owns status, optimistic version, fixed source metadata, deterministic source signature, explicit `no_additions_confirmed`, accountable Actor evidence, and the latest approval pointer.

The lifecycle is exactly:

```text
DRAFT → VALIDATED → APPROVED → REOPENED → VALIDATED → APPROVED
```

A material save preserves its editable state: `DRAFT` remains `DRAFT` and `REOPENED` remains `REOPENED`, with one version increment and the bounded draft-created/replaced event as applicable. Validation moves either editable state to `VALIDATED`. There is no `REOPENED → DRAFT` transition and no editable transition from `VALIDATED`.

### `pantry_need_lines`

Stable identity is:

```text
batch
+ service date
+ School
+ backend-derived default Delivery Location
+ Ingredient
```

Purpose, Unit, quantity, note, and source evidence are mutable facts, not identity. Complete replacement reuses an existing line for the same grain, invalidates omissions, and never physically deletes a stable line. Restoring a prior grain reuses its UUID.

Quantities are exact positive decimals with at most six fractional digits. The backend does not round, ceil, convert, or reinterpret them.

### Approval snapshots

Each approval creates one immutable header for the exact approved batch version and every-and-only active line. Snapshot lines preserve IDs plus School, Delivery Location, Ingredient, Unit, and Purpose display facts needed for later historical interpretation.

Historical snapshot versions are not foreign keys to the mutable current batch version. They are bound to stable batch identity, protected by unique batch/version identity and deferred exact-evidence guards. This permits later reopen while preserving all prior approvals.

An explicit zero-line approval creates one header with `no_additions_confirmed = true`, `line_count = 0`, and no snapshot line.

## Reference authority

The operator selects only School, Ingredient, and Purpose.

- School must be active and belong to an active `SCHOOL_CATERING` Customer.
- PostgreSQL derives the School’s exact active `default_delivery_location_id` and requires that Location to belong to the same Customer.
- Ingredient must be active and have a purchase Unit.
- PostgreSQL resolves only `ingredients.purchase_unit_id → units.unit_id` and requires the Unit to be active.
- Purpose must exist, be active, and apply its current note rule.

Delivery Location and Unit are displayed by React but are never caller-authoritative fields or selectors. Validation and approval rederive both references and detect stale persisted values.

## Preview, signature, and replacement

Preview writes nothing. It canonicalizes only the reviewed operator fields, derives references, applies current typed rules, returns stable blockers/warnings, and computes a SHA-256 signature over business content.

The signature includes week, explicit zero-additions fact, service date, School, derived Delivery Location, Ingredient, resolved Unit, Purpose, exact quantity, normalized note, and normalized source request reference. It is independent of row order, harmless whitespace, Unicode composition, and source-row evidence.

Preview returns deterministic arrays for new, changed, unchanged, and omitted lines plus changed School/date pairs. Save recomputes all facts, requires the preview signature, current version, and persisted signature, and performs one atomic complete replacement. Exact canonical replacement returns `NO_CHANGE` with no event or audit write. Exact request replay returns the original durable receipt; changed idempotency-key reuse fails closed.

## Zero additions

An empty ordinary draft is incomplete. Zero additions is valid only through an explicit operator confirmation.

- Active lines and `no_additions_confirmed = true` are mutually exclusive.
- Saving active rows sets the fact to false.
- Explicit zero confirmation submits an empty row set and invalidates prior active rows through the same stable-line model.
- No zero-quantity or placeholder line is ever created.

## Security

All five relations have enabled and forced RLS. Browser roles have no private-schema access. `authenticated` receives execution only on the six reviewed APIs; `anon` and `service_role` receive none.

All APIs are `SECURITY DEFINER` with empty `search_path` and exact schema qualification. Reads use `planning.inputs.read`; save/validate use `planning.pantry.write`; approve/reopen use `planning.inputs.approve`. All six require exact JWT-subject binding, an active Actor, the existing global Planning scope, and safe envelopes.

The deferred snapshot-integrity trigger is `SECURITY DEFINER` owned by the existing Planning command runtime. This is required because PostgreSQL can execute deferred triggers at transaction commit after the API function’s definer context has ended. The runtime retains only its bounded relation privileges and RLS policies; temporary schema-create authority used to transfer function ownership is revoked in the migration.

## UI and review mode

Pantry is a bounded submodule under `planning-inputs/pantry/` and a thin third tab in `PlanningInputsWorkbench`. The UI shows backend status/version/signature/action flags, active and invalid rows, derived references, Purpose metadata, preview comparison, blockers/warnings, zero confirmation, approval history, and audit history. Editing is disabled when backend `allowed_actions.can_save` is false.

Browser working edits are tracked separately from authoritative readback. Adding, changing, removing, or replacing rows—including explicit zero-additions confirmation—marks the workbench dirty. Preview does not clear that state; validation, approval, and reopen remain unavailable until a successful save or authoritative refresh adopts backend readback. A request-generation guard ignores late reads from a previously selected week and clears prior-week visible working rows while the newer week loads.

Review mode uses the exact connected shape and exact two accepted Purpose fixtures without Supabase or other network access. It remains visibly marked as non-persistent.

## Migration and rollback

Migration: `20260729032653_pantry_02_connected_pantry_source.sql`.

A local rollback is a database rebuild to the prior migration. A deployed rollback would require a reviewed forward migration that first preserves or remaps all working and approval evidence, then removes grants, policies, triggers, APIs, helper functions, capability, foreign keys, and the five relations in dependency order. It must not delete approved operational history.

No hosted deployment or production rollback action is authorized by PANTRY-02.

## Verification

- `supabase/tests/pantry_02_connected_pantry_source.sql`: exact `plan(46)`, including forced deferred-constraint checks at positive and zero-line approval boundaries.
- `supabase/tests/atlas_current_platform_security_catalog.sql`: exact whole-platform counts, owners, functions, grants, policies, triggers, and digests.
- `pnpm local:pantry02:verify`: loopback-guarded browser-key lifecycle through stable correction, positive approval, reopen, zero-line successor approval, exact event/audit evidence, and physical downstream non-mutation.
- Focused TypeScript tests cover the six-function registry/adapter, envelopes, response handling, dynamic Purpose metadata, derived reference display, zero confirmation, dirty preview/save gating, stale-week response isolation, backend action flags, lifecycle, history, and safe error states.

## Exclusions

PANTRY-02 does not deploy Supabase, seed production Purpose data, mutate OPS v1/v2 or Retool, implement workbook/Google/recurring import, call Wholesale commands, persist readiness, generate Need, create Confirmed Need or Purchase Handoff, choose a supplier or Warehouse route, or create Procurement, receiving, stock, Dispatch, or fulfilment records.
