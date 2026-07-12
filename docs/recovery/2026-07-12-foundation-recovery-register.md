# Atlas Foundation Recovery Register

**Date:** 2026-07-12  
**Status:** Active recovery decision  
**Purpose:** Preserve useful work, correct implementation sequence, and prevent further AI effort from extending a mis-scoped prototype.

## 1. Recovery conclusion

The approved Atlas direction remains valid. The sequencing error was implementation-level: TASK-001 built a detailed Planner page before Phase 3 established the React application shell, navigation, screen flow, role access, and page responsibilities required by the rollout plan.

TASK-001 is therefore retained as a **Requirement Review UI exploration**, not accepted as the Atlas application structure or final Planner contract.

## 2. Keep without redesign

The following remain governing foundations:

- Vision and Product Charter
- Business Model and Operating Flows
- Business Glossary
- Business Processes
- System Map and module boundaries
- Domain model and calculation principles
- Security and API contract standards
- Development governance and Codex task boundaries
- Rollout principle: OPS v1 remains operational during parallel rollout
- UI-led, contract-constrained sequence
- React coordinates; backend decides
- Catering and wholesale converge into a shared requirement pipeline
- Released PO and dispatch documents are immutable snapshots
- Retool remains support/diagnostic only in the target state

## 3. Keep and reposition from TASK-001

| Asset | Recovery treatment | Target use |
|---|---|---|
| Vite/React/TypeScript foundation | Keep | Atlas frontend foundation |
| Pinned dependencies and package metadata | Keep | Reproducible development |
| Typed fixture pattern | Keep | Cross-page workflow fixtures |
| Requirement table | Keep and refactor | Requirement Review page |
| Calculation trace drawer | Keep and refactor | Requirement inspection |
| Warning/readiness chips | Keep | Shared status components |
| Exception-first filter | Keep | Requirement Review and QA |
| Grouped rows | Keep | Reusable operational data table |
| Sticky key columns | Keep | Dense workbench tables |
| Vietnamese labels and date display | Keep | Shared locale conventions |
| Prototype banner | Keep during Phase 3 | Prevent mock UI confusion |
| Local review notes | Keep only as prototype behavior | Demonstrate future note command |
| Interaction tests | Keep and expand | Cross-page journey tests |
| Planner findings document | Keep | Inputs to later contract review |

## 4. Rework before reuse

| Current element | Problem | Required correction |
|---|---|---|
| “Planner Workspace” page identity | Combines several lifecycle responsibilities | Rename/reframe as Requirement Review |
| Four view modes | Supplier view crosses into Procurement ownership | Keep date/customer/source views; move supplier work to Supplier Allocation |
| Demand-source side panel | Appears to mix source capture and review | Convert to source completeness/filter summary |
| Supplier assignment preview | Blurs review and purchasing authority | Make read-only eligibility preview or move to Procurement |
| Local ready action | Can be mistaken for authoritative readiness | Replace with a prototype request/validation interaction |
| Override/substitution buttons | Do not demonstrate real input | Build explicit mock forms with reason and scope |
| Date text control | Does not yet establish robust picker behavior | Replace with a tested Vietnamese date-picker component later |
| Page-level CSS | Not yet an application design system | Extract shared shell/table/status tokens incrementally |
| Summary cards | Mix attention signals and workflow state | Define card navigation and state semantics per page |

## 5. Retire

The following ideas should not guide further design:

- One Planner super-screen owning demand review, supplier assignment, PO readiness, and the entire operational flow
- Treating the current fixture types as approved backend contracts
- Freezing API or schema design directly from TASK-001
- Adding more visual polish to compensate for missing page boundaries
- Replicating Retool event chains, temporary state, helper queries, or export JavaScript as React business logic
- Migrating duplicate or deprecated public/ops_v2 RPC paths without classification

## 6. OPS v1 evidence to preserve

Retool and the supplied schema remain valuable evidence for:

- actual staff workflow order;
- required input fields and bulk-edit patterns;
- quantity override and supplier split behavior;
- PO views by supplier, school, and ingredient;
- dispatch document requirements;
- PO-versus-dispatch reconciliation;
- export formats and operational terminology;
- existing Supabase views/RPCs that must be classified during adapter and migration design.

They are not target UI or target architecture specifications.

## 7. Corrected implementation sequence

1. Atlas application map and page responsibilities.
2. React application shell and navigation.
3. Mock end-to-end catering journey.
4. Mock end-to-end wholesale journey.
5. Requirement Review component integration from TASK-001.
6. Supplier Allocation, PO, Dispatch, and QA page prototypes.
7. Product-owner workflow review.
8. State/read/command contract review.
9. Conceptual data model.
10. Supabase schema/RPC design only after approval.

## 8. Recovery value estimate

This is an implementation recovery, not a restart.

- Governing architecture and business documents: approximately 90% retained.
- OPS v1 analysis and workflow evidence: approximately 80% retained as migration evidence.
- React technical foundation and reusable UI primitives: approximately 60–70% reusable.
- Current page composition and workflow assumptions: approximately 20–30% reusable without redesign.
- Supabase implementation effort discarded: none, because TASK-001 correctly avoided backend work.

## 9. Immediate decision

Stop feature expansion in TASK-001. Keep PR #2 draft as an evidence branch and UI exploration. Execute TASK-002 as the next bounded implementation task.
