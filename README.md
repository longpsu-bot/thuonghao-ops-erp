# Thượng Hảo OPS ERP

**Project codename:** Atlas

Atlas is the operational management platform for Thượng Hảo's school catering and ingredient-distribution business.

The repository is the authoritative source for business definitions, architecture, contracts, implementation, tests, rollout guidance, and review history. Chat history and AI memory are working aids, not formal project records.

## Current status

Atlas has completed the Admin / Master Data Management in-memory prototype sequence, the bounded PD-05.1 Dispatch and Delivery foundation, the PD-05.2 Dispatch integration/operator-workflow review, the MVP vertical-slice operator review, and the fixture-backed MVP morning chaos simulation. The synthetic vertical slice now traces school catering, mixed fulfilment, wholesale, delivery exception/return, and blocked operating-day scenarios from source need to delivery outcome while preserving domain ownership and operator attention. Atlas page `mvp-operations-simulation` exposes the 02:00–08:00 simulation as a read-only review surface.

PA-01 now proposes the Atlas persistence architecture before any database implementation. It defines canonical identity, persistence classifications, aggregate and transaction boundaries, immutable snapshots and revisions, source-owned evidence, authorization capabilities, audit, derived read models, and the legacy migration boundary. It authorizes no schema, migration, RLS, RPC, Edge Function, backend, Supabase client, Retool, credential, or production-data change.

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

No Supabase credential or production-data access is required for the current in-memory prototype work.

Before changing code, read `AGENTS.md` and the relevant domain contract.

## Read first

1. [`AGENTS.md`](AGENTS.md) — repository operating rules and hard boundaries
2. [`ARCH-001 — OPS ERP Business Architecture`](docs/architecture/arch-001-ops-erp-business-architecture.md) — principles and domain-first method
3. [`ARCH-002 — Atlas System Map`](docs/architecture/arch-002-atlas-system-map.md) — official feature-placement, ownership, traceability, and delivery map
4. [`Atlas Vision`](docs/architecture/atlas-vision.md) — why Atlas exists and what success means
5. [`Roadmap`](docs/architecture/roadmap.md) — delivery order and current status
6. [`PA-01 — Atlas Persistence Contract`](docs/architecture/pa-01-atlas-persistence-contract.md) — proposed authority for future persistence design
7. The relevant contract under `docs/architecture/`
8. The corresponding GitHub issue and pull request

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

## Source-of-truth rule

Important decisions must be recorded in this repository through architecture documents, contracts, GitHub issues, code, tests, or pull-request history. A future developer or software partner should be able to clone the repository and continue without depending on private chat history.
