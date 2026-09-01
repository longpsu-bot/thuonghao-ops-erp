-- PR #242: connected Planning/Procurement contract hardening.
--
-- D-042 retains an invalidated school-catering Purchase Handoff root so a
-- corrected Planning release can reuse it. The v2 eligibility and command
-- predicates below count only active Handoffs as release conflicts while
-- preserving unchanged historical-row visibility for correction and audit.

-- PostgreSQL numeric values must cross the JSON/browser boundary as strings.
-- The existing read implementations and all internal fingerprints continue to
-- use exact numeric values; only the two public response envelopes are shaped.
grant atlas_read_runtime to postgres with set true;
grant create on schema atlas_core, atlas_api to atlas_read_runtime;
set role atlas_read_runtime;

create function atlas_core.procurement_read_exact_numbers_as_strings(payload jsonb)
returns jsonb
language plpgsql
immutable
security invoker
set search_path = ''
as $$
declare
  result jsonb;
  entry record;
begin
  if payload is null then
    return null;
  end if;

  if pg_catalog.jsonb_typeof(payload) = 'object' then
    result := '{}'::jsonb;
    for entry in
      select object_entry.key, object_entry.value
      from pg_catalog.jsonb_each(payload) object_entry
    loop
      result := result || pg_catalog.jsonb_build_object(
        entry.key,
        case
          when entry.key = 'split_ratio'
            and pg_catalog.jsonb_typeof(entry.value) = 'number'
            then pg_catalog.to_jsonb(
              ((entry.value #>> '{}')::numeric(20, 12))::text
            )
          when entry.key in (
            'family_quantity',
            'contribution_quantity',
            'allocated_quantity',
            'ordered_quantity'
          ) and pg_catalog.jsonb_typeof(entry.value) = 'number'
            then pg_catalog.to_jsonb(
              ((entry.value #>> '{}')::numeric(20, 6))::text
            )
          else atlas_core.procurement_read_exact_numbers_as_strings(entry.value)
        end
      );
    end loop;
    return result;
  end if;

  if pg_catalog.jsonb_typeof(payload) = 'array' then
    select coalesce(
      pg_catalog.jsonb_agg(
        atlas_core.procurement_read_exact_numbers_as_strings(item.value)
        order by item.ordinality
      ),
      '[]'::jsonb
    )
    into result
    from pg_catalog.jsonb_array_elements(payload) with ordinality as item(value, ordinality);
    return result;
  end if;

  return payload;
end;
$$;

revoke execute on function atlas_core.procurement_read_exact_numbers_as_strings(jsonb)
  from public, anon, authenticated, service_role;

alter function atlas_api.get_school_catering_procurement_workbench(jsonb)
  rename to get_school_catering_procurement_workbench_numeric_compat;
alter function atlas_api.get_school_catering_procurement_workbench_numeric_compat(jsonb)
  set schema atlas_core;
revoke execute on function
  atlas_core.get_school_catering_procurement_workbench_numeric_compat(jsonb)
  from public, anon, authenticated, service_role;

create function atlas_api.get_school_catering_procurement_workbench(request jsonb)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select atlas_core.procurement_read_exact_numbers_as_strings(
    atlas_core.get_school_catering_procurement_workbench_numeric_compat(request)
  );
$$;
revoke execute on function atlas_api.get_school_catering_procurement_workbench(jsonb)
  from public, anon, service_role;
grant execute on function atlas_api.get_school_catering_procurement_workbench(jsonb)
  to authenticated;

alter function atlas_api.get_school_catering_purchase_orders(jsonb)
  rename to get_school_catering_purchase_orders_numeric_compat;
alter function atlas_api.get_school_catering_purchase_orders_numeric_compat(jsonb)
  set schema atlas_core;
revoke execute on function atlas_core.get_school_catering_purchase_orders_numeric_compat(jsonb)
  from public, anon, authenticated, service_role;

create function atlas_api.get_school_catering_purchase_orders(request jsonb)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select atlas_core.procurement_read_exact_numbers_as_strings(
    atlas_core.get_school_catering_purchase_orders_numeric_compat(request)
  );
$$;
revoke execute on function atlas_api.get_school_catering_purchase_orders(jsonb)
  from public, anon, service_role;
grant execute on function atlas_api.get_school_catering_purchase_orders(jsonb)
  to authenticated;

reset role;
revoke create on schema atlas_core, atlas_api from atlas_read_runtime;
grant atlas_read_runtime to postgres with set false;

-- The affected v2 functions are owned by the bounded Confirmed Need runtime.
grant atlas_confirmed_need_review_runtime to postgres with set true;
grant create on schema atlas_core, atlas_api to atlas_confirmed_need_review_runtime;
set role atlas_confirmed_need_review_runtime;

create or replace function atlas_core.d037_extend_workbench(
  p_workbench jsonb,
  p_actor_id uuid
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_batch_id uuid := atlas_core.pa_05b_safe_uuid(
    p_workbench ->> 'confirmed_need_batch_id'
  );
  v_batch atlas_planning.confirmed_need_batches%rowtype;
  v_has_save_capability boolean := false;
  v_has_release_capability boolean := false;
  v_handoff_exists boolean := false;
  v_release_evaluation jsonb;
  v_save_code text;
  v_release_code text;
  v_save_message text;
  v_release_message text;
begin
  p_workbench := atlas_core.planning_contract_02b_extend_workbench(p_workbench);

  select batch.* into strict v_batch
  from atlas_planning.confirmed_need_batches batch
  where batch.confirmed_need_batch_id = v_batch_id;

  select exists (
    select 1
    from atlas_core.actor_role_memberships membership
    join atlas_core.roles role_record
      on role_record.role_id = membership.role_id
    join atlas_core.role_capabilities role_capability
      on role_capability.role_id = role_record.role_id
    join atlas_core.capabilities capability
      on capability.capability_id = role_capability.capability_id
    where membership.actor_id = p_actor_id
      and membership.membership_status = 'ACTIVE'
      and membership.effective_from <= pg_catalog.transaction_timestamp()
      and (membership.effective_to is null
        or membership.effective_to > pg_catalog.transaction_timestamp())
      and role_record.role_status = 'ACTIVE'
      and capability.capability_status = 'ACTIVE'
      and capability.capability_code = 'confirmed_need_quantities.confirm'
  ) and exists (
    select 1 from atlas_core.actor_scopes scope
    where scope.actor_id = p_actor_id
      and scope.scope_status = 'ACTIVE'
      and scope.scope_kind = 'GLOBAL'
      and scope.effective_from <= pg_catalog.transaction_timestamp()
      and (scope.effective_to is null
        or scope.effective_to > pg_catalog.transaction_timestamp())
  ) into v_has_save_capability;

  select exists (
    select 1
    from atlas_core.actor_role_memberships membership
    join atlas_core.roles role_record
      on role_record.role_id = membership.role_id
    join atlas_core.role_capabilities role_capability
      on role_capability.role_id = role_record.role_id
    join atlas_core.capabilities capability
      on capability.capability_id = role_capability.capability_id
    where membership.actor_id = p_actor_id
      and membership.membership_status = 'ACTIVE'
      and membership.effective_from <= pg_catalog.transaction_timestamp()
      and (membership.effective_to is null
        or membership.effective_to > pg_catalog.transaction_timestamp())
      and role_record.role_status = 'ACTIVE'
      and capability.capability_status = 'ACTIVE'
      and capability.capability_code = 'confirmed_need_release.release'
  ) and exists (
    select 1 from atlas_core.actor_scopes scope
    where scope.actor_id = p_actor_id
      and scope.scope_status = 'ACTIVE'
      and scope.scope_kind = 'GLOBAL'
      and scope.effective_from <= pg_catalog.transaction_timestamp()
      and (scope.effective_to is null
        or scope.effective_to > pg_catalog.transaction_timestamp())
  ) into v_has_release_capability;

  select exists (
    select 1 from atlas_planning.purchase_handoff_batches handoff
    where handoff.confirmed_need_batch_id = v_batch_id
      and handoff.handoff_status not in ('INVALIDATED', 'REOPENED')
  ) into v_handoff_exists;

  if v_batch.source_kind = 'NEED_GENERATION'
    and v_batch.batch_status in ('DRAFT_REVIEW', 'REOPENED')
  then
    begin
      v_release_evaluation := atlas_core.rmvp_06_canonical_evaluation(v_batch_id);
    exception when others then
      v_release_evaluation := null;
    end;
  end if;

  v_save_code := case
    when v_batch.source_kind <> 'NEED_GENERATION'
      then 'SAVE_UNSUPPORTED_SOURCE_KIND'
    when v_batch.batch_status not in ('DRAFT_REVIEW', 'REOPENED')
      then 'SAVE_BATCH_NOT_EDITABLE'
    when not v_has_save_capability then 'SAVE_CAPABILITY_REQUIRED'
    else null
  end;
  v_save_message := case v_save_code
    when 'SAVE_UNSUPPORTED_SOURCE_KIND'
      then 'Dá»¯ liá»‡u nÃ y khÃ´ng há»— trá»£ thao tÃ¡c lÆ°u.'
    when 'SAVE_BATCH_NOT_EDITABLE'
      then 'Dá»¯ liá»‡u nÃ y khÃ´ng cÃ²n cho phÃ©p chá»‰nh sá»­a.'
    when 'SAVE_CAPABILITY_REQUIRED'
      then 'Báº¡n chÆ°a cÃ³ quyá»n lÆ°u thay Ä‘á»•i nÃ y.'
    else null
  end;

  v_release_code := case
    when v_batch.source_kind <> 'NEED_GENERATION'
      then 'RELEASE_UNSUPPORTED_SOURCE_KIND'
    when v_batch.batch_status = 'RELEASED_FOR_PURCHASE_HANDOFF'
      then 'RELEASE_ALREADY_COMPLETED'
    when v_batch.batch_status not in ('DRAFT_REVIEW', 'REOPENED')
      then 'RELEASE_BATCH_NOT_EDITABLE'
    when not v_has_release_capability then 'RELEASE_CAPABILITY_REQUIRED'
    when v_handoff_exists then 'RELEASE_PURCHASE_HANDOFF_CONFLICT'
    when v_release_evaluation is null
      or v_release_evaluation ->> 'outcome' <> 'VALIDATED'
      then 'RELEASE_INCOMPLETE'
    else null
  end;
  v_release_message := case v_release_code
    when 'RELEASE_UNSUPPORTED_SOURCE_KIND'
      then 'Dá»¯ liá»‡u nÃ y khÃ´ng há»— trá»£ bÆ°á»›c chuyá»ƒn sang lÃªn Ä‘Æ¡n.'
    when 'RELEASE_ALREADY_COMPLETED'
      then 'Dá»¯ liá»‡u Ä‘Ã£ Ä‘Æ°á»£c chuyá»ƒn sang lÃªn Ä‘Æ¡n.'
    when 'RELEASE_BATCH_NOT_EDITABLE'
      then 'Dá»¯ liá»‡u hiá»‡n táº¡i chÆ°a thá»ƒ chuyá»ƒn sang lÃªn Ä‘Æ¡n.'
    when 'RELEASE_CAPABILITY_REQUIRED'
      then 'Báº¡n chÆ°a cÃ³ quyá»n thá»±c hiá»‡n bÆ°á»›c nÃ y.'
    when 'RELEASE_PURCHASE_HANDOFF_CONFLICT'
      then 'Dá»¯ liá»‡u Ä‘Ã£ Ä‘Æ°á»£c chuyá»ƒn sang bÆ°á»›c mua hÃ ng.'
    when 'RELEASE_INCOMPLETE'
      then 'CÃ²n dÃ²ng cáº§n xá»­ lÃ½ trÆ°á»›c khi chuyá»ƒn sang lÃªn Ä‘Æ¡n.'
    else null
  end;

  return p_workbench || pg_catalog.jsonb_build_object(
    'allowed_actions', (p_workbench -> 'allowed_actions')
      || pg_catalog.jsonb_build_object(
        'save_confirmed_needs', v_save_code is null,
        'release_confirmed_needs', v_release_code is null
      ),
    'disabled_reason_codes', (p_workbench -> 'disabled_reason_codes')
      || pg_catalog.jsonb_build_object(
        'save_confirmed_needs', v_save_code,
        'release_confirmed_needs', v_release_code
      ),
    'disabled_reasons', (p_workbench -> 'disabled_reasons')
      || pg_catalog.jsonb_build_object(
        'save_confirmed_needs', v_save_message,
        'release_confirmed_needs', v_release_message
      )
  );
end;
$$;

create or replace function atlas_api.release_confirmed_needs(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'release_confirmed_needs';
  v_error jsonb;
  v_context jsonb;
  v_actor_id uuid;
  v_begin jsonb;
  v_receipt_id uuid;
  v_batch_id uuid := atlas_core.pa_05b_safe_uuid(
    request #>> '{payload,confirmed_need_batch_id}');
  v_batch atlas_planning.confirmed_need_batches%rowtype;
  v_prelock_evaluation jsonb;
  v_evaluation jsonb;
  v_attempt_id uuid := gen_random_uuid();
  v_attempt_number bigint;
  v_item jsonb;
  v_validation_line_id uuid;
  v_validated_version bigint;
  v_approved_version bigint;
  v_released_version bigint;
  v_snapshot_id uuid := gen_random_uuid();
  v_release_id uuid := gen_random_uuid();
  v_projection jsonb;
  v_fingerprint text;
  v_line_count integer;
  v_events jsonb;
  v_validation_events jsonb;
  v_approval_events jsonb;
  v_response jsonb;
begin
  v_error := atlas_core.d037_validate_command(request, v_name);
  if v_error is not null then return v_error; end if;
  v_context := atlas_core.rmvp_07_authorize(request, v_name,
    'confirmed_need_release.release');
  if v_context ? 'error' then return v_context -> 'error'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_context ->> 'actor_id');
  v_begin := atlas_core.pa_05b_begin_command(request, v_actor_id, v_name,
    'PLANNING', 'ConfirmedNeedBatch:' || v_batch_id::text);
  if v_begin ->> 'status' <> 'NEW' then return v_begin -> 'response'; end if;
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_begin ->> 'receipt_id');

  select * into v_batch from atlas_planning.confirmed_need_batches batch
  where batch.confirmed_need_batch_id = v_batch_id for update;
  if not found then
    v_error := atlas_core.d037_error(request, 'RMVP-07.v2', v_name,
      'CONFIRMED_NEED_BATCH_NOT_FOUND', 'The Confirmed Need batch was not found.');
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if v_batch.source_kind <> 'NEED_GENERATION'
    or v_batch.batch_status not in ('DRAFT_REVIEW', 'REOPENED')
  then
    v_error := atlas_core.d037_error(request, 'RMVP-07.v2', v_name,
      'CONFIRMED_NEED_NOT_RELEASABLE',
      'Only a current saved Confirmed Need can be moved to ordering.', false,
      v_batch.version);
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if v_batch.version <> atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') then
    v_error := atlas_core.d037_error(request, 'RMVP-07.v2', v_name,
      'STALE_CONFIRMED_NEED_BATCH', 'The data changed. Refresh before continuing.',
      false, v_batch.version);
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;
  if exists (select 1 from atlas_planning.purchase_handoff_batches handoff
    where handoff.confirmed_need_batch_id = v_batch_id
      and handoff.handoff_status not in ('INVALIDATED', 'REOPENED'))
  then
    v_error := atlas_core.d037_error(request, 'RMVP-07.v2', v_name,
      'PURCHASE_HANDOFF_CONFLICT',
      'A Purchase Handoff already exists for this result.', false,
      v_batch.version);
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  perform line.confirmed_need_line_id
  from atlas_planning.confirmed_need_lines line
  where line.confirmed_need_batch_id = v_batch_id
  order by line.confirmed_need_line_id for update;
  v_prelock_evaluation := atlas_core.rmvp_06_canonical_evaluation(v_batch_id);

  perform unit.unit_id from atlas_admin.units unit
  where unit.unit_id in (select line.controlled_unit_id
    from atlas_planning.confirmed_need_lines line
    where line.confirmed_need_batch_id = v_batch_id)
  order by unit.unit_id for share;
  perform policy.planning_quantity_policy_id
  from atlas_planning.planning_quantity_policies policy
  where policy.planning_quantity_policy_id in (
    select decision.planning_quantity_policy_id
    from atlas_planning.confirmed_need_line_decisions decision
    where decision.confirmed_need_batch_id = v_batch_id)
  order by policy.planning_quantity_policy_id for share;
  perform policy_revision.planning_quantity_policy_revision_id
  from atlas_planning.planning_quantity_policy_revisions policy_revision
  where policy_revision.planning_quantity_policy_revision_id in (
    select decision.planning_quantity_policy_revision_id
    from atlas_planning.confirmed_need_line_decisions decision
    where decision.confirmed_need_batch_id = v_batch_id)
  order by policy_revision.planning_quantity_policy_revision_id for share;
  perform run.need_generation_run_id
  from atlas_planning.need_generation_runs run
  where run.need_generation_run_id = v_batch.current_need_generation_run_id
  for share;
  perform source_release.need_generation_release_snapshot_id
  from atlas_planning.need_generation_release_snapshots source_release
  where source_release.need_generation_release_snapshot_id
    = v_batch.current_need_generation_release_snapshot_id for share;
  perform member.need_generation_release_snapshot_line_id
  from atlas_planning.need_generation_release_snapshot_lines member
  where member.need_generation_release_snapshot_id
    = v_batch.current_need_generation_release_snapshot_id
  order by member.need_generation_release_snapshot_line_id for share;

  v_evaluation := atlas_core.rmvp_06_canonical_evaluation(v_batch_id,
    v_prelock_evaluation ->> 'validation_fingerprint');
  if v_evaluation ->> 'outcome' <> 'VALIDATED' then
    v_error := atlas_core.d037_error(request, 'RMVP-07.v2', v_name,
      'CONFIRMED_NEED_INCOMPLETE',
      'Complete and save every required decision before moving to ordering.',
      false, v_batch.version) || pg_catalog.jsonb_build_object(
        'blockers', v_evaluation -> 'ordered_issues');
    return atlas_core.pa_05b_finish_command(v_receipt_id, v_error, false);
  end if;

  v_validated_version := v_batch.version + 1;
  v_approved_version := v_batch.version + 2;
  v_released_version := v_batch.version + 3;
  select coalesce(max(attempt.attempt_number), 0) + 1 into v_attempt_number
  from atlas_planning.confirmed_need_validation_attempts attempt
  where attempt.confirmed_need_batch_id = v_batch_id;

  insert into atlas_planning.confirmed_need_validation_attempts (
    confirmed_need_validation_attempt_id, confirmed_need_batch_id,
    attempt_number, source_kind, evaluated_batch_version,
    resulting_batch_version, prior_batch_status, resulting_batch_status,
    outcome, line_count, blocking_issue_count, warning_count,
    validation_fingerprint, evaluated_by_actor_id, evaluated_at, command_id,
    correlation_id, reason_code, reason_note
  ) values (
    v_attempt_id, v_batch_id, v_attempt_number, 'NEED_GENERATION',
    v_batch.version, v_validated_version, v_batch.batch_status, 'VALIDATED',
    'VALIDATED', (v_evaluation ->> 'line_count')::integer, 0,
    (v_evaluation ->> 'warning_count')::integer,
    v_evaluation ->> 'validation_fingerprint', v_actor_id,
    pg_catalog.transaction_timestamp(),
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),
    'BATCH_VALIDATION_REQUESTED', null
  );

  for v_item in select value from pg_catalog.jsonb_array_elements(
    v_evaluation -> 'ordered_lines')
    order by (value ->> 'line_sort_position')::integer
  loop
    insert into atlas_planning.confirmed_need_validation_lines (
      confirmed_need_validation_attempt_id, confirmed_need_batch_id,
      confirmed_need_line_id, validation_outcome, controlled_unit_id,
      observed_current_revision_count, observed_current_decision_count,
      observed_eligible_policy_count, observed_source_membership_count,
      line_sort_position, current_confirmed_need_line_revision_id,
      current_confirmed_need_line_decision_id, planning_quantity_policy_id,
      planning_quantity_policy_revision_id, need_generation_run_id,
      need_generation_run_version, need_generation_release_snapshot_id,
      theoretical_quantity, confirmed_quantity, planning_tick_count,
      source_membership_total
    ) values (
      v_attempt_id, v_batch_id,
      atlas_core.pa_05b_safe_uuid(v_item ->> 'confirmed_need_line_id'),
      'VALIDATED', atlas_core.pa_05b_safe_uuid(v_item ->> 'controlled_unit_id'),
      (v_item ->> 'observed_current_revision_count')::integer,
      (v_item ->> 'observed_current_decision_count')::integer,
      (v_item ->> 'observed_eligible_policy_count')::integer,
      (v_item ->> 'observed_source_membership_count')::integer,
      (v_item ->> 'line_sort_position')::integer,
      atlas_core.pa_05b_safe_uuid(
        v_item ->> 'current_confirmed_need_line_revision_id'),
      atlas_core.pa_05b_safe_uuid(
        v_item ->> 'current_confirmed_need_line_decision_id'),
      atlas_core.pa_05b_safe_uuid(v_item ->> 'planning_quantity_policy_id'),
      atlas_core.pa_05b_safe_uuid(
        v_item ->> 'planning_quantity_policy_revision_id'),
      atlas_core.pa_05b_safe_uuid(v_item ->> 'need_generation_run_id'),
      nullif(v_item ->> 'need_generation_run_version', '')::bigint,
      atlas_core.pa_05b_safe_uuid(
        v_item ->> 'need_generation_release_snapshot_id'),
      nullif(v_item ->> 'theoretical_quantity', '')::numeric(20, 6),
      nullif(v_item ->> 'confirmed_quantity', '')::numeric(20, 6),
      nullif(v_item ->> 'planning_tick_count', '')::numeric(20, 0),
      nullif(v_item ->> 'source_membership_total', '')::numeric(20, 6)
    );
  end loop;
  for v_item in select value from pg_catalog.jsonb_array_elements(
    v_evaluation -> 'ordered_issues')
    order by (value ->> 'issue_sort_position')::integer
  loop
    v_validation_line_id := null;
    if v_item ->> 'confirmed_need_line_id' is not null then
      select line.confirmed_need_validation_line_id into strict v_validation_line_id
      from atlas_planning.confirmed_need_validation_lines line
      where line.confirmed_need_validation_attempt_id = v_attempt_id
        and line.confirmed_need_line_id = atlas_core.pa_05b_safe_uuid(
          v_item ->> 'confirmed_need_line_id');
    end if;
    insert into atlas_planning.confirmed_need_validation_issues (
      confirmed_need_validation_attempt_id, confirmed_need_validation_line_id,
      confirmed_need_batch_id, confirmed_need_line_id, severity, issue_code,
      safe_operator_message, issue_sort_position
    ) values (
      v_attempt_id, v_validation_line_id, v_batch_id,
      atlas_core.pa_05b_safe_uuid(v_item ->> 'confirmed_need_line_id'),
      v_item ->> 'severity', v_item ->> 'issue_code',
      v_item ->> 'safe_operator_message',
      (v_item ->> 'issue_sort_position')::integer
    );
  end loop;

  update atlas_planning.confirmed_need_batches
  set batch_status = 'VALIDATED', version = v_validated_version,
    current_confirmed_need_validation_attempt_id = v_attempt_id,
    updated_at = pg_catalog.transaction_timestamp()
  where confirmed_need_batch_id = v_batch_id;
  v_validation_events := atlas_core.rmvp_06_record_change(request, v_actor_id,
    v_receipt_id, v_batch_id, v_batch.version, v_validated_version,
    'ConfirmedNeedsValidated',
    pg_catalog.jsonb_build_object('batch_status', v_batch.batch_status,
      'batch_version', v_batch.version),
    pg_catalog.jsonb_build_object('resulting_status', 'VALIDATED',
      'resulting_version', v_validated_version,
      'validation_attempt_id', v_attempt_id));

  set constraints
    atlas_planning.confirmed_need_validation_attempts_integrity,
    atlas_planning.confirmed_need_validation_lines_integrity,
    atlas_planning.confirmed_need_validation_issues_integrity,
    atlas_planning.confirmed_need_batches_validation_integrity,
    atlas_planning.confirmed_need_batches_rmvp07_integrity immediate;
  set constraints
    atlas_planning.confirmed_need_validation_attempts_integrity,
    atlas_planning.confirmed_need_validation_lines_integrity,
    atlas_planning.confirmed_need_validation_issues_integrity,
    atlas_planning.confirmed_need_batches_validation_integrity,
    atlas_planning.confirmed_need_batches_rmvp07_integrity deferred;

  if not atlas_core.rmvp_07_validation_evidence_complete(
    v_batch_id, v_attempt_id, v_validated_version)
  then
    raise exception using errcode = '23514',
      message = 'D-037 validation evidence is incomplete';
  end if;
  v_projection := atlas_core.rmvp_07_validated_facts_projection(v_batch_id, null);
  v_fingerprint := atlas_core.rmvp_07_validated_facts_fingerprint(v_projection);
  insert into atlas_planning.confirmed_need_approval_snapshots (
    confirmed_need_approval_snapshot_id, confirmed_need_batch_id,
    approved_version, approved_by_actor_id, approved_at, command_id,
    source_kind, confirmed_need_validation_attempt_id,
    validated_fact_fingerprint
  ) values (
    v_snapshot_id, v_batch_id, v_approved_version, v_actor_id,
    pg_catalog.transaction_timestamp(),
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'), 'NEED_GENERATION',
    v_attempt_id, v_fingerprint
  );
  insert into atlas_planning.confirmed_need_snapshot_lines (
    confirmed_need_approval_snapshot_id, confirmed_need_line_revision_id,
    ingredient_id, approved_quantity, unit_id, ingredient_name_snapshot
  ) select v_snapshot_id, revision.confirmed_need_line_revision_id,
    revision.ingredient_id, revision.confirmed_quantity, revision.unit_id,
    ingredient.ingredient_name
  from atlas_planning.confirmed_need_lines line
  join atlas_planning.confirmed_need_line_revisions revision
    on revision.confirmed_need_line_id = line.confirmed_need_line_id
    and revision.is_current
  join atlas_admin.ingredients ingredient
    on ingredient.ingredient_id = revision.ingredient_id
  where line.confirmed_need_batch_id = v_batch_id
  order by line.confirmed_need_line_id;
  get diagnostics v_line_count = row_count;
  update atlas_planning.confirmed_need_line_revisions revision
  set revision_status = 'APPROVED'
  where revision.confirmed_need_batch_id = v_batch_id
    and revision.is_current and revision.revision_status = 'DRAFT';
  update atlas_planning.confirmed_need_batches
  set batch_status = 'APPROVED', version = v_approved_version,
    approved_by_actor_id = v_actor_id,
    approved_at = pg_catalog.transaction_timestamp(),
    current_confirmed_need_validation_attempt_id = null,
    current_confirmed_need_approval_snapshot_id = v_snapshot_id,
    current_confirmed_need_release_id = null,
    updated_at = pg_catalog.transaction_timestamp()
  where confirmed_need_batch_id = v_batch_id;
  v_approval_events := atlas_core.rmvp_07_record_change(request, v_actor_id,
    v_receipt_id, v_batch_id, v_validated_version, v_approved_version,
    'ConfirmedNeedsApproved',
    pg_catalog.jsonb_build_object('resulting_status', 'VALIDATED',
      'resulting_version', v_validated_version),
    pg_catalog.jsonb_build_object('resulting_status', 'APPROVED',
      'resulting_version', v_approved_version,
      'approval_snapshot_id', v_snapshot_id));

  set constraints
    atlas_planning.confirmed_need_batches_rmvp07_integrity,
    atlas_planning.confirmed_need_approval_snapshots_rmvp07_integrity,
    atlas_planning.confirmed_need_snapshot_lines_rmvp07_integrity immediate;
  set constraints
    atlas_planning.confirmed_need_batches_rmvp07_integrity,
    atlas_planning.confirmed_need_approval_snapshots_rmvp07_integrity,
    atlas_planning.confirmed_need_snapshot_lines_rmvp07_integrity deferred;

  if atlas_core.rmvp_07_validated_facts_fingerprint(
      atlas_core.rmvp_07_validated_facts_projection(v_batch_id, null))
    is distinct from v_fingerprint
  then
    raise exception using errcode = '23514',
      message = 'D-037 approved facts changed before release';
  end if;
  insert into atlas_planning.confirmed_need_releases (
    confirmed_need_release_id, confirmed_need_batch_id, source_kind,
    confirmed_need_approval_snapshot_id, source_approved_batch_version,
    resulting_released_batch_version, released_by_actor_id, released_at,
    command_id
  ) values (
    v_release_id, v_batch_id, 'NEED_GENERATION', v_snapshot_id,
    v_approved_version, v_released_version, v_actor_id,
    pg_catalog.transaction_timestamp(),
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id')
  );
  update atlas_planning.confirmed_need_line_revisions revision
  set revision_status = 'RELEASED'
  where revision.confirmed_need_batch_id = v_batch_id
    and revision.is_current and revision.revision_status = 'APPROVED';
  update atlas_planning.confirmed_need_batches
  set batch_status = 'RELEASED_FOR_PURCHASE_HANDOFF',
    version = v_released_version, released_by_actor_id = v_actor_id,
    released_at = pg_catalog.transaction_timestamp(),
    current_confirmed_need_release_id = v_release_id,
    updated_at = pg_catalog.transaction_timestamp()
  where confirmed_need_batch_id = v_batch_id;
  v_events := atlas_core.rmvp_07_record_change(request, v_actor_id,
    v_receipt_id, v_batch_id, v_approved_version, v_released_version,
    'ConfirmedNeedsReleasedForPurchaseHandoff',
    pg_catalog.jsonb_build_object('resulting_status', 'APPROVED',
      'resulting_version', v_approved_version),
    pg_catalog.jsonb_build_object(
      'resulting_status', 'RELEASED_FOR_PURCHASE_HANDOFF',
      'resulting_version', v_released_version, 'release_id', v_release_id));

  v_response := pg_catalog.jsonb_build_object(
    'success', true, 'contract_version', 'RMVP-07.v2',
    'command_name', v_name, 'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id',
    'idempotency_status', 'COMPLETED',
    'confirmed_need_batch_id', v_batch_id,
    'prior_batch_status', v_batch.batch_status,
    'resulting_batch_status', 'RELEASED_FOR_PURCHASE_HANDOFF',
    'prior_batch_version', v_batch.version,
    'resulting_batch_version', v_released_version,
    'validation_attempt_id', v_attempt_id,
    'approval_snapshot_id', v_snapshot_id,
    'release_id', v_release_id,
    'released_line_count', v_line_count,
    'warning_count', (v_evaluation ->> 'warning_count')::integer,
    'receipt_id', v_receipt_id,
    'validation_event_id', v_validation_events -> 'domain_event_id',
    'approval_event_id', v_approval_events -> 'domain_event_id',
    'release_event_id', v_events -> 'domain_event_id',
    'safe_operator_message', 'Confirmed Need was released for ordering.',
    'authoritative_readback', atlas_core.d037_extend_workbench(
      atlas_core.rmvp_07_extend_workbench(
        atlas_core.rmvp_06_extend_workbench(
          atlas_core.rmvp_05_workbench_payload(
            v_batch_id, '{}'::jsonb, 0, 10000
          )
        ), v_actor_id
      ), v_actor_id
    )
  );
  v_response := atlas_core.pa_05b_finish_command(v_receipt_id, v_response, true);
  set constraints all immediate;
  set constraints all deferred;
  return v_response;
exception when others then
  return atlas_core.d037_error(request, 'RMVP-07.v2', v_name,
    'INTERNAL_COMMAND_FAILURE',
    'The Release outcome is unknown. Refresh before continuing.', true);
end;
$$;

reset role;
revoke create on schema atlas_core, atlas_api from atlas_confirmed_need_review_runtime;
grant atlas_confirmed_need_review_runtime to postgres with set false;
