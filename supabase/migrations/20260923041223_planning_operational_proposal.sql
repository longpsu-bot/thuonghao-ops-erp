-- PLANNING-OPERATIONAL-PROPOSAL-01
--
-- Keep raw theoretical totals exact while deriving each Draft Confirmed Need
-- proposal from the one effective exact-Unit Planning quantity policy. The
-- repository already patches this materializer through guarded pg_get_functiondef
-- replacement, so this forward migration uses the same fail-fast convention.

reset role;
grant atlas_planning_materialization_runtime to postgres with set true;
set role atlas_owner;
grant create on schema atlas_core to atlas_planning_materialization_runtime;
set role atlas_planning_materialization_runtime;

do $$
declare
  v_oid oid;
  v_definition text;
  v_before text;
begin
  select p.oid, pg_catalog.pg_get_functiondef(p.oid)
  into strict v_oid, v_definition
  from pg_catalog.pg_proc p
  join pg_catalog.pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'atlas_core'
    and p.proname = 'planning_contract_01_materialize_confirmed_needs'
    and pg_catalog.pg_get_function_identity_arguments(p.oid) = 'request jsonb';

  if pg_catalog.md5((select p.prosrc from pg_catalog.pg_proc p where p.oid = v_oid))
      <> '2210cbdfab17d68315643ec4fd794267'
  then
    raise exception 'Unexpected Planning materializer baseline';
  end if;

  v_before := v_definition;
  v_definition := pg_catalog.replace(v_definition,
$old$  v_group_count integer := 0;
$old$,
$new$  v_group_count integer := 0;
  v_missing_policy_count integer := 0;
  v_ambiguous_policy_count integer := 0;
$new$);
  if v_definition = v_before then
    raise exception 'Planning proposal variable patch made no change';
  end if;

  v_before := v_definition;
  v_definition := pg_catalog.replace(v_definition,
$old$  if (v_run.period_end - v_run.period_start + 1) > 14
$old$,
$new$  -- Resolve policy once, set-wise, for every exact Unit/service-date key
  -- represented by the already-grouped operational identities. Missing and
  -- ambiguous effectivity fail before any Confirmed Need row is written.
  with policy_keys as (
    select distinct theoretical.service_date, theoretical.unit_id
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    where release_line.need_generation_release_snapshot_id =
        v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
  ), policy_resolution as (
    select policy_key.service_date, policy_key.unit_id,
           count(policy_revision.planning_quantity_policy_revision_id)::integer
             as policy_count
    from policy_keys policy_key
    left join atlas_planning.planning_quantity_policy_revisions policy_revision
      on policy_revision.unit_id = policy_key.unit_id
     and policy_revision.policy_revision_status in ('ACTIVE', 'RETIRED')
     and policy_revision.effective_from <= policy_key.service_date
     and (
       policy_revision.effective_to is null
       or policy_key.service_date < policy_revision.effective_to
     )
    group by policy_key.service_date, policy_key.unit_id
  )
  select
    count(*) filter (where policy_count = 0)::integer,
    count(*) filter (where policy_count > 1)::integer
  into v_missing_policy_count, v_ambiguous_policy_count
  from policy_resolution;

  if v_missing_policy_count > 0 then
    v_error := atlas_core.pa_05b_command_error(
      request, 'MISSING_PLANNING_QUANTITY_POLICY',
      'No eligible exact-Unit Planning quantity policy exists for the service date.',
      'PLANNING', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if v_ambiguous_policy_count > 0 then
    v_error := atlas_core.pa_05b_command_error(
      request, 'AMBIGUOUS_PLANNING_QUANTITY_POLICY',
      'More than one eligible exact-Unit Planning quantity policy exists for the service date.',
      'PLANNING', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  if (v_run.period_end - v_run.period_start + 1) > 14
$new$);
  if v_definition = v_before then
    raise exception 'Planning proposal policy-validation patch made no change';
  end if;

  v_before := v_definition;
  v_definition := pg_catalog.replace(v_definition,
$old$    insert into atlas_planning.confirmed_need_line_revisions (
$old$,
$new$    with policy_resolution as (
      select
        target_line.confirmed_need_line_id,
        min(policy_revision.planning_step) as planning_step
      from atlas_planning.confirmed_need_lines target_line
      join atlas_planning.planning_quantity_policy_revisions policy_revision
        on policy_revision.unit_id = target_line.controlled_unit_id
       and policy_revision.policy_revision_status in ('ACTIVE', 'RETIRED')
       and policy_revision.effective_from <= target_line.service_date
       and (
         policy_revision.effective_to is null
         or target_line.service_date < policy_revision.effective_to
       )
      where target_line.confirmed_need_batch_id = v_batch_id
        and target_line.source_kind = 'NEED_GENERATION'
      group by target_line.confirmed_need_line_id
      having count(policy_revision.planning_quantity_policy_revision_id) = 1
    )
    insert into atlas_planning.confirmed_need_line_revisions (
$new$);
  if v_definition = v_before then
    raise exception 'Planning proposal set-wise policy binding patch made no change';
  end if;

  v_before := v_definition;
  v_definition := pg_catalog.replace(v_definition,
$old$      sum(theoretical.theoretical_quantity),
      sum(theoretical.theoretical_quantity),
$old$,
$new$      sum(theoretical.theoretical_quantity),
      pg_catalog.ceil(
        sum(theoretical.theoretical_quantity) / policy.planning_step
      ) * policy.planning_step,
$new$);
  if v_definition = v_before then
    raise exception 'Planning proposal initial quantity patch made no change';
  end if;

  v_before := v_definition;
  v_definition := pg_catalog.replace(v_definition,
$old$    from atlas_planning.confirmed_need_lines target_line
    join atlas_planning.need_generation_release_snapshot_lines release_line
$old$,
$new$    from atlas_planning.confirmed_need_lines target_line
    join policy_resolution policy
      on policy.confirmed_need_line_id = target_line.confirmed_need_line_id
    join atlas_planning.need_generation_release_snapshot_lines release_line
$new$);
  if v_definition = v_before then
    raise exception 'Planning proposal initial policy join patch made no change';
  end if;

  v_before := v_definition;
  v_definition := pg_catalog.replace(v_definition,
$old$             target_line.customer_id, target_line.school_id, target_line.delivery_location_id;
    get diagnostics v_created_revision_count = row_count;
$old$,
$new$             target_line.customer_id, target_line.school_id,
             target_line.delivery_location_id, policy.planning_step;
    get diagnostics v_created_revision_count = row_count;
    if v_created_revision_count <> v_group_count then
      raise exception 'Planning policy resolution changed during materialization';
    end if;
$new$);
  if v_definition = v_before then
    raise exception 'Planning proposal initial cardinality patch made no change';
  end if;

  v_before := v_definition;
  v_definition := pg_catalog.replace(v_definition,
$old$      grouped.theoretical_total,
      grouped.theoretical_total,
$old$,
$new$      grouped.theoretical_total,
      pg_catalog.ceil(
        grouped.theoretical_total / policy.planning_step
      ) * policy.planning_step,
$new$);
  if v_definition = v_before then
    raise exception 'Planning proposal correction quantity patch made no change';
  end if;

  v_before := v_definition;
  v_definition := pg_catalog.replace(v_definition,
$old$     and target_line.controlled_unit_id = grouped.unit_id
    left join lateral (
$old$,
$new$     and target_line.controlled_unit_id = grouped.unit_id
    join policy_resolution policy
      on policy.confirmed_need_line_id = target_line.confirmed_need_line_id
    left join lateral (
$new$);
  if v_definition = v_before then
    raise exception 'Planning proposal correction policy join patch made no change';
  end if;

  v_before := v_definition;
  v_definition := pg_catalog.replace(v_definition,
$old$    ) prior_revision on true;
    get diagnostics v_created_revision_count = row_count;
$old$,
$new$    ) prior_revision on true;
    get diagnostics v_created_revision_count = row_count;
    if v_created_revision_count <> v_group_count then
      raise exception 'Planning policy resolution changed during rematerialization';
    end if;
$new$);
  if v_definition = v_before then
    raise exception 'Planning proposal correction cardinality patch made no change';
  end if;

  execute v_definition;
end;
$$;

comment on function atlas_core.planning_contract_01_materialize_confirmed_needs(jsonb) is
  'Private CMD-15 materializer. Preserves exact raw grouped theoretical quantities and derives Draft proposals set-wise from the one effective exact-Unit Planning quantity policy.';

reset role;
set role atlas_owner;
revoke create on schema atlas_core from atlas_planning_materialization_runtime;
reset role;
revoke atlas_planning_materialization_runtime from postgres;
