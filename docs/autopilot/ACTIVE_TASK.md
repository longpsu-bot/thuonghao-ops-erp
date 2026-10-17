# Atlas Autopilot — Active Task

**CURRENT AUTHORITATIVE OWNER DIRECTIVE — 18 October 2026**  
**Execution specification:** [Issue #400 — Atlas UX revisions and traceable Need → new-number PO](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/400).

This file supersedes the **17 October #388 diagnosis/optimization baton** and older commands in [Issue #389](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/389), [Issue #398](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/398) and the retained [16 October recovery runbook](ATLAS-RECOVERY-392-388-2026-10-16.md), but does not change historical evidence or retroactively waive failed acceptance tests. **#393 remains a Draft and is NOT adopted into main**; this direct Owner instruction must be passed to an already-connected Codex session. A GitHub update does not start a runner.

## Only active implementation task — A: #392 UX acceptance repairs

Review the Owner's actual local PRODUCT-REVIEW-PR392.md in the authorized session before implementation; disclose if not accessible. Start from verified Draft [#392](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/392) head `6f9f288c76cfa48691fca2f4968ce03185502bb2`, preserve unrelated changes/stashes, keep the PR Draft. The User reports three new acceptance defects:

1. **Allocation Discard loses keyboard focus:** restore focus to a persistent, still-mounted initiating control after dialog exit without fake focus forcing or changing dirty/UNKNOWN guards.
2. **Mobile quantity is detached from identity:** ensure editing at 390 px always shows School/delivery, Ingredient, Unit, service date and relevant Supplier alongside the exact field/value; keep association after sort/filter/Save.
3. **"Tiếp tục lên đơn" misstates a consequential action:** this is `controller.prepare(...)` in `ProcurementWorkbench.tsx`, not navigation. Present a clear **"Chuẩn bị đơn mua"** action and describe Planning release/Handoff/supplier support effects. It does NOT officially issue PO; `Phát hành đơn mua` remains separately authorized.

The earlier seven Owner visual defects from [#392 review](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/392#issuecomment-6236435366) also remain applicable: 50-School picker, Pantry School selection, two Pantry source categories, clipped Allocation action, Schools management sub-jobs, row-delete affordances, Ingredient document-code copy. **Important supersessions**: [Pantry two distinct source categories](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/392#issuecomment-6236559983) and [no required Ingredient document code on supplier PO](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/389#issuecomment-6236671930) are already Owner-approved business meanings. The present Pantry purpose-free v4 is incompatible and MUST NOT be deployed unchanged.

**A acceptance:** actual populated browser interactions/screens at 1366×768 and 390×844 (also 1440×900), focus, identity/quantity context, transparent Prepare versus official PO release; meaningful red→green regressions and exact-head frontend CI. A CI pass is not substitute for actual Product visual acceptance. Contract-dependent Pantry and PO code work is separately gated below.

## Queued, NOT simultaneously active

- **B1: Pantry authoritative source separation** — separately persist `planning_identified_supplement` (Bổ sung) and `school_requested_supplement` (Đặt theo yêu cầu nhà trường) even for the same School/date/Ingredient, e.g., distinct 5+3 rows with exact 8 derived only under current family/composition rules. Purpose category is NOT the ADDITIVE/COMPLETE mode. Requires a compatible forward SQL/API/uniqueness design and DB Full Integration; do not deploy unapplied v4 as-is.
- **B2: PO Ingredient outward document code optional** — remove visible Mã hàng and the ingredient-code release/export blocker across preliminary and official PO, XLSX/PDF/ZIP, preserving mandatory Supplier identity, hidden machine IDs and historical immutable snapshots. Separate bounded backend/document contract.
- **C: Need amendment with traceable new-number PO** — **authoritative business result is APPROVED:** append Need quantity+reason+Actor+R/D history, review current complete supplier/date replacement Draft, explicitly release new official PO number and link/supersede prior PO without changing it, preserve audit even when Supplier presents old PO. Payment will be based on future actual **accepted receipts**, not PO quantity; Warehouse/payment work is not included. Current #398/#399 and #388/#396 approaches failed their release/performance gates; do NOT silently reuse or bypass D-037. Produce smallest exact contract bridge and implementation only when safe and fully authorized; new business authority/persistent proof requires Owner decision. No auto-start of C while A/B active.
- **SOP:** Vietnamese exceptional-correction SOP is DRAFT; not executable cutover authority until separately approved.

## Hard limits and stop

Use `OPS_SYSTEM_MAP v1.0` and **FACTS EXPLICIT — STATE DERIVED — SUPPORTING OBJECTS GENERATED**. PostgreSQL owns exact arithmetic/quantity, authorization, transaction, receipt/replay, immutable released snapshots and source lineage; React coordinates presentation and local drafts only.

No automatic merges, PR Ready promotion, hosted Atlas Staging/Production writes, OPS v1/Retool writes, released supplier commitments, Warehouse start, or #388/#396 optimization loops. Preserve existing branch heads and the user's original checkout/stash. One active task/PR at a time, focused tests first, appropriate DB security/concurrency/integration before release. Two same-root failed strategies → STOP with quantitative evidence; no threshold inflation or test skips. **Staging is at migration 109, Pantry v4/C unapplied.**

Each checkpoint must report exact SHA, affected files, source/proof boundary, PASS/FAIL/BLOCKED for UX, Pantry, PO-code, Need correction separately, exact CI + Full Integration status and evidence limitations. Stop on unresolved Product contract/permission or unsafe lifecycle change. **Follow Issue #400 for the complete currently authorized sequence; do not infer missing permissions or silently execute later queued tasks.**
