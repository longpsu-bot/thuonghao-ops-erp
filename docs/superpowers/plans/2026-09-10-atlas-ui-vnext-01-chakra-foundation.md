# Atlas UI vNext foundation implementation plan

**Goal:** Build a fixture-only Chakra presentation beside the certified Atlas application.

**Authority:** Product-approved ATLAS-UI-VNEXT-01-CHAKRA-FOUNDATION-SHELL; OPS_SYSTEM_MAP v1.0; D-034/D-035. One agent, inline execution, no subagents.

**Baseline:** `40adf86db6dbe835c367478a4c933a3fbbd6cc34`, the verified PR #273 squash result. Canonical checkout explicitly confirmed by Product: `E:/Project/OPS ERP/thuonghao-ops-erp`. Work directly there on `feat/atlas-ui-vnext-01-chakra-foundation`; the unused setup worktree is detached and contains no task edits.

**Architecture:** Business capability → operator job → command/read model → vNext workbench → Atlas design language → Chakra primitive. Fixture data only. No business/API/model, production entrypoint, legacy styling, Supabase, Retool, navigation or hosted changes.

**Dependencies:** Exact `@chakra-ui/react@3.37.0`, `@emotion/react@11.14.0`, development `@chakra-ui/cli@3.37.0`. Stop on dependency policy rejection. Keep Mantine and Phosphor.

## Task 1 — Architecture decision and design-language specification

- [x] Check D-045 is unallocated; retain D-034/D-035 unchanged.
- [x] Create `docs/decisions/decision-atlas-chakra-ui-foundation.md` and `docs/ui/atlas-vnext-design-language-v1.md`; supersede only D-033 status and update decision register.
- [x] Verify links, status, explicit business exclusions and touched-file formatting; commit documentation.

## Task 2 — Dependencies and system/provider

- [x] Add provider tests in `src/vnext/atlas/AtlasVNextShell.test.tsx`: token context resolves workspace, provider renders Chakra child, reset/global selectors stay scoped. Observe failure before implementation.
- [x] Implement `system.ts` with defaultConfig, scoped variables/reset/global CSS, semantic tokens, recipes, text styles and animation styles; implement `AtlasVNextProvider.tsx`.
- [x] Run pinned Chakra CLI typegen through a deterministic package command before typecheck/build/Storybook and certification. Generated package declarations stay in node_modules, never hand-maintained unions.
- [x] Run focused tests and commit system/provider/dependencies.

## Task 3 — Refresh primitive and motion

- [x] Write `AtlasRefreshButton.test.tsx` for accessible name, enabled click, disabled/loading activation, persistent DOM identity, completion and bounded cleanup.
- [x] Observe red, implement `AtlasRefreshButton.tsx` with Phosphor ArrowClockwise, 36px geometry, 800ms spin and 200ms completion; reduced motion suppresses both.
- [x] Run focused tests and commit.

## Task 4 — vNext shell

- [x] Extend shell tests for navigation, one main, current page and mobile menu keyboard semantics; observe red.
- [x] Implement `AtlasVNextShell.tsx`, desktop sidebar and compact expandable navigation, flexible main with no document overflow. Labels remain fixture content.
- [x] Run focused tests and commit.

## Task 5 — Design-language reference

- [x] Write `AtlasDesignLanguageReference.test.tsx` for heading, toolbar order, table semantics, selection cue and action hierarchy; observe red.
- [x] Implement reference and Storybook story with explicit provider. Date → School → search → state → refresh; local table overflow, attached detail, one dominant action; ordinary/blocker/empty/loading/unknown fixtures.
- [x] Run focused tests and commit.

## Task 6 — Boundary checker and certification

- [x] Write `scripts/check-atlas-vnext-ui-boundary.test.mjs` for Chakra-only acceptance, Mantine/theme/styles rejection, Chakra outside vNext rejection, model/API acceptance. Update certification-order assertion; observe red.
- [x] Implement deterministic source import checker and `ui:vnext:check`; preserve certification steps and add guard/typegen.
- [x] Run checker and focused certification tests; commit.

## Task 7 — Visual evidence and final verification

- [x] Build temporary pure-Chakra local harness outside repository; block nonlocal HTTP/WebSocket traffic. Capture 1366×768, 1440×900, 1920×1080 and 360×800; default, detail, refreshing, completed and blocker/unknown.
- [x] Record browser version/DPR, console, requests, screenshot manifest; verify focus, no document overflow, local scrolling and reduced motion.
- [x] Run focused tests including representative legacy #273 tests, boundary checker, typecheck, build, build-storybook, touched-source/document Prettier and git diff --check.
- [x] Self-review scope/security and record results. Delivery follows final commit: push the clean branch and open one Draft PR, then stop without merging. Next: ATLAS-UI-VNEXT-02-CHAKRA-PROCUREMENT after visual approval.

## Verification record — 10/09/2026

- Exact dependency pins were accepted by the existing supply-chain policy; no substitution or policy exception. Local Node 24.18.0 / pnpm 11.19.0; CI retains its pinned pnpm 11.7.0 and Node 24 setup.
- Task 1: D-045 was unallocated; links/status/format verified. D-034/D-035 unchanged. The approved attached task supplied the design; no separate speculative design process.
- Tasks 2–5: provider, refresh, shell and reference tests were written and run before their implementations (missing-component red); all now pass. The provider's conditional-token isolation assertion independently demonstrated assertion-red then green after scoping inherited light/dark selectors. No separate color-mode subsystem. Scoped zero-specificity preflight and disabled cascade layers preserve VNext recipes against the legacy Storybook element styles. Browser assertions cover primary background, 13px table type and normal header casing.
- Task 6 original delivery: missing checker and certification-order assertion both failed before implementation; 18 boundary tests and 103 certification-contract tests passed. The initial direct-import boundary is superseded by the explicit business bridge boundary in correction 01A below.
- Final focused run: **8 files / 218 tests passed**: 13 VNext, 18 boundary, 103 certification-contract, 84 legacy #273 regression/smoke tests. No hosted integration invoked.
- `pnpm ui:vnext:check`, `pnpm typecheck`, `pnpm build`, `pnpm build-storybook`, touched-source/document Prettier and `git diff --check` passed. Typegen uses pinned CLI output under node_modules, not tracked declarations. Build warnings concern large existing application/PDF/spreadsheet chunks and Storybook plugin timing; no failed gates.
- Pure harness evidence directory (outside repository): `C:/Users/HOME/.codex/visualizations/2026/09/10/01a089fc-fd88-74f1-9530-14ac7fa6596e/vnext-evidence/`. Reproduction inputs: `main.ts`, `build.mjs`, `capture.mjs`; results: `manifest.json`, `storybook-check.json`.
- Chromium **151.0.7922.34**, DPR **1**, viewports **1366×768 / 1440×900 / 1920×1080 / 360×800**. Manifest contains **42 captures**, **8 local requests**, **0 external requests**, **0 console errors**. Nonlocal HTTP and all WebSockets are blocked by default.
- Each viewport captures selected-detail, default-table, loading-refresh, completed-refresh, blocker, unknown, empty, long-search-empty, keyboard-focus and reduced-motion. Mobile additionally captures navigation and the full stacked reference. Completion screenshot pauses the actual CSS animation at its lift apex; timer cleanup and semantics are separately tested.
- Verified 40px filter controls / 6px corners; 36px refresh; 800ms spin; 200ms completion; stable layout geometry; reduced-motion suppression; no document-wide overflow; desktop action within viewport; mobile keyboard toggle/Escape and local table scrolling. Tight desktop heights use bounded table/detail scrolling. The initial browser-native date control is superseded by the sanctioned Chakra segmented control in correction 01A below.
- Storybook reference refresh and legacy Recipe smoke pass with no page errors. Screenshots: `storybook-vnext.png`, `storybook-legacy-recipe.png`. Storybook is not isolation evidence because its legacy global provider remains.
- Self-review: no production `main.tsx`, legacy theme/styles, Atlas modules/navigation, D-034/D-035, workflow files, Supabase, Retool, API/model/business contracts changed. No database migration or hosted write; rollback is presentation/build-only. Product visual approval remains required before the next Procurement task.

- One existing Pantry focus assertion failed during a run concurrent with builds; its unchanged useEffect-driven focus passed in the isolated 16-test file and the subsequent complete 218-test focused run without concurrent builds. No legacy test was modified or weakened. CI remains the broad certification authority.
- Prettier was checked for all touched source/config/document files in the repository formatter's scope. The generated pnpm lockfile retains pnpm's native formatting; a broad formatting-only rewrite was reverted.

## Correction 01A — design gate, 10/09/2026

Approved task: **ATLAS-UI-VNEXT-01A-DESIGN-GATE-CORRECTIONS**. Continued the same branch and Draft PR #274 with exactly one agent. Before edits, fetched origin and verified clean working tree, exact head `7eca6f8c680487a18051dec579aafbc34d7370bb`, exact base `40adf86db6dbe835c367478a4c933a3fbbd6cc34`, canonical checkout and open/Draft PR. No new branch or PR.

- [x] Sanctioned `AtlasDateInput`: official Chakra 3.37 DateInput, explicit vi-VN, forced leading zeros, day/month/year segments; internal ISO calendar dates via Chakra's public parseDate export. Resolved @internationalized/date 3.12.3 is already transitive; no dependency changes. Date editing test verifies ISO output and an English surrounding locale cannot change dd/mm/yyyy presentation.
- [x] Compact module/context Kế hoạch mua hàng → active h1 Phân bổ nhà cung ứng; explicit Phân bổ NCC / Xem phân bổ fixture actions; human quantity literals with adjacent units. No real numeric semantics changed.
- [x] Desktop 62/38 master/detail, 320px detail minimum and narrow stacking. Selected row uses background, left indicator and aria-selected without an extra text line.
- [x] Unknown outcome uses warning/uncertain treatment and blocks mutation. Separate Tải lại để xác nhận reloads only fixture state. Routine refresh cannot unblock unknown outcome. Existing refresh geometry/motion/cleanup preserved.
- [x] Primary hover uses independent action.primary.hover. Legacy src imports are denied except exact approved business modules through src/vnext/atlas/bridges; registry remains empty and no speculative bridge exists. Focused fixture proves permitted API reuse and rejection of indirect Workbench/Mantine, direct Mantine and legacy theme/styles.
- [x] Focused TDD: observed failures for missing date component, semantic hover coupling, direct/indirect boundary loopholes and outdated reference conventions before implementation. Final **5 files / 38 tests passed** (16 VNext + 22 boundary). `pnpm ui:vnext:check`, `pnpm typecheck`, `pnpm build`, `pnpm build-storybook`, touched-file Prettier and `git diff --check` passed. Existing large-chunk and Storybook plugin timing warnings remain non-blocking; GitHub Actions owns broad certification.
- [x] Regenerated pure local harness evidence: `C:/Users/HOME/.codex/visualizations/2026/09/10/01a089fc-fd88-74f1-9530-14ac7fa6596e/vnext-01a-evidence/`. Chromium 151.0.7922.34, DPR 1, **English browser locale**, all four required viewports. `manifest.json`: **42 captures**, **8 local requests**, **zero external requests / console errors**. Checks cover 38% detail at each desktop width, dd/mm/yyyy, homogeneous 40px/6px controls, explicit recovery, non-color selection, overflow, keyboard focus/navigation, refresh geometry/motion and reduced motion. Corrected date styling on the actual segment-group slot after visual inspection.
- [x] Product upload contact sheet (outside repo): `C:/Users/HOME/.codex/visualizations/2026/09/10/01a089fc-fd88-74f1-9530-14ac7fa6596e/vnext-01a-evidence/atlas-vnext-01a-contact-sheet.png`. Six critical views plus a labeled mobile continuation crop. Reproduction inputs and individual screenshots stay outside Git.
- [x] Qodana at starting head: inspected check 102795786702 and compared all 29 annotations to the PR diff. **Zero introduced changed-line hygiene findings**; **16 duplicate-code notices and 13 hygiene notices** are on unchanged legacy lines, explicitly deferred as outside this bounded foundation correction. The only annotated file also touched by the PR is scripts/atlas-staging-contract.test.mjs: annotations at lines 1343/1995, while the PR adds only four certification assertions near lines 752/767. No unrelated legacy cleanup or deduplication. Raw annotations retained in external evidence as qodana-starting-head.json.
- [x] Self-review: only date/reference/system, focused tests/checker and these two existing docs changed. D-045 unchanged in substance and file; no production rendering, dependency, API/model/auth, Supabase/migration/RLS/RPC/Edge Function, Retool, Google Sheets, live OPS or hosted business data changes. Zero hosted business writes. No migration; rollback remains presentation-only. Procurement not started. PR remains Draft and must not merge before Product visual approval.

## ATLAS-UI-VNEXT-01B — Soft Mineral visual identity

Approved bounded Product refinement, 10/09/2026. Staff reported fatigue during long operational sessions; Soft Mineral introduces calm mineral surfaces, slate/eucalyptus navigation and actions, and sparse clay identity cues. No theme study or workflow redesign. Exactly one agent, no subagents.

- [x] Fetched origin; verified the authorized E:/Project/OPS ERP/thuonghao-ops-erp checkout, correct GitHub origin, existing feat/atlas-ui-vnext-01-chakra-foundation branch, clean worktree and exact starting head `7499f654da0bea1c5c04c169a07f6d50efb18696`. PR #274 open/Draft; expected base `40adf86db6dbe835c367478a4c933a3fbbd6cc34`. Starting Frontend CI, Qodana and Supabase Smoke succeeded (Full Integration skipped by existing workflow). `ops:workspace` passed with its historical other-machine path warning; the task explicitly authorizes this checkout.
- [x] Exact palette implemented in system.ts; semantic tokens remain component authority. Raw token/value registry:

| Raw token       | Exact value |
| --------------- | ----------- |
| workspace       | `#F2F4F2`   |
| workbench       | `#FAFBFA`   |
| toolbar         | `#F0F4F1`   |
| subtle          | `#F6F8F6`   |
| selected        | `#E7EFEB`   |
| navigation      | `#31413E`   |
| navigationHover | `#3B4D49`   |
| navMuted        | `#C2CBC7`   |
| primary         | `#35564C`   |
| primaryHover    | `#2F4B43`   |
| text            | `#2A3330`   |
| muted           | `#66726D`   |
| clay            | `#B47A56`   |
| clayText        | `#915D3E`   |
| border          | `#D8DFDB`   |
| borderSoft      | `#E4E9E6`   |
| focus           | `#567A71`   |
| focusDark       | `#E0B589`   |
| success         | `#3F755E`   |
| successSoft     | `#EAF3ED`   |
| warning         | `#80612A`   |
| warningSoft     | `#F8F1DF`   |
| danger          | `#A3493F`   |
| dangerSoft      | `#F9ECEA`   |
| info            | `#456D76`   |
| infoSoft        | `#E9F0F1`   |
| white           | `#FFFFFF`   |

- [x] Enabled `strictTokens: true`, ran configured typegen, retained generated declarations exclusively in node_modules. Added a compile-time negative raw-color assertion. Typography uses shared text styles and existing font-weight tokens. Structural values use CSS variable fallbacks, without manufacturing Product tokens for every layout measurement. Browser evidence caught Chakra 3.37's type-only bracket escape emitting invalid CSS; explicit focus longhands also prevent inherited outline shorthand from resetting semantic focus colors; no bracket escape, cast, `any`, generated-type patch or strictness downgrade remains. The extra provider edit is only a zero-width structural literal; refresh logic is unchanged.
- [x] Lighter 6px workbench boundary, no elevation; softly tinted table header and off-white shared outline controls; readable placeholders and date literals; eucalyptus primary default/independent hover; slate navigation with narrow clay active rail and stronger active icon weight. Shared table recipe owns selected background, clay geometric indicator and reduced-motion-aware 140ms transition. Detail remains attached with a single edge, no shadow. Semantic badges retain independent pale status surfaces. D-045 remains technically accurate and unchanged.
- [x] TDD: four architecture assertions failed against the old palette/strictness/table convention before implementation. Final **7 files / 147 tests passed**: 22 vNext, 22 boundary, 103 certification-contract. Existing date editing/locale, refresh cleanup/motion, mobile navigation and unknown explicit recovery tests pass unchanged. Browser tests retain 62/38, ISO-to-dd/mm/yyyy, refresh spin/completion geometry and recovery behavior. No hosted business integrations invoked locally.
- [x] `pnpm ui:vnext:check`, `pnpm ui:vnext:typegen`, `pnpm typecheck`, `pnpm build`, `pnpm build-storybook` passed. Touched-file Prettier and `git diff --check` passed. Only existing large-chunk and Storybook plugin timing warnings. GitHub Actions owns broad final-head certification.
- [x] Final pure local evidence root: `C:/Users/HOME/.codex/visualizations/2026/09/10/01a08b23-5346-7b61-9067-e2664c213b14/vnext-01b-evidence/`. Chromium **151.0.7922.34**, DPR 1, English browser locale; **1366×768, 1440×900, 1920×1080, 360×800**, **47 captures**, eight local GET requests, **zero unexpected external requests / console errors / document-wide overflow**. Manifest and reproduction build/capture inputs retained outside Git. Includes default, selected/detail, attention, unknown, loading/completed refresh, keyboard focus, reduced motion, mobile navigation/full continuation and a 1366 close view of rails/header. Static captures allow the 140ms selection transition to settle; refresh animation evidence retains actual motion frames.
- [x] Rendered CSS semantic pairs verified: body/workbench **12.54:1**, muted/workbench **4.83:1**, muted/toolbar **4.51:1**, inverse/navigation **10.73:1**, inverse/primary **8.12:1**, accent/workbench **5.27:1**. Status text/soft surfaces: success **4.73**, warning **5.09**, danger **5.08**, info **4.92**. Focus ring/workbench **4.58**, toolbar **4.28**; inverse focus/navigation **5.69**, active navigation **4.75**. All checked normal text pairs ≥4.5 and focus pairs ≥3. Muted text would fail on selected/warning rows, so shared row styling promotes secondary content/actions to fg.primary (**6.94 / 7.21**). Selection combines geometry and aria-selected; warnings retain explicit text/symbols; unknown is neither success nor failure.
- [x] Contact sheet: `C:/Users/HOME/.codex/visualizations/2026/09/10/01a08b23-5346-7b61-9067-e2664c213b14/vnext-01b-evidence/atlas-vnext-01b-contact-sheet.png`. Matching 01A/01B comparison: `C:/Users/HOME/.codex/visualizations/2026/09/10/01a08b23-5346-7b61-9067-e2664c213b14/vnext-01b-evidence/atlas-vnext-01a-vs-01b-contact-sheet.png`. Screenshots remain outside the repository.
- [x] Visual self-review at 1366×768: calmer sidebar/large surfaces, legible dense table, small clay rails, aligned off-white 40px/6px controls, obvious eucalyptus save action reachable within viewport. Six rows visible before local table scrolling; attached detail retains local scrolling at short desktop height. Remaining Product review: long-session comfort is a staff judgment on real displays; muted toolbar text is AA-compliant but deliberately near the threshold (4.51:1), so future opacity reductions are prohibited.
- [x] Scope/security review: only vNext presentation, its tests and the two existing docs. No legacy Mantine presentation, production entrypoint, dependency, CI gate, business/API/quantity/lifecycle/auth change. No Procurement implementation. No backend, Supabase schema/migration/RLS/RPC/Edge Function, Retool, Google Sheets, live OPS or hosted business writes. No migration; rollback restores the prior presentation only. Continue the same Draft PR #274; do not merge. ATLAS-UI-VNEXT-02 remains unauthorized.
