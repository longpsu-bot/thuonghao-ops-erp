# TASK-ATLAS-UI-VNEXT-08 — Integrated Station workbench

**Status:** Bounded UI implementation complete; controller-owned render, finish review, and CI evidence pending

**Dispatch base:** `3523a9226967be18dd398267f8367287e6afe139`

**Branch:** `feat/atlas-ui-vnext-08-station-workbench`

## Goal and locked direction

Transfer the Product-selected refined **Trạm Điều Hành** hierarchy into the existing Atlas vNext Procurement allocation and Ingredient catalogue/detail surfaces. The transfer uses only Sổ Điều Phối's compact table density and restraint.

Locked geometry:

- desktop task context: exactly `196px`;
- mobile task-context block: exactly `88px`;
- desktop attached detail: exactly `320px` for the two primary target jobs;
- table target: approximately `38px` header, `42px` rows, and `178px` sticky identity where appropriate;
- mobile action targets: at least `44px`.

Secondary jobs may inherit the shared context primitive. Their internal composition is not redesigned.

## Implementation scope

- Add the presentation-only `AtlasTaskContext` and `bg.context` semantic token (`#DDE7E1`).
- Compose Procurement allocation as task context, compact workbar, natural-height table, and attached supplier decision detail.
- Compose Ingredients as task context, dense 360-row catalogue, and attached Ingredient detail.
- Retain native local table scrolling, keyboard-reachable table viewports, mobile continuation cues, clay selection rails, and eucalyptus focus treatment.
- Preserve explicit, uniquely named row actions, synchronized `aria-selected`/`aria-expanded`, detail focus entry, and exact-trigger focus return.

No hook, bridge, read model, API, quantity helper, permission rule, lifecycle, backend command, Supabase object, migration, RLS policy, Planning surface, Purchase Handoff behavior, PO lifecycle, recipe, school workflow, Retool application, or hosted data is changed.

## Acceptance evidence

Focused component evidence covers:

- the exact context and detail geometry;
- Procurement selection, action eligibility, quantity validation, dirty exit, uncertain recovery, focus entry, and focus return;
- Ingredient selection, 360 DOM rows, condensed supplier preview, review workflow, permissions/lifecycle, dirty exit, read-only/archive behavior, and focus entry/return;
- neutral disabled recipes, semantic token separation, and keyboard-reachable local table viewports.

Local verification commands and final pass counts are recorded in the implementation agent report. The controller must independently attach rendered production evidence and the finish-review verdict before the stacked PR is considered ready.

## Accessibility and security boundary

- Row actions remain explicit buttons; rows do not become undocumented navigation targets.
- Selection and expansion states are programmatically exposed.
- Opening detail focuses its labelled surface; closing returns focus to the exact initiating action.
- Mobile action targets use a minimum `44px` height, and table overflow remains local and labelled.
- Focus uses `focus.ring`; clay remains selection/identity only.
- Existing tab semantics, dirty guards, permission guards, error recovery, exact-quantity behavior, and backend authority remain unchanged.
- This presentation-only change adds no credentials, data access, storage, network call, or security-policy change.

## Validation commands

Run each focused test file in a separate process:

```text
pnpm exec vitest run src/vnext/atlas/system.test.tsx
pnpm exec vitest run src/vnext/atlas/AtlasTaskContext.test.tsx
pnpm exec vitest run src/vnext/atlas/AtlasTableViewport.test.tsx
pnpm exec vitest run src/vnext/atlas/procurement/ProcurementWorkbench.test.tsx
pnpm exec vitest run src/vnext/atlas/procurement/ProcurementSupplierDetail.test.tsx
pnpm exec vitest run src/vnext/atlas/master-data/IngredientSupplierWorkbench.test.tsx
pnpm typecheck
pnpm ui:vnext:check
pnpm exec prettier --check <every changed tracked file>
git diff --check
```

## Controller-owned screenshot matrix

The following production captures are **pending controller capture**; no screenshot result is claimed by this implementation task.

| Surface                   | Required states and widths                                                                            | Evidence state             |
| ------------------------- | ----------------------------------------------------------------------------------------------------- | -------------------------- |
| Procurement               | 1440 selected/unselected; 1280 unselected; 768 unselected; 390 selected/unselected                    | Pending controller capture |
| Ingredients               | 1440 selected/catalogue; 1280 catalogue; 768 catalogue; 390 selected/catalogue                        | Pending controller capture |
| Fixture-backed safeguards | Loading, empty/no-match, error, permission/read-only, stale/uncertain, reduced motion where supported | Pending controller capture |
| Comparison                | `#315 baseline → refined Station prototype → production implementation` at 1440 and 390               | Pending controller capture |

The independent `atlas-ui-finish-reviewer` verdict and GitHub `Frontend CI / Format, typecheck, test, build` result are also **pending controller execution**.

## Rollback

Revert the bounded frontend/documentation commit. No database, migration, remote data, API contract, or hosted-state rollback is required.

## Remaining risks

- The fixed context/detail planes reduce master-table width; controller capture must confirm the action column is initially visible at 1440 and local overflow remains discoverable at narrower widths.
- The 360-row Ingredient catalogue intentionally preserves one explicit action per row. The long keyboard tab sequence remains a production usability concern for a future separately approved accessibility slice; this task does not remove the documented action.
- Visual parity with the refined prototype, responsive overflow, contrast, and all non-happy-path screenshots remain subject to the controller-owned production render and finish-review gate.
