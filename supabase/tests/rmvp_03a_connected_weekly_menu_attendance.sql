begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;

select is(
  (
    select array_agg(capability_code order by capability_code)::text[]
    from atlas_core.capabilities
    where capability_code like 'planning.%'
      and capability_code in (
        'planning.inputs.read',
        'planning.weekly_menu.write',
        'planning.attendance.write',
        'planning.inputs.approve'
      )
  ),
  array[
    'planning.attendance.write',
    'planning.inputs.approve',
    'planning.inputs.read',
    'planning.weekly_menu.write'
  ]::text[],
  'RMVP-03A registers exactly the four bounded Planning-input capabilities'
);

select is(
  (
    select array_agg(p.proname order by p.proname)::text[]
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname in (
        'get_planning_inputs_workbench',
        'preview_weekly_menu_import',
        'preview_attendance_import',
        'save_weekly_menu_draft',
        'validate_weekly_menu',
        'approve_weekly_menu',
        'reopen_weekly_menu',
        'create_attendance_draft_from_defaults',
        'save_attendance_draft',
        'validate_attendance',
        'approve_attendance',
        'reopen_attendance'
      )
  ),
  array[
    'approve_attendance',
    'approve_weekly_menu',
    'create_attendance_draft_from_defaults',
    'get_planning_inputs_workbench',
    'preview_attendance_import',
    'preview_weekly_menu_import',
    'reopen_attendance',
    'reopen_weekly_menu',
    'save_attendance_draft',
    'save_weekly_menu_draft',
    'validate_attendance',
    'validate_weekly_menu'
  ]::text[],
  'RMVP-03A exposes exactly the twelve requested APIs'
);

select ok(
  (
    select bool_and(
      p.prosecdef
      and p.proconfig = array['search_path=""']::text[]
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')
      and not has_function_privilege('anon', p.oid, 'EXECUTE')
      and not has_function_privilege('service_role', p.oid, 'EXECUTE')
    )
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname in (
        'get_planning_inputs_workbench',
        'preview_weekly_menu_import',
        'preview_attendance_import',
        'save_weekly_menu_draft',
        'validate_weekly_menu',
        'approve_weekly_menu',
        'reopen_weekly_menu',
        'create_attendance_draft_from_defaults',
        'save_attendance_draft',
        'validate_attendance',
        'approve_attendance',
        'reopen_attendance'
      )
  ),
  'all RMVP-03A APIs are fixed-search-path definers with the browser-only boundary'
);

select ok(
  not has_schema_privilege('authenticated', 'atlas_planning', 'USAGE')
  and not has_schema_privilege('anon', 'atlas_planning', 'USAGE')
  and not has_schema_privilege('service_role', 'atlas_planning', 'USAGE'),
  'Weekly Menu and Attendance relations remain private'
);

select ok(
  (
    select p.prosecdef
      and pg_catalog.pg_get_userbyid(p.proowner) = 'atlas_read_runtime'
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_core'
      and p.proname = 'rmvp_03a_planning_workbench_payload'
  )
  and not has_column_privilege(
    'atlas_planning_command_runtime',
    'atlas_audit.audit_events',
    'event_type',
    'SELECT'
  )
  and not has_table_privilege(
    'atlas_planning_command_runtime',
    'atlas_admin.dishes',
    'INSERT'
  )
  and not has_table_privilege(
    'atlas_planning_command_runtime',
    'atlas_admin.recipes',
    'UPDATE'
  ),
  'command readback uses the shaped read owner without raw audit or Admin writes'
);

insert into atlas_core.actors (
  actor_id, actor_type, display_name
) values
  (
    'e3000000-0000-0000-0000-000000000001',
    'HUMAN',
    'RMVP-03A authorized operator'
  ),
  (
    'e3000000-0000-0000-0000-000000000002',
    'HUMAN',
    'RMVP-03A denied operator'
  );

insert into atlas_core.actor_auth_subjects (
  actor_auth_subject_id, actor_id, auth_subject_id
) values
  (
    'e3000000-0000-0000-0000-000000000011',
    'e3000000-0000-0000-0000-000000000001',
    'e3000000-0000-0000-0000-000000000101'
  ),
  (
    'e3000000-0000-0000-0000-000000000012',
    'e3000000-0000-0000-0000-000000000002',
    'e3000000-0000-0000-0000-000000000102'
  );

insert into atlas_core.roles (
  role_id, role_code, role_name
) values
  (
    'e3000000-0000-0000-0000-000000000020',
    'rmvp03a.planning_operator',
    'RMVP-03A Planning operator'
  ),
  (
    'e3000000-0000-0000-0000-000000000021',
    'rmvp03a.no_capability',
    'RMVP-03A no capability'
  );

insert into atlas_core.role_capabilities (role_id, capability_id)
select 'e3000000-0000-0000-0000-000000000020', capability_id
from atlas_core.capabilities
where capability_code in (
  'planning.inputs.read',
  'planning.weekly_menu.write',
  'planning.attendance.write',
  'planning.inputs.approve'
);

insert into atlas_core.actor_role_memberships (actor_id, role_id) values
  (
    'e3000000-0000-0000-0000-000000000001',
    'e3000000-0000-0000-0000-000000000020'
  ),
  (
    'e3000000-0000-0000-0000-000000000002',
    'e3000000-0000-0000-0000-000000000021'
  );

insert into atlas_core.actor_scopes (actor_id, scope_kind) values
  ('e3000000-0000-0000-0000-000000000001', 'GLOBAL'),
  ('e3000000-0000-0000-0000-000000000002', 'GLOBAL');

insert into atlas_admin.customers (
  customer_id, customer_code, customer_name, customer_type
) values (
  'e3100000-0000-0000-0000-000000000001',
  'rmvp03a-customer',
  'RMVP-03A School Customer',
  'SCHOOL_CATERING'
);

insert into atlas_admin.delivery_locations (
  delivery_location_id, customer_id, location_code, location_name,
  address_text
) values (
  'e3100000-0000-0000-0000-000000000002',
  'e3100000-0000-0000-0000-000000000001',
  'rmvp03a-kitchen',
  'RMVP-03A Kitchen',
  'Local test address'
);

insert into atlas_admin.school_types (
  school_type_id, school_type_code, school_type_name
) values (
  'e3100000-0000-0000-0000-000000000003',
  'rmvp03a-primary',
  'RMVP-03A Primary'
);

insert into atlas_admin.schools (
  school_id, customer_id, school_code, school_name, school_type_id,
  default_delivery_location_id, display_order,
  default_student_portions, default_teacher_portions
) values
  (
    'e3100000-0000-0000-0000-000000000010',
    'e3100000-0000-0000-0000-000000000001',
    'rmvp03a-school-a',
    'RMVP-03A School A',
    'e3100000-0000-0000-0000-000000000003',
    'e3100000-0000-0000-0000-000000000002',
    1,
    100,
    10
  ),
  (
    'e3100000-0000-0000-0000-000000000011',
    'e3100000-0000-0000-0000-000000000001',
    'rmvp03a-school-b',
    'RMVP-03A School B',
    'e3100000-0000-0000-0000-000000000003',
    'e3100000-0000-0000-0000-000000000002',
    2,
    0,
    0
  );

insert into atlas_admin.dishes (
  dish_id, dish_code, dish_name, dish_status, display_order,
  requires_need_generation
) values
  (
    'e3100000-0000-0000-0000-000000000020',
    'rmvp03a-soup',
    'RMVP-03A Soup',
    'ACTIVE',
    1,
    false
  ),
  (
    'e3100000-0000-0000-0000-000000000021',
    'rmvp03a-main',
    'RMVP-03A Main',
    'ACTIVE',
    2,
    false
  );

create or replace function pg_temp.rmvp03a_command(
  p_name text,
  p_expected_version bigint,
  p_payload jsonb,
  p_note text default 'Rolled-back RMVP-03A acceptance test.'
)
returns jsonb
language sql
as $$
  select jsonb_build_object(
    'contract_version', 'RMVP-03A.v1',
    'command_id', md5('rmvp03a-command:' || p_name)::uuid,
    'correlation_id', 'e3900000-0000-0000-0000-000000000001',
    'idempotency_key', 'rmvp03a:' || p_name,
    'expected_version', p_expected_version,
    'requested_by_auth_subject',
      'e3000000-0000-0000-0000-000000000101',
    'requested_at', transaction_timestamp() - interval '1 second',
    'reason_code', 'RMVP03A_TEST',
    'reason_note', p_note,
    'payload', p_payload
  );
$$;

create or replace function pg_temp.rmvp03a_read(
  p_payload jsonb,
  p_subject uuid default 'e3000000-0000-0000-0000-000000000101'
)
returns jsonb
language sql
as $$
  select jsonb_build_object(
    'contract_version', 'RMVP-03A.v1',
    'requested_by_auth_subject', p_subject,
    'correlation_id', 'e3900000-0000-0000-0000-000000000002',
    'payload', p_payload
  );
$$;

create or replace function pg_temp.rmvp03a_physical_count(
  p_kind text
)
returns integer
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_kind = 'active_menu_lines' then
    return (
      select count(*)::integer
      from atlas_planning.weekly_menu_lines
      where line_status = 'ACTIVE'
    );
  elsif p_kind = 'all_menu_lines' then
    return (select count(*)::integer from atlas_planning.weekly_menu_lines);
  elsif p_kind = 'invalid_menu_lines' then
    return (
      select count(*)::integer
      from atlas_planning.weekly_menu_lines
      where line_status = 'INVALID'
    );
  elsif p_kind = 'active_attendance_lines' then
    return (
      select count(*)::integer
      from atlas_planning.attendance_lines
      where line_status = 'ACTIVE'
    );
  elsif p_kind = 'all_attendance_lines' then
    return (select count(*)::integer from atlas_planning.attendance_lines);
  elsif p_kind = 'invalid_attendance_lines' then
    return (
      select count(*)::integer
      from atlas_planning.attendance_lines
      where line_status = 'INVALID'
    );
  elsif p_kind = 'menu_snapshot_lines' then
    return (
      select count(*)::integer
      from atlas_planning.weekly_menu_approval_snapshot_lines
    );
  elsif p_kind = 'menu_snapshots' then
    return (
      select count(*)::integer
      from atlas_planning.weekly_menu_approval_snapshots
    );
  elsif p_kind = 'menu_v1_original_lines' then
    return (
      select count(*)::integer
      from atlas_planning.weekly_menu_approval_snapshot_lines line
      where line.weekly_menu_version = 1
        and (
          (
            line.school_id =
              'e3100000-0000-0000-0000-000000000010'
            and line.menu_slot_code = 'soup'
            and line.dish_id =
              'e3100000-0000-0000-0000-000000000020'
          )
          or (
            line.school_id =
              'e3100000-0000-0000-0000-000000000011'
            and line.menu_slot_code = 'savory'
            and line.dish_id =
              'e3100000-0000-0000-0000-000000000021'
          )
        )
    );
  elsif p_kind = 'menu_v2_corrected_lines' then
    return (
      select count(*)::integer
      from atlas_planning.weekly_menu_approval_snapshot_lines line
      where line.weekly_menu_version = 2
        and line.dish_id =
          'e3100000-0000-0000-0000-000000000021'
    );
  elsif p_kind = 'attendance_snapshot_lines' then
    return (
      select count(*)::integer
      from atlas_planning.attendance_approval_snapshot_lines
    );
  elsif p_kind = 'attendance_snapshots' then
    return (
      select count(*)::integer
      from atlas_planning.attendance_approval_snapshots
    );
  elsif p_kind = 'attendance_v1_original_lines' then
    return (
      select count(*)::integer
      from atlas_planning.attendance_approval_snapshot_lines line
      where line.attendance_version = 1
        and (
          (
            line.school_id =
              'e3100000-0000-0000-0000-000000000010'
            and line.student_portions = 100
            and line.teacher_portions = 10
          )
          or (
            line.school_id =
              'e3100000-0000-0000-0000-000000000011'
            and line.student_portions = 0
            and line.teacher_portions = 0
          )
        )
    );
  elsif p_kind = 'attendance_v2_corrected_lines' then
    return (
      select count(*)::integer
      from atlas_planning.attendance_approval_snapshot_lines line
      where line.attendance_version = 2
        and (
          (
            line.school_id =
              'e3100000-0000-0000-0000-000000000010'
            and line.student_portions = 101
            and line.teacher_portions = 11
          )
          or (
            line.school_id =
              'e3100000-0000-0000-0000-000000000011'
            and line.student_portions = 0
            and line.teacher_portions = 0
          )
        )
    );
  elsif p_kind = 'attendance_stable_snapshot_links' then
    return (
      select count(*)::integer
      from atlas_planning.attendance_lines line
      join atlas_planning.attendance_approval_snapshot_lines snapshot_line
        on snapshot_line.attendance_line_id = line.attendance_line_id
      where line.line_status = 'ACTIVE'
    );
  elsif p_kind = 'planning_events' then
    return (
      select count(*)::integer
      from atlas_audit.domain_events
      where source_domain = 'PLANNING'
        and aggregate_type in ('WeeklyMenu', 'AttendanceBatch')
    );
  elsif p_kind = 'planning_input_sets' then
    return (select count(*)::integer from atlas_planning.planning_input_sets);
  elsif p_kind = 'need_generation_runs' then
    return (select count(*)::integer from atlas_planning.need_generation_runs);
  end if;
  return -1;
end;
$$;

create temporary table rmvp03a_results (
  result_name text primary key,
  response_payload jsonb not null
);
grant select, insert on rmvp03a_results to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'e3000000-0000-0000-0000-000000000101',
  true
);

insert into rmvp03a_results values (
  'menu-preview-a',
  atlas_api.preview_weekly_menu_import(
    pg_temp.rmvp03a_read(
      jsonb_build_object(
        'week_start', '2026-08-03',
        'rows', jsonb_build_array(
          jsonb_build_object(),
          jsonb_build_object(
            'school_id', 'e3100000-0000-0000-0000-000000000011',
            'service_date', '2026-08-03',
            'menu_slot_code', 'SAVORY',
            'dish_id', 'e3100000-0000-0000-0000-000000000021',
            'source_row_reference', 'sheet:3'
          ),
          jsonb_build_object(
            'school_id', 'e3100000-0000-0000-0000-000000000010',
            'service_date', '2026-08-03',
            'menu_slot_code', ' soup ',
            'dish_id', 'e3100000-0000-0000-0000-000000000020',
            'source_row_reference', 'sheet:2'
          )
        )
      )
    )
  )
);

insert into rmvp03a_results values (
  'menu-preview-b',
  atlas_api.preview_weekly_menu_import(
    pg_temp.rmvp03a_read(
      jsonb_build_object(
        'week_start', '2026-08-03',
        'rows', jsonb_build_array(
          jsonb_build_object(
            'school_id', 'e3100000-0000-0000-0000-000000000010',
            'service_date', '2026-08-03',
            'menu_slot_code', 'soup',
            'dish_id', 'e3100000-0000-0000-0000-000000000020',
            'source_row_reference', 'different-reference'
          ),
          jsonb_build_object(
            'school_id', 'e3100000-0000-0000-0000-000000000011',
            'service_date', '2026-08-03',
            'menu_slot_code', 'savory',
            'dish_id', 'e3100000-0000-0000-0000-000000000021',
            'source_row_reference', 'another-reference'
          )
        )
      )
    )
  )
);

select is(
  (
    select response_payload -> 'preview' ->> 'source_signature'
    from rmvp03a_results where result_name = 'menu-preview-a'
  ),
  (
    select response_payload -> 'preview' ->> 'source_signature'
    from rmvp03a_results where result_name = 'menu-preview-b'
  ),
  'menu checksum is independent of row order, blank rows, and source-row labels'
);

select is(
  (
    select jsonb_array_length(
      response_payload -> 'preview' -> 'canonical_rows'
    )
    from rmvp03a_results where result_name = 'menu-preview-a'
  ),
  2,
  'menu preview omits harmless blank rows while preserving two source rows'
);

select is(
  (
    select response_payload -> 'preview' -> 'comparison'
      ->> 'new_assignments'
    from rmvp03a_results where result_name = 'menu-preview-a'
  ),
  '2',
  'menu preview reports the two new assignments before any write'
);

select is(
  (
    select array_agg(
      row ->> 'source_row_reference'
      order by row ->> 'source_row_reference'
    )::text[]
    from rmvp03a_results result
    cross join lateral jsonb_array_elements(
      result.response_payload -> 'preview' -> 'canonical_rows'
    ) row
    where result.result_name = 'menu-preview-a'
  ),
  array['sheet:2', 'sheet:3']::text[],
  'canonical Menu rows preserve normalized source-row evidence'
);

select is(
  (
    select atlas_api.preview_weekly_menu_import(
      pg_temp.rmvp03a_read(
        jsonb_build_object(
          'week_start', '2026-08-03',
          'source_signature',
            original.response_payload -> 'preview' ->> 'source_signature',
          'rows', jsonb_build_array(
            original.response_payload -> 'preview'
              -> 'canonical_rows' -> 0
          )
        )
      )
    ) -> 'preview' -> 'issues' -> 'blockers' -> 0 ->> 'code'
    from rmvp03a_results original
    where original.result_name = 'menu-preview-a'
  ),
  'CHECKSUM_MISMATCH',
  'a reused signature with different canonical content fails closed'
);

insert into rmvp03a_results
select
  'menu-save',
  atlas_api.save_weekly_menu_draft(
    pg_temp.rmvp03a_command(
      'menu-save',
      1,
      jsonb_build_object(
        'week_start', '2026-08-03',
        'source_type', 'WORKBOOK_IMPORT',
        'source_name', 'OPS Menu Weekly',
        'source_signature',
          preview.response_payload -> 'preview' ->> 'source_signature',
        'expected_source_signature', null,
        'rows',
          preview.response_payload -> 'preview' -> 'canonical_rows'
      )
    )
  )
from rmvp03a_results preview
where preview.result_name = 'menu-preview-a';

select is(
  (
    select response_payload ->> 'success'
    from rmvp03a_results where result_name = 'menu-save'
  ),
  'true',
  'authorized menu draft save succeeds'
);

select is(
  pg_temp.rmvp03a_physical_count('active_menu_lines'),
  2,
  'menu draft persists exactly two active stable assignment rows'
);

insert into rmvp03a_results
select
  'menu-preview-omit',
  atlas_api.preview_weekly_menu_import(
    pg_temp.rmvp03a_read(
      jsonb_build_object(
        'week_start', '2026-08-03',
        'rows', jsonb_build_array(
          source.response_payload -> 'preview' -> 'canonical_rows' -> 0
        )
      )
    )
  )
from rmvp03a_results source
where source.result_name = 'menu-preview-a';

insert into rmvp03a_results
select
  'menu-omit',
  atlas_api.save_weekly_menu_draft(
    pg_temp.rmvp03a_command(
      'menu-omit',
      1,
      jsonb_build_object(
        'week_start', '2026-08-03',
        'source_type', 'WORKBOOK_IMPORT',
        'source_name', 'OPS Menu Weekly',
        'source_signature',
          omitted.response_payload -> 'preview' ->> 'source_signature',
        'expected_source_signature',
          original.response_payload -> 'preview' ->> 'source_signature',
        'rows',
          omitted.response_payload -> 'preview' -> 'canonical_rows'
      )
    )
  )
from rmvp03a_results omitted
cross join rmvp03a_results original
where omitted.result_name = 'menu-preview-omit'
  and original.result_name = 'menu-preview-a';

select is(
  jsonb_build_object(
    'all', pg_temp.rmvp03a_physical_count('all_menu_lines'),
    'active', pg_temp.rmvp03a_physical_count('active_menu_lines'),
    'invalid', pg_temp.rmvp03a_physical_count('invalid_menu_lines')
  ),
  jsonb_build_object('all', 2, 'active', 1, 'invalid', 1),
  'omitted menu assignment is invalidated without deleting or duplicating its stable line'
);

insert into rmvp03a_results
select
  'menu-restore',
  atlas_api.save_weekly_menu_draft(
    pg_temp.rmvp03a_command(
      'menu-restore',
      1,
      jsonb_build_object(
        'week_start', '2026-08-03',
        'source_type', 'WORKBOOK_IMPORT',
        'source_name', 'OPS Menu Weekly',
        'source_signature',
          original.response_payload -> 'preview' ->> 'source_signature',
        'expected_source_signature',
          omitted.response_payload -> 'preview' ->> 'source_signature',
        'rows',
          original.response_payload -> 'preview' -> 'canonical_rows'
      )
    )
  )
from rmvp03a_results original
cross join rmvp03a_results omitted
where original.result_name = 'menu-preview-a'
  and omitted.result_name = 'menu-preview-omit';

select is(
  jsonb_build_object(
    'all', pg_temp.rmvp03a_physical_count('all_menu_lines'),
    'active', pg_temp.rmvp03a_physical_count('active_menu_lines'),
    'invalid', pg_temp.rmvp03a_physical_count('invalid_menu_lines')
  ),
  jsonb_build_object('all', 2, 'active', 2, 'invalid', 0),
  'restored menu assignment reactivates the same stable line'
);

insert into rmvp03a_results
select
  'menu-source-conflict',
  atlas_api.save_weekly_menu_draft(
    pg_temp.rmvp03a_command(
      'menu-source-conflict',
      1,
      jsonb_build_object(
        'week_start', '2026-08-03',
        'source_type', 'WORKBOOK_IMPORT',
        'source_name', 'OPS Menu Weekly',
        'source_signature',
          preview.response_payload -> 'preview' ->> 'source_signature',
        'expected_source_signature', repeat('0', 64),
        'rows',
          preview.response_payload -> 'preview' -> 'canonical_rows'
      )
    )
  )
from rmvp03a_results preview
where preview.result_name = 'menu-preview-a';

select is(
  (
    select response_payload ->> 'error_code'
    from rmvp03a_results
    where result_name = 'menu-source-conflict'
  ),
  'STALE_SOURCE_SIGNATURE',
  'changed persisted source signature fails closed before draft replacement'
);

insert into rmvp03a_results
select
  'menu-save-replay',
  atlas_api.save_weekly_menu_draft(
    pg_temp.rmvp03a_command(
      'menu-save',
      1,
      jsonb_build_object(
        'week_start', '2026-08-03',
        'source_type', 'WORKBOOK_IMPORT',
        'source_name', 'OPS Menu Weekly',
        'source_signature',
          preview.response_payload -> 'preview' ->> 'source_signature',
        'expected_source_signature', null,
        'rows',
          preview.response_payload -> 'preview' -> 'canonical_rows'
      )
    )
  )
from rmvp03a_results preview
where preview.result_name = 'menu-preview-a';

select is(
  (
    select response_payload from rmvp03a_results
    where result_name = 'menu-save-replay'
  ),
  (
    select response_payload from rmvp03a_results
    where result_name = 'menu-save'
  ),
  'exact menu command replay returns the original durable response'
);

insert into rmvp03a_results
select
  'menu-no-change',
  atlas_api.save_weekly_menu_draft(
    pg_temp.rmvp03a_command(
      'menu-no-change',
      1,
      jsonb_build_object(
        'week_start', '2026-08-03',
        'source_type', 'WORKBOOK_IMPORT',
        'source_name', 'OPS Menu Weekly',
        'source_signature',
          preview.response_payload -> 'preview' ->> 'source_signature',
        'expected_source_signature',
          preview.response_payload -> 'preview' ->> 'source_signature',
        'rows',
          preview.response_payload -> 'preview' -> 'canonical_rows'
      )
    )
  )
from rmvp03a_results preview
where preview.result_name = 'menu-preview-a';

select is(
  (
    select response_payload ->> 'idempotency_status'
    from rmvp03a_results where result_name = 'menu-no-change'
  ),
  'NO_CHANGE',
  'exact canonical menu replacement is a no-write success'
);

insert into rmvp03a_results values (
  'menu-validate',
  atlas_api.validate_weekly_menu(
    pg_temp.rmvp03a_command(
      'menu-validate',
      1,
      jsonb_build_object('week_start', '2026-08-03')
    )
  )
);
insert into rmvp03a_results values (
  'menu-approve',
  atlas_api.approve_weekly_menu(
    pg_temp.rmvp03a_command(
      'menu-approve',
      1,
      jsonb_build_object('week_start', '2026-08-03')
    )
  )
);

select is(
  (
    select response_payload -> 'authoritative_readback'
      -> 'weekly_menu' ->> 'weekly_menu_status'
    from rmvp03a_results where result_name = 'menu-approve'
  ),
  'APPROVED',
  'menu validates and approves through the authoritative lifecycle'
);

select is(
  pg_temp.rmvp03a_physical_count('menu_snapshot_lines'),
  2,
  'menu approval snapshot contains the exact two active assignments'
);

insert into rmvp03a_results values (
  'menu-reopen-without-note',
  atlas_api.reopen_weekly_menu(
    pg_temp.rmvp03a_command(
      'menu-reopen-without-note',
      1,
      jsonb_build_object('week_start', '2026-08-03'),
      ''
    )
  )
);

select is(
  (
    select response_payload ->> 'error_code'
    from rmvp03a_results
    where result_name = 'menu-reopen-without-note'
  ),
  'VALIDATION_FAILED',
  'menu reopen fails closed without a reason note'
);

insert into rmvp03a_results values (
  'menu-reopen',
  atlas_api.reopen_weekly_menu(
    pg_temp.rmvp03a_command(
      'menu-reopen',
      1,
      jsonb_build_object('week_start', '2026-08-03'),
      'Correct the approved service menu.'
    )
  )
);

select is(
  (
    select response_payload -> 'authoritative_readback'
      -> 'weekly_menu' ->> 'weekly_menu_status'
    from rmvp03a_results where result_name = 'menu-reopen'
  ),
  'REOPENED',
  'menu reopen creates the next working lifecycle state'
);

select is(
  (
    select (
      response_payload -> 'authoritative_readback'
        -> 'weekly_menu' ->> 'version'
    )::integer
    from rmvp03a_results where result_name = 'menu-reopen'
  ),
  2,
  'menu reopen advances the working version exactly once'
);

insert into rmvp03a_results values (
  'menu-correction-preview',
  atlas_api.preview_weekly_menu_import(
    pg_temp.rmvp03a_read(
      jsonb_build_object(
        'week_start', '2026-08-03',
        'rows', jsonb_build_array(
          jsonb_build_object(
            'school_id', 'e3100000-0000-0000-0000-000000000010',
            'service_date', '2026-08-03',
            'menu_slot_code', 'soup',
            'dish_id', 'e3100000-0000-0000-0000-000000000021',
            'source_row_reference', 'correction:2'
          ),
          jsonb_build_object(
            'school_id', 'e3100000-0000-0000-0000-000000000011',
            'service_date', '2026-08-03',
            'menu_slot_code', 'savory',
            'dish_id', 'e3100000-0000-0000-0000-000000000021',
            'source_row_reference', 'correction:3'
          )
        )
      )
    )
  )
);

insert into rmvp03a_results
select
  'menu-resave-after-reopen',
  atlas_api.save_weekly_menu_draft(
    pg_temp.rmvp03a_command(
      'menu-resave-after-reopen',
      2,
      jsonb_build_object(
        'week_start', '2026-08-03',
        'source_type',
          reopened.response_payload -> 'authoritative_readback'
            -> 'weekly_menu' ->> 'source_type',
        'source_name',
          reopened.response_payload -> 'authoritative_readback'
            -> 'weekly_menu' ->> 'source_name',
        'source_signature',
          preview.response_payload -> 'preview' ->> 'source_signature',
        'expected_source_signature',
          reopened.response_payload -> 'authoritative_readback'
            -> 'weekly_menu' ->> 'source_signature',
        'rows', preview.response_payload -> 'preview' -> 'canonical_rows'
      )
    )
  )
from rmvp03a_results reopened
cross join rmvp03a_results preview
where reopened.result_name = 'menu-reopen'
  and preview.result_name = 'menu-correction-preview';

insert into rmvp03a_results values (
  'menu-revalidate',
  atlas_api.validate_weekly_menu(
    pg_temp.rmvp03a_command(
      'menu-revalidate',
      2,
      jsonb_build_object('week_start', '2026-08-03')
    )
  )
);
insert into rmvp03a_results values (
  'menu-reapprove',
  atlas_api.approve_weekly_menu(
    pg_temp.rmvp03a_command(
      'menu-reapprove',
      2,
      jsonb_build_object('week_start', '2026-08-03')
    )
  )
);

select is(
  jsonb_build_object(
    'snapshots',
      pg_temp.rmvp03a_physical_count('menu_snapshots'),
    'snapshot_lines',
      pg_temp.rmvp03a_physical_count('menu_snapshot_lines')
  ),
  jsonb_build_object('snapshots', 2, 'snapshot_lines', 4),
  'menu reapproval appends a second exact snapshot without changing the first'
);

select is(
  jsonb_build_object(
    'version_1_original_lines',
      pg_temp.rmvp03a_physical_count('menu_v1_original_lines'),
    'version_2_corrected_lines',
      pg_temp.rmvp03a_physical_count('menu_v2_corrected_lines')
  ),
  jsonb_build_object(
    'version_1_original_lines', 2,
    'version_2_corrected_lines', 2
  ),
  'menu correction changes the stable working line while the first snapshot stays exact'
);

insert into rmvp03a_results values (
  'workbench-before-attendance',
  atlas_api.get_planning_inputs_workbench(
    pg_temp.rmvp03a_read(
      jsonb_build_object('week_start', '2026-08-03')
    )
  )
);

insert into rmvp03a_results
select
  'attendance-default-preview',
  atlas_api.preview_attendance_import(
    pg_temp.rmvp03a_read(
      jsonb_build_object(
        'week_start', '2026-08-03',
        'rows',
          source.response_payload -> 'workbench'
            -> 'default_attendance_preview'
      )
    )
  )
from rmvp03a_results source
where source.result_name = 'workbench-before-attendance';

insert into rmvp03a_results
select
  'attendance-default-create',
  atlas_api.create_attendance_draft_from_defaults(
    pg_temp.rmvp03a_command(
      'attendance-default-create',
      1,
      jsonb_build_object(
        'week_start', '2026-08-03',
        'source_signature',
          source.response_payload -> 'preview' ->> 'source_signature',
        'expected_source_signature', null
      )
    )
  )
from rmvp03a_results source
where source.result_name = 'attendance-default-preview';

select is(
  (
    select jsonb_array_length(
      response_payload -> 'authoritative_readback'
        -> 'attendance' -> 'lines'
    )
    from rmvp03a_results
    where result_name = 'attendance-default-create'
  ),
  2,
  'attendance defaults use the two menu school/date pairs, not an implicit today'
);

select ok(
  (
    select response_payload -> 'preview' -> 'issues' -> 'warnings'
      @> jsonb_build_array(
        jsonb_build_object(
          'code', 'ZERO_TOTAL_PORTIONS',
          'message',
            'Student and teacher portions total zero for this school and date.',
          'source_row_reference', 'default:rmvp03a-school-b:2026-08-03'
        )
      )
    from rmvp03a_results
    where result_name = 'attendance-default-preview'
  ),
  'explicit zero default is retained and visible as a warning'
);

insert into rmvp03a_results values (
  'attendance-negative-preview',
  atlas_api.preview_attendance_import(
    pg_temp.rmvp03a_read(
      jsonb_build_object(
        'week_start', '2026-08-03',
        'rows', jsonb_build_array(
          jsonb_build_object(
            'school_id', 'e3100000-0000-0000-0000-000000000010',
            'service_date', '2026-08-03',
            'student_portions', -1,
            'teacher_portions', 0,
            'source_row_reference', 'negative:1'
          )
        )
      )
    )
  )
);

select ok(
  (
    select response_payload -> 'preview' -> 'issues' -> 'blockers'
      @> jsonb_build_array(
        jsonb_build_object(
          'code', 'INVALID_STUDENT_PORTIONS',
          'message',
            'Student portions must be an explicit non-negative integer.',
          'source_row_reference', 'negative:1'
        )
      )
    from rmvp03a_results
    where result_name = 'attendance-negative-preview'
  ),
  'negative Attendance input is blocked without being inferred as zero'
);

insert into rmvp03a_results
select
  'attendance-preview-omit',
  atlas_api.preview_attendance_import(
    pg_temp.rmvp03a_read(
      jsonb_build_object(
        'week_start', '2026-08-03',
        'rows', jsonb_build_array(
          source.response_payload -> 'preview' -> 'canonical_rows' -> 0
        )
      )
    )
  )
from rmvp03a_results source
where source.result_name = 'attendance-default-preview';

insert into rmvp03a_results
select
  'attendance-omit',
  atlas_api.save_attendance_draft(
    pg_temp.rmvp03a_command(
      'attendance-omit',
      1,
      jsonb_build_object(
        'week_start', '2026-08-03',
        'source_type', 'SCHOOL_DEFAULTS',
        'source_name', 'School defaults for 2026-08-03',
        'source_signature',
          omitted.response_payload -> 'preview' ->> 'source_signature',
        'expected_source_signature',
          created.response_payload -> 'authoritative_readback'
            -> 'attendance' ->> 'source_signature',
        'rows',
          omitted.response_payload -> 'preview' -> 'canonical_rows'
      )
    )
  )
from rmvp03a_results omitted
cross join rmvp03a_results created
where omitted.result_name = 'attendance-preview-omit'
  and created.result_name = 'attendance-default-create';

select is(
  jsonb_build_object(
    'all', pg_temp.rmvp03a_physical_count('all_attendance_lines'),
    'active', pg_temp.rmvp03a_physical_count('active_attendance_lines'),
    'invalid', pg_temp.rmvp03a_physical_count('invalid_attendance_lines')
  ),
  jsonb_build_object('all', 2, 'active', 1, 'invalid', 1),
  'omitted Attendance row is invalidated without deleting its stable line'
);

insert into rmvp03a_results
select
  'attendance-restore',
  atlas_api.save_attendance_draft(
    pg_temp.rmvp03a_command(
      'attendance-restore',
      1,
      jsonb_build_object(
        'week_start', '2026-08-03',
        'source_type', 'SCHOOL_DEFAULTS',
        'source_name', 'School defaults for 2026-08-03',
        'source_signature',
          original.response_payload -> 'preview' ->> 'source_signature',
        'expected_source_signature',
          omitted.response_payload -> 'preview' ->> 'source_signature',
        'rows',
          original.response_payload -> 'preview' -> 'canonical_rows'
      )
    )
  )
from rmvp03a_results original
cross join rmvp03a_results omitted
where original.result_name = 'attendance-default-preview'
  and omitted.result_name = 'attendance-preview-omit';

select is(
  jsonb_build_object(
    'all', pg_temp.rmvp03a_physical_count('all_attendance_lines'),
    'active', pg_temp.rmvp03a_physical_count('active_attendance_lines'),
    'invalid', pg_temp.rmvp03a_physical_count('invalid_attendance_lines')
  ),
  jsonb_build_object('all', 2, 'active', 2, 'invalid', 0),
  'restored Attendance row reactivates the same stable line'
);

insert into rmvp03a_results values (
  'attendance-validate',
  atlas_api.validate_attendance(
    pg_temp.rmvp03a_command(
      'attendance-validate',
      1,
      jsonb_build_object('week_start', '2026-08-03')
    )
  )
);
insert into rmvp03a_results values (
  'attendance-approve',
  atlas_api.approve_attendance(
    pg_temp.rmvp03a_command(
      'attendance-approve',
      1,
      jsonb_build_object('week_start', '2026-08-03')
    )
  )
);

select is(
  (
    select response_payload -> 'authoritative_readback'
      -> 'attendance' ->> 'attendance_status'
    from rmvp03a_results where result_name = 'attendance-approve'
  ),
  'APPROVED',
  'attendance validates and approves through the authoritative lifecycle'
);

select is(
  pg_temp.rmvp03a_physical_count('attendance_snapshot_lines'),
  2,
  'attendance approval snapshot contains the exact two active rows'
);

select is(
  pg_temp.rmvp03a_physical_count('attendance_stable_snapshot_links'),
  2,
  'attendance approval snapshot retains the exact stable working line identities'
);

insert into rmvp03a_results values (
  'attendance-reopen',
  atlas_api.reopen_attendance(
    pg_temp.rmvp03a_command(
      'attendance-reopen',
      1,
      jsonb_build_object('week_start', '2026-08-03'),
      'Correct the approved attendance count.'
    )
  )
);

select is(
  (
    select response_payload -> 'authoritative_readback'
      -> 'attendance' ->> 'attendance_status'
    from rmvp03a_results where result_name = 'attendance-reopen'
  ),
  'REOPENED',
  'attendance reopen enters the installed correction lifecycle'
);

select is(
  (
    select (
      response_payload -> 'authoritative_readback'
        -> 'attendance' ->> 'version'
    )::integer
    from rmvp03a_results where result_name = 'attendance-reopen'
  ),
  2,
  'attendance reopen advances the working version exactly once'
);

insert into rmvp03a_results values (
  'attendance-correction-preview',
  atlas_api.preview_attendance_import(
    pg_temp.rmvp03a_read(
      jsonb_build_object(
        'week_start', '2026-08-03',
        'rows', jsonb_build_array(
          jsonb_build_object(
            'school_id', 'e3100000-0000-0000-0000-000000000010',
            'service_date', '2026-08-03',
            'student_portions', 101,
            'teacher_portions', 11,
            'source_row_reference', 'attendance-correction:2'
          ),
          jsonb_build_object(
            'school_id', 'e3100000-0000-0000-0000-000000000011',
            'service_date', '2026-08-03',
            'student_portions', 0,
            'teacher_portions', 0,
            'source_row_reference', 'attendance-correction:3'
          )
        )
      )
    )
  )
);

insert into rmvp03a_results
select
  'attendance-resave-after-reopen',
  atlas_api.save_attendance_draft(
    pg_temp.rmvp03a_command(
      'attendance-resave-after-reopen',
      2,
      jsonb_build_object(
        'week_start', '2026-08-03',
        'source_type',
          reopened.response_payload -> 'authoritative_readback'
            -> 'attendance' ->> 'source_type',
        'source_name',
          reopened.response_payload -> 'authoritative_readback'
            -> 'attendance' ->> 'source_name',
        'source_signature',
          preview.response_payload -> 'preview' ->> 'source_signature',
        'expected_source_signature',
          reopened.response_payload -> 'authoritative_readback'
            -> 'attendance' ->> 'source_signature',
        'rows', preview.response_payload -> 'preview' -> 'canonical_rows'
      )
    )
  )
from rmvp03a_results reopened
cross join rmvp03a_results preview
where reopened.result_name = 'attendance-reopen'
  and preview.result_name = 'attendance-correction-preview';

insert into rmvp03a_results values (
  'attendance-revalidate',
  atlas_api.validate_attendance(
    pg_temp.rmvp03a_command(
      'attendance-revalidate',
      2,
      jsonb_build_object('week_start', '2026-08-03')
    )
  )
);
insert into rmvp03a_results values (
  'attendance-reapprove',
  atlas_api.approve_attendance(
    pg_temp.rmvp03a_command(
      'attendance-reapprove',
      2,
      jsonb_build_object('week_start', '2026-08-03')
    )
  )
);

select is(
  jsonb_build_object(
    'snapshots',
      pg_temp.rmvp03a_physical_count('attendance_snapshots'),
    'snapshot_lines',
      pg_temp.rmvp03a_physical_count('attendance_snapshot_lines')
  ),
  jsonb_build_object('snapshots', 2, 'snapshot_lines', 4),
  'attendance reapproval appends a second exact snapshot'
);

select is(
  jsonb_build_object(
    'version_1_original_lines',
      pg_temp.rmvp03a_physical_count('attendance_v1_original_lines'),
    'version_2_corrected_lines',
      pg_temp.rmvp03a_physical_count('attendance_v2_corrected_lines')
  ),
  jsonb_build_object(
    'version_1_original_lines', 2,
    'version_2_corrected_lines', 2
  ),
  'attendance correction reuses stable rows while the first snapshot stays exact'
);

insert into rmvp03a_results values (
  'attendance-stale-validate',
  atlas_api.validate_attendance(
    pg_temp.rmvp03a_command(
      'attendance-stale-validate',
      99,
      jsonb_build_object('week_start', '2026-08-03')
    )
  )
);

select is(
  (
    select response_payload ->> 'error_code'
    from rmvp03a_results
    where result_name = 'attendance-stale-validate'
  ),
  'STALE_VERSION',
  'stale Attendance lifecycle request fails closed before status handling'
);

select ok(
  (
    select (
      response_payload -> 'authoritative_readback'
        -> 'readiness' ->> 'ready'
    )::boolean
    from rmvp03a_results where result_name = 'attendance-reapprove'
  ),
  'readiness comparison becomes true only after both inputs are approved'
);

select ok(
  jsonb_array_length(
    atlas_api.get_planning_inputs_workbench(
      pg_temp.rmvp03a_read(
        jsonb_build_object('week_start', '2026-08-03')
      )
    ) -> 'workbench' -> 'weekly_menu' -> 'change_history'
  ) > 0,
  'Weekly Menu workbench includes expandable command-audit history'
);

select ok(
  jsonb_array_length(
    atlas_api.get_planning_inputs_workbench(
      pg_temp.rmvp03a_read(
        jsonb_build_object('week_start', '2026-08-03')
      )
    ) -> 'workbench' -> 'attendance' -> 'change_history'
  ) > 0,
  'Attendance workbench includes expandable command-audit history'
);

select is(
  (
    atlas_api.get_planning_inputs_workbench(
      pg_temp.rmvp03a_read(
        jsonb_build_object('week_start', '2026-08-03'),
        'e3000000-0000-0000-0000-000000000102'
      )
    ) ->> 'error_code'
  ),
  'AUTH_SUBJECT_MISMATCH',
  'a caller cannot substitute a different bound auth subject'
);

select set_config(
  'request.jwt.claim.sub',
  'e3000000-0000-0000-0000-000000000102',
  true
);
select is(
  (
    atlas_api.get_planning_inputs_workbench(
      pg_temp.rmvp03a_read(
        jsonb_build_object('week_start', '2026-08-03'),
        'e3000000-0000-0000-0000-000000000102'
      )
    ) ->> 'error_code'
  ),
  'CAPABILITY_DENIED',
  'an authenticated actor without the Planning read capability fails closed'
);
select set_config(
  'request.jwt.claim.sub',
  'e3000000-0000-0000-0000-000000000101',
  true
);

select ok(
  pg_temp.rmvp03a_physical_count('planning_events') = 18,
  'state-changing menu and attendance commands emit one event each while no-change does not'
);

select is(
  jsonb_build_object(
    'planning_input_sets',
      pg_temp.rmvp03a_physical_count('planning_input_sets'),
    'need_generation_runs',
      pg_temp.rmvp03a_physical_count('need_generation_runs')
  ),
  jsonb_build_object(
    'planning_input_sets', 0,
    'need_generation_runs', 0
  ),
  'Planning Input Readiness and Need Generation relations remain untouched'
);

reset role;

select *
from finish();

rollback;
