# Atlas vNext 10 — Decision Surface Refinement

**Status:** Approved implementation authority

**Date:** 28/09/2026

**Implementation baseline:** `ae90d2df297c571f2cca0ab116091a6c494062cb`

**Branch:** `feat/atlas-ui-vnext-10-decision-surface-refinement`

**Scope:** React/Chakra presentation, focused interaction tests and review evidence only

## 1. Purpose and authority

UI-10 gives the four Atlas operating surfaces more room for the current decision while preserving the certified UI-09 workflows. It refines the global shell, current-task context, Procurement allocation review and Confirmed Need confirmation table. It does not change controllers, hooks, bridges, APIs, database objects, calculation rules, permissions, lifecycle transitions, persistence or command semantics.

UI-10 supersedes UI-09 only where this document explicitly changes presentation. UI-09 and the approved business and decision documents remain authoritative for all protected behavior.

The operating hierarchy remains:

```text
global/module navigation
→ durable current-job context
→ active work surface
→ current decision
→ one authoritative action
```

## 2. Shared shell and task context

Desktop uses one persistent 72px slate navigation rail. The Atlas identity occupies approximately 56–60px at the top. Navigation controls are centered 44px targets with 18–20px icons. Every control exposes its full Vietnamese name, active navigation uses `aria-current`, accessible hover/focus tooltips expose the same complete labels, and the active item uses the existing navigation-hover surface, stronger icon weight and 3px clay identity rail.

The `Mở điều hướng Atlas` control opens a 272px labelled Chakra Drawer over the rail and workspace. Opening the Drawer does not change workspace width. The Drawer contains the complete grouped navigation names and footer, contains focus, closes with Escape and restores focus to the exact control that opened it. Mobile retains the top bar and the same overlay Drawer behavior.

`AtlasTaskContext` is a horizontal, full-width header. Its ordinary desktop height targets 72px with a 68px minimum, `bg.context`, and one bottom separator. At desktop widths it uses `minmax(0, 1fr) auto`: a muted 12px module label and 26px/700 active-job H1 on the left, with one muted 13px scope sentence on the right. On mobile it becomes one column with a 20px H1 and the scope sentence below. The header remains content-driven for long or zoomed text and does not clip to a fixed 88px block.

## 3. Workbench composition

Procurement, Ingredients, Planning Sources and Confirmed Need use one vertical work sequence:

```text
task context
→ tabs
→ workbar
→ operation and command feedback
→ current decision surface
→ authoritative action
```

The task context no longer consumes a persistent left column. Filters remain in their owning workbar; the context sentence does not duplicate them as chips. Tables own local horizontal overflow through `AtlasTableViewport`, and the document itself does not acquire horizontal overflow.

## 4. Procurement allocation

The Procurement allocation table has six resting columns:

1. `Nguyên liệu`
2. `Trường / điểm giao`
3. `Nhu cầu`
4. `Nhà cung ứng`
5. `Tình trạng / vấn đề`
6. `Thao tác`

The table targets an 880px minimum width, approximately 38px headers and 46–48px ordinary rows. Ingredient identity is semibold. Exact quantities are right aligned with the unit adjacent. The status column derives presentation only from existing exact quantities and backend state: `Đủ`, `Chưa phân bổ`, exact `Thiếu N unit` or `Vượt N unit`, `Cần cập nhật`, or `Bị chặn`. It never fabricates a quantity when the source is absent or uncertain. The selected row uses `bg.selected` and the clay selection rail.

The attached supplier detail remains 320px on desktop and follows the table on smaller widths. Its allocation summary is one exact reconciliation sentence, for example `100 / 100 kg đã phân bổ · Đã đủ`, with exact deficit or excess alternatives. Add, remove, save, permission, dirty-state and backend-validation behavior remain unchanged.

## 5. Confirmed Need

The resting Confirmed Need table has five columns:

1. `Nguyên liệu / nơi nhận`
2. `Đề xuất vận hành`
3. `Số lượng xác nhận`
4. `Thay đổi`
5. `Lý do / ghi chú`

Units remain adjacent to quantities. Raw theoretical requirement and the permanent `Làm tròn` and `Bước xác nhận` helper lines are removed from resting rows. An ordinary acceptance reads `Theo đề xuất`. A valid human change receives neutral eucalyptus decision emphasis and an exact signed delta with unit. Only invalid input receives danger treatment. Visual adjustment state compares the exact proposal and current confirmation; a fresh line is not presented as adjusted merely because its first decision is unsaved. Existing reason/note requirements and the stable `data-confirmed-need-line-id` selector remain intact.

Local step validation is actionable and uses the effective policy already supplied by the certified controller: `Số lượng xác nhận phải theo bước 0,01 kg.` No client-side rounding or replacement quantity is introduced.

`Xem cách hình thành nhu cầu` is the progressive evidence surface for the exact raw quantity. It identifies the selected run and current batch, and matches the complete identity exposed by the current Need Generation detail plus the exact Confirmed Need line. It requires one and only one match; missing or ambiguous data fails closed. When available it shows recipe and direct contributions, exact raw total, the revision's snapshotted proposal-rounding step, proposal, effective H1A confirmation step, confirmed value and atomic source lines. It does not join by ingredient alone and introduces no new endpoint.

## 6. States, responsiveness and accessibility

- Desktop at 1440px shows the 72px rail, approximately 72px task header, 320px Procurement detail and the main Confirmed Need decision columns without a persistent context sidebar.
- Narrow mobile keeps the top navigation, compact task header, local table scrolling, stacked detail and 44px interaction targets.
- Loading, empty, error, disabled, permission, historical and unknown-outcome states retain their current behavioral authority.
- Focus visibility, Drawer keyboard containment and focus restoration use existing Chakra and Atlas behavior. Motion respects the existing reduced-motion handling.
- Long Vietnamese labels, exact high-precision quantities and 200% zoom remain content-driven and locally contained.

## 7. System reuse and protected boundaries

UI-10 adapts `AtlasVNextShell` and `AtlasTaskContext` because they are shared by all four target surfaces. It reuses the existing Soft Mineral semantic tokens, table viewport, button recipes, status meanings and exact decimal/BigInt helpers. No new visual system or business-state helper is introduced.

The change has zero effect on Supabase, migrations, RLS, API contracts, hooks, bridges, materialization, calculation precedence, confirmation authority, Procurement persistence, Planning closeout, Retool or hosted data. All user-visible derived phrases are presentation over existing authoritative values.

## 8. Acceptance and evidence

Acceptance requires focused structure and interaction tests for the shared shell/context and both decision surfaces, relevant Atlas regression tests, TypeScript validation, the vNext boundary check, targeted formatting and whitespace checks. Visual evidence covers Procurement, Confirmed Need, Ingredients and Planning Sources at 1440×900 and 390×844, including the Drawer and progressive detail where applicable.
