begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select plan(46);

grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;

select is(
  (
    select array_agg(c.relname order by c.relname)::text[]
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'atlas_planning'
      and c.relkind = 'r'
      and c.relname like 'pantry_need_%'
  ),
  array[
    'pantry_need_approval_snapshot_lines',
    'pantry_need_approval_snapshots',
    'pantry_need_batches',
    'pantry_need_lines',
    'pantry_need_purposes'
  ]::text[],
  'PANTRY-02 creates exactly five private Pantry relations'
);

select is(
  (
    select array_agg(p.proname order by p.proname)::text[]
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname like '%pantry%'
  ),
  array[
    'approve_pantry',
    'get_pantry_source_workbench',
    'preview_pantry_source',
    'reopen_pantry',
    'save_pantry_draft',
    'validate_pantry'
  ]::text[],
  'PANTRY-02 exposes exactly the six reviewed APIs'
);

select is(
  (
    select count(*)::integer
    from atlas_core.capabilities
    where capability_code = 'planning.pantry.write'
  ),
  1,
  'PANTRY-02 adds exactly planning.pantry.write'
);

select is(
  (
    select count(*)::integer
    from atlas_core.roles
    where role_code ilike '%pantry%'
  ),
  0,
  'PANTRY-02 adds no role'
);

select is(
  (
    select count(*)::integer
    from atlas_planning.pantry_need_purposes
  ),
  0,
  'the migration adds no production Pantry Purpose row'
);

select ok(
  not has_schema_privilege('authenticated', 'atlas_planning', 'USAGE')
  and not has_schema_privilege('anon', 'atlas_planning', 'USAGE')
  and not has_schema_privilege('service_role', 'atlas_planning', 'USAGE'),
  'Pantry relations remain outside direct browser schema access'
);

select ok(
  (
    select bool_and(c.relrowsecurity and c.relforcerowsecurity)
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'atlas_planning'
      and c.relkind = 'r'
      and c.relname like 'pantry_need_%'
  ),
  'all five Pantry relations have enabled and forced RLS'
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
        'get_pantry_source_workbench',
        'preview_pantry_source',
        'save_pantry_draft',
        'validate_pantry',
        'approve_pantry',
        'reopen_pantry'
      )
  ),
  'all six APIs are fixed-search-path definers with browser-only execute'
);

select ok(
  (
    select bool_and(
      case
        when p.proname in (
          'get_pantry_source_workbench',
          'preview_pantry_source'
        )
          then pg_get_userbyid(p.proowner) = 'atlas_read_runtime'
        else pg_get_userbyid(p.proowner) =
          'atlas_planning_command_runtime'
      end
    )
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname in (
        'get_pantry_source_workbench',
        'preview_pantry_source',
        'save_pantry_draft',
        'validate_pantry',
        'approve_pantry',
        'reopen_pantry'
      )
  ),
  'read and command APIs use the intended least-privilege owners'
);

select ok(
  has_table_privilege(
    'atlas_planning_command_runtime',
    'atlas_planning.pantry_need_batches',
    'INSERT, UPDATE, SELECT'
  )
  and not has_table_privilege(
    'atlas_planning_command_runtime',
    'atlas_planning.pantry_need_batches',
    'DELETE'
  )
  and not has_table_privilege(
    'atlas_planning_command_runtime',
    'atlas_planning.pantry_need_purposes',
    'INSERT'
  )
  and not has_table_privilege(
    'authenticated',
    'atlas_planning.pantry_need_batches',
    'SELECT'
  ),
  'runtime grants permit bounded commands without browser, delete, or Purpose CRUD'
);

insert into atlas_planning.pantry_need_purposes (
  pantry_need_purpose_id,
  purpose_code,
  purpose_name_vi,
  purpose_description,
  note_rule,
  purpose_status,
  display_order
) values
  (
    'a7200000-0000-4000-8000-000000000001',
    'school_requested_supplement',
    'Bổ sung theo yêu cầu của trường',
    'An identified School has explicitly requested an additional Ingredient quantity for the stated service date beyond the demand already represented by controlled Planning sources.',
    'REQUIRED',
    'ACTIVE',
    10
  ),
  (
    'a7200000-0000-4000-8000-000000000002',
    'planning_identified_supplement',
    'Bổ sung do bộ phận Kế hoạch xác định',
    'Planning or catering operations has identified a specific additional Ingredient quantity required to deliver service for the stated School and service date, and that quantity is not represented by another controlled Planning source.',
    'REQUIRED',
    'ACTIVE',
    20
  );

select is(
  (
    select jsonb_agg(
      jsonb_build_object(
        'code', purpose_code,
        'name_vi', purpose_name_vi,
        'note_rule', note_rule,
        'status', purpose_status,
        'order', display_order
      )
      order by display_order
    )
    from atlas_planning.pantry_need_purposes
  ),
  '[
    {
      "code": "school_requested_supplement",
      "name_vi": "Bổ sung theo yêu cầu của trường",
      "note_rule": "REQUIRED",
      "status": "ACTIVE",
      "order": 10
    },
    {
      "code": "planning_identified_supplement",
      "name_vi": "Bổ sung do bộ phận Kế hoạch xác định",
      "note_rule": "REQUIRED",
      "status": "ACTIVE",
      "order": 20
    }
  ]'::jsonb,
  'review fixture contains exactly the two approved initial Purposes'
);

insert into atlas_core.actors (
  actor_id,
  actor_type,
  display_name
) values
  (
    'a7200000-0000-0000-0000-000000000010',
    'HUMAN',
    'PANTRY-02 authorized operator'
  ),
  (
    'a7200000-0000-0000-0000-000000000011',
    'HUMAN',
    'PANTRY-02 denied operator'
  );

insert into atlas_core.actor_auth_subjects (
  actor_auth_subject_id,
  actor_id,
  auth_subject_id
) values
  (
    'a7200000-0000-0000-0000-000000000012',
    'a7200000-0000-0000-0000-000000000010',
    'a7200000-0000-0000-0000-000000000110'
  ),
  (
    'a7200000-0000-0000-0000-000000000013',
    'a7200000-0000-0000-0000-000000000011',
    'a7200000-0000-0000-0000-000000000111'
  );

insert into atlas_core.roles (
  role_id,
  role_code,
  role_name
) values
  (
    'a7200000-0000-0000-0000-000000000014',
    'pantry02.test_operator',
    'PANTRY-02 test operator'
  ),
  (
    'a7200000-0000-0000-0000-000000000015',
    'pantry02.test_denied',
    'PANTRY-02 denied test operator'
  );

insert into atlas_core.role_capabilities (role_id, capability_id)
select
  'a7200000-0000-0000-0000-000000000014',
  capability.capability_id
from atlas_core.capabilities capability
where capability.capability_code in (
  'planning.inputs.read',
  'planning.inputs.approve',
  'planning.pantry.write'
);

insert into atlas_core.actor_role_memberships (actor_id, role_id) values
  (
    'a7200000-0000-0000-0000-000000000010',
    'a7200000-0000-0000-0000-000000000014'
  ),
  (
    'a7200000-0000-0000-0000-000000000011',
    'a7200000-0000-0000-0000-000000000015'
  );

insert into atlas_core.actor_scopes (actor_id, scope_kind) values
  ('a7200000-0000-0000-0000-000000000010', 'GLOBAL'),
  ('a7200000-0000-0000-0000-000000000011', 'GLOBAL');

insert into atlas_admin.customers (
  customer_id,
  customer_code,
  customer_name,
  customer_type
) values
  (
    'a7200000-0000-0000-0000-000000000020',
    'pantry02-school-customer',
    'PANTRY-02 School Customer',
    'SCHOOL_CATERING'
  ),
  (
    'a7200000-0000-0000-0000-000000000021',
    'pantry02-inactive-customer',
    'PANTRY-02 Inactive School Customer',
    'SCHOOL_CATERING'
  );

insert into atlas_admin.delivery_locations (
  delivery_location_id,
  customer_id,
  location_code,
  location_name,
  address_text
) values
  (
    'a7200000-0000-0000-0000-000000000022',
    'a7200000-0000-0000-0000-000000000020',
    'pantry02-default',
    'PANTRY-02 Default Kitchen',
    'PANTRY-02 default address'
  ),
  (
    'a7200000-0000-0000-0000-000000000023',
    'a7200000-0000-0000-0000-000000000020',
    'pantry02-alternative',
    'PANTRY-02 Alternative Kitchen',
    'PANTRY-02 alternative address'
  ),
  (
    'a7200000-0000-0000-0000-000000000024',
    'a7200000-0000-0000-0000-000000000021',
    'pantry02-inactive-customer-location',
    'PANTRY-02 Inactive Customer Location',
    'PANTRY-02 inactive customer address'
  );

insert into atlas_admin.school_types (
  school_type_id,
  school_type_code,
  school_type_name
) values (
  'a7200000-0000-0000-0000-000000000025',
  'pantry02-primary',
  'PANTRY-02 Primary'
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
    'a7200000-0000-0000-0000-000000000026',
    'a7200000-0000-0000-0000-000000000020',
    'pantry02-school',
    'PANTRY-02 School',
    'a7200000-0000-0000-0000-000000000025',
    'a7200000-0000-0000-0000-000000000022',
    1,
    100,
    10
  ),
  (
    'a7200000-0000-0000-0000-000000000027',
    'a7200000-0000-0000-0000-000000000021',
    'pantry02-inactive-customer-school',
    'PANTRY-02 Inactive Customer School',
    'a7200000-0000-0000-0000-000000000025',
    'a7200000-0000-0000-0000-000000000024',
    2,
    100,
    10
  );

update atlas_admin.customers
set
  customer_status = 'INACTIVE',
  updated_at = transaction_timestamp()
where customer_id = 'a7200000-0000-0000-0000-000000000021';

insert into atlas_admin.units (
  unit_id,
  unit_code,
  unit_name,
  dimension_code,
  decimal_scale
) values
  (
    'a7200000-0000-0000-0000-000000000030',
    'pantry02-kg',
    'PANTRY-02 kilogram',
    'MASS',
    6
  ),
  (
    'a7200000-0000-0000-0000-000000000031',
    'pantry02-each',
    'PANTRY-02 each',
    'COUNT',
    0
  );

insert into atlas_admin.ingredients (
  ingredient_id,
  ingredient_code,
  ingredient_name,
  ingredient_group,
  purchase_unit_id,
  ingredient_type,
  shopping_type,
  order_step
) values
  (
    'a7200000-0000-0000-0000-000000000032',
    'pantry02-rice',
    'PANTRY-02 Rice',
    'Food',
    'a7200000-0000-0000-0000-000000000030',
    'Food',
    'Planned',
    1
  ),
  (
    'a7200000-0000-0000-0000-000000000033',
    'pantry02-eggs',
    'PANTRY-02 Eggs',
    'Food',
    'a7200000-0000-0000-0000-000000000031',
    'Food',
    'Planned',
    1
  );

create or replace function pg_temp.pantry02_read(
  payload jsonb,
  subject uuid default 'a7200000-0000-0000-0000-000000000110'
)
returns jsonb
language sql
as $$
  select jsonb_build_object(
    'contract_version', 'PANTRY-02.v1',
    'requested_by_auth_subject', subject,
    'correlation_id', 'a7200000-0000-0000-0000-000000000120',
    'payload', payload
  );
$$;

create or replace function pg_temp.pantry02_command(
  command_name text,
  expected_version bigint,
  payload jsonb,
  note text default 'Rolled-back PANTRY-02 acceptance test.'
)
returns jsonb
language sql
as $$
  select jsonb_build_object(
    'contract_version', 'PANTRY-02.v1',
    'command_id', md5('pantry02-command:' || command_name)::uuid,
    'correlation_id', 'a7200000-0000-0000-0000-000000000121',
    'idempotency_key', 'pantry02:' || command_name,
    'expected_version', expected_version,
    'requested_by_auth_subject',
      'a7200000-0000-0000-0000-000000000110',
    'requested_at', transaction_timestamp() - interval '1 second',
    'reason_code', 'PANTRY02_TEST',
    'reason_note', note,
    'payload', payload
  );
$$;

create or replace function pg_temp.pantry02_physical_count(kind text)
returns integer
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if kind = 'batches' then
    return (select count(*)::integer from atlas_planning.pantry_need_batches);
  elsif kind = 'active_lines' then
    return (
      select count(*)::integer
      from atlas_planning.pantry_need_lines
      where line_status = 'ACTIVE'
    );
  elsif kind = 'invalid_lines' then
    return (
      select count(*)::integer
      from atlas_planning.pantry_need_lines
      where line_status = 'INVALID'
    );
  elsif kind = 'all_lines' then
    return (select count(*)::integer from atlas_planning.pantry_need_lines);
  elsif kind = 'snapshots' then
    return (
      select count(*)::integer
      from atlas_planning.pantry_need_approval_snapshots
    );
  elsif kind = 'snapshot_lines' then
    return (
      select count(*)::integer
      from atlas_planning.pantry_need_approval_snapshot_lines
    );
  elsif kind = 'events' then
    return (
      select count(*)::integer
      from atlas_audit.domain_events
      where aggregate_type = 'PantryNeedBatch'
    );
  elsif kind = 'audits' then
    return (
      select count(*)::integer
      from atlas_audit.audit_events
      where aggregate_type = 'PantryNeedBatch'
    );
  end if;
  return -1;
end;
$$;

create temporary table pantry02_results (
  result_name text primary key,
  response_payload jsonb not null
);
grant select, insert on pantry02_results to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a7200000-0000-0000-0000-000000000110',
  true
);

insert into pantry02_results values (
  'workbench',
  atlas_api.get_pantry_source_workbench(
    pg_temp.pantry02_read(
      jsonb_build_object('week_start', '2026-08-03')
    )
  )
);

select ok(
  (
    select (response_payload ->> 'success')::boolean
      and jsonb_array_length(
        response_payload -> 'workbench' -> 'purposes'
      ) = 2
      and response_payload #>>
        '{workbench,schools,0,default_delivery_location,delivery_location_id}'
        = 'a7200000-0000-0000-0000-000000000022'
      and response_payload #>>
        '{workbench,ingredients,0,purchase_unit,unit_id}'
        is not null
      and (response_payload #>> '{workbench,allowed_actions,can_save}')::boolean
    from pantry02_results
    where result_name = 'workbench'
  ),
  'authorized workbench returns governed Purposes and backend-derived references'
);

select is(
  (
    select jsonb_array_length(
      response_payload -> 'workbench' -> 'schools'
    )
    from pantry02_results
    where result_name = 'workbench'
  ),
  1,
  'workbench excludes a School whose SCHOOL_CATERING parent Customer is inactive'
);

reset role;

insert into atlas_planning.pantry_need_purposes (
  pantry_need_purpose_id,
  purpose_code,
  purpose_name_vi,
  purpose_description,
  note_rule,
  purpose_status,
  display_order
) values
  (
    'a7200000-0000-4000-8000-000000000003',
    'test_optional_note',
    'Mục đích kiểm thử ghi chú không bắt buộc',
    'Rolled-back OPTIONAL note-rule fixture.',
    'OPTIONAL',
    'ACTIVE',
    30
  ),
  (
    'a7200000-0000-4000-8000-000000000004',
    'test_prohibited_note',
    'Mục đích kiểm thử cấm ghi chú',
    'Rolled-back PROHIBITED note-rule fixture.',
    'PROHIBITED',
    'ACTIVE',
    40
  ),
  (
    'a7200000-0000-4000-8000-000000000005',
    'test_inactive_purpose',
    'Mục đích kiểm thử không hoạt động',
    'Rolled-back inactive Purpose fixture.',
    'OPTIONAL',
    'INACTIVE',
    50
  );

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a7200000-0000-0000-0000-000000000110',
  true
);

insert into pantry02_results
select
  scenario_name,
  atlas_api.preview_pantry_source(
    pg_temp.pantry02_read(
      jsonb_build_object(
        'week_start', '2026-08-03',
        'no_additions_confirmed', false,
        'rows', jsonb_build_array(
          jsonb_build_object(
            'service_date', '2026-08-03',
            'school_id', 'a7200000-0000-0000-0000-000000000026',
            'ingredient_id', 'a7200000-0000-0000-0000-000000000032',
            'pantry_need_purpose_id', purpose_id,
            'requested_quantity', '1',
            'note', note_value
          )
        )
      )
    )
  )
from (
  values
    (
      'note-required',
      'a7200000-0000-4000-8000-000000000001'::uuid,
      null::text
    ),
    (
      'note-optional',
      'a7200000-0000-4000-8000-000000000003'::uuid,
      null::text
    ),
    (
      'note-prohibited',
      'a7200000-0000-4000-8000-000000000004'::uuid,
      'A prohibited note'::text
    ),
    (
      'purpose-inactive',
      'a7200000-0000-4000-8000-000000000005'::uuid,
      null::text
    )
) fixture(scenario_name, purpose_id, note_value);

select ok(
  (
    select jsonb_path_exists(
      response_payload,
      '$.preview.issues.blockers[*] ? (@.code == "MISSING_REQUIRED_NOTE")'
    )
    from pantry02_results
    where result_name = 'note-required'
  )
  and (
    select (response_payload #>> '{preview,can_save}')::boolean
    from pantry02_results
    where result_name = 'note-optional'
  )
  and (
    select jsonb_path_exists(
      response_payload,
      '$.preview.issues.blockers[*] ? (@.code == "PROHIBITED_NOTE_PRESENT")'
    )
    from pantry02_results
    where result_name = 'note-prohibited'
  )
  and (
    select jsonb_path_exists(
      response_payload,
      '$.preview.issues.blockers[*] ? (@.code == "INACTIVE_PURPOSE")'
    )
    from pantry02_results
    where result_name = 'purpose-inactive'
  ),
  'preview enforces REQUIRED, OPTIONAL, PROHIBITED, and inactive Purpose rules'
);

insert into pantry02_results values (
  'preview-a',
  atlas_api.preview_pantry_source(
    pg_temp.pantry02_read(
      jsonb_build_object(
        'week_start', '2026-08-03',
        'no_additions_confirmed', false,
        'rows', jsonb_build_array(
          jsonb_build_object(
            'service_date', '2026-08-03',
            'school_id', 'a7200000-0000-0000-0000-000000000026',
            'ingredient_id', 'a7200000-0000-0000-0000-000000000032',
            'pantry_need_purpose_id',
              'a7200000-0000-4000-8000-000000000001',
            'requested_quantity', '2.500000',
            'note', ' School request ',
            'source_request_reference', 'REQ-1',
            'source_row_reference', 'sheet:2'
          ),
          jsonb_build_object(
            'service_date', '2026-08-04',
            'school_id', 'a7200000-0000-0000-0000-000000000026',
            'ingredient_id', 'a7200000-0000-0000-0000-000000000033',
            'pantry_need_purpose_id',
              'a7200000-0000-4000-8000-000000000002',
            'requested_quantity', '12',
            'note', 'Planning identified',
            'source_row_reference', 'sheet:3'
          )
        )
      )
    )
  )
);

insert into pantry02_results values (
  'preview-b',
  atlas_api.preview_pantry_source(
    pg_temp.pantry02_read(
      jsonb_build_object(
        'week_start', '2026-08-03',
        'no_additions_confirmed', false,
        'rows', jsonb_build_array(
          jsonb_build_object(
            'service_date', '2026-08-04',
            'school_id', 'a7200000-0000-0000-0000-000000000026',
            'ingredient_id', 'a7200000-0000-0000-0000-000000000033',
            'pantry_need_purpose_id',
              'a7200000-0000-4000-8000-000000000002',
            'requested_quantity', '12',
            'note', 'Planning identified',
            'source_row_reference', 'different-row'
          ),
          jsonb_build_object(
            'service_date', '2026-08-03',
            'school_id', 'a7200000-0000-0000-0000-000000000026',
            'ingredient_id', 'a7200000-0000-0000-0000-000000000032',
            'pantry_need_purpose_id',
              'a7200000-0000-4000-8000-000000000001',
            'requested_quantity', '2.5',
            'note', 'School request',
            'source_request_reference', 'REQ-1',
            'source_row_reference', 'another-row'
          )
        )
      )
    )
  )
);

select ok(
  (
    select (response_payload #>> '{preview,can_save}')::boolean
      and jsonb_array_length(
        response_payload #> '{preview,issues,blockers}'
      ) = 0
      and response_payload #>>
        '{preview,canonical_rows,0,delivery_location_id}'
        = 'a7200000-0000-0000-0000-000000000022'
      and response_payload #>>
        '{preview,canonical_rows,0,unit_id}'
        = 'a7200000-0000-0000-0000-000000000030'
    from pantry02_results
    where result_name = 'preview-a'
  ),
  'valid preview is saveable and derives exact default location and purchase unit'
);

select is(
  (
    select response_payload #>> '{preview,source_signature}'
    from pantry02_results
    where result_name = 'preview-a'
  ),
  (
    select response_payload #>> '{preview,source_signature}'
    from pantry02_results
    where result_name = 'preview-b'
  ),
  'signature is order-independent and excludes source-row evidence'
);

select ok(
  (
    select jsonb_array_length(
      response_payload #> '{preview,comparison,new_lines}'
    ) = 2
      and jsonb_array_length(
        response_payload #> '{preview,comparison,changed_lines}'
      ) = 0
      and jsonb_array_length(
        response_payload #> '{preview,comparison,unchanged_lines}'
      ) = 0
      and jsonb_array_length(
        response_payload #> '{preview,comparison,omitted_lines}'
      ) = 0
      and jsonb_array_length(
        response_payload #> '{preview,comparison,changed_school_dates}'
      ) = 2
    from pantry02_results
    where result_name = 'preview-a'
  ),
  'new preview returns exact categorized lines and changed School/date pairs'
);

insert into pantry02_results
select
  scenario_name,
  atlas_api.preview_pantry_source(
    pg_temp.pantry02_read(
      jsonb_build_object(
        'week_start', '2026-08-03',
        'no_additions_confirmed', false,
        'rows', jsonb_build_array(
          jsonb_build_object(
            'service_date', '2026-08-05',
            'school_id', 'a7200000-0000-0000-0000-000000000026',
            'ingredient_id', 'a7200000-0000-0000-0000-000000000032',
            'pantry_need_purpose_id',
              'a7200000-0000-4000-8000-000000000001',
            'requested_quantity', '1.250000',
            'note', normalized_note,
            'source_request_reference', ' YÊU CẦU-01 ',
            'source_row_reference', source_row
          )
        )
      )
    )
  )
from (
  values
    (
      'preview-unicode-nfc',
      pg_catalog.normalize(' Bổ sung có dấu ', 'NFC'),
      'sheet:unicode:1'
    ),
    (
      'preview-unicode-nfd',
      pg_catalog.normalize('Bổ sung có dấu', 'NFD'),
      'sheet:unicode:99'
    )
) fixture(scenario_name, normalized_note, source_row);

select is(
  (
    select response_payload #>> '{preview,source_signature}'
    from pantry02_results
    where result_name = 'preview-unicode-nfc'
  ),
  (
    select response_payload #>> '{preview,source_signature}'
    from pantry02_results
    where result_name = 'preview-unicode-nfd'
  ),
  'signature is independent of harmless whitespace and Unicode representation'
);

insert into pantry02_results values (
  'preview-caller-authority',
  atlas_api.preview_pantry_source(
    pg_temp.pantry02_read(
      jsonb_build_object(
        'week_start', '2026-08-03',
        'no_additions_confirmed', false,
        'rows', jsonb_build_array(
          jsonb_build_object(
            'service_date', '2026-08-03',
            'school_id', 'a7200000-0000-0000-0000-000000000026',
            'delivery_location_id',
              'a7200000-0000-0000-0000-000000000023',
            'ingredient_id', 'a7200000-0000-0000-0000-000000000032',
            'unit_id', 'a7200000-0000-0000-0000-000000000031',
            'pantry_need_purpose_id',
              'a7200000-0000-4000-8000-000000000001',
            'requested_quantity', '1',
            'note', 'Caller tried to author derived fields'
          )
        )
      )
    )
  )
);

select ok(
  (
    select jsonb_path_exists(
      response_payload,
      '$.preview.issues.blockers[*] ? (
        @.code == "CALLER_DELIVERY_LOCATION_NOT_ALLOWED"
      )'
    )
      and not (response_payload #>> '{preview,can_save}')::boolean
    from pantry02_results
    where result_name = 'preview-caller-authority'
  ),
  'caller-authored Delivery Location and Unit fail closed'
);

insert into pantry02_results values (
  'preview-invalid-quantities',
  atlas_api.preview_pantry_source(
    pg_temp.pantry02_read(
      jsonb_build_object(
        'week_start', '2026-08-03',
        'no_additions_confirmed', false,
        'rows', (
          select jsonb_agg(
            jsonb_build_object(
              'service_date', '2026-08-05',
              'school_id', 'a7200000-0000-0000-0000-000000000026',
              'ingredient_id',
                'a7200000-0000-0000-0000-000000000032',
              'pantry_need_purpose_id',
                'a7200000-0000-4000-8000-000000000001',
              'requested_quantity', quantity_value,
              'note', 'Quantity test',
              'source_row_reference', 'quantity:' || ordinality
            )
          )
          from unnest(
            array[
              '0',
              '-1',
              'NaN',
              'Infinity',
              'abc',
              '1.1234567'
            ]
          ) with ordinality invalid(quantity_value, ordinality)
        )
      )
    )
  )
);

select ok(
  (
    select jsonb_path_exists(
      response_payload,
      '$.preview.issues.blockers[*] ? (
        @.code == "QUANTITY_NOT_POSITIVE"
      )'
    )
      and jsonb_path_exists(
        response_payload,
        '$.preview.issues.blockers[*] ? (
          @.code == "QUANTITY_NONFINITE"
        )'
      )
      and jsonb_path_exists(
        response_payload,
        '$.preview.issues.blockers[*] ? (
          @.code == "QUANTITY_MALFORMED"
        )'
      )
    from pantry02_results
    where result_name = 'preview-invalid-quantities'
  ),
  'zero, negative, non-finite, malformed, and excess-scale quantities are blocked'
);

select is(
  pg_temp.pantry02_physical_count('batches'),
  0,
  'all preview variants remain write-free'
);

insert into pantry02_results
select
  'save-initial',
  atlas_api.save_pantry_draft(
    pg_temp.pantry02_command(
      'save-initial',
      1,
      jsonb_build_object(
        'week_start', '2026-08-03',
        'no_additions_confirmed', false,
        'source_signature',
          preview.response_payload #>> '{preview,source_signature}',
        'expected_source_signature', null,
        'rows', jsonb_build_array(
          jsonb_build_object(
            'service_date', '2026-08-03',
            'school_id', 'a7200000-0000-0000-0000-000000000026',
            'ingredient_id', 'a7200000-0000-0000-0000-000000000032',
            'pantry_need_purpose_id',
              'a7200000-0000-4000-8000-000000000001',
            'requested_quantity', '2.500000',
            'note', 'School request',
            'source_request_reference', 'REQ-1',
            'source_row_reference', 'sheet:2'
          ),
          jsonb_build_object(
            'service_date', '2026-08-04',
            'school_id', 'a7200000-0000-0000-0000-000000000026',
            'ingredient_id', 'a7200000-0000-0000-0000-000000000033',
            'pantry_need_purpose_id',
              'a7200000-0000-4000-8000-000000000002',
            'requested_quantity', '12',
            'note', 'Planning identified',
            'source_row_reference', 'sheet:3'
          )
        )
      )
    )
  )
from pantry02_results preview
where preview.result_name = 'preview-a';

select ok(
  (
    select (response_payload ->> 'success')::boolean
      and response_payload #>> '{new_versions,pantry_need_batch_version}'
        = '1'
      and response_payload #>>
        '{workbench,batch,pantry_need_batch_status}' = 'DRAFT'
    from pantry02_results
    where result_name = 'save-initial'
  ),
  'authorized initial save creates DRAFT version 1 with readback'
);

select is(
  pg_temp.pantry02_physical_count('active_lines'),
  2,
  'initial save persists exactly two active stable lines'
);

insert into pantry02_results
select
  'save-initial-replay',
  atlas_api.save_pantry_draft(
    pg_temp.pantry02_command(
      'save-initial',
      1,
      jsonb_build_object(
        'week_start', '2026-08-03',
        'no_additions_confirmed', false,
        'source_signature',
          preview.response_payload #>> '{preview,source_signature}',
        'expected_source_signature', null,
        'rows', jsonb_build_array(
          jsonb_build_object(
            'service_date', '2026-08-03',
            'school_id', 'a7200000-0000-0000-0000-000000000026',
            'ingredient_id', 'a7200000-0000-0000-0000-000000000032',
            'pantry_need_purpose_id',
              'a7200000-0000-4000-8000-000000000001',
            'requested_quantity', '2.500000',
            'note', 'School request',
            'source_request_reference', 'REQ-1',
            'source_row_reference', 'sheet:2'
          ),
          jsonb_build_object(
            'service_date', '2026-08-04',
            'school_id', 'a7200000-0000-0000-0000-000000000026',
            'ingredient_id', 'a7200000-0000-0000-0000-000000000033',
            'pantry_need_purpose_id',
              'a7200000-0000-4000-8000-000000000002',
            'requested_quantity', '12',
            'note', 'Planning identified',
            'source_row_reference', 'sheet:3'
          )
        )
      )
    )
  )
from pantry02_results preview
where preview.result_name = 'preview-a';

select ok(
  (
    select replay.response_payload = initial.response_payload
    from pantry02_results replay
    cross join pantry02_results initial
    where replay.result_name = 'save-initial-replay'
      and initial.result_name = 'save-initial'
  )
  and pg_temp.pantry02_physical_count('active_lines') = 2,
  'exact command replay returns the durable result without another write'
);

insert into pantry02_results
select
  'save-initial-conflict',
  atlas_api.save_pantry_draft(
    pg_temp.pantry02_command(
      'save-initial',
      1,
      jsonb_build_object(
        'week_start', '2026-08-03',
        'no_additions_confirmed', false,
        'source_signature',
          preview.response_payload #>> '{preview,source_signature}',
        'expected_source_signature', null,
        'rows', jsonb_build_array(
          jsonb_build_object(
            'service_date', '2026-08-03',
            'school_id', 'a7200000-0000-0000-0000-000000000026',
            'ingredient_id', 'a7200000-0000-0000-0000-000000000032',
            'pantry_need_purpose_id',
              'a7200000-0000-4000-8000-000000000001',
            'requested_quantity', '99',
            'note', 'Changed reuse must fail',
            'source_request_reference', 'REQ-1'
          )
        )
      )
    )
  )
from pantry02_results preview
where preview.result_name = 'preview-a';

select is(
  (
    select response_payload ->> 'error_code'
    from pantry02_results
    where result_name = 'save-initial-conflict'
  ),
  'IDEMPOTENCY_CONFLICT',
  'changed reuse of an idempotency key fails closed'
);

insert into pantry02_results values (
  'stale-signature',
  atlas_api.validate_pantry(
    pg_temp.pantry02_command(
      'stale-signature',
      1,
      jsonb_build_object(
        'week_start', '2026-08-03',
        'expected_source_signature', repeat('0', 64)
      )
    )
  )
);

select is(
  (
    select response_payload ->> 'error_code'
    from pantry02_results
    where result_name = 'stale-signature'
  ),
  'STALE_SOURCE_SIGNATURE',
  'current-version command with a stale source signature fails closed'
);

insert into pantry02_results
select
  'save-no-change',
  atlas_api.save_pantry_draft(
    pg_temp.pantry02_command(
      'save-no-change',
      1,
      jsonb_build_object(
        'week_start', '2026-08-03',
        'no_additions_confirmed', false,
        'source_signature',
          preview.response_payload #>> '{preview,source_signature}',
        'expected_source_signature',
          preview.response_payload #>> '{preview,source_signature}',
        'rows', jsonb_build_array(
          jsonb_build_object(
            'service_date', '2026-08-03',
            'school_id', 'a7200000-0000-0000-0000-000000000026',
            'ingredient_id', 'a7200000-0000-0000-0000-000000000032',
            'pantry_need_purpose_id',
              'a7200000-0000-4000-8000-000000000001',
            'requested_quantity', '2.5',
            'note', 'School request',
            'source_request_reference', 'REQ-1',
            'source_row_reference', 'changed-evidence'
          ),
          jsonb_build_object(
            'service_date', '2026-08-04',
            'school_id', 'a7200000-0000-0000-0000-000000000026',
            'ingredient_id', 'a7200000-0000-0000-0000-000000000033',
            'pantry_need_purpose_id',
              'a7200000-0000-4000-8000-000000000002',
            'requested_quantity', '12',
            'note', 'Planning identified',
            'source_row_reference', 'different-evidence'
          )
        )
      )
    )
  )
from pantry02_results preview
where preview.result_name = 'preview-a';

select ok(
  (
    select response_payload ->> 'idempotency_status' = 'NO_CHANGE'
      and jsonb_array_length(
        response_payload -> 'emitted_event_ids'
      ) = 0
      and response_payload #>> '{new_versions,pantry_need_batch_version}'
        = '1'
    from pantry02_results
    where result_name = 'save-no-change'
  ),
  'no business-fact change keeps the version and emits no event'
);

insert into pantry02_results values (
  'preview-replacement',
  atlas_api.preview_pantry_source(
    pg_temp.pantry02_read(
      jsonb_build_object(
        'week_start', '2026-08-03',
        'no_additions_confirmed', false,
        'rows', jsonb_build_array(
          jsonb_build_object(
            'service_date', '2026-08-03',
            'school_id', 'a7200000-0000-0000-0000-000000000026',
            'ingredient_id', 'a7200000-0000-0000-0000-000000000032',
            'pantry_need_purpose_id',
              'a7200000-0000-4000-8000-000000000001',
            'requested_quantity', '3',
            'note', 'Corrected school request',
            'source_request_reference', 'REQ-1'
          )
        )
      )
    )
  )
);

select ok(
  (
    select jsonb_array_length(
      response_payload #> '{preview,comparison,new_lines}'
    ) = 0
      and jsonb_array_length(
        response_payload #> '{preview,comparison,changed_lines}'
      ) = 1
      and jsonb_array_length(
        response_payload #> '{preview,comparison,unchanged_lines}'
      ) = 0
      and jsonb_array_length(
        response_payload #> '{preview,comparison,omitted_lines}'
      ) = 1
      and jsonb_array_length(
        response_payload #> '{preview,comparison,changed_school_dates}'
      ) = 2
    from pantry02_results
    where result_name = 'preview-replacement'
  ),
  'replacement preview categorizes changed and omitted stable grains'
);

insert into pantry02_results
select
  'save-replacement',
  atlas_api.save_pantry_draft(
    pg_temp.pantry02_command(
      'save-replacement',
      1,
      jsonb_build_object(
        'week_start', '2026-08-03',
        'no_additions_confirmed', false,
        'source_signature',
          replacement.response_payload #>> '{preview,source_signature}',
        'expected_source_signature',
          original.response_payload #>> '{preview,source_signature}',
        'rows', jsonb_build_array(
          jsonb_build_object(
            'service_date', '2026-08-03',
            'school_id', 'a7200000-0000-0000-0000-000000000026',
            'ingredient_id', 'a7200000-0000-0000-0000-000000000032',
            'pantry_need_purpose_id',
              'a7200000-0000-4000-8000-000000000001',
            'requested_quantity', '3',
            'note', 'Corrected school request',
            'source_request_reference', 'REQ-1'
          )
        )
      )
    )
  )
from pantry02_results replacement
cross join pantry02_results original
where replacement.result_name = 'preview-replacement'
  and original.result_name = 'preview-a';

select ok(
  (
    select (response_payload ->> 'success')::boolean
      and response_payload #>> '{new_versions,pantry_need_batch_version}'
        = '2'
    from pantry02_results
    where result_name = 'save-replacement'
  )
  and pg_temp.pantry02_physical_count('active_lines') = 1
  and pg_temp.pantry02_physical_count('invalid_lines') = 1
  and pg_temp.pantry02_physical_count('all_lines') = 2
  and (
    select replacement.response_payload #>>
      '{workbench,batch,active_lines,0,pantry_need_line_id}'
      =
      initial.response_payload #>>
        '{workbench,batch,active_lines,0,pantry_need_line_id}'
      and replacement.response_payload #>>
        '{workbench,batch,active_lines,0,requested_quantity}'
        = '3.000000'
    from pantry02_results replacement
    cross join pantry02_results initial
    where replacement.result_name = 'save-replacement'
      and initial.result_name = 'save-initial'
  ),
  'full replacement advances once, reuses one identity, and invalidates omission'
);

select is(
  (
    select response_payload #>>
      '{workbench,batch,active_lines,0,requested_quantity}'
    from pantry02_results
    where result_name = 'save-replacement'
  ),
  '3.000000',
  'working facts preserve the exact decimal quantity without rounding'
);

insert into pantry02_results
select
  'validate',
  atlas_api.validate_pantry(
    pg_temp.pantry02_command(
      'validate',
      2,
      jsonb_build_object(
        'week_start', '2026-08-03',
        'expected_source_signature',
          preview.response_payload #>> '{preview,source_signature}'
      )
    )
  )
from pantry02_results preview
where preview.result_name = 'preview-replacement';

insert into pantry02_results
select
  'approve',
  atlas_api.approve_pantry(
    pg_temp.pantry02_command(
      'approve',
      3,
      jsonb_build_object(
        'week_start', '2026-08-03',
        'expected_source_signature',
          preview.response_payload #>> '{preview,source_signature}'
      )
    )
  )
from pantry02_results preview
where preview.result_name = 'preview-replacement';

select ok(
  (
    select response_payload #>>
      '{workbench,batch,pantry_need_batch_status}' = 'APPROVED'
      and response_payload #>> '{new_versions,pantry_need_batch_version}'
        = '4'
      and jsonb_array_length(
        response_payload #> '{workbench,batch,approval_history}'
      ) = 1
    from pantry02_results
    where result_name = 'approve'
  )
  and pg_temp.pantry02_physical_count('snapshots') = 1
  and pg_temp.pantry02_physical_count('snapshot_lines') = 1,
  'validate and approve advance versions and capture every-and-only active line'
);

set constraints all immediate;
set constraints all deferred;

reset role;

select throws_ok(
  $$
    update atlas_planning.pantry_need_approval_snapshots
    set source_signature = repeat('0', 64)
  $$,
  '23514',
  'Pantry approval snapshots and snapshot lines are immutable',
  'approved Pantry snapshot headers cannot be updated'
);

select throws_ok(
  $$
    delete from atlas_planning.pantry_need_approval_snapshot_lines
  $$,
  '23514',
  'Pantry approval snapshots and snapshot lines are immutable',
  'approved Pantry snapshot lines cannot be deleted'
);

select throws_ok(
  $$
    update atlas_planning.pantry_need_purposes
    set
      purpose_code = 'changed_after_use',
      version = version + 1
    where pantry_need_purpose_id =
      'a7200000-0000-4000-8000-000000000001'
  $$,
  '23514',
  'an operationally used Pantry Purpose code is immutable',
  'a Pantry Purpose code is immutable after operational use'
);

select throws_ok(
  $$
    delete from atlas_planning.pantry_need_purposes
    where pantry_need_purpose_id =
      'a7200000-0000-4000-8000-000000000001'
  $$,
  '23503',
  'referenced Pantry Purposes cannot be deleted',
  'a referenced Pantry Purpose cannot be hard-deleted'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a7200000-0000-0000-0000-000000000110',
  true
);

insert into pantry02_results
select
  'reopen',
  atlas_api.reopen_pantry(
    pg_temp.pantry02_command(
      'reopen',
      4,
      jsonb_build_object(
        'week_start', '2026-08-03',
        'expected_source_signature',
          preview.response_payload #>> '{preview,source_signature}'
      ),
      'Correct the approved quantity.'
    )
  )
from pantry02_results preview
where preview.result_name = 'preview-replacement';

select ok(
  (
    select response_payload #>>
      '{workbench,batch,pantry_need_batch_status}' = 'REOPENED'
      and response_payload #>> '{new_versions,pantry_need_batch_version}'
        = '5'
      and jsonb_array_length(
        response_payload #> '{workbench,batch,approval_history}'
      ) = 1
    from pantry02_results
    where result_name = 'reopen'
  ),
  'reasoned reopen advances once and preserves prior approval history'
);

insert into pantry02_results values (
  'preview-second',
  atlas_api.preview_pantry_source(
    pg_temp.pantry02_read(
      jsonb_build_object(
        'week_start', '2026-08-03',
        'no_additions_confirmed', false,
        'rows', jsonb_build_array(
          jsonb_build_object(
            'service_date', '2026-08-03',
            'school_id', 'a7200000-0000-0000-0000-000000000026',
            'ingredient_id', 'a7200000-0000-0000-0000-000000000032',
            'pantry_need_purpose_id',
              'a7200000-0000-4000-8000-000000000001',
            'requested_quantity', '4',
            'note', 'Second approved correction',
            'source_request_reference', 'REQ-1'
          )
        )
      )
    )
  )
);

insert into pantry02_results
select
  'save-second',
  atlas_api.save_pantry_draft(
    pg_temp.pantry02_command(
      'save-second',
      5,
      jsonb_build_object(
        'week_start', '2026-08-03',
        'no_additions_confirmed', false,
        'source_signature',
          next_preview.response_payload #>> '{preview,source_signature}',
        'expected_source_signature',
          prior_preview.response_payload #>> '{preview,source_signature}',
        'rows', jsonb_build_array(
          jsonb_build_object(
            'service_date', '2026-08-03',
            'school_id', 'a7200000-0000-0000-0000-000000000026',
            'ingredient_id', 'a7200000-0000-0000-0000-000000000032',
            'pantry_need_purpose_id',
              'a7200000-0000-4000-8000-000000000001',
            'requested_quantity', '4',
            'note', 'Second approved correction',
            'source_request_reference', 'REQ-1'
          )
        )
      )
    )
  )
from pantry02_results next_preview
cross join pantry02_results prior_preview
where next_preview.result_name = 'preview-second'
  and prior_preview.result_name = 'preview-replacement';

insert into pantry02_results
select
  'validate-second',
  atlas_api.validate_pantry(
    pg_temp.pantry02_command(
      'validate-second',
      6,
      jsonb_build_object(
        'week_start', '2026-08-03',
        'expected_source_signature',
          preview.response_payload #>> '{preview,source_signature}'
      )
    )
  )
from pantry02_results preview
where preview.result_name = 'preview-second';

insert into pantry02_results
select
  'approve-second',
  atlas_api.approve_pantry(
    pg_temp.pantry02_command(
      'approve-second',
      7,
      jsonb_build_object(
        'week_start', '2026-08-03',
        'expected_source_signature',
          preview.response_payload #>> '{preview,source_signature}'
      )
    )
  )
from pantry02_results preview
where preview.result_name = 'preview-second';

select ok(
  (
    select response_payload #>>
      '{workbench,batch,pantry_need_batch_status}' = 'REOPENED'
      and response_payload #>> '{new_versions,pantry_need_batch_version}'
        = '6'
    from pantry02_results
    where result_name = 'save-second'
  )
  and (
    select response_payload #>>
      '{workbench,batch,pantry_need_batch_status}' = 'VALIDATED'
      and response_payload #>> '{new_versions,pantry_need_batch_version}'
        = '7'
    from pantry02_results
    where result_name = 'validate-second'
  )
  and (
    select response_payload #>> '{new_versions,pantry_need_batch_version}'
        = '8'
      and response_payload #>>
        '{workbench,batch,pantry_need_batch_status}' = 'APPROVED'
      and jsonb_array_length(
        response_payload #> '{workbench,batch,approval_history}'
      ) = 2
      and response_payload #>>
        '{workbench,batch,approval_history,0,approved_batch_version}'
        = '8'
      and response_payload #>>
        '{workbench,batch,approval_history,1,approved_batch_version}'
        = '4'
    from pantry02_results
    where result_name = 'approve-second'
  )
  and pg_temp.pantry02_physical_count('snapshots') = 2
  and pg_temp.pantry02_physical_count('snapshot_lines') = 2,
  'REOPENED correction stays REOPENED v6, validates v7, and reapproves v8 without mutating the first snapshot'
);

insert into pantry02_results values (
  'preview-zero',
  atlas_api.preview_pantry_source(
    pg_temp.pantry02_read(
      jsonb_build_object(
        'week_start', '2026-08-10',
        'no_additions_confirmed', true,
        'rows', jsonb_build_array()
      )
    )
  )
);

insert into pantry02_results
select
  'save-zero',
  atlas_api.save_pantry_draft(
    pg_temp.pantry02_command(
      'save-zero',
      1,
      jsonb_build_object(
        'week_start', '2026-08-10',
        'no_additions_confirmed', true,
        'source_signature',
          preview.response_payload #>> '{preview,source_signature}',
        'expected_source_signature', null,
        'rows', jsonb_build_array()
      )
    )
  )
from pantry02_results preview
where preview.result_name = 'preview-zero';

insert into pantry02_results
select
  'validate-zero',
  atlas_api.validate_pantry(
    pg_temp.pantry02_command(
      'validate-zero',
      1,
      jsonb_build_object(
        'week_start', '2026-08-10',
        'expected_source_signature',
          preview.response_payload #>> '{preview,source_signature}'
      )
    )
  )
from pantry02_results preview
where preview.result_name = 'preview-zero';

insert into pantry02_results
select
  'approve-zero',
  atlas_api.approve_pantry(
    pg_temp.pantry02_command(
      'approve-zero',
      2,
      jsonb_build_object(
        'week_start', '2026-08-10',
        'expected_source_signature',
          preview.response_payload #>> '{preview,source_signature}'
      )
    )
  )
from pantry02_results preview
where preview.result_name = 'preview-zero';

set constraints all immediate;
set constraints all deferred;

select ok(
  (
    select response_payload #>>
      '{workbench,batch,pantry_need_batch_status}' = 'APPROVED'
      and response_payload #>>
        '{workbench,batch,no_additions_confirmed}' = 'true'
      and response_payload #>>
        '{workbench,batch,approval_history,0,line_count}' = '0'
    from pantry02_results
    where result_name = 'approve-zero'
  ),
  'explicit zero-additions week validates and approves with a zero-line snapshot'
);

select is(
  (
    select atlas_api.get_pantry_source_workbench(
      pg_temp.pantry02_read(
        jsonb_build_object('week_start', '2026-08-03'),
        'a7200000-0000-0000-0000-000000000111'
      )
    ) ->> 'error_code'
  ),
  'AUTH_SUBJECT_MISMATCH',
  'request subject must equal auth.uid()'
);

select is(
  (
    select atlas_api.get_pantry_source_workbench(
      pg_temp.pantry02_read(
        jsonb_build_object('week_start', '2026-08-03'),
        'a7200000-0000-0000-0000-000000000110'
      )
      || jsonb_build_object(
        'requested_by_auth_subject',
          'a7200000-0000-0000-0000-000000000111'
      )
    ) ->> 'error_code'
  ),
  'AUTH_SUBJECT_MISMATCH',
  'a mapped but different requested subject is denied'
);

select is(
  (
    select atlas_api.validate_pantry(
      pg_temp.pantry02_command(
        'stale-validation',
        1,
        jsonb_build_object(
          'week_start', '2026-08-03',
          'expected_source_signature', repeat('0', 64)
        )
      )
    ) ->> 'error_code'
  ),
  'STALE_VERSION',
  'stale lifecycle command fails closed'
);

select is(
  pg_temp.pantry02_physical_count('events'),
  11,
  'every material Pantry action emits exactly one domain event'
);

select is(
  pg_temp.pantry02_physical_count('audits'),
  11,
  'every material Pantry action emits exactly one audit event'
);

select set_config(
  'request.jwt.claim.sub',
  'a7200000-0000-0000-0000-000000000111',
  true
);

select is(
  atlas_api.get_pantry_source_workbench(
    pg_temp.pantry02_read(
      jsonb_build_object('week_start', '2026-08-03'),
      'a7200000-0000-0000-0000-000000000111'
    )
  ) ->> 'error_code',
  'CAPABILITY_DENIED',
  'an authenticated Actor without the read capability is denied'
);

reset role;

update atlas_core.actor_scopes
set scope_status = 'REVOKED'
where actor_id = 'a7200000-0000-0000-0000-000000000010'
  and scope_kind = 'GLOBAL';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'a7200000-0000-0000-0000-000000000110',
  true
);

select is(
  atlas_api.get_pantry_source_workbench(
    pg_temp.pantry02_read(
      jsonb_build_object('week_start', '2026-08-03')
    )
  ) ->> 'error_code',
  'SCOPE_DENIED',
  'the existing global Planning scope remains mandatory'
);

reset role;

select is(
  (
    (select count(*) from atlas_planning.planning_input_sets)
    + (select count(*) from atlas_planning.need_generation_runs)
    + (select count(*) from atlas_planning.confirmed_need_batches)
    + (select count(*) from atlas_planning.purchase_handoff_batches)
    + (select count(*) from atlas_planning.wholesale_orders)
    + (select count(*) from atlas_procurement.fulfilment_allocations)
    + (select count(*) from atlas_procurement.purchase_orders)
    + (select count(*) from atlas_evidence.supplier_receiving_evidence)
    + (select count(*) from atlas_dispatch.dispatch_plans)
  )::integer,
  0,
  'Pantry approval writes no readiness, Need, handoff, Wholesale, Procurement, receiving, or Dispatch object'
);

select * from finish();
rollback;
