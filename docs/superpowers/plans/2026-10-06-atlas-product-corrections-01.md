# Integrated operator review corrections implementation plan

> **For agentic workers:** Use superpowers:subagent-driven-development to execute the ordered checkpoints. The owner-supplied ATLAS-PRODUCT-CORRECTIONS-01 brief is the requirements authority for this task.

**Goal:** Deliver the six connected operator review findings in one draft production PR.

**Architecture:** Retain backend business authority and D-048's static registry, local reducer (`openIds`, `activeId`), and persistent keyed owners. Derive new Recipe authoring Units from Ingredient purchase Units; retain immutable historical evidence. Keep incomplete Menu candidates local and block every consequential save until fully canonical.

**Tech Stack:** Existing React/TypeScript, Atlas Chakra v3 system, Supabase/PostgreSQL, Vitest, pgTAP and existing browser fixtures.

## Global constraints

- Starting main: `dd00f304e43de77b59288e32109db6fd8884c5f7`.
- Branch: `feat/atlas-product-corrections-01`; one draft PR; no merge.
- No hosted migration execution, Retool/OPS v1 changes, production business writes, new dependencies, business concepts, lifecycle changes, conversions, or Backend Convergence 02B–02D work.
- Preserve security-definer configuration, runtime ownership, grants, RLS, concurrency, currentness, immutable evidence, API identity and transaction boundaries.
- Eleven real workspace destinations; keep the existing twelve-capacity fixture.
- Ponytail FULL; preserve the incumbent Atlas visual system; Impeccable final review.

## Task 1 — Recipe Unit authority and Change Order presentation

Files: `src/vnext/atlas/recipes/`, Recipe types/read adapters in `src/modules/atlas/recipes/`, bounded forward migration and pgTAP only if necessary, affected Recipe API documentation.

- [x] Reproduce `RecipeCapability / clears metadata status only after approved discard completes` before editing. Baseline run failed with metadata form still mounted after discard (23 passed, 1 failed).
- [x] Trace discard approval through controller, Dialog exit completion and real browser animation; distinguish production defect from jsdom behavior. Preserve focused regression.
- [x] Expose purchase Unit through existing shaped read if missing; bind new PRESENT authoring to current active purchase Unit, with read-only display and missing/inactive blockers.
- [x] Prove backend mismatched-Unit rejection and historical stored-Unit preservation; retain import/copy/successor semantics.
- [x] Attach derived Change Order Unit to quantity; preserve command bytes and KEEP behavior.
- [x] Run focused frontend/backend regressions, document evidence, commit `fix(recipe): enforce ingredient unit authority`.

## Task 2 — Independent persistent operator owners and launcher

Files: registry/app/shell/launcher/workspace tests; Planning, Procurement, Recipe and Ingredient/Supplier presentation wrappers only as needed.

- [x] Register Thực đơn, Xác nhận nhu cầu, Phân bổ NCC, Đơn mua, Phiếu xuất kho, Đối chiếu PO / Phiếu xuất kho, Trường học, Nguyên liệu, Nhà cung ứng, Công thức, Lệnh điều chỉnh exactly once.
- [x] Reuse current controllers; remove grouped primary switching from production workspace rendering. Preserve Menu/Sĩ số/Bổ sung secondary jobs.
- [x] Route Need handoff to Allocation: exact first-mount date, preserved already-open context and truthful mismatch disclosure.
- [x] Keep each owner mounted/inert on switch, with independent close/sign-out protection and no activation reads.
- [x] Move launcher far left; use existing Phosphor hamburger with accessible name/title and visible menu heading.
- [x] Test independent state, no duplicate/mount/read, all dirty owners, mobile selector and capacity. Commit `feat(atlas): decompose operator workbenches`.

## Task 3 — Resilient local Menu candidate

Files: current Menu parser/review model, `src/vnext/atlas/planning/weeklyMenuSync.ts`, Planning source controller/presentation and focused tests; affected Planning documentation.

- [x] Parse all source cells, retaining valid candidate values and exact per-cell diagnostics with existing codes and source evidence.
- [x] Show concise Vietnamese blocker count and actionable source/cell details; never infer blank/delete/null from invalid data.
- [x] Block Preview/Save writes while blockers exist; only fully valid canonical candidates reach the existing atomic command.
- [x] Test valid/invalid/corrected source, School/date safety, no writes, signature/currentness and correction protections. Commit `fix(planning): retain valid menu sync candidate cells`.

## Task 4 — Integrated certification and draft delivery

Files: existing workspace browser/performance scripts, affected UI/decision/API documentation and one bounded implementation evidence record.

- [x] Capture requested views at 1920×1080, 1440×900, 1366×768, 650×900 and 360×800; certify eleven real destinations and twelve-capacity fixture.
- [x] Run existing switching benchmark and inspect material regression, overflow, active-tab reveal, focus/hidden/inert behavior and mobile access.
- [x] Perform Impeccable and Ponytail reviews with one bounded correction pass.
- [x] Run focused checks plus `pnpm ui:vnext:check`, `pnpm typecheck`, `pnpm test`, `pnpm build-storybook`, `pnpm build`, `pnpm ops:workspace`, `git diff --check`.
- [ ] Commit `test/docs: integrated product corrections certification`, push, create/attach draft PR and verify required CI on final head. Disclose automatic preview if present. Do not deploy or merge.
