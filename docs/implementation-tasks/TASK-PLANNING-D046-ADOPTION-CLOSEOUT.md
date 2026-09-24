# TASK-PLANNING-D046-ADOPTION-CLOSEOUT — Legacy Recipe Unit adoption repair

## Status and authority

Owner-approved for implementation on 24/09/2026 with the narrow conditions
recorded below. Implementation must start from
`55a9fb2702043fba7c8f3a7d8cdcc43a76577808` on
`fix/planning-d046-adoption-closeout`. This task authorizes a Draft PR only. It
does not authorize merge, deployment, a protected hosted workflow, or any
Staging business-data write.

The implemented authority is registered as
[D-047](../decisions/decision-planning-legacy-adoption-unit-repair.md) and
BR-047. D-047 is subordinate to the exact provenance conditions in this task
and does not broaden D-046 or create a general Unit-change capability.

The canonical checkout for this task is
`E:/Project/OPS ERP/thuonghao-ops-erp`. Live OPS v1 and Retool are read-only
evidence sources. PR #286 and Procurement are outside scope.

## Root-cause verdict

The defect is in the OPS-v1 master-data adoption boundary, not D-046.

The OPS-v1 snapshot retained each `bill_of_materials.purchase_unit` as
`recipe_lines.unit_legacy_id`, and the Atlas Recipe importer resolved that
field directly into `atlas_admin.recipe_line_revisions.unit_id`. OPS v1's
effective Planning chain instead carried the BoM numeric usable quantity
unchanged while reattaching `ingredients.purchase_unit`. Atlas therefore made
the raw legacy BoM label authoritative where the legacy operational system had
made the Ingredient purchase Unit authoritative.

The old import passed because Recipe release/adoption only required an active
Ingredient, active Unit, and positive quantity. It did not require the released
Recipe Unit to equal the Ingredient purchase Unit. D-046 exposed the defect by
correctly requiring the grouped theoretical Unit, Ingredient purchase Unit,
and `Ingredient.order_step` Unit to be identical before proposal derivation.

No affected numeric quantity requires conversion. The repair changes Unit
authority while retaining the exact numeric quantity.

## Proven affected catalog

| OPS-v1 Ingredient                            | Raw BoM label | OPS-v1 effective / Atlas target Unit | Current affected Atlas lines |
| -------------------------------------------- | ------------- | ------------------------------------ | ---------------------------: |
| 956 — Đùi góc tư gà                          | Cái           | Kilogram (`Kg`)                      |                           22 |
| 1012 — Sữa chua uống Ánh Hồng 70ml hương dâu | Bịch          | Chai                                 |                            2 |
| 1045 — Thơm                                  | Quả           | Trái                                 |                           50 |
| 1057 — Chuối poli                            | Cái           | Quả                                  |                            2 |
| **Total**                                    |               |                                      |                       **76** |

The 76 mapped line revisions belong to 74 current released Recipe versions.
Their successor versions copy 322 PRESENT lines: 76 corrected lines and 246
unchanged lines. All 76 have `OPS_V1` Ingredient, Recipe line, Recipe-line
revision, import-batch, source-fingerprint, and raw snapshot evidence.

The selected 14–18/09 workload contains 24 generated occurrences from eight
mapped legacy lines across three of these Ingredients. The current-to-corrected
Confirmed Need group counts are:

| Service date | Before | Corrected |
| ------------ | -----: | --------: |
| 14/09/2026   |    232 |       231 |
| 15/09/2026   |    225 |       225 |
| 16/09/2026   |    213 |       213 |
| 17/09/2026   |    248 |       248 |
| 18/09/2026   |    210 |       210 |

The 14/09 reduction is exactly one merge: two BÌNH QUỚI / Thơm groups with the
same date, customer, school, and delivery location previously differed only by
`Quả` versus `Trái`; both become one `Trái` group. Contribution membership and
numeric quantities are unchanged. No other corrected group merges, splits, or
disappears.

## Explicitly excluded native configuration

The released `UIQ03A_SAVE` Cánh gà line has no OPS-v1 Recipe-line adoption
mapping. Its Recipe Unit is `Kilogram` while its Ingredient purchase Unit is
`Cái`. It must not receive transition evidence, normalization, aliasing, or an
exemption. D-046 must continue returning its existing configuration blocker.

This exclusion is a required acceptance test: it proves the repair is derived
from historical adoption facts rather than a generic cross-Unit bypass.

## Approved business contract

A cross-Unit Recipe successor may cross the existing Planning no-conversion
boundary only when all of these facts are proven together:

1. `source_system = 'OPS_V1'` and authoritative adoption mappings exist for
   the Ingredient, Recipe, stable Recipe line, predecessor revision, and source
   import batch.
2. The predecessor Unit equals the raw imported BoM-line Unit.
3. The successor Unit equals the same Ingredient's authoritative
   `purchase_unit_id`.
4. Stable Recipe line and `ingredient_id` are unchanged.
5. `quantity_per_basis` and the generated theoretical quantity are numerically
   unchanged.
6. There is no conversion factor, conversion operation, alias inference, or
   fallback.
7. Service date, customer, school, delivery location, and contribution source
   identities are unchanged.
8. The old Recipe versions, Recipe-line revisions, Need runs, release snapshots,
   Confirmed Need revisions, source snapshots, and fingerprints remain
   immutable.
9. The successor Recipe version and line revision have direct predecessor
   lineage and immutable bounded correction evidence.
10. D-046 derives the proposal from the corrected Ingredient Unit and the
    snapshotted `Ingredient.order_step`.
11. A Unit-changing or merge-changing line receives no fabricated human
    decision. Existing D-040 continuity may carry authority only for a separate
    unchanged exact operational identity that already satisfies its full
    governed predicate.

Eligibility is derived from provenance. Equality of quantities plus a changed
Unit is never sufficient.

## Architecture and data design

### Future/replay adoption

The normalized snapshot continues to preserve the raw BoM label in
`recipe_lines.unit_legacy_id`; changing that fact or its fingerprint would
erase source evidence. `atlas_legacy.master_recipe_composition` and the Recipe
plan instead resolve the operational `unit_id` through the mapped Ingredient's
`purchase_unit_id`. Reconciliation compares this operational composition to
the current released Recipe, so already-correct rows remain `NO_CHANGE` and
only real mismatches get successors.

Import validation independently proves that the referenced snapshot
Ingredient is active, its purchase Unit resolves, and the raw BoM Unit also
resolves for evidence. Replay of the same completed snapshot remains
idempotent.

### Immutable transition evidence

Add a private, forced-RLS relation named
`atlas_legacy.recipe_unit_adoption_evidence`. One row records either a future
raw-label/operational-Unit adoption fact or one corrected Recipe-line revision
transition and contains:

- the completed import batch and `OPS_V1` snapshot identity;
- stable legacy Recipe-line identity and source fingerprint;
- Recipe, stable Recipe line, target Recipe version/revision, and—for a
  correction row—the direct predecessor Recipe version/revision;
- unchanged Ingredient and `quantity_per_basis`;
- raw BoM source Unit and corrected Ingredient purchase Unit;
- evidence kind `OPS_V1_INGREDIENT_PURCHASE_UNIT_ADOPTION` for a new import or
  correction kind `OPS_V1_BOM_UNIT_TO_INGREDIENT_PURCHASE_UNIT_CORRECTION` for
  a predecessor/successor repair;
- responsible import actor and immutable recorded timestamp.

The relation has exact uniqueness, foreign keys, source/evidence-kind checks,
and supporting indexes for target-revision and predecessor-revision lookups.
Future imports write a row whenever the raw BoM Unit differs from the adopted
operational Unit, so that source fact remains queryable after import. Correction
rows additionally require direct predecessor/successor lineage. The relation
has no conversion-factor column and no browser/API grant. A guard rejects
updates/deletes and verifies the applicable Recipe rows and Ingredient purchase
Unit at insertion.

This persistent evidence is necessary because Recipe-version evidence retains
snapshot-level identity and mappings retain fingerprints/targets, but Atlas
does not persist the raw master snapshot itself. Without this generated
supporting object, a later Planning correction could not prove the exact raw
BoM Unit → Ingredient purchase Unit transition solely from authoritative
database facts.

### Current adopted data

The forward migration deterministically discovers the complete eligible set
from mappings, the completed import reconciliation, current released versions,
and raw snapshot evidence. It reconciles every eligible mismatch and proves
that its transitioned count equals its eligible count before commit. An empty
database or a database without a completed OPS-v1 import is a valid no-op, so
clean local resets remain installable. The protected Staging preflight and
post-deployment readback, rather than a production-specific migration constant,
must prove the expected 76 line transitions across 74 Recipe successors with
322 PRESENT successor lines, of which 246 are exact copies.

For each affected Recipe the migration:

1. locks Recipes and Recipe versions in stable identifier order;
2. creates one deterministic successor Recipe version;
3. copies every current line with direct revision lineage;
4. replaces only each proven line's Unit with the Ingredient purchase Unit;
5. keeps Ingredient, quantity, note, basis, scope, and stable line identity;
6. records transition evidence before release;
7. validates the successor, locks the released predecessor, and releases the
   successor atomically;
8. leaves source mappings, import batches, and source fingerprints pointing to
   their original imported facts; it updates only the recorded target version
   of a predecessor mapping when the importer-owned lifecycle lock requires
   that existing drift bookkeeping.

The native Cánh gà line cannot enter the candidate query because it lacks the
required Recipe-line adoption mapping and raw import evidence.

This migration is the sole exception to the normal `RECIPE_COMMITTED_USE`
prohibition. It may create successors for operationally used Recipes only when
every row in the affected version is handled by the provenance-qualified,
no-conversion adoption repair above. The reconciler is private, migration-owned,
and exposes no alternate Recipe-edit command. Normal UI/API saves, releases,
imports, and unrelated post-use composition changes continue to return
`RECIPE_COMMITTED_USE`.

### Mandatory hosted adoption manifest

Deployment is prohibited until a repository-owned read-only Staging verifier
proves the current pre-migration manifest is still exactly:

- 76 eligible lines across 74 current released versions;
- four and only four approved OPS-v1 Ingredients: `956`, `1012`, `1045`, and
  `1057`;
- 322 projected successor PRESENT rows, comprising 76 corrected rows and 246
  exact sibling copies;
- complete import/mapping/fingerprint/raw-Unit evidence for every candidate;
- zero native or partially mapped candidates, with Cánh gà explicitly excluded.

Any drift blocks deployment and requires owner review. After deployment, the
same verifier runs in post-deploy mode and proves that the exact manifest became
74 immutable successors and 76 correction-evidence rows with all sibling facts
preserved. Both phases are read-only; neither verifier applies the migration or
changes business data.

### Release invariant

The backend Recipe-version integrity boundary rejects any newly released
PRESENT Recipe line whose Unit differs from its Ingredient purchase Unit. This
applies to all release paths, including native Save/release and import, without
rewriting already released history. Error output is safe and actionable.

### Planning transition

The existing `SOURCE_SPLIT_MERGE_POLICY_REQUIRED` guard remains the default.
Its Unit-difference branch accepts only a direct theoretical successor whose
new Recipe-line revision has one matching correction row in
`recipe_unit_adoption_evidence` and whose predecessor/successor facts
satisfy every approved identity and quantity equality above. Any missing,
ambiguous, inconsistent, native, or converted transition still fails closed.

D-046's configuration predicate and exact proposal formula remain unchanged.

## Preserved 17/09 correction contract

The deployed Recipe repair makes the current Recipe successor authoritative,
but does not touch the preserved Planning evidence. The preflight therefore
derives `OUTDATED` while the selected/current Menu, Attendance, and Pantry
fingerprints remain equal. A separately
owner-authorized one-shot invocation of existing `RMVP-04.v3`
`execute_need_generation` performs the correction:

```text
old run 0c83… v3 RELEASED_FOR_CONFIRMATION
→ invalidated in place to v4, release snapshot retained
→ one direct successor run v3 RELEASED_FOR_CONFIRMATION
→ same batch a031… rematerialized from v1 to v2
→ old current revisions become historical
→ 248 new current revisions carry D-046 step/version snapshots
→ zero human decisions and zero Purchase Handoffs
```

The selected/current Weekly Menu, Attendance, and Pantry fingerprints remain
byte-identical. The TÂN AN HỘI / Thơm contribution keeps numeric theoretical
quantity `3.800000` while transitioning `Quả → Trái` through the proven Recipe
line successor. Current group count remains 248.

The one-shot correction tool performs exact read-only preflight, sends at most
one command, never retries an uncertain outcome, and resolves uncertainty only
through authoritative readback. It is not part of a protected workflow and is
not run by this task.

## Protected certification contract

The browser closeout accepts only `D046_CORRECTED_RESUME`, not the old
`PRISTINE_GENERATED_RESUME`. Before browser Save it proves:

- the fixed old run and batch still exist;
- exactly one direct released successor run is current;
- the old run is INVALIDATED v4 and the successor is v3;
- both release snapshots retain 304 generated contributions;
- the same batch is DRAFT_REVIEW v2 and points from the old origin to the new
  current run;
- there are exactly 248 current revisions, all with positive non-null D-046
  snapshot pairs and exact upward-rounded proposals;
- every old pre-D-046 revision remains retained with its null snapshot pair;
- zero decisions, Save receipts, and Purchase Handoffs;
- one original and one correction generation receipt, with no duplicate or
  replayed correction;
- source fingerprints are unchanged.

After the one browser Save, the same two-run/one-batch lineage remains; the
batch advances once to v3 and contains 248 first decisions (one adjustment and
247 proposal acceptances), one Save receipt, and zero Purchase Handoffs.

The performance verifier expects `231, 231, 225, 213, 210`. Each 14/09 probe
also proves, from contribution and adoption evidence, 232 legacy-label groups
project to 231 corrected groups through exactly one two-to-one merge with zero
contribution loss and no split.

The following post-merge owner sequence is deliberately unexecuted by this
implementation task and is strictly ordered:

```text
merge reviewed PR
→ run read-only pre-deploy adoption manifest against Atlas Staging
→ if and only if exact 76/74/322/246 + four-Ingredient + Cánh exclusion PASS, authorize deployment
→ deploy exact merged SHA/migration to Atlas Staging
→ run read-only post-deploy adoption manifest and catalog/preflight proof
→ protected Planning Performance
→ if and only if PASS, separately authorize and run one 17/09 correction
→ read-only D046_CORRECTED_RESUME proof
→ pin immutable frontend deployment for exact certified SHA
→ protected Planning Browser Closeout
→ final read-only proof
→ declare certified only when both independent statuses PASS
```

None of these steps is authorized by implementation, test, merge, or the
presence of a ready script alone. Each hosted mutation retains its existing
protected authorization boundary. Planning is certified only when the
independent Performance and Browser Closeout statuses both pass.

## Security and rollback

All new evidence is private, forced-RLS, least-privilege, and inaccessible to
`public`, `anon`, `authenticated`, and `service_role`. Existing security-
definer functions keep an empty `search_path`; no browser relation grant,
service-role credential, timeout change, retry, or RLS weakening is allowed.

Before deployment, rollback is removal of the unmerged migration and code.
After deployment, Recipe successors and transition evidence are immutable and
must not be deleted or rewritten; rollback is a reviewed forward fix that
changes future selection/validation while retaining every Recipe and Planning
fact. If the owner-authorized 17/09 correction has run, both Need runs and all
old/new Confirmed Need revisions also remain immutable.

## Acceptance criteria

- Exactly 76 proven OPS-v1 lines across 74 current versions receive the repair;
  246 copied sibling lines remain byte-equivalent in business facts.
- Raw BoM labels, quantities, mappings, fingerprints, import batches, and old
  Recipe/Planning rows remain auditable.
- Future/replay import uses Ingredient purchase Unit operationally and is
  idempotent.
- Native Cánh gà and every unproven cross-Unit configuration remain blocked.
- No conversion, alias inference, quantity rewrite, generic exception flag, or
  new public business command exists.
- Release rejects new Recipe/Ingredient Unit mismatches at the backend.
- Initial and correction materialization preserve exact quantities,
  contribution membership, immutable history, and D-046 proposal evidence.
- Corrected counts are 231/231/225/213/210 for performance dates and 248 for
  17/09, with the one 14/09 merge proven rather than assumed.
- The closeout verifier is ready for the corrected pre-Save checkpoint but no
  hosted correction or protected workflow is run by this task.
- A read-only pre-deploy manifest gate blocks deployment on any deviation from
  76/74/322/246, the four approved Ingredients, or native Cánh gà exclusion;
  post-deploy readback proves the same manifest was repaired.
