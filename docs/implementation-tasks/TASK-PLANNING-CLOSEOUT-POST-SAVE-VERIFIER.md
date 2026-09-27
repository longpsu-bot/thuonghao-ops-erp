# Planning Closeout Post-Save Verifier Repair

**Status:** Implemented locally; review and merge remain separate

**Starting SHA:** `1ee97fdb2a51d992c0ee57a9763243ad2da7c279`

**Scope:** Certification/verifier repair only. No migration, hosted write,
Planning regeneration, Confirmed Need Save, Purchase Handoff, Retool/OPS v1
change, public API change, or business/security-contract change is authorized.

## Root cause

The original final assertion reused the strict pre-Save D-046 measurement. It
compared each current revision's `confirmed_quantity` with the generated
proposal formula. After the authorized Save, one current revision correctly
contains the operator's adjusted quantity, so that measurement becomes 247
exact current quantities and one intentional human outcome.

The immutable decision fact remains the correct post-Save proof:
`confirmed_need_line_decisions.proposed_quantity_before` is joined to its exact
decision revision and the authoritative Ingredient purchase Unit, order step,
and version. All 248 proposal-before facts must satisfy the D-046 formula.

## State-specific certification

- `classifyPlanningCheckpoint` remains the strict pre-Save v2 proof: 248
  current generated proposals, zero decisions, zero Save receipts, and zero
  Handoffs.
- `POST_SAVE_CLOSEOUT_RESUME` is the strict v3 proof: 248 current lines, 249
  stable identities, 248 decisions/current decisions, 247 exact acceptances,
  one exact operational adjustment with nonblank note and Planning-step
  alignment, 248 valid proposal-before facts, one semantically valid completed
  Save receipt, and zero Handoffs.
- The post-Save browser path is read-only. It opens the existing 17/09 review,
  checks all 248 persisted current decisions, navigates away and reopens, and
  compares a deterministic SHA-256 fingerprint of the persisted decision facts.
  It has no edit, Save, Generate, or Handoff invocation.
- `pre_save_rehearsal` remains available only when the workflow also receives
  explicit `persist_rehearsal=true`. A v2 state in `post_save_resume` fails
  before browser authentication and cannot fall through to the mutation path.

Failures report compact dimension counts and booleans. They never log the 248
line or decision objects.

## Preview provenance

The verifier distinguishes:

- verifier commit: the exact new `main` SHA supplied to the workflow;
- certified preview base:
  `1ee97fdb2a51d992c0ee57a9763243ad2da7c279`;
- immutable PR #286 preview SHA:
  `4eddd97a7524606ca6ce5e48e2700f6d23a31a03`;
- immutable preview URL:
  `https://2c95cd16.thuonghao-ops-erp.pages.dev/`.

The older preview remains acceptable only when the GitHub comparison from the
certified preview base to the verifier commit contains certification-only
changes under the fail-closed allowlist: the closeout verifier, browser runner,
closeout workflow, relevant verifier tests, and `docs/`. A UI, bridge, RPC,
migration, runtime business-logic, or unrecognized script change rejects the
candidate and requires a refreshed preview. PR #286 must remain Draft/Open at
the exact head/base, and the existing immutable build-manifest checks remain
mandatory.

## Migration, security, and rollback

There is no schema or data migration. The verifier uses read-only management
SQL and the existing authorized RMVP-05 review read. It does not change RLS,
roles, grants, credentials, timeouts, idempotency, or Save semantics.

Before merge, rollback is removal of this bounded verifier change. After merge,
rollback is a normal verifier-only revert; the already-persisted v3 Planning
facts remain untouched.

## Post-merge owner sequence

1. Obtain the exact new `main` verifier SHA.
2. Do not rerun D-046 correction, Need Generation, Confirmed Need Save, or
   Handoff.
3. Keep the existing Staging batch v3 facts intact.
4. Run `Atlas Staging Planning Closeout` with
   `closeout_mode=post_save_resume` and `persist_rehearsal=false`.
5. Require `FINAL_PLANNING_CLOSEOUT_PASS` and the exact 248/249/248/248,
   247/1, one-receipt, zero-Handoff, unchanged-fingerprint proof.
6. Freeze Planning Closeout unless a new independent business defect is found.
