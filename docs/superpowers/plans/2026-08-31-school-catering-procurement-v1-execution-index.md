# School-Catering Procurement V1 — Execution Index

**Canonical design:** `docs/superpowers/specs/2026-08-30-school-catering-procurement-v1-design.md`

## Execution order

Implement and review these plans sequentially. Do not stack implementation from later slices on an unaccepted earlier slice unless explicitly authorized.

1. `docs/superpowers/plans/2026-08-31-school-catering-procurement-v1-backend-foundation.md`
   - branch: `feat/sc-proc-01-backend-foundation`
   - boundary: Planning Purchase Handoff + Allocation Family backend/read API
   - stop: Draft PR + backend CI/review gate
2. `docs/superpowers/plans/2026-08-31-school-catering-procurement-v1-allocation-workbench.md`
   - branch: `feat/sc-proc-02-allocation-workbench`
   - prerequisite: SC-PROC-01 merged/accepted
   - boundary: connected `Phân bổ nhà cung ứng` UI + Planning transition
   - stop: exact-head hosted browser acceptance
3. `docs/superpowers/plans/2026-08-31-school-catering-procurement-v1-po-release.md`
   - branch: `feat/sc-proc-03-po-release`
   - prerequisite: SC-PROC-02 merged/accepted
   - boundary: PO drafts → numbered release → print/PDF
   - stop: full Procurement V1 hosted acceptance; no merge without user approval

## Codex settings for every slice

- Model: **GPT-5.6 Sol**
- Reasoning: **Medium**
- Agents: **1**
- Parallel agents: **Off**
- Subagents: **Off**

Increase reasoning only if a concrete SQL concurrency/RLS ambiguity cannot be resolved from the design and named reference files. Report the reason before expanding exploration.

## Credit/time discipline

- Start a fresh Codex thread for each SC-PROC slice.
- Read the canonical design, the current slice plan, and only the reference files listed in that plan.
- Do not perform a broad repository tour.
- Use TDD and the focused tests named in the plan.
- Do not repeatedly run repository-wide Vitest or every pgTAP suite locally.
- GitHub Actions is the comprehensive format/typecheck/test/build/Supabase-diff/integration gate.
- If local Supabase/Docker is unavailable, do **not** spend the task repairing Docker. Run the checks that do not require it, push a Draft PR, and let the existing Supabase Smoke/Full Integration workflows execute the database certification. Debug only a failing CI reproducer afterward.
- Re-fetch `origin/main` immediately before branch creation and before final PR certification.

## Non-negotiable scope boundaries

- OPS_SYSTEM_MAP v1.0 / ARCH-002 remains authoritative.
- Supabase Staging is Atlas authority; Retool/OPS v1 is workflow evidence only.
- No Live OPS or Retool mutation.
- No production deployment.
- Preserve PA-05D/PA-05E wholesale behavior.
- Do not use wholesale `release_purchase_handoff` or `fulfilment_allocation_*` as the school-catering implementation shortcut.
- No Ingredient/Supplier code-numbering correction inside Procurement PRs; track that as separate Admin follow-up.
- No Warehouse, Dispatch, Finance, price/tax/invoice/payment, supplier acknowledgement, released-PO cancellation/revision/replacement, or external supplier messaging in Procurement V1.
- Operators never type official PO numbers; V1 release generates `PO-YYYYMMDD-NNNN` server-side.
- React consumes shaped `atlas_api` reads/commands and does not reconstruct authoritative business rules.

## Standard first message for a Codex slice

Use this pattern, replacing only the plan path/branch/title for the current slice:

```text
Implement the approved OPS / Project Atlas School-Catering Procurement V1 slice from the repository's current origin/main.

Governing authority:
- OPS_SYSTEM_MAP v1.0 / ARCH-002
- docs/superpowers/specs/2026-08-30-school-catering-procurement-v1-design.md
- <CURRENT_SLICE_PLAN_PATH>

Recommended settings:
- GPT-5.6 Sol
- Medium reasoning
- one agent
- parallel agents off
- subagents off

Before editing:
1. fetch origin/main and confirm the exact starting SHA;
2. create <CURRENT_SLICE_BRANCH> from fresh origin/main;
3. read only the design, current slice plan, and the exact reference files listed by the plan;
4. state any blocking contradiction before coding. Do not broaden scope to resolve a contradiction silently.

Execution:
- follow the plan task-by-task with TDD;
- preserve all listed domain/authority boundaries;
- use focused local checks only;
- if local Supabase/Docker is unavailable, do not repair infrastructure as part of this task; use GitHub Actions for database certification;
- keep the PR Draft;
- do not mutate Live OPS, Retool, or production;
- do not merge.

At the end, report exact head SHA, changed files, focused local evidence, GitHub check status, hosted preview when applicable, and any remaining review gate.
```

## Completion definition

Procurement V1 planning is complete. Implementation is complete only after all three slices are accepted in sequence and the exact-head SC-PROC-03 preview proves the cross-stage flow:

```text
Planning
→ Purchase Handoff
→ Allocation Family
→ supplier split / rebalance
→ PO draft
→ RELEASED_TO_SUPPLIER
→ official print/PDF
```

and proves that an upstream edit before release stales/rebalances only the affected Procurement objects while a released PO remains immutable.
