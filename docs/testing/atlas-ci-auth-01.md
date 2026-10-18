# ATLAS-CI-AUTH-01 — authentication correction and browser gate

Evidence captured 19 October 2026, Asia/Saigon. Authority: [Issue #403's latest
Owner supersession](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/403).
The older requirement to render 50 Schools inside authentication tests is superseded.

## Code identity and boundary

- Starting SHA and unchanged #402 head: `7dd922230be231d81971fbdab6f3c2a61f3056c4`.
- Task branch: `fix/atlas-ci-auth-01-test-boundary`, already clean at that SHA when this task began.
- Canonical checkout verified: `D:/Project/Repo/OPS/thuonghao-ops-erp`; expected origin, fetch, clean status and `pnpm ops:workspace` passed. `origin/main` was `3667966a3f6703a6585f07ba619969ec851ca7b8` and is an ancestor. The explicit task authorizes the frozen stacked start.
- Target: one Draft against `codex/atlas-b1-pantry-two-source`; final pushed SHA, PR and exact-head CI are recorded in the PR delivery handoff.
- Source manifest: `src/vnext/atlas/AtlasVNextApp.test.tsx` only. Supporting changes are this report, the execution plan and raw focused logs in `artifacts/atlas-ci-auth-01/`.
- Runtime, business logic, schema, dependencies, global timeout, auth/RLS and #402 are unchanged. Other worktrees/stashes are preserved.

## Authentication verification

| Gate                                                                       | Isolated first passing sample | Final focused sample | Budget / verdict           |
| -------------------------------------------------------------------------- | ----------------------------: | -------------------: | -------------------------- |
| A1 clean real-menu sign-out, callback exactly once, no blocker/dialog/Save |                      1,989 ms |               642 ms | 5,000 ms / PASS            |
| A2 real keyed identity remount, no draft leakage or hidden Save            |                      3,625 ms |             2,541 ms | 5,000 ms / PASS            |
| A3 unchanged dirty sign-out, Cancel and explicit guarded Discard           |                             — |             3,884 ms | Unchanged 5,000 ms / PASS  |
| School UNKNOWN outcome requires authoritative recovery; no resend          |                             — |               684 ms | PASS                       |
| School stale outcome requires authoritative recovery; no resend            |                             — |             1,681 ms | PASS                       |
| School success with failed authoritative readback remains locked           |                             — |               545 ms | PASS                       |
| Recipe UNKNOWN blocks exit and retains recovery                            |                             — |             5,207 ms | Unchanged 15,000 ms / PASS |
| Procurement UNKNOWN / retryable failure blocks exit                        |                             — |     1,780 / 1,141 ms | Unchanged 15,000 ms / PASS |
| PXK UNKNOWN retains exact recovery and blocks exit                         |                             — |                62 ms | PASS                       |

Two passing A1/A2 samples support retaining 5 seconds for both tests. These are
observations, not performance guarantees. No timeout was increased. A1 starts
from the real loaded Menu with the existing two-School fixture limit; reaching a
clean authenticated state does not require opening School forms. A2 uses
`showSchool(2)`. The existing dirty test and all recovery tests are unchanged.

Final focused invocation:

```powershell
pnpm test --dir src/vnext/atlas AtlasVNextApp.test.tsx AtlasUnresolvedExit.test.tsx schools/SchoolDefaultsWorkbench.test.tsx -t 'clean sign out calls|a changed identity loses|blocks dirty sign-out|UNKNOWN|unknown|locks a|locks after success' --maxWorkers=1 --reporter=verbose
```

Result: 3 files passed, 10 tests passed; 39 cases excluded by the explicit focused
name filter. These are not newly skipped tests. Total process 67.48 s includes
43.11 s import, 5.10 s environment and 18.18 s test execution. This process duration
is not a real-browser interaction measurement.

### Assertion manifest

| Original obligation                                            | Retained or strengthened coverage                                                                                                                                    |
| -------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Mount actual Atlas as operator and reach School workbench      | A2 retains real Provider/App, Menu, launcher and School navigation; two representative Schools replace catalog-scale coupling                                        |
| Actual account menu → Đăng xuất → one callback                 | A1 and A2 both retain real controls; operator identity label is now asserted                                                                                         |
| Edit after callback, before the parent processes identity loss | A2 retains that exact sequence and now proves `123` is actually present before switching; untouched School stays `317`                                               |
| Rerender as second-operator / second@example.test              | A2 retains real authSubject-keyed ApplicationSession, asserts old School inputs disconnect and checks the new account label                                          |
| Reopen Schools and prior draft is absent                       | Both new fields must be visible/enabled, differ from `123`, and equal their exact authoritative fixture defaults (`280`, `317`); the read must use `second-operator` |
| No unintended Save                                             | New explicit School bulk-Save spy assertions before/after identity transition and after clean sign-out                                                               |
| No residual dialog                                             | Retained final absence check; additionally verifies no residual sign-out blocker and one total callback after new-account inspection                                 |
| Dirty/UNKNOWN safety                                           | Existing dirty assertions unchanged; focused existing recovery regressions passed as listed above                                                                    |

No genuine runtime security defect was established. No production repair is
justified by the observed test timeout.

## Preserved failure evidence

- Frozen GitHub [Frontend failure 39137594276](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/39137594276): 3,064 passed, one composite timeout, two existing skips; build did not execute.
- The supplied prior measurement report/Issue #403 records 34-School journeys of 9.35 s (last green) and 12.53 s (frozen), a 50-School **timeout at** 40.11 s, callback 3.14–4.29 ms and focused sign-out 1.527 s. These are historical observations, not rerun browser measurements.
- This task's correctly scoped unchanged composite reproduced the 5-second timeout: reported test duration 6,769 ms, process 23.12 s. No assertion failure established leakage.
- An initial local command matched similarly named tests inside preserved `.worktrees`; it was interrupted and excluded from acceptance evidence. The observed copied-worktree `Invalid Chai property: toHaveValue` belongs to that invalidly scoped attempt. Subsequent invocations use `--dir src/vnext/atlas`; no repository Vitest configuration was changed.
- Initial memory-pressured focused attempt: unchanged dirty test timed out at 5,741 ms; the initial clean test unnecessarily navigated Schools and timed out at 5,107 ms. The following identity case saw two callbacks. Timed-out async work can continue after cleanup, so that contaminated attempt is not evidence of a runtime double sign-out. The final independent and combined runs passed. Its raw incomplete log remains preserved; no timeout increase, retry policy or skip masks it.
- Earlier #402 field-query attempts and B1 browser/Supabase evidence remain untouched. The historical Supabase certification retains its original SHA; this test-only correction does not require a new backend run.

## Independent 34/50-School browser benchmark — BLOCKED

The real connected Chrome browser was selected. A disposable local-only fixture
entry was prepared under ignored `dist/atlas-ci-auth-01/`, using the actual
AtlasVNextProvider/App and existing application fixtures. It configures comparable
34/50 active School sets, four existing School types, long Vietnamese names,
attendance defaults, three cooking groups and two dispatch groups. Its optional
explicit Save/readback is in-memory fixture behavior only: no hosted client,
network/backend timing or authorization claim. No hosted Atlas/OPS v1/Retool
write was attempted. The local Vite server started at `127.0.0.1:3012` in 713 ms.

| Context                                                  | Observation                                                                                                             |
| -------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| Operating system                                         | Windows 11 Home Single Language, 10.0.26200                                                                             |
| CPU                                                      | Intel Core i7-10510U @ 1.80 GHz; 4 cores / 8 logical processors                                                         |
| OS-visible RAM                                           | 8,168,948 KiB (about 7.79 GiB)                                                                                          |
| Free RAM before work / pressured tests / browser attempt | 886,360 / 279,960 / 483,344 KiB (about 866 / 273 / 472 MiB)                                                             |
| Browser                                                  | Connected local Chrome; installed executable 155.0.8059.80; active engine version unverified because inspection stalled |
| Viewport                                                 | Requested 1440×900 override; actual viewport and DPR could not be verified                                              |
| Initial 34-School navigation                             | Browser Page.navigate command timed out after 10 seconds; tab inventory still showed about:blank                        |
| Inspect same tab                                         | Browser-control call timed out after 30 seconds and its kernel reset                                                    |
| 1366×768 / 390×844 / 50 Schools                          | Not reached                                                                                                             |
| Cold/warm or repeated per-action samples                 | n=0 valid browser samples; no distribution available                                                                    |
| Original screenshots                                     | None captured; screenshot gate BLOCKED                                                                                  |
| Console/network/main-thread evidence                     | Could not collect reliably; prepared instrumentation never yielded usable app evidence                                  |

The confirmed gate is unreliable browser navigation/inspection on this
memory-pressured host, not a measured Atlas performance defect. No valid
click-to-content, search, filter, selection, edit/validation, view-switch,
Save/readback or return-navigation latency can be reported. The 10/30-second
browser-control limits are **not** measured operator-visible Atlas response times.
No 34-versus-50 browser comparison or operational SLA is inferred from JSDOM.
Stop browser work for Owner/environment review; do not start production
performance optimization. The task-created Vite process was stopped and its
temporary Chrome viewport override was cleared.

## Review, certification and rollback boundary

Focused authentication/recovery: PASS. One independent read-only source review
against the frozen base found no actionable findings and returned PASS for the
bounded test correction, without merge approval. It verified original assertion
coverage and the raw focused logs. It explicitly declined to judge browser
latency/appearance, hosted token invalidation, backend RLS and full certification;
those remain governed by their respective evidence, not the review verdict.
Changed-file Prettier and diff whitespace checks passed.

Exact-head normal Frontend CI follows this evidence capture; its authoritative
outcomes and link belong in the final PR/task handoff. Full-suite tests, formatting/typegen,
TypeScript, UI boundary and build must each be reported from the actual run;
none is inferred from focused tests. Overall delivery remains **BLOCKED** while
the required real-browser benchmark is missing, even if Frontend CI later passes.

No schema migration, hosted mutation or data rollback exists. Revert the test
correction to restore the previous composite; preserve historical diagnostic logs.
No merge/deployment or next-task promotion is authorized. Stop for Product Owner
review with the browser gate explicitly outstanding.
