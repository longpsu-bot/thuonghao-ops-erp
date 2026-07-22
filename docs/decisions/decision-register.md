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
| D-019 | Use UI-led, contract-constrained design before Supabase schema implementation. | Accepted | Workflow and UI prototypes should expose required states, actions, warnings, and data contracts before database tables and RPCs are finalized. This prevents premature schema design while avoiding UI-only logic that recreates Retool-style complexity. |

PA-06D approved directions and unresolved product choices are tracked separately in [Decision PA-06D — Quantity Truth and Write Fidelity](decision-pa-06d-quantity-truth-and-write-fidelity.md). Pending PA-06D rows are not accepted project decisions.

PA-06E approved directions and unresolved product choices are tracked separately in [Decision PA-06E — Confirmed Need Source Correction](decision-pa-06e-confirmed-need-source-correction.md). The existing Confirmed Need revision is retained and no Planning confirmation aggregate is introduced; pending PA-06E rows and proposed APIs are not accepted project decisions or canonical registry entries.

PA-06E-H0 physical recommendations and unresolved prerequisites are tracked separately in [Decision PA-06E-H0 — Source Lineage and Decision Evidence](decision-pa-06e-h0-source-lineage-and-decision-evidence.md). The selected inline typed-source, theoretical predecessor, decision-evidence, policy-gate, and materialization directions remain proposed until product, architecture, security, and migration review; no implementation or API-registry change is approved by that record.

The bounded PA-06E-H0A1 customer, school, same-customer default delivery-location, and relational `SCHOOL` scope model is recorded in [Decision PA-06E-H0A1 — School and Delivery-Location Ownership](decision-pa-06e-h0a1-school-delivery-location-ownership.md). Issue #117 accepts this reference foundation only; later school-catering lineage, calculation, confirmation, policy, and API decisions remain outside its authority.

The bounded PA-06E-H0A2 Dish, scoped Recipe, RecipeVersion release, stable RecipeLine, and immutable RecipeLineRevision model is recorded in [Decision PA-06E-H0A2 — Immutable Recipe and BOM Reference Lineage](decision-pa-06e-h0a2-immutable-recipe-bom-reference-lineage.md). Issue #119 accepts this private reference foundation only; selection precedence, commands, review/unlock workflow, calculation policy, Planning lineage, and later materialization decisions remain outside its authority.

The bounded PA-06E-H0A3a stable Weekly Menu root, typed working lines, exact approval snapshot, and immutable snapshot-line model is recorded in [Decision PA-06E-H0A3a — Controlled Weekly Menu Persistence](decision-pa-06e-h0a3a-controlled-weekly-menu-persistence.md). Issue #121 accepts this private persistence foundation only; commands, authorization, issues/events, slot policy, Attendance, Need Generation, API/UI, hosted execution, and production rollout remain outside its authority.

The bounded PA-06E-H0A3b stable Attendance batch, School/date exact-portion lines, exact approval snapshot, and immutable snapshot-line model is recorded in [Decision PA-06E-H0A3b — Controlled Attendance Persistence](decision-pa-06e-h0a3b-controlled-attendance-persistence.md). Issue #123 accepts this private persistence foundation only; commands, authorization, import behavior, defaults, inactive-School policy, issues/events, Planning Input Set, readiness, Need Generation, API/UI, hosted execution, and production rollout remain outside its authority.

The bounded PA-06E-H0A4a Planning Input Readiness design is recorded in [Decision PA-06E-H0A4 — Planning Input Readiness](decision-pa-06e-h0a4-planning-input-readiness.md). Issue #125 accepts one stable exact-period root, immutable evaluation versions/issues, direct typed Weekly Menu and Attendance approval-snapshot bindings, period containment, a closed lifecycle, explicit invalidation, nonblocking warnings with acknowledgement deferred, and handoff-only request semantics. Persistence, commands, authorization, events, API/UI, hosted execution, calculation, and downstream materialization remain outside its authority.

The bounded PA-06E-H0A4b private persistence implementation is recorded in [Decision PA-06E-H0A4b — Planning Input Readiness Persistence](decision-pa-06e-h0a4b-planning-input-readiness-persistence.md). Issue #127 accepts exactly three Planning relations, direct typed source snapshot ownership, immutable sequential evaluations/issues, exact blocker/warning evidence, the closed lifecycle, explicit invalidation, forced RLS with zero policies, and 123 focused pgTAP assertions. Commands, authorization, events, acknowledgement, read/API/UI surfaces, hosted execution, calculation, H0A5, and downstream materialization remain outside its authority.

The bounded PA-06E-H0A5a Need Generation design is recorded in [Decision PA-06E-H0A5 — Need Generation Run and Theoretical Lineage](decision-pa-06e-h0a5-need-generation-lineage.md). Issue #129 accepts one exact input-set/evaluation run attempt, a linear correction chain, immutable typed input and Recipe-use evidence, one fixed proportional numeric calculation contract, deterministic Recipe precedence, source-Unit output, atomic direct typed lineage, explicit predecessor/removal semantics, a closed issue catalog, the four-state lifecycle, and an immutable release boundary. H0A5b persistence, commands, authorization, API/UI, hosted execution, Confirmed Need materialization, downstream correction, and production rollout remain outside its authority.

The bounded PA-06E-H0A5b private persistence implementation is recorded in [Decision PA-06E-H0A5b — Need Generation Persistence](decision-pa-06e-h0a5b-need-generation-persistence.md). Issue #131 implements exactly 11 private Planning relations, four guards, 22 relation-local triggers, fixed PostgreSQL numeric calculation, typed readiness/Recipe/source/predecessor lineage, the exact post-entry issue catalog, closed lifecycle, immutable release membership, and 244 focused pgTAP assertions. Commands, authorization, API/UI, hosted execution, supported reintroduction, Confirmed Need materialization, Procurement, and production rollout remain outside its authority.

The bounded PA-06E-H0B1a decision is recorded in [Decision PA-06E-H0B1 — Confirmed Need Identity and Contribution Membership](decision-pa-06e-h0b1-confirmed-need-identity-membership.md). Issue #133 accepts the exact batch/date/customer/School/delivery-location/Ingredient/controlled-Unit stable-line tuple, separation of authorization from identity, a no-conversion source-Unit-equals-controlled-Unit slice, explicit `WHOLESALE`/`NEED_GENERATION` source families on the existing aggregate, immutable revision-owned plural contribution membership, exact numeric totals, the two mandatory deferred guards, unchanged PA-05D behavior, private security, and four future H0B1b test families. H0B1b persistence, H0C, H1 decisions/policy/runtime, APIs/UI, hosted execution, and production rollout remain separately unauthorized.

## Change procedure

A decision may be amended or superseded only when:

1. the new decision is explicitly approved;
2. the affected documents and modules are identified;
3. the reason and impact are recorded;
4. a new ADR is created when the change is structurally significant.
