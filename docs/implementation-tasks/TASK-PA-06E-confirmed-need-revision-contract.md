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

The correction pass also reread the exact merged PA-04/PA-05D migrations and the product/architecture review on PR #114. Five conflicts or incompletenesses were reconciled explicitly:

| Finding                                  | Governing evidence                                                                                                                                                        | Corrected PA-06E position                                                                                                                                   |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Business reuse versus physical readiness | The parent contract defines generic Confirmed Need; PA-04 requires `wholesale_order_id`, `wholesale_order_line_id`, and `wholesale_order_line_revision_id`.               | Retain the aggregate, but require H0 school-catering source generalization before H1; fake wholesale lineage is prohibited.                                 |
| Line decision evidence                   | The parent defines `ConfirmedNeedAdjustment`; PA-02 proposes append-only evidence; PA-04 omits it and exposes only revision creator/command plus batch approval evidence. | Treat line decision evidence as a persistence gap and recommend a hybrid revision-payload plus append-only evidence model, pending H0.                      |
| Missing validation transition            | The parent defines `VALIDATED`, `ValidateConfirmedNeeds`, `ConfirmedNeedsValidated`, and `ConfirmedNeedValidationFailed`.                                                 | Retain proposed `validate_confirmed_needs`; approval requires its exact validated batch version.                                                            |
| Row immutability wording                 | Current revisions contain mutable `is_current` and `revision_status`.                                                                                                     | Freeze revision payload; allow controlled current/status supersession metadata; keep snapshots/releases/events/audit/downstream references fully immutable. |
| Missing materialization boundary         | The parent defines `CreateConfirmedNeedsFromGeneration`; PA-05D only materializes wholesale pass-through.                                                                 | H0 must define `create_confirmed_needs_from_generation`; source owners never write a confirmed Planning decision.                                           |

`PA-05D.v1` continues to prove direct-wholesale pass-through equality and remains unchanged.

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
- Existing logical Confirmed Need source-reference/adjustment children carry source and decision semantics; current PA-04 physical tables do not yet persist school-catering lineage or complete line evidence. No separate confirmation aggregate is required.
- A corrected recipe, BOM, menu, attendance count, unit conversion, source mapping, or ingredient activation is versioned by its owner; Need Generation calculates; a controlled Planning materialization boundary creates the pending-review Confirmed Need consequence. It does not rewrite prior payloads or facts.
- Review is line-level; validation, approval, and release are separate complete-batch actions. Partial release is not supported absent new evidence and approval.
- Revision quantity/item/unit/source/creation payload is immutable; only current/status lifecycle metadata may change on supersession. Snapshots and downstream references are fully immutable.
- Direct-wholesale remains exact pass-through and `PA-05D.v1` remains unchanged.
- Purchase consequence shown in Planning is advisory only; Procurement remains authoritative for purchasable quantity, allocation, PO, and Dispatch lineage.
- Production operational policies must be versioned and fail closed. The `0.01 kg` Planning step and `0.1 kg` advisory purchase step are fixtures only.
- Proposed functions and capabilities in PA-06E are not additions to the canonical PA-06A registry.
- H0 persistence/source generalization and materialization must precede H1 one-line read/preview/confirm.

## 5. Corrected future backend sequence — proposed, not authorized here

### 5.1 PA-06E-H0 — school-catering persistence/source generalization and materialization contract

H0 must separately define and obtain approval for:

- a governed physical implementation of logical `ConfirmedNeedSourceReference` using dedicated and/or typed relational children consistent with PA-02;
- removal/generalization of the required wholesale-only source dependency for school-catering rows while preserving `PA-05D.v1` compatibility;
- a physical line decision-evidence model for actor/time, reason, before/after, rule/source set, exact revision/batch version, command, and unchanged acceptance;
- the Planning-owned/integration-authorized `create_confirmed_needs_from_generation` materialization boundary for initial and corrected generation results;
- migration/backfill/rollback, private-table security, runtime ownership, grants/RLS, idempotency, locks, events/audit, and focused database tests.

Source-reference options to evaluate are a dedicated child, declared typed relations, or a bounded typed child family. Decision-evidence options are an append-only child, bounded revision metadata, or the recommended hybrid. Exact physical choices remain pending. H0 must reject fake wholesale records, free-text polymorphic IDs, caller-authored table names, and generic unvalidated JSON lineage.

This PR writes no H0 DDL, migration, command, grant, or test.

### 5.2 PA-06E-H1 — one-line authorized read, preview, and confirmation

H1 may begin only after the H0-generalized physical model exists. Its one synthetic school-catering line includes:

- stable Confirmed Need line identity without wholesale lineage;
- one exact Need Generation/source revision and governed source-reference set;
- one authenticated Planning actor and approved school/date scope;
- one effective versioned Planning policy using a `0.01 kg` fixture step;
- one theoretical quantity and one proposed confirmed quantity;
- one explicit unchanged or adjusted line decision-evidence result;
- one backend preview and preview-bound confirmation;
- one exact result, authoritative readback, receipt, event, audit, and append-only line decision record.

An H1 test fixture may provision the starting line locally instead of executing materialization, but only against the already generalized H0 schema. It cannot fake wholesale references.

### 5.3 Proposed callable/dependency boundary

H0 must contract the noncanonical materialization gap:

1. `atlas_api.create_confirmed_needs_from_generation(request jsonb) returns jsonb`

H1 may propose only:

1. `atlas_api.get_confirmed_need_review(request jsonb) returns jsonb`
2. `atlas_api.preview_confirmed_need_confirmation(request jsonb) returns jsonb`
3. `atlas_api.confirm_need_quantities(request jsonb) returns jsonb`

Later lifecycle work must retain:

1. `atlas_api.validate_confirmed_needs(request jsonb) returns jsonb`
2. `atlas_api.approve_confirmed_need_batch(request jsonb) returns jsonb`
3. `atlas_api.release_confirmed_need_batch(request jsonb) returns jsonb`
4. `atlas_api.reopen_confirmed_need_batch(request jsonb) returns jsonb`

The review/lifecycle family therefore has seven functions; materialization is a separate H0 prerequisite. All names, capabilities, schemas, ownership, grants, and registry entries remain pending.

### 5.4 Preview/commit acceptance

The later confirmation command must:

- require the exact line revision, calculation/source revision, policy version, expected batch version, preview hash/token, idempotency key, and actor scope used by preview;
- reject stale, mismatched, ambiguous, invalid, or unauthorized input without partial writes;
- recompute or verify authoritative results inside the backend boundary;
- create a successor only for a material payload change, or bind append-only unchanged-acceptance evidence to the exact current Draft revision;
- increment the batch concurrency version exactly once for one committed command;
- preserve unchanged lines and every historical revision payload while allowing controlled current/status supersession metadata;
- return an exact receipt and authoritative readback that match what the UI showed;
- record actor/time, reason, before/after, rule/source set, batch/revision versions, request hash, predecessor/current identity, unchanged/adjusted acceptance kind, event, and audit evidence.

### 5.5 Explicit exclusions from H1

H1 does not include materialization execution, complete-batch validation, approval, release, CMD-03, Purchase Handoff, Procurement allocation, PO, Dispatch, downstream correction, direct-wholesale behavior, production data, live queues, UI, or deployment.

## 6. Future implementation test blueprint

A later approved backend task must provide focused automated tests for:

### 6.1 H0 persistence and materialization

- current merged schema assertions prove all three required Confirmed Need source fields are wholesale-specific;
- school-catering materialization cannot use fake wholesale records, free-text polymorphic IDs, caller-authored table names, or generic unvalidated JSON lineage;
- governed source references bind exact generation/source revisions through typed relational constraints;
- `create_confirmed_needs_from_generation` creates/refreshes Draft lines and non-authoritative proposals but never confirms Planning authority;
- corrected generation creates explicit successor Draft revisions or new stable lines without changing old payloads;
- append-only line evidence captures changed and unchanged acceptance with actor/time, before/after, reason, rule/source, exact versions, and command; and
- PA-05D direct-wholesale schema, functions, equality, and tests remain unchanged.

### 6.2 Calculation and policy

- exact high-scale theoretical calculation remains distinguishable from Planning operational precision;
- `0.01 kg` fixture quantization is deterministic and does not derive from numeric column scale;
- a missing, ambiguous, expired, malformed, zero, or negative effective Planning step fails closed;
- the policy version used by preview is the policy version committed;
- the `0.1 kg` purchase consequence is visibly advisory and creates no Procurement fact.

### 6.3 Revision and history

- a material operator change creates the expected predecessor-linked successor and supersedes only the prior current revision;
- a recipe or BOM correction creates new calculation evidence and a pending-review successor;
- prior revision quantity/item/unit/source/predecessor/creation/command payload remains unchanged, while controlled `is_current`/status metadata may transition on supersession;
- approval snapshots, snapshot lines, release evidence, receipts, events, audit, and downstream references remain fully unchanged;
- accepting an unchanged proposal follows the approved no-noise rule and still records explicit decision evidence;
- exact zero remains traceable and follows the approved zero-release policy;
- stable line identity is preserved when business identity is unchanged and is not reused when ingredient or scope identity changes.

### 6.4 Preview, concurrency, and idempotency

- preview and commit return the same quantities, rule version, reason consequence, and display-ready exact value;
- an expected-batch-version mismatch rejects with no writes;
- a changed line revision, source/calculation revision, policy version, preview token, or scope rejects as stale;
- same idempotency key plus same request replays one receipt and creates no extra revision/event/audit record;
- same idempotency key plus different request returns conflict;
- one multi-line confirmation, when later approved, increments the batch version once and changes only intended lines.

### 6.5 Authorization and safe errors

- browser/authenticated roles have no direct private-table access;
- read, preview, and confirm each require their exact capability and current effective school/date scope;
- cross-school, cross-date, expired assignment, missing actor mapping, and insufficient capability fail closed;
- safe error envelopes contain no SQL text, private schema name, policy internals, or confidential row data;
- function ownership, fixed empty search path, grants, and absence of dynamic SQL meet the security contract.

### 6.6 Validation, batch, and downstream gates for later slices

- successful validation produces an exact `VALIDATED` batch version and `ConfirmedNeedsValidated` evidence;
- failed validation leaves the batch unapproved and returns/persists governed issues with `ConfirmedNeedValidationFailed` under the later command contract;
- approval requires the exact validated version/line/decision set and rechecks critical invariants;
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
- [x] Record twenty-six decision rows and distinguish approved from pending physical/product choices.
- [x] Separate reusable business semantics from wholesale-specific physical-schema readiness and prohibit fake wholesale lineage.
- [x] Identify governed source-reference and line decision-evidence persistence as H0 prerequisites.
- [x] Define unchanged-proposal acceptance through append-only evidence without an identical successor revision.
- [x] Restore `validate_confirmed_needs` for the approved `VALIDATED` transition.
- [x] Separate immutable revision payload from controlled current/status lifecycle metadata.
- [x] Restore `create_confirmed_needs_from_generation` materialization responsibility.
- [x] Sequence H0 before H1 and leave validation/approval/release/CMD-03 for later tasks.
- [x] Add only the three requested documents and five minimal cross-references.
- [x] Make no executable, registry, package, live-system, or deployment change.

## 8. Validation record

Correction-pass validation on 2026-07-19:

- `pnpm ops:workspace` — passed on the exact existing task branch and canonical origin; expected working-tree changes were reported.
- `pnpm install --frozen-lockfile` — passed; the verified lockfile was already up to date.
- `pnpm format` — passed; every file in the routine repository format scope matched Prettier.
- explicit Prettier `--check` of all three corrected PA-06E files — passed after formatting.
- `git diff --check` and `git diff --cached --check` — passed.
- relative Markdown-link validation — passed for all three corrected Markdown files.
- targeted correction assertions — passed for exactly three Markdown changes, twenty-six decision rows, eight API-gap entries, and all five review corrections: wholesale-specific schema limits/fake-lineage prohibition, governed source-reference prerequisite, explicit changed/unchanged line decision evidence, retained validation command/events, immutable payload versus lifecycle metadata, Need Generation materialization, H0-before-H1 order, unchanged `PA-05D.v1`, noncanonical APIs, and documentation-only scope.

The routine full frontend format/typecheck/test/build suite remains owned by GitHub Actions under `Frontend CI / Format, typecheck, test, build`.

## 9. Prohibited changes

Do not add or modify SQL, migrations, functions, grants, RLS, generated types, React, Storybook, packages, Retool, Supabase project configuration, production data, OPS v1, credentials, deployment, or the canonical API registry. Do not implement H0, H1, materialization, validation, approval, release, handoff, Procurement, PO, Dispatch, or direct-wholesale behavior.

Do not introduce a new business aggregate, fake wholesale lineage, polymorphic free-text source IDs, caller-authored table names, generic unvalidated JSON lineage, generic decision framework, partial release, silently mutable released document, or cross-domain workflow without a separately approved ADR or task.

## 10. Publication boundary

Publish this task as a draft pull request titled `PA-06E: Define Confirmed Need revision and source-correction contract`. The pull request must remain draft, unmerged, and undeployed. Its description must state that PA-06D is the merged prerequisite; calculated and confirmed quantities remain distinct; existing Confirmed Need is retained; current physical persistence is wholesale-specific; H0 source/evidence generalization and materialization must precede H1; validation is restored; no Planning Quantity Confirmation is added; direct-wholesale is unchanged; no backend or UI behavior changed; no Supabase, Retool, or production state changed; and proposed APIs are not canonical registry entries.

## 11. Migration and rollback effect

There is no migration or operational rollback. The branch changes Markdown only and can be reverted through normal Git history.
