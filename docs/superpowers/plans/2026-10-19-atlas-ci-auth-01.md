# ATLAS-CI-AUTH-01 Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans for the bounded test correction and one independent read-only review before certification.

**Goal:** Separate authentication correctness from realistic School browser responsiveness without changing runtime or security policy.

**Architecture:** Keep the real mounted Atlas application and its keyed ApplicationSession. Reuse showSchool(2); retain real account-menu interaction and the stale edit after a clean sign-out callback. Characterize browser performance separately with disposable fixtures.

**Tech Stack:** React, TypeScript, Vitest/JSDOM, existing Chakra system, connected Chrome, GitHub Actions.

**Spec:** [Issue #403 supersession](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/403) and the Owner's ATLAS-CI-AUTH-01 execution brief. Start at frozen #402 head `7dd922230be231d81971fbdab6f3c2a61f3056c4`.

## Global Constraints

- Only the task-authorized D: checkout and existing clean task branch; preserve other worktrees/stashes and #402.
- No runtime, dependency, global timeout, business, authorization, schema or hosted-data changes.
- Clean sign-out maximum 5,000 ms; identity test budget must be measured, with no repeated timeout increases.
- Preserve dirty/UNKNOWN, stale edit, both identities, real remount, authoritative defaults, no hidden Save and no residual dialog.
- No invented browser SLA; stop for Owner review on genuine security/performance defects or unreliable evidence.
- One stacked Draft targeting `codex/atlas-b1-pantry-two-source`; no merge/deployment or B2/C.

## Review Focus

- A stale edit made after the sign-out callback must be visible before changing identity, so an empty-draft false positive cannot pass.
- Identity B must see exact authoritative defaults and detached identity-A inputs, rather than merely a value different from 123.
- Identity transitions and sign-out must never call School Save implicitly.
- A discarded dirty owner and an UNKNOWN command must retain their distinct existing guard semantics.
- Browser timings must identify fixture/network limitations, memory pressure, cold/warm samples and measurement overhead.

### Task 1: Correct authentication acceptance boundaries

**Files:** Modify `src/vnext/atlas/AtlasVNextApp.test.tsx`; document evidence in `docs/testing/atlas-ci-auth-01.md`.

- [x] Confirm original failing test and historical diagnostic evidence; run a correctly scoped original focused test.
- [x] Split clean sign-out from identity reset: A1 uses loaded Menu with the existing small fixture limit; A2 uses showSchool(2), retaining real UI/callback once, stale edit 123, operator → second-operator, exact fixture defaults and no residual dialog.
- [x] Observe School write calls across both journeys and assert none. Leave existing dirty regression assertions unchanged.
- [x] Run focused A1/A2/A3 and recovery regressions; two passing A1/A2 samples support the unchanged 5-second budgets. See the evidence report for retained failed attempts and final 10-test PASS.

### Task 2: Characterize real browser responsiveness

**Files:** Temporary disposable benchmark entry/evidence outside committed runtime; report and original screenshots under `docs/testing/` where feasible.

- [ ] Use actual Atlas UI in connected Chrome with comparable 34/50 active School fixtures, Vietnamese names, School types, defaults and groups.
- [ ] At 1440×900, 1366×768 and 390×844 record cold/warm opening, search, filter, selection, edit/validation, view change, permitted Save/readback and return navigation.
- [ ] Record device/browser/DPR, sample counts/distribution, console/network/main-thread evidence where supported and original screenshots. Report a missing or unreliable gate as BLOCKED; never substitute JSDOM timings.
- [ ] Stop if a reproducible serious user-facing defect requires production remediation.

### Task 3: Review and exact-head certification

- [x] Obtain one independent read-only review of the bounded diff and assertion manifest; no actionable findings, bounded correction PASS, overall browser gate BLOCKED.
- [ ] Format changed files, check diff, commit and push one meaningful task branch; create/attach one stacked Draft PR.
- [ ] Dispatch normal Frontend CI once for the exact pushed head (stacked PRs do not trigger the main-target PR workflow automatically). Observe frozen install, boundary/typegen, format, TypeScript, full tests and actual build.
- [ ] Record exact SHA/run/manifest, historical failures and PASS/FAIL/BLOCKED gates. No new Supabase certification for this frontend-test-only change. Stop for Product Owner review.

Capture status before publication: Task 1 PASS; Task 2 BLOCKED after real connected
Chrome navigation and same-tab inspection timed out on the memory-pressured host.
There are zero valid browser samples/screenshots. Do not repeat local measurement
or begin performance remediation in this task. Remaining Task 3 publication/CI
results are recorded in the final PR/task handoff without changing the certified
commit merely to embed its own SHA.
