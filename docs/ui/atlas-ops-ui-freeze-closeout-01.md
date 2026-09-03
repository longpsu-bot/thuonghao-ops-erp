# ATLAS-OPS-UI-FREEZE-CLOSEOUT-01

Pinned base: `4fa5968daa00d7abadccdc2ae7ab154c2c0c4bb1`.

This is the last authorized presentation completeness pass, not the freeze gate.
The approved task brief and ARCH-002 govern scope. No backend, API, lifecycle,
calculation, eligibility, allocation persistence, export contract, dependency,
shell, Retool, or other-module changes are authorized. The user subsequently
authorized a narrow embedded Need Generation presentation correction and the
Confirmed Need review-fixture repair below. Separately authorized staging
inspection released one synthetic Confirmed Need; its pending Handoff and
supported-command recovery belong to the separate task recorded below.

## Audit before implementation

Inspected the current React product using its populated, session-only review
adapters at the pinned baseline. These use the same workbenches as connected
mode. They do not certify hosted data or backend transactions.

| ID    | Class                  | Reproduced finding / decision                                                                                                                                                                                                                                                                                            |
| ----- | ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| E1    | Responsive/workspace   | At 1366 × 768 an open allocation detail leaves a 1080px table in a 629px master; at 1920 the master is 929px and still scrolls. PO similarly leaves 930px in 629px. Row actions and state disappear to the right. Compact only the open-detail master on side-by-side layouts; retain the complete closed/stacked table. |
| A1    | Definite completeness  | Bulk recommendation and active-family Save both use primary styling. Keep bulk confirmation secondary, with unchanged candidates and command.                                                                                                                                                                            |
| B1    | Visual inconsistency   | Allocation demand/assigned/remainder render as equally weighted inline text despite an existing label/value total primitive. Use small labels, tabular values, and explicit balanced/attention/invalid remainder presentation.                                                                                           |
| C1    | Operator comprehension | Clean and released PO detail shows version and server-number explanation in a normal-visible block before lifecycle actions. Move support context into collapsed `Nguồn & lịch sử`; retain the official number and warnings in business content.                                                                         |
| C2    | Operator comprehension | The released-PO scenario renders the known `PO_ALREADY_RELEASED` terminal-state explanation as a red error. Present that exact reason as neutral guidance only for a released PO; retain every other blocker.                                                                                                            |
| D1    | Accessibility/focus    | Allocation and PO row actions leave focus on the master when detail opens; closing does not restore it. Selected rows use only a pale background. Focus the detail heading, restore the invoking row action on Close, and expose expanded state plus a non-color selection cue.                                          |
| B2/D2 | Visual density / focus | Planning rail renders a second status line even for healthy/neutral states at 1366 and 1920. The selected tab suppresses its focus outline. Quiet healthy states while preserving accessible status descriptions, visible warning text and keyboard focus.                                                               |
| F1    | Reviewed, unchanged    | Closed masters already fill the available workspace. Stacked master/detail at 900 is appropriate. Keep global scanning-table minimum widths.                                                                                                                                                                             |
| F2    | Reviewed, unchanged    | Exception select fits the workbar. No demonstrated material improvement justifies replacing it with four counted controls. Reads/filter semantics remain unchanged.                                                                                                                                                      |
| F3    | Reviewed, unchanged    | Planning menu and Attendance have attached reviews and one rail action. Pantry retains explicit weekly zero confirmation. Need generation remains embedded; Confirmed Need dirty/save/clean actions remain in place. No layout redesign.                                                                                 |
| F4    | Reviewed, unchanged    | Recommendation/rebalance remain visibly advisory. Supplier ineligibility requires explicit replacement. Clean/stale/released PO lifecycle and released-only XLSX/PDF remain governed by existing actions.                                                                                                                |
| F5    | Reviewed, unchanged    | `Quay lại` returns from Planning review to editing; `Đóng` dismisses Procurement detail. The different labels describe different tasks.                                                                                                                                                                                  |

Follow-up browser finding D3: opening the deployed Menu review with no changes
leaves focus on the page body; populated local Attendance keeps focus on Save,
and Pantry also loses focus. The attached review now receives focus on open;
`Quay lại` restores its current rail action. Three regression tests failed first.
This changes only focus and accessible review targeting, not review/save data.

Follow-up finding A2 (**PR blocker B2, resolved**): the deployed, current
Confirmed Need rendered `Mở xác nhận` with primary styling alongside the rail's
`Chuyển sang lên đơn` (or dirty `Lưu`), even when that same batch was open.
The user explicitly authorized this narrow exception to the original Need
Generation boundary. The embedded action is now secondary navigation; matching
the visible batch ID and service date replaces it with quiet `Đang mở` text.
The date selector, generation commands, callbacks and lifecycle stay unchanged.
Three focused assertions failed before correction, including the parent
workbench's independent Monday/Wednesday batch navigation.

**PR blocker B3, resolved:** the standalone Confirmed Need helper threw
`PlanningRailActionPortal requires PlanningRailActionProvider`. The authorized
fixture repair adds the existing provider/host and fixes the unknown-save play
helper, which incorrectly waited for a successful save. Released, unknown-save,
refresh-required after unknown release, and handoff-pending stories now exercise
the real review component with session-only adapters. Play assertions verify
commitment locks and explicit recovery text. The handoff fixture is simulated
review evidence; it does not certify or repair the staging B1 failure.

### Conditional supplier removal

**Deferred Product/Contract clarification — non-blocking for Planning + Procurement freeze.**
Existing API describes positive complete splits and immutable
successor revisions. The reviewed backend tests prove successor 60/40 and 30/20
saves, but not omission of a previously persisted participant. No new removal
action is implemented. Owner: Procurement contract/product owner; follow-up:
establish a concrete MVP operator case that cannot be completed safely without
removal, then approve omission semantics and a focused backend regression before
authorizing a persisted-participant removal UI. This is PR item B4, an enhancement
until that operator case is established; it must not hold the freeze.

### Separate integration blocker B1

The released staging synthetic Confirmed Need for **31/08/2026**, **Atlas Staging
Synthetic School / Kitchen**, **Gà rehearsal Atlas**, **11 kg**, received:
`The school-catering Purchase Handoff request is invalid.` No allocation or PO
was created, and no direct SQL repair or retry was performed in this UI task.

After #249 is reviewed and merged, the separate bounded task
**PLANNING-PROCUREMENT-HANDOFF-RECOVERY-01** must reproduce that released need,
inspect Atlas's exact Handoff request against the deployed authoritative
contract, add a failing regression, and fix only the actual defect. Recover
through supported commands, prove idempotency without duplicate Handoff,
verify the expected Allocation Family, and continue Allocation → DRAFT PO on
staging. Make the operator-facing message natural Vietnamese if the same failure
can legitimately recur. No direct SQL repair. This task is not started here.

The sequence is #249 review/merge → HANDOFF-RECOVERY-01 →
PLANNING-PROCUREMENT-FREEZE-01 → frozen Planning/Procurement → Warehouse.
PR #249 stays Draft/unmerged pending review. No further visual-polish round is
planned; B1 is the remaining integration blocker, B4 is non-blocking.

## Final routine-refresh consistency correction (B5)

The user explicitly authorized this final shared presentation correction to
PR #249. Rendered pre-change evidence at 1366 × 768: Planning had a 32 × 32
icon with `aria-label="Làm mới"`; Procurement had an approximately 85 × 41 text
button with no tooltip. Both routine workbars now use `RefreshButton` in
`WorkbenchComponents.tsx`: the existing Phosphor `ArrowClockwise`, a 36 × 36
circle, shared secondary outline/hover/focus/disabled styling, and
`aria-label="Làm mới dữ liệu"` plus `title="Làm mới dữ liệu"`.

Handlers and existing disabled conditions remain unchanged. No recovery
control is converted: `Tải lại dữ liệu`, `Tải lại dữ liệu hiện tại`,
`Thử tải lại`, `Thử lại bàn giao`, and other safety/retry actions keep text.
No Admin, Warehouse or Dispatch adoption is included. One shared accessibility
test is added; existing Planning/Procurement refresh and recovery tests verify
the updated routine label, retained recovery text and authoritative readback.
Final slice checks and preview evidence are recorded in the Draft PR body.

## Bounded execution and verification

1. Add failing focused tests for D1/B2/D2, primary hierarchy and PO disclosure.
2. Update the reproduced Planning/Procurement presentation findings, their
   focused tests and scoped rules in styles.css. The final authorized slice
   includes shared RefreshButton, embedded Need Generation navigation and the
   standalone Confirmed Need stories.
3. Browser-check the reproduced defects and required populated states at 1366,
   1920, 900, 650 and 360; inspect console, keyboard/focus and containment.
4. Run combined Planning/Procurement tests, typecheck, touched-file formatting
   and diff whitespace checks. Push and open a Draft PR; leave unmerged.
5. Use GitHub Actions for full validation and the exact-head Cloudflare preview
   for final visual QA. Report uninspected or unavailable checks as blocked.

No migration is needed. Reverting the UI commits restores prior presentation;
it does not undo the separately authorized synthetic staging release.

## Development validation

- Test-first reproduction: five new cases failed for missing presentation/focus
  behavior; the released-state guidance assertion also failed before its fix.
- Combined Planning/Procurement component, model, API, integration, export and
  shared presentation regression: **267 tests passed across 27 files** after
  the final B2/B3/routine-refresh corrections. The four Confirmed Need recovery
  stories also report **Pass** in Storybook's Interactions panel.
- `pnpm typecheck` and `git diff --check`: passed.
- Local browser: compact allocation and PO masters both fit 629px panes at
  1366 × 768; allocation demand/remainder 120/20 and applied 120/0 inspected;
  selected headings receive focus and Close returns to their invoking actions.
- No authoritative calculations, mutations, payloads, permissions or data-access
  paths changed. Unknown/stale locks and released supplier snapshot exports are
  covered by unchanged regression expectations.
- Final viewport/state matrix, exact-head preview and CI results belong in the
  Draft PR body, so recording those results does not change the inspected head.
