# TASK-003 — Source-of-Need Contract Decisions

**Status:** Draft v0.2 decision addendum  
**Parent contract:** `docs/architecture/task-003-source-of-need-contract.md`  
**Scope:** Backend/domain rules only; no migration, SQL, React integration, or production behavior.

This addendum records the working decisions made after reviewing the initial TASK-003 decision checkpoint. These decisions should be folded back into the parent contract before PR #18 is marked ready.

## 1. Approved Decisions

### 1.1 `ConfirmedNeed` is the gate before purchasing

Approved.

Purchase planning must consume `ConfirmedNeed`, not raw menu, attendance, pantry, direct request, or manual UI rows.

```text
PlanningSource
→ CalculatedNeed
→ ConfirmedNeed
→ PurchaseAllocation
```

### 1.2 Direct ingredient requests may bypass recipe/BOM

Approved, but only as controlled source-of-need records.

A direct ingredient request may bypass recipe/BOM when the item is not naturally derived from a dish formula, such as:

- special school request
- extra rice, water, milk, fruit, or packaged item
- one-off event quantity
- operational item not represented in a recipe

Direct requests must still capture requester, purpose, destination, ingredient, quantity, unit, date, and confirmation.

### 1.3 `trace_id` is per confirmed ingredient line

Approved.

Each confirmed ingredient line receives its own `confirmed_need_id` and human-readable `trace_id`.

If several lines originate from the same menu, attendance batch, pantry run, or school request, the shared business context is represented through `source_refs` and, later if needed, a `source_bundle_id` or `planning_batch_id`.

### 1.4 Downstream records should reference `confirmed_need_id`

Approved.

Once `ConfirmedNeed` exists, future downstream records should reference `confirmed_need_id`. Composite business keys must not be the only way to identify an operational need.

Examples:

- `purchase_assignment.confirmed_need_id`
- `purchase_order_line.confirmed_need_id`
- `dispatch_line.confirmed_need_id`
- `receiving_line.confirmed_need_id`
- `exception.confirmed_need_id`

Existing v1 records do not need immediate forced backfill, but new vNext records should follow this rule.

### 1.5 v1 composite-key pain must not be repeated

Approved.

Do not use these as primary operational identity:

```text
service_date + school_id + dish_id + recipe_id + bom_line_id + ingredient_id
```

These fields remain useful as attributes and indexes, but `confirmed_need_id` is the stable operational identity.

## 2. Pantry and Warehouse Fulfilment Decision

### Decision

Pantry requests should be created by Planning, not by Warehouse.

Planning owns the pantry need because pantry demand is part of the same source-of-need layer as menu, attendance, direct requests, and manual adjustments.

### Operating rule

```text
Planning creates pantry need
→ Planning checks available warehouse stock
→ If stock is insufficient, release PO to external supplier
→ If stock is sufficient, release internal fulfilment instruction to Warehouse
```

In the UI, Warehouse may be treated similarly to a supplier for fulfilment routing, but the backend contract should distinguish:

```text
external supplier = purchase source
warehouse stock = internal fulfilment source
```

This prevents accounting and supplier-debt logic from confusing Warehouse with a real supplier later.

### Contract implication

TASK-003 should not implement inventory accounting. However, it must not block future allocation to either:

```text
supply_source_type = external_supplier
supply_source_type = warehouse_stock
```

`ConfirmedNeed` remains the demand object. Later purchase/allocation contracts decide whether the demand is fulfilled by external purchase or internal warehouse stock.

## 3. Reopen vs Purchase Replacement Decision

### Decision

Reopening a confirmed need must be handled carefully because Purchase may replace an ingredient completely after demand confirmation.

A procurement replacement is not always the same as reopening the original demand.

### Demand correction

Use `reopenConfirmedNeed()` when the confirmed demand itself was wrong.

Examples:

- wrong quantity
- wrong school/destination
- wrong service date
- wrong menu/attendance source
- wrong ingredient due to planning or recipe issue

A reopened need must be reconfirmed before new downstream allocation.

### Procurement replacement

If Purchase replaces an ingredient because of supplier availability, price, quality, or operational constraints, the system should create a downstream replacement/revision record linked to the original `confirmed_need_id`.

Examples:

- supplier cannot provide ingredient A and proposes ingredient B
- Purchase replaces one brand/spec with another
- ingredient is substituted before dispatch

This should create an event such as:

```text
purchase_ingredient_replaced
allocation_revised
document_revision_required
```

### Dispatch and Warehouse impact

When a replacement changes the actual item to be dispatched or received, Dispatch and Warehouse must see the replacement clearly before execution.

Future downstream records should be able to carry:

```text
confirmed_need_id
original_ingredient_id
replacement_ingredient_id
replacement_reason
replacement_approved_by
replacement_event_id
```

Released PO, dispatch, and receiving forms must snapshot the replacement state. They must not silently inherit changed ingredient values.

### Approval boundary

If the replacement is an approved procurement equivalent, Purchase may propose it and Planning may confirm it.

If the replacement changes the recipe, dish meaning, food quality, allergen exposure, or customer commitment, it must route back to Planning/BGĐ and may require reopening the confirmed need or creating a new confirmed need.

## 4. Manual Quantity Adjustment Decision

### Decision

Manual adjustments should not require free-text reasons every time.

The current recipe/quantity baseline is not exact enough, and routine quantity changes may be large. Forcing staff to type a reason for every adjustment would create fatigue and low-quality notes.

### Low-friction audit rule

The system should always record:

- actor
- timestamp
- before quantity
- after quantity
- affected `confirmed_need_id` or preview line

But the reason requirement should depend on risk and timing.

### Reason levels

```text
Level 0 — no manual reason required
Routine pre-confirmation quantity entry or correction while building needs.
The system records actor, timestamp, before/after value.

Level 1 — reason category required
Large variance, repeated correction, or adjustment outside normal recipe tolerance.
Use structured reason codes instead of free text where possible.

Level 2 — free-text note required
After confirmation, after PO release, controlled ingredient, high-value item, food-safety concern, supplier substitution, or management override.
```

### Suggested reason codes

```text
recipe_estimate_adjustment
attendance_update
portion_size_adjustment
school_request_change
pantry_stock_check
purchase_replacement
supplier_availability
quality_issue
management_override
other
```

Free text should be optional for routine pre-confirmation work and required only for exception-heavy actions.

## 5. Remaining Open Questions

Before TASK-004 implementation, decide:

1. What variance threshold moves an adjustment from Level 0 to Level 1?
2. Which ingredients or item categories require Level 2 notes?
3. Who can approve procurement replacements: Purchase lead, Planning lead, or BGĐ?
4. Should `source_bundle_id` / `planning_batch_id` exist in TASK-004, or later?
5. How should Warehouse-as-internal-fulfilment appear in the UI without becoming an accounting supplier?

## 6. Effect on Parent Contract

Before PR #18 is ready, fold these decisions into the parent contract:

- pantry requests are Planning-owned
- Warehouse can be a fulfilment source, not an accounting supplier
- ingredient replacement is separate from demand reopening
- manual adjustment reason policy is tiered, not free-text-every-time
- approved decision checkpoint items should move from open questions into explicit rules
