# Changelog

All notable architecture, documentation, and implementation changes should be recorded here.

---

## 2026-07-12 — UI and documentation before Supabase schema

### Accepted

- Product owner confirmed the implementation sequence should remain documentation-first and UI-first before Supabase schema implementation.
- Supabase remains the target backend platform, but schema work should follow reviewed workflows, UI states, data contracts, master-data review, and calculation-rule design.

### Updated

- `docs/decisions/decision-register.md`
- `docs/current-context.md`
- `docs/handbook/12-rollout-and-migration-plan.md`

---

## 2026-07-12 — Vietnamese master-data review package accepted as baseline

### Accepted

- Vietnamese staff-facing master-data review package is accepted as a practical baseline.
- The package may be revised after staff complete the review of ingredients, units, and recipe quantities.

### Added

- `docs/master-data/vi/README.md`
- `docs/master-data/vi/01-ra-soat-danh-muc-nguyen-lieu.md`
- `docs/master-data/vi/02-dinh-nghia-bang-nguyen-lieu.md`
- `docs/master-data/vi/03-quy-tac-don-vi-va-quy-doi.md`
- `docs/master-data/vi/04-huong-dan-ra-soat-dong-cong-thuc.md`
- `docs/master-data/vi/05-mo-hinh-cau-hinh-quy-tac-tinh-toan.md`

---

## 2026-07-12 — Foundation baseline

### Added

- Repository foundation.
- Root README.
- Root AGENTS.md.
- OPS ERP Handbook Documents 01–12.
- Decision Register.
- Business Rule Register.
- Open Questions Register.
- Business Glossary with language policy.
- Current Context.
- API Contracts Catalogue.
- UI Catalogue.
- Database Governance.
- Test Strategy.
- Operations Runbook.

### Decisions recorded

- GitHub is the source of truth.
- React and TypeScript are the primary frontend direction.
- Supabase and PostgreSQL are the primary backend direction.
- Codex is the implementation assistant under bounded architecture instructions.
- English is the authoritative documentation language; Vietnamese labels are added selectively.

### Notes

These documents are baseline drafts. Business-critical documents must be reviewed before implementation begins.
