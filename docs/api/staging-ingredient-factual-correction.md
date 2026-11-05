# Staging Ingredient factual correction

The parity mandate authorizes eight previously reviewed Ingredient-name
corrections and the necessary source-backed classification correction for
Ingredient1047. The earlier name-only preview rejected before writes because
its non-name guard correctly found source type43 and Atlas type36. Both source
catalogue identities and their existing active typed Atlas mappings were checked
read-only. This is an explicit source fact; no classification is inferred from
an Ingredient name.

## Exact contract

The private session-local contract is
`OPS-V1-INGREDIENT-FACTUAL-CORRECTION.v1`, with receipt identity
`ops-v1-ingredient-factual-correction-20261105-v1`. Existing file/function/command
paths are retained for compatibility, while workflow/operator descriptions
explicitly disclose eight names plus one canonical classification. Any unexpected
receipt for the obsolete name-only correction rejects execution.

The exact eight names remain pinned in the runner. Ingredient1047 additionally
changes its existing canonical `ingredient_type_id` from mapped OPS v1 type36
(Heo) to mapped type43 (Thuỷ hải sản). Both existing catalogue rows must be ACTIVE
and have their exact approved names/codes, and source catalogue36/43 names plus
read-only access proof enter the reviewed plan. No catalogue entry is created or
modified. The actual source Ingredient1047 record retains type43 throughout;
its full source fingerprint is never rewritten to pretend it has type36.

Preview reports every old/new name and explicitly shows Ingredient1047's old/new
source-type identities, canonical IDs and catalogue names. Apply requires all
rows and mappings at the reviewed version2 baseline, changes each row once to
version3, and refreshes the eight typed mappings with their truthful full current
source fingerprints. Only Ingredient1047's canonical type reference can change.
Legacy text fields, other types, Units, quantities, groups, steps, status, Recipe
facts and all identities remain unchanged.

## Gates and transaction

The protected manual workflow retains exact current-main checkout before setup,
exact-head Frontend and executed Full Integration certification, fixed Staging
confirmation, protected credentials, verified TLS and complete exact migration138
history. The private SQL requires the existing active unlinked technical
Migration Actor. Source uses only the fixed read-only OPS v1 endpoint and checks
both Ingredient and allowlisted type-catalogue access.

Apply requires a separately reviewed exact plan checksum. It authenticates the
actual protected user and performs the normal authorized Ingredient read before
privileged writes. The same session verifies all eight resulting names and
Ingredient1047's exact seafood canonical ID/name, then signs out with local
scope in finally. Cleanup errors preserve a primary failure.

The atomic allowed delta is eight name updates, one canonical type-reference
update, one version increment per Ingredient, eight mapping refreshes and one
completed receipt. All other Atlas rows and fields, historical receipts and
mappings are fingerprinted and preserved. The only additional protected-field
exception is Ingredient1047's canonical type ID; SQL independently enforces its
exact36→43 transition and verifies final type43. Source/target/mapping/catalogue,
version or other non-name drift rejects execution. A late failure rolls back
names, classification, versions, mappings and receipt together.

Only a known successful Apply is followed by identical receipt replay. Uncertain
transport or failed results stop without an automatic retry. Retain receipts and
inspect actual state before a reviewed forward recovery; do not delete history.

## Verification and release

Focused runner and rolled-back local pgTAP tests cover source/catalogue proof,
the explicit type transition, unchanged other types, version/mapping truth,
obsolete receipt rejection, drift, late-failure rollback, full protected facts,
replay, authentication, cleanup and type/name readback. Local verification does
not claim a hosted correction.

After independent review and exact-head CI, merge/certify exact main and obtain a
fresh separately reviewed protected Preview before Apply. This remains the final
Atlas data mutation of the parity campaign. Preserve archive603/inactive17,
native3/3, all34 configured weekday Schools and School54's existing receipt.
No schema, public API, grant, dependency, School data, source/Production write,
Warehouse or Supplier cancellation change is included.
