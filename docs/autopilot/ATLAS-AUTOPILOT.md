# Atlas Autopilot Mandate

**Status:** ACTIVE — OWNER-CONTROLLED, TIERED BOUNDED RECOVERY.  
**Owner amendment:** 16 October 2026, following PRs #392/#388 failed acceptance.  
**Current control-plane checkpoint:** align these three governance documents in existing Draft #393, then resume the sole technical priority, `ATLAS-C388-PREPARATION-DIAG-01` — diagnosis only. Full [execution plan](ATLAS-RECOVERY-392-388-2026-10-16.md); [active baton](ACTIVE_TASK.md); [Issue #389](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/389).

Task A is **PASS** at frozen #392 `6f9f288c76cfa48691fca2f4968ce03185502bb2`: Frontend [38921984408](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/38921984408) and Supabase Smoke [38921984463](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/38921984463) PASS; Full Integration SKIPPED. The UI remains Draft for Owner review on **17 October 2026**. No #392 changes, additional tests/certification, CI reruns, merge or deployment before that decision; these results do not certify #388.

The Owner explicitly supersedes the old Task A active/Task B queued sequence with this bounded priority. Earlier failures remain historical evidence. Draft #393 is not merged into `main`: direct thread authorization covers the connected runner, not silent adoption by main-following automation. Diagnosis approval does not authorize #388 SQL optimization, change limits, merge/deploy code or launch a new process by itself.

## Control loop

```text
Owner-approved bounded issue → verify true latest repo & actual checkout
→ classify failure (fixture/oracle vs flaky harness vs app vs performance vs business safety)
→ smallest permitted correction → focused evidence → normal exact-head CI
→ independent review → PASS or documented FAIL/BLOCKED → STOP
```

- **No endless automation:** one active task, one narrow change set, no speculative optimization ladder. Two repeats of the _same_ failure after focused attempts → STOP and report. An unrelated/new failure can be classified but not used to widen scope silently.
- **STOP is strategy-specific:** a known test fixture typo or stale assertion can be fixed within an Owner-approved recovery task. Do not use STOP to freeze harmless repair; do not classify a real regression as test fragility.
- **Validation proportional to risk:** fast focused tests during development, mandatory complete operational safety/latency and exact-head GitHub CI for release, and separate multi-cycle stress/soak evidence. Eight-cycle history tests do **not** block independent UI PR #392. Existing tests are retained; no xfail/skip/threshold inflation to manufacture success.
- **No early green:** 23/38 SQL assertions is incomplete; 588 focused SQL assertions do not certify #388 Preparation. Unknown results remain UNKNOWN until authoritative readback.
- **One task at a time:** Task A is completed/frozen. Finish the #393 governance checkpoint, then only the explicitly promoted #388 transaction-wide Preparation diagnosis. At most one baseline and one controlled diagnostic; stop with evidence and one remediation proposal. No SQL implementation or other task is automatically promoted.

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
- #385–#387 and Warehouse remain parked, not discarded. #388 remains an investigational Draft with diagnosis-only authority; #392 remains a frozen Draft pending Owner acceptance on 17 October. Do not merge, force-reset, overwrite existing worktrees or combine their source.
- Do not create test infrastructure, broad multi-agent loops, 8-cycle scale replays or all-repo certification simply to make Autopilot appear active.
- Every task ends with head SHA, verification scope, source of failed/passed evidence, risk classification, PASS/FAIL/BLOCKED, and explicit next Product decision. Do not auto-promote queued work.

Historical visual D1/D2 art direction and Owner-selected C are preserved in [Issue #389](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/389), [Draft #392](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/392) and older Git history; those artifacts no longer define the active execution horizon.
