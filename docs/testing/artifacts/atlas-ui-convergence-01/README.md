# Atlas UI convergence browser evidence

10 October 2026; `fix/atlas-ui-convergence-01`; reviewed against integrated main
`40bfda08439e61cbcac82e5416dc3442f75aa951` after PR #363 merged.

[Owner contact sheet — 18 views](owner-contact-sheet.jpg) includes the required
launcher, 4+ workspaces, clean day workbar and populated Need, seven-day PO/PXK,
selected PO, PXK export utilities, two Master Data toolbars, internal tabs and
mobile views. [All 13 workbenches](all-workbenches.jpg) provides coverage context.

## Provenance

Screenshots were captured through the Codex in-app browser from the actual Atlas
workbench components at `atlas-vnext-review.html?scenario=range`. The review entry
uses in-memory fixture API adapters, including realistic seven-day document lists
with draft/released states and stable date-specific identities. It is separate from
the production connected entry. No hosted read/write or Staging/Live OPS mutation
was performed by these fixtures. Export utility handlers are local fixture stubs;
export command/snapshot behavior is covered by automated tests.

Most desktop views use a 1440×900 viewport; narrow views use 360×900. Device scaling
can produce a one-pixel difference in recorded screenshot dimensions. Table
viewports scroll locally without widening the document. Additional range samples
use 650, 1366 and 1920px; audit JSON records observed DOM geometry.

The workspace-before comparison uses the repository's previously saved
`docs/testing/ux/atlas-tab-borders/planning-1440x900.png` baseline; it is explicitly
labelled archival rather than newly captured. `confirmed-need-before.jpg` was
captured before replacing its editable week/day controls; its surrounding shell
already includes the new workspace treatment. The contact-sheet date comparisons
crop only that workbar region. School desktop/mobile and final PXK/invalid-range
views were recaptured after #363 integration and review fixes.

## Full-resolution views

| Area                         | Evidence                                                                                                                                                                                |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Launcher and workspace strip | [Launcher](launcher-after.jpg), [13 open tabs](workspace-tabs.jpg)                                                                                                                      |
| Confirmed Need comparison    | [Before date surface](confirmed-need-before.jpg), [After / populated](confirmed-need-after.jpg)                                                                                         |
| Need states                  | [Blocked](need-blocked.jpg), [Narrow](narrow-need.jpg)                                                                                                                                  |
| Purchase Orders              | [Seven-day list](po-seven-days.jpg), [Detail](po-detail.jpg), [Invalid eighth day](po-invalid-range.jpg), [Empty](po-empty.jpg)                                                         |
| PXK / Dispatch               | [Seven-day list / utilities](pxk-seven-days.jpg), [Detail / collapsed-history context](pxk-detail.jpg), [Narrow](narrow-pxk.jpg)                                                        |
| Master Data                  | [Schools](schools.jpg), [Ingredients](ingredients.jpg), [Suppliers](suppliers.jpg)                                                                                                      |
| Planning sources             | [Menu](menu.jpg), [Attendance](attendance.jpg), [Pantry](pantry.jpg)                                                                                                                    |
| Other owners                 | [Allocation](allocation.jpg), [Recipes](recipes.jpg), [Changes](changes.jpg), [Reconciliation](reconciliation.jpg)                                                                      |
| Internal navigation          | [Flat task tabs in isolated combined procurement fixture](internal-tabs.jpg)                                                                                                            |
| Responsive samples           | [Narrow range](narrow-range.jpg), [Narrow Ingredients](narrow-ingredients.jpg), [Narrow Schools](narrow-schools.jpg), [650px](po-650.jpg), [1366px](po-1366.jpg), [1920px](po-1920.jpg) |
| Connected entry limitation   | [Connection gate](connected-entry.jpg) — no configured authenticated connection in this isolated checkout                                                                               |
| Geometry observations        | [Desktop](desktop-audit.json), [Narrow](narrow-audit.json), [Additional widths](widths-audit.json)                                                                                      |

These images support presentation review. They do not assert production data
accuracy, hosted integration acceptance or rendered export-document QA.
