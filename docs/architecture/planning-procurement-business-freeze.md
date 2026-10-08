# Planning–Procurement Business Freeze

## 1. Freeze decision

**Decision:** `PLANNING-PROCUREMENT-BUSINESS-FREEZE-01`. **Status:** Accepted by the Product Owner, 7 October 2026. `PLANNING_PROCUREMENT_BUSINESS_FREEZE = APPROVED`.

Planning and Procurement business meaning, authority, command boundaries and the connected operator journey through Purchase Orders are the accepted Atlas baseline. This is a **business / application contract freeze**. Presentation and behavior-preserving implementation improvement remain open under sections 22–24. Repository closeout of this task completes only after this documentation PR is approved and merged; this record authorizes no implementation or deployment.

## 2. Effective baseline

| Identifier                      | Accepted value                                                                                                                       |
| ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| REPOSITORY_MAIN_SHA / MERGE_SHA | `010871bebb43f3883c77c5b9bf6954282053c93d`                                                                                           |
| PREVIEW_SHA                     | `b556c4449030f7622e4c003a77afc9afcaecf9af`                                                                                           |
| Merge                           | [PR #355 — finalize Shopping List School bands and compact Units](https://github.com/longpsu-bot/thuonghao-ops-erp/pull/355), merged |
| Hosted main                     | [Connected Atlas](https://thuonghao-ops-erp.pages.dev/)                                                                              |
| ATLAS_STAGING_PROJECT           | `rnzxmxiiqgtdevzregff`                                                                                                               |
| ATLAS_STAGING_MIGRATION_COUNT   | `92`                                                                                                                                 |
| ATLAS_STAGING_MIGRATION_TIP     | `20261006112515_atlas_recipe_purchase_unit_read`                                                                                     |
| SHOPPING_LIST_CONTRACT          | `ATLAS_SHOPPING_LIST_V2`                                                                                                             |
| SHOPPING_LIST_GEOMETRY          | `A+`                                                                                                                                 |
| ATLAS_DESIGN_LANGUAGE           | `v3`                                                                                                                                 |
| WORKBENCH_COUNT                 | `11`                                                                                                                                 |

This task freshly verified origin/main, #355's merged state/SHAs, the hosted main build manifest and the Staging migration ledger. Operator acceptance in section 21 is the Owner-supplied completed rehearsal, recorded here without rerunning business commands. Live OPS `qnthofvccilhnefdcxnz` is never an Atlas deployment target. Retool changes in this task: **0**.

## 3. Architecture authority

[OPS_SYSTEM_MAP v1.0 / ARCH-002](arch-002-atlas-system-map.md), [Atlas Vision](atlas-vision.md) and [ATLAS-MODEL-PRINCIPLE-01](../decisions/decision-atlas-model-convergence.md) govern: **FACTS EXPLICIT — STATE DERIVED — SUPPORTING OBJECTS GENERATED**. Delivery remains workflow-led, contract-constrained and backend-authoritative.

Supabase/PostgreSQL owns authoritative facts, calculations, validation, currentness, concurrency, idempotency, commitments, immutable evidence, permissions and transaction boundaries. React / Atlas vNext owns presentation, interaction, local proposals/drafts, workbench-local context and persistent workspace composition. Retool OPS v1 supplies operational continuity, workflow and dependency evidence; it is not architecture authority.

Use the [authority map through Procurement](atlas-authority-map-through-procurement.md) and each linked contract for exact signatures, registries and correction rules. This record freezes accepted meaning; it does not replace API specifications or make older implementation-status notes current.

The [decision register](../decisions/decision-register.md) and [business-rule register](../business-rules/business-rule-register.md) retain their existing authority; this decision adds no new business rule or lifecycle.

## 4. Frozen domain scope

Planning owns accepted Menu, Attendance and Pantry/direct facts, derived readiness, generated Need and explicit Confirmed Need decisions/release. Procurement owns accepted supplier splits, purchase preparation and supplier PO commitments. Recipe/effective BOM and Change Orders are upstream support. School PXK and reconciliation are retained downstream consumers at their existing bounded interface.

The approved three-stage operating baseline remains Requirement Planning → Purchase Planning → Warehouse Receiving. Recipe governance is not another daily stage. This decision certifies the implemented journey through Procurement; it neither designs nor certifies Warehouse Receiving.

## 5. End-to-end operator journey

```text
Google Sheet Menu sync → canonical Preview → atomic source Save/readback
Attendance / Pantry authored facts → consequential Save/readback
→ backend daily readiness/currentness
→ explicit daily Need Generation/update
→ Confirmed Need review → local quantity work → explicit Save
→ optional Shopping List export/import → local proposals → explicit Save
→ Tiếp tục phân bổ NCC (navigation only)
→ supplier proposal / manual split → explicit Allocation Save
→ atomic purchase preparation (Need release + Handoff + promotion + PO support)
→ PO review → explicit release of each supplier PO
→ existing School PXK / reconciliation reads
```

Recommendations and generated review remain advisory. Preparation is consequential but does not issue supplier commitments. Navigation is never a business command. Hosted PO acceptance establishes connected released-order reads and retained context; PXK/reconciliation acceptance is smoke evidence, not a fresh full issuance or Warehouse certification.

## 6. Business authority map

| Meaning                                     | Authority                                                       | Local / derived / generated boundary                                  |
| ------------------------------------------- | --------------------------------------------------------------- | --------------------------------------------------------------------- |
| School, Ingredient, Unit, Supplier identity | Governed Master Data IDs and relationships                      | Names are presentation; historical snapshots retain captured meaning. |
| Accepted Planning sources                   | Planning-owned exact saved approval snapshots                   | Parsed candidates/defaults are local proposals; readiness is derived. |
| Need proposal                               | Backend-bound source, calculation and contribution evidence     | Generated support is not manually authored business state.            |
| Confirmed quantity                          | Planning human decision and immutable revision/decision lineage | Browser/XLSX proposals confer no authority.                           |
| Supplier split and supplier-facing note     | Procurement exact saved allocation revision                     | Advice/rebalance is unaccepted until explicit Save.                   |
| Planning purchase transfer                  | Released Need and real Handoff lineage                          | Provisioning/promotion is generated within accepted commands.         |
| Supplier commitment                         | Procurement released PO snapshot and official number            | Draft/successor preparation is generated support.                     |
| Effective BOM / Change Order                | Recipe released evidence and scoped dated adjustment history    | Backend derives composition, locks and temporal applicability.        |

## 7. Command/write boundaries

| Intent                       | Existing boundary                                                                  | Consequence                                                                                                                                   |
| ---------------------------- | ---------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| Accept sources               | `save_weekly_menu`, `save_attendance`, `save_pantry`                               | Full atomic consequential source Save, canonical validation and immutable acceptance evidence.                                                |
| Generate/update a day        | `execute_need_generation` (`RMVP-04.v3`)                                           | One transaction binds sources, calculation/release evidence and Confirmed Need materialization/correction.                                    |
| Save confirmed quantity work | `save_confirmed_needs` (`RMVP-05.v2`)                                              | Only actual changed decisions; atomic history/readback; does not itself validate, approve or release.                                         |
| Standalone Planning release  | `release_confirmed_needs` (`RMVP-07.v2`)                                           | Complete saved fact validation/approval/release; allocation readiness prerequisite; creates no Handoff or PO.                                 |
| Save supplier splits         | `save_confirmed_supplier_allocation` or `save_school_catering_supplier_allocation` | Route by current source kind; append exact accepted revision, never silently promote source.                                                  |
| Prepare purchase orders      | `prepare_school_catering_purchase_orders`                                          | Atomically compose existing Planning release, Handoff, split promotion and PO support; preserve the contract's explicit replacement frontier. |
| Issue supplier commitment    | `release_school_catering_purchase_order`                                           | One explicit supplier PO release with immutable content and backend numbering.                                                                |

Exact recovery, correction and replacement behavior remains in [Confirmed Need Save/Release](../api/confirmed-need-save-release-v2.md) and [Procurement](../api/school-catering-procurement.md). A backend failure and an unknown transport outcome retain their distinct write-certainty/recovery contracts. No hidden partial Save or browser lifecycle chain is accepted.

## 8. Read/currentness boundaries

Authenticated shaped reads/previews derive currentness, blockers and allowed actions without business writes. A revision head is not proof of semantic freshness. Exact date source comparisons, batch/version, source fingerprint, revision, decision and membership checks stay backend-owned; commands lock/reread them again. React may restrict an allowed action for dirty/busy/invalid/unknown state, never promote a denied action.

Shopping List export/import rereads complete coherent authority. Released PO/PXK reads use captured commitment snapshots, not current master-data reconstruction. Reconciliation comparison and operational currentness are independent; an `OK` comparison cannot override a blocker.

## 9. Local draft versus authoritative state

Parsed Menu candidates, generated Attendance defaults, quantity proposals, XLSX edits, supplier suggestions and manual unsaved splits are local work. Rendering, reading, switching, opening a workbench, applying advice or discarding a proposal does not persist a business fact. Only the existing explicit authorized command and authoritative result establish acceptance. Generated backend evidence may be durable for traceability; “generated” does not mean disposable or human-approved.

## 10. Planning source authority

- **Weekly Menu:** Google Sheet is the normal external authoring source. Atlas fetches/parses candidate evidence; backend Preview owns canonical validation. Invalid cells coexist with valid local neighbors, remain visible blockers and prevent consequential Save. Corrected full candidates proceed to one atomic canonical Save; valid cells never justify partial authoritative writes.
- **Attendance:** accepted School/date quantities are Planning inputs; explicit zero is distinct from blank/missing. School resolution uses unique normalized code first and unique name fallback only where the existing contract permits it; ambiguous identities never resolve by array order. Defaults are working proposals. Source/currentness semantics remain backend-owned.
- **Pantry / additions:** existing Planning-owned direct facts, Purpose and explicit no-additions evidence remain. Missing work is not no-additions. D-044's exact Pantry batch + School + date `ADDITIVE | COMPLETE` fact controls composition, not Purpose or React routing; historical missing mode retains `ADDITIVE`. Unit/location derivation and consequential acceptance remain server-owned. React invents no lifecycle.

Sources: [Planning inputs](../api/rmvp-03a-planning-inputs.md) and [Pantry](../api/pantry-02-source.md), including their current amendments.

## 11. Readiness and Need Generation authority

Readiness derives from current accepted facts via [automatic preflight](../api/rmvp-03b-planning-input-readiness.md#10-additive-automatic-preflight-rmvp-03bv2); it needs no independently authored lifecycle. Compatibility evaluation evidence remains governed history.

[Need Generation](../api/rmvp-04-connected-need-generation.md) owns all arithmetic, Recipe selection, source membership, proposal rounding and output/currentness. Normal execution is exact service-date `D..D`, even when source parents cover a week. Existing legacy-overlap, correction, D-044 direct-complete, selective-continuity and D-047 proven adoption rules remain. React never reproduces Need arithmetic or creates a weekly authority aggregate. Accepted inputs are bound exactly; generated runs, contributions and release evidence retain lineage and cannot be manually invented or silently rewritten.

## 12. Confirmed Need authority

Confirmed Need is Planning's explicit decision over a generated proposal. Theoretical, proposed and confirmed quantities remain distinct. Exact quantities retain the current six-decimal baseline/read contract; real operator edits follow the existing two-decimal entry, effective Planning-step, policy and reason rules. D-046 proposal rounding and human confirmation quantum remain distinct backend authorities.

Save is an explicit consequential command with exact expected batch/version/revision/decision/source checks. Stale facts fail closed. Validation, approval and release retain complete immutable evidence; normal release/preparation composes deterministic validation and approval internally rather than adding human ceremony. Carried confirmation requires exact continuity evidence and creates no fake human decision. Historical source/decision facts never become a simplified mutable “current Need row” or change when master data changes.

Sources: [review and precision](../api/rmvp-05-connected-confirmed-need-review.md), [Save/Release v2](../api/confirmed-need-save-release-v2.md), [validation](../api/rmvp-06-connected-confirmed-need-validation.md), [approval/release evidence](../api/rmvp-07-connected-confirmed-need-approval-release.md).

## 13. Shopping List V2 boundary

**Business/import contract: frozen. A+: current approved presentation baseline.** The [V2 contract](../xlsx/atlas-shopping-list-xlsx-v1.md) and [schema](../xlsx/atlas-shopping-list-xlsx-v1.schema.json) retain historical V1 filenames; V1 is not silently accepted.

- Export requires complete saved/current daily Confirmed Need, clean local drafts and coherent authorized source evidence. Structural collection supports 1–7 service dates; current connected UI is exact-day and rejects multi-date local apply with its existing deferred-UI result. No weekly aggregate is created.
- `DATA_LINE` and `SCHOOL_BAND` are explicit kinds. Every business line repeats `__school_id` and `__school_name` even with a blank visible School cell. School ID and Unit ID remain identity authority; names are validated snapshots/display. Bands create no fake quantity or line identity.
- Hidden batch/version/source/line/revision/decision/School/location/Ingredient/Unit and exact quantity baseline evidence must match fresh authority. The unsigned workbook and protection are not authorization or cryptographic provenance.
- Validate the whole workbook, its package/structure, complete line set, grouping/pagination, currentness and identity before any local apply. Stale or modified identity rejects the entire workbook. Current importer also validates A+ geometry; a visual change is not automatically import-compatible.
- Only `SỐ LƯỢNG` becomes a local quantity proposal. `GHI CHÚ` is Supplier advice / working paper, ignored on import; it is neither allocation nor governed decision-note authority. Unchanged quantities preserve exact authority without phantom edits.
- Import performs **0 immediate business writes**. Consequential persistence requires the existing explicit Save, which revalidates backend facts and policy.

Visual evolution requires explicit document-system review, demonstrated contract compatibility or intentional versioning. It must never silently relax structural validation.

## 14. Procurement Allocation authority

[Procurement's current amendment](../api/school-catering-procurement.md#purchase-review-confirm-release-01-amendment) permits pre-Handoff allocation against complete current **saved Confirmed Need**. Commitment preparation then consumes released Planning purchase facts and promotes exact saved splits to real Handoff lineage. These are two source stages of one accepted journey; Allocation never redefines Need authority or substitutes generated quantities for missing confirmation.

Supplier eligibility, priority advice and exact-residual rebalance follow backend contracts. Local/manual splits are not accepted until explicit Save; their exact total must reconcile to authoritative requirement. Source-kind writer routing, locks, currentness, versions and concurrent-writer safeguards remain backend-owned. Need → Allocation navigation writes nothing; activating an already-open Allocation owner preserves its date/context and discloses a discrepancy rather than silently retargeting it.

**IMPLEMENTATION CONVERGENCE CANDIDATE:** the [02A audit](atlas-backend-convergence-02a-audit.md) identifies allocation precision-validation asymmetry. Business quantity meaning is frozen; the asymmetric implementation is not certified correct or approved for consolidation. 02B needs separate complete-command evidence and contract interpretation first.

## 15. Purchase Order authority

PO release is Procurement's explicit supplier commitment. Preparation/navigation and generated Drafts are not issuance. Released number, line quantities, supplier note, School breakdown and other required snapshots remain immutable and historically reproducible. Freshness and release eligibility are derived under [the PO contract](../api/school-catering-procurement.md); current School/Supplier/master changes never reconstruct released content.

Corrections use the existing explicit replacement lineage and independent release. A zero-supplier result retains the current cancellation-required blocker; this freeze invents no cancellation process. Downstream dispatch/reconciliation consumes exact snapshots where required. PO document presentation is not redesigned or globally frozen here.

## 16. Recipe / effective BOM support authority

[Recipe](../api/rmvp-02a-recipes-bom.md) owns base composition; [effective BOM](../api/rmvp-02b-recipe-adjustments-effective-bom.md) resolves exact date/context through released base → system Ingredient → system Dish → School → School-and-Dish precedence. Normal system context uses Dish + canonical School Type, never a proxy School or GENERAL fallback. Approved Menu use derives the normal base-edit lock.

For new PRESENT line authoring, Ingredient's active purchase Unit is authoritative and read-only to the operator; quantity is editable where allowed. Missing/inactive/mismatched Units block normal Save. Released historical compositions retain their stored Unit and provenance; no bulk master-Unit rewrite or inferred conversion is permitted. Existing governed copy/import/successor and proven D-047 adoption boundaries remain; no additional lifecycle machine is introduced.

## 17. Change Order support authority

[Change Order](../api/rmvp-02b-recipe-adjustments-effective-bom.md) owns scoped human intent and immutable dated correction/cancellation lineage. ADD derives Ingredient purchase Unit; quantity-bearing REPLACE derives substitute Ingredient purchase Unit; ADJUST_QUANTITY uses the target line's stored Unit; KEEP manufactures no Unit choice. Backend command semantics and effective-BOM precedence remain authoritative. The UI does not infer a new lifecycle or replay raw revisions to invent effective history.

## 18. PXK / reconciliation at the current boundary

[School PXK](../api/school-dispatch-release.md) is bounded School/date/location immutable dispatch-document evidence from current Need, saved allocation and released PO coverage. Preview is read-only; existing release is explicit and snapshots exact lineage/header facts. It requires no stock, receiving, lot, pick, movement or Trip facts.

[Reconciliation](../api/school-fulfilment-reconciliation.md) reads released PO/PXK evidence and compares exact Ingredient + Unit quantities; unlike Units never combine. Captured operational location does not move when School defaults change. It writes no resolution or business fact. Only these Procurement-consumer relationships are retained by this freeze; hosted acceptance for both is **smoke**, with no new Warehouse or Dispatch expansion certified.

**Composition supersession — 8 October 2026 (Draft PR #358):** [D-048](../decisions/decision-atlas-persistent-workspace.md) now defines **13 persistent owners**: separate Thực đơn, Sĩ số and Hàng đặt riêng (formerly Bổ sung), plus the existing jobs. Local-state/guard ownership and business/backend contracts are unchanged. Earlier eleven-owner hosted acceptance remains historical; this amendment claims no hosted rollout.

The frozen table's `WORKBENCH_COUNT = 11` and section 19 record the accepted hosted baseline, not the revised presentation count.

## 19. Persistent workspace ownership

[D-048](../decisions/decision-atlas-persistent-workspace.md), as amended by the eleven-owner Product correction and implemented at this baseline, freezes business ownership implications:

| Owner key         | Operator job                  |
| ----------------- | ----------------------------- |
| `planning`        | Thực đơn                      |
| `confirmed-need`  | Xác nhận nhu cầu              |
| `procurement`     | Phân bổ NCC                   |
| `purchase-orders` | Đơn mua                       |
| `pxk`             | Phiếu xuất kho                |
| `reconciliation`  | Đối chiếu PO / Phiếu xuất kho |
| `schools`         | Trường học                    |
| `ingredients`     | Nguyên liệu                   |
| `suppliers`       | Nhà cung ứng                  |
| `recipes`         | Công thức                     |
| `change-orders`   | Lệnh điều chỉnh               |

One persistent keyed instance owns each workbench's local state/date/context. Switching is not business exit, permits accepted dirty switching and retains inactive local work without activation refresh. Close invokes that owner's guard; sign-out resolves dirty owners individually and cannot discard earlier owners before a later cancellation. Navigation does not mutate business facts. This freezes no tab colors, styling or layout geometry, and creates no durable/cross-session workspace entity.

## 20. Security, concurrency and idempotency invariants

Existing authenticated public read/command boundaries, JWT-bound Actor/capability/scope checks, private helpers, revoke-first grants and forced RLS remain. SECURITY DEFINER/INVOKER and fixed search-path conventions stay intentional per contract, not mechanically interchangeable. No browser-only business calculation, direct private-table authority, React service-role credential or anon/service-role operator bypass is accepted.

Commands remain atomic with their required receipts/idempotency, expected versions/currentness, deterministic locking, immutable audit and complete evidence. Changed replay cannot overwrite facts. Unknown outcomes require the family's authoritative recovery; safe no-write failures are not relabeled unknown. This freezes invariants, not every existing helper/object identity forever; retirement requires separate compatibility proof.

## 21. Accepted hosted evidence

**Evidence basis:** the Product Owner supplied successful connected rehearsal and Shopping List V2 A+ hosted acceptance in this task. Earlier [5 October parity/rehearsal](../testing/atlas-staging-connected-rehearsal.md) and [XLSX native evidence](../xlsx/atlas-shopping-list-xlsx-v1-evidence.md) retain their dated limits. Their “pending”, “NOT RUN” and “HOLD” observations, including those in the V2 spec/schema/task status notes, are superseded **for current acceptance status** by this later Owner decision, not rewritten as if they had already passed. Exact API/business rules remain in their canonical contracts. No new business commands or acceptance data were created by this freeze task.

Accepted rehearsal: Shell, Persistent Workspace, Attendance, Pantry, Need Generation, Confirmed Need, Need → Allocation handoff, Allocation, Recipes, Recipe purchase Unit, Change Orders, Schools, Ingredients and Suppliers **PASS**. Menu **PASS for approved September reads and sync entry point**; PO **PASS for connected released-order read / retained context**; PXK and reconciliation **PASS smoke**; Design Language v3 **PASS desktop/mobile sanity**. 18/09 generation produced **231 source lines / 210 Need rows**. Shopping List **PASS after #355**.

No Planning/Procurement authority, business-data-loss, currentness, concurrency-contract or hosted-environment defect was demonstrated. This is accepted evidence within the stated scope, not proof that every negative/concurrency case was exercised hosted or every object is defect-free. Suspected allocation precision remains the section 14 investigation candidate.

17 September Shopping List acceptance retained:

| Evidence                           | Value                                                                                                                                             |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| Confirmed Need batch / version     | `a0311e0a-a4de-48b9-a529-fe7464a3352b` / `3`                                                                                                      |
| First line                         | `444b33c8-1e00-46ba-a2a8-c995d9fd9900`                                                                                                            |
| First revision                     | `173f2e18-5b3f-4662-91f1-1ec766bb3a36`                                                                                                            |
| First decision                     | `6fc3f04a-0b90-4b58-ab7c-2dbfb4691864`                                                                                                            |
| Exact authoritative first quantity | `228.010000`                                                                                                                                      |
| Pre/post acceptance fingerprint    | `ed9e9955fa56e13d0ed4f367d262db4c8e4627786f32d9ac31570a71e8ba1dbe`                                                                                |
| Acceptance operations              | Clean XLSX import, QA XLSX import, local proposal discard; fingerprint unchanged after each; **Save never clicked; 0 immediate business writes**. |

Current approved A+: physical A4 portrait, **12 pages**, frozen rows **1–3**, `printTitlesRow = 1:3`; global `TRƯỜNG | THÀNH PHẦN | ĐVT | SỐ LƯỢNG | GHI CHÚ`; body School bands; blank visible School on **248 DATA_LINE** rows with repeated hidden School name/ID; **20 initial / 6 continuation** bands; **28 / 44 / 28 pt** normal/wrapped/band height; usable Unit **54.5 pt**, Note **132.5 pt**. All current Units **kg, Cái, Miếng, Quả, Cốc, Hộp, Gói, Trái** fit. No clipping, cropping or overflow. These are accepted specimen metrics, not business constraints on future data or a global document freeze.

| Area                  | Accepted behavior                                                 | Authority                                                            | Hosted/rehearsal evidence                                     | Frozen?                            | Future lane                          |
| --------------------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------------------------------------------------- | ---------------------------------- | ------------------------------------ |
| Menu                  | Full canonical sync acceptance; blocked local candidates retained | [Planning inputs](../api/rmvp-03a-planning-inputs.md)                | Approved September reads / sync entry PASS                    | Business boundary                  | UX; compatible implementation        |
| Attendance            | Exact School/date facts; zero ≠ missing                           | Planning inputs above                                                | PASS                                                          | Business                           | UX / import presentation             |
| Pantry                | Explicit additions/no-additions and composition mode              | [Pantry](../api/pantry-02-source.md)                                 | PASS                                                          | Business                           | UX; compatible implementation        |
| Readiness             | Derived current sources, no independent human state               | [Preflight](../api/rmvp-03b-planning-input-readiness.md)             | Connected generation prerequisite; no separate result claimed | Business                           | 02B–02D proof                        |
| Need Generation       | Exact-day backend calculation and lineage                         | [Generation](../api/rmvp-04-connected-need-generation.md)            | 18/09 PASS; 231 source / 210 Need rows                        | Business                           | Measured convergence                 |
| Confirmed Need        | Explicit Save and immutable decision/release evidence             | [Save/Release](../api/confirmed-need-save-release-v2.md)             | PASS; identified 17/09 facts retained                         | Business                           | UX; compatible implementation        |
| Shopping List V2      | Whole-workbook local proposals; explicit Save                     | [V2](../xlsx/atlas-shopping-list-xlsx-v1.md)                         | A+ import/discard PASS; fingerprint unchanged                 | Business/import; current A+ only   | Document-system review/versioning    |
| Allocation            | Exact saved splits; source-kind/currentness checks                | [Procurement](../api/school-catering-procurement.md)                 | PASS; navigation handoff PASS                                 | Business; precision asymmetry open | 02B evidence; UX                     |
| PO                    | Explicit supplier commitment; immutable snapshots                 | Procurement above                                                    | Released-order read / retained context PASS                   | Business                           | Document System; convergence         |
| Recipe                | Ingredient purchase Unit; exact effective context/history         | [Recipe](../api/rmvp-02a-recipes-bom.md)                             | Recipe and purchase Unit PASS                                 | Supporting business authority      | UX; compatible implementation        |
| Change Order          | Scoped immutable intent; action-specific Unit                     | [Effective BOM](../api/rmvp-02b-recipe-adjustments-effective-bom.md) | PASS                                                          | Supporting business authority      | UX; compatible implementation        |
| PXK                   | Current Procurement consumer; immutable bounded document          | [PXK](../api/school-dispatch-release.md)                             | PASS smoke                                                    | Existing interface only            | Document System; Dispatch separately |
| Reconciliation        | Exact read-only PO/PXK comparison                                 | [Reconciliation](../api/school-fulfilment-reconciliation.md)         | PASS smoke                                                    | Existing read boundary             | UX; compatible implementation        |
| Persistent Workspace  | Eleven owners, retained context, guarded exit                     | [D-048](../decisions/decision-atlas-persistent-workspace.md)         | PASS                                                          | Business/local ownership           | UX presentation                      |
| Atlas Design Language | v3 operational legibility                                         | [v3](../ui/atlas-design-language-v3.md)                              | Desktop/mobile sanity PASS                                    | Current baseline; visually open    | ATLAS-UX-POLISH-02                   |
| Document Presentation | A+ accepted; other documents retain existing contracts            | V2 above; PO/PXK contracts                                           | Shopping List only; no global acceptance                      | No global presentation freeze      | ATLAS-DOCUMENT-SYSTEM-01             |

## Explicitly unfrozen

- **Atlas UI polish:** table hierarchy, filter placement, action discoverability, spacing, sticky behavior, information density, responsive refinements, small workflow affordances and visual polish. Design Language v3 is the current baseline, not permanent visual immutability. `ATLAS-UX-POLISH-02` follows approximately **5–10 working days of staff usage evidence**.
- **Document presentation:** `ATLAS-DOCUMENT-SYSTEM-01` covers PO, PXK, Dispatch, Attendance/import templates, common branding/layout, signatures/header/footer and grouped exports. A+ is the current Shopping List baseline; broader presentation is open, with a later document presentation freeze. Changes breaking V2 import compatibility require explicit contract/version review.
- **Backend implementation:** object/helper layout is not frozen. Externally observable business semantics remain frozen; behavior-preserving convergence requires proof under separate 02B–02D tasks.
- **Warehouse:** not designed or frozen by this decision; remains future new-domain work after a sufficiently certified backend baseline.

**BUSINESS FREEZE DOES NOT AUTHORIZE BACKEND CONVERGENCE.** The merged [#353 / 02A audit](atlas-backend-convergence-02a-audit.md) governs proposed 02B–02D: no broad rewrite, migration squash or retirement by name/age/row count. Compatibility remains until complete safe-retirement proof. Three duplication families are proven equivalent candidates, six are semantically different, three need additional evidence; allocation precision requires investigation. No broad grant/RLS/security defect was demonstrated. Performance requires measurement; ordered applied migration history remains authority. None of those findings freezes every current implementation object as necessary.

## 23. Change control after freeze

| Class                          | Rule                                                                                                                                                                                            | Examples                                                                                                                        |
| ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| A — PRESENTATION-ONLY          | May proceed without reopening business freeze when authority, commands, identities, currentness, persistence and output/import compatibility are preserved. Follow existing UI/document review. | Styling, table density, non-structural document presentation.                                                                   |
| B — IMPLEMENTATION-CONVERGENCE | Separate bounded 02B–02D approval and proven observable equivalence, including security/error/transaction/history behavior.                                                                     | Pure helper reuse, measured index/performance work, compatibility retirement after complete proof.                              |
| C — BUSINESS-CONTRACT CHANGE   | Requires explicit Product/architecture amendment identifying affected contracts and migration/compatibility impact.                                                                             | Redefining Confirmed Need, Unit or Allocation authority, PO commitment, Menu source, or making XLSX import persist immediately. |
| D — NEW DOMAIN                 | Requires new architecture/task and domain-boundary approval.                                                                                                                                    | Warehouse.                                                                                                                      |

The freeze is a **baseline of accepted meaning**. It permits bug, security, performance, UX and document fixes that restore/preserve the frozen contract without reopening the entire freeze. A proposed fix that changes the contract is Class C. Stop on a real unresolved contradiction and report `FREEZE_CONTRADICTION` with exact sources, incompatible meanings and recommended resolution; do not silently tidy authority.

## 24. Roadmap after freeze

Current: close `PLANNING-PROCUREMENT-BUSINESS-FREEZE-01` after this PR is approved/merged. Then separate tracks may proceed in parallel while preserving frozen contracts:

1. Staff usage for approximately 5–10 working days → `ATLAS-UX-POLISH-02`.
2. `ATLAS-DOCUMENT-SYSTEM-01` → PO/PXK/Dispatch/Attendance-import presentation → later document presentation freeze.
3. `ATLAS-BACKEND-CONVERGENCE-02B` → `02C` → `02D`, each separately bounded under the 02A evidence gates.

Warehouse begins only after the backend baseline is sufficiently certified for its new domain boundary. UX and document completion are not prerequisites for 02B absent a demonstrated dependency. See [roadmap](roadmap.md).

## 25. Rollback / supersession

This documentation-only task has no schema, migration, business-data, Retool or live OPS rollback. A reviewed Git revert can remove the repository record; it does not reverse issued commitments or silently rescind the Owner decision. Rescinding/amending accepted meaning requires an explicit superseding Product/architecture decision, dated rationale, affected contracts and precise new baseline/compatibility rule. Preserve this evidence and all historical snapshots. Future operational recovery uses the existing governed restore/forward-correction procedures, never migration-ledger deletion or historical rewrites.
