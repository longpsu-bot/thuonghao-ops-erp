# Migration 109 exact-School PXK validation

Status: local implementation and rollback validation passed; fixed-head review, exact-head CI and guarded hosted rollout pending.

## Boundary and local evidence

[ATLAS-PXK-EXACT-SCHOOL-SCOPE-01](../decisions/decision-atlas-pxk-exact-school-scope.md) records Product's 14 October 2026 approval. Migration `20261014120320_atlas_pxk_exact_school_scope.sql` changes one existing private helper and two read-filter callers. It adds no object, grant, role/capability, policy, UI behavior, staff assignment or second-person requirement. Generic school-catering/PA-05B authorization, whole-PO scope and Preparation GLOBAL are unchanged.

A newly created disposable local database was initialized through migration 108. Existing local volumes were preserved. The new authenticated rollback matrix reproduced exactly three failures on 108: School A could read/reconcile School B and passed the scope guard for its release when A's default equalled B's captured location. Positive B/location/Customer/GLOBAL controls and scope validity cases passed before the correction. The clean shared-PO fixture stage is used before existing tests deliberately make Procurement stale; release commands run with normal guards and isolated rollback.

After the forward migration:

| Focused suite                                                            | Passing assertions |
| ------------------------------------------------------------------------ | -----------------: |
| School Dispatch release, including authenticated scope/capability matrix |                134 |
| School fulfilment reconciliation                                         |                 16 |
| School-catering PO regression                                            |                155 |
| Exact current platform security/catalog                                  |                 30 |
| Total                                                                    |                335 |

The matrix covers exact A/B scope, explicit location/Customer/GLOBAL, other Customer/location, revoked/expired status, expired/future effective times, each independently missing task capability, zero writes for denied/isolated commands, same-Actor multi-School release/audit/replay, captured historical location, frozen PXK, wrong operational/cross-Customer locations and the retained successor/currentness suite. Exact catalog counts, fingerprints and grants remain at baseline 108; no expectation change was required.

The extended manual synthetic fixture passes 48 named cases locally. A negative control restores only the old three scope function definitions inside a local transaction: acceptance fails at `exact_school_shared_default_read` and emits no aggregate success. The transaction ends without persistent changes; the independent postflight reports 36 clear relations and zero probe rows. This proves the new policy check cannot silently accept migration-108 behavior. It does not constitute hosted acceptance.

A bounded local helper timing used the existing two-School/two-location fixture and 1,000 iterations of A and B target evaluation: 2,000 calls took 469.37 ms with the new predicate and 705.81 ms with the old delegation. The B target changes from the old unintended allow to the required deny. This single fixture/run is an evaluation-cost observation, not public-RPC latency or hosted scale certification. No timeout was increased. Benchmark source/timing was executed only in rollback; the old definition was not retained.

Sanitized local logs are retained under `C:/Users/HOME/AppData/Local/Temp/`: `atlas-pxk-exact-school-red.log`, `atlas-pxk-exact-dispatch-green.log`, `atlas-pxk-exact-synthetic-green.log`, `atlas-pxk-109-manual-old-scope-red.log` and the `atlas-pxk109-*.sql.log` focused/postflight files. No hosted probes were executed by the implementer.

## Guarded Staging procedure after review

Require the exact reviewed merged business SHA to pass Frontend CI and Supabase Full Integration, then use the existing protected Staging workflow on `rnzxmxiiqgtdevzregff` only. Require migration tip 108 before the one forward migration; inspect 109 history and unchanged helper owner `atlas_read_runtime`, SECURITY DEFINER, empty search path, existing read/Dispatch execution and denied browser/service execution afterward. Compare exact catalog identities/counts/grants and the existing advisory baseline. No runtime deployment is authorized solely by this document.

After a fixed-source audit and explicit execution clearance:

1. Fetch the full exact committed `supabase/local/atlas_auth_scope_alignment_postflight.sql` and synthetic acceptance SQL, verify source SHA, byte counts and SHA-256, and execute each file in one database session.
2. Run the independent read-only postflight. Require 36 clear relation checks, zero probes, migration 108 present and unchanged real Draft count/fingerprint against the separately recorded current baseline. Verify 109 explicitly from migration history and the synthetic gate.
3. Run `supabase/local/atlas_auth_scope_alignment_synthetic_acceptance.sql`. Its current 109 extension requires `success=true`, exactly 48 named cases, `synthetic_releases_only=true` and `probe_rollback_verified=true`. It retains the original 27 cases plus 21 new gates/security/scope/attribution checks. All commands target reserved `f108` fixtures/date `2098-10-14` inside explicit rollback, with normal guards restored after seeding.
4. Run the independent postflight again. Require 36 clear relations, zero probe rows and the identical real Draft count/fingerprint. Preserve full sanitized reports and exact source/deployment identities. Never restore real data to force a fingerprint match.

The script retains 8-second statement / 1-second lock caps, catches only successful rollback sentinels and emits one complete final JSON. Any failure, timeout, missing/malformed report or unknown connection outcome stops further probe writes; run independent read-only postflight, investigate and obtain clearance before a manual revision/retry. Do not automatically retry or raise timeouts. No pgTAP extension installation, new runner, real PO/PXK release, staff grant or Production/OPS-v1/Retool write is allowed.

Migration 108's [43-case hosted result](atlas-auth-scope-alignment-staging-108.md) and JSON evidence remain pinned to reviewed source `8340e9a38fcdd27755a8c5cecbe70da8eafb053e`. The current synthetic file requires 109 and has 48 cases; do not reinterpret the old report as a later-policy result. The earlier real-workload read acceptance need not be rerun merely to restate its unchanged evidence. Historical PXK/PO content, numbers and source lineage remain protected.
