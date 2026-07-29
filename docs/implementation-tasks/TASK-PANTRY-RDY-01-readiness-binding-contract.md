# TASK-PANTRY-RDY-01 — Pantry Readiness-Binding Contract

- **Status:** Documentation finalized and locally validated; pending draft-PR
  review and merge
- **Approval date:** 2026-07-29
- **Starting baseline:** `fbcb0016245028f8e845fe79a1d568e92166ce52`
- **Branch:** `docs/pantry-rdy-01-readiness-binding-contract`
- **Canonical decision:** [Decision PANTRY-RDY-01](../decisions/decision-pantry-rdy-01-planning-input-readiness.md)
- **Architecture amendment:** [PANTRY-RDY-01 Planning Input Readiness Amendment](../architecture/pantry-rdy-01-planning-input-readiness-amendment.md)

## Objective

Amend Planning Input Readiness so that every new `READY` evaluation and every
new Need Generation request requires one exact current approved Weekly Menu,
Attendance, and Pantry snapshot through distinct direct typed immutable
bindings.

This task is documentation and product-decision work only. It does not begin
PANTRY-RDY-02 or the Pantry Need Generation amendment.

## Recovery record

The previously assumed branch and uncommitted draft did not survive. The
recovery-first investigation found:

- no local or remote `*pantry-rdy*` branch;
- no additional Git worktree;
- no matching path history or PANTRY-RDY reflog entry;
- no matching content in either retained stash;
- no matching filename or registry marker in unreachable Git commits, trees,
  or blobs; and
- no exact draft filename under the available `D:\Project` root. The previously
  referenced `E:\Project` root was not present on this machine.

Recovery therefore used authorized Case C. The branch was created from the
exact approved baseline and the documentation was reconstructed from approved
repository authority and the Product Owner-approved registry.

## Accepted documentation outcome

The sole canonical accepted decision registry is the linked PANTRY-RDY-01
decision. It establishes:

- Pantry as the mandatory third readiness source;
- the exact Pantry batch/snapshot/version binding;
- independent full period containment for all three source families;
- equivalent positive and explicit zero-line Pantry approval evidence;
- current approved Pantry snapshot eligibility;
- immutable prior evaluations and successor re-evaluation;
- explicit invalidation with no automatic source trigger;
- the bounded Pantry blocker and issue-context extensions;
- unchanged Menu/Attendance warnings; and
- no downstream calculation or operational mutation.

The parent architecture contract and H0A4 decision are amended only where their
two-source statements and related readiness/request rules became stale. The
stable exact-period root, immutable evaluation versions and issues, closed
lifecycle, warning acknowledgement deferral, and evidence-only handoff remain
unchanged.

## Historical compatibility

Pre-PANTRY-RDY-02 evaluations remain immutable and may retain null Pantry
binding fields. They remain historical evidence but cannot authorize a new
Need Generation request after the amendment. A current root relying on that
evidence must be explicitly invalidated and re-evaluated with one exact
approved Pantry snapshot. No historical binding is backfilled or fabricated.

## Future PANTRY-RDY-02 boundary

The later implementation is limited to one migration, zero new relations, zero
public APIs, zero capabilities, zero roles or runtime roles, zero scope kinds,
zero policies, and zero automatic source triggers.

Expected work is limited to three nullable Pantry binding columns, one
all-null-or-all-present constraint, one direct composite ownership foreign key,
one supporting snapshot unique constraint when required, one leading binding
index, issue-code and input-type extensions, amendments to existing readiness
guards, and in-place updates to the three canonical readiness pgTAP suites.
Neither a fourth readiness relation nor a fourth readiness test suite is
authorized.

## Exact documentation boundary

The task changes exactly:

1. `docs/architecture/pantry-rdy-01-planning-input-readiness-amendment.md`;
2. `docs/decisions/decision-pantry-rdy-01-planning-input-readiness.md`;
3. `docs/implementation-tasks/TASK-PANTRY-RDY-01-readiness-binding-contract.md`;
4. `docs/architecture/planning-domain-input-readiness-contract.md`;
5. `docs/decisions/decision-pa-06e-h0a4-planning-input-readiness.md`;
6. `docs/decisions/decision-register.md`; and
7. `docs/architecture/roadmap.md`.

No eighth file is authorized.

## Validation record

- `pnpm ops:workspace`: PASS;
- `pnpm format`: PASS;
- targeted Prettier validation of all seven changed Markdown files: PASS;
- `git diff --check`: PASS;
- relative Markdown-link validation: PASS;
- exact seven-file documentation-only scope validation: PASS;
- canonical registry and registry-uniqueness validation: PASS;
- stale two-source-authority search: PASS;
- decision-register entry uniqueness validation: PASS; and
- roadmap status validation: PASS.

Database tests were intentionally not run for this documentation-only task.

## Migration, security, and rollback

PANTRY-RDY-01 has no migration or runtime effect. Rollback is documentation
only: revert this bounded documentation commit. The existing H0A4b and
PANTRY-02 migrations, tests, records, guards, RLS, roles, capabilities, APIs,
and data remain unchanged.

No SQL, migration, database, API, capability, role, policy, package, React,
hosted Supabase, production data, OPS v1/v2, Retool, Need Generation, Confirmed
Need, Purchase Handoff, Procurement, Warehouse, Dispatch, or Wholesale mutation
is part of this task.
