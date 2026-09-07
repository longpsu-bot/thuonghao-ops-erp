# OPS v1 School Fulfilment Closeout Design

**Status:** Approved for implementation

**Date:** 2026-09-07

**Architecture authority:** OPS_SYSTEM_MAP v1.0 / ARCH-002

**Repository baseline:** `origin/main` at `606009b6d9afa590a202974394194dd26d44926a`

**Scope:** Direct Ingredient Need convergence, append-only Confirmed Need correction,
School-catering supplier-PO replacement, and School/date Phiếu xuất kho release.

**Out of scope:** stock, receiving, lots, reservations, picking, trips, vehicles,
drivers, delivery proof, supplier-cancellation execution, generic workflow/source
registries, hosted deployment, and OPS v1 or Retool mutation.

## 1. Executive decision

The bounded closeout path is:

```text
School need facts
  = recipe-derived contributions
  + additive direct Ingredient contributions
  or one complete direct School/date list
→ Confirmed Need
→ explicitly saved supplier allocation
→ released supplier commitment
→ explicitly released School/date/location PXK
```

The governing rule is:

> FACTS EXPLICIT — STATE DERIVED — SUPPORTING OBJECTS GENERATED.

A downstream commitment freezes its own historical snapshot, not upstream reality.
Confirmed Need successors remain permissible after a supplier PO or PXK is released.
Atlas derives which downstream objects are stale or require replacement and requires
explicit operator actions before a new external commitment becomes current.

## 2. Direct Ingredient Need authority

### 2.1 Common source

The existing Pantry aggregate remains the one direct-Ingredient input source. A line
continues to record the exact School, service date, delivery location, Ingredient,
controlled Unit, quantity, Purpose, and optional note. The existing
`PANTRY_DIRECT` Need Generation lineage remains authoritative.

Purpose explains why an Ingredient was entered directly. Purpose does not decide
whether Recipe/Menu/Attendance contributes for the same School/date.

### 2.2 Additive versus complete

Add one closed fact at `Pantry batch + School + service date`:

- `ADDITIVE`: direct lines coexist with Recipe-derived demand;
- `COMPLETE`: direct lines are the complete Need for that School/date and Recipe,
  Menu, and Attendance are neither required nor fabricated.

This is the smallest correct grain because one Pantry batch can cover multiple
Schools and dates, and the same School can be catering-derived on one date and
direct-complete on another. A line-level mode would permit contradictory modes for
one operational scope, while Purpose is explanation rather than routing authority.

New consequential saves with positive direct lines must persist exactly one mode for
every represented School/date. Approval snapshots copy the mode immutably. Existing
historical snapshots with no mode remain valid and are interpreted as `ADDITIVE`;
they are not rewritten or backfilled into invented facts.

The existing explicit no-additions fact remains available for catering readiness.
Atlas does not require a separate “no wholesale order” fact.

### 2.3 Need Generation composition

Need Generation composes authoritative School sources:

```text
ADDITIVE scope: RECIPE_DERIVED + PANTRY_DIRECT
COMPLETE scope: PANTRY_DIRECT only
```

For `COMPLETE`, Recipe contributions for that exact School/date are suppressed and
Menu/Attendance snapshot references may be absent under a database-enforced closed
condition. No placeholder source rows are created. Fingerprints and currentness
include the persisted mode and exact approved Pantry snapshot evidence.

School remains the operational recipient. Any compatibility `customer_id` is
resolved and validated from the School by the backend; it is not a second
operator-selected recipient.

## 3. Confirmed Need correction after commitment

Confirmed Need remains append-only:

- a legitimate correction creates a successor revision/decision;
- the old revision, decision, approval, release, and downstream evidence remain
  immutable;
- the current applicable Confirmed Need is derived from the successor chain;
- released School-catering POs or PXKs do not block the successor fact;
- existing wholesale/supplier-direct guards remain unchanged unless their exact
  contract is explicitly amended.

`BLOCKED_BY_DOWNSTREAM_COMMITMENT` protects immutable downstream content from
destructive rewrite. It does not freeze upstream reality.

Allocation currentness compares its complete exact Confirmed Need contribution set
and fingerprint with the currently applicable released Confirmed Need set. A source
change makes the prior allocation stale. Atlas may derive a ratio-preserving
proposal, but only an explicit allocation Save creates the new authoritative
revision.

## 4. Supplier PO replacement

### 4.1 Exact impact

The supplier commitment fingerprint covers the complete current School delivery
instructions for one supplier/date, including School, delivery location, Ingredient,
Unit, quantity, exact Confirmed Need revision/decision lineage, allocation revision,
and supplier split. Therefore a `+10/-10` redistribution between Schools requires a
replacement even when the supplier total is unchanged.

Only supplier/date commitments whose exact membership changes are affected.

### 4.2 Separate replacement root

A released PO is never edited. Once the revised allocation is explicitly saved,
Atlas may generate a complete replacement `DRAFT` root with direct
`replaces_purchase_order_id` lineage. While that draft exists:

- the old PO remains `RELEASED_TO_SUPPLIER` and externally active;
- the draft has no official document number;
- both histories are visible and their immutable revisions are retained.

Explicit replacement release atomically:

1. rechecks current allocation and complete fingerprint;
2. locks the replacement and replaced roots;
3. assigns a new server-generated official number;
4. releases the replacement;
5. marks the replaced root `SUPERSEDED`;
6. records receipt, event, and audit evidence.

Idempotent replay returns the original outcome; changed intent conflicts.

### 4.3 Removed-supplier safety boundary

If a supplier's current allocation becomes zero:

- Confirmed Need correction and revised allocation Save remain allowed;
- the old released PO remains immutable and externally active;
- Atlas derives `CANCELLATION_REQUIRED` for that supplier commitment;
- Atlas creates no zero-line PO and performs no implicit cancellation or
  supersession;
- replacement drafts may be generated for suppliers retaining positive allocation;
- Procurement is not current, and PXK release is blocked, until the removed-supplier
  commitment has been resolved by a later approved cancellation policy.

Existing `CANCELLED` or `CANCELLATION` vocabulary is not sufficient business
authority. This change deliberately introduces no cancellation command.

## 5. School PXK release

### 5.1 Bounded aggregate

Add a School release aggregate in `atlas_dispatch`, separate from historical
DispatchPlan/Trip execution:

- `school_dispatch_releases`: immutable released header/snapshots, status
  `RELEASED | SUPERSEDED`, official number, source fingerprint, predecessor, actor,
  command, and version;
- `school_dispatch_release_lines`: immutable Ingredient/Unit/quantity and display
  snapshots;
- typed lineage linking each line to exact Confirmed Need, allocation, supplier
  split, and released PO revision/line coverage.

The grain is `service_date + school_id + delivery_location_id`. The PXK is a School
document and is not split merely because multiple suppliers cover its Ingredients.

### 5.2 Readiness and release

Preview is derived and writes nothing. Release is permitted only when the backend
rechecks:

- current applicable released Confirmed Need;
- current explicitly saved balanced allocation;
- complete current released supplier-PO coverage;
- no unresolved removed-supplier commitment;
- expected preview fingerprint/version and actor capability/scope.

Release atomically creates the immutable header, lines, lineage, official number,
receipt, event, and audit evidence. No normal PXK draft lifecycle exists.

Released PXKs remain immutable and exportable. If the exact current fingerprint
changes, preview derives replacement-required. Explicit successor release creates a
new official document and atomically marks the prior release `SUPERSEDED`. Until that
action, the prior PXK remains the current released document.

PXK readiness does not inspect or require receipt, stock, lot, balance, reservation,
pick, cross-dock, Dispatch Plan, trip, vehicle, driver, or load facts.

### 5.3 Application

Add `Kho → Phiếu xuất kho` with date/range and School filters, backend-derived
readiness, read-only preview, explicit release, immutable history, and export titled
`PHIẾU XUẤT KHO`. Export includes official number, service date, School, delivery
location, Ingredient, exact quantity, Unit, immutable display snapshots, and note.

## 6. Security and transactions

New relations are private with RLS enabled and forced. Browser roles receive no
direct relation or sequence access. Public APIs use authenticated Actor resolution,
least-privilege runtimes, capability checks, fixed empty `search_path`, fully
qualified SQL, deterministic locks, optimistic versions/fingerprints, idempotency,
safe errors, command receipts, domain events, and audit evidence.

Use existing capabilities where semantically exact. Add only bounded PXK read and
release capabilities when the registry has no equivalent. No service-role
credential is introduced into React.

## 7. Forward compatibility and amendments

This decision forward-amends, without rewriting historical documents:

- Pantry's earlier additive-only interpretation: historical absence means
  `ADDITIVE`; new School/date mode can be `COMPLETE`;
- Need Generation's all-three-source requirement: it remains for catering-derived
  scopes, while exact direct-complete scopes require only approved Pantry evidence;
- the downstream commitment guard: released School-catering commitments freeze
  themselves, not later upstream successor facts.

Historical wholesale APIs and old DispatchPlan/Trip APIs remain physically
available for compatibility but are not normal new Application paths.

## 8. Migration and rollback effects

Migrations are forward-only. Rollback is a later forward migration that disables new
application entry points while retaining immutable evidence; released documents and
lineage must not be deleted. No Atlas Staging backfill or deployment is authorized.

## 9. Stop conditions retained

Stop rather than broaden this design if implementation requires a non-School
recipient redesign, immutable-history rewrite, released-content mutation, generic
provenance machinery, stock facts, actual inventory management, or hosted/live
mutation.
