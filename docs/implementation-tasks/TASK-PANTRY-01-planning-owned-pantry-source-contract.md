# TASK-PANTRY-01 — Define Planning-Owned Pantry Source Contract

- **Status:** Documentation complete; draft PR review pending
- **Baseline:** `a12099599bb659f8ab754df5bdeb28ce4b0bae14`
- **Branch:** `docs/pantry-01-planning-source-contract`
- **Task type:** Documentation and governance only

## 1. Purpose

Resolve the repository’s explicit Pantry contract gap before any Pantry migration, API or React work.

The task establishes Pantry as a typed Planning-owned source while preserving the existing boundaries for Weekly Menu, Attendance, Planning Input Readiness, Need Generation, Wholesale Orders, Procurement, Warehouse and Dispatch.

## 2. Authority reviewed

- `AGENTS.md`
- `docs/architecture/task-003-source-of-need-contract.md`
- `docs/architecture/pa-01-atlas-persistence-contract.md`
- `docs/architecture/pa-02-physical-schema-and-constraint-design.md`
- `docs/architecture/pa-05d-planning-command-family-contract.md`
- `docs/architecture/rmvp-03a-connected-weekly-menu-attendance.md`
- Planning Input Readiness contracts and decisions
- Need Generation contracts and decisions
- Confirmed Need identity and contribution-membership contracts
- Procurement fulfilment-allocation boundary
- `docs/architecture/roadmap.md`
- `docs/decisions/decision-register.md`
- merged RMVP-03A baseline
- read-only OPS v1 schema and Retool Menu/Ordering exports

## 3. Retool and legacy evidence

The reviewed OPS v1 evidence shows an adjacent operational grid pattern with:

- date-range selection;
- School and Ingredient selection;
- quantity and note editing;
- Unit display derived from Ingredient `purchase_unit`;
- legacy identity based on `service_date + school_id + ingredient_id`;
- changed-row bulk-save behavior.

Retool export SHA-256:

```text
064D74570F1CA06CD95FF2E46D07F372717ED113B7EFD16B68BFFEEE3D51ED3B
```

The retained Retool export does not contain a component or tab labelled Pantry. The evidence is descriptive of adjacent operator interaction, not authoritative for Atlas Pantry identity, lifecycle, add-row behavior or downstream routing.

## 4. Deliverables

- [PANTRY-01 architecture contract](../architecture/pantry-01-planning-owned-pantry-source-contract.md)
- [PANTRY-01 decision record](../decisions/decision-pantry-01-planning-owned-pantry-source.md)
- decision-register entry
- roadmap sequencing clarification

## 5. Decisions established

- Pantry is a first-class Planning-owned source.
- Pantry is not a Wholesale Order or Warehouse stock action.
- Pantry uses typed Supabase references for School, Delivery Location, Ingredient, Unit and Pantry Purpose.
- The Pantry Unit is the Ingredient's current `purchase_unit_id`, which references the authoritative Unit row; missing or mismatched Unit authority blocks the future command.
- Pantry Purpose is a typed database catalog whose production codes and seed values remain separately reviewed.
- One batch covers one Monday-start week.
- One active stable line exists per batch/date/School/location/Ingredient.
- Capture lifecycle is `DRAFT → VALIDATED → APPROVED → REOPENED → VALIDATED → APPROVED`.
- Approval creates an immutable exact-line snapshot.
- Pantry does not directly create Confirmed Need.
- A later readiness amendment binds the approved Pantry snapshot directly.
- A later Need Generation amendment consumes Pantry as a direct Ingredient contribution without Recipe explosion.
- Procurement later chooses supplier, Warehouse, mixed or another approved fulfilment source.
- RMVP-03B remains Planning Input Readiness.
- React must render business references, rules and allowed actions from authorized Supabase shaped reads rather than permanent TypeScript configuration.

## 6. Explicit boundaries

This task authorizes no:

- migration;
- database relation creation;
- API or command implementation;
- runtime role, grant or RLS change;
- React change;
- Planning Input evaluation change;
- Need Generation change;
- Confirmed Need creation;
- Procurement, Warehouse or Dispatch change;
- hosted Supabase deployment;
- production data, seed or credential;
- OPS v1, OPS v2 or Retool mutation.

The existing PA-05D Wholesale Order commands remain unchanged and must not be reused for Pantry.

## 7. Validation

Documentation review must confirm:

1. OPS_SYSTEM_MAP placement is explicit.
2. The aggregate grain and lifecycle are unambiguous.
3. Database-driven React requirements are mandatory.
4. exact future persistence/API/capability/runtime bounds are stated.
5. Planning Input and Need Generation amendments are separately bounded.
6. supplier-versus-Warehouse routing remains Procurement-owned.
7. the contract does not mutate current persistence or application behavior.
8. all relative documentation links resolve.
9. Markdown formatting and diff whitespace checks pass in CI.

## 8. Next task

After this contract is merged, a separately authorized `PANTRY-02` task may implement the bounded persistence, command/read surface and connected capture/approval UI within the exact limits defined by PANTRY-01.

PANTRY-02 must not silently include Planning Input Readiness or Need Generation changes.
