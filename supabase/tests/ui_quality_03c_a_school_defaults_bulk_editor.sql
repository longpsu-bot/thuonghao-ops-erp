begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

select ok(
  exists (
    select 1
    from pg_proc function_object
    join pg_namespace namespace_object
      on namespace_object.oid = function_object.pronamespace
    join pg_roles owner_role on owner_role.oid = function_object.proowner
    where namespace_object.nspname = 'atlas_api'
      and function_object.proname = 'update_school_portion_defaults_bulk'
      and pg_get_function_identity_arguments(function_object.oid) = 'request jsonb'
      and function_object.prosecdef
      and function_object.proconfig::text like '%search_path=%'
      and owner_role.rolname = 'atlas_master_data_command_runtime'
  ),
  '03C-A bulk command is an empty-search-path definer owned by the existing runtime'
);

select ok(
  has_function_privilege(
    'authenticated',
    'atlas_api.update_school_portion_defaults_bulk(jsonb)',
    'EXECUTE'
  ),
  'authenticated may execute the bulk command'
);
select ok(
  not has_function_privilege(
    'anon',
    'atlas_api.update_school_portion_defaults_bulk(jsonb)',
    'EXECUTE'
  ),
  'anon cannot execute the bulk command'
);
select ok(
  not has_function_privilege(
    'service_role',
    'atlas_api.update_school_portion_defaults_bulk(jsonb)',
    'EXECUTE'
  ),
  'service_role cannot execute the bulk command'
);
select is(
  (
    select count(*)::integer
    from atlas_core.capabilities
    where capability_code = 'master_data.schools.write'
      and capability_status = 'ACTIVE'
  ),
  1,
  'the existing active master_data.schools.write capability is reused'
);
select ok(
  not exists (
    select 1
    from atlas_core.capabilities
    where capability_code like '%school%bulk%'
       or capability_code like '%bulk%school%'
  ),
  'no bulk-specific School capability exists'
);

insert into atlas_core.actors (actor_id, actor_type, display_name) values
  (
    'c3100000-0000-0000-0000-000000000001',
    'HUMAN',
    'UI-QUALITY-03C-A authorized operator'
  ),
  (
    'c3100000-0000-0000-0000-000000000002',
    'HUMAN',
    'UI-QUALITY-03C-A denied operator'
  );

insert into atlas_core.actor_auth_subjects (
  actor_auth_subject_id,
  actor_id,
  auth_subject_id
) values
  (
    'c3100000-0000-0000-0000-000000000011',
    'c3100000-0000-0000-0000-000000000001',
    'c3100000-0000-0000-0000-000000000101'
  ),
  (
    'c3100000-0000-0000-0000-000000000012',
    'c3100000-0000-0000-0000-000000000002',
    'c3100000-0000-0000-0000-000000000102'
  );

insert into atlas_core.roles (role_id, role_code, role_name) values
  (
    'c3100000-0000-0000-0000-000000000020',
    'ui_quality_03c_a.school_defaults_operator',
    'UI-QUALITY-03C-A School defaults operator'
  ),
  (
    'c3100000-0000-0000-0000-000000000021',
    'ui_quality_03c_a.no_capability',
    'UI-QUALITY-03C-A no capability'
  );

insert into atlas_core.role_capabilities (role_id, capability_id)
select
  'c3100000-0000-0000-0000-000000000020',
  capability_id
from atlas_core.capabilities
where capability_code = 'master_data.schools.write';

insert into atlas_core.actor_role_memberships (actor_id, role_id) values
  (
    'c3100000-0000-0000-0000-000000000001',
    'c3100000-0000-0000-0000-000000000020'
  ),
  (
    'c3100000-0000-0000-0000-000000000002',
    'c3100000-0000-0000-0000-000000000021'
  );

insert into atlas_core.actor_scopes (actor_id, scope_kind) values
  ('c3100000-0000-0000-0000-000000000001', 'GLOBAL'),
  ('c3100000-0000-0000-0000-000000000002', 'GLOBAL');

insert into atlas_admin.customers (
  customer_id,
  customer_code,
  customer_name,
  customer_type
) values (
  'c3200000-0000-0000-0000-000000000001',
  'uiq03ca-customer',
  'UI-QUALITY-03C-A Customer',
  'SCHOOL_CATERING'
);

insert into atlas_admin.delivery_locations (
  delivery_location_id,
  customer_id,
  location_code,
  location_name,
  address_text
) values (
  'c3200000-0000-0000-0000-000000000002',
  'c3200000-0000-0000-0000-000000000001',
  'uiq03ca-main-gate',
  'UI-QUALITY-03C-A Main Gate',
  'UI-QUALITY-03C-A address'
);

insert into atlas_admin.school_types (
  school_type_id,
  school_type_code,
  school_type_name
) values (
  'c3200000-0000-0000-0000-000000000003',
  'uiq03ca-primary',
  'Primary'
);

insert into atlas_admin.schools (
  school_id,
  customer_id,
  school_code,
  school_name,
  school_type_id,
  default_delivery_location_id,
  display_order,
  default_student_portions,
  default_teacher_portions
) values
  (
    'c3200000-0000-0000-0000-000000000011',
    'c3200000-0000-0000-0000-000000000001',
    'uiq03ca-school-a',
    'UI-QUALITY-03C-A School A',
    'c3200000-0000-0000-0000-000000000003',
    'c3200000-0000-0000-0000-000000000002',
    1,
    100,
    10
  ),
  (
    'c3200000-0000-0000-0000-000000000012',
    'c3200000-0000-0000-0000-000000000001',
    'uiq03ca-school-b',
    'UI-QUALITY-03C-A School B',
    'c3200000-0000-0000-0000-000000000003',
    'c3200000-0000-0000-0000-000000000002',
    2,
    200,
    20
  ),
  (
    'c3200000-0000-0000-0000-000000000013',
    'c3200000-0000-0000-0000-000000000001',
    'uiq03ca-school-c',
    'UI-QUALITY-03C-A School C',
    'c3200000-0000-0000-0000-000000000003',
    'c3200000-0000-0000-0000-000000000002',
    3,
    300,
    30
  );

create temporary table uiq03ca_school_c_before as
select
  school_id,
  default_student_portions,
  default_teacher_portions,
  version,
  updated_at
from atlas_admin.schools
where school_id = 'c3200000-0000-0000-0000-000000000013';

create or replace function pg_temp.uiq03ca_bulk_request(
  p_command_id uuid,
  p_idempotency_key text,
  p_subject uuid,
  p_changes jsonb
)
returns jsonb
language sql
as $$
  select jsonb_build_object(
    'contract_version', 'RMVP-01.v2',
    'command_id', p_command_id,
    'correlation_id', 'c3900000-0000-0000-0000-000000000001',
    'idempotency_key', p_idempotency_key,
    'requested_by_auth_subject', p_subject,
    'requested_at', transaction_timestamp() - interval '1 second',
    'reason_code', 'SCHOOL_PORTION_DEFAULTS_BULK_UPDATE',
    'reason_note', 'Rolled-back UI-QUALITY-03C-A test',
    'payload', jsonb_build_object('changes', p_changes)
  );
$$;

create temporary table uiq03ca_results (
  result_name text primary key,
  response_payload jsonb not null
);
grant select, insert on uiq03ca_results to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'c3100000-0000-0000-0000-000000000101',
  true
);

insert into uiq03ca_results values (
  'success',
  atlas_api.update_school_portion_defaults_bulk(
    pg_temp.uiq03ca_bulk_request(
      'c3900000-0000-0000-0000-000000000101',
      'uiq03ca-success',
      'c3100000-0000-0000-0000-000000000101',
      jsonb_build_array(
        jsonb_build_object(
          'school_id', 'c3200000-0000-0000-0000-000000000011',
          'expected_version', 1,
          'default_student_portions', 120,
          'default_teacher_portions', 10
        ),
        jsonb_build_object(
          'school_id', 'c3200000-0000-0000-0000-000000000012',
          'expected_version', 1,
          'default_student_portions', 200,
          'default_teacher_portions', 25
        )
      )
    )
  )
);
insert into uiq03ca_results values (
  'replay',
  atlas_api.update_school_portion_defaults_bulk(
    pg_temp.uiq03ca_bulk_request(
      'c3900000-0000-0000-0000-000000000101',
      'uiq03ca-success',
      'c3100000-0000-0000-0000-000000000101',
      jsonb_build_array(
        jsonb_build_object(
          'school_id', 'c3200000-0000-0000-0000-000000000011',
          'expected_version', 1,
          'default_student_portions', 120,
          'default_teacher_portions', 10
        ),
        jsonb_build_object(
          'school_id', 'c3200000-0000-0000-0000-000000000012',
          'expected_version', 1,
          'default_student_portions', 200,
          'default_teacher_portions', 25
        )
      )
    )
  )
);
insert into uiq03ca_results values (
  'empty',
  atlas_api.update_school_portion_defaults_bulk(
    pg_temp.uiq03ca_bulk_request(
      'c3900000-0000-0000-0000-000000000102',
      'uiq03ca-empty',
      'c3100000-0000-0000-0000-000000000101',
      '[]'::jsonb
    )
  )
);
insert into uiq03ca_results values (
  'duplicate',
  atlas_api.update_school_portion_defaults_bulk(
    pg_temp.uiq03ca_bulk_request(
      'c3900000-0000-0000-0000-000000000103',
      'uiq03ca-duplicate',
      'c3100000-0000-0000-0000-000000000101',
      jsonb_build_array(
        jsonb_build_object(
          'school_id', 'c3200000-0000-0000-0000-000000000011',
          'expected_version', 2,
          'default_student_portions', 121,
          'default_teacher_portions', 10
        ),
        jsonb_build_object(
          'school_id', 'c3200000-0000-0000-0000-000000000011',
          'expected_version', 2,
          'default_student_portions', 122,
          'default_teacher_portions', 10
        )
      )
    )
  )
);
insert into uiq03ca_results values (
  'invalid',
  atlas_api.update_school_portion_defaults_bulk(
    pg_temp.uiq03ca_bulk_request(
      'c3900000-0000-0000-0000-000000000104',
      'uiq03ca-invalid',
      'c3100000-0000-0000-0000-000000000101',
      jsonb_build_array(
        jsonb_build_object(
          'school_id', 'not-a-uuid',
          'expected_version', 2,
          'default_student_portions', -1,
          'default_teacher_portions', 10
        )
      )
    )
  )
);
insert into uiq03ca_results values (
  'missing_expected_version',
  atlas_api.update_school_portion_defaults_bulk(
    pg_temp.uiq03ca_bulk_request(
      'c3900000-0000-0000-0000-000000000105',
      'uiq03ca-missing-version',
      'c3100000-0000-0000-0000-000000000101',
      jsonb_build_array(
        jsonb_build_object(
          'school_id', 'c3200000-0000-0000-0000-000000000011',
          'default_student_portions', 121,
          'default_teacher_portions', 10
        )
      )
    )
  )
);
insert into uiq03ca_results values (
  'missing_school',
  atlas_api.update_school_portion_defaults_bulk(
    pg_temp.uiq03ca_bulk_request(
      'c3900000-0000-0000-0000-000000000106',
      'uiq03ca-missing-school',
      'c3100000-0000-0000-0000-000000000101',
      jsonb_build_array(
        jsonb_build_object(
          'school_id', 'c3200000-0000-0000-0000-000000000011',
          'expected_version', 2,
          'default_student_portions', 121,
          'default_teacher_portions', 10
        ),
        jsonb_build_object(
          'school_id', 'c3200000-0000-0000-0000-000000000099',
          'expected_version', 1,
          'default_student_portions', 999,
          'default_teacher_portions', 99
        )
      )
    )
  )
);
insert into uiq03ca_results values (
  'stale',
  atlas_api.update_school_portion_defaults_bulk(
    pg_temp.uiq03ca_bulk_request(
      'c3900000-0000-0000-0000-000000000107',
      'uiq03ca-stale',
      'c3100000-0000-0000-0000-000000000101',
      jsonb_build_array(
        jsonb_build_object(
          'school_id', 'c3200000-0000-0000-0000-000000000011',
          'expected_version', 2,
          'default_student_portions', 121,
          'default_teacher_portions', 10
        ),
        jsonb_build_object(
          'school_id', 'c3200000-0000-0000-0000-000000000012',
          'expected_version', 1,
          'default_student_portions', 200,
          'default_teacher_portions', 26
        )
      )
    )
  )
);
reset role;

select is(
  (select response_payload ->> 'success' from uiq03ca_results where result_name = 'success'),
  'true',
  'an authenticated authorized Actor can save two changed Schools atomically'
);
select is(
  (
    select jsonb_agg(
      jsonb_build_array(
        school_id,
        default_student_portions,
        default_teacher_portions,
        version
      )
      order by school_id
    )
    from atlas_admin.schools
    where school_id in (
      'c3200000-0000-0000-0000-000000000011',
      'c3200000-0000-0000-0000-000000000012'
    )
  ),
  jsonb_build_array(
    jsonb_build_array('c3200000-0000-0000-0000-000000000011', 120, 10, 2),
    jsonb_build_array('c3200000-0000-0000-0000-000000000012', 200, 25, 2)
  ),
  'both changed Schools update and each version increments exactly once'
);
select ok(
  (select default_teacher_portions = 10 from atlas_admin.schools where school_id = 'c3200000-0000-0000-0000-000000000011')
  and (select default_student_portions = 200 from atlas_admin.schools where school_id = 'c3200000-0000-0000-0000-000000000012'),
  'one-field edits preserve the other value sent by the Application'
);
select is(
  (
    select jsonb_build_object(
      'school_id', current_school.school_id,
      'default_student_portions', current_school.default_student_portions,
      'default_teacher_portions', current_school.default_teacher_portions,
      'version', current_school.version,
      'updated_at', current_school.updated_at
    )
    from atlas_admin.schools current_school
    where current_school.school_id = 'c3200000-0000-0000-0000-000000000013'
  ),
  (
    select jsonb_build_object(
      'school_id', baseline.school_id,
      'default_student_portions', baseline.default_student_portions,
      'default_teacher_portions', baseline.default_teacher_portions,
      'version', baseline.version,
      'updated_at', baseline.updated_at
    )
    from uiq03ca_school_c_before baseline
  ),
  'the untouched School remains byte-for-business-fact unchanged'
);
select is(
  (
    select response_payload -> 'updated_schools'
    from uiq03ca_results
    where result_name = 'success'
  ),
  jsonb_build_array(
    jsonb_build_object(
      'school_id', 'c3200000-0000-0000-0000-000000000011',
      'version', 2,
      'default_student_portions', 120,
      'default_teacher_portions', 10
    ),
    jsonb_build_object(
      'school_id', 'c3200000-0000-0000-0000-000000000012',
      'version', 2,
      'default_student_portions', 200,
      'default_teacher_portions', 25
    )
  ),
  'success returns authoritative updated School facts'
);
select is(
  (
    select count(*)::integer
    from atlas_core.command_receipts
    where command_id = 'c3900000-0000-0000-0000-000000000101'
      and command_name = 'update_school_portion_defaults_bulk'
      and outcome = 'COMPLETED'
  ),
  1,
  'one bulk Save creates one completed command receipt'
);
select is(
  (
    select count(distinct aggregate_id)::integer
    from atlas_audit.domain_events
    where command_id = 'c3900000-0000-0000-0000-000000000101'
      and event_type = 'SchoolPortionDefaultsUpdated'
  ),
  2,
  'one School domain event exists for every changed School'
);
select is(
  (
    select count(distinct aggregate_id)::integer
    from atlas_audit.audit_events
    where command_id = 'c3900000-0000-0000-0000-000000000101'
      and event_type = 'SchoolPortionDefaultsUpdated'
      and aggregate_version_after = aggregate_version_before + 1
  ),
  2,
  'one versioned audit record exists for every changed School'
);
select is(
  (select response_payload ->> 'error_code' from uiq03ca_results where result_name = 'empty'),
  'VALIDATION_FAILED',
  'an empty change list is rejected'
);
select is(
  (select response_payload ->> 'error_code' from uiq03ca_results where result_name = 'duplicate'),
  'VALIDATION_FAILED',
  'a duplicate School is rejected'
);
select is(
  (select response_payload ->> 'error_code' from uiq03ca_results where result_name = 'invalid'),
  'VALIDATION_FAILED',
  'a malformed School identity and negative count are rejected'
);
select is(
  (select response_payload ->> 'error_code' from uiq03ca_results where result_name = 'missing_expected_version'),
  'VALIDATION_FAILED',
  'a missing row expected_version is rejected'
);
select is(
  (select response_payload ->> 'error_code' from uiq03ca_results where result_name = 'missing_school'),
  'NOT_FOUND',
  'one missing School rejects the complete command'
);
select is(
  (
    select jsonb_agg(
      jsonb_build_array(school_id, default_student_portions, default_teacher_portions, version)
      order by school_id
    )
    from atlas_admin.schools
    where school_id in (
      'c3200000-0000-0000-0000-000000000011',
      'c3200000-0000-0000-0000-000000000012'
    )
  ),
  jsonb_build_array(
    jsonb_build_array('c3200000-0000-0000-0000-000000000011', 120, 10, 2),
    jsonb_build_array('c3200000-0000-0000-0000-000000000012', 200, 25, 2)
  ),
  'missing and stale batch failures leave every School unchanged'
);
select is(
  (
    select count(*)::integer
    from atlas_audit.domain_events
    where command_id in (
      'c3900000-0000-0000-0000-000000000106',
      'c3900000-0000-0000-0000-000000000107'
    )
  ) + (
    select count(*)::integer
    from atlas_audit.audit_events
    where command_id in (
      'c3900000-0000-0000-0000-000000000106',
      'c3900000-0000-0000-0000-000000000107'
    )
  ),
  0,
  'missing and stale failures create no domain or audit changes'
);
select is(
  (select response_payload ->> 'error_code' from uiq03ca_results where result_name = 'stale'),
  'STALE_VERSION',
  'one stale School rejects the complete command with STALE_VERSION'
);
select is(
  (
    select response_payload -> 'blocking_references' -> 0 ->> 'school_name'
    from uiq03ca_results
    where result_name = 'stale'
  ),
  'UI-QUALITY-03C-A School B',
  'stale response safely identifies the affected School by human name'
);
select is(
  (select response_payload from uiq03ca_results where result_name = 'replay'),
  (select response_payload from uiq03ca_results where result_name = 'success'),
  'an exact idempotent replay returns the stored successful outcome'
);
select ok(
  (
    select bool_and(version = 2)
    from atlas_admin.schools
    where school_id in (
      'c3200000-0000-0000-0000-000000000011',
      'c3200000-0000-0000-0000-000000000012'
    )
  )
  and (
    select count(*) = 2
    from atlas_audit.domain_events
    where command_id = 'c3900000-0000-0000-0000-000000000101'
  )
  and (
    select count(*) = 2
    from atlas_audit.audit_events
    where command_id = 'c3900000-0000-0000-0000-000000000101'
  ),
  'idempotent replay does not increment versions or duplicate evidence'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'c3100000-0000-0000-0000-000000000102',
  true
);
insert into uiq03ca_results values (
  'denied',
  atlas_api.update_school_portion_defaults_bulk(
    pg_temp.uiq03ca_bulk_request(
      'c3900000-0000-0000-0000-000000000108',
      'uiq03ca-denied',
      'c3100000-0000-0000-0000-000000000102',
      jsonb_build_array(
        jsonb_build_object(
          'school_id', 'c3200000-0000-0000-0000-000000000011',
          'expected_version', 2,
          'default_student_portions', 121,
          'default_teacher_portions', 10
        )
      )
    )
  )
);
reset role;
select is(
  (select response_payload ->> 'error_code' from uiq03ca_results where result_name = 'denied'),
  'CAPABILITY_DENIED',
  'the existing School write capability is enforced server-side'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'c3100000-0000-0000-0000-000000000101',
  true
);
insert into uiq03ca_results values (
  'v1_compatibility',
  atlas_api.update_school_portion_defaults(
    jsonb_build_object(
      'contract_version', 'RMVP-01.v1',
      'command_id', 'c3900000-0000-0000-0000-000000000109',
      'correlation_id', 'c3900000-0000-0000-0000-000000000001',
      'idempotency_key', 'uiq03ca-v1-compatibility',
      'expected_version', 1,
      'requested_by_auth_subject', 'c3100000-0000-0000-0000-000000000101',
      'requested_at', transaction_timestamp() - interval '1 second',
      'reason_code', 'SCHOOL_PORTION_DEFAULTS_UPDATE',
      'reason_note', 'Rolled-back v1 compatibility check',
      'payload', jsonb_build_object(
        'school_id', 'c3200000-0000-0000-0000-000000000013',
        'default_student_portions', 301,
        'default_teacher_portions', 30
      )
    )
  )
);
reset role;
select is(
  (
    select jsonb_build_array(
      response_payload ->> 'success',
      response_payload ->> 'contract_version'
    )
    from uiq03ca_results
    where result_name = 'v1_compatibility'
  ),
  jsonb_build_array('true', 'RMVP-01.v1'),
  'the existing RMVP-01.v1 single-School command remains callable and unchanged'
);

select * from finish();
rollback;
