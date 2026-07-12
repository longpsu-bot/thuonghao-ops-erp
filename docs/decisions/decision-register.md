# OPS ERP Decision Register

This register records approved project and architecture decisions. Detailed decisions may later be expanded into ADR files under `docs/decisions/adr/`.

| ID | Decision | Status | Rationale |
|---|---|---|---|
| D-001 | Use React and TypeScript as the primary OPS ERP frontend. | Accepted | Provides maintainable custom UI, source control, reusable components, testing, and stronger long-term flexibility than continuing to expand Retool. |
| D-002 | Use Supabase and PostgreSQL as the initial backend platform. | Accepted | Reuses existing capability while providing database, Auth, RLS, RPCs, storage, and managed operations. |
| D-003 | Use a modular-monolith architecture. | Accepted | Keeps deployment and operations simple while preserving clear module boundaries. |
| D-004 | Authoritative business logic belongs in the backend. | Accepted | Prevents duplicated and inconsistent calculation logic across clients. |
| D-005 | Codex is the primary implementation assistant. | Accepted | Supports bounded, reviewable development while architecture remains human-governed. |
| D-006 | Keep OPS v1 operational while building OPS ERP in parallel. | Accepted | Reduces operational risk and enables module-by-module rollout. |
| D-007 | Design the target architecture before deciding what legacy data to migrate. | Accepted | Prevents migration of duplicated or obsolete technical structures. |
| D-008 | Repository documentation is the architectural source of truth. | Accepted | Avoids dependence on chat history or personal memory. |
| D-009 | Transferability to another engineering team is a core design requirement. | Accepted | Protects the business from dependence on one person, vendor, or AI tool. |
| D-010 | Runtime AI will not make authoritative operational decisions in the initial system. | Accepted | Keeps calculations deterministic, auditable, and controllable. |
| D-011 | GitHub is the source of truth for documentation and code. | Accepted | Keeps definitions, decisions, migrations, tests, and implementation versioned together. |
| D-012 | Catering and wholesale are separate demand sources feeding a shared requirement pipeline. | Accepted | Unifies procurement and fulfilment while preserving different demand semantics. |
| D-013 | Wholesale ingredient demand bypasses recipe explosion. | Accepted | Wholesale orders already specify ingredients directly. |
| D-014 | Order-specific substitutions do not modify permanent recipes. | Accepted | Preserves recipe integrity and correctly scopes operational exceptions. |
| D-015 | Significant multi-record business actions should use one transactional backend command. | Accepted | Prevents partial writes and preserves traceability. |
| D-016 | Retool is not the primary long-term ERP interface. | Accepted | Current Retool apps contain substantial UI state, JavaScript, event, and query complexity; future use is limited to selected support/admin tools. |
| D-017 | Do not build a generic formula engine initially. | Accepted | Typed functions and typed configuration tables are easier to audit, test, and maintain. |
| D-018 | Released operational documents are immutable snapshots. | Accepted | Future data or rule changes must not silently rewrite commitments or history. |
| D-019 | Build workflow documentation and UI prototypes before finalizing Supabase table/schema design. | Accepted | The database must support validated business workflows, not prematurely freeze assumptions before staff review, UI review, and rule design are clear. |

## Change procedure

A decision may be amended or superseded only when:

1. the new decision is explicitly approved;
2. the affected documents and modules are identified;
3. the reason and impact are recorded;
4. a new ADR is created when the change is structurally significant.
