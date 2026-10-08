# Workbench composition correction — 8 October 2026

Draft PR #358 continues the Owner's explicit thirteen-workbench revision. The earlier rounded/outlined tab treatment is rejected; its “Owner-approved” claim is withdrawn. The latest fixture screenshots replace that rejected PR evidence, not earlier accepted project evidence.

## Scope and acceptance

Reuse the existing Planning source component with fixed Menu, Attendance and Pantry owners. Production navigation exposes **Thực đơn**, **Sĩ số**, **Hàng đặt riêng**, and **Xác nhận nhu cầu** independently, with no source sub-tabs. Eight daily jobs plus five configuration jobs make **13** production owners. `Bổ sung` becomes `Hàng đặt riêng` as the operator destination; Pantry business meaning and explicit zero-source semantics remain unchanged.

D-048's registry/reducer/lifetime remains authoritative: mounted local state, owner guards and backend authority stay with each existing implementation. Switching performs no business write. Workspace navigation uses clear active text and one restrained underline, neutral inactive/hover treatment and visible focus. Full tab outlines, accent enclosures, rounded lower corners and added bottom spacing are removed. The previous shared task-tab styling changes are reverted so Procurement presentation remains at the main baseline.

Bounded sequence: meaningful composition/retention tests first; reuse the existing fixed-owner pattern; update current authority with dated supersession notes; run focused regressions and five-width fixture checks; independently review; update the same Draft PR and require its frontend CI. No merge.

## Verification

- Production fixture browser check passed at **1920×1080, 1440×900, 1366×768, 650×900 and 360×800**. Each opened all 13 owners, found no source sub-tabs, retained independent Attendance/Pantry drafts, cancelled guarded close safely, and produced no document overflow or browser errors. Desktop Home/End and the 26-control mobile open-owner selector passed. See [machine-readable results](browser-results.json).
- Reproduce with `python -X utf8 scripts/atlas_source_owners_browser_test.py` after starting local Vite on port 5188. This uses local fixture APIs only. Existing reusable browser harness owner lists/counts now reflect 13; their historical output folders were not regenerated.
- Meaningful tests were added before implementation for the 13-owner registry and fixed-source identity. Retention tests cover Menu search, Attendance/Pantry/Need drafts, DOM identity, unchanged activation reads, unique filter IDs, inactive/inert panels, close cancel/discard/reopen, sign-out and no business writes. A delayed source Review completion regression verifies inactive owners cannot steal focus.
- **198 focused tests passed across 11 files** (source/owner/application/shell/system/lifetime/handoff and cutover regression). Two existing 5-second checks timed out during concurrent local execution and passed unchanged when rerun alone. Required GitHub Actions status is recorded in the PR. UI boundary, changed-file formatting, whitespace checks and Impeccable detector passed. Independent source-ownership and fresh five-width visual finish reviews passed with no remaining actionable findings. Fixture checks do not claim hosted or staff acceptance.

| Width | Current fixture screenshot                                                    |
| ----- | ----------------------------------------------------------------------------- |
| 1920  | [Workspace](planning-1920x1080.png)                                           |
| 1440  | [Workspace](planning-1440x900.png) · [13-job launcher](launcher-1440x900.png) |
| 1366  | [Workspace](planning-1366x768.png)                                            |
| 650   | [Workspace](planning-650x900.png)                                             |
| 360   | [Workspace](planning-360x800.png)                                             |

![Quiet workspace navigation and separate source owners](planning-1440x900.png)

![Narrow workspace with the existing open-owner selector](planning-360x800.png)

## Security and rollback

Schema/migrations, RPC/API contracts, calculations, quantity semantics, Save/release, currentness/concurrency, permissions/RLS, Procurement, Retool and Live OPS are unchanged. Atlas Staging is untouched. No dependencies or global state store are added. Revert this frontend/docs revision to restore the previous composition; no data rollback is required.
