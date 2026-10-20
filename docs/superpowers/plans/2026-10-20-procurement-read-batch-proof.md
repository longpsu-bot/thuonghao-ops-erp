# Procurement read batch proof repair

> Use superpowers:executing-plans for this bounded repair and one final independent review.

**Goal:** Load Allocation and Purchase Orders for the existing reopened 236-line Staging batch within the unchanged authenticated eight-second budget.

**Spec:** Existing K2 corrected-source authority and K3 operator read contracts; `docs/api/school-catering-procurement.md` and `docs/implementation-tasks/TASK-ATLAS-C-K3-OPERATOR-INTEGRATION-01.md`.

**Diagnosis:** Both exact authenticated read requests for 2026-10-12 time out in the same canonical facts projection. A single family proof takes 1,147 ms and reconstructs all 236 lines. Repeating this proof per family cannot meet the budget. The retained date range is intentional and is not the failure cause.

**Scope:** One forward migration, the existing released Allocation scale regression (extended through a genuine post-release correction), and this ledger. Private read helpers may receive a context computed once inside the authenticated read statement. Preserve every original closed-batch predicate, canonical family selector, capability/scope check, owner, RLS rule, source lock, writer, public request/response shape, and historical document. No stored cache, supplied authority, timeout increase, business command replay, OPSv1/Retool write, or automatic date/draft change.

- [x] Extend the existing 236-family fixture with an official quantity correction; observe Allocation and PO read failures under eight seconds.
- [x] Reuse the exact K2 closed-batch proof once per batch in private read context; thread that context through existing read helpers only.
- [x] Pass scale reads, canonical parity/tamper and authorization regressions. Independently review the complete change.
- [ ] Run normal GitHub validation, merge and deploy through the already authorized protected Staging path; verify exact read results and unchanged business data. Preserve user drafts during browser verification.

## Evidence ledger

- Base: main `61c84afafe8701b499fc54305e4c6f48ddba0e5e`; clean authorized E: checkout, verified remote and workspace.
- Staging: migration 120; both reads fail with SQLSTATE 57014 at eight seconds. Facts projection alone: 306 ms; canonical evaluation: 174 ms; one exact family proof: 1,147 ms.
- Interfaces: the context is created from current database facts inside a read statement and is executable only by internal roles. No context parameter is accepted by public RPCs. Commands keep their existing authority path.
- RED: after a genuine official v3 correction, both 236-family reads exceed eight seconds. Ordinary released reads still pass. Fixture setup defers constraints before the correction, matching the existing transactional command tests.
- Isolated GREEN: Allocation 1,441 ms, PO 1,350 ms; exactly one closed-batch proof per read, all 236 families returned, only the corrected family changes source, and business facts/receipts remain identical. Overlapping local suites produced additional timeouts; performance suites run sequentially.
- Existing K2/School/source/history suite: 153/153 PASS. Normal full frontend and database certification for the previous installed main also completed PASS.
- Final extended scale/security/parity suite: 28/28 PASS; Allocation 1,456 ms and PO 1,279 ms. New helpers reject all public request roles; read and command proofs/selectors match exactly for both corrected and unchanged families, and the affected Draft remains stale. Independent whole-branch source/security review: no actionable findings.
- Migration adds private context readers for the existing layered read chain. It retains original helper bodies and execution-role recipients; future changes to these canonical predicates must update their context readers together. Original commands, locks, public RPC shapes, original owners/ACLs, and released documents are unchanged. Recovery is a forward migration restoring the two read entry bodies; no data rollback is needed.
