# TASK-ATLAS-UI-VISUAL-POLISH-MENU-SYNC

## Authority and boundary

This task starts from `origin/main` at
`202cd9c7eae7a41cd1fccb263f5ad22f7afbb7cf` on
`feat/atlas-ui-visual-polish-menu-sync`. The approved scope is the connected
Chakra Atlas visual finish and the normal Weekly Menu Google synchronization
journey. Google Sheet remains the sole normal Menu authoring authority. Atlas
owns canonical validation, consequential persistence, immutable snapshots,
audit, currentness and downstream consumption. The task retains the three-stage
operating baseline and **FACTS EXPLICIT → STATE DERIVED → SUPPORTING OBJECTS
GENERATED**.

No database schema, migration, RPC, Edge Function, RLS, capability, business
status, calculation, Procurement command, production data or hosted Staging
business fact changes are authorized. Retool and OPS v1 are evidence only.

## Weekly Menu operator contract

The previous connected path was:

```text
Google Sheet → Đồng bộ Google Sheet → browser-local candidate
→ Xem thay đổi → Preview + correction-impact read → Lưu
→ save_weekly_menu → authoritative readback
```

The current approved normal path is:

```text
Google Sheet → Đồng bộ Google Sheet → governed fetch → parseMenuMatrix
→ preview_weekly_menu_import → require can_save
→ atlas_api.save_weekly_menu → authoritative readback → refreshed table
```

The backend Preview remains a deterministic canonical validation step, not an
operator decision. The payload must include the complete canonical week even
when table search, School or date filters narrow the visible projection. The
existing v2 command envelope supplies expected aggregate version, source and
expected source signatures, authenticated subject, command and correlation IDs,
and idempotency. The browser does not use raw table writes or a draft →
validate → approve command chain.

`NO_CHANGE` remains the backend's no-write idempotent outcome. The UI derives
assignment-level ADDED, REPLACED and REMOVED counts only for presentation, by
comparing the persisted canonical Menu with the incoming canonical candidate.
After successful Save and authoritative readback, additions and unchanged
assignments update quiet inline sync status; replacements/removals generate one
non-blocking Atlas-scoped notification. A failed, blocked, stale or uncertain
Save cannot emit a success notification.

The existing consequential Save rechecks downstream correction safety under
locks. Only its exceptional correction blocker causes the UI to request
`get_planning_source_correction_impact` for actionable dates and any permitted
`Chuẩn bị hiệu chỉnh` action. It does not regenerate Need, reopen Confirmed Need
or mutate Purchase Handoff implicitly. A transport-uncertain Save is never
blindly retried; authoritative readback determines the current persisted state.
Attendance and Pantry retain their own Review/Save workflows.

## Visual composition

The 72px rail, mobile drawer, navigation, portal tooltips, Soft Mineral identity
and #339 table interactions remain intact. The connected shell gives the active
module first visual priority, with date/environment/user as utilities; the
workbench names the current job. Workspace, primary work surface and inset
toolbar/detail surfaces have clearer tonal separation. A shared Chakra table
treatment owns subtle vertical cell dividers and stronger major boundaries
without changing fixed column geometry, sticky intersections or local scrolling.
The Menu sync status and exceptional correction signal remain attached to the
workbench. Notification content is announced politely, does not steal focus,
and dismisses automatically with reduced-motion support.

## Supplier line-note audit: separate follow-up

The current Procurement model has `reason_note` on
`atlas_procurement.fulfilment_allocation_revisions` and
`atlas_procurement.purchase_order_revisions`; those notes explain revisions.
Neither `fulfilment_allocation_line_revisions` nor
`purchase_order_line_revisions` has a supplier-facing instruction field. A
client-only field, revision reason note, or unrelated JSON snapshot would not
create a dependable supplier instruction.

Product should separately approve a supplier-specific Ingredient/order-line
instruction at the supplier allocation-line revision grain, copied immutably
into the PO-line revision snapshot and carried through printed/exported/sent
supplier documents. That task must define edit/correction timing, traceability,
validation, contract fields, persistence, tests and rollout. This PR does not
implement it.

## Verification and handoff

Focused Menu interaction tests, #339 table tests, Storybook browser captures at
1440×900, 1280×800, 768×1024 and 390×844, and before/after contact sheets are
the review evidence under
[`docs/testing/artifacts/atlas-ui-visual-polish-menu-sync/`](../testing/artifacts/atlas-ui-visual-polish-menu-sync/README.md).
That artifact index also records the local Storybook focus-instrumentation
console caveat. The requested local gates are `pnpm ui:vnext:check`,
`pnpm typecheck`, targeted Prettier, `git diff --check` and
`pnpm ops:workspace`. GitHub's Frontend CI is the full validation authority
after the Draft PR is pushed. Product and architecture review are required
before merge.

No migration or hosted business-data write is part of implementation; rollback
is reverting the frontend and documentation commit. Existing persisted Menu
facts and immutable history remain untouched by rollback.
