# Decision — PA-05B-H3 Bounded Successful Trip Closure

**Status:** Approved; implementation pending review and merge of the prerequisite package

## Decision

Atlas will add one bounded Dispatch command:

```sql
atlas_api.close_successful_trip(request jsonb)
```

The command will finalize one fully delivered and fully reconciled Dispatch Trip by setting `completed_at`, incrementing the trip version once, and emitting `SuccessfulDispatchTripClosed` plus one audit event.

The reviewed Atlas API surface will increase from 17 to exactly 18 functions.

## Rationale

Successful delivery and successful trip closure are related but distinct business facts.

```text
Delivery confirmation
→ proves destination outcome for one stop and its load lines

Trip closure
→ proves the entire trip has no remaining unresolved transport obligation
```

Keeping closure as an explicit command preserves the approved PA-05A command catalog and allows PA-05G to remain acceptance-only rather than quietly adding a missing write path.

## Ownership

- Planning continues to own requirement, quantity, destination, date, and release lineage.
- Procurement continues to own allocation and supplier commitment.
- Evidence continues to own source proof and applications.
- Dispatch owns trip execution, delivery outcome, and trip closure.

Closure reads and locks upstream and Dispatch lineage but mutates only the selected Dispatch Trip.

## Runtime decision

Reuse `atlas_dispatch_command_runtime`.

Do not create another runtime role. The role already owns the bounded Dispatch setup and execution functions and is the correct owner for the closure command.

## Closure state

The command requires:

- current trip status `DELIVERED`;
- non-null departure time;
- null existing completion time;
- every stop `DELIVERED`;
- exact successful confirmation of every current load line;
- no missing, extra, duplicate, cross-wired, returned, excepted, or unresolved child fact.

On success:

- preserve `trip_status = DELIVERED`;
- set `completed_at`;
- increment the trip version once.

No new `COMPLETED` status is introduced because the existing schema already distinguishes delivery status from the completion timestamp.

## Rejected alternatives

### Treat `DELIVERED` as implicit closure

Rejected because it leaves the approved closure command absent, leaves `completed_at` unset, and prevents a distinct audited finalization decision.

### Fold closure into `confirm_successful_delivery`

Rejected because the final stop command should not silently close an entire trip or assume that all concurrent stop and load facts remain reconciled without an explicit trip-wide check.

### Add closure inside PA-05G

Rejected because PA-05G is an acceptance task, not a hidden business-command implementation task.

### Add a generic lifecycle/state-machine framework

Rejected as unnecessary for one bounded command.

### Add exception/return closure now

Rejected. PA-05B-H3 covers successful closure only. Exception, return, cancellation, reopening, and plan closure remain separately approved future work.

### Add a new runtime role

Rejected. Closure is Dispatch-owned and fits the existing hardened Dispatch runtime.

## Consequences

- PA-05G can validate a fully command-authored source-to-closure path.
- The API count becomes 18.
- The command must independently prove trip-wide child cardinality and reconciliation rather than relying only on statuses.
- The closure timestamp becomes an authoritative audited fact.
- No UI, read API, deployment, Retool, OPS v1, Warehouse, Finance, or broader workflow behavior is introduced.
