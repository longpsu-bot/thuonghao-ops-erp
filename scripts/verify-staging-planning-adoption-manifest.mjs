import { fileURLToPath } from "node:url";
import {
  executeAtlasStagingManagementSql,
  validateAtlasStagingPackageProtectedValues,
  redactAtlasStagingDiagnostic,
} from "./atlas-staging-contract.mjs";
import { verifyPackageCheckout } from "./install-atlas-staging-package.mjs";

const PHASES = new Set(["pre-deploy", "post-deploy"]);
const EXPECTED_INGREDIENTS = ["956", "1012", "1045", "1057"];
const EXPECTED = Object.freeze({
  eligibleLineCount: 76,
  affectedReleasedVersionCount: 74,
  projectedSuccessorPresentCount: 322,
  correctedLineCount: 76,
  copiedSiblingCount: 246,
  legacyIngredientIds: EXPECTED_INGREDIENTS,
  excludedNativeMismatchCount: 1,
  excludedNativeSourceKind: "UIQ03A_SAVE",
});

const sameArray = (left, right) =>
  Array.isArray(left) &&
  left.length === right.length &&
  left.every((value, index) => value === right[index]);

export function classifyPlanningAdoptionManifest(snapshot, phase) {
  const reject = () => {
    throw new Error("PLANNING_ADOPTION_MANIFEST_REJECTED");
  };
  if (!PHASES.has(phase) || snapshot?.phase !== phase) reject();
  const accepted =
    snapshot.eligible_line_count === 76 &&
    snapshot.affected_released_version_count === 74 &&
    snapshot.projected_successor_present_count === 322 &&
    snapshot.corrected_line_count === 76 &&
    snapshot.copied_sibling_count === 246 &&
    sameArray(snapshot.legacy_ingredient_ids, EXPECTED_INGREDIENTS) &&
    snapshot.excluded_native_mismatch_count === 1 &&
    snapshot.excluded_native_source_kind === "UIQ03A_SAVE" &&
    snapshot.incomplete_candidate_count === 0 &&
    snapshot.duplicate_candidate_count === 0 &&
    snapshot.remapped_source_count === 0 &&
    snapshot.exact_reconciliation_action_count === 76 &&
    (phase === "pre-deploy" ||
      (snapshot.correction_evidence_count === 76 &&
        snapshot.direct_successor_version_count === 74 &&
        snapshot.successor_present_count === 322 &&
        snapshot.exact_sibling_copy_count === 246 &&
        snapshot.locked_predecessor_version_count === 74 &&
        snapshot.successor_version_mismatch_count === 0 &&
        snapshot.sibling_mismatch_count === 0));
  if (!accepted) reject();
  return { ...EXPECTED, legacyIngredientIds: [...EXPECTED_INGREDIENTS] };
}

function preDeployManifestSql() {
  return `begin read only;
with released_mismatches as materialized (
  select version.recipe_id,version.recipe_version_id,line.recipe_line_revision_id,line.recipe_line_id,
         line.ingredient_id,line.unit_id source_unit_id,ingredient.purchase_unit_id corrected_unit_id,
         line.quantity_per_basis,version.source_evidence->>'source_kind' source_kind
  from atlas_admin.recipe_versions version
  join atlas_admin.recipe_line_revisions line
    on line.recipe_version_id=version.recipe_version_id and line.line_disposition='PRESENT'
  join atlas_admin.ingredients ingredient on ingredient.ingredient_id=line.ingredient_id
  where version.recipe_version_status='RELEASED_FOR_PLANNING'
    and line.unit_id<>ingredient.purchase_unit_id
),candidate_authority as materialized (
  select mismatch.*,
         line_mapping.legacy_id legacy_recipe_line_id,
         ingredient_mapping.legacy_id legacy_ingredient_id,
         revision_mapping.last_source_fingerprint source_fingerprint,
         revision_mapping.last_seen_import_batch_id,
         batch.import_batch_id complete_import_batch_id,
         version_mapping.recipe_version_id mapped_recipe_version_id,
         source_unit_mapping.unit_id mapped_source_unit_id,
         corrected_unit_mapping.unit_id mapped_corrected_unit_id,
         coalesce(actions.target_action_count,0) target_action_count,
         coalesce(actions.exact_action_count,0) exact_action_count
  from released_mismatches mismatch
  left join atlas_legacy.master_data_mappings line_mapping
    on line_mapping.source_system='OPS_V1' and line_mapping.object_type='RECIPE_LINE'
   and line_mapping.recipe_line_id=mismatch.recipe_line_id
  left join atlas_legacy.master_data_mappings revision_mapping
    on revision_mapping.source_system='OPS_V1' and revision_mapping.object_type='RECIPE_LINE_REVISION'
   and revision_mapping.recipe_line_revision_id=mismatch.recipe_line_revision_id
  left join atlas_legacy.master_data_mappings version_mapping
    on version_mapping.source_system='OPS_V1' and version_mapping.object_type='RECIPE_VERSION'
   and version_mapping.recipe_version_id=mismatch.recipe_version_id
  left join atlas_legacy.master_data_mappings ingredient_mapping
    on ingredient_mapping.source_system='OPS_V1' and ingredient_mapping.object_type='INGREDIENT'
   and ingredient_mapping.ingredient_id=mismatch.ingredient_id
  left join atlas_legacy.master_data_mappings source_unit_mapping
    on source_unit_mapping.source_system='OPS_V1' and source_unit_mapping.object_type='UNIT'
   and source_unit_mapping.unit_id=mismatch.source_unit_id
  left join atlas_legacy.master_data_mappings corrected_unit_mapping
    on corrected_unit_mapping.source_system='OPS_V1' and corrected_unit_mapping.object_type='UNIT'
   and corrected_unit_mapping.unit_id=mismatch.corrected_unit_id
  left join atlas_legacy.import_batches batch
    on batch.import_batch_id=revision_mapping.last_seen_import_batch_id
   and batch.source_system='OPS_V1' and batch.import_status='COMPLETED'
  left join lateral (
    select
      count(*) filter (where action.value->>'object_type'='RECIPE_LINE_REVISION'
        and action.value->>'target_id'=mismatch.recipe_line_revision_id::text)::integer target_action_count,
      count(*) filter (where action.value->>'object_type'='RECIPE_LINE_REVISION'
        and action.value->>'target_id'=mismatch.recipe_line_revision_id::text
        and action.value#>>'{values,recipe_id}'=mismatch.recipe_id::text
        and action.value#>>'{values,recipe_line_id}'=mismatch.recipe_line_id::text
        and action.value#>>'{values,ingredient_id}'=mismatch.ingredient_id::text
        and (action.value#>>'{values,quantity_per_basis}')::numeric=mismatch.quantity_per_basis
        and action.value#>>'{values,unit_id}'=mismatch.source_unit_id::text)::integer exact_action_count
    from jsonb_array_elements(coalesce(batch.reconciliation->'actions','[]'::jsonb)) action(value)
  ) actions on true
),eligible as materialized (
  select * from candidate_authority where legacy_recipe_line_id is not null
    and legacy_ingredient_id is not null and source_fingerprint is not null
    and last_seen_import_batch_id is not null and complete_import_batch_id is not null
    and mapped_recipe_version_id is not null and mapped_source_unit_id is not null
    and mapped_corrected_unit_id is not null and quantity_per_basis>0
    and exact_action_count=1
),affected as materialized (
  select distinct recipe_version_id from eligible
),projected as materialized (
  select line.recipe_line_revision_id,line.recipe_version_id,
         exists(select 1 from eligible e where e.recipe_line_revision_id=line.recipe_line_revision_id) corrected
  from atlas_admin.recipe_line_revisions line join affected using(recipe_version_id)
  where line.line_disposition='PRESENT'
)
select jsonb_build_object(
  'phase','pre-deploy',
  'eligible_line_count',(select count(*)::integer from eligible),
  'affected_released_version_count',(select count(*)::integer from affected),
  'projected_successor_present_count',(select count(*)::integer from projected),
  'corrected_line_count',(select count(*)::integer from projected where corrected),
  'copied_sibling_count',(select count(*)::integer from projected where not corrected),
  'legacy_ingredient_ids',(select coalesce(jsonb_agg(legacy_ingredient_id order by legacy_ingredient_id::integer),'[]') from (select distinct legacy_ingredient_id from eligible) ids),
  'excluded_native_mismatch_count',(select count(*)::integer from released_mismatches mismatch where mismatch.source_kind='UIQ03A_SAVE' and not exists(select 1 from eligible e where e.recipe_line_revision_id=mismatch.recipe_line_revision_id)),
  'excluded_native_source_kind','UIQ03A_SAVE',
  'incomplete_candidate_count',(select count(*)::integer from candidate_authority where source_kind is distinct from 'UIQ03A_SAVE' and (legacy_recipe_line_id is null or legacy_ingredient_id is null or source_fingerprint is null or last_seen_import_batch_id is null or complete_import_batch_id is null or mapped_recipe_version_id is null or mapped_source_unit_id is null or mapped_corrected_unit_id is null or quantity_per_basis<=0 or exact_action_count<>1)),
  'duplicate_candidate_count',(select count(*)::integer from (
    select recipe_line_revision_id from candidate_authority
    where source_kind is distinct from 'UIQ03A_SAVE'
    group by recipe_line_revision_id
    having count(*)<>1 or max(exact_action_count)>1
  ) duplicates),
  'remapped_source_count',(select count(*)::integer from candidate_authority where source_kind is distinct from 'UIQ03A_SAVE' and target_action_count<>exact_action_count),
  'exact_reconciliation_action_count',(select count(*)::integer from candidate_authority where exact_action_count=1)
) as manifest;
rollback;`;
}

export function planningAdoptionPostDeployQuerySql() {
  return `with evidence as materialized (
  select * from atlas_legacy.recipe_unit_adoption_evidence
  where evidence_kind='OPS_V1_BOM_UNIT_TO_INGREDIENT_PURCHASE_UNIT_CORRECTION'
    and source_system='OPS_V1'
),successors as materialized (
  select target_recipe_version_id recipe_version_id,
         predecessor_recipe_version_id
  from evidence
  group by target_recipe_version_id,predecessor_recipe_version_id
),valid_successors as materialized (
  select target.recipe_version_id,predecessor.recipe_version_id predecessor_recipe_version_id
  from successors expected
  join atlas_admin.recipe_versions target
    on target.recipe_version_id=expected.recipe_version_id
   and target.predecessor_recipe_version_id=expected.predecessor_recipe_version_id
   and target.recipe_version_status='RELEASED_FOR_PLANNING'
  join atlas_admin.recipe_versions predecessor
    on predecessor.recipe_version_id=expected.predecessor_recipe_version_id
   and target.recipe_id=predecessor.recipe_id
   and target.version_number=predecessor.version_number+1
   and target.basis_portions=predecessor.basis_portions
   and target.source_evidence->>'source_kind'='OPS_V1_BOM_UNIT_TO_INGREDIENT_PURCHASE_UNIT_CORRECTION'
   and target.source_evidence->>'predecessor_recipe_version_id'=predecessor.recipe_version_id::text
),present as materialized (
  select line.* from atlas_admin.recipe_line_revisions line
  join successors using(recipe_version_id) where line.line_disposition='PRESENT'
),corrected as materialized (
  select distinct line.recipe_line_revision_id from present line
  join evidence on evidence.target_recipe_line_revision_id=line.recipe_line_revision_id
   and evidence.target_recipe_version_id=line.recipe_version_id
   and evidence.predecessor_recipe_line_revision_id=line.predecessor_recipe_line_revision_id
   and evidence.recipe_id=line.recipe_id and evidence.recipe_line_id=line.recipe_line_id
   and evidence.corrected_unit_id=line.unit_id and evidence.ingredient_id=line.ingredient_id
   and evidence.quantity_per_basis=line.quantity_per_basis
  join atlas_admin.recipe_line_revisions predecessor
    on predecessor.recipe_line_revision_id=line.predecessor_recipe_line_revision_id
   and predecessor.recipe_version_id=evidence.predecessor_recipe_version_id
   and predecessor.recipe_id=line.recipe_id and predecessor.recipe_line_id=line.recipe_line_id
   and predecessor.ingredient_id=line.ingredient_id
   and predecessor.quantity_per_basis=line.quantity_per_basis
   and predecessor.unit_id=evidence.source_unit_id
   and line.line_revision_number=predecessor.line_revision_number+1
),sibling_comparison as materialized (
  select successor.recipe_line_revision_id,
         predecessor.recipe_line_revision_id is not null
         and successor.recipe_id=predecessor.recipe_id
         and successor.recipe_line_id=predecessor.recipe_line_id
         and successor.line_revision_number=predecessor.line_revision_number+1
         and successor.ingredient_id=predecessor.ingredient_id
         and successor.quantity_per_basis=predecessor.quantity_per_basis
         and successor.unit_id=predecessor.unit_id
         and successor.line_disposition=predecessor.line_disposition
         and successor.calculation_kind is not distinct from predecessor.calculation_kind
         and successor.operational_note is not distinct from predecessor.operational_note exact_copy
  from present successor
  left join atlas_admin.recipe_line_revisions predecessor
    on predecessor.recipe_line_revision_id=successor.predecessor_recipe_line_revision_id
  where not exists(select 1 from corrected where corrected.recipe_line_revision_id=successor.recipe_line_revision_id)
),mapped as materialized (
  select evidence.*,
         revision_mapping.recipe_line_revision_id mapped_revision_id,
         revision_mapping.last_seen_import_batch_id mapped_batch_id,
         revision_mapping.last_source_fingerprint mapped_fingerprint,
         ingredient_mapping.legacy_id legacy_ingredient_id,
         batch.import_batch_id complete_batch_id,
         coalesce(actions.target_action_count,0) target_action_count,
         coalesce(actions.exact_action_count,0) exact_action_count
  from evidence
  left join atlas_legacy.master_data_mappings revision_mapping
    on revision_mapping.source_system='OPS_V1' and revision_mapping.object_type='RECIPE_LINE_REVISION'
   and revision_mapping.recipe_line_revision_id=evidence.predecessor_recipe_line_revision_id
  left join atlas_legacy.master_data_mappings ingredient_mapping
    on ingredient_mapping.source_system='OPS_V1' and ingredient_mapping.object_type='INGREDIENT'
   and ingredient_mapping.ingredient_id=evidence.ingredient_id
  left join atlas_legacy.import_batches batch on batch.import_batch_id=evidence.import_batch_id
   and batch.source_system='OPS_V1' and batch.import_status='COMPLETED'
   and batch.snapshot_id=evidence.snapshot_id and batch.snapshot_checksum=evidence.snapshot_checksum
  left join lateral (
    select
      count(*) filter (where action.value->>'object_type'='RECIPE_LINE_REVISION'
        and action.value->>'target_id'=evidence.predecessor_recipe_line_revision_id::text)::integer target_action_count,
      count(*) filter (where action.value->>'object_type'='RECIPE_LINE_REVISION'
        and action.value->>'target_id'=evidence.predecessor_recipe_line_revision_id::text
        and action.value#>>'{values,recipe_id}'=evidence.recipe_id::text
        and action.value#>>'{values,recipe_line_id}'=evidence.recipe_line_id::text
        and action.value#>>'{values,ingredient_id}'=evidence.ingredient_id::text
        and (action.value#>>'{values,quantity_per_basis}')::numeric=evidence.quantity_per_basis
        and action.value#>>'{values,unit_id}'=evidence.source_unit_id::text)::integer exact_action_count
    from jsonb_array_elements(coalesce(batch.reconciliation->'actions','[]'::jsonb)) action(value)
  ) actions on true
),native_mismatch as materialized (
  select line.recipe_line_revision_id,version.source_evidence->>'source_kind' source_kind
  from atlas_admin.recipe_versions version
  join atlas_admin.recipe_line_revisions line on line.recipe_version_id=version.recipe_version_id and line.line_disposition='PRESENT'
  join atlas_admin.ingredients ingredient on ingredient.ingredient_id=line.ingredient_id
  where version.recipe_version_status='RELEASED_FOR_PLANNING'
    and line.unit_id<>ingredient.purchase_unit_id
    and version.source_evidence->>'source_kind'='UIQ03A_SAVE'
)
select jsonb_build_object(
  'phase','post-deploy','eligible_line_count',(select count(*)::integer from evidence),
  'affected_released_version_count',(select count(*)::integer from successors),
  'projected_successor_present_count',(select count(*)::integer from present),
  'corrected_line_count',(select count(*)::integer from corrected),
  'copied_sibling_count',(select count(*)::integer from present p where not exists(select 1 from corrected c where c.recipe_line_revision_id=p.recipe_line_revision_id)),
  'legacy_ingredient_ids',(select coalesce(jsonb_agg(legacy_ingredient_id order by legacy_ingredient_id::integer),'[]') from (select distinct legacy_ingredient_id from mapped) ids),
  'excluded_native_mismatch_count',(select count(*)::integer from native_mismatch),
  'excluded_native_source_kind','UIQ03A_SAVE',
  'incomplete_candidate_count',(select count(*)::integer from mapped where mapped_revision_id is null or legacy_ingredient_id is null or complete_batch_id is null or exact_action_count<>1),
  'duplicate_candidate_count',(select count(*)::integer from (select predecessor_recipe_line_revision_id from evidence group by predecessor_recipe_line_revision_id having count(*)<>1) duplicates),
  'remapped_source_count',(select count(*)::integer from mapped where mapped_batch_id<>import_batch_id or mapped_fingerprint<>source_fingerprint or target_action_count<>exact_action_count),
  'exact_reconciliation_action_count',(select count(*)::integer from mapped where exact_action_count=1),
  'correction_evidence_count',(select count(*)::integer from evidence),
  'direct_successor_version_count',(select count(*)::integer from valid_successors),
  'successor_present_count',(select count(*)::integer from present),
  'exact_sibling_copy_count',(select count(*)::integer from sibling_comparison where exact_copy),
  'locked_predecessor_version_count',(select count(*)::integer from valid_successors successor join atlas_admin.recipe_versions predecessor on predecessor.recipe_version_id=successor.predecessor_recipe_version_id where predecessor.recipe_version_status='LOCKED'),
  'successor_version_mismatch_count',(select count(*)::integer from successors)-(select count(*)::integer from valid_successors),
  'sibling_mismatch_count',(select count(*)::integer from sibling_comparison where not exact_copy)
)`;
}

function postDeployManifestSql() {
  return `begin read only;
${planningAdoptionPostDeployQuerySql()} as manifest;
rollback;`;
}

export function planningAdoptionManifestSql(phase) {
  if (!PHASES.has(phase))
    throw new Error("PLANNING_ADOPTION_MANIFEST_PHASE_REJECTED");
  return phase === "pre-deploy"
    ? preDeployManifestSql()
    : postDeployManifestSql();
}

export async function verifyPlanningAdoptionManifest({
  commitSha,
  phase,
  environment = process.env,
} = {}) {
  if (!PHASES.has(phase))
    throw new Error("PLANNING_ADOPTION_MANIFEST_PHASE_REJECTED");
  const target = validateAtlasStagingPackageProtectedValues(environment);
  verifyPackageCheckout({ commitSha });
  const rows = JSON.parse(
    await executeAtlasStagingManagementSql(
      target,
      planningAdoptionManifestSql(phase),
    ),
  );
  const manifest = classifyPlanningAdoptionManifest(rows[0]?.manifest, phase);
  return { status: "PLANNING_ADOPTION_MANIFEST_PASS", phase, manifest };
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const shaAt = process.argv.indexOf("--commit-sha");
  const phaseAt = process.argv.indexOf("--phase");
  verifyPlanningAdoptionManifest({
    commitSha: process.argv[shaAt + 1],
    phase: process.argv[phaseAt + 1],
  })
    .then((result) => console.log(JSON.stringify(result)))
    .catch((error) => {
      console.error(redactAtlasStagingDiagnostic(error.message));
      process.exitCode = 1;
    });
}
