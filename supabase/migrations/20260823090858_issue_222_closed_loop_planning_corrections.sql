-- Issue #222 / D-042
-- Closed-loop, date-scoped correction of consequential Planning sources.
-- Adds one shaped impact read and one governed correction command. Existing
-- source-save identities remain stable and delegate to their exact v2 bodies.

reset role;
grant atlas_planning_command_runtime, atlas_need_generation_runtime,
  atlas_confirmed_need_review_runtime, atlas_read_runtime
to postgres with set true;
set role atlas_owner;

grant usage on schema atlas_procurement to atlas_planning_command_runtime;
grant select on atlas_procurement.fulfilment_allocations
to atlas_planning_command_runtime;
create policy issue_222_planning_commitment_select
on atlas_procurement.fulfilment_allocations
for select to atlas_planning_command_runtime using (true);

grant create on schema atlas_core, atlas_api to atlas_planning_command_runtime;
set role atlas_planning_command_runtime;

alter function atlas_api.save_weekly_menu(jsonb) set schema atlas_core;
alter function atlas_core.save_weekly_menu(jsonb)
  rename to issue_222_save_weekly_menu_impl;
alter function atlas_api.save_attendance(jsonb) set schema atlas_core;
alter function atlas_core.save_attendance(jsonb)
  rename to issue_222_save_attendance_impl;
alter function atlas_api.save_pantry(jsonb) set schema atlas_core;
alter function atlas_core.save_pantry(jsonb)
  rename to issue_222_save_pantry_impl;

revoke execute on function
  atlas_core.issue_222_save_weekly_menu_impl(jsonb),
  atlas_core.issue_222_save_attendance_impl(jsonb),
  atlas_core.issue_222_save_pantry_impl(jsonb)
from public, anon, authenticated, service_role;
grant execute on function
  atlas_core.issue_222_save_weekly_menu_impl(jsonb),
  atlas_core.issue_222_save_attendance_impl(jsonb),
  atlas_core.issue_222_save_pantry_impl(jsonb)
to atlas_planning_command_runtime;

create function atlas_core.issue_222_affected_dates(
  source_kind text,
  source_payload jsonb
)
returns date[]
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_kind text := pg_catalog.upper(coalesce(source_kind, ''));
  v_week_start date := atlas_core.pa_05d_safe_date(
    source_payload ->> 'week_start'
  );
  v_snapshot_id uuid;
  v_rows jsonb;
  v_dates date[] := '{}'::date[];
begin
  if v_week_start is null or pg_catalog.jsonb_typeof(source_payload -> 'rows')
      is distinct from 'array' then
    return v_dates;
  end if;

  if v_kind = 'WEEKLY_MENU' then
    v_rows := atlas_core.rmvp_03a_canonical_menu_rows(
      source_payload -> 'rows'
    );
    select menu.latest_approval_snapshot_id into v_snapshot_id
    from atlas_planning.weekly_menus menu
    where menu.week_start = v_week_start
    order by menu.updated_at desc, menu.weekly_menu_id
    limit 1;

    with proposed as (
      select
        atlas_core.pa_05d_safe_date(row ->> 'service_date') service_date,
        atlas_core.pa_05b_safe_uuid(row ->> 'school_id') school_id,
        row ->> 'menu_slot_code' menu_slot_code,
        atlas_core.pa_05b_safe_uuid(row ->> 'dish_id') dish_id
      from pg_catalog.jsonb_array_elements(v_rows) row
    ), current_facts as (
      select line.service_date, line.school_id, line.menu_slot_code, line.dish_id
      from atlas_planning.weekly_menu_approval_snapshot_lines line
      where line.weekly_menu_approval_snapshot_id = v_snapshot_id
    ), differences as (
      (select * from proposed except select * from current_facts)
      union
      (select * from current_facts except select * from proposed)
    )
    select coalesce(pg_catalog.array_agg(distinct service_date order by service_date),
      '{}'::date[]) into v_dates
    from differences where service_date is not null;
  elsif v_kind = 'ATTENDANCE' then
    v_rows := atlas_core.rmvp_03a_canonical_attendance_rows(
      source_payload -> 'rows'
    );
    select batch.latest_approval_snapshot_id into v_snapshot_id
    from atlas_planning.attendance_batches batch
    where batch.period_start = v_week_start
      and batch.period_end = v_week_start + 6
    order by batch.updated_at desc, batch.attendance_batch_id
    limit 1;

    with proposed as (
      select
        atlas_core.pa_05d_safe_date(row ->> 'service_date') service_date,
        atlas_core.pa_05b_safe_uuid(row ->> 'school_id') school_id,
        atlas_core.pa_05b_safe_bigint(row ->> 'student_portions') student_portions,
        atlas_core.pa_05b_safe_bigint(row ->> 'teacher_portions') teacher_portions
      from pg_catalog.jsonb_array_elements(v_rows) row
    ), current_facts as (
      select line.service_date, line.school_id,
        line.student_portions, line.teacher_portions
      from atlas_planning.attendance_approval_snapshot_lines line
      where line.attendance_approval_snapshot_id = v_snapshot_id
    ), differences as (
      (select * from proposed except select * from current_facts)
      union
      (select * from current_facts except select * from proposed)
    )
    select coalesce(pg_catalog.array_agg(distinct service_date order by service_date),
      '{}'::date[]) into v_dates
    from differences where service_date is not null;
  elsif v_kind = 'PANTRY' then
    v_rows := atlas_core.pantry_02_canonical_rows(
      v_week_start, source_payload -> 'rows'
    );
    select batch.latest_approval_snapshot_id into v_snapshot_id
    from atlas_planning.pantry_need_batches batch
    where batch.week_start = v_week_start
    order by batch.updated_at desc, batch.pantry_need_batch_id
    limit 1;

    with proposed as (
      select
        atlas_core.pa_05d_safe_date(row ->> 'service_date') service_date,
        atlas_core.pa_05b_safe_uuid(row ->> 'school_id') school_id,
        atlas_core.pa_05b_safe_uuid(row ->> 'delivery_location_id') delivery_location_id,
        atlas_core.pa_05b_safe_uuid(row ->> 'ingredient_id') ingredient_id,
        atlas_core.pa_05b_safe_uuid(row ->> 'unit_id') unit_id,
        atlas_core.pa_05b_safe_uuid(row ->> 'pantry_need_purpose_id') purpose_id,
        atlas_core.pantry_02_safe_quantity(row ->> 'requested_quantity') quantity
      from pg_catalog.jsonb_array_elements(v_rows) row
    ), current_facts as (
      select line.service_date, line.school_id, line.delivery_location_id,
        line.ingredient_id, line.unit_id,
        line.pantry_need_purpose_id, line.requested_quantity
      from atlas_planning.pantry_need_approval_snapshot_lines line
      where line.pantry_need_approval_snapshot_id = v_snapshot_id
    ), differences as (
      (select * from proposed except select * from current_facts)
      union
      (select * from current_facts except select * from proposed)
    )
    select coalesce(pg_catalog.array_agg(distinct service_date order by service_date),
      '{}'::date[]) into v_dates
    from differences where service_date is not null;
  end if;
  return v_dates;
end;
$$;

create function atlas_core.issue_222_chain_payload(run_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with chain as (
    select run.need_generation_run_id, run.period_start, run.period_end,
      run.run_status, run.version as need_generation_run_version,
      batch.confirmed_need_batch_id,
      batch.batch_status as confirmed_need_status,
      batch.version as confirmed_need_batch_version,
      batch.current_confirmed_need_release_id is not null
        or batch.released_at is not null as planning_release_occurred
    from atlas_planning.need_generation_runs run
    left join atlas_planning.confirmed_need_batches batch
      on batch.source_kind = 'NEED_GENERATION'
     and batch.current_need_generation_run_id = run.need_generation_run_id
    where run.need_generation_run_id = issue_222_chain_payload.run_id
  ), handoff as (
    select
      pg_catalog.bool_or(h.handoff_status not in ('INVALIDATED', 'REOPENED'))
        as active_handoff_exists,
      coalesce(pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'purchase_handoff_batch_id', h.purchase_handoff_batch_id,
          'handoff_status', h.handoff_status,
          'version', h.version
        ) order by h.created_at, h.purchase_handoff_batch_id
      ) filter (where h.purchase_handoff_batch_id is not null), '[]'::jsonb)
        as handoffs
    from chain
    left join atlas_planning.purchase_handoff_batches h
      on h.confirmed_need_batch_id = chain.confirmed_need_batch_id
  ), downstream as (
    select exists (
      select 1
      from chain
      join atlas_planning.purchase_handoff_batches h
        on h.confirmed_need_batch_id = chain.confirmed_need_batch_id
      join atlas_planning.purchase_handoff_revisions hr
        on hr.purchase_handoff_batch_id = h.purchase_handoff_batch_id
      join atlas_planning.dispatch_requirement_revisions drr
        on drr.purchase_handoff_revision_id = hr.purchase_handoff_revision_id
      join atlas_procurement.fulfilment_allocations allocation
        on allocation.dispatch_requirement_id = drr.dispatch_requirement_id
    ) as later_downstream_commitment_exists
  )
  select pg_catalog.to_jsonb(chain) || pg_catalog.jsonb_build_object(
    'is_legacy_range', chain.period_start <> chain.period_end,
    'active_purchase_handoff_exists', coalesce(handoff.active_handoff_exists, false),
    'purchase_handoffs', handoff.handoffs,
    'later_downstream_commitment_exists',
      downstream.later_downstream_commitment_exists
  )
  from chain cross join handoff cross join downstream;
$$;

create function atlas_core.issue_222_source_impact_payload(
  source_kind text,
  source_payload jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_dates date[] := atlas_core.issue_222_affected_dates(
    source_kind, source_payload
  );
  v_date date;
  v_chains jsonb;
  v_policy text;
  v_action text;
  v_message text;
  v_items jsonb := '[]'::jsonb;
  v_allowed boolean := true;
  v_blocker text;
begin
  foreach v_date in array v_dates loop
    select coalesce(pg_catalog.jsonb_agg(
      atlas_core.issue_222_chain_payload(run.need_generation_run_id)
      order by run.period_start, run.period_end, run.need_generation_run_id
    ), '[]'::jsonb) into v_chains
    from atlas_planning.need_generation_runs run
    where run.run_status <> 'INVALIDATED'
      and v_date between run.period_start and run.period_end;

    if pg_catalog.jsonb_array_length(v_chains) = 0 then
      v_policy := 'SAFE_NOT_GENERATED';
      v_action := 'SAVE_SOURCE';
      v_message := 'Có thể lưu thay đổi; ngày này chưa tạo Nhu cầu.';
    elsif exists (
      select 1 from pg_catalog.jsonb_array_elements(v_chains) chain
      where (chain ->> 'later_downstream_commitment_exists')::boolean
    ) then
      v_policy := 'BLOCKED_BY_DOWNSTREAM_COMMITMENT';
      v_action := 'START_DOWNSTREAM_CORRECTION';
      v_message := 'Nhu cầu ngày này đã có cam kết vận hành phía sau; cần quy trình hiệu chỉnh riêng.';
    elsif exists (
      select 1 from pg_catalog.jsonb_array_elements(v_chains) chain
      where (chain ->> 'active_purchase_handoff_exists')::boolean
    ) then
      v_policy := 'BLOCKED_BY_PURCHASE_HANDOFF';
      v_action := 'START_DOWNSTREAM_CORRECTION';
      v_message := 'Nhu cầu ngày này đã bàn giao cho Thu mua; cần hiệu chỉnh hạ nguồn riêng.';
    elsif exists (
      select 1 from pg_catalog.jsonb_array_elements(v_chains) chain
      where coalesce(chain ->> 'confirmed_need_status', '')
        not in ('DRAFT_REVIEW', 'REOPENED')
    ) then
      v_policy := 'PLANNING_RELEASE_CORRECTION_REQUIRED';
      v_action := 'PREPARE_PLANNING_CORRECTION';
      v_message := 'Nhu cầu đã được Kế hoạch cam kết; hãy mở lại cam kết trước khi lưu.';
    elsif exists (
      select 1 from pg_catalog.jsonb_array_elements(v_chains) chain
      where (chain ->> 'is_legacy_range')::boolean
    ) then
      v_policy := 'LEGACY_RANGE_CORRECTION_REQUIRED';
      v_action := 'RETIRE_LEGACY_RANGE';
      v_message := 'Ngày này thuộc Nhu cầu nhiều ngày cũ; cần xử lý toàn bộ khoảng trước khi lưu.';
    else
      v_policy := 'SAFE_REGENERATE';
      v_action := 'CONFIRM_SAVE_THEN_REGENERATE';
      v_message := 'Lưu thay đổi sẽ làm Nhu cầu ngày này cần được tạo lại.';
    end if;

    if v_policy not in ('SAFE_NOT_GENERATED', 'SAFE_REGENERATE') then
      v_allowed := false;
      v_blocker := coalesce(v_blocker, v_policy);
    end if;
    v_items := v_items || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'service_date', v_date,
        'need_state', case
          when pg_catalog.jsonb_array_length(v_chains) = 0 then 'NOT_GENERATED'
          when exists (
            select 1 from pg_catalog.jsonb_array_elements(v_chains) chain
            where (chain ->> 'is_legacy_range')::boolean
          ) then 'LEGACY_OVERLAP'
          else 'GENERATED' end,
        'confirmed_need_state', case
          when pg_catalog.jsonb_array_length(v_chains) = 0 then null
          when pg_catalog.jsonb_array_length(v_chains) = 1
            then v_chains -> 0 ->> 'confirmed_need_status'
          else 'MULTIPLE_CHAINS' end,
        'planning_release_occurred', exists (
          select 1 from pg_catalog.jsonb_array_elements(v_chains) chain
          where (chain ->> 'planning_release_occurred')::boolean
        ),
        'purchase_handoff_exists', exists (
          select 1 from pg_catalog.jsonb_array_elements(v_chains) chain
          where (chain ->> 'active_purchase_handoff_exists')::boolean
        ),
        'later_downstream_commitment_exists', exists (
          select 1 from pg_catalog.jsonb_array_elements(v_chains) chain
          where (chain ->> 'later_downstream_commitment_exists')::boolean
        ),
        'legacy_overlap_exists', exists (
          select 1 from pg_catalog.jsonb_array_elements(v_chains) chain
          where (chain ->> 'is_legacy_range')::boolean
        ),
        'correction_policy', v_policy,
        'safe_to_save', v_policy in ('SAFE_NOT_GENERATED', 'SAFE_REGENERATE'),
        'next_required_action', v_action,
        'operator_message', v_message,
        'chains', v_chains
      )
    );
  end loop;

  return pg_catalog.jsonb_build_object(
    'source_kind', pg_catalog.upper(source_kind),
    'material_change', pg_catalog.cardinality(v_dates) > 0,
    'affected_service_dates', to_jsonb(v_dates),
    'date_impacts', v_items,
    'save_allowed', v_allowed,
    'save_blocker_code', v_blocker
  );
end;
$$;

create function atlas_core.issue_222_source_save_auth_error(
  request jsonb,
  command_name text,
  contract_version text,
  capability_code text
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_error jsonb;
  v_actor jsonb;
begin
  v_error := atlas_core.planning_contract_01_validate_command(
    request, command_name, contract_version
  );
  if v_error is not null then return v_error; end if;
  v_actor := atlas_core.pa_05b_resolve_actor(request, 'PLANNING', command_name);
  if v_actor ? 'error' then
    return (v_actor -> 'error') ||
      pg_catalog.jsonb_build_object('contract_version', contract_version);
  end if;
  if v_actor ->> 'actor_type' <> 'HUMAN' then
    return atlas_core.planning_contract_01_command_error(
      request, command_name, contract_version, 'DELEGATION_NOT_SUPPORTED',
      'Only an active authenticated human actor may use this command.'
    );
  end if;
  return atlas_core.pa_05b_authorize_actor(
    request, atlas_core.pa_05b_safe_uuid(v_actor ->> 'actor_id'),
    capability_code, 'PLANNING', command_name, null, null, null
  );
end;
$$;

create function atlas_core.issue_222_enforce_source_save(
  request jsonb,
  source_kind text,
  command_name text,
  contract_version text,
  capability_code text
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_error jsonb;
  v_impact jsonb;
  v_dates date[];
  v_run_id uuid;
  v_payload jsonb := request -> 'payload';
  v_week_start date := atlas_core.pa_05d_safe_date(
    request -> 'payload' ->> 'week_start'
  );
  v_rows jsonb;
  v_claimed_signature text;
  v_derived_signature text;
  v_no_additions boolean;
begin
  -- Preserve each established Save contract's deterministic payload and
  -- checksum precedence before the new authorization/downstream recheck.
  if source_kind in ('WEEKLY_MENU', 'ATTENDANCE') then
    if v_week_start is null
      or v_payload - array[
        'week_start', 'source_type', 'source_name', 'source_signature',
        'expected_source_signature', 'rows'
      ] <> '{}'::jsonb
      or not (v_payload ?& array[
        'week_start', 'source_type', 'source_name', 'source_signature',
        'expected_source_signature', 'rows'
      ])
      or pg_catalog.jsonb_typeof(v_payload -> 'rows') <> 'array'
    then
      return atlas_core.planning_contract_01_command_error(
        request, command_name, contract_version, 'VALIDATION_FAILED',
        case source_kind when 'WEEKLY_MENU'
          then 'The Weekly Menu completion payload is invalid.'
          else 'The Attendance completion payload is invalid.' end
      );
    end if;
    v_claimed_signature := pg_catalog.lower(coalesce(
      atlas_core.rmvp_03a_normalize_text(v_payload ->> 'source_signature'), ''
    ));
    if source_kind = 'WEEKLY_MENU' then
      v_rows := atlas_core.rmvp_03a_canonical_menu_rows(v_payload -> 'rows');
      v_derived_signature := atlas_core.rmvp_03a_menu_signature(v_rows);
    else
      v_rows := atlas_core.rmvp_03a_canonical_attendance_rows(v_payload -> 'rows');
      v_derived_signature := atlas_core.rmvp_03a_attendance_signature(v_rows);
    end if;
    if v_claimed_signature = ''
      or v_claimed_signature <> v_derived_signature
    then
      return atlas_core.planning_contract_01_command_error(
        request, command_name, contract_version, 'CHECKSUM_MISMATCH',
        case source_kind when 'WEEKLY_MENU'
          then 'Save requires the checksum of the complete canonical Weekly Menu.'
          else 'Save requires the checksum of the complete canonical Attendance.' end
      );
    end if;
  else
    if v_week_start is null
      or v_payload - array[
        'week_start', 'no_additions_confirmed', 'source_signature',
        'expected_source_signature', 'rows'
      ] <> '{}'::jsonb
      or not (v_payload ?& array[
        'week_start', 'no_additions_confirmed', 'source_signature',
        'expected_source_signature', 'rows'
      ])
      or pg_catalog.jsonb_typeof(v_payload -> 'no_additions_confirmed')
        <> 'boolean'
      or pg_catalog.jsonb_typeof(v_payload -> 'rows') <> 'array'
    then
      return atlas_core.planning_contract_01_command_error(
        request, command_name, contract_version, 'VALIDATION_FAILED',
        'The Pantry completion payload is invalid.'
      );
    end if;
    v_no_additions := (v_payload ->> 'no_additions_confirmed')::boolean;
    v_rows := atlas_core.pantry_02_canonical_rows(
      v_week_start, v_payload -> 'rows'
    );
    v_claimed_signature := atlas_core.pantry_02_normalize_text(
      v_payload ->> 'source_signature'
    );
    v_derived_signature := atlas_core.pantry_02_signature(
      v_week_start, v_no_additions, v_rows
    );
    if v_claimed_signature is null
      or v_claimed_signature is distinct from v_derived_signature
    then
      return atlas_core.planning_contract_01_command_error(
        request, command_name, contract_version, 'CHECKSUM_MISMATCH',
        'Save requires the checksum of the complete server-canonical Pantry source.'
      );
    end if;
  end if;

  v_error := atlas_core.issue_222_source_save_auth_error(
    request, command_name, contract_version, capability_code
  );
  if v_error is not null then return v_error; end if;
  v_dates := atlas_core.issue_222_affected_dates(
    source_kind, request -> 'payload'
  );

  -- Serialize against correction, Confirmed Need, and Handoff commands for
  -- every consequential date. Locking the run first matches the correction
  -- command's order; locking its Confirmed Need prevents a new Handoff from
  -- being created between this recheck and the source Save.
  for v_run_id in
    select run.need_generation_run_id
    from atlas_planning.need_generation_runs run
    where run.run_status <> 'INVALIDATED'
      and exists (
        select 1 from pg_catalog.unnest(v_dates) affected(service_date)
        where affected.service_date between run.period_start and run.period_end
    )
    order by run.need_generation_run_id
  loop
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
      'atlas:planning-correction:' || v_run_id::text, 0
    ));

    perform 1
    from atlas_planning.confirmed_need_batches batch
    where batch.source_kind = 'NEED_GENERATION'
      and batch.current_need_generation_run_id = v_run_id
    order by batch.confirmed_need_batch_id
    for update;

    perform 1
    from atlas_planning.purchase_handoff_batches handoff
    join atlas_planning.confirmed_need_batches batch
      on batch.confirmed_need_batch_id = handoff.confirmed_need_batch_id
    where batch.source_kind = 'NEED_GENERATION'
      and batch.current_need_generation_run_id = v_run_id
    order by handoff.purchase_handoff_batch_id
    for update of handoff;
  end loop;

  v_impact := atlas_core.issue_222_source_impact_payload(
    source_kind, request -> 'payload'
  );
  if not coalesce((v_impact ->> 'save_allowed')::boolean, false) then
    return atlas_core.planning_contract_01_command_error(
      request, command_name, contract_version,
      v_impact ->> 'save_blocker_code',
      'Thay đổi nguồn chưa thể lưu vì cần xử lý cam kết Nhu cầu trước.',
      '[]'::jsonb, v_impact -> 'date_impacts'
    );
  end if;
  return null;
end;
$$;

create function atlas_api.get_planning_source_correction_impact(request jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'get_planning_source_correction_impact';
  v_contract constant text := 'PLANNING-CORRECTION.v1';
  v_actor jsonb;
  v_error jsonb;
  v_kind text := request -> 'payload' ->> 'source_kind';
  v_source_payload jsonb := request -> 'payload' -> 'source_payload';
begin
  if request is null or request - array[
      'contract_version', 'requested_by_auth_subject', 'correlation_id', 'payload'
    ] <> '{}'::jsonb
    or request ->> 'contract_version' is distinct from v_contract
    or atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id') is null
    or atlas_core.pa_05b_safe_uuid(request ->> 'requested_by_auth_subject') is null
    or (request -> 'payload') - array['source_kind', 'source_payload'] <> '{}'::jsonb
    or pg_catalog.upper(coalesce(v_kind, '')) not in
      ('WEEKLY_MENU', 'ATTENDANCE', 'PANTRY')
    or pg_catalog.jsonb_typeof(v_source_payload) is distinct from 'object'
  then
    return atlas_core.pa_05b_command_error(
      coalesce(request, '{}'::jsonb), 'VALIDATION_FAILED',
      'Yêu cầu xem ảnh hưởng nguồn Kế hoạch không hợp lệ.',
      'PLANNING', v_name
    ) || pg_catalog.jsonb_build_object('contract_version', v_contract);
  end if;
  v_actor := atlas_core.pa_05b_resolve_actor(request, 'PLANNING', v_name);
  if v_actor ? 'error' then
    return (v_actor -> 'error') ||
      pg_catalog.jsonb_build_object('contract_version', v_contract);
  end if;
  v_error := atlas_core.pa_05b_authorize_actor(
    request, atlas_core.pa_05b_safe_uuid(v_actor ->> 'actor_id'),
    'planning.inputs.read', 'PLANNING', v_name, null, null, null
  );
  if v_error is not null then
    return v_error || pg_catalog.jsonb_build_object('contract_version', v_contract);
  end if;
  return pg_catalog.jsonb_build_object(
    'success', true, 'contract_version', v_contract,
    'correlation_id', request ->> 'correlation_id',
    'impact', atlas_core.issue_222_source_impact_payload(v_kind, v_source_payload)
  );
exception when others then
  return atlas_core.pa_05b_command_error(
    request, 'INTERNAL_READ_FAILURE',
    'Không thể kiểm tra ảnh hưởng hiệu chỉnh một cách an toàn.',
    'PLANNING', v_name
  ) || pg_catalog.jsonb_build_object('contract_version', v_contract);
end;
$$;

create function atlas_api.save_weekly_menu(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare v_error jsonb;
begin
  v_error := atlas_core.issue_222_enforce_source_save(
    request, 'WEEKLY_MENU', 'save_weekly_menu', 'RMVP-03A.v2',
    'planning.weekly_menu.write'
  );
  if v_error is not null then return v_error; end if;
  return atlas_core.issue_222_save_weekly_menu_impl(request);
end;
$$;

create function atlas_api.save_attendance(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare v_error jsonb;
begin
  v_error := atlas_core.issue_222_enforce_source_save(
    request, 'ATTENDANCE', 'save_attendance', 'RMVP-03A.v2',
    'planning.attendance.write'
  );
  if v_error is not null then return v_error; end if;
  return atlas_core.issue_222_save_attendance_impl(request);
end;
$$;

create function atlas_api.save_pantry(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare v_error jsonb;
begin
  v_error := atlas_core.issue_222_enforce_source_save(
    request, 'PANTRY', 'save_pantry', 'PANTRY-02.v2',
    'planning.pantry.write'
  );
  if v_error is not null then return v_error; end if;
  return atlas_core.issue_222_save_pantry_impl(request);
end;
$$;

revoke execute on function
  atlas_core.issue_222_affected_dates(text, jsonb),
  atlas_core.issue_222_chain_payload(uuid),
  atlas_core.issue_222_source_impact_payload(text, jsonb),
  atlas_core.issue_222_source_save_auth_error(jsonb, text, text, text),
  atlas_core.issue_222_enforce_source_save(jsonb, text, text, text, text)
from public, anon, authenticated, service_role;
grant execute on function
  atlas_core.issue_222_affected_dates(text, jsonb),
  atlas_core.issue_222_chain_payload(uuid),
  atlas_core.issue_222_source_impact_payload(text, jsonb),
  atlas_core.issue_222_source_save_auth_error(jsonb, text, text, text),
  atlas_core.issue_222_enforce_source_save(jsonb, text, text, text, text)
to atlas_planning_command_runtime;
grant execute on function
  atlas_core.issue_222_chain_payload(uuid),
  atlas_core.issue_222_source_impact_payload(text, jsonb)
to atlas_need_generation_runtime;
grant execute on function
  atlas_core.issue_222_source_impact_payload(text, jsonb)
to atlas_read_runtime;

revoke execute on function
  atlas_api.get_planning_source_correction_impact(jsonb),
  atlas_api.save_weekly_menu(jsonb),
  atlas_api.save_attendance(jsonb),
  atlas_api.save_pantry(jsonb)
from public, anon, authenticated, service_role;
grant execute on function
  atlas_api.get_planning_source_correction_impact(jsonb),
  atlas_api.save_weekly_menu(jsonb),
  atlas_api.save_attendance(jsonb),
  atlas_api.save_pantry(jsonb)
to authenticated;

comment on function atlas_api.get_planning_source_correction_impact(jsonb) is
  'PLANNING-CORRECTION.v1 backend-owned material affected-date and downstream correction impact read.';
comment on function atlas_api.save_weekly_menu(jsonb) is
  'RMVP-03A.v2 consequential Weekly Menu Save with Issue #222 closed-loop enforcement.';
comment on function atlas_api.save_attendance(jsonb) is
  'RMVP-03A.v2 consequential Attendance Save with Issue #222 closed-loop enforcement.';
comment on function atlas_api.save_pantry(jsonb) is
  'PANTRY-02.v2 consequential Pantry Save with Issue #222 closed-loop enforcement.';

reset role;
set role atlas_owner;
revoke create on schema atlas_core, atlas_api from atlas_planning_command_runtime;

grant create on schema atlas_core to atlas_confirmed_need_review_runtime;
set role atlas_confirmed_need_review_runtime;

create function atlas_core.issue_222_reopen_confirmed_need(
  confirmed_need_batch_id uuid,
  expected_version bigint
)
returns atlas_planning.confirmed_need_batches
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_batch atlas_planning.confirmed_need_batches%rowtype;
begin
  update atlas_planning.confirmed_need_batches batch
  set batch_status = 'REOPENED',
    version = batch.version + 1,
    current_confirmed_need_validation_attempt_id = null,
    current_confirmed_need_approval_snapshot_id = null,
    current_confirmed_need_release_id = null,
    updated_at = pg_catalog.transaction_timestamp()
  where batch.confirmed_need_batch_id =
      issue_222_reopen_confirmed_need.confirmed_need_batch_id
    and batch.version = issue_222_reopen_confirmed_need.expected_version
    and batch.source_kind = 'NEED_GENERATION'
    and batch.batch_status not in ('DRAFT_REVIEW', 'REOPENED')
  returning batch.* into v_batch;
  if v_batch.confirmed_need_batch_id is null then
    raise exception using errcode = 'P0001',
      message = 'Confirmed Need reopen precondition failed';
  end if;
  return v_batch;
end;
$$;

revoke execute on function
  atlas_core.issue_222_reopen_confirmed_need(uuid, bigint)
from public, anon, authenticated, service_role;
grant execute on function
  atlas_core.issue_222_reopen_confirmed_need(uuid, bigint)
to atlas_need_generation_runtime;

reset role;
set role atlas_owner;
revoke create on schema atlas_core from atlas_confirmed_need_review_runtime;

grant create on schema atlas_api to atlas_need_generation_runtime;
set role atlas_need_generation_runtime;

create function atlas_api.prepare_planning_source_correction(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'prepare_planning_source_correction';
  v_contract constant text := 'PLANNING-CORRECTION.v1';
  v_payload jsonb := request -> 'payload';
  v_run_id uuid := atlas_core.pa_05b_safe_uuid(
    request -> 'payload' ->> 'need_generation_run_id'
  );
  v_batch_id uuid := atlas_core.pa_05b_safe_uuid(
    request -> 'payload' ->> 'confirmed_need_batch_id'
  );
  v_expected_batch_version bigint := atlas_core.pa_05b_safe_bigint(
    request -> 'payload' ->> 'expected_confirmed_need_batch_version'
  );
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_run atlas_planning.need_generation_runs%rowtype;
  v_batch atlas_planning.confirmed_need_batches%rowtype;
  v_chain jsonb;
  v_before_run_version bigint;
  v_before_batch_version bigint;
  v_action text;
  v_recorded jsonb;
  v_response jsonb;
  v_error jsonb;
begin
  if v_run_id is null or v_batch_id is null or v_expected_batch_version is null
    or v_payload - array[
      'need_generation_run_id', 'confirmed_need_batch_id',
      'expected_confirmed_need_batch_version'
    ] <> '{}'::jsonb
    or request ->> 'reason_code' is distinct from
      'PLANNING_SOURCE_CORRECTION_PREPARED'
    or pg_catalog.btrim(coalesce(request ->> 'reason_note', '')) = ''
  then
    return atlas_core.planning_contract_01_command_error(
      request, v_name, v_contract, 'VALIDATION_FAILED',
      'Yêu cầu chuẩn bị hiệu chỉnh Kế hoạch không hợp lệ.'
    );
  end if;

  v_prepare := atlas_core.planning_contract_01_prepare_top_command(
    request, v_name, v_contract, 'planning.need_generation.write',
    'need-generation:' || v_run_id::text
  );
  if v_prepare ->> 'status' = 'RETURN' then
    return (v_prepare -> 'response') ||
      pg_catalog.jsonb_build_object('contract_version', v_contract);
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'atlas:planning-correction:' || v_run_id::text, 0
  ));

  select * into v_run from atlas_planning.need_generation_runs run
  where run.need_generation_run_id = v_run_id for update;
  select * into v_batch from atlas_planning.confirmed_need_batches batch
  where batch.confirmed_need_batch_id = v_batch_id for update;

  if v_run.need_generation_run_id is null
    or v_batch.confirmed_need_batch_id is null
    or v_batch.source_kind <> 'NEED_GENERATION'
    or v_batch.current_need_generation_run_id <> v_run_id
  then
    v_error := atlas_core.planning_contract_01_command_error(
      request, v_name, v_contract, 'CORRECTION_CHAIN_NOT_FOUND',
      'Không tìm thấy đúng chuỗi Nhu cầu cần hiệu chỉnh.'
    );
    return atlas_core.pa_05b_finish_command(
      v_receipt_id, v_error, false
    );
  end if;
  if v_run.version <> atlas_core.pa_05b_safe_bigint(
      request ->> 'expected_version'
    ) or v_batch.version <> v_expected_batch_version then
    v_error := atlas_core.planning_contract_01_command_error(
      request, v_name, v_contract, 'STALE_VERSION',
      'Cam kết Kế hoạch đã thay đổi; hãy tải lại trước khi hiệu chỉnh.',
      '[]'::jsonb, '[]'::jsonb, v_run.version
    );
    return atlas_core.pa_05b_finish_command(
      v_receipt_id, v_error, false
    );
  end if;
  if v_run.run_status = 'INVALIDATED' then
    v_error := atlas_core.planning_contract_01_command_error(
      request, v_name, v_contract, 'NO_CHANGE',
      'Nhu cầu cũ đã được đưa về lịch sử.'
    );
    return atlas_core.pa_05b_finish_command(
      v_receipt_id, v_error, false
    );
  end if;

  v_chain := atlas_core.issue_222_chain_payload(v_run_id);
  if coalesce((v_chain ->> 'later_downstream_commitment_exists')::boolean, false)
    or coalesce((v_chain ->> 'active_purchase_handoff_exists')::boolean, false)
  then
    v_error := atlas_core.planning_contract_01_command_error(
      request, v_name, v_contract,
      case when (v_chain ->> 'later_downstream_commitment_exists')::boolean
        then 'BLOCKED_BY_DOWNSTREAM_COMMITMENT'
        else 'BLOCKED_BY_PURCHASE_HANDOFF' end,
      'Cam kết đã đi vào Thu mua hoặc vận hành; cần quy trình hiệu chỉnh hạ nguồn riêng.',
      '[]'::jsonb, pg_catalog.jsonb_build_array(v_chain)
    );
    return atlas_core.pa_05b_finish_command(
      v_receipt_id, v_error, false
    );
  end if;

  v_before_run_version := v_run.version;
  v_before_batch_version := v_batch.version;

  -- Re-read after acquiring the Confirmed Need lock. Handoff creation uses
  -- that same root lock, so a prior Handoff is visible and a later one waits.
  v_chain := atlas_core.issue_222_chain_payload(v_run_id);
  if coalesce((v_chain ->> 'later_downstream_commitment_exists')::boolean, false)
    or coalesce((v_chain ->> 'active_purchase_handoff_exists')::boolean, false)
  then
    v_error := atlas_core.planning_contract_01_command_error(
      request, v_name, v_contract,
      case when (v_chain ->> 'later_downstream_commitment_exists')::boolean
        then 'BLOCKED_BY_DOWNSTREAM_COMMITMENT'
        else 'BLOCKED_BY_PURCHASE_HANDOFF' end,
      'Cam kết đã đi vào Thu mua hoặc vận hành; cần quy trình hiệu chỉnh hạ nguồn riêng.',
      '[]'::jsonb, pg_catalog.jsonb_build_array(v_chain)
    );
    return atlas_core.pa_05b_finish_command(
      v_receipt_id, v_error, false
    );
  end if;

  if v_batch.batch_status not in ('DRAFT_REVIEW', 'REOPENED') then
    v_error := atlas_core.pa_05b_authorize_actor(
      request, v_actor_id, 'confirmed_need_release.release',
      'PLANNING', v_name, null, null, null
    );
    if v_error is not null then
      return atlas_core.pa_05b_finish_command(
        v_receipt_id,
        v_error || pg_catalog.jsonb_build_object(
          'contract_version', v_contract
        ),
        false
      );
    end if;
    perform atlas_core.issue_222_reopen_confirmed_need(
      v_batch_id, v_expected_batch_version
    );
    v_action := 'CONFIRMED_NEED_REOPENED';
  elsif v_run.period_start <> v_run.period_end then
    update atlas_planning.need_generation_runs
    set run_status = 'INVALIDATED', version = version + 1,
      invalidated_by_actor_id = v_actor_id,
      invalidated_at = pg_catalog.transaction_timestamp(),
      updated_at = pg_catalog.transaction_timestamp()
    where need_generation_run_id = v_run_id;
    v_action := 'LEGACY_RANGE_INVALIDATED';
  else
    v_error := atlas_core.planning_contract_01_command_error(
      request, v_name, v_contract, 'CORRECTION_ACTION_NOT_REQUIRED',
      'Cam kết hiện tại đã có thể hiệu chỉnh; hãy lưu nguồn rồi tạo lại Nhu cầu.'
    );
    return atlas_core.pa_05b_finish_command(
      v_receipt_id, v_error, false
    );
  end if;

  -- Surface all deferred lifecycle/source/history invariants before returning
  -- a successful command response. A failure rolls the whole command back.
  set constraints all immediate;
  set constraints all deferred;

  select * into strict v_run from atlas_planning.need_generation_runs run
  where run.need_generation_run_id = v_run_id;
  select * into strict v_batch from atlas_planning.confirmed_need_batches batch
  where batch.confirmed_need_batch_id = v_batch_id;
  v_recorded := atlas_core.rmvp_04_record_change(
    request, v_actor_id, v_receipt_id, 'PlanningSourceCorrectionPrepared',
    v_run_id, v_before_run_version, v_run.version,
    pg_catalog.jsonb_build_object(
      'need_generation_run_status', v_chain ->> 'run_status',
      'confirmed_need_status', v_chain ->> 'confirmed_need_status',
      'confirmed_need_batch_version', v_before_batch_version
    ),
    pg_catalog.jsonb_build_object(
      'correction_action', v_action,
      'need_generation_run_status', v_run.run_status,
      'confirmed_need_status', v_batch.batch_status,
      'confirmed_need_batch_version', v_batch.version
    )
  );
  v_response := pg_catalog.jsonb_build_object(
    'success', true, 'contract_version', v_contract,
    'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id',
    'idempotency_status', 'COMPLETED',
    'correction_action', v_action,
    'affected_aggregate_ids', pg_catalog.jsonb_build_object(
      'need_generation_run_id', v_run_id,
      'confirmed_need_batch_id', v_batch_id
    ),
    'new_versions', pg_catalog.jsonb_build_object(
      'need_generation_run_version', v_run.version,
      'confirmed_need_batch_version', v_batch.version
    ),
    'emitted_event_ids', pg_catalog.jsonb_build_array(
      v_recorded -> 'domain_event_id'
    ),
    'audit_event_ids', pg_catalog.jsonb_build_array(
      v_recorded -> 'audit_event_id'
    ),
    'safe_operator_message', case v_action
      when 'CONFIRMED_NEED_REOPENED'
        then 'Đã mở lại cam kết Kế hoạch; có thể lưu nguồn rồi tạo lại Nhu cầu.'
      else 'Đã đưa Nhu cầu nhiều ngày cũ về lịch sử; chưa tự động tạo Nhu cầu ngày.'
    end,
    'warnings', '[]'::jsonb, 'blockers', '[]'::jsonb
  );
  return atlas_core.pa_05b_finish_command(
    v_receipt_id, v_response, true
  );
exception
  when serialization_failure or deadlock_detected
    or lock_not_available or query_canceled then
    v_error := atlas_core.planning_contract_01_command_error(
      request, v_name, v_contract, 'RETRYABLE_CONCURRENCY_FAILURE',
      'Không thể khóa trạng thái hiệu chỉnh an toàn; có thể thử lại đúng yêu cầu.'
    );
    return v_error;
  when others then
    v_error := atlas_core.planning_contract_01_command_error(
      request, v_name, v_contract, 'INTERNAL_COMMAND_FAILURE',
      'Không thể chuẩn bị hiệu chỉnh Kế hoạch một cách an toàn.'
    );
    return v_error;
end;
$$;

revoke execute on function atlas_api.prepare_planning_source_correction(jsonb)
from public, anon, authenticated, service_role;
grant execute on function atlas_api.prepare_planning_source_correction(jsonb)
to authenticated;
comment on function atlas_api.prepare_planning_source_correction(jsonb) is
  'PLANNING-CORRECTION.v1 reasoned reopen or legacy-range retirement command preserving immutable Planning release history.';

reset role;
set role atlas_owner;
revoke create on schema atlas_api from atlas_need_generation_runtime;
comment on schema atlas_api is
  'Function-only Atlas Data API boundary including D-042 closed-loop Planning source correction.';
reset role;
set role atlas_owner;
grant create on schema atlas_api to atlas_read_runtime;
reset role;
alter function atlas_api.get_planning_source_correction_impact(jsonb)
  owner to atlas_read_runtime;
set role atlas_owner;
revoke create on schema atlas_api from atlas_read_runtime;
reset role;
revoke atlas_planning_command_runtime, atlas_need_generation_runtime,
  atlas_confirmed_need_review_runtime, atlas_read_runtime from postgres;
