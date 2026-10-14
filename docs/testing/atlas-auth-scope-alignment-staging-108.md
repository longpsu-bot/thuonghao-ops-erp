# Migration 108 Staging authorization acceptance

Status: hosted rollback acceptance passed on 14 October 2026 at independently reviewed source `8340e9a38fcdd27755a8c5cecbe70da8eafb053e`. Workload: 16 checks across eight RPC cases; synthetic: 27 checks; independent postflight: 36 clear relation checks and zero probe rows after each batch. PR #381 remains a review/CI gate for these acceptance artifacts and the next task baton.

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
2. Run `supabase/local/atlas_auth_scope_alignment_workload_acceptance.sql`. Require exactly 16 named checks across `top_level_rpc_cases=8`, `success=true`, `probe_rollback_verified=true` and `real_po_unchanged=true`. It selects a real current multi-School Draft PO and exercises full, partial and GLOBAL shaped reads. It never releases a real PO. It also exercises real Generated Purchase Review sources with Procurement-only, Confirmed-Need-only and matching/outside Customer scope.
3. Run the independent postflight again and compare the Draft PO count/fingerprint to preflight. Require zero remaining probe identities, scope/role assignments, receipts, audit events, source facts and documents.
4. Run `supabase/local/atlas_auth_scope_alignment_synthetic_acceptance.sql`. Require exactly 27 named cases, `success=true`, `synthetic_releases_only=true` and `probe_rollback_verified=true`. It seeds only reserved `f108` identities and date `2098-10-14` inside rollback, adapts the existing PXK fixture, and exercises real public PO/PXK commands with normal command guards restored after seeding. It covers whole-PO partial/full access, missing capabilities, stale version, immutable numbering/replay, PXK scoped/GLOBAL release and read, reconciliation, and Preparation's inherited GLOBAL lifecycle gate.
5. Run the independent postflight once more and compare the same real Draft PO fingerprint. Preserve the JSON reports and exact source/deployment SHAs as evidence.

Each acceptance file uses explicit `BEGIN`/`ROLLBACK`, temporary assertion/report helpers and one final JSON result. Workload probe identities are created and rolled back independently for each public RPC case. Eight separate top-level `SELECT` calls each run one RPC; passed case labels and timings are appended to temporary results only after successful fixture rollback. The synthetic batch uses one isolated fixture subtransaction. Only the dedicated successful-rollback SQLSTATE is caught; actual assertion failures propagate and abort. The final report requires every expected case. Missing, malformed or incomplete output is failure, even when transport status is successful. The final outer rollback removes temporary scaffolding.

Both batches retain an 8-second statement cap and 1-second lock cap. No product timeout is increased. PostgreSQL 17 applies the cap independently to top-level statements within a multi-statement simple-query message, so workload RPCs have separate existing budgets rather than sharing one `DO` budget. See the [PostgreSQL timeout reference](https://www.postgresql.org/docs/17/runtime-config-client.html#GUC-STATEMENT-TIMEOUT). Workload results report each RPC's elapsed time. These are bounded observations, not hosted scale certification or a latency distribution. The earlier two-line/two-School helper benchmark remains separately bounded evidence in the original task.

If an assertion, timeout, collision, source prerequisite or connection outcome is unclear, stop. Run the independent read-only postflight before considering a manual retry. Never retry acceptance writes automatically. A changed real Draft fingerprint requires investigation; do not overwrite or restore hosted data to force a match.

## Local validation

The new synthetic acceptance passes all 27 cases against a newly created disposable local database. Workload acceptance fails loudly when real-workload prerequisites are absent, then passes all 16 cases when pre-existing workload is supplied by the repository's existing local Procurement and Generated Review fixtures. The fixture preparation is local-only and rolled back. The standalone postflight reports zero remaining probe rows.

An injected assertion failure after synthetic command execution aborted loudly and left postflight clear. This verifies that the successful-rollback handler cannot hide an assertion failure. No hosted acceptance result is claimed by local validation.

Source review also found that the original workload assertion could accept a redacted PO for a partial Actor. The revised assertion requires the selected PO ID to be absent entirely for that Actor, while full/GLOBAL Actors require the complete line count. A locally injected zero-line PO leak reproduced the original assertion defect, then failed loudly with the revised assertion. Normal workload acceptance still passes all 16 cases and postflight remains clear.

The per-RPC revision retains that negative leak proof. An additional forced failure in the last RPC case must abort without emitting an aggregate success report, and the independent postflight must remain clear; earlier successful cases cannot mask a later failure.

## Initial hosted attempt and read-only diagnosis

Reviewed acceptance source `32bffd5547e05ea772e8213a9d0b9764659db300` was executed only after source audit and explicit execution clearance. Fresh read-only preflight returned 36 clear relation checks, zero probe rows, 17 real Draft POs and fingerprint `cefbff23b30cbc15dac0b890a956d884`.

The initial workload batch hit SQLSTATE `57014` at its 8-second cap inside the existing `school_catering_procurement_date_current` → `school_catering_family_projection` path. That version put multiple public reads inside one `DO` statement. It produced no valid 16-case report, so no acceptance pass is claimed. Further probe writes stopped; synthetic acceptance was not executed. Independent postflight immediately confirmed zero probe rows, the same 17 Draft POs and the identical fingerprint.

An explicitly authorized independent read-only diagnostic used the existing managed GLOBAL operator, authenticated execution, the same 8-second/1-second caps, date `2026-10-12` and one supplier. It returned one real PO successfully in 2,212.95 ms. This does not establish an individual RPC exceeding eight seconds. Deployed currentness-function MD5 `39f65214edb8019ef57c8e5280091784` and v2-base MD5 `7442905d426082ad8ef9ea81f5f06cec` match the canonical deployed source. Migration 108 does not rewrite that currentness path. The revised harness separates statement budgets instead of changing product timeout or currentness semantics.

## Verified hosted result — 14 October 2026

Terra audited the revised exact source and Product/Architecture explicitly cleared its execution after diagnosis. This was a reviewed revision; the original stopped attempt remains evidence. Each committed SQL file was fetched in full and checked against its byte length and SHA-256 before execution on the explicit Staging project. The [durable JSON evidence](evidence/atlas-auth-scope-alignment-staging-108.json) contains source hashes, deployment SHA, every named case and all five parsed reports.

- Fresh preflight: migration 108 present, 36 relation checks, zero probe rows, 17 real Draft POs, fingerprint `cefbff23b30cbc15dac0b890a956d884`.
- Workload: all 16 checks / eight RPC cases passed. The selected PO `3bf24a48-2bab-4519-9fe1-07e907ed7cf6` contains 148 lines and 21 School scopes. Full and GLOBAL reads returned complete content; partial scope returned no selected PO. Procurement capability, missing capability, matching/outside Customer filtering and exact private-helper security checks passed. Selected PO fingerprint remained `47e3b267c0b3b3573ed739d64a81b198`.
- Independent postflight after workload: 36 checks / zero probes, identical 17-Draft fingerprint.
- Synthetic: all 27 checks passed, including isolated PO/PXK release, capability denials, wrong scope, GLOBAL controls, replay/numbering, stale version, reconciliation, exact-School PO shared-location denial and Preparation's inherited GLOBAL gate. Releases used only reserved `f108` fixtures/date `2098-10-14` and rolled back.
- Independent postflight after synthetic: 36 checks / zero probes, identical 17-Draft fingerprint. No persistent probe identities, scopes, receipts, audit facts or documents remained. No real PO/PXK was released.

The three real PO reads took 2,923.66 ms (full School scope), 2,256.09 ms (partial scope) and 2,762.68 ms (GLOBAL). Generated Review cases took 46.89, 4.38, 0.98, 3.90 and 3.09 ms. All completed with unchanged 8-second statement / 1-second lock caps. These single-run observations cover this selected 148-line/21-School PO and the available Generated Review fixture source; they do not establish a latency distribution or broader scale guarantee. The selected Generated Review source date was `2046-09-19`, an existing Staging rehearsal source.

Full sanitized connector responses remain outside the repository in `C:/Users/HOME/AppData/Local/Temp/atlas-auth-staging-108-acceptance-per-rpc.json`; the earlier timeout and independent read-only diagnosis remain in the separate files listed in the durable JSON. Business deployment remains `d254c099098a1f004f4eaaf78092f1aab9c32bd3`; acceptance source is `8340e9a38fcdd27755a8c5cecbe70da8eafb053e`.

## Remaining Product decision

The existing PXK/reconciliation predicate accepts the scoped School's default delivery location. Whether `SCHOOL` must mean exact School-only access or preserve that location coverage when Schools share a default is a separate Product choice. No response to that question is approval. The acceptance code preserves the deployed predicate and does not change authorization policy.

The active baton now records that unresolved decision. Migration 108's bounded authorization correction has passed Staging acceptance; Production/cutover authority and the separate PXK policy remain unapproved.
