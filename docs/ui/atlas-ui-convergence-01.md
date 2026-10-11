# Atlas UI convergence 01

Owner-authorized application-wide presentation task, 10 October 2026.
Starting main: `2f3741f38fe26adc9505ffd773c07c11c70b8c0e`.
Dedicated branch: `fix/atlas-ui-convergence-01`. The original dirty checkout is untouched.
PR #363 merged during this task; its main commit
`40bfda08439e61cbcac82e5416dc3442f75aa951` was integrated before final review and validation.
Main then advanced with PR #365 to `6bf31593276f73aab5ddc9fa27785e8167291024`.
That main commit was integrated before final-head certification. Its School
reconciliation tooling is inherited from main and was not executed by this UI
task. The only UI overlap was Recipe tests; both sets of assertions were retained.

## Authority and scope

ARCH-002 and **FACTS EXPLICIT → STATE DERIVED → SUPPORTING OBJECTS GENERATED**
remain authoritative. **OPERATOR SURFACE MINIMAL** applies to presentation:
backend commands, quantities, eligibility, concurrency and audit remain unchanged.
This task expressly supersedes v3's underline-only workspace treatment with compact,
bounded tabs. It introduces no domain concept, dependency, RPC change or migration.

Confirmed Need has one editable service day; its Monday/week context is derived.
PO and PXK expose 1–7 consecutive calendar days inclusive, including cross-week
ranges through one combined interval control and one range calendar. Contextual
opening defaults to one day. Invalid drafts issue no scope read
and retain the last valid loaded authority and export scope. Allocation stays daily.
Release and replacement stay per individual document.

## Discovery and decisions

| Observed issue                                                                  | Severity | Affected workbenches                  | Decision                                                                         | Outcome / reason                     |
| ------------------------------------------------------------------------------- | -------- | ------------------------------------- | -------------------------------------------------------------------------------- | ------------------------------------ |
| Editable week plus day obscures exact-day operation                             | P0       | Confirmed Need                        | One Atlas day picker, derive week                                                | Implemented                          |
| Document read UI restricts existing range contracts to one day                  | P0       | PO, PXK                               | Shared range picker and local seven-day bound                                    | Implemented                          |
| Empty filtered Attendance reads like confirmed zero                             | P0       | Attendance                            | Distinguish no matches from explicit zero                                        | Implemented                          |
| Workspace active/inactive boundaries and reused icons are weak                  | P1       | All 13                                | Compact bounded tabs; registry owns 13 distinct icons                            | Implemented                          |
| Refresh offsets and unrelated control heights                                   | P1       | All 13                                | Small shared workbar/actions, 40px desktop and 44px narrow targets               | Implemented                          |
| Internal tabs compete with workspace level                                      | P1       | Internal workbench views              | Flat section navigation below bounded workspaces                                 | Implemented                          |
| Raw backend English in source/readiness feedback                                | P1       | Confirmed Need, Pantry, Recipes       | Frontend code-to-Vietnamese mapping; preserve codes                              | Implemented                          |
| Empty source and empty filtered scope conflated                                 | P1       | Menu, Attendance, Pantry              | Concise scope-aware copy near content                                            | Implemented                          |
| Fragmented export utilities and abbreviation-only actions                       | P1       | PO, PXK                               | Coherent secondary utility groups and explicit wording                           | Implemented                          |
| Cancelled keyboard date change leaves the date field ahead of loaded data       | P1       | Confirmed Need                        | Reset cancelled picker draft; restore focus after quick and pointer cancellation | Implemented; red/green regression    |
| Long School name overlaps the PXK date cell                                     | P1       | PXK                                   | Wrap school identity within its existing column                                  | Implemented                          |
| Range endpoints look like independent date fields and lack shared error context | P2       | PO, PXK                               | One labelled interval control and range calendar; one linked workbar error       | Implemented                          |
| Empty/unknown blockers expose implementation text                               | P2       | Confirmed Need, Pantry, Change Orders | Known code translations plus concise Vietnamese fallback                         | Implemented                          |
| School refresh differs from shared grammar                                      | P2       | Schools                               | Apply presentation wrapper after #363 integration                                | Implemented; #363 behavior preserved |

## Workbench coverage

All 13 registry owners were inspected in code and in the populated browser fixture
at desktop and 360px. This is targeted convergence, not a universal form/table rewrite.

| Workbench             | Final presentation and retained behavior                                                                                       |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Schools               | Shared search/type/Refresh baseline; editable attendance and #363 domain behavior preserved                                    |
| Ingredients           | Aligned search/status/Refresh; one primary add action; existing dense data table                                               |
| Suppliers             | Same action grammar; existing contacts, filters and supplier authority                                                         |
| Menu                  | Shared workbar; scope-aware filtered empty message; weekly source behavior retained                                            |
| Attendance            | Shared workbar; no matches distinguished from confirmed zero; pending review preserved                                         |
| Pantry                | Shared workbar; Vietnamese blockers and scope-aware empty message                                                              |
| Confirmed Need        | One editable service day; derived Monday context; dirty-date cancellation and focus preserved                                  |
| Supplier Allocation   | Single-day workbar retained; backend allocation authority unchanged                                                            |
| Purchase Orders       | Inclusive 1–7 day range; supplier identity first; visible service date and explicit Excel/PDF/ZIP labels                       |
| PXK / Dispatch        | Same range control; school identity first; cooking-location context secondary; collapsed history and coherent export utilities |
| Dishes / Recipes      | Shared workbar; readable Vietnamese readiness messages; source/governance ownership unchanged                                  |
| Change Orders         | Aligned date/search/status/Refresh; translated blockers; named local table viewport                                            |
| School Reconciliation | Shared range/search/Refresh baseline; named local table viewport; evidence and quantities unchanged                            |

Workspace tabs have resting boundaries, different active surfaces and accent edges.
Unsaved, attention and blocked markers have different shapes and readable labels.
Internal task tabs remain flat and visually subordinate. Launcher, desktop tabs and
mobile switcher all read icons from the same 13-icon registry.

## Execution and acceptance

- [x] Workspace/launcher/icons and accessibility regression tests.
- [x] Shared workbar and Confirmed Need exact-day/dirty-transition tests.
- [x] PO/PXK range limits, exact existing API parameters, loaded export scope tests.
- [x] Remaining workbench alignment, empty-state and operator-copy tests.
- [x] Browser review across all 13 owners with populated fixtures and narrow state.
- [x] Before/after Owner contact sheet.
- [x] Requested local commands, targeted failure retries, fresh code review and Draft PR #364.

Handoff requires green Frontend CI on the final branch head, visible in
[Draft PR #364's checks](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/364/checks).
The PR stays Draft for Owner product acceptance.

No Staging, Live OPS or Retool writes; no deployment or merge.
PR #363's School/export grouping/domain behavior is integrated from main and is not reimplemented.

## Deferred backend findings

None identified. No approved contract conflict was found. No P0/P1 remains open in
the fresh code review; the two review findings and subsequent range accessibility
finding were fixed and reviewed again.

## Browser evidence and limitations

The [Owner contact sheet](../testing/artifacts/atlas-ui-convergence-01/owner-contact-sheet.jpg)
has 18 views, including workspace/date before-and-after, document range lists,
selected details, export utilities, Master Data, internal navigation and mobile.
The [all-owner sheet](../testing/artifacts/atlas-ui-convergence-01/all-workbenches.jpg)
shows every workbench. See the [evidence index](../testing/artifacts/atlas-ui-convergence-01/README.md)
for full-resolution images and provenance.

No document-level overflow was observed at 360, 650, 1366, 1440 or 1920px.
Tables retain local scrolling. Browser measurements confirmed approximately 40px
desktop and 44px mobile workbar controls with a common bottom edge. The seven-day
cross-week range loaded; an eighth day displayed `Chọn tối đa 7 ngày.` while
retaining the last valid list/export scope and disabling invalid-scope refresh.
The narrow range control displays the entire interval and calendar icon together.

Owner correction, 11 October: PO and PXK now present a single
`dd/mm/yyyy — dd/mm/yyyy` control. It opens one Monday-first range calendar,
highlights the entire selected interval, and commits the scope after the second
date. Keyboard selection and Escape cancellation retain the same scope rules.
PXK dirty-note cancellation restores focus to the combined range control.
The seven-day limit, loaded export scope and backend contracts are unchanged.
The range control fills its labelled field at every reviewed breakpoint; the
single-day calendar recipe remains unchanged. PO/PXK and responsive evidence was
recaptured after this correction, and both contact sheets were regenerated.

The real connected entry was inspected but showed its connection gate: this
isolated checkout has no configured authenticated connection. Operational browser
review therefore uses the actual workbench components with local fixture adapters.
These fixtures never contact hosted services. Hosted connected behavior is not
certified by these screenshots. No login provisioning or Staging writes were used.

## Validation and rollback

Focused tests preceded format, typecheck, tests, build, UI boundary and whitespace
checks. Validation closeout continued on 11 October 2026; results are below.
Rollback reverts this frontend/docs change; there is no migration or data rollback.
Security review: no service-role credentials, privilege/RLS changes, API contract
changes, domain quantity calculations or backend-authoritative outcomes were added.
Changed implementation files are confined to `src/vnext/atlas`; supporting files
are UI documentation and browser evidence. Package and lock files are unchanged.

### Final validation

Local `pnpm format`, `pnpm typecheck`, `pnpm build`, `pnpm ui:vnext:check` and
`git diff --check` passed. The full local `pnpm test --maxWorkers=1` run covered
206 files and 2,754 tests: 2,737 passed and 17 initially failed. That run included
outdated date-surface expectations and five-second timing failures on this
memory-constrained Windows machine. Subsequent focused runs passed every
initially failed case. The final ten-file retry passed 20 cases; its stale Week
assertion and remaining Planning timeout both passed in the final two-case retry.
After integrating PR #365, the overlapping Recipe capability suite passed all
28 tests, retaining the upstream recovery/animation checks and this task's copy check.
No timeout, assertion, accessibility check, test scope or CI setting was weakened.

The Owner's single-control correction passed all 72 focused tests across the
shared range picker, independent workspace owners, PO and PXK suites. Those
checks cover one control with no endpoint spinbuttons, complete-only selection,
Monday-first calendar highlights, cross-month keyboard selection, Escape,
eight-day rejection, loaded export scope, and quick/pointer dirty cancellation
with restored interval, note and focus. Browser checks at 360, 650, 1366, 1440 and
1920px confirmed full field width, 40/44px height and no document overflow.

Date/range hook tests, seven-day boundary tests, retained export scope tests,
workspace/icon and workbar contracts, Vietnamese copy tests and dirty-date
cancellation regressions also passed during development. Quick and pointer
cancellation both retain the unsaved quantity, restore the displayed day and
restore keyboard focus after the replacement date field commits.

GitHub Actions owns complete certification on the final PR head, including frozen
installation, formatting, typecheck, the full test suite, build, UI boundary and
diff checks. Use the linked PR checks for its final-head result; the initial local
run's failures are disclosed separately rather than represented as a green local
full-suite run.
