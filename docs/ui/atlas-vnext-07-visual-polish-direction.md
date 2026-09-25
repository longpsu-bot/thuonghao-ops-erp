# Atlas vNext 07 Visual Polish Direction

**Status:** Approved for implementation  
**Branch:** `feat/atlas-ui-vnext-07-visual-polish`  
**Draft PR:** #315  
**Approved slice:** Workbench identity + bounded responsive table geometry

## 1. Purpose

This document records the approved visual direction for the next Atlas Chakra UI polish slice. It is intentionally presentation-only. It does not authorize changes to business workflow, backend semantics, lifecycle, API contracts, permissions, quantities, persistence, Supabase, Retool or Planning certification behavior.

The target is a polished institutional operations ERP that remains dense, table-first, Vietnamese-first, fast to scan and comfortable for long operator sessions. The work must not drift into generic SaaS dashboard styling, card soup, decorative metrics, gradients, glass, glow or a wholesale redesign.

## 2. Governing sources

- `AGENTS.md`
- `docs/ui/atlas-vnext-design-language-v1.md`
- `docs/ui/atlas-ui-quality-standard.md`
- `docs/ui/atlas-operator-workbench-patterns.md`
- D-034 — `docs/decisions/decision-atlas-modern-operations-ui-visual-architecture.md`
- D-035 — `docs/decisions/decision-atlas-workflow-first-operator-ux.md`
- D-045 — `docs/decisions/decision-atlas-chakra-ui-foundation.md`
- `src/vnext/atlas/system.ts`
- `src/vnext/atlas/AtlasVNextShell.tsx`

When this direction conflicts with an approved Product or architecture source, the approved source wins and implementation must stop for clarification.

## 3. Review evidence

The fixture-backed Atlas vNext review entry was inspected at:

- 1440 × 900
- 1280 × 800
- 768 × 1024
- 390 × 844

Reviewed surfaces:

- shell/navigation;
- School default portions;
- Ingredient/Supplier master data;
- Recipe catalogue/workbench;
- Procurement allocation.

The review produced sixteen screenshots. The capture reported zero console warnings/errors and no document-wide horizontal overflow. Narrow tables already use local overflow in several modules, but their geometry and identity anchoring are inconsistent.

Observed scale and composition:

- Schools rendered 34 editable rows in an approximately 3,000px document.
- Ingredients rendered 360 rows in an approximately 17,747px table inside a locally contained catalogue.
- Recipes rendered 12 rows, but the five-column catalogue collapsed into severe word wrapping at 390px.
- Procurement rendered one row above a large empty region and hid its H1 from visual presentation.

## 4. Executive diagnosis

Atlas already has the correct visual foundation: restrained Soft Mineral surfaces, eucalyptus navigation, clay selection accents, dense tables, readable controls and backend-authoritative behavior. The remaining quality gap is structural rather than decorative.

The reviewed modules use inconsistent identity sequences, toolbar compositions and table containment rules. This weakens the five-second understanding test: the operator should immediately see the current job, scope, work surface, state and one meaningful action. Narrow layouts expose the inconsistency most clearly through excessive shell height, fragmented action placement and crushed table columns.

The approved response is not a token facelift or a module-by-module redesign. It is a small shared presentation contract, applied to representative dense and sparse workbenches while preserving job-specific geometry.

## 5. Ranked visual improvements

### 5.1 Prevent narrow table collapse

Use job-derived minimum widths and local horizontal overflow rather than compressing columns until Vietnamese copy wraps word by word.

Initial geometry targets:

- Recipes: approximately 720px;
- Schools: 850–900px;
- Ingredients: 920–980px;
- Procurement: 1,020–1,080px.

At 768px and 390px, keep the primary human-recognizable identity column available while scrolling where useful. Sticky cells must use an opaque workbench background and verified stacking/focus behavior.

### 5.2 Restore visible Procurement identity

Procurement must show:

1. muted module context `Kế hoạch mua hàng`;
2. visible H1 `Phân bổ nhà cung ứng` or `Đơn mua`;
3. the existing primary job tabs;
4. the existing scope toolbar.

Programmatic stage-change focus must target the visible H1. `Phân bổ NCC / Đơn mua` remains primary job navigation and retains its stronger contained treatment.

### 5.3 Bound School bulk maintenance

The School table may use bounded local vertical scrolling. The dirty/invalid summary and `Lưu thay đổi` remain outside and immediately above the viewport.

Requirements:

- sticky table header;
- labelled, keyboard-reachable scroll region;
- no focus trap;
- local horizontal scrolling only;
- no page-wide horizontal overflow;
- all editable rows preserved;
- sticky School identity where useful at narrow widths;
- no pagination in this slice.

### 5.4 Establish a consistent identity order

Multi-job modules use:

```text
module context
→ current-job H1
→ job tabs
→ toolbar
→ work surface
```

Schools, as a single-job module, use:

```text
module context
→ H1
→ toolbar
→ summary/action
→ work surface
```

Primary operator-job tabs and quiet local/secondary tabs remain intentionally different hierarchy tiers. Do not normalize all tabs into one visual style.

### 5.5 Compose toolbar actions deliberately

Preserve practical filter order and group Refresh with the current primary action when both exist. Use the existing control scale, approximately 40px controls and 36px compact utilities, with disciplined 10px gaps and 16px toolbar padding.

Primary actions remain content-width at 768px and wider. They may flex at 390px when necessary for reachability and clear hierarchy.

### 5.6 Preserve Ingredient scale while adding context

Keep the full dataset and current local containment. Do not add pagination, virtualisation, result slicing, backend search or new dependencies.

Show useful result context:

```text
<filtered count> / <total count> nguyên liệu
```

when filtering changes the visible result set. Keep Ingredient identity available during narrow horizontal scrolling and retain the explicit `Xem / sửa` action.

### 5.7 Resolve sparse Procurement composition

The Procurement workbench should occupy the shell's remaining vertical space while keeping its table top-aligned. Do not fill the sparse state with decorative cards, KPIs or artificial content.

### 5.8 Reduce narrow-screen shell overhead

Preserve the 60px Atlas/navigation row, current navigation behavior, service date, operator identity and `Đăng xuất`. Tighten only the secondary header using compact vertical padding, bounded/ellipsized identity text and stable action placement.

## 6. Shared-system direction

Keep `src/vnext/atlas/system.ts` changes minimal. Do not change the palette, font stack, type scale, radii or action semantics unless implementation proves a presentation requirement is shared by at least two connected surfaces.

The approved workbench-frame convention is:

- outer `bg.workbench` surface;
- 6px workbench radius and one subtle edge;
- 16px identity inset;
- 12–13px muted context;
- 24px/650 visible H1;
- 6–10px context/title gap;
- 10–16px title/tab gap;
- `bg.toolbar` with 16px padding and 10px gaps;
- no nested header card or shadow.

A small presentation-only `AtlasTableViewport` is approved if at least two modules share identical structural behavior. It may own:

- local x/y overflow;
- max-height containment;
- accessible region naming;
- keyboard focusability;
- sticky-header containment;
- sticky-column stacking/background mechanics.

It must not own:

- data or columns;
- filtering, pagination or sorting;
- selection or business state;
- API behavior.

Screen-owned geometry remains screen-owned. A shared viewport must not impose one universal width or height.

Do not modify `src/vnext/atlas/AtlasTaskTabs.ts` in this slice because Planning consumes it.

## 7. Representative screen direction

### 7.1 Shell/navigation

- Preserve the 224px desktop sidebar, slate surface, clay active rail and visible Vietnamese labels.
- Preserve current desktop/tablet/mobile main insets.
- Tighten only the mobile secondary header.
- Keep operator identity textual rather than reducing it to an unlabeled icon.
- Preserve 44px navigation targets, inverse focus rings, Escape dismissal, focus return to `Danh mục` and reduced-motion behavior.
- Do not rename jobs or expose roadmap concepts.

### 7.2 Schools

- Keep direct numeric editing, tabular numerals, dirty-row background/rail and the single `Lưu thay đổi` command.
- Bound the 34-row table vertically and retain local horizontal scrolling.
- Keep dirty and invalid counts adjacent to Save.
- Keep School name/code/customer/type/status/location and both editable quantities.
- At narrow widths, the order number may move into School secondary text if needed to recover space without losing information.
- Disabled Save remains neutral and visually subordinate.

### 7.3 Ingredients/Suppliers

- Preserve separate Ingredient and Supplier jobs and current table-to-detail behavior.
- Use module context → current-job H1 → local job tabs.
- Preserve local vertical containment and sticky header.
- Add filtered/total Ingredient result context.
- Use an explicit table minimum width and sticky Ingredient identity at narrow widths.
- Keep `Tạo nguyên liệu` dominant and Refresh subordinate.
- Keep `Xem / sửa` explicit rather than making the whole row an implicit navigation control.
- Keep supplier-priority preview as quiet secondary text.

### 7.4 Recipes

- Preserve catalogue, creation/copy helper and post-lock Change Order jobs.
- Remove duplicated frame padding only where it is purely presentational.
- Give the non-compact Dish catalogue an approximately 720px minimum width.
- Keep the table locally scrollable and Dish identity available at 768px/390px.
- Preserve `Tạo món mới` as primary and `Nhập workbook` as a utility.
- Preserve existing fixed navigator/editor geometry while a Dish is open.
- Keep lock explanation and Change Order entry explicit but subordinate.

### 7.5 Procurement

- Restore a visible H1 and place it before the primary job tabs.
- Retain `Phân bổ NCC` as the abbreviated tab label and use `Phân bổ nhà cung ứng` as the full title.
- Fill the available workbench height without decorative content.
- Keep sparse tables top-aligned.
- Preserve all eight columns through local scrolling and keep Ingredient identity available at narrow widths.
- Preserve `Tiếp tục lên đơn` as the only dominant commitment action when backend-authorized.

The fixture may produce a saved/BALANCED allocation while `preparation` remains blocked unless the scenario is `ready`. Do not modify production/UI semantics to reconcile `Đã đủ` with `ALLOCATION_IMBALANCED`. For visual capture, use a semantically coherent Procurement scenario such as `ready`. Record the contradictory fixture as follow-up evidence only.

## 8. Existing strengths to protect

- Soft Mineral palette and current typography in `src/vnext/atlas/system.ts`.
- Desktop layering between navigation, global header, workspace and workbench.
- Sparse clay use for active navigation and selected rows.
- Dense, quiet table headers without zebra striping.
- Numeric alignment and quantity/unit adjacency.
- Ingredient local containment for large content.
- Recipe navigator/editor geometry.
- Status treatments pairing color with readable text.
- Existing compact Refresh treatment.
- Focus-visible, disabled-state, reduced-motion, Drawer focus-return and selected-row semantics.
- Backend-owned authority and safe unknown/stale outcome behavior.
- Recipe lock/Change Order boundary, Procurement preparation flow and all current Planning interaction.

## 9. First implementation slice

### In scope

- `src/vnext/atlas/AtlasVNextShell.tsx`
- `src/vnext/atlas/system.ts`, only for proven shared presentation requirements
- optional presentation-only `src/vnext/atlas/AtlasTableViewport.tsx`
- `src/vnext/atlas/schools/SchoolDefaultsWorkbench.tsx`
- `src/vnext/atlas/master-data/IngredientSupplierWorkbench.tsx`
- `src/vnext/atlas/master-data/IngredientCatalogue.tsx`
- `src/vnext/atlas/recipes/RecipeCapability.tsx`
- `src/vnext/atlas/recipes/DishRecipeWorkbench.tsx`
- `src/vnext/atlas/recipes/DishCatalogue.tsx`
- `src/vnext/atlas/procurement/ProcurementWorkbench.tsx`
- `src/vnext/atlas/procurement/ProcurementAllocationTable.tsx`
- focused tests and review-fixture recaptures at 1440/1280/768/390

### Out of scope

- `src/vnext/atlas/AtlasTaskTabs.ts`
- Planning components, behavior or certification work
- hooks, bridges, request builders, controllers, models or API contracts
- Supabase, database, migration, RLS or persistence changes
- quantity, permission, status or lifecycle changes
- Ingredient pagination, virtualisation, backend search or result slicing
- Recipe editor, Change Order, Supplier editor or Procurement allocation behavior
- notice-system consolidation
- new dependencies or broad component rewrites
- dashboards, decorative metrics, cards, gradients or branding changes

## 10. Visual acceptance checklist

### Viewports and hierarchy

- [ ] At 1440 × 900 and 1280 × 800, every screen shows context, visible H1, applicable tabs, aligned toolbar and dominant work surface without excessive title height.
- [ ] At 768 × 1024, filters reflow to no more than two columns and actions remain coherently grouped.
- [ ] At 390 × 844, shell chrome is compact and no H1, control label, account action or primary command is clipped.
- [ ] All four widths have zero document-wide horizontal overflow.
- [ ] Horizontal overflow occurs only inside explicitly labelled table regions.
- [ ] A first-time operator can identify the job, scope, work surface, state and primary action in approximately five seconds.
- [ ] Exactly one ordinary business command is visually dominant in each context.

### Responsive tables

- [ ] Schools' 34 rows are bounded while summary and Save remain outside and immediately above the viewport.
- [ ] Schools retains all editable rows with sticky header and useful School identity anchoring.
- [ ] Ingredients preserves all 360 fixture rows inside local containment and shows accurate filtered/total context.
- [ ] Recipes no longer collapses into word-by-word stacks at 390px.
- [ ] Procurement preserves all eight columns through local scrolling and keeps quantities adjacent to their unit.
- [ ] Sticky identity/header cells use opaque backgrounds and correct stacking without duplicated borders.
- [ ] Sticky regions never obscure visible focus.
- [ ] Scroll regions are keyboard reachable, accessibly named and do not trap focus.

### States and interaction

- [ ] Loading preserves the workbench frame and disables or hides commands while eligibility is unknown.
- [ ] Empty states continue to distinguish no records, no filter matches and missing prerequisites.
- [ ] Error, warning, stale and uncertain outcomes retain semantic text and non-color cues.
- [ ] Unknown write outcomes keep mutation disabled and retain authoritative refresh.
- [ ] Read-only states look intentional rather than broken.
- [ ] Disabled primary/destructive controls retain neutral disabled styling.
- [ ] Existing detail/workspace focus-entry and focus-return behavior remains intact.
- [ ] Mobile navigation still closes with Escape and returns focus to `Danh mục`.
- [ ] Reduced-motion behavior remains intact.

### Contract boundary and evidence

- [ ] No backend, Supabase, migration, RLS, API, model, quantity, status, lifecycle, permission or persistence delta.
- [ ] No Planning behavior or protected closeout interaction changes.
- [ ] No new dependency.
- [ ] Procurement visual evidence uses a semantically coherent scenario such as `ready`.
- [ ] Responsive recapture reports zero console warnings/errors and zero document-wide overflow.

## 11. Follow-up findings outside this slice

1. The contradictory Procurement review fixture should be corrected or documented in a separate fixture/test-evidence task. It is not production contract work for this PR.
2. Ingredient pagination, authoritative server search or virtualisation may require a separate Product/performance task if real connected scale warrants it.
3. Any future shared tab treatment must preserve the distinction between primary operator-job navigation and secondary/local tabs and must be reviewed with Planning consumers in scope.
