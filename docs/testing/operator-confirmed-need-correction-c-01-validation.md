# Operator C — implemented Draft validation checkpoint

Status: **implemented Draft; acceptance incomplete**. The user requested wrap-up and push on 16 October 2026. Keep PR #388 Draft. No ready status, merge, manual deployment or hosted database write is authorized. Staging remains on accepted migration 109. Automatic Pages previews are separate.

The implementation adds a closed Need-correction preview, one atomic reopen-plus-Save command and exact immutable family continuity for Allocation, PO and PXK. The existing Confirmed Need dirty owner retains the original request through UNKNOWN, exact retry and authoritative readback. Operators explicitly release replacements and successors; old released snapshots remain preserved. Existing capabilities, scopes, GLOBAL requirements and whole-PO disclosure apply. C is independent of unmerged A2/B.

## Final source and completed checks

- Migration `20261015065552_operator_confirmed_need_correction.sql`: LF/applied SHA256 `3669f2740ed4cf9cf273d13cd2c282f33435d03e1da87bb95af3756420340e76`, with 0 CRLF pairs.
- Fresh task-owned forward15 replays 109 exact main Gitblob migrations, ending at `20261014120320`, then applies the complete C file once atomically. This is schema-applied history, without a fabricated CLI ledger. Baseline catalog 30 passes; global roles and schema ACLs restore exactly. All 497 function metadata entries match the previous checkpoint; only the two reviewed context/family-proof bodies changed. No business residue remains.
- **455 focused SQL assertions pass:** correction 103, continuity 108, consumers 58, catalog 31 and PO 155. Every stream has its complete sequential plan. Genuine full-School members, facts, hashes, PH identity and quantity survive grouping; changed-middle, locator-swap, duplicate, NULL, missing and foreign-group cases retain the authority boundaries.
- Four C suites use the existing include-expanding runner and remote Full list. The TAP guard rejects incomplete 84/92 streams, malformed output and bailouts while accepting complete 31+11 and trailing no_plan streams. No new runner or dependency.

Wrap verification: the changed runner/contract file passes all 139 tracked tests; formatting and exact whitespace checks pass.

## Unresolved acceptance

**Strict29 fails.** The workload has 50 Schools with distinct locations and 5 Ingredients: 250 whole families. One complete public correction, allocation, Preparation, PO replacement/release and PXK successor cycle finished before the second Preparation exceeded 20 seconds. **1/8 cycles observed; 0/20 final assertions.** The entire transaction rolled back. Actors, runs, batches, receipts, POs and PXKs remain at zero. This is not successful scale acceptance.

The first cycle took 17,607.927 ms for Preparation, 3,251.795 ms for the full PO read and 5,488.783 ms for the full 50-School PXK read. Limits remain 8 seconds per public call, 20 seconds for Preparation and 1 second at lock entry; the existing nested materializer uses 5 seconds. Timed completion includes guard flushes. One recorded statistics prerequisite covers 13 relations, with no per-cycle refresh, timeout increase or discarded warm-up. All previous databases and physical-state qualifications remain preserved.

Diagnostic30 reached the second Preparation, canceled at 20 seconds and preserved all 24 pre/post business images. Its completed counters overlap and omit interrupted work; this is diagnostic evidence, not acceptance. The later `dd3d3207` candidate remains **TEMP-only and unapplied**, excluded from the PR runtime.

Earlier evidence stays qualified: Task 6 browser checks at `5586b01`, the pending-date confirmation at `61214daa` and five detector targets; Task 4 actual waits on `b4df`; initial historical exports on `678`. **Final waits, final exports and broader incumbent regressions were not rerun on `3669`.** Exact-head remote Full is deferred; normal push CI is separate. No local Full reset was run.

[Portable sanitized summary and evidence hashes](artifacts/atlas-operator-confirmed-need-correction-c-01/summary.json). Raw logs remain local. The first forward14 role-placement attempt rolled back; its recovered bytes/global-schema parity remain qualified, without a separate pre-retry catalog snapshot. Rejected source proposals and invalid diagnostic28 are not acceptance evidence.
