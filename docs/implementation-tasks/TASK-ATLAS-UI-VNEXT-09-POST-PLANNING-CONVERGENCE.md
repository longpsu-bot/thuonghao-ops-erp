# TASK-ATLAS-UI-VNEXT-09 — Post-Planning Station convergence

## Result

UI-09 is implemented on `feat/atlas-ui-vnext-09-post-planning-convergence`. The product render is pinned to `d00d8ddd11428d9251ab6222294db6a3ec395919`; the comparison baseline is exact `origin/main` commit `42e473b5b856100869538f4e41ef5a325b99c893`. The historical presentation reference `ea154020bef6a068c1a9f70f5b6ba93d65ccc4a0` remained read-only.

The four target surfaces now share the approved Station hierarchy while retaining the current controllers, hooks, APIs, bridges, exact-quantity rules, permissions, lifecycles, dirty guards, operation status and navigation behavior. No database, migration, hosted data or production-cutover change exists.

## Director verdict and transfer ledger

| Source or concern                                                                       | Decision              | Applied result                                                        | Protected behavior                                                                    |
| --------------------------------------------------------------------------------------- | --------------------- | --------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| Pinned task context and table viewport                                                  | PORT/ADAPT            | Current-safe `AtlasTaskContext` and `AtlasTableViewport`              | Presentation only; no business state                                                  |
| Soft Mineral system                                                                     | KEEP + PORT one token | Existing system retained; `bg.context` added                          | Existing action/status/focus meanings                                                 |
| Pinned Procurement composition                                                          | ADAPT                 | Current controller output in Station composition                      | Allocation, Orders, exact quantity, permissions, dirty/recovery                       |
| Pinned Ingredient composition                                                           | ADAPT                 | Current 360-row catalogue and 320px detail in Station composition     | Current model/lifecycle/review; Supplier inner composition                            |
| Current Planning jobs                                                                   | KEEP/ADAPT            | Three jobs retained with source viewports and wide task review        | Payload/currentness, imports, zero/no-additions, recovery, commands                   |
| Current Confirmed Need                                                                  | KEEP/ADAPT            | Seven-function decision table, action hierarchy and certified fixture | Both rounding rules, stable line IDs, exact values, operation status, Save/navigation |
| Stale pinned consumers, prototype CSS/parser/data, non-target shell/Recipe/School hunks | OMIT                  | Not transferred                                                       | Current certified behavior and module boundaries                                      |
| Evidence-detected 36–40px mobile controls                                               | FIX under Task 6 TDD  | Shared responsive 44px minimum target; desktop density retained       | Presentation only; no authority or workflow change                                    |

## Implemented tasks and commits

| Task                                       | Commit                                     | Outcome                                                                                |
| ------------------------------------------ | ------------------------------------------ | -------------------------------------------------------------------------------------- |
| Shared Station foundation                  | `62c20c52162cabd9ff2c54e50e706e70d4b52dd0` | Shared context, viewport and semantic context surface                                  |
| Procurement Station                        | `5e3cf4d1a12e85cbf4062a8d3118351c47f2a445` | Eight-column Allocation surface, fixed detail and exact focus return; Orders preserved |
| Ingredient Station                         | `185248406e29e3ef1d60eac2cb8f6ecb70d36f98` | Truthful 360-row catalogue, selected detail and archived/read-only presentation        |
| Planning Sources Station                   | `888cd5fa20b13e479ccb41211b191049a2520919` | Menu/Attendance/Pantry viewports and task-specific wide review                         |
| Confirmed Need Station                     | `4ebdffeb5ec148275c9bd14fac8c49498c8c797b` | Seven functions, Save/Continue hierarchy and 248-current/249-historical fixture proof  |
| Evidence-detected mobile target correction | `d00d8ddd11428d9251ab6222294db6a3ec395919` | Responsive 44px target for shared controls, tabs, Refresh and date trigger             |

## Strict TDD evidence for the Task 6 correction

The initial 390×844 production renders measured shared actions and controls at 36–40px against the approved 44px target. Tests were changed first.

- First RED: `system.test.tsx` and `AtlasRefreshButton.test.tsx` produced 2 failed tests and 12 passing tests because no mobile minimum existed and Refresh remained 36px.
- First GREEN: the same two files passed 14/14 after the shared recipe, task-tab and Refresh correction.
- Second RED: `system.test.tsx` and `IngredientSupplierWorkbench.test.tsx` produced 2 failed tests and 26 passing tests for the remaining 36px date trigger and 40px Ingredient job tabs.
- Second GREEN: the same two files passed 28/28 after the minimal presentation correction.
- Final render audit: zero target violations across all ten 390×844 state captures. Desktop `control=40px` and `compact=36px` tokens remain unchanged; the responsive minimum is removed at `lg`.

## Focused regression and static validation

All commands excluded `.worktrees/**`.

| Command group                                                                 | Result                                                              |
| ----------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| Task 1 — context, viewport, system                                            | 3 files passed; 13 tests passed                                     |
| Task 2 — Procurement workbench/detail/exit/controller                         | 4 files passed; 62 tests passed                                     |
| Task 3 — Ingredient workbench/fixture/model/controller                        | 4 files passed; 56 tests passed                                     |
| Task 4 — Planning workbench/isolation/Pantry/controller/exit                  | 5 files passed; 76 tests passed                                     |
| Task 5 — Confirmed Need workbench/draft/controller/status/exit/exact quantity | 6 files passed; 108 tests passed                                    |
| Focused Task 1–5 total                                                        | 22 files passed; 315 tests passed; zero failed                      |
| `pnpm typecheck`                                                              | PASS; Chakra typegen and `tsc -b --pretty false` exited 0           |
| `pnpm ui:vnext:check`                                                         | PASS; `Atlas vNext UI boundary passed.`                             |
| Explicit Prettier check                                                       | PASS for all 34 supported changed files after this record was added |
| `git diff --check`                                                            | PASS                                                                |

The full routine frontend install/format/test/build suite remains owned by `Frontend CI / Format, typecheck, test, build` on the pull request, as required by `AGENTS.md`.

## Render evidence

Evidence root (outside Git):

`C:\Users\hp\.codex\visualizations\2026\09\27\01a0e35e-6f81-7113-9bd0-ed7c6a5400c2\atlas-ui-09-evidence`

Primary artifacts:

- `atlas-ui-09-manifest.json` — aggregate manifest; every capture includes full commit SHA, surface, state, viewport, fixture, story, pixel dimensions and audits.
- `current/current-manifest.json` and `current/current-summary.json` — 40 production renders at `d00d8ddd11428d9251ab6222294db6a3ec395919`.
- `baseline/baseline-manifest.json` and `baseline/baseline-summary.json` — four exact `origin/main` renders at `42e473b5b856100869538f4e41ef5a325b99c893`.
- `atlas-ui-09-contact-sheet.png` — compact 40-image current matrix.
- `atlas-ui-09-before-after-contact-sheet.png` — four 1440×900 exact-baseline comparisons.
- `console-network-notes.md` — console, exception, dialog, network and harness-limit notes.

Current state matrix (each state captured at 1440×900, 1280×800, 768×1024 and 390×844):

| Surface          | States                                                                                   | Production fixture/story basis                                                                                |
| ---------------- | ---------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| Procurement      | unselected; first allocation row selected                                                | `normal`; production row action opens attached detail                                                         |
| Ingredients      | unselected; first Ingredient selected                                                    | `INGREDIENTS_DENSE_360`; production row action opens attached detail                                          |
| Planning Sources | editing; review                                                                          | `menu_dirty`; `menu_review`                                                                                   |
| Confirmed Need   | clean 248; authoritative post-Save; released post-Save read-only; dirty valid adjustment | `certified_shape`; `normal` driven through production inputs/Save/readback; `released`; `normal` + dirty play |

The dedicated post-Save capture uses the production `CurrentConfirmedNeed` story and review fixture, drives the production quantity/reason/note controls and Save action, and waits for the authoritative `Đã lưu thay đổi.` readback. This replaced a static-build Storybook play failure; no state or screenshot was fabricated.

## Interaction and responsive review

- Browser/DPR: headless Chrome 153.0.8010.53 at DPR 1 for screenshots.
- Network: 656 current and 62 baseline requests; all were loopback Storybook documents/assets; zero non-loopback requests and no hosted reads/writes.
- Console: zero console entries in current and baseline runs.
- Storybook limitation: 16 current and one baseline `HTMLElement.focus` `Illegal invocation` exceptions occur while the static Storybook instrumentation and Chakra focus-visible tracking initialize Confirmed Need controls. The identical baseline signature, successful rendering and successful focus checks classify this as harness integration noise, not a clean-exception claim.
- Dirty guard: three expected `beforeunload` dialogs appeared between viewport passes and were accepted by the harness.
- Keyboard: ten subsequent focus stops were recorded for every capture (400 samples). This verifies representative order, not an exhaustive traversal of all 360 Ingredient row actions.
- Focus: eight Procurement/Ingredient selected-state checks entered the attached region and returned to the exact initiating trigger; zero failures. Four authoritative Save/readback interactions also passed.
- Overflow: zero document-wide horizontal-overflow captures; 39 local horizontally scrolling regions; every one had a semantic start or end continuation cue.
- Mobile targets: zero width-or-height violations below 44px after the Task 6 correction (visually hidden checkbox/radio inputs excluded because their labelled control owns the hit area).
- Reduced motion: 40/40 audits; only Chrome's `1e-05s` reduced-motion sentinel duration remained, with no substantive motion.
- 200%: four surface checks used a 720×450 CSS viewport at DPR 2; zero document overflow. This is an emulation, not a browser-UI zoom gesture.
- Large text: four surface checks doubled the root font size; zero document overflow.
- Long Vietnamese fixture values were present in 12 captures and visually retained without displacing the primary action.

## Exact tracked-file / Prettier classification

Compared with `42e473b5b856100869538f4e41ef5a325b99c893`, the following 37 tracked files changed. The 34 Markdown/TypeScript/TSX files were passed explicitly to `pnpm exec prettier --check`; the three TOML agent definitions are unsupported by this Prettier configuration and were reviewed as text.

### TOML — manual text review

- `.codex/agents/atlas-chakra-implementer.toml`
- `.codex/agents/atlas-ui-director.toml`
- `.codex/agents/atlas-ui-finish-reviewer.toml`

### Prettier-supported — explicit check list

- `docs/implementation-tasks/TASK-ATLAS-UI-VNEXT-09-POST-PLANNING-CONVERGENCE.md`
- `docs/superpowers/plans/2026-09-27-atlas-ui-vnext-09-post-planning-convergence.md`
- `docs/ui/atlas-vnext-09-post-planning-design.md`
- `src/vnext/atlas/AtlasProcurementExit.test.tsx`
- `src/vnext/atlas/AtlasRefreshButton.test.tsx`
- `src/vnext/atlas/AtlasRefreshButton.tsx`
- `src/vnext/atlas/AtlasTableViewport.test.tsx`
- `src/vnext/atlas/AtlasTableViewport.tsx`
- `src/vnext/atlas/AtlasTaskContext.test.tsx`
- `src/vnext/atlas/AtlasTaskContext.tsx`
- `src/vnext/atlas/AtlasTaskTabs.ts`
- `src/vnext/atlas/AtlasUnresolvedExit.test.tsx`
- `src/vnext/atlas/master-data/IngredientCatalogue.tsx`
- `src/vnext/atlas/master-data/IngredientDetail.tsx`
- `src/vnext/atlas/master-data/IngredientSupplierWorkbench.test.tsx`
- `src/vnext/atlas/master-data/IngredientSupplierWorkbench.tsx`
- `src/vnext/atlas/planning-confirmed/ConfirmedNeedTable.tsx`
- `src/vnext/atlas/planning-confirmed/ConfirmedNeedWorkbench.stories.tsx`
- `src/vnext/atlas/planning-confirmed/ConfirmedNeedWorkbench.test.tsx`
- `src/vnext/atlas/planning-confirmed/ConfirmedNeedWorkbench.tsx`
- `src/vnext/atlas/planning-confirmed/confirmedNeedReviewFixtures.ts`
- `src/vnext/atlas/planning/PlanningAttendanceStage.tsx`
- `src/vnext/atlas/planning/PlanningMenuStage.tsx`
- `src/vnext/atlas/planning/PlanningPantryStage.tsx`
- `src/vnext/atlas/planning/PlanningSourceReview.tsx`
- `src/vnext/atlas/planning/PlanningSourcesWorkbench.test.tsx`
- `src/vnext/atlas/planning/PlanningSourcesWorkbench.tsx`
- `src/vnext/atlas/procurement/ProcurementAllocationTable.tsx`
- `src/vnext/atlas/procurement/ProcurementSupplierDetail.test.tsx`
- `src/vnext/atlas/procurement/ProcurementSupplierDetail.tsx`
- `src/vnext/atlas/procurement/ProcurementWorkbench.test.tsx`
- `src/vnext/atlas/procurement/ProcurementWorkbench.tsx`
- `src/vnext/atlas/system.test.tsx`
- `src/vnext/atlas/system.ts`

## Protected-boundary and security review

`git diff --name-only 42e473b5b856100869538f4e41ef5a325b99c893...HEAD -- supabase .github/workflows index.html src/main.tsx scripts` returned no paths. Therefore:

- zero changes exist under `supabase/**`;
- zero Planning certification, closeout, performance or other script/workflow changes exist;
- `index.html` and `src/main.tsx` are unchanged;
- no RLS, privilege, migration, RPC, API, bridge, contract, controller, authority/draft helper, hosted-state or credential behavior changed;
- no new dependency, workflow stage, business concept or production data path was introduced.

The Task 6 mobile correction changes only responsive Chakra presentation recipes and local tab/icon dimensions. It does not grant authority, issue commands or expose data.

## Rollback

Rollback is frontend/document-only. Revert the UI-09 commits (including `d00d8ddd11428d9251ab6222294db6a3ec395919`) and the final acceptance-evidence commit. There is no database, migration, RLS, hosted-data or production-cutover rollback. External evidence can be removed independently because it is not application state.

## Remaining risks and gates

- The static Storybook/Chrome focus-instrumentation exception is documented above and in the external notes; a different browser/runtime may not reproduce it.
- Keyboard sampling does not exhaustively tab through every action in the 360-row Ingredient fixture.
- The 200% result is device-metrics emulation, not an OS/browser UI zoom or assistive-technology session.
- Real-device touch, screen-reader and browser-matrix validation remain unverified by the local headless harness.
- GitHub `Frontend CI / Format, typecheck, test, build` and the independent finish review remain required before merge. No local BLOCK or MAJOR product finding remains.
