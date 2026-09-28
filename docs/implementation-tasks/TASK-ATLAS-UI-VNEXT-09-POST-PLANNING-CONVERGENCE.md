# TASK-ATLAS-UI-VNEXT-09 — Post-Planning Station convergence

## Result

UI-09 is implemented on `feat/atlas-ui-vnext-09-post-planning-convergence`. The independent `atlas-ui-finish-reviewer` returned final verdict **PASS** at exact branch code/evidence HEAD `2c7b4438c78ff479be10d26bdae98b417c718402`, with every prior finding closed and no remaining BLOCK or MAJOR finding. The final product code and disabled-onward compact-keyboard evidence are pinned to `bdc8235a7754224020c967df2db141089f530437`; the full visual matrix remains pinned to `dfd077f04d8ea9f734ff39b00eb530026247a6ad`, and the enabled-onward keyboard supplement remains pinned to `c4448d1e66e5923d599a2a28eeb0770e5db2f6cb`. The comparison baseline is exact `origin/main` commit `42e473b5b856100869538f4e41ef5a325b99c893`. The historical presentation reference `ea154020bef6a068c1a9f70f5b6ba93d65ccc4a0` remained read-only.

The four target surfaces now share the approved Station hierarchy while retaining the current controllers, hooks, APIs, bridges, exact-quantity rules, permissions, lifecycles, dirty guards, operation status and navigation behavior. No database, migration, hosted data or production-cutover change exists.

## Director verdict and transfer ledger

| Source or concern                                                                       | Decision              | Applied result                                                                                          | Protected behavior                                                                    |
| --------------------------------------------------------------------------------------- | --------------------- | ------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| Pinned task context and table viewport                                                  | PORT/ADAPT            | Current-safe `AtlasTaskContext` and `AtlasTableViewport`                                                | Presentation only; no business state                                                  |
| Soft Mineral system                                                                     | KEEP + PORT one token | Existing system retained; `bg.context` added                                                            | Existing action/status/focus meanings                                                 |
| Pinned Procurement composition                                                          | ADAPT                 | Current controller output in Station composition                                                        | Allocation, Orders, exact quantity, permissions, dirty/recovery                       |
| Pinned Ingredient composition                                                           | ADAPT                 | Current 360-row catalogue and 320px detail in Station composition                                       | Current model/lifecycle/review; Supplier inner composition                            |
| Current Planning jobs                                                                   | KEEP/ADAPT            | Three jobs retained with source viewports and wide task review                                          | Payload/currentness, imports, zero/no-additions, recovery, commands                   |
| Current Confirmed Need                                                                  | KEEP/ADAPT            | Seven-function decision table, action hierarchy and certified fixture                                   | Both rounding rules, stable line IDs, exact values, operation status, Save/navigation |
| Stale pinned consumers, prototype CSS/parser/data, non-target shell/Recipe/School hunks | OMIT                  | Not transferred                                                                                         | Current certified behavior and module boundaries                                      |
| Evidence-detected 36–40px mobile controls                                               | FIX under Task 6 TDD  | Shared responsive 44px minimum target; desktop density retained                                         | Presentation only; no authority or workflow change                                    |
| Finish-review identity/action/evidence findings                                         | FIX under review loop | Sticky identity, compact filters/actions, coherent Save fixture/evidence and visible Procurement footer | Current commands, controllers, APIs and exact-quantity rules unchanged                |
| Disabled-onward compact keyboard trap                                                   | FIX under review loop | Resolve an enabled onward target before cancelling Tab; loading status is a stable focus fallback       | Enabled Refresh order and all controller/command eligibility remain unchanged         |

## Implemented tasks and commits

| Task                                       | Commit                                     | Outcome                                                                                                                 |
| ------------------------------------------ | ------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------- |
| Shared Station foundation                  | `62c20c52162cabd9ff2c54e50e706e70d4b52dd0` | Shared context, viewport and semantic context surface                                                                   |
| Procurement Station                        | `5e3cf4d1a12e85cbf4062a8d3118351c47f2a445` | Eight-column Allocation surface, fixed detail and exact focus return; Orders preserved                                  |
| Ingredient Station                         | `185248406e29e3ef1d60eac2cb8f6ecb70d36f98` | Truthful 360-row catalogue, selected detail and archived/read-only presentation                                         |
| Planning Sources Station                   | `888cd5fa20b13e479ccb41211b191049a2520919` | Menu/Attendance/Pantry viewports and task-specific wide review                                                          |
| Confirmed Need Station                     | `4ebdffeb5ec148275c9bd14fac8c49498c8c797b` | Seven functions, Save/Continue hierarchy and 248-current/249-historical fixture proof                                   |
| Evidence-detected mobile target correction | `d00d8ddd11428d9251ab6222294db6a3ec395919` | Responsive 44px target for shared controls, tabs, Refresh and date trigger                                              |
| Finish-review correction bundle            | `836bdb21f626fb0673280fa67a852833f3484680` | Sticky identity, mobile disclosure, coherent Save fixture, Procurement detail envelope and design whitespace correction |
| Deterministic review interaction           | `1d70f4f743217fd43f23d3b7dff9688897d0d51b` | Production-control Storybook changes replace flaky typed instrumentation                                                |
| Browser-verified identity inset            | `394a75d8653d6966f008fb8662b29852102a04a1` | Opaque first header/cell remain horizontally sticky in Chrome                                                           |
| Reachable dirty mobile Save                | `dfd077f04d8ea9f734ff39b00eb530026247a6ad` | Dirty mobile table allocation keeps primary Save inside the viewport                                                    |
| Compact filter keyboard order              | `c4448d1e66e5923d599a2a28eeb0770e5db2f6cb` | Keyboard expansion enters revealed controls, traverses them, then continues to Refresh                                  |
| Disabled-onward keyboard exit              | `bdc8235a7754224020c967df2db141089f530437` | Disabled Refresh no longer traps the last revealed filter; forward and reverse paths remain logical                     |

## Finish-review correction evidence

Review 1 reported five MAJOR and two MINOR presentation/evidence findings, with no backend or security defect. Each production/fixture issue was reproduced before correction.

- RED: Confirmed Need lacked sticky first-header/identity styles, no compact `Bộ lọc` disclosure, saved readback retained `adjusted: 0`/`PROPOSAL_ACCEPTED`, and Procurement retained the taller `calc(100dvh - 270px)` detail envelope. The two affected files produced three Confirmed Need failures and one Procurement failure before implementation.
- GREEN: sticky opaque identity surfaces, truthful compact filter summary, coherent `OPERATIONAL_ADJUSTMENT` readback/history/reason and the constrained Procurement envelope passed 46/46 affected tests.
- Storybook RED: the hardened capture assertion stopped on the original dirty story at value `10,25`, adjustment state `invalid`, delta `0`, disabled Save. Deterministic production-control change events then passed all four viewport assertions at `12,5`, delta `+2,25`, enabled primary Save and no error.
- Browser RED/GREEN: the capture check exposed an ambiguous header selector and then confirmed the scoped Confirmed Need header and cells resolve to `position: sticky`, `left: 0px` and opaque surfaces. The dirty 390×844 Save initially ended four pixels below the viewport; a test-first dirty-only mobile height correction moved the full 44px primary action on-screen.
- Evidence hygiene: ordinary renders reset document and every local scroll origin; only nine labelled detail/review captures apply deliberate scrolling. Exact `git diff --check 42e473b5b856100869538f4e41ef5a325b99c893...HEAD` now passes after replacing the five Markdown hard-break spaces.

### Finish-review loop 2 — compact keyboard order

The second review found one MAJOR keyboard-order defect and confirmed that the original five MAJOR and two MINOR findings remained closed. On compact layouts, the revealed filter fields were visually below `Bộ lọc` but earlier in DOM order, so forward Tab from the expanded disclosure skipped them.

- RED: five keyboard-driven cases failed — Procurement 390px, Ingredients 390px, Planning Sources 390px, and Confirmed Need at 390px and 768px. After search → Tab → keyboard activation, focus stayed on `Bộ lọc`; the next Tab reached Refresh without entering the filter group.
- GREEN: the shared presentation helper moves focus to the first revealed control, keeps forward/reverse traversal inside the disclosed group, returns reverse traversal to `Bộ lọc`, and hands the last forward stop to Refresh. The same five cases passed 5/5.
- Affected regression: the four workbench files passed 100/100 tests when run individually (32 Confirmed Need, 21 Procurement, 26 Planning Sources, 21 Ingredients). A combined resource-heavy run hit two existing five-second timeouts; isolated reruns passed both timed-out tests.
- Static validation: `pnpm typecheck`, `pnpm ui:vnext:check`, explicit Prettier, `git diff --check`, and the protected-path check passed.
- Browser proof: five production Storybook captures at exact code SHA `c4448d1e66e5923d599a2a28eeb0770e5db2f6cb` passed search-to-disclosure, first-filter focus, complete forward traversal to Refresh, and reverse return to `Bộ lọc` assertions. No unrelated state or viewport was recaptured.

### Finish-review loop 3 — disabled-onward keyboard exit

The third review found one MAJOR follow-on defect: forward Tab from the last revealed filter was always cancelled, even when native Refresh was disabled and therefore supplied no enabled target. Focus remained on the last filter.

- RED: Procurement loading, Ingredients `canRefresh=false`, Planning review, and Confirmed Need loading at 390px and 768px retained focus inside the final revealed filter. The initial focused run failed 5/5 new assertions.
- GREEN: `compactFilterFocus.ts` now resolves an enabled direct or following target before calling `preventDefault()`. If no target exists, native Tab is not cancelled. Confirmed Need initial loading exposes its existing status as a programmatic fallback (`tabIndex=-1`) after the workbar; no business control or command was added.
- State matrix: automated user-Tab coverage passes Procurement busy/locked/selected at 390px; Planning busy/locked/review at 390px; Confirmed Need busy/loading/locked at 390px and 768px; and Ingredients `canRefresh=false` at 390px. Enabled-Refresh behavior from loop 2 remains covered.
- Focused regression: the four affected suites pass 114/114 in isolated runs with a 15-second per-test ceiling (25 Procurement, 29 Planning Sources, 38 Confirmed Need, 22 Ingredients). The ceiling avoids the known resource-only five-second timeout seen when the dense 360-row fixture runs concurrently.
- Static validation: `pnpm typecheck`, `pnpm ui:vnext:check`, explicit Prettier, exact `git diff --check 42e473b5b856100869538f4e41ef5a325b99c893`, and the protected-path check passed.
- Browser proof: nine scoped production Storybook captures at `bdc8235a7754224020c967df2db141089f530437` cover stable selected/locked/review/loading/`canRefresh=false` disabled states at the required compact widths. Every run proved Refresh disabled, forward focus outside the revealed filter group, and Shift+Tab return to `Bộ lọc`. Busy transitions are deterministic in automated component tests but have no frozen production Storybook story, so no busy screenshot was fabricated.

## Strict TDD evidence for the Task 6 correction

The initial 390×844 production renders measured shared actions and controls at 36–40px against the approved 44px target. Tests were changed first.

- First RED: `system.test.tsx` and `AtlasRefreshButton.test.tsx` produced 2 failed tests and 12 passing tests because no mobile minimum existed and Refresh remained 36px.
- First GREEN: the same two files passed 14/14 after the shared recipe, task-tab and Refresh correction.
- Second RED: `system.test.tsx` and `IngredientSupplierWorkbench.test.tsx` produced 2 failed tests and 26 passing tests for the remaining 36px date trigger and 40px Ingredient job tabs.
- Second GREEN: the same two files passed 28/28 after the minimal presentation correction.
- Final render audit: zero target violations across all ten 390×844 state captures. Desktop `control=40px` and `compact=36px` tokens remain unchanged; the responsive minimum is removed at `lg`.

## Focused regression and static validation

All commands excluded `.worktrees/**`.

The parent controller repeated the exact-HEAD focused validation at `2c7b4438c78ff479be10d26bdae98b417c718402` after the final independent review. The results below supersede the earlier 316-test pre-closeout run.

| Command group                                                                 | Result                                                    |
| ----------------------------------------------------------------------------- | --------------------------------------------------------- |
| Task 1 — context, viewport, system                                            | 3 files passed; 13 tests passed                           |
| Task 2 — Procurement workbench/detail/exit/controller                         | 4 files passed; 67 tests passed                           |
| Task 3 — Ingredient workbench/fixture/model/controller                        | 4 files passed; 58 tests passed                           |
| Task 4 — Planning workbench/isolation/Pantry/controller/exit                  | 5 files passed; 80 tests passed                           |
| Task 5 — Confirmed Need workbench/draft/controller/status/exit/exact quantity | 6 files passed; 117 tests passed                          |
| Focused Task 1–5 total                                                        | 22 files passed; 335 tests passed; zero failed            |
| `pnpm typecheck`                                                              | PASS; Chakra typegen and `tsc -b --pretty false` exited 0 |
| `pnpm ui:vnext:check`                                                         | PASS; `Atlas vNext UI boundary passed.`                   |
| Targeted Prettier check                                                       | PASS on the exact changed-file set                        |
| Exact baseline diff and protected-boundary checks                             | PASS; zero whitespace errors and zero protected paths     |

The full routine frontend install/format/test/build suite remains owned by `Frontend CI / Format, typecheck, test, build` on the pull request, as required by `AGENTS.md`.

## Render evidence

Evidence root (outside Git):

`C:\Users\hp\.codex\visualizations\2026\09\27\01a0e35e-6f81-7113-9bd0-ed7c6a5400c2\atlas-ui-09-evidence`

Primary artifacts:

- `atlas-ui-09-manifest.json` — aggregate manifest; every capture includes full commit SHA, surface, state, viewport, fixture, story, pixel dimensions and audits.
- `current/current-manifest.json` and `current/current-summary.json` — 40 production renders at `dfd077f04d8ea9f734ff39b00eb530026247a6ad`.
- `baseline/baseline-manifest.json` and `baseline/baseline-summary.json` — four exact `origin/main` renders at `42e473b5b856100869538f4e41ef5a325b99c893`.
- `atlas-ui-09-contact-sheet.png` — compact 40-image current matrix.
- `atlas-ui-09-before-after-contact-sheet.png` — four 1440×900 exact-baseline comparisons.
- `console-network-notes.md` — console, exception, dialog, network and harness-limit notes.
- `keyboard-review-2-c4448d1/keyboard-manifest.json` and `keyboard-summary.json` — five scoped expanded-filter keyboard proofs at `c4448d1e66e5923d599a2a28eeb0770e5db2f6cb`.
- `keyboard-review-2-c4448d1/keyboard__*.png` — Procurement, Ingredients and Planning Sources at 390×844 plus Confirmed Need at 390×844 and 768×1024, each captured with focus on the first revealed control.
- `keyboard-review-3-bdc8235/keyboard-manifest.json` and `keyboard-summary.json` — nine scoped disabled-onward proofs at `bdc8235a7754224020c967df2db141089f530437`.
- `keyboard-review-3-bdc8235/keyboard-disabled__*.png` — Procurement selected/locked, Planning review/locked, Ingredients `canRefresh=false` at 390×844, plus Confirmed Need loading/locked at both 390×844 and 768×1024.

Current state matrix (each state captured at 1440×900, 1280×800, 768×1024 and 390×844):

| Surface          | States                                                                                   | Production fixture/story basis                                                                                |
| ---------------- | ---------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| Procurement      | unselected; first allocation row selected                                                | `normal`; production row action opens attached detail                                                         |
| Ingredients      | unselected; first Ingredient selected                                                    | `INGREDIENTS_DENSE_360`; production row action opens attached detail                                          |
| Planning Sources | editing; review                                                                          | `menu_dirty`; `menu_review`                                                                                   |
| Confirmed Need   | clean 248; authoritative post-Save; released post-Save read-only; dirty valid adjustment | `certified_shape`; `normal` driven through production inputs/Save/readback; `released`; `normal` + dirty play |

The dedicated post-Save capture uses the production `CurrentConfirmedNeed` story and review fixture, drives the production quantity/reason/note controls and Save action, and waits for the authoritative `Đã lưu thay đổi.` readback. This replaced a static-build Storybook play failure; no state or screenshot was fabricated.

The dirty-adjustment captures use the production `DirtyValid` story. Before each screenshot the harness asserts `data-adjustment-state="valid"`, exact visible delta `+2,25`, enabled primary Save, `aria-invalid="false"` and no row error. The post-Save captures assert exact `12,5`, `1 đã điều chỉnh`, reason/note readback and absence of a remaining Save action. All checks are recorded in `reviewChecks`.

## Interaction and responsive review

- Browser/DPR: headless Chrome 153.0.8010.53 at DPR 1 for screenshots.
- Network: 656 current and 62 baseline requests; all were loopback Storybook documents/assets; zero non-loopback requests and no hosted reads/writes.
- Console: zero console entries in current and baseline runs.
- Storybook limitation: 16 current and one baseline `HTMLElement.focus` `Illegal invocation` exceptions occur while the static Storybook instrumentation and Chakra focus-visible tracking initialize Confirmed Need controls. The identical baseline signature, successful rendering and successful focus checks classify this as harness integration noise, not a clean-exception claim.
- Dirty guard: three expected `beforeunload` dialogs appeared between viewport passes and were accepted by the harness.
- Keyboard: ten subsequent focus stops were recorded for every capture (400 samples). This verifies representative order, not an exhaustive traversal of all 360 Ingredient row actions.
- Compact keyboard supplement: all five scoped runs used real Chrome Tab and Space key dispatch. Each run proved search → `Bộ lọc`, keyboard expansion → first revealed control, disclosed-control traversal → Refresh, and Shift+Tab from the first control → `Bộ lọc`. The supplement made 82 loopback requests, zero non-loopback requests and zero console entries. Its two Confirmed Need `Illegal invocation` exceptions have the previously documented baseline-identical Storybook focus-instrumentation signature; all keyboard assertions still passed.
- Disabled-onward keyboard supplement: all nine scoped runs used real Chrome Tab and Space dispatch and reset document/local scroll origins. All assertions passed; 149 requests were loopback-only, zero non-loopback requests and zero console entries occurred. Two Confirmed Need locked-state `Illegal invocation` exceptions match the already documented baseline-identical Storybook focus-instrumentation signature.
- Focus: eight Procurement/Ingredient selected-state checks entered the attached region and returned to the exact initiating trigger; zero failures. Four authoritative Save/readback interactions also passed.
- Overflow: zero document-wide horizontal-overflow captures; 39 local horizontally scrolling regions; every one had a semantic start or end continuation cue.
- Scroll determinism: all 40 captures reset document and local scroll to origin. Four compact attached-detail, two compact Planning-review and three dirty-adjustment-review renders then applied deliberate labelled scroll only; each reason/selector is stored with its manifest entry.
- Mobile targets: zero width-or-height violations below 44px after the Task 6 correction (visually hidden checkbox/radio inputs excluded because their labelled control owns the hit area).
- Reduced motion: 40/40 audits; only Chrome's `1e-05s` reduced-motion sentinel duration remained, with no substantive motion.
- 200%: four surface checks used a 720×450 CSS viewport at DPR 2; zero document overflow. This is an emulation, not a browser-UI zoom gesture.
- Large text: four surface checks doubled the root font size; zero document overflow.
- Long Vietnamese fixture values were present in 12 captures and visually retained without displacing the primary action.

## Exact tracked-file / Prettier classification

Compared with `42e473b5b856100869538f4e41ef5a325b99c893`, 39 tracked files changed. The 36 Markdown/TypeScript/TSX files were passed explicitly to `pnpm exec prettier --check`; the three TOML agent definitions are unsupported by this Prettier configuration and were reviewed as text.

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
- `src/vnext/atlas/compactFilterFocus.ts`
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

The Task 6 and finish-review corrections change only responsive Chakra presentation, focus sequencing, review fixtures/tests/stories and evidence documentation. They do not grant authority, issue commands or expose data.

## Rollback

Rollback is frontend/document-only. Revert the UI-09 commits through `bdc8235a7754224020c967df2db141089f530437` and the acceptance-evidence commits. There is no database, migration, RLS, hosted-data or production-cutover rollback. External evidence can be removed independently because it is not application state.

## Remaining risks and gates

- The static Storybook/Chrome focus-instrumentation exception is documented above and in the external notes; a different browser/runtime may not reproduce it.
- Keyboard sampling does not exhaustively tab through every action in the 360-row Ingredient fixture.
- The 200% result is device-metrics emulation, not an OS/browser UI zoom or assistive-technology session.
- Real-device touch, screen-reader and browser-matrix validation remain unverified by the local headless harness.
- Independent finish review is complete with final verdict **PASS** and every prior finding closed. GitHub `Frontend CI / Format, typecheck, test, build` remains pending until the pull request is opened and is still required before merge.
