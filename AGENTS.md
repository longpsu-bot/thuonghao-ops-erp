# AGENTS.md

## Project mission

Build OPS ERP (Project Atlas), a maintainable and transferable ERP for school catering and ingredient distribution.

## Authority hierarchy

1. Approved documents in `docs/`
2. Database migrations and tests
3. Application code
4. Chat discussions and AI memory

When code conflicts with approved documentation, stop and report the conflict.

## Mandatory reading before implementation

- `README.md`
- `docs/handbook/01-vision-product-charter.md`
- `docs/decisions/decision-register.md`
- `docs/business-rules/business-rule-register.md`
- relevant module specifications and API contracts

## Architecture rules

- Use React and TypeScript for the primary frontend.
- Use Supabase and PostgreSQL for authoritative backend logic.
- Use a modular-monolith architecture.
- Frontend coordinates user interaction; backend decides authoritative business outcomes.
- One business action should map to one transactional backend command where practical.
- Released operational documents must not be silently recalculated.
- Every effective operational quantity must retain traceability to its source and adjustments.
- React code must not use Supabase service-role credentials.
- Security must be enforced through backend privileges and RLS, not only UI visibility.

## Change-control rules

Codex and other implementation agents must not, without an approved ADR or explicit task instruction:

- change module boundaries;
- introduce new business concepts;
- alter status lifecycles;
- change calculation precedence;
- add major dependencies;
- bypass RLS or security controls;
- edit production data directly;
- alter API contracts silently;
- disable tests;
- make broad unrelated changes.

## Task boundaries

Each implementation task should:

- address one bounded capability;
- identify allowed modules and expected files;
- state prohibited changes;
- include acceptance criteria;
- include required tests;
- update affected documentation in the same change.

Prefer small, reviewable changes. Unexpectedly broad diffs must be stopped and explained.

## Database rules

- All schema changes must use version-controlled migrations.
- Do not manually alter production schema outside approved emergency procedures.
- Preserve stable line identity and traceability across demand, requirements, procurement, and fulfilment.
- Do not create direct dependencies from new OPS ERP modules to undocumented legacy internals; use controlled adapter views or APIs.

## Definition of done

A task is done only when:

- acceptance criteria pass;
- relevant automated tests pass;
- security implications are reviewed;
- documentation is updated;
- migration and rollback effects are stated where applicable;
- the change summary identifies files changed and any open risks.
