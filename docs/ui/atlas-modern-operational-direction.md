# Atlas modern operational direction — candidate

**ATLAS-UI-VNEXT-03A · CANDIDATE / PRODUCT REVIEW ONLY · 5 October 2026**

This document does **not** supersede [Atlas design language v1](atlas-vnext-design-language-v1.md). Direction B is the owner's approved hypothesis; the owner has not selected a coded finalist. Production implementation is a separate task.

## Authority and starting gate

PR [#348](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/348), Shopping List XLSX v1, merged on 5 October 2026 before branch creation. Starting `origin/main`: `bae6ca0bc0559d20259e0241944bab5108613559`. Clean user-authorized checkout: `E:/Project/OPS ERP/thuonghao-ops-erp`. Branch: `design/atlas-ui-vnext-03a-modern-operational-pilot`. Workspace check passed; its historical D: path warning does not override the task-authorized E: checkout.

Reference hierarchy:

1. Atlas workflow/business contracts, [ARCH-002](../architecture/arch-002-atlas-system-map.md), and [model convergence](../decisions/decision-atlas-model-convergence.md).
2. Owner-approved Direction B and this bounded pilot request.
3. Saas UI v3 application grammar.
4. Chakra UI v3 implementation patterns.
5. Horizon visual polish.

**FACTS EXPLICIT — STATE DERIVED — SUPPORTING OBJECTS GENERATED** remains authoritative. The three-stage operating baseline remains Requirement Planning, Purchase Planning, Warehouse Receiving. Recipes are supporting governance; this pilot's PXK surface represents the current connected School release capability and does not introduce another daily stage.

## Product identity

A modern B2B operational ERP for school catering and ingredient distribution. Calm mineral surfaces and eucalyptus actions support repeated work, exact quantities, recipient identity and explainable exceptions. Brand expression belongs in type, alignment, proportion and restrained navigation. There are no decorative business metrics or invented operational claims.

## Application structure

One application shell, one dominant operator job, scope controls, exceptions, dense primary work surface, contextual detail and an explicit command. Shell utilities remain secondary. Selected Recipes use a narrow navigator and a dominant editor; Procurement uses a master table and allocation editor; PXK uses a master and document detail. The geometry follows the job.

Three hypotheses use exactly the same workbench components and fixture factories:

| Variant                 | Shell / composition                                                                   | Detail and density                                                                    |
| ----------------------- | ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| A — Operational Saas UI | 204px light labeled sidebar, flush continuous work plane, compact 24px task title     | Flat attached editor with one separator; existing readable operational row rhythm     |
| B — Modern Operational  | 228px eucalyptus/slate sidebar, inset work plane, 28px title, composed spacing        | Refined subtle detail, 410px allocation editor at wide desktop, restrained outer lift |
| C — Dense Modern ERP    | Horizontal application navigation, full-width task plane, compact title/context strip | 370px allocation editor at wide desktop, compact cell rhythm and crisp structure      |

These are composition hypotheses, not palette swaps. Narrow screens share accessible control sizing and stack detail beneath the master.

## Typography

Retain Inter / Segoe UI / Arial and Atlas semantic foregrounds. Candidate task title: A 24px, B 28px, C 21px; mobile 22px. Section, body, label and helper typography retain production recipes. Use tabular numerals for data and adjacent units. No display face, all-caps microtype or decorative monospace.

## Surface hierarchy

Workspace → primary work plane → scope toolbar → table → attached detail → signal. A tests a continuous flat plane; B tests one softly lifted outer plane and quieter detail; C tests minimal framing. Status surfaces retain existing semantic colors and text. Do not shadow every region or nest decorative cards.

## Spacing rhythm

Retain the existing 6/10/16/24/32px vocabulary for controls and internal groups. Candidate outer gutters: A 0, B 24/28, C 8/12. B spends space on clear region separation, not inflated rows. C trims cell padding without shrinking input targets. Mobile gutter is 10px; local horizontal table scrolling remains intentional.

## Radius strategy

Candidate outer planes: A square, B 10px, C 2px; B attached editor 8px. Controls keep Atlas's 8px and mobile target contract. This isolated CSS tests a small geometry family; it does not amend production tokens or recipes.

## Elevation strategy

A and C remain flat. B uses one offset, softly blurred shadow on the outer work plane. Attached editors use surface tone, not another shadow. The comparison toolbar is review tooling and does not belong to the proposed production language.

## Navigation

Use consistent Phosphor icons and text destinations. A tests a light labeled side navigation; B tests a modern dark labeled sidebar; C tests horizontal navigation for a small destination set. Active location uses typography and semantic selected tone. At narrow widths, a reachable `Danh mục` disclosure reveals destinations in flow. Prototype destinations reset fixture data; they are not production routing or an approved expanded information architecture.

## Filters

Date/week, School, search and exceptions must remain reachable and reflect the active scope. Keep the current Atlas date components, Vietnamese display and canonical values. Preserve current dirty transitions, focus handling and selected-allocation scope locks. No generic filter builder. Inherited DOM/visual ordering issues are explicitly evaluated before v2 adoption.

## Dense tables

Tables own the majority of work space. Preserve exact numeric strings, column geometry, adjacent units, business order, explicit row actions, quiet hairlines, selected state and local scrolling. Prefer exceptions over a wall of normal badges. Do not compress quantity/identity into unreadable cells. Freeze only enough identity to preserve context; a 260px frozen column is inappropriate at 360px.

## Master/detail

Stable identity/context header → reconciliation or state → editable/document body → reachable action footer. Procurement detail locks scope exactly as today. Recipes reserve room for base editing and separate effective composition. PXK separates proposed release from immutable existing documents. Narrow detail is stacked; selection focus and close/return are retained.

## Business actions

- Confirmed Need: `Xuất Phiếu đi chợ`, `Nhập Phiếu đi chợ`, explicit `Lưu`, then `Tiếp tục phân bổ NCC`. Dirty state disables Shopping List and continuation; Save becomes primary.
- Procurement: exact splits, advisory suggestions, explicit `Lưu phân bổ`, then separate preparation and supplier release.
- Recipes: `Xem thay đổi` → `Lưu công thức`, with a frozen review and explicit return. Used base recipes remain read-only.
- Dispatch: current School `Phiếu xuất kho`; note is local until explicit `Phát hành phiếu xuất kho`. No Draft/Save lifecycle or quantity editing.

Pilot export/import callbacks are local review stubs, just as in the existing application review. They do not generate files or parse an uploaded workbook; the existing production Shopping List service and contract remain untouched. Real workbench gates are still exercised.

## Status and exceptions

Use the existing shaped states and concrete Vietnamese messages. Dirty, invalid, blocked, stale, uncertain outcome, released and empty have distinct meanings. Keep persistent uncertainty locks and explicit recovery. Color complements text and symbols. Do not add statuses or treat toast disappearance as resolution.

## Responsive states

Evidence targets 1920×1080, 1440×900, 1366×768, 650×900 and 360×800. Wide desktops use job-specific splits. Below 1024px navigation becomes an in-flow disclosure and selected detail stacks. Keep 44px mobile controls, readable labels, focused-input reveal, local overflow and no document-wide horizontal scrolling. Full-page captures show details/actions below the initial viewport; viewport captures show the actual first-viewport cost.

## Motion

No decorative page entrances. Retain workbench state/focus behavior and reduced-motion support. Comparison is immediate and preserves the mounted workbench when switching A/B/C. Entering/leaving D resets its separate review workspace; switching workbench tabs within D preserves them. Review variant and fixture controls are outside proposed product navigation.

## Anti-patterns

No dashboard card wall, KPI ornament, purple AI/crypto aesthetic, glass, promotional sidebar, wholesale template transplant, extra provider, table engine, design-system reboot, business logic in styling, automatic Save/release, hidden row actions or shrinking touch targets to claim density.

## Primary references

Verified during the independent reference review on 5 October 2026:

- [Chakra Table](https://chakra-ui.com/docs/components/table), [recipes](https://chakra-ui.com/docs/theming/recipes), [responsive design](https://chakra-ui.com/docs/styling/responsive-design): current docs and installed Atlas Chakra/CLI 3.37.0.
- [Saas UI v3 shell composition](https://github.com/saas-js/saas-ui/blob/v3/apps/compositions/src/examples/app-shell-sidebar.tsx), [page](https://github.com/saas-js/saas-ui/blob/v3/apps/compositions/src/ui/page/page.tsx), [responsive split](https://github.com/saas-js/saas-ui/blob/v3/apps/compositions/src/examples/split-page-responsive.tsx): v3 source at `1df691360c7f979b684923463bdd1825c2bdc769`; preset package 3.0.0-rc.1. Borrow composition, not runtime code.
- [Horizon official visual reference](https://github.com/horizon-ui/horizon-ui-chakra/blob/main/README.md): source at `27a99f9fb391e9da126e91cf109b3afd953fb58b`. Its package uses Chakra 2.6.1; the README badge is not Chakra v3 evidence. The official live demo was paused, so the linked visual was used.

No reference dependency is needed.

## Bounded implementation and review plan

Allowed files: the dedicated Storybook prototype and scoped CSS, a capture/check script, this candidate direction, and the evaluation record. Production components, adapters, system/provider, APIs, contracts, tests and dependencies are read-only.

1. Verify #348 and the clean authorized checkout; branch from current `origin/main`.
2. Read current contracts and four connected surfaces; run four blind, read-only jury reviews.
3. Reuse Atlas provider/workbenches/fixtures; code three isolated compositions and common eight-state review controls.
4. Capture the five viewports and populated/detail/dirty/problem states; compare contact sheets and record measurable overflow/row evidence.
5. Obtain separate final visual, operator and accessibility reviews; run Ponytail and optional Anti-Slop AFTER review.
6. Run UI boundary, typecheck, Storybook build, workspace and targeted formatting; commit, push and create a draft review PR. Do not merge or deploy.

Acceptance: four surfaces, structurally distinct A/B/C with identical functionality, post-#348 controls, state evidence, advisory scoring and owner decision retained. No backend/business/Retool change. No migration or rollback operation; removing the prototype/docs/script restores the baseline. Finalist adoption requires a separate approved Design Language v2 and production task.

## Variant D — Persistent Workspace

ATLAS-UI-VNEXT-03A-D extends draft #349 from `79cee68de5b80c7825d89289a85e156da4e6fc96`; it does not implement a production workspace or select a finalist. The owner requests C's usable width with B's Atlas finish and persistent workbench tabs.

Direction contract: one compact slate/eucalyptus utility bar, a separate launcher, a locally scrolling open-tab strip and a full-width work plane. Active tabs attach visually to that plane; an Atlas semantic-warning dot and accessible text identify unsaved work or form attention. At 360px, a compact open-workbench selector replaces the desktop strip. Switching changes visibility; closing invokes the owning workbench's existing exit boundary.

Bounded plan: extend the existing story/CSS and capture harness, add focused prototype-only interaction checks, then update these two documents and obtain independent visual/operator/accessibility/Ponytail reviews. Preserve A/B/C. No production components, dependencies, contracts, provider/system or backend changes. Acceptance covers all four mounted workbenches, retained drafts/filter/detail, no switch reads/remounts, guarded close, local twelve-tab overflow, mobile behavior and final-head CI.

- **WORKSPACE_MODEL:** static typed workbench descriptors → open IDs/order and active ID in local `useReducer` → stable keyed React panels. Descriptors and instances are UI identities, not domain objects or classes.
- **TAB_OPEN_RULE:** open once and activate; launch an already-open destination activates its existing instance.
- **TAB_SWITCH_RULE:** activate without `requestExit`, reload or unmount. Resolve an existing modal before switching; focus the destination tab to dismiss nonmodal transient UI.
- **TAB_CLOSE_RULE:** activate the guard owner, invoke its own `exitRef.requestExit`, and remove only inside the approval callback. Cancellation/blocking retains the panel. Choose a neighboring tab and restore focus after approved removal.
- **DIRTY_TAB_RULE:** tab presentation mirrors existing rendered dirty evidence; the existing exit handle remains the only discard authority. Recipe metadata lacks an exact rendered dirty signal, so an open create/edit form carries truthful “biểu mẫu món đang mở, kiểm tra thay đổi” attention, including after switching. It never claims that form is clean or that every open form is dirty. Production needs a small explicit tab-status callback; no drafts or validation move into the reducer.
- **SIGNOUT_RULE:** production must visit all open guards sequentially, with each owner visible, and sign out only after every approval. Cancellation stops the sequence. Existing approvals can already discard local work, so this is not an atomic preflight; earlier approved discards are not restored after a later cancellation. D has no real sign-out action.
- **MOUNTING_RULE:** one keyed mounted panel per open ID; inactive panels are hidden/inert. Reuse an Atlas provider inside each panel to contain its existing calendar portals. Never hide an open modal with active document-level focus/scroll locks.
- **FRESHNESS_RULE:** no refresh merely on activation. Stable Auth/API/context seeds preserve local state; existing scope reads, explicit refresh, write-time currentness, unknown/stale locks and command/readback remain authoritative. A future clean-return freshness policy may offer a check, but must not overwrite dirty/recovery state or imply cached authority is timeless.
- **CURRENT_DATE_PROPAGATION:** production App owns a shared date; Planning, Procurement and PXK report local dates outward, and unmounting currently initializes the next module from it. Recipes has its own as-of date. The four initial date props are mount seeds, not controlled values.
- **PERSISTENT_TAB_DATE_RISK:** changing the shared seed does not retarget an open Procurement; it would also describe whichever mounted module reported last. Date and stage must remain local.
- **RECOMMENDED_V2_DATE_SEMANTIC:** opening seeds a local date; activation retains it. Need continuation opens an unopened Procurement at the exact Need date/Allocation stage. An existing Procurement is activated with its date, stage and draft intact; explicitly disclose mismatched source date or retained Orders stage. Use existing guarded detail/date/stage controls in D. A later production task can add a guarded `requestContext({date, stage})` interface; do not simulate retargeting by changing an initial prop or remounting.
- **FUTURE_12_TAB_BEHAVIOR:** four real surfaces plus eight clearly illustrative capacity descriptors, one instance each, recognizable Vietnamese labels, local strip scrolling with active-tab reveal. No pinning, grouping or multi-instance dates.
- **REDUX_DECISION:** `NOT_JUSTIFIED`. Workspace facts fit a local reducer; workbench state remains inside mounted components. No Zustand, cache, router, persistence framework, classes or additional tab library.

Known dependency ceiling: DatePicker creates a shared, delayed document-body live announcer outside portal containers. Persistent tabs expose possible cross-tab announcement interference; this must be checked/documented and addressed in a separate production accessibility task, not by altering the Atlas provider here.
