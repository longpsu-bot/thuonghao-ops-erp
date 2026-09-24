-- D-047 bounded OPS-v1 Recipe Unit adoption correction.
-- Raw BoM Unit remains evidence; Ingredient purchase Unit is operational authority.
set role atlas_owner;

create table atlas_legacy.recipe_unit_adoption_evidence (
  recipe_unit_adoption_evidence_id uuid not null default gen_random_uuid(),
  evidence_kind text not null,
  source_system text not null,
  import_batch_id uuid not null,
  snapshot_id text not null,
  snapshot_checksum text not null,
  legacy_recipe_line_id text not null,
  source_fingerprint text not null,
  recipe_id uuid not null,
  recipe_line_id uuid not null,
  predecessor_recipe_version_id uuid,
  target_recipe_version_id uuid not null,
  predecessor_recipe_line_revision_id uuid,
  target_recipe_line_revision_id uuid not null,
  ingredient_id uuid not null,
  quantity_per_basis numeric(20,6) not null,
  source_unit_id uuid not null,
  corrected_unit_id uuid not null,
  recorded_by_actor_id uuid not null,
  recorded_at timestamptz not null default transaction_timestamp(),
  constraint recipe_unit_adoption_evidence_pkey primary key (recipe_unit_adoption_evidence_id),
  constraint recipe_unit_adoption_evidence_kind_check check (
    evidence_kind in (
      'OPS_V1_INGREDIENT_PURCHASE_UNIT_ADOPTION',
      'OPS_V1_BOM_UNIT_TO_INGREDIENT_PURCHASE_UNIT_CORRECTION'
    )
  ),
  constraint recipe_unit_adoption_evidence_source_check check (source_system = 'OPS_V1'),
  constraint recipe_unit_adoption_evidence_snapshot_checksum_check check (snapshot_checksum ~ '^[0-9a-f]{64}$'),
  constraint recipe_unit_adoption_evidence_source_fingerprint_check check (source_fingerprint ~ '^[0-9a-f]{64}$'),
  constraint recipe_unit_adoption_evidence_quantity_check check (quantity_per_basis > 0),
  constraint recipe_unit_adoption_evidence_distinct_units_check check (source_unit_id <> corrected_unit_id),
  constraint recipe_unit_adoption_evidence_batch_fkey foreign key (import_batch_id)
    references atlas_legacy.import_batches(import_batch_id) on delete restrict,
  constraint recipe_unit_adoption_evidence_recipe_fkey foreign key (recipe_id)
    references atlas_admin.recipes(recipe_id) on delete restrict,
  constraint recipe_unit_adoption_evidence_line_fkey foreign key (recipe_line_id, recipe_id)
    references atlas_admin.recipe_lines(recipe_line_id, recipe_id) on delete restrict,
  constraint recipe_unit_adoption_evidence_predecessor_version_fkey foreign key (predecessor_recipe_version_id, recipe_id)
    references atlas_admin.recipe_versions(recipe_version_id, recipe_id) on delete restrict,
  constraint recipe_unit_adoption_evidence_target_version_fkey foreign key (target_recipe_version_id, recipe_id)
    references atlas_admin.recipe_versions(recipe_version_id, recipe_id) on delete restrict,
  constraint recipe_unit_adoption_evidence_predecessor_revision_fkey foreign key (
    predecessor_recipe_line_revision_id, recipe_id, recipe_line_id
  ) references atlas_admin.recipe_line_revisions (
    recipe_line_revision_id, recipe_id, recipe_line_id
  ) on delete restrict,
  constraint recipe_unit_adoption_evidence_target_revision_fkey foreign key (
    target_recipe_line_revision_id, recipe_id, recipe_line_id
  ) references atlas_admin.recipe_line_revisions (
    recipe_line_revision_id, recipe_id, recipe_line_id
  ) on delete restrict,
  constraint recipe_unit_adoption_evidence_ingredient_fkey foreign key (ingredient_id)
    references atlas_admin.ingredients(ingredient_id) on delete restrict,
  constraint recipe_unit_adoption_evidence_source_unit_fkey foreign key (source_unit_id)
    references atlas_admin.units(unit_id) on delete restrict,
  constraint recipe_unit_adoption_evidence_corrected_unit_fkey foreign key (corrected_unit_id)
    references atlas_admin.units(unit_id) on delete restrict,
  constraint recipe_unit_adoption_evidence_actor_fkey foreign key (recorded_by_actor_id)
    references atlas_core.actors(actor_id) on delete restrict,
  constraint recipe_unit_adoption_evidence_target_revision_key unique (target_recipe_line_revision_id),
  constraint recipe_unit_adoption_evidence_transition_key unique nulls not distinct (
    predecessor_recipe_line_revision_id,
    target_recipe_line_revision_id
  ),
  constraint recipe_unit_adoption_evidence_kind_lineage_check check (
    (
      evidence_kind = 'OPS_V1_INGREDIENT_PURCHASE_UNIT_ADOPTION'
      and predecessor_recipe_version_id is null
      and predecessor_recipe_line_revision_id is null
    )
    or (
      evidence_kind = 'OPS_V1_BOM_UNIT_TO_INGREDIENT_PURCHASE_UNIT_CORRECTION'
      and predecessor_recipe_version_id is not null
      and predecessor_recipe_line_revision_id is not null
    )
  )
);

create index recipe_unit_adoption_evidence_predecessor_revision_idx
  on atlas_legacy.recipe_unit_adoption_evidence(predecessor_recipe_line_revision_id)
  where predecessor_recipe_line_revision_id is not null;
create index recipe_unit_adoption_evidence_recipe_versions_idx
  on atlas_legacy.recipe_unit_adoption_evidence(recipe_id, target_recipe_version_id);
create index recipe_unit_adoption_evidence_legacy_line_idx
  on atlas_legacy.recipe_unit_adoption_evidence(source_system, legacy_recipe_line_id);

alter table atlas_legacy.recipe_unit_adoption_evidence enable row level security;
alter table atlas_legacy.recipe_unit_adoption_evidence force row level security;
revoke all on table atlas_legacy.recipe_unit_adoption_evidence from public, anon, authenticated, service_role;
grant select, insert on table atlas_legacy.recipe_unit_adoption_evidence to atlas_master_data_command_runtime;
grant usage on schema atlas_legacy to atlas_planning_materialization_runtime;
grant select on table atlas_legacy.recipe_unit_adoption_evidence to atlas_planning_materialization_runtime;
grant select on table atlas_legacy.import_batches,atlas_legacy.master_data_mappings
  to atlas_planning_materialization_runtime;
create policy planning_unit_adoption_import_batch_select
  on atlas_legacy.import_batches for select
  to atlas_planning_materialization_runtime
  using (source_system='OPS_V1' and import_status='COMPLETED');
create policy planning_unit_adoption_mapping_select
  on atlas_legacy.master_data_mappings for select
  to atlas_planning_materialization_runtime
  using (source_system='OPS_V1');
create policy planning_unit_adoption_master_select
  on atlas_legacy.recipe_unit_adoption_evidence for select
  to atlas_master_data_command_runtime using (true);
create policy planning_unit_adoption_master_insert
  on atlas_legacy.recipe_unit_adoption_evidence for insert
  to atlas_master_data_command_runtime with check (true);
create policy planning_unit_adoption_materialization_select
  on atlas_legacy.recipe_unit_adoption_evidence for select
  to atlas_planning_materialization_runtime using (true);

create function atlas_legacy.recipe_unit_adoption_evidence_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  batch atlas_legacy.import_batches%rowtype;
  target_revision atlas_admin.recipe_line_revisions%rowtype;
  target_version atlas_admin.recipe_versions%rowtype;
  predecessor_revision atlas_admin.recipe_line_revisions%rowtype;
  line_mapping atlas_legacy.master_data_mappings%rowtype;
begin
  if tg_op <> 'INSERT' then
    raise exception using errcode='23514', message='recipe Unit adoption evidence is immutable';
  end if;

  select * into batch
  from atlas_legacy.import_batches b
  where b.import_batch_id = new.import_batch_id
    and b.source_system = 'OPS_V1'
    and b.import_status = 'COMPLETED'
    and b.snapshot_id = new.snapshot_id
    and b.snapshot_checksum = new.snapshot_checksum;
  if not found then
    raise exception using errcode='23514', message='recipe Unit adoption requires completed OPS-v1 import evidence';
  end if;
  if new.recorded_by_actor_id is distinct from batch.operator_actor_id then
    raise exception using errcode='23514', message='recipe Unit adoption actor must match completed import evidence';
  end if;

  select * into line_mapping
  from atlas_legacy.master_data_mappings m
  where m.source_system='OPS_V1'
    and m.object_type='RECIPE_LINE'
    and m.legacy_id=new.legacy_recipe_line_id
    and m.recipe_line_id=new.recipe_line_id;
  if not found then
    raise exception using errcode='23514', message='recipe Unit adoption requires exact Recipe-line mapping';
  end if;

  if not exists (
    select 1 from atlas_legacy.master_data_mappings m
    where m.source_system='OPS_V1'
      and m.object_type='UNIT'
      and m.unit_id=new.source_unit_id
  ) then
    raise exception using errcode='23514', message='recipe Unit adoption requires mapped raw Unit';
  end if;

  select * into target_revision
  from atlas_admin.recipe_line_revisions r
  where r.recipe_line_revision_id=new.target_recipe_line_revision_id;
  select * into target_version
  from atlas_admin.recipe_versions v
  where v.recipe_version_id=new.target_recipe_version_id;

  if target_revision.recipe_id is distinct from new.recipe_id
    or target_revision.recipe_version_id is distinct from new.target_recipe_version_id
    or target_revision.recipe_line_id is distinct from new.recipe_line_id
    or target_revision.ingredient_id is distinct from new.ingredient_id
    or target_revision.quantity_per_basis is distinct from new.quantity_per_basis
    or target_revision.unit_id is distinct from new.corrected_unit_id
    or target_revision.line_disposition <> 'PRESENT'
    or target_version.recipe_id is distinct from new.recipe_id
    or not exists (
      select 1 from atlas_admin.ingredients i
      where i.ingredient_id=new.ingredient_id
        and i.purchase_unit_id=new.corrected_unit_id
    )
  then
    raise exception using errcode='23514', message='recipe Unit adoption target facts are inconsistent';
  end if;

  if new.evidence_kind='OPS_V1_INGREDIENT_PURCHASE_UNIT_ADOPTION' then
    if target_version.source_evidence->>'source_system' is distinct from 'OPS_V1'
      or target_version.source_evidence->>'snapshot_id' is distinct from new.snapshot_id
      or target_version.source_evidence->>'snapshot_checksum' is distinct from new.snapshot_checksum
      or not exists (
        select 1 from atlas_legacy.master_data_mappings m
        where m.source_system='OPS_V1'
          and m.object_type='RECIPE_LINE_REVISION'
          and m.recipe_line_revision_id=new.target_recipe_line_revision_id
          and m.last_seen_import_batch_id=new.import_batch_id
          and m.last_source_fingerprint=new.source_fingerprint
      )
    then
      raise exception using errcode='23514', message='recipe Unit adoption snapshot lineage is inconsistent';
    end if;
  else
    select * into predecessor_revision
    from atlas_admin.recipe_line_revisions r
    where r.recipe_line_revision_id=new.predecessor_recipe_line_revision_id;
    if target_version.predecessor_recipe_version_id is distinct from new.predecessor_recipe_version_id
      or target_revision.predecessor_recipe_line_revision_id is distinct from new.predecessor_recipe_line_revision_id
      or predecessor_revision.recipe_version_id is distinct from new.predecessor_recipe_version_id
      or predecessor_revision.recipe_id is distinct from new.recipe_id
      or predecessor_revision.recipe_line_id is distinct from new.recipe_line_id
      or predecessor_revision.ingredient_id is distinct from new.ingredient_id
      or predecessor_revision.quantity_per_basis is distinct from new.quantity_per_basis
      or predecessor_revision.unit_id is distinct from new.source_unit_id
      or not exists (
        select 1 from atlas_legacy.master_data_mappings m
        where m.source_system='OPS_V1'
          and m.object_type='RECIPE_LINE_REVISION'
          and m.recipe_line_revision_id=new.predecessor_recipe_line_revision_id
          and m.last_seen_import_batch_id=new.import_batch_id
          and m.last_source_fingerprint=new.source_fingerprint
      )
    then
      raise exception using errcode='23514', message='recipe Unit correction predecessor lineage is inconsistent';
    end if;
  end if;
  return new;
end
$$;

create trigger recipe_unit_adoption_evidence_guard
before insert or update or delete on atlas_legacy.recipe_unit_adoption_evidence
for each row execute function atlas_legacy.recipe_unit_adoption_evidence_guard();

revoke all on function atlas_legacy.recipe_unit_adoption_evidence_guard() from public, anon, authenticated, service_role;

create function atlas_legacy.master_recipe_operational_unit(snapshot jsonb, ingredient_legacy text)
returns uuid
language sql
stable
security invoker
set search_path=''
as $$
  select atlas_legacy.master_import_target_id(
    snapshot,
    'UNIT',
    (
      select source_ingredient.value->>'purchase_unit_legacy_id'
      from jsonb_array_elements(snapshot#>'{records,ingredients}') source_ingredient
      where source_ingredient.value->>'legacy_id'=ingredient_legacy
    )
  )
$$;

create or replace function atlas_legacy.master_recipe_composition(snapshot jsonb, legacy text)
returns jsonb language sql stable security invoker set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object(
   'ingredient_id',atlas_legacy.master_import_target_id(snapshot,'INGREDIENT',r.value->>'ingredient_legacy_id'),
   'unit_id',atlas_legacy.master_recipe_operational_unit(snapshot,r.value->>'ingredient_legacy_id'),
   'quantity_per_basis',(r.value->>'quantity_per_basis')::numeric,
   'operational_note',r.value->>'operational_note') order by r.value->>'ingredient_legacy_id' collate "C"),'[]')
 from jsonb_array_elements(snapshot#>'{records,recipe_lines}') r
 where r.value->>'recipe_legacy_id'=legacy
$$;

do $patch_recipe_plan$
declare
  definition text;
  old_validation text := $old$
   ingredient:=atlas_legacy.master_import_target_id(snapshot,'INGREDIENT',r->>'ingredient_legacy_id');
   unit:=atlas_legacy.master_import_target_id(snapshot,'UNIT',r->>'unit_legacy_id');
   if ingredient is null or unit is null then code:='INVALID_COMPOSITION_REFERENCE'; end if;
$old$;
  new_validation text := $new$
   ingredient:=atlas_legacy.master_import_target_id(snapshot,'INGREDIENT',r->>'ingredient_legacy_id');
   unit:=atlas_legacy.master_import_target_id(snapshot,'UNIT',r->>'unit_legacy_id');
   if ingredient is null or unit is null
     or atlas_legacy.master_recipe_operational_unit(snapshot,r->>'ingredient_legacy_id') is null
   then code:='INVALID_COMPOSITION_REFERENCE'; end if;
   if ingredient is not null
     and unit is distinct from atlas_legacy.master_recipe_operational_unit(snapshot,r->>'ingredient_legacy_id')
     and exists(select 1 from atlas_admin.recipe_lines l where l.recipe_line_id=md5('OPS_V1:RECIPE_LINE:'||(r->>'legacy_id'))::uuid)
     and not exists(
       select 1 from atlas_legacy.master_data_mappings m
       where m.source_system='OPS_V1'
         and m.object_type='RECIPE_LINE'
         and m.legacy_id=r->>'legacy_id'
         and m.recipe_line_id=md5('OPS_V1:RECIPE_LINE:'||(r->>'legacy_id'))::uuid
     )
   then code:='LEGACY_ADOPTION_LINEAGE_REQUIRED'; end if;
$new$;
  old_unit text := $old$
      'unit_id',case when src_line is null then prior.unit_id else atlas_legacy.master_import_target_id(snapshot,'UNIT',src_line->>'unit_legacy_id') end,
$old$;
  new_unit text := $new$
      'unit_id',case when src_line is null then prior.unit_id else atlas_legacy.master_recipe_operational_unit(snapshot,src_line->>'ingredient_legacy_id') end,
$new$;
begin
  select pg_get_functiondef('atlas_legacy.master_import_recipe_plan(jsonb)'::regprocedure)
    into definition;
  if position(old_validation in definition)=0 or position(old_unit in definition)=0 then
    raise exception 'PLANNING_ADOPTION_RECIPE_PLAN_PATCH_ANCHOR_MISSING';
  end if;
  definition:=replace(replace(definition,old_validation,new_validation),old_unit,new_unit);
  execute definition;
end
$patch_recipe_plan$;

create function atlas_legacy.record_master_recipe_unit_adoption_evidence(
  snapshot jsonb,
  plan jsonb,
  import_batch uuid,
  actor uuid
)
returns void
language plpgsql
volatile
security invoker
set search_path=''
as $$
declare
  source_line jsonb;
  action jsonb;
  ingredient uuid;
  source_unit uuid;
  corrected_unit uuid;
  stable_line uuid;
  target_revision uuid;
  target_version uuid;
  source_fingerprint text;
begin
  if current_user<>'postgres' then
    raise exception using errcode='42501',message='Private master import requires the privileged database operator';
  end if;
  for source_line in
    select line.value
    from jsonb_array_elements(snapshot#>'{records,recipe_lines}') line
    order by line.value->>'legacy_id' collate "C"
  loop
    ingredient:=atlas_legacy.master_import_target_id(snapshot,'INGREDIENT',source_line->>'ingredient_legacy_id');
    source_unit:=atlas_legacy.master_import_target_id(snapshot,'UNIT',source_line->>'unit_legacy_id');
    select i.purchase_unit_id into corrected_unit
    from atlas_admin.ingredients i where i.ingredient_id=ingredient;
    if source_unit is not distinct from corrected_unit then
      continue;
    end if;

    select m.recipe_line_id into stable_line
    from atlas_legacy.master_data_mappings m
    where m.source_system='OPS_V1'
      and m.object_type='RECIPE_LINE'
      and m.legacy_id=source_line->>'legacy_id';
    if stable_line is null then
      raise exception using errcode='23514',message='LEGACY_ADOPTION_LINEAGE_REQUIRED';
    end if;

    select item.value into action
    from jsonb_array_elements(plan->'actions') item
    where item.value->>'object_type'='RECIPE_LINE_REVISION'
      and item.value->>'action'='CREATE'
      and item.value#>>'{values,recipe_line_id}'=stable_line::text
      and item.value#>>'{values,line_disposition}'='PRESENT';
    if action is null then
      continue;
    end if;

    target_revision:=(action->>'target_id')::uuid;
    target_version:=(action#>>'{values,recipe_version_id}')::uuid;
    select m.last_source_fingerprint into source_fingerprint
    from atlas_legacy.master_data_mappings m
    where m.source_system='OPS_V1'
      and m.object_type='RECIPE_LINE_REVISION'
      and m.recipe_line_revision_id=target_revision
      and m.last_seen_import_batch_id=import_batch;

    insert into atlas_legacy.recipe_unit_adoption_evidence(
      recipe_unit_adoption_evidence_id,evidence_kind,source_system,import_batch_id,
      snapshot_id,snapshot_checksum,legacy_recipe_line_id,source_fingerprint,
      recipe_id,recipe_line_id,target_recipe_version_id,target_recipe_line_revision_id,
      ingredient_id,quantity_per_basis,source_unit_id,corrected_unit_id,recorded_by_actor_id
    )
    values(
      md5('OPS_V1:UNIT_ADOPTION:'||target_revision::text)::uuid,
      'OPS_V1_INGREDIENT_PURCHASE_UNIT_ADOPTION','OPS_V1',import_batch,
      snapshot->>'snapshot_id',snapshot->>'snapshot_checksum',source_line->>'legacy_id',source_fingerprint,
      (action#>>'{values,recipe_id}')::uuid,stable_line,target_version,target_revision,
      ingredient,(action#>>'{values,quantity_per_basis}')::numeric,source_unit,corrected_unit,actor
    );
  end loop;
end
$$;

revoke all on function atlas_legacy.record_master_recipe_unit_adoption_evidence(jsonb,jsonb,uuid,uuid)
  from public, anon, authenticated, service_role;

do $patch_master_apply$
declare
  definition text;
  old_call text := $old$
  for a in select x.value from jsonb_array_elements(p->'actions') x loop
    perform atlas_legacy.master_import_record_mapping(a,batch);
  end loop;
  fps:=atlas_legacy.master_import_capture_fingerprints();
$old$;
  new_call text := $new$
  for a in select x.value from jsonb_array_elements(p->'actions') x loop
    perform atlas_legacy.master_import_record_mapping(a,batch);
  end loop;
  perform atlas_legacy.record_master_recipe_unit_adoption_evidence(snapshot,p,batch,operator_actor_id);
  fps:=atlas_legacy.master_import_capture_fingerprints();
$new$;
  old_lock text := '    atlas_legacy.import_batches,atlas_legacy.master_data_mappings in share row exclusive mode;';
  new_lock text := '    atlas_legacy.import_batches,atlas_legacy.master_data_mappings,atlas_legacy.recipe_unit_adoption_evidence in share row exclusive mode;';
begin
  select pg_get_functiondef('atlas_legacy.apply_master_data_snapshot(jsonb,text,uuid)'::regprocedure)
    into definition;
  if position(old_call in definition)=0 or position(old_lock in definition)=0 then
    raise exception 'PLANNING_ADOPTION_MASTER_APPLY_PATCH_ANCHOR_MISSING';
  end if;
  definition:=replace(replace(definition,old_call,new_call),old_lock,new_lock);
  execute definition;
end
$patch_master_apply$;

do $patch_release_guard$
declare
  definition text;
  anchor text := $anchor$
  if new.recipe_version_status = 'RELEASED_FOR_PLANNING'
    and new.predecessor_recipe_version_id is not null
  then
$anchor$;
  replacement text := $replacement$
  if new.recipe_version_status = 'RELEASED_FOR_PLANNING'
    and exists (
      select 1
      from atlas_admin.recipe_line_revisions revision
      join atlas_admin.ingredients ingredient on ingredient.ingredient_id=revision.ingredient_id
      where revision.recipe_version_id=new.recipe_version_id
        and revision.line_disposition='PRESENT'
        and revision.unit_id is distinct from ingredient.purchase_unit_id
    )
  then
    raise exception using
      errcode = '23514',
      message = 'released Recipe Unit must equal Ingredient purchase Unit';
  end if;

  if new.recipe_version_status = 'RELEASED_FOR_PLANNING'
    and new.predecessor_recipe_version_id is not null
  then
$replacement$;
begin
  select pg_get_functiondef('atlas_admin.pa_06e_h0a2_recipe_version_integrity_guard()'::regprocedure)
    into definition;
  if position(anchor in definition)=0 then
    raise exception 'PLANNING_ADOPTION_RELEASE_GUARD_PATCH_ANCHOR_MISSING';
  end if;
  execute replace(definition,anchor,replacement);
end
$patch_release_guard$;

reset role;

grant atlas_planning_materialization_runtime to postgres with set true;
set role atlas_owner;
grant create on schema atlas_core to atlas_planning_materialization_runtime;
create function atlas_core.planning_legacy_adoption_unit_transition_allowed(
  predecessor_line_id uuid,
  successor_line_id uuid
)
returns boolean
language sql
stable
security invoker
set search_path=''
as $$
  select exists (
    select 1
    from atlas_planning.theoretical_need_lines predecessor
    join atlas_planning.theoretical_need_lines successor
      on successor.theoretical_need_line_id=successor_line_id
     and successor.predecessor_theoretical_need_line_id=predecessor.theoretical_need_line_id
     and successor.predecessor_need_generation_run_id=predecessor.need_generation_run_id
    join atlas_admin.recipe_line_revisions predecessor_revision
      on predecessor_revision.recipe_line_revision_id=predecessor.recipe_line_revision_id
    join atlas_admin.recipe_line_revisions successor_revision
      on successor_revision.recipe_line_revision_id=successor.recipe_line_revision_id
     and successor_revision.predecessor_recipe_line_revision_id=predecessor_revision.recipe_line_revision_id
    join atlas_admin.recipe_versions successor_version
      on successor_version.recipe_version_id=successor.recipe_version_id
     and successor_version.predecessor_recipe_version_id=predecessor.recipe_version_id
    join atlas_legacy.recipe_unit_adoption_evidence evidence
      on evidence.evidence_kind='OPS_V1_BOM_UNIT_TO_INGREDIENT_PURCHASE_UNIT_CORRECTION'
     and evidence.source_system='OPS_V1'
     and evidence.predecessor_recipe_version_id=predecessor.recipe_version_id
     and evidence.target_recipe_version_id=successor.recipe_version_id
     and evidence.predecessor_recipe_line_revision_id=predecessor.recipe_line_revision_id
     and evidence.target_recipe_line_revision_id=successor.recipe_line_revision_id
     and evidence.recipe_id=successor.recipe_id
     and evidence.recipe_line_id=successor.recipe_line_id
     and evidence.ingredient_id=successor.ingredient_id
    join atlas_legacy.import_batches batch
      on batch.import_batch_id=evidence.import_batch_id
     and batch.source_system='OPS_V1'
     and batch.import_status='COMPLETED'
     and batch.snapshot_id=evidence.snapshot_id
     and batch.snapshot_checksum=evidence.snapshot_checksum
    join atlas_legacy.master_data_mappings line_mapping
      on line_mapping.source_system='OPS_V1'
     and line_mapping.object_type='RECIPE_LINE'
     and line_mapping.legacy_id=evidence.legacy_recipe_line_id
     and line_mapping.recipe_line_id=evidence.recipe_line_id
    join atlas_legacy.master_data_mappings revision_mapping
      on revision_mapping.source_system='OPS_V1'
     and revision_mapping.object_type='RECIPE_LINE_REVISION'
     and revision_mapping.recipe_line_revision_id=evidence.predecessor_recipe_line_revision_id
     and revision_mapping.last_seen_import_batch_id=evidence.import_batch_id
     and revision_mapping.last_source_fingerprint=evidence.source_fingerprint
    join atlas_legacy.master_data_mappings recipe_mapping
      on recipe_mapping.source_system='OPS_V1'
     and recipe_mapping.object_type='RECIPE'
     and recipe_mapping.recipe_id=evidence.recipe_id
    join atlas_legacy.master_data_mappings version_mapping
      on version_mapping.source_system='OPS_V1'
     and version_mapping.object_type='RECIPE_VERSION'
     and version_mapping.recipe_version_id=evidence.predecessor_recipe_version_id
    join atlas_legacy.master_data_mappings ingredient_mapping
      on ingredient_mapping.source_system='OPS_V1'
     and ingredient_mapping.object_type='INGREDIENT'
     and ingredient_mapping.ingredient_id=evidence.ingredient_id
    join atlas_legacy.master_data_mappings source_unit_mapping
      on source_unit_mapping.source_system='OPS_V1'
     and source_unit_mapping.object_type='UNIT'
     and source_unit_mapping.unit_id=evidence.source_unit_id
    join atlas_admin.ingredients ingredient
      on ingredient.ingredient_id=successor.ingredient_id
     and ingredient.purchase_unit_id=successor.unit_id
    join atlas_planning.confirmed_need_line_revision_contributions old_contribution
      on old_contribution.theoretical_need_line_id=predecessor.theoretical_need_line_id
     and old_contribution.need_generation_run_id=predecessor.need_generation_run_id
     and old_contribution.service_date=predecessor.service_date
     and old_contribution.school_id=predecessor.school_id
     and old_contribution.ingredient_id=predecessor.ingredient_id
     and old_contribution.source_unit_id=predecessor.unit_id
     and old_contribution.source_theoretical_quantity=predecessor.theoretical_quantity
    join atlas_admin.schools school
      on school.school_id=successor.school_id
     and school.customer_id=old_contribution.customer_id
     and school.default_delivery_location_id=old_contribution.delivery_location_id
    where predecessor.theoretical_need_line_id=predecessor_line_id
      and predecessor.line_disposition='ACTIVE'
      and successor.line_disposition='ACTIVE'
      and predecessor.contribution_family='RECIPE_DERIVED'
      and successor.contribution_family='RECIPE_DERIVED'
      and predecessor.recipe_id=successor.recipe_id
      and predecessor.recipe_line_id=successor.recipe_line_id
      and predecessor.ingredient_id=successor.ingredient_id
      and predecessor.theoretical_quantity=successor.theoretical_quantity
      and predecessor.school_id=successor.school_id
      and predecessor.service_date=successor.service_date
      and evidence.source_unit_id=predecessor.unit_id
      and evidence.corrected_unit_id=successor.unit_id
      and evidence.quantity_per_basis=successor_revision.quantity_per_basis
      and predecessor_revision.ingredient_id=successor_revision.ingredient_id
      and predecessor_revision.quantity_per_basis=successor_revision.quantity_per_basis
      and predecessor_revision.unit_id=evidence.source_unit_id
      and successor_revision.unit_id=evidence.corrected_unit_id
  )
$$;
revoke all on function atlas_core.planning_legacy_adoption_unit_transition_allowed(uuid,uuid)
  from public,anon,authenticated,service_role;
grant execute on function atlas_core.planning_legacy_adoption_unit_transition_allowed(uuid,uuid)
  to atlas_planning_materialization_runtime;
reset role;

set role atlas_planning_materialization_runtime;
do $patch_planning_materializer$
declare
  definition text;
  prior_properties jsonb;
  after_properties jsonb;
  expected_md5 constant text := 'e301e98274c7b02ec541c5cfa28f6849';
  old_guard text := $old$
          successor.service_date <> old_contribution.service_date
          or successor.school_id <> old_contribution.school_id
          or successor.unit_id <> old_contribution.source_unit_id
$old$;
  new_guard text := $new$
          successor.service_date <> old_contribution.service_date
          or successor.school_id <> old_contribution.school_id
          or (
            successor.unit_id <> old_contribution.source_unit_id
            and not atlas_core.planning_legacy_adoption_unit_transition_allowed(
              old_contribution.theoretical_need_line_id,
              successor.theoretical_need_line_id
            )
          )
$new$;
begin
  select pg_get_functiondef(procedure.oid),jsonb_build_object(
    'owner',procedure.proowner,'security_definer',procedure.prosecdef,
    'volatility',procedure.provolatile,'config',procedure.proconfig,'acl',procedure.proacl
  )
  into definition,prior_properties
  from pg_proc procedure
  where procedure.oid='atlas_core.planning_contract_01_materialize_confirmed_needs(jsonb)'::regprocedure;

  if md5(definition)<>expected_md5 then
    raise exception 'PLANNING_ADOPTION_MATERIALIZER_BASELINE_HASH_MISMATCH';
  end if;
  if position(old_guard in definition)=0 then
    raise exception 'PLANNING_ADOPTION_MATERIALIZER_PATCH_ANCHOR_MISSING';
  end if;
  execute replace(definition,old_guard,new_guard);

  select jsonb_build_object(
    'owner',procedure.proowner,'security_definer',procedure.prosecdef,
    'volatility',procedure.provolatile,'config',procedure.proconfig,'acl',procedure.proacl
  )
  into after_properties
  from pg_proc procedure
  where procedure.oid='atlas_core.planning_contract_01_materialize_confirmed_needs(jsonb)'::regprocedure;
  if after_properties is distinct from prior_properties then
    raise exception 'PLANNING_ADOPTION_MATERIALIZER_PROPERTIES_CHANGED';
  end if;
end
$patch_planning_materializer$;

revoke all on function atlas_core.planning_contract_01_materialize_confirmed_needs(jsonb)
  from public,anon,service_role;
reset role;
set role atlas_owner;
revoke create on schema atlas_core from atlas_planning_materialization_runtime;
reset role;
revoke atlas_planning_materialization_runtime from postgres;

do $reconcile_existing_ops_v1_adoption$
declare
  version_row record;
  line_row record;
  successor_version uuid;
  successor_revision uuid;
  actor uuid;
  eligible_line_count bigint;
  eligible_recipe_count bigint;
  transitioned_line_count bigint := 0;
  transitioned_recipe_count bigint := 0;
  successor_present_line_count bigint := 0;
  corrected_line_count bigint := 0;
  copied_line_count bigint := 0;
begin
  create temp table _ops_v1_unit_repair_candidates on commit drop as
  select
    revision.recipe_line_revision_id as predecessor_recipe_line_revision_id,
    revision.recipe_version_id as predecessor_recipe_version_id,
    revision.recipe_id,
    revision.recipe_line_id,
    revision.ingredient_id,
    revision.quantity_per_basis,
    revision.unit_id as source_unit_id,
    ingredient.purchase_unit_id as corrected_unit_id,
    line_mapping.legacy_id as legacy_recipe_line_id,
    revision_mapping.last_source_fingerprint as source_fingerprint,
    batch.import_batch_id,
    batch.snapshot_id,
    batch.snapshot_checksum,
    batch.operator_actor_id
  from atlas_admin.recipe_line_revisions revision
  join atlas_admin.recipe_versions version
    on version.recipe_version_id=revision.recipe_version_id
   and version.recipe_version_status='RELEASED_FOR_PLANNING'
  join atlas_admin.ingredients ingredient
    on ingredient.ingredient_id=revision.ingredient_id
  join atlas_legacy.master_data_mappings line_mapping
    on line_mapping.source_system='OPS_V1'
   and line_mapping.object_type='RECIPE_LINE'
   and line_mapping.recipe_line_id=revision.recipe_line_id
  join atlas_legacy.master_data_mappings revision_mapping
    on revision_mapping.source_system='OPS_V1'
   and revision_mapping.object_type='RECIPE_LINE_REVISION'
   and revision_mapping.recipe_line_revision_id=revision.recipe_line_revision_id
  join atlas_legacy.import_batches batch
    on batch.import_batch_id=revision_mapping.last_seen_import_batch_id
   and batch.source_system='OPS_V1'
   and batch.import_status='COMPLETED'
  where revision.line_disposition='PRESENT'
    and revision.unit_id is distinct from ingredient.purchase_unit_id
    and revision_mapping.last_source_fingerprint is not null
    and batch.operator_actor_id is not null
    and exists (
      select 1 from atlas_legacy.master_data_mappings ingredient_mapping
      where ingredient_mapping.source_system='OPS_V1'
        and ingredient_mapping.object_type='INGREDIENT'
        and ingredient_mapping.ingredient_id=revision.ingredient_id
    )
    and exists (
      select 1 from atlas_legacy.master_data_mappings unit_mapping
      where unit_mapping.source_system='OPS_V1'
        and unit_mapping.object_type='UNIT'
        and unit_mapping.unit_id=revision.unit_id
    )
    and exists (
      select 1 from atlas_legacy.master_data_mappings recipe_mapping
      where recipe_mapping.source_system='OPS_V1'
        and recipe_mapping.object_type='RECIPE'
        and recipe_mapping.recipe_id=revision.recipe_id
    )
    and exists (
      select 1 from atlas_legacy.master_data_mappings version_mapping
      where version_mapping.source_system='OPS_V1'
        and version_mapping.object_type='RECIPE_VERSION'
        and version_mapping.recipe_version_id=revision.recipe_version_id
    )
    and exists (
      select 1
      from jsonb_array_elements(coalesce(batch.reconciliation->'actions','[]'::jsonb)) action
      where action.value->>'object_type'='RECIPE_LINE_REVISION'
        and action.value->>'target_id'=revision.recipe_line_revision_id::text
        and action.value#>>'{values,recipe_id}'=revision.recipe_id::text
        and action.value#>>'{values,recipe_line_id}'=revision.recipe_line_id::text
        and action.value#>>'{values,ingredient_id}'=revision.ingredient_id::text
        and (action.value#>>'{values,quantity_per_basis}')::numeric=revision.quantity_per_basis
        and action.value#>>'{values,unit_id}'=revision.unit_id::text
    );

  select count(*),count(distinct predecessor_recipe_version_id)
    into eligible_line_count,eligible_recipe_count
  from _ops_v1_unit_repair_candidates;

  if eligible_line_count=0 then
    return;
  end if;

  perform 1
  from atlas_admin.recipes recipe
  where recipe.recipe_id in (select distinct recipe_id from _ops_v1_unit_repair_candidates)
  order by recipe.recipe_id
  for update;
  perform 1
  from atlas_admin.recipe_versions version
  where version.recipe_version_id in (select distinct predecessor_recipe_version_id from _ops_v1_unit_repair_candidates)
  order by version.recipe_version_id
  for update;

  create temp table _ops_v1_unit_repair_successors (
    predecessor_recipe_line_revision_id uuid primary key,
    target_recipe_line_revision_id uuid not null,
    target_recipe_version_id uuid not null,
    corrected boolean not null
  ) on commit drop;

  for version_row in
    select version.*, candidate.operator_actor_id
    from atlas_admin.recipe_versions version
    join (
      select predecessor_recipe_version_id,(array_agg(operator_actor_id order by operator_actor_id))[1] as operator_actor_id
      from _ops_v1_unit_repair_candidates
      group by predecessor_recipe_version_id
    ) candidate on candidate.predecessor_recipe_version_id=version.recipe_version_id
    order by version.recipe_id,version.recipe_version_id
  loop
    actor:=version_row.operator_actor_id;
    successor_version:=md5('OPS_V1:UNIT_ADOPTION_RECIPE_VERSION:'||version_row.recipe_version_id::text)::uuid;

    insert into atlas_admin.recipe_versions(
      recipe_version_id,recipe_id,version_number,predecessor_recipe_version_id,
      basis_portions,created_by_actor_id,draft_composition,source_evidence
    )
    select
      successor_version,version_row.recipe_id,version_row.version_number+1,version_row.recipe_version_id,
      version_row.basis_portions,actor,
      coalesce(jsonb_agg(jsonb_build_object(
        'recipe_id',revision.recipe_id,
        'recipe_version_id',successor_version,
        'recipe_line_id',revision.recipe_line_id,
        'line_revision_number',revision.line_revision_number+1,
        'predecessor_recipe_line_revision_id',revision.recipe_line_revision_id,
        'ingredient_id',revision.ingredient_id,
        'unit_id',coalesce(candidate.corrected_unit_id,revision.unit_id),
        'quantity_per_basis',revision.quantity_per_basis,
        'line_disposition',revision.line_disposition,
        'operational_note',revision.operational_note
      ) order by revision.recipe_line_id),'[]'::jsonb),
      jsonb_build_object(
        'source_kind','OPS_V1_BOM_UNIT_TO_INGREDIENT_PURCHASE_UNIT_CORRECTION',
        'source_system','OPS_V1',
        'predecessor_recipe_version_id',version_row.recipe_version_id
      )
    from atlas_admin.recipe_line_revisions revision
    left join _ops_v1_unit_repair_candidates candidate
      on candidate.predecessor_recipe_line_revision_id=revision.recipe_line_revision_id
    where revision.recipe_version_id=version_row.recipe_version_id;

    for line_row in
      select revision.*,candidate.corrected_unit_id,candidate.legacy_recipe_line_id,
        candidate.source_fingerprint,candidate.import_batch_id,candidate.snapshot_id,
        candidate.snapshot_checksum,candidate.source_unit_id,candidate.operator_actor_id
      from atlas_admin.recipe_line_revisions revision
      left join _ops_v1_unit_repair_candidates candidate
        on candidate.predecessor_recipe_line_revision_id=revision.recipe_line_revision_id
      where revision.recipe_version_id=version_row.recipe_version_id
      order by revision.recipe_line_id
    loop
      successor_revision:=md5('OPS_V1:UNIT_ADOPTION_RECIPE_LINE_REVISION:'||line_row.recipe_line_revision_id::text)::uuid;
      insert into atlas_admin.recipe_line_revisions(
        recipe_line_revision_id,recipe_id,recipe_version_id,recipe_line_id,line_revision_number,
        predecessor_recipe_line_revision_id,ingredient_id,quantity_per_basis,unit_id,
        line_disposition,calculation_kind,operational_note,created_by_actor_id
      ) values (
        successor_revision,line_row.recipe_id,successor_version,line_row.recipe_line_id,line_row.line_revision_number+1,
        line_row.recipe_line_revision_id,line_row.ingredient_id,line_row.quantity_per_basis,
        coalesce(line_row.corrected_unit_id,line_row.unit_id),line_row.line_disposition,
        line_row.calculation_kind,line_row.operational_note,actor
      );
      insert into _ops_v1_unit_repair_successors values(
        line_row.recipe_line_revision_id,successor_revision,successor_version,line_row.corrected_unit_id is not null
      );

      if line_row.corrected_unit_id is not null then
        insert into atlas_legacy.recipe_unit_adoption_evidence(
          recipe_unit_adoption_evidence_id,evidence_kind,source_system,import_batch_id,
          snapshot_id,snapshot_checksum,legacy_recipe_line_id,source_fingerprint,
          recipe_id,recipe_line_id,predecessor_recipe_version_id,target_recipe_version_id,
          predecessor_recipe_line_revision_id,target_recipe_line_revision_id,
          ingredient_id,quantity_per_basis,source_unit_id,corrected_unit_id,recorded_by_actor_id
        ) values (
          md5('OPS_V1:UNIT_ADOPTION_CORRECTION:'||successor_revision::text)::uuid,
          'OPS_V1_BOM_UNIT_TO_INGREDIENT_PURCHASE_UNIT_CORRECTION','OPS_V1',line_row.import_batch_id,
          line_row.snapshot_id,line_row.snapshot_checksum,line_row.legacy_recipe_line_id,line_row.source_fingerprint,
          line_row.recipe_id,line_row.recipe_line_id,version_row.recipe_version_id,successor_version,
          line_row.recipe_line_revision_id,successor_revision,line_row.ingredient_id,
          line_row.quantity_per_basis,line_row.source_unit_id,line_row.corrected_unit_id,line_row.operator_actor_id
        );
        transitioned_line_count:=transitioned_line_count+1;
        corrected_line_count:=corrected_line_count+1;
      elsif line_row.line_disposition='PRESENT' then
        copied_line_count:=copied_line_count+1;
      end if;
      if line_row.line_disposition='PRESENT' then
        successor_present_line_count:=successor_present_line_count+1;
      end if;
    end loop;

    update atlas_admin.recipe_versions
    set recipe_version_status='VALIDATED',validated_by_actor_id=actor,
      validated_at=clock_timestamp(),version=version+1
    where recipe_version_id=successor_version;
    set constraints atlas_admin.recipe_versions_integrity_guard immediate;
    set constraints atlas_admin.recipe_versions_integrity_guard deferred;

    update atlas_admin.recipe_versions
    set recipe_version_status='LOCKED',locked_by_actor_id=actor,
      locked_at=clock_timestamp(),version=version+1
    where recipe_version_id=version_row.recipe_version_id
      and recipe_version_status='RELEASED_FOR_PLANNING';
    update atlas_admin.recipe_versions
    set recipe_version_status='RELEASED_FOR_PLANNING',released_by_actor_id=actor,
      released_at=clock_timestamp(),version=version+1
    where recipe_version_id=successor_version;
    set constraints atlas_admin.recipe_versions_integrity_guard immediate;
    set constraints atlas_admin.recipe_versions_integrity_guard deferred;

    update atlas_legacy.master_data_mappings mapping
    set last_target_version=predecessor.version,updated_at=clock_timestamp()
    from atlas_admin.recipe_versions predecessor
    where mapping.source_system='OPS_V1'
      and mapping.object_type='RECIPE_VERSION'
      and mapping.recipe_version_id=version_row.recipe_version_id
      and predecessor.recipe_version_id=version_row.recipe_version_id
      and mapping.last_target_version is distinct from predecessor.version;
    transitioned_recipe_count:=transitioned_recipe_count+1;
  end loop;

  if transitioned_line_count<>eligible_line_count
    or transitioned_recipe_count<>eligible_recipe_count
    or successor_present_line_count<>corrected_line_count+copied_line_count
  then
    raise exception using errcode='23514',message='OPS_V1_ADOPTION_RECONCILIATION_COUNT_MISMATCH';
  end if;
end
$reconcile_existing_ops_v1_adoption$;

set role atlas_owner;
revoke all on function atlas_legacy.master_recipe_composition(jsonb,text) from public,anon,authenticated,service_role;
revoke all on function atlas_legacy.master_recipe_operational_unit(jsonb,text) from public,anon,authenticated,service_role;
revoke all on function atlas_legacy.master_import_recipe_plan(jsonb) from public,anon,authenticated,service_role;
revoke all on function atlas_legacy.apply_master_data_snapshot(jsonb,text,uuid) from public,anon,authenticated,service_role;
revoke all on function atlas_admin.pa_06e_h0a2_recipe_version_integrity_guard() from public,anon,authenticated,service_role;
reset role;
