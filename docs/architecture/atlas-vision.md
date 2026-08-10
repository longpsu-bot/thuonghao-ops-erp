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

Atlas uses the canonical delivery shorthand:

> **Workflow-led, contract-constrained, backend-authoritative.**

This refines delivery sequencing without replacing `OPS_SYSTEM_MAP`, business architecture, or backend authority.

### Business architecture defines ownership and boundaries

Atlas begins by establishing the mission, capability, domain owner, business object, and responsibility boundary. Technology is selected only after the business need is understood.

Business architecture is not optional, and UI exploration does not replace it.

### Workflow discovery before detailed contract freeze

Before freezing a detailed lifecycle or command surface, Atlas should prove the concrete operator job:

- what the operator is trying to accomplish;
- what information must be visible;
- which exceptions matter;
- which actions represent real human decisions or authored operational facts;
- which apparent lifecycle steps are deterministic system work.

Lightweight workflow sketches, fixtures, mock screens, or UI prototypes may be used for this discovery.

These artifacts are not the authoritative Application layer. They must not contain hidden authoritative calculations, authorization, business transitions, or write orchestration.

### Minimum contract before authoritative implementation

Once the operator workflow and human decision boundaries are sufficiently understood, define the minimum business contract needed for that thin slice.

The contract constrains:

- business objects and ownership;
- genuine human commands and system-internal work;
- events and read models;
- validation and authorization;
- lineage and immutable evidence;
- idempotency and transaction boundaries;
- exceptions, recovery, and exclusions.

Implementation agents execute the accepted contract rather than inventing architecture while coding.

Do not over-contract an entire future domain before its operator workflows have been proven.

### Backend authority

The application may guide interaction, but authoritative validation, authorization, calculations, lifecycle, lineage, audit, idempotency, and transaction integrity belong to controlled backend/domain commands and read models.

React coordinates interaction and renders authoritative results. React does not become a hidden ERP engine.

A correct Atlas backend should make the connected React Application comparatively boring.

### Thin connected vertical delivery

Delivery should proceed through the smallest operationally coherent vertical slice rather than completing every backend contract in a domain before connecting real operators.

For example, Warehouse should prefer:

```text
Receiving operator workflow
→ lightweight receiving UI/workflow exploration
→ minimum receiving contract
→ authoritative receiving backend
→ connected receiving UI
→ operator review
```

Then move to a proven next need such as discrepancy handling or stock intake.

The same rule applies to Procurement, Production/QA, Dispatch, and later domains.

Do not design hypothetical capability families merely because they may eventually exist.

### Human-action discipline

Carry forward the D-036 lesson:

> **Humans approve business commitments. Systems validate deterministic system work.**

Before creating a public command or primary button, ask:

1. Is the person authoring operational facts?
2. Is the person making a genuine business decision or commitment?
3. Is this a necessary exception or correction?

If none applies, the action is probably deterministic system work and should normally remain backend-internal.

This is not an absolute rule. Legitimate operational acknowledgements, safety decisions, segregation-of-duties requirements, and other proven business controls remain valid.

### Decision-first user experience

The primary screen shows only what an operator needs to decide or act. Supporting detail is progressively disclosed. Traceability, audit, and history remain available without overwhelming ordinary work.

D-034 governs visual direction. D-035 governs workflow-first Application presentation. D-036 clarifies which Planning transitions genuinely deserve human actions.

### Traceability by design

Important records preserve their source, version, actor, timestamp, reason, and downstream use. Traceability is part of the object model, not an afterthought or reporting patch.

### Complexity discipline

A proposed abstraction, lifecycle state, API, table, or testing framework should have evidence from at least one of:

- an actual current business requirement;
- security;
- data integrity;
- realistic operational recovery;
- two or more proven consumers where shared abstraction is claimed.

Prefer a local function or bounded implementation over a generic framework when sufficient. Do not design for hypothetical scale.

When repeated corrections expose the same design assumption, reassess the boundary instead of continuing a fail → patch → fail cycle.

### Small, reviewable delivery

Work is delivered through bounded issues and pull requests. Each PR should be understandable, testable, reversible, and aligned with one approved slice.

Validation should match the risk of the change. Cross-version backend or lifecycle-boundary work warrants deeper integration evidence; ordinary UI-only work should not inherit an expensive backend certification gate merely because such a gate exists.

## Role of OPS v1

OPS v1 is an operational knowledge base and continuity boundary. Retool pages, Supabase tables/functions, spreadsheets, and current operator behavior provide evidence of business intent, practical field density, edge cases, and proven workflows.

Useful evidence includes:

- simple operator mental models;
- explicit Save;
- dense operational information;
- quick search and editing;
- practical exception handling;
- familiar Vietnamese task language.

Atlas should not copy:

- direct browser SQL;
- JavaScript or component state as business authority;
- client-side calculation authority;
- hidden write orchestration;
- implicit authorization;
- Retool component or page structure as Atlas architecture.

Atlas should preserve useful business behavior while redesigning ownership, contracts, backend authority, and operator experience.

## MVP meaning

MVP does not mean a static presentation. A capability counts only when an operator can complete useful business work and one more OPS v1 workflow can be reduced, simplified, or prepared for retirement.

MVP also does not mean implementing the entire company at once. Atlas advances through thin connected operational slices across domains such as:

```text
Planning
→ Procurement
→ Warehouse
→ Production and Quality
→ Dispatch and Delivery
→ Finance and Reporting
```

A domain does not need every future capability implemented before its first useful connected slice reaches operators.

## Success criteria

Atlas succeeds when:

- another competent developer or software company can clone the repository and understand the project direction;
- business ownership is visible in the system;
- operators can complete daily decisions without understanding technical internals;
- detailed contracts reflect proven operator workflows rather than speculative lifecycle mechanics;
- authoritative business behavior remains backend-owned;
- released records and changes are traceable;
- the company can replace OPS v1 incrementally through thin connected slices rather than a risky one-time migration;
- management can focus on exceptions, performance, and growth rather than routine data movement.

## Architecture stability

The approved business architecture remains a delivery constraint. It should not be repeatedly redesigned for theoretical improvement.

The workflow-led method shapes how Atlas discovers and freezes detailed contracts; it does not weaken accepted ownership, security, data integrity, lineage, audit, or backend authority.

Architecture or contract changes require a verified business need, a fundamental implementation defect, evidence from operator review, or an explicit product-owner decision.
