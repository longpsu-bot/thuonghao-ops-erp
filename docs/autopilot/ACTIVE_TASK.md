# Atlas Autopilot — Active Task

**Current Owner priority — 16 October 2026:** Publish the three-document governance alignment in policy Draft [#393](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/393) **FIRST**, then resume only bounded diagnosis on Draft [#388](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/388). Hold [#392](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/392) unchanged for **Owner UI/Product review on 17 October 2026**; no additional edits/certification, automatic review, merge or deployment.

**Immediate control-plane checkpoint:** align only this baton, the mandate and the recovery runbook in existing Draft #393, then resume the single technical priority below. No timed #388 run starts before that checkpoint is published. This is the Owner's explicit thread authorization while #393 remains unmerged; no new implementation or policy-adoption claim. UI #392 is frozen at its exact passing head: no changes, additional tests/certification, manual CI reruns, merge or deployment before the Owner's review decision.

**Active bounded task:** `ATLAS-C388-PREPARATION-DIAG-01` — **DIAGNOSIS ONLY**. Explicitly Owner-promoted in [Issue #389](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/389); today’s directive confirms priority. The promotion is not authority to change #388 SQL, raise timeouts, rerun an unbounded certification loop, merge or deploy.

**Completed previous task:** `ATLAS-UI392-CI-REPAIR-01` — **PASS** at `6f9f288c76cfa48691fca2f4968ce03185502bb2`. Frontend [38921984408](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/38921984408) PASS; Supabase Smoke [38921984463](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/38921984463) PASS, Full Integration **SKIPPED**. UI feature itself remains Draft, pending Owner acceptance. These results never certify #388.

**Controlling runbook:** [ATLAS-RECOVERY-392-388-2026-10-16.md](ATLAS-RECOVERY-392-388-2026-10-16.md) (newer checkpoint at top). **Policy branch status:** Draft #393 is not merged into `main`; direct Owner thread authorization covers the currently connected task, but main-following automation must not falsely claim adopted policy. This GitHub edit is a handoff, not proof that Codex executed.

## Current #388 evidence and problem

- Preserved Draft head: `11cda965cb87b16035b361dd5d52620950fd0fd9`; 588 focused assertions PASS.
- Strict31: 50 Schools × 5 Ingredients = 250 families; **0/8 cycles**, **0/20 final assertions**; first post-correction Preparation exceeds unchanged **20 seconds**; whole local transaction rolls back to zero business residue.
- The interrupted frame was `school_catering_lock_handoff_source` invoked from createDrafts. This is **not** cost attribution.
- Static source review: C migration `supabase/migrations/20261015065552_operator_confirmed_need_correction.sql` calls the handoff lock in a family loop (near line 3365). The underlying implementation (in `20260831090000_school_catering_handoff_allocation.sql`, near line 80) has **two family-filtered `FOR KEY SHARE` scans** of Handoff batches/revisions. Instrument call counts, per-call total latency, query plans and lock waits before proposing a change; source inspection alone cannot prove it is the bottleneck.

## Authorized work sequence (one task, two phases)

**Phase B1 — evidence-only diagnosis now:** verify canonical checkout, current main and #388 exact SHA; preserve dirty worktrees, local fixtures and raw logs. On a disposable local database clone, isolate the first post-correction Preparation with unchanged workload, role, 13-relation ANALYZE prerequisite, 8s public/20s Preparation/1s lock-entry/disclosed nested5s constraints. Capture transaction wall time; stage timing for `createDrafts`; call counts/timing and waits for `school_catering_lock_handoff_source`; `pg_stat_statements`/function statistics where safely supported; targeted `EXPLAIN (ANALYZE, BUFFERS)` under rollback-only conditions. Control for repeated row scans, locks, query-plan instability, snapshot history and test overhead. Use only already approved local/synthetic data. **No optimization implementation or benchmark reclassification.**

Bound B1 to **one baseline plus one controlled diagnostic**, not repeated eight-cycle runs. Reuse the verified original public prefix and existing local helpers on proven-absent owned clones. Read-only live source/hash/metadata/global-schema/physical-state verification precedes probes; disclose inherited dead tuples and shared-cache/first-use limitations. Session-only instrumentation must preserve limits/roles and report incomplete/inlined/canceled work; inclusive parent/child times are not additive. Do not install new instrumentation, reset shared statistics/caches, change global settings/grants or add per-edge ANALYZE. A prefix/setup failure is INVALID for target-cost attribution; report it before any further attempt.

**Phase B2 — decision handoff:** produce one supported root-cause hypothesis with measurements, a minimal reproduction, a single bounded remediation candidate, scope of SQL bodies and unchanged predicates, expected risk and parity tests. Return PASS for diagnosis only if measurements are trustworthy; otherwise BLOCKED with precise missing evidence. Owner must separately authorize runtime remediation.

## Policies and prohibitions

1. `OPS_SYSTEM_MAP v1.0`; **FACTS EXPLICIT — STATE DERIVED — SUPPORTING OBJECTS GENERATED**. Keep exact quantities, Units, School/Ingredient/Supplier scope, RLS/capabilities, idempotent receipts, dirty/UNKNOWN guards, immutable released PO/PXK and full Handoff continuity.
2. No changing public 8s / Preparation 20s / lock-entry 1s / nested 5s limits. Keep the eight-cycle stress oracle intact. Do not assert success based on 588 focused checks or promote the interrupted frame to a measured cause.
3. Freeze #392 at `6f9f288c`: no modification, additional focused/full certification or CI rerun, merge or deployment until Owner review on 17 October and a separate decision. Existing Task A PASS does not itself accept the whole UI product.
4. No hosted Atlas Staging writes (latest accepted migration 109), no OPS v1 `qnthofvccilhnefdcxnz` / Retool writes, no Production or real supplier commitments. Warehouse and #385–#387 remain parked.
5. Root/Terra navigator and independent reviewer remain read-only; Sol/Codex may run only bounded authorized local diagnostics after `AGENTS.md` canonical checkout verification.
6. End with exact source SHA, test/setup conditions, quantitative evidence and timings, no-change confirmation, PASS/FAIL/BLOCKED and the next Owner decision. **No automatic task succession.**

**Next Product decision:** after B1/B2 evidence, authorize or reject one bounded #388 remediation; separately review #392 tomorrow. Keep #393 Draft until its control-plane changes are reviewed; a Github PR does not start or authorize a local runner by itself.
