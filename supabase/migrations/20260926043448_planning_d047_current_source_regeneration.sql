-- D-047 correction necessity is independent of Menu/Attendance/Pantry currentness.
-- No data migration, public contract change, receipt rewrite, or source mutation.
set role atlas_owner;
grant usage on schema atlas_legacy to atlas_need_generation_runtime;
grant select on atlas_legacy.recipe_unit_adoption_evidence,
  atlas_legacy.import_batches, atlas_legacy.master_data_mappings
  to atlas_need_generation_runtime;
create policy planning_adoption_generation_evidence_select
  on atlas_legacy.recipe_unit_adoption_evidence for select
  to atlas_need_generation_runtime
  using (source_system='OPS_V1' and evidence_kind='OPS_V1_BOM_UNIT_TO_INGREDIENT_PURCHASE_UNIT_CORRECTION');
create policy planning_adoption_generation_import_select
  on atlas_legacy.import_batches for select to atlas_need_generation_runtime
  using (source_system='OPS_V1' and import_status='COMPLETED');
create policy planning_adoption_generation_mapping_select
  on atlas_legacy.master_data_mappings for select to atlas_need_generation_runtime
  using (source_system='OPS_V1');

create function atlas_core.planning_legacy_adoption_regeneration_required(run_id uuid)
returns boolean
language sql stable security invoker set search_path=''
as $$
  select exists (
    select 1
    from atlas_planning.need_generation_runs run
    join atlas_planning.theoretical_need_lines line
      on line.need_generation_run_id=run.need_generation_run_id
     and line.line_disposition='ACTIVE' and line.contribution_family='RECIPE_DERIVED'
    join atlas_legacy.recipe_unit_adoption_evidence evidence
      on evidence.evidence_kind='OPS_V1_BOM_UNIT_TO_INGREDIENT_PURCHASE_UNIT_CORRECTION'
     and evidence.source_system='OPS_V1'
     and evidence.recipe_id=line.recipe_id
     and evidence.recipe_line_id=line.recipe_line_id
     and evidence.ingredient_id=line.ingredient_id
     and evidence.predecessor_recipe_version_id=line.recipe_version_id
     and evidence.predecessor_recipe_line_revision_id=line.recipe_line_revision_id
     and evidence.source_unit_id=line.unit_id
    join atlas_admin.recipe_versions target
      on target.recipe_version_id=evidence.target_recipe_version_id
     and target.recipe_id=evidence.recipe_id
     and target.recipe_version_status='RELEASED_FOR_PLANNING'
     and target.predecessor_recipe_version_id=evidence.predecessor_recipe_version_id
    join atlas_admin.recipe_line_revisions revision
      on revision.recipe_line_revision_id=evidence.target_recipe_line_revision_id
     and revision.recipe_version_id=target.recipe_version_id
     and revision.recipe_id=evidence.recipe_id
     and revision.recipe_line_id=evidence.recipe_line_id
     and revision.ingredient_id=evidence.ingredient_id
     and revision.predecessor_recipe_line_revision_id=evidence.predecessor_recipe_line_revision_id
     and revision.line_disposition='PRESENT'
     and revision.unit_id=evidence.corrected_unit_id
     and revision.quantity_per_basis=evidence.quantity_per_basis
    join atlas_admin.recipe_line_revisions predecessor
      on predecessor.recipe_line_revision_id=evidence.predecessor_recipe_line_revision_id
     and predecessor.recipe_version_id=evidence.predecessor_recipe_version_id
     and predecessor.recipe_id=evidence.recipe_id
     and predecessor.recipe_line_id=evidence.recipe_line_id
     and predecessor.ingredient_id=evidence.ingredient_id
     and predecessor.line_disposition='PRESENT'
     and predecessor.unit_id=evidence.source_unit_id
     and predecessor.quantity_per_basis=evidence.quantity_per_basis
    join atlas_admin.ingredients ingredient
      on ingredient.ingredient_id=evidence.ingredient_id
     and ingredient.purchase_unit_id=evidence.corrected_unit_id
    join atlas_legacy.import_batches batch
      on batch.import_batch_id=evidence.import_batch_id
     and batch.source_system='OPS_V1' and batch.import_status='COMPLETED'
     and batch.snapshot_id=evidence.snapshot_id
     and batch.snapshot_checksum=evidence.snapshot_checksum
    where run.need_generation_run_id=run_id
      and run.run_status='RELEASED_FOR_CONFIRMATION'
      and not exists (
        select 1 from atlas_planning.need_generation_runs later
        where later.planning_input_set_id=run.planning_input_set_id
          and later.attempt_ordinal>run.attempt_ordinal
      )
      and evidence.source_unit_id<>evidence.corrected_unit_id
      -- Re-prove each unique typed mapping. A remapped or duplicate identity
      -- must not turn an ordinary current run into a correction candidate.
      and (select count(*) from atlas_legacy.master_data_mappings m
        where m.source_system='OPS_V1' and m.object_type='RECIPE'
          and m.recipe_id=evidence.recipe_id)=1
      and (select count(*) from atlas_legacy.master_data_mappings m
        where m.source_system='OPS_V1' and m.object_type='RECIPE_VERSION'
          and m.recipe_version_id=evidence.predecessor_recipe_version_id)=1
      and (select count(*) from atlas_legacy.master_data_mappings m
        where m.source_system='OPS_V1' and m.object_type='RECIPE_LINE'
          and m.recipe_line_id=evidence.recipe_line_id)=1
      and exists (select 1 from atlas_legacy.master_data_mappings m
        where m.source_system='OPS_V1' and m.object_type='RECIPE_LINE'
          and m.recipe_line_id=evidence.recipe_line_id
          and m.legacy_id=evidence.legacy_recipe_line_id)
      and (select count(*) from atlas_legacy.master_data_mappings m
        where m.source_system='OPS_V1' and m.object_type='RECIPE_LINE_REVISION'
          and m.recipe_line_revision_id=evidence.predecessor_recipe_line_revision_id)=1
      and exists (select 1 from atlas_legacy.master_data_mappings m
        where m.source_system='OPS_V1' and m.object_type='RECIPE_LINE_REVISION'
          and m.recipe_line_revision_id=evidence.predecessor_recipe_line_revision_id
          and m.last_seen_import_batch_id=evidence.import_batch_id
          and m.last_source_fingerprint=evidence.source_fingerprint)
      and (select count(*) from atlas_legacy.master_data_mappings m
        where m.source_system='OPS_V1' and m.object_type='INGREDIENT'
          and m.ingredient_id=evidence.ingredient_id)=1
      and (select count(*) from atlas_legacy.master_data_mappings m
        where m.source_system='OPS_V1' and m.object_type='UNIT'
          and m.unit_id=evidence.source_unit_id)=1
      and (select count(*) from atlas_legacy.master_data_mappings m
        where m.source_system='OPS_V1' and m.object_type='UNIT'
          and m.unit_id=evidence.corrected_unit_id)=1
      and (select count(*) from pg_catalog.jsonb_array_elements(batch.reconciliation->'actions') action
        where action->>'object_type'='RECIPE_LINE_REVISION'
          and action->>'target_id'=predecessor.recipe_line_revision_id::text)=1
      and exists (select 1 from pg_catalog.jsonb_array_elements(batch.reconciliation->'actions') action
        where action->>'object_type'='RECIPE_LINE_REVISION'
          and action->>'target_id'=predecessor.recipe_line_revision_id::text
          and action#>>'{values,recipe_id}'=predecessor.recipe_id::text
          and action#>>'{values,recipe_line_id}'=predecessor.recipe_line_id::text
          and action#>>'{values,ingredient_id}'=predecessor.ingredient_id::text
          and (action#>>'{values,quantity_per_basis}')::numeric=predecessor.quantity_per_basis
          and action#>>'{values,unit_id}'=predecessor.unit_id::text)
  )
$$;
revoke all on function atlas_core.planning_legacy_adoption_regeneration_required(uuid)
  from public,anon,authenticated,service_role;
grant execute on function atlas_core.planning_legacy_adoption_regeneration_required(uuid)
  to atlas_need_generation_runtime;
reset role;

-- Guarded replacement preserves all other atomic orchestration and properties.
grant atlas_need_generation_runtime to postgres with set true;
set role atlas_owner;
grant create on schema atlas_core to atlas_need_generation_runtime;
reset role;
set role atlas_need_generation_runtime;
do $patch$
declare
  definition text;
  properties jsonb;
  after_properties jsonb;
  old_guard text := $old$    if v_preflight ->> 'downstream_currentness' = 'CURRENT' then$old$;
  new_guard text := $new$    if v_preflight ->> 'downstream_currentness' = 'CURRENT'
       and not atlas_core.planning_legacy_adoption_regeneration_required(
         v_terminal.need_generation_run_id
       ) then$new$;
  old_reason text := $old$        'UPSTREAM_SOURCE_CHANGED',
        coalesce(nullif(pg_catalog.btrim(request ->> 'reason_note'), ''),
          'Dữ liệu nguồn hoàn tất đã thay đổi.'),$old$;
  new_reason text := $new$        case when v_preflight ->> 'downstream_currentness' = 'CURRENT'
          then 'PLANNING_CORRECTION' else 'UPSTREAM_SOURCE_CHANGED' end,
        coalesce(nullif(pg_catalog.btrim(request ->> 'reason_note'), ''),
          case when v_preflight ->> 'downstream_currentness' = 'CURRENT'
            then 'D-047 governed Recipe adoption correction; command ' || (request ->> 'command_id')
            else 'Dữ liệu nguồn hoàn tất đã thay đổi.' end),$new$;
begin
  select pg_get_functiondef(p.oid),jsonb_build_object(
    'owner',p.proowner,'security_definer',p.prosecdef,'volatility',p.provolatile,
    'config',p.proconfig,'acl',p.proacl) into definition,properties
  from pg_proc p where p.oid='atlas_core.issue_223_execute_need_generation_v2(jsonb)'::regprocedure;
  if md5(definition)<>'740e00450a10b994429afe6535ef2389'
     or position(old_guard in definition)=0 or position(old_reason in definition)=0 then
    raise exception 'D047_GENERATION_BASELINE_MISMATCH';
  end if;
  execute replace(replace(definition,old_guard,new_guard),old_reason,new_reason);
  select jsonb_build_object(
    'owner',p.proowner,'security_definer',p.prosecdef,'volatility',p.provolatile,
    'config',p.proconfig,'acl',p.proacl) into after_properties
  from pg_proc p where p.oid='atlas_core.issue_223_execute_need_generation_v2(jsonb)'::regprocedure;
  if properties is distinct from after_properties then
    raise exception 'D047_GENERATION_PROPERTIES_CHANGED';
  end if;
end
$patch$;
reset role;
set role atlas_owner;
revoke create on schema atlas_core from atlas_need_generation_runtime;
reset role;
grant atlas_need_generation_runtime to postgres with set false;
