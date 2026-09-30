# Planning Closeout Post-Save Verifier Repair

**Status:** Desktop browser-selector repair candidate; review and merge remain separate

**Final certification-pin starting main SHA:** `9ba47752b5d7e2f750bca19d723c8de46751b771`

**Browser-selector repair starting main SHA:** `6c7f184b19622250a9b79f12c46cd0a86496dc11`

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
  Save receipt, and zero Handoffs. The deployed receipt scope is exactly
  `<actor>:ConfirmedNeedBatch:<batch>`; no domain segment is inserted.
- The post-Save browser path is read-only. It opens the existing 17/09 review,
  checks all 248 persisted current decisions, navigates away and reopens, and
  compares a deterministic SHA-256 fingerprint of the persisted decision facts.
  It has no edit, Save, Generate, or Handoff invocation.
- `pre_save_rehearsal` remains available only when the workflow also receives
  explicit `persist_rehearsal=true`. A v2 state in `post_save_resume` fails
  before browser authentication and cannot fall through to the mutation path.

Failures report compact dimension counts and booleans. They never log the 248
line or decision objects.

## Protected desktop browser failure and repair

Protected Closeout run
[`36701115177`](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/36701115177)
passed exact checkout, frozen installation, and non-mutating preflight, then
failed at `BROWSER_GATE_authenticated_shell`. The supplied Supabase browser trace
shows an HTTP 200 password-token response for subject
`a1010000-0000-4000-8000-000000000101`, followed by an authenticated HTTP 200
`get_school_master_data` response. Authentication succeeded and the connected
Schools module mounted. The verifier's wait still targeted the full/drawer menu
landmark `nav[aria-label="Điều hướng Atlas"]`, which is absent from the stationary
desktop Chakra shell at the protected runner's 1600 × 1100 viewport.

The desktop shell instead exposes `aside[aria-label="Điều hướng nhanh Atlas"]`
with `nav[aria-label="Điều hướng mô-đun Atlas"]`. The repaired verifier requires
both landmarks, scopes Planning navigation and navigation diagnostics to the
module nav, and selects its icon-only `Lập nhu cầu` button by accessible label.
Failure diagnostics now report only safe shell structure, alert count, bounded
module labels, and URL origin/path; they never include form values, credentials,
tokens, browser storage, or cookies.

Run `36701115177` failed before Generate, Save, or Handoff was reached. It made
no business writes. This repair does not retry that run or dispatch another
Planning Closeout. The older hosted-closeout document's obsolete selector is a
later documentation cleanup outside this certification-only delta.

## Preview provenance

The verifier distinguishes:

- verifier commit: the exact new `main` SHA supplied to the workflow;
- certified preview base:
  `9ba47752b5d7e2f750bca19d723c8de46751b771`;
- immutable PR #286 preview SHA:
  `a51759a1ae3c5d38e957b3824ee5c38c33e69205`;
- immutable preview URL:
  `https://06e87532.thuonghao-ops-erp.pages.dev/`.

The approved immutable preview remains acceptable only when the GitHub comparison from the
certified preview base to the verifier commit contains certification-only
changes under the fail-closed allowlist: the closeout verifier, browser runner,
closeout workflow, relevant verifier tests, and this exact implementation-task
document. A UI, bridge, RPC, migration, runtime business-logic, other document,
or unrecognized script change rejects the candidate and requires a refreshed
preview. PR #286 must remain Draft/Open at the exact head and target the `main`
base ref. Its base SHA is intentionally not pinned because `main` advances when
the verifier lands; the two independent comparison checks retain the immutable
certified merge-base proofs. The existing immutable build-manifest checks
remain mandatory.

Final connected read-only UAT passed after #336 on the approved immutable
preview. It covered the Chakra connected production entrypoint, Procurement's
248-row local scrolling and sticky header, mobile sticky identity intersections
for Confirmed Need, Procurement, Ingredients, and Planning Menu, and retained
Confirmed Need state (248 current rows and decisions, one persisted adjustment).
The hosted UAT performed zero business writes.

## Migration, security, and rollback

There is no schema or data migration. The verifier uses read-only management
SQL and the existing authorized RMVP-05 review read. It does not change RLS,
roles, grants, credentials, timeouts, idempotency, or Save semantics.

Before merge, rollback is removal of this bounded verifier change. After merge,
rollback is a normal verifier-only revert; the already-persisted v3 Planning
facts remain untouched.

## Next owner sequence — not yet executed

1. Merge this certification-pin PR.
2. Record the resulting verifier `main` SHA as `VERIFIER_MAIN`.
3. Do not rebase PR #286 afterward; keep its approved preview head pinned.
4. Update the protected `atlas-staging` preview variables to the exact approved
   preview SHA and immutable URL above.
5. Run `Atlas Staging Planning Closeout` with `commit_sha=VERIFIER_MAIN`,
   `closeout_mode=post_save_resume`, and `persist_rehearsal=false`.
6. Require `FINAL_PLANNING_CLOSEOUT_PASS` and the exact 248/249/248/248,
   247/1, one-receipt, zero-Handoff, unchanged-fingerprint proof.
7. Only afterward consider PR #286 Ready for Review and owner merge.

Do not rerun D-046 correction, Need Generation, Confirmed Need Save, or
Handoff. Keep the existing Staging batch v3 facts intact.
