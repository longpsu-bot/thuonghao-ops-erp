# TASK-RMVP-06B — Connected Confirmed Need Validation

## Status

Implemented on branch `codex/rmvp-06b-connected-confirmed-need-validation` from accepted baseline `2ac4775af957070225916da3912c61df30ae4395`. The change remains draft and unmerged until exact-head GitHub validation and product/architecture review complete.

## Outcome

The accepted RMVP-06A contract is implemented as one complete-batch `NEED_GENERATION` validation boundary. Both governed outcomes persist immutable evidence. `BLOCKED` retains working lifecycle/version; `VALIDATED` advances exactly once and makes the review read-only while awaiting separately authorized approval.

The implementation uses all 19 accepted blocking codes and both accepted warnings. It keeps the four corrected cardinality codes distinct: `CURRENT_REVISION_AMBIGUOUS`, `CURRENT_DECISION_AMBIGUOUS`, `PLANNING_POLICY_MISSING`, and `PLANNING_POLICY_AMBIGUOUS`.

## Database delta

One forward migration adds:

- capability `confirmed_need_validation.validate` with no production binding;
- public `atlas_api.validate_confirmed_needs(jsonb)` owned by the reused Confirmed Need runtime;
- three private forced-RLS evidence relations for attempts, complete line observations, and issues;
- one nullable batch pointer to the exact successful attempt;
- immutable and deferred integrity guards, composite evidence foreign keys, minimum runtime grants/policies, canonical evaluation, event/audit shaping, and additive RMVP-05 read shaping.

It creates no role, scope kind, view, sequence, source trigger, approval relation, release relation, downstream operational fact, production seed, or hosted resource.

## Application delta

The existing connected Confirmed Need submodule registers the fourth RPC and exact `RMVP-06.v1` envelope. The workbench shows `Kiểm tra toàn bộ`, backend-derived eligibility/disabled reason, latest outcome/Actor/time/counts, blockers before warnings, and line markers. `Đã kiểm tra` switches all quantity editing/preview/confirmation controls to read-only and displays `Đã kiểm tra; chờ phê duyệt`. Late results are discarded after reload, batch change, Draft edit, or newer intent. Validation has no automatic retry.

Review-mode fixtures model both missing-decision `BLOCKED` and complete `VALIDATED` results. Focused tests cover request routing, exact envelope, blocked issue rendering, validation success, and read-only transition.

## Verification

- seedless local migration reset passes;
- focused pgTAP passes exact `plan(65)`;
- short authenticated browser-key validation/replay/readback passes from an empty database;
- focused Atlas RPC/API/workbench Vitest passes;
- CI installs bounded SQL prerequisites for pgTAP, resets afterward to prevent fixture leakage, and runs short plus full upstream browser journeys.

GitHub Actions remains the owner of the routine frozen install, formatting, typecheck, complete frontend tests, build, and diff-whitespace checks.

## Security and rollback

Only authenticated callers can execute the public function; Actor/capability/`GLOBAL` scope checks remain authoritative. Browser roles receive no private relation access. The reused runtime remains `NOLOGIN NOINHERIT`, fixed-search-path, forced-RLS constrained, and without downstream rights. React contains no service credential.

Rollback is forward-only: a corrective migration must first prove no batch points to successful validation evidence, then remove the additive API/read shape, pointer, guards, evidence relations, and unbound capability. Deleting or rewriting committed evidence is not an ordinary rollback path.

## Exclusions

Approval, approval snapshots, release, reopen, CMD-03, Purchase Handoff, Procurement, Warehouse, Dispatch, production capability binding, production Planning-policy data, hosted Supabase mutation, Retool, credentials, and deployment remain outside RMVP-06B.
