# Atlas Autopilot — Active Task

**Policy supersession (Owner, 16 October 2026):** [ATLAS-AUTOPILOT-RECOVERY-392-388-01](ATLAS-RECOVERY-392-388-2026-10-16.md) supersedes the prior *design-discovery-only* and overly broad *FAIL/STOP no-repair* baton. Keep the older evidence in Issue [#389](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/389) and Draft PRs.

**Task:** `ATLAS-UI392-CI-REPAIR-01`  
**Status:** OWNER-APPROVED PLAN — one bounded CI recovery, **no session presumed running**.  
**Next:** `ATLAS-C388-PREPARATION-DIAG-01` — QUEUED, diagnosis only; **not authorized for automatic succession**.

## Immediate objective

Recover existing Draft [UI #392](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/392) through one focused CI-harness/fixture/interaction task. Preserve the selected compact Chakra ERP UI, 13 connected owners, Weekly Menu landing, Pantry v4, supplier-first PO, current exports, original guards, exact values and historical evidence. #392 is not release-ready.

Pinned initial observations (recheck latest head): runtime `34c85ea87a61fdcfedf33d08e38a4715e9eaeea5`, docs-only `0880db42666649dceb3698b1590af026ced5a5c0`. GitHub Frontend CI reports 4 failures/3,037 passes/2 skipped (registry `node` vs `pnpm`, Ingredient accessible tab, School dirty sign-out timeout, Confirmed Need→Allocation timeout); earlier PXK Cancel focus failure requires focused regression. Supabase CI aborts Pantry SQL line 427 on a malformed UUID after 23/38 assertions. Follow the [exact repair playbook](ATLAS-RECOVERY-392-388-2026-10-16.md#task-a--atlas-ui392-ci-repair-01-the-only-active-implementer-task).

**Authorized now, when a verified Codex/implementer is actually started:** one narrowly scoped repair on the existing Draft #392. Test-only errors do not require another Owner gate when repaired without weakening assertions. Distinct app regressions may be repaired minimally inside the named UI flows; any changed business/API/SQL/capability policy requires new Owner approval. Focused verification first, normal exact-head CI after push, no repeat loops. Same-root failure twice → STOP with evidence.

## Subsequent need work — parked for promotion

[Need #388](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/388) remains an incomplete Draft: 588 focused SQL passes, first genuine post-correction Preparation >20 seconds at 250 families, 0/8 stress cycles, full rollback. The first-cycle failure **remains a genuine blocker**, not a mere overly strict stress gate. Its eight-cycle historical test must be retained and separated from unrelated UI certification. **No change to timeout or #388 acceptance authority is approved.** After Task A, navigator/Owner may authorize one local transaction-wide Preparation diagnosis **without speculative SQL optimization**; no automatic Task B start.

## Operating contract

1. Read `AGENTS.md`, `docs/autopilot/ATLAS-AUTOPILOT.md`, the recovery plan and current Issue #389. Verify canonical checkout with `git fetch origin`, clean working tree, remote and `pnpm ops:workspace` before code edits. Do not overwrite existing dirty/stashed work.
2. One active task; preserve existing PR #392 and #388 branches, no unintended new feature PR or broad rewrites.
3. Maintain `OPS_SYSTEM_MAP v1.0` and **FACTS EXPLICIT — STATE DERIVED — SUPPORTING OBJECTS GENERATED**; exact quantity/Unit, immutable released documents, supplier eligibility, RLS/capabilities, business receipts, state/currentness and dirty/UNKNOWN recovery remain hard gates.
4. Do not merge, deploy, modify hosted business data or grant permissions. Atlas Staging `rnzxmxiiqgtdevzregff` migration 109 accepted; OPS v1 `qnthofvccilhnefdcxnz` / Retool hard NO-WRITE. Warehouse and #385–#387 remain parked.
5. Report a clear PASS / FAIL / BLOCKED outcome, exact tests/head and the next decision. A GitHub plan change **does not itself start Codex**.

This supersedes historical D1/D2-only instructions after the plan's adoption in `main`; visual selection/implementation history remains evidenced in Issue #389 and PR #392.
