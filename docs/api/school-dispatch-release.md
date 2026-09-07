# School Dispatch Release API Contract

**Contract:** `SCHOOL-DISPATCH-RELEASE.v1`

**Decision:** [D-044](../decisions/decision-ops-v1-school-fulfilment-closeout.md)

**Domain:** Dispatch

**Operational recipient:** School

**Document grain:** service date + School + delivery location

## Boundary

This contract implements the minimum School/day `PHIẾU XUẤT KHO` capability. It is
separate from the historical supplier-direct DispatchPlan/Trip pipeline and does not
represent Warehouse stock movement.

## API registry

| Function                                                 | Kind                  | Capability                        | Purpose                                                                                                        |
| -------------------------------------------------------- | --------------------- | --------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `atlas_api.get_school_dispatch_release_workbench(jsonb)` | Shaped read           | `dispatch.school_release.read`    | Derive School/date readiness, read-only preview, exact currentness, immutable current release, and history.    |
| `atlas_api.release_school_dispatch_document(jsonb)`      | Transactional command | `dispatch.school_release.release` | Explicitly create one immutable official PXK or successor and atomically supersede its predecessor when given. |

Both functions revoke execution from public, anon, and service-role. Only
`authenticated` can execute them. Browser roles have no direct grants on private
PXK relations.

## Workbench read

Request:

```json
{
  "contract_version": "SCHOOL-DISPATCH-RELEASE.v1",
  "requested_by_auth_subject": "uuid",
  "correlation_id": "uuid",
  "payload": {
    "date_start": "YYYY-MM-DD",
    "date_end": "YYYY-MM-DD",
    "school_ids": ["uuid"],
    "search": null
  }
}
```

The inclusive range is at most 31 days. The response contains rows at the exact
document grain with state `READY | CURRENT | REPLACEMENT_REQUIRED | BLOCKED`,
expected version, derived preview, current release, complete immutable history,
allowed actions, warnings, and blockers.

Preview creates no durable row. Its SHA-256 fingerprint covers exact Confirmed Need
revision and decision, Allocation Family revision/contribution/split, released PO
root/revision/line, covered quantity, Ingredient, Unit, School, date, and location.
When one Allocation Family spans multiple Schools or suppliers, deterministic
contribution/supplier ranges assign exact covered quantities without rounded-ratio
residuals; both School contribution totals and supplier split totals remain
reconcilable.

## Release command

The standard command envelope requires:

- `reason_code = SCHOOL_DISPATCH_DOCUMENT_RELEASED`;
- optional `reason_note`, normalized and limited to 500 characters, which is frozen
  into the released document snapshot and included in later exports;
- `expected_version` (`0` for first release, current version for replacement);
- payload `service_date`, `school_id`, `delivery_location_id`,
  `expected_source_fingerprint`, and nullable `predecessor_release_id`.

The backend resolves and authorizes the Actor, validates School/location scope,
begins the idempotent receipt, obtains the School/date/location advisory lock and
shared upstream source locks, reloads current release and preview, and rejects stale
version, predecessor, fingerprint, or readiness.

Success creates one official server-numbered `RELEASED` header, immutable lines and
typed sources, one domain event and one audit event. If a predecessor exists, it is
changed only from `RELEASED` to `SUPERSEDED` inside the same successful transaction.
The predecessor remains exportable with identical number, lines, snapshots, and
lineage. There is no Draft PXK lifecycle.

## Readiness and blockers

Release requires current applicable released Confirmed Need, current explicitly
saved balanced Allocation Families, and every exact supplier split covered by a
current released School-catering PO. `CANCELLATION_REQUIRED` blocks release when a
former supplier commitment remains active after its allocation becomes zero.

Closed blocker codes are:

- `SCHOOL_SCOPE_INVALID`;
- `NO_CURRENT_NEED`;
- `PO_COVERAGE_INCOMPLETE`;
- `PROCUREMENT_NOT_CURRENT`;
- `CANCELLATION_REQUIRED`.

No readiness SQL reads or requires receipt, inventory, stock, lot, balance,
reservation, pick, cross-dock, DispatchPlan, trip, vehicle, driver, or load facts.

## Persistence and security

Private forced-RLS relations:

- `atlas_dispatch.school_dispatch_releases`;
- `atlas_dispatch.school_dispatch_release_lines`;
- `atlas_dispatch.school_dispatch_release_line_sources`.

The read is owned by the existing read runtime; the command is owned by the existing
Dispatch command runtime. A narrow Procurement-runtime helper obtains shared locks
on the upstream allocation/PO rows without granting Dispatch mutation authority.
All public security-definer functions use an empty `search_path` and fully qualified
objects.

## Rollback

Rollback is forward-only. A later migration may revoke the two entry points while
retaining all released documents, numbers, immutable lines, lineage, receipts,
events, and audit evidence.
