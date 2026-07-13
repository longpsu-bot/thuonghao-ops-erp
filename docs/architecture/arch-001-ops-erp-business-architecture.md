# ARCH-001 — OPS ERP Business Architecture

**Status:** Approved and frozen baseline v1.1
**Scope:** Mission, business principles, domain ownership, and delivery method

## Mission

Atlas transforms the operational knowledge accumulated in OPS v1 into a scalable ERP for Thượng Hảo. It preserves proven operating practices while redesigning the system around clear ownership, controlled handoffs, traceability, operational simplicity, and long-term adaptability.

Technology serves the business. Business architecture comes first.

## OPS v1 role

OPS v1 is the operational knowledge base. Retool applications, Supabase behavior, spreadsheets, and operator practice provide evidence of real business intent and exceptions.

Atlas should preserve that intent without copying Retool screens or treating current database structures as permanent domain boundaries.

## Design method

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

The order must not be reversed.

## Principles

1. **Domain first.** Capability, owner, and business object are established before implementation.
2. **Contract first.** Objects, lifecycle, commands, events, read models, validations, boundaries, UX, and acceptance criteria are agreed before code.
3. **One object, one owner.** Other domains may reference or request changes but may not silently redefine another domain's object.
4. **Commands change state.** Important changes happen through explicit business commands.
5. **Events explain outcomes.** Events record what happened, who acted, when, why, and which controlled inputs were used.
6. **Read models serve decisions.** UI screens consume prepared business views rather than reconstructing ERP logic from raw data.
7. **Traceability by design.** Important records preserve source, version, actor, timestamp, reason, and downstream use.
8. **Stable identity.** Operational records use stable IDs; business meaning belongs in attributes and relationships.
9. **Released history is preserved.** Corrections use revisions, reopenings, invalidations, cancellations, or compensating actions.
10. **Decision-first UX.** Show enough to decide, allow expansion to explain, and keep audit/history outside the default view.
11. **Backend authority.** React coordinates presentation and interaction; authoritative calculations and state transitions belong to controlled domain/backend commands.
12. **Small delivery units.** Work is delivered through bounded issues and reviewable pull requests.

## Core domains

- **Planning:** Weekly Menu, Attendance, other controlled sources, Planning Input Readiness, Need Generation, Confirmed Need, and Purchase Handoff.
- **Recipe:** Dish, Recipe, Recipe Version, BOM, and controlled formula changes.
- **Procurement:** Supplier assignment, allocation, purchase orders, confirmations, and replacements.
- **Warehouse:** Receiving, stock, lots, fulfilment, picking, dispatch, adjustments, and stock count.
- **Dispatch and Delivery:** Plans, handoffs, confirmations, exceptions, and returns.
- **Production and Quality:** Kitchen execution, portioning, waste, food safety, inspection, complaints, holds, and corrective action.
- **Finance, Reporting, and Administration:** Finance owns financial records; Reporting reads across domains; Administration owns setup and permissions rather than daily decisions.

The official detailed domain, ownership, traceability, and technology map is maintained in [`ARCH-002 — Atlas System Map`](arch-002-atlas-system-map.md).

## Planning MVP flow

```text
Weekly Menu / Attendance / Other controlled sources
→ Planning Input Readiness
→ Need Generation
→ Confirmed Need
→ Purchase Handoff
→ Procurement
```

Planning owns demand up to release to Procurement. It does not assign suppliers, create purchase orders, receive goods, dispatch goods, or perform accounting.

## Definition of ready

A feature is ready only when its capability, domain, owner, object, lifecycle, commands, read models, supported user decision, acceptance criteria, exclusions, contract, and issue are clear.

## Definition of done

A capability is done when the business owner can complete the intended workflow, the operator can decide faster or with fewer errors, traceability and history are preserved, boundaries remain intact, tests and validation pass, and the change moves Atlas toward reducing an OPS v1 workflow.

## Delivery workflow

```text
Contract
→ GitHub issue
→ Bounded implementation branch
→ Tests and validation
→ Pull request
→ Review
→ Merge
→ Integration or next capability
```

Independent modules may be built in parallel when each has an approved contract, separate module ownership, typed fixture references, independent tests, and a later bounded integration PR.

## MVP delivery rule

Architecture is a constraint, not the recurring deliverable. Every sprint should end with a usable capability.

The practical test is:

```text
Can one more OPS v1 workflow be reduced, simplified, or prepared for retirement?
```

Current delivery status is maintained in [`roadmap.md`](roadmap.md).

## Architecture Freeze v1.1

ARCH-001 and ARCH-002 are frozen as the Atlas MVP baseline.

They change only when a verified business requirement cannot fit the model, implementation exposes a fundamental ownership/lifecycle/traceability defect, or the product owner explicitly approves a change.

Theoretical refinement alone is not sufficient reason to redesign the baseline. Future work should focus on contracts, implementation, integration, and operator value.