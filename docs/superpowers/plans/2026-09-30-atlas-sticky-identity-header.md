# Atlas Sticky Identity Header Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep the first identity header visible and above body cells when wide Atlas tables scroll vertically and horizontally.

**Architecture:** Chakra `Table.Root stickyHeader` owns vertical positioning. Each affected table owns its first column's horizontal offset and the header row's stacking layer. Browser assertions use the existing Storybook fixtures and actual Chromium layout because jsdom cannot evaluate sticky geometry.

**Tech Stack:** React, TypeScript, Chakra UI v3, Storybook, Python Playwright.

**Spec:** User-provided sticky first-column header regression request, 30 September 2026; [Atlas vNext design language](../../ui/atlas-vnext-design-language-v1.md).

## Global Constraints

- Work on `fix/atlas-ui-sticky-identity-header` from `477d0a15eea620b8a3397e1602b0df1fe97640f1`.
- Preserve body-cell positioning, header height, column widths, palette, scrolling, selection, focus, and accessibility.
- Change no backend, dependencies, production entrypoint, PR #286, hosted business data, Supabase, or Retool.
- Open a Draft PR to `main`; do not merge it.

---

### Task 1: Reproduce the overlap in Chromium

**Files:**

- Create: `scripts/atlas_sticky_header_browser_test.py`

**Interfaces:**

- Consumes: existing Storybook stories at `http://127.0.0.1:6006/iframe.html`.
- Produces: browser assertions for first and second header position, paint order, and mobile horizontal alignment.

- [x] Write a browser test that constrains each real `AtlasTableViewport` to 240px, scrolls vertically by 180px, and samples the top header pixels with `elementFromPoint` at 1440px and 390px.
- [x] Run it before implementation and record 11 failures for Confirmed Need, Procurement, and Ingredients; then record four more failures when Planning Menu joined the scope.

### Task 2: Correct only the affected tables

**Files:**

- Modify: `src/vnext/atlas/planning-confirmed/ConfirmedNeedTable.tsx`
- Modify: `src/vnext/atlas/master-data/IngredientCatalogue.tsx`
- Modify: `src/vnext/atlas/procurement/ProcurementAllocationTable.tsx`
- Modify: `src/vnext/atlas/planning/PlanningMenuStage.tsx` (same defect reproduced during the required spot-check)

**Interfaces:**

- Consumes: `Table.Root stickyHeader` and existing Atlas structural CSS variables.
- Produces: header row above body identity cells; responsive horizontal first-column offset.

- [x] Raise each sticky header row above frozen body cells without replacing Chakra's `position` or `top`.
- [x] Remove first-header `position` and `top` overrides; retain the opaque toolbar surface and intersection layer.
- [x] Use responsive `left` on Ingredients and Procurement first headers, with desktop `auto`.
- [x] Run the same browser assertions until green, then check current header height and widths.

### Task 3: Validate and document

**Files:**

- Modify: `docs/ui/atlas-vnext-design-language-v1.md`

**Interfaces:**

- Produces: a short presentation rule for header row stacking and frozen identity intersections.

- [x] Run focused AtlasTableViewport, Confirmed Need, Procurement, Ingredients, and Planning Sources Vitest files: 119 tests in five files passed with two workers.
- [x] Spot-check Attendance, Pantry, and Supplier Catalogue in the browser at 1440px and 390px; their first headers painted above scrolled rows. Planning Menu joined Task 2 after reproducing the same paint overlap.
- [x] Run `pnpm ui:vnext:check`, `pnpm typecheck`, targeted Prettier, and `git diff --check`.
- [ ] Commit, push, and open a small Draft PR to `main` after verifying the final diff.

The final Chromium run passed all 14 vertical and horizontal cases. In each, the first header and the next header stayed at the viewport top after 180px vertical scroll. At 390px, the first header and body identity column remained aligned after 120px horizontal scroll, and the header won the top-left paint intersection. The document had no horizontal overflow. Body-cell styles and widths were not changed.

Rollback is a frontend and documentation revert. There is no migration or data rollback; no Supabase, Retool, or hosted business writes were made.
