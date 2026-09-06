# RECIPE-LEGACY-ISSUANCE-READ-01 — Legacy issuance history truth

**Status:** Implemented and locally verified on a bounded Draft branch

**Baseline:** `a60085163ecbfde8dc5f7c2d97a454bc57ec0f60`

**Acceptance:** A12 from `ATLAS-MODEL-CONVERGENCE-01`

## Authority and boundary

This task corrects only the backend provenance shape returned by
`atlas_core.recipe_effective_history(date, uuid, uuid, uuid)`. It starts from
current `origin/main`, independently of Draft PRs #258 and #259. It adds no
frontend behavior, relation, public API, helper, capability, role, lifecycle,
import job, backfill, hosted write, deployment, or merge.

The approved rule is: only represent original business issuance provenance that
is actually known. OPS v1 did not preserve an authoritative original Actor for
the affected System BOM Change Orders. The Atlas importer Actor and Atlas import
timestamp remain valid technical provenance, but they are not original business
issuance.

## Diagnosis and test-first evidence

The normal adjustment operator read already classified an immutable revision as
legacy-unattributed when either condition holds:

```sql
revision.reason_code like 'LEGACY_%'
or (
  revision.source_evidence ? 'historical_actor_approval_claimed'
  and coalesce(
    (revision.source_evidence ->> 'historical_actor_approval_claimed')::boolean,
    false
  ) = false
)
```

It returned `LEGACY_UNATTRIBUTED` with null issuer/time. Effective Recipe history
instead returned `actor.display_name` and `revision.created_at` unconditionally.
The approved API document already required nullable legacy attribution, so the
implementation diverged from the documented contract.

The focused history fixture first added one materially contributing root with a
known importer and fixed import timestamp, followed by an Atlas-native correction
and cancellation. Against the unchanged backend, four new assertions failed:
legacy issuer/time nulling, importer suppression, native correction attribution,
and native cancellation attribution. Adjustment-ledger parity and source-row
immutability already passed. A pre-existing wall-clock-dependent release fixture
was fixed to deterministic September 2026 timestamps before recording this RED
result.

## Implementation

The forward migration replaces only the existing private
`recipe_effective_history` function body. While it filters materially applicable
Change Orders, it joins each shaped tag back to its exact immutable revision and
applies the operator-read predicate above. Legacy-unattributed tags receive:

```json
{
  "issuance_kind": "LEGACY_UNATTRIBUTED",
  "issuer": null,
  "issued_at": null
}
```

All other tags receive `issuance_kind: ATLAS_NATIVE` and retain the Actor name
and immutable revision `created_at` already shaped by the candidate history.
Classification is revision-specific: a legacy revision does not erase valid
Actor/time evidence from a later native correction or cancellation on the same
root.

No shared helper was introduced. The operator read had no reusable helper, and a
new function would have expanded the private function/security catalog for one
small predicate. Mirroring the exact established predicate in the history read
is the smaller change; both authority documents record that intentional parity.

## Acceptance evidence

The focused pgTAP suite proves:

- A12-1 through A12-3: a legacy revision exposes null issuer/time and never
  substitutes the retained importer Actor or import timestamp;
- A12-4 through A12-7: native attribution remains intact, the operator ledger
  agrees with effective history, and native correction/cancellation evidence is
  preserved per revision;
- A12-8 and A12-9: existing material-history, full-BOM, effective-boundary,
  correction, cancellation, and temporal-state assertions remain green;
- A12-10: existing authenticated read and platform security suites retain the
  same capability, owner, grants, and denial behavior; and
- A12-11: a before/after JSON snapshot proves the authenticated history reads do
  not mutate the root or any revision row.

## Targeted validation

- A clean local database reset applies every migration through
  `20260906105509_recipe_legacy_issuance_read_01.sql`.
- The A12-focused history suite passes 48 assertions after its four expected RED
  failures against the unchanged backend.
- The effective-history, normal adjustment operator, RMVP-02B, effective-product
  correction, active-on-create lifecycle, and platform security suites pass 200
  assertions across six files on the clean reset.
- `supabase db lint --schema atlas_core` reports no issue for the amended
  function. Its warnings are pre-existing warnings in unrelated functions plus
  the pre-existing unused `reference_date` parameter on the candidate-history
  function.
- Touched Markdown passes Prettier, and the branch remains subject to exact-head
  GitHub CI at the Draft review gate.

## Rollback and integration gate

The migration changes read shaping only and writes no business row. On a
disposable local database, rollback is a reset. After future use, rollback is a
reviewed forward migration restoring the prior function definition; immutable
Recipe and Change Order evidence needs no conversion.

This branch is an integration component. The compatible nullable frontend lives
in Draft PR #258, and the independent A07 backend correction lives in Draft PR
#259. This A12 branch must remain Draft and must not be merged or deployed by
itself. Atlas Staging, live OPS v1, Retool, and hosted business data remain
unchanged.
