# Atlas Vision

## Why Atlas exists

Thượng Hảo has accumulated valuable operating knowledge through OPS v1, Retool applications, Supabase functions, spreadsheets, and management practice. That knowledge is real and useful, but much of it is still embedded in screens, database behavior, individual experience, and informal workarounds.

Atlas exists to turn that operational knowledge into a durable ERP that can scale beyond individual people and tools.

Atlas is not a visual rewrite of Retool. It is the business operating system for Thượng Hảo.

## Business outcome

Atlas should allow the company to operate through clear responsibilities, explicit approvals, controlled handoffs, and traceable exceptions.

The intended result is:

- less dependence on directors for routine purchasing and operational decisions;
- clearer responsibilities for Planning, Procurement, Warehouse, Kitchen, Drivers, QA, and Finance;
- reliable handover when staff change or when a professional software team takes over;
- fewer hidden calculations and undocumented workarounds;
- faster daily decisions with enough detail available when investigation is needed;
- preserved history for released operational records;
- gradual replacement of OPS v1 workflows without disrupting the business.

## Product philosophy

### Business architecture before implementation

Atlas begins with the capability, domain owner, business object, lifecycle, command, and decision. Technology is selected only after the business rule is clear.

### Contract before code

Each bounded capability has a contract defining objects, lifecycle, commands, events, read models, validations, exclusions, and acceptance criteria. Implementation agents execute the approved contract rather than inventing architecture while coding.

### Decision-first user experience

The primary screen shows only what an operator needs to decide or act. Supporting detail is expandable. Traceability, audit, and history are available without overwhelming daily work.

### Traceability by design

Important records preserve their source, version, actor, timestamp, reason, and downstream use. Traceability is part of the object model, not an afterthought or reporting patch.

### Backend authority

The application may guide interaction, but authoritative calculations and state transitions belong to controlled domain/backend commands. React does not become a hidden ERP engine.

### Small, reviewable delivery

Work is delivered through bounded issues and pull requests. Each PR should be understandable, testable, reversible, and aligned with one approved capability. Independent modules may be built in parallel behind typed contracts and integrated later.

## Role of OPS v1

OPS v1 is the operational knowledge base. Retool pages, Supabase tables, functions, triggers, and current operator behavior provide evidence of business intent, edge cases, and proven workflows.

Atlas should preserve useful business behavior while redesigning ownership, contracts, and operator experience. It should not copy Retool page structure or treat current database tables as permanent domain boundaries.

## MVP meaning

MVP does not mean a static presentation. A capability counts only when an operator can complete useful business work and one more OPS v1 workflow can be reduced, simplified, or prepared for retirement.

MVP also does not mean implementing the entire company at once. Atlas advances domain by domain:

```text
Planning
→ Procurement
→ Warehouse
→ Production and Quality
→ Dispatch and Delivery
→ Finance and Reporting
```

Each domain should become operationally coherent before expansion creates unnecessary coupling.

## Success criteria

Atlas succeeds when:

- another competent developer or software company can clone the repository and understand the project direction;
- business ownership is visible in the system;
- operators can complete daily decisions without understanding technical internals;
- released records and changes are traceable;
- the company can replace OPS v1 incrementally rather than through a risky one-time migration;
- future backend implementation can preserve the contracts already proven in the prototype;
- management can focus on exceptions, performance, and growth rather than routine data movement.

## Architecture stability

The approved business architecture is now a delivery constraint. It should not be repeatedly redesigned for theoretical improvement. Changes require a verified business need, a fundamental implementation defect, or an explicit product-owner decision.