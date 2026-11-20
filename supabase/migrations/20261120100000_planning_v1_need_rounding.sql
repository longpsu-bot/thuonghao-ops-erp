-- D-046 amendment: a batch keeps the rounding rule it was created with.
begin;
create temporary table need_rounding_leases on commit drop as
select r.rolname, m.set_option,
       has_schema_privilege(r.oid, 'atlas_core', 'CREATE') as had_create
from pg_roles r left join pg_auth_members m
  on m.roleid = r.oid and m.member = current_user::regrole and m.grantor = current_user::regrole
where r.rolname in ('atlas_owner', 'atlas_planning_materialization_runtime', 'atlas_confirmed_need_review_runtime');
grant select on need_rounding_leases to atlas_owner;
grant atlas_owner, atlas_planning_materialization_runtime, atlas_confirmed_need_review_runtime to postgres with set true;

create function pg_temp.patch_need_rounding(target regprocedure, anchor text, replacement text, occurrences integer default 1)
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
alter table atlas_planning.confirmed_need_batches add column proposal_whole_round_from numeric(20,6)
  check (proposal_whole_round_from >= 1);
comment on column atlas_planning.confirmed_need_batches.proposal_whole_round_from is
  'Immutable threshold applied after the Ingredient step ceiling. NULL preserves ceiling-only proposals.';

-- This is the only setting to replace in a forward migration when changing the cutoff.
create function atlas_core.new_need_whole_round_from() returns numeric
language sql immutable security invoker set search_path = '' as $$ select 2::numeric $$;
revoke all on function atlas_core.new_need_whole_round_from() from public, anon, authenticated, service_role;
grant execute on function atlas_core.new_need_whole_round_from() to atlas_planning_materialization_runtime;

create function atlas_core.planning_need_proposal(raw_quantity numeric, ingredient_step numeric,
  whole_round_from numeric, confirmation_step numeric default null)
returns numeric language plpgsql immutable security invoker set search_path = '' as $$
declare
  proposal numeric := pg_catalog.ceil(raw_quantity / ingredient_step) * ingredient_step;
begin
  if proposal >= whole_round_from then
    proposal := pg_catalog.round(proposal);
  end if;
  if pg_catalog.mod(proposal, confirmation_step) <> 0 then
    raise exception using errcode = 'PNR01', message = 'Proposal is incompatible with the confirmation step';
  end if;
  return proposal::numeric(20,6);
end $$;
revoke all on function atlas_core.planning_need_proposal(numeric,numeric,numeric,numeric)
  from public, anon, authenticated, service_role;
grant execute on function atlas_core.planning_need_proposal(numeric,numeric,numeric,numeric)
  to atlas_planning_materialization_runtime, atlas_confirmed_need_review_runtime;

create function atlas_planning.guard_need_rounding_threshold() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  raise exception using errcode = '23514', message = 'Confirmed Need proposal rounding threshold is immutable';
end $$;
revoke all on function atlas_planning.guard_need_rounding_threshold() from public, anon, authenticated, service_role;
create trigger confirmed_need_batches_guard_rounding_threshold
before update of proposal_whole_round_from on atlas_planning.confirmed_need_batches
for each row when (old.proposal_whole_round_from is distinct from new.proposal_whole_round_from)
execute function atlas_planning.guard_need_rounding_threshold();
reset role;

set role atlas_planning_materialization_runtime;
do $migration$
declare writer constant regprocedure := 'atlas_core.planning_contract_01_materialize_confirmed_needs(jsonb)';
begin
  perform pg_temp.patch_need_rounding(writer, '      current_need_generation_release_snapshot_id
    ) values', '      current_need_generation_release_snapshot_id,
      proposal_whole_round_from
    ) values');
  perform pg_temp.patch_need_rounding(writer, '      v_release.need_generation_release_snapshot_id
    ) returning confirmed_need_batch_id into v_batch_id;',
    '      v_release.need_generation_release_snapshot_id,
      atlas_core.new_need_whole_round_from()
    ) returning confirmed_need_batch_id, proposal_whole_round_from into v_batch_id, v_batch.proposal_whole_round_from;');
  perform pg_temp.patch_need_rounding(writer,
    'ingredient.version as proposal_rounding_ingredient_version',
    'ingredient.version as proposal_rounding_ingredient_version,
        min(policy_revision.planning_step) as confirmation_step', 2);
  perform pg_temp.patch_need_rounding(writer,
    'pg_catalog.ceil(
        sum(theoretical.theoretical_quantity)
          / proposal.proposal_rounding_step
      ) * proposal.proposal_rounding_step',
    'atlas_core.planning_need_proposal(sum(theoretical.theoretical_quantity),
        proposal.proposal_rounding_step, v_batch.proposal_whole_round_from, proposal.confirmation_step)');
  perform pg_temp.patch_need_rounding(writer, '             proposal.proposal_rounding_ingredient_version;',
    '             proposal.proposal_rounding_ingredient_version, proposal.confirmation_step;');
  perform pg_temp.patch_need_rounding(writer,
    'pg_catalog.ceil(
        grouped.theoretical_total / proposal.proposal_rounding_step
      ) * proposal.proposal_rounding_step',
    'atlas_core.planning_need_proposal(grouped.theoretical_total,
        proposal.proposal_rounding_step, v_batch.proposal_whole_round_from, proposal.confirmation_step)');
  perform pg_temp.patch_need_rounding(writer, 'exception
  when serialization_failure', $handler$exception
  when sqlstate 'PNR01' then
    return atlas_core.pa_05b_command_error(request, 'INGREDIENT_ROUNDING_STEP_INCOMPATIBLE',
      'The rounded proposal cannot be confirmed with the effective Planning step.', 'PLANNING', v_command_name);
  when serialization_failure$handler$);
end $migration$;
reset role;

set role atlas_confirmed_need_review_runtime;
select pg_temp.patch_need_rounding('atlas_core.rmvp_05_workbench_payload(uuid,jsonb,integer,integer)',
  'pg_catalog.ceil(
          revision.theoretical_quantity / revision.proposal_rounding_step
        ) * revision.proposal_rounding_step',
  'atlas_core.planning_need_proposal(revision.theoretical_quantity,
          revision.proposal_rounding_step, b.proposal_whole_round_from)');
select pg_temp.patch_need_rounding('atlas_core.rmvp_05_workbench_payload(uuid,jsonb,integer,integer)',
  '      end as proposed_confirmed_quantity,',
  '      end as proposed_confirmed_quantity,
      b.proposal_whole_round_from,');
select pg_temp.patch_need_rounding('atlas_core.rmvp_05_workbench_payload(uuid,jsonb,integer,integer)',
  $old$'proposal_rounding_step', line.proposal_rounding_step::text,$old$,
  $new$'proposal_rounding_step', line.proposal_rounding_step::text,
              'proposal_whole_round_from', line.proposal_whole_round_from::text,$new$);
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
