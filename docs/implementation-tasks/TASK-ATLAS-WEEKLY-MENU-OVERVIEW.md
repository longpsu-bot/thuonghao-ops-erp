# Weekly Menu whole-week review

Owner feedback identifies inactive Schools in Weekly Menu and the inconvenience
of reviewing only one date at a time. The approved layout keeps the current
Dish Type columns and represents each School/service date as one row, with
sorting by School or date. Google Sheets remains the authoring source.

The bounded change covers the vNext Planning source controller, Weekly Menu
table, workbar context, focused tests and a multi-date Storybook fixture.
Only ACTIVE Schools enter the Weekly Menu table and School picker. Refresh
removes inactive identities from the local selection using the existing scope
normalizer. Full source catalogues, saved lines and diagnostics remain intact.
Other Planning jobs retain their existing historical display behavior.

Rows represent actual source School/date pairs in the selected week, including
located rejected source cells. No empty operational rows are fabricated.
The table keeps canonical School/date ordering by default, accessible ascending
and descending sort controls, existing Dish Type order, exact per-cell source
errors and local scrolling. The Weekly Menu context shows the full week and
does not offer a one-day selector. Attendance keeps its service-date filter.

Acceptance covers inactive School removal from both table and picker, stale
selection reconciliation, multi-date/weekend visibility, sorting, empty/source
error states and unchanged complete Google Sheet sync payloads. Focused tests
and rendered desktop/mobile review verify behavior. GitHub owns full validation.
No schema, API, privilege, calculation, source data or operational writes are
introduced. Recovery reverts the view change without altering persisted data.
