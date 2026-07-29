# Decision PANTRY-REF-01 — Pantry Reference Data

- **Status:** Accepted
- **Decision date:** 2026-07-28
- **Owner:** Product owner
- **Detailed authority:** [PANTRY-REF-01 Reference-Data Contract and Readiness Gate](../architecture/pantry-ref-01-reference-data-contract.md)
- **Parent decision:** [Decision PANTRY-01](decision-pantry-01-planning-owned-pantry-source.md)

## Context

PANTRY-01 requires one typed Pantry Purpose on every positive active Pantry
line and requires School, Delivery Location, Ingredient, and Ingredient
purchase-Unit identities to remain backend-authoritative.

The retained Pantry evidence shows School and Ingredient selection, quantity
and note editing, and Ingredient-derived purchase-Unit display. It does not
establish a stable production Purpose vocabulary, Purpose note rules, or a
broader School/location relationship.

PANTRY-02 must not invent those product decisions while implementing
persistence or React behavior.

## Accepted decisions

1. The architecture contract owns the sole complete accepted Pantry Purpose
   registry. It defines two active, note-required Purposes:
   School-requested supplement and Planning-identified supplement.
2. Purpose codes are stable lowercase identifiers unrelated to legacy numeric
   IDs. Status, operator label, description, display order, and note rule are
   authoritative catalog facts returned by Supabase, not React constants.
3. Only an active Purpose satisfying its current note rule is selectable for a
   positive active Pantry line. Historical approval snapshots retain the exact
   approved Purpose meaning.
4. A selectable School is an active typed Atlas School under an active
   `SCHOOL_CATERING` Customer and is authorized for the caller's existing
   scope.
5. A selectable Delivery Location is active, same-customer, authorized, and,
   on the current approved schema, exactly the School's authoritative default
   delivery location. Callers cannot author a School/location relationship.
6. A selectable Ingredient is an active existing Atlas Ingredient with a
   non-null `purchase_unit_id` resolving to an active Unit.
7. Unit authority remains
   `atlas_admin.ingredients.purchase_unit_id → atlas_admin.units.unit_id`.
   The operator does not select a Unit, and React does not submit or map
   authoritative Unit identity.
8. Supplier eligibility and Warehouse stock availability are not required to
   record Pantry demand. Procurement later chooses fulfilment.
9. `no_additions_confirmed = true` remains batch-level controlled absence. A
   valid zero-line approval has no Purpose and no zero-quantity line.
10. PANTRY-REF-01 changes no data or implementation. PANTRY-02 remains limited
    to exactly five private Pantry relations, at most six APIs, at most one new
    capability, zero new roles including runtime roles, and one bounded
    migration reusing existing Planning runtimes.

## Product approval record

On 2026-07-28, the Product Owner explicitly approved both proposed Pantry
Purpose rows and `PREF-A01` through `PREF-A09` exactly as proposed. That
approval accepts the complete canonical registry, note rules, prohibited
interpretations, reference-readiness gates, and zero-additions boundary
recorded by the architecture contract.

The approval is documentation authority only. PANTRY-02 must not begin before
this contract is merged and PANTRY-02 is separately authorized.

## Consequences

- PANTRY-02 receives an exact, database-driven Purpose and reference-readiness
  contract without gaining new scope.
- Invalid or stale references fail closed in future Pantry reads and commands.
- Purpose deactivation or master-data changes do not rewrite historical Pantry
  snapshots.
- The exact production seed, hosted deployment, and production-data action
  remain separate decisions.

## Implementation prohibition

This decision authorizes no SQL, migration, seed row, React change, API,
capability, role, RLS policy, grant, hosted resource, production mutation,
credential, OPS v1/v2 change, Retool change, Planning Input change, Need
Generation change, or PANTRY-02 work.
