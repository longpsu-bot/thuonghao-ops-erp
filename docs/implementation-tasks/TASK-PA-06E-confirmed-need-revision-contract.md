# TASK-PA-06E — Confirmed Need Revision Contract

**Status:** Documentation task complete when its pull request is reviewed; no implementation is authorized

**Task type:** Architecture, decision, and future-slice definition only

**Starting baseline:** `14e80aba28ddfc1d2abfe71a7add83512a455647` (merged PA-06D / PR #113)

**Task branch:** `docs/pa-06e-confirmed-need-revision-contract`

**Architecture contract:** [PA-06E Confirmed Need Review, Adjustment, Revision, and Source-Correction Contract](../architecture/pa-06e-confirmed-need-review-adjustment-revision-contract.md)

**Decision record:** [Decision PA-06E Confirmed Need Source Correction](../decisions/decision-pa-06e-confirmed-need-source-correction.md)

## 1. Objective

Define the smallest transferable contract for school-catering staff to review calculated requirement, confirm or adjust operational need, respond to corrected upstream sources, approve a complete batch snapshot, and release an exact Planning commitment for a later Purchase Handoff.

The task resolves the PA-06D architectural question by retaining the existing `ConfirmedNeedBatch` / `ConfirmedNeedLine` / `ConfirmedNeedLineRevision` aggregate. It does not add a Planning Quantity Confirmation, generic Quantity Decision, editable Purchase Handoff, or cross-domain workflow object.

## 2. Authority and evidence reviewed

The task is governed by repository documentation first, then merged migrations/tests, then application prototypes. The review covered:

- the product charter, system map, domain model, module boundaries, security, calculation, and API standards;
- the decision register and business-rule register;
- PA-01 through PA-04 persistence, revision, security, and Confirmed Need evidence;
- PA-05A, PA-05B, PA-05D, and PA-05E command, authorization, receipt, lineage, and direct-wholesale behavior;
- Planning Need Generation, Confirmed Need, Purchase Handoff, source-governance, and unit contracts;
- PA-06A registry and UI-contract boundary, PA-06C task evidence, and all PA-06D architecture, rule, decision, UI, and task records.

No approved-document conflict was found. The existing physical model already supports stable lines, predecessor-linked revisions, separate theoretical and confirmed quantities, immutable approval snapshots, explicit reopen, and separate release. `PA-05D.v1` additionally proves direct-wholesale pass-through equality and must remain unchanged.

## 3. Documentation deliverables

This branch contains exactly these new deliverables:

1. [PA-06E architecture contract](../architecture/pa-06e-confirmed-need-review-adjustment-revision-contract.md)
2. [PA-06E decision record](../decisions/decision-pa-06e-confirmed-need-source-correction.md)
3. this implementation-task record

It also adds minimal navigation or compatibility references in:

- [Architecture roadmap](../architecture/roadmap.md)
- [PA-05D Planning command family](../architecture/pa-05d-planning-command-family-contract.md)
- [PA-06D quantity-truth contract](../architecture/pa-06d-quantity-truth-rounding-rebalancing-contract.md)
- [PA-06D quantity-truth decision](../decisions/decision-pa-06d-quantity-truth-and-write-fidelity.md)
- [Decision register](../decisions/decision-register.md)

## 4. Accepted directions recorded by this task

- Calculated Requirement is exact calculation evidence; Theoretical Quantity is that evidence on an exact Confirmed Need line revision.
- Confirmed Quantity is Planning decision evidence only after explicit confirmation; a system-created value is labeled as a proposal until then.
- Released Confirmed Quantity comes only from an immutable approved snapshot released by Planning.
- Existing Confirmed Need line revisions carry source correction and operator adjustment; no separate confirmation aggregate is required.
- A corrected recipe, BOM, menu, attendance count, unit conversion, source mapping, or ingredient activation creates new source/calculation evidence and a pending-review Confirmed Need revision. It does not rewrite prior facts.
- Review is line-level; approval and release are complete-batch actions. Partial release is not supported absent new evidence and approval.
- Direct-wholesale remains exact pass-through and `PA-05D.v1` remains unchanged.
- Purchase consequence shown in Planning is advisory only; Procurement remains authoritative for purchasable quantity, allocation, PO, and Dispatch lineage.
- Production operational policies must be versioned and fail closed. The `0.01 kg` Planning step and `0.1 kg` advisory purchase step are fixtures only.
- Proposed functions and capabilities in PA-06E are not additions to the canonical PA-06A registry.

## 5. Later first backend slice — proposed, not authorized here

### 5.1 Bounded scenario

Use one synthetic school-catering line with:

- stable Confirmed Need line identity;
- one exact source/calculation revision;
- one authenticated Planning actor and approved school/date scope;
- one effective versioned Planning policy using a `0.01 kg` fixture step;
- one theoretical quantity and one proposed confirmed quantity;
- one governed reason when the confirmed result differs;
- one backend preview;
- one preview-bound confirmation command;
- one exact result, authoritative readback, receipt, event, and audit record.

### 5.2 Proposed callable boundary

The first slice may propose only:

1. `atlas_api.get_confirmed_need_review(request jsonb) returns jsonb`
2. `atlas_api.preview_confirmed_need_confirmation(request jsonb) returns jsonb`
3. `atlas_api.confirm_need_quantities(request jsonb) returns jsonb`

Names, capabilities, schemas, ownership, and grants remain pending until the implementation task performs security review and explicitly updates the canonical registry.

### 5.3 Preview/commit acceptance

The later confirmation command must:

- require the exact line revision, calculation/source revision, policy version, expected batch version, preview hash/token, idempotency key, and actor scope used by preview;
- reject stale, mismatched, ambiguous, invalid, or unauthorized input without partial writes;
- recompute or verify authoritative results inside the backend boundary;
- create or bind the intended decision revision according to the approved material-revision policy;
- increment the batch concurrency version exactly once for one committed command;
- preserve unchanged lines and all historical revisions;
- return an exact receipt and authoritative readback that match what the UI showed;
- record actor, reason, request hash, predecessor/current identity, event, and audit evidence.

### 5.4 Explicit exclusions from the first slice

The first slice does not include batch approval, batch release, CMD-03, Purchase Handoff, Procurement allocation, PO, Dispatch, downstream correction, direct-wholesale behavior, production data, live queues, UI, or deployment.

## 6. Future implementation test blueprint

A later approved backend task must provide focused automated tests for:

### 6.1 Calculation and policy

- exact high-scale theoretical calculation remains distinguishable from Planning operational precision;
- `0.01 kg` fixture quantization is deterministic and does not derive from numeric column scale;
- a missing, ambiguous, expired, malformed, zero, or negative effective Planning step fails closed;
- the policy version used by preview is the policy version committed;
- the `0.1 kg` purchase consequence is visibly advisory and creates no Procurement fact.

### 6.2 Revision and history

- a material operator change creates the expected predecessor-linked successor and supersedes only the prior current revision;
- a recipe or BOM correction creates new calculation evidence and a pending-review successor;
- prior approved and released revisions and snapshot lines remain byte-for-byte stable;
- accepting an unchanged proposal follows the approved no-noise rule and still records explicit decision evidence;
- exact zero remains traceable and follows the approved zero-release policy;
- stable line identity is preserved when business identity is unchanged and is not reused when ingredient or scope identity changes.

### 6.3 Preview, concurrency, and idempotency

- preview and commit return the same quantities, rule version, reason consequence, and display-ready exact value;
- an expected-batch-version mismatch rejects with no writes;
- a changed line revision, source/calculation revision, policy version, preview token, or scope rejects as stale;
- same idempotency key plus same request replays one receipt and creates no extra revision/event/audit record;
- same idempotency key plus different request returns conflict;
- one multi-line confirmation, when later approved, increments the batch version once and changes only intended lines.

### 6.4 Authorization and safe errors

- browser/authenticated roles have no direct private-table access;
- read, preview, and confirm each require their exact capability and current effective school/date scope;
- cross-school, cross-date, expired assignment, missing actor mapping, and insufficient capability fail closed;
- safe error envelopes contain no SQL text, private schema name, policy internals, or confidential row data;
- function ownership, fixed empty search path, grants, and absence of dynamic SQL meet the security contract.

### 6.5 Batch and downstream gates for later slices

- stale, invalid, or unreviewed lines block full-batch approval;
- approval snapshots exact current revisions and increments batch version once;
- release consumes the exact approved snapshot and is separate from approval;
- corrected sources after approval/release require explicit reopen and a new snapshot/release;
- school-catering CMD-03 rejects a stale or incompatible release when that contract is later approved;
- direct-wholesale theoretical, confirmed, approved, released, and handoff quantities remain exactly equal under existing PA-05D tests;
- no correction silently mutates a Handoff, PO, Dispatch Requirement, or physical evidence.

## 7. Documentation-task acceptance criteria

- [x] Use the merged PA-06D commit as the clean starting baseline.
- [x] Define the five-state Confirmed Need batch lifecycle and four-state line-revision lifecycle without adding statuses.
- [x] Distinguish Calculated Requirement, Theoretical Quantity, Confirmed Quantity, and Released Confirmed Quantity.
- [x] Compare adjustment/revision alternatives and recommend the smallest audit-safe model.
- [x] Define source corrections for recipe quantity/ingredient, BOM quantity/ingredient, menu dish, attendance/meal count, unit conversion, school/date/source mapping, and ingredient activation.
- [x] Define behavior before approval, after approval, after release, after handoff, and after PO/Dispatch.
- [x] Include the `10.234 kg` / `10.20 kg` / recipe revision 7 / Confirmed Need revision 3 / later `10.654 kg` example.
- [x] Preserve direct-wholesale pass-through and CMD-03 compatibility.
- [x] Define WYSIWYG preview/commit, proposed API delta, authorization, errors/recovery, Vietnamese-term status, first slice, and tests.
- [x] Record eighteen decision rows and distinguish approved from pending choices.
- [x] Add only the three requested documents and five minimal cross-references.
- [x] Make no executable, registry, package, live-system, or deployment change.

## 8. Validation record

Validation on 2026-07-19:

- `pnpm ops:workspace` — passed on the exact task branch and canonical origin; expected working-tree changes were reported.
- `pnpm install --frozen-lockfile` — passed; lockfile was already up to date.
- `pnpm format` — passed; every file in the routine repository format scope matched Prettier.
- explicit Prettier `--check` of the three new PA-06E files — passed after formatting the two new files that required it.
- `git diff --check` — passed.
- relative Markdown-link validation — passed for all eight changed Markdown files.
- targeted content assertions — passed for exactly eight Markdown changes, eighteen decision rows, nine correction types, five timing windows, six proposed APIs, existing-aggregate choice, quantity separation, direct-wholesale equality, source-revision behavior, immutable prior facts, unchanged CMD-03 boundary, Procurement ownership, and pending-decision labels.

The routine full frontend format/typecheck/test/build suite remains owned by GitHub Actions under `Frontend CI / Format, typecheck, test, build`.

## 9. Prohibited changes

Do not add or modify SQL, migrations, functions, grants, RLS, generated types, React, Storybook, packages, Retool, Supabase project configuration, production data, OPS v1, credentials, deployment, or the canonical API registry. Do not implement approval, release, handoff, Procurement, PO, Dispatch, or direct-wholesale behavior.

Do not introduce a new business aggregate, generic decision framework, partial release, silently mutable released document, or cross-domain workflow without a separately approved ADR or task.

## 10. Publication boundary

Publish this task as a draft pull request titled `PA-06E: Define Confirmed Need revision and source-correction contract`. The pull request must remain draft, unmerged, and undeployed. Its description must state that PA-06D is the merged prerequisite; calculated and confirmed quantities remain distinct; existing Confirmed Need is retained; no Planning Quantity Confirmation is added; direct-wholesale is unchanged; no backend or UI behavior changed; no Supabase, Retool, or production state changed; and proposed APIs are not canonical registry entries.

## 11. Migration and rollback effect

There is no migration or operational rollback. The branch changes Markdown only and can be reverted through normal Git history.
