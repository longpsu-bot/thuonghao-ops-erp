# Atlas reconciliation and staff review — 9 November 2026

## Authorized scope

The Owner requested the remaining Recipe differences in one staff-review file,
confirmed two Recipe decisions and explicitly authorized deleting all current
Staging operational documents as test data. The final clarification includes
documents referencing copied v1 Schools; it is broader than the initial seven
PO/four-dispatch synthetic-School subset. Full inventory is54 POs and22 School
dispatch releases. Source OPS v1 and Production remain NO-WRITE. Real Supplier
commitment cancellation and Warehouse workflow expansion remain excluded.

The [continuation plan](../superpowers/plans/2026-11-09-atlas-reconciliation-staff-review.md)
defines exact allowed/protected facts and the one-off Staging maintenance review.
This is not authorization for generic deletion, normal business-history rewrites,
source changes, automatic reseeding or another legacy-rule adoption.

## Confirmed facts saved through existing authenticated UI

All four commands use SYSTEM_DISH, one canonical School Type,9 November2026
onward with no end date. The original released Recipe/BOM and unrelated
ingredients/quantities remain intact. Existing Actor/time describe actual Atlas
issuance; no legacy identity or historical approval was fabricated.

| Dish                       | Type | Confirmed outcome                                                      | Actual adjustment / revision                                                    |
| -------------------------- | ---- | ---------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| 1735 Nạc vai ram           | 1    | Keep Nạc vai heo3.5kg/100 portions; remove duplicate Thịt vai heo line | `d4ca494a-039d-49af-8771-f6b2c75b1cce` / `56694ba9-136c-492c-952f-a45eeedbcaed` |
| 1735 Nạc vai ram           | 2    | Keep Nạc vai heo5kg/100 portions; remove duplicate Thịt vai heo line   | `9a0fe255-7820-48e7-a4b5-b84fc25e6c37` / `98c0c716-7ea3-47e6-ad55-7c2004181d5a` |
| 1802 Mướp xào nấm, thịt gà | 1    | Replace Nấm rơm0.1kg with Nấm bào ngư0.15kg/100 portions               | `773537b2-ee38-4817-9b4a-f11e19485df9` / `7e6f1682-f100-47cb-9e62-d2fe6a0c6ed7` |
| 1802 Mướp xào nấm, thịt gà | 2    | Replace Nấm rơm0.1kg with Nấm bào ngư0.15kg/100 portions               | `158084e3-cb3d-4042-8efb-3e84fdff9c79` / `24b069db-4ba0-45d6-ac41-2344d5489a18` |

Fresh independent canonical readback at05:42 UTC confirms these results. Native
roots/revisions became12/12; the prior8/8 are byte-identical. All82 operational
table fingerprints remain unchanged by these four commands. The later test
cleanup has separate authority and must not be conflated with this preservation
proof. Saved UI screenshots and private readback retain the actual command facts.

Historical/current readback independently resolves all eight contexts (two
Dishes, two types,8/9 November) as READY. None of the new four adjustments applies
on8 November; on9 November only the exact new scoped adjustment applies.

The earlier Owner Recipe3529 decision (Dish2071/type2, pork5.5kg/100 portions)
remains effective and is included in the review packet's five confirmed decisions.

## Complete review packet and remaining differences

System capture covers1,534 mapped typed contexts:1,195 MATCH,331 DIFFERENCE,
0 missing and8 source-absent. Affected-School capture covers1,962 contexts across
17 Schools:1,905 DIFFERENCE,0 missing and57 BLOCKED for inactive Schools11/20/21.
This School scope covers contexts related to current School overrides; it is not
every Cartesian School/Dish combination. System-level differences are represented
once rather than duplicated for every School inheriting that system context.

The XLSX contains5,740 changed-Ingredient rows:647 system and5,093 School rows,
covering2,236 distinct difference contexts. Each row retains controlled Ingredient
identity, Unit, exact normalized v1/Atlas values per100 portions, related source
orders and an explicit cause. Separate sections retain65 exceptional contexts
(8 source absent,57 inactive School) and the five confirmed Owner decisions.
Blank editable fields are review inputs, never implied approval or DB writes.
An absent Ingredient is not represented as numeric zero.

Final workbook SHA256:
`5bac42dd3c5f31d924af6c13f53c96abd7109892f847defb18557ebc28afdf0f`.
All5,740 exported rows and24 columns were checked against the supplied packet;
keys, names, exact/numeric quantities, causes, decisions and blank reviewer fields
match. Native XLSX checks confirm four sheets, header/identifier freezing,
review dropdowns, filters, zero formula errors and no external/private-file links.
Representative rendered ranges were inspected. Initial artifact reimport compared
empty strings against normalized Excel null cells and failed that assertion;
the blank comparison was corrected without changing zero or quantity semantics.
The final native value/control verification passes; no initial failure is hidden.

The331 system contexts classify as follows:

| Cause                                                            | Contexts | Treatment                                                                                                     |
| ---------------------------------------------------------------- | -------: | ------------------------------------------------------------------------------------------------------------- |
| Actual source system Recipe orders not yet adopted               |      248 | Staff review                                                                                                  |
| Global order13, Thịt vai heo1042→Nạc vai heo1041                 |       76 | Staff review; do not activate the global rule                                                                 |
| Source inactive Bột mì903 omitted from effective view            |        2 | Xíu mại sốt cà1672, both types: source base retains0.5kg, v1 Ingredient inactive, Atlas active; staff decides |
| Owner total pork decision for1735                                |        2 | Intentional difference:3.5kg/5kg, not doubled source totals                                                   |
| 1802 source view-chain conflict plus other unadopted ingredients |        2 | Mushroom decision saved; other ingredients still await staff                                                  |
| Owner pork correction for3529                                    |        1 | Intentional difference: pork5.5kg instead of source beef                                                      |

After removing the two duplicate1735 lines,25 current typed contexts still have
both1041 and1042. This does not make global order13 safe: preserve line identity,
do not aggregate away contributions or infer the other dishes' intended totals
from the one confirmed dish. The source also retains471 active system rows with
445 ranked winners and112 active School replacements. Archived source activity
is not automatic current Atlas authority. No further batch adoption is performed
before staff review.

Source/target reads are separate READ ONLY transactions. School source batches
reuse the original definition with only exact School/Dish narrowing, retaining
ranking/recursion. Quantities compare as exact rational numbers normalized to100
portions; only approved kg/Kilogram and Hủ/Hũ aliases apply. Source-related order
IDs in the workbook are context lookup evidence, not a claim that every listed
order applies to each changed Ingredient line. Raw payloads stay outside Git.

## Test disposal verification gate

The read-only inventory and private backup are preparation, not a successful
deletion. The final fixed manifest, exact business-trigger allowlist, protected
facts, actual-schema purge/restore rehearsal, code review, certification,
rollback Preview and guarded Apply/readback must all be recorded before claiming
cleanup complete. Preserve v1 masters/Recipes/mappings,605 source history records,
all import receipts, nine business adjustment roots/revisions, access/audit,
shared Units and configuration. The three separately proven old fixture
adjustments and unmapped synthetic masters belong to the authorized test purge.

The only lock exception is platform-owned, SELECT-only `auth.schema_migrations`:
its explicit ACCESS SHARE lock respects existing privileges. All other selected
tables use ACCESS EXCLUSIVE. Exact before/after ledger and catalog comparisons
must pass; the platform ledger is observed unchanged, not serialized against
concurrent platform writers. No grants, roles or security guards are changed.

The completed disposable recovery rehearsal at source commit `da37a0c9` returned
`RESTORED_EXACTLY`: same-path Preview deleted27,431 rows and rolled back; actual
purge deleted27,402 operational rows and29 fixture rows; all FK checks passed
before restoration. All67 external backup files then restored27,431 rows in place.
The75 reviewed business restore guards were restored exactly. Full row/catalog
equality and validated FKs passed before commit and again after commit. A second
independent external reconstruction matched. Actual Staging semantic schema hash
is `08fc31ff1cd527b348767e61ab2fcde2783d1e6b8a419ddd166a23d407100708`.

This local data set is a partial protected FK closure, with zero mapped resolver
contexts; it proves exact recovery of the disposal set, not a complete Staging
database or resolver restoration. Hosted execution separately requires all1,534
mapped system contexts and exact before/after canonical compositions. A fresh
receipt must execute from eventual certified main; the earlier commit identity
must never be relabeled. The fresh main proof and hosted execution are recorded below.

The bootstrap overlay only restores eight formatting-only function definitions
and one explicit owner ACL in newly created disposable databases. Direct source
category checks confirmed the original Unicode CHECK definitions already match
Staging; no CHECK or hosted schema changes are needed.

## Verified hosted disposal

PR464 was merged as main `1f83f6f878b761c1736e34414d6d0bda9d67d458` after
exact-head Frontend42588674411 and executed Full Integration42588674402 passed,
with independent architecture/security/recovery review. Main itself was then
certified by [Frontend42590891782](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/42590891782)
and [Full Integration42590892103](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/42590892103).
The actual Full Integration job and certification step passed; skipped Smoke is
not counted as an executed certificate.

A fresh external recovery rehearsal executed from that exact clean main and
returned `RESTORED_EXACTLY`. Its canonical JSON proof checksum is
`ba611d69c55d7e4effc466dc31a636db3c1b08b7d5bb63475bdea4f9916f90b5`.
All three executing source hashes match the reviewed implementation; the prior
receipt was preserved and never relabeled. No raw backup files were uploaded.

[Hosted Preview42593389650](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/42593389650)
executed the real27,431-row disposal and rolled back. It verified1,534 mapped
system contexts and1,538 canonical contexts at9 November. Independent read-only
counts, identities, history, mappings and ten Owner context hashes matched the
pre-Preview baseline exactly. Independent review approved its actual content
checksum `23ebf70dd07cb3f95b83b18e71bdda0a07f44c545c1b8c197dd60271c9306449`.

[Apply42594135361](https://github.com/longpsu-bot/thuonghao-ops-erp/actions/runs/42594135361)
was dispatched once and succeeded with `APPLIED`, no rollback and that exact
reviewed checksum. It deleted27,402 operational rows plus29 fixture rows:
27,431 total, including54 POs and22 School dispatch releases. All immediate FK
checks, exact DELETE RETURNING membership, protected row hashes and canonical
comparisons passed. Original trigger modes and raw catalog were restored before
commit; the catalog checksum remains
`bdba1effd71a641aadcf5b235a41f193ad468452602ff738d2137af237f6581b`.

Independent post-Apply READ ONLY verification confirms:

- All76 allowlisted operational tables contain zero rows.
- The exact nine business adjustment roots and nine revisions retain their full
  PostgreSQL row texts; only the three proven old test adjustments were removed.
- All ten Owner current/historical context hashes remain identical.
- All605 v1 history records,767 mapped Dishes and14,558 mappings remain.
- Zero unvalidated Atlas FKs and zero abnormal Atlas trigger states.
- The delivered XLSX retains its verified SHA256 above.

All v1 masters, Recipes, import receipts, shared Units, six configuration
families, access/audit and unrelated facts were preserved by exact outside-set
hash checks. The platform-owned auth migration ledger was observed unchanged
under its documented ACCESS SHARE exception. No persistent schema, API, role,
grant, RLS or security-guard change was made. Source OPS v1 and Production were
not written. Warehouse and real Supplier cancellation remain excluded.

The disposal horizon is closed. Do not replay this one-off command or earlier
imports, reseed the deleted tests, infer staff acceptance or start a pilot.
Recovery uses the retained private67-file backup and reviewed demonstrated
restore. The complete workbook remains the staff decision queue; unconfirmed
Recipe differences are unchanged until reviewed through governed commands.
