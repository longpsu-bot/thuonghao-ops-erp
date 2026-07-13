# ARCH-001 — OPS ERP Business Architecture

**Status:** Approved baseline v1.0  
**Scope:** Business architecture and design method  
**Audience:** Product owner, operators, implementation agents, future software partners  
**Implementation status:** Architecture only; no database, API, or UI changes

## 1. Mission

Atlas transforms the operational knowledge accumulated in OPS v1 into a scalable ERP platform for Thượng Hảo.

Atlas preserves proven operating practices while redesigning the system around clear business ownership, traceability, operational simplicity, and long-term adaptability.

Technology serves the business. The business architecture comes first.

## 2. OPS v1 Role

OPS v1 is not treated as a failed old system.

It is the operational knowledge base that captured years of real business behavior, exceptions, workarounds, and decision patterns.

Atlas should not copy OPS v1 screens directly. Atlas should extract the business intent from OPS v1 and re-express it through cleaner domains, contracts, commands, read models, and simpler workspaces.

## 3. Design Method

Business domains are the primary unit of design.

The design order is:

```text
Mission
→ Business Capability
→ Business Domain
→ Business Object
→ Business Contract
→ Command / Event
→ Read Model
→ Application
→ Technology
```

The design order must not be reversed. Do not start from a screen, table, or framework and then invent business meaning afterward.

When a new feature is proposed, ask:

1. Which business capability does this belong to?
2. Which domain owns it?
3. Which business object changes?
4. Which command changes state?
5. Which read model serves the user?
6. How do we keep the operator experience simple?

## 4. Architecture Principles

### 4.1 Business Architecture before Implementation

No implementation should begin until the business process, owner, object, command, and success criteria are clear enough for MVP delivery.

### 4.2 One Business Object, One Owner

Every business object has one authoritative owner. Other domains may read or request changes through commands, but they must not silently redefine another domain's object.

### 4.3 Traceability by Design

Every important operational decision should be able to answer:

```text
Why?
Who?
When?
Based on what?
```

Traceability is designed into the business object and event model, not added later as a report.

### 4.4 Stable Operational Identity

Operational identity uses stable surrogate IDs. Business meaning is represented through attributes, relationships, lineage, and source references.

Do not encode business meaning into primary keys.

### 4.5 Commands Change State

Users do not directly mutate important operational state. They execute business commands such as confirm, reopen, release, receive, replace, or cancel.

Commands validate business rules, create events, and return authoritative results.

### 4.6 Read Models Serve the UI

Applications should read prepared business views or APIs. The UI should not reconstruct ERP logic from raw tables.

### 4.7 Released Documents Preserve History

Released operational documents are snapshots. Later corrections create revisions, cancellations, or compensating actions. They must not silently rewrite released history.

### 4.8 Additive Evolution

New source types, workflows, or operational exceptions should extend the model without forcing redesign of existing business objects.

### 4.9 Operational Simplicity

The internal architecture may be sophisticated, but the operator experience should remain simple. Operators should not need to understand UUIDs, lineage graphs, or event streams to complete daily work.

### 4.10 Progressive Disclosure

Show enough to decide. Allow expansion to explain. Never force the full operational model into the primary screen.

### 4.11 Decision-Centric UX

Every workspace exists because someone must make a business decision. If a screen does not support a clear decision, it should be redesigned, merged, or removed.

### 4.12 Cognitive Load Minimization

Primary workspaces should show only decision-critical information. Detail, audit, traceability, document history, and diagnostics should be available through expansion, drawers, dialogs, or dedicated explain views.

### 4.13 Business First, Technology Second

Major design decisions should be explainable without mentioning React, Supabase, Vercel, Retool, or any other technology. Technology appears only after the business rule is clear.

## 5. UX Philosophy

Atlas is a decision-first ERP with traceability by design.

The default interaction model has three layers:

```text
Level 1 — Decision View
Show the minimum information required to make the current decision.

Level 2 — Operational Detail
Expandable row, drawer, popup, or secondary table with supporting context.

Level 3 — Explain / Audit / History
Lineage, events, before/after quantities, source references, documents, and investigation details.
```

Typical primary tables should be compact. As a design discipline, aim for 5–8 visible decision-critical columns before expanding for details.

The goal is not to hide complexity. The goal is to place complexity where it helps rather than where it slows daily decisions.

## 6. Core Business Domains

### 6.1 Planning Domain

**Owner:** Tổ Kế hoạch  
**Purpose:** Transform customer demand into authorized purchasing demand.

Core business objects:

- Weekly Menu
- Attendance
- Direct Request
- Pantry Request
- Calculated Need
- Confirmed Need

Planning owns demand confirmation. Procurement, Warehouse, Reporting, and Finance may read confirmed demand, but they must not silently redefine it.

### 6.2 Recipe Domain

**Owner:** QA / Nutrition / Planning, depending on organization maturity  
**Purpose:** Maintain food production standards and ingredient formulas.

Core business objects:

- Dish
- Recipe
- Recipe Version
- Recipe Change Order
- Bill of Materials

Recipe controls should not be mixed into daily purchasing decisions unless a change affects the actual demand or substitution rules.

### 6.3 Procurement Domain

**Owner:** Thu mua  
**Purpose:** Convert confirmed demand into supplier commitments.

Core business objects:

- Supplier
- Supplier Assignment
- Purchase Allocation
- Purchase Order
- Supplier Revision
- Procurement Replacement

Procurement may propose supplier or ingredient replacements, but replacement must be visible to Planning, Dispatch, and Warehouse when it affects what will be sent or received.

### 6.4 Warehouse Domain

**Owner:** Kho  
**Purpose:** Fulfil confirmed supply commitments through receiving, stock, dispatch, and internal fulfilment.

Core business objects:

- Warehouse
- Stock
- Receiving
- Dispatch
- Internal Fulfilment
- Inventory Adjustment

Warehouse can fulfil from stock, but Warehouse should not redefine demand. In Atlas, Warehouse may appear as an internal fulfilment source, not an accounting supplier.

### 6.5 Dispatch Domain

**Owner:** Kho vận / Điều phối giao hàng  
**Purpose:** Move goods from warehouse or supplier flow to kitchen, school, or destination.

Core business objects:

- Dispatch Plan
- Dispatch Line
- Driver Handoff
- Delivery Exception

Dispatch should consume released supply commitments and replacement snapshots. It should not infer substitutions silently.

### 6.6 Quality Domain

**Owner:** QA  
**Purpose:** Control quality, food safety, inspection, complaint, supplier quality, and corrective action.

Core business objects:

- Inspection
- Supplier Quality Issue
- Complaint
- Recall / Hold
- Corrective Action

Quality is not part of the first Planning MVP, but the architecture must leave room for it.

### 6.7 Reporting and Administration

Reporting reads across domains. Administration supports setup, permissions, and master data. These areas should not become hidden owners of operational business decisions.

### 6.8 Finance Domain

Finance is future scope. It may later own invoices, payments, balances, and cost analysis, but MVP Planning, Procurement, and Warehouse workflows should not be blocked by full finance implementation.

## 7. Canonical MVP Flow

The MVP flow is:

```text
Weekly Menu
→ Attendance
→ Need Generation
→ Confirmed Need
→ Purchase Allocation
→ Purchase Order
→ Receiving
→ Dispatch
```

Planning produces confirmed demand. Procurement turns confirmed demand into supplier commitment. Warehouse receives and dispatches fulfilment.

This flow is the north star for MVP delivery.

## 8. Domain Contract Template

Every domain contract should follow the same structure:

```text
Purpose
Owner
Business Objects
Commands
Events
Read Models
External Dependencies
Business Rules
Out of Scope
Acceptance Criteria
```

A domain is not ready for implementation until these are clear enough for MVP delivery.

## 9. Definition of Ready

A feature is ready for implementation only when the following are known:

- business domain
- business owner
- business object
- command or read model
- user decision supported
- success criteria
- explicit non-goals

If these are unclear, do not code yet.

## 10. Definition of Done

A feature is done when:

- the business owner can complete the intended workflow
- the operator can make the correct decision faster or with fewer errors
- traceability is preserved
- architecture principles are respected
- tests and validation appropriate to the change have passed
- staff review feedback has been addressed or explicitly deferred

## 11. MVP Delivery Rule

Architecture is now a constraint, not the deliverable.

For the MVP phase, every sprint should end with a usable business capability. The practical test is:

```text
Can one more OPS v1 workflow be reduced or turned off?
```

If the answer is no, the work should be questioned.

## 12. Current MVP Direction

The first MVP target is the Planning Domain.

Planning Domain MVP should allow Planning to complete daily demand work in Atlas:

```text
Weekly Menu
→ Attendance
→ Need Generation
→ Need Adjustment
→ Confirmed Need
→ Purchase Handoff
```

The immediate next implementation track is:

```text
Planning Domain Sprint 1
TASK-004A — Confirmed Need Foundation
```

TASK-004A should implement only the minimal Confirmed Need foundation defined by the approved TASK-003 contract. It should not expand into the full ERP.

## 13. Architecture Freeze v1.0

ARCH-001 is frozen as the baseline for MVP delivery.

This does not mean the architecture cannot evolve. It means new architecture changes must show why the current baseline is insufficient.

Future changes should be based on real implementation or staff review feedback, not theoretical refinement.
