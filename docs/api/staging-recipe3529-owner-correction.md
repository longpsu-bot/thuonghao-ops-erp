# Staging Recipe3529 Owner correction

The Owner's explicit 9 November 2026 confirmation, **“thịt heo xay nha”**,
supersedes the earlier request to leave the ambiguous Recipe unchanged. This
is a new Atlas-native decision, not an OPS v1 Change Order or historical issuance.
The bounded runner is `scripts/correct-atlas-staging-recipe3529.mjs`; manual
execution uses `Atlas Staging Recipe3529 Owner Correction` in the protected
`atlas-staging` environment.

## Exact correction

One `SYSTEM_DISH / REPLACE` applies from `2026-11-09` to Dish 2071, School Type 2,
Recipe 3529, stable Recipe Line `b72261a4-a7b1-5a0d-14ae-0b692dc52a13`.
Ingredient 1037 (beef) becomes Ingredient 1208 (Nạc vai heo xay), UUID
`1edd7b1a-c5c9-00aa-2132-635144259d32`. Type 1 already uses this current pork
Ingredient; source global order 14 also selected 1208 from retired 1040. The
replacement keeps quantity and Unit by supplying null for both optional fields.
It preserves 5.5 kg/100 portions, the other four Ingredients 896/914/943/960 at
2/2/1/0.1 kg, the shared Dish name, Type 1 and all pre-date composition.

The durable Vietnamese reason is:

> Chủ sở hữu xác nhận dùng thịt heo xay cho công thức 3529, món 2071, loại trường 2. Thay thịt bò bằng Nạc vai heo xay (1208) từ ngày 09/11/2026; giữ nguyên 5,5 kg/100 suất và các nguyên liệu còn lại.

Source evidence records `source_kind: ATLAS_OPERATOR`, the exact owner
confirmation, decision date and source references. It claims no old issuer,
source order or historical approval. The authenticated user's actual Actor is
resolved by PostgreSQL. The runner never supplies an Actor ID.

## Review and execution

Run the four-global adoption first. Its conservative interaction gate excludes
new native adjustments; running this correction first would block that adoption.
Then certify the exact current `origin/main` SHA with successful Frontend CI and
an executed Full Integration certificate. The workflow verifies both before
dependency installation and loading the test-user password. The runner repeats
exact-main/certification checks immediately before its fresh read and command.

Preview authenticates with only the approved Staging publishable key and the
actual protected test-user credentials, verifies `/auth/v1/user` matches the
session and configured email, then reads the four canonical typed contexts:
Type 1 and Type 2 at 8 and 9 November through
`resolve_system_effective_recipe_composition` (`RECIPE-EFFECTIVE.v1`). Each must
be `READY`, select the pinned typed released version and retain the expected
five atomic lines, quantities and kg Unit. The runner requests the existing
`preview_recipe_composition_adjustment` (`RMVP-02B.v1`); backend write capability
and global scope checks must succeed even for Preview.

The combined SHA-256 binds exact code SHA, approved target, authenticated subject,
all four canonical resolutions, exact proposal/source evidence and native Preview,
and the stable Create envelope. The only execution-time field excluded is
`requested_at`, generated immediately before Create as required by the existing
command contract. Command, correlation, adjustment, revision and idempotency
identities remain fixed. Preview calls no command and writes no adjustment,
revision, event, audit row or command receipt. Authentication opens and closes
only the local user session.

Apply requires the separately reviewed `plan_checksum`, explicit
`target_project_ref: rnzxmxiiqgtdevzregff` and `apply: true`. It reproduces the
reviewed plan, repeats certification, re-reads all contexts and obtains a fresh
native Preview. Any drift blocks before Create. One transactional
`create_recipe_composition_adjustment` creates the rule and first revision using
the authenticated subject. PostgreSQL revalidates the exact typed target under
the established locks, RLS/capability and idempotency boundaries. A known successful
receipt is replayed with the identical request; an unknown outcome is never retried.
All four contexts are then read again: only Type 2 at 9 November may differ, by
the precise replacement and one new lineage step. Stable identities, base facts,
all other effective fields and pre-date/Type 1 resolution must match exactly.

The session is logged out in `finally` after success or failure. Artifacts contain
only the reviewed checksum, bounded correction summary and receipt identifiers;
no credentials, tokens or private relation dumps. No Management token, database
password, SQL, service-role key, source write or Actor impersonation is used.

## Verification and recovery

Focused Vitest tests cover wrong context, stable line, selected version,
Ingredient, quantity, Unit, readiness, permission, stale Preview, read-only
Preview, exact Create/replay/readback, target/key validation, certification order,
unknown outcome and logout. Existing backend REPLACE, concurrency and RLS tests
remain authoritative; this adds no migration, schema, API, dependency or grant.

Released Recipe Versions and operational snapshots are not updated by this native
command. Fresh generation can consume the new effective composition from the
stated date; prior runs retain their immutable evidence and existing correction
workflow. The authenticated runner's preservation proof covers the four selected
canonical contexts, not a private-table checksum audit of all operations.

If Create or replay returns an unknown outcome, inspect the fixed command identity
and durable receipt before another action. Never delete the rule, reset data,
change the idempotency key or rerun with new IDs to bypass uncertainty. Recovery
uses a separately reviewed native forward correction/cancellation. Hosted Preview,
Apply and actual CI evidence are recorded by the parent delivery task; this note
does not claim they have occurred.
