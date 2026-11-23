-- D-046: select the ceiling from the grouped raw requirement. Freeze herb membership at generation.
begin;
create temporary table need_rounding_leases on commit drop as
select r.rolname, m.set_option,
       has_schema_privilege(r.oid, 'atlas_core', 'CREATE') as had_create
from pg_roles r left join pg_auth_members m
  on m.roleid = r.oid and m.member = current_user::regrole and m.grantor = current_user::regrole
where r.rolname in ('atlas_owner', 'atlas_planning_materialization_runtime', 'atlas_confirmed_need_review_runtime');
grant select on need_rounding_leases to atlas_owner;
grant atlas_owner, atlas_planning_materialization_runtime, atlas_confirmed_need_review_runtime to postgres with set true;

create function pg_temp.patch_herb_ceiling(target regprocedure, anchor text, replacement text, occurrences integer default 1)
returns void language plpgsql as $$
declare definition text := replace(pg_get_functiondef(target), E'\r\n', E'\n');
begin
  if cardinality(string_to_array(definition, anchor)) <> occurrences + 1 then
    raise exception 'Unexpected Need rounding anchor in %: %', target, anchor;
  end if;
  execute replace(definition, anchor, replacement);
end $$;

set role atlas_owner;
grant create on schema atlas_core to atlas_planning_materialization_runtime, atlas_confirmed_need_review_runtime;
alter table atlas_planning.confirmed_need_batches add column proposal_herb_ingredient_ids uuid[];
comment on column atlas_planning.confirmed_need_batches.proposal_herb_ingredient_ids is
  'Snapshot of approved culinary herbs. Empty uses ingredient steps for every line. NULL retains the historical formula.';

create trigger confirmed_need_batches_guard_rounding_herbs
before update of proposal_herb_ingredient_ids on atlas_planning.confirmed_need_batches
for each row when (old.proposal_herb_ingredient_ids is distinct from new.proposal_herb_ingredient_ids)
execute function atlas_planning.guard_need_rounding_threshold();

create function atlas_core.ingredient_need_proposal(raw_quantity numeric, ingredient_step numeric,
  threshold numeric, is_kilogram boolean, is_listed_herb boolean, confirmation_step numeric default null)
returns numeric language plpgsql immutable security invoker set search_path = '' as $$
declare
  effective_step numeric := ingredient_step;
begin
  if is_listed_herb is null then
    return atlas_core.unit_need_proposal(raw_quantity, ingredient_step, threshold, is_kilogram, confirmation_step);
  end if;
  if is_listed_herb and is_kilogram then
    effective_step := case when raw_quantity < threshold then 0.1 else 0.5 end;
  end if;
  return atlas_core.planning_need_proposal(raw_quantity, effective_step, null, confirmation_step);
end $$;
revoke all on function atlas_core.ingredient_need_proposal(numeric,numeric,numeric,boolean,boolean,numeric)
  from public, anon, authenticated, service_role;
grant execute on function atlas_core.ingredient_need_proposal(numeric,numeric,numeric,boolean,boolean,numeric)
  to atlas_planning_materialization_runtime, atlas_confirmed_need_review_runtime;
reset role;

set role atlas_planning_materialization_runtime;
do $migration$
declare writer constant regprocedure := 'atlas_core.planning_contract_01_materialize_confirmed_needs(jsonb)';
begin
  perform pg_temp.patch_herb_ceiling(writer, 'proposal_whole_round_from, proposal_kg_unit_ids',
    'proposal_whole_round_from, proposal_kg_unit_ids, proposal_herb_ingredient_ids', 2);
  perform pg_temp.patch_herb_ceiling(writer,
    'order by unit_id)
    ) returning confirmed_need_batch_id',
    $new$order by unit_id),
      array(select ingredient_id from atlas_admin.ingredients where ingredient_code in (
        'v1-ingredient-960',  -- Hành lá
        'v1-ingredient-989',  -- Ngò rí
        'v1-ingredient-988',  -- Ngò gai
        'v1-ingredient-1004', -- Rau ôm
        'v1-ingredient-1078', -- Rau quế
        'v1-ingredient-1109', -- Rau kinh giới
        'v1-ingredient-1120'  -- Rau thơm các loại
      ) order by ingredient_id)
    ) returning confirmed_need_batch_id$new$);
  perform pg_temp.patch_herb_ceiling(writer, 'into v_batch_id, v_batch.proposal_whole_round_from, v_batch.proposal_kg_unit_ids;',
    'into v_batch_id, v_batch.proposal_whole_round_from, v_batch.proposal_kg_unit_ids, v_batch.proposal_herb_ingredient_ids;');
  perform pg_temp.patch_herb_ceiling(writer, 'atlas_core.unit_need_proposal(', 'atlas_core.ingredient_need_proposal(', 2);
  perform pg_temp.patch_herb_ceiling(writer, 'any(v_batch.proposal_kg_unit_ids), proposal.confirmation_step)',
    'any(v_batch.proposal_kg_unit_ids),
        target_line.ingredient_id = any(v_batch.proposal_herb_ingredient_ids), proposal.confirmation_step)', 2);
end $migration$;
reset role;

set role atlas_confirmed_need_review_runtime;
do $migration$
declare reader constant regprocedure := 'atlas_core.rmvp_05_workbench_payload(uuid,jsonb,integer,integer)';
begin
  perform pg_temp.patch_herb_ceiling(reader, 'atlas_core.unit_need_proposal(', 'atlas_core.ingredient_need_proposal(');
  perform pg_temp.patch_herb_ceiling(reader, 'any(b.proposal_kg_unit_ids))',
    'any(b.proposal_kg_unit_ids), l.ingredient_id = any(b.proposal_herb_ingredient_ids))');
  perform pg_temp.patch_herb_ceiling(reader, '      b.proposal_whole_round_from,',
    '      b.proposal_whole_round_from,
      case when b.proposal_herb_ingredient_ids is not null then
        l.controlled_unit_id = any(b.proposal_kg_unit_ids) and l.ingredient_id = any(b.proposal_herb_ingredient_ids)
      end as proposal_herb_ceiling,');
  perform pg_temp.patch_herb_ceiling(reader, $old$'proposal_is_kilogram', line.proposal_is_kilogram,$old$,
    $new$'proposal_is_kilogram', line.proposal_is_kilogram,
              'proposal_herb_ceiling', line.proposal_herb_ceiling,$new$);
end $migration$;
reset role;

set role atlas_owner;
do $$ declare lease record; begin
  for lease in select * from pg_temp.need_rounding_leases where not had_create and rolname <> 'atlas_owner' loop
    execute format('revoke create on schema atlas_core from %I', lease.rolname);
  end loop;
end $$;
reset role;
do $$ declare lease record; begin
  for lease in select * from pg_temp.need_rounding_leases loop
    if lease.set_option is null then
      execute format('revoke %I from postgres granted by postgres', lease.rolname);
    elsif not lease.set_option then
      execute format('grant %I to postgres with set false', lease.rolname);
    end if;
  end loop;
end $$;
commit;
