# TASK-003 — Source-of-Need and Confirmed Need Backend Contract

**Status:** Draft v0.1  
**Scope:** Backend/domain contract only  
**Implementation:** No database migration, no SQL, no React integration  
**Related UI baseline:** TASK-002G Atlas source-of-need workflow

## 1. Purpose

TASK-003 defines the backend/domain contract for the source-of-need layer behind Atlas.

The contract answers four ERP questions:

1. Why does this ingredient need exist?
2. What is the official final quantity?
3. Who confirmed it?
4. What downstream work can use it?

Purchase planning must consume `ConfirmedNeed`, not raw menu rows, raw attendance rows, pantry rows, direct request rows, or manual UI values.

The purpose of this document is to define the contract before implementation so Supabase, future React screens, and any Retool support tooling share the same operating model.

## 2. Core Rule

Planning sources explain demand.

Calculated needs estimate demand.

Confirmed needs authorize purchasing.

The long-term backend chain is:

```text
PlanningSource
→ CalculatedNeed
→ ConfirmedNeed
→ PurchaseAllocation
→ ReleasedDocument
→ ReceivingResult
→ Exception / Resolution
```

For TASK-003, only this part is in scope:

```text
PlanningSource
→ CalculatedNeed
→ ConfirmedNeed
```

`confirmNeed()` is the gate before purchase allocation. No purchase allocation should be created from a non-confirmed need.

## 3. Scalability and Key Design Principles

The v1 design made changes difficult because operational identity depended too heavily on composite business keys such as service date, school, dish, ingredient, recipe, and BOM line. TASK-003 avoids repeating this mistake.

### 3.1 Stable Operational Identity

Every confirmed need must have a stable surrogate identity:

- `confirmed_need_id` as UUID primary identity
- `trace_id` as human-readable lineage code

Business dimensions are attributes and indexes, not primary identity.

Examples of business dimensions:

- service date
- recipient or school
- destination
- dish
- recipe
- BOM line
- ingredient
- source type
- delivery requirement
- status

The system must not use a composite business key as the only identity of an operational need.

### 3.2 Business Meaning Is Lineage, Not Identity

The system separates identity from lineage.

`confirmed_need_id` answers:

```text
Which operational need line is this?
```

`source_refs` answers:

```text
Why does this need exist?
```

This separation allows the business explanation to evolve without breaking downstream records.

### 3.3 `effective_line_key` Is Useful but Optional

`effective_line_key` is useful for recipe/BOM-derived needs. It must not be required for every confirmed need.

Direct ingredient requests and pantry needs may not have a natural BOM line.

Therefore:

- `confirmed_need_id` is required
- `effective_line_key` is optional

`effective_line_key` is a lineage and matching attribute for BOM-derived needs, not a universal operational identity.

### 3.4 New Source Types Must Be Additive

Adding future source types should add source records and source references, not redesign purchase, PO, dispatch, receiving, or QA keys.

Possible future source types include:

- `emergency_purchase_request`
- `school_event_extra_meal`
- `menu_substitution`
- `supplier_replacement`
- `quality_hold_replacement`
- `inventory_replenishment`

The downstream model should continue to work as long as the source can produce or modify a `ConfirmedNeed`.

### 3.5 Downstream Records Reference `confirmed_need_id`

Once `ConfirmedNeed` exists, future downstream records should reference `confirmed_need_id`.

Examples:

- `purchase_assignment.confirmed_need_id`
- `purchase_order_line.confirmed_need_id`
- `dispatch_line.confirmed_need_id`
- `receiving_line.confirmed_need_id`
- `exception.confirmed_need_id`

Hard rule:

```text
No downstream table may depend only on a composite business key to identify a need. Downstream records must reference confirmed_need_id once ConfirmedNeed exists.
```

### 3.6 Released Documents Snapshot Facts

Released PO, dispatch, and receiving-form records should snapshot released facts:

- released quantity
- item labels
- supplier
- destination
- delivery requirement
- source or revision version

Later changes to a confirmed need must not silently rewrite already released documents.

Corrections require one of the following explicit actions:

- reopen
- revision
- cancellation
- compensating action

### 3.7 Events Record Important Changes

The first implementation does not need full event sourcing.

It only needs enough event records to explain:

- who changed something
- what changed
- when it changed
- why it changed
- what operational object was affected

## 4. Source Types

Initial source types:

```text
weekly_menu
attendance
recipe_bom
direct_ingredient_request
pantry_need
manual_adjustment
```

Source behavior:

```text
weekly_menu + attendance + recipe_bom
→ calculated ingredient need

direct_ingredient_request
→ direct ingredient need

pantry_need
→ internal / pantry ingredient need

manual_adjustment
→ modifies calculated or direct need
```

`attendance` and `recipe_bom` are source references used to explain menu-derived needs. They are not normally top-level `ConfirmedNeed.source_type` values by themselves.

## 5. ConfirmedNeed Contract

```ts
type ConfirmedNeed = {
  confirmed_need_id: string; // UUID primary identity
  trace_id: string; // human-readable lineage code

  service_date: string;

  recipient_id?: string;
  school_id?: string;
  destination_id?: string;
  destination_label: string;

  source_type:
    | "weekly_menu"
    | "direct_ingredient_request"
    | "pantry_need"
    | "manual_adjustment";

  source_refs: SourceRef[];

  dish_id?: string;
  recipe_id?: string;
  bom_line_id?: string;
  effective_line_key?: string;

  ingredient_id: string;
  purchase_unit: string;
  delivery_requirement?: string;

  calculated_qty: number;
  actual_qty?: number;
  final_qty: number;
  variance_qty: number;

  status:
    | "draft"
    | "needs_review"
    | "confirmed"
    | "reopened"
    | "cancelled";

  reason?: string;
  note?: string;

  entered_by?: string;
  confirmed_by?: string;
  confirmed_at?: string;

  created_at: string;
  updated_at: string;
};
```

### Quantity Meaning

- `calculated_qty`: quantity produced by calculation or source estimate.
- `actual_qty`: hand-entered or operationally adjusted quantity, when available.
- `final_qty`: official quantity approved for downstream purchasing.
- `variance_qty`: `final_qty - calculated_qty`.

### Identity Meaning

- `confirmed_need_id` is the backend identity.
- `trace_id` is the human-readable trace code for review and explanation.
- `effective_line_key` is optional lineage for BOM-derived needs.

## 6. SourceRef Contract

```ts
type SourceRef = {
  source_type:
    | "weekly_menu"
    | "attendance"
    | "recipe_bom"
    | "direct_ingredient_request"
    | "pantry_need"
    | "manual_adjustment";

  source_id?: number | string;
  label: string;
  contribution?: string;
};
```

### Example — Menu + Attendance + Recipe/BOM

```json
{
  "trace_id": "OPS-2026-0714-ND-BIDO-001",
  "source_type": "weekly_menu",
  "source_refs": [
    {
      "source_type": "weekly_menu",
      "label": "Canh bí đỏ · Trường Nguyễn Du · 14/07/2026"
    },
    {
      "source_type": "attendance",
      "label": "320 suất thực tế"
    },
    {
      "source_type": "recipe_bom",
      "label": "Bí đỏ · 0.225 kg/suất"
    }
  ]
}
```

### Example — Direct Ingredient Request

```json
{
  "trace_id": "OPS-2026-0714-MA-GAO-001",
  "source_type": "direct_ingredient_request",
  "source_refs": [
    {
      "source_type": "direct_ingredient_request",
      "label": "Gạo Jasmine · đặt riêng cho Trường Minh Anh",
      "contribution": "120 kg"
    }
  ]
}
```

### Example — Pantry Need

```json
{
  "trace_id": "OPS-2026-0714-PN-DAU-001",
  "source_type": "pantry_need",
  "source_refs": [
    {
      "source_type": "pantry_need",
      "label": "Dầu ăn · bổ sung pantry bếp trung tâm",
      "contribution": "20 lít"
    }
  ]
}
```

### Example — Manual Adjustment

```json
{
  "trace_id": "OPS-2026-0714-ND-BIDO-001",
  "source_type": "weekly_menu",
  "source_refs": [
    {
      "source_type": "weekly_menu",
      "label": "Canh bí đỏ · Trường Nguyễn Du · 14/07/2026"
    },
    {
      "source_type": "attendance",
      "label": "320 suất thực tế"
    },
    {
      "source_type": "recipe_bom",
      "label": "Bí đỏ · 0.225 kg/suất"
    },
    {
      "source_type": "manual_adjustment",
      "label": "Giảm 3 kg theo xác nhận sĩ số thực tế",
      "contribution": "-3 kg"
    }
  ]
}
```

## 7. State Model

Normal flow:

```text
draft
→ needs_review
→ confirmed
→ reopened
→ confirmed
```

Exceptional terminal state:

```text
cancelled
```

State meaning:

| State          | Meaning                                                                        |
| -------------- | ------------------------------------------------------------------------------ |
| `draft`        | Source exists but is not ready for purchasing.                                 |
| `needs_review` | Missing attendance, unknown dish, missing recipe/BOM, missing quantity, or manual issue. |
| `confirmed`    | Official quantity is approved for purchasing.                                  |
| `reopened`     | Previously confirmed line is being corrected.                                  |
| `cancelled`    | Need is no longer valid and must not be purchased.                             |

State rules:

- Purchase allocation may only consume `confirmed` needs.
- Reopening a confirmed need must create an event.
- Cancelling a confirmed need must create an event and must not silently remove downstream history.
- A reopened need must be reconfirmed before new downstream allocation.

## 8. Command Contracts

Initial backend commands:

```ts
syncWeeklyMenuSource(payload)
upsertAttendanceSource(payload)
createDirectIngredientRequest(payload)
generatePantryNeeds(payload)

previewCalculatedNeeds(params)

upsertActualNeedOverride(payload)
confirmNeed(payload)
reopenConfirmedNeed(payload)
cancelConfirmedNeed(payload)
```

Boundary rule:

```text
confirmNeed() is the gate before purchase allocation.
```

No purchase allocation should be created from a non-confirmed need.

### Command Responsibility

| Command                           | Responsibility                                                              |
| --------------------------------- | --------------------------------------------------------------------------- |
| `syncWeeklyMenuSource`            | Imports or synchronizes menu source facts.                                  |
| `upsertAttendanceSource`          | Creates or updates attendance / portion source facts.                       |
| `createDirectIngredientRequest`   | Creates a direct ingredient request that can become a confirmed need.       |
| `generatePantryNeeds`             | Creates pantry/internal ingredient needs for confirmation.                  |
| `previewCalculatedNeeds`          | Shows calculated needs before confirmation; must not authorize purchasing.  |
| `upsertActualNeedOverride`        | Applies manual quantity correction with reason and traceability.            |
| `confirmNeed`                     | Approves final quantity for purchasing.                                     |
| `reopenConfirmedNeed`             | Reopens a confirmed need for correction.                                    |
| `cancelConfirmedNeed`             | Cancels a need that is no longer valid.                                     |

## 9. Event Contracts

Every important command should emit an event.

Initial event types:

```text
planning_source_synced
attendance_source_upserted
direct_request_created
pantry_need_generated
calculated_need_previewed
actual_need_overridden
need_confirmed
need_reopened
need_cancelled
```

Event shape:

```ts
type OpsEvent = {
  event_id: string;
  event_type: string;

  trace_id?: string;

  entity_type: string;
  entity_id: string;

  actor_id?: string;
  actor_email?: string;

  occurred_at: string;
  reason?: string;

  before?: unknown;
  after?: unknown;
};
```

Event requirements:

- Events must identify the affected entity.
- Events must record actor and timestamp when available.
- Quantity changes must include reason.
- Reopen and cancellation must be visible in event history.
- Events are audit support for operational traceability; they are not a full event-sourcing design in TASK-003.

## 10. UI Read Models

Future React Atlas screens should read from backend views or APIs rather than reconstructing business logic in React.

For TASK-003, the first read models are:

```text
v_planning_sources_queue
v_confirmed_needs_workbench
v_need_lineage_explainer
```

Later downstream contracts may need:

```text
v_purchase_allocation_queue
v_release_reconciliation
v_receiving_exception_queue
```

Read-model responsibilities:

| Read model                     | Responsibility                                                        |
| ------------------------------ | --------------------------------------------------------------------- |
| `v_planning_sources_queue`     | Shows source rows, source status, owner, blocker, and readiness.      |
| `v_confirmed_needs_workbench`  | Shows calculated, actual, variance, final quantity, status, and gate. |
| `v_need_lineage_explainer`     | Explains where a need came from and what changed.                     |

## 11. Supabase Reuse and Gap Map

Existing concepts likely to be reused or adapted:

- `daily_orders` / `daily_order_dishes`
- `recipes` / `bill_of_materials`
- `actual_need_overrides`
- `v_actual_needs_effective_live` or equivalent actual-needs view
- `purchase_assignments`
- `purchase_orders` / `purchase_order_lines`
- `dispatch_headers` / `dispatch_lines`
- audit or release events, if available

Known gaps:

- no explicit `confirmed_needs` snapshot table yet
- no explicit `confirmed_need_source_refs` lineage table yet
- no unified `ops_events` table yet
- pantry and direct request need clearer authoritative contracts
- downstream records do not yet consistently reference `confirmed_need_id`

## 12. First Implementation Slice

The first backend implementation should stay small:

```text
confirmed_needs
confirmed_need_source_refs
ops_events
```

The first slice should define:

1. stable `ConfirmedNeed` identity
2. source lineage storage
3. minimal event recording
4. `confirmNeed()` behavior
5. `reopenConfirmedNeed()` behavior
6. confirmed-needs read model

Do not build broader ERP functionality in this slice.

## 13. Deferred Scope

Explicitly out of scope for TASK-003:

- inventory accounting
- driver confirmation
- school/kitchen confirmation
- QA workflow
- payment
- invoice reconciliation
- real document generation
- supplier debt
- full purchase-order lifecycle
- React-to-Supabase integration
- replacing Retool immediately
- production data changes

## 14. Decision Checkpoint

Before implementation, answer these business questions:

1. Is `ConfirmedNeed` the correct gate before purchasing?
2. Can a direct ingredient request bypass recipe/BOM?
3. Can pantry needs be confirmed by Kho, or must Kế hoạch confirm them?
4. Who can reopen a confirmed need?
5. What happens if a need changes after PO is released?
6. Should manual adjustments require reason every time?
7. Should `trace_id` be generated per ingredient line or per source bundle?
8. Should downstream documents reference `confirmed_need_id` from the first implementation slice?
9. Which v1 keys caused the most pain and must not be repeated?

## 15. Acceptance Criteria for This Contract

This contract is acceptable when it clearly defines:

- why `ConfirmedNeed` exists
- how source-of-need lineage is represented
- why stable surrogate identity is required
- how `effective_line_key` remains useful but optional
- which commands and events are expected
- which read models future UI needs
- what existing Supabase concepts can be reused
- what is deliberately out of scope

No migration, SQL, backend command, or UI implementation is required for TASK-003 v0.1.
