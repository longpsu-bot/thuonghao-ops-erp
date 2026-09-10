# ATLAS-UI-VNEXT-02A — Procurement design safety closeout

## Scope and authority

Continue `feat/atlas-ui-vnext-02-chakra-procurement` and Draft PR #275 from exact head `3a75572aadc7adaf527aef0049a87dc9aae754e2`, base `6413d787539a5651f59956540f1fdc449b4665c2`. The authorized checkout is `D:/Project/Repo/OPS/thuonghao-ops-erp`. Remote, clean worktree, exact head and open Draft PR were verified after the user approved switching from the initial unrelated local branch. One agent; no subagents.

This implements the user's bounded A–H closeout under OPS_SYSTEM_MAP v1.0, D-034/D-035/D-045 and the frozen Soft Mineral design language. Only vNext Procurement presentation, the optional AtlasDateInput disabled prop, focused tests, review fixtures and documentation change. No Product model, API, request builder, quantity scale or status lifecycle change.

## Delivered behavior

- An open supplier editor owns date, School and stage context. Date, School, the other job tab, search, exception filtering and routine refresh are disabled. The active tab remains selected. Clean Close is immediate; dirty Close uses the existing discard Dialog. Cancel retains the exact draft and its quiet `Đang chỉnh sửa · chưa lưu` footer text; discard/reopen restores saved authority. Save/readback removes dirty state. The exception Field must own `disabled`, because Chakra Field context otherwise overrides NativeSelect's local disabled state.
- AtlasDateInput forwards the public optional `disabled` prop to Chakra DateInput.Root. Verified against installed Chakra 3.37.0 declarations, inherited Zag 1.43.3 DateInputProps, and [official DateInput documentation](https://next.chakra-ui.com/docs/components/date-input). Existing vi-VN, leading zeros and dd/mm/yyyy presentation / ISO business dates stay intact.
- Inputs display `60`, `40`, `48,5`; accept comma or dot decimals and trim only outer whitespace. Mixed separators, thousands grouping, exponent notation, negatives, text and more than six fractional digits are rejected. Six-place scaled BigInt preserves exact sums and remainders. A deterministic serializer converts valid positive Save splits to canonical six-place dot strings before the unchanged request builder (`48,5` → `48.500000`). This matches the existing Procurement API contract's exact string examples and six-place quantity scale; no rounding or Number/parseFloat arithmetic is introduced.
- UNKNOWN feedback remains UNKNOWN after failed recovery. The workbench additionally displays `Không tải được dữ liệu hiện tại: <safe message>` and keeps `Tải lại để xác nhận` available. The controller already retained the read error and write lock correctly, so its production logic is unchanged. Successful later read clears the error and UNKNOWN feedback; backend permissions still decide actionability. No automatic write retry.
- Selected PO detail always owns dedicated stale/replacement/cancellation guidance. Matching `PO_DRAFT_STALE`, `PO_REPLACEMENT_REQUIRED`, `CANCELLATION_REQUIRED`, and (only for replacement guidance) `PO_ALREADY_RELEASED` are suppressed from generic detail reasons and that selected row's warnings. Unselected rows and scope-wide blockers stay visible. Unrelated reasons remain visible; existing operator-message string deduplication is retained. No global operator-copy modification.
- One tiny vNext-local Vietnamese fold helper serves allocation search and School search. Rendered School search proves `NGUYEN` matches Nguyễn; focused cases also cover Trần, Đặng, case and normal Vietnamese matching.

## Acceptance and fresh verification

Regression tests first reproduced comma parsing, raw input display, unprotected context, hidden recovery-read failure, accent-sensitive picker and duplicate PO guidance. The green pass also caught the enclosing Field overriding the exception select's disabled prop; this was fixed at the Field. Controller tests confirm the existing UNKNOWN/recovery safety behavior, source-qualified builders, exact retry, stale/currentness guards and backend permission gates.

| Check                                  | Fresh result                                        |
| -------------------------------------- | --------------------------------------------------- |
| vNext Procurement                      | 106 tests passed, 6 files                           |
| Unchanged legacy Procurement workbench | 55 passed                                           |
| Boundary tests                         | 28 passed                                           |
| AtlasDateInput regressions             | 2 passed                                            |
| Combined focused run                   | 191 passed, 9 files                                 |
| `pnpm ui:vnext:check`                  | Passed                                              |
| `pnpm ui:vnext:typegen`                | Passed                                              |
| `pnpm typecheck`                       | Passed                                              |
| `pnpm build`                           | Passed; existing large-chunk warning                |
| `pnpm build-storybook`                 | Passed; large-chunk/plugin warnings retained in log |

Focused command: `pnpm exec vitest run src/vnext/atlas/procurement src/vnext/atlas/AtlasDateInput.test.tsx scripts/check-atlas-vnext-ui-boundary.test.mjs src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.test.tsx --exclude '**/.worktrees/**' --maxWorkers=1 --pool=threads --reporter=verbose`. The exclusion confines discovery to this authorized checkout: an initial substring-filtered run accidentally discovered unchanged tests in nested historical worktrees. No test, configuration or legacy checkout was changed to address that discovery issue. Threads/one worker are local runner options only. GitHub Actions owns broad certification.

## Visual evidence

Evidence root: `C:/Users/hp/.codex/visualizations/2026/09/10/atlas-vnext-02a/`

Updated single contact sheet: `C:/Users/hp/.codex/visualizations/2026/09/10/atlas-vnext-02a/atlas-vnext-02a-contact-sheet.png`

Pure-vNext external Vite harness; headless local Microsoft Edge `152.0.4191.66`, DPR 1. Fifteen screenshots cover 1366×768, 1440×900, 1920×1080 and 360×800, including landing, clean and dirty detail, comma input/disabled context, dirty Dialog, UNKNOWN, failed recovery, stale/replacement/cancellation POs and mobile. `browser-evidence.json` records geometry and requests; `capture.mjs` records interaction assertions. Zero non-local requests, non-GET requests, browser exceptions, console warnings or console errors. No screenshot binaries are committed.

At 1366×768, master/detail remains about 677px/415px (62/38), with a single separator and local table scrolling. The table remains dominant, running balance is visible, dirty indication is quiet and visible above the footer, Save ends at y≈728, and context controls are subtly disabled. No page-wide horizontal overflow at any viewport, new card growth, border system, palette or design-system expansion. Mobile stacks controls and preserves local table scrolling. The review shell's existing navigation labels are unchanged fixtures, not new approved workflows.

## Review, boundaries and rollback

Inline product/architecture and security review performed against A–H because the task forbids subagents. No remaining implementation blocker or new Product decision was identified. Draft status and unmerged delivery are intentional; this is not production cutover approval.

Backend, Supabase, schema, migrations, RLS, RPC, Edge Functions, Auth contracts, Procurement/Purchase contracts, Retool, Google Sheets, live OPS and hosted Staging business data remain untouched. Zero hosted business writes. The staging migration authority remains `20260908225248 purchase_preparation_replacement_frontier`. Planning was not started. Production entrypoint, AtlasApp routing, navigation and legacy Procurement were not changed. The exact five-module business bridge, frozen Chakra v3/Soft Mineral tokens and strictTokens remain unchanged.

No migration or data rollback is needed. Reverting this closeout commit restores the previous isolated presentation while retaining the original vNext Procurement implementation. Frontend/Storybook chunk warnings remain outside this closeout's scope.

## Qodana annotation disposition

Inspected all 30 actual annotations from check run `102900877978` on starting PR head `3a75572aadc7adaf527aef0049a87dc9aae754e2`. Classification compares the PR diff with base `6413d787539a5651f59956540f1fdc449b4665c2`; every category-2 file has the identical Git blob at base and starting head. Repeated annotations are retained as individual entries. Category 1 has one unused import, removed. Category 2 has 29 unchanged legacy findings (including all 16 duplication notices), deliberately retained. Neutral Qodana conclusion does **not** mean zero findings.

| #   | Starting-head location                                                            | Inspection                                | Classification / disposition           |
| --- | --------------------------------------------------------------------------------- | ----------------------------------------- | -------------------------------------- |
| 1   | `src/modules/admin/RecipeAdjustmentWorkbench.test.tsx:455`                        | Duplicated code fragment                  | 2 — unchanged legacy; retained         |
| 2   | `src/modules/admin/RecipeAdjustmentWorkbench.test.tsx:1097`                       | Duplicated code fragment                  | 2 — unchanged legacy; retained         |
| 3   | `src/modules/atlas/planning-inputs/PlanningInputsWorkbench.tsx:697`               | Duplicated code fragment                  | 2 — unchanged legacy; retained         |
| 4   | `src/modules/atlas/review/reviewMasterDataApi.ts:551`                             | Duplicated code fragment                  | 2 — unchanged legacy; retained         |
| 5   | `scripts/verify-local-planning-contract-01.mjs:1`                                 | Duplicated code fragment                  | 2 — unchanged legacy; retained         |
| 6   | `src/modules/admin/dishRecipeAdminDomain.ts:906`                                  | Duplicated code fragment                  | 2 — unchanged legacy; retained         |
| 7   | `src/modules/admin/DishRecipeAdminWorkbench.test.tsx:1720`                        | Duplicated code fragment                  | 2 — unchanged legacy; retained         |
| 8   | `src/modules/admin/DishRecipeAdminWorkbench.test.tsx:213`                         | Duplicated code fragment                  | 2 — unchanged legacy; retained         |
| 9   | `src/modules/atlas/planning-inputs/PlanningInputsWorkbench.test.tsx:960`          | Duplicated code fragment                  | 2 — unchanged legacy; retained         |
| 10  | `src/modules/atlas/review/reviewMasterDataApi.ts:593`                             | Duplicated code fragment                  | 2 — unchanged legacy; retained         |
| 11  | `src/modules/admin/DishRecipeAdminWorkbench.test.tsx:1165`                        | Duplicated code fragment                  | 2 — unchanged legacy; retained         |
| 12  | `src/modules/atlas/dispatch/schoolDispatchReleaseExports.ts:176`                  | Duplicated code fragment                  | 2 — unchanged legacy; retained         |
| 13  | `src/modules/admin/RecipeAdjustmentWorkbench.test.tsx:474`                        | Duplicated code fragment                  | 2 — unchanged legacy; retained         |
| 14  | `src/modules/admin/RecipeAdjustmentWorkbench.test.tsx:1025`                       | Duplicated code fragment                  | 2 — unchanged legacy; retained         |
| 15  | `src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.test.tsx:967`   | Duplicated code fragment                  | 2 — unchanged legacy; retained         |
| 16  | `src/modules/atlas/planning-inputs/confirmed-needs/reviewConfirmedNeedApi.ts:394` | Duplicated code fragment                  | 2 — unchanged legacy; retained         |
| 17  | `src/modules/admin/DishRecipeAdminWorkbench.tsx:25`                               | Unused import                             | 2 — unchanged legacy; retained         |
| 18  | `src/modules/admin/DishRecipeAdminWorkbench.test.tsx:17`                          | Unused import                             | 2 — unchanged legacy; retained         |
| 19  | `src/vnext/atlas/procurement/ProcurementWorkbench.test.tsx:16`                    | Unused import                             | 1 — removed unused reviewFamily import |
| 20  | `src/modules/admin/DishRecipeAdminWorkbench.tsx:266`                              | Unused local symbol                       | 2 — unchanged legacy; retained         |
| 21  | `src/modules/admin/DishRecipeAdminWorkbench.tsx:1135`                             | Pointless statement or boolean expression | 2 — unchanged legacy; retained         |
| 22  | `src/modules/atlas/recipes/recipeModel.ts:828`                                    | Pointless statement or boolean expression | 2 — unchanged legacy; retained         |
| 23  | `src/modules/atlas/procurement/SchoolCateringProcurementWorkbench.tsx:306`        | Pointless statement or boolean expression | 2 — unchanged legacy; retained         |
| 24  | `src/modules/admin/DishRecipeAdminWorkbench.tsx:562`                              | Pointless statement or boolean expression | 2 — unchanged legacy; retained         |
| 25  | `src/modules/atlas/recipes/recipeModel.ts:749`                                    | Pointless statement or boolean expression | 2 — unchanged legacy; retained         |
| 26  | `scripts/atlas-staging-contract.test.mjs:1995`                                    | Redundant character escape                | 2 — unchanged legacy; retained         |
| 27  | `scripts/atlas-staging-contract.test.mjs:1995`                                    | Redundant character escape                | 2 — unchanged legacy; retained         |
| 28  | `scripts/atlas-staging-contract.test.mjs:1343`                                    | Consecutive spaces                        | 2 — unchanged legacy; retained         |
| 29  | `scripts/atlas-staging-contract.test.mjs:1343`                                    | Consecutive spaces                        | 2 — unchanged legacy; retained         |
| 30  | `scripts/atlas-staging-contract.test.mjs:1343`                                    | Consecutive spaces                        | 2 — unchanged legacy; retained         |
