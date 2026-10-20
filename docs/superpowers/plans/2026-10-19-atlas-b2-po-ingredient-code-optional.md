# B2 optional Ingredient code implementation plan

> Execute inline in the isolated B2 worktree, with one independent read-only
> branch review after implementation. The explicit user brief authorizes execution.

**Goal:** Release and export valid POs without a manual Ingredient code.

**Architecture:** Amend existing backend authority and retain official historical
rendering. Remove the preliminary summary's visible code column. Add no authority,
dependency, lifecycle, table or hosted mutation.

**Tech Stack:** PostgreSQL/Supabase, React/TypeScript, ExcelJS, pdfmake, Vitest, pgTAP.

**Spec:** [Contract delta](../../implementation-tasks/TASK-ATLAS-B2-PO-INGREDIENT-CODE-OPTIONAL-01.md).

## Execution

- [x] Verify exact base and independent worktree; preserve original local edits.
- [x] Inspect authority, current functions/owners, exporters and historical layouts.
- [x] Add focused tests: null-code release/readback/replacement, Supplier rejection,
      descriptive evidence, native Ingredient Create/Edit, all exports and old rendering.
      Run them against the baseline and retain the expected failures.
- [x] Generate a new migration using the pinned Supabase CLI; amend only the three
      named function bodies with guarded anchors, retaining every other guard/privilege.
      Run the changed SQL tests in an isolated local database, including replay checks.
- [x] Make nullable export/review changes and remove the preliminary summary code
      column, retaining historical hidden facts. Run the affected frontend tests.
- [x] Update the PO/master-data contracts and bounded baton; record changed files,
      migration/rollback and actual evidence. Review the complete branch independently.
- [ ] Commit/push one coherent B2 branch and create one Draft targeting the frozen
      stack base. Dispatch existing exact-head Frontend and Supabase workflows once.
- [ ] Inspect all three required job results, including actual Full Integration
      execution. Report PASS/FAIL/BLOCKED and stop for Product Owner review.
