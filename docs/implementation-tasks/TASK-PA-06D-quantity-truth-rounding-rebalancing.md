# TASK-PA-06D — Quantity Truth, Precision, Rounding, Rebalancing, and Write Fidelity

**Task type:** Documentation and contract only

**Starting baseline:** `f25acededa6750f6ab08326333bff588e437f41b` or later matching `origin/main`

**Task branch:** `docs/pa-06d-quantity-truth-rounding-rebalancing`

**Merge/deployment state:** Draft only; do not merge or deploy

## 1. Objective

Create the authoritative prerequisite for future Atlas Requirement Planning and Procurement quantity UI. Define quantity ownership, precision separation, upward purchase quantization, supplier tick allocation, proportional rebalancing, residual distribution, PO/Dispatch equality, Vietnamese operator language and exact preview-to-persistence fidelity.

This task must expose legacy contradictions without treating them as approved Atlas rules.

## 2. Governing sources and authority

Review in this order:

1. approved Atlas business/domain contracts;
2. merged Atlas migrations and tests;
3. live OPS Supabase behavior, read-only;
4. Retool export evidence, read-only;
5. explicitly labeled assumptions and recommendations.

Mandatory repository sources include `AGENTS.md`, `README.md`, the product charter, ARCH-001/ARCH-002, business/decision registers, PA-01 through PA-03 persistence contracts, PA-05D and PA-05E contracts/migrations/tests, PA-06A connection/workflow/screen contracts, active workbench requirements, the merged PA-06C task record and current Planning/Procurement/document prototypes.

## 3. Evidence review record

### 3.1 Retool

The four available OPS exports were reviewed read-only. The Purchase Planner export is primary evidence. Trace coverage includes:

- master load, seed, merge, actual-need save controller/query and refresh;
- detail pool, seed, edits, split, removal, manual `Cân bằng`, validation and family save;
- PO and Dispatch confirmation, reads and export formatters;
- exact `EPS=1e-6`, `toFixed(6)`, `round6`, ratios, total comparison and residual behavior.

| Retained path and exact file name                  | Artifact type      | SHA-256                                                            |
| -------------------------------------------------- | ------------------ | ------------------------------------------------------------------ |
| `/mnt/data/OPS - Admin (in production).json`       | Retool JSON export | `A6D74CA01F7942687E8639FFEF73DBA5A89C6BCBF653F9454011CEC551549350` |
| `/mnt/data/OPS - Công thức.json`                   | Retool JSON export | `B38C86AC3B1FED985F6BC07D91C0708CF5AACCCC682434BA2498960D1DA1B809` |
| `/mnt/data/OPS - Nguyên liệu và Nhà cung ứng.json` | Retool JSON export | `2FB973CBD6A3900252AA9037A1D4D197551BCCC93DB60E36512D97F27D903648` |
| `/mnt/data/OPS - Lên đơn, Đặt hàng (1).json`       | Retool JSON export | `6F6FF8D025696D375F354A86126661D20C3E9908D6475D40ECB14EE006B4A371` |
| `/mnt/data/schema.sql`                             | PostgreSQL schema  | `1254D4DE81AE0B581B87666F4AA7195932ACB9ED8559B677AE9F0AA95C24DB6D` |

The exact retained JSON bytes were no longer mounted during the 2026-07-19 correction pass. The original draft mistakenly presented hashes from differently named or different-byte files under `D:\Project\OPS v2` as retained hashes. The contract records those local alternatives, their exact names/types/hashes, and the reason they differ. The local `D:\Project\OPS\schema.sql` was re-hashed and matches the retained schema hash.

Observed active invocation:

```text
q_ppwb_master_load
→ public.v_actual_needs_effective_orderable
→ public.actual_need_overrides
→ public.purchase_assignments

js_ppwb_save_actual_need
→ q_ppwb_save_actual_need
→ public.app_upsert_actual_need_overrides_bulk
→ public.fn_rebalance_purchase_assignments_for_keys_fast

q_ppwb_detail_pool_load
→ public views and tables

js_ppwb_detail_save
→ q_ppwb_detail_replace_family
→ public.app_replace_purchase_assignments_family_planner

q_po_confirm
→ public.app_confirm_purchase_orders

q_dispatch_confirm
→ public.app_confirm_dispatch
```

The duplicate `q_ppwb_master_save_and_rebalance` query also targets `public.app_upsert_actual_need_overrides_bulk`, but `js_ppwb_save_actual_need` selects `q_ppwb_save_actual_need`. The active public grain is `service_date + school_id + ingredient_id`. The public bulk upsert stores exact `qty_actual`, calls the public fast rebalance across existing and positive-baseline ingredient families, prefers the override over `qty_final_orderable`, may insert the preferred supplier, rounds non-final proportional rows to six decimals, gives the final technically sorted row the exact residual, and deletes family rows when the new total is nonpositive.

The server rebalance is proportional; manual Retool `Cân bằng` is sequential fill/cap; detail save accepts exact manual decimals; local state is optimistic; master refresh performs readback while detail save does not. The exported detail-save JavaScript contains duplicated declarations, so it is evidence of intent and query linkage, not proof of reliable live execution.

### 3.2 Live OPS Supabase

Project `qnthofvccilhnefdcxnz` (`OPS`) was reviewed read-only. No schema or data mutation is permitted.

Review covers:

- `ingredient_order_step`, `ceil_to_step`, `theoretical_orderable_qty`;
- effective need/orderable/assignment feed views;
- all relevant public/OPS_V2 upsert, rebalance and family-replacement variants, classified separately from Retool invocation evidence;
- Purchase Assignment and Actual Need Override triggers;
- public PO and Dispatch confirmation invoked by the retained export, plus OPS_V2 equivalents classified as present but uninvoked by that export;
- PO/Dispatch line/read/export flow;
- quantity/ratio types and constraints.

Key evidence:

- current reviewed quantity and ratio columns use unrestricted PostgreSQL `numeric`;
- six-decimal behavior is selected in functions/JavaScript, not a universal schema scale;
- current live ingredient configuration is `0.1` for kg and `1` for current other/count-like units, but those are purchase steps, not approved Planning steps;
- theoretical orderable logic may round below source need at/above its threshold;
- the active public PO path sums exact portions, while the active public Dispatch path applies a second ceiling;
- no reviewed public or OPS_V2 constraint enforces supplier portions as purchase-step multiples or exact family totals;
- public uses `service_date + school_id + ingredient_id`; OPS_V2 uses `service_date + school_id + effective_line_key`;
- OPS_V2 objects are present, but the retained export does not invoke them and therefore does not establish them as its active path.

## 4. Deliverables

Create only:

1. `docs/architecture/pa-06d-quantity-truth-rounding-rebalancing-contract.md`;
2. `docs/business-rules/pa-06d-rounding-rebalancing-rule-register.md`;
3. `docs/ui/pa-06d-requirement-allocation-workbench-spec.md`;
4. `docs/decisions/decision-pa-06d-quantity-truth-and-write-fidelity.md`;
5. this task record.

Add minimal navigation/register links only to the roadmap, PA-06A screen map, business-rule register and decision register.

## 5. Required contract outcomes

- Distinct quantity meanings from raw calculation through delivered quantity.
- Separate calculation precision, epsilon, ratio precision, Planning step, purchase step, persistence and display precision.
- Complete 27-rule legacy/recommended register.
- Required raw values tested against steps `0.1`, `1`, `0.5`, `0.25`.
- One/two/three-supplier, equal/uneven, increase/reduce/zero, residual and manual allocation examples.
- Exact identification of legacy below-source results.
- Recommended integer tick model and exact sum invariant.
- Proportional default; sequential Retool behavior recorded as legacy evidence requiring decision.
- Exact WYSIWYG preview/commit/readback/PO/Dispatch invariant.
- Two Vietnamese-first workbench specifications.
- Workbench B title `Phân bổ số lượng cho nhà cung cấp`, with action `Xem trước phân bổ lại theo tỷ lệ` and tick support wording `Tổng số đơn vị theo bước đặt hàng`.
- Complete glossary, operator-state matrix, 18 full copy examples and language QA corrections.
- Comparison of `Nhu cầu vận hành`, `Nhu cầu đề xuất xác nhận`, and `Số lượng đề xuất xác nhận`; `Nhu cầu vận hành` remains proposed pending product-owner and operations-language review.
- Seventeen explicit product decisions with unresolved items not marked approved.
- Gap analysis against the current 18-function Atlas API.
- Smallest backend and later UI follow-ups.

## 6. Prohibited changes

Do not modify React, Storybook, application behavior, package files, dependencies, SQL, migrations, RPCs, tables, columns, fixtures, the 18-function registry, Retool, production data, credentials, hosted infrastructure or deployments. Do not access Atlas private tables from browser code. Do not weaken tests or state that a legacy rule is approved because it exists.

## 7. Smallest future implementation sequence

### 7.1 PA-06D-H1 backend follow-up

Accepted baseline:

```text
Wholesale source
→ released Confirmed Need Batch/line revisions
→ CMD-03 creates Purchase Handoff directly in RELEASED_TO_PROCUREMENT, version 1
→ CMD-04 creates a released Dispatch Requirement
```

PA-06D-H1 is a preferred future insertion point, not an approved task. If separately approved, it should attach Quantity Decision preview/confirmation to a Confirmed Need line/revision, and CMD-03 should consume that confirmed decision when releasing the Purchase Handoff. The bounded work would include:

- effective-dated Quantity Decision rule resolution;
- authorized line detail/discovery read;
- backend quantity preview and preview-bound commit;
- exact purchase ticks, rule/source/aggregate versions and rounding difference;
- receipt, event and audit compatibility;
- authoritative command result and authorized readback;
- focused invariant, authorization, stale, idempotency and WYSIWYG tests.

This direction requires explicit architecture, command-contract, registry, lineage, authorization, event, audit, and test approval before implementation. An explicit new intermediate object between Confirmed Need and Purchase Handoff is an alternative architecture change, not an already approved object. Neither option may silently change the 18-function registry, add multi-supplier allocation or broaden scope.

### 7.2 Smallest later UI follow-up

After an insertion point and PA-06D-H1 boundary are explicitly approved and implemented, implement only `Rà soát số lượng nhu cầu`. Include Vietnamese preview/confirmation, stale and ambiguous-outcome handling, exact returned snapshot, authorized readback and audit link. Do not enable allocation edits until a separate split-allocation backend contract is approved.

### 7.3 Deferred

- Multi-supplier allocation aggregate/commands and authorized reads;
- fixed supplier portions and supplier-specific steps;
- residual-priority master data;
- released-PO correction lifecycle;
- PO/Dispatch document implementation;
- rollout, legacy reconciliation and migration;
- Retool or production changes.

## 8. Acceptance criteria

- The five deliverables exist and are internally linked.
- Existing authoritative documents are changed only by minimal links/register entries.
- Every required precision, rule, example, contradiction, UI state, glossary field, decision and API gap is present.
- Normal operator copy is Vietnamese-only, natural and actionable.
- Document language QA passes; product-owner terminology approval and rendered operations review remain pending and are not represented as final passes.
- No unresolved product choice is labeled approved.
- Repository diff contains documentation only.
- `pnpm ops:workspace`, `pnpm install --frozen-lockfile`, `pnpm format`, and `git diff --check` pass.
- A draft PR titled `PA-06D: Define quantity truth, precision, rounding, and rebalancing` is opened and remains unmerged/undeployed.

## 9. Pull-request statement

The PR body must state:

- documentation only;
- no rounding or rebalancing implementation is approved yet;
- OPS Supabase and Retool were reviewed read-only;
- six decimals are internal computational precision, not operational precision;
- all identified contradictions are documented;
- all remaining product decisions are explicit;
- no backend, UI, Retool or production behavior changed.

## 10. Verification record

Initial verification on 2026-07-18 in the canonical repository and task branch:

- local starting `main` and `origin/main` both resolved to `f25acededa6750f6ab08326333bff588e437f41b`, which includes merged PR #112;
- `pnpm ops:workspace` passed and identified the intended repository, origin and branch;
- `pnpm install --frozen-lockfile` reported the workspace already up to date;
- `pnpm format` passed;
- the five new PA-06D documents passed an explicit Prettier check;
- relative Markdown file links in the five deliverables and four minimally linked documents resolved locally;
- `git diff --check` passed before staging and `git diff --cached --check` passed on the exact nine-file staged scope;
- no wider frontend suite was run because the diff is documentation-only and no focused failure or CI requirement called for it.

Correction verification on 2026-07-19 in the same task branch:

- direct inspection of the Retool source ZIP established the controller/query targets as public and confirmed that the duplicate master-save query is not the controller target;
- the exact retained `/mnt/data` artifact names and review-recorded SHA-256 values were asserted in the evidence tables; the exact retained JSON bytes were not mounted for recalculation, so this limitation is explicit rather than masked;
- the local alternative JSON exports, Retool source ZIP, and local schema were re-hashed; the local schema matched the retained schema record;
- `pnpm ops:workspace`, `pnpm install --frozen-lockfile`, and `pnpm format` passed with the bundled non-interactive runtime;
- the five PA-06D documents passed an explicit Prettier check and `git diff --check`;
- relative Markdown file links resolved across the five deliverables and four navigation/register documents;
- targeted assertions passed for public-path attribution, public/OPS_V2 grains, lifecycle wording, retained hash records, corrected Vietnamese terms, and the three separate language-review statuses;
- no frontend, SQL, migration, RPC, Retool, Supabase, production-data, or deployment behavior was changed.
