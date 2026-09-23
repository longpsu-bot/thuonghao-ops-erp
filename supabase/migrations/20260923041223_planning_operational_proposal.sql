-- PLANNING-OPERATIONAL-PROPOSAL-01
--
-- Keep raw theoretical totals exact while deriving each Draft Confirmed Need
-- proposal from the Ingredient operational rounding step. The effective H1A
-- policy remains the exact human confirmation quantum. The
-- repository already patches this materializer through guarded pg_get_functiondef
-- replacement, so this forward migration uses the same fail-fast convention.

reset role;
set role atlas_owner;

alter table atlas_planning.confirmed_need_line_revisions
  add column proposal_rounding_step numeric(20,6),
  add column proposal_rounding_ingredient_version bigint,
  add constraint confirmed_need_revision_proposal_rounding_pair_ck check (
    (proposal_rounding_step is null and proposal_rounding_ingredient_version is null)
    or
    (proposal_rounding_step is not null and proposal_rounding_ingredient_version is not null)
  ),
  add constraint confirmed_need_revision_proposal_rounding_step_ck check (
    proposal_rounding_step is null or proposal_rounding_step > 0
  ),
  add constraint confirmed_need_revision_proposal_rounding_version_ck check (
    proposal_rounding_ingredient_version is null
    or proposal_rounding_ingredient_version > 0
  );

comment on column atlas_planning.confirmed_need_line_revisions.proposal_rounding_step is
  'Exact Ingredient.order_step used to derive this NEED_GENERATION proposal; null only for legacy revisions.';
comment on column atlas_planning.confirmed_need_line_revisions.proposal_rounding_ingredient_version is
  'Ingredient version paired with proposal_rounding_step; null only for legacy revisions.';

reset role;
grant atlas_planning_materialization_runtime,
  atlas_confirmed_need_review_runtime,
  atlas_read_runtime to postgres with set true;
set role atlas_owner;
grant create on schema atlas_core to atlas_planning_materialization_runtime;
grant create on schema atlas_core to atlas_confirmed_need_review_runtime;
grant create on schema atlas_api to atlas_read_runtime;
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
  v_invalid_rounding_config_count integer := 0;
  v_missing_policy_count integer := 0;
  v_ambiguous_policy_count integer := 0;
  v_incompatible_rounding_step_count integer := 0;
$new$);
  if v_definition = v_before then
    raise exception 'Planning proposal variable patch made no change';
  end if;

  v_before := v_definition;
  v_definition := pg_catalog.replace(v_definition,
$old$  if (v_run.period_end - v_run.period_start + 1) > 14
$old$,
$new$  -- Resolve Ingredient rounding configuration and the human confirmation
  -- policy once, set-wise, for every released operational identity. All
  -- configuration failures occur before any Confirmed Need row is written.
  with policy_keys as (
    select distinct theoretical.service_date, theoretical.ingredient_id,
           theoretical.unit_id
    from atlas_planning.need_generation_release_snapshot_lines release_line
    join atlas_planning.theoretical_need_lines theoretical
      on theoretical.theoretical_need_line_id = release_line.theoretical_need_line_id
    where release_line.need_generation_release_snapshot_id =
        v_release.need_generation_release_snapshot_id
      and theoretical.line_disposition = 'ACTIVE'
  ), proposal_resolution as (
    select policy_key.service_date, policy_key.ingredient_id, policy_key.unit_id,
           ingredient.ingredient_id as resolved_ingredient_id,
           ingredient.purchase_unit_id,
           ingredient.order_step,
           ingredient.version as ingredient_version,
           count(policy_revision.planning_quantity_policy_revision_id)::integer
             as policy_count,
           min(policy_revision.planning_step) as planning_step
    from policy_keys policy_key
    left join atlas_admin.ingredients ingredient
      on ingredient.ingredient_id = policy_key.ingredient_id
     and ingredient.ingredient_status = 'ACTIVE'
    left join atlas_planning.planning_quantity_policy_revisions policy_revision
      on policy_revision.unit_id = policy_key.unit_id
     and policy_revision.policy_revision_status in ('ACTIVE', 'RETIRED')
     and policy_revision.effective_from <= policy_key.service_date
     and (
       policy_revision.effective_to is null
       or policy_key.service_date < policy_revision.effective_to
     )
    group by policy_key.service_date, policy_key.ingredient_id,
             policy_key.unit_id, ingredient.ingredient_id,
             ingredient.purchase_unit_id, ingredient.order_step,
             ingredient.version
  )
  select
    count(*) filter (
      where resolved_ingredient_id is null
         or purchase_unit_id is distinct from unit_id
         or order_step is null
         or order_step <= 0
         or ingredient_version is null
         or ingredient_version <= 0
    )::integer,
    count(*) filter (where policy_count = 0)::integer,
    count(*) filter (where policy_count > 1)::integer,
    count(*) filter (
      where resolved_ingredient_id is not null
        and purchase_unit_id = unit_id
        and order_step > 0
        and ingredient_version > 0
        and policy_count = 1
        and pg_catalog.mod(order_step, planning_step) <> 0
    )::integer
  into v_invalid_rounding_config_count, v_missing_policy_count,
       v_ambiguous_policy_count, v_incompatible_rounding_step_count
  from proposal_resolution;

  if v_invalid_rounding_config_count > 0 then
    v_error := atlas_core.pa_05b_command_error(
      request, 'INGREDIENT_ROUNDING_CONFIGURATION_INVALID',
      'Every Ingredient requires a positive rounding step in its exact controlled Unit.',
      'PLANNING', v_command_name
    );
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

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
  if v_incompatible_rounding_step_count > 0 then
    v_error := atlas_core.pa_05b_command_error(
      request, 'INGREDIENT_ROUNDING_STEP_INCOMPATIBLE',
      'The Ingredient rounding step is not an exact positive integer multiple of the human confirmation step.',
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
$new$    with proposal_resolution as (
      select
        target_line.confirmed_need_line_id,
        ingredient.order_step as proposal_rounding_step,
        ingredient.version as proposal_rounding_ingredient_version
      from atlas_planning.confirmed_need_lines target_line
      join atlas_admin.ingredients ingredient
        on ingredient.ingredient_id = target_line.ingredient_id
       and ingredient.ingredient_status = 'ACTIVE'
       and ingredient.purchase_unit_id = target_line.controlled_unit_id
       and ingredient.order_step > 0
       and ingredient.version > 0
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
      group by target_line.confirmed_need_line_id, ingredient.order_step,
               ingredient.version
      having count(policy_revision.planning_quantity_policy_revision_id) = 1
         and pg_catalog.mod(
           ingredient.order_step, min(policy_revision.planning_step)
         ) = 0
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
        sum(theoretical.theoretical_quantity)
          / proposal.proposal_rounding_step
      ) * proposal.proposal_rounding_step,
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
    join proposal_resolution proposal
      on proposal.confirmed_need_line_id = target_line.confirmed_need_line_id
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
             target_line.delivery_location_id,
             proposal.proposal_rounding_step,
             proposal.proposal_rounding_ingredient_version;
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
        grouped.theoretical_total / proposal.proposal_rounding_step
      ) * proposal.proposal_rounding_step,
$new$);
  if v_definition = v_before then
    raise exception 'Planning proposal correction quantity patch made no change';
  end if;

  v_before := v_definition;
  v_definition := pg_catalog.replace(v_definition,
$old$      confirmed_quantity,
      unit_id,
$old$,
$new$      confirmed_quantity,
      proposal_rounding_step,
      proposal_rounding_ingredient_version,
      unit_id,
$new$);
  if v_definition = v_before then
    raise exception 'Planning proposal snapshot-column patch made no change';
  end if;

  v_before := v_definition;
  v_definition := pg_catalog.replace(v_definition,
$old$      ) * proposal.proposal_rounding_step,
      target_line.controlled_unit_id,
$old$,
$new$      ) * proposal.proposal_rounding_step,
      proposal.proposal_rounding_step,
      proposal.proposal_rounding_ingredient_version,
      target_line.controlled_unit_id,
$new$);
  if v_definition = v_before then
    raise exception 'Planning proposal snapshot-value patch made no change';
  end if;

  v_before := v_definition;
  v_definition := pg_catalog.replace(v_definition,
$old$     and target_line.controlled_unit_id = grouped.unit_id
    left join lateral (
$old$,
$new$     and target_line.controlled_unit_id = grouped.unit_id
    join proposal_resolution proposal
      on proposal.confirmed_need_line_id = target_line.confirmed_need_line_id
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
  'Private CMD-15 materializer. Preserves exact raw grouped theoretical quantities, derives Draft proposals set-wise from Ingredient.order_step, and retains H1A as the exact human confirmation quantum.';

reset role;
set role atlas_confirmed_need_review_runtime;

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
    and p.proname = 'rmvp_05_workbench_payload'
    and pg_catalog.pg_get_function_identity_arguments(p.oid) =
      'batch_id uuid, filters jsonb, line_offset integer, line_limit integer';

  if pg_catalog.md5((select p.prosrc from pg_catalog.pg_proc p where p.oid = v_oid))
      <> '8b6d2cf82efc618e440d12bd062dd356'
  then
    raise exception 'Unexpected Confirmed Need workbench baseline';
  end if;

  v_before := v_definition;
  v_definition := pg_catalog.replace(v_definition,
$old$      revision.confirmed_quantity as proposed_confirmed_quantity,
      revision.need_generation_run_id,
$old$,
$new$      revision.confirmed_quantity as proposed_confirmed_quantity,
      revision.proposal_rounding_step,
      revision.need_generation_run_id,
$new$);
  if v_definition = v_before then
    raise exception 'Confirmed Need proposal snapshot select patch made no change';
  end if;

  v_before := v_definition;
  v_definition := pg_catalog.replace(v_definition,
$old$              'proposed_confirmed_quantity', line.proposed_confirmed_quantity::text,
              'current_decision_id', line.confirmed_need_line_decision_id,
$old$,
$new$              'proposed_confirmed_quantity', line.proposed_confirmed_quantity::text,
              'proposal_rounding_step', line.proposal_rounding_step::text,
              'current_decision_id', line.confirmed_need_line_decision_id,
$new$);
  if v_definition = v_before then
    raise exception 'Confirmed Need proposal snapshot JSON patch made no change';
  end if;

  execute v_definition;
end;
$$;

reset role;
set role atlas_read_runtime;

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
  where n.nspname = 'atlas_api'
    and p.proname = 'get_ingredient_supplier_master_data'
    and pg_catalog.pg_get_function_identity_arguments(p.oid) = 'request jsonb';

  if pg_catalog.md5((select p.prosrc from pg_catalog.pg_proc p where p.oid = v_oid))
      <> '0c0cc7b3ef66cb487d19906601cf02ef'
  then
    raise exception 'Unexpected Ingredient master-data read baseline';
  end if;

  v_before := v_definition;
  v_definition := pg_catalog.replace(v_definition,
$old$        'unit_code', u.unit_code,
        'unit_name', u.unit_name,
        'unit_status', u.unit_status
$old$,
$new$        'unit_code', u.unit_code,
        'unit_name', u.unit_name,
        'unit_status', u.unit_status,
        'dimension_code', u.dimension_code
$new$);
  if v_definition = v_before then
    raise exception 'Ingredient master-data Unit dimension patch made no change';
  end if;

  execute v_definition;
end;
$$;

reset role;
set role atlas_owner;
revoke create on schema atlas_core from atlas_planning_materialization_runtime;
revoke create on schema atlas_core from atlas_confirmed_need_review_runtime;
revoke create on schema atlas_api from atlas_read_runtime;
reset role;
revoke atlas_planning_materialization_runtime,
  atlas_confirmed_need_review_runtime,
  atlas_read_runtime from postgres;
