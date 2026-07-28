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
- `docs/architecture/rmvp-01-independent-atlas-master-data.md`
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

The February Retool JSON export with SHA-256
`064D74570F1CA06CD95FF2E46D07F372717ED113B7EFD16B68BFFEEE3D51ED3B`
does not contain the Pantry-labelled objects reviewed for this decision.

The separate Retool export `OPS - Lên đơn, Đặt hàng (1)`, identified by JSON
SHA-256
`6F6FF8D025696D375F354A86126661D20C3E9908D6475D40ECB14EE006B4A371`
and decomposed ZIP SHA-256
`728611082382E9146C9456910E6D334B9B8135BD1A1BBEAC4D9C3476BB12C18F`,
contains Pantry-specific internal components, controllers, queries and
dedicated tab-key logic. Reviewed examples include:

- `ctl_pantry_load`;
- `tblPantry`;
- `q_pantry_load`;
- `q_pantry_ingredients`;
- `q_pantry_save_upsert`;
- Pantry tab key `7` and the `not_pantry_tab` result for another selected tab.

That Retool export and the OPS v1 schema evidence establish:

- date-range selection;
- School and Ingredient selection;
- quantity and note editing;
- Unit display derived from Ingredient `purchase_unit`;
- legacy identity based on `service_date + school_id + ingredient_id`;
- changed-row save behavior;
- Pantry persistence and contribution to the legacy theoretical-needs flow.

Both exports are read-only operational evidence. They do not define Atlas
Pantry ownership, stable UUID identity, lifecycle, approval snapshots, source
signatures, Unit authority, deletion semantics, Need Generation, Confirmed
Need, supplier selection, Warehouse routing or Procurement release.

## 4. Deliverables

- [PANTRY-01 architecture contract](../architecture/pantry-01-planning-owned-pantry-source-contract.md)
- [PANTRY-01 decision record](../decisions/decision-pantry-01-planning-owned-pantry-source.md)
- decision-register entry
- roadmap sequencing clarification

## 5. Decisions established

- Pantry is a first-class Planning-owned source.
- Pantry is not a Wholesale Order or Warehouse stock action.
- Pantry uses typed Supabase references for School, Delivery Location, Ingredient, Unit and Pantry Purpose.
- The backend resolves Pantry Unit from the Ingredient's current `purchase_unit_id` and active Unit row; React neither selects nor submits authoritative Unit identity, and missing, inactive or stale Unit authority blocks the future command.
- Pantry Purpose is a typed database catalog whose production codes and seed values remain separately reviewed.
- One batch covers one Monday-start week.
- One active stable line exists per batch/date/School/location/Ingredient.
- An exact zero-line approval is valid only with `no_additions_confirmed = true`; it records controlled absence and never creates a zero-quantity line.
- Capture lifecycle is `DRAFT → VALIDATED → APPROVED → REOPENED → VALIDATED → APPROVED`.
- Approval creates an immutable exact snapshot header and every-and-only active line set, including the valid empty set for an explicit no-additions confirmation.
- Pantry does not directly create Confirmed Need.
- A later readiness amendment binds the approved Pantry snapshot directly.
- A later Need Generation amendment consumes positive Pantry lines as direct Ingredient contributions without Recipe explosion and retains a zero-line approval as exact input evidence without fabricating a contribution.
- Procurement later chooses supplier, Warehouse, mixed or another approved fulfilment source.
- RMVP-03B remains Planning Input Readiness.
- PANTRY-REF-01 is the mandatory reference-data dependency before PANTRY-02 and separately approves the initial Pantry Purpose vocabulary and reference-readiness criteria.
- PANTRY-02 remains limited to exactly five private Pantry relations, at most six APIs, at most one new capability and zero new roles, including runtime roles.
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
4. explicit `no_additions_confirmed` zero-line approval is distinct from a prohibited zero-quantity line.
5. Ingredient purchase Unit is resolved server-side and cannot be selected or overridden by React.
6. PANTRY-REF-01 is a mandatory reference-data dependency.
7. the five-relation, six-API, one-capability and zero-new-role limits are unchanged.
8. Planning Input and Need Generation amendments are separately bounded without renaming RMVP-03B.
9. supplier-versus-Warehouse routing remains Procurement-owned.
10. the contract does not mutate current persistence or application behavior.
11. all relative documentation links resolve.
12. Markdown formatting and diff whitespace checks pass in CI.

## 8. Next task

After this contract is merged and the separately authorized `PANTRY-REF-01` reference-data dependency is approved, a separately authorized `PANTRY-02` task may implement the bounded persistence, command/read surface and connected capture/approval UI within the exact limits defined by PANTRY-01.

PANTRY-02 must not silently include Planning Input Readiness or Need Generation changes.
