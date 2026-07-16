# Thượng Hảo OPS ERP

**Project codename:** Atlas

Atlas is the operational management platform for Thượng Hảo's school catering and ingredient-distribution business.

The repository is the authoritative source for business definitions, architecture, contracts, implementation, tests, rollout guidance, and review history. Chat history and AI memory are working aids, not formal project records.

## Current status

Atlas has completed the Admin / Master Data Management in-memory prototype sequence, the bounded PD-05.1 Dispatch and Delivery foundation, the PD-05.2 Dispatch integration/operator-workflow review, the MVP vertical-slice operator review, and the fixture-backed MVP morning chaos simulation. The synthetic vertical slice now traces school catering, mixed fulfilment, wholesale, delivery exception/return, and blocked operating-day scenarios from source need to delivery outcome while preserving domain ownership and operator attention. Atlas page `mvp-operations-simulation` exposes the 02:00–08:00 simulation as a read-only review surface.

PA-01 defines the Atlas persistence contract. PA-02 defines the physical PostgreSQL/Supabase namespace, table catalog, typed cross-domain line spine, revision/snapshot patterns, evidence-application constraints, quantity/time conventions, transaction matrix, indexes, access preview, derived read models, legacy staging, and the first supplier-direct wholesale schema subset. PA-03 defines the actor/capability model, dedicated `atlas_api` function surface, revoke-first grants, RLS direction, security-definer hardening, mandatory idempotency and optimistic concurrency, deterministic locking/isolation, safe errors, reporting/storage/integration controls, and first-slice security tests. PA-04 is the merged version-controlled migration foundation for supplier-direct Slice 1: nine private Atlas schemas, 52 authoritative tables, two private security-invoker trace views, forced RLS, revoke-first privileges, and a 23-check pgTAP verification script. PA-05A is complete on `main` as the supplier-direct business-command/RPC and shaped-read contract. PA-05B is merged with five evidence-to-delivery commands, one authorized shaped trace, hardened runtime roles/RLS, and 64 focused pgTAP assertions. PA-05C adds three bounded, capability/scope-filtered API wrappers for evidence readiness, operator blockers, and command/audit timeline visibility. PA-05B-H1 closes Issue #82’s shared-runtime privilege risk by splitting the PA-05B command owners into Evidence and Dispatch roles, retaining read-only ownership for the approved read surface, and adding a 10-check effective-privilege audit.

PA-05D and PA-05E are complete on `main`. Together they add the authoritative Planning release chain, exact supplier-direct fulfilment allocation, and released supplier purchase orders while preserving the reviewed 15-function API boundary. Capability review then identified one prerequisite before Dispatch setup: the existing PA-05B load and successful-delivery commands were validated around one load line per stop, while PA-05D and PA-05E create normal multi-line requirements and allocations. PA-05B-H2 corrects load, departure, and successful delivery for atomic multi-line execution without adding a public function or table. The approved PA-05A catalog also retains a separate successful-trip closure command, tracked by Issue #93, so PA-05G remains acceptance-only rather than hiding a missing write command. The backend sequence is PA-05B-H2, PA-05F Dispatch setup, PA-05B-H3 successful trip closure, PA-05G end-to-end backend acceptance, then PA-06 React connection.

The Planning Domain foundation and integration review are complete. The Procurement contract, bounded in-memory foundation, integration/operator-workflow review, and fulfilment-allocation amendment are complete as architecture baselines. The Warehouse domain contract, bounded in-memory receiving foundation, integration/operator-workflow review, Stock Release contract, and bounded in-memory Stock Release foundation are complete. The Admin / Master Data Management contract, School info, Ingredients & Suppliers, consolidated Dishes & Recipes foundations, and Admin integration/operator-workflow review are complete as in-memory prototypes. PD-05 Dispatch and Delivery starts from Planning-released dispatch requirements, Procurement fulfilment allocation, and physical fulfilment evidence rather than mandatory Warehouse release. Its in-memory foundation and operator review prove trip/load/delivery, attention, exception, return, and closure rules. Production/QA and Finance/Accounting are deferred for the MVP.

See [`docs/architecture/roadmap.md`](docs/architecture/roadmap.md) for current status.

## Technology direction

- React + TypeScript for the primary application and interaction layer
- Supabase + PostgreSQL for future authoritative persistence, transactions, RLS, and backend business commands
- Codex as a bounded implementation assistant
- Retool retained as OPS v1 business evidence and for selected diagnostic/support tooling
- GitHub as the project source of truth

## Continue on another computer

Cloning this repository is sufficient to recover the approved project direction and current codebase.

```bash
git clone https://github.com/longpsu-bot/thuonghao-ops-erp.git
cd thuonghao-ops-erp
pnpm install
pnpm ops:workspace
pnpm test
pnpm dev
```

Requirements:

- Git
- Node.js compatible with the repository configuration
- pnpm
- GitHub access to the private repository

No Supabase credential or production-data access is required. The PA-04 through PA-05E migrations can be verified against a disposable local PostgreSQL/Supabase-compatible database without linking a hosted project.

Before changing code, read `AGENTS.md` and the relevant domain contract.

## Read first

1. [`AGENTS.md`](AGENTS.md) — repository operating rules and hard boundaries
2. [`ARCH-001 — OPS ERP Business Architecture`](docs/architecture/arch-001-ops-erp-business-architecture.md) — principles and domain-first method
3. [`ARCH-002 — Atlas System Map`](docs/architecture/arch-002-atlas-system-map.md) — official feature-placement, ownership, traceability, and delivery map
4. [`Atlas Vision`](docs/architecture/atlas-vision.md) — why Atlas exists and what success means
5. [`Roadmap`](docs/architecture/roadmap.md) — delivery order and current status
6. [`PA-01 — Atlas Persistence Contract`](docs/architecture/pa-01-atlas-persistence-contract.md) — proposed authority for future persistence design
7. [`PA-02 — Physical Schema and Constraint Design`](docs/architecture/pa-02-physical-schema-and-constraint-design.md) — proposed physical design before migrations
8. [`PA-03 — Authorization, Command, and Transaction Safety Design`](docs/architecture/pa-03-authorization-command-and-transaction-safety-design.md) — proposed security and command boundary before migrations
9. [`PA-04 — Supplier-direct Slice 1 Migration Foundation`](docs/architecture/pa-04-supplier-direct-slice-1-migration-foundation.md) — merged migration scope, security posture, verification, exclusions, and next gates
10. [`PA-05A — Supplier-direct command/RPC contract`](docs/architecture/pa-05a-supplier-direct-command-rpc-contract.md) — approved callable command/read behavior
11. [`PA-05B — Supplier-direct command implementation`](docs/architecture/pa-05b-supplier-direct-command-implementation.md) — bounded SQL functions, security posture, idempotency, invariants, tests, exclusions, and next gates
12. [`PA-05C — Authorized read API wrappers`](docs/architecture/pa-05c-authorized-read-api-wrappers.md) — bounded readiness, blocker, and audit reads
13. [`PA-05B-H1 — Runtime-role hardening`](docs/architecture/pa-05b-h1-runtime-role-hardening.md) — least-privilege Evidence, Dispatch, and Read runtime ownership
14. [`PA-05D — Bounded Planning command family`](docs/architecture/pa-05d-planning-command-family-contract.md) — wholesale source-to-dispatch-requirement write contract
15. [`PA-05E — Bounded Procurement command family`](docs/architecture/pa-05e-procurement-command-family-contract.md) — exact supplier allocation and released supplier purchase-order contract
16. [`PA-05B-H2 — Multi-line Dispatch execution correction`](docs/architecture/pa-05b-h2-multiline-dispatch-execution-contract.md) — atomic multi-line load, trip-wide departure revalidation, and multi-line successful delivery
17. The relevant contract under `docs/architecture/`
18. The corresponding GitHub issue and pull request

## Architecture method

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

Business architecture comes before implementation. Implementation agents may execute approved contracts but must not invent or alter domain ownership, authoritative calculations, or production backend behavior without an explicit approved task.

## Delivery workflow

```text
Contract
→ GitHub issue
→ Bounded implementation branch
→ Tests and validation
→ Pull request
→ Review
→ Merge
```

Independent modules may be implemented in parallel when they have approved contracts, separate ownership, typed fixture interfaces, and a later bounded integration PR.

## Repository tour

- `src/modules/atlas/` — Atlas shell and application composition
- `src/modules/weekly-menu/` — Weekly Menu in-memory domain and workbench
- `src/modules/attendance/` — Attendance in-memory domain and workbench
- `src/modules/planning-input-readiness/` — Planning Input Readiness domain
- `docs/architecture/` — architecture baselines and domain contracts
- `docs/decisions/` — decision records
- `docs/business-rules/` — business-rule catalogue
- `docs/ui/` — UI specifications
- `docs/rollout/` — migration and rollout plans
- `.github/workflows/` — CI and review-artifact automation

## Standard validation

```bash
pnpm ops:workspace
pnpm format
pnpm typecheck
pnpm test
pnpm build
git diff --check
```
