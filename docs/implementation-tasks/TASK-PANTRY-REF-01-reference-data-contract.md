# TASK-PANTRY-REF-01 — Define Pantry Reference-Data Contract

- **Status:** Documentation complete; draft PR review pending
- **Baseline:** `dd1c20d13af98cd7804436c54e469f5856d06326`
- **Branch:** `docs/pantry-ref-01-reference-data-contract`
- **Task type:** Documentation and product decision only

## 1. Objective

Define the mandatory Pantry Purpose and existing-reference readiness contract
that must be approved before PANTRY-02.

This task does not implement the contract and does not begin PANTRY-02.

## 2. Authority reviewed

- `AGENTS.md`
- `README.md`
- `docs/handbook/01-vision-product-charter.md`
- `docs/business-rules/business-rule-register.md`
- `docs/architecture/pantry-01-planning-owned-pantry-source-contract.md`
- `docs/decisions/decision-pantry-01-planning-owned-pantry-source.md`
- `docs/implementation-tasks/TASK-PANTRY-01-planning-owned-pantry-source-contract.md`
- `docs/architecture/rmvp-01-independent-atlas-master-data.md`
- `docs/architecture/pa-02-physical-schema-and-constraint-design.md`
- `docs/architecture/roadmap.md`
- `docs/decisions/decision-register.md`
- implemented Customer, School, Delivery Location, Ingredient, Unit, and
  `ingredients.purchase_unit_id` migrations and focused acceptance evidence
- retained `OPS - Lên đơn, Đặt hàng (1)` Retool JSON, verified directly at
  SHA-256
  `6F6FF8D025696D375F354A86126661D20C3E9908D6475D40ECB14EE006B4A371` and
  used only as read-only operational evidence

## 3. Deliverables

- [PANTRY-REF-01 architecture contract](../architecture/pantry-ref-01-reference-data-contract.md)
- [PANTRY-REF-01 decision record](../decisions/decision-pantry-ref-01-reference-data.md)
- this bounded task record
- accepted decision-register entry and concise roadmap status/link update

The architecture contract owns the sole complete Pantry Purpose registry.

## 4. Bounded scope

PANTRY-REF-01 documents:

- accepted stable Purpose codes;
- Vietnamese operator labels and concise meanings;
- initial Purpose statuses and display order;
- note rules, permitted uses, and prohibited interpretations;
- School readiness;
- Delivery Location readiness;
- Ingredient readiness;
- server-resolved Ingredient purchase-Unit readiness;
- the zero-additions boundary;
- the unchanged PANTRY-02 limit; and
- the Product Owner approval record for `PREF-A01` through `PREF-A09`.

## 5. Product Owner approval

Repository and retained operational evidence did not establish the exact
production Purpose vocabulary. The architecture contract therefore presented
every proposed Purpose row and assumption for explicit review.

On 2026-07-28, the Product Owner explicitly approved:

- both canonical Pantry Purpose rows exactly as proposed;
- the exact codes, Vietnamese labels, meanings, initial statuses, display
  orders, note rules, permitted uses, and prohibited interpretations; and
- `PREF-A01` through `PREF-A09` exactly as proposed, including the active
  parent Customer gate and default-Delivery-Location-only first slice.

The product gate is closed. This approval permits documentation publication
only. PANTRY-02 remains blocked until this contract is merged and PANTRY-02 is
separately authorized.

## 6. Acceptance criteria

1. one canonical Purpose registry contains every required field and approval
   status;
2. no Purpose code derives from a numeric legacy ID;
3. no `OTHER`, free-text-only, or `NO_ADDITIONS` Purpose exists;
4. Purpose and note rules apply only to positive active Pantry lines;
5. School, Delivery Location, Ingredient, and Unit gates are exact and typed;
6. Unit remains backend-resolved from `ingredients.purchase_unit_id`;
7. supplier eligibility and Warehouse stock do not gate Pantry capture;
8. PANTRY-02 remains exactly five relations, at most six APIs, at most one new
   capability, zero new roles, and one bounded migration;
9. all relative links resolve;
10. targeted Markdown formatting and `git diff --check` pass; and
11. the diff contains documentation only.

## 7. Explicit exclusions

PANTRY-REF-01 authorizes no:

- SQL, migration, relation, column, trigger, or function;
- seed row, fixture promoted as authority, or production-data change;
- API, command, event, capability, role, policy, grant, or runtime change;
- React, generated type, package, or build behavior;
- hosted Supabase action or credential;
- OPS v1, OPS v2, or Retool mutation;
- Planning Input Readiness or Need Generation change; or
- PANTRY-02 implementation.

## 8. Validation

Before publication, run:

```text
pnpm ops:workspace
targeted formatting for changed Markdown documents
relative Markdown-link validation
git diff --check
documentation-only scope validation
```

Database tests are not required solely for this documentation task.

## 9. Publication boundary

Following Product Owner approval:

1. record approval in the architecture and decision documents;
2. update the decision register and roadmap consistently;
3. rerun local documentation validation;
4. commit the documentation;
5. push this bounded branch;
6. open one draft pull request titled
   `PANTRY-REF-01: Define Pantry reference data contract`;
7. keep the pull request draft and do not merge; and
8. report the exact head SHA, workflow status, and all unresolved questions.

Approval of this documentation does not authorize production Purpose seed or
PANTRY-02.

## 10. Migration, security, and rollback effect

There is no database, hosted, or production effect. Security roles, scopes,
capabilities, policies, grants, and runtimes are unchanged. Documentation
rollback is a normal Git revert.
