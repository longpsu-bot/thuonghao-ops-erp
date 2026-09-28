# Atlas vNext 09 — Post-Planning Station Convergence

**Status:** Approved implementation authority

**Date:** 27/09/2026

**Current-main baseline:** `42e473b5b856100869538f4e41ef5a325b99c893`

**Pinned UI reference:** `ea154020bef6a068c1a9f70f5b6ba93d65ccc4a0`

**Branch:** `feat/atlas-ui-vnext-09-post-planning-convergence`
**Scope:** React/Chakra presentation and review evidence only

> **Presentation supersession:**
> [Atlas vNext 10 — Decision Surface Refinement](./atlas-vnext-10-decision-surface-refinement.md)
> supersedes UI-09's 196px/88px task-context geometry, the eight-column
> Procurement allocation table and the seven-function resting Confirmed Need
> table. UI-09 remains authoritative for the protected workflows, contracts,
> quantity meanings, permissions and command semantics that UI-10 preserves.

## 1. Purpose and authority

UI-09 ports the approved `Trạm Điều Hành` direction onto the certified current system. It does not merge the old UI stack. Current-main controllers, bridges, APIs, quantity helpers, permissions, command semantics, long-running-operation behavior and certification selectors remain authoritative.

The governing sources are D-034, D-035, D-045, the Atlas vNext design language, the Atlas UI quality standard, D-036/D-037 as amended by the current Procurement contract, and the certified Planning implementation on `main`. The pinned UI-07/UI-08 branch supplies presentation intent only. Where old implementation conflicts with current behavior, current behavior wins.

The visual hierarchy is locked:

```text
global/module navigation
→ durable current-job context
→ active work surface
→ current decision
→ one authoritative action
```

The Station is operational software, not a dashboard, marketing surface, card gallery or generic admin template.

## 2. Director diagnosis

The four target surfaces have correct behavioral boundaries and Soft Mineral primitives but do not yet read as one operating station. Procurement and Ingredients retain older header/tool framing and flexible detail widths. Planning Sources hides the active source job and squeezes a comparison task into a generic inspector. Confirmed Need preserves the correct facts but presents its table, utilities and Save/Continue state without enough decision hierarchy. UI-09 therefore changes composition, density, containment, focus and responsive behavior while leaving authority and workflow untouched.

The director found no approved-document conflict and proposed no backend, API, lifecycle, calculation, persistence, permission or hosted-data change.

## 3. Selected inherited direction

- Direction: `Trạm Điều Hành`.
- Table treatment: `Sổ Điều Phối` density and restraint.
- Desktop task context: exactly `196px`.
- Compact context below `lg`: exactly `88px`.
- Procurement and Ingredient desktop detail: exactly `320px`.
- Table header target: approximately `38px`.
- Resting display row target: approximately `42px`.
- Mobile interaction target: at least `44px`.
- Planning comparison width follows its job and is not forced into a 320px detail.
- Editable, multiline, validation, error, historical and expanded rows remain content-driven.

Selection uses the existing clay identity rail. Keyboard focus uses eucalyptus. These meanings remain visually distinct.

## 4. Transfer ledger

| Old source / concept                             | Current-main target            | Decision     | Reason                                                 | Protected behavior                          |
| ------------------------------------------------ | ------------------------------ | ------------ | ------------------------------------------------------ | ------------------------------------------- |
| Exact restored UI agent definitions              | `.codex/agents/*`              | KEEP CURRENT | Exact pinned blobs are already restored                | Role separation and writer boundary         |
| Refined `Trạm Điều Hành` thesis                  | All four surfaces              | PORT         | Product-selected direction                             | No workflow or backend change               |
| `Sổ Điều Phối` density/restraint                 | Operational tables             | ADAPT        | Port rhythm, not a universal structure                 | Job-specific geometry                       |
| `bg.context` token                               | `src/vnext/atlas/system.ts`    | PORT         | Durable context needs one semantic surface             | Existing palette/action meanings            |
| Existing Soft Mineral system                     | `system.ts`                    | KEEP CURRENT | Already authoritative                                  | Focus, disabled and status semantics        |
| Pinned `AtlasTaskContext`                        | Shared component               | ADAPT        | Planning/mobile/accessibility need current-safe inputs | Presentation only; 196px/88px               |
| Pinned `AtlasTableViewport`                      | Shared component               | PORT         | Correct local-overflow ownership                       | Native scroll; no business state            |
| Pinned shared tests                              | Shared tests                   | ADAPT        | Cover four current consumers                           | Geometry, named region and one H1           |
| UI-08 Procurement composition                    | Current Procurement            | ADAPT        | Reconcile with newer source/controllers                | Allocation, permissions, dirty and recovery |
| UI-08 sparse allocation table                    | Procurement table              | PORT         | Product-selected behavior                              | Eight columns and exact quantities          |
| UI-08 Procurement 320px detail                   | Supplier detail                | PORT         | Locked desktop geometry                                | Add/remove/save/readback                    |
| Current Procurement hooks/bridges/helpers        | Procurement                    | KEEP CURRENT | Newer authority                                        | Exact allocation and unknown outcomes       |
| Current Orders job                               | Procurement                    | KEEP CURRENT | Outside the allocation redesign                        | PO behavior and exports                     |
| UI-08 Ingredient composition                     | Current Ingredients            | ADAPT        | Reconcile with current lifecycle/review                | 360 rows and current commands               |
| UI-08 count/status/action treatment              | Ingredient catalogue           | PORT         | Improves scanability and truthfulness                  | Explicit status/actions                     |
| UI-08 Ingredient 320px detail                    | Ingredient detail              | PORT         | Locked desktop geometry                                | Review/lifecycle/read-only                  |
| Current Ingredient/Supplier controller           | Master data                    | KEEP CURRENT | Backend-authoritative behavior                         | Permissions, dirty and recovery             |
| Current Supplier inner composition               | Supplier job                   | KEEP CURRENT | Not a primary redesign target                          | Supplier workflow                           |
| Current three Planning source jobs               | Planning Sources               | KEEP CURRENT | Approved workflow                                      | Menu/Attendance/Pantry commands             |
| Station context/workbar for Planning             | Planning Sources               | ADAPT        | Extends selected direction                             | Week/date/scope/search/refresh              |
| Current generic Planning review split            | Planning review                | ADAPT        | Comparison needs more width                            | Before/after/correction semantics           |
| Current source tables                            | Source stages                  | ADAPT        | Add containment and rhythm only                        | Imports, zero/no-additions and errors       |
| Current Planning hooks/APIs                      | Planning                       | KEEP CURRENT | Frozen contract                                        | Dirty/currentness/recovery                  |
| Seven Confirmed Need functions                   | Confirmed Need table           | KEEP CURRENT | Distinct authoritative facts                           | Raw/proposal/human/delta/reason             |
| Station context/workbar for Confirmed Need       | Confirmed workbench            | ADAPT        | Improves decision hierarchy                            | Existing filters/actions                    |
| `AtlasOperationStatus`                           | Confirmed Need                 | KEEP CURRENT | Certified behavior newer than #319                     | Busy, elapsed, readback and unknown         |
| `data-confirmed-need-line-id`                    | Confirmed Need table           | KEEP CURRENT | Protected browser selector                             | Stable identity                             |
| Exact quantity/draft helpers                     | Confirmed Need                 | KEEP CURRENT | D-046/H1A authority                                    | Decimal and historical precision            |
| Old #319 removal of operation status             | Confirmed Need                 | OMIT         | Stale against certified main                           | Long-operation safety                       |
| Old #319 removal of line selector                | Confirmed Need                 | OMIT         | Breaks certification                                   | Stable identities                           |
| Old non-target shell/Recipe/School hunks         | Non-target modules             | OMIT         | Outside UI-09                                          | Later current behavior                      |
| Prototype CSS/parser/hardcoded data              | Production                     | OMIT         | Prototype evidence only                                | Tokens and exact helpers                    |
| Historical screenshots                           | UI-09 evidence                 | OMIT         | Comparison only                                        | New evidence must be current                |
| Existing stories/fixtures                        | Four surfaces                  | KEEP CURRENT | Useful state coverage                                  | Behavioral regression evidence              |
| UI-09 large render fixtures                      | Review-only fixtures/tests     | ADAPT        | Integrated acceptance                                  | No hosted IDs or production hardcoding      |
| Retained Staging IDs/data                        | Any fixture or production file | OMIT         | Protected certification evidence                       | No second hosted write                      |
| `AtlasTaskTabs` and `PlanningCapability`         | Current navigation             | KEEP CURRENT | Existing hierarchy is authoritative                    | Keyboard and dirty-exit routing             |
| Protected backend/certification/entrypoint paths | Repository boundary            | KEEP CURRENT | Explicit zero-change requirement                       | Certified backend and cutover               |

## 5. Shared Station foundation

### `AtlasTaskContext`

The component accepts display-ready module identity, one visible active-job H1, concise context values, and explicit accessible summary text. It must not fetch, filter, derive lifecycle, own navigation, interpret permissions or run commands.

At `lg` and above it is a 196px context plane. Below `lg` it becomes an 88px compact block with a combined human-readable summary. It uses a single new semantic `bg.context` surface, one separator and no shadow/card treatment. It must not generate an empty accessible name from arbitrary React content.

| Surface          | Module                        | Active job                         | Desktop details                  | Compact summary |
| ---------------- | ----------------------------- | ---------------------------------- | -------------------------------- | --------------- |
| Procurement      | `Kế hoạch mua hàng`           | `Phân bổ nhà cung ứng` / `Đơn mua` | Date; School/location scope      | Date · scope    |
| Ingredients      | `Nguyên liệu và Nhà cung ứng` | `Nguyên liệu` / `Nhà cung ứng`     | Count; Ingredient status         | Count · status  |
| Planning Sources | `Lập nhu cầu`                 | `Thực đơn` / `Sĩ số` / `Bổ sung`   | Week; service date; School scope | Date · scope    |
| Confirmed Need   | `Lập nhu cầu`                 | `Xác nhận nhu cầu`                 | Service date; School scope       | Date · scope    |

Failed reads show `Không xác định`, never a fabricated zero count.

### `AtlasTableViewport`

The viewport is a presentation-only, named `role="region"` with `tabIndex={0}`. It owns local horizontal/vertical overflow and semantic continuation cues while retaining native scrolling. It does not own rows, columns, filtering, selection, sorting, pagination or business state. Sticky headers and identity cells use opaque semantic surfaces and verified stacking/focus behavior.

Functional edge fades may be used only as overflow cues and must not become decorative gradients.

## 6. Procurement design

The primary decision is exact supplier allocation. While editing, `Lưu phân bổ` is the single dominant action.

Composition: task context → current job tabs → compact workbar → counts/blockers → natural-height allocation table → exact 320px attached detail when selected → calm unused canvas. The table is flexible; the detail is fixed at 320px on desktop and follows the table in document order on narrower widths.

- Search remains immediate. Mobile keeps search visible and moves date, School scope and exception filter into `Bộ lọc` with a truthful closed summary.
- The table keeps all eight columns, approximately 980px minimum width and a sticky Ingredient identity around 178px.
- Exact quantities remain right-aligned and adjacent to Unit.
- Row actions include Ingredient plus School/location context and synchronize `aria-selected` and `aria-expanded`.
- Detail summary order is confirmed need → allocated → remaining.
- Participating suppliers remain distinct from eligible non-participants.
- Add/remove, recommendation disclosure, validation, dirty state, exit guard, permissions and authoritative readback remain unchanged.
- Detail focus entry and exact initiating-action focus return are required.

## 7. Ingredient design

The primary job is locating and maintaining an Ingredient while preserving catalogue density and lifecycle authority.

Composition: task context → existing Ingredient/Supplier tabs → compact workbar → quiet result count → catalogue → exact 320px detail → current review/lifecycle dialogs. Supplier retains its current inner composition.

- Search stays immediate. Status moves under mobile `Bộ lọc` with a visible summary.
- `Tạo nguyên liệu` is dominant only when no detail/review is active.
- All 360 fixture rows remain rendered; no pagination or virtualization is added.
- Catalogue minimum width is approximately 940px; sticky identity is approximately 178px.
- Ingredient name dominates; status is restrained text, not badge clutter.
- Priority suppliers show the first two plus `+N`.
- Row actions remain explicit and unique: `Xem / sửa` or `Xem`, with `aria-expanded`.
- Filtered count reads `<filtered> / <total> nguyên liệu`; an unfiltered successful read shows `<total> nguyên liệu`; read failure is unknown.
- Archived detail looks intentionally read-only rather than broken/disabled.
- Focus enters the detail and returns to the exact row action.

## 8. Planning Sources design

The three jobs remain `Thực đơn`, `Sĩ số`, and `Bổ sung`. The operator completes the selected source for the visible week/date/School scope, reviews the source change and saves once. The outer `PlanningCapability` phase navigation stays before the workbench context.

Composition: task context → source-job tabs → compact week/date/scope/search/refresh workbar → source utility strip → source editor/table → dirty state and `Xem thay đổi` → task-specific review.

Desktop workbar order is week → service date → School scope → search → refresh. On mobile, search and refresh remain immediate and the other controls move beneath `Bộ lọc` with a truthful summary.

- Menu retains Google source/sync utilities, all Dish Type columns and sticky School identity.
- Attendance retains quiet totals, secondary bulk paste and explicit zero distinct from missing/invalid.
- Pantry retains School addition, mode, exact quantity, purpose/note policy, reference, explicit no-additions, derived Unit/location and row errors.
- Menu keeps `max-content`; Attendance targets approximately 620px; Pantry approximately 1200px. Validation/helper rows remain content-height.
- Review is not a 320px inspector. Desktop uses `minmax(330px, .9fr) minmax(440px, 1.1fr)` with one attached separator; at 768px and below it stacks full width beneath the editor.
- Review preserves School/context, Before and Proposed meanings plus backend Pantry before/after pairs.
- `Lưu` is dominant only when current backend/local eligibility allows it. `Chuẩn bị hiệu chỉnh` is dominant only for the current authorized correction case.
- Frozen review disables routine refresh. Focus enters review and returns to the exact trigger.
- No approval/readiness/lifecycle ceremony is added.

## 9. Confirmed Need design

The operator accepts the operational proposal or enters a valid human decision, saves it, and only then continues to Procurement.

Composition: task context → compact context/filter workbar → operation/command feedback → preflight or batch summary → utilities/differences control → seven-function table → persistent action footer → progressive support detail.

When no current batch exists, a compact preflight surface replaces an empty table. `Tạo nhu cầu` or `Cập nhật nhu cầu` is the sole dominant action when eligible. `AtlasOperationStatus` remains outside the 248-row table subtree with immediate duplicate prevention, delayed calm status, elapsed time outside the live region, explicit failed/unknown outcomes and success only after authoritative readback.

The table uses a named local viewport with approximately 1180px minimum width and preserves:

1. Ingredient / recipient-location.
2. Unit.
3. `Nhu cầu tính`.
4. `Đề xuất vận hành`.
5. `Số lượng xác nhận`.
6. `Thay đổi`.
7. `Lý do / ghi chú`.

Theoretical quantity is a quiet backend fact. Proposal is a generated reference and retains `proposal_rounding_step`. Confirmation is the human decision zone and retains `effective_policy.planning_step`. A valid adjustment is neutral/primary, never styled as corrupt merely because it differs. Only invalid input receives danger treatment and associated error text. Exact values, historical precision, existing field labels and `data-confirmed-need-line-id` remain unchanged.

Shopping-list import/export and `Xem cách hình thành nhu cầu` stay tertiary. Dirty valid work makes `Lưu` dominant and continuation unavailable/subordinate. Clean backend-authorized work makes `Tiếp tục phân bổ NCC` dominant. Released/history state has no Save and is explicitly read-only.

The UI-09 review fixture must represent 248 current lines, 248 current decisions, 247 proposal acceptances, one valid operational adjustment and 249 retained historical identities without rendering 249 current rows. It includes long Vietnamese names, decimal kg, Count Unit and historical read-only precision. Retained Staging UUIDs are forbidden.

## 10. Responsive behavior

| Viewport | Required composition                                                                                                                            |
| -------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| 1440×900 | 196px context; broad work surface; exact 320px Procurement/Ingredient detail; Planning comparison at least 440px; Confirmed Need local overflow |
| 1280×800 | Same desktop context; tighter workbars; Planning split minima preserved; no squeezed generic sidebar                                            |
| 768×1024 | 88px context; deliberate filter reflow; review/detail stacked; tables keep local overflow                                                       |
| 390×844  | 88px context; immediate search/refresh/current action; 44px targets; visible continuation cue; complete detail below table                      |

No viewport may introduce document-wide horizontal overflow. Critical fields are not hidden for screenshot fit. Long Vietnamese copy wraps without displacing the primary action.

## 11. Interaction and accessibility

- Exactly one visible H1 per active workbench; attached detail/review uses semantic H2.
- Existing tab semantics and keyboard behavior remain.
- Rows never become hidden navigation controls; explicit buttons remain.
- Preserve `aria-selected`, `aria-expanded`, unique action names, error associations and stable selectors.
- Detail/review focus entry and exact initiating-action focus return are required.
- Status never relies on color alone.
- Mobile actions are at least 44px.
- Long-operation live announcements exclude elapsed-time ticks.
- Reduced motion removes entry/spin/lift transitions without changing layout or state.
- Verification covers keyboard order, 200% zoom, large text and long Vietnamese values.

## 12. State matrix

| State                | Presentation requirement                                                        |
| -------------------- | ------------------------------------------------------------------------------- |
| Loading              | Preserve frame/context; eligibility unknown; commands unavailable               |
| Ready                | Work surface dominates; one current business action                             |
| True empty           | Describe the genuinely empty authoritative scope                                |
| No search match      | Describe the filter/search result without implying missing source data          |
| Read error           | Explicit alert and labelled recovery; no invented count/state                   |
| Permission/read-only | Explain safe business reason when available; intentionally unavailable controls |
| Dirty                | `Đang chỉnh sửa · chưa lưu`; Save/review hierarchy changes                      |
| Invalid              | Exact field association; authoritative actions neutral-disabled                 |
| Saving/busy          | Immediate duplicate prevention; context retained; no fake progress              |
| Success              | Only after authoritative readback                                               |
| Stale                | Explain changed data; require explicit reload                                   |
| Unknown              | Claim neither success nor failure; block mutation; `Tải lại để xác nhận`        |
| Selected             | Clay rail/background plus programmatic selection; focus stays separate          |
| Unselected           | Quiet resting row and explicit action                                           |
| Archived/historical  | Explicit read-only explanation and intact exact value                           |
| Reduced motion       | No cosmetic motion; state and focus unchanged                                   |

## 13. Forbidden changes

UI-09 must not change Supabase, migrations, RLS, privileges, RPC/API/bridge contracts, hooks/controllers/models, quantity/currentness/lifecycle/permission rules, Planning certification scripts, generation, Save, handoff, Procurement release, retained Staging data, Retool, PR #286, `index.html`, `src/main.tsx`, or production cutover. It introduces no framework, grid, virtualizer, state library, date/decimal helper, workflow step or backend evidence API.

## 14. Implementation targets

Expected presentation targets are shared Station components/system tokens; current Procurement table/detail/workbench; Ingredient catalogue/detail/workbench; Planning source stages/review/workbench; and Confirmed Need workbench/table/support/feedback only where presentation requires. Stories, review fixtures and focused tests may change. Hooks, bridges, contracts and `supabase/**` must remain untouched.

## 15. Render and verification matrix

Capture actual production React/Chakra implementation for Procurement, Ingredients, Planning Sources and Confirmed Need at 1440×900, 1280×800, 768×1024 and 390×844. Include selected/unselected; Planning edit/review; Confirmed Need clean/dirty/valid adjustment/post-Save read-only. Every image is labelled with commit SHA, surface, state, viewport and fixture. A compact contact sheet and manifest remain outside Git.

## 16. Acceptance checklist

- Shared context and table viewport remain presentation-only and meet locked geometry.
- Procurement preserves all allocation, supplier, dirty, permission and recovery behavior.
- Ingredients preserve 360-row proof, lifecycle authority, read-only states and exact focus return.
- Planning preserves three jobs, source-specific fields, dirty/correction behavior and wide comparison.
- Confirmed Need preserves seven functions, both rounding steps, exact quantities, selectors, operation status and Save/Continue hierarchy.
- All four responsive widths have no document overflow and retain local continuation cues.
- Loading, empty, no-match, error, read-only, dirty, invalid, busy, success, stale, unknown, selected, unselected, historical/archive and reduced-motion states are covered where applicable.
- Focused tests, typecheck, `ui:vnext:check`, targeted Prettier and `git diff --check` pass.
- Finish review has no BLOCK or MAJOR finding.
- Protected backend, certification and entrypoint paths have zero changes.

## 17. Rollback and remaining risks

Rollback is a frontend/document revert only; no database or hosted-state rollback exists because UI-09 creates none.

Evidence-backed risks requiring render proof are the 1280px Planning comparison, Confirmed Need local overflow beside the 196px context, the intentional long tab sequence across 360 Ingredient row actions, and long Vietnamese values at 200% zoom. No current UI-09 render existed at design approval time.
