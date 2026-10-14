# Migration 108 Staging authorization acceptance

Status: acceptance SQL validated locally; hosted execution awaits source review.

On 14 October 2026, the Product Owner's “Please proceed” advanced the concrete reviewed PR #380 handoff through merge, protected Atlas Staging deployment and rollback-only acceptance. The approval is bounded to that correction. It does not authorize Production, real supplier/PXK commitments, OPS v1/Retool writes or a decision about inherited PXK shared-location matching.

## Deployment authority

- PR #380 implementation head: `0082ec79a9924011640bc81a1a1c78c5213e7d4e`.
- Merged main/business deployment SHA: `d254c099098a1f004f4eaaf78092f1aab9c32bd3`.
- Merged-head [Frontend CI](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/38545264913) and [Full Integration](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/38545264875): passed.
- Guarded [Staging deployment](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/38546830503): passed, including preflight and platform verification. Navigator readback confirmed 108 migrations, tip `20261014090000_atlas_cutover_auth_scope_alignment` and the private helper boundary.
- Only hosted target: `rnzxmxiiqgtdevzregff`.

## Reviewed execution procedure

Use the existing explicit-project Supabase connector or validated Staging Postgres transport. Do not create another runner, dependency, workflow or hosted extension. Before execution, verify the approved target, deployed business SHA/migration history and the reviewed acceptance-source SHA. Execute each file in one database session; do not split its transaction across requests.

1. Run `supabase/local/atlas_auth_scope_alignment_postflight.sql` as a read-only preflight. Require `success=true`, migration 108 present, all 36 probe-relation checks clear and zero probe rows. Retain the existing Draft PO count/fingerprint.
2. Run `supabase/local/atlas_auth_scope_alignment_workload_acceptance.sql`. Require exactly 16 named cases, `success=true`, `probe_rollback_verified=true` and `real_po_unchanged=true`. It selects a real current multi-School Draft PO and exercises full, partial and GLOBAL shaped reads. It never releases a real PO. It also exercises real Generated Purchase Review sources with Procurement-only, Confirmed-Need-only and matching/outside Customer scope.
3. Run the independent postflight again and compare the Draft PO count/fingerprint to preflight. Require zero remaining probe identities, scope/role assignments, receipts, audit events, source facts and documents.
4. Run `supabase/local/atlas_auth_scope_alignment_synthetic_acceptance.sql`. Require exactly 27 named cases, `success=true`, `synthetic_releases_only=true` and `probe_rollback_verified=true`. It seeds only reserved `f108` identities and date `2098-10-14` inside rollback, adapts the existing PXK fixture, and exercises real public PO/PXK commands with normal command guards restored after seeding. It covers whole-PO partial/full access, missing capabilities, stale version, immutable numbering/replay, PXK scoped/GLOBAL release and read, reconciliation, and Preparation's inherited GLOBAL lifecycle gate.
5. Run the independent postflight once more and compare the same real Draft PO fingerprint. Preserve the JSON reports and exact source/deployment SHAs as evidence.

Each acceptance file uses explicit `BEGIN`/`ROLLBACK`, temporary assertion/report helpers and one final JSON result. The probe work runs in a nested exception subtransaction. Only its dedicated successful-rollback SQLSTATE is caught; actual assertion failures propagate and abort. The retained result is emitted after probe rollback. Missing, malformed or incomplete output is failure, even when transport status is successful. The final outer rollback removes temporary scaffolding.

Both batches retain an 8-second statement cap and 1-second lock cap. No product timeout is increased. Workload timing records one complete read and one partial-scope read of the selected real PO, including normal shaped-read work. These are bounded observations, not hosted scale certification or a latency distribution. The earlier two-line/two-School helper benchmark remains separately bounded evidence in the original task.

If an assertion, timeout, collision, source prerequisite or connection outcome is unclear, stop. Run the independent read-only postflight before considering a manual retry. Never retry acceptance writes automatically. A changed real Draft fingerprint requires investigation; do not overwrite or restore hosted data to force a match.

## Local validation

The new synthetic acceptance passes all 27 cases against a newly created disposable local database. Workload acceptance fails loudly when real-workload prerequisites are absent, then passes all 16 cases when pre-existing workload is supplied by the repository's existing local Procurement and Generated Review fixtures. The fixture preparation is local-only and rolled back. The standalone postflight reports zero remaining probe rows.

An injected assertion failure after synthetic command execution aborted loudly and left postflight clear. This verifies that the successful-rollback handler cannot hide an assertion failure. No hosted acceptance result is claimed by local validation.

## Remaining Product decision

The existing PXK/reconciliation predicate accepts the scoped School's default delivery location. Whether `SCHOOL` must mean exact School-only access or preserve that location coverage when Schools share a default is a separate Product choice. No response to that question is approval. The acceptance code preserves the deployed predicate and does not change authorization policy.

After verified hosted acceptance, update the active baton with evidence and that unresolved decision. Do not mark Production/cutover authority or the PXK policy complete by implication.
