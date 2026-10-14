-- Migration 107. Product amendment ATLAS-EFFECTIVE-COMPOSITION-GENERATION-01.
-- Generated evidence only; existing rows and released base Recipes are untouched.
reset role;
create temporary table atlas_effective_runtime_access_before as
select role.rolname,membership.admin_option,membership.inherit_option,membership.set_option
from pg_catalog.pg_roles role left join pg_catalog.pg_auth_members membership
  on membership.roleid=role.oid and membership.member='postgres'::regrole
 and membership.grantor='postgres'::regrole
where role.rolname in ('atlas_need_generation_runtime','atlas_planning_materialization_runtime');
create temporary table atlas_effective_schema_access_before as
select pg_catalog.has_schema_privilege('atlas_need_generation_runtime','atlas_core','CREATE') as had_create;
grant atlas_need_generation_runtime to postgres with set true;
grant atlas_planning_materialization_runtime to postgres with set true;
set role atlas_owner;

alter table atlas_planning.need_generation_recipe_selections
  add column effective_composition jsonb,
  add constraint need_generation_effective_composition_array check (
    effective_composition is null or jsonb_typeof(effective_composition)='array'
  );
alter table atlas_planning.need_generation_recipe_line_uses
  alter column recipe_line_id drop not null,
  alter column recipe_line_revision_id drop not null,
  add column effective_line jsonb,
  add column adjustment_line_id uuid,
  add column adjustment_id uuid,
  add column adjustment_revision_id uuid,
  add column effective_ingredient_id uuid generated always as ((effective_line->>'final_ingredient_id')::uuid) stored,
  add column effective_unit_id uuid generated always as ((effective_line->>'final_unit_id')::uuid) stored,
  add constraint need_generation_effective_ingredient_fkey foreign key (effective_ingredient_id) references atlas_admin.ingredients on delete restrict,
  add constraint need_generation_effective_unit_fkey foreign key (effective_unit_id) references atlas_admin.units on delete restrict,
  add constraint need_generation_add_revision_fkey foreign key (adjustment_revision_id,adjustment_id)
    references atlas_admin.recipe_composition_adjustment_revisions(recipe_composition_adjustment_revision_id,recipe_composition_adjustment_id) on delete restrict,
  add constraint need_generation_effective_line_identity check (
    (recipe_line_id is not null and recipe_line_revision_id is not null
      and adjustment_line_id is null and adjustment_id is null and adjustment_revision_id is null)
    or (recipe_line_id is null and recipe_line_revision_id is null
      and effective_line is not null and adjustment_line_id is not null
      and adjustment_id is not null and adjustment_revision_id is not null)
  ),
  add constraint need_generation_effective_line_values check (
    effective_line is null or (
      jsonb_typeof(effective_line)='object'
      and effective_ingredient_id is not null and effective_unit_id is not null
      and (effective_line->>'final_quantity_per_basis')::numeric >= 0
      and effective_line->>'final_disposition' in ('PRESENT','REMOVED')
      and jsonb_typeof(effective_line->'lineage')='array'
      and jsonb_typeof(effective_line->'applied_revision_ids')='array'
    )
  );
create unique index need_generation_effective_add_line_key
  on atlas_planning.need_generation_recipe_line_uses(need_generation_recipe_selection_id,adjustment_line_id)
  where adjustment_line_id is not null;
create unique index theoretical_need_lines_effective_use_key
  on atlas_planning.theoretical_need_lines(need_generation_recipe_line_use_id,attendance_approval_snapshot_line_id)
  where need_generation_recipe_line_use_id is not null;
create index need_generation_effective_ingredient_idx on atlas_planning.need_generation_recipe_line_uses(effective_ingredient_id)
  where effective_ingredient_id is not null;
create index need_generation_effective_unit_idx on atlas_planning.need_generation_recipe_line_uses(effective_unit_id)
  where effective_unit_id is not null;
create index need_generation_add_revision_idx on atlas_planning.need_generation_recipe_line_uses(adjustment_revision_id,adjustment_id)
  where adjustment_revision_id is not null;

grant select on atlas_admin.recipe_composition_adjustments,atlas_admin.recipe_composition_adjustment_revisions
  to atlas_need_generation_runtime;
create policy need_generation_effective_adjustments_read on atlas_admin.recipe_composition_adjustments
  for select to atlas_need_generation_runtime using (true);
create policy need_generation_effective_revisions_read on atlas_admin.recipe_composition_adjustment_revisions
  for select to atlas_need_generation_runtime using (true);
grant execute on function
  atlas_core.recipe_effective_resolve_composition(date,uuid,uuid,uuid,jsonb,uuid,uuid),
  atlas_core.rmvp_02b_resolve_selected_composition(date,uuid,uuid,jsonb,uuid,uuid),
  atlas_core.rmvp_02b_active_rules(date,uuid,uuid,jsonb,uuid),
  atlas_core.rmvp_02b_transform_line(jsonb,jsonb),
  atlas_core.rmvp_02b_safe_date(text),
  atlas_core.pa_05b_safe_numeric(text)
  to atlas_need_generation_runtime;

-- Check the capture once per selection, never per Ingredient. Later transitions
-- validate immutable membership and arithmetic without resolving today's rules.
create function atlas_planning.need_generation_effective_capture_guard()
returns trigger language plpgsql security invoker set search_path='' as $$
declare
  menu atlas_planning.weekly_menu_approval_snapshot_lines%rowtype;
  resolved jsonb;
begin
  if new.effective_composition is null then return new; end if;
  select * into strict menu from atlas_planning.weekly_menu_approval_snapshot_lines
    where weekly_menu_approval_snapshot_line_id=new.weekly_menu_approval_snapshot_line_id;
  resolved:=atlas_core.recipe_effective_resolve_composition(menu.service_date,new.school_id,new.dish_id,
    new.school_type_id,jsonb_build_object('_target_school_type_id',new.school_type_id),null,new.recipe_version_id);
  if resolved->>'status' is distinct from 'READY'
    or resolved->'lines' is distinct from new.effective_composition
    or resolved#>>'{selected_recipe,recipe_id}' is distinct from new.recipe_id::text
  then raise exception using errcode='23514',message='Need Generation must capture the exact READY effective composition'; end if;
  return new;
end $$;
revoke all on function atlas_planning.need_generation_effective_capture_guard() from public,anon,authenticated,service_role;
create trigger need_generation_effective_capture before insert
  on atlas_planning.need_generation_recipe_selections for each row
  execute function atlas_planning.need_generation_effective_capture_guard();
reset role;

-- A disappeared native ADD is an explicit predecessor-bound removal, using
-- the existing governed Recipe replacement evidence path.
create function atlas_core.need_generation_effective_contains_line(composition jsonb,prior_use_id uuid)
returns boolean language sql stable security invoker set search_path='' as $$
  select exists(select 1 from atlas_planning.need_generation_recipe_line_uses captured,
    jsonb_array_elements(composition) line
    where captured.need_generation_recipe_line_use_id=prior_use_id
      and line->>'final_disposition'='PRESENT'
      and ((captured.recipe_line_id is not null and line->>'base_recipe_line_id'=captured.recipe_line_id::text)
        or (captured.adjustment_line_id is not null and line->>'adjustment_line_id'=captured.adjustment_line_id::text)))
$$;
alter function atlas_core.need_generation_effective_contains_line(jsonb,uuid) owner to atlas_owner;
revoke all on function atlas_core.need_generation_effective_contains_line(jsonb,uuid) from public,anon,authenticated,service_role;
grant execute on function atlas_core.need_generation_effective_contains_line(jsonb,uuid)
  to atlas_need_generation_runtime,atlas_planning_materialization_runtime;

do $removal$
declare definition text; old_text text;
begin
  definition:=pg_get_functiondef('atlas_core.planning_contract_02a_recipe_replacement_removal(uuid,uuid,uuid,jsonb)'::regprocedure);
  old_text:=$sql$        current_selection.recipe_version_id
      ) is distinct from row($sql$;
  if position(old_text in definition)=0 then raise exception '107 missing replacement predicate'; end if;
  -- Wrap only the existing three-column Recipe comparison.
  definition:=replace(definition,'      and row('||E'\n        current_selection.dish_id','      and (row('||E'\n        current_selection.dish_id');
  old_text:=$sql$        prior_selection.recipe_version_id
      )$sql$;
  definition:=replace(definition,old_text,old_text||$sql$ or (
        current_selection.effective_composition is not null
        and not atlas_core.need_generation_effective_contains_line(
          current_selection.effective_composition,prior.need_generation_recipe_line_use_id
        )
      ))$sql$);
  definition:=replace(definition,E'      recipe_version_id uuid\n',E'      recipe_version_id uuid, effective_composition jsonb\n');
  execute definition;

  definition:=pg_get_functiondef('atlas_planning.planning_contract_02a_recipe_replacement_guard()'::regprocedure);
  old_text:=$sql$          and row(
            successor_selection.dish_id,
            successor_selection.recipe_id,
            successor_selection.recipe_version_id
          ) is distinct from row(
            predecessor_selection.dish_id,
            predecessor_selection.recipe_id,
            predecessor_selection.recipe_version_id
          )$sql$;
  if position(old_text in definition)=0 then raise exception '107 missing governed removal guard predicate'; end if;
  definition:=replace(definition,old_text,replace(old_text,'and row(','and (row(')||$sql$ or (
            successor_selection.effective_composition is not null
            and not atlas_core.need_generation_effective_contains_line(
              successor_selection.effective_composition,predecessor.need_generation_recipe_line_use_id
            )
          ))$sql$);
  definition:=replace(definition,E'          ) = row(\n            predecessor.dish_id',E'          ) is not distinct from row(\n            predecessor.dish_id');
  execute definition;

  definition:=pg_get_functiondef('atlas_core.planning_contract_01_materialize_confirmed_needs(jsonb)'::regprocedure);
  old_text:=$sql$                     successor.contribution_family = 'RECIPE_DERIVED'
                     and successor.line_disposition = 'REMOVED'
                     and successor.recipe_replacement_predecessor_selection_id is not null
                     and successor.recipe_replacement_successor_selection_id is not null$sql$;
  if position(old_text in definition)=0 then raise exception '107 missing Confirmed Need removal acceptance'; end if;
  definition:=replace(definition,old_text,$sql$                     successor.contribution_family = 'RECIPE_DERIVED'
                     and successor.line_disposition = 'REMOVED'
                     and ((successor.recipe_replacement_predecessor_selection_id is not null
                       and successor.recipe_replacement_successor_selection_id is not null)
                       or exists(select 1 from atlas_planning.need_generation_recipe_line_uses captured
                         where captured.need_generation_recipe_line_use_id=successor.need_generation_recipe_line_use_id
                           and captured.effective_line->>'final_disposition'='REMOVED'))$sql$);
  execute definition;
end $removal$;

do $generator$
declare
  definition text:=pg_get_functiondef('atlas_api.create_need_generation_run(jsonb)'::regprocedure);
  old_text text;
  new_text text;
begin
  definition:=replace(definition,'  v_revision record;',E'  v_revision record;\n  v_effective jsonb;');
  old_text:=E'    v_selection_id := gen_random_uuid();';
  new_text:=$sql$    -- Preserve the existing released-base selection; pin that exact version
    -- through the canonical resolver's selected-version support argument.
    v_effective := atlas_core.recipe_effective_resolve_composition(
      v_menu.service_date,v_menu.school_id,v_menu.dish_id,v_menu.school_type_id,
      jsonb_build_object('_target_school_type_id',v_menu.school_type_id),null,v_menu.recipe_version_id
    );
    if v_effective->>'status' is distinct from 'READY' then
      v_error:=atlas_core.rmvp_04_error(request,v_name,'NEED_GENERATION_HAS_BLOCKERS',
        'Effective Recipe composition is not ready for this Menu assignment.');
      return atlas_core.pa_05b_finish_command(v_receipt_id,v_error,false);
    end if;
    v_selection_id := gen_random_uuid();$sql$;
  if position(old_text in definition)=0 then raise exception '107 missing generator selection boundary'; end if;
  definition:=replace(definition,old_text,new_text);
  definition:=replace(definition,'''selection_scope'', v_menu.selection_scope',
    '''selection_scope'', v_menu.selection_scope, ''effective_composition'', v_effective->''lines''');
  old_text:=$sql$      select revision.*, ingredient.ingredient_status,
        unit.unit_status
      from atlas_admin.recipe_line_revisions as revision
      join atlas_admin.ingredients as ingredient
        on ingredient.ingredient_id = revision.ingredient_id
      join atlas_admin.units as unit on unit.unit_id = revision.unit_id
      where revision.recipe_version_id = v_menu.recipe_version_id
        and revision.recipe_id = v_menu.recipe_id
      order by revision.recipe_line_id$sql$;
  new_text:=$sql$      select (line->>'base_recipe_line_id')::uuid as recipe_line_id,
        (line->>'base_recipe_line_revision_id')::uuid as recipe_line_revision_id,
        (line->>'final_ingredient_id')::uuid as ingredient_id,
        (line->>'final_unit_id')::uuid as unit_id,
        (line->>'final_quantity_per_basis')::numeric as quantity_per_basis,
        line->>'final_disposition' as line_disposition,
        line as effective_line,(line->>'adjustment_line_id')::uuid as adjustment_line_id,
        ingredient.ingredient_status,unit.unit_status
      from jsonb_array_elements(v_effective->'lines') line
      join atlas_admin.ingredients ingredient on ingredient.ingredient_id=(line->>'final_ingredient_id')::uuid
      join atlas_admin.units unit on unit.unit_id=(line->>'final_unit_id')::uuid
      order by coalesce(line->>'base_recipe_line_id',line->>'adjustment_line_id')$sql$;
  if position(old_text in definition)=0 then raise exception '107 missing base composition query'; end if;
  definition:=replace(definition,old_text,new_text);
  old_text:=$sql$'recipe_line_revision_id', v_revision.recipe_line_revision_id
        )$sql$;
  new_text:=$sql$'recipe_line_revision_id', v_revision.recipe_line_revision_id,
          'effective_line',v_revision.effective_line,
          'adjustment_line_id',v_revision.adjustment_line_id,
          'adjustment_id',case when v_revision.adjustment_line_id is not null then v_revision.effective_line#>>'{lineage,0,adjustment_id}' end,
          'adjustment_revision_id',case when v_revision.adjustment_line_id is not null then v_revision.effective_line#>>'{lineage,0,revision_id}' end
        )$sql$;
  if position(old_text in definition)=0 then raise exception '107 missing composition-use capture'; end if;
  definition:=replace(definition,old_text,new_text);
  old_text:='          and prior.recipe_line_id = v_revision.recipe_line_id;';
  new_text:=$sql$          and prior.recipe_line_id is not distinct from v_revision.recipe_line_id
          and (v_revision.recipe_line_id is not null or exists (
            select 1 from atlas_planning.need_generation_recipe_line_uses prior_use
            where prior_use.need_generation_recipe_line_use_id=prior.need_generation_recipe_line_use_id
              and prior_use.adjustment_line_id=v_revision.adjustment_line_id
          ));$sql$;
  if position(old_text in definition)=0 then raise exception '107 missing predecessor lookup'; end if;
  definition:=replace(definition,old_text,new_text);
  old_text:='            and removed.recipe_line_id = v_revision.recipe_line_id';
  new_text:=old_text||$sql$
            and not exists (
              select 1 from atlas_planning.need_generation_recipe_line_uses removed_use
              where removed_use.need_generation_recipe_line_use_id=removed.need_generation_recipe_line_use_id
                and jsonb_array_length(removed_use.effective_line->'lineage')>0
            )$sql$;
  definition:=replace(definition,old_text,new_text);
  old_text:=$sql$    recipe_line_revision_id, captured_at
  )
  select item.id, v_snapshot_id, v_run_id, item.selection_id,
    item.recipe_id, item.recipe_version_id, item.recipe_line_id,
    item.recipe_line_revision_id, v_now
  from pg_catalog.jsonb_to_recordset(v_uses) as item(
    id uuid, selection_id uuid, recipe_id uuid, recipe_version_id uuid,
    recipe_line_id uuid, recipe_line_revision_id uuid
  );$sql$;
  new_text:=$sql$    recipe_line_revision_id, captured_at,effective_line,adjustment_line_id,adjustment_id,adjustment_revision_id
  )
  select item.id, v_snapshot_id, v_run_id, item.selection_id,
    item.recipe_id, item.recipe_version_id, item.recipe_line_id,
    item.recipe_line_revision_id, v_now,item.effective_line,item.adjustment_line_id,item.adjustment_id,item.adjustment_revision_id
  from pg_catalog.jsonb_to_recordset(v_uses) as item(
    id uuid, selection_id uuid, recipe_id uuid, recipe_version_id uuid,
    recipe_line_id uuid, recipe_line_revision_id uuid,effective_line jsonb,
    adjustment_line_id uuid,adjustment_id uuid,adjustment_revision_id uuid
  );$sql$;
  if position(old_text in definition)=0 then raise exception '107 missing composition-use insert'; end if;
  definition:=replace(definition,old_text,new_text);
  -- Selection insert has one scalar tuple, before the theoretical-line insert.
  old_text:='selection_scope, selected_at';
  if position(old_text in definition)=0 then raise exception '107 missing selection columns'; end if;
  definition:=replace(definition,old_text,'selection_scope, selected_at,effective_composition');
  definition:=replace(definition,'    item.selection_scope, v_now','    item.selection_scope, v_now,item.effective_composition');
  definition:=replace(definition,E'    selection_scope text\n  );',E'    selection_scope text,effective_composition jsonb\n  );');
  execute definition;
end $generator$;

-- Adapt the existing guards rather than bypassing them for new runs.
do $integrity$
declare
  definition text:=pg_get_functiondef('atlas_planning.pa_06e_h0a5b_need_generation_integrity_guard()'::regprocedure);
  old_text text;
  new_text text;
begin
  old_text:=$sql$      join atlas_admin.recipe_line_revisions revision
        on revision.recipe_line_revision_id = new.recipe_line_revision_id$sql$;
  new_text:=$sql$      join atlas_planning.need_generation_recipe_line_uses captured
        on captured.need_generation_recipe_line_use_id=new.need_generation_recipe_line_use_id
      left join atlas_admin.recipe_line_revisions effective_base on effective_base.recipe_line_revision_id=captured.recipe_line_revision_id
    cross join lateral (select case when captured.effective_line is null then effective_base.recipe_id else captured.recipe_id end as recipe_id,
      case when captured.effective_line is null then effective_base.recipe_version_id else captured.recipe_version_id end as recipe_version_id,
      case when captured.effective_line is null then effective_base.recipe_line_id else captured.recipe_line_id end as recipe_line_id,
      captured.recipe_line_revision_id,
      case when captured.effective_line is null then effective_base.ingredient_id else captured.effective_ingredient_id end as ingredient_id,
      case when captured.effective_line is null then effective_base.unit_id else captured.effective_unit_id end as unit_id,
      case when captured.effective_line is null then effective_base.quantity_per_basis else (captured.effective_line->>'final_quantity_per_basis')::numeric end as quantity_per_basis,
      case when captured.effective_line is null then effective_base.line_disposition else captured.effective_line->>'final_disposition' end as line_disposition) as revision$sql$;
  if position(old_text in definition)=0 then raise exception '107 missing scale ownership proof'; end if;
  definition:=replace(definition,old_text,new_text);
  definition:=replace(definition,'and revision.recipe_line_id = new.recipe_line_id',
    'and revision.recipe_line_id is not distinct from new.recipe_line_id');
  old_text:=$sql$      select count(*) from atlas_admin.recipe_line_revisions revision
      where revision.recipe_version_id = new.recipe_version_id$sql$;
  new_text:=$sql$      select case when selection.effective_composition is not null
        then jsonb_array_length(selection.effective_composition)
        else (select count(*) from atlas_admin.recipe_line_revisions revision where revision.recipe_version_id=new.recipe_version_id) end
      from atlas_planning.need_generation_recipe_selections selection
      where selection.need_generation_recipe_selection_id=new.need_generation_recipe_selection_id$sql$;
  if position(old_text in definition)=0 then raise exception '107 missing scale composition count'; end if;
  definition:=replace(definition,old_text,new_text);
  old_text:=$sql$    join atlas_admin.recipe_line_revisions as revision
      on revision.recipe_line_revision_id = line_use.recipe_line_revision_id$sql$;
  definition:=replace(definition,old_text,
    $sql$    left join atlas_admin.recipe_line_revisions effective_base on effective_base.recipe_line_revision_id=line_use.recipe_line_revision_id
    cross join lateral (select case when line_use.effective_line is null then effective_base.recipe_id else line_use.recipe_id end as recipe_id,
      case when line_use.effective_line is null then effective_base.recipe_version_id else line_use.recipe_version_id end as recipe_version_id,
      case when line_use.effective_line is null then effective_base.recipe_line_id else line_use.recipe_line_id end as recipe_line_id,
      line_use.recipe_line_revision_id,
      case when line_use.effective_line is null then effective_base.ingredient_id else line_use.effective_ingredient_id end as ingredient_id,
      case when line_use.effective_line is null then effective_base.unit_id else line_use.effective_unit_id end as unit_id,
      case when line_use.effective_line is null then effective_base.quantity_per_basis else (line_use.effective_line->>'final_quantity_per_basis')::numeric end as quantity_per_basis,
      case when line_use.effective_line is null then effective_base.line_disposition else line_use.effective_line->>'final_disposition' end as line_disposition) as revision$sql$);
  old_text:=$sql$        select count(*)
        from atlas_admin.recipe_line_revisions as revision
        where revision.recipe_version_id = selection.recipe_version_id$sql$;
  new_text:=$sql$        select case when selection.effective_composition is not null
          then jsonb_array_length(selection.effective_composition)
          else (select count(*) from atlas_admin.recipe_line_revisions revision where revision.recipe_version_id=selection.recipe_version_id) end$sql$;
  if position(old_text in definition)=0 then raise exception '107 missing full composition count'; end if;
  definition:=replace(definition,old_text,new_text);
  definition:=replace(definition,E'      and not exists (\n        select 1\n        from atlas_planning.need_generation_recipe_line_uses as line_use',
    E'      and selection.effective_composition is null\n      and not exists (\n        select 1\n        from atlas_planning.need_generation_recipe_line_uses as line_use');
  old_text:=$sql$    join atlas_admin.recipe_line_revisions as recipe_revision
      on recipe_revision.recipe_line_revision_id = line.recipe_line_revision_id$sql$;
  definition:=replace(definition,old_text,
    $sql$    left join atlas_admin.recipe_line_revisions effective_base on effective_base.recipe_line_revision_id=line_use.recipe_line_revision_id
    cross join lateral (select case when line_use.effective_line is null then effective_base.recipe_id else line_use.recipe_id end as recipe_id,
      case when line_use.effective_line is null then effective_base.recipe_version_id else line_use.recipe_version_id end as recipe_version_id,
      case when line_use.effective_line is null then effective_base.recipe_line_id else line_use.recipe_line_id end as recipe_line_id,
      line_use.recipe_line_revision_id,
      case when line_use.effective_line is null then effective_base.ingredient_id else line_use.effective_ingredient_id end as ingredient_id,
      case when line_use.effective_line is null then effective_base.unit_id else line_use.effective_unit_id end as unit_id,
      case when line_use.effective_line is null then effective_base.quantity_per_basis else (line_use.effective_line->>'final_quantity_per_basis')::numeric end as quantity_per_basis,
      case when line_use.effective_line is null then effective_base.line_disposition else line_use.effective_line->>'final_disposition' end as line_disposition) as recipe_revision$sql$);
  old_text:=$sql$    join atlas_admin.recipe_line_revisions as recipe_revision
      on recipe_revision.recipe_line_revision_id = line_use.recipe_line_revision_id
     and recipe_revision.line_disposition = 'PRESENT'$sql$;
  new_text:=$sql$    left join atlas_admin.recipe_line_revisions effective_base on effective_base.recipe_line_revision_id=line_use.recipe_line_revision_id
    join lateral (select case when line_use.effective_line is null then effective_base.recipe_id else line_use.recipe_id end as recipe_id,
      case when line_use.effective_line is null then effective_base.recipe_version_id else line_use.recipe_version_id end as recipe_version_id,
      case when line_use.effective_line is null then effective_base.recipe_line_id else line_use.recipe_line_id end as recipe_line_id,
      line_use.recipe_line_revision_id,
      case when line_use.effective_line is null then effective_base.ingredient_id else line_use.effective_ingredient_id end as ingredient_id,
      case when line_use.effective_line is null then effective_base.unit_id else line_use.effective_unit_id end as unit_id,
      case when line_use.effective_line is null then effective_base.quantity_per_basis else (line_use.effective_line->>'final_quantity_per_basis')::numeric end as quantity_per_basis,
      case when line_use.effective_line is null then effective_base.line_disposition else line_use.effective_line->>'final_disposition' end as line_disposition) as recipe_revision
      on recipe_revision.line_disposition='PRESENT'$sql$;
  definition:=replace(definition,old_text,new_text);
  old_text:=$sql$    join atlas_admin.recipe_line_revisions as current_revision
      on current_revision.recipe_line_revision_id = current_use.recipe_line_revision_id$sql$;
  definition:=replace(definition,old_text,
    $sql$    left join atlas_admin.recipe_line_revisions effective_base on effective_base.recipe_line_revision_id=current_use.recipe_line_revision_id
    cross join lateral (select case when current_use.effective_line is null then effective_base.recipe_id else current_use.recipe_id end as recipe_id,
      case when current_use.effective_line is null then effective_base.recipe_version_id else current_use.recipe_version_id end as recipe_version_id,
      case when current_use.effective_line is null then effective_base.recipe_line_id else current_use.recipe_line_id end as recipe_line_id,
      current_use.recipe_line_revision_id,
      case when current_use.effective_line is null then effective_base.ingredient_id else current_use.effective_ingredient_id end as ingredient_id,
      case when current_use.effective_line is null then effective_base.unit_id else current_use.effective_unit_id end as unit_id,
      case when current_use.effective_line is null then effective_base.quantity_per_basis else (current_use.effective_line->>'final_quantity_per_basis')::numeric end as quantity_per_basis,
      case when current_use.effective_line is null then effective_base.line_disposition else current_use.effective_line->>'final_disposition' end as line_disposition) as current_revision$sql$);
  -- Native dated REMOVE is reversible; permanent base removed-line governance stays.
  definition:=replace(definition,E'      and prior.line_disposition = \'REMOVED\'\n      and current_revision.line_disposition',
    E'      and prior.line_disposition = \'REMOVED\'\n      and not exists (select 1 from atlas_planning.need_generation_recipe_line_uses prior_use where prior_use.need_generation_recipe_line_use_id=prior.need_generation_recipe_line_use_id and jsonb_array_length(prior_use.effective_line->\'lineage\')>0)\n      and current_revision.line_disposition');
  -- Null base IDs must still agree exactly with the owning use.
  definition:=replace(definition,'line_use.recipe_line_id <> line.recipe_line_id','line_use.recipe_line_id is distinct from line.recipe_line_id');
  definition:=replace(definition,'line_use.recipe_line_revision_id <> line.recipe_line_revision_id','line_use.recipe_line_revision_id is distinct from line.recipe_line_revision_id');
  definition:=replace(definition,'predecessor.recipe_line_id <> line.recipe_line_id',$sql$predecessor.recipe_line_id is distinct from line.recipe_line_id
        or (line.recipe_line_id is null and line.need_generation_recipe_line_use_id is not null and not exists (
          select 1 from atlas_planning.need_generation_recipe_line_uses current_use
          join atlas_planning.need_generation_recipe_line_uses prior_use
            on prior_use.need_generation_recipe_line_use_id=predecessor.need_generation_recipe_line_use_id
          where current_use.need_generation_recipe_line_use_id=line.need_generation_recipe_line_use_id
            and current_use.adjustment_line_id=prior_use.adjustment_line_id
        ))$sql$);
  execute definition;
end $integrity$;

-- Only the base-line portion of the source check changes. The use FK and
-- strengthened effective evidence guard below prove ADD identity instead.
do $family$
declare definition text;
begin
  select pg_get_constraintdef(oid) into strict definition from pg_constraint
    where conrelid='atlas_planning.theoretical_need_lines'::regclass and conname='theoretical_need_lines_source_family_check';
  definition:=replace(definition,'(recipe_line_id IS NOT NULL) AND (recipe_line_revision_id IS NOT NULL)',
    '(((recipe_line_id IS NOT NULL) AND (recipe_line_revision_id IS NOT NULL)) OR ((recipe_line_id IS NULL) AND (recipe_line_revision_id IS NULL)))');
  execute 'alter table atlas_planning.theoretical_need_lines drop constraint theoretical_need_lines_source_family_check';
  execute 'alter table atlas_planning.theoretical_need_lines add constraint theoretical_need_lines_source_family_check '||definition;
end $family$;

set role atlas_owner;
create function atlas_planning.need_generation_effective_use_guard()
returns trigger language plpgsql security invoker set search_path='' as $$
declare selected atlas_planning.need_generation_recipe_selections%rowtype;
begin
  select * into strict selected from atlas_planning.need_generation_recipe_selections
    where need_generation_recipe_selection_id=new.need_generation_recipe_selection_id;
  if selected.effective_composition is null then
    if new.effective_line is not null then raise exception using errcode='23514',message='Effective use requires an effective selection capture'; end if;
    return new;
  end if;
  if new.effective_line is null
    or not exists(select 1 from jsonb_array_elements(selected.effective_composition) line where line=new.effective_line)
    or selected.recipe_id is distinct from new.recipe_id
    or selected.recipe_version_id is distinct from new.recipe_version_id
    or (new.effective_line->>'selected_recipe_id')::uuid is distinct from new.recipe_id
    or (new.effective_line->>'selected_recipe_version_id')::uuid is distinct from new.recipe_version_id
    or (new.effective_line->>'base_recipe_line_id')::uuid is distinct from new.recipe_line_id
    or (new.effective_line->>'base_recipe_line_revision_id')::uuid is distinct from new.recipe_line_revision_id
    or (new.effective_line->>'adjustment_line_id')::uuid is distinct from new.adjustment_line_id
  then raise exception using errcode='23514',message='Effective use must match its exact immutable selection member'; end if;
  if new.adjustment_line_id is not null and not exists (
    select 1 from atlas_admin.recipe_composition_adjustments root
    join atlas_admin.recipe_composition_adjustment_revisions revision
      on revision.recipe_composition_adjustment_id=root.recipe_composition_adjustment_id
    where root.recipe_composition_adjustment_id=new.adjustment_id
      and root.adjustment_line_id=new.adjustment_line_id and root.action_kind='ADD'
      and revision.recipe_composition_adjustment_revision_id=new.adjustment_revision_id
      and new.effective_line#>>'{lineage,0,adjustment_id}'=new.adjustment_id::text
      and new.effective_line#>>'{lineage,0,revision_id}'=new.adjustment_revision_id::text
      and new.effective_line#>>'{lineage,0,action_kind}'='ADD'
  ) then raise exception using errcode='23514',message='Effective ADD must retain exact creator root, revision and stable adjustment line'; end if;
  if exists (
    select 1 from jsonb_array_elements(new.effective_line->'lineage') step
    left join atlas_admin.recipe_composition_adjustment_revisions revision
      on revision.recipe_composition_adjustment_revision_id=(step->>'revision_id')::uuid
      and revision.recipe_composition_adjustment_id=(step->>'adjustment_id')::uuid
    where revision.recipe_composition_adjustment_revision_id is null
  ) then raise exception using errcode='23514',message='Effective provenance must reference exact immutable adjustment revisions'; end if;
  return new;
end $$;
revoke all on function atlas_planning.need_generation_effective_use_guard() from public,anon,authenticated,service_role;
create trigger need_generation_effective_use before insert
  on atlas_planning.need_generation_recipe_line_uses for each row execute function atlas_planning.need_generation_effective_use_guard();

grant create on schema atlas_core to atlas_need_generation_runtime;
create function atlas_core.need_generation_effective_current(target_run_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare selected record; current_version uuid; resolved jsonb; line jsonb;
begin
  for selected in
    select selection.*,menu.service_date,school.school_type_id as current_school_type_id
    from atlas_planning.need_generation_recipe_selections selection
    join atlas_planning.weekly_menu_approval_snapshot_lines menu using(weekly_menu_approval_snapshot_line_id)
    join atlas_admin.schools school on school.school_id=selection.school_id
    where selection.need_generation_run_id=target_run_id
  loop
    if selected.school_type_id is distinct from selected.current_school_type_id then return false; end if;
    -- Preserve existing base-version/D-047 currentness policy. This check
    -- compares effective composition of the exact captured selected base.
    current_version:=selected.recipe_version_id;
    resolved:=atlas_core.recipe_effective_resolve_composition(selected.service_date,selected.school_id,
      selected.dish_id,selected.school_type_id,jsonb_build_object('_target_school_type_id',selected.school_type_id),null,current_version);
    if resolved->>'status' is distinct from 'READY' then return false; end if;
    if selected.effective_composition is not null then
      if selected.effective_composition is distinct from resolved->'lines' then return false; end if;
    else
      -- Pre-107 captures were base-only. Retain their currency only when today's
      -- exact resolved values AND provenance are still that captured base.
      if jsonb_array_length(resolved->'lines')<>(select count(*) from atlas_planning.need_generation_recipe_line_uses
        where need_generation_recipe_selection_id=selected.need_generation_recipe_selection_id) then return false; end if;
      for line in select * from jsonb_array_elements(resolved->'lines') loop
        if jsonb_array_length(line->'applied_revision_ids')<>0 or not exists (
          select 1 from atlas_planning.need_generation_recipe_line_uses captured
          join atlas_admin.recipe_line_revisions revision using(recipe_line_revision_id)
          where captured.need_generation_recipe_selection_id=selected.need_generation_recipe_selection_id
            and captured.recipe_line_revision_id=(line->>'base_recipe_line_revision_id')::uuid
            and revision.ingredient_id=(line->>'final_ingredient_id')::uuid
            and revision.unit_id=(line->>'final_unit_id')::uuid
            and revision.quantity_per_basis=(line->>'final_quantity_per_basis')::numeric
            and revision.line_disposition=line->>'final_disposition'
        ) then return false; end if;
      end loop;
    end if;
  end loop;
  return true;
end $$;
reset role;
alter function atlas_core.need_generation_effective_current(uuid) owner to atlas_need_generation_runtime;
revoke all on function atlas_core.need_generation_effective_current(uuid) from public,anon,authenticated,service_role;
grant execute on function atlas_core.need_generation_effective_current(uuid) to atlas_planning_materialization_runtime,atlas_read_runtime;
reset role;

do $currentness$
declare
  definition text:=pg_get_functiondef('atlas_core.planning_contract_01_preflight_payload(date,date,jsonb)'::regprocedure);
  old_text text:='  return v_payload;';
begin
  if position(old_text in definition)=0 then raise exception '107 missing preflight return'; end if;
  definition:=replace(definition,old_text,$sql$  if v_payload->>'downstream_currentness'='CURRENT'
    and not atlas_core.need_generation_effective_current(
      atlas_core.pa_05b_safe_uuid(v_payload#>>'{current_need,need_generation_run_id}')
    ) then
    v_payload:=jsonb_set(v_payload,'{downstream_currentness}','"OUTDATED"'::jsonb,true);
  end if;
  return v_payload;$sql$);
  execute definition;
end $currentness$;

do $lifecycle_currentness$
declare definition text; signature text; anchor text:='  if v_run.blocking_issue_count > 0 then';
begin
  foreach signature in array array['atlas_api.validate_need_generation_run(jsonb)','atlas_api.release_need_generation_run(jsonb)'] loop
    definition:=pg_get_functiondef(signature::regprocedure);
    if position(anchor in definition)=0 then raise exception '107 missing lifecycle blocker boundary: %',signature; end if;
    definition:=replace(definition,anchor,$sql$  if not atlas_core.need_generation_effective_current(v_run_id) then
    v_error:=atlas_core.rmvp_04_error(request,v_name,'STALE_SOURCE_BINDING',
      'Effective Recipe composition changed after generation. Regenerate from current evidence.');
    return atlas_core.pa_05b_finish_command(v_receipt_id,v_error,false);
  end if;
$sql$||anchor);
    execute definition;
  end loop;
  definition:=pg_get_functiondef('atlas_core.planning_contract_01_materialize_confirmed_needs(jsonb)'::regprocedure);
  anchor:='  -- Admin reference locks, always UUID ordered.';
  if position(anchor in definition)=0 then raise exception '107 missing materialization currentness boundary'; end if;
  definition:=replace(definition,anchor,$sql$  if not atlas_core.need_generation_effective_current(v_run_id) then
    v_error:=atlas_core.pa_05b_command_error(request,'STALE_SOURCE_BINDING',
      'Effective Recipe composition changed after generation. Regenerate from current evidence.',
      'PLANNING',v_command_name);
    return atlas_core.pa_05b_finish_command(v_receipt_id,v_error,false);
  end if;
$sql$||anchor);
  execute definition;
end $lifecycle_currentness$;


reset role;
-- Restore exact pre-migration privileges, including existing non-SET ownership
-- memberships used by the controlled upgrade/rehearsal tooling.
do $restore_access$
declare access record;
begin
  if not (select had_create from pg_temp.atlas_effective_schema_access_before) then
    revoke create on schema atlas_core from atlas_need_generation_runtime;
  end if;
  for access in select * from pg_temp.atlas_effective_runtime_access_before loop
    if access.admin_option is null then
      execute pg_catalog.format('revoke %I from postgres',access.rolname);
    else
      execute pg_catalog.format('grant %I to postgres with admin %s, inherit %s, set %s',
        access.rolname,case when access.admin_option then 'true' else 'false' end,
        case when access.inherit_option then 'true' else 'false' end,
        case when access.set_option then 'true' else 'false' end);
    end if;
  end loop;
end $restore_access$;
drop table pg_temp.atlas_effective_schema_access_before;
drop table pg_temp.atlas_effective_runtime_access_before;
