# Atlas Procurement Cutover Rehearsal Plan

> Execute inline using the existing verification workflow.

Goal: certify the released 2026-10-12 Procurement state through authenticated hosted HTTP, then normal connected operator reads.

Authority: Product's two-phase request and authorization to use a temporary protected GitHub Actions runner.

## Scope

Only scripts/atlas-procurement-cutover*.mjs, focused harness tests, this record, and conditional wiring in the existing Planning Performance workflow.
No application edits, dependencies, migrations, deployment, preparation, allocation saves, PO commands, Supplier changes, Retool, or OPS v1.
The runner checks out certified main a9230321161ce62da3572b3d5ae9f3d78f71ac42; its separate workflow revision supplies the harness after clean preflight.

## Execution

- [ ] Test rejection of wrong quantities, notes, contribution lineage, duplicate identity, mismatched authority, timeout, and changed snapshots.
- [ ] Run Phase A with the existing protected identity and hosted RPC; require HTTP/business success, 236 exact accepted rows, <8000ms, and unchanged authoritative snapshots.
- [ ] Stop on Phase A failure with evidence; make no repair.
- [ ] On Phase A pass, run the connected frontend's normal read/navigation/refresh/reopen journey for the selected date, reconcile 17 Draft POs/236 lines, inspect high/low line-count POs, and exercise eligible exports.
- [ ] Record disabled official Draft exports explicitly; never release a PO to enable export.
- [ ] Capture screenshots, safe logs, export artifacts, before/after hashes and final report; stop after acceptance.

Security: use existing protected test credentials and browser-safe key for HTTP; Management SQL is BEGIN READ ONLY / ROLLBACK evidence only. Never upload credentials or session tokens.
Migration/rollback: none; temporary runner branch is not merged into main.
