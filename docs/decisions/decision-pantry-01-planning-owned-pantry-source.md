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
3. School, Delivery Location, Ingredient, Unit and Pantry Purpose use typed database references. Pantry Unit authority is the Ingredient's current `atlas_admin.ingredients.purchase_unit_id` referencing `atlas_admin.units.unit_id`. No conversion or fallback is authorized.
4. `pantry_need_purposes` is a typed Planning catalog. PANTRY-01 does not fix production codes, labels, note rules or seed values, and React does not own the vocabulary.
5. The capture lifecycle is `DRAFT → VALIDATED → APPROVED → REOPENED → VALIDATED → APPROVED`. Approval creates an immutable exact-line snapshot; Pantry has no `RELEASED` state.
6. Pantry approval does not create Confirmed Need or choose fulfilment. Later bounded amendments bind the approved snapshot to Planning Input evaluation and Need Generation; Procurement later selects supplier, Warehouse, mixed or another approved fulfilment source.
7. RMVP-03B remains Planning Input Readiness. PANTRY-02 is the later bounded persistence, command, read-model and connected capture/approval task; Pantry readiness and Need Generation amendments remain separate.
8. PANTRY-02 may propose five private Pantry relations, at most six APIs and at most one new capability while reusing existing Planning runtimes. It adds no runtime role or downstream Planning/Procurement/Warehouse mutation.
9. OPS v1 and Retool are read-only operational evidence. The retained export does not contain a Pantry-labelled tab, so it cannot define Pantry authority, identity, lifecycle or routing.

## Supersession and impact

This decision resolves the TASK-003 Pantry contract gap and supersedes only the deferred Pantry rows in PA-02 section 5.3. It does not change:

- the existing Wholesale Order contract or PA-05D commands;
- merged Weekly Menu or Attendance behavior;
- current Planning Input Readiness persistence;
- current Need Generation persistence;
- Confirmed Need, Procurement, Warehouse or Dispatch contracts;
- hosted Supabase or legacy systems.

## Implementation prohibition

This decision is documentation authority only. Database, API and React implementation requires a separately authorized PANTRY-02 task after this decision and its architecture contract are merged.
