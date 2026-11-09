# Bounded Staging global replacement adoption — 9 November 2026

The Owner-authorized reconciliation amends the local-only usage restriction of
`atlas_legacy.import_recipe_adjustment_snapshot` for this single guarded Atlas
Staging transaction. Its implementation, privileges, validation, immutable
lineage, deterministic identities and replay behavior remain unchanged. The
generic importer is not a hosted operator API. No permanent schema, resolver,
grant, RLS, lifecycle or calculation contract changes.

The session-local package `atlas-staging-global-replacements.sql` admits only
actual active OPS v1 Ingredient orders 7, 11, 12 and 14, preserving exactly
1043→1039, 1029→1067, 836→904 and 1040→1208. The fifth actual order 13,
1042→1041, remains excluded because its proposed effect creates duplicate final
Ingredients. Missing, extra, duplicate, inactive or changed source identities,
edges or pinned source dates fail closed. The original normalized source row,
including its verbatim `source_record` and effective date, is retained as JSON
in immutable `reason_note`; original attribution remains explicitly unknown.
Atlas authority starts **2026-11-09**. This does not fabricate historic Atlas
issuance or turn effective-view differences into authored business facts.

The four-input protected workflow requires full current-main certification,
exact Staging configuration and verified PostgreSQL transport. Preview executes
the actual importer, identical replay, and canonical before/after proof, then
rolls back the complete inner transaction. Preview creates no persistent
receipt, root or revision. `content_checksum` is the **combined reviewed plan**:
source content, whole target fingerprints, migration history, fixed date, exact
orders/exclusion and the unlinked technical MIGRATION Actor. Supply that value
as `reviewed_content_checksum` on Apply. `source_content_checksum` is returned
separately for source evidence; it is not the Apply approval token. Fresh
technical extraction metadata does not change source content identity.

Apply takes deterministically ordered table locks and rechecks the combined
reviewed fingerprint under those locks. Any unrelated target drift also blocks
the reviewed Apply. There is no automatic unknown-outcome retry. Exactly four
new roots, four first revisions and one import receipt are permitted; the same
snapshot must immediately return `REPLAYED` with the identical receipt. Existing
adoption identities fail closed on a subsequent workflow invocation; use the
retained receipt and readback to investigate an uncertain result.

Every mapped Dish × both canonical typed contexts is canonically resolved at
2026-11-08 and 2026-11-09 before and after. Historical resolution is unchanged;
current readiness, blockers, warnings, selected Recipe, stable line identity,
quantities and Units are preserved. Only the four exact Ingredient edges and
their corresponding new lineage steps are allowed, preserving the full prior
lineage prefix. Duplicate destinations block the whole transaction. No line
aggregation or snapshot-delta rules are introduced.

Because global rules run before Dish and School layers, this bounded proof
first rejects every current/future existing global or School-wide revision and
every current/future Dish or School-Dish revision applicable to a mapped Dish
and canonical School Type. Expired revisions and unrelated unmapped/noncanonical
native fixture contexts are retained. The gate is deliberately conservative:
an interacting rule requires a separate reviewed canonical proof, not a naïve
final-Ingredient substitution oracle. This adoption does not activate the other
source system/School rules or claim complete v1 parity.

All Atlas relations are fingerprinted under locks. Every preexisting row,
including native adjustments/revisions, released operational documents, master
identities/mappings, weekday defaults and earlier receipts, remains identical.
Only the exact nine newly admitted rows are excluded from the preservation
comparison, and their deltas are independently checked. Migration history must
match the certified checkout. Recovery after committed adoption is reviewed
forward correction, never deletion, reset or backdating. OPS v1 and Production
remain NO-WRITE; Warehouse and Supplier cancellation remain excluded.

Focused checks: `pnpm exec vitest run
scripts/adopt-atlas-staging-global-replacements.test.mjs` and
`node scripts/test-local-staging-global-replacements.mjs`. The latter is a
rollback-only pgTAP fixture through the existing local Supabase transport.

## Completed bounded execution — 9 November

At certified main `0cff3f32`, Preview42554715147 rolled back and
Apply42555155022 committed exactly the reviewed four orders, then REPLAYED.
Actual receipt `6a81d3f7-1650-4547-a52d-ea168f17866a`; reviewed combined checksum
`16c893655c6e5be0b252c4688d6fc054a157face186b0b3b88a109531c511095`.
All1,534 canonical contexts and117 protected tables passed the bounded proof;
305 effective lines changed. Do not replay this one-off with a fresh snapshot.
The later Recipe3529 Owner correction used the existing authenticated product
command, not this import exception. See [actual receipts and qualified final
comparisons](../testing/atlas-bom-reconciliation-2026-11-09.md).
