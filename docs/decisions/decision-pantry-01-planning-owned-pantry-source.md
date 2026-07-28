# Decision PANTRY-01 — Planning-Owned Pantry Source

- **Status:** Accepted
- **Decision date:** 2026-07-28
- **Owner:** Product owner
- **Detailed authority:** [PANTRY-01 — Planning-Owned Pantry Source Contract](../architecture/pantry-01-planning-owned-pantry-source-contract.md)

## Context

OPS v1 records Pantry quantities by service date, School and Ingredient and adds them directly to theoretical-needs projections. The retained Retool and schema exports prove that this workflow exists, but they also combine client-side Unit mapping, destructive deletion and direct calculation coupling.

Atlas already has approved and implemented Weekly Menu, Attendance and direct Wholesale source families. Existing contracts did not safely authorize Pantry persistence or commands. PA-05D expressly limits its pass-through release shortcut to direct Wholesale demand.

## Accepted decisions

1. Pantry is a first-class Planning-owned source, distinct from Wholesale, Warehouse stock actions, Recipe/BOM overrides and downstream commitments.
2. One Pantry batch covers one explicit Monday-start week. One stable line represents batch, service date, School, Delivery Location and Ingredient; working corrections preserve that identity.
3. A batch may approve an exact zero-line snapshot only with `no_additions_confirmed = true`. The flag is false when active lines exist. A zero-line snapshot is explicit controlled absence evidence, not a zero-quantity line; every persisted line still requires a positive quantity.
4. School, Delivery Location, Ingredient, Unit and Pantry Purpose use typed database references. The backend, not React or the caller, resolves Pantry Unit authority through the Ingredient's current `atlas_admin.ingredients.purchase_unit_id` to an active `atlas_admin.units.unit_id`. Missing, inactive or stale authority blocks the command; no conversion, fallback or caller override is authorized.
5. `pantry_need_purposes` is a typed Planning catalog. PANTRY-01 does not fix production codes, labels, note rules or seed values, and React does not own the vocabulary.
6. The capture lifecycle is `DRAFT → VALIDATED → APPROVED → REOPENED → VALIDATED → APPROVED`. Approval creates an immutable exact snapshot header and every-and-only active line set, including the valid empty set for an explicit no-additions confirmation; Pantry has no `RELEASED` state.
7. Pantry approval does not create Confirmed Need or choose fulfilment. Later bounded amendments bind the approved snapshot to Planning Input evaluation and Need Generation; Procurement later selects supplier, Warehouse, mixed or another approved fulfilment source.
8. RMVP-03B remains Planning Input Readiness. PANTRY-02 is the later bounded persistence, command, read-model and connected capture/approval task; Pantry readiness and Need Generation amendments remain separate.
9. PANTRY-REF-01 is the mandatory reference-data dependency before PANTRY-02. It separately approves the initial Pantry Purpose vocabulary and reference-readiness criteria without changing the PANTRY-02 limit of five private Pantry relations, at most six APIs, at most one new capability and zero new roles, including runtime roles.
10. PANTRY-02 reuses existing Planning runtimes and adds no downstream Planning/Procurement/Warehouse mutation.
11. OPS v1 and Retool are read-only operational evidence. The February JSON at SHA-256 `064D74570F1CA06CD95FF2E46D07F372717ED113B7EFD16B68BFFEEE3D51ED3B` does not contain the reviewed Pantry-labelled objects; the separate `OPS - Lên đơn, Đặt hàng (1)` export, identified by JSON SHA-256 `6F6FF8D025696D375F354A86126661D20C3E9908D6475D40ECB14EE006B4A371` and decomposed ZIP SHA-256 `728611082382E9146C9456910E6D334B9B8135BD1A1BBEAC4D9C3476BB12C18F`, contains Pantry-specific components, queries and tab-key logic. Neither export defines Atlas authority, identity, lifecycle, Unit authority, approval or routing.

## Supersession and impact

This decision resolves the TASK-003 Pantry contract gap and supersedes only the deferred Pantry rows in PA-02 section 5.3. It does not change:

- the existing Wholesale Order contract or PA-05D commands;
- merged Weekly Menu or Attendance behavior;
- current Planning Input Readiness persistence;
- current Need Generation persistence;
- Confirmed Need, Procurement, Warehouse or Dispatch contracts;
- the RMVP-03B Planning Input Readiness designation;
- the five-relation, six-API, one-capability and zero-new-role PANTRY-02 limits;
- hosted Supabase or legacy systems.

## Implementation prohibition

This decision is documentation authority only. Database, API and React implementation requires the separately authorized PANTRY-REF-01 dependency to be approved and a separately authorized PANTRY-02 task after this decision and its architecture contract are merged.
