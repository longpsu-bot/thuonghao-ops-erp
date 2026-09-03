# ATLAS-OPS-UI-FREEZE-CLOSEOUT-01

Pinned base: `4fa5968daa00d7abadccdc2ae7ab154c2c0c4bb1`.

This is the last authorized presentation completeness pass, not the freeze gate.
The approved task brief and ARCH-002 govern scope. No backend, API, lifecycle,
calculation, eligibility, allocation persistence, export contract, dependency,
shell, hosted-data, Retool, or other-module changes are authorized.

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

Follow-up finding A2 (blocked by scope): the deployed, current Confirmed Need
renders the Need Generation `Mở xác nhận` button with primary styling alongside
the rail's `Chuyển sang lên đơn` (or dirty `Lưu`). The brief explicitly prohibits
Need Generation changes. Owner: Planning product owner; follow-up: authorize a
bounded presentation-only adjustment to that embedded navigation action. No
generation or lifecycle behavior should change. This prevents freeze readiness.

The existing standalone Confirmed Need Storybook state helper also fails with
`PlanningRailActionPortal requires PlanningRailActionProvider`. It predates this
diff and is outside the specified production areas. Owner: Planning UI test
maintainer; follow-up: restore the story's rail provider/host, then rerun released
and unknown-outcome visual checks. Product checks use the actual workbench.

### Conditional supplier removal

**BLOCKED — explicit persisted Supplier removal requires contract/product
confirmation.** Existing API describes positive complete splits and immutable
successor revisions. The reviewed backend tests prove successor 60/40 and 30/20
saves, but not omission of a previously persisted participant. No new removal
action is implemented. Owner: Procurement contract/product owner; follow-up:
explicitly approve omission semantics and establish a focused backend regression
before authorizing a persisted-participant removal UI.

## Bounded execution and verification

1. Add failing focused tests for D1/B2/D2, primary hierarchy and PO disclosure.
2. Update only AllocationFamilyTable, SupplierSplitPanel,
   SchoolCateringProcurementWorkbench, PurchaseOrderStage, PlanningWorkflowBar,
   their focused tests and scoped rules in styles.css.
3. Browser-check the reproduced defects and required populated states at 1366,
   1920, 900, 650 and 360; inspect console, keyboard/focus and containment.
4. Run combined Planning/Procurement tests, typecheck, touched-file formatting
   and diff whitespace checks. Push and open a Draft PR; leave unmerged.
5. Use GitHub Actions for full validation and the exact-head Cloudflare preview
   for final visual QA. Report uninspected or unavailable checks as blocked.

No migration or data rollback is needed. Reverting the presentation commit
restores the prior UI without changing persisted operational documents.

## Development validation

- Test-first reproduction: five new cases failed for missing presentation/focus
  behavior; the released-state guidance assertion also failed before its fix.
- Combined Planning/Procurement component, model, API, integration and export
  regression: **261 tests passed across 26 files** after the D3 focus fix.
- `pnpm typecheck` and `git diff --check`: passed.
- Local browser: compact allocation and PO masters both fit 629px panes at
  1366 × 768; allocation demand/remainder 120/20 and applied 120/0 inspected;
  selected headings receive focus and Close returns to their invoking actions.
- No authoritative calculations, mutations, payloads, permissions or data-access
  paths changed. Unknown/stale locks and released supplier snapshot exports are
  covered by unchanged regression expectations.
- Final viewport/state matrix, exact-head preview and CI results belong in the
  Draft PR body, so recording those results does not change the inspected head.
