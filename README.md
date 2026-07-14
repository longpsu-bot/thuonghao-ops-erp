# Thượng Hảo OPS ERP

**Project codename:** Atlas

Atlas is the operational management platform for Thượng Hảo's school catering and ingredient-distribution business.

The repository is the authoritative source for business definitions, architecture, contracts, implementation, tests, rollout guidance, and review history. Chat history and AI memory are working aids, not formal project records.

## Current status

Atlas is in Planning Domain MVP delivery.

Completed foundations include Weekly Menu, Attendance, Planning Input Readiness, Need Generation, Confirmed Need, and Purchase Handoff. The bounded PD-01 integration and architecture-conformance review is pending review and merge.

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
6. The relevant contract under `docs/architecture/`
7. The corresponding GitHub issue and pull request

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
