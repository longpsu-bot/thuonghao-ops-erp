# Atlas vNext 11 — Visual Finish and Surface Refinement

**Status:** Implemented for finish review

**Date:** 28/09/2026

**Implementation baseline:** `91835680f2c2e99243d05012871994459b3b16c1`

**Branch:** `feat/atlas-ui-vnext-11-visual-finish`

**Scope:** React/Chakra presentation, focused presentation tests and review evidence only

## 1. Purpose and authority

UI-11 is a visual finish pass over the approved UI-10 structure. It strengthens hierarchy, scanability and control cohesion across Procurement, Ingredients, Planning Sources and Confirmed Need while preserving the UI-10 shell, columns, master/detail geometry, compact filters and progressive disclosures.

The Atlas vNext design language, UI-09 protected workflows and UI-10 decision-surface structure remain authoritative. This change adds no business state, calculation, lifecycle, permission, persistence, API, bridge or backend behavior.

## 2. Finish diagnosis

UI-10 had the correct information architecture but used the same pale voice for headers, controls and row content. The repeated outlined controls, quiet table labels and uniform secondary text made the station feel closer to a component library composition than a mature operating tool. UI-11 concentrates the visual change in shared recipes and repeated presentation meanings instead of adding decoration or new containers.

## 3. Shared finish rules

- The horizontal task masthead keeps its existing height and context tint. Module context is 12px semibold and muted; the active job remains the 26px desktop / 20px mobile H1 with tighter tracking; the scope summary uses a distinct 13px medium voice.
- The 72px desktop rail and 44px controls remain exact. The active clay rail is absolutely positioned so the icon optical axis does not move. Tooltips retain slate, 12px semibold text, a subtle border and no shadow.
- Primary task tabs use an off-white selected surface and a 3px clay bottom marker. Secondary source tabs use semibold text and an underline without a selected fill.
- Workbars use the toolbar surface, 10px mobile / 12px desktop vertical rhythm, 16px desktop horizontal padding, a stronger search label and a deliberate lower boundary into the decision surface.
- Resting controls use the workbench surface and default border. Hover uses the semantic interactive border mapped to the existing eucalyptus focus color. Focus remains the existing 2px Atlas ring. Disabled controls retain full-opacity neutral styling.
- Secondary buttons are white on toolbar surfaces. Tertiary actions are transparent and quiet. The new `tableAction` recipe is reserved for compact row actions: transparent rest, subtle border and selected/interactive hover.
- Shared table headers retain the 38px target, use 13px semibold default text, toolbar tone, a default lower rule and 12px horizontal cell padding. Rows retain their approved density with one subtle lower edge, quiet hover, selected eucalyptus and the stable 3px clay rail.
- `quantityInline` uses 13px semibold tabular numerals. `unitInline` uses 12px normal muted text with a six-pixel visual separation. Exact quantity strings and precision remain unchanged.

## 4. Surface application

### Procurement

The six-column table, 880px minimum and 320px attached detail remain unchanged. Ingredient identity leads; School is medium with delivery location subordinate; balanced `Đủ` stays muted. Exceptions retain their symbol and text, with semibold warning or danger emphasis and no whole-row tint. Row actions use the quiet table-action recipe. The detail reconciliation separates the exact allocated/target quantity, muted `đã phân bổ`, and the meaningful deficit, excess or balanced outcome while preserving the exact accessible sentence.

### Confirmed Need

The five UI-10 columns remain unchanged. Proposal quantities use the shared quantity/unit hierarchy. A valid changed confirmation uses the selected eucalyptus decision zone, interactive border and stronger input value; its exact delta appears only when meaningful. Invalid input remains the only danger treatment. Unchanged reason/note content stays quiet, and the dirty helper uses operational eucalyptus rather than warning semantics. The progressive evidence surface remains attached and flat.

### Ingredients

All 360 fixture rows remain rendered at the existing 42px target. Ingredient names remain semibold, normal lifecycle text stays muted, and `Ngừng dùng` stays semibold warning text. Order steps use tabular numerals, supplier priority numbers are emphasized inside restrained secondary copy, and row actions use the shared table-action recipe. The sticky identity and 320px detail geometry are unchanged.

### Planning Sources

The three jobs and all source behavior remain unchanged. Secondary tabs now read as source switches instead of filled chips. The workbar follows the shared rhythm. Review tables keep `Trước` muted and give changed `Đề xuất` values primary semibold emphasis. Dirty guidance remains calm and the existing single authoritative action hierarchy is preserved.

## 5. Responsive and accessibility result

Desktop evidence uses 1440×900. Mobile evidence uses 390×844. The 72px desktop rail, overlay drawer, local table overflow, compact filter disclosures, 44px mobile targets, exact row/action names, tab semantics, focus behavior and reduced-motion rules are unchanged. Quantity and Unit DOM spacing remains explicit so accessible names and text exports preserve strings such as `+0,01 kg`.

The evidence set includes the four resting surfaces at both viewports plus Procurement selected/problem, Ingredients selected, Confirmed Need dirty-valid and the scrolled open progressive detail. The full-resolution captures remain in the task visualization directory under `atlas-ui-11-implementation/`.

Review sheets are checked into the repository for Draft PR review:

- [Desktop before / after](./evidence/atlas-ui-11/atlas-ui-11-before-after.png)
- [Mobile before / after](./evidence/atlas-ui-11/atlas-ui-11-mobile.png)
- [Selected, problem, dirty-valid and progressive-detail states](./evidence/atlas-ui-11/atlas-ui-11-state-evidence.png)

## 6. Validation and rollback

Focused tests cover the shared recipes and the nearest shell, task-context, Procurement, Ingredients, Planning Sources and Confirmed Need behavior boundaries. Required validation is TypeScript, the Atlas vNext boundary checker, targeted Prettier and whitespace checks.

### Environment identity correction

The connected shell header persistently shows `Môi trường · <environmentLabel>` beside the existing session identity, including compact layouts and while the navigation drawer is closed. This restores the visible environment identification required by PA-06A and keeps the label outside animated page content. The drawer footer retains its environment label; reference mode retains its non-authoritative footer. The 72px rail, 272px overlay drawer, task masthead and module navigation are unchanged. The existing page-transition assertion for the mounted environment label remains unchanged and must pass.

Rollback is a frontend and documentation revert. There is no migration, hosted-state or data rollback because UI-11 changes no backend, Supabase, Retool or hosted business data.

## 7. Protected boundaries

UI-11 changes no Supabase object, migration, RLS policy, API/RPC contract, controller, hook, bridge, calculation, exact quantity formatter, Planning certification, Procurement persistence, Confirmed Need persistence, lifecycle, permission, Retool asset, dependency, production entrypoint or hosted business data.
