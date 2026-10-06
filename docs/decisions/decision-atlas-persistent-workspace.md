# Decision D-048 — Atlas Persistent Workspace

**Status:** Owner-selected direction; production contract pending review and merge.

**Date:** 5 October 2026

**Approval basis:** Product Owner's ATLAS-UI-VNEXT-03B brief selects Variant D.

**Scope:** Application navigation/lifetime and presentation.

**Owner amendment — 6 October 2026 (ATLAS-PRODUCT-CORRECTIONS-01):** The owner explicitly replaces grouped destinations with eleven operator-job owners and moves the icon-only launcher to the far left. This bounded implementation and amendment await PR review/merge. The original seven-destination evidence remains historical; business domains, APIs and operating stages are unchanged.

## Context and authority

Atlas operators move among Need, supplier allocation, Recipes and School PXK while retaining local drafts, scope and selected detail. The current `AtlasVNextApp.tsx` conditionally mounts one module through `AtlasPageTransition`; navigation and voluntary sign-out invoke the active `AtlasModuleExitHandle`. Its shared service date seeds the next mounted operational module. `AtlasVNextShell.tsx` exposes seven destinations through a rail/drawer. This is the existing v1 implementation, not evidence that persistent workspace behavior is already shipped.

Draft [PR #349](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/349) at `e4b968989702540af94f25b996b570de796e489b` demonstrates retained panels and D's combination of C density and B finish. Its four prototype tests and local screenshot evidence establish a design hypothesis, not production/Auth/portal certification. Keep the PR draft/unmerged and copy no prototype implementation into production.

[ARCH-002](../architecture/arch-002-atlas-system-map.md), [PA-06A](../architecture/pa-06a-application-connection-contract.md), [ATLAS-MODEL-PRINCIPLE-01](decision-atlas-model-convergence.md), D-035 and D-045 remain authoritative. **FACTS EXPLICIT — STATE DERIVED — SUPPORTING OBJECTS GENERATED.** Workbench descriptors and tabs own no business meaning or persistence.

## Decision

| Decision key               | Frozen direction                                                                       |
| -------------------------- | -------------------------------------------------------------------------------------- |
| SELECTED_DIRECTION         | D                                                                                      |
| WORKSPACE_MODEL            | Static Registry + Local Reducer + Persistent Mounted Components                        |
| WORKBENCH_REGISTRY         | Static presentation/application definitions; conceptual id, label, icon, group, render |
| REDUX                      | REJECTED_FOR_NOW / NOT_JUSTIFIED                                                       |
| ZUSTAND                    | REJECTED_FOR_NOW / NOT_JUSTIFIED                                                       |
| ONE_INSTANCE_PER_WORKBENCH | YES                                                                                    |
| TAB_SWITCH_IS_EXIT         | NO                                                                                     |
| TAB_CLOSE_IS_EXIT          | YES                                                                                    |
| ACTIVATION_REFRESH         | NO                                                                                     |
| DATE_AFTER_MOUNT           | WORKBENCH_LOCAL                                                                        |
| SIGNOUT_WITH_DIRTY_TABS    | BLOCK_AND_RESOLVE_INDIVIDUALLY                                                         |

The workspace reducer owns only ordered open IDs and the active ID. A definition is not a database entity, domain aggregate, persisted lifecycle, Redux entity or class. Mounted owners retain forms, quantities, Supplier selection, filters, reads, commands, validation and currentness locally. About 10–12 workbenches do not justify a global store.

Opening an unopened ID mounts once and activates it; reopening activates its existing instance. Switching preserves date/stage/draft/selection/scroll without calling an exit guard, initializing reads or unmounting. Ordinary dirty switching is allowed. Resolve a live modal before hiding its owner. Closing is an actual exit and removes the panel only after the owning guard approves; existing Save/discard/cancel and busy/stale/unknown safeguards remain authoritative.

Use explicit workbench-to-workspace presentation reporting for ordinary/unsaved and optional truthful attention. Reports contain no draft or authoritative business state. DOM scraping is rejected. Recipe create/edit metadata accuracy is a release gate, not a form-open proxy for clean/dirty.

Attempted sign-out with any unsaved open owner blocks without discarding, identifies those owners and requires individual resolution. **Reject the prototype's sequential destructive exit composition:** an early discarded draft cannot be restored if a later guard cancels. Do not invent atomic global Save/Discard. Preserve non-destructive busy/unknown/session safety and browser `beforeunload` protection, including inactive workbenches.

Date seeds apply only on first mount. Need's **Tiếp tục phân bổ NCC** opens unopened **Phân bổ NCC** at the exact Need service date. Already-open Allocation is activated with date/local work intact; date discrepancies are explicitly disclosed. This application activation performs no backend business handoff. An explicit guarded `requestContext(...)` is deferred unless proven necessary.

Activation never refreshes. Existing command/readback, currentness/version/concurrency and stale/unknown recovery remain in each workbench. Inspect hidden effects/timers; never overwrite local work with hidden or activation-time refresh. Inactive panels are hidden/inert and excluded from focus, commands and active landmarks; escaping transient UI and DatePicker focus/input ownership require browser verification.

## Visual decision and alternatives

Select **Atlas Modern Operational Workspace**: full-width dense plane and compact shell from C, eucalyptus/slate identity, typography, refined surfaces and restrained elevation from B, with Atlas-integrated workbench tabs. Desktop is **☰ + ATLAS + compact utilities**, then open tabs, then active workbench. The far-left Phosphor List control has `aria-label="Bàn làm việc"` and `title="Bàn làm việc"`; the opened launcher retains the visible **Bàn làm việc** heading; the permanent icon rail is not primary v2 navigation.

The registry-generated **Bàn làm việc** launcher lists all available destinations with simple local search. Groups are **CÔNG VIỆC HẰNG NGÀY** (Thực đơn, Xác nhận nhu cầu, Phân bổ NCC, Đơn mua, Phiếu xuất kho, Đối chiếu PO / Phiếu xuất kho) and **DỮ LIỆU & CẤU HÌNH** (Trường học, Nguyên liệu, Nhà cung ứng, Công thức, Lệnh điều chỉnh), with no empty future groups. It shows only quiet open status and contains no business drafts/state. Successful selection opens/activates or activates-existing without duplication, closes the launcher and restores trigger focus; keyboard traversal/activation and Escape are required. Dirty/attention remains primarily on open tabs.

One compact shell utility contains user/environment/sign-out; the launcher does not repeat them. Mobile separates **Bàn làm việc** (launcher) from **Đang mở** (open-workbench selector); do not squeeze the full desktop strip/rail onto mobile. Touch targets remain 44px. Command-palette dependencies, nested navigation frameworks, recently used, favorites, pins and customizable groups are deferred until demonstrated need.

- Retain v1's switch/unmount model: rejected for this selected direction; operators would still reconstruct open local work.
- Adopt A, B or C alone: rejected as the v2 direction; the owner selected D's combined density/finish and persistence.
- Redux/Zustand or a workspace framework: rejected for now; local navigation facts and existing React state suffice.
- Durable/multiple-instance/cross-window workspaces: deferred until concrete operational demand.
- Merge #349: rejected; prototype DOM bridges, illustrative destinations, CSS and focus shim are evidence-only shortcuts.

## Supersession and consequences

After review and merge, [Design Language v2](../ui/atlas-vnext-design-language-v2.md) supersedes v1's shell/navigation/lifetime, replacement-page motion and selected composition geometry. D-045's Chakra foundation, D-035's operator hierarchy and D-034's table-first/signal-only principles remain. This decision does not add modules or daily stages, alter API contracts, lifecycle/status authority, quantity rules, Auth/RLS, currentness or released history. Existing internal job guards remain; the persistence promise applies to workspace tabs, not a new unguarded internal job lifecycle.

Benefits: immediate return to open work, preserved useful table width, visible unsaved attention. Costs: multiple retained React trees, explicit status/guard integration, local-date discrepancy disclosure and hidden-portal interaction audit. Required implementation gates are Recipe status accuracy, hidden timers, DatePicker browser ownership, focus cleanup and mobile/12-tab acceptance. They must pass before production rollout; this documentation makes no runtime certification claim.

**Owner clarification — 5 October 2026:** 03C does not require screen-reader/disability-assistance certification for the current Atlas operator population. Remove NVDA/JAWS, spoken-date/live-announcer human verification and WCAG certification as release gates. Retain browser input/focus isolation, date ownership, transient dismissal, predictable guarded dialogs/shortcuts and state-preserving navigation. This narrows presentation acceptance only; it changes no business/API/security contract.

Implementation is separately bounded by [03C](../implementation-tasks/TASK-ATLAS-UI-VNEXT-03C-PERSISTENT-WORKSPACE-PRODUCTION.md): A Workspace Foundation, then B Visual Adoption of Need, Procurement, Recipes and School PXK without requiring every module to be restyled.

## Operator-owner composition amendment

Each of the eleven jobs owns its persistent component and exit/status report.
Thực đơn retains Thực đơn / Sĩ số / Bổ sung as secondary jobs with the existing
week/date/School semantics. Recipe authoring and Change Orders compose directly;
Ingredient and Supplier owners reuse the existing hook/API with fixed identities.
Allocation and Orders reuse the Procurement hook with fixed owner stages. Successful
preparation or uncertain-outcome recovery verifies Orders readback and then refreshes
Allocation's own authority before activating Orders. An unopened Orders owner uses
the exact preparation date; an existing Orders owner keeps its date/filter/data and
receives explicit refresh disclosure, even for the same date. Activation adds no read.
Backend currentness and command checks remain authoritative. The test-only twelve
capacity descriptors remain separate from the eleven production destinations.

## Safety, validation and rollback

03B changes documents only: **Supabase 0; Retool 0; business-contract changes 0; hosted writes 0.** Hosted migration state is evidence only. No deployment, schema migration, production data change or data rollback.

Validate with `pnpm ui:vnext:check`, `pnpm typecheck`, `pnpm ops:workspace`, targeted Prettier and `git diff --check`; GitHub owns full Frontend CI. Product/architecture review and merge make the contract effective; production implementation/deployment remain separate. Reverting this documentation amendment restores v1's contract without runtime/data effects.

Revisit the store decision only for demonstrated multi-instance workbenches, durable restoration, cross-window synchronization or shared editable cross-workbench state. Do not add tab grouping, pinning, favorites or multi-instance dates for hypothetical scale.
