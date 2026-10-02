# TASK-ATLAS-SHOPPING-LIST-XLSX-CONTRACT-01

## Status and scope

**TASK_STATUS: READY_FOR_PRODUCT_REVIEW.** Proposed format frozen for review; Product approval is pending. No connected implementation or merge.

Starting SHA: `d81b60ca63349794d28b0dcc5d34f5fd3e1ebfa1`, exact fetched `origin/main`, PR #345. Branch: `design/atlas-shopping-list-xlsx-contract-01`. Authorized checkout: `E:/Project/OPS ERP/thuonghao-ops-erp`; origin is `https://github.com/longpsu-bot/thuonghao-ops-erp.git`. Incoming branch was clean; the new design branch was created directly from origin/main. `pnpm ops:workspace` passed with the pre-existing advisory old D: path warning; the task-authorized E: Git root/remote were verified. No other checkout was used or edited.

Allowed modules/files: this task record and `docs/xlsx/` contract, schema, synthetic fixture, isolated generator/finalizer/validator and specimen. Prohibited: production Shopping List exporter/parser, connected workbench/controller, app wiring, Supabase/RLS/RPC, migrations, dependencies, Retool/OPS v1, arithmetic, persistence, Procurement, Reconciliation, Dispatch and hosted business data.

## Deliverables and acceptance

- [Canonical proposed contract](../xlsx/atlas-shopping-list-xlsx-v1.md): explicit resolution of 6.1–6.20, Vietnamese operator labels, complete metadata/evidence classification, compatibility, exact quantity/note rules, persistence boundary and acceptance matrix.
- [Machine-readable schema](../xlsx/atlas-shopping-list-xlsx-v1.schema.json): closed per-object shapes, explicit cross-object invariants and physical layout annotations; not a connected parser.
- [Evidence/comparison](../xlsx/atlas-shopping-list-xlsx-v1-evidence.md): current Atlas, named Retool scripts/PurchasePlanner, supplied right-hand layout and every intentional difference; source SHA256 provenance without business payload dumps.
- [Specimen XLSX](../xlsx/examples/atlas-shopping-list-v1-example.xlsx): 80 fully synthetic lines, 2 dates, 3 schools, 13 Ingredient identities, integer/one/six-decimal/zero cases, long labels, notes, alternate-location display and separate ambiguous-label rejection control.
- Isolated deterministic fixture creator, artifact-tool builder, standard-library native-feature finalizer, and static specimen/schema validator. No application import or wiring.

Acceptance for this **design task**: all requested contract questions have explicit proposed rules; specimen matches those rules; source comparison and limitations are honest; required artifacts are committed in a Draft PR; no production change or hosted business write. Product approval is a later checkpoint, not implied by successful fixture validation. The future-import acceptance matrix is a conformance requirement, not a passing production test suite.

## Validation

Required focused checks:

1. Generate and finalize the specimen; independently inspect saved OOXML and normalized JSON Schema, expected date/school/Ingredient coverage, exact decimal cells, protected edit ranges, structured Tables including identities, very-hidden metadata, row/sheet binding, repeat-title/print area/page-break configuration and no formulas/macros/external links.
2. Run static validator negative controls for locked visible-label edits, quantity/evidence corruption, marker/unknown/duplicate line, revision/decision/date/Unit/source/version evidence. These validate the synthetic static specimen, not the future connected importer.
3. Regenerate to a temporary output and compare deterministic final bytes against the committed artifact using the same bundled artifact-tool release.
4. Visually review both date sheets, long text, six-decimal quantities, group boundaries, location suffix and notes. Inspect native Excel behavior if available; distinguish structural/render proof from staff acceptance.
5. Run the existing focused Atlas Shopping List/precision tests to show baseline remains unchanged, format changed Markdown/JSON/JS and check diff whitespace. GitHub Actions owns the full routine frontend suite.
6. Verify changed paths are only the permitted documentation/specimen scope before commit/push/Draft PR.

Results are appended after execution below. No test, validation configuration or CI check is weakened.

### Executed evidence

- Existing `confirmedNeedShoppingList.test.ts` and `confirmedNeedShoppingListPrecision.test.ts`: **30/30 passed** in the focused Vitest run. Production behavior remains unchanged.
- Static specimen/fixture/schema validation: **28/28 negative controls rejected**, including source run/snapshot/period, row deletion/duplication/unknown IDs, stale evidence, visible labels, outside-range data, Table expansion, canonical display ambiguity, external OPC relationship and macro content type. This is an isolated export-fixture verifier, not future connected V1 import acceptance.
- Same bundled artifact-tool release regenerated an independently finalized temporary XLSX with identical SHA256: `05ca567917b04fa2697dc207045131ff39817f561fb869114394133f1626e1f3`. Fixed ZIP timestamps, core timestamps and normalized scoped relationship IDs remove authoring-tool randomness. The specimen is 17,865 bytes.
- Native **Excel 16.0 / Excel 2019** opened all sheets without repair. Both date sheets allowed protected D/E edits, rejected locked A edits, retained full-row technical bindings through full-Table sorting after deliberate unprotect, and filtered 13/40 rows after unprotect. Very-hidden metadata/workbook structure protection remained present. The committed file was never saved by Excel.
- Native unchanged SaveCopyAs and D4/E4 edit + SaveCopyAs to external temporary files preserved every other contractual cell, six-decimal `1.234567`, Table ranges and very-hidden metadata. Excel added only benign `docProps/app.xml` and `docProps/core.xml`, which V1 permits. Other Excel builds can add permitted internal printer settings; staff compatibility review remains necessary.
- Native PDF print export produced **6 A4 landscape pages**, three School groups per date. All six pages were visually inspected: long School/Ingredient names and supplier notes wrap, six-decimal values remain visible, School/location labels repeat, title/help/header repeat, print area excludes identities and footer numbers all pages. Review PDF/PNGs and retained source dumps remain outside Git; the XLSX is the review deliverable.
- Protected filtering limitation: native `AllowFiltering=true`, but COM `Range.AutoFilter` on the protected Table failed. Unprotected filtering passed; protected dropdown interaction remains an explicit staff/Product check. No claim of protected filter certification.
- Independent design review uses the requested GPT-5.6 model family with Extra High reasoning. Findings tightened display ambiguity, coupled-draft conflicts, cross-session limits, decimal locale/large-entry wording, schema semantics, package validation and supplier-note persistence guidance. Product approval remains pending.
- Focused formatting and diff-whitespace checks apply to the new files. GitHub Actions owns the routine full frontend validation after Draft PR creation; no full local suite rerun is needed.

## Security, rollback and review gate

Zero schema/migration/API changes; no migration rollback. Rollback of the review proposal is documentation/fixture-only. Hidden/protected workbook content is not security. Stable backend identity, currentness, authorization and exact transactional Save remain authoritative. The local manifest is ephemeral export evidence, no durable business authority; quantity edits fail closed without the retained manifest; restart recovery is annotation-only. No client service-role credential or hosted connection is introduced.

SUPABASE_WRITES: 0. RETOOL_WRITES: 0. OPS_V1_WRITES: 0. HOSTED_BUSINESS_WRITES: 0. GitHub branch/commit/Draft PR publication is explicitly requested and is the only external publication.

Product must approve the contract and specimen, including repeated School/location display, SỐ LƯỢNG wording, seven-day existing-batch limit, protected sorting/filter dropdown review, closed compatibility and baseline/conflict handling. The user's in-task clarification that staff put supplier names in GHI CHÚ is preserved: proposed notes are free local/workbook annotations, not governed reason notes or supplier allocations. Quantity changes require an explanation entered in Atlas before Lưu. Persisting supplier annotations, changing equal-proposal reason semantics, historical read-only export and a workbook collecting independent daily batches are excluded extensions, not implicit V1 permissions.

**Next gate: Product Owner contract/specimen review. Stop before production implementation. Do not merge.**
