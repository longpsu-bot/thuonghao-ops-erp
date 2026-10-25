# Atlas UI readability review — 25 October 2026

## Scope and evidence

Owner requested a practical UI/UX investigation with more attention to styling,
typography and layout, without an extended redesign. The authorized checkout is
`D:/Project/Repo/OPS/thuonghao-ops-erp`; the bounded branch starts at `c9641522`.
Shiro and the vendored Chakra UI Refactor guidance informed the review. The
official Playwright Interactive skill was installed for reusable browser QA.

Reviewed the shared system, shell, workbar and task context, Planning, Recipe,
master-data and Procurement presentation. Fresh rendered checks concentrate on
Procurement's normal, stale and failed-read states. Existing historical captures
inform composition only. This is not a full application usability or accessibility
certification.

## Findings and decisions

1. **Fixed: PO state competed with subordinate metadata.** Rail state and the
   selected document's state used 13px helper text. They now use the existing
   14px semibold label role; the selected state has its own line. Date and
   document number retain 13px helper typography. Warning states retain their
   established semantic color. No new status, badge or lifecycle is introduced.
2. **Fixed: warning and failure messages lacked consistent structure.** Related
   PO and Allocation guidance now share the existing warning surface, explicit
   icon and 3px edge. Date-range, read and export failures use the existing danger
   anatomy. Message content, range-error IDs, live-region roles and retry
   conditions remain intact. Compact warning text inside the supplier rail is
   retained to avoid expanding every rail item into another panel.
3. **Defer: supplier rail density.** Current cards retain supplier, date, line
   count, state and document number across several rows. Compaction could help
   long seven-day lists, but the present one-document fixture does not establish
   the benefit. Preserve selected C geometry until a populated comparison exists.
4. **Investigate next: long-content layout.** Shared task summaries request
   desktop nowrap, School breakdowns lack consistent column alignment, and PO
   workplanes have nested scrolling. These are source risks requiring long-name,
   multi-School and multi-document reproduction before changing geometry.
5. **Review tooling: verify fonts in the isolated fixture.** Storybook's legacy
   wrapper yielded 13px Nunito Sans table text during this session. The isolated
   Atlas fixture computes the intended Inter/Segoe UI stack and 14px table text.
   A global production font change is not justified by that Storybook result.

Keep the deep eucalyptus shell, neutral working surfaces, existing type scale,
distinct primary action and persistent operator jobs. Do not reopen the approved
C design or the 23 October action-height/layout work.

## Bounded implementation and QA inventory

Allowed source files: `ProcurementOrdersStage.tsx`, `ProcurementWorkbench.tsx`
and the small presentation-only `ProcurementNotice.tsx` in the same module.
Use existing semantic text and feedback roles. No provider, global token,
dependency, hook, command, export calculation, API, permission, domain boundary
or business lifecycle change is in scope.

- Verify PO state at 14px/600 in both rail and header; date remains 13px.
- Inspect normal/stale/error states at desktop and narrow widths, including
  grouped warning copy, icon, edge, wrapping and reachable recovery.
- Measure document overflow at 1366, 1440, 1920, 650 and 360px.
- Exercise Close focus return, search with no results and search restoration,
  launcher Escape focus, plus failed-read retry. These cover recovery and empty
  states as well as the normal path.
- Run focused PO, export, bulk-release and Procurement workbench regressions;
  formatting, TypeScript and the existing vNext boundary scan. Let normal GitHub
  Actions own full frontend validation.
- Obtain an independent rendered/source finish review before publication.

## Verification

Localhost preview requests stalled, so a Vite bundle of the existing opt-in review
entry was written outside the repository and loaded through a local file URL in
Chromium. It uses fixture APIs only, with no hosted reads or writes. The bundle
build passes; its fixture-only chunk-size warning does not certify the production
entry. The six captures in [the evidence directory](evidence/atlas-ui-readability-20261025)
record the original desktop PO and updated normal, stale and error surfaces.

Browser measurements confirm 14px/600 PO state text, 14px error copy, 3px error
edge, 44px narrow retry target and zero document horizontal overflow at all five
widths. Close returns focus to its PO rail trigger; launcher Escape returns focus
to Chức năng. Search-empty and restoration work, and failed-read retry preserves
the explicit error and recovery control. The independent visual/source review
reports no actionable blockers and unchanged backend/action/security contracts.

Focused automated checks and GitHub CI results are recorded with the PR. The
initial local test command also collected stale `.worktrees` copies; the corrected
focused command excludes those unrelated checkouts. No test assertion or CI
configuration is weakened.

## Security, rollback and limits

No migration or data rollback is needed. Revert the three presentation files to
restore previous styling. API calls, quantities, authorization, released document
snapshots and recovery callbacks are unchanged. No deployment is claimed.
Long-content rail/scroll changes and Storybook isolation remain follow-up work;
neither is a blocker introduced by this bounded presentation pass.
