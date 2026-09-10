# ATLAS-UI-VNEXT-02 — Chakra Procurement workbench

Status: Implemented for isolated review; production cutover is not included. Final delivery is one Draft PR, with product/architecture review and GitHub Actions certification still required before any future merge.

## Baseline and scope

- Starting SHA: `6413d787539a5651f59956540f1fdc449b4665c2` (PR #274 squash merge).
- Branch: `feat/atlas-ui-vnext-02-chakra-procurement`.
- Authorized checkout: `E:/Project/OPS ERP/thuonghao-ops-erp`; correct remote and clean worktree verified. The user approved creating the task branch from the exact baseline after the initial checkout was found on the previous foundation branch.
- One implementation agent; no subagents. Review performed inline against the task and governing documents.
- Authority: OPS_SYSTEM_MAP v1.0, D-034/D-035/D-045, Atlas Design Language V1 and `docs/api/school-catering-procurement.md`.

## Delivered behavior

The workbench receives `authSubject`, `purchaseReviewApi`, `procurementApi`, `initialServiceDate`, optional `initialStage`, optional School catalogue and optional `onExportXlsx` / `onExportPdf` callbacks. Existing production integration is untouched.

Allocation uses the current confirmed-allocation read, exact single-date scope and explicitly committed School filters. Empty School IDs mean all Schools. Search and exceptions are local; School checkbox changes remain drafts until Apply, selecting all normalizes to empty IDs, and zero selection cannot apply. A successful all-School read supplies the catalogue when one is not injected.

The dense table presents exact human quantities, five operator states, explicit row actions and a selected surface plus geometric clay rail. Supplier detail has an exact running balance, participating eligible suppliers, explicit additions, eligible draft removal, visible ineligible saved allocations and advisory recommendation/rebalance regions. Applying a proposal changes only local input; Save uses the existing source-qualified builder. Numeric equality is six-place BigInt arithmetic, including values beyond IEEE-754 precision. Invalid input is never silently rounded or converted to zero. Clean Close returns immediately; dirty Close uses a scoped Chakra Dialog with cancel/discard and focus return.

Authoritative date/School/stage changes supersede outstanding reads and command responses. Commands have an immediate duplicate-activation guard. Stale and unknown results lock writes; retryable backend failures offer explicit retry of the identical request. There is no automatic write retry. Successful commands read authority back; failed readback yields uncertain feedback and a mutation lock. Confirmed-source Save uses `CONFIRMED-SUPPLIER-ALLOCATION.v1`; returned Handoff-source authority retains its existing source-qualified writer, without adding the old recommendation bulk-confirmation UI.

Ready, allowed preparation is available only from a successful current read with no active supplier editor. The existing `PURCHASE-COMMITMENT.v1` request builder owns the request. The workbench enters Orders only after PO readback succeeds; failed preparation readback recovers through another PO read.

Orders show supplier/date documents and exact delivery lines. Current drafts release independently; stale drafts use the existing draft materialization command; stale released commitments use the existing replacement command; cancellation-required shows the blocker without inventing a cancel API. Superseded documents are historical. Each state has at most one dominant consequential action. Released/superseded export-ready snapshots with backend export permission may be passed to injected XLSX/PDF callbacks, rendered as utility actions.

## Files and business bridge

Created under `src/vnext/atlas/procurement/`:

- `ProcurementWorkbench.tsx` and `ProcurementWorkbench.test.tsx`: operator composition, filters, School scope and integrated interactions.
- `useProcurementWorkbench.ts` and `useProcurementWorkbench.test.tsx`: request builders, currentness, command locks, retry and readback.
- `ProcurementAllocationTable.tsx`: exact allocation scanning and selection.
- `ProcurementSchoolScope.tsx`: Procurement-specific 33-School-capable picker.
- `ProcurementSupplierDetail.tsx` and `ProcurementSupplierDetail.test.tsx`: local allocation decisions and dirty Dialog.
- `ProcurementCommandFeedback.tsx`: safe messages and labeled recovery.
- `ProcurementOrdersStage.tsx` and `ProcurementOrdersStage.test.tsx`: supplier PO table/detail, action and export eligibility.
- `procurementExactQuantity.ts` and `procurementExactQuantity.test.ts`: focused exact input/display arithmetic.
- `procurementReviewFixtures.ts`: deterministic typed local responses.
- `ProcurementWorkbench.stories.tsx`: 16 review scenarios, explicitly wrapped with AtlasVNextProvider and AtlasVNextShell.

Created `src/vnext/atlas/bridges/procurement.ts`. The boundary checker and its tests approve exactly these reviewed, non-presentation modules:

1. `src/modules/atlas/procurement/purchaseReviewApi`
2. `src/modules/atlas/procurement/schoolCateringProcurementApi`
3. `src/modules/atlas/procurement/schoolCateringProcurementModel`
4. `src/modules/atlas/procurement/procurementOperatorCopy`
5. `src/modules/atlas/connection/atlasRpc` (type-only bridge import)

The API modules depend only on the listed request/model authorities; the model and copy modules import no presentation. `atlasRpc` imports only the Supabase client type. No legacy workbench, table, panel, School selector, CSS, theme or navigation is approved. `purchaseOrderExports` is deliberately excluded.

Also updated the design-language implementation note and created the dated implementation plan. No other module is changed.

## Validation

Fresh checks after the browser fixes:

| Check                                                          | Result                                         |
| -------------------------------------------------------------- | ---------------------------------------------- |
| `pnpm ui:vnext:check`                                          | Passed                                         |
| `pnpm ui:vnext:typegen`                                        | Passed                                         |
| `pnpm typecheck`                                               | Passed                                         |
| vNext Procurement tests                                        | 78 passed across 5 files                       |
| Boundary tests                                                 | 28 passed                                      |
| Unchanged legacy `SchoolCateringProcurementWorkbench.test.tsx` | 55 passed                                      |
| Combined focused run                                           | 161 passed, 7 files                            |
| `pnpm build`                                                   | Passed; large-chunk warning                    |
| `pnpm build-storybook`                                         | Passed; large-chunk and plugin-timing warnings |

The first failing tests preceded the new helpers, boundary registry, controller and UI components. Later red/green checks caught inherited School checkbox labels and missing scope-wide blockers. A browser assertion first failed because the Save footer ended at 788px in a 768px viewport; after the local-height correction it ends at 728px. Tests establish equivalent safety outcomes through new presentation, without requiring legacy DOM/class parity or changing legacy tests.

Touched-file Prettier and `git diff --check` passed. Fresh command logs are saved with the browser evidence. The final mobile regression also verifies a 400px local table scroll surface at 360×800, instead of stretching the page with all rows.

Broad routine certification is owned by `Frontend CI / Format, typecheck, test, build` on the PR. Local tests and builds are evidence, not a claim of GitHub CI approval or independent product/architecture approval.

## Browser evidence

External pure-vNext harness and evidence root:

`C:/Users/HOME/.codex/visualizations/2026/09/10/atlas-vnext-02/`

Contact sheet:

`C:/Users/HOME/.codex/visualizations/2026/09/10/atlas-vnext-02/atlas-vnext-02-contact-sheet.png`

Browser: headless local Microsoft Edge `152.0.4191.66`, DPR 1. Captured 1366×768, 1440×900, 1920×1080 and 360×800. `browser-evidence.json` records 23 named viewport captures, keyboard/geometry assertions, requests and console evidence; an additional full-page mobile capture is included. HTTP/WebSocket traffic is restricted to the local harness; there were zero non-local requests, zero business-write requests, zero browser exceptions and zero console warnings/errors.

At 1366×768, the primary table dominates the workbench and all toolbar controls fit one row. Supplier detail measures about 415px beside a 677px master (38/62), with a single separator. Its running balance stays above local scrolling and Save ends at about y=728. Attached tables can scroll horizontally within the master; the document does not overflow horizontally. Mobile stacks scope controls and attached detail, retaining the dense, locally horizontally scrollable table. Long Vietnamese School names remain visible in the picker. No KPI cards, nested cards, raw palette changes or decorative dashboard treatments were introduced.

Keyboard checks cover opening/searching/toggling the School picker, zero-selection prevention, Escape and focus return; arrow-key stage navigation; detail focus and row focus return; dirty Dialog initial focus, Tab trapping and Escape preserving drafts. Selection has `aria-selected` plus a non-color rail; warnings include text/symbols. Reduced motion disables row transitions and the dirty Dialog has no motion.

## Differences, risks and rollback

- The visual composition is intentionally new: two job tabs, attached detail, quieter balanced rows, a Chakra dirty Dialog, no technical trace panel, and secondary export actions. No Product/design deviation requiring new approval was introduced.
- Search/exception filters and other allocation row actions are disabled while supplier detail is active, keeping the originating row available for focus return and preserving the active local draft. Explicit authoritative scope changes still invalidate the editor as requested.
- This task wires no default export library. Review callback actions explicitly announce a preview and do not create a real document. Real integration must inject the existing immutable-document exporter at its boundary. The legacy export helper currently accepts only `RELEASED_TO_SUPPLIER`; adapting that helper for historical `SUPERSEDED` exports is outside this isolated presentation slice. It was neither imported nor modified here.
- Fixtures provide explicit snapshots; they are not a simulated backend and do not certify backend algorithms or hosted integration. Auth subject and API adapters remain the responsibility of a later production integration task.
- No backend/Supabase schema, migration, RLS, RPC, Edge Function, authentication, contract, model, Retool, Google Sheets, Staging data or live OPS change. No hosted business write was performed.
- Production entrypoint, AtlasApp routing, navigation and legacy Procurement remain unchanged. Soft Mineral raw values and `strictTokens: true` remain unchanged.
- No migration/data rollback effects. Removing the isolated vNext Procurement files and its five bridge-registry entries rolls back this presentation, without affecting production routing or business facts.
