# Atlas vNext design language v2 — Modern Operational Workspace

**Visual supersession — 6 October 2026:** [Atlas Design Language v3 — Operational Legibility](atlas-design-language-v3.md) supersedes v2's visual color, contrast, typography-legibility and component styling guidance. Workspace/navigation/lifetime architecture remains authoritative where not superseded; v2 also remains historical design evidence. D-048 and business/API/state ownership are unchanged.

**Task:** ATLAS-UI-VNEXT-03B · **Prepared:** 5 October 2026

**Status:** Owner-selected direction D; production contract pending review and merge.

**Owner amendment — 6 October 2026:** ATLAS-PRODUCT-CORRECTIONS-01 updates operator-job granularity and launcher placement below; PR review/merge is pending. Earlier prototype and seven-owner evidence remain historical.

**Decision:** [D-048 — Persistent Workspace](../decisions/decision-atlas-persistent-workspace.md).

**Composition supersession — 8 October 2026 (Draft PR #358):** [D-048](../decisions/decision-atlas-persistent-workspace.md) now defines **13 persistent owners**: separate Thực đơn, Sĩ số and Hàng đặt riêng (formerly Bổ sung), plus the existing jobs. Local-state/guard ownership and business/backend contracts are unchanged. Earlier eleven-owner hosted acceptance remains historical; this amendment claims no hosted rollout.

## Authority and effective scope

[ARCH-002](../architecture/arch-002-atlas-system-map.md), [PA-06A](../architecture/pa-06a-application-connection-contract.md), [model convergence](../decisions/decision-atlas-model-convergence.md), D-035 and D-045 govern this presentation/application contract. **FACTS EXPLICIT — STATE DERIVED — SUPPORTING OBJECTS GENERATED.** Supabase/PostgreSQL owns business facts, persistence, calculations, permissions, currentness, concurrency and commitments. Retool/OPS v1 supplies workflow evidence only.

After this contract is reviewed and merged, v2 supersedes v1's single-active-module shell, rail/drawer navigation, switch-as-exit composition, replacement-page motion and selected presentation geometry. It preserves the existing Chakra v3 foundation, semantic palette, business interaction safeguards and all business/API contracts. It does not retrospectively change the running application. Production adoption belongs to [03C](../implementation-tasks/TASK-ATLAS-UI-VNEXT-03C-PERSISTENT-WORKSPACE-PRODUCTION.md).

Evidence only: draft [PR #349](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/349) at **`e4b968989702540af94f25b996b570de796e489b`**. Its [candidate direction](https://github.com/longpsu-bot/thuonghao-ops-erp/blob/e4b968989702540af94f25b996b570de796e489b/docs/ui/atlas-modern-operational-direction.md), [evaluation](https://github.com/longpsu-bot/thuonghao-ops-erp/blob/e4b968989702540af94f25b996b570de796e489b/docs/ui/atlas-ui-vnext-03a-evaluation.md), prototype, screenshots and tests inform the contract; none constitutes production implementation. Keep #349 draft and unmerged. In particular, its DOM status bridge, sequential destructive sign-out recommendation, provider-per-panel containment and Storybook focus shim are not production contracts.

## 1. Product identity

**ATLAS MODERN OPERATIONAL WORKSPACE = C workspace density + B visual polish + persistent workbench tabs + Atlas business semantics + Chakra UI v3.**

Atlas is operational software for school catering and ingredient distribution. Calm eucalyptus/slate identity, mineral surfaces, precise typography and exact quantities support repeated decisions. The primary table/editor earns the space; brand expression stays in alignment, proportion and restrained details. Preserve the approved Requirement Planning → Purchase Planning → Warehouse Receiving operating baseline. Recipes/change control remain supporting governance; current School PXK is a bounded existing capability, not a newly invented daily stage.

## 2. Application shell

Use a compact slate/eucalyptus utility bar with a far-left Phosphor List icon launcher, followed by Atlas identity and one compact account/environment utility control containing user, environment and sign-out. Do not repeat user/environment in the launcher. The icon trigger keeps `aria-label="Bàn làm việc"` and `title="Bàn làm việc"`; the opened menu displays **Bàn làm việc** as its heading. Below the bar, open-workbench navigation attaches to a full-width active work plane. The current permanent icon rail is not primary v2 navigation; no permanent wide sidebar. Do not repeat the module label, workbench title, scope and counts in multiple shell bands. The workbench's current operator job is the strongest heading. Business dates belong to workbench context; a shell clock must not masquerade as a shared editable service date.

```text
[☰] | ATLAS | ...compact account utility...
------------------------------------------------
[open workbench tabs]
------------------------------------------------
active workbench
```

## 3. Workspace model

```text
STATIC WORKBENCH REGISTRY
        ↓
LOCAL WORKSPACE REDUCER
        ↓
PERSISTENT KEYED WORKBENCH COMPONENTS
```

The authoritative workspace UI facts are only ordered open Workbench IDs and active Workbench ID. IDs are unique; the active ID is open, or absent when none are open. Opening appends a new ID; approved closing removes it. Closing the active tab activates an adjacent remaining tab, with a deterministic fallback; an empty workspace offers the launcher.

One instance per Workbench ID in v2. Persistent means retained while open in the current authenticated application session, not durable restoration after reload. Workbench-local React state owns drafts, quantities, selected Supplier, filters, search, API results, command state, validation, currentness and business status. None belongs in the workspace reducer. Small presentation reports, guard handles and mount seeds do not become a second business-state store.

**Redux = NOT JUSTIFIED. Zustand = NOT JUSTIFIED.** Thirteen workbenches need only this small navigation state machine; persistent mounting preserves local state. No global state dependency or workspace cache.

## 4. Workbench registry

A static definition conceptually provides **id, label, icon, group, render**. These describe identity, recognizable Vietnamese destination, the existing Phosphor icon vocabulary, launcher grouping and composition. Exact TypeScript, optionality and file boundaries belong to implementation review; no speculative fields are frozen here.

A descriptor is a presentation/application object, not a database entity, domain aggregate, persisted lifecycle object, Redux entity or class instance. Reuse current capability boundaries and approved labels. The current thirteen production IDs are `planning` (Thực đơn), `attendance` (Sĩ số), `pantry` (Hàng đặt riêng), `confirmed-need`, `procurement` (Phân bổ NCC), `purchase-orders`, `pxk`, `reconciliation`, `schools`, `ingredients`, `suppliers`, `recipes` and `change-orders`. Each owns a persistent component. Production Planning sources have no secondary source-job tabs; fixed owners reuse the existing source implementations. A prototype capacity descriptor is not permission to invent a module.

## 5. Workbench tabs

| Operator action                       | Required behavior                                                                                                                    |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Open an unopened launcher destination | Mount once, append its tab, activate it.                                                                                             |
| Reopen an already-open destination    | Activate the existing instance; create no duplicate.                                                                                 |
| Switch                                | Change visibility/focus; no exit request, unmount or initialization reload. Preserve local state, date, stage, selection and scroll. |
| Switch with unsaved local work        | Allowed; dirty status remains visible while inactive.                                                                                |
| Close                                 | Actual workbench exit through the owning guard; see section 9.                                                                       |

Tabs belong visually to Atlas. The active tab connects to the work plane through surface continuity, text weight and a geometric selected cue. Avoid browser-chrome imitation. Unsaved markers are subtle but obvious, with accessible text. Use one locally scrolling strip with active-tab reveal, including its close control, and recognizable Vietnamese labels. Overflow must not widen the document or obscure the only route to a tab.

## 6. Navigation / launcher

**Launcher = all available Atlas workbenches. Tab strip = workbenches already open in this session.** Generate the compact launcher from the static Workbench Registry; include simple local label search and exactly these initial meaningful operator categories:

| Group               | Destinations                                                                                                            |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| CÔNG VIỆC HẰNG NGÀY | Thực đơn; Sĩ số; Hàng đặt riêng; Xác nhận nhu cầu; Phân bổ NCC; Đơn mua; Phiếu xuất kho; Đối chiếu PO / Phiếu xuất kho. |
| DỮ LIỆU & CẤU HÌNH  | Trường học; Nguyên liệu; Nhà cung ứng; Công thức; Lệnh điều chỉnh.                                                      |

No empty future groups. Search filters local registry labels, creates no business read/command, and stays out of the workspace reducer. The launcher contains no business drafts/state. It may show only quiet **Đang mở** status; dirty/attention belongs primarily on the corresponding open tab, not duplicated detailed state in the launcher.

Selecting an unopened item opens + activates it; selecting an already-open item activates its existing tab and never duplicates it. Close after successful selection and restore focus to the launcher trigger. Support keyboard entry/search, item traversal, activation, Escape/outside dismissal and visible trigger focus. Empty workspace remains usable. Preserve each independent Planning source/Confirmed Need, Recipe authoring/Change Order, Procurement Allocation/Orders and Ingredient/Supplier owner, along with available reconciliation paths. Grouping communicates existing work, not new domain ownership.

No command-palette dependency, nested navigation framework, favorites, recently used, pinned workbenches or customizable groups until real use demonstrates need. No new router or tab library.

## 7. Workbench mounting

Key each open panel by stable Workbench ID and retain it while open. Neither activation, tab order nor a changed date seed may change its key. Auth subject and API identities remain stable across switches; a genuine identity change still starts a fresh application session and clears the prior user's workspace/recovery context.

Inactive panels are visually hidden, inert, absent from active accessibility landmarks and unable to receive keyboard focus or operator commands. Hide the panel, not its existence. In-flight command/read completion may settle under existing ownership and late-response rules; switching neither cancels a committed intent nor starts a command.

Dismiss nonmodal transient UI on deactivation and contain its portals. Resolve an active modal before hiding its owner: focus traps and document scroll locks must never survive invisibly. This modal rule does not turn ordinary dirty switching into an exit. Retain the existing Atlas provider/system; choose the smallest verified portal-containment solution rather than copying prototype provider nesting.

## 8. Dirty / attention signals

Each workbench explicitly reports presentation metadata to the workspace: clean/ordinary, unsaved local work, and optional attention when unresolved local UI needs disclosure. The owning local dirty calculation supplies this report; the workspace does not duplicate draft comparison or infer status from rendered text, attributes, DOM scraping or MutationObserver.

Reports contain no business draft, quantity, validation payload or authoritative business status. Attention explains its meaning and must not claim an unchanged open form is dirty or an edited form is clean. Exact Recipe metadata reporting is a production gate: create/edit Dish fields, base Recipe edits and change-order jobs must report accurately from each independent owner. Missing or uncertain reporting is not evidence of clean state. Reset/remove presentation reports only after authoritative local resolution or approved unmount.

## 9. Close behavior

Closing invokes the selected owner's existing `AtlasModuleExitHandle.requestExit` boundary. If closing an inactive tab, make its owner visible before its guard can open a dialog. Remove/unmount only after guard approval; cancel/block retains its tab, draft and context. Clean close follows the owner's existing rules. Preserve workbench Save/discard/cancel semantics: Save is the existing local business action; do not manufacture a universal save operation or auto-save before closing.

Busy, frozen Review, stale and unknown-outcome protections remain authoritative. The tab marker cannot override a guard. Restore focus after approved removal and dialog cleanup to the adjacent tab, narrow selector, or empty-workspace launcher. Guarded close/reopen creates a new instance and a new mount seed; switching does neither.

## 10. Sign-out behavior

If **any open workbench reports unsaved local work**, sign-out is blocked and discards nothing. Identify each workbench needing resolution and let the operator activate it, save/discard/close it individually, then try sign-out when none remains dirty. Resolution must include inactive tabs.

Do not compose destructive exits sequentially: an earlier discard must not occur merely because sign-out was attempted and a later owner canceled. No atomic global Save or global Discard is introduced. Preserve existing non-destructive busy/unknown-outcome/session safeguards when no dirty work remains; clean is not proof that an unresolved command is safe to abandon. Browser close/reload retains appropriate `beforeunload` protection for all open owners, including hidden ones. Session expiry and forced identity changes remain governed by Auth/security contracts, not this voluntary sign-out flow.

## 11. Service-date semantics

**Date is workbench-local after mount.** An initial date is a seed, not a continuously controlled global value. A newly opened operational workbench may seed from the current business context; activating an existing one preserves its date and stage. Never silently retarget an existing dirty workbench. Recipes retain their explicit as-of context; reconciliation retains its local date range. Internal scope/job changes keep their existing guards.

Confirmed Need's **Tiếp tục phân bổ NCC** follows this application navigation contract:

| Allocation state      | Handoff behavior                                                                                                                                 |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| Not open              | Open Phân bổ NCC with the exact Need service date.                                                                                               |
| Already open          | Activate Allocation; retain its date, local state and drafts.                                                                                    |
| Retained date differs | Clearly disclose the Need date and retained Allocation date. Keep existing guarded scope controls available; never silently remount or retarget. |

This activation creates no Purchase Handoff, supplier commitment or other business fact. Existing backend commands own those outcomes. A guarded explicit `requestContext(...)` may be considered later only if implementation review proves it necessary; v2 does not require it.

Successful Allocation preparation retains Allocation identity. Its existing command
and Orders proof read remain local; refresh Allocation authority before unlocking it
or opening Orders. Unknown/readback recovery follows the same path without retrying
the write. Orders opens at the exact preparation date only on first mount. If already
open, retain its context and disclose explicit refresh even when dates match, because
its current displayed read predates preparation. Do not add activation reads or share
mutable Procurement drafts between owners.

## 12. Freshness / currentness

**Tab activation is not a refresh event.** Return is immediate and never automatically reloads merely because a panel became visible. Stable seeds and API/Auth inputs must not accidentally trigger initialization effects. Hidden-workbench timers, subscriptions and scope effects require inspection; notably the existing Recipe change-order Vietnam-midnight behavior is outside the four-surface prototype proof.

Existing backend currentness, versions, optimistic concurrency, command/readback, stale locks and explicit refresh protect authority. An in-progress or dirty workbench must never be overwritten by activation-time or hidden-workbench refresh. Unknown outcomes stay uncertain and mutation-locked until governed recovery; tab switching is no recovery proof. Preserve late-response protection and exact intent retry semantics.

Optional clean-workbench freshness UX: a truthful age/currentness hint may offer **Làm mới dữ liệu** without implying a background check occurred. This is separate, local UX, not a required return-time read, global cache, polling or background synchronization system. Frozen Review keeps routine refresh disabled; labeled stale/unknown recovery remains distinct from the routine refresh icon.

## 13. Typography

Retain Inter / Segoe UI / Arial and semantic text styles. Freeze D's compact job heading at 24px/650 on desktop and 22px/650 at narrow widths; section 17px/600, body 14px, table 13px, label 13px/600, helper 12px, button 14px/600. Encode adoption centrally in Atlas styles rather than raw component overrides. The active job heading outranks shell/tab labels; avoid repeated introductions and all-caps microtype. Quantities use tabular numerals and adjacent Units, preserving exact human formatting without meaningless trailing zeroes or precision loss.

## 14. Surface hierarchy

Utility bar → open-workbench navigation → mineral workspace → primary work plane → scope toolbar → table/editor → attached detail → contextual signal. Retain the existing Soft Mineral semantic families in `system.ts`: `bg.*`, `fg.*`, `border.*`, `action.primary.*`, `status.*` and `focus.*`. Eucalyptus owns actions, slate/eucalyptus owns navigation, clay is a sparse geometric brand/selection cue. Status colors retain their own meaning.

Distinguish surfaces through tone, typography, alignment and space before outlines. Active tabs attach to `bg.workbench`; detail uses a subtle attached surface and one separator. Selected/warning rows promote secondary text to the existing readable foreground. No default card-inside-card composition, decorative counters or badge walls.

## 15. Spacing

Retain the 6/10/16/24/32px Atlas spacing vocabulary. Spend space on region separation and input clarity; compact shell bands and small outer gutters preserve full operational width. Use approximately 8–12px desktop work-plane gutters and 10px narrow gutters, not B's wide inset/sidebar. Dense read rows may use 4–6px vertical cell padding; controls remain 40px desktop, compact utilities 36px, and touch targets at least 44×44px on narrow layouts. Do not compress inputs to claim density.

Use bounded table/editor slots that account for live notice/Review/dirty bands and keep primary footers reachable. Do not copy prototype selectors or hard-coded viewport deductions that only fit fixture row counts. Confirm dirty Need Save remains reachable at 1366×768 and selected editors retain usable space.

## 16. Radii

Use a small coordinated family: existing 8px control radius and 6px workbench/detail radius. Tabs use a restrained top-edge treatment that connects to the plane. Routine refresh retains its circular geometry. No arbitrary pill shells, large rounded table cards or per-module radius families.

## 17. Elevation

The work plane and attached detail remain quiet and primarily flat. Surface contrast and separators carry hierarchy. Restrained elevation may distinguish an escaping launcher, dialog or transient notification; reuse sanctioned Atlas treatment. No shadow on every toolbar/editor, glass, glow or decorative lift that reduces table width.

## 18. Filters

Order scope controls date/period → School → search → state/exception → refresh, with DOM/keyboard order matching visual order. Labels remain visible and Vietnamese; authoritative scope/stage locks stay with each workbench. Local filters/sorting do not become workspace facts. Keep compact desktop alignment and prioritized narrow reflow, avoiding unnecessary mobile filter stacks.

Reuse `AtlasDateInput` with Chakra DateInput/DatePicker, Vietnamese `dd/mm/yyyy`, Monday-first calendar and canonical `YYYY-MM-DD` values. Entry and calendar trigger share disabled behavior; selection closes the popup and returns focus. Use the existing Atlas portal scope, viewport bounds and public date API. No new date parser/library or native-date substitution. Reuse `AtlasRefreshButton` and its existing loading/disabled contract.

## 19. Table density

Tables retain most useful width: human identity → context → right-aligned exact quantity + Unit → relevant exception/state → explicit row action. Use quiet headers, hairlines, stable column geometry, semantic selection and local scrolling. Never expose UUID/version/fingerprint columns as routine business work.

Fixed semantic columns and sticky identity/header intersections preserve context under filtering/scrolling. Local sorting is stable, Vietnamese-aware, non-mutating and exact for quantities; editable rows do not move during input. Freeze only enough identity for the viewport; a wide frozen column must not consume a phone's usable width. Named keyboard-scroll regions and contextual row-action labels remain required.

## 20. Master/detail

Geometry follows the job. A true decision master/detail keeps the existing 62/38 target when useful; supplier allocation can use a roughly 380px desktop editor with the remaining width for the master. Recipe authoring uses a compact roughly 300–340px navigator and dominant editor, rather than a forced equal split or catalogue table squeezed beside the form.

Detail anatomy: identity/context → reconciliation or state → editable/document body → reachable action footer. Stack below the width needed for both jobs; selection focuses detail and close returns to its source row. Short editors size to content; long bodies scroll above the footer. School PXK distinguishes proposed release from immutable existing documents. Avoid doubled headers, decorative empty canvases and universal mechanical ratios.

## 21. Business action hierarchy

Use one dominant next business action backed by existing command eligibility. Secondary/tertiary utilities, row actions and destructive consequences use the existing Atlas recipes. Disabled controls are neutral, readable and explain their actual blocker; local presentation may restrict backend permission, never promote a denied command.

- Confirmed Need: retain Shopping List export/import gates, explicit **Lưu**, then **Tiếp tục phân bổ NCC**. Unsaved work makes Save primary and blocks gated continuation/output.
- Procurement: exact saved splits, advisory proposals, **Lưu phân bổ**, separate preparation and independent supplier PO release.
- Recipes: **Xem thay đổi** → frozen Review → **Lưu công thức**; operationally used bases direct changes through **Điều chỉnh**.
- School PXK: local note until explicit **Phát hành phiếu xuất kho**; no new Draft/Save lifecycle or quantity editing.

Exports use existing immutable snapshots and injected production exporters. Tab operations never auto-save, prepare, approve, release, round or redistribute quantities.

## 22. Status / exceptions

Preserve clean, unsaved, invalid, blocked, stale, loading, empty, released and unknown-outcome meanings from shaped results and local interaction rules. Use Vietnamese text plus symbol/structure; color alone is insufficient. Healthy state is quiet, exceptions appear at the affected decision, support/audit evidence stays behind disclosure.

Unknown write completion claims neither success nor failure, remains inline and blocks mutation until **Tải lại để xác nhận** or the existing governed recovery. Toast dismissal, switching, closing a notice and cached reads do not resolve it. Tab attention is presentation disclosure, not a business status or a new lifecycle.

## 23. Responsive / mobile

Do not squeeze the desktop tab strip or permanent rail onto phone width. Keep two separate controls: **Bàn làm việc** opens the registry launcher; **Đang mở** is the compact selector for open workbenches. The latter names the active workbench and unsaved/attention state, exposes all open workbenches, and provides a reachable close action. The compact account/environment utility remains reachable without repeating its content in the launcher. The existing desktop breakpoint (64rem) is the initial switcher boundary; certify content at intermediate widths as well as phone width.

Preserve 44px touch targets, long Vietnamese labels, local table overflow and focused-field reveal. No document-wide horizontal overflow, clipped Save/release footers or mobile card conversion that drops identity/quantity/Unit. Verify 1920×1080, 1440×900, 1366×768, 650×900 and 360×800, including selected/dirty/error states and 12 open tabs.

## 24. Accessibility

Use named tablist/tab/tabpanel relationships, selected state and roving keyboard focus. ArrowLeft/Right and Home/End traverse tabs; activation is immediate because it performs no initialization read. Tab enters the active workbench; contextual close is keyboard reachable and named. A Delete close shortcut, if retained, invokes the same owner guard. Preserve clear focus, readable contrast, labels and row-error association.

Inactive panels and escaping portals must be absent from focus, active landmarks and operator interaction. Nonmodal transient UI is dismissed; a modal is resolved before deactivation. Launcher, guard cancellation, approved close and mobile switching all have visible focus destinations; do not leave focus on a removed tab or let deferred dialog cleanup steal it.

**DATEPICKER_WORKSPACE_GATE — owner clarification, 5 October 2026:** only the active workbench may expose a calendar. Switching dismisses transient date UI; inactive panels cannot receive input or focus. Selection belongs to its owner, activation never changes a date, and no hidden popup/focus trap survives switching or closing. Browser checks must pass with several mounted date controls. NVDA/JAWS, screen-reader journeys, spoken-date verification, live-announcer human certification and WCAG certification are not release requirements for the current operator population. Keep the existing library's semantics; no specialized speech adapter is required. Supabase/business architecture remains unchanged.

## 25. Motion

Tab activation changes visibility immediately. It does not run v1's guarded exit/replacement transition, fade-out delay, initialization entrance or a two-workbench crossfade. The compact shell and tab strip stay stationary; active-tab reveal scrolls locally without disruptive animation. Existing local detail/selection/button feedback may remain restrained.

Retain reduced-motion support, the sanctioned routine-refresh loading/completion feedback and distinct persistent uncertainty states. Read completion is not business success. No row stagger, scale, blur, decorative page entrance or motion blocking focus/reading.

## 26. Anti-patterns

No primary permanent icon rail/wide sidebar, browser-chrome tabs, dashboard/KPI ornament, nested card wall, module-specific design systems, duplicate provider bootstrap, new tab/date/state/command-palette library, nested navigation framework, launcher business state or repeated account/environment details. No global editable drafts, DOM dirty scraping, changing keys to retarget dates, activation refresh, sequential destructive sign-out, global Save/Discard, hidden modal locks, toast-only blockers or copied prototype focus shims/CSS. Never move authoritative business decisions into frontend workspace state or bypass RLS through visibility.

## 27. Extensibility

Design for approximately 10–12 workbenches with local tab-strip overflow, active-tab reveal and recognizable Vietnamese labels. Add a reviewed static definition over an existing bounded capability; preserve one instance per ID. No tab groups, pinning, favorites, recently used, customizable launcher groups, multi-window, durable workspace persistence or multi-instance dates until real use requires them.

Revisit a global store only after a concrete requirement for multiple instances, durable restoration, cross-window synchronization or genuinely shared editable cross-workbench state. A future guarded context request likewise needs demonstrated use. Hypothetical scale is not justification.

## 28. Production rollout

03B freezes documents only: **SUPABASE_CHANGES = 0; RETOOL_CHANGES = 0; BUSINESS_CONTRACT_CHANGES = 0; HOSTED_WRITES = 0.** No deployment, migration or data rollback is required.

03C separates **A. Workspace Foundation** from **B. Visual Adoption**. A retains every current destination and certifies lifecycle, local-date/handoff, status/sign-out, hidden-workbench safety, keyboard/mobile and DatePicker behavior. B first polishes Confirmed Need, Procurement, Recipes and School PXK using this contract. Other workbenches can initially retain their internal composition inside the new shell and converge in later bounded tasks.

Reuse Atlas's custom Chakra system, semantic tokens, recipes, provider, business bridges and import checks; retain strict token typing and generated declarations. Review architecture/product acceptance and exact-head GitHub Frontend CI before merge. Production deployment remains separately authorized. #349 stays draft/unmerged; start implementation from reviewed main and build production wiring independently from its evidence. A future rollback of the workspace returns to reviewed shell composition; it must warn about local unsaved work and never imply durable draft restoration.
