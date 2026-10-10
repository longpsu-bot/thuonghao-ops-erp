# Atlas document School grouping 02

This task implements the Owner amendment recorded in `docs/implementation-tasks/TASK-ATLAS-DOCUMENT-SCHOOL-GROUPING-02.md`. Cooking Location and Dispatch membership are separate current Admin facts. Future releases freeze both; historical documents retain their captured evidence.

## Hosted configuration gate

Read-only inspection on 10 October 2026 confirmed Staging `rnzxmxiiqgtdevzregff` still has 97 migrations, ending at `20261010034834`. Its typed `OPS_V1` / `SCHOOL` mapping for legacy ID `10` resolves to School code `v1-school-10`, named `BÌNH QUỚI`. The required ID `52` main School and Hùng Vương IDs `47`, `48`, `49`, `50`, `53` are absent. The current identities are insufficient to configure the Owner relationships safely.

Read-only source inspection of OPS V1 `qnthofvccilhnefdcxnz` confirms ID `52` is `BÌNH QUỚI`, ID `10` is `BÌNH QUỚI - PHÂN HIỆU`, and the five distinct Hùng Vương Schools exist. No source, Staging or Retool data was changed.

Before hosted configuration, reconcile the School master through the existing [controlled master import](master-data-rehearsal-import.md) and its typed mapping/readback. Renaming the stale School alone, resolving by a matching name, inventing UUIDs or omitting absent Schools does not satisfy this gate. Review effects on existing School references and history before applying any reconciliation.

Pass the canonical School readback and typed mapping readback to `buildSchoolDocumentConfiguration()` in `scripts/atlas-document-school-configuration.mjs`. It requires each approved source ID exactly once, a distinct existing target UUID, the canonical code/name and a valid display order. It fails with `SCHOOL_MASTER_RECONCILIATION_REQUIRED` before producing a plan if evidence is missing, duplicated or inconsistent. Names validate a typed identity; they never resolve one.

The builder returns `CONFIGURATION_PLAN_ONLY`; it performs no mutation. Its exact Dispatch memberships are Vĩnh Tân two Schools, Hùng Vương five Schools and Phú Hoà Đông 1 main/PH1/PH2. PH3 is excluded. Cooking assignments are independently proposed for Phạm Văn Cội/Lê Văn Thế, Vĩnh Tân/main branch, and the company kitchen for Hùng Vương Chiều Mặn 2.

After reconciliation and required migration/test gates pass, review that plan and use the authorized Admin commands with current versions/readback. Do not configure hosted data from fixtures. Verify no additional School is included in those Dispatch groups; all other Schools retain separate output.

The ordering plan makes only the Bình Quới pair and five Hùng Vương Schools adjacent in the specified order. Stable sorting preserves canonical readback order for tied existing display orders and all unrelated relative order. It does not change database display-order values. Review available positions before applying targeted updates through the existing School master command. If the existing positions cannot express the approved adjacency without changing unrelated order, stop for an explicit ordering change; do not densely renumber or name-sort the master.

## Release and export behavior

The new migration evolves `atlas_admin.cooking_groups` with explicit `location_kind` and `host_school_id`. Existing unresolved rows remain unresolved; new assignments to them fail until explicitly reconciled. A School host uses its stable UUID; a company location has a null host and the canonical name `Công ty Thượng Hảo`. Dispatch groups and School membership use independent private tables and shaped authorized APIs.

PO School detail retains every School separately. Canonical self-cooking is identified by a `SCHOOL` host UUID equal to the School UUID. Remote School/company locations add the captured `Nấu tại` suffix. Unresolved canonical facts cannot fabricate that suffix. Old group-only releases preserve their historical captured context without guessing a host.

Grouped Dispatch XLSX/ZIP uses only captured Dispatch membership. Within one date/group, it combines exact quantities only for equal Ingredient UUID, Unit UUID and captured PXK document note. Distinct notes, Units, Ingredients and dates remain distinct. The presentation group creates no School or PXK identity. Hidden `DOCUMENT` and `ROW_SOURCE` records retain all original release, release-line, School, date, quantity and upstream lineage identities; singular identity cells on combined rows are blank.

The School width/height method and native evidence are documented in [School row measurement](../testing/atlas-school-row-measurement.md). PO bands use actual visible columns A:F; hidden B contributes zero. `Theo hàng` uses only C. PXK School headers use A:H. All use Times New Roman 14 pt and the exact `28 + 16 × (lines − 1)` formula without a line cap.

## Validation record

On 10 October 2026, focused SQL passed 614 assertions: grouping 41, cooking 33, platform catalog 28, PO 135, PXK 62 and three affected historical catalog fixtures 315. Those fixtures now assert the exact added Dispatch relations, policies and enabled guards. Certification contract tests passed 111 assertions. Document/export/Shopping List verification passed 193 tests across 11 files; a subsequent five-PXK-number regression and focused exporter/packaging rerun passed 33 tests. Focused Admin/API/controller tests also passed. School configuration/order planning passed five Vitest tests, including stale master rejection, exact memberships, targeted adjacency and unrelated tied-order preservation.

Local `pnpm format`, `pnpm typecheck`, `pnpm build`, `pnpm ui:vnext:check` and whitespace checks passed. Native Excel open/save/reopen, printed full text/bounds and actual width/font/height checks passed four workbooks, 25 School rows and three PXK-number headers, including five combined Hùng Vương numbers; committed evidence is in `docs/testing/artifacts/atlas-document-school-grouping-02`. A fresh chronological reset applied all 98 migrations, including the final appended migration, before the local container restart failed. Local security advisor reported no issues. Final independent code review found no remaining actionable defects.

The full local frontend run was stopped after unchanged recipe-screen tests exceeded their original timeouts during database replay. Full local Supabase certification was blocked by `supabase_storage_thuonghao-ops-erp` becoming unhealthy during reset/restart, after migration application. These runs are not recorded as passing. Required exact-head GitHub frontend and full backend results are tracked in [Draft PR #363](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/363); the full backend workflow was explicitly dispatched because Draft PR events run only smoke certification. No thresholds or CI gates were weakened.

Initial CI exposed a Node/Vitest collection mismatch and three stale global catalog fixtures. The configuration tests now use the repository's Vitest runner in both frontend and full backend certification. The corrected runner/contract checks pass 116 tests, and all 315 catalog assertions pass with the explicit new identities retained.

Full Integration also exposed a deterministic browser-fixture collision: an earlier allocation verifier created the synthetic Supplier A without a document code, and the procurement fixture's conflict update refreshed only its status. The backend correctly blocked PO release with `PO_DOCUMENT_CODE_REQUIRED`. The procurement fixture now refreshes its explicit synthetic supplier document code on conflict; the existing readiness, numbering, release and lineage assertions are retained. Fresh local replay applied all 98 migrations, passed the 158 PO boundary SQL assertions, and passed the complete procurement browser verifier through replacement release and immutable history. This correction affects local certification fixtures only.

## Migration and rollback effects

The final pre-merge copy correction names Dispatch Group assignment explicitly in `set_school_dispatch_group` validation and safe-failure messages. Error codes and business semantics are unchanged; Cooking Location assignment messages retain their own terminology. The hosted rollout order is: merge the exact-head-validated grouping PR; reconcile canonical typed School mappings through the controlled master path; then deploy migration 98 and configure the approved independent relationships. Any ambiguous identity blocks hosted mutation with `SCHOOL_MASTER_RECONCILIATION_REQUIRED`.

Focused School Admin verification exposed an asynchronous test race: the Cooking Location editor clears before the workspace-status effect reports its final readback state. The test now awaits the existing final-status assertion through the standard `waitFor`; all asserted values and test timeouts remain unchanged.

`20261010102603_atlas_document_school_grouping_02.sql` is an appended migration; the 97 previously applied migrations are untouched. It adds current relationship authority and canonical snapshot fields for future releases, updates release/read models and guards PO School snapshot immutability. It performs no historical document backfill or hosted master configuration.

Rollback requires a separately reviewed migration and application compatibility plan. Do not drop captured canonical fields, rewrite released JSON or remove referenced relationship identities. Retain the existing compatibility cooking fields and historical read behavior. No automatic down migration, deployment, merge or production write is included in this task.
