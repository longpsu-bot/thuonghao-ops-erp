-- RMVP-03A: connected Weekly Menu and Attendance workbench.
--
-- This migration exposes the existing PA-06E-H0A3a/H0A3b persistence through
-- one reviewed Planning read/command boundary. It adds the typed Dish Type
-- catalog and the narrow Google Sheet source configuration used by that
-- boundary. It deliberately creates no competing Planning object, runtime
-- role, downstream Need Generation mutation, or legacy write path.

set role atlas_owner;

create table atlas_admin.dish_types (
  dish_type_id uuid not null default gen_random_uuid(),
  dish_type_code text not null,
  dish_type_name text not null,
  source_header_aliases text[] not null default '{}'::text[],
  display_order integer not null default 0,
  dish_type_status text not null default 'ACTIVE',
  version bigint not null default 1,
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  constraint dish_types_pkey primary key (dish_type_id),
  constraint dish_types_code_key unique (dish_type_code),
  constraint dish_types_code_check check (
    dish_type_code = lower(btrim(dish_type_code))
    and dish_type_code ~ '^[a-z][a-z0-9_]*$'
  ),
  constraint dish_types_name_check check (btrim(dish_type_name) <> ''),
  constraint dish_types_aliases_check check (
    array_position(source_header_aliases, '') is null
  ),
  constraint dish_types_display_order_check check (display_order >= 0),
  constraint dish_types_status_check check (
    dish_type_status in ('ACTIVE', 'INACTIVE')
  ),
  constraint dish_types_version_check check (version > 0),
  constraint dish_types_timestamps_check check (updated_at >= created_at)
);

create index dish_types_status_display_order_idx
  on atlas_admin.dish_types (
    dish_type_status,
    display_order,
    dish_type_code,
    dish_type_id
  );

insert into atlas_admin.dish_types (
  dish_type_id,
  dish_type_code,
  dish_type_name,
  source_header_aliases,
  display_order
) values
  (
    'd1500000-0000-4000-8000-000000000001',
    'soup',
    'Món canh',
    array['Canh', 'Mon canh', 'Món Canh']::text[],
    1
  ),
  (
    'd1500000-0000-4000-8000-000000000002',
    'savory',
    'Món mặn',
    array['Mặn', 'Mon man', 'Món Mặn']::text[],
    2
  ),
  (
    'd1500000-0000-4000-8000-000000000003',
    'stir_fry',
    'Món xào',
    array['Xào', 'Mon xao', 'Món Xào']::text[],
    3
  ),
  (
    'd1500000-0000-4000-8000-000000000004',
    'dessert',
    'Tráng miệng',
    array['Trang mieng', 'Tráng Miệng']::text[],
    4
  ),
  (
    'd1500000-0000-4000-8000-000000000005',
    'afternoon_snack',
    'Buổi xế',
    array['Bữa xế', 'Bua xe', 'Buoi xe']::text[],
    5
  ),
  (
    'd1500000-0000-4000-8000-000000000006',
    'beverage',
    'Nước',
    array['Nuoc', 'Đồ uống', 'Do uong']::text[],
    6
  );

alter table atlas_admin.dishes
  add column dish_type_id uuid,
  add constraint dishes_dish_type_fkey foreign key (dish_type_id)
    references atlas_admin.dish_types (dish_type_id) on delete restrict;

create index dishes_dish_type_idx
  on atlas_admin.dishes (dish_type_id)
  where dish_type_id is not null;

alter table atlas_planning.weekly_menu_lines
  add constraint weekly_menu_lines_menu_slot_type_fkey
    foreign key (menu_slot_code)
    references atlas_admin.dish_types (dish_type_code)
    on update restrict
    on delete restrict;

create index weekly_menu_lines_menu_slot_type_idx
  on atlas_planning.weekly_menu_lines (menu_slot_code);

create table atlas_planning.weekly_menu_google_sources (
  weekly_menu_google_source_id uuid not null default gen_random_uuid(),
  source_code text not null,
  source_name text not null,
  spreadsheet_id text not null,
  sheet_name_pattern text not null,
  range_a1_template text not null,
  source_status text not null default 'ACTIVE',
  display_order integer not null default 0,
  version bigint not null default 1,
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  constraint weekly_menu_google_sources_pkey primary key (
    weekly_menu_google_source_id
  ),
  constraint weekly_menu_google_sources_code_key unique (source_code),
  constraint weekly_menu_google_sources_code_check check (
    source_code = lower(btrim(source_code))
    and source_code ~ '^[a-z][a-z0-9_.-]*$'
  ),
  constraint weekly_menu_google_sources_name_check check (
    btrim(source_name) <> ''
  ),
  constraint weekly_menu_google_sources_spreadsheet_check check (
    btrim(spreadsheet_id) <> ''
  ),
  constraint weekly_menu_google_sources_sheet_pattern_check check (
    btrim(sheet_name_pattern) <> ''
    and position('{DD-MM-YYYY}' in sheet_name_pattern) > 0
  ),
  constraint weekly_menu_google_sources_range_check check (
    btrim(range_a1_template) <> ''
    and position('{sheet}' in range_a1_template) > 0
  ),
  constraint weekly_menu_google_sources_status_check check (
    source_status in ('ACTIVE', 'INACTIVE')
  ),
  constraint weekly_menu_google_sources_display_order_check check (
    display_order >= 0
  ),
  constraint weekly_menu_google_sources_version_check check (version > 0),
  constraint weekly_menu_google_sources_timestamps_check check (
    updated_at >= created_at
  )
);

create index weekly_menu_google_sources_status_order_idx
  on atlas_planning.weekly_menu_google_sources (
    source_status,
    display_order,
    source_code,
    weekly_menu_google_source_id
  );

alter table atlas_admin.dish_types enable row level security;
alter table atlas_admin.dish_types force row level security;
alter table atlas_planning.weekly_menu_google_sources
  enable row level security;
alter table atlas_planning.weekly_menu_google_sources
  force row level security;

reset role;

insert into atlas_core.capabilities (
  capability_code,
  capability_name,
  owning_domain,
  capability_status
) values
  (
    'planning.inputs.read',
    'Read Weekly Menu and Attendance inputs',
    'PLANNING',
    'ACTIVE'
  ),
  (
    'planning.weekly_menu.write',
    'Maintain Weekly Menu drafts',
    'PLANNING',
    'ACTIVE'
  ),
  (
    'planning.attendance.write',
    'Maintain Attendance drafts',
    'PLANNING',
    'ACTIVE'
  ),
  (
    'planning.inputs.approve',
    'Approve and reopen Planning inputs',
    'PLANNING',
    'ACTIVE'
  );

create or replace function atlas_core.rmvp_03a_safe_nonnegative_integer(
  value text
)
returns integer
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_value bigint;
begin
  if value is null or pg_catalog.btrim(value) !~ '^[0-9]+$' then
    return null;
  end if;
  v_value := pg_catalog.btrim(value)::bigint;
  if v_value > 2147483647 then
    return null;
  end if;
  return v_value::integer;
exception
  when numeric_value_out_of_range then
    return null;
end;
$$;

create or replace function atlas_core.rmvp_03a_normalize_text(value text)
returns text
language sql
immutable
set search_path = ''
as $$
  select nullif(
    pg_catalog.normalize(
      pg_catalog.btrim(coalesce(value, '')),
      'NFC'
    ),
    ''
  );
$$;

create or replace function atlas_core.rmvp_03a_sha256(value jsonb)
returns text
language sql
immutable
set search_path = ''
as $$
  select pg_catalog.encode(
    extensions.digest(
      pg_catalog.convert_to(coalesce(value, 'null'::jsonb)::text, 'UTF8'),
      'sha256'
    ),
    'hex'
  );
$$;

create or replace function atlas_core.rmvp_03a_canonical_menu_rows(
  rows jsonb
)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  with source_rows as (
    select
      item.value,
      item.ordinality
    from pg_catalog.jsonb_array_elements(
      case
        when pg_catalog.jsonb_typeof(rows) = 'array' then rows
        else '[]'::jsonb
      end
    ) with ordinality item(value, ordinality)
  ),
  normalized as (
    select
      atlas_core.rmvp_03a_normalize_text(value ->> 'school_id')
        as school_id,
      atlas_core.rmvp_03a_normalize_text(value ->> 'service_date')
        as service_date,
      pg_catalog.lower(
        coalesce(
          atlas_core.rmvp_03a_normalize_text(value ->> 'menu_slot_code'),
          ''
        )
      ) as menu_slot_code,
      atlas_core.rmvp_03a_normalize_text(value ->> 'dish_id') as dish_id,
      coalesce(
        atlas_core.rmvp_03a_normalize_text(
          value ->> 'source_row_reference'
        ),
        'row:' || ordinality::text
      ) as source_row_reference
    from source_rows
  ),
  meaningful as (
    select *
    from normalized
    where school_id is not null
       or service_date is not null
       or menu_slot_code <> ''
       or dish_id is not null
  )
  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'school_id', school_id,
        'service_date', service_date,
        'menu_slot_code', nullif(menu_slot_code, ''),
        'dish_id', dish_id,
        'source_row_reference', source_row_reference
      )
      order by
        coalesce(school_id, ''),
        coalesce(service_date, ''),
        menu_slot_code,
        coalesce(dish_id, ''),
        source_row_reference
    ),
    '[]'::jsonb
  )
  from meaningful;
$$;

create or replace function atlas_core.rmvp_03a_menu_signature(rows jsonb)
returns text
language sql
immutable
set search_path = ''
as $$
  with canonical as (
    select value
    from pg_catalog.jsonb_array_elements(
      atlas_core.rmvp_03a_canonical_menu_rows(rows)
    )
  )
  select atlas_core.rmvp_03a_sha256(
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          value - 'source_row_reference'
          order by
            value ->> 'school_id',
            value ->> 'service_date',
            value ->> 'menu_slot_code',
            value ->> 'dish_id'
        )
        from canonical
      ),
      '[]'::jsonb
    )
  );
$$;

create or replace function atlas_core.rmvp_03a_canonical_attendance_rows(
  rows jsonb
)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  with source_rows as (
    select
      item.value,
      item.ordinality
    from pg_catalog.jsonb_array_elements(
      case
        when pg_catalog.jsonb_typeof(rows) = 'array' then rows
        else '[]'::jsonb
      end
    ) with ordinality item(value, ordinality)
  ),
  normalized as (
    select
      atlas_core.rmvp_03a_normalize_text(value ->> 'school_id')
        as school_id,
      atlas_core.rmvp_03a_normalize_text(value ->> 'service_date')
        as service_date,
      atlas_core.rmvp_03a_normalize_text(value ->> 'student_portions')
        as student_portions_text,
      atlas_core.rmvp_03a_normalize_text(value ->> 'teacher_portions')
        as teacher_portions_text,
      coalesce(
        atlas_core.rmvp_03a_normalize_text(
          value ->> 'source_row_reference'
        ),
        'row:' || ordinality::text
      ) as source_row_reference
    from source_rows
  ),
  meaningful as (
    select *
    from normalized
    where school_id is not null
       or service_date is not null
       or student_portions_text is not null
       or teacher_portions_text is not null
  )
  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'school_id', school_id,
        'service_date', service_date,
        'student_portions',
          coalesce(
            pg_catalog.to_jsonb(
              atlas_core.rmvp_03a_safe_nonnegative_integer(
                student_portions_text
              )
            ),
            pg_catalog.to_jsonb(student_portions_text)
          ),
        'teacher_portions',
          coalesce(
            pg_catalog.to_jsonb(
              atlas_core.rmvp_03a_safe_nonnegative_integer(
                teacher_portions_text
              )
            ),
            pg_catalog.to_jsonb(teacher_portions_text)
          ),
        'source_row_reference', source_row_reference
      )
      order by
        coalesce(school_id, ''),
        coalesce(service_date, ''),
        coalesce(student_portions_text, ''),
        coalesce(teacher_portions_text, ''),
        source_row_reference
    ),
    '[]'::jsonb
  )
  from meaningful;
$$;

create or replace function atlas_core.rmvp_03a_attendance_signature(
  rows jsonb
)
returns text
language sql
immutable
set search_path = ''
as $$
  with canonical as (
    select value
    from pg_catalog.jsonb_array_elements(
      atlas_core.rmvp_03a_canonical_attendance_rows(rows)
    )
  )
  select atlas_core.rmvp_03a_sha256(
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          value - 'source_row_reference'
          order by
            value ->> 'school_id',
            value ->> 'service_date',
            value ->> 'student_portions',
            value ->> 'teacher_portions'
        )
        from canonical
      ),
      '[]'::jsonb
    )
  );
$$;

create or replace function atlas_core.rmvp_03a_read_error(
  request jsonb,
  read_name text,
  error_code text,
  safe_message text,
  field_errors jsonb default '[]'::jsonb
)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'success', false,
    'contract_version', 'RMVP-03A.v1',
    'error_code', error_code,
    'safe_message', safe_message,
    'domain', 'PLANNING',
    'read_name', read_name,
    'field_errors', coalesce(field_errors, '[]'::jsonb),
    'correlation_id', request ->> 'correlation_id'
  );
$$;

create or replace function atlas_core.rmvp_03a_validate_read_request(
  request jsonb,
  read_name text
)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_errors jsonb := '[]'::jsonb;
begin
  if request is null or pg_catalog.jsonb_typeof(request) <> 'object' then
    return atlas_core.rmvp_03a_read_error(
      coalesce(request, '{}'::jsonb),
      read_name,
      'VALIDATION_FAILED',
      'The read request must be a JSON object.'
    );
  end if;
  if request ->> 'contract_version' is distinct from 'RMVP-03A.v1' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'contract_version',
        'message', 'Use RMVP-03A.v1.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(
    request ->> 'requested_by_auth_subject'
  ) is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'requested_by_auth_subject',
        'message', 'A valid UUID is required.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id') is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'correlation_id',
        'message', 'A valid UUID is required.'
      )
    );
  end if;
  if request -> 'payload' is null
     or pg_catalog.jsonb_typeof(request -> 'payload') <> 'object' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'payload',
        'message', 'A JSON object is required.'
      )
    );
  elsif atlas_core.pa_05d_safe_date(
    request -> 'payload' ->> 'week_start'
  ) is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'payload.week_start',
        'message', 'An explicit ISO service-week start is required.'
      )
    );
  end if;
  if pg_catalog.jsonb_array_length(v_errors) > 0 then
    return atlas_core.rmvp_03a_read_error(
      request,
      read_name,
      'VALIDATION_FAILED',
      'The read envelope is invalid.',
      v_errors
    );
  end if;
  return null;
end;
$$;

create or replace function atlas_core.rmvp_03a_validate_command_request(
  request jsonb,
  command_name text
)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_errors jsonb := '[]'::jsonb;
  v_requested_at timestamptz;
begin
  if request is null or pg_catalog.jsonb_typeof(request) <> 'object' then
    return atlas_core.pa_05b_command_error(
      coalesce(request, '{}'::jsonb),
      'VALIDATION_FAILED',
      'The command request must be a JSON object.',
      'PLANNING',
      command_name
    );
  end if;
  if request ->> 'contract_version' is distinct from 'RMVP-03A.v1' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'contract_version',
        'message', 'Use RMVP-03A.v1.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'command_id') is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'command_id',
        'message', 'A valid UUID is required.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id') is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'correlation_id',
        'message', 'A valid UUID is required.'
      )
    );
  end if;
  if pg_catalog.btrim(coalesce(request ->> 'idempotency_key', '')) = ''
     or pg_catalog.length(request ->> 'idempotency_key') > 200 then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'idempotency_key',
        'message', 'A non-empty key of at most 200 characters is required.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') is null
     or atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') <= 0 then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'expected_version',
        'message', 'A positive integer version is required.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(
    request ->> 'requested_by_auth_subject'
  ) is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'requested_by_auth_subject',
        'message', 'A valid UUID is required.'
      )
    );
  end if;
  v_requested_at := atlas_core.pa_05b_safe_timestamptz(
    request ->> 'requested_at'
  );
  if v_requested_at is null
     or v_requested_at > pg_catalog.transaction_timestamp() then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'requested_at',
        'message', 'A valid non-future timestamp is required.'
      )
    );
  end if;
  if pg_catalog.btrim(coalesce(request ->> 'reason_code', '')) = '' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'reason_code',
        'message', 'A reason code is required.'
      )
    );
  end if;
  if not (request ? 'reason_note') then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'reason_note',
        'message', 'reason_note is required and may be null.'
      )
    );
  end if;
  if request -> 'payload' is null
     or pg_catalog.jsonb_typeof(request -> 'payload') <> 'object' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'payload',
        'message', 'A JSON object is required.'
      )
    );
  elsif atlas_core.pa_05d_safe_date(
    request -> 'payload' ->> 'week_start'
  ) is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'payload.week_start',
        'message', 'An explicit ISO service-week start is required.'
      )
    );
  end if;
  if pg_catalog.jsonb_array_length(v_errors) > 0 then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'The command envelope is invalid.',
      'PLANNING',
      command_name,
      false,
      v_errors
    );
  end if;
  return null;
end;
$$;

create or replace function atlas_core.rmvp_03a_authorize_global(
  request jsonb,
  capability_code text,
  operation_name text
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_actor_context jsonb;
  v_actor_id uuid;
  v_error jsonb;
begin
  v_actor_context := atlas_core.pa_05b_resolve_actor(
    request,
    'PLANNING',
    operation_name
  );
  if v_actor_context ? 'error' then
    return v_actor_context;
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_actor_context ->> 'actor_id');
  v_error := atlas_core.pa_05b_authorize_actor(
    request,
    v_actor_id,
    capability_code,
    'PLANNING',
    operation_name,
    null,
    null,
    null
  );
  if v_error is not null then
    return pg_catalog.jsonb_build_object('error', v_error);
  end if;
  return pg_catalog.jsonb_build_object('actor_id', v_actor_id);
end;
$$;

create or replace function atlas_core.rmvp_03a_prepare_command(
  request jsonb,
  command_name text,
  capability_code text,
  aggregate_scope text
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  v_error jsonb;
  v_context jsonb;
  v_actor_id uuid;
  v_begin jsonb;
begin
  v_error := atlas_core.rmvp_03a_validate_command_request(
    request,
    command_name
  );
  if v_error is not null then
    return pg_catalog.jsonb_build_object(
      'status', 'RETURN',
      'response', v_error
    );
  end if;
  v_context := atlas_core.rmvp_03a_authorize_global(
    request,
    capability_code,
    command_name
  );
  if v_context ? 'error' then
    return pg_catalog.jsonb_build_object(
      'status', 'RETURN',
      'response', v_context -> 'error'
    );
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_context ->> 'actor_id');
  v_begin := atlas_core.pa_05b_begin_command(
    request,
    v_actor_id,
    command_name,
    'PLANNING',
    aggregate_scope
  );
  if v_begin ->> 'status' in ('REPLAY', 'ERROR') then
    return pg_catalog.jsonb_build_object(
      'status', 'RETURN',
      'response', v_begin -> 'response'
    );
  end if;
  return pg_catalog.jsonb_build_object(
    'status', 'READY',
    'actor_id', v_actor_id,
    'receipt_id', v_begin ->> 'receipt_id'
  );
end;
$$;

create or replace function atlas_core.rmvp_03a_menu_issues(
  week_start date,
  rows jsonb
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with canonical as (
    select value as row
    from pg_catalog.jsonb_array_elements(
      atlas_core.rmvp_03a_canonical_menu_rows(rows)
    )
  ),
  issues as (
    select
      'BLOCKER'::text as severity,
      'EMPTY_WEEKLY_MENU'::text as code,
      'The weekly menu contains no meaningful assignment.'::text as message,
      null::text as source_row_reference
    where not exists (select 1 from canonical)
    union all
    select
      'BLOCKER', 'INVALID_SCHOOL_ID',
      'A row does not identify a valid school.',
      row ->> 'source_row_reference'
    from canonical
    where atlas_core.pa_05b_safe_uuid(row ->> 'school_id') is null
    union all
    select
      'BLOCKER', 'INVALID_SERVICE_DATE',
      'A row does not contain a valid ISO service date.',
      row ->> 'source_row_reference'
    from canonical
    where atlas_core.pa_05d_safe_date(row ->> 'service_date') is null
    union all
    select
      'BLOCKER', 'SERVICE_DATE_OUTSIDE_WEEK',
      'A menu assignment falls outside the selected service week.',
      row ->> 'source_row_reference'
    from canonical
    where atlas_core.pa_05d_safe_date(row ->> 'service_date') is not null
      and atlas_core.pa_05d_safe_date(row ->> 'service_date')
        not between week_start and week_start + 6
    union all
    select
      'BLOCKER', 'UNKNOWN_DISH_TYPE',
      'A row references a Dish Type that does not exist.',
      row ->> 'source_row_reference'
    from canonical
    where not exists (
      select 1
      from atlas_admin.dish_types dish_type
      where dish_type.dish_type_code = row ->> 'menu_slot_code'
    )
    union all
    select
      'BLOCKER', 'INACTIVE_DISH_TYPE',
      'A row references an inactive Dish Type.',
      row ->> 'source_row_reference'
    from canonical
    join atlas_admin.dish_types dish_type
      on dish_type.dish_type_code = row ->> 'menu_slot_code'
    where dish_type.dish_type_status <> 'ACTIVE'
    union all
    select
      'BLOCKER', 'INVALID_DISH_ID',
      'A row does not identify a valid dish.',
      row ->> 'source_row_reference'
    from canonical
    where atlas_core.pa_05b_safe_uuid(row ->> 'dish_id') is null
    union all
    select
      'BLOCKER', 'UNKNOWN_SCHOOL',
      'A row references a school that does not exist.',
      row ->> 'source_row_reference'
    from canonical
    where atlas_core.pa_05b_safe_uuid(row ->> 'school_id') is not null
      and not exists (
        select 1
        from atlas_admin.schools school
        where school.school_id =
          atlas_core.pa_05b_safe_uuid(row ->> 'school_id')
      )
    union all
    select
      'BLOCKER', 'INACTIVE_SCHOOL',
      'A row references an inactive school.',
      row ->> 'source_row_reference'
    from canonical
    join atlas_admin.schools school
      on school.school_id =
        atlas_core.pa_05b_safe_uuid(row ->> 'school_id')
    where school.school_status <> 'ACTIVE'
    union all
    select
      'BLOCKER', 'UNKNOWN_DISH',
      'A row references a dish that does not exist.',
      row ->> 'source_row_reference'
    from canonical
    where atlas_core.pa_05b_safe_uuid(row ->> 'dish_id') is not null
      and not exists (
        select 1
        from atlas_admin.dishes dish
        where dish.dish_id =
          atlas_core.pa_05b_safe_uuid(row ->> 'dish_id')
      )
    union all
    select
      'BLOCKER', 'INACTIVE_DISH',
      'A row references an inactive dish.',
      row ->> 'source_row_reference'
    from canonical
    join atlas_admin.dishes dish
      on dish.dish_id =
        atlas_core.pa_05b_safe_uuid(row ->> 'dish_id')
    where dish.dish_status <> 'ACTIVE'
    union all
    select
      'BLOCKER', 'UNMAPPED_DISH_TYPE',
      'The selected Dish is not mapped to a Dish Type.',
      row ->> 'source_row_reference'
    from canonical
    join atlas_admin.dishes dish
      on dish.dish_id =
        atlas_core.pa_05b_safe_uuid(row ->> 'dish_id')
    where dish.dish_type_id is null
    union all
    select
      'BLOCKER', 'DISH_TYPE_MISMATCH',
      'The selected Dish does not match the Menu slot Dish Type.',
      row ->> 'source_row_reference'
    from canonical
    join atlas_admin.dishes dish
      on dish.dish_id =
        atlas_core.pa_05b_safe_uuid(row ->> 'dish_id')
    join atlas_admin.dish_types dish_type
      on dish_type.dish_type_code = row ->> 'menu_slot_code'
    where dish.dish_type_id is distinct from dish_type.dish_type_id
    union all
    select
      'BLOCKER', 'DUPLICATE_MENU_ASSIGNMENT',
      'The same school, date, and menu slot appears more than once.',
      pg_catalog.min(row ->> 'source_row_reference')
    from canonical
    group by
      row ->> 'school_id',
      row ->> 'service_date',
      row ->> 'menu_slot_code'
    having count(*) > 1
    union all
    select
      'WARNING', 'RECIPE_NOT_READY',
      'The assigned dish has no released active recipe for this school type.',
      row ->> 'source_row_reference'
    from canonical
    join atlas_admin.schools school
      on school.school_id =
        atlas_core.pa_05b_safe_uuid(row ->> 'school_id')
     and school.school_status = 'ACTIVE'
    join atlas_admin.dishes dish
      on dish.dish_id =
        atlas_core.pa_05b_safe_uuid(row ->> 'dish_id')
     and dish.dish_status = 'ACTIVE'
    where dish.requires_need_generation
      and not exists (
        select 1
        from atlas_admin.recipes recipe
        join atlas_admin.recipe_versions version
          on version.recipe_id = recipe.recipe_id
        where recipe.dish_id = dish.dish_id
          and recipe.recipe_status = 'ACTIVE'
          and version.recipe_version_status = 'RELEASED_FOR_PLANNING'
          and (
            recipe.school_type_id is null
            or recipe.school_type_id = school.school_type_id
          )
      )
    union all
    select
      'WARNING', 'EFFECTIVE_BOM_BLOCKED',
      'Effective Recipe composition is currently blocked for this assignment.',
      row ->> 'source_row_reference'
    from canonical
    join atlas_admin.schools school
      on school.school_id =
        atlas_core.pa_05b_safe_uuid(row ->> 'school_id')
     and school.school_status = 'ACTIVE'
    join atlas_admin.dishes dish
      on dish.dish_id =
        atlas_core.pa_05b_safe_uuid(row ->> 'dish_id')
     and dish.dish_status = 'ACTIVE'
    cross join lateral (
      select atlas_core.rmvp_02b_resolve_effective_composition(
        atlas_core.pa_05d_safe_date(row ->> 'service_date'),
        school.school_id,
        dish.dish_id,
        null,
        null,
        null
      ) as result
    ) resolution
    where dish.requires_need_generation
      and resolution.result ->> 'status' = 'BLOCKED'
    union all
    select
      'WARNING', 'SUSPICIOUS_DUPLICATE_DISH',
      'The same dish is assigned to multiple slots for one school and date.',
      pg_catalog.min(row ->> 'source_row_reference')
    from canonical
    group by
      row ->> 'school_id',
      row ->> 'service_date',
      row ->> 'dish_id'
    having count(distinct row ->> 'menu_slot_code') > 1
    union all
    select
      'WARNING', 'DIFFERS_FROM_APPROVED_MENU',
      'This assignment differs from the latest approved snapshot.',
      row ->> 'source_row_reference'
    from canonical
    join atlas_planning.weekly_menus menu
      on menu.week_start = $1
     and menu.latest_approval_snapshot_id is not null
    left join atlas_planning.weekly_menu_approval_snapshot_lines approved
      on approved.weekly_menu_approval_snapshot_id =
          menu.latest_approval_snapshot_id
     and approved.school_id =
          atlas_core.pa_05b_safe_uuid(row ->> 'school_id')
     and approved.service_date =
          atlas_core.pa_05d_safe_date(row ->> 'service_date')
     and approved.menu_slot_code = row ->> 'menu_slot_code'
    where approved.weekly_menu_line_id is null
       or approved.dish_id is distinct from
          atlas_core.pa_05b_safe_uuid(row ->> 'dish_id')
    union all
    select
      'WARNING', 'OMITS_APPROVED_MENU_ASSIGNMENT',
      'The draft omits an assignment from the latest approved snapshot.',
      approved.source_row_reference
    from atlas_planning.weekly_menus menu
    join atlas_planning.weekly_menu_approval_snapshot_lines approved
      on approved.weekly_menu_approval_snapshot_id =
          menu.latest_approval_snapshot_id
    where menu.week_start = $1
      and not exists (
        select 1
        from canonical
        where atlas_core.pa_05b_safe_uuid(row ->> 'school_id') =
              approved.school_id
          and atlas_core.pa_05d_safe_date(row ->> 'service_date') =
              approved.service_date
          and row ->> 'menu_slot_code' = approved.menu_slot_code
      )
  )
  select pg_catalog.jsonb_build_object(
    'blockers',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'code', code,
            'message', message,
            'source_row_reference', source_row_reference
          )
          order by code, source_row_reference nulls first
        )
        from issues
        where severity = 'BLOCKER'
      ),
      '[]'::jsonb
    ),
    'warnings',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'code', code,
            'message', message,
            'source_row_reference', source_row_reference
          )
          order by code, source_row_reference nulls first
        )
        from issues
        where severity = 'WARNING'
      ),
      '[]'::jsonb
    )
  );
$$;

create or replace function atlas_core.rmvp_03a_attendance_issues(
  week_start date,
  rows jsonb
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with canonical as (
    select value as row
    from pg_catalog.jsonb_array_elements(
      atlas_core.rmvp_03a_canonical_attendance_rows(rows)
    )
  ),
  issues as (
    select
      'BLOCKER'::text as severity,
      'EMPTY_ATTENDANCE'::text as code,
      'Attendance contains no meaningful row.'::text as message,
      null::text as source_row_reference
    where not exists (select 1 from canonical)
    union all
    select
      'BLOCKER', 'INVALID_SCHOOL_ID',
      'A row does not identify a valid school.',
      row ->> 'source_row_reference'
    from canonical
    where atlas_core.pa_05b_safe_uuid(row ->> 'school_id') is null
    union all
    select
      'BLOCKER', 'INVALID_SERVICE_DATE',
      'A row does not contain a valid ISO service date.',
      row ->> 'source_row_reference'
    from canonical
    where atlas_core.pa_05d_safe_date(row ->> 'service_date') is null
    union all
    select
      'BLOCKER', 'SERVICE_DATE_OUTSIDE_WEEK',
      'An attendance row falls outside the selected service week.',
      row ->> 'source_row_reference'
    from canonical
    where atlas_core.pa_05d_safe_date(row ->> 'service_date') is not null
      and atlas_core.pa_05d_safe_date(row ->> 'service_date')
        not between week_start and week_start + 6
    union all
    select
      'BLOCKER', 'INVALID_STUDENT_PORTIONS',
      'Student portions must be an explicit non-negative integer.',
      row ->> 'source_row_reference'
    from canonical
    where atlas_core.rmvp_03a_safe_nonnegative_integer(
      row ->> 'student_portions'
    ) is null
    union all
    select
      'BLOCKER', 'INVALID_TEACHER_PORTIONS',
      'Teacher portions must be an explicit non-negative integer.',
      row ->> 'source_row_reference'
    from canonical
    where atlas_core.rmvp_03a_safe_nonnegative_integer(
      row ->> 'teacher_portions'
    ) is null
    union all
    select
      'BLOCKER', 'UNKNOWN_SCHOOL',
      'A row references a school that does not exist.',
      row ->> 'source_row_reference'
    from canonical
    where atlas_core.pa_05b_safe_uuid(row ->> 'school_id') is not null
      and not exists (
        select 1
        from atlas_admin.schools school
        where school.school_id =
          atlas_core.pa_05b_safe_uuid(row ->> 'school_id')
      )
    union all
    select
      'BLOCKER', 'INACTIVE_SCHOOL',
      'A row references an inactive school.',
      row ->> 'source_row_reference'
    from canonical
    join atlas_admin.schools school
      on school.school_id =
        atlas_core.pa_05b_safe_uuid(row ->> 'school_id')
    where school.school_status <> 'ACTIVE'
    union all
    select
      'BLOCKER', 'DUPLICATE_ATTENDANCE_ASSIGNMENT',
      'The same school and date appears more than once.',
      pg_catalog.min(row ->> 'source_row_reference')
    from canonical
    group by row ->> 'school_id', row ->> 'service_date'
    having count(*) > 1
    union all
    select
      'WARNING', 'PORTIONS_DIFFER_FROM_DEFAULT',
      'Attendance differs from the current school defaults.',
      row ->> 'source_row_reference'
    from canonical
    join atlas_admin.schools school
      on school.school_id =
        atlas_core.pa_05b_safe_uuid(row ->> 'school_id')
     and school.school_status = 'ACTIVE'
    where atlas_core.rmvp_03a_safe_nonnegative_integer(
            row ->> 'student_portions'
          ) is not null
      and atlas_core.rmvp_03a_safe_nonnegative_integer(
            row ->> 'teacher_portions'
          ) is not null
      and (
        atlas_core.rmvp_03a_safe_nonnegative_integer(
          row ->> 'student_portions'
        ) <> school.default_student_portions
        or atlas_core.rmvp_03a_safe_nonnegative_integer(
          row ->> 'teacher_portions'
        ) <> school.default_teacher_portions
      )
    union all
    select
      'WARNING', 'ZERO_TOTAL_PORTIONS',
      'Student and teacher portions total zero for this school and date.',
      row ->> 'source_row_reference'
    from canonical
    where atlas_core.rmvp_03a_safe_nonnegative_integer(
            row ->> 'student_portions'
          ) = 0
      and atlas_core.rmvp_03a_safe_nonnegative_integer(
            row ->> 'teacher_portions'
          ) = 0
    union all
    select
      'WARNING', 'DIFFERS_FROM_APPROVED_ATTENDANCE',
      'These portions differ from the latest approved snapshot.',
      row ->> 'source_row_reference'
    from canonical
    join atlas_planning.attendance_batches batch
      on batch.period_start = $1
     and batch.period_end = $1 + 6
     and batch.latest_approval_snapshot_id is not null
    left join atlas_planning.attendance_approval_snapshot_lines approved
      on approved.attendance_approval_snapshot_id =
          batch.latest_approval_snapshot_id
     and approved.school_id =
          atlas_core.pa_05b_safe_uuid(row ->> 'school_id')
     and approved.service_date =
          atlas_core.pa_05d_safe_date(row ->> 'service_date')
    where approved.attendance_line_id is null
       or approved.student_portions is distinct from
          atlas_core.rmvp_03a_safe_nonnegative_integer(
            row ->> 'student_portions'
          )
       or approved.teacher_portions is distinct from
          atlas_core.rmvp_03a_safe_nonnegative_integer(
            row ->> 'teacher_portions'
          )
    union all
    select
      'WARNING', 'OMITS_APPROVED_ATTENDANCE',
      'The draft omits a row from the latest approved snapshot.',
      approved.source_row_reference
    from atlas_planning.attendance_batches batch
    join atlas_planning.attendance_approval_snapshot_lines approved
      on approved.attendance_approval_snapshot_id =
          batch.latest_approval_snapshot_id
    where batch.period_start = $1
      and batch.period_end = $1 + 6
      and not exists (
        select 1
        from canonical
        where atlas_core.pa_05b_safe_uuid(row ->> 'school_id') =
              approved.school_id
          and atlas_core.pa_05d_safe_date(row ->> 'service_date') =
              approved.service_date
      )
  )
  select pg_catalog.jsonb_build_object(
    'blockers',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'code', code,
            'message', message,
            'source_row_reference', source_row_reference
          )
          order by code, source_row_reference nulls first
        )
        from issues
        where severity = 'BLOCKER'
      ),
      '[]'::jsonb
    ),
    'warnings',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'code', code,
            'message', message,
            'source_row_reference', source_row_reference
          )
          order by code, source_row_reference nulls first
        )
        from issues
        where severity = 'WARNING'
      ),
      '[]'::jsonb
    )
  );
$$;

create or replace function atlas_core.rmvp_03a_default_attendance_rows(
  week_start date
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with selected_menu as (
    select menu.weekly_menu_id
    from atlas_planning.weekly_menus menu
    where menu.week_start = $1
  ),
  menu_population as (
    select distinct line.school_id, line.service_date
    from selected_menu menu
    join atlas_planning.weekly_menu_lines line
      on line.weekly_menu_id = menu.weekly_menu_id
     and line.line_status = 'ACTIVE'
    join atlas_admin.schools school
      on school.school_id = line.school_id
     and school.school_status = 'ACTIVE'
  ),
  fallback_population as (
    select
      school.school_id,
      day.service_date::date
    from atlas_admin.schools school
    cross join pg_catalog.generate_series(
      $1::timestamp,
      ($1 + 6)::timestamp,
      interval '1 day'
    ) day(service_date)
    where school.school_status = 'ACTIVE'
      and not exists (select 1 from menu_population)
  ),
  population as (
    select * from menu_population
    union all
    select * from fallback_population
  )
  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'school_id', population.school_id,
        'service_date', population.service_date,
        'student_portions', school.default_student_portions,
        'teacher_portions', school.default_teacher_portions,
        'source_row_reference',
          'default:' || school.school_code || ':' ||
          population.service_date::text
      )
      order by
        school.display_order,
        school.school_code,
        population.service_date
    ),
    '[]'::jsonb
  )
  from population
  join atlas_admin.schools school
    on school.school_id = population.school_id;
$$;

create or replace function atlas_core.rmvp_03a_planning_workbench_payload(
  target_week_start date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_menu atlas_planning.weekly_menus%rowtype;
  v_attendance atlas_planning.attendance_batches%rowtype;
  v_menu_rows jsonb := '[]'::jsonb;
  v_attendance_rows jsonb := '[]'::jsonb;
  v_menu_issues jsonb;
  v_attendance_issues jsonb;
  v_coverage_warnings jsonb := '[]'::jsonb;
  v_missing_attendance integer := 0;
  v_without_menu integer := 0;
begin
  select *
    into v_menu
  from atlas_planning.weekly_menus menu
  where menu.week_start = target_week_start;

  if found then
    select coalesce(
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'weekly_menu_line_id', line.weekly_menu_line_id,
          'school_id', line.school_id,
          'service_date', line.service_date,
          'menu_slot_code', line.menu_slot_code,
          'dish_id', line.dish_id,
          'line_status', line.line_status,
          'source_row_reference', line.source_row_reference,
          'updated_by_actor_id', line.updated_by_actor_id,
          'updated_at', line.updated_at
        )
        order by
          school.display_order,
          school.school_code,
          line.service_date,
          line.menu_slot_code,
          line.weekly_menu_line_id
      ),
      '[]'::jsonb
    )
      into v_menu_rows
    from atlas_planning.weekly_menu_lines line
    join atlas_admin.schools school on school.school_id = line.school_id
    where line.weekly_menu_id = v_menu.weekly_menu_id;
  end if;

  select *
    into v_attendance
  from atlas_planning.attendance_batches batch
  where batch.period_start = target_week_start
    and batch.period_end = target_week_start + 6;

  if found then
    select coalesce(
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'attendance_line_id', line.attendance_line_id,
          'school_id', line.school_id,
          'service_date', line.service_date,
          'student_portions', line.student_portions,
          'teacher_portions', line.teacher_portions,
          'line_status', line.line_status,
          'source_row_reference', line.source_row_reference,
          'updated_by_actor_id', line.updated_by_actor_id,
          'updated_at', line.updated_at
        )
        order by
          school.display_order,
          school.school_code,
          line.service_date,
          line.attendance_line_id
      ),
      '[]'::jsonb
    )
      into v_attendance_rows
    from atlas_planning.attendance_lines line
    join atlas_admin.schools school on school.school_id = line.school_id
    where line.attendance_batch_id = v_attendance.attendance_batch_id;
  end if;

  v_menu_issues := atlas_core.rmvp_03a_menu_issues(
    target_week_start,
    (
      select coalesce(pg_catalog.jsonb_agg(row), '[]'::jsonb)
      from pg_catalog.jsonb_array_elements(v_menu_rows) row
      where row ->> 'line_status' = 'ACTIVE'
    )
  );
  v_attendance_issues := atlas_core.rmvp_03a_attendance_issues(
    target_week_start,
    (
      select coalesce(pg_catalog.jsonb_agg(row), '[]'::jsonb)
      from pg_catalog.jsonb_array_elements(v_attendance_rows) row
      where row ->> 'line_status' = 'ACTIVE'
    )
  );

  if v_menu.weekly_menu_id is not null
     and v_attendance.attendance_batch_id is not null then
    select count(*)::integer
      into v_missing_attendance
    from (
      select distinct line.school_id, line.service_date
      from atlas_planning.weekly_menu_lines line
      where line.weekly_menu_id = v_menu.weekly_menu_id
        and line.line_status = 'ACTIVE'
    ) menu_assignment
    where not exists (
      select 1
      from atlas_planning.attendance_lines attendance_line
      where attendance_line.attendance_batch_id =
          v_attendance.attendance_batch_id
        and attendance_line.line_status = 'ACTIVE'
        and attendance_line.school_id = menu_assignment.school_id
        and attendance_line.service_date = menu_assignment.service_date
    );

    select count(*)::integer
      into v_without_menu
    from atlas_planning.attendance_lines attendance_line
    where attendance_line.attendance_batch_id =
        v_attendance.attendance_batch_id
      and attendance_line.line_status = 'ACTIVE'
      and not exists (
        select 1
        from atlas_planning.weekly_menu_lines menu_line
        where menu_line.weekly_menu_id = v_menu.weekly_menu_id
          and menu_line.line_status = 'ACTIVE'
          and menu_line.school_id = attendance_line.school_id
          and menu_line.service_date = attendance_line.service_date
      );
  end if;

  if v_missing_attendance > 0 then
    v_coverage_warnings := v_coverage_warnings ||
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'code', 'MENU_ASSIGNMENT_WITHOUT_ATTENDANCE',
          'message',
            v_missing_attendance::text ||
            ' school/date menu assignments have no active attendance row.',
          'count', v_missing_attendance
        )
      );
  end if;
  if v_without_menu > 0 then
    v_coverage_warnings := v_coverage_warnings ||
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'code', 'ATTENDANCE_WITHOUT_MENU_ASSIGNMENT',
          'message',
            v_without_menu::text ||
            ' active attendance rows have no menu assignment.',
          'count', v_without_menu
        )
      );
  end if;

  return pg_catalog.jsonb_build_object(
    'week_start', target_week_start,
    'week_end', target_week_start + 6,
    'dish_types',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'dish_type_id', dish_type.dish_type_id,
            'dish_type_code', dish_type.dish_type_code,
            'dish_type_name', dish_type.dish_type_name,
            'source_header_aliases', dish_type.source_header_aliases,
            'display_order', dish_type.display_order,
            'dish_type_status', dish_type.dish_type_status,
            'version', dish_type.version
          )
          order by
            dish_type.display_order,
            dish_type.dish_type_code,
            dish_type.dish_type_id
        )
        from atlas_admin.dish_types dish_type
        where dish_type.dish_type_status = 'ACTIVE'
      ),
      '[]'::jsonb
    ),
    'schools',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'school_id', school.school_id,
            'school_code', school.school_code,
            'school_name', school.school_name,
            'school_status', school.school_status,
            'display_order', school.display_order,
            'school_type_id', school.school_type_id,
            'default_student_portions',
              school.default_student_portions,
            'default_teacher_portions',
              school.default_teacher_portions
          )
          order by
            school.display_order,
            school.school_code,
            school.school_id
        )
        from atlas_admin.schools school
      ),
      '[]'::jsonb
    ),
    'dishes',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'dish_id', dish.dish_id,
            'dish_code', dish.dish_code,
            'dish_name', dish.dish_name,
            'dish_category', dish.dish_category,
            'dish_type_id', dish.dish_type_id,
            'dish_type_code', dish_type.dish_type_code,
            'dish_type_name', dish_type.dish_type_name,
            'dish_status', dish.dish_status,
            'display_order', dish.display_order,
            'requires_need_generation', dish.requires_need_generation
          )
          order by
            dish.display_order,
            dish.dish_code,
            dish.dish_id
        )
        from atlas_admin.dishes dish
        left join atlas_admin.dish_types dish_type
          on dish_type.dish_type_id = dish.dish_type_id
      ),
      '[]'::jsonb
    ),
    'google_sheet_sources',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'weekly_menu_google_source_id',
              source.weekly_menu_google_source_id,
            'source_code', source.source_code,
            'source_name', source.source_name,
            'source_status', source.source_status,
            'display_order', source.display_order
          )
          order by
            source.display_order,
            source.source_code,
            source.weekly_menu_google_source_id
        )
        from atlas_planning.weekly_menu_google_sources source
        where source.source_status = 'ACTIVE'
      ),
      '[]'::jsonb
    ),
    'weekly_menu',
    case
      when v_menu.weekly_menu_id is null then null
      else pg_catalog.jsonb_build_object(
        'weekly_menu_id', v_menu.weekly_menu_id,
        'week_start', v_menu.week_start,
        'week_end', v_menu.week_end,
        'source_type', v_menu.source_type,
        'source_name', v_menu.source_name,
        'source_signature', v_menu.source_signature,
        'weekly_menu_status', v_menu.weekly_menu_status,
        'row_count', v_menu.row_count,
        'imported_by_actor_id', v_menu.imported_by_actor_id,
        'imported_at', v_menu.imported_at,
        'latest_approved_by_actor_id',
          v_menu.latest_approved_by_actor_id,
        'latest_approved_at', v_menu.latest_approved_at,
        'latest_approval_snapshot_id',
          v_menu.latest_approval_snapshot_id,
        'version', v_menu.version,
        'created_at', v_menu.created_at,
        'updated_at', v_menu.updated_at,
        'lines', v_menu_rows,
        'issues', v_menu_issues,
        'change_history',
          coalesce(
            (
              select pg_catalog.jsonb_agg(
                pg_catalog.jsonb_build_object(
                  'audit_event_id', audit.audit_event_id,
                  'event_type', audit.event_type,
                  'version_before', audit.aggregate_version_before,
                  'version_after', audit.aggregate_version_after,
                  'actor_id', audit.actor_id,
                  'actor_display_name', actor.display_name,
                  'reason_code', audit.reason_code,
                  'reason_note', audit.reason_note,
                  'occurred_at', audit.occurred_at
                )
                order by audit.occurred_at desc, audit.audit_event_id
              )
              from atlas_audit.audit_events audit
              join atlas_core.actors actor
                on actor.actor_id = audit.actor_id
              where audit.aggregate_type = 'WeeklyMenu'
                and audit.aggregate_id = v_menu.weekly_menu_id
            ),
            '[]'::jsonb
          ),
        'approval_history',
          coalesce(
            (
              select pg_catalog.jsonb_agg(
                pg_catalog.jsonb_build_object(
                  'approval_snapshot_id',
                    snapshot.weekly_menu_approval_snapshot_id,
                  'version', snapshot.weekly_menu_version,
                  'approved_by_actor_id', snapshot.approved_by_actor_id,
                  'approved_by_display_name', actor.display_name,
                  'approved_at', snapshot.approved_at,
                  'line_count',
                    (
                      select count(*)
                      from
                        atlas_planning.weekly_menu_approval_snapshot_lines
                          snapshot_line
                      where snapshot_line.weekly_menu_approval_snapshot_id =
                        snapshot.weekly_menu_approval_snapshot_id
                    )
                )
                order by snapshot.weekly_menu_version desc
              )
              from atlas_planning.weekly_menu_approval_snapshots snapshot
              join atlas_core.actors actor
                on actor.actor_id = snapshot.approved_by_actor_id
              where snapshot.weekly_menu_id = v_menu.weekly_menu_id
            ),
            '[]'::jsonb
          )
      )
    end,
    'attendance',
    case
      when v_attendance.attendance_batch_id is null then null
      else pg_catalog.jsonb_build_object(
        'attendance_batch_id', v_attendance.attendance_batch_id,
        'period_start', v_attendance.period_start,
        'period_end', v_attendance.period_end,
        'source_type', v_attendance.source_type,
        'source_name', v_attendance.source_name,
        'source_signature', v_attendance.source_signature,
        'attendance_status', v_attendance.attendance_status,
        'row_count', v_attendance.row_count,
        'imported_by_actor_id', v_attendance.imported_by_actor_id,
        'imported_at', v_attendance.imported_at,
        'latest_approved_by_actor_id',
          v_attendance.latest_approved_by_actor_id,
        'latest_approved_at', v_attendance.latest_approved_at,
        'latest_approval_snapshot_id',
          v_attendance.latest_approval_snapshot_id,
        'version', v_attendance.version,
        'created_at', v_attendance.created_at,
        'updated_at', v_attendance.updated_at,
        'lines', v_attendance_rows,
        'issues', v_attendance_issues,
        'change_history',
          coalesce(
            (
              select pg_catalog.jsonb_agg(
                pg_catalog.jsonb_build_object(
                  'audit_event_id', audit.audit_event_id,
                  'event_type', audit.event_type,
                  'version_before', audit.aggregate_version_before,
                  'version_after', audit.aggregate_version_after,
                  'actor_id', audit.actor_id,
                  'actor_display_name', actor.display_name,
                  'reason_code', audit.reason_code,
                  'reason_note', audit.reason_note,
                  'occurred_at', audit.occurred_at
                )
                order by audit.occurred_at desc, audit.audit_event_id
              )
              from atlas_audit.audit_events audit
              join atlas_core.actors actor
                on actor.actor_id = audit.actor_id
              where audit.aggregate_type = 'AttendanceBatch'
                and audit.aggregate_id = v_attendance.attendance_batch_id
            ),
            '[]'::jsonb
          ),
        'approval_history',
          coalesce(
            (
              select pg_catalog.jsonb_agg(
                pg_catalog.jsonb_build_object(
                  'approval_snapshot_id',
                    snapshot.attendance_approval_snapshot_id,
                  'version', snapshot.attendance_version,
                  'approved_by_actor_id', snapshot.approved_by_actor_id,
                  'approved_by_display_name', actor.display_name,
                  'approved_at', snapshot.approved_at,
                  'line_count',
                    (
                      select count(*)
                      from
                        atlas_planning.attendance_approval_snapshot_lines
                          snapshot_line
                      where snapshot_line.attendance_approval_snapshot_id =
                        snapshot.attendance_approval_snapshot_id
                    )
                )
                order by snapshot.attendance_version desc
              )
              from atlas_planning.attendance_approval_snapshots snapshot
              join atlas_core.actors actor
                on actor.actor_id = snapshot.approved_by_actor_id
              where snapshot.attendance_batch_id =
                v_attendance.attendance_batch_id
            ),
            '[]'::jsonb
          )
      )
    end,
    'readiness', pg_catalog.jsonb_build_object(
      'weekly_menu_approved',
        coalesce(v_menu.weekly_menu_status = 'APPROVED', false),
      'attendance_approved',
        coalesce(v_attendance.attendance_status = 'APPROVED', false),
      'weekly_menu_approval_snapshot_id',
        v_menu.latest_approval_snapshot_id,
      'attendance_approval_snapshot_id',
        v_attendance.latest_approval_snapshot_id,
      'ready',
        coalesce(v_menu.weekly_menu_status = 'APPROVED', false)
        and coalesce(v_attendance.attendance_status = 'APPROVED', false),
      'warnings', v_coverage_warnings
    ),
    'default_attendance_preview',
      atlas_core.rmvp_03a_default_attendance_rows(target_week_start)
  );
end;
$$;

create or replace function atlas_core.rmvp_03a_record_change(
  request jsonb,
  actor_id uuid,
  command_receipt_id uuid,
  event_type text,
  aggregate_type text,
  aggregate_id uuid,
  version_before bigint,
  version_after bigint,
  before_summary jsonb,
  after_summary jsonb
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  v_domain_event_id uuid;
  v_audit_event_id uuid;
begin
  insert into atlas_audit.domain_events (
    event_type,
    source_domain,
    aggregate_type,
    aggregate_id,
    aggregate_version,
    command_receipt_id,
    command_id,
    correlation_id,
    actor_id,
    occurred_at,
    payload_summary
  ) values (
    event_type,
    'PLANNING',
    aggregate_type,
    aggregate_id,
    version_after,
    command_receipt_id,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),
    actor_id,
    pg_catalog.transaction_timestamp(),
    after_summary
  )
  returning domain_event_id into v_domain_event_id;

  insert into atlas_audit.audit_events (
    event_type,
    source_domain,
    aggregate_type,
    aggregate_id,
    aggregate_version_before,
    aggregate_version_after,
    command_receipt_id,
    command_id,
    correlation_id,
    actor_id,
    reason_code,
    reason_note,
    before_summary,
    after_summary,
    source_interface,
    occurred_at
  ) values (
    event_type,
    'PLANNING',
    aggregate_type,
    aggregate_id,
    version_before,
    version_after,
    command_receipt_id,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),
    actor_id,
    request ->> 'reason_code',
    request ->> 'reason_note',
    before_summary,
    after_summary,
    'atlas_api',
    pg_catalog.transaction_timestamp()
  )
  returning audit_event_id into v_audit_event_id;

  return pg_catalog.jsonb_build_object(
    'domain_event_id', v_domain_event_id,
    'audit_event_id', v_audit_event_id
  );
end;
$$;

create or replace function atlas_core.rmvp_03a_finish_success(
  request jsonb,
  actor_id uuid,
  command_receipt_id uuid,
  event_type text,
  aggregate_type text,
  aggregate_id uuid,
  version_before bigint,
  version_after bigint,
  before_summary jsonb,
  after_summary jsonb,
  safe_operator_message text,
  affected_aggregate_ids jsonb,
  target_week_start date
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  v_events jsonb;
  v_response jsonb;
begin
  v_events := atlas_core.rmvp_03a_record_change(
    request,
    actor_id,
    command_receipt_id,
    event_type,
    aggregate_type,
    aggregate_id,
    version_before,
    version_after,
    before_summary,
    after_summary
  );
  v_response := pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RMVP-03A.v1',
    'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id',
    'idempotency_status', 'COMPLETED',
    'affected_aggregate_ids', affected_aggregate_ids,
    'new_versions', pg_catalog.jsonb_build_object(
      'aggregate_version', version_after
    ),
    'emitted_event_ids', pg_catalog.jsonb_build_array(
      v_events -> 'domain_event_id'
    ),
    'audit_event_ids', pg_catalog.jsonb_build_array(
      v_events -> 'audit_event_id'
    ),
    'authoritative_readback',
      atlas_core.rmvp_03a_planning_workbench_payload(target_week_start),
    'safe_operator_message', safe_operator_message,
    'warnings', '[]'::jsonb,
    'blockers', '[]'::jsonb
  );
  return atlas_core.pa_05b_finish_command(
    command_receipt_id,
    v_response,
    true
  );
end;
$$;

create or replace function atlas_core.rmvp_03a_finish_no_change(
  request jsonb,
  command_receipt_id uuid,
  target_week_start date,
  safe_operator_message text
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  v_response jsonb;
begin
  v_response := pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RMVP-03A.v1',
    'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id',
    'idempotency_status', 'NO_CHANGE',
    'affected_aggregate_ids', '{}'::jsonb,
    'new_versions', '{}'::jsonb,
    'emitted_event_ids', '[]'::jsonb,
    'audit_event_ids', '[]'::jsonb,
    'authoritative_readback',
      atlas_core.rmvp_03a_planning_workbench_payload(target_week_start),
    'safe_operator_message', safe_operator_message,
    'warnings', '[]'::jsonb,
    'blockers', '[]'::jsonb
  );
  return atlas_core.pa_05b_finish_command(
    command_receipt_id,
    v_response,
    true
  );
end;
$$;

create or replace function atlas_api.get_planning_inputs_workbench(
  request jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'get_planning_inputs_workbench';
  v_error jsonb;
  v_context jsonb;
  v_week_start date;
  v_connector_source_id uuid;
  v_connector_source jsonb;
begin
  v_error := atlas_core.rmvp_03a_validate_read_request(request, v_name);
  if v_error is not null then return v_error; end if;
  v_context := atlas_core.rmvp_03a_authorize_global(
    request,
    'planning.inputs.read',
    v_name
  );
  if v_context ? 'error' then return v_context -> 'error'; end if;
  v_week_start := atlas_core.pa_05d_safe_date(
    request -> 'payload' ->> 'week_start'
  );
  if request -> 'payload' ? 'google_connector_source_id' then
    v_connector_source_id := atlas_core.pa_05b_safe_uuid(
      request -> 'payload' ->> 'google_connector_source_id'
    );
    if v_connector_source_id is null then
      return atlas_core.rmvp_03a_read_error(
        request,
        v_name,
        'INVALID_GOOGLE_SOURCE',
        'The configured Google Sheet source is invalid.'
      );
    end if;
    select pg_catalog.jsonb_build_object(
      'weekly_menu_google_source_id',
        source.weekly_menu_google_source_id,
      'source_code', source.source_code,
      'source_name', source.source_name,
      'spreadsheet_id', source.spreadsheet_id,
      'sheet_name_pattern', source.sheet_name_pattern,
      'range_a1_template', source.range_a1_template,
      'source_status', source.source_status,
      'display_order', source.display_order,
      'version', source.version
    )
      into v_connector_source
    from atlas_planning.weekly_menu_google_sources source
    where source.weekly_menu_google_source_id = v_connector_source_id
      and source.source_status = 'ACTIVE';
    if v_connector_source is null then
      return atlas_core.rmvp_03a_read_error(
        request,
        v_name,
        'GOOGLE_SOURCE_UNAVAILABLE',
        'The configured Google Sheet source is unavailable.'
      );
    end if;
  end if;
  return pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RMVP-03A.v1',
    'correlation_id', request ->> 'correlation_id',
    'workbench',
      atlas_core.rmvp_03a_planning_workbench_payload(v_week_start),
    'google_connector_source', v_connector_source,
    'safe_operator_message',
      'Authorized Weekly Menu and Attendance data returned.'
  );
exception when others then
  return atlas_core.rmvp_03a_read_error(
    request,
    v_name,
    'INTERNAL_READ_FAILURE',
    'Planning inputs could not be returned safely.'
  );
end;
$$;

create or replace function atlas_api.preview_weekly_menu_import(
  request jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'preview_weekly_menu_import';
  v_error jsonb;
  v_context jsonb;
  v_week_start date;
  v_rows jsonb;
  v_signature text;
  v_issues jsonb;
  v_supplied_signature text;
  v_existing_rows jsonb := '[]'::jsonb;
  v_comparison jsonb;
begin
  v_error := atlas_core.rmvp_03a_validate_read_request(request, v_name);
  if v_error is not null then return v_error; end if;
  v_context := atlas_core.rmvp_03a_authorize_global(
    request,
    'planning.inputs.read',
    v_name
  );
  if v_context ? 'error' then return v_context -> 'error'; end if;
  v_week_start := atlas_core.pa_05d_safe_date(
    request -> 'payload' ->> 'week_start'
  );
  v_rows := atlas_core.rmvp_03a_canonical_menu_rows(
    request -> 'payload' -> 'rows'
  );
  v_signature := atlas_core.rmvp_03a_menu_signature(v_rows);
  v_issues := atlas_core.rmvp_03a_menu_issues(v_week_start, v_rows);
  if pg_catalog.jsonb_array_length(
       coalesce(request -> 'payload' -> 'rows', '[]'::jsonb)
     ) > pg_catalog.jsonb_array_length(v_rows) then
    v_issues := pg_catalog.jsonb_set(
      v_issues,
      '{warnings}',
      (v_issues -> 'warnings') || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'code', 'IGNORED_BLANK_SOURCE_ROWS',
          'message', 'Harmless blank source rows were ignored.',
          'source_row_reference', null
        )
      )
    );
  end if;
  v_supplied_signature := pg_catalog.lower(
    coalesce(
      atlas_core.rmvp_03a_normalize_text(
        request -> 'payload' ->> 'source_signature'
      ),
      ''
    )
  );
  if v_supplied_signature <> '' and v_supplied_signature <> v_signature then
    v_issues := pg_catalog.jsonb_set(
      v_issues,
      '{blockers}',
      (v_issues -> 'blockers') || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'code', 'CHECKSUM_MISMATCH',
          'message',
            'The supplied checksum does not match canonical menu content.',
          'source_row_reference', null
        )
      )
    );
  end if;
  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'school_id', line.school_id,
        'service_date', line.service_date,
        'menu_slot_code', line.menu_slot_code,
        'dish_id', line.dish_id
      )
    ),
    '[]'::jsonb
  )
    into v_existing_rows
  from atlas_planning.weekly_menu_lines line
  join atlas_planning.weekly_menus menu
    on menu.weekly_menu_id = line.weekly_menu_id
  where menu.week_start = v_week_start
    and line.line_status = 'ACTIVE';
  with incoming as (
    select *
    from pg_catalog.jsonb_to_recordset(v_rows) as row(
      school_id text,
      service_date date,
      menu_slot_code text,
      dish_id text
    )
  ),
  existing as (
    select *
    from pg_catalog.jsonb_to_recordset(v_existing_rows) as row(
      school_id text,
      service_date date,
      menu_slot_code text,
      dish_id text
    )
  ),
  classified as (
    select
      incoming.school_id,
      incoming.service_date,
      case
        when existing.school_id is null then 'NEW'
        when existing.dish_id is distinct from incoming.dish_id then 'CHANGED'
        else 'UNCHANGED'
      end comparison_status
    from incoming
    left join existing using (school_id, service_date, menu_slot_code)
    union all
    select existing.school_id, existing.service_date, 'OMITTED'
    from existing
    where not exists (
      select 1
      from incoming
      where incoming.school_id = existing.school_id
        and incoming.service_date = existing.service_date
        and incoming.menu_slot_code = existing.menu_slot_code
    )
  ),
  changed_days as (
    select distinct school_id, service_date
    from classified
    where comparison_status <> 'UNCHANGED'
  )
  select pg_catalog.jsonb_build_object(
    'new_assignments',
      count(*) filter (where comparison_status = 'NEW'),
    'changed_assignments',
      count(*) filter (where comparison_status = 'CHANGED'),
    'unchanged_assignments',
      count(*) filter (where comparison_status = 'UNCHANGED'),
    'omitted_prior_assignments',
      count(*) filter (where comparison_status = 'OMITTED'),
    'changed_school_days',
      coalesce(
        (
          select pg_catalog.jsonb_agg(
            pg_catalog.jsonb_build_object(
              'school_id', changed_days.school_id,
              'service_date', changed_days.service_date
            )
            order by changed_days.school_id, changed_days.service_date
          )
          from changed_days
        ),
        '[]'::jsonb
      )
  )
    into v_comparison
  from classified;
  return pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RMVP-03A.v1',
    'correlation_id', request ->> 'correlation_id',
    'preview', pg_catalog.jsonb_build_object(
      'week_start', v_week_start,
      'week_end', v_week_start + 6,
      'canonical_rows', v_rows,
      'source_signature', v_signature,
      'source_row_count',
        pg_catalog.jsonb_array_length(
          coalesce(request -> 'payload' -> 'rows', '[]'::jsonb)
        ),
      'row_count', pg_catalog.jsonb_array_length(v_rows),
      'normalized_assignment_count',
        pg_catalog.jsonb_array_length(v_rows),
      'comparison', v_comparison,
      'issues', v_issues,
      'can_save',
        pg_catalog.jsonb_array_length(v_issues -> 'blockers') = 0
    ),
    'safe_operator_message',
      'Weekly Menu import preview completed without writing data.'
  );
exception when others then
  return atlas_core.rmvp_03a_read_error(
    request,
    v_name,
    'INTERNAL_READ_FAILURE',
    'The Weekly Menu preview could not be produced safely.'
  );
end;
$$;

create or replace function atlas_api.preview_attendance_import(
  request jsonb
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'preview_attendance_import';
  v_error jsonb;
  v_context jsonb;
  v_week_start date;
  v_rows jsonb;
  v_signature text;
  v_issues jsonb;
  v_supplied_signature text;
  v_existing_rows jsonb := '[]'::jsonb;
  v_comparison jsonb;
begin
  v_error := atlas_core.rmvp_03a_validate_read_request(request, v_name);
  if v_error is not null then return v_error; end if;
  v_context := atlas_core.rmvp_03a_authorize_global(
    request,
    'planning.inputs.read',
    v_name
  );
  if v_context ? 'error' then return v_context -> 'error'; end if;
  v_week_start := atlas_core.pa_05d_safe_date(
    request -> 'payload' ->> 'week_start'
  );
  v_rows := atlas_core.rmvp_03a_canonical_attendance_rows(
    request -> 'payload' -> 'rows'
  );
  v_signature := atlas_core.rmvp_03a_attendance_signature(v_rows);
  v_issues := atlas_core.rmvp_03a_attendance_issues(
    v_week_start,
    v_rows
  );
  if pg_catalog.jsonb_array_length(
       coalesce(request -> 'payload' -> 'rows', '[]'::jsonb)
     ) > pg_catalog.jsonb_array_length(v_rows) then
    v_issues := pg_catalog.jsonb_set(
      v_issues,
      '{warnings}',
      (v_issues -> 'warnings') || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'code', 'IGNORED_BLANK_SOURCE_ROWS',
          'message', 'Harmless blank source rows were ignored.',
          'source_row_reference', null
        )
      )
    );
  end if;
  v_supplied_signature := pg_catalog.lower(
    coalesce(
      atlas_core.rmvp_03a_normalize_text(
        request -> 'payload' ->> 'source_signature'
      ),
      ''
    )
  );
  if v_supplied_signature <> '' and v_supplied_signature <> v_signature then
    v_issues := pg_catalog.jsonb_set(
      v_issues,
      '{blockers}',
      (v_issues -> 'blockers') || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'code', 'CHECKSUM_MISMATCH',
          'message',
            'The supplied checksum does not match canonical attendance content.',
          'source_row_reference', null
        )
      )
    );
  end if;
  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'school_id', line.school_id,
        'service_date', line.service_date,
        'student_portions', line.student_portions,
        'teacher_portions', line.teacher_portions
      )
    ),
    '[]'::jsonb
  )
    into v_existing_rows
  from atlas_planning.attendance_lines line
  join atlas_planning.attendance_batches batch
    on batch.attendance_batch_id = line.attendance_batch_id
  where batch.period_start = v_week_start
    and batch.period_end = v_week_start + 6
    and line.line_status = 'ACTIVE';
  with incoming as (
    select *
    from pg_catalog.jsonb_to_recordset(v_rows) as row(
      school_id text,
      service_date date,
      student_portions integer,
      teacher_portions integer
    )
  ),
  existing as (
    select *
    from pg_catalog.jsonb_to_recordset(v_existing_rows) as row(
      school_id text,
      service_date date,
      student_portions integer,
      teacher_portions integer
    )
  ),
  classified as (
    select
      incoming.school_id,
      incoming.service_date,
      case
        when existing.school_id is null then 'NEW'
        when existing.student_portions is distinct from
             incoming.student_portions
          or existing.teacher_portions is distinct from
             incoming.teacher_portions
        then 'CHANGED'
        else 'UNCHANGED'
      end comparison_status
    from incoming
    left join existing using (school_id, service_date)
    union all
    select existing.school_id, existing.service_date, 'OMITTED'
    from existing
    where not exists (
      select 1
      from incoming
      where incoming.school_id = existing.school_id
        and incoming.service_date = existing.service_date
    )
  ),
  changed_days as (
    select distinct school_id, service_date
    from classified
    where comparison_status <> 'UNCHANGED'
  )
  select pg_catalog.jsonb_build_object(
    'new_rows', count(*) filter (where comparison_status = 'NEW'),
    'changed_rows', count(*) filter (where comparison_status = 'CHANGED'),
    'unchanged_rows',
      count(*) filter (where comparison_status = 'UNCHANGED'),
    'omitted_prior_rows',
      count(*) filter (where comparison_status = 'OMITTED'),
    'changed_school_days',
      coalesce(
        (
          select pg_catalog.jsonb_agg(
            pg_catalog.jsonb_build_object(
              'school_id', changed_days.school_id,
              'service_date', changed_days.service_date
            )
            order by changed_days.school_id, changed_days.service_date
          )
          from changed_days
        ),
        '[]'::jsonb
      )
  )
    into v_comparison
  from classified;
  return pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RMVP-03A.v1',
    'correlation_id', request ->> 'correlation_id',
    'preview', pg_catalog.jsonb_build_object(
      'week_start', v_week_start,
      'week_end', v_week_start + 6,
      'canonical_rows', v_rows,
      'source_signature', v_signature,
      'source_row_count',
        pg_catalog.jsonb_array_length(
          coalesce(request -> 'payload' -> 'rows', '[]'::jsonb)
        ),
      'row_count', pg_catalog.jsonb_array_length(v_rows),
      'normalized_row_count', pg_catalog.jsonb_array_length(v_rows),
      'comparison', v_comparison,
      'issues', v_issues,
      'can_save',
        pg_catalog.jsonb_array_length(v_issues -> 'blockers') = 0
    ),
    'safe_operator_message',
      'Attendance import preview completed without writing data.'
  );
exception when others then
  return atlas_core.rmvp_03a_read_error(
    request,
    v_name,
    'INTERNAL_READ_FAILURE',
    'The Attendance preview could not be produced safely.'
  );
end;
$$;

create or replace function atlas_api.save_weekly_menu_draft(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'save_weekly_menu_draft';
  v_payload jsonb := request -> 'payload';
  v_week_start date := atlas_core.pa_05d_safe_date(
    v_payload ->> 'week_start'
  );
  v_rows jsonb := atlas_core.rmvp_03a_canonical_menu_rows(
    v_payload -> 'rows'
  );
  v_signature text := atlas_core.rmvp_03a_menu_signature(v_rows);
  v_supplied_signature text := pg_catalog.lower(
    coalesce(
      atlas_core.rmvp_03a_normalize_text(
        v_payload ->> 'source_signature'
      ),
      ''
    )
  );
  v_source_type text := coalesce(
    atlas_core.rmvp_03a_normalize_text(v_payload ->> 'source_type'),
    ''
  );
  v_source_name text := coalesce(
    atlas_core.rmvp_03a_normalize_text(v_payload ->> 'source_name'),
    ''
  );
  v_expected_source_signature text := pg_catalog.lower(
    coalesce(
      atlas_core.rmvp_03a_normalize_text(
        v_payload ->> 'expected_source_signature'
      ),
      ''
    )
  );
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_menu atlas_planning.weekly_menus%rowtype;
  v_issues jsonb;
  v_current_rows jsonb := '[]'::jsonb;
  v_current_signature text;
  v_before_status text;
  v_created boolean := false;
begin
  v_prepare := atlas_core.rmvp_03a_prepare_command(
    request,
    v_name,
    'planning.weekly_menu.write',
    'weekly-menu:' || coalesce(v_week_start::text, 'invalid')
  );
  if v_prepare ->> 'status' = 'RETURN' then
    return v_prepare -> 'response';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');

  if v_source_type = '' or v_source_name = '' then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'VALIDATION_FAILED',
        'Source type and source name are required.',
        'PLANNING',
        v_name
      ),
      false
    );
  end if;
  if v_supplied_signature = ''
     or v_supplied_signature <> v_signature then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'CHECKSUM_MISMATCH',
        'Save requires the checksum returned by the canonical preview.',
        'PLANNING',
        v_name
      ),
      false
    );
  end if;
  v_issues := atlas_core.rmvp_03a_menu_issues(v_week_start, v_rows);
  if pg_catalog.jsonb_array_length(v_issues -> 'blockers') > 0 then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'VALIDATION_FAILED',
        'Weekly Menu blockers must be resolved before saving.',
        'PLANNING',
        v_name,
        false,
        '[]'::jsonb,
        v_issues -> 'blockers'
      ),
      false
    );
  end if;

  select *
    into v_menu
  from atlas_planning.weekly_menus menu
  where menu.week_start = v_week_start
  for update;

  if found then
    if v_menu.version <> atlas_core.pa_05b_safe_bigint(
      request ->> 'expected_version'
    ) then
      return atlas_core.pa_05b_finish_command(
        v_receipt_id,
        atlas_core.pa_05b_command_error(
          request,
          'STALE_VERSION',
          'The Weekly Menu changed after it was read. Refresh before saving.',
          'PLANNING',
          v_name,
          false,
          '[]'::jsonb,
          '[]'::jsonb,
          v_menu.version
        ),
        false
      );
    end if;
    if v_expected_source_signature = ''
       or v_expected_source_signature <> v_menu.source_signature then
      return atlas_core.pa_05b_finish_command(
        v_receipt_id,
        atlas_core.pa_05b_command_error(
          request,
          'STALE_SOURCE_SIGNATURE',
          'The Weekly Menu source changed after it was read.',
          'PLANNING',
          v_name
        ),
        false
      );
    end if;
    if v_menu.weekly_menu_status not in ('DRAFT', 'REOPENED') then
      return atlas_core.pa_05b_finish_command(
        v_receipt_id,
        atlas_core.pa_05b_command_error(
          request,
          'INVARIANT_VIOLATION',
          'Only a DRAFT or REOPENED Weekly Menu can be saved.',
          'PLANNING',
          v_name
        ),
        false
      );
    end if;
    select coalesce(
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'school_id', line.school_id,
          'service_date', line.service_date,
          'menu_slot_code', line.menu_slot_code,
          'dish_id', line.dish_id,
          'source_row_reference', line.source_row_reference
        )
      ),
      '[]'::jsonb
    )
      into v_current_rows
    from atlas_planning.weekly_menu_lines line
    where line.weekly_menu_id = v_menu.weekly_menu_id
      and line.line_status = 'ACTIVE';
    v_current_signature := atlas_core.rmvp_03a_menu_signature(
      v_current_rows
    );
    if v_current_signature <> v_menu.source_signature then
      return atlas_core.pa_05b_finish_command(
        v_receipt_id,
        atlas_core.pa_05b_command_error(
          request,
          'PERSISTED_SIGNATURE_MISMATCH',
          'Stored menu evidence does not match its active assignments.',
          'PLANNING',
          v_name
        ),
        false
      );
    end if;
    if v_menu.weekly_menu_status = 'DRAFT'
       and v_signature = v_current_signature
       and v_source_type = v_menu.source_type
       and v_source_name = v_menu.source_name then
      return atlas_core.rmvp_03a_finish_no_change(
        request,
        v_receipt_id,
        v_week_start,
        'The canonical Weekly Menu already matches the saved draft.'
      );
    end if;
  else
    if atlas_core.pa_05b_safe_bigint(
      request ->> 'expected_version'
    ) <> 1
       or v_expected_source_signature <> '' then
      return atlas_core.pa_05b_finish_command(
        v_receipt_id,
        atlas_core.pa_05b_command_error(
          request,
          'STALE_VERSION',
          'A new Weekly Menu starts at version 1 with no prior signature.',
          'PLANNING',
          v_name
        ),
        false
      );
    end if;
    insert into atlas_planning.weekly_menus (
      week_start,
      week_end,
      source_type,
      source_name,
      source_signature,
      weekly_menu_status,
      row_count,
      imported_by_actor_id
    ) values (
      v_week_start,
      v_week_start + 6,
      v_source_type,
      v_source_name,
      v_signature,
      'DRAFT',
      pg_catalog.jsonb_array_length(v_rows),
      v_actor_id
    )
    returning * into v_menu;
    v_created := true;
  end if;

  v_before_status := v_menu.weekly_menu_status;

  if not v_created then
    if v_menu.weekly_menu_status = 'REOPENED' then
      update atlas_planning.weekly_menus
      set weekly_menu_status = 'DRAFT'
      where weekly_menu_id = v_menu.weekly_menu_id;
    end if;
    update atlas_planning.weekly_menus
    set source_type = v_source_type,
        source_name = v_source_name,
        source_signature = v_signature,
        row_count = pg_catalog.jsonb_array_length(v_rows),
        imported_by_actor_id = v_actor_id,
        imported_at = pg_catalog.transaction_timestamp(),
        updated_at = pg_catalog.transaction_timestamp()
    where weekly_menu_id = v_menu.weekly_menu_id;
  end if;

  update atlas_planning.weekly_menu_lines line
  set line_status = 'INVALID',
      updated_by_actor_id = v_actor_id,
      updated_at = pg_catalog.transaction_timestamp()
  where line.weekly_menu_id = v_menu.weekly_menu_id
    and line.line_status = 'ACTIVE'
    and not exists (
      select 1
      from pg_catalog.jsonb_array_elements(v_rows) item
      where atlas_core.pa_05b_safe_uuid(item ->> 'school_id') =
          line.school_id
        and atlas_core.pa_05d_safe_date(item ->> 'service_date') =
          line.service_date
        and item ->> 'menu_slot_code' = line.menu_slot_code
    );

  insert into atlas_planning.weekly_menu_lines (
    weekly_menu_id,
    school_id,
    service_date,
    menu_slot_code,
    dish_id,
    line_status,
    source_row_reference,
    created_by_actor_id,
    updated_by_actor_id
  )
  select
    v_menu.weekly_menu_id,
    atlas_core.pa_05b_safe_uuid(item ->> 'school_id'),
    atlas_core.pa_05d_safe_date(item ->> 'service_date'),
    item ->> 'menu_slot_code',
    atlas_core.pa_05b_safe_uuid(item ->> 'dish_id'),
    'ACTIVE',
    item ->> 'source_row_reference',
    v_actor_id,
    v_actor_id
  from pg_catalog.jsonb_array_elements(v_rows) item
  on conflict (
    weekly_menu_id,
    school_id,
    service_date,
    menu_slot_code
  ) do update set
    dish_id = excluded.dish_id,
    line_status = 'ACTIVE',
    source_row_reference = excluded.source_row_reference,
    updated_by_actor_id = excluded.updated_by_actor_id,
    updated_at = pg_catalog.transaction_timestamp();

  set constraints
    atlas_planning.weekly_menus_snapshot_integrity_guard,
    atlas_planning.weekly_menu_approval_snapshots_integrity_guard,
    atlas_planning.weekly_menu_approval_snapshot_lines_integrity_guard
    immediate;
  set constraints
    atlas_planning.weekly_menus_snapshot_integrity_guard,
    atlas_planning.weekly_menu_approval_snapshots_integrity_guard,
    atlas_planning.weekly_menu_approval_snapshot_lines_integrity_guard
    deferred;

  return atlas_core.rmvp_03a_finish_success(
    request,
    v_actor_id,
    v_receipt_id,
    case
      when v_created then 'WeeklyMenuDraftCreated'
      else 'WeeklyMenuDraftReplaced'
    end,
    'WeeklyMenu',
    v_menu.weekly_menu_id,
    v_menu.version,
    v_menu.version,
    pg_catalog.jsonb_build_object(
      'status', v_before_status,
      'source_signature', v_menu.source_signature,
      'row_count', v_menu.row_count
    ),
    pg_catalog.jsonb_build_object(
      'status', 'DRAFT',
      'source_signature', v_signature,
      'row_count', pg_catalog.jsonb_array_length(v_rows)
    ),
    'Weekly Menu draft saved with stable assignment identities.',
    pg_catalog.jsonb_build_object(
      'weekly_menu_id', v_menu.weekly_menu_id
    ),
    v_week_start
  );
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request,
      'RETRYABLE_CONCURRENCY_FAILURE',
      'The Weekly Menu could not be locked safely. Retry the exact request.',
      'PLANNING',
      v_name,
      true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'The Weekly Menu draft could not be saved safely.',
      'PLANNING',
      v_name
    );
end;
$$;

create or replace function atlas_api.validate_weekly_menu(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'validate_weekly_menu';
  v_week_start date := atlas_core.pa_05d_safe_date(
    request -> 'payload' ->> 'week_start'
  );
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_menu atlas_planning.weekly_menus%rowtype;
  v_rows jsonb;
  v_issues jsonb;
begin
  v_prepare := atlas_core.rmvp_03a_prepare_command(
    request,
    v_name,
    'planning.weekly_menu.write',
    'weekly-menu:' || coalesce(v_week_start::text, 'invalid')
  );
  if v_prepare ->> 'status' = 'RETURN' then
    return v_prepare -> 'response';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  select *
    into v_menu
  from atlas_planning.weekly_menus menu
  where menu.week_start = v_week_start
  for update;
  if not found then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'NOT_FOUND', 'The Weekly Menu was not found.',
        'PLANNING', v_name
      ),
      false
    );
  end if;
  if v_menu.version <> atlas_core.pa_05b_safe_bigint(
    request ->> 'expected_version'
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'STALE_VERSION',
        'The Weekly Menu changed after it was read.',
        'PLANNING',
        v_name,
        false,
        '[]'::jsonb,
        '[]'::jsonb,
        v_menu.version
      ),
      false
    );
  end if;
  if v_menu.weekly_menu_status <> 'DRAFT' then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'INVARIANT_VIOLATION',
        'Only a DRAFT Weekly Menu can be validated.',
        'PLANNING',
        v_name
      ),
      false
    );
  end if;
  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'school_id', line.school_id,
        'service_date', line.service_date,
        'menu_slot_code', line.menu_slot_code,
        'dish_id', line.dish_id,
        'source_row_reference', line.source_row_reference
      )
    ),
    '[]'::jsonb
  )
    into v_rows
  from atlas_planning.weekly_menu_lines line
  where line.weekly_menu_id = v_menu.weekly_menu_id
    and line.line_status = 'ACTIVE';
  v_issues := atlas_core.rmvp_03a_menu_issues(v_week_start, v_rows);
  if pg_catalog.jsonb_array_length(v_issues -> 'blockers') > 0 then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'VALIDATION_FAILED',
        'Weekly Menu blockers must be resolved before validation.',
        'PLANNING',
        v_name,
        false,
        '[]'::jsonb,
        v_issues -> 'blockers'
      ),
      false
    );
  end if;
  update atlas_planning.weekly_menus
  set weekly_menu_status = 'VALIDATED'
  where weekly_menu_id = v_menu.weekly_menu_id;
  set constraints
    atlas_planning.weekly_menus_snapshot_integrity_guard,
    atlas_planning.weekly_menu_approval_snapshots_integrity_guard,
    atlas_planning.weekly_menu_approval_snapshot_lines_integrity_guard
    immediate;
  set constraints
    atlas_planning.weekly_menus_snapshot_integrity_guard,
    atlas_planning.weekly_menu_approval_snapshots_integrity_guard,
    atlas_planning.weekly_menu_approval_snapshot_lines_integrity_guard
    deferred;
  return atlas_core.rmvp_03a_finish_success(
    request,
    v_actor_id,
    v_receipt_id,
    'WeeklyMenuValidated',
    'WeeklyMenu',
    v_menu.weekly_menu_id,
    v_menu.version,
    v_menu.version,
    pg_catalog.jsonb_build_object('status', 'DRAFT'),
    pg_catalog.jsonb_build_object(
      'status', 'VALIDATED',
      'row_count', v_menu.row_count
    ),
    'Weekly Menu validated against current Planning references.',
    pg_catalog.jsonb_build_object(
      'weekly_menu_id', v_menu.weekly_menu_id
    ),
    v_week_start
  );
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request,
      'RETRYABLE_CONCURRENCY_FAILURE',
      'The Weekly Menu could not be locked safely. Retry the exact request.',
      'PLANNING',
      v_name,
      true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'The Weekly Menu could not be validated safely.',
      'PLANNING',
      v_name
    );
end;
$$;

create or replace function atlas_api.approve_weekly_menu(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'approve_weekly_menu';
  v_week_start date := atlas_core.pa_05d_safe_date(
    request -> 'payload' ->> 'week_start'
  );
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_menu atlas_planning.weekly_menus%rowtype;
  v_rows jsonb;
  v_issues jsonb;
  v_snapshot_id uuid := gen_random_uuid();
  v_approved_at timestamptz := pg_catalog.transaction_timestamp();
begin
  v_prepare := atlas_core.rmvp_03a_prepare_command(
    request,
    v_name,
    'planning.inputs.approve',
    'weekly-menu:' || coalesce(v_week_start::text, 'invalid')
  );
  if v_prepare ->> 'status' = 'RETURN' then
    return v_prepare -> 'response';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  select *
    into v_menu
  from atlas_planning.weekly_menus menu
  where menu.week_start = v_week_start
  for update;
  if not found then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'NOT_FOUND', 'The Weekly Menu was not found.',
        'PLANNING', v_name
      ),
      false
    );
  end if;
  if v_menu.version <> atlas_core.pa_05b_safe_bigint(
    request ->> 'expected_version'
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'STALE_VERSION',
        'The Weekly Menu changed after it was read.',
        'PLANNING',
        v_name,
        false,
        '[]'::jsonb,
        '[]'::jsonb,
        v_menu.version
      ),
      false
    );
  end if;
  if v_menu.weekly_menu_status <> 'VALIDATED' then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'INVARIANT_VIOLATION',
        'Only a VALIDATED Weekly Menu can be approved.',
        'PLANNING',
        v_name
      ),
      false
    );
  end if;
  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'school_id', line.school_id,
        'service_date', line.service_date,
        'menu_slot_code', line.menu_slot_code,
        'dish_id', line.dish_id,
        'source_row_reference', line.source_row_reference
      )
    ),
    '[]'::jsonb
  )
    into v_rows
  from atlas_planning.weekly_menu_lines line
  where line.weekly_menu_id = v_menu.weekly_menu_id
    and line.line_status = 'ACTIVE';
  v_issues := atlas_core.rmvp_03a_menu_issues(v_week_start, v_rows);
  if pg_catalog.jsonb_array_length(v_issues -> 'blockers') > 0 then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'VALIDATION_FAILED',
        'Weekly Menu blockers must be resolved before approval.',
        'PLANNING',
        v_name,
        false,
        '[]'::jsonb,
        v_issues -> 'blockers'
      ),
      false
    );
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(line.dish_id::text, 17403)
  )
  from (
    select distinct active_line.dish_id
    from atlas_planning.weekly_menu_lines active_line
    where active_line.weekly_menu_id = v_menu.weekly_menu_id
      and active_line.line_status = 'ACTIVE'
  ) line
  order by line.dish_id;
  insert into atlas_planning.weekly_menu_approval_snapshots (
    weekly_menu_approval_snapshot_id,
    weekly_menu_id,
    weekly_menu_version,
    approved_by_actor_id,
    approved_at
  ) values (
    v_snapshot_id,
    v_menu.weekly_menu_id,
    v_menu.version,
    v_actor_id,
    v_approved_at
  );
  insert into atlas_planning.weekly_menu_approval_snapshot_lines (
    weekly_menu_approval_snapshot_id,
    weekly_menu_id,
    weekly_menu_version,
    weekly_menu_line_id,
    school_id,
    service_date,
    menu_slot_code,
    dish_id,
    source_row_reference
  )
  select
    v_snapshot_id,
    v_menu.weekly_menu_id,
    v_menu.version,
    line.weekly_menu_line_id,
    line.school_id,
    line.service_date,
    line.menu_slot_code,
    line.dish_id,
    line.source_row_reference
  from atlas_planning.weekly_menu_lines line
  where line.weekly_menu_id = v_menu.weekly_menu_id
    and line.line_status = 'ACTIVE';
  update atlas_planning.weekly_menus
  set weekly_menu_status = 'APPROVED',
      latest_approved_by_actor_id = v_actor_id,
      latest_approved_at = v_approved_at,
      latest_approval_snapshot_id = v_snapshot_id
  where weekly_menu_id = v_menu.weekly_menu_id;
  set constraints
    atlas_planning.weekly_menus_snapshot_integrity_guard,
    atlas_planning.weekly_menu_approval_snapshots_integrity_guard,
    atlas_planning.weekly_menu_approval_snapshot_lines_integrity_guard
    immediate;
  set constraints
    atlas_planning.weekly_menus_snapshot_integrity_guard,
    atlas_planning.weekly_menu_approval_snapshots_integrity_guard,
    atlas_planning.weekly_menu_approval_snapshot_lines_integrity_guard
    deferred;
  return atlas_core.rmvp_03a_finish_success(
    request,
    v_actor_id,
    v_receipt_id,
    'WeeklyMenuApproved',
    'WeeklyMenu',
    v_menu.weekly_menu_id,
    v_menu.version,
    v_menu.version,
    pg_catalog.jsonb_build_object('status', 'VALIDATED'),
    pg_catalog.jsonb_build_object(
      'status', 'APPROVED',
      'approval_snapshot_id', v_snapshot_id,
      'row_count', v_menu.row_count
    ),
    'Weekly Menu approved with an immutable exact-line snapshot.',
    pg_catalog.jsonb_build_object(
      'weekly_menu_id', v_menu.weekly_menu_id,
      'weekly_menu_approval_snapshot_id', v_snapshot_id
    ),
    v_week_start
  );
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request,
      'RETRYABLE_CONCURRENCY_FAILURE',
      'The Weekly Menu could not be locked safely. Retry the exact request.',
      'PLANNING',
      v_name,
      true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'The Weekly Menu could not be approved safely.',
      'PLANNING',
      v_name
    );
end;
$$;

-- Ownership is assigned once for the complete API family before the remaining
-- bodies are replaced below. These transaction-local stubs are never visible
-- outside a successful migration and let every public function receive its
-- final runtime owner and privilege set in one security block.
create or replace function atlas_api.reopen_weekly_menu(request jsonb)
returns jsonb
language sql
volatile
security definer
set search_path = ''
as $$
  select '{}'::jsonb;
$$;

create or replace function atlas_core.rmvp_03a_save_attendance_internal(
  request jsonb,
  command_name text,
  proposed_rows jsonb,
  proposed_source_type text,
  proposed_source_name text,
  proposed_signature text
)
returns jsonb
language sql
volatile
security invoker
set search_path = ''
as $$
  select '{}'::jsonb;
$$;

create or replace function atlas_api.create_attendance_draft_from_defaults(
  request jsonb
)
returns jsonb
language sql
volatile
security definer
set search_path = ''
as $$
  select '{}'::jsonb;
$$;

create or replace function atlas_api.save_attendance_draft(request jsonb)
returns jsonb
language sql
volatile
security definer
set search_path = ''
as $$
  select '{}'::jsonb;
$$;

create or replace function atlas_api.validate_attendance(request jsonb)
returns jsonb
language sql
volatile
security definer
set search_path = ''
as $$
  select '{}'::jsonb;
$$;

create or replace function atlas_api.approve_attendance(request jsonb)
returns jsonb
language sql
volatile
security definer
set search_path = ''
as $$
  select '{}'::jsonb;
$$;

create or replace function atlas_api.reopen_attendance(request jsonb)
returns jsonb
language sql
volatile
security definer
set search_path = ''
as $$
  select '{}'::jsonb;
$$;

grant usage on schema
  atlas_core,
  atlas_admin,
  atlas_planning,
  atlas_audit,
  extensions
to atlas_planning_command_runtime, atlas_read_runtime;

grant select on
  atlas_core.actors,
  atlas_core.actor_auth_subjects,
  atlas_core.roles,
  atlas_core.capabilities,
  atlas_core.role_capabilities,
  atlas_core.actor_role_memberships,
  atlas_core.actor_scopes,
  atlas_core.command_receipts,
  atlas_admin.school_types,
  atlas_admin.schools,
  atlas_admin.dish_types,
  atlas_admin.dishes,
  atlas_admin.ingredients,
  atlas_admin.units,
  atlas_admin.recipes,
  atlas_admin.recipe_versions,
  atlas_admin.recipe_lines,
  atlas_admin.recipe_line_revisions,
  atlas_admin.recipe_composition_adjustments,
  atlas_admin.recipe_composition_adjustment_revisions,
  atlas_planning.weekly_menus,
  atlas_planning.weekly_menu_lines,
  atlas_planning.weekly_menu_approval_snapshots,
  atlas_planning.weekly_menu_approval_snapshot_lines,
  atlas_planning.attendance_batches,
  atlas_planning.attendance_lines,
  atlas_planning.attendance_approval_snapshots,
  atlas_planning.attendance_approval_snapshot_lines
to atlas_planning_command_runtime;

grant select on atlas_admin.dish_types
  to atlas_master_data_command_runtime;
grant insert (dish_type_id), update (dish_type_id)
  on atlas_admin.dishes
  to atlas_master_data_command_runtime;

grant insert, update on
  atlas_planning.weekly_menus,
  atlas_planning.weekly_menu_lines,
  atlas_planning.attendance_batches,
  atlas_planning.attendance_lines
to atlas_planning_command_runtime;

grant insert on
  atlas_planning.weekly_menu_approval_snapshots,
  atlas_planning.weekly_menu_approval_snapshot_lines,
  atlas_planning.attendance_approval_snapshots,
  atlas_planning.attendance_approval_snapshot_lines
to atlas_planning_command_runtime;

create policy rmvp_03a_command_school_select
  on atlas_admin.schools
  for select to atlas_planning_command_runtime using (true);
create policy rmvp_03a_planning_dish_type_select
  on atlas_admin.dish_types
  for select to atlas_planning_command_runtime using (true);
create policy rmvp_03a_command_dish_select
  on atlas_admin.dishes
  for select to atlas_planning_command_runtime using (true);
create policy rmvp_03a_command_recipe_select
  on atlas_admin.recipes
  for select to atlas_planning_command_runtime using (true);
create policy rmvp_03a_command_recipe_version_select
  on atlas_admin.recipe_versions
  for select to atlas_planning_command_runtime using (true);
create policy rmvp_03a_command_ingredient_select
  on atlas_admin.ingredients
  for select to atlas_planning_command_runtime using (true);
create policy rmvp_03a_command_unit_select
  on atlas_admin.units
  for select to atlas_planning_command_runtime using (true);
create policy rmvp_03a_command_recipe_line_select
  on atlas_admin.recipe_lines
  for select to atlas_planning_command_runtime using (true);
create policy rmvp_03a_command_recipe_line_revision_select
  on atlas_admin.recipe_line_revisions
  for select to atlas_planning_command_runtime using (true);
create policy rmvp_03a_command_recipe_adjustment_select
  on atlas_admin.recipe_composition_adjustments
  for select to atlas_planning_command_runtime using (true);
create policy rmvp_03a_command_recipe_adjustment_revision_select
  on atlas_admin.recipe_composition_adjustment_revisions
  for select to atlas_planning_command_runtime using (true);

create policy rmvp_03a_command_weekly_menu_select
  on atlas_planning.weekly_menus
  for select to atlas_planning_command_runtime using (true);
create policy rmvp_03a_command_weekly_menu_insert
  on atlas_planning.weekly_menus
  for insert to atlas_planning_command_runtime with check (true);
create policy rmvp_03a_command_weekly_menu_update
  on atlas_planning.weekly_menus
  for update to atlas_planning_command_runtime
  using (true) with check (true);
create policy rmvp_03a_command_weekly_menu_line_select
  on atlas_planning.weekly_menu_lines
  for select to atlas_planning_command_runtime using (true);
create policy rmvp_03a_command_weekly_menu_line_insert
  on atlas_planning.weekly_menu_lines
  for insert to atlas_planning_command_runtime with check (true);
create policy rmvp_03a_command_weekly_menu_line_update
  on atlas_planning.weekly_menu_lines
  for update to atlas_planning_command_runtime
  using (true) with check (true);
create policy rmvp_03a_command_weekly_menu_snapshot_select
  on atlas_planning.weekly_menu_approval_snapshots
  for select to atlas_planning_command_runtime using (true);
create policy rmvp_03a_command_weekly_menu_snapshot_insert
  on atlas_planning.weekly_menu_approval_snapshots
  for insert to atlas_planning_command_runtime with check (true);
create policy rmvp_03a_command_weekly_menu_snapshot_line_select
  on atlas_planning.weekly_menu_approval_snapshot_lines
  for select to atlas_planning_command_runtime using (true);
create policy rmvp_03a_command_weekly_menu_snapshot_line_insert
  on atlas_planning.weekly_menu_approval_snapshot_lines
  for insert to atlas_planning_command_runtime with check (true);

create policy rmvp_03a_command_attendance_select
  on atlas_planning.attendance_batches
  for select to atlas_planning_command_runtime using (true);
create policy rmvp_03a_command_attendance_insert
  on atlas_planning.attendance_batches
  for insert to atlas_planning_command_runtime with check (true);
create policy rmvp_03a_command_attendance_update
  on atlas_planning.attendance_batches
  for update to atlas_planning_command_runtime
  using (true) with check (true);
create policy rmvp_03a_command_attendance_line_select
  on atlas_planning.attendance_lines
  for select to atlas_planning_command_runtime using (true);
create policy rmvp_03a_command_attendance_line_insert
  on atlas_planning.attendance_lines
  for insert to atlas_planning_command_runtime with check (true);
create policy rmvp_03a_command_attendance_line_update
  on atlas_planning.attendance_lines
  for update to atlas_planning_command_runtime
  using (true) with check (true);
create policy rmvp_03a_command_attendance_snapshot_select
  on atlas_planning.attendance_approval_snapshots
  for select to atlas_planning_command_runtime using (true);
create policy rmvp_03a_command_attendance_snapshot_insert
  on atlas_planning.attendance_approval_snapshots
  for insert to atlas_planning_command_runtime with check (true);
create policy rmvp_03a_command_attendance_snapshot_line_select
  on atlas_planning.attendance_approval_snapshot_lines
  for select to atlas_planning_command_runtime using (true);
create policy rmvp_03a_command_attendance_snapshot_line_insert
  on atlas_planning.attendance_approval_snapshot_lines
  for insert to atlas_planning_command_runtime with check (true);

grant select on
  atlas_admin.schools,
  atlas_admin.dish_types,
  atlas_admin.dishes,
  atlas_admin.recipes,
  atlas_admin.recipe_versions,
  atlas_planning.weekly_menus,
  atlas_planning.weekly_menu_lines,
  atlas_planning.weekly_menu_approval_snapshots,
  atlas_planning.weekly_menu_approval_snapshot_lines,
  atlas_planning.attendance_batches,
  atlas_planning.attendance_lines,
  atlas_planning.attendance_approval_snapshots,
  atlas_planning.attendance_approval_snapshot_lines,
  atlas_planning.weekly_menu_google_sources
to atlas_read_runtime;

create policy rmvp_03a_admin_dish_type_select
  on atlas_admin.dish_types
  for select to atlas_master_data_command_runtime using (true);
create policy rmvp_03a_read_dish_type_select
  on atlas_admin.dish_types
  for select to atlas_read_runtime using (true);
create policy rmvp_03a_read_google_source_select
  on atlas_planning.weekly_menu_google_sources
  for select to atlas_read_runtime using (true);

create policy rmvp_03a_read_weekly_menu_select
  on atlas_planning.weekly_menus
  for select to atlas_read_runtime using (true);
create policy rmvp_03a_read_weekly_menu_line_select
  on atlas_planning.weekly_menu_lines
  for select to atlas_read_runtime using (true);
create policy rmvp_03a_read_weekly_menu_snapshot_select
  on atlas_planning.weekly_menu_approval_snapshots
  for select to atlas_read_runtime using (true);
create policy rmvp_03a_read_weekly_menu_snapshot_line_select
  on atlas_planning.weekly_menu_approval_snapshot_lines
  for select to atlas_read_runtime using (true);
create policy rmvp_03a_read_attendance_select
  on atlas_planning.attendance_batches
  for select to atlas_read_runtime using (true);
create policy rmvp_03a_read_attendance_line_select
  on atlas_planning.attendance_lines
  for select to atlas_read_runtime using (true);
create policy rmvp_03a_read_attendance_snapshot_select
  on atlas_planning.attendance_approval_snapshots
  for select to atlas_read_runtime using (true);
create policy rmvp_03a_read_attendance_snapshot_line_select
  on atlas_planning.attendance_approval_snapshot_lines
  for select to atlas_read_runtime using (true);

alter function atlas_core.rmvp_03a_safe_nonnegative_integer(text)
  owner to atlas_owner;
alter function atlas_core.rmvp_03a_normalize_text(text)
  owner to atlas_owner;
alter function atlas_core.rmvp_03a_sha256(jsonb)
  owner to atlas_owner;
alter function atlas_core.rmvp_03a_canonical_menu_rows(jsonb)
  owner to atlas_owner;
alter function atlas_core.rmvp_03a_menu_signature(jsonb)
  owner to atlas_owner;
alter function atlas_core.rmvp_03a_canonical_attendance_rows(jsonb)
  owner to atlas_owner;
alter function atlas_core.rmvp_03a_attendance_signature(jsonb)
  owner to atlas_owner;
alter function atlas_core.rmvp_03a_read_error(
  jsonb, text, text, text, jsonb
) owner to atlas_owner;
alter function atlas_core.rmvp_03a_validate_read_request(jsonb, text)
  owner to atlas_owner;
alter function atlas_core.rmvp_03a_validate_command_request(jsonb, text)
  owner to atlas_owner;
alter function atlas_core.rmvp_03a_authorize_global(jsonb, text, text)
  owner to atlas_owner;
alter function atlas_core.rmvp_03a_prepare_command(
  jsonb, text, text, text
) owner to atlas_owner;
alter function atlas_core.rmvp_03a_menu_issues(date, jsonb)
  owner to atlas_owner;
alter function atlas_core.rmvp_03a_attendance_issues(date, jsonb)
  owner to atlas_owner;
alter function atlas_core.rmvp_03a_default_attendance_rows(date)
  owner to atlas_owner;
alter function atlas_core.rmvp_03a_record_change(
  jsonb, uuid, uuid, text, text, uuid, bigint, bigint, jsonb, jsonb
) owner to atlas_owner;
alter function atlas_core.rmvp_03a_finish_success(
  jsonb, uuid, uuid, text, text, uuid, bigint, bigint,
  jsonb, jsonb, text, jsonb, date
) owner to atlas_owner;
alter function atlas_core.rmvp_03a_finish_no_change(
  jsonb, uuid, date, text
) owner to atlas_owner;
alter function atlas_core.rmvp_03a_save_attendance_internal(
  jsonb, text, jsonb, text, text, text
) owner to atlas_owner;

grant execute on function
  atlas_core.pa_05d_safe_date(text),
  atlas_core.rmvp_03a_safe_nonnegative_integer(text),
  atlas_core.rmvp_03a_normalize_text(text),
  atlas_core.rmvp_03a_sha256(jsonb),
  atlas_core.rmvp_03a_canonical_menu_rows(jsonb),
  atlas_core.rmvp_03a_menu_signature(jsonb),
  atlas_core.rmvp_03a_canonical_attendance_rows(jsonb),
  atlas_core.rmvp_03a_attendance_signature(jsonb),
  atlas_core.rmvp_03a_read_error(jsonb, text, text, text, jsonb),
  atlas_core.rmvp_03a_validate_read_request(jsonb, text),
  atlas_core.rmvp_03a_authorize_global(jsonb, text, text),
  atlas_core.rmvp_03a_menu_issues(date, jsonb),
  atlas_core.rmvp_03a_attendance_issues(date, jsonb),
  atlas_core.rmvp_03a_default_attendance_rows(date),
  atlas_core.rmvp_03a_planning_workbench_payload(date),
  extensions.digest(bytea, text)
to atlas_read_runtime;

grant execute on function
  atlas_core.pa_05d_safe_date(text),
  atlas_core.pa_05b_safe_uuid(text),
  atlas_core.pa_05b_safe_bigint(text),
  atlas_core.pa_05b_safe_numeric(text),
  atlas_core.pa_05b_safe_timestamptz(text),
  atlas_core.pa_05b_current_auth_subject(),
  atlas_core.pa_05b_command_error(
    jsonb, text, text, text, text, boolean, jsonb, jsonb, bigint
  ),
  atlas_core.pa_05b_resolve_actor(jsonb, text, text),
  atlas_core.pa_05b_authorize_actor(
    jsonb, uuid, text, text, text, uuid, uuid, uuid
  ),
  atlas_core.pa_05b_request_hash(jsonb),
  atlas_core.pa_05b_begin_command(jsonb, uuid, text, text, text),
  atlas_core.pa_05b_finish_command(uuid, jsonb, boolean),
  atlas_core.rmvp_03a_safe_nonnegative_integer(text),
  atlas_core.rmvp_03a_normalize_text(text),
  atlas_core.rmvp_03a_sha256(jsonb),
  atlas_core.rmvp_03a_canonical_menu_rows(jsonb),
  atlas_core.rmvp_03a_menu_signature(jsonb),
  atlas_core.rmvp_03a_canonical_attendance_rows(jsonb),
  atlas_core.rmvp_03a_attendance_signature(jsonb),
  atlas_core.rmvp_03a_validate_command_request(jsonb, text),
  atlas_core.rmvp_03a_authorize_global(jsonb, text, text),
  atlas_core.rmvp_03a_prepare_command(jsonb, text, text, text),
  atlas_core.rmvp_03a_menu_issues(date, jsonb),
  atlas_core.rmvp_03a_attendance_issues(date, jsonb),
  atlas_core.rmvp_03a_default_attendance_rows(date),
  atlas_core.rmvp_03a_planning_workbench_payload(date),
  atlas_core.rmvp_03a_record_change(
    jsonb, uuid, uuid, text, text, uuid, bigint, bigint, jsonb, jsonb
  ),
  atlas_core.rmvp_03a_finish_success(
    jsonb, uuid, uuid, text, text, uuid, bigint, bigint,
    jsonb, jsonb, text, jsonb, date
  ),
  atlas_core.rmvp_03a_finish_no_change(jsonb, uuid, date, text),
  atlas_core.rmvp_03a_save_attendance_internal(
    jsonb, text, jsonb, text, text, text
  ),
  atlas_core.rmvp_02b_safe_date(text),
  atlas_core.rmvp_02b_active_rules(date, uuid, uuid, jsonb, uuid),
  atlas_core.rmvp_02b_transform_line(jsonb, jsonb),
  atlas_core.rmvp_02b_resolve_effective_composition(
    date, uuid, uuid, jsonb, uuid, uuid
  ),
  extensions.digest(bytea, text)
to atlas_planning_command_runtime;

grant atlas_planning_command_runtime, atlas_read_runtime
  to postgres with set true;
grant create on schema atlas_core to atlas_read_runtime;
alter function atlas_core.rmvp_03a_planning_workbench_payload(date)
  owner to atlas_read_runtime;
revoke create on schema atlas_core from atlas_read_runtime;
grant create on schema atlas_api
  to atlas_planning_command_runtime, atlas_read_runtime;

alter function atlas_api.get_planning_inputs_workbench(jsonb)
  owner to atlas_read_runtime;
alter function atlas_api.preview_weekly_menu_import(jsonb)
  owner to atlas_read_runtime;
alter function atlas_api.preview_attendance_import(jsonb)
  owner to atlas_read_runtime;
alter function atlas_api.save_weekly_menu_draft(jsonb)
  owner to atlas_planning_command_runtime;
alter function atlas_api.validate_weekly_menu(jsonb)
  owner to atlas_planning_command_runtime;
alter function atlas_api.approve_weekly_menu(jsonb)
  owner to atlas_planning_command_runtime;
alter function atlas_api.reopen_weekly_menu(jsonb)
  owner to atlas_planning_command_runtime;
alter function atlas_api.create_attendance_draft_from_defaults(jsonb)
  owner to atlas_planning_command_runtime;
alter function atlas_api.save_attendance_draft(jsonb)
  owner to atlas_planning_command_runtime;
alter function atlas_api.validate_attendance(jsonb)
  owner to atlas_planning_command_runtime;
alter function atlas_api.approve_attendance(jsonb)
  owner to atlas_planning_command_runtime;
alter function atlas_api.reopen_attendance(jsonb)
  owner to atlas_planning_command_runtime;

revoke create on schema atlas_api
  from atlas_planning_command_runtime, atlas_read_runtime;

revoke execute on function
  atlas_core.rmvp_03a_safe_nonnegative_integer(text),
  atlas_core.rmvp_03a_normalize_text(text),
  atlas_core.rmvp_03a_sha256(jsonb),
  atlas_core.rmvp_03a_canonical_menu_rows(jsonb),
  atlas_core.rmvp_03a_menu_signature(jsonb),
  atlas_core.rmvp_03a_canonical_attendance_rows(jsonb),
  atlas_core.rmvp_03a_attendance_signature(jsonb),
  atlas_core.rmvp_03a_read_error(jsonb, text, text, text, jsonb),
  atlas_core.rmvp_03a_validate_read_request(jsonb, text),
  atlas_core.rmvp_03a_validate_command_request(jsonb, text),
  atlas_core.rmvp_03a_authorize_global(jsonb, text, text),
  atlas_core.rmvp_03a_prepare_command(jsonb, text, text, text),
  atlas_core.rmvp_03a_menu_issues(date, jsonb),
  atlas_core.rmvp_03a_attendance_issues(date, jsonb),
  atlas_core.rmvp_03a_default_attendance_rows(date),
  atlas_core.rmvp_03a_planning_workbench_payload(date),
  atlas_core.rmvp_03a_record_change(
    jsonb, uuid, uuid, text, text, uuid, bigint, bigint, jsonb, jsonb
  ),
  atlas_core.rmvp_03a_finish_success(
    jsonb, uuid, uuid, text, text, uuid, bigint, bigint,
    jsonb, jsonb, text, jsonb, date
  ),
  atlas_core.rmvp_03a_finish_no_change(jsonb, uuid, date, text),
  atlas_core.rmvp_03a_save_attendance_internal(
    jsonb, text, jsonb, text, text, text
  )
from public, anon, authenticated, service_role;

revoke execute on function
  atlas_api.get_planning_inputs_workbench(jsonb),
  atlas_api.preview_weekly_menu_import(jsonb),
  atlas_api.preview_attendance_import(jsonb),
  atlas_api.save_weekly_menu_draft(jsonb),
  atlas_api.validate_weekly_menu(jsonb),
  atlas_api.approve_weekly_menu(jsonb),
  atlas_api.reopen_weekly_menu(jsonb),
  atlas_api.create_attendance_draft_from_defaults(jsonb),
  atlas_api.save_attendance_draft(jsonb),
  atlas_api.validate_attendance(jsonb),
  atlas_api.approve_attendance(jsonb),
  atlas_api.reopen_attendance(jsonb)
from public, anon, service_role;

grant execute on function
  atlas_api.get_planning_inputs_workbench(jsonb),
  atlas_api.preview_weekly_menu_import(jsonb),
  atlas_api.preview_attendance_import(jsonb),
  atlas_api.save_weekly_menu_draft(jsonb),
  atlas_api.validate_weekly_menu(jsonb),
  atlas_api.approve_weekly_menu(jsonb),
  atlas_api.reopen_weekly_menu(jsonb),
  atlas_api.create_attendance_draft_from_defaults(jsonb),
  atlas_api.save_attendance_draft(jsonb),
  atlas_api.validate_attendance(jsonb),
  atlas_api.approve_attendance(jsonb),
  atlas_api.reopen_attendance(jsonb)
to authenticated;

comment on function atlas_api.get_planning_inputs_workbench(jsonb) is
  'RMVP-03A authorized exact-week Weekly Menu and Attendance workbench read with immutable approval history and read-only readiness comparison.';
comment on function atlas_api.preview_weekly_menu_import(jsonb) is
  'RMVP-03A no-write Unicode-normalized, order-independent Weekly Menu canonicalization, checksum, and validation preview.';
comment on function atlas_api.preview_attendance_import(jsonb) is
  'RMVP-03A no-write Unicode-normalized, order-independent Attendance canonicalization, checksum, and validation preview.';
comment on function atlas_api.save_weekly_menu_draft(jsonb) is
  'RMVP-03A atomic Weekly Menu DRAFT full replacement preserving stable assignment identities and invalidating omitted rows.';
comment on function atlas_api.validate_weekly_menu(jsonb) is
  'RMVP-03A authoritative Weekly Menu validation and DRAFT to VALIDATED transition.';
comment on function atlas_api.approve_weekly_menu(jsonb) is
  'RMVP-03A Weekly Menu approval with one immutable exact active-line snapshot.';
comment on function atlas_api.reopen_weekly_menu(jsonb) is
  'RMVP-03A reasoned Weekly Menu reopen to the next working version while preserving approval history.';
comment on function
  atlas_api.create_attendance_draft_from_defaults(jsonb) is
  'RMVP-03A menu-aware Attendance draft creation from explicit current school defaults.';
comment on function atlas_api.save_attendance_draft(jsonb) is
  'RMVP-03A atomic Attendance DRAFT full replacement preserving stable row identities and invalidating omitted rows.';
comment on function atlas_api.validate_attendance(jsonb) is
  'RMVP-03A authoritative Attendance validation and DRAFT to VALIDATED transition.';
comment on function atlas_api.approve_attendance(jsonb) is
  'RMVP-03A Attendance approval with one immutable exact active-line snapshot.';
comment on function atlas_api.reopen_attendance(jsonb) is
  'RMVP-03A reasoned Attendance reopen to the next working version while preserving approval history.';

-- Extend the existing RMVP-02A read/command contract in place. Dish Type is
-- authoritative; dish_category remains transitional descriptive text only.
set role atlas_owner;

create or replace function atlas_core.rmvp_02a_recipe_workbench_payload()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'dish_types',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'dish_type_id', dish_type.dish_type_id,
            'dish_type_code', dish_type.dish_type_code,
            'dish_type_name', dish_type.dish_type_name,
            'source_header_aliases', dish_type.source_header_aliases,
            'display_order', dish_type.display_order,
            'dish_type_status', dish_type.dish_type_status,
            'version', dish_type.version,
            'created_at', dish_type.created_at,
            'updated_at', dish_type.updated_at
          )
          order by
            dish_type.display_order,
            dish_type.dish_type_code,
            dish_type.dish_type_id
        )
        from atlas_admin.dish_types dish_type
      ),
      '[]'::jsonb
    ),
    'dishes',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'dish_id', dish.dish_id,
            'dish_code', dish.dish_code,
            'dish_name', dish.dish_name,
            'dish_category', dish.dish_category,
            'dish_type_id', dish.dish_type_id,
            'dish_type_code', dish_type.dish_type_code,
            'dish_type_name', dish_type.dish_type_name,
            'operational_notes', dish.operational_notes,
            'dish_status', dish.dish_status,
            'display_order', dish.display_order,
            'requires_need_generation', dish.requires_need_generation,
            'version', dish.version,
            'created_at', dish.created_at,
            'updated_at', dish.updated_at
          )
          order by dish.display_order, dish.dish_name, dish.dish_id
        )
        from atlas_admin.dishes dish
        left join atlas_admin.dish_types dish_type
          on dish_type.dish_type_id = dish.dish_type_id
      ),
      '[]'::jsonb
    ),
    'school_types',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'school_type_id', school_type.school_type_id,
            'school_type_code', school_type.school_type_code,
            'school_type_name', school_type.school_type_name,
            'school_type_status', school_type.school_type_status
          )
          order by school_type.school_type_name, school_type.school_type_id
        )
        from atlas_admin.school_types school_type
      ),
      '[]'::jsonb
    ),
    'ingredients',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'ingredient_id', ingredient.ingredient_id,
            'ingredient_code', ingredient.ingredient_code,
            'ingredient_name', ingredient.ingredient_name,
            'ingredient_status', ingredient.ingredient_status
          )
          order by ingredient.ingredient_name, ingredient.ingredient_id
        )
        from atlas_admin.ingredients ingredient
      ),
      '[]'::jsonb
    ),
    'units',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'unit_id', unit.unit_id,
            'unit_code', unit.unit_code,
            'unit_name', unit.unit_name,
            'unit_status', unit.unit_status
          )
          order by unit.unit_name, unit.unit_id
        )
        from atlas_admin.units unit
      ),
      '[]'::jsonb
    ),
    'recipes',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'recipe_id', recipe.recipe_id,
            'dish_id', recipe.dish_id,
            'school_type_id', recipe.school_type_id,
            'recipe_status', recipe.recipe_status,
            'version', recipe.version,
            'created_at', recipe.created_at,
            'updated_at', recipe.updated_at
          )
          order by recipe.dish_id, recipe.school_type_id nulls first,
            recipe.recipe_id
        )
        from atlas_admin.recipes recipe
      ),
      '[]'::jsonb
    ),
    'recipe_versions',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'recipe_version_id', version.recipe_version_id,
            'recipe_id', version.recipe_id,
            'version_number', version.version_number,
            'predecessor_recipe_version_id',
              version.predecessor_recipe_version_id,
            'basis_portions', version.basis_portions,
            'recipe_version_status', version.recipe_version_status,
            'version', version.version,
            'source_evidence', version.source_evidence,
            'created_by_actor_id', version.created_by_actor_id,
            'created_at', version.created_at,
            'validated_by_actor_id', version.validated_by_actor_id,
            'validated_at', version.validated_at,
            'released_by_actor_id', version.released_by_actor_id,
            'released_at', version.released_at,
            'locked_by_actor_id', version.locked_by_actor_id,
            'locked_at', version.locked_at,
            'composition',
              atlas_core.rmvp_02a_recipe_version_composition(
                version.recipe_version_id
              )
          )
          order by version.recipe_id, version.version_number,
            version.recipe_version_id
        )
        from atlas_admin.recipe_versions version
      ),
      '[]'::jsonb
    )
  );
$$;

reset role;
grant atlas_master_data_command_runtime to postgres with set true;
grant create on schema atlas_api to atlas_master_data_command_runtime;
set role atlas_master_data_command_runtime;

create or replace function atlas_api.create_dish(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'create_dish';
  v_payload jsonb := request -> 'payload';
  v_code text := pg_catalog.lower(
    pg_catalog.btrim(coalesce(v_payload ->> 'dish_code', ''))
  );
  v_dish_name text := pg_catalog.btrim(
    coalesce(v_payload ->> 'dish_name', '')
  );
  v_category text := nullif(
    pg_catalog.btrim(coalesce(v_payload ->> 'dish_category', '')),
    ''
  );
  v_dish_type_id uuid := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'dish_type_id'
  );
  v_notes text := nullif(
    pg_catalog.btrim(coalesce(v_payload ->> 'operational_notes', '')),
    ''
  );
  v_display_order bigint := atlas_core.pa_05b_safe_bigint(
    v_payload ->> 'display_order'
  );
  v_requires boolean;
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_dish_id uuid;
begin
  if atlas_core.rmvp_02a_validate_command_request(
    request,
    v_name
  ) is not null then
    return atlas_core.rmvp_02a_validate_command_request(request, v_name);
  end if;
  begin
    v_requires := (v_payload ->> 'requires_need_generation')::boolean;
  exception when others then
    v_requires := null;
  end;
  if atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') <> 1
     or v_code = ''
     or v_dish_name = ''
     or v_dish_type_id is null
     or v_display_order is null
     or v_display_order < 0
     or v_display_order > 2147483647
     or v_requires is null then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'Dish values are incomplete or invalid.',
      'ADMIN',
      v_name,
      false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field', 'payload.dish_type_id',
          'message',
          'A database-backed active Dish Type is required.'
        )
      )
    );
  end if;
  v_prepare := atlas_core.rmvp_02a_prepare_command(
    request,
    v_name,
    'master_data.recipes.write',
    'dish-code:' || v_code
  );
  if v_prepare ->> 'status' = 'RETURN' then
    return v_prepare -> 'response';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  if not exists (
    select 1
    from atlas_admin.dish_types dish_type
    where dish_type.dish_type_id = v_dish_type_id
      and dish_type.dish_type_status = 'ACTIVE'
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'VALIDATION_FAILED',
        'The selected Dish Type is unknown or inactive.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  if exists (
    select 1 from atlas_admin.dishes where dish_code = v_code
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'CONFLICT',
        'The dish code is already in use.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  insert into atlas_admin.dishes (
    dish_code,
    dish_name,
    dish_category,
    dish_type_id,
    operational_notes,
    dish_status,
    display_order,
    requires_need_generation
  ) values (
    v_code,
    v_dish_name,
    v_category,
    v_dish_type_id,
    v_notes,
    'DRAFT',
    v_display_order::integer,
    v_requires
  )
  returning dish_id into v_dish_id;
  return atlas_core.rmvp_02a_finish_success(
    request,
    v_actor_id,
    v_receipt_id,
    'DishCreated',
    'Dish',
    v_dish_id,
    null,
    1,
    null,
    pg_catalog.jsonb_build_object(
      'dish_code', v_code,
      'dish_name', v_dish_name,
      'dish_status', 'DRAFT',
      'dish_category', v_category,
      'dish_type_id', v_dish_type_id,
      'display_order', v_display_order,
      'requires_need_generation', v_requires
    ),
    'Dish created as a draft.',
    pg_catalog.jsonb_build_object('dish_id', v_dish_id)
  );
exception
  when unique_violation then
    return atlas_core.pa_05b_command_error(
      request,
      'CONFLICT',
      'The dish identity is already in use.',
      'ADMIN',
      v_name
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'The dish could not be created safely.',
      'ADMIN',
      v_name
    );
end;
$$;

create or replace function atlas_api.update_dish(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'update_dish';
  v_payload jsonb := request -> 'payload';
  v_dish_id uuid := atlas_core.pa_05b_safe_uuid(v_payload ->> 'dish_id');
  v_code text := pg_catalog.lower(
    pg_catalog.btrim(coalesce(v_payload ->> 'dish_code', ''))
  );
  v_dish_name text := pg_catalog.btrim(
    coalesce(v_payload ->> 'dish_name', '')
  );
  v_category text := nullif(
    pg_catalog.btrim(coalesce(v_payload ->> 'dish_category', '')),
    ''
  );
  v_dish_type_id uuid := atlas_core.pa_05b_safe_uuid(
    v_payload ->> 'dish_type_id'
  );
  v_notes text := nullif(
    pg_catalog.btrim(coalesce(v_payload ->> 'operational_notes', '')),
    ''
  );
  v_display_order bigint := atlas_core.pa_05b_safe_bigint(
    v_payload ->> 'display_order'
  );
  v_requires boolean;
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_dish atlas_admin.dishes%rowtype;
  v_before jsonb;
  v_after jsonb;
begin
  if atlas_core.rmvp_02a_validate_command_request(
    request,
    v_name
  ) is not null then
    return atlas_core.rmvp_02a_validate_command_request(request, v_name);
  end if;
  begin
    v_requires := (v_payload ->> 'requires_need_generation')::boolean;
  exception when others then
    v_requires := null;
  end;
  if v_dish_id is null
     or v_code = ''
     or v_dish_name = ''
     or v_dish_type_id is null
     or v_display_order is null
     or v_display_order < 0
     or v_display_order > 2147483647
     or v_requires is null then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'Dish values are incomplete or invalid.',
      'ADMIN',
      v_name
    );
  end if;
  v_prepare := atlas_core.rmvp_02a_prepare_command(
    request,
    v_name,
    'master_data.recipes.write',
    'dish:' || v_dish_id::text
  );
  if v_prepare ->> 'status' = 'RETURN' then
    return v_prepare -> 'response';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_dish_id::text, 17403)
  );
  select * into v_dish
  from atlas_admin.dishes
  where dish_id = v_dish_id
  for update;
  if not found then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'NOT_FOUND', 'The dish was not found.', 'ADMIN', v_name
      ),
      false
    );
  end if;
  if v_dish.version <> atlas_core.pa_05b_safe_bigint(
    request ->> 'expected_version'
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'STALE_VERSION',
        'The dish changed after it was read. Refresh before saving.',
        'ADMIN',
        v_name,
        false,
        '[]'::jsonb,
        '[]'::jsonb,
        v_dish.version
      ),
      false
    );
  end if;
  if atlas_core.uiq03a_dish_used_operationally(v_dish.dish_id) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'INVARIANT_VIOLATION',
        'Món này đã có trong thực đơn đã duyệt. Muốn thay đổi công thức, hãy dùng Điều chỉnh.',
        'ADMIN', v_name
      ),
      false
    );
  end if;
  if v_code <> v_dish.dish_code then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'INVARIANT_VIOLATION',
        'Dish code is a stable identity and cannot be changed.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  if not exists (
    select 1
    from atlas_admin.dish_types dish_type
    where dish_type.dish_type_id = v_dish_type_id
      and dish_type.dish_type_status = 'ACTIVE'
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'VALIDATION_FAILED',
        'The selected Dish Type is unknown or inactive.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  if v_dish.dish_status = 'ACTIVE' and exists (
    select 1
    from atlas_admin.dishes other_dish
    where other_dish.dish_id <> v_dish_id
      and other_dish.dish_status = 'ACTIVE'
      and pg_catalog.lower(pg_catalog.btrim(other_dish.dish_name))
        = pg_catalog.lower(v_dish_name)
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'CONFLICT',
        'An active dish with this normalized name already exists.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  v_before := pg_catalog.jsonb_build_object(
    'dish_code', v_dish.dish_code,
    'dish_name', v_dish.dish_name,
    'dish_category', v_dish.dish_category,
    'dish_type_id', v_dish.dish_type_id,
    'operational_notes', v_dish.operational_notes,
    'display_order', v_dish.display_order,
    'requires_need_generation', v_dish.requires_need_generation
  );
  update atlas_admin.dishes
  set dish_name = v_dish_name,
      dish_category = v_category,
      dish_type_id = v_dish_type_id,
      operational_notes = v_notes,
      display_order = v_display_order::integer,
      requires_need_generation = v_requires,
      version = version + 1,
      updated_at = pg_catalog.transaction_timestamp()
  where dish_id = v_dish_id;
  v_after := pg_catalog.jsonb_build_object(
    'dish_code', v_code,
    'dish_name', v_dish_name,
    'dish_category', v_category,
    'dish_type_id', v_dish_type_id,
    'operational_notes', v_notes,
    'display_order', v_display_order,
    'requires_need_generation', v_requires
  );
  return atlas_core.rmvp_02a_finish_success(
    request,
    v_actor_id,
    v_receipt_id,
    'DishUpdated',
    'Dish',
    v_dish_id,
    v_dish.version,
    v_dish.version + 1,
    v_before,
    v_after,
    'Dish details saved.',
    pg_catalog.jsonb_build_object('dish_id', v_dish_id)
  );
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request,
      'RETRYABLE_CONCURRENCY_FAILURE',
      'The dish could not be locked safely. Retry the exact request.',
      'ADMIN',
      v_name,
      true
    );
  when unique_violation then
    return atlas_core.pa_05b_command_error(
      request,
      'CONFLICT',
      'The active normalized dish name is already in use.',
      'ADMIN',
      v_name
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'The dish could not be saved safely.',
      'ADMIN',
      v_name
    );
end;
$$;

create or replace function atlas_api.set_dish_lifecycle(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'set_dish_lifecycle';
  v_payload jsonb := request -> 'payload';
  v_dish_id uuid := atlas_core.pa_05b_safe_uuid(v_payload ->> 'dish_id');
  v_target_status text := pg_catalog.upper(
    pg_catalog.btrim(coalesce(v_payload ->> 'dish_status', ''))
  );
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_dish atlas_admin.dishes%rowtype;
begin
  if atlas_core.rmvp_02a_validate_command_request(
    request,
    v_name
  ) is not null then
    return atlas_core.rmvp_02a_validate_command_request(request, v_name);
  end if;
  if v_dish_id is null or v_target_status not in ('ACTIVE', 'INACTIVE') then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'Dish lifecycle values are invalid.',
      'ADMIN',
      v_name
    );
  end if;
  v_prepare := atlas_core.rmvp_02a_prepare_command(
    request,
    v_name,
    'master_data.recipes.write',
    'dish:' || v_dish_id::text
  );
  if v_prepare ->> 'status' = 'RETURN' then
    return v_prepare -> 'response';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_dish_id::text, 17403)
  );
  select * into v_dish
  from atlas_admin.dishes
  where dish_id = v_dish_id
  for update;
  if not found then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'NOT_FOUND', 'The dish was not found.', 'ADMIN', v_name
      ),
      false
    );
  end if;
  if v_dish.version <> atlas_core.pa_05b_safe_bigint(
    request ->> 'expected_version'
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'STALE_VERSION',
        'The dish changed after it was read. Refresh before changing status.',
        'ADMIN',
        v_name,
        false,
        '[]'::jsonb,
        '[]'::jsonb,
        v_dish.version
      ),
      false
    );
  end if;
  if atlas_core.uiq03a_dish_used_operationally(v_dish.dish_id) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'INVARIANT_VIOLATION',
        'Món này đã có trong thực đơn đã duyệt. Muốn thay đổi công thức, hãy dùng Điều chỉnh.',
        'ADMIN', v_name
      ),
      false
    );
  end if;
  if v_dish.dish_status = v_target_status
     or not (
       (v_dish.dish_status = 'DRAFT' and v_target_status = 'ACTIVE')
       or (v_dish.dish_status = 'ACTIVE' and v_target_status = 'INACTIVE')
       or (v_dish.dish_status = 'INACTIVE' and v_target_status = 'ACTIVE')
     ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'INVARIANT_VIOLATION',
        'The requested dish lifecycle transition is not allowed.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  if v_target_status = 'ACTIVE' and not exists (
    select 1
    from atlas_admin.dish_types dish_type
    where dish_type.dish_type_id = v_dish.dish_type_id
      and dish_type.dish_type_status = 'ACTIVE'
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'INVARIANT_VIOLATION',
        'An active database-backed Dish Type is required before activation.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  if v_target_status = 'ACTIVE' and exists (
    select 1
    from atlas_admin.dishes other_dish
    where other_dish.dish_id <> v_dish_id
      and other_dish.dish_status = 'ACTIVE'
      and pg_catalog.lower(pg_catalog.btrim(other_dish.dish_name))
        = pg_catalog.lower(pg_catalog.btrim(v_dish.dish_name))
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'CONFLICT',
        'An active dish with this normalized name already exists.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  update atlas_admin.dishes
  set dish_status = v_target_status,
      version = version + 1,
      updated_at = pg_catalog.transaction_timestamp()
  where dish_id = v_dish_id;
  return atlas_core.rmvp_02a_finish_success(
    request,
    v_actor_id,
    v_receipt_id,
    case
      when v_target_status = 'ACTIVE' then 'DishActivated'
      else 'DishDeactivated'
    end,
    'Dish',
    v_dish_id,
    v_dish.version,
    v_dish.version + 1,
    pg_catalog.jsonb_build_object(
      'dish_status', v_dish.dish_status,
      'dish_type_id', v_dish.dish_type_id
    ),
    pg_catalog.jsonb_build_object(
      'dish_status', v_target_status,
      'dish_type_id', v_dish.dish_type_id
    ),
    case
      when v_target_status = 'ACTIVE' then 'Dish activated.'
      else 'Dish deactivated; historical references were preserved.'
    end,
    pg_catalog.jsonb_build_object('dish_id', v_dish_id)
  );
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request,
      'RETRYABLE_CONCURRENCY_FAILURE',
      'The dish could not be locked safely. Retry the exact request.',
      'ADMIN',
      v_name,
      true
    );
  when unique_violation then
    return atlas_core.pa_05b_command_error(
      request,
      'CONFLICT',
      'The active normalized dish name is already in use.',
      'ADMIN',
      v_name
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'The dish status could not be changed safely.',
      'ADMIN',
      v_name
    );
end;
$$;

comment on function atlas_api.create_dish(jsonb) is
  'RMVP-02A Dish create extended in RMVP-03A to require an active database-backed Dish Type.';
comment on function atlas_api.update_dish(jsonb) is
  'RMVP-02A Dish update extended in RMVP-03A with stable code and active Dish Type validation.';
comment on function atlas_api.set_dish_lifecycle(jsonb) is
  'RMVP-02A Dish lifecycle extended in RMVP-03A to require an active Dish Type before activation.';

reset role;
revoke create on schema atlas_api from atlas_master_data_command_runtime;
revoke atlas_master_data_command_runtime from postgres;
set role atlas_owner;

comment on table atlas_admin.dish_types is
  'RMVP-03A authoritative typed Dish classification and Weekly Menu slot catalog; codes are stable and referenced rows cannot be hard-deleted.';
comment on column atlas_admin.dishes.dish_type_id is
  'Nullable transition from historical free-text dish_category to authoritative Dish Type identity.';
comment on table atlas_planning.weekly_menu_google_sources is
  'RMVP-03A private connector configuration only; contains no Google credential and grants no direct browser access.';

reset role;

comment on schema atlas_api is
  'Function-only Atlas Data API boundary; includes reviewed master-data, Recipe/BOM, effective-adjustment, Weekly Menu, and Attendance commands and reads.';

-- Keep the temporary ownership memberships until the complete function bodies
-- below have replaced the transaction-local stubs.

create or replace function atlas_api.reopen_weekly_menu(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'reopen_weekly_menu';
  v_week_start date := atlas_core.pa_05d_safe_date(
    request -> 'payload' ->> 'week_start'
  );
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_menu atlas_planning.weekly_menus%rowtype;
begin
  v_prepare := atlas_core.rmvp_03a_prepare_command(
    request,
    v_name,
    'planning.inputs.approve',
    'weekly-menu:' || coalesce(v_week_start::text, 'invalid')
  );
  if v_prepare ->> 'status' = 'RETURN' then
    return v_prepare -> 'response';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  if atlas_core.rmvp_03a_normalize_text(
    request ->> 'reason_note'
  ) is null then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'VALIDATION_FAILED',
        'Reopening requires a non-empty reason note.',
        'PLANNING',
        v_name
      ),
      false
    );
  end if;
  select *
    into v_menu
  from atlas_planning.weekly_menus menu
  where menu.week_start = v_week_start
  for update;
  if not found then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'NOT_FOUND', 'The Weekly Menu was not found.',
        'PLANNING', v_name
      ),
      false
    );
  end if;
  if v_menu.version <> atlas_core.pa_05b_safe_bigint(
    request ->> 'expected_version'
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'STALE_VERSION',
        'The Weekly Menu changed after it was read.',
        'PLANNING',
        v_name,
        false,
        '[]'::jsonb,
        '[]'::jsonb,
        v_menu.version
      ),
      false
    );
  end if;
  if v_menu.weekly_menu_status not in (
    'APPROVED',
    'NEED_GENERATION_REQUESTED'
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'INVARIANT_VIOLATION',
        'Only an approved or requested Weekly Menu can be reopened.',
        'PLANNING',
        v_name
      ),
      false
    );
  end if;
  update atlas_planning.weekly_menus
  set weekly_menu_status = 'REOPENED',
      version = version + 1
  where weekly_menu_id = v_menu.weekly_menu_id;
  set constraints
    atlas_planning.weekly_menus_snapshot_integrity_guard,
    atlas_planning.weekly_menu_approval_snapshots_integrity_guard,
    atlas_planning.weekly_menu_approval_snapshot_lines_integrity_guard
    immediate;
  set constraints
    atlas_planning.weekly_menus_snapshot_integrity_guard,
    atlas_planning.weekly_menu_approval_snapshots_integrity_guard,
    atlas_planning.weekly_menu_approval_snapshot_lines_integrity_guard
    deferred;
  return atlas_core.rmvp_03a_finish_success(
    request,
    v_actor_id,
    v_receipt_id,
    'WeeklyMenuReopened',
    'WeeklyMenu',
    v_menu.weekly_menu_id,
    v_menu.version,
    v_menu.version + 1,
    pg_catalog.jsonb_build_object(
      'status', v_menu.weekly_menu_status,
      'approval_snapshot_id', v_menu.latest_approval_snapshot_id
    ),
    pg_catalog.jsonb_build_object(
      'status', 'REOPENED',
      'approval_snapshot_id', v_menu.latest_approval_snapshot_id
    ),
    'Weekly Menu reopened as the next working version; approval history was preserved.',
    pg_catalog.jsonb_build_object(
      'weekly_menu_id', v_menu.weekly_menu_id
    ),
    v_week_start
  );
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request,
      'RETRYABLE_CONCURRENCY_FAILURE',
      'The Weekly Menu could not be locked safely. Retry the exact request.',
      'PLANNING',
      v_name,
      true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'The Weekly Menu could not be reopened safely.',
      'PLANNING',
      v_name
    );
end;
$$;

create or replace function atlas_core.rmvp_03a_save_attendance_internal(
  request jsonb,
  command_name text,
  proposed_rows jsonb,
  proposed_source_type text,
  proposed_source_name text,
  proposed_signature text
)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  v_week_start date := atlas_core.pa_05d_safe_date(
    request -> 'payload' ->> 'week_start'
  );
  v_rows jsonb := atlas_core.rmvp_03a_canonical_attendance_rows(
    proposed_rows
  );
  v_signature text := atlas_core.rmvp_03a_attendance_signature(v_rows);
  v_source_type text := coalesce(
    atlas_core.rmvp_03a_normalize_text(proposed_source_type),
    ''
  );
  v_source_name text := coalesce(
    atlas_core.rmvp_03a_normalize_text(proposed_source_name),
    ''
  );
  v_supplied_signature text := pg_catalog.lower(
    coalesce(
      atlas_core.rmvp_03a_normalize_text(proposed_signature),
      ''
    )
  );
  v_expected_source_signature text := pg_catalog.lower(
    coalesce(
      atlas_core.rmvp_03a_normalize_text(
        request -> 'payload' ->> 'expected_source_signature'
      ),
      ''
    )
  );
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_batch atlas_planning.attendance_batches%rowtype;
  v_issues jsonb;
  v_current_rows jsonb := '[]'::jsonb;
  v_current_signature text;
  v_before_status text;
  v_created boolean := false;
begin
  v_prepare := atlas_core.rmvp_03a_prepare_command(
    request,
    command_name,
    'planning.attendance.write',
    'attendance:' || coalesce(v_week_start::text, 'invalid')
  );
  if v_prepare ->> 'status' = 'RETURN' then
    return v_prepare -> 'response';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');

  if v_source_type = '' or v_source_name = '' then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'VALIDATION_FAILED',
        'Source type and source name are required.',
        'PLANNING',
        command_name
      ),
      false
    );
  end if;
  if v_supplied_signature = ''
     or v_supplied_signature <> v_signature then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'CHECKSUM_MISMATCH',
        'Save requires the checksum returned by the canonical preview.',
        'PLANNING',
        command_name
      ),
      false
    );
  end if;
  v_issues := atlas_core.rmvp_03a_attendance_issues(
    v_week_start,
    v_rows
  );
  if pg_catalog.jsonb_array_length(v_issues -> 'blockers') > 0 then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'VALIDATION_FAILED',
        'Attendance blockers must be resolved before saving.',
        'PLANNING',
        command_name,
        false,
        '[]'::jsonb,
        v_issues -> 'blockers'
      ),
      false
    );
  end if;

  select *
    into v_batch
  from atlas_planning.attendance_batches batch
  where batch.period_start = v_week_start
    and batch.period_end = v_week_start + 6
  for update;

  if found then
    if v_batch.version <> atlas_core.pa_05b_safe_bigint(
      request ->> 'expected_version'
    ) then
      return atlas_core.pa_05b_finish_command(
        v_receipt_id,
        atlas_core.pa_05b_command_error(
          request,
          'STALE_VERSION',
          'Attendance changed after it was read. Refresh before saving.',
          'PLANNING',
          command_name,
          false,
          '[]'::jsonb,
          '[]'::jsonb,
          v_batch.version
        ),
        false
      );
    end if;
    if v_expected_source_signature = ''
       or v_expected_source_signature <> v_batch.source_signature then
      return atlas_core.pa_05b_finish_command(
        v_receipt_id,
        atlas_core.pa_05b_command_error(
          request,
          'STALE_SOURCE_SIGNATURE',
          'Attendance source changed after it was read.',
          'PLANNING',
          command_name
        ),
        false
      );
    end if;
    if v_batch.attendance_status not in ('DRAFT', 'REOPENED') then
      return atlas_core.pa_05b_finish_command(
        v_receipt_id,
        atlas_core.pa_05b_command_error(
          request,
          'INVARIANT_VIOLATION',
          'Only DRAFT or REOPENED Attendance can be saved.',
          'PLANNING',
          command_name
        ),
        false
      );
    end if;
    select coalesce(
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'school_id', line.school_id,
          'service_date', line.service_date,
          'student_portions', line.student_portions,
          'teacher_portions', line.teacher_portions,
          'source_row_reference', line.source_row_reference
        )
      ),
      '[]'::jsonb
    )
      into v_current_rows
    from atlas_planning.attendance_lines line
    where line.attendance_batch_id = v_batch.attendance_batch_id
      and line.line_status = 'ACTIVE';
    v_current_signature := atlas_core.rmvp_03a_attendance_signature(
      v_current_rows
    );
    if v_current_signature <> v_batch.source_signature then
      return atlas_core.pa_05b_finish_command(
        v_receipt_id,
        atlas_core.pa_05b_command_error(
          request,
          'PERSISTED_SIGNATURE_MISMATCH',
          'Stored attendance evidence does not match its active rows.',
          'PLANNING',
          command_name
        ),
        false
      );
    end if;
    if v_batch.attendance_status = 'DRAFT'
       and v_signature = v_current_signature
       and v_source_type = v_batch.source_type
       and v_source_name = v_batch.source_name then
      return atlas_core.rmvp_03a_finish_no_change(
        request,
        v_receipt_id,
        v_week_start,
        'Canonical Attendance already matches the saved draft.'
      );
    end if;
  else
    if atlas_core.pa_05b_safe_bigint(
      request ->> 'expected_version'
    ) <> 1
       or v_expected_source_signature <> '' then
      return atlas_core.pa_05b_finish_command(
        v_receipt_id,
        atlas_core.pa_05b_command_error(
          request,
          'STALE_VERSION',
          'New Attendance starts at version 1 with no prior signature.',
          'PLANNING',
          command_name
        ),
        false
      );
    end if;
    insert into atlas_planning.attendance_batches (
      period_start,
      period_end,
      source_type,
      source_name,
      source_signature,
      attendance_status,
      row_count,
      imported_by_actor_id
    ) values (
      v_week_start,
      v_week_start + 6,
      v_source_type,
      v_source_name,
      v_signature,
      'DRAFT',
      pg_catalog.jsonb_array_length(v_rows),
      v_actor_id
    )
    returning * into v_batch;
    v_created := true;
  end if;

  v_before_status := v_batch.attendance_status;

  if not v_created then
    if v_batch.attendance_status = 'REOPENED' then
      update atlas_planning.attendance_batches
      set attendance_status = 'DRAFT'
      where attendance_batch_id = v_batch.attendance_batch_id;
    end if;
    update atlas_planning.attendance_batches
    set source_type = v_source_type,
        source_name = v_source_name,
        source_signature = v_signature,
        row_count = pg_catalog.jsonb_array_length(v_rows),
        imported_by_actor_id = v_actor_id,
        imported_at = pg_catalog.transaction_timestamp(),
        updated_at = pg_catalog.transaction_timestamp()
    where attendance_batch_id = v_batch.attendance_batch_id;
  end if;

  update atlas_planning.attendance_lines line
  set line_status = 'INVALID',
      updated_by_actor_id = v_actor_id,
      updated_at = pg_catalog.transaction_timestamp()
  where line.attendance_batch_id = v_batch.attendance_batch_id
    and line.line_status = 'ACTIVE'
    and not exists (
      select 1
      from pg_catalog.jsonb_array_elements(v_rows) item
      where atlas_core.pa_05b_safe_uuid(item ->> 'school_id') =
          line.school_id
        and atlas_core.pa_05d_safe_date(item ->> 'service_date') =
          line.service_date
    );

  insert into atlas_planning.attendance_lines (
    attendance_batch_id,
    school_id,
    service_date,
    student_portions,
    teacher_portions,
    line_status,
    source_row_reference,
    created_by_actor_id,
    updated_by_actor_id
  )
  select
    v_batch.attendance_batch_id,
    atlas_core.pa_05b_safe_uuid(item ->> 'school_id'),
    atlas_core.pa_05d_safe_date(item ->> 'service_date'),
    atlas_core.rmvp_03a_safe_nonnegative_integer(
      item ->> 'student_portions'
    ),
    atlas_core.rmvp_03a_safe_nonnegative_integer(
      item ->> 'teacher_portions'
    ),
    'ACTIVE',
    item ->> 'source_row_reference',
    v_actor_id,
    v_actor_id
  from pg_catalog.jsonb_array_elements(v_rows) item
  on conflict (
    attendance_batch_id,
    school_id,
    service_date
  ) do update set
    student_portions = excluded.student_portions,
    teacher_portions = excluded.teacher_portions,
    line_status = 'ACTIVE',
    source_row_reference = excluded.source_row_reference,
    updated_by_actor_id = excluded.updated_by_actor_id,
    updated_at = pg_catalog.transaction_timestamp();

  set constraints
    atlas_planning.attendance_batches_snapshot_integrity_guard,
    atlas_planning.attendance_approval_snapshots_integrity_guard,
    atlas_planning.attendance_approval_snapshot_lines_integrity_guard
    immediate;
  set constraints
    atlas_planning.attendance_batches_snapshot_integrity_guard,
    atlas_planning.attendance_approval_snapshots_integrity_guard,
    atlas_planning.attendance_approval_snapshot_lines_integrity_guard
    deferred;

  return atlas_core.rmvp_03a_finish_success(
    request,
    v_actor_id,
    v_receipt_id,
    case
      when v_created then 'AttendanceDraftCreated'
      else 'AttendanceDraftReplaced'
    end,
    'AttendanceBatch',
    v_batch.attendance_batch_id,
    v_batch.version,
    v_batch.version,
    pg_catalog.jsonb_build_object(
      'status', v_before_status,
      'source_signature', v_batch.source_signature,
      'row_count', v_batch.row_count
    ),
    pg_catalog.jsonb_build_object(
      'status', 'DRAFT',
      'source_signature', v_signature,
      'row_count', pg_catalog.jsonb_array_length(v_rows)
    ),
    'Attendance draft saved with stable row identities.',
    pg_catalog.jsonb_build_object(
      'attendance_batch_id', v_batch.attendance_batch_id
    ),
    v_week_start
  );
end;
$$;

create or replace function atlas_api.create_attendance_draft_from_defaults(
  request jsonb
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'create_attendance_draft_from_defaults';
  v_week_start date := atlas_core.pa_05d_safe_date(
    request -> 'payload' ->> 'week_start'
  );
  v_rows jsonb := atlas_core.rmvp_03a_default_attendance_rows(
    v_week_start
  );
begin
  return atlas_core.rmvp_03a_save_attendance_internal(
    request,
    v_name,
    v_rows,
    'SCHOOL_DEFAULTS',
    'School defaults for ' || coalesce(v_week_start::text, 'invalid'),
    request -> 'payload' ->> 'source_signature'
  );
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request,
      'RETRYABLE_CONCURRENCY_FAILURE',
      'Attendance could not be locked safely. Retry the exact request.',
      'PLANNING',
      v_name,
      true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'Attendance defaults could not be saved safely.',
      'PLANNING',
      v_name
    );
end;
$$;

create or replace function atlas_api.save_attendance_draft(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'save_attendance_draft';
begin
  return atlas_core.rmvp_03a_save_attendance_internal(
    request,
    v_name,
    request -> 'payload' -> 'rows',
    request -> 'payload' ->> 'source_type',
    request -> 'payload' ->> 'source_name',
    request -> 'payload' ->> 'source_signature'
  );
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request,
      'RETRYABLE_CONCURRENCY_FAILURE',
      'Attendance could not be locked safely. Retry the exact request.',
      'PLANNING',
      v_name,
      true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'Attendance could not be saved safely.',
      'PLANNING',
      v_name
    );
end;
$$;

create or replace function atlas_api.validate_attendance(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'validate_attendance';
  v_week_start date := atlas_core.pa_05d_safe_date(
    request -> 'payload' ->> 'week_start'
  );
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_batch atlas_planning.attendance_batches%rowtype;
  v_rows jsonb;
  v_issues jsonb;
begin
  v_prepare := atlas_core.rmvp_03a_prepare_command(
    request,
    v_name,
    'planning.attendance.write',
    'attendance:' || coalesce(v_week_start::text, 'invalid')
  );
  if v_prepare ->> 'status' = 'RETURN' then
    return v_prepare -> 'response';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  select *
    into v_batch
  from atlas_planning.attendance_batches batch
  where batch.period_start = v_week_start
    and batch.period_end = v_week_start + 6
  for update;
  if not found then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'NOT_FOUND', 'Attendance was not found.',
        'PLANNING', v_name
      ),
      false
    );
  end if;
  if v_batch.version <> atlas_core.pa_05b_safe_bigint(
    request ->> 'expected_version'
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'STALE_VERSION',
        'Attendance changed after it was read.',
        'PLANNING',
        v_name,
        false,
        '[]'::jsonb,
        '[]'::jsonb,
        v_batch.version
      ),
      false
    );
  end if;
  if v_batch.attendance_status <> 'DRAFT' then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'INVARIANT_VIOLATION',
        'Only DRAFT Attendance can be validated.',
        'PLANNING',
        v_name
      ),
      false
    );
  end if;
  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'school_id', line.school_id,
        'service_date', line.service_date,
        'student_portions', line.student_portions,
        'teacher_portions', line.teacher_portions,
        'source_row_reference', line.source_row_reference
      )
    ),
    '[]'::jsonb
  )
    into v_rows
  from atlas_planning.attendance_lines line
  where line.attendance_batch_id = v_batch.attendance_batch_id
    and line.line_status = 'ACTIVE';
  v_issues := atlas_core.rmvp_03a_attendance_issues(
    v_week_start,
    v_rows
  );
  if pg_catalog.jsonb_array_length(v_issues -> 'blockers') > 0 then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'VALIDATION_FAILED',
        'Attendance blockers must be resolved before validation.',
        'PLANNING',
        v_name,
        false,
        '[]'::jsonb,
        v_issues -> 'blockers'
      ),
      false
    );
  end if;
  update atlas_planning.attendance_batches
  set attendance_status = 'VALIDATED'
  where attendance_batch_id = v_batch.attendance_batch_id;
  set constraints
    atlas_planning.attendance_batches_snapshot_integrity_guard,
    atlas_planning.attendance_approval_snapshots_integrity_guard,
    atlas_planning.attendance_approval_snapshot_lines_integrity_guard
    immediate;
  set constraints
    atlas_planning.attendance_batches_snapshot_integrity_guard,
    atlas_planning.attendance_approval_snapshots_integrity_guard,
    atlas_planning.attendance_approval_snapshot_lines_integrity_guard
    deferred;
  return atlas_core.rmvp_03a_finish_success(
    request,
    v_actor_id,
    v_receipt_id,
    'AttendanceValidated',
    'AttendanceBatch',
    v_batch.attendance_batch_id,
    v_batch.version,
    v_batch.version,
    pg_catalog.jsonb_build_object('status', 'DRAFT'),
    pg_catalog.jsonb_build_object(
      'status', 'VALIDATED',
      'row_count', v_batch.row_count
    ),
    'Attendance validated against current Planning references.',
    pg_catalog.jsonb_build_object(
      'attendance_batch_id', v_batch.attendance_batch_id
    ),
    v_week_start
  );
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request,
      'RETRYABLE_CONCURRENCY_FAILURE',
      'Attendance could not be locked safely. Retry the exact request.',
      'PLANNING',
      v_name,
      true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'Attendance could not be validated safely.',
      'PLANNING',
      v_name
    );
end;
$$;

create or replace function atlas_api.approve_attendance(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'approve_attendance';
  v_week_start date := atlas_core.pa_05d_safe_date(
    request -> 'payload' ->> 'week_start'
  );
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_batch atlas_planning.attendance_batches%rowtype;
  v_rows jsonb;
  v_issues jsonb;
  v_snapshot_id uuid := gen_random_uuid();
  v_approved_at timestamptz := pg_catalog.transaction_timestamp();
begin
  v_prepare := atlas_core.rmvp_03a_prepare_command(
    request,
    v_name,
    'planning.inputs.approve',
    'attendance:' || coalesce(v_week_start::text, 'invalid')
  );
  if v_prepare ->> 'status' = 'RETURN' then
    return v_prepare -> 'response';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  select *
    into v_batch
  from atlas_planning.attendance_batches batch
  where batch.period_start = v_week_start
    and batch.period_end = v_week_start + 6
  for update;
  if not found then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'NOT_FOUND', 'Attendance was not found.',
        'PLANNING', v_name
      ),
      false
    );
  end if;
  if v_batch.version <> atlas_core.pa_05b_safe_bigint(
    request ->> 'expected_version'
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'STALE_VERSION',
        'Attendance changed after it was read.',
        'PLANNING',
        v_name,
        false,
        '[]'::jsonb,
        '[]'::jsonb,
        v_batch.version
      ),
      false
    );
  end if;
  if v_batch.attendance_status <> 'VALIDATED' then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'INVARIANT_VIOLATION',
        'Only VALIDATED Attendance can be approved.',
        'PLANNING',
        v_name
      ),
      false
    );
  end if;
  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'school_id', line.school_id,
        'service_date', line.service_date,
        'student_portions', line.student_portions,
        'teacher_portions', line.teacher_portions,
        'source_row_reference', line.source_row_reference
      )
    ),
    '[]'::jsonb
  )
    into v_rows
  from atlas_planning.attendance_lines line
  where line.attendance_batch_id = v_batch.attendance_batch_id
    and line.line_status = 'ACTIVE';
  v_issues := atlas_core.rmvp_03a_attendance_issues(
    v_week_start,
    v_rows
  );
  if pg_catalog.jsonb_array_length(v_issues -> 'blockers') > 0 then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'VALIDATION_FAILED',
        'Attendance blockers must be resolved before approval.',
        'PLANNING',
        v_name,
        false,
        '[]'::jsonb,
        v_issues -> 'blockers'
      ),
      false
    );
  end if;
  insert into atlas_planning.attendance_approval_snapshots (
    attendance_approval_snapshot_id,
    attendance_batch_id,
    attendance_version,
    approved_by_actor_id,
    approved_at
  ) values (
    v_snapshot_id,
    v_batch.attendance_batch_id,
    v_batch.version,
    v_actor_id,
    v_approved_at
  );
  insert into atlas_planning.attendance_approval_snapshot_lines (
    attendance_approval_snapshot_id,
    attendance_batch_id,
    attendance_version,
    attendance_line_id,
    school_id,
    service_date,
    student_portions,
    teacher_portions,
    source_row_reference
  )
  select
    v_snapshot_id,
    v_batch.attendance_batch_id,
    v_batch.version,
    line.attendance_line_id,
    line.school_id,
    line.service_date,
    line.student_portions,
    line.teacher_portions,
    line.source_row_reference
  from atlas_planning.attendance_lines line
  where line.attendance_batch_id = v_batch.attendance_batch_id
    and line.line_status = 'ACTIVE';
  update atlas_planning.attendance_batches
  set attendance_status = 'APPROVED',
      latest_approved_by_actor_id = v_actor_id,
      latest_approved_at = v_approved_at,
      latest_approval_snapshot_id = v_snapshot_id
  where attendance_batch_id = v_batch.attendance_batch_id;
  set constraints
    atlas_planning.attendance_batches_snapshot_integrity_guard,
    atlas_planning.attendance_approval_snapshots_integrity_guard,
    atlas_planning.attendance_approval_snapshot_lines_integrity_guard
    immediate;
  set constraints
    atlas_planning.attendance_batches_snapshot_integrity_guard,
    atlas_planning.attendance_approval_snapshots_integrity_guard,
    atlas_planning.attendance_approval_snapshot_lines_integrity_guard
    deferred;
  return atlas_core.rmvp_03a_finish_success(
    request,
    v_actor_id,
    v_receipt_id,
    'AttendanceApproved',
    'AttendanceBatch',
    v_batch.attendance_batch_id,
    v_batch.version,
    v_batch.version,
    pg_catalog.jsonb_build_object('status', 'VALIDATED'),
    pg_catalog.jsonb_build_object(
      'status', 'APPROVED',
      'approval_snapshot_id', v_snapshot_id,
      'row_count', v_batch.row_count
    ),
    'Attendance approved with an immutable exact-line snapshot.',
    pg_catalog.jsonb_build_object(
      'attendance_batch_id', v_batch.attendance_batch_id,
      'attendance_approval_snapshot_id', v_snapshot_id
    ),
    v_week_start
  );
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request,
      'RETRYABLE_CONCURRENCY_FAILURE',
      'Attendance could not be locked safely. Retry the exact request.',
      'PLANNING',
      v_name,
      true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'Attendance could not be approved safely.',
      'PLANNING',
      v_name
    );
end;
$$;

create or replace function atlas_api.reopen_attendance(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'reopen_attendance';
  v_week_start date := atlas_core.pa_05d_safe_date(
    request -> 'payload' ->> 'week_start'
  );
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_batch atlas_planning.attendance_batches%rowtype;
begin
  v_prepare := atlas_core.rmvp_03a_prepare_command(
    request,
    v_name,
    'planning.inputs.approve',
    'attendance:' || coalesce(v_week_start::text, 'invalid')
  );
  if v_prepare ->> 'status' = 'RETURN' then
    return v_prepare -> 'response';
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  if atlas_core.rmvp_03a_normalize_text(
    request ->> 'reason_note'
  ) is null then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'VALIDATION_FAILED',
        'Reopening requires a non-empty reason note.',
        'PLANNING',
        v_name
      ),
      false
    );
  end if;
  select *
    into v_batch
  from atlas_planning.attendance_batches batch
  where batch.period_start = v_week_start
    and batch.period_end = v_week_start + 6
  for update;
  if not found then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'NOT_FOUND', 'Attendance was not found.',
        'PLANNING', v_name
      ),
      false
    );
  end if;
  if v_batch.version <> atlas_core.pa_05b_safe_bigint(
    request ->> 'expected_version'
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'STALE_VERSION',
        'Attendance changed after it was read.',
        'PLANNING',
        v_name,
        false,
        '[]'::jsonb,
        '[]'::jsonb,
        v_batch.version
      ),
      false
    );
  end if;
  if v_batch.attendance_status not in (
    'APPROVED',
    'USED_FOR_NEED_GENERATION'
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'INVARIANT_VIOLATION',
        'Only approved or used Attendance can be reopened.',
        'PLANNING',
        v_name
      ),
      false
    );
  end if;
  update atlas_planning.attendance_batches
  set attendance_status = 'REOPENED',
      version = version + 1
  where attendance_batch_id = v_batch.attendance_batch_id;
  set constraints
    atlas_planning.attendance_batches_snapshot_integrity_guard,
    atlas_planning.attendance_approval_snapshots_integrity_guard,
    atlas_planning.attendance_approval_snapshot_lines_integrity_guard
    immediate;
  set constraints
    atlas_planning.attendance_batches_snapshot_integrity_guard,
    atlas_planning.attendance_approval_snapshots_integrity_guard,
    atlas_planning.attendance_approval_snapshot_lines_integrity_guard
    deferred;
  return atlas_core.rmvp_03a_finish_success(
    request,
    v_actor_id,
    v_receipt_id,
    'AttendanceReopened',
    'AttendanceBatch',
    v_batch.attendance_batch_id,
    v_batch.version,
    v_batch.version + 1,
    pg_catalog.jsonb_build_object(
      'status', v_batch.attendance_status,
      'approval_snapshot_id', v_batch.latest_approval_snapshot_id
    ),
    pg_catalog.jsonb_build_object(
      'status', 'REOPENED',
      'approval_snapshot_id', v_batch.latest_approval_snapshot_id
    ),
    'Attendance reopened as the next working version; approval history was preserved.',
    pg_catalog.jsonb_build_object(
      'attendance_batch_id', v_batch.attendance_batch_id
    ),
    v_week_start
  );
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request,
      'RETRYABLE_CONCURRENCY_FAILURE',
      'Attendance could not be locked safely. Retry the exact request.',
      'PLANNING',
      v_name,
      true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'Attendance could not be reopened safely.',
      'PLANNING',
      v_name
    );
end;
$$;

revoke atlas_planning_command_runtime, atlas_read_runtime from postgres;
