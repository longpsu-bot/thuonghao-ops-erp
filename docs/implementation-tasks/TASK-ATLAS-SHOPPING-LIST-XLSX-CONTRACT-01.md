# TASK-ATLAS-SHOPPING-LIST-XLSX-CONTRACT-01

**TASK_STATUS: READY_FOR_PRODUCT_REVIEW.** Same Draft PR #347, branch `design/atlas-shopping-list-xlsx-contract-01`; no merge. This calibration starts at `8567299f7c0227eafbea4b7b3ded40a014e631ce` and supersedes the preceding PRINT_GEOMETRY_BLOCKED status. Canonical checkout `D:/Project/Repo/OPS/thuonghao-ops-erp` was authorized and verified (root, remote, fetch, branch, clean starting status and workspace guard). Print proposal passed native QA; Product approval is pending.

## Settled business boundary

FACTS EXPLICIT → STATE DERIVED → SUPPORTING OBJECTS GENERATED. One generated workbook collects 1–7 service dates, each with its own daily Confirmed Need batch and worksheet. No weekly aggregate, persisted lifecycle or cross-date transaction. Export saved/current facts only; unsaved local draft blocks Export until `Lưu` or discard/reload.

Import after browser restart uses no manifest. Load every daily batch fresh; verify stable row, revision/decision, source/currentness and exact row set; compare quantity; publish local quantity proposals only after whole-workbook validation. A stale/wrong date rejects all draft changes. Only SỐ LƯỢNG imports. Governed reasons remain Atlas requirements before explicit `Lưu`, the sole write. GHI CHÚ is derived Supplier advice plus working paper, ignored and never persisted on import; Supplier drift alone does not stale quantity. Supplier allocation belongs to Procurement.

One location displays School only; multiple display School plus subordinate `Điểm giao: <canonical label>`. Hidden Location stays row-bound; ambiguous canonical labels block export. Protected filtering is BEST_EFFORT, independent of identity safety.

## QA fixture recalibration and print proposal

User-provided read-only design snapshot: 248 rows, combined P95 58, P99 65.53, maximum 67. No Staging/hosted read was performed here. Guard `ceil(67 × 1.25) = 84` is a fixture QA envelope, not a business/DB length constraint. Independent stress limits School 32, Location 32, Ingredient 48, Supplier 25, quantity 12; realistic composite 79. No normal artificial all-maxima row. All 59 lines on three dates/batches remain, with stable source/revision/decision IDs and exact precision cases. Four synthetic Schools, 29 Ingredients and 11 Supplier masters isolate the fields. Nonprinted `OUT_OF_CERTIFIED_PRINT_ENVELOPE` retains the 68-character Ingredient/~45-character Supplier concepts and is recognized as outside certification.

Exact G1/G2/G3 reruns at native 100%/95% failed seven quantity hashes and clipped wrapped labels. G1/G3 also split horizontally at 100%. Only after those tests was D expanded to 19. Selected **G3-Q widths 20/33/7/19/14**, typography title/header/body/School/Supplier **20/18/18/18/16 pt**, row classes **27/72/168 pt** (hard cap 168, only three), header 48, title/gap 32/5, explicit scale 95%, margins 0.20/0.20/0.25/0.25 inch. This proposal replaces the historical 44 pt cap under the latest task's bounded-class requirement; Product has not yet approved it. No arbitrary per-string height or auto-fit is used.

Final native Excel 16 read-only export passed: four A4 portrait pages, **22/22/12/3** body rows, normal body **17.16 pt**, Supplier **15.24 pt**, measured scale **95.33%**, all visible A:E content and all 59 exact quantities, no hashes/horizontal split, repeating titles/headings and hidden evidence excluded. All four rendered pages reviewed at 100 dpi. XLSX SHA-256 `c76fa81af48f0f7b5bbbef50e3f338857eb75055ff74ec0f662a1ea23b4f34f3`. [Evidence](../xlsx/atlas-shopping-list-xlsx-v1-evidence.md#calibrated-envelope-review-from-8567299) records the metric definitions, candidates, bounded-class rationale and physical checks.

Future connected exporter must detect overflow, including actual glyph/cell overflow inside a nominal character envelope, and use approved handling or clear warning/block. Never silently clip, accept hashes, drop below the print-size floor or add a database length rule. Actual data pagination, overflow handling and cross-version certification remain implementation acceptance work.

## Validation and change scope

Contract/schema/evidence/task, synthetic fixture builder/JSON, specimen generator/finalizer, static validator, native PDF validator and XLSX only. Production `confirmedNeedShoppingList.ts` and `ConfirmedNeedWorkbench.tsx` are untouched. Existing identity, currentness and precision coverage is retained. Specimen validator passes 41 prior negative controls plus seven new envelope controls; native validator verifies actual PDF content/size independently. Fresh validation passed: focused Shopping List/precision Vitest suites (two authorized checkout files, 30 tests), `pnpm ui:vnext:check`, `pnpm typecheck`, targeted Prettier, `git diff --check` and `pnpm ops:workspace`. GitHub Actions owns the full Frontend CI; inspect the pushed head results on #347.

## Security, rollback and future implementation

Hidden/protected cells are operator guidance, never security. Fresh authorized backend reads, row/batch/currentness checks and existing Save privileges are decisive. No schema, migration, API, backend privilege, RLS, production importer/exporter or connected UI change occurs; rollback is documentation/specimen-only. A future bounded connected implementation may need an authorized shaped read for 1–7 daily batches and first preferred Supplier projection. No Supabase object is added here.

Remaining Product decisions: **NONE — proposed contract ready for Product approval**. The fixed 27/72/168 pt proposal is disclosed for that approval, not claimed already approved. Protected filtering and connected certification are not contract blockers.

SUPABASE_WRITES: 0. RETOOL_WRITES: 0. OPS_V1_WRITES: 0. HOSTED_BUSINESS_WRITES: 0.
