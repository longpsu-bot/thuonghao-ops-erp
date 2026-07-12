# OPS ERP Handbook
## 11 — Development Guide

**Document ID:** OPS-HANDBOOK-011  
**Status:** Baseline draft  
**Authority:** Engineering workflow and Codex usage  
**Review required:** Technical review before coding begins  

---

## 1. Purpose

This document defines how OPS ERP should be developed so the codebase remains understandable, testable, and transferable.

---

## 2. Development principle

Architecture comes before implementation.

Codex should implement bounded tasks from approved documentation. It should not invent architecture, module boundaries, data models, or business rules.

---

## 3. Roles

### Product Owner

Owns business intent, priorities, acceptance, and operating constraints.

### Architecture Function

Owns system structure, module boundaries, design rules, documentation consistency, and technical governance.

### Codex

Acts as implementation engineer. Codex may write code, tests, migrations, and implementation notes within approved scope.

---

## 4. Repository structure

Planned structure:

```text
ops-erp/
├── AGENTS.md
├── README.md
├── docs/
├── frontend/
├── supabase/
├── tests/
└── scripts/
```

---

## 5. Required workflow

```text
Business idea
    ↓
Architecture discussion
    ↓
Documentation update
    ↓
Implementation task
    ↓
Codex change
    ↓
Review
    ↓
Merge
```

---

## 6. Codex task standard

Each Codex task should specify:

- goal;
- affected module;
- files allowed to change;
- files not allowed to change;
- business rules involved;
- API contracts involved;
- acceptance criteria;
- test requirements;
- documentation updates required.

---

## 7. Change scope rule

A task should be small enough to review safely.

Preferred limits:

- one feature or fix;
- one module where possible;
- fewer than 10 materially changed files unless approved;
- tests included for business logic;
- no unrelated refactoring.

---

## 8. Forbidden Codex actions

Codex must not:

- change architecture without ADR;
- add major dependencies without approval;
- bypass RLS or permission checks;
- put service-role secrets in frontend code;
- silently change API contracts;
- delete tests to pass CI;
- edit unrelated modules;
- rewrite large areas without review;
- implement business logic from assumptions.

---

## 9. Testing principle

Business rules must be testable. Critical calculations, permissions, releases, and correction flows require tests.

---

## 10. GitHub Actions validation

Routine full-suite validation belongs to GitHub Actions rather than repeated Codex turns.

For each pull request to `main`, the `Frontend CI` workflow runs:

- `pnpm install --frozen-lockfile`;
- `pnpm format`;
- `pnpm typecheck`;
- `pnpm test`;
- `pnpm build`;
- `git diff --check`.

During implementation, Codex should run only the focused checks needed to build or debug the bounded change. After pushing, GitHub Actions becomes the routine merge-gate evidence.

Codex should inspect logs and fix the code only when CI fails. It should not repeatedly run the entire successful suite merely to produce a narrative validation report. Additional local or specialized validation remains appropriate for migrations, security-sensitive changes, production incidents, or tasks whose risks are not covered by the standard workflow.

Copilot or other AI code review is not enabled as a routine gate. Product, architecture, security, and visual workflow reviews remain human-governed and separate from automated CI.

## 11. Documentation principle

A code change that changes behavior should update documentation in the same branch or commit set.

---

## 12. Commit message guidance

Preferred examples:

- `docs: add calculation specification`
- `feat(demand): create wholesale order draft screen`
- `fix(requirements): preserve substitution trace`
- `test(procurement): cover rounding edge cases`

---

## 13. Definition of done

A task is done when:

- implementation matches approved scope;
- focused implementation checks pass where needed;
- the GitHub Actions validation workflow passes;
- affected docs are updated;
- no unauthorized architectural change occurred;
- reviewer can understand the change from the PR summary.

---

## 14. Review note

This guide will become stricter once React, Supabase migrations, and test tooling are introduced.
