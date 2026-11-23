-- D-046: freeze the unit policy with the generated batch so later master edits cannot change history.
begin;
create temporary table need_rounding_leases on commit drop as
select r.rolname, m.set_option,
       has_schema_privilege(r.oid, 'atlas_core', 'CREATE') as had_create
from pg_roles r left join pg_auth_members m
  on m.roleid = r.oid and m.member = current_user::regrole and m.grantor = current_user::regrole
where r.rolname in ('atlas_owner', 'atlas_planning_materialization_runtime', 'atlas_confirmed_need_review_runtime');
grant select on need_rounding_leases to atlas_owner;
grant atlas_owner, atlas_planning_materialization_runtime, atlas_confirmed_need_review_runtime to postgres with set true;

create function pg_temp.patch_unit_need_rounding(target regprocedure, anchor text, replacement text, occurrences integer default 1)
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
alter table atlas_planning.confirmed_need_batches add column proposal_kg_unit_ids uuid[];
comment on column atlas_planning.confirmed_need_batches.proposal_kg_unit_ids is
  'Kilogram units at batch creation. NULL identifies the earlier proposal formula.';

create trigger confirmed_need_batches_guard_rounding_units
before update of proposal_kg_unit_ids on atlas_planning.confirmed_need_batches
for each row when (old.proposal_kg_unit_ids is distinct from new.proposal_kg_unit_ids)
execute function atlas_planning.guard_need_rounding_threshold();

create function atlas_core.unit_need_proposal(raw_quantity numeric, ingredient_step numeric,
  whole_round_from numeric, is_kilogram boolean, confirmation_step numeric default null)
returns numeric language plpgsql immutable security invoker set search_path = '' as $$
declare
  stepped numeric;
  proposal numeric;
begin
  if is_kilogram is null or whole_round_from is null then
    return atlas_core.planning_need_proposal(raw_quantity, ingredient_step, whole_round_from, confirmation_step);
  end if;
  stepped := pg_catalog.ceil(raw_quantity / ingredient_step) * ingredient_step;
  proposal := pg_catalog.round(stepped, case when is_kilogram and stepped < whole_round_from then 1 else 0 end);
  if pg_catalog.mod(proposal, confirmation_step) <> 0 then
    raise exception using errcode = 'PNR01', message = 'Proposal is incompatible with the confirmation step';
  end if;
  return proposal::numeric(20,6);
end $$;
revoke all on function atlas_core.unit_need_proposal(numeric,numeric,numeric,boolean,numeric)
  from public, anon, authenticated, service_role;
grant execute on function atlas_core.unit_need_proposal(numeric,numeric,numeric,boolean,numeric)
  to atlas_planning_materialization_runtime, atlas_confirmed_need_review_runtime;
reset role;

set role atlas_planning_materialization_runtime;
do $migration$
declare writer constant regprocedure := 'atlas_core.planning_contract_01_materialize_confirmed_needs(jsonb)';
begin
  perform pg_temp.patch_unit_need_rounding(writer, '      proposal_whole_round_from
    ) values', '      proposal_whole_round_from, proposal_kg_unit_ids
    ) values');
  perform pg_temp.patch_unit_need_rounding(writer,
    '      atlas_core.new_need_whole_round_from()
    ) returning confirmed_need_batch_id, proposal_whole_round_from into v_batch_id, v_batch.proposal_whole_round_from;',
    $new$      atlas_core.new_need_whole_round_from(),
      array(select unit_id from atlas_admin.units
        where lower(trim(unit_code)) in ('kg', 'kilogram', 'v1-unit-kg')
           or lower(trim(unit_name)) in ('kg', 'kilogram')
        order by unit_id)
    ) returning confirmed_need_batch_id, proposal_whole_round_from, proposal_kg_unit_ids
      into v_batch_id, v_batch.proposal_whole_round_from, v_batch.proposal_kg_unit_ids;$new$);
  perform pg_temp.patch_unit_need_rounding(writer, 'atlas_core.planning_need_proposal(', 'atlas_core.unit_need_proposal(', 2);
  perform pg_temp.patch_unit_need_rounding(writer,
    'v_batch.proposal_whole_round_from, proposal.confirmation_step)',
    'v_batch.proposal_whole_round_from, target_line.controlled_unit_id = any(v_batch.proposal_kg_unit_ids), proposal.confirmation_step)', 2);
end $migration$;
reset role;

set role atlas_confirmed_need_review_runtime;
do $migration$
declare reader constant regprocedure := 'atlas_core.rmvp_05_workbench_payload(uuid,jsonb,integer,integer)';
begin
  perform pg_temp.patch_unit_need_rounding(reader, 'atlas_core.planning_need_proposal(revision.theoretical_quantity,
          revision.proposal_rounding_step, b.proposal_whole_round_from)',
    'atlas_core.unit_need_proposal(revision.theoretical_quantity,
          revision.proposal_rounding_step, b.proposal_whole_round_from, l.controlled_unit_id = any(b.proposal_kg_unit_ids))');
  perform pg_temp.patch_unit_need_rounding(reader, '      b.proposal_whole_round_from,',
    '      b.proposal_whole_round_from,
      l.controlled_unit_id = any(b.proposal_kg_unit_ids) as proposal_is_kilogram,');
  perform pg_temp.patch_unit_need_rounding(reader, $old$'proposal_whole_round_from', line.proposal_whole_round_from::text,$old$,
    $new$'proposal_whole_round_from', line.proposal_whole_round_from::text,
              'proposal_is_kilogram', line.proposal_is_kilogram,$new$);
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
