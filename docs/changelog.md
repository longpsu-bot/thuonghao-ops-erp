# Changelog

All notable architecture, documentation, and implementation changes should be recorded here.

---

## 2026-07-12 — Master data review baseline accepted

### Accepted baseline

- Vietnamese staff-facing master-data review package is accepted as a practical baseline for staff review.
- The package may be revised after ingredient master-data cleanup, unit review, and recipe quantity review.
- The accepted direction remains: calculation rules must be configurable, viewable, versioned where needed, traceable, and explainable. No hidden or hard-coded magic calculation rules are allowed.

### Relevant documents

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
