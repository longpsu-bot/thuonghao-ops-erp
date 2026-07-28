# Decision PANTRY-01 — Planning-Owned Pantry Source

**Status:** Accepted  
**Decision date:** 2026-07-28  
**Owner:** Product owner  
**Contract:** [PANTRY-01 — Planning-Owned Pantry Source Contract](../architecture/pantry-01-planning-owned-pantry-source-contract.md)

## Context

OPS v1 records Pantry quantities by service date, School and Ingredient and adds them directly to theoretical-needs projections. The retained Retool and schema exports prove that this workflow exists, but they also combine client-side Unit mapping, destructive deletion and direct calculation coupling.

Atlas already has approved and implemented Weekly Menu, Attendance and direct Wholesale source families. Existing contracts did not safely authorize Pantry persistence or commands. PA-05D expressly limits its pass-through release shortcut to direct Wholesale demand.

## Accepted decisions

### PTRY-01 — Domain ownership

Pantry is a first-class Planning-owned source.

### PTRY-02 — Distinct source family

Pantry is not a Wholesale Order and does not reuse Wholesale record or release commands.

### PTRY-03 — Business meaning

A Pantry line is an additional direct Ingredient need for one School, Delivery Location and service date. It supplements Menu/Recipe demand but does not modify a Recipe.

### PTRY-04 — Aggregate grain

One Pantry batch covers one explicit Monday-start service week. One active stable line exists per batch, service date, School, Delivery Location and Ingredient.

### PTRY-05 — Typed database references

School, Delivery Location, Ingredient, Unit and Pantry Purpose are canonical IDs resolved from typed Supabase relations. React never owns their mappings, labels, lifecycle or display order.

### PTRY-06 — Purpose catalog

Pantry Purpose is a typed Planning catalog. The initial stable codes are `SUPPLEMENTAL_NEED`, `URGENT_OPERATIONAL`, `TEMPORARY_REPLACEMENT` and `OTHER_REVIEWED`. `OTHER_REVIEWED` requires a note.

### PTRY-07 — Lifecycle

The capture lifecycle is `DRAFT → VALIDATED → APPROVED → REOPENED → VALIDATED → APPROVED`. There is no Pantry `RELEASED` state in the capture slice.

### PTRY-08 — Approval meaning

Approval creates an immutable exact-line snapshot and makes that snapshot eligible for later Planning Input evaluation. Approval is not Procurement release, Warehouse reservation or supplier commitment.

### PTRY-09 — Correction

Working corrections preserve stable line identity. Omitted lines become invalid rather than being deleted. Reopening requires a reason and never rewrites a prior approval snapshot.

### PTRY-10 — Downstream calculation

Pantry does not directly create Confirmed Need. A later Planning Input and Need Generation amendment consumes the approved snapshot as a direct Ingredient contribution without Recipe explosion and with direct typed lineage.

### PTRY-11 — Fulfilment routing

Pantry does not decide supplier versus Warehouse fulfilment. Procurement later allocates released requirement quantities to supplier, Warehouse, mixed or another approved source.

### PTRY-12 — RMVP sequencing

RMVP-03B remains Planning Input Readiness. PANTRY-01 does not replace or renumber it. Pantry persistence/UI and Pantry readiness/Need Generation amendments remain separately bounded tasks.

### PTRY-13 — Runtime and API bounds

A later Pantry implementation reuses `atlas_read_runtime` and `atlas_planning_command_runtime`, adds at most one capability (`planning.pantry.write`), adds no runtime role and exposes at most six reviewed Pantry APIs.

### PTRY-14 — Legacy evidence

OPS v1 Retool and SQL are migration and workflow evidence only. Atlas does not copy composite numeric identity, client-side Unit maps, destructive deletion or direct theoretical-view coupling.

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
