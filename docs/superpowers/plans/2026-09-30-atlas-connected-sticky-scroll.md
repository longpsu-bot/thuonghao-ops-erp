# Atlas Connected Sticky Scroll Implementation Plan

> **For agentic workers:** Execute the checks below in order in this authorized checkout. This is a bounded presentation-only hotfix.

**Goal:** Keep the identity header aligned with its frozen body column and keep long Procurement allocations locally scrollable in the connected Chakra shell.

**Architecture:** Chakra `Table.Root stickyHeader` owns vertical header-row stickiness. The first header and body cells each own horizontal stickiness. `AtlasTableViewport` retains native local overflow, with Procurement setting a viewport-aware desktop maximum rather than a fixed height.

**Tech Stack:** React, TypeScript, Chakra UI 3.37.0, Vitest, Storybook, Playwright.

**Spec:** User's connected-shell sticky table correction, 2026-09-30; `docs/ui/atlas-vnext-design-language-v1.md` and `docs/ui/atlas-vnext-09-post-planning-design.md`.

## Constraints

- Start from exact `origin/main` `2ab8c30f189dc0fd7d634d0c2b839c0cac6f5031` in the authorized E: checkout.
- Leave PR #286 and all backend, API, OPS v1, Retool, and production entrypoint files untouched.
- Keep the table correction presentation-only and preserve the existing header-row stacking layer.
- Treat Storybook as fixture evidence; connected immutable-preview UAT follows merge and refresh of PR #286.

## Steps

- [x] Strengthen the browser regression to measure Procurement without injected desktop height and check horizontal identity/header paint at compact width.
- [x] Run the strengthened regression against current main and record the expected failures.
- [x] Set explicit first-header sticky positioning in the four affected tables and a natural-until-max desktop Procurement viewport.
- [x] Run the regression at 1440×900 and 390×844, plus Procurement at 1366×768 and 1920×1080; inspect short-list and detail geometry and spot-check the other three tables.
- [x] Update current UI contracts and record fixture-versus-connected evidence.
- [x] Run focused tests and requested boundary, type, formatting, and whitespace checks.
- [ ] Commit, push, open a draft PR against main, and inspect Frontend CI. Do not merge.

## Regression evidence and limit

The original fixture script forced both `height` and `maxHeight` to `240px` before every case. Before the fix, the strengthened 248-row Procurement fixture measured `max-height: none`, `scrollHeight = clientHeight = 12237px`, and `scrollTop = 0` at 1366, 1440, and 1920. This reproduced the missing local desktop scroll. At 390px, the first identity headers of Confirmed Need, Procurement, Ingredients, and Planning Menu moved 120px left while their body identity cells stayed frozen. The top-left paint hit failed.

The final fixture regression passes all affected cases. Procurement's 248-row viewport uses its configured desktop maximum without injected height: 368px at 1366×768, 500px at 1440×900, and 680px at 1920×1080. Each has `scrollHeight > clientHeight`, accepts 180px of local vertical scroll, and retains the header at the local top. Attached detail remains 320px wide; table and footer bottoms are y=761, 893, and 1073 respectively, inside the corresponding viewport. A two-row Procurement fixture measures 137px client and scroll height at all three desktop widths. At 390×844, all four affected first headers remain aligned with their frozen body cells after 120px horizontal and 180px vertical scroll, with the first header painted at the intersection. Attendance, Pantry, and Supplier Catalogue pass vertical paint spot checks at 1440 and 390. No case has document-wide horizontal overflow.

This is fixture regression evidence, not connected production certification. `.storybook/preview.ts` imports Mantine and legacy `src/styles.css`; the legacy bare `th { position: sticky }` rule masked the missing Chakra first-header position. The browser regression neutralizes that bare rule with an equal-specificity later rule while preserving component Chakra classes and inline styles. Final connected immutable-preview UAT is required after this hotfix merges and PR #286 is refreshed. The old preview remains invalid for pinning.
