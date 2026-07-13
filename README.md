# Thượng Hảo OPS ERP

**Project codename:** Atlas

Thượng Hảo OPS ERP is the operational management platform for a school catering and ingredient distribution business.

The repository is the authoritative source for:

- business and product definitions;
- architecture decisions;
- business rules;
- API and UI specifications;
- database migrations;
- application source code;
- testing, rollout, and operations guidance.

## Current status

The project is in **Foundation Release FR-1**. The current focus is business architecture, governance, documentation, and repository standards before application implementation begins.

## Technology direction

- React and TypeScript for the primary application
- Supabase and PostgreSQL for backend services and authoritative business logic
- Codex as the bounded implementation assistant
- Retool retained only for selected administrative, diagnostic, and support tooling

## Source-of-truth rule

Important project decisions must be recorded in this repository. Chat history and AI memory are working aids, not formal project records.

## Primary architecture baseline

Start with [`ARCH-001 — OPS ERP Business Architecture`](docs/architecture/arch-001-ops-erp-business-architecture.md).

ARCH-001 defines the Atlas mission, domain-first design method, design principles, MVP flow, and architecture freeze for delivery. It is the baseline for future domain contracts and implementation tasks.

## Documentation map

- `docs/handbook/` — governing business and architecture documents
- `docs/architecture/` — backend/domain architecture contracts
- `docs/decisions/` — decision register and ADRs
- `docs/business-rules/` — business-rule catalogue
- `docs/open-questions/` — unresolved design questions
- `docs/api/` — API contracts
- `docs/ui/` — UI specifications
- `docs/rollout/` — migration and rollout plans
- `docs/operations/` — operating runbooks

## Development principle

Business architecture comes before implementation. Codex may implement approved specifications but must not invent or alter architecture without an explicit approved decision.
