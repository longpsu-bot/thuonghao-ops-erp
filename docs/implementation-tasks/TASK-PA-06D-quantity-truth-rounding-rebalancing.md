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

| Retained evidence                      | SHA-256                                                            |
| -------------------------------------- | ------------------------------------------------------------------ |
| OPS Admin production export            | `8C5BA8205C1DE37966B1ED0A0762DB6B508D634E7EA91E92788308B0AFD2BAE1` |
| OPS Công thức export                   | `E50AB600E98C1AC683BD449C8B2C859846C0BF5E5AE2A5A807BBE827B03852E9` |
| OPS Nguyên liệu và Nhà cung ứng export | `0DA3AD9F1C31DC29504B63F711150153C16F09451E2A8D299A9EC61048BC9722` |
| OPS Lên đơn, Đặt hàng export           | `2714512AB9A47CF9E560305C48192ABD45AB3E99ACC5ADE5C26C5414DD263093` |
| Retained `schema.sql`                  | `1254D4DE81AE0B581B87666F4AA7195932ACB9ED8559B677AE9F0AA95C24DB6D` |

Observed active invocation:

```text
master save
→ q_ppwb_save_actual_need
→ ops_v2.app_upsert_actual_need_overrides_bulk
→ ops_v2.fn_rebalance_purchase_assignments_for_keys_planner

detail save
→ q_ppwb_detail_replace_family
→ ops_v2.app_replace_purchase_assignments_family_planner
```

The server rebalance is proportional; manual Retool `Cân bằng` is sequential fill/cap; detail save accepts exact manual decimals; local state is optimistic; master refresh performs readback while detail save does not. The exported detail-save JavaScript contains duplicated declarations, so it is evidence of intent and query linkage, not proof of reliable live execution.

### 3.2 Live OPS Supabase

Project `qnthofvccilhnefdcxnz` (`OPS`) was reviewed read-only. No schema or data mutation is permitted.

Review covers:

- `ingredient_order_step`, `ceil_to_step`, `theoretical_orderable_qty`;
- effective need/orderable/assignment feed views;
- all relevant public/OPS_V2 upsert, rebalance and family-replacement variants;
- Purchase Assignment and Actual Need Override triggers;
- active OPS_V2 PO and Dispatch confirmation;
- PO/Dispatch line/read/export flow;
- quantity/ratio types and constraints.

Key evidence:

- current reviewed quantity and ratio columns use unrestricted PostgreSQL `numeric`;
- six-decimal behavior is selected in functions/JavaScript, not a universal schema scale;
- current live ingredient configuration is `0.1` for kg and `1` for current other/count-like units, but those are purchase steps, not approved Planning steps;
- theoretical orderable logic may round below source need at/above its threshold;
- OPS_V2 PO sums exact portions, while OPS_V2 Dispatch applies a second ceiling;
- no OPS_V2 constraint enforces supplier portions as purchase-step multiples or exact family totals.

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
- Complete glossary, operator-state matrix, 18 full copy examples and language QA corrections.
- Seventeen explicit product decisions with unresolved items not marked approved.
- Gap analysis against the current 18-function Atlas API.
- Smallest backend and later UI follow-ups.

## 6. Prohibited changes

Do not modify React, Storybook, application behavior, package files, dependencies, SQL, migrations, RPCs, tables, columns, fixtures, the 18-function registry, Retool, production data, credentials, hosted infrastructure or deployments. Do not access Atlas private tables from browser code. Do not weaken tests or state that a legacy rule is approved because it exists.

## 7. Smallest future implementation sequence

### 7.1 PA-06D-H1 backend follow-up

One separately approved bounded task for one unreleased Purchase Handoff line:

- effective-dated Quantity Decision rule resolution;
- authorized line detail/discovery read;
- backend quantity preview and preview-bound commit;
- exact purchase ticks, rule/source/aggregate versions and rounding difference;
- receipt, event and audit compatibility;
- authoritative command result and authorized readback;
- focused invariant, authorization, stale, idempotency and WYSIWYG tests.

It must not silently change the 18-function registry, add multi-supplier allocation or broaden scope.

### 7.2 Smallest later UI follow-up

Implement only `Rà soát số lượng nhu cầu` against the approved PA-06D-H1 boundary. Include Vietnamese preview/confirmation, stale and ambiguous-outcome handling, exact returned snapshot, authorized readback and audit link. Do not enable allocation edits until a separate split-allocation backend contract is approved.

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

Verified on 2026-07-18 in the canonical repository and task branch:

- local starting `main` and `origin/main` both resolved to `f25acededa6750f6ab08326333bff588e437f41b`, which includes merged PR #112;
- `pnpm ops:workspace` passed and identified the intended repository, origin and branch;
- `pnpm install --frozen-lockfile` reported the workspace already up to date;
- `pnpm format` passed;
- the five new PA-06D documents passed an explicit Prettier check;
- relative Markdown file links in the five deliverables and four minimally linked documents resolved locally;
- `git diff --check` passed before staging and `git diff --cached --check` passed on the exact nine-file staged scope;
- no wider frontend suite was run because the diff is documentation-only and no focused failure or CI requirement called for it.
