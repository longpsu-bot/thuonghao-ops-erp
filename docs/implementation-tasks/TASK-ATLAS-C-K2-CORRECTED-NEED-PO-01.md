# ATLAS-C-K2-CORRECTED-NEED-PO-01

Status: backend implementation and local verification complete. Exact-head CI evidence is attached to the Draft PR; Product acceptance remains pending.

Authority: [Issue #400 Owner K2 decision](https://github.com/longpsu-bot/thuonghao-ops-erp/issues/400#issuecomment-6263269007), the explicit task brief, and Draft #408 at `2b9f261a31381dab49c7ad87f38b6ad087635b07`.
The Owner decision supersedes the proposed receipt certificate in #406. Receipts remain idempotency, recovery and audit infrastructure. Existing explicit PO Release owns the final supplier commitment after independently validating authoritative relational source facts under locks.

## Scope and implementation

- Verified the selected `E:/Project/OPS ERP/thuonghao-ops-erp` checkout, remote, clean starting tree and workspace check; branched from the requested exact #408 SHA. The user explicitly selected this checkout after the multiple-checkout hard stop.
- Reproduced the initial authenticated 100 release and authentic K1 110 Save. On the base, corrected Preparation failed with `PURCHASE_HANDOFF_CONFLICT`.
- Added one forward migration, `20261019090134_atlas_k2_corrected_need_purchase_orders.sql`. No application tables, roles, capabilities, triggers, public API signatures, lifecycle or receipt authority were added.
- The closed corrected-source projection derives original validated release/snapshot/Handoff ancestry, exact stable-line membership, immutable theoretical contributions, Unit/policy, predecessor-linked decisions and live canonical source currentness. Changed families use existing typed `CONFIRMED_NEED`; unchanged families retain their original `PURCHASE_HANDOFF` identities. Source XOR remains enforced.
- Corrected Preparation retains the original release/Handoff and requires explicit affected allocation acceptance. Existing Draft and Release paths compare complete current contributions/splits; Release rechecks the Actor, Procurement capability, whole represented School/location scope, Supplier eligibility and full date document frontier after waits. No current Planning capability is required of the releaser or the prior Planning Actor.
- Locks follow the existing source root order, then Supplier/allocation/PO boundaries. Supplier status locks use SHARE. Seven Core key-column UPDATE grants with forced-RLS `WITH CHECK(false)` allow authorization row locks while rejecting actual changes.
- The existing deferred PO integrity guard now runs as the existing Procurement runtime, which can see its rows under forced RLS. The old atlas_owner context saw zero Procurement rows. The guard retains immutable shape checks and delegates only immutable Planning ancestry to a private boolean helper. Live currentness stays in Draft/Release so a later correction cannot invalidate issued history or queued historical constraints.

The two new helpers are stateless and private: one locks the release Actor's authorization rows; one checks immutable Planning ancestry. Neither stores or transfers authority. Public, anon, authenticated and service_role execution is revoked. Catalog changes are exactly two private functions, nine policies and thirteen grants; table, trigger, role, capability and public API catalogs remain unchanged. Schema CREATE leases and runtime SET posture are restored.

## Changed files

- Migration and new K2 SQL journey.
- Shared `supabase/local/atlas_b1_two_school_need_fixture.sql`, extracted unchanged from the K1 test; K1 test includes it. K1 writer and receipt-integrity functions remain untouched.
- `purchase_review_confirm_release.sql`: replace privileged legacy post-issuance reopen fixtures with authentic K1 v3 commands, and assert the Owner-approved original Handoff preservation. Initial Handoff, coverage, cancellation, stale replacement, rollback and immutable-history assertions remain.
- Whole-platform security catalog: exact reviewed deltas only.
- Fixture-aware SQL runner: optional disposable database name.
- Ten-case local concurrent-session runner, Full Integration registration and registry tests, Smoke registration and workflow path filters.
- Procurement API contract and this evidence record.

## Executed local evidence

Disposable local databases only; the existing local `postgres` database and hosted systems were not migrated. The exact base schema was cloned, then the forward migration was installed. SQL fixtures and fault probes roll back. Concurrent tests create and drop only their own disposable databases.

- Real authenticated initial Need100 / PO-001100, K1 correction110 / explicit allocation110 / Preparation / complete Draft / explicit PO-002110, then K1 correction90 / reacceptance / complete PO-00390. Three distinct official numbers; predecessor supersession is atomic; all issued revisions, quantities, School snapshots and frozen document/export fields remain identical.
- Multiple Suppliers and two Schools sharing a location, with authentic B1 Recipe20 + breakfast5 + host3 theoretical contribution beneath human30 and another School20. Full corrected family50 is covered by complete Supplier documents.
- Removed Supplier remains `CANCELLATION_REQUIRED`; zero replacement is rejected. A new Supplier omitted in another family blocks final Release even when the target Draft itself remains current.
- Inactive Actor/Supplier, missing Procurement capability, wrong School scope, reopened Menu, a later authentic Need decision and injected Release failure all reject without changing any PO facts.
- A manufactured valid-lifecycle completed transfer receipt alone cannot create a replacement Draft. Unsupported noncurrent initial-CN history is rejected by the official source guard.
- Seven actual same-value Core key UPDATE attempts are denied; private helper execution is denied to public request roles; missing ancestry is false. Valid proof mutation cases cover unknown appended IDs, mismatched revision/decision, wrong quantity and wrong Unit.
- Ten real concurrent-session cases passed: Menu, Need, Actor and Supplier writers, each in both commit orders; exact Release request after first commit and first rollback. Tests observe `pg_blocking_pids`, verify immutable predecessor state and recover discarded responses through an authenticated shaped read. Existing timeout limits are unchanged.
- Focused regressions passed: K1 81, receipt integrity50, school-catering PO161, Handoff/allocation88, Purchase Review193, Planning correction23, source ambiguity9, whole-platform security catalog30. Additional focused checks passed: K2 93, release projection7, released allocation read13 (236 families; three samples1.83–1.90 seconds under the unchanged8-second limit), runtime hardening1, wholesale compatibility56, B1 two-source39 and composition51. The workflow registry test passed116 assertions.

Independent source/security review confirmed the fixed RLS context, private helper boundaries, original initial-Handoff path, compatible locks and live-versus-historical separation. Its malformed-proof finding was fixed with explicit LEFT JOIN rejection and mutation tests. Final independent source/security review found no unresolved findings. The additional continuity finding was fixed at the historical gate and live root/predecessor bindings using the existing approved continuity predicate. A real pre-issuance Pantry successor/regeneration/selective Save test proves both Schools retain carried authority through later K1 correction and replacement.

Known diagnostic limitation: an existing immutable contribution guard rejects an attempted equal-total membership rewrite with SQLSTATE42703 (it references an absent OLD.is_current field), rather than the intended23514. The mutation remains rejected; this pre-existing diagnostic bug is not changed or represented as successful upstream correction. Quantity corrections do not certify changed Weekly Menu Dish acceptance after issuance.

## Migration, rollback and acceptance

No data backfill, production write, historical quantity rewrite or dependency addition. The migration is transactional. Before any issued corrected documents exist, a reviewed forward rollback may restore the prior function definitions and remove only the two helpers/nine policies/thirteen grants. After corrected documents exist, preserve their typed immutable lineage and read support; disable new corrected admission through a reviewed forward change instead of deleting history or blindly reverting the migration.

One Draft PR is stacked on #408. Its checks and validation section record the required exact-head Frontend, Supabase Smoke and actually executed Full Integration outcomes; Product/architecture acceptance remains required. No merge, deployment, hosted write, Warehouse/payment work or further upstream-correction implementation is authorized by this task. Stop after K2.
