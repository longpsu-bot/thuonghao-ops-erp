# Decision D-047 — Proven OPS-v1 Recipe Unit adoption repair

**Status:** Accepted

**Date:** 24/09/2026

**Approval:** Product Owner, bounded task authorization
`TASK-PLANNING-D046-ADOPTION-CLOSEOUT`.

## Decision

Atlas may repair a Recipe Unit mismatch only when explicit OPS-v1 adoption
lineage proves that the predecessor Recipe line retained the imported legacy
BoM Unit while the operational legacy path used the same Ingredient's purchase
Unit. The repair creates an immutable direct Recipe-version and line-revision
successor. It keeps the Ingredient, numeric `quantity_per_basis`, generated
theoretical quantity, School, service date, Customer, Delivery Location, and
all contribution source identities unchanged. It performs no conversion and
has no conversion factor.

The corrected Unit must equal the Ingredient's authoritative
`purchase_unit_id`. The predecessor Unit must equal the mapped raw OPS-v1 BoM
Unit. Equality of quantity plus a changed Unit is never sufficient. Missing,
ambiguous, remapped, native, or incomplete provenance fails closed under the
normal cross-Unit Planning invariant.

This is a bounded adoption correction, not a general Unit-change capability.
In particular, the native `UIQ03A_SAVE` Cánh gà mismatch has no OPS-v1 Recipe
line adoption evidence and remains blocked by D-046.

## Evidence and authority

The private, forced-RLS
`atlas_legacy.recipe_unit_adoption_evidence` relation is a generated supporting
object. Atlas retains the imported snapshot identity, completed import batch,
typed mappings, source fingerprints, and immutable Recipe facts, but does not
persist the raw master snapshot payload. Durable line-level evidence is
therefore required to prove the exact raw Unit, corrected Unit, unchanged
quantity, stable line, and direct predecessor/successor pair later.

The relation is not a bypass flag and is not duplicate business authority.
Eligibility remains derived from the joined import, mapping, Ingredient,
Recipe, and Planning facts. No public API or browser role can write or read the
relation. Evidence is insert-only and may be created only by the governed
import/correction boundary.

Candidate proof includes exactly one matching completed-import reconciliation
action for the target Recipe-line revision. The action must repeat the same
Recipe, stable line, Ingredient, numeric quantity, and raw Unit; target-only or
partially matching actions are insufficient. The migration itself requires
exactly one target action, exactly one exact action, and exactly one OPS-v1
mapping for the Recipe, Recipe version, stable line, revision, Ingredient, raw
Unit, and corrected Ingredient purchase Unit. Duplicate actions or missing or
ambiguous typed mappings make the candidate ineligible even if the hosted
manifest gate is bypassed. Post-repair proof compares every successor and
unaffected sibling directly with its predecessor rather than inferring
correctness from cardinality alone.

## Recipe and Planning behavior

Newly released PRESENT Recipe lines must use their Ingredient purchase Unit.
Existing released history is not rewritten. The adoption migration may create
proven successors for already committed Recipes; ordinary Recipe edits and
unproven post-use changes remain blocked by `RECIPE_COMMITTED_USE`.

The private Planning transition predicate accepts a Unit-changing theoretical
successor only when the complete D-047 evidence join succeeds and every
non-Unit identity and numeric quantity is unchanged. The public RMVP-04
signatures and envelopes do not change. D-046 then derives the proposal from
the corrected Unit and the exact snapshotted `Ingredient.order_step`.

Old Need releases, Confirmed Need memberships, source snapshots, Recipe
versions, and pre-D-046 null proposal-snapshot revisions remain immutable and
are not backfilled. A correction creates successor lineage. Human Confirmed
Need authority is neither fabricated nor copied across a Unit-changing or
merge-changing identity; D-040 continuity remains available only when its
separate unchanged-identity predicate is fully satisfied.

## Failure, security, and rollback

Safe failures remain configuration or source-lineage failures; they do not
expose legacy payloads, conversion suggestions, or alternate quantities. The
new private predicate and evidence relation retain empty-search-path,
least-privilege, and forced-RLS boundaries.

Before deployment, rollback is removal of the unmerged change. After
deployment, immutable Recipe successors and evidence are retained; rollback is
a reviewed forward fix governing future selection or validation. If a Planning
correction has run, its predecessor/successor runs and Confirmed Need revisions
also remain immutable.

## Related authority

- [D-039](decision-register.md): Recipe replacement correction lineage.
- [D-040](decision-register.md): selective human-decision continuity.
- [D-042](decision-register.md): explicit source-correction workflow.
- [D-046](decision-planning-operational-proposal.md): exact proposal Unit and
  Ingredient-step authority.
- [Implementation task](../implementation-tasks/TASK-PLANNING-D046-ADOPTION-CLOSEOUT.md).

## Current-source recovery clarification — 26/09/2026

Facts remain explicit, state derived, and supporting objects generated. Source
currentness and Recipe adoption correction necessity are independent. A current
terminal Need run embedding a proven D-047 predecessor requires regeneration even
when all completed source fingerprints remain `CURRENT`. The released exact
adoption successor and immutable provenance derive this requirement; callers
cannot request an exemption. An ordinary newer Recipe or the native Cánh gà
mismatch remains ineligible.

The canonical atomic Need command records `PLANNING_CORRECTION` for this
unchanged-source invalidation and preserves the separate readiness review reason.
After correction it naturally returns `NO_CHANGE`. The migration changes future
execution only: it does not backfill evidence, proposals, receipts or released
history. Rollback after deployment is a reviewed forward migration restoring the
prior private command definition and revoking/removing its unused private helper
and read policies; any already-created correction history must be retained.

The earlier hosted D046 attempt returned successful `NO_CHANGE`, producing an
immutable audit receipt without a business-state mutation. Closeout accepts at
most one exactly qualified benign attempt alongside the original generation
receipt, and requires a separate completed successor-generation receipt. Unknown
extra receipts or multiple benign attempts fail closed. This history is neither
corruption nor successful correction evidence.
