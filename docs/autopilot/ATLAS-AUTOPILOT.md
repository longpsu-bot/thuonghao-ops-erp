# Atlas Autopilot Mandate

**Status:** ACTIVE — OWNER-CONTROLLED, TIERED BOUNDED RECOVERY.  
**Owner amendment:** 16 October 2026, following PRs #392/#388 failed acceptance.  
**Current control-plane task:** `ATLAS-UI392-CI-REPAIR-01` only. Full [execution plan](ATLAS-RECOVERY-392-388-2026-10-16.md); [active baton](ACTIVE_TASK.md); [Issue #389](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/389).

This supersedes the merged 16 October D1/D2 design-only pause and the later PR #392 blanket FAIL/STOP instruction **only to the extent of this exact, bounded CI repair**. It does not retroactively convert failed evidence to PASS, authorize #388 SQL optimization, merge/deploy code, or launch a Codex process. If this document is still in an unmerged PR, agents following `main` must not pretend it is adopted.

## Control loop

```text
Owner-approved bounded issue → verify true latest repo & actual checkout
→ classify failure (fixture/oracle vs flaky harness vs app vs performance vs business safety)
→ smallest permitted correction → focused evidence → normal exact-head CI
→ independent review → PASS or documented FAIL/BLOCKED → STOP
```

- **No endless automation:** one active task, one narrow change set, no speculative optimization ladder. Two repeats of the *same* failure after focused attempts → STOP and report. An unrelated/new failure can be classified but not used to widen scope silently.
- **STOP is strategy-specific:** a known test fixture typo or stale assertion can be fixed within an Owner-approved recovery task. Do not use STOP to freeze harmless repair; do not classify a real regression as test fragility.
- **Validation proportional to risk:** fast focused tests during development, mandatory complete operational safety/latency and exact-head GitHub CI for release, and separate multi-cycle stress/soak evidence. Eight-cycle history tests do **not** block independent UI PR #392. Existing tests are retained; no xfail/skip/threshold inflation to manufacture success.
- **No early green:** 23/38 SQL assertions is incomplete; 588 focused SQL assertions do not certify #388 Preparation. Unknown results remain UNKNOWN until authoritative readback.
- **One task at a time:** #392 CI recovery first; #388 transaction-wide Preparation diagnosis requires an explicit subsequent promotion to `ACTIVE_TASK.md`. Diagnostic approval is not authorization for optimization.

## Governance and role separation

GitHub `longpsu-bot/thuonghao-ops-erp` is the handoff. Read `AGENTS.md`, both control-plane docs, Issue #389 and current relevant contracts. The navigator/Terra role reviews and directs read-only; the implementer/Sol/Codex performs bounded writes only in a verified canonical checkout; an independent reviewer checks behavioral, visual, and contract evidence. Chat, comments, or GitHub PR creation alone do not start a local Codex session.

Use `OPS_SYSTEM_MAP v1.0` and **FACTS EXPLICIT — STATE DERIVED — SUPPORTING OBJECTS GENERATED**. PostgreSQL retains facts, derived state, calculations, authorization, concurrency, immutable released document history and idempotency; React coordinates presentation. Chakra v3 persists for 13 workbenches.

## Hard Product stops

Stop and require a new Owner decision before:
1. changing an unresolved business policy, domain concept, command or calculation precedence;
2. paid/production infrastructure, new deployments or first Production write-ownership transfer;
3. irreversible supplier PO/PXK communication or real commitments;
4. destructive Production data correction;
5. material RLS/capability/authorization broadening;
6. final Warehouse policy selection or Warehouse implementation;
7. unapproved #388 runtime optimization, changes to public/Preparation/lock timeout ceilings, or waiver of historical proof;
8. merging or deploying Drafts #385–#388 or #392 without their own acceptance and release review.

`ONE_STAFF_PER_OPERATIONAL_TASK` remains in force: existing Actor capability suffices for normal work, without adding a generic second-person approval, while scopes/audit/immutable evidence remain mandatory.

## Environment, preservation, and finish

- Atlas Staging `rnzxmxiiqgtdevzregff`: read-only in this task; last accepted migration 109. OPS v1 Supabase `qnthofvccilhnefdcxnz` and Retool: hard NO-WRITE. Atlas Production: no approved target.
- PRs #385–#388 and Warehouse remain parked, not discarded. #392 remains Draft pending acceptance; do not merge, force-reset, overwrite existing worktrees or combine with #388.
- Do not create test infrastructure, broad multi-agent loops, 8-cycle scale replays or all-repo certification simply to make Autopilot appear active.
- Every task ends with head SHA, verification scope, source of failed/passed evidence, risk classification, PASS/FAIL/BLOCKED, and explicit next Product decision. Do not auto-promote queued work.

Historical visual D1/D2 art direction and Owner-selected C are preserved in [Issue #389](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/389), [Draft #392](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/392) and older Git history; those artifacts no longer define the active execution horizon.
