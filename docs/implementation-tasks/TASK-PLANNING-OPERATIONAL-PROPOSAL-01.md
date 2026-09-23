# TASK-PLANNING-OPERATIONAL-PROPOSAL-01 — Policy-derived Planning proposal

## Status

Implemented with scoped frontend and full local Supabase verification on
23/09/2026. GitHub exact-head frontend validation remains pending. Work is
bounded to branch `feat/planning-operational-proposal-01` from
`f6beaf88ad308378d00f336b625b1d369cf2a2b9`. Deployment, Staging mutation,
protected certification, and merge are not authorized by this task.

## Product outcome

Atlas keeps three quantities distinct:

1. `theoretical_quantity` is the exact grouped raw calculated requirement.
2. the current Draft revision `confirmed_quantity` is the deterministic system
   proposal `ceil(theoretical_quantity / planning_step) * planning_step`.
3. a Confirmed Need decision is explicit human authority and must already be an
   exact whole number of effective Planning-policy ticks.

System proposal derivation is not a human adjustment. Accepting the unchanged
proposal remains `UNCHANGED_PROPOSAL_ACCEPTED` / `PROPOSAL_ACCEPTED`; a real
operator change remains `ADJUSTED_QUANTITY_CONFIRMED` /
`OPERATIONAL_QUANTITY_ADJUSTMENT`. Invalid human input remains fail closed and
receives no replacement value.

## Architecture map and insertion point

```text
raw Planning source facts
→ theoretical_need_lines
→ immutable released generation snapshot
→ grouped seven-part Confirmed Need operational identity
→ exact revision theoretical_quantity
→ effective Unit Planning policy resolved for the service date
→ upward-quantized Draft revision confirmed_quantity
→ RMVP-05 proposed_confirmed_quantity readback
→ local confirmation draft
→ RMVP-05.v2 preview/Save
→ H1B1 append-only decision evidence
```

The authoritative proposal derivation is inserted after the grouped
contribution sum and before Draft revision persistence in
`atlas_core.planning_contract_01_materialize_confirmed_needs(jsonb)`. Policy is
resolved set-wise for the grouped identities. Contributions are never
individually quantized.

## Allowed change surface

- one forward migration that replaces the existing private materialization
  function while preserving its signature, owner, security-definer posture,
  empty search path, volatility, grants, timeouts, and transaction behavior;
- focused pgTAP suites for initial and correction materialization, policy
  failure atomicity, RMVP-05/H1B1 decisions, security, and operational scale;
- the active Chakra Confirmed Need model, draft, workbench, table, fixtures, and
  focused tests;
- the Planning browser harness and its local semantic-selector tests;
- the canonical decision register and directly affected PA-06D, PA-06E-H0,
  H1A, RMVP-05, and implementation documentation.

## Prohibited changes

- no new table, aggregate root, lifecycle, public API, policy fallback,
  conversion, major dependency, or generic rules engine;
- no mutation of historical Confirmed Need rows, decisions, source facts, or
  contribution membership;
- no Procurement-step reuse, Purchase Handoff semantic change, Warehouse,
  Dispatch, Retool, or OPS v1 change;
- no broad grants, direct browser relation access, RLS weakening, service-role
  browser credential, timeout increase, retry, or performance-threshold change;
- no Staging DML/deployment, protected browser/performance workflow, or change
  to PR #286.

## RED → GREEN implementation plan

### Task 1 — Backend RED

- Add exact materialization examples for `0.0255 → 0.03`, `0.105 → 0.11`,
  `1.225 → 1.23`, `3.8 → 4`, `204.75 → 205`, and `228 → 228` under their
  effective Unit policies.
- Prove `0.004 + 0.004` aggregates to raw `0.008` and proposal `0.01`, not
  `0.02`.
- Prove missing, ineffective, and safely constructible ambiguous policy
  resolution fail atomically with zero partial materialization.
- Prove correction creates a new current revision with exact raw membership and
  a policy-derived proposal while the old revision and source facts stay
  immutable and Procurement stays untouched.
- Extend RMVP-05/Save coverage for unchanged proposal acceptance, real
  adjustment, exact trailing-zero equivalence, invalid kg/count ticks, no
  replacement quantity, and first-decision semantics.
- Run the focused tests and retain the expected pre-implementation failures.

### Task 2 — Backend GREEN

- Create one repository-convention forward migration.
- In both initial and correction materialization statements, aggregate first,
  resolve exact Unit/effective-date policy set-wise, require exactly one
  eligible revision, then calculate with PostgreSQL `numeric` arithmetic.
- Preserve `theoretical_quantity`, membership quantities, correction lineage,
  D-040 carry behavior, D-042 correction behavior, security, grants, and safe
  error/no-partial-write behavior.
- Review relevant indexes and local execution shape; do not add per-line
  resolver calls.

### Task 3 — Frontend RED → GREEN

- Add exact decimal-string/BigInt tick validation using each line's
  `effective_policy.planning_step`; do not use JavaScript floating point or a
  fixed two-decimal business rule.
- Keep fresh lines editable even when raw values have high precision. Restrict
  historical protection to actual authoritative historical decisions that
  cannot safely round-trip.
- Render distinct `Nhu cầu tính`, `Đề xuất vận hành`, and `Số lượng xác nhận`
  columns, default the input from the system proposal, and expose compact step
  and Unit context.
- Preserve the first-Save rule that every fresh line receives its first explicit
  decision.

### Task 4 — Browser harness

- Replace stale column-position assumptions with semantic field selectors.
- Prove proposal-baseline editing, one adjustment/reason/note, Save enablement,
  resume without Generate, at most one Save click, and existing readback proof.
- Do not run the protected hosted browser workflow.

### Task 5 — Documentation and decision evidence

- Add accepted decision D-046 dated 23/09/2026 and link it from affected
  contracts.
- State explicitly that system derivation upward-quantizes raw aggregate while
  human input must already be exact ticks and remains fail closed.
- Record forward-fix rollback behavior and the owner-controlled post-merge
  correction/certification plan without executing it.

### Task 6 — Verification and review

- Run focused backend, policy/H1B1, RMVP-05/Save, frontend, browser-harness, and
  operational-scale tests while iterating.
- Near finalization run Node syntax checks, TypeScript, formatting, diff
  whitespace, the repository Supabase authority, and `pnpm certify:frontend`
  once.
- Perform the task's 25-point adversarial review, inspect security/grant and
  execution-shape deltas, commit, push, and open the requested draft pull
  request. GitHub Actions owns broad exact-head certification.

## Acceptance criteria

- Raw aggregate and contribution/source truth remain exact and unchanged.
- Proposal is exactly
  `ceil(sum(raw contributions) / planning_step) * planning_step` under exactly
  one effective Unit policy, with no fallback.
- Initial and correction materialization share the rule; old revisions remain
  immutable.
- Backend independently rejects nonrepresentable human input without a
  replacement value and retains exact tick evidence.
- Operators can distinguish raw, proposal, and confirmation values; local
  validation uses the actual policy step; fresh lines remain editable.
- First Save still produces one explicit first decision for every fresh line.
- No new schema aggregate/public surface/security exposure, no Procurement
  semantic change, and no Staging or protected-workflow mutation.

## Migration and rollback

The change is forward-only and rewrites no rows. Before deployment, rollback is
removing the undeployed migration and application changes. After deployment or
new materialization use, rollback requires a reviewed forward migration that
restores the prior function behavior while preserving every materialized
revision, decision, receipt, event, audit, and source fact. Existing
old-semantics Drafts are corrected only through the approved
correction/regeneration command after separate owner authorization.

## Protected certification boundary

The existing protected closeout classifier and its
`PRISTINE_GENERATED_RESUME` checkpoint remain unchanged because they describe
the immutable old-semantics Staging rehearsal state. This task changes only the
local semantic selector harness; it does not run or generalize the protected
workflow, mutate the checkpoint, or modify PR #286.

After merge, deployment, and the separately authorized Planning correction,
the owner must verify the exact new source/readback state and approve or pin the
correct immutable browser candidate. If the current PR #286 candidate is no
longer valid, replacing it or generalizing the protected classifier requires a
separate owner-authorized change.

## Implementation evidence

- one forward migration patches the private H0 materializer without adding a
  table, business aggregate, public API, runtime grant, policy fallback, or
  production seed;
- initial and correction paths aggregate raw contributions first, resolve
  Planning policy set-wise, and derive the Draft proposal with PostgreSQL
  `numeric` arithmetic;
- focused pgTAP proves kg and COUNT examples, missing/ineffective/ambiguous
  policy atomicity, immutable correction history, H1B1 decision evidence, and
  RMVP-05.v2 fail-closed Save behavior;
- the active Chakra workbench distinguishes raw, proposal, and confirmation,
  validates decimal strings against the effective step, and keeps fresh
  undecided lines editable;
- the browser harness locates quantity fields semantically and edits from the
  system proposal baseline;
- local operational-scale coverage passes; this is development evidence only
  and is not the independent protected performance certification.

The repository's 95-command local Supabase Full Integration authority passed
from a clean reset. The bounded frontend/harness suite passed 398 tests, Node
syntax checks, TypeScript, formatting, production build, and diff whitespace
checks. The single requested `pnpm certify:frontend` invocation passed install,
UI-boundary, type generation, formatting, and typecheck, then failed in the
full Vitest phase under local parallel load. A direct full-suite diagnostic
reproduced shifting unrelated five-second timeouts (22 failures across 12
files; 2,050 tests passed), while the specifically reported Recipe and Pantry
files passed 30/30 in isolation. No timeout, worker, or unrelated product code
was changed; GitHub Actions remains the exact-head broad frontend authority.
