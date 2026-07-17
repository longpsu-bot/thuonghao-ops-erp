# PA-06A — Screen, Workbench, and Input/Output Map

**Status:** Proposed documentation contract; pending review
**Canonical API registry:** [PA-06A Application Connection Contract](../architecture/pa-06a-application-connection-contract.md#6-canonical-atlas-api-registry)
**Formal read-gap register owner:** This document

## 1. Exact frontend and prototype artifacts

PA-06A reviewed these exact current paths:

- `src/modules/atlas/atlasConfig.ts` — current page and navigation configuration;
- `src/modules/atlas/AtlasApp.tsx` — current React shell and local page switching;
- `src/modules/atlas/WorkbenchComponents.tsx` — current shared `Chip`, `CompactTable`, `ActionBar`, `TracePanel`, `PageShell`, and `Panel` primitives;
- `package.json` — React/React DOM runtime dependency baseline; no Supabase client;
- `docs/ui/atlas-workbench-requirements.md` — active local-fixture workbench requirements;
- `docs/ui/atlas-three-stage-workflow.md` — explicitly superseded note.

The active requirements describe one control board plus five daily work pages. Therefore “five-page prototype document” is not a unique literal title and should be understood as shorthand only after this path reconciliation.

## 2. Application structure decision

PA-06 should prefer a small number of coherent workbenches, not one page per API function.

Proposed connected workbenches:

1. Planning Source & Release;
2. Procurement Commitment;
3. Supplier Evidence & Readiness;
4. Dispatch Setup;
5. Dispatch Execution;
6. a shared Trace & Audit panel.

These are application responsibilities, not permission to build production queues. Each workbench starts from known authorized context unless the read-gap register explicitly says otherwise.

## 3. Interaction types

| Interaction type | Purpose | Required visible information | Authority boundary |
|---|---|---|---|
| Work queue | Discover which objects need attention | bounded object reference, status, owner, date/scope, next action | Requires an approved discovery read; no current global queue exists |
| Detail view | Review one known authoritative context | public references, opaque IDs, quantities, versions, status, lineage | Approved read or preceding command response only |
| Action form | Collect allowlisted operator input | target object/version, editable fields, read-only authoritative fields | Client validates form shape; backend decides outcome |
| Confirmation | Prevent unintended authoritative action | command purpose, affected object, expected transition, exact quantity/unit/date/supplier/destination summary | No business approval is inferred from UI confirmation |
| Outcome | Explain what the backend accepted | safe message, IDs, versions, events, audit, warnings, blockers, replay/retry classification | Command response is authoritative |
| Trace/history | Explain source and command evidence | source references, lineage IDs, receipt, events, audit actors/times | READ-01 and READ-04 only |

## 4. Workbench map

### 4.1 Planning Source & Release

- **Primary operator:** Planning coordinator / release controller.
- **Business objects:** Wholesale Order, Confirmed Need Batch, Purchase Handoff, Dispatch Requirement.
- **Commands:** CMD-01 through CMD-04.
- **Reads:** READ-04 when command/correlation/aggregate IDs are known; READ-01 only after completed downstream trace.
- **Input categories:** customer/location context, reference, service date, item lines, reasons, confirmation.
- **Output/state:** each root/revision/line ID, lifecycle status, returned versions, event/audit IDs.
- **Client versions:** Wholesale Order, Confirmed Need, Purchase Handoff, Dispatch Requirement as returned.
- **Loading:** disable duplicate submit while retaining immutable intent.
- **Empty:** distinguish no known context from an unsupported queue.
- **Error:** field errors remain beside inputs; safe command error appears in outcome.
- **Conflict/retry:** stale requires refresh/new intent; retryable allows exact retry.
- **Confirmation:** required for each release command.
- **Audit access:** command/correlation/aggregate link to READ-04.
- **Production entry limitation:** customer/location/item discovery and Draft/released source queues require a bounded discovery read.

### 4.2 Procurement Commitment

- **Primary operator:** Buyer.
- **Business objects:** Fulfilment Allocation and Purchase Order.
- **Commands:** CMD-05 and CMD-06 only.
- **Reads:** READ-04; later readiness reads once Evidence exists.
- **Input categories:** known requirement lines, supplier assignment, immutable quantity/unit, document number, reason.
- **Output/state:** allocation and PO roots/revisions/lines, returned versions, event/audit IDs.
- **Client versions:** requirement version then allocation version.
- **Loading/empty/error/conflict:** same command outcome contract as Planning.
- **Confirmation:** supplier, document number, line set, destination, and date.
- **Unsupported prototype actions:** no validate allocation, approve allocation, PO draft, validate PO, supplier confirmation, amend, reopen, or cancel commands exist.

### 4.3 Supplier Evidence & Readiness

- **Primary operator:** Evidence / receiving clerk, with Dispatch visibility.
- **Business objects:** Supplier Receiving Evidence and Evidence Application.
- **Commands:** CMD-07 and CMD-08.
- **Reads:** READ-02, READ-03, READ-04; READ-01 after completion.
- **Input categories:** known PO-line and allocation-line context, Evidence reference, quantity, unit, occurrence time, reason.
- **Output/state:** Evidence/Application IDs, guarded PO/allocation versions, per-line readiness, blockers, audit history.
- **Client versions:** current Purchase Order and Fulfilment Allocation versions.
- **Loading:** show which immutable request is in flight.
- **Empty:** “No selected Evidence context” is distinct from “no work.”
- **Error:** show duplicate reference, mismatch, over-application, stale, denied, and safe internal failure separately.
- **Conflict/retry:** stale stops; exact retry preserves the original request.
- **Confirmation:** source document and target allocation line must be shown together.
- **Pilot boundary:** without a discovery read, this can only be an isolated fixture-context pilot.

### 4.4 Dispatch Setup

- **Primary operator:** Dispatch planner.
- **Business objects:** Dispatch Plan, memberships, Trip, Stops.
- **Commands:** CMD-09 and CMD-10.
- **Reads:** READ-02, READ-03, READ-04.
- **Input categories:** known fully evidenced requirement/allocation pairs and versions, Plan/Trip references, assignment, ordered membership subset.
- **Output/state:** Plan/Trip/Stop IDs and versions, derived service date, blockers and audit evidence.
- **Confirmation:** exact memberships and stop order.
- **Production entry limitation:** candidate requirements and unassigned membership discovery require a bounded read.

### 4.5 Dispatch Execution

- **Primary operator:** Dispatch controller and delivery operator.
- **Business objects:** Dispatch Load, Trip, Stop, Delivery Confirmation.
- **Commands:** CMD-11 through CMD-14.
- **Reads:** READ-01 through READ-04.
- **Input categories:** known Trip/Stop/current versions, exact load lines and Evidence bridges, departure/delivery/completion times, receiver reference.
- **Output/state:** load/bridge/confirmation IDs, Trip/Stop versions, readiness, blockers, trace, audit.
- **Confirmation:** mandatory for load, departure, delivery, and closure.
- **Unsupported paths:** returns, exceptions, partial delivery, cancellation, reopening, and route optimization remain outside the slice.
- **Production entry limitation:** execution Trip queue and complete reloadable Trip detail require a bounded discovery/detail read.

### 4.6 Trace & Audit panel

The existing static `TracePanel` is the smallest visual starting point, but a later connected version must separate:

```text
Public references
Opaque IDs
Stage statuses
Quantity reconciliation
Readiness and blockers
Command receipt
Domain events
Audit events
```

It must not become a generic reporting framework or expose raw rows.

## 5. Standard screen states

| State | Required behavior |
|---|---|
| Loading | Preserve target object/version and show which read or command is active |
| Empty known context | Explain that the selected context has no rows or no completed trace |
| Missing context | Explain which authoritative selector is required |
| Validation error | Map `field_errors` to the form and keep unsent input |
| Safe business blocker | Show code, safe message, blocking references, warnings, and owning action |
| Stale version | Show expected/actual version, preserve draft, disable blind retry |
| Retryable concurrency | Offer exact retry of the immutable request |
| Exact replay | Show original completed result without implying another write |
| Capability denied | Stop and direct the user to role administration; no client bypass |
| Scope denied | Stop and show the bounded context; never broaden to private tables |
| Session expired | Disable submit, preserve safe local draft, require reauthentication and review |
| Internal safe failure | Show safe message and IDs useful to support; hide private diagnostics |

## 6. Formal read-gap register

Classification:

1. supported by an existing authorized read;
2. supported only when an authoritative ID is already known;
3. suitable only for an isolated fixture-context pilot;
4. requires a separately approved bounded discovery read;
5. deferred.

| Proposed queue, list, search, dashboard, or selector | Operator information needed | Current authorized read | ID/scope already required | How the client obtains it today | Direct-table access otherwise required? | Class |
|---|---|---|---|---|---|---:|
| Show the result of the command just submitted | Safe outcome, affected IDs, versions, events/audit IDs | Command response, not a read | Command intent is already known | Same in-flight request | No | 1 |
| Completed source-line trace | Source through delivery IDs, states, quantities | READ-01 | Wholesale Order line revision ID | Prior command response, trusted deep link, or fixture | Yes if the ID is unknown | 2 |
| Evidence readiness for one source line | Per-line Evidence/load/delivery state | READ-02 | Wholesale Order line revision ID | Prior command response, trusted deep link, or fixture | Yes if unknown | 2 |
| Evidence readiness for one requirement | Per-line Evidence/load/delivery state | READ-02 | Dispatch Requirement revision ID | CMD-04 response, trusted context, or fixture | Yes if unknown | 2 |
| Evidence readiness for one Trip | Per-line readiness across Stops | READ-02 | Dispatch Trip ID | CMD-10 response, trusted context, or fixture | Yes if unknown | 2 |
| Blockers for one Trip | Safe blocker list and owning team | READ-03 | Dispatch Trip ID | CMD-10 response, trusted context, or fixture | Yes if unknown | 2 |
| Blockers for a known customer/date | Bounded customer operating observations | READ-03 | Customer ID plus service date | Customer context must already be known | Yes for customer discovery | 2 |
| Blockers for a known location/date | Bounded location operating observations | READ-03 | Delivery Location ID plus service date | Location context must already be known | Yes for location discovery | 2 |
| Audit by command | Receipt and events for a submission | READ-04 | Command ID | Client owns the command intent | No | 1 |
| Audit by journey | Events across related commands | READ-04 | Correlation ID | Workbench owns the journey | No | 1 |
| Audit by aggregate | Aggregate event history | READ-04 | Supported aggregate type and ID | Prior command response or trusted context | Yes if object discovery is needed | 2 |
| Evidence pilot context | One synthetic PO line, allocation line, current versions, subject and scope | READ-02/03/04 after IDs are supplied | Multiple known fixture IDs | Rolled-back/local synthetic fixture or explicit test context | Yes outside the fixture | 3 |
| Planning source work queue | Draft/released source references, date, customer, current version, next action | None | No supported selector discovers sources | Not available | Yes | 4 |
| Customer selector | Authorized customer references and status | None | No selector | Not available | Yes | 4 |
| Delivery Location selector | Authorized locations for selected customer | None | No selector | Not available | Yes | 4 |
| Ingredient and unit selector | Active item/unit references valid for the workflow | None | No selector | Not available | Yes | 4 |
| Released Confirmed Need / Handoff queue | Released roots, revisions, versions, next action | None | No selector | Not available | Yes | 4 |
| Released Dispatch Requirement queue | Requirement revision, lines, quantities, current version | None | No selector | Not available | Yes | 4 |
| Supplier and eligibility selector | Active supplier choices for exact line | None | No selector | Not available | Yes | 4 |
| Allocation detail and supplier PO release queue | Allocation lines, supplier groups, current version, released PO coverage | None | No selector | Not available | Yes | 4 |
| PO awaiting Evidence queue | PO/line references, supplier/item/unit/quantity, current version | None | No selector | Not available | Yes | 4 |
| Dispatch Plan candidate queue | Fully evidenced requirement/allocation pairs and versions | None | No selector | Not available | Yes | 4 |
| Unassigned Plan membership selector | Membership IDs, destination, service date, assignment state | None | No selector | Not available | Yes | 4 |
| Dispatch execution Trip queue | Assigned/loaded/in-transit/delivered Trips, versions, next action | None | No selector | Not available | Yes | 4 |
| Complete reloadable Trip detail | Stops, memberships, current load lines, Evidence bridges, versions | Existing reads are partial/advisory | Trip ID | Known Trip context | Yes for missing command-form detail | 4 |
| Global control board | Cross-domain prioritized work and owner | READ-03 is bounded and not a global queue | No global selector | Not available | Yes | 4 |
| Free-text search across operational objects | Authorized references, dates, statuses, owners | None | No selector | Not available | Yes | 4 |
| PO/Dispatch document export queue | Released document references and printable detail | None | No selector | Not available | Yes | 5 |
| Return/exception queue | Non-success delivery outcomes and next action | No accepted command/read model | Not applicable | Not available | Yes and backend contract is absent | 5 |
| Warehouse receiving/stock queue | Warehouse custody and stock facts | Outside supplier-direct slice | Not applicable | Not available | Yes and wrong domain | 5 |

### 6.1 Read-gap rule

No class-4 or class-5 requirement may be implemented by direct browser access to Atlas private tables. A proposed production workflow must stop and request a separately reviewed bounded read contract.

A class-3 pilot must be visibly labeled as isolated synthetic context and must not be presented as a production queue.

## 7. Input/output diagrams

Exact field names and response keys live only in the canonical registry.

### 7.1 Planning Source & Release

```text
Operator input
  customer/location context + reference + date + exact item lines + reason
→ client shape checks
  required fields + UUID/date/positive quantity + duplicate-line checks
→ CMD-01
  exact PA-05D envelope and payload
→ safe response
  Wholesale Order/line IDs + order version + event/audit IDs
→ UI state
  Draft detail + immutable command outcome
→ operator confirmation
  target order + current version + release transition
→ CMD-02 → CMD-03 → CMD-04
→ safe responses
  returned downstream IDs and versions at each step
→ next action
  Procurement Commitment with known requirement context
```

### 7.2 Procurement Commitment

```text
Known released requirement context
  requirement revision + line revisions + current version
→ operator assignment
  supplier per line; authoritative quantity/unit read-only
→ confirmation
  complete line coverage + supplier + destination + service date
→ CMD-05
→ safe response
  allocation/revision/line IDs + allocation version
→ supplier PO form
  allocation revision + supplier + document number + reason
→ CMD-06
→ safe response
  PO/revision/line IDs + PO version + unchanged allocation version
→ next action
  Evidence recording for known returned PO-line context
```

### 7.3 Supplier Evidence & Readiness

```text
Known Evidence context
  PO-line revision + PO version + supplier/item/unit/quantity
→ operator input
  Evidence reference + quantity + occurrence time + reason
→ confirmation
  released commitment and physical document shown together
→ CMD-07
→ safe response
  Evidence ID + guarded PO version + event/audit IDs
→ application input
  Evidence ID + allocation-line revision + allocation version + quantity/unit
→ CMD-08
→ safe response
  Evidence Application ID + guarded allocation version
→ READ-02 + READ-03 + READ-04
→ UI state
  readiness quantities/status + blockers/owners + receipt/events/audit
→ next action
  resolve Evidence or proceed with known-context Dispatch setup
```

### 7.4 Dispatch Setup

```text
Known fully evidenced pairs
  requirement/allocation revision IDs + both versions
→ operator input
  Plan reference + optional wave
→ CMD-09
→ safe response
  Plan/membership IDs + Plan version + derived service date
→ assignment input
  Plan version + Trip reference + driver/vehicle + ordered membership IDs
→ CMD-10
→ safe response
  new Plan version + Trip/Stop IDs and versions
→ next action
  load confirmation for known Stops
```

### 7.5 Dispatch Execution

```text
Known Trip/Stop context and current Trip version
→ exact physical load input
  all lines + quantities/units + Evidence Application bridges + load time
→ CMD-11
→ safe response
  Load/line/bridge IDs + Trip/Stop versions
→ trip-wide departure confirmation
→ CMD-12
→ safe response
  Trip and every Stop version
→ exact destination receipt
  all load lines + delivered quantity + zero return/exception + receiver/time
→ CMD-13
→ safe response
  Delivery Confirmation IDs + Trip/Stop versions
→ successful closure confirmation
→ CMD-14
→ safe response
  completion time + Trip version + event/audit IDs
→ READ-01 + READ-04
→ completed trace and history
```

## 8. Retool evidence boundary

Reviewed OPS v1 exports:

- `OPS - Admin (in production).json`;
- `OPS - Công thức.json`;
- `OPS - Nguyên liệu và Nhà cung ứng.json`;
- `OPS - Lên đơn, Đặt hàng (1).json`.

Operator ergonomics to retain:

- date-first and scope-first filters;
- visible Vietnamese operational language;
- compact editable tables where editing is actually approved;
- change previews and “no changes” feedback;
- confirmations before authoritative or destructive actions;
- explicit accepted, skipped, and rejected counts;
- immediate safe notifications and recovery guidance;
- refresh after a successful authoritative action;
- exports or printable views only after an approved document/read contract;
- visible supplier, school/location, item, quantity, unit, and next action.

Patterns explicitly rejected:

- direct SQL writes;
- direct `public` table dependencies;
- delete-and-reinsert replacement workflows;
- hidden JavaScript transaction orchestration;
- UI-owned normalization, allocation, or business transformations;
- service-role behavior;
- raw RPC chaining without visible command inputs/outputs.

Retool informs operator language and decision support. Atlas commands and reads remain authoritative.

## 9. Current prototype contradictions to resolve later

1. Procurement prototype actions such as validate, approve, draft, and supplier-confirm do not map to accepted commands.
2. The generic document-release workspace exceeds the single accepted supplier-PO release command.
3. “Warehouse Receiving” cannot represent supplier-direct Evidence without changing domain ownership.
4. Dispatch prototype return/exception states exceed the successful-path-only backend.
5. The static Trace panel does not yet expose command identity, versions, events, audit IDs, stale/retry/replay, or scope denial.
6. The control board cannot be connected as a global queue with READ-03.
7. Current forms assume reference lists that the 18-function read boundary does not provide.
