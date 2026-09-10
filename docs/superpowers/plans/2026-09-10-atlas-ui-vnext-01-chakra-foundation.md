# Atlas UI vNext foundation implementation plan

**Goal:** Build a fixture-only Chakra presentation beside the certified Atlas application.

**Authority:** Product-approved ATLAS-UI-VNEXT-01-CHAKRA-FOUNDATION-SHELL; OPS_SYSTEM_MAP v1.0; D-034/D-035. One agent, inline execution, no subagents.

**Baseline:** `40adf86db6dbe835c367478a4c933a3fbbd6cc34`, the verified PR #273 squash result. Canonical checkout explicitly confirmed by Product: `E:/Project/OPS ERP/thuonghao-ops-erp`. Work directly there on `feat/atlas-ui-vnext-01-chakra-foundation`; the unused setup worktree is detached and contains no task edits.

**Architecture:** Business capability → operator job → command/read model → vNext workbench → Atlas design language → Chakra primitive. Fixture data only. No business/API/model, production entrypoint, legacy styling, Supabase, Retool, navigation or hosted changes.

**Dependencies:** Exact `@chakra-ui/react@3.37.0`, `@emotion/react@11.14.0`, development `@chakra-ui/cli@3.37.0`. Stop on dependency policy rejection. Keep Mantine and Phosphor.

## Task 1 — Architecture decision and design-language specification

- [ ] Check D-045 is unallocated; retain D-034/D-035 unchanged.
- [ ] Create `docs/decisions/decision-atlas-chakra-ui-foundation.md` and `docs/ui/atlas-vnext-design-language-v1.md`; supersede only D-033 status and update decision register.
- [ ] Verify links, status, explicit business exclusions and touched-file formatting; commit documentation.

## Task 2 — Dependencies and system/provider

- [ ] Add provider tests in `src/vnext/atlas/AtlasVNextShell.test.tsx`: token context resolves workspace, provider renders Chakra child, reset/global selectors stay scoped. Observe failure before implementation.
- [ ] Implement `system.ts` with defaultConfig, scoped variables/reset/global CSS, semantic tokens, recipes, text styles and animation styles; implement `AtlasVNextProvider.tsx`.
- [ ] Run pinned Chakra CLI typegen through a deterministic package command before typecheck/build/Storybook and certification. Generated package declarations stay in node_modules, never hand-maintained unions.
- [ ] Run focused tests and commit system/provider/dependencies.

## Task 3 — Refresh primitive and motion

- [ ] Write `AtlasRefreshButton.test.tsx` for accessible name, enabled click, disabled/loading activation, persistent DOM identity, completion and bounded cleanup.
- [ ] Observe red, implement `AtlasRefreshButton.tsx` with Phosphor ArrowClockwise, 36px geometry, 800ms spin and 200ms completion; reduced motion suppresses both.
- [ ] Run focused tests and commit.

## Task 4 — vNext shell

- [ ] Extend shell tests for navigation, one main, current page and mobile menu keyboard semantics; observe red.
- [ ] Implement `AtlasVNextShell.tsx`, desktop sidebar and compact expandable navigation, flexible main with no document overflow. Labels remain fixture content.
- [ ] Run focused tests and commit.

## Task 5 — Design-language reference

- [ ] Write `AtlasDesignLanguageReference.test.tsx` for heading, toolbar order, table semantics, selection cue and action hierarchy; observe red.
- [ ] Implement reference and Storybook story with explicit provider. Date → School → search → state → refresh; local table overflow, attached detail, one dominant action; ordinary/blocker/empty/loading/unknown fixtures.
- [ ] Run focused tests and commit.

## Task 6 — Boundary checker and certification

- [ ] Write `scripts/check-atlas-vnext-ui-boundary.test.mjs` for Chakra-only acceptance, Mantine/theme/styles rejection, Chakra outside vNext rejection, model/API acceptance. Update certification-order assertion; observe red.
- [ ] Implement deterministic source import checker and `ui:vnext:check`; preserve certification steps and add guard/typegen.
- [ ] Run checker and focused certification tests; commit.

## Task 7 — Visual evidence and final verification

- [ ] Build temporary pure-Chakra local harness outside repository; block nonlocal HTTP/WebSocket traffic. Capture 1366×768, 1440×900, 1920×1080 and 360×800; default, detail, refreshing, completed and blocker/unknown.
- [ ] Record browser version/DPR, console, requests, screenshot manifest; verify focus, no document overflow, local scrolling and reduced motion.
- [ ] Run focused tests including representative legacy #273 tests, boundary checker, typecheck, build, build-storybook, touched-file Prettier and git diff --check.
- [ ] Self-review scope/security, record results, commit clean branch, push and open one Draft PR. Stop without merging. Next: ATLAS-UI-VNEXT-02-CHAKRA-PROCUREMENT after visual approval.
