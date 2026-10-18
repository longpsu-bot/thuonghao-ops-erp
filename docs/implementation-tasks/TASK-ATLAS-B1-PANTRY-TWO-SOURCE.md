# ATLAS B1 — Pantry two-source contract delta and execution record

**Current Product amendment:** the [18 October Product-model closeout](TASK-ATLAS-B1-PRODUCT-MODEL-CLOSEOUT.md)
supersedes earlier operator labels/COMPLETE instructions below. This ledger retains
the prior implementation and its source-qualified validation history.

Status: implementation authorized; validation pending. Starting SHA:
`4419033c2e4637fefb651d4ba395f4993a4e3599` (#401). Base branch:
`codex/atlas-400-ux-closeout`. B1 branch: `codex/atlas-b1-pantry-two-source`.
Authority: [Issue #400](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/400),
[Owner decision](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/392#issuecomment-6236559983),
and the explicit 18 October B1 execution brief. No merge or deployment.

## Business-contract delta

Two direct Ingredient requests may share batch, School, date, default Delivery
Location and Ingredient when their existing Purpose differs. `Bổ sung` means
`planning_identified_supplement`; `Đặt theo yêu cầu nhà trường` means
`school_requested_supplement`. Each retains its own stable UUID, exact quantity,
references, Actor/time evidence and immutable approval membership. A 5 kg and a
3 kg request remain two facts. Their matching purchasing requirement derives 8 kg
through existing contribution machinery, without another authored summary row.

Reuse **PANTRY-02.v3** at the existing Preview and consequential Save endpoints.
Its authored Purpose reference and School/date mode contracts already represent
the required facts. A new wire version would duplicate these capabilities.
The UI offers only the two approved active Purpose codes for creation, resolves
their reference IDs from authoritative readback, and inherits the selection once
per Add. PostgreSQL validates reference identity/status/note rules and derives
Location/Unit. The browser supplies no Purpose metadata or derived quantities.
The Owner's subsequent 18 October UI instruction keeps only `Nguồn của dòng mới`
in the creation toolbar. New School/date scopes use the existing ADDITIVE default;
persisted modes, including COMPLETE, remain unchanged and visible as read-only
facts. Category selection never reclassifies a saved mode. This explicitly
supersedes the earlier School → calculation selector → source selector → Add
creation layout, without changing D-044 backend behavior or historical evidence.
Unknown/inactive references and same-Purpose duplicate grain fail closed.
Existing rows keep their persisted Purpose, including the v4 neutral category;
changing the Add selector never reclassifies an existing row. Catalog note rules
remain authoritative (the existing Foundation package has OPTIONAL notes for
both categories); no automatic Purpose seeding, relabeling or policy backfill.

Extend the existing stable uniqueness grain by `pantry_need_purpose_id`; make
Purpose part of immutable line identity. Include Purpose in duplicate detection,
Save conflict target, Preview joins and canonical ordering. Removing one source
invalidates only that source; later reintroduction reuses its existing grain ID.
Purpose changes become omission plus a distinct source identity, preserving old
snapshots. Existing all-line replacement, locking, optimistic versions, signatures,
receipts, error envelopes and correction impact continue to govern Save. Exact
v3 receipt retries must resolve before mutable downstream correction checks,
after unchanged Actor/capability/scope authorization, as v4 already does.

`ADDITIVE` and `COMPLETE` remain independent School/date facts under D-044.
Existing Need snapshot membership and `pantry_need_line_id` contribution lineage
must prove 20 + 5 + 3 = 28 for ADDITIVE and 5 + 3 = 8 for COMPLETE, with exact
School/date/Location/Ingredient/Unit partitioning. No Need/Procurement algorithm,
public command limit, released commitment, permission or lifecycle is redesigned.
V1–v4 remain callable, historical signatures keep their values for the formerly
unique grain, and no historical row/snapshot is rewritten. One forward migration
replays after inherited v4. Operational rollback requires reviewed forward repair
or restoration; restoring the old unique constraint after overlaps exist would
be destructive and is prohibited. Disposable test rollback discards only B1 data.

## Bounded implementation plan

1. Add a failing pgTAP two-source identity/signature/Preview regression; run it on
   a fresh disposable inherited replay. Amend only the uniqueness constraint and
   existing Pantry canonical/current/signature/issue/line-guard/Save/Preview bodies,
   plus the existing v3 receipt replay boundary. Preserve ownership/ACL/search_path.
2. Extend real command tests for independent correction/deletion, snapshots,
   retries/conflicts/stale/auth/rollback and downstream Need/Confirmed Need lineage.
   Run focused Pantry, direct-need, Planning correction and purchasing regressions.
3. Add failing frontend serialization/controller/grouping tests, then connect v3
   Preview/impact/Save/readback in `pantryApi.ts`, `pantryModel.ts`,
   `usePlanningSources.ts` and `PlanningPantryStage.tsx`. Keep the isolated design
   fixture nonpersistent. Preserve search, exact quantities, focus and dirty/UNKNOWN.
4. Register the actual new SQL suite and catalog expectations; update Pantry API
   and architecture docs. Check formatting, UI boundary, TypeScript and build.
   Use real browser acceptance at 1366×768, 1440×900 and 390×844 with original
   screenshot dimensions. Distinguish local authenticated persistence from mocks.
5. Review the whole bounded diff, commit/push one stacked Draft targeting #401,
   and run exact-head Frontend CI, Supabase Smoke and Full Integration. Record
   actual results, failures and skipped gates. Stop for Product review.

Prohibited: edits to applied migrations, #392/#401, hosted data, B2/C, released
PO/Dispatch history, Warehouse/payment, dependencies, privileges or test weakening.
Security review covers existing GLOBAL scope and capability/subject checks, private
relations/helpers, hardened function ownership and schema leases, and atomic rollback.

## Evidence ledger

- Canonical `D:/Project/Repo/OPS/thuonghao-ops-erp`: clean, correct origin,
  fetched main `3667966a3f6703a6585f07ba619969ec851ca7b8`, exact #401 base and
  `pnpm ops:workspace` PASS. Existing worktrees and six stashes preserved.
- Disposable local project: `atlas-b1-pantry-20261018`, independent 5572x ports.
  Existing local stacks and all hosted databases are preserved.
- Forward migration replay PASS after the inherited sequence in the isolated
  project. Initial intended SQL regressions failed 3/3 before the amendment.
- The first authenticated-role, rolled-back B1 journey passed 25/25 assertions:
  separate source IDs `9c701378-c0bd-40df-8c6e-6c45b2ce4578` (5 kg) and
  `66bd5909-13b4-4777-9ac4-293fd7bf0187` (3 kg), exact COMPLETE 8 kg,
  two theoretical contributions and two Confirmed Need revision contributions,
  independent 5+4 correction, omission, immutable history and retry/conflict.
  This run predates the expanded purchasing/security assertions; it does not
  certify the final expanded suite or the separate ADDITIVE 28 kg test.
- Existing Pantry v1 (46), v4 (38), Pantry Need materialization (144) and direct
  composition (31) assertions passed locally. The longer Planning contract suite
  encountered a statement timeout and exit 137; later suites in that sequential
  invocation did not run. Preserve the failure; no timeout was changed.
- Focused authored serialization/API tests passed 2/2 and the new controller
  journey passed 1/1 after its intended failure. Later compatibility/test changes
  still require final verification. UI boundary and changed-file formatting pass.
- Local host free physical memory fell below 40 MB. The UI worker stalled before
  reporting a result; a prior frontend process failed startup with exit
  `-1073741502`. B1-only service stops were attempted; Docker could not confirm
  stopping the B1 DB. Existing stacks were never stopped/reset. CLI TCP database
  attempts failed; successful SQL evidence used direct local-container psql with
  authenticated role/JWT subject, not a hosted API or browser session.
- Independent read-only review found and corrected one SQL-test delimiter defect;
  no remaining Critical/Important source finding. The protected correction test
  now requires the exact `PLANNING_RELEASE_CORRECTION_REQUIRED` error. Review is
  source evidence, not a substitute for executing final tests.
- Final expanded SQL, exact-head CI/Smoke/Full Integration, browser, security
  catalog and final build evidence remain pending. Current verdict:
  **BLOCKED — VALIDATION**. No B1 completion, hosted persistence, Product acceptance,
  merge or deployment claim. Detailed final results belong to the stacked Draft
  and external evidence handoff, pinned to its actual final SHA.
- First remote checkpoint `88aa359`: Supabase Smoke PASS; Full Integration reached
  the expanded B1 suite and passed 38/39 assertions, including actual confirmation,
  supplier allocation, released Need contribution preservation and exact correction
  blocker. The unknown-School test changed the row's School without adding its
  required School/date mode, so v3 correctly rejected mode coverage before exposing
  the expected `UNKNOWN_SCHOOL` row blocker. The fixture now supplies both represented
  mode keys; the exact unknown-reference assertion is retained. No runtime, policy,
  timeout, capability or expected rejection is changed. Fresh final CI is required.
- The first Frontend CI checkpoint passed formatting/typecheck and 3,057 tests;
  two source-isolation assertions still expected v4 Purpose stripping in the
  vnext controller. They now require the actual authored Purpose and unchanged
  catalog note metadata for backend v3 validation. Explicit legacy v4 adapter
  compatibility coverage remains. This is a contract-expectation update; no
  runtime or validation guard is changed. The corrected focused invocation passed
  168 tests across 12 files; fresh exact-head CI remains required.
- After the Owner freed RAM, focused tests completed. Browser navigation still
  timed out in both the in-app browser and Chrome, including a browser focus
  command. No viewport, screenshot, rendered UX or connected persistence result
  was obtained. The B1-only Vite process was stopped; other applications and
  Docker projects were preserved.
- Validation continuation completed real browser v3 Save/readback against the
  isolated local stack with 50 active School/customer pairs and 403 Ingredients,
  plus exact 1366×768, 1440×900 and 390×844 app viewports. Separate authenticated
  browser sessions proved stale-Save locking/recovery; concurrent authenticated
  HTTP requests produced one commit and one STALE_VERSION, with exact retry and
  idempotency-conflict checks. The Owner then requested the single source selector
  and explicitly chose ADDITIVE for new School/date scopes. That bounded UI delta
  requires refreshed focused, rendered and final-head evidence in the PR/handoff.
- Local Vitest discovery included preserved worktrees under `.worktrees` in the
  earlier 168-test invocation. That count was not confined to canonical source.
  Continuation checks use `--dir src`; clean-checkout GitHub CI was unaffected.
- The final single-selector browser journey saved and refreshed two new sources
  on 20/10/2026: Planning 5 and School 3, automatically ADDITIVE. An independent
  authenticated public workbench read confirmed both, alongside the unchanged
  19/10 COMPLETE facts and original source IDs. Immutable first-approval evidence
  remained 5/3 after concurrent edits, mobile correction and the new date's Save.
- Final app browsing contexts measured exactly 1440×900, 1366×768 and 390×844,
  with no horizontal document overflow and one source selector / zero calculation
  selectors. A borderless test host framed the unchanged connected app at exact
  CSS dimensions because Windows rounded the outer browser by one pixel. Raw
  JPEG captures cover the entire app viewport; no transforms or image processing.
  Separate app and outer dimensions are retained in the external evidence.
- Final focused UI checkpoint: three changed cases passed; the existing multi-
  School journey reached its unchanged 5-second timeout, including when isolated.
  The host again fell to 40 MB free RAM. No timeout, journey or assertion was
  weakened. Formatting, UI boundary and diff whitespace passed. Clean-runner
  exact-head Frontend CI must adjudicate the timeout before a PASS verdict.
- Read-only review of the single-selector delta found no concrete issue. Only
  the B1 Vite/test-host processes and four B1 containers were stopped after browser
  proof; their volumes, other projects, worktrees and stashes remain preserved.
  Final exact-SHA CI results and the completion verdict are pinned in the Draft
  PR and external handoff, superseding earlier blocked checkpoints above.
