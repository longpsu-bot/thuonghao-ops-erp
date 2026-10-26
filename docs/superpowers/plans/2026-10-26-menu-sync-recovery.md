# Menu-sync recovery — 26 October 2026

Owner-authorized bounded implementation from main `30e7b249`. Endpoint: focused
checks and one Draft PR. No merge or deployment; Warehouse remains paused.
This explicit task supersedes the older documentation-only Autopilot horizon
only for the Menu-sync recovery scope below.

## Scope and acceptance

- Edge connector and Apps Script transport: distinguish temporary Auth/Atlas
  outages from actual authentication, capability and configured-source failures.
  Preserve correlated safe envelopes and never expose upstream bodies/secrets.
- Bound the connector's network stages to one 35-second budget, below the
  existing 45-second browser timeout. Propagate cancellation through the
  Google POST, allowed redirect GET and body reads; retain Google's existing
  30-second sublimit. No automatic retries or new business commands.
- Reuse shared Vietnamese error copy in the active Menu controller and retained
  reference workbench. State the next action and that failed fetch did not Save.
  Preserve existing candidates, context-generation guards and successful
  fetch → Preview → canonical Save/readback behavior.
- Add fault-injected handler/transport tests and controller/message regressions.
  Required cases: 429/5xx, genuine auth/denial/source absence, malformed replies,
  rejected/aborted reads, total deadline, no secret leakage, no downstream Save
  after failure, and explicit successful retry.
- Update the Planning API contract in the same change with the bounded
  operational error/deadline amendment.

Allowed source files: `supabase/functions/atlas-weekly-menu-google-sync/`,
`src/modules/atlas/planning-inputs/planningInputsModel.ts` and its tests,
the retained `PlanningInputsWorkbench.tsx` message caller, and
`src/vnext/atlas/planning/usePlanningSources.ts` and its tests.
No SQL, grants/RLS, payload signatures, source identities, recipe arithmetic,
business lifecycle, dependencies, Warehouse, other review findings or hosted
settings/data changes.

## Execution

1. Add focused failing tests for the reproduced classification/deadline and
   Vietnamese recovery failures; run them before production edits.
2. Repair the existing connector/transport and shared message caller paths.
   Keep request authentication and backend source authorization before Google.
3. Run affected tests excluding local historical snapshot/worktree copies,
   typecheck and formatting/whitespace checks. Review security and exact scope.
4. Commit/push the bounded branch and open a Draft PR. Let normal GitHub Actions
   own the full routine frontend suite. Record CI without claiming deployment.

Rollback is a source revert. No database migration or data rollback applies.

## Local verification

- Fault-injected regressions failed before the fixes, including outage status,
  missing cancellation, recovery copy, broken body streams and malformed source
  evidence. The completed focused run passed all **185 tests across six files**:
  handler, transport, active Menu controller, shared model, retained workbench
  and Atlas RPC client. Local historical snapshot/worktree copies were excluded.
- Strict standalone Edge TypeScript, application TypeScript, the vNext UI
  boundary check, Prettier and `git diff --check` passed.
- Independent read-only review identified the body-stream and malformed-source
  classification gaps; both received failing regressions and fixes. Follow-up
  review found no remaining blocker in those corrected paths.
- Authentication, backend capability/source checks and redirect credential
  isolation remain in place. Failures retain candidates and do not Save.
- This is implementation and local evidence only. Full routine validation runs
  in GitHub Actions after the Draft PR opens. No hosted acceptance, deployment,
  migration or Warehouse work was performed.

## PR #441 review and CI follow-up — 26 October 2026

The Owner subsequently authorized review, readiness and merge of PR #441 if
CI and review pass. This extends the original Draft-only endpoint; deployment
remains prohibited and Warehouse remains paused.

- Initial head `2a862f75`: Supabase Integration passed; Frontend CI
  [40264438920](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/40264438920)
  failed one retained `AtlasApp.test.tsx` assertion of the old Vietnamese copy
  (3,234 other tests passed, two skipped). The failure was reproduced locally.
  The affected six scenarios now assert the full next action and no-save notice.
  This test file is included in the bounded follow-up scope.
- Independent review found no standards/security blocker, but found that unknown
  prototype property names could bypass the shared Vietnamese fallback. Three
  new regressions failed before the own-property lookup guard was added.
- Both affected test files now pass all 40 tests; application TypeScript,
  changed-file formatting and diff whitespace checks pass. No tests were
  disabled, weakened or skipped to clear the CI failure.
- Fresh GitHub Actions on the follow-up head remain the readiness/merge gate.
  These local results do not establish deployment or hosted acceptance.
