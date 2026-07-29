-- PANTRY-02: connected Planning-owned Pantry source.
--
-- This migration is deliberately bounded to five private Pantry relations,
-- six reviewed atlas_api functions, one capability, and zero roles. It adds
-- no production Purpose rows, downstream Planning facts, fulfilment facts,
-- hosted resources, or legacy-system writes.

set role atlas_owner;

create table atlas_planning.pantry_need_purposes (
  pantry_need_purpose_id uuid not null default gen_random_uuid(),
  purpose_code text not null,
  purpose_name_vi text not null,
  purpose_description text not null,
  note_rule text not null,
  purpose_status text not null default 'ACTIVE',
  display_order integer not null,
  version bigint not null default 1,
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  constraint pantry_need_purposes_pkey primary key (pantry_need_purpose_id),
  constraint pantry_need_purposes_code_key unique (purpose_code),
  constraint pantry_need_purposes_code_check check (
    purpose_code = lower(btrim(purpose_code))
    and purpose_code ~ '^[a-z][a-z0-9]*(_[a-z0-9]+)*$'
  ),
  constraint pantry_need_purposes_name_check check (
    btrim(purpose_name_vi) <> ''
  ),
  constraint pantry_need_purposes_description_check check (
    btrim(purpose_description) <> ''
  ),
  constraint pantry_need_purposes_note_rule_check check (
    note_rule in ('OPTIONAL', 'REQUIRED', 'PROHIBITED')
  ),
  constraint pantry_need_purposes_status_check check (
    purpose_status in ('ACTIVE', 'INACTIVE')
  ),
  constraint pantry_need_purposes_display_order_check check (
    display_order >= 0
  ),
  constraint pantry_need_purposes_version_check check (version > 0),
  constraint pantry_need_purposes_timestamps_check check (
    updated_at >= created_at
  )
);

create index pantry_need_purposes_status_order_idx
  on atlas_planning.pantry_need_purposes (
    purpose_status,
    display_order,
    purpose_code
  );

create table atlas_planning.pantry_need_batches (
  pantry_need_batch_id uuid not null default gen_random_uuid(),
  week_start date not null,
  week_end date generated always as (week_start + 6) stored,
  pantry_need_batch_status text not null default 'DRAFT',
  version bigint not null default 1,
  source_type text not null default 'MANUAL_ATLAS',
  source_name text not null default 'Nhập thủ công Atlas',
  source_signature text not null,
  no_additions_confirmed boolean not null default false,
  requesting_actor_id uuid not null,
  creation_method text not null default 'MANUAL_ATLAS',
  latest_approved_by_actor_id uuid,
  latest_approved_at timestamptz,
  latest_approval_snapshot_id uuid,
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  constraint pantry_need_batches_pkey primary key (pantry_need_batch_id),
  constraint pantry_need_batches_week_start_key unique (week_start),
  constraint pantry_need_batches_id_version_key unique (
    pantry_need_batch_id,
    version
  ),
  constraint pantry_need_batches_requesting_actor_fkey foreign key (
    requesting_actor_id
  ) references atlas_core.actors (actor_id) on delete restrict,
  constraint pantry_need_batches_latest_approved_actor_fkey foreign key (
    latest_approved_by_actor_id
  ) references atlas_core.actors (actor_id) on delete restrict,
  constraint pantry_need_batches_week_check check (
    extract(isodow from week_start) = 1
  ),
  constraint pantry_need_batches_status_check check (
    pantry_need_batch_status in (
      'DRAFT',
      'VALIDATED',
      'APPROVED',
      'REOPENED'
    )
  ),
  constraint pantry_need_batches_version_check check (version > 0),
  constraint pantry_need_batches_source_type_check check (
    source_type = 'MANUAL_ATLAS'
  ),
  constraint pantry_need_batches_source_name_check check (
    source_name = 'Nhập thủ công Atlas'
  ),
  constraint pantry_need_batches_signature_check check (
    source_signature ~ '^[0-9a-f]{64}$'
  ),
  constraint pantry_need_batches_creation_method_check check (
    creation_method = 'MANUAL_ATLAS'
  ),
  constraint pantry_need_batches_approval_evidence_check check (
    (
      latest_approved_by_actor_id is null
      and latest_approved_at is null
      and latest_approval_snapshot_id is null
    )
    or (
      latest_approved_by_actor_id is not null
      and latest_approved_at is not null
      and latest_approval_snapshot_id is not null
    )
  ),
  constraint pantry_need_batches_approved_status_check check (
    pantry_need_batch_status <> 'APPROVED'
    or latest_approval_snapshot_id is not null
  ),
  constraint pantry_need_batches_timestamps_check check (
    updated_at >= created_at
  )
);

create index pantry_need_batches_requesting_actor_idx
  on atlas_planning.pantry_need_batches (requesting_actor_id);
create index pantry_need_batches_latest_approved_actor_idx
  on atlas_planning.pantry_need_batches (latest_approved_by_actor_id)
  where latest_approved_by_actor_id is not null;

create table atlas_planning.pantry_need_lines (
  pantry_need_line_id uuid not null default gen_random_uuid(),
  pantry_need_batch_id uuid not null,
  service_date date not null,
  school_id uuid not null,
  delivery_location_id uuid not null,
  ingredient_id uuid not null,
  unit_id uuid not null,
  pantry_need_purpose_id uuid not null,
  requested_quantity numeric(20, 6) not null,
  note text,
  source_request_reference text,
  source_row_reference text,
  line_status text not null default 'ACTIVE',
  updated_by_actor_id uuid not null,
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  constraint pantry_need_lines_pkey primary key (pantry_need_line_id),
  constraint pantry_need_lines_id_batch_key unique (
    pantry_need_line_id,
    pantry_need_batch_id
  ),
  constraint pantry_need_lines_batch_fkey foreign key (pantry_need_batch_id)
    references atlas_planning.pantry_need_batches (
      pantry_need_batch_id
    ) on delete restrict,
  constraint pantry_need_lines_school_fkey foreign key (school_id)
    references atlas_admin.schools (school_id) on delete restrict,
  constraint pantry_need_lines_delivery_location_fkey foreign key (
    delivery_location_id
  ) references atlas_admin.delivery_locations (
    delivery_location_id
  ) on delete restrict,
  constraint pantry_need_lines_ingredient_fkey foreign key (ingredient_id)
    references atlas_admin.ingredients (ingredient_id) on delete restrict,
  constraint pantry_need_lines_unit_fkey foreign key (unit_id)
    references atlas_admin.units (unit_id) on delete restrict,
  constraint pantry_need_lines_purpose_fkey foreign key (
    pantry_need_purpose_id
  ) references atlas_planning.pantry_need_purposes (
    pantry_need_purpose_id
  ) on delete restrict,
  constraint pantry_need_lines_updated_by_actor_fkey foreign key (
    updated_by_actor_id
  ) references atlas_core.actors (actor_id) on delete restrict,
  constraint pantry_need_lines_stable_grain_key unique (
    pantry_need_batch_id,
    service_date,
    school_id,
    delivery_location_id,
    ingredient_id
  ),
  constraint pantry_need_lines_quantity_check check (
    requested_quantity > 0
  ),
  constraint pantry_need_lines_note_check check (
    note is null or btrim(note) <> ''
  ),
  constraint pantry_need_lines_source_request_check check (
    source_request_reference is null
    or btrim(source_request_reference) <> ''
  ),
  constraint pantry_need_lines_source_row_check check (
    source_row_reference is null
    or btrim(source_row_reference) <> ''
  ),
  constraint pantry_need_lines_status_check check (
    line_status in ('ACTIVE', 'INVALID')
  ),
  constraint pantry_need_lines_timestamps_check check (
    updated_at >= created_at
  )
);

create index pantry_need_lines_school_idx
  on atlas_planning.pantry_need_lines (school_id);
create index pantry_need_lines_location_idx
  on atlas_planning.pantry_need_lines (delivery_location_id);
create index pantry_need_lines_ingredient_idx
  on atlas_planning.pantry_need_lines (ingredient_id);
create index pantry_need_lines_unit_idx
  on atlas_planning.pantry_need_lines (unit_id);
create index pantry_need_lines_purpose_idx
  on atlas_planning.pantry_need_lines (pantry_need_purpose_id);
create index pantry_need_lines_updated_actor_idx
  on atlas_planning.pantry_need_lines (updated_by_actor_id);
create index pantry_need_lines_active_batch_idx
  on atlas_planning.pantry_need_lines (
    pantry_need_batch_id,
    service_date,
    school_id,
    ingredient_id
  )
  where line_status = 'ACTIVE';

create table atlas_planning.pantry_need_approval_snapshots (
  pantry_need_approval_snapshot_id uuid not null default gen_random_uuid(),
  pantry_need_batch_id uuid not null,
  approved_batch_version bigint not null,
  approved_by_actor_id uuid not null,
  approved_at timestamptz not null,
  source_signature text not null,
  no_additions_confirmed boolean not null,
  line_count integer not null,
  blocker_summary jsonb not null default '[]'::jsonb,
  warning_summary jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default transaction_timestamp(),
  constraint pantry_need_approval_snapshots_pkey primary key (
    pantry_need_approval_snapshot_id
  ),
  constraint pantry_need_approval_snapshots_id_batch_key unique (
    pantry_need_approval_snapshot_id,
    pantry_need_batch_id
  ),
  constraint pantry_need_approval_snapshots_batch_fkey foreign key (
    pantry_need_batch_id
  ) references atlas_planning.pantry_need_batches (
    pantry_need_batch_id
  ) on delete restrict,
  constraint pantry_need_approval_snapshots_actor_fkey foreign key (
    approved_by_actor_id
  ) references atlas_core.actors (actor_id) on delete restrict,
  constraint pantry_need_approval_snapshots_batch_version_key unique (
    pantry_need_batch_id,
    approved_batch_version
  ),
  constraint pantry_need_approval_snapshots_version_check check (
    approved_batch_version > 0
  ),
  constraint pantry_need_approval_snapshots_signature_check check (
    source_signature ~ '^[0-9a-f]{64}$'
  ),
  constraint pantry_need_approval_snapshots_line_count_check check (
    line_count >= 0
  ),
  constraint pantry_need_approval_snapshots_summary_check check (
    jsonb_typeof(blocker_summary) = 'array'
    and jsonb_typeof(warning_summary) = 'array'
  ),
  constraint pantry_need_approval_snapshots_zero_line_check check (
    (
      no_additions_confirmed
      and line_count = 0
    )
    or (
      not no_additions_confirmed
      and line_count > 0
    )
  )
);

create index pantry_need_approval_snapshots_actor_idx
  on atlas_planning.pantry_need_approval_snapshots (
    approved_by_actor_id
  );

alter table atlas_planning.pantry_need_batches
  add constraint pantry_need_batches_latest_snapshot_fkey foreign key (
    latest_approval_snapshot_id,
    pantry_need_batch_id
  ) references atlas_planning.pantry_need_approval_snapshots (
    pantry_need_approval_snapshot_id,
    pantry_need_batch_id
  ) on delete restrict deferrable initially deferred;

create index pantry_need_batches_latest_snapshot_idx
  on atlas_planning.pantry_need_batches (latest_approval_snapshot_id)
  where latest_approval_snapshot_id is not null;

create table atlas_planning.pantry_need_approval_snapshot_lines (
  pantry_need_approval_snapshot_id uuid not null,
  pantry_need_line_id uuid not null,
  service_date date not null,
  school_id uuid not null,
  school_code_snapshot text not null,
  school_name_snapshot text not null,
  delivery_location_id uuid not null,
  delivery_location_code_snapshot text not null,
  delivery_location_name_snapshot text not null,
  delivery_location_address_snapshot text not null,
  ingredient_id uuid not null,
  ingredient_code_snapshot text not null,
  ingredient_name_snapshot text not null,
  unit_id uuid not null,
  unit_code_snapshot text not null,
  unit_name_snapshot text not null,
  pantry_need_purpose_id uuid not null,
  purpose_code_snapshot text not null,
  purpose_name_snapshot text not null,
  purpose_description_snapshot text not null,
  purpose_note_rule_snapshot text not null,
  requested_quantity numeric(20, 6) not null,
  note text,
  source_request_reference text,
  source_row_reference text,
  created_at timestamptz not null default transaction_timestamp(),
  constraint pantry_need_approval_snapshot_lines_pkey primary key (
    pantry_need_approval_snapshot_id,
    pantry_need_line_id
  ),
  constraint pantry_need_approval_snapshot_lines_snapshot_fkey foreign key (
    pantry_need_approval_snapshot_id
  ) references atlas_planning.pantry_need_approval_snapshots (
    pantry_need_approval_snapshot_id
  ) on delete restrict,
  constraint pantry_need_approval_snapshot_lines_working_line_fkey foreign key (
    pantry_need_line_id
  ) references atlas_planning.pantry_need_lines (
    pantry_need_line_id
  ) on delete restrict,
  constraint pantry_need_approval_snapshot_lines_school_fkey foreign key (
    school_id
  ) references atlas_admin.schools (school_id) on delete restrict,
  constraint pantry_need_approval_snapshot_lines_location_fkey foreign key (
    delivery_location_id
  ) references atlas_admin.delivery_locations (
    delivery_location_id
  ) on delete restrict,
  constraint pantry_need_approval_snapshot_lines_ingredient_fkey foreign key (
    ingredient_id
  ) references atlas_admin.ingredients (ingredient_id) on delete restrict,
  constraint pantry_need_approval_snapshot_lines_unit_fkey foreign key (
    unit_id
  ) references atlas_admin.units (unit_id) on delete restrict,
  constraint pantry_need_approval_snapshot_lines_purpose_fkey foreign key (
    pantry_need_purpose_id
  ) references atlas_planning.pantry_need_purposes (
    pantry_need_purpose_id
  ) on delete restrict,
  constraint pantry_need_approval_snapshot_lines_quantity_check check (
    requested_quantity > 0
  ),
  constraint pantry_need_approval_snapshot_lines_note_check check (
    note is null or btrim(note) <> ''
  ),
  constraint pantry_need_approval_snapshot_lines_source_request_check check (
    source_request_reference is null
    or btrim(source_request_reference) <> ''
  ),
  constraint pantry_need_approval_snapshot_lines_source_row_check check (
    source_row_reference is null
    or btrim(source_row_reference) <> ''
  ),
  constraint pantry_need_approval_snapshot_lines_snapshot_text_check check (
    btrim(school_code_snapshot) <> ''
    and btrim(school_name_snapshot) <> ''
    and btrim(delivery_location_code_snapshot) <> ''
    and btrim(delivery_location_name_snapshot) <> ''
    and btrim(delivery_location_address_snapshot) <> ''
    and btrim(ingredient_code_snapshot) <> ''
    and btrim(ingredient_name_snapshot) <> ''
    and btrim(unit_code_snapshot) <> ''
    and btrim(unit_name_snapshot) <> ''
    and btrim(purpose_code_snapshot) <> ''
    and btrim(purpose_name_snapshot) <> ''
    and btrim(purpose_description_snapshot) <> ''
  ),
  constraint pantry_need_approval_snapshot_lines_note_rule_check check (
    purpose_note_rule_snapshot in ('OPTIONAL', 'REQUIRED', 'PROHIBITED')
  )
);

create index pantry_snapshot_lines_working_line_idx
  on atlas_planning.pantry_need_approval_snapshot_lines (
    pantry_need_line_id
  );
create index pantry_snapshot_lines_school_idx
  on atlas_planning.pantry_need_approval_snapshot_lines (school_id);
create index pantry_snapshot_lines_location_idx
  on atlas_planning.pantry_need_approval_snapshot_lines (
    delivery_location_id
  );
create index pantry_snapshot_lines_ingredient_idx
  on atlas_planning.pantry_need_approval_snapshot_lines (ingredient_id);
create index pantry_snapshot_lines_unit_idx
  on atlas_planning.pantry_need_approval_snapshot_lines (unit_id);
create index pantry_snapshot_lines_purpose_idx
  on atlas_planning.pantry_need_approval_snapshot_lines (
    pantry_need_purpose_id
  );

alter table atlas_planning.pantry_need_purposes
  enable row level security;
alter table atlas_planning.pantry_need_purposes
  force row level security;
alter table atlas_planning.pantry_need_batches
  enable row level security;
alter table atlas_planning.pantry_need_batches
  force row level security;
alter table atlas_planning.pantry_need_lines
  enable row level security;
alter table atlas_planning.pantry_need_lines
  force row level security;
alter table atlas_planning.pantry_need_approval_snapshots
  enable row level security;
alter table atlas_planning.pantry_need_approval_snapshots
  force row level security;
alter table atlas_planning.pantry_need_approval_snapshot_lines
  enable row level security;
alter table atlas_planning.pantry_need_approval_snapshot_lines
  force row level security;

reset role;

insert into atlas_core.capabilities (
  capability_code,
  capability_name,
  owning_domain
) values (
  'planning.pantry.write',
  'Maintain Pantry source drafts',
  'PLANNING'
);

set role atlas_owner;

create function atlas_planning.pantry_02_purpose_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    if exists (
      select 1
      from atlas_planning.pantry_need_lines line
      where line.pantry_need_purpose_id = old.pantry_need_purpose_id
    ) or exists (
      select 1
      from atlas_planning.pantry_need_approval_snapshot_lines snapshot_line
      where snapshot_line.pantry_need_purpose_id =
        old.pantry_need_purpose_id
    ) then
      raise exception using
        errcode = '23503',
        message = 'referenced Pantry Purposes cannot be deleted';
    end if;
    return old;
  end if;

  if tg_op = 'UPDATE' then
    if new.pantry_need_purpose_id is distinct from old.pantry_need_purpose_id
      or new.created_at is distinct from old.created_at
    then
      raise exception using
        errcode = '23514',
        message = 'Pantry Purpose identity and creation evidence are immutable';
    end if;

    if new.purpose_code is distinct from old.purpose_code
      and (
        exists (
          select 1
          from atlas_planning.pantry_need_lines line
          where line.pantry_need_purpose_id = old.pantry_need_purpose_id
        )
        or exists (
          select 1
          from atlas_planning.pantry_need_approval_snapshot_lines snapshot_line
          where snapshot_line.pantry_need_purpose_id =
            old.pantry_need_purpose_id
        )
      )
    then
      raise exception using
        errcode = '23514',
        message = 'an operationally used Pantry Purpose code is immutable';
    end if;

    if new.version <> old.version + 1 then
      raise exception using
        errcode = '23514',
        message = 'Pantry Purpose updates must advance version exactly once';
    end if;
    if new.updated_at < old.updated_at then
      raise exception using
        errcode = '23514',
        message = 'Pantry Purpose updates cannot move updated_at backward';
    end if;
  end if;

  return new;
end
$$;

reset role;

create function atlas_core.pantry_02_record_change(
  event_name text,
  batch_id uuid,
  version_before bigint,
  version_after bigint,
  receipt_id uuid,
  request jsonb,
  actor_id uuid,
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
  domain_event_id uuid;
  audit_event_id uuid;
begin
  insert into atlas_audit.domain_events as inserted_event (
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
    event_name,
    'PLANNING',
    'PantryNeedBatch',
    batch_id,
    version_after,
    receipt_id,
    atlas_core.pa_05b_safe_uuid(request ->> 'command_id'),
    atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id'),
    actor_id,
    pg_catalog.transaction_timestamp(),
    after_summary
  )
  returning inserted_event.domain_event_id
    into domain_event_id;

  insert into atlas_audit.audit_events as inserted_audit (
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
    event_name,
    'PLANNING',
    'PantryNeedBatch',
    batch_id,
    version_before,
    version_after,
    receipt_id,
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
  returning inserted_audit.audit_event_id
    into audit_event_id;

  return pg_catalog.jsonb_build_object(
    'domain_event_id', domain_event_id,
    'audit_event_id', audit_event_id
  );
end
$$;

create function atlas_core.pantry_02_success(
  request jsonb,
  batch atlas_planning.pantry_need_batches,
  event_ids jsonb,
  audit_ids jsonb,
  operator_message text,
  workbench jsonb,
  idempotency_status text default 'COMPLETED'
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'PANTRY-02.v1',
    'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id',
    'idempotency_status', idempotency_status,
    'affected_aggregate_ids',
      pg_catalog.jsonb_build_object(
        'pantry_need_batch_id', batch.pantry_need_batch_id,
        'week_start', batch.week_start
      ),
    'new_versions',
      pg_catalog.jsonb_build_object(
        'pantry_need_batch_version', batch.version
      ),
    'emitted_event_ids', coalesce(event_ids, '[]'::jsonb),
    'audit_event_ids', coalesce(audit_ids, '[]'::jsonb),
    'safe_operator_message', operator_message,
    'warnings', '[]'::jsonb,
    'blockers', '[]'::jsonb,
    'workbench', workbench
  );
$$;

create function atlas_api.get_pantry_source_workbench(request jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_variable
declare
  read_name constant text := 'get_pantry_source_workbench';
  validation_error jsonb;
  actor_context jsonb;
  actor_id uuid;
  week_start date;
begin
  validation_error := atlas_core.pantry_02_validate_read_request(
    request,
    read_name,
    true
  );
  if validation_error is not null then
    return validation_error;
  end if;

  actor_context := atlas_core.pantry_02_authorize_global(
    request,
    'planning.inputs.read',
    read_name
  );
  if actor_context ? 'error' then
    return actor_context -> 'error';
  end if;

  actor_id := atlas_core.pa_05b_safe_uuid(actor_context ->> 'actor_id');
  week_start := atlas_core.pa_05d_safe_date(
    request -> 'payload' ->> 'week_start'
  );

  return pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'PANTRY-02.v1',
    'read_name', read_name,
    'correlation_id', request ->> 'correlation_id',
    'workbench',
      atlas_core.pantry_02_workbench_payload(week_start, actor_id)
  );
exception
  when others then
    return atlas_core.pantry_02_read_error(
      request,
      read_name,
      'INTERNAL_READ_FAILURE',
      'The Pantry workbench could not be loaded safely.'
    );
end
$$;

create function atlas_api.preview_pantry_source(request jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_variable
declare
  read_name constant text := 'preview_pantry_source';
  validation_error jsonb;
  actor_context jsonb;
  actor_id uuid;
  week_start date;
  no_additions boolean;
  rows jsonb;
  canonical_rows jsonb;
  issues jsonb;
  signature text;
  claimed_signature text;
  current_batch atlas_planning.pantry_need_batches%rowtype;
  comparison_status text;
  comparison jsonb;
begin
  validation_error := atlas_core.pantry_02_validate_read_request(
    request,
    read_name,
    true
  );
  if validation_error is not null then
    return validation_error;
  end if;
  if pg_catalog.jsonb_typeof(
    request -> 'payload' -> 'no_additions_confirmed'
  ) <> 'boolean' then
    return atlas_core.pantry_02_read_error(
      request,
      read_name,
      'VALIDATION_FAILED',
      'An explicit no-additions confirmation is required.',
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field', 'payload.no_additions_confirmed',
          'message', 'A Boolean value is required.'
        )
      )
    );
  end if;
  if pg_catalog.jsonb_typeof(request -> 'payload' -> 'rows') <> 'array' then
    return atlas_core.pantry_02_read_error(
      request,
      read_name,
      'VALIDATION_FAILED',
      'Pantry rows must be an array.',
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field', 'payload.rows',
          'message', 'An array is required.'
        )
      )
    );
  end if;

  actor_context := atlas_core.pantry_02_authorize_global(
    request,
    'planning.inputs.read',
    read_name
  );
  if actor_context ? 'error' then
    return actor_context -> 'error';
  end if;
  actor_id := atlas_core.pa_05b_safe_uuid(actor_context ->> 'actor_id');

  week_start := atlas_core.pa_05d_safe_date(
    request -> 'payload' ->> 'week_start'
  );
  no_additions := (request -> 'payload' ->> 'no_additions_confirmed')::boolean;
  rows := request -> 'payload' -> 'rows';
  canonical_rows := atlas_core.pantry_02_canonical_rows(week_start, rows);
  issues := atlas_core.pantry_02_issues(
    week_start,
    no_additions,
    canonical_rows
  );
  signature := atlas_core.pantry_02_signature(
    week_start,
    no_additions,
    canonical_rows
  );
  claimed_signature := atlas_core.pantry_02_normalize_text(
    request -> 'payload' ->> 'claimed_source_signature'
  );

  if claimed_signature is not null
    and claimed_signature is distinct from signature
  then
    issues := pg_catalog.jsonb_set(
      issues,
      '{blockers}',
      issues -> 'blockers' || pg_catalog.jsonb_build_array(
        atlas_core.pantry_02_issue(
          'SOURCE_SIGNATURE_MISMATCH',
          'The claimed Pantry signature does not match the canonical proposal.',
          null,
          'claimed_source_signature'
        )
      )
    );
  end if;

  select batch.*
    into current_batch
  from atlas_planning.pantry_need_batches batch
  where batch.week_start = week_start;

  comparison_status := case
    when current_batch.pantry_need_batch_id is null then 'NEW'
    when current_batch.source_signature = signature
      and current_batch.no_additions_confirmed = no_additions
      then 'NO_CHANGE'
    else 'REPLACEMENT'
  end;

  with proposed as (
    select item.value as proposed_row
    from pg_catalog.jsonb_array_elements(canonical_rows) item(value)
  ),
  existing as (
    select item.value as existing_row
    from pg_catalog.jsonb_array_elements(
      case
        when current_batch.pantry_need_batch_id is null then '[]'::jsonb
        else atlas_core.pantry_02_current_rows(
          current_batch.pantry_need_batch_id
        )
      end
    ) item(value)
  ),
  classified as (
    select
      proposed.proposed_row,
      existing.existing_row,
      case
        when existing.existing_row is null then 'NEW'
        when proposed.proposed_row is null then 'OMITTED'
        when pg_catalog.jsonb_build_object(
          'pantry_need_purpose_id',
            proposed.proposed_row -> 'pantry_need_purpose_id',
          'requested_quantity',
            proposed.proposed_row -> 'requested_quantity',
          'note', proposed.proposed_row -> 'note',
          'source_request_reference',
            proposed.proposed_row -> 'source_request_reference'
        ) = pg_catalog.jsonb_build_object(
          'pantry_need_purpose_id',
            existing.existing_row -> 'pantry_need_purpose_id',
          'requested_quantity',
            existing.existing_row -> 'requested_quantity',
          'note', existing.existing_row -> 'note',
          'source_request_reference',
            existing.existing_row -> 'source_request_reference'
        ) then 'UNCHANGED'
        else 'CHANGED'
      end as comparison_kind
    from proposed
    full join existing
      on proposed.proposed_row ->> 'service_date' =
          existing.existing_row ->> 'service_date'
     and proposed.proposed_row ->> 'school_id' =
          existing.existing_row ->> 'school_id'
     and proposed.proposed_row ->> 'delivery_location_id' =
          existing.existing_row ->> 'delivery_location_id'
     and proposed.proposed_row ->> 'ingredient_id' =
          existing.existing_row ->> 'ingredient_id'
  )
  select pg_catalog.jsonb_build_object(
    'new_lines',
      coalesce(
        (
          select pg_catalog.jsonb_agg(
            classified.proposed_row
            order by
              classified.proposed_row ->> 'service_date',
              classified.proposed_row ->> 'school_id',
              classified.proposed_row ->> 'ingredient_id'
          )
          from classified
          where classified.comparison_kind = 'NEW'
        ),
        '[]'::jsonb
      ),
    'changed_lines',
      coalesce(
        (
          select pg_catalog.jsonb_agg(
            pg_catalog.jsonb_build_object(
              'before', classified.existing_row,
              'after', classified.proposed_row
            )
            order by
              classified.proposed_row ->> 'service_date',
              classified.proposed_row ->> 'school_id',
              classified.proposed_row ->> 'ingredient_id'
          )
          from classified
          where classified.comparison_kind = 'CHANGED'
        ),
        '[]'::jsonb
      ),
    'unchanged_lines',
      coalesce(
        (
          select pg_catalog.jsonb_agg(
            pg_catalog.jsonb_build_object(
              'pantry_need_line_id',
                classified.existing_row -> 'pantry_need_line_id',
              'line', classified.proposed_row
            )
            order by
              classified.proposed_row ->> 'service_date',
              classified.proposed_row ->> 'school_id',
              classified.proposed_row ->> 'ingredient_id'
          )
          from classified
          where classified.comparison_kind = 'UNCHANGED'
        ),
        '[]'::jsonb
      ),
    'omitted_lines',
      coalesce(
        (
          select pg_catalog.jsonb_agg(
            classified.existing_row
            order by
              classified.existing_row ->> 'service_date',
              classified.existing_row ->> 'school_id',
              classified.existing_row ->> 'ingredient_id'
          )
          from classified
          where classified.comparison_kind = 'OMITTED'
        ),
        '[]'::jsonb
      ),
    'changed_school_dates',
      coalesce(
        (
          select pg_catalog.jsonb_agg(
            pg_catalog.jsonb_build_object(
              'school_id', changed_date.school_id,
              'service_date', changed_date.service_date
            )
            order by changed_date.service_date, changed_date.school_id
          )
          from (
            select distinct
              coalesce(
                classified.proposed_row ->> 'school_id',
                classified.existing_row ->> 'school_id'
              ) as school_id,
              coalesce(
                classified.proposed_row ->> 'service_date',
                classified.existing_row ->> 'service_date'
              ) as service_date
            from classified
            where classified.comparison_kind <> 'UNCHANGED'
              and coalesce(
                classified.proposed_row ->> 'school_id',
                classified.existing_row ->> 'school_id'
              ) is not null
              and coalesce(
                classified.proposed_row ->> 'service_date',
                classified.existing_row ->> 'service_date'
              ) is not null
          ) changed_date
        ),
        '[]'::jsonb
      )
    )
    into comparison;

  return pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'PANTRY-02.v1',
    'read_name', read_name,
    'correlation_id', request ->> 'correlation_id',
    'preview', pg_catalog.jsonb_build_object(
      'week_start', week_start,
      'week_end', week_start + 6,
      'source_type', 'MANUAL_ATLAS',
      'source_name', 'Nhập thủ công Atlas',
      'source_signature', signature,
      'no_additions_confirmed', no_additions,
      'canonical_rows', canonical_rows,
      'issues', issues,
      'comparison',
        pg_catalog.jsonb_build_object(
          'status', comparison_status,
          'current_batch_id', current_batch.pantry_need_batch_id,
          'current_version', current_batch.version,
          'current_status', current_batch.pantry_need_batch_status,
          'current_source_signature', current_batch.source_signature
        ) || comparison,
      'can_save',
        pg_catalog.jsonb_array_length(issues -> 'blockers') = 0
        and atlas_core.pantry_02_actor_has_capability(
          actor_id,
          'planning.pantry.write'
        )
        and (
          current_batch.pantry_need_batch_id is null
          or current_batch.pantry_need_batch_status in ('DRAFT', 'REOPENED')
        )
    )
  );
exception
  when others then
    return atlas_core.pantry_02_read_error(
      request,
      read_name,
      'INTERNAL_READ_FAILURE',
      'The Pantry proposal could not be previewed safely.'
    );
end
$$;

create function atlas_core.pantry_02_read_error(
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
    'contract_version', 'PANTRY-02.v1',
    'error_code', error_code,
    'safe_message', safe_message,
    'domain', 'PLANNING',
    'read_name', read_name,
    'field_errors', coalesce(field_errors, '[]'::jsonb),
    'correlation_id', request ->> 'correlation_id'
  );
$$;

create function atlas_core.pantry_02_validate_read_request(
  request jsonb,
  read_name text,
  require_valid_week boolean
)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  errors jsonb := '[]'::jsonb;
  week_start date;
begin
  if request is null or pg_catalog.jsonb_typeof(request) <> 'object' then
    return atlas_core.pantry_02_read_error(
      coalesce(request, '{}'::jsonb),
      read_name,
      'VALIDATION_FAILED',
      'The Pantry read request must be a JSON object.'
    );
  end if;
  if request ->> 'contract_version' is distinct from 'PANTRY-02.v1' then
    errors := errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'contract_version',
        'message', 'Use PANTRY-02.v1.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(
    request ->> 'requested_by_auth_subject'
  ) is null then
    errors := errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'requested_by_auth_subject',
        'message', 'A valid UUID is required.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id') is null then
    errors := errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'correlation_id',
        'message', 'A valid UUID is required.'
      )
    );
  end if;
  if request -> 'payload' is null
    or pg_catalog.jsonb_typeof(request -> 'payload') <> 'object'
  then
    errors := errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'payload',
        'message', 'A JSON object is required.'
      )
    );
  elsif not (request -> 'payload' ? 'week_start') then
    errors := errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'payload.week_start',
        'message', 'An explicit Pantry week is required.'
      )
    );
  elsif require_valid_week then
    week_start := atlas_core.pa_05d_safe_date(
      request -> 'payload' ->> 'week_start'
    );
    if week_start is null or extract(isodow from week_start) <> 1 then
      errors := errors || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field', 'payload.week_start',
          'message', 'A valid Monday ISO date is required.'
        )
      );
    end if;
  end if;

  if pg_catalog.jsonb_array_length(errors) > 0 then
    return atlas_core.pantry_02_read_error(
      request,
      read_name,
      'VALIDATION_FAILED',
      'The Pantry read envelope is invalid.',
      errors
    );
  end if;
  return null;
end
$$;

create function atlas_core.pantry_02_validate_command_request(
  request jsonb,
  command_name text
)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  errors jsonb := '[]'::jsonb;
  requested_at timestamptz;
begin
  if request is null or pg_catalog.jsonb_typeof(request) <> 'object' then
    return atlas_core.pa_05b_command_error(
      coalesce(request, '{}'::jsonb),
      'VALIDATION_FAILED',
      'The Pantry command request must be a JSON object.',
      'PLANNING',
      command_name
    );
  end if;
  if request ->> 'contract_version' is distinct from 'PANTRY-02.v1' then
    errors := errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'contract_version',
        'message', 'Use PANTRY-02.v1.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'command_id') is null then
    errors := errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'command_id',
        'message', 'A valid UUID is required.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id') is null then
    errors := errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'correlation_id',
        'message', 'A valid UUID is required.'
      )
    );
  end if;
  if pg_catalog.btrim(coalesce(request ->> 'idempotency_key', '')) = ''
    or pg_catalog.length(request ->> 'idempotency_key') > 200
  then
    errors := errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'idempotency_key',
        'message', 'A non-empty key of at most 200 characters is required.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') is null
    or atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') <= 0
  then
    errors := errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'expected_version',
        'message', 'A positive expected version is required.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(
    request ->> 'requested_by_auth_subject'
  ) is null then
    errors := errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'requested_by_auth_subject',
        'message', 'A valid UUID is required.'
      )
    );
  end if;
  requested_at := atlas_core.pa_05b_safe_timestamptz(
    request ->> 'requested_at'
  );
  if requested_at is null
    or requested_at > pg_catalog.transaction_timestamp()
  then
    errors := errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'requested_at',
        'message', 'A valid non-future timestamp is required.'
      )
    );
  end if;
  if pg_catalog.btrim(coalesce(request ->> 'reason_code', '')) = '' then
    errors := errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'reason_code',
        'message', 'A reason code is required.'
      )
    );
  end if;
  if not (request ? 'reason_note') then
    errors := errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'reason_note',
        'message', 'reason_note is required and may be null.'
      )
    );
  end if;
  if request -> 'payload' is null
    or pg_catalog.jsonb_typeof(request -> 'payload') <> 'object'
  then
    errors := errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'payload',
        'message', 'A JSON object is required.'
      )
    );
  elsif atlas_core.pa_05d_safe_date(
    request -> 'payload' ->> 'week_start'
  ) is null then
    errors := errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'payload.week_start',
        'message', 'A valid ISO Pantry week is required.'
      )
    );
  end if;

  if pg_catalog.jsonb_array_length(errors) > 0 then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'The Pantry command envelope is invalid.',
      'PLANNING',
      command_name,
      false,
      errors
    );
  end if;
  return null;
end
$$;

create function atlas_core.pantry_02_authorize_global(
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
  actor_context jsonb;
  actor_id uuid;
  auth_error jsonb;
begin
  actor_context := atlas_core.pa_05b_resolve_actor(
    request,
    'PLANNING',
    operation_name
  );
  if actor_context ? 'error' then
    return actor_context;
  end if;
  actor_id := atlas_core.pa_05b_safe_uuid(actor_context ->> 'actor_id');
  auth_error := atlas_core.pa_05b_authorize_actor(
    request,
    actor_id,
    capability_code,
    'PLANNING',
    operation_name,
    null,
    null,
    null
  );
  if auth_error is not null then
    return pg_catalog.jsonb_build_object('error', auth_error);
  end if;
  return pg_catalog.jsonb_build_object('actor_id', actor_id);
end
$$;

create function atlas_core.pantry_02_actor_has_capability(
  target_actor_id uuid,
  target_capability_code text
)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select exists (
    select 1
    from atlas_core.actor_role_memberships membership
    join atlas_core.roles role
      on role.role_id = membership.role_id
    join atlas_core.role_capabilities role_capability
      on role_capability.role_id = role.role_id
    join atlas_core.capabilities capability
      on capability.capability_id = role_capability.capability_id
    where membership.actor_id = target_actor_id
      and membership.membership_status = 'ACTIVE'
      and membership.effective_from <= pg_catalog.transaction_timestamp()
      and (
        membership.effective_to is null
        or membership.effective_to > pg_catalog.transaction_timestamp()
      )
      and role.role_status = 'ACTIVE'
      and capability.capability_status = 'ACTIVE'
      and capability.capability_code = target_capability_code
  ) and exists (
    select 1
    from atlas_core.actor_scopes scope
    where scope.actor_id = target_actor_id
      and scope.scope_kind = 'GLOBAL'
      and scope.scope_status = 'ACTIVE'
      and scope.effective_from <= pg_catalog.transaction_timestamp()
      and (
        scope.effective_to is null
        or scope.effective_to > pg_catalog.transaction_timestamp()
      )
  );
$$;

create function atlas_core.pantry_02_prepare_command(
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
  validation_error jsonb;
  actor_context jsonb;
  actor_id uuid;
  begin_result jsonb;
begin
  validation_error := atlas_core.pantry_02_validate_command_request(
    request,
    command_name
  );
  if validation_error is not null then
    return pg_catalog.jsonb_build_object(
      'status', 'RETURN',
      'response', validation_error
    );
  end if;

  actor_context := atlas_core.pantry_02_authorize_global(
    request,
    capability_code,
    command_name
  );
  if actor_context ? 'error' then
    return pg_catalog.jsonb_build_object(
      'status', 'RETURN',
      'response', actor_context -> 'error'
    );
  end if;
  actor_id := atlas_core.pa_05b_safe_uuid(actor_context ->> 'actor_id');
  begin_result := atlas_core.pa_05b_begin_command(
    request,
    actor_id,
    command_name,
    'PLANNING',
    aggregate_scope
  );
  if begin_result ->> 'status' in ('REPLAY', 'ERROR') then
    return pg_catalog.jsonb_build_object(
      'status', 'RETURN',
      'response', begin_result -> 'response'
    );
  end if;
  return pg_catalog.jsonb_build_object(
    'status', 'READY',
    'actor_id', actor_id,
    'receipt_id', begin_result ->> 'receipt_id'
  );
end
$$;

create function atlas_core.pantry_02_workbench_payload(
  target_week_start date,
  target_actor_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  batch atlas_planning.pantry_need_batches%rowtype;
  current_rows jsonb := '[]'::jsonb;
  current_issues jsonb := pg_catalog.jsonb_build_object(
    'blockers', '[]'::jsonb,
    'warnings', '[]'::jsonb
  );
  catalog_blockers jsonb := '[]'::jsonb;
  can_write boolean := atlas_core.pantry_02_actor_has_capability(
    target_actor_id,
    'planning.pantry.write'
  );
  can_approve boolean := atlas_core.pantry_02_actor_has_capability(
    target_actor_id,
    'planning.inputs.approve'
  );
begin
  select source_batch.*
    into batch
  from atlas_planning.pantry_need_batches source_batch
  where source_batch.week_start = target_week_start;

  if batch.pantry_need_batch_id is not null then
    current_rows := atlas_core.pantry_02_current_rows(
      batch.pantry_need_batch_id
    );
    current_issues := atlas_core.pantry_02_issues(
      target_week_start,
      batch.no_additions_confirmed,
      current_rows
    );
  end if;

  if not exists (
    select 1
    from atlas_planning.pantry_need_purposes purpose
    where purpose.purpose_status = 'ACTIVE'
  ) then
    catalog_blockers := pg_catalog.jsonb_build_array(
      atlas_core.pantry_02_issue(
        'PURPOSE_CATALOG_EMPTY',
        'No active Pantry Purpose is configured.',
        null,
        'pantry_need_purpose_id'
      )
    );
  end if;

  return pg_catalog.jsonb_build_object(
    'week_start', target_week_start,
    'week_end', target_week_start + 6,
    'source_method', pg_catalog.jsonb_build_object(
      'source_type', 'MANUAL_ATLAS',
      'source_name', 'Nhập thủ công Atlas'
    ),
    'purposes',
      coalesce(
        (
          select pg_catalog.jsonb_agg(
            pg_catalog.jsonb_build_object(
              'pantry_need_purpose_id', purpose.pantry_need_purpose_id,
              'purpose_code', purpose.purpose_code,
              'purpose_name_vi', purpose.purpose_name_vi,
              'purpose_description', purpose.purpose_description,
              'note_rule', purpose.note_rule,
              'purpose_status', purpose.purpose_status,
              'display_order', purpose.display_order,
              'version', purpose.version
            )
            order by
              purpose.display_order,
              purpose.purpose_code,
              purpose.pantry_need_purpose_id
          )
          from atlas_planning.pantry_need_purposes purpose
          where purpose.purpose_status = 'ACTIVE'
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
              'customer_id', school.customer_id,
              'customer_name', customer.customer_name,
              'default_delivery_location',
                pg_catalog.jsonb_build_object(
                  'delivery_location_id',
                    location.delivery_location_id,
                  'location_code', location.location_code,
                  'location_name', location.location_name,
                  'address_text', location.address_text,
                  'timezone_name', location.timezone_name
                )
            )
            order by
              school.display_order,
              school.school_code,
              school.school_id
          )
          from atlas_admin.schools school
          join atlas_admin.customers customer
            on customer.customer_id = school.customer_id
           and customer.customer_type = 'SCHOOL_CATERING'
           and customer.customer_status = 'ACTIVE'
          join atlas_admin.delivery_locations location
            on location.delivery_location_id =
              school.default_delivery_location_id
           and location.customer_id = school.customer_id
           and location.location_status = 'ACTIVE'
          where school.school_status = 'ACTIVE'
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
              'ingredient_status', ingredient.ingredient_status,
              'purchase_unit',
                pg_catalog.jsonb_build_object(
                  'unit_id', unit.unit_id,
                  'unit_code', unit.unit_code,
                  'unit_name', unit.unit_name
                )
            )
            order by
              ingredient.ingredient_name,
              ingredient.ingredient_code,
              ingredient.ingredient_id
          )
          from atlas_admin.ingredients ingredient
          join atlas_admin.units unit
            on unit.unit_id = ingredient.purchase_unit_id
           and unit.unit_status = 'ACTIVE'
          where ingredient.ingredient_status = 'ACTIVE'
        ),
        '[]'::jsonb
      ),
    'catalog_issues', pg_catalog.jsonb_build_object(
      'blockers', catalog_blockers,
      'warnings', '[]'::jsonb
    ),
    'batch',
      case
        when batch.pantry_need_batch_id is null then null
        else pg_catalog.jsonb_build_object(
          'pantry_need_batch_id', batch.pantry_need_batch_id,
          'week_start', batch.week_start,
          'week_end', batch.week_end,
          'pantry_need_batch_status', batch.pantry_need_batch_status,
          'version', batch.version,
          'source_type', batch.source_type,
          'source_name', batch.source_name,
          'source_signature', batch.source_signature,
          'no_additions_confirmed',
            batch.no_additions_confirmed,
          'requesting_actor_id', batch.requesting_actor_id,
          'requesting_actor_name',
            (
              select requesting_actor.display_name
              from atlas_core.actors requesting_actor
              where requesting_actor.actor_id = batch.requesting_actor_id
            ),
          'creation_method', batch.creation_method,
          'latest_approved_by_actor_id',
            batch.latest_approved_by_actor_id,
          'latest_approved_at', batch.latest_approved_at,
          'latest_approval_snapshot_id',
            batch.latest_approval_snapshot_id,
          'created_at', batch.created_at,
          'updated_at', batch.updated_at,
          'active_lines',
            coalesce(
              (
                select pg_catalog.jsonb_agg(
                  pg_catalog.jsonb_build_object(
                    'pantry_need_line_id', line.pantry_need_line_id,
                    'service_date', line.service_date,
                    'school_id', line.school_id,
                    'school_code', school.school_code,
                    'school_name', school.school_name,
                    'delivery_location_id',
                      line.delivery_location_id,
                    'delivery_location_code',
                      location.location_code,
                    'delivery_location_name',
                      location.location_name,
                    'ingredient_id', line.ingredient_id,
                    'ingredient_code', ingredient.ingredient_code,
                    'ingredient_name', ingredient.ingredient_name,
                    'unit_id', line.unit_id,
                    'unit_code', unit.unit_code,
                    'unit_name', unit.unit_name,
                    'pantry_need_purpose_id',
                      line.pantry_need_purpose_id,
                    'purpose_code', purpose.purpose_code,
                    'purpose_name_vi', purpose.purpose_name_vi,
                    'purpose_description',
                      purpose.purpose_description,
                    'purpose_note_rule', purpose.note_rule,
                    'requested_quantity', line.requested_quantity,
                    'note', line.note,
                    'source_request_reference',
                      line.source_request_reference,
                    'source_row_reference',
                      line.source_row_reference,
                    'line_status', line.line_status,
                    'updated_by_actor_id',
                      line.updated_by_actor_id,
                    'updated_at', line.updated_at
                  )
                  order by
                    line.service_date,
                    school.display_order,
                    ingredient.ingredient_name,
                    line.pantry_need_line_id
                )
                from atlas_planning.pantry_need_lines line
                left join atlas_admin.schools school
                  on school.school_id = line.school_id
                left join atlas_admin.delivery_locations location
                  on location.delivery_location_id =
                    line.delivery_location_id
                left join atlas_admin.ingredients ingredient
                  on ingredient.ingredient_id = line.ingredient_id
                left join atlas_admin.units unit
                  on unit.unit_id = line.unit_id
                left join atlas_planning.pantry_need_purposes purpose
                  on purpose.pantry_need_purpose_id =
                    line.pantry_need_purpose_id
                where line.pantry_need_batch_id =
                  batch.pantry_need_batch_id
                  and line.line_status = 'ACTIVE'
              ),
              '[]'::jsonb
            ),
          'invalid_lines',
            coalesce(
              (
                select pg_catalog.jsonb_agg(
                  pg_catalog.jsonb_build_object(
                    'pantry_need_line_id', line.pantry_need_line_id,
                    'service_date', line.service_date,
                    'school_id', line.school_id,
                    'school_code', school.school_code,
                    'school_name', school.school_name,
                    'delivery_location_id',
                      line.delivery_location_id,
                    'delivery_location_name',
                      location.location_name,
                    'ingredient_id', line.ingredient_id,
                    'ingredient_code', ingredient.ingredient_code,
                    'ingredient_name', ingredient.ingredient_name,
                    'unit_id', line.unit_id,
                    'unit_code', unit.unit_code,
                    'unit_name', unit.unit_name,
                    'pantry_need_purpose_id',
                      line.pantry_need_purpose_id,
                    'purpose_code', purpose.purpose_code,
                    'purpose_name_vi', purpose.purpose_name_vi,
                    'requested_quantity', line.requested_quantity,
                    'note', line.note,
                    'source_request_reference',
                      line.source_request_reference,
                    'source_row_reference',
                      line.source_row_reference,
                    'line_status', line.line_status,
                    'updated_at', line.updated_at
                  )
                  order by
                    line.service_date,
                    school.display_order,
                    ingredient.ingredient_name,
                    line.pantry_need_line_id
                )
                from atlas_planning.pantry_need_lines line
                left join atlas_admin.schools school
                  on school.school_id = line.school_id
                left join atlas_admin.delivery_locations location
                  on location.delivery_location_id =
                    line.delivery_location_id
                left join atlas_admin.ingredients ingredient
                  on ingredient.ingredient_id = line.ingredient_id
                left join atlas_admin.units unit
                  on unit.unit_id = line.unit_id
                left join atlas_planning.pantry_need_purposes purpose
                  on purpose.pantry_need_purpose_id =
                    line.pantry_need_purpose_id
                where line.pantry_need_batch_id =
                  batch.pantry_need_batch_id
                  and line.line_status = 'INVALID'
              ),
              '[]'::jsonb
            ),
          'issues', current_issues,
          'approval_history',
            coalesce(
              (
                select pg_catalog.jsonb_agg(
                  pg_catalog.jsonb_build_object(
                    'pantry_need_approval_snapshot_id',
                      snapshot.pantry_need_approval_snapshot_id,
                    'approved_batch_version',
                      snapshot.approved_batch_version,
                    'approved_by_actor_id',
                      snapshot.approved_by_actor_id,
                    'approved_by_display_name',
                      approver.display_name,
                    'approved_at', snapshot.approved_at,
                    'source_signature',
                      snapshot.source_signature,
                    'no_additions_confirmed',
                      snapshot.no_additions_confirmed,
                    'line_count', snapshot.line_count,
                    'blocker_summary',
                      snapshot.blocker_summary,
                    'warning_summary',
                      snapshot.warning_summary,
                    'lines',
                      coalesce(
                        (
                          select pg_catalog.jsonb_agg(
                            pg_catalog.to_jsonb(snapshot_line)
                            order by
                              snapshot_line.service_date,
                              snapshot_line.school_code_snapshot,
                              snapshot_line.ingredient_code_snapshot,
                              snapshot_line.pantry_need_line_id
                          )
                          from atlas_planning
                            .pantry_need_approval_snapshot_lines
                              snapshot_line
                          where
                            snapshot_line
                              .pantry_need_approval_snapshot_id =
                            snapshot.pantry_need_approval_snapshot_id
                        ),
                        '[]'::jsonb
                      )
                  )
                  order by
                    snapshot.approved_batch_version desc,
                    snapshot.pantry_need_approval_snapshot_id
                )
                from atlas_planning.pantry_need_approval_snapshots
                  snapshot
                join atlas_core.actors approver
                  on approver.actor_id =
                    snapshot.approved_by_actor_id
                where snapshot.pantry_need_batch_id =
                  batch.pantry_need_batch_id
              ),
              '[]'::jsonb
            ),
          'change_history',
            coalesce(
              (
                select pg_catalog.jsonb_agg(
                  pg_catalog.jsonb_build_object(
                    'audit_event_id', audit.audit_event_id,
                    'event_type', audit.event_type,
                    'version_before',
                      audit.aggregate_version_before,
                    'version_after',
                      audit.aggregate_version_after,
                    'actor_id', audit.actor_id,
                    'actor_display_name', audit_actor.display_name,
                    'reason_code', audit.reason_code,
                    'reason_note', audit.reason_note,
                    'occurred_at', audit.occurred_at
                  )
                  order by audit.occurred_at desc, audit.audit_event_id
                )
                from atlas_audit.audit_events audit
                join atlas_core.actors audit_actor
                  on audit_actor.actor_id = audit.actor_id
                where audit.aggregate_type = 'PantryNeedBatch'
                  and audit.aggregate_id =
                    batch.pantry_need_batch_id
              ),
              '[]'::jsonb
            )
        )
      end,
    'allowed_actions', pg_catalog.jsonb_build_object(
      'can_preview', true,
      'can_save',
        can_write and (
          batch.pantry_need_batch_id is null
          or batch.pantry_need_batch_status in ('DRAFT', 'REOPENED')
        ),
      'can_validate',
        can_write
        and batch.pantry_need_batch_status in ('DRAFT', 'REOPENED'),
      'can_approve',
        can_approve
        and batch.pantry_need_batch_status = 'VALIDATED',
      'can_reopen',
        can_approve
        and batch.pantry_need_batch_status = 'APPROVED'
    )
  );
end
$$;

create function atlas_planning.pantry_02_batch_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  prior_snapshot_version bigint;
begin
  if tg_op = 'INSERT' then
    if new.pantry_need_batch_status <> 'DRAFT' or new.version <> 1 then
      raise exception using
        errcode = '23514',
        message = 'new Pantry batches must enter as DRAFT version 1';
    end if;
    return new;
  end if;

  if tg_op = 'DELETE' then
    raise exception using
      errcode = '23514',
      message = 'Pantry batches cannot be physically deleted';
  end if;

  if new.pantry_need_batch_id is distinct from old.pantry_need_batch_id
    or new.week_start is distinct from old.week_start
    or new.source_type is distinct from old.source_type
    or new.source_name is distinct from old.source_name
    or new.requesting_actor_id is distinct from old.requesting_actor_id
    or new.creation_method is distinct from old.creation_method
    or new.created_at is distinct from old.created_at
  then
    raise exception using
      errcode = '23514',
      message = 'Pantry batch identity and server-owned source evidence are immutable: '
        || pg_catalog.concat_ws(
          ',',
          case when new.pantry_need_batch_id is distinct from
            old.pantry_need_batch_id then 'pantry_need_batch_id' end,
          case when new.week_start is distinct from old.week_start
            then 'week_start' end,
          case when new.source_type is distinct from old.source_type
            then 'source_type' end,
          case when new.source_name is distinct from old.source_name
            then 'source_name' end,
          case when new.requesting_actor_id is distinct from
            old.requesting_actor_id then 'requesting_actor_id' end,
          case when new.creation_method is distinct from old.creation_method
            then 'creation_method' end,
          case when new.created_at is distinct from old.created_at
            then 'created_at' end
        );
  end if;

  if new.version <> old.version + 1 then
    raise exception using
      errcode = '23514',
      message = 'a material Pantry batch change must advance version exactly once';
  end if;
  if new.updated_at < old.updated_at then
    raise exception using
      errcode = '23514',
      message = 'a material Pantry batch change cannot move updated_at backward';
  end if;

  if old.latest_approval_snapshot_id is not null
    and new.pantry_need_batch_status <> 'APPROVED'
    and (
      new.latest_approval_snapshot_id is distinct from
        old.latest_approval_snapshot_id
      or new.latest_approved_by_actor_id is distinct from
        old.latest_approved_by_actor_id
      or new.latest_approved_at is distinct from old.latest_approved_at
    )
  then
    raise exception using
      errcode = '23514',
      message = 'prior Pantry approval evidence is preserved outside approval';
  end if;

  if new.pantry_need_batch_status = old.pantry_need_batch_status then
    if old.pantry_need_batch_status not in ('DRAFT', 'REOPENED') then
      raise exception using
        errcode = '23514',
        message = 'validated and approved Pantry batches cannot be edited';
    end if;
    if new.latest_approval_snapshot_id is distinct from
        old.latest_approval_snapshot_id
      or new.latest_approved_by_actor_id is distinct from
        old.latest_approved_by_actor_id
      or new.latest_approved_at is distinct from old.latest_approved_at
    then
      raise exception using
        errcode = '23514',
        message = 'Pantry approval evidence changes only during approval';
    end if;
    return new;
  end if;

  if not (
    (
      old.pantry_need_batch_status in ('DRAFT', 'REOPENED')
      and new.pantry_need_batch_status = 'VALIDATED'
    )
    or (
      old.pantry_need_batch_status = 'VALIDATED'
      and new.pantry_need_batch_status = 'APPROVED'
    )
    or (
      old.pantry_need_batch_status = 'APPROVED'
      and new.pantry_need_batch_status = 'REOPENED'
    )
  ) then
    raise exception using
      errcode = '23514',
      message = 'Pantry lifecycle transition is invalid';
  end if;

  if new.pantry_need_batch_status <> 'APPROVED'
    and (
      new.latest_approval_snapshot_id is distinct from
        old.latest_approval_snapshot_id
      or new.latest_approved_by_actor_id is distinct from
        old.latest_approved_by_actor_id
      or new.latest_approved_at is distinct from old.latest_approved_at
    )
  then
    raise exception using
      errcode = '23514',
      message = 'Pantry approval evidence changes only during approval';
  end if;

  if new.pantry_need_batch_status = 'APPROVED'
    and old.latest_approval_snapshot_id is not null
  then
    select snapshot.approved_batch_version
      into prior_snapshot_version
    from atlas_planning.pantry_need_approval_snapshots snapshot
    where snapshot.pantry_need_approval_snapshot_id =
      old.latest_approval_snapshot_id;

    if new.latest_approval_snapshot_id is not distinct from
        old.latest_approval_snapshot_id
      or new.version <= prior_snapshot_version
    then
      raise exception using
        errcode = '23514',
        message = 'later Pantry approval requires a new later-version snapshot';
    end if;
  end if;

  return new;
end
$$;

create function atlas_planning.pantry_02_line_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  target_batch atlas_planning.pantry_need_batches%rowtype;
begin
  if tg_op = 'DELETE' then
    raise exception using
      errcode = '23514',
      message = 'stable Pantry lines cannot be physically deleted';
  end if;

  if tg_op = 'UPDATE' and (
    new.pantry_need_line_id is distinct from old.pantry_need_line_id
    or new.pantry_need_batch_id is distinct from old.pantry_need_batch_id
    or new.service_date is distinct from old.service_date
    or new.school_id is distinct from old.school_id
    or new.delivery_location_id is distinct from old.delivery_location_id
    or new.ingredient_id is distinct from old.ingredient_id
    or new.created_at is distinct from old.created_at
  ) then
    raise exception using
      errcode = '23514',
      message = 'stable Pantry line grain and creation evidence are immutable';
  end if;

  select batch.*
    into target_batch
  from atlas_planning.pantry_need_batches batch
  where batch.pantry_need_batch_id = new.pantry_need_batch_id;

  if not found then
    return new;
  end if;
  if target_batch.pantry_need_batch_status not in ('DRAFT', 'REOPENED') then
    raise exception using
      errcode = '23514',
      message = 'Pantry lines are mutable only in DRAFT or REOPENED batches';
  end if;
  if new.service_date < target_batch.week_start
    or new.service_date > target_batch.week_end
  then
    raise exception using
      errcode = '23514',
      message = 'Pantry line service date must be inside the batch week';
  end if;

  return new;
end
$$;

create function atlas_planning.pantry_02_snapshot_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  target_batch atlas_planning.pantry_need_batches%rowtype;
  target_snapshot atlas_planning.pantry_need_approval_snapshots%rowtype;
  target_line atlas_planning.pantry_need_lines%rowtype;
  school_row atlas_admin.schools%rowtype;
  location_row atlas_admin.delivery_locations%rowtype;
  ingredient_row atlas_admin.ingredients%rowtype;
  unit_row atlas_admin.units%rowtype;
  purpose_row atlas_planning.pantry_need_purposes%rowtype;
begin
  if tg_op in ('UPDATE', 'DELETE') then
    raise exception using
      errcode = '23514',
      message = 'Pantry approval snapshots and snapshot lines are immutable';
  end if;

  if tg_table_name = 'pantry_need_approval_snapshots' then
    select batch.*
      into target_batch
    from atlas_planning.pantry_need_batches batch
    where batch.pantry_need_batch_id = new.pantry_need_batch_id;

    if not found
      or target_batch.pantry_need_batch_status <> 'VALIDATED'
      or new.approved_batch_version <> target_batch.version + 1
      or new.source_signature is distinct from target_batch.source_signature
      or new.no_additions_confirmed is distinct from
        target_batch.no_additions_confirmed
    then
      raise exception using
        errcode = '23514',
        message = 'Pantry approval requires the exact current validated working facts';
    end if;
    return new;
  end if;

  select snapshot.*
    into target_snapshot
  from atlas_planning.pantry_need_approval_snapshots snapshot
  where snapshot.pantry_need_approval_snapshot_id =
    new.pantry_need_approval_snapshot_id;

  select line.*
    into target_line
  from atlas_planning.pantry_need_lines line
  where line.pantry_need_line_id = new.pantry_need_line_id;

  select school.* into school_row
  from atlas_admin.schools school
  where school.school_id = new.school_id;
  select location.* into location_row
  from atlas_admin.delivery_locations location
  where location.delivery_location_id = new.delivery_location_id;
  select ingredient.* into ingredient_row
  from atlas_admin.ingredients ingredient
  where ingredient.ingredient_id = new.ingredient_id;
  select unit.* into unit_row
  from atlas_admin.units unit
  where unit.unit_id = new.unit_id;
  select purpose.* into purpose_row
  from atlas_planning.pantry_need_purposes purpose
  where purpose.pantry_need_purpose_id = new.pantry_need_purpose_id;

  if target_snapshot.pantry_need_approval_snapshot_id is null
    or target_line.pantry_need_line_id is null
    or target_line.line_status <> 'ACTIVE'
    or target_line.pantry_need_batch_id is distinct from
      target_snapshot.pantry_need_batch_id
    or new.service_date is distinct from target_line.service_date
    or new.school_id is distinct from target_line.school_id
    or new.delivery_location_id is distinct from
      target_line.delivery_location_id
    or new.ingredient_id is distinct from target_line.ingredient_id
    or new.unit_id is distinct from target_line.unit_id
    or new.pantry_need_purpose_id is distinct from
      target_line.pantry_need_purpose_id
    or new.requested_quantity is distinct from
      target_line.requested_quantity
    or new.note is distinct from target_line.note
    or new.source_request_reference is distinct from
      target_line.source_request_reference
    or new.source_row_reference is distinct from
      target_line.source_row_reference
    or new.school_code_snapshot is distinct from school_row.school_code
    or new.school_name_snapshot is distinct from school_row.school_name
    or new.delivery_location_code_snapshot is distinct from
      location_row.location_code
    or new.delivery_location_name_snapshot is distinct from
      location_row.location_name
    or new.delivery_location_address_snapshot is distinct from
      location_row.address_text
    or new.ingredient_code_snapshot is distinct from
      ingredient_row.ingredient_code
    or new.ingredient_name_snapshot is distinct from
      ingredient_row.ingredient_name
    or new.unit_code_snapshot is distinct from unit_row.unit_code
    or new.unit_name_snapshot is distinct from unit_row.unit_name
    or new.purpose_code_snapshot is distinct from purpose_row.purpose_code
    or new.purpose_name_snapshot is distinct from
      purpose_row.purpose_name_vi
    or new.purpose_description_snapshot is distinct from
      purpose_row.purpose_description
    or new.purpose_note_rule_snapshot is distinct from purpose_row.note_rule
  then
    raise exception using
      errcode = '23514',
      message = 'Pantry snapshot lines must exactly copy active working and display facts';
  end if;

  return new;
end
$$;

create function atlas_planning.pantry_02_snapshot_integrity_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_batch atlas_planning.pantry_need_batches%rowtype;
  target_snapshot atlas_planning.pantry_need_approval_snapshots%rowtype;
  target_snapshot_id uuid;
begin
  if tg_table_name = 'pantry_need_batches' then
    if new.pantry_need_batch_status <> 'APPROVED' then
      return null;
    end if;
    target_batch := new;
    target_snapshot_id := new.latest_approval_snapshot_id;
  elsif tg_table_name = 'pantry_need_approval_snapshots' then
    select batch.* into target_batch
    from atlas_planning.pantry_need_batches batch
    where batch.pantry_need_batch_id = new.pantry_need_batch_id;
    target_snapshot_id := new.pantry_need_approval_snapshot_id;
  else
    select snapshot.* into target_snapshot
    from atlas_planning.pantry_need_approval_snapshots snapshot
    where snapshot.pantry_need_approval_snapshot_id =
      new.pantry_need_approval_snapshot_id;
    select batch.* into target_batch
    from atlas_planning.pantry_need_batches batch
    where batch.pantry_need_batch_id = target_snapshot.pantry_need_batch_id;
    target_snapshot_id := new.pantry_need_approval_snapshot_id;
  end if;

  if target_batch.pantry_need_batch_status <> 'APPROVED'
    or target_batch.latest_approval_snapshot_id is distinct from
      target_snapshot_id
  then
    raise exception using
      errcode = '23514',
      message = 'Pantry approval snapshot must be bound to the approved batch';
  end if;

  select snapshot.* into target_snapshot
  from atlas_planning.pantry_need_approval_snapshots snapshot
  where snapshot.pantry_need_approval_snapshot_id = target_snapshot_id;

  if not found
    or target_snapshot.pantry_need_batch_id is distinct from
      target_batch.pantry_need_batch_id
    or target_snapshot.approved_batch_version is distinct from
      target_batch.version
    or target_snapshot.approved_by_actor_id is distinct from
      target_batch.latest_approved_by_actor_id
    or target_snapshot.approved_at is distinct from
      target_batch.latest_approved_at
    or target_snapshot.source_signature is distinct from
      target_batch.source_signature
    or target_snapshot.no_additions_confirmed is distinct from
      target_batch.no_additions_confirmed
  then
    raise exception using
      errcode = '23514',
      message = 'approved Pantry batch evidence must match its exact snapshot';
  end if;

  if target_snapshot.line_count <> (
    select count(*)::integer
    from atlas_planning.pantry_need_approval_snapshot_lines snapshot_line
    where snapshot_line.pantry_need_approval_snapshot_id =
      target_snapshot_id
  ) then
    raise exception using
      errcode = '23514',
      message = 'Pantry snapshot line count must match the exact line set';
  end if;

  if exists (
    select 1
    from atlas_planning.pantry_need_lines line
    where line.pantry_need_batch_id = target_batch.pantry_need_batch_id
      and line.line_status = 'ACTIVE'
      and not exists (
        select 1
        from atlas_planning.pantry_need_approval_snapshot_lines snapshot_line
        where snapshot_line.pantry_need_approval_snapshot_id =
          target_snapshot_id
          and snapshot_line.pantry_need_line_id = line.pantry_need_line_id
      )
  ) or exists (
    select 1
    from atlas_planning.pantry_need_approval_snapshot_lines snapshot_line
    left join atlas_planning.pantry_need_lines line
      on line.pantry_need_line_id = snapshot_line.pantry_need_line_id
    where snapshot_line.pantry_need_approval_snapshot_id =
      target_snapshot_id
      and (
        line.pantry_need_line_id is null
        or line.pantry_need_batch_id is distinct from
          target_batch.pantry_need_batch_id
        or line.line_status <> 'ACTIVE'
      )
  ) then
    raise exception using
      errcode = '23514',
      message = 'Pantry snapshot must contain every-and-only active line';
  end if;

  if target_snapshot.no_additions_confirmed and exists (
    select 1
    from atlas_planning.pantry_need_approval_snapshot_lines snapshot_line
    where snapshot_line.pantry_need_approval_snapshot_id =
      target_snapshot_id
  ) then
    raise exception using
      errcode = '23514',
      message = 'zero-additions Pantry snapshots cannot contain a line';
  end if;

  return null;
end
$$;

create trigger pantry_need_purposes_guard
before update or delete on atlas_planning.pantry_need_purposes
for each row execute function atlas_planning.pantry_02_purpose_guard();

create trigger pantry_need_batches_guard
before insert or update or delete on atlas_planning.pantry_need_batches
for each row execute function atlas_planning.pantry_02_batch_guard();

create trigger pantry_need_lines_guard
before insert or update or delete on atlas_planning.pantry_need_lines
for each row execute function atlas_planning.pantry_02_line_guard();

create trigger pantry_need_approval_snapshots_guard
before insert or update or delete
on atlas_planning.pantry_need_approval_snapshots
for each row execute function atlas_planning.pantry_02_snapshot_guard();

create trigger pantry_need_approval_snapshot_lines_guard
before insert or update or delete
on atlas_planning.pantry_need_approval_snapshot_lines
for each row execute function atlas_planning.pantry_02_snapshot_guard();

create constraint trigger pantry_need_batches_snapshot_integrity_guard
after insert or update on atlas_planning.pantry_need_batches
deferrable initially deferred
for each row execute function
  atlas_planning.pantry_02_snapshot_integrity_guard();

create constraint trigger pantry_need_approval_snapshots_integrity_guard
after insert on atlas_planning.pantry_need_approval_snapshots
deferrable initially deferred
for each row execute function
  atlas_planning.pantry_02_snapshot_integrity_guard();

create constraint trigger pantry_need_approval_snapshot_lines_integrity_guard
after insert on atlas_planning.pantry_need_approval_snapshot_lines
deferrable initially deferred
for each row execute function
  atlas_planning.pantry_02_snapshot_integrity_guard();

create function atlas_core.pantry_02_normalize_text(value text)
returns text
language sql
immutable
set search_path = ''
as $$
  select nullif(
    pg_catalog.normalize(pg_catalog.btrim(coalesce(value, '')), 'NFC'),
    ''
  );
$$;

create function atlas_core.pantry_02_safe_quantity(value text)
returns numeric(20, 6)
language plpgsql
immutable
set search_path = ''
as $$
declare
  normalized text := atlas_core.pantry_02_normalize_text(value);
  parsed numeric;
  bounded numeric(20, 6);
begin
  if normalized is null
    or normalized !~ '^[+]?[0-9]+(\.[0-9]{1,6})?$'
  then
    return null;
  end if;
  parsed := normalized::numeric;
  if parsed <= 0 then
    return null;
  end if;
  bounded := parsed::numeric(20, 6);
  if bounded::numeric is distinct from parsed then
    return null;
  end if;
  return bounded;
exception
  when invalid_text_representation or numeric_value_out_of_range then
    return null;
end
$$;

create function atlas_core.pantry_02_sha256(value jsonb)
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

create function atlas_core.pantry_02_canonical_rows(
  target_week_start date,
  rows jsonb
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with source_rows as (
    select item.value as row_value, item.ordinality
    from pg_catalog.jsonb_array_elements(
      case
        when pg_catalog.jsonb_typeof(rows) = 'array' then rows
        else '[]'::jsonb
      end
    ) with ordinality item(value, ordinality)
  ),
  normalized as (
    select
      source_rows.row_value,
      source_rows.ordinality,
      atlas_core.pantry_02_normalize_text(
        source_rows.row_value ->> 'service_date'
      ) as service_date_text,
      atlas_core.pantry_02_normalize_text(
        source_rows.row_value ->> 'school_id'
      ) as school_id_text,
      atlas_core.pantry_02_normalize_text(
        source_rows.row_value ->> 'ingredient_id'
      ) as ingredient_id_text,
      atlas_core.pantry_02_normalize_text(
        source_rows.row_value ->> 'pantry_need_purpose_id'
      ) as purpose_id_text,
      atlas_core.pantry_02_normalize_text(
        source_rows.row_value ->> 'requested_quantity'
      ) as quantity_text,
      atlas_core.pantry_02_normalize_text(
        source_rows.row_value ->> 'note'
      ) as normalized_note,
      atlas_core.pantry_02_normalize_text(
        source_rows.row_value ->> 'source_request_reference'
      ) as source_request_reference,
      coalesce(
        atlas_core.pantry_02_normalize_text(
          source_rows.row_value ->> 'source_row_reference'
        ),
        'row:' || source_rows.ordinality::text
      ) as source_row_reference,
      coalesce(
        (
          select pg_catalog.jsonb_agg(key order by key)
          from pg_catalog.jsonb_object_keys(source_rows.row_value) key
          where key not in (
            'service_date',
            'school_id',
            'ingredient_id',
            'pantry_need_purpose_id',
            'requested_quantity',
            'note',
            'source_request_reference',
            'source_row_reference'
          )
        ),
        '[]'::jsonb
      ) as caller_authority_fields
    from source_rows
  ),
  resolved as (
    select
      normalized.*,
      atlas_core.pa_05d_safe_date(normalized.service_date_text)
        as service_date,
      atlas_core.pa_05b_safe_uuid(normalized.school_id_text)
        as school_id,
      atlas_core.pa_05b_safe_uuid(normalized.ingredient_id_text)
        as ingredient_id,
      atlas_core.pa_05b_safe_uuid(normalized.purpose_id_text)
        as pantry_need_purpose_id,
      atlas_core.pantry_02_safe_quantity(normalized.quantity_text)
        as requested_quantity
    from normalized
  )
  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'input_index', resolved.ordinality,
        'service_date_input', resolved.service_date_text,
        'service_date', resolved.service_date,
        'school_id_input', resolved.school_id_text,
        'school_id', resolved.school_id,
        'school_code', school.school_code,
        'school_name', school.school_name,
        'school_status', school.school_status,
        'school_customer_id', school.customer_id,
        'customer_type', customer.customer_type,
        'customer_status', customer.customer_status,
        'delivery_location_id', location.delivery_location_id,
        'delivery_location_code', location.location_code,
        'delivery_location_name', location.location_name,
        'delivery_location_address', location.address_text,
        'delivery_location_status', location.location_status,
        'delivery_location_customer_id', location.customer_id,
        'ingredient_id_input', resolved.ingredient_id_text,
        'ingredient_id', resolved.ingredient_id,
        'ingredient_code', ingredient.ingredient_code,
        'ingredient_name', ingredient.ingredient_name,
        'ingredient_status', ingredient.ingredient_status,
        'unit_id', unit.unit_id,
        'unit_code', unit.unit_code,
        'unit_name', unit.unit_name,
        'unit_status', unit.unit_status,
        'pantry_need_purpose_id_input', resolved.purpose_id_text,
        'pantry_need_purpose_id', resolved.pantry_need_purpose_id,
        'purpose_code', purpose.purpose_code,
        'purpose_name_vi', purpose.purpose_name_vi,
        'purpose_description', purpose.purpose_description,
        'purpose_note_rule', purpose.note_rule,
        'purpose_status', purpose.purpose_status,
        'requested_quantity_input', resolved.quantity_text,
        'requested_quantity', resolved.requested_quantity,
        'note', resolved.normalized_note,
        'note_input_present',
          resolved.row_value ? 'note'
          and resolved.row_value -> 'note' <> 'null'::jsonb,
        'note_whitespace_only',
          resolved.row_value ? 'note'
          and resolved.row_value -> 'note' <> 'null'::jsonb
          and resolved.normalized_note is null,
        'source_request_reference', resolved.source_request_reference,
        'source_row_reference', resolved.source_row_reference,
        'caller_authority_fields', resolved.caller_authority_fields
      )
      order by
        coalesce(resolved.service_date::text, ''),
        coalesce(resolved.school_id::text, ''),
        coalesce(location.delivery_location_id::text, ''),
        coalesce(resolved.ingredient_id::text, ''),
        resolved.ordinality
    ),
    '[]'::jsonb
  )
  from resolved
  left join atlas_admin.schools school
    on school.school_id = resolved.school_id
  left join atlas_admin.customers customer
    on customer.customer_id = school.customer_id
  left join atlas_admin.delivery_locations location
    on location.delivery_location_id =
      school.default_delivery_location_id
  left join atlas_admin.ingredients ingredient
    on ingredient.ingredient_id = resolved.ingredient_id
  left join atlas_admin.units unit
    on unit.unit_id = ingredient.purchase_unit_id
  left join atlas_planning.pantry_need_purposes purpose
    on purpose.pantry_need_purpose_id =
      resolved.pantry_need_purpose_id;
$$;

create function atlas_core.pantry_02_signature(
  target_week_start date,
  no_additions_confirmed boolean,
  canonical_rows jsonb
)
returns text
language sql
immutable
set search_path = ''
as $$
  with signature_rows as (
    select row
    from pg_catalog.jsonb_array_elements(
      case
        when pg_catalog.jsonb_typeof(canonical_rows) = 'array'
          then canonical_rows
        else '[]'::jsonb
      end
    ) row
  )
  select atlas_core.pantry_02_sha256(
    pg_catalog.jsonb_build_object(
      'week_start', target_week_start,
      'no_additions_confirmed', coalesce(no_additions_confirmed, false),
      'rows',
        coalesce(
          (
            select pg_catalog.jsonb_agg(
              pg_catalog.jsonb_build_object(
                'service_date', row -> 'service_date',
                'school_id', row -> 'school_id',
                'delivery_location_id', row -> 'delivery_location_id',
                'ingredient_id', row -> 'ingredient_id',
                'unit_id', row -> 'unit_id',
                'pantry_need_purpose_id', row -> 'pantry_need_purpose_id',
                'requested_quantity', row -> 'requested_quantity',
                'note', row -> 'note',
                'source_request_reference',
                  row -> 'source_request_reference'
              )
              order by
                row ->> 'service_date',
                row ->> 'school_id',
                row ->> 'delivery_location_id',
                row ->> 'ingredient_id'
            )
            from signature_rows
          ),
          '[]'::jsonb
        )
    )
  );
$$;

create function atlas_core.pantry_02_current_rows(batch_id uuid)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select coalesce(
    pg_catalog.jsonb_agg(
      (
        atlas_core.pantry_02_canonical_rows(
          batch.week_start,
          pg_catalog.jsonb_build_array(
            pg_catalog.jsonb_build_object(
              'service_date', line.service_date,
              'school_id', line.school_id,
              'ingredient_id', line.ingredient_id,
              'pantry_need_purpose_id', line.pantry_need_purpose_id,
              'requested_quantity', line.requested_quantity,
              'note', line.note,
              'source_request_reference', line.source_request_reference,
              'source_row_reference', line.source_row_reference
            )
          )
        ) -> 0
      ) || pg_catalog.jsonb_build_object(
        'pantry_need_line_id', line.pantry_need_line_id,
        'persisted_delivery_location_id', line.delivery_location_id,
        'persisted_unit_id', line.unit_id,
        'line_status', line.line_status,
        'updated_by_actor_id', line.updated_by_actor_id,
        'updated_at', line.updated_at
      )
      order by
        line.service_date,
        line.school_id,
        line.delivery_location_id,
        line.ingredient_id,
        line.pantry_need_line_id
    ),
    '[]'::jsonb
  )
  from atlas_planning.pantry_need_lines line
  join atlas_planning.pantry_need_batches batch
    on batch.pantry_need_batch_id = line.pantry_need_batch_id
  where line.pantry_need_batch_id = batch_id
    and line.line_status = 'ACTIVE';
$$;

create function atlas_core.pantry_02_lock_references(canonical_rows jsonb)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  perform 1
  from atlas_admin.schools school
  where school.school_id in (
    select (value ->> 'school_id')::uuid
    from pg_catalog.jsonb_array_elements(canonical_rows)
  )
  order by school.school_id
  for key share;
  perform 1
  from atlas_admin.delivery_locations location
  where location.delivery_location_id in (
    select (value ->> 'delivery_location_id')::uuid
    from pg_catalog.jsonb_array_elements(canonical_rows)
  )
  order by location.delivery_location_id
  for key share;
  perform 1
  from atlas_admin.ingredients ingredient
  where ingredient.ingredient_id in (
    select (value ->> 'ingredient_id')::uuid
    from pg_catalog.jsonb_array_elements(canonical_rows)
  )
  order by ingredient.ingredient_id
  for key share;
  perform 1
  from atlas_admin.units unit_row
  where unit_row.unit_id in (
    select (value ->> 'unit_id')::uuid
    from pg_catalog.jsonb_array_elements(canonical_rows)
  )
  order by unit_row.unit_id
  for key share;
  perform 1
  from atlas_planning.pantry_need_purposes purpose
  where purpose.pantry_need_purpose_id in (
    select (value ->> 'pantry_need_purpose_id')::uuid
    from pg_catalog.jsonb_array_elements(canonical_rows)
  )
  order by purpose.pantry_need_purpose_id
  for key share;
end
$$;

create function atlas_core.pantry_02_issue(
  code text,
  message text,
  source_row_reference text default null,
  field_name text default null
)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'code', code,
    'message', message,
    'source_row_reference', source_row_reference,
    'field', field_name
  );
$$;

create function atlas_core.pantry_02_issues(
  target_week_start date,
  no_additions_confirmed boolean,
  canonical_rows jsonb
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  blockers jsonb := '[]'::jsonb;
  warnings jsonb := '[]'::jsonb;
  item jsonb;
  row_ref text;
  quantity_text text;
  duplicate_issues jsonb;
begin
  if target_week_start is null then
    blockers := blockers || pg_catalog.jsonb_build_array(
      atlas_core.pantry_02_issue(
        'INVALID_WEEK_START',
        'A valid ISO Pantry week start is required.',
        null,
        'week_start'
      )
    );
  elsif extract(isodow from target_week_start) <> 1 then
    blockers := blockers || pg_catalog.jsonb_build_array(
      atlas_core.pantry_02_issue(
        'WEEK_START_NOT_MONDAY',
        'The Pantry week must start on Monday.',
        null,
        'week_start'
      )
    );
  end if;

  for item in
    select value
    from pg_catalog.jsonb_array_elements(
      case
        when pg_catalog.jsonb_typeof(canonical_rows) = 'array'
          then canonical_rows
        else '[]'::jsonb
      end
    )
  loop
    row_ref := item ->> 'source_row_reference';

    if pg_catalog.jsonb_array_length(
      coalesce(item -> 'caller_authority_fields', '[]'::jsonb)
    ) > 0 then
      blockers := blockers || pg_catalog.jsonb_build_array(
        atlas_core.pantry_02_issue(
          case
            when (item -> 'caller_authority_fields') ? 'delivery_location_id'
              then 'CALLER_DELIVERY_LOCATION_NOT_ALLOWED'
            when (item -> 'caller_authority_fields') ? 'unit_id'
              then 'CALLER_UNIT_NOT_ALLOWED'
            else 'UNREVIEWED_ROW_FIELD'
          end,
          'The row contains a caller-authored or unreviewed field.',
          row_ref,
          'rows'
        )
      );
    end if;

    if item -> 'service_date' = 'null'::jsonb then
      blockers := blockers || pg_catalog.jsonb_build_array(
        atlas_core.pantry_02_issue(
          'INVALID_SERVICE_DATE',
          'A valid service date is required.',
          row_ref,
          'service_date'
        )
      );
    elsif target_week_start is not null and (
      (item ->> 'service_date')::date < target_week_start
      or (item ->> 'service_date')::date > target_week_start + 6
    ) then
      blockers := blockers || pg_catalog.jsonb_build_array(
        atlas_core.pantry_02_issue(
          'SERVICE_DATE_OUTSIDE_WEEK',
          'The service date is outside the selected Pantry week.',
          row_ref,
          'service_date'
        )
      );
    end if;

    if item -> 'school_id' = 'null'::jsonb then
      blockers := blockers || pg_catalog.jsonb_build_array(
        atlas_core.pantry_02_issue(
          case
            when item ->> 'school_id_input' is null
              then 'SCHOOL_REQUIRED'
            else 'INVALID_SCHOOL_ID'
          end,
          'A valid School reference is required.',
          row_ref,
          'school_id'
        )
      );
    elsif item ->> 'school_name' is null then
      blockers := blockers || pg_catalog.jsonb_build_array(
        atlas_core.pantry_02_issue(
          'UNKNOWN_SCHOOL',
          'The School does not exist.',
          row_ref,
          'school_id'
        )
      );
    else
      if item ->> 'school_status' <> 'ACTIVE' then
        blockers := blockers || pg_catalog.jsonb_build_array(
          atlas_core.pantry_02_issue(
            'INACTIVE_SCHOOL',
            'The School is not active.',
            row_ref,
            'school_id'
          )
        );
      end if;
      if item ->> 'customer_type' <> 'SCHOOL_CATERING' then
        blockers := blockers || pg_catalog.jsonb_build_array(
          atlas_core.pantry_02_issue(
            'SCHOOL_CUSTOMER_TYPE_INVALID',
            'The School parent is not a SCHOOL_CATERING Customer.',
            row_ref,
            'school_id'
          )
        );
      end if;
      if item ->> 'customer_status' <> 'ACTIVE' then
        blockers := blockers || pg_catalog.jsonb_build_array(
          atlas_core.pantry_02_issue(
            'SCHOOL_CUSTOMER_INACTIVE',
            'The School parent Customer is not active.',
            row_ref,
            'school_id'
          )
        );
      end if;
      if item -> 'delivery_location_id' = 'null'::jsonb then
        blockers := blockers || pg_catalog.jsonb_build_array(
          atlas_core.pantry_02_issue(
            'DEFAULT_DELIVERY_LOCATION_MISSING',
            'The School default Delivery Location is missing.',
            row_ref,
            'school_id'
          )
        );
      else
        if item ->> 'delivery_location_status' <> 'ACTIVE' then
          blockers := blockers || pg_catalog.jsonb_build_array(
            atlas_core.pantry_02_issue(
              'DEFAULT_DELIVERY_LOCATION_INACTIVE',
              'The School default Delivery Location is not active.',
              row_ref,
              'school_id'
            )
          );
        end if;
        if item ->> 'delivery_location_customer_id' is distinct from
          item ->> 'school_customer_id'
        then
          blockers := blockers || pg_catalog.jsonb_build_array(
            atlas_core.pantry_02_issue(
              'DEFAULT_DELIVERY_LOCATION_CUSTOMER_MISMATCH',
              'The School default Delivery Location has the wrong Customer.',
              row_ref,
              'school_id'
            )
          );
        end if;
      end if;
    end if;

    if item -> 'ingredient_id' = 'null'::jsonb then
      blockers := blockers || pg_catalog.jsonb_build_array(
        atlas_core.pantry_02_issue(
          case
            when item ->> 'ingredient_id_input' is null
              then 'INGREDIENT_REQUIRED'
            else 'INVALID_INGREDIENT_ID'
          end,
          'A valid Ingredient reference is required.',
          row_ref,
          'ingredient_id'
        )
      );
    elsif item ->> 'ingredient_name' is null then
      blockers := blockers || pg_catalog.jsonb_build_array(
        atlas_core.pantry_02_issue(
          'UNKNOWN_INGREDIENT',
          'The Ingredient does not exist.',
          row_ref,
          'ingredient_id'
        )
      );
    else
      if item ->> 'ingredient_status' = 'ARCHIVED' then
        blockers := blockers || pg_catalog.jsonb_build_array(
          atlas_core.pantry_02_issue(
            'ARCHIVED_INGREDIENT',
            'The Ingredient is archived.',
            row_ref,
            'ingredient_id'
          )
        );
      elsif item ->> 'ingredient_status' <> 'ACTIVE' then
        blockers := blockers || pg_catalog.jsonb_build_array(
          atlas_core.pantry_02_issue(
            'INACTIVE_INGREDIENT',
            'The Ingredient is not active.',
            row_ref,
            'ingredient_id'
          )
        );
      end if;
      if item -> 'unit_id' = 'null'::jsonb then
        blockers := blockers || pg_catalog.jsonb_build_array(
          atlas_core.pantry_02_issue(
            'PURCHASE_UNIT_MISSING',
            'The Ingredient has no active purchase Unit.',
            row_ref,
            'ingredient_id'
          )
        );
      elsif item ->> 'unit_status' <> 'ACTIVE' then
        blockers := blockers || pg_catalog.jsonb_build_array(
          atlas_core.pantry_02_issue(
            'PURCHASE_UNIT_INACTIVE',
            'The Ingredient purchase Unit is not active.',
            row_ref,
            'ingredient_id'
          )
        );
      end if;
      if item ? 'persisted_unit_id'
        and item ->> 'persisted_unit_id' is distinct from item ->> 'unit_id'
      then
        blockers := blockers || pg_catalog.jsonb_build_array(
          atlas_core.pantry_02_issue(
            'STALE_PERSISTED_UNIT',
            'The stored Pantry Unit no longer matches the Ingredient purchase Unit.',
            row_ref,
            'ingredient_id'
          )
        );
      end if;
      if item ? 'persisted_delivery_location_id'
        and item ->> 'persisted_delivery_location_id' is distinct from
          item ->> 'delivery_location_id'
      then
        blockers := blockers || pg_catalog.jsonb_build_array(
          atlas_core.pantry_02_issue(
            'STALE_DEFAULT_DELIVERY_LOCATION',
            'The stored Delivery Location no longer matches the School default.',
            row_ref,
            'school_id'
          )
        );
      end if;
    end if;

    if item -> 'pantry_need_purpose_id' = 'null'::jsonb then
      blockers := blockers || pg_catalog.jsonb_build_array(
        atlas_core.pantry_02_issue(
          case
            when item ->> 'pantry_need_purpose_id_input' is null
              then 'PURPOSE_REQUIRED'
            else 'INVALID_PURPOSE_ID'
          end,
          'A valid Pantry Purpose is required.',
          row_ref,
          'pantry_need_purpose_id'
        )
      );
    elsif item ->> 'purpose_name_vi' is null then
      blockers := blockers || pg_catalog.jsonb_build_array(
        atlas_core.pantry_02_issue(
          'UNKNOWN_PURPOSE',
          'The Pantry Purpose does not exist.',
          row_ref,
          'pantry_need_purpose_id'
        )
      );
    else
      if item ->> 'purpose_status' <> 'ACTIVE' then
        blockers := blockers || pg_catalog.jsonb_build_array(
          atlas_core.pantry_02_issue(
            'INACTIVE_PURPOSE',
            'The Pantry Purpose is not active.',
            row_ref,
            'pantry_need_purpose_id'
          )
        );
      end if;
      if coalesce((item ->> 'note_whitespace_only')::boolean, false) then
        blockers := blockers || pg_catalog.jsonb_build_array(
          atlas_core.pantry_02_issue(
            'WHITESPACE_ONLY_NOTE',
            'A supplied Pantry note must contain non-whitespace text.',
            row_ref,
            'note'
          )
        );
      elsif item ->> 'purpose_note_rule' = 'REQUIRED'
        and item -> 'note' = 'null'::jsonb
      then
        blockers := blockers || pg_catalog.jsonb_build_array(
          atlas_core.pantry_02_issue(
            'MISSING_REQUIRED_NOTE',
            'The selected Pantry Purpose requires a note.',
            row_ref,
            'note'
          )
        );
      elsif item ->> 'purpose_note_rule' = 'PROHIBITED'
        and item -> 'note' <> 'null'::jsonb
      then
        blockers := blockers || pg_catalog.jsonb_build_array(
          atlas_core.pantry_02_issue(
            'PROHIBITED_NOTE_PRESENT',
            'The selected Pantry Purpose prohibits a note.',
            row_ref,
            'note'
          )
        );
      end if;
    end if;

    quantity_text := item ->> 'requested_quantity_input';
    if quantity_text is null then
      blockers := blockers || pg_catalog.jsonb_build_array(
        atlas_core.pantry_02_issue(
          'QUANTITY_REQUIRED',
          'A Pantry quantity is required.',
          row_ref,
          'requested_quantity'
        )
      );
    elsif lower(quantity_text) in (
      'nan',
      '+nan',
      '-nan',
      'infinity',
      '+infinity',
      '-infinity',
      'inf',
      '+inf',
      '-inf'
    ) then
      blockers := blockers || pg_catalog.jsonb_build_array(
        atlas_core.pantry_02_issue(
          'QUANTITY_NONFINITE',
          'A Pantry quantity must be finite.',
          row_ref,
          'requested_quantity'
        )
      );
    elsif quantity_text ~ '^[+-]?([0-9]+(\.[0-9]*)?|\.[0-9]+)$'
      and item -> 'requested_quantity' = 'null'::jsonb
      and quantity_text::numeric <= 0
    then
      blockers := blockers || pg_catalog.jsonb_build_array(
        atlas_core.pantry_02_issue(
          'QUANTITY_NOT_POSITIVE',
          'A Pantry quantity must be greater than zero.',
          row_ref,
          'requested_quantity'
        )
      );
    elsif item -> 'requested_quantity' = 'null'::jsonb then
      blockers := blockers || pg_catalog.jsonb_build_array(
        atlas_core.pantry_02_issue(
          'QUANTITY_MALFORMED',
          'A Pantry quantity must be an exact positive decimal with at most six fractional digits.',
          row_ref,
          'requested_quantity'
        )
      );
    end if;
  end loop;

  with valid_grains as (
    select
      value ->> 'service_date' as service_date,
      value ->> 'school_id' as school_id,
      value ->> 'delivery_location_id' as delivery_location_id,
      value ->> 'ingredient_id' as ingredient_id,
      min(value ->> 'source_row_reference') as source_row_reference,
      count(*) as row_count
    from pg_catalog.jsonb_array_elements(
      case
        when pg_catalog.jsonb_typeof(canonical_rows) = 'array'
          then canonical_rows
        else '[]'::jsonb
      end
    )
    where value -> 'service_date' <> 'null'::jsonb
      and value -> 'school_id' <> 'null'::jsonb
      and value -> 'delivery_location_id' <> 'null'::jsonb
      and value -> 'ingredient_id' <> 'null'::jsonb
    group by
      value ->> 'service_date',
      value ->> 'school_id',
      value ->> 'delivery_location_id',
      value ->> 'ingredient_id'
    having count(*) > 1
  )
  select coalesce(
    pg_catalog.jsonb_agg(
      atlas_core.pantry_02_issue(
        'DUPLICATE_ACTIVE_GRAIN',
        'The proposed Pantry rows repeat the same service date, School, default Delivery Location, and Ingredient.',
        source_row_reference,
        'rows'
      )
    ),
    '[]'::jsonb
  )
    into duplicate_issues
  from valid_grains;

  blockers := blockers || duplicate_issues;

  if pg_catalog.jsonb_array_length(
    case
      when pg_catalog.jsonb_typeof(canonical_rows) = 'array'
        then canonical_rows
      else '[]'::jsonb
    end
  ) = 0 and not coalesce(no_additions_confirmed, false) then
    blockers := blockers || pg_catalog.jsonb_build_array(
      atlas_core.pantry_02_issue(
        'NO_ADDITIONS_CONFIRMATION_REQUIRED',
        'An empty Pantry week requires explicit no-additions confirmation.',
        null,
        'no_additions_confirmed'
      )
    );
  end if;

  if pg_catalog.jsonb_array_length(
    case
      when pg_catalog.jsonb_typeof(canonical_rows) = 'array'
        then canonical_rows
      else '[]'::jsonb
    end
  ) > 0 and coalesce(no_additions_confirmed, false) then
    blockers := blockers || pg_catalog.jsonb_build_array(
      atlas_core.pantry_02_issue(
        'ACTIVE_LINES_WITH_NO_ADDITIONS',
        'Active Pantry lines cannot be combined with no-additions confirmation.',
        null,
        'no_additions_confirmed'
      )
    );
  end if;

  if pg_catalog.jsonb_array_length(
    case
      when pg_catalog.jsonb_typeof(canonical_rows) = 'array'
        then canonical_rows
      else '[]'::jsonb
    end
  ) > 0 and not exists (
    select 1
    from atlas_planning.pantry_need_purposes purpose
    where purpose.purpose_status = 'ACTIVE'
  ) then
    blockers := blockers || pg_catalog.jsonb_build_array(
      atlas_core.pantry_02_issue(
        'PURPOSE_CATALOG_EMPTY',
        'No active Pantry Purpose is configured.',
        null,
        'pantry_need_purpose_id'
      )
    );
  end if;

  return pg_catalog.jsonb_build_object(
    'blockers', blockers,
    'warnings', warnings
  );
exception
  when invalid_text_representation or numeric_value_out_of_range then
    return pg_catalog.jsonb_build_object(
      'blockers',
        blockers || pg_catalog.jsonb_build_array(
          atlas_core.pantry_02_issue(
            'QUANTITY_MALFORMED',
            'A Pantry quantity could not be interpreted safely.',
            row_ref,
            'requested_quantity'
          )
        ),
      'warnings', warnings
    );
end
$$;

create function atlas_api.save_pantry_draft(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
#variable_conflict use_variable
declare
  command_name constant text := 'save_pantry_draft';
  prepared jsonb;
  actor_id uuid;
  receipt_id uuid;
  error_response jsonb;
  week_start date;
  no_additions boolean;
  proposed_rows jsonb;
  canonical_rows jsonb;
  issues jsonb;
  derived_signature text;
  claimed_signature text;
  expected_signature text;
  batch atlas_planning.pantry_need_batches%rowtype;
  version_before bigint;
  event_name text;
  recorded jsonb;
  item jsonb;
  workbench jsonb;
  response jsonb;
begin
  prepared := atlas_core.pantry_02_prepare_command(
    request,
    command_name,
    'planning.pantry.write',
    'PantryNeedBatch'
  );
  if prepared ->> 'status' = 'RETURN' then
    return prepared -> 'response';
  end if;
  actor_id := atlas_core.pa_05b_safe_uuid(prepared ->> 'actor_id');
  receipt_id := atlas_core.pa_05b_safe_uuid(prepared ->> 'receipt_id');

  if pg_catalog.jsonb_typeof(
    request -> 'payload' -> 'no_additions_confirmed'
  ) <> 'boolean'
    or pg_catalog.jsonb_typeof(request -> 'payload' -> 'rows') <> 'array'
  then
    error_response := atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'Pantry save requires explicit no-additions confirmation and a row array.',
      'PLANNING',
      command_name,
      false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field', 'payload',
          'message',
            'no_additions_confirmed must be Boolean and rows must be an array.'
        )
      )
    );
    return atlas_core.pa_05b_finish_command(
      receipt_id,
      error_response,
      false
    );
  end if;

  week_start := atlas_core.pa_05d_safe_date(
    request -> 'payload' ->> 'week_start'
  );
  no_additions := (request -> 'payload' ->> 'no_additions_confirmed')::boolean;
  proposed_rows := request -> 'payload' -> 'rows';
  canonical_rows := atlas_core.pantry_02_canonical_rows(
    week_start,
    proposed_rows
  );
  issues := atlas_core.pantry_02_issues(
    week_start,
    no_additions,
    canonical_rows
  );
  derived_signature := atlas_core.pantry_02_signature(
    week_start,
    no_additions,
    canonical_rows
  );
  claimed_signature := atlas_core.pantry_02_normalize_text(
    request -> 'payload' ->> 'source_signature'
  );
  expected_signature := atlas_core.pantry_02_normalize_text(
    request -> 'payload' ->> 'expected_source_signature'
  );

  if claimed_signature is null
    or claimed_signature is distinct from derived_signature
  then
    issues := pg_catalog.jsonb_set(
      issues,
      '{blockers}',
      issues -> 'blockers' || pg_catalog.jsonb_build_array(
        atlas_core.pantry_02_issue(
          'SOURCE_SIGNATURE_MISMATCH',
          'Save requires the exact signature returned by Pantry preview.',
          null,
          'source_signature'
        )
      )
    );
  end if;
  if pg_catalog.jsonb_array_length(issues -> 'blockers') > 0 then
    error_response := atlas_core.pa_05b_command_error(
      request,
      'INVARIANT_VIOLATION',
      'The Pantry draft has blocking issues.',
      'PLANNING',
      command_name,
      false,
      '[]'::jsonb,
      '[]'::jsonb,
      null
    ) || pg_catalog.jsonb_build_object(
      'blockers', issues -> 'blockers',
      'warnings', issues -> 'warnings'
    );
    return atlas_core.pa_05b_finish_command(
      receipt_id,
      error_response,
      false
    );
  end if;

  perform atlas_core.pantry_02_lock_references(canonical_rows);

  select current_batch.*
    into batch
  from atlas_planning.pantry_need_batches current_batch
  where current_batch.week_start = week_start
  for update;

  if batch.pantry_need_batch_id is null then
    if request ->> 'expected_version' <> '1'
      or expected_signature is not null
    then
      error_response := atlas_core.pa_05b_command_error(
        request,
        'STALE_VERSION',
        'The Pantry week state changed. Refresh and preview again.',
        'PLANNING',
        command_name,
        false,
        '[]'::jsonb,
        '[]'::jsonb,
        null
      );
      return atlas_core.pa_05b_finish_command(
        receipt_id,
        error_response,
        false
      );
    end if;

    insert into atlas_planning.pantry_need_batches (
      week_start,
      pantry_need_batch_status,
      version,
      source_signature,
      no_additions_confirmed,
      requesting_actor_id
    ) values (
      week_start,
      'DRAFT',
      1,
      derived_signature,
      no_additions,
      actor_id
    )
    returning * into batch;
    version_before := null;
    event_name := 'PantryDraftCreated';
  else
    if batch.version <> atlas_core.pa_05b_safe_bigint(
      request ->> 'expected_version'
    ) then
      error_response := atlas_core.pa_05b_command_error(
        request,
        'STALE_VERSION',
        'The Pantry week changed. Refresh and preview again.',
        'PLANNING',
        command_name,
        false,
        '[]'::jsonb,
        pg_catalog.jsonb_build_array(batch.pantry_need_batch_id),
        batch.version
      );
      return atlas_core.pa_05b_finish_command(
        receipt_id,
        error_response,
        false
      );
    end if;
    if expected_signature is null
      or expected_signature is distinct from batch.source_signature
    then
      error_response := atlas_core.pa_05b_command_error(
        request,
        'STALE_SOURCE_SIGNATURE',
        'The Pantry source signature changed. Refresh and preview again.',
        'PLANNING',
        command_name
      );
      return atlas_core.pa_05b_finish_command(
        receipt_id,
        error_response,
        false
      );
    end if;
    if batch.pantry_need_batch_status not in ('DRAFT', 'REOPENED') then
      error_response := atlas_core.pa_05b_command_error(
        request,
        'INVALID_LIFECYCLE_STATE',
        'Only a Draft or Reopened Pantry week can be replaced.',
        'PLANNING',
        command_name
      );
      return atlas_core.pa_05b_finish_command(
        receipt_id,
        error_response,
        false
      );
    end if;

    if batch.source_signature = derived_signature
      and batch.no_additions_confirmed = no_additions
    then
      workbench := atlas_core.pantry_02_workbench_payload(
        week_start,
        actor_id
      );
      response := atlas_core.pantry_02_success(
        request,
        batch,
        '[]'::jsonb,
        '[]'::jsonb,
        'The Pantry proposal contains no business-fact changes.',
        workbench,
        'NO_CHANGE'
      );
      return atlas_core.pa_05b_finish_command(receipt_id, response, true);
    end if;

    version_before := batch.version;
    event_name := 'PantryDraftReplaced';
  end if;

  update atlas_planning.pantry_need_lines line
  set
    line_status = 'INVALID',
    updated_by_actor_id = actor_id,
    updated_at = pg_catalog.transaction_timestamp()
  where line.pantry_need_batch_id = batch.pantry_need_batch_id
    and line.line_status = 'ACTIVE';

  for item in
    select value
    from pg_catalog.jsonb_array_elements(canonical_rows)
    order by
      value ->> 'service_date',
      value ->> 'school_id',
      value ->> 'delivery_location_id',
      value ->> 'ingredient_id'
  loop
    insert into atlas_planning.pantry_need_lines (
      pantry_need_batch_id,
      service_date,
      school_id,
      delivery_location_id,
      ingredient_id,
      unit_id,
      pantry_need_purpose_id,
      requested_quantity,
      note,
      source_request_reference,
      source_row_reference,
      line_status,
      updated_by_actor_id
    ) values (
      batch.pantry_need_batch_id,
      (item ->> 'service_date')::date,
      (item ->> 'school_id')::uuid,
      (item ->> 'delivery_location_id')::uuid,
      (item ->> 'ingredient_id')::uuid,
      (item ->> 'unit_id')::uuid,
      (item ->> 'pantry_need_purpose_id')::uuid,
      (item ->> 'requested_quantity')::numeric(20, 6),
      item ->> 'note',
      item ->> 'source_request_reference',
      item ->> 'source_row_reference',
      'ACTIVE',
      actor_id
    )
    on conflict (
      pantry_need_batch_id,
      service_date,
      school_id,
      delivery_location_id,
      ingredient_id
    ) do update
    set
      unit_id = excluded.unit_id,
      pantry_need_purpose_id = excluded.pantry_need_purpose_id,
      requested_quantity = excluded.requested_quantity,
      note = excluded.note,
      source_request_reference = excluded.source_request_reference,
      source_row_reference = excluded.source_row_reference,
      line_status = 'ACTIVE',
      updated_by_actor_id = excluded.updated_by_actor_id,
      updated_at = pg_catalog.transaction_timestamp();
  end loop;

  if version_before is not null then
    update atlas_planning.pantry_need_batches target_batch
    set
      pantry_need_batch_status = target_batch.pantry_need_batch_status,
      source_signature = derived_signature,
      no_additions_confirmed = no_additions,
      version = target_batch.version + 1,
      updated_at = pg_catalog.transaction_timestamp()
    where target_batch.pantry_need_batch_id = batch.pantry_need_batch_id
    returning * into batch;
  end if;

  recorded := atlas_core.pantry_02_record_change(
    event_name,
    batch.pantry_need_batch_id,
    version_before,
    batch.version,
    receipt_id,
    request,
    actor_id,
    case
      when version_before is null then null
      else pg_catalog.jsonb_build_object(
        'status', batch.pantry_need_batch_status,
        'version', version_before,
        'source_signature', expected_signature
      )
    end,
    pg_catalog.jsonb_build_object(
      'status', batch.pantry_need_batch_status,
      'version', batch.version,
      'source_signature', batch.source_signature,
      'no_additions_confirmed', batch.no_additions_confirmed,
      'line_count', pg_catalog.jsonb_array_length(canonical_rows)
    )
  );
  workbench := atlas_core.pantry_02_workbench_payload(
    week_start,
    actor_id
  );
  response := atlas_core.pantry_02_success(
    request,
    batch,
    pg_catalog.jsonb_build_array(recorded ->> 'domain_event_id'),
    pg_catalog.jsonb_build_array(recorded ->> 'audit_event_id'),
    case
      when version_before is null then 'Pantry draft created.'
      else 'Pantry draft replaced.'
    end,
    workbench
  );
  return atlas_core.pa_05b_finish_command(receipt_id, response, true);
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request,
      'RETRYABLE_CONCURRENCY_FAILURE',
      'The Pantry draft could not acquire a safe transaction state. Retry the exact request.',
      'PLANNING',
      command_name,
      true
    );
  when unique_violation then
    return atlas_core.pa_05b_command_error(
      request,
      'RETRYABLE_CONCURRENCY_FAILURE',
      'The Pantry week changed concurrently. Refresh and retry.',
      'PLANNING',
      command_name,
      true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'The Pantry draft could not be saved safely.',
      'PLANNING',
      command_name
    );
end
$$;

create function atlas_api.validate_pantry(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
#variable_conflict use_variable
declare
  command_name constant text := 'validate_pantry';
  prepared jsonb;
  actor_id uuid;
  receipt_id uuid;
  error_response jsonb;
  week_start date;
  expected_signature text;
  batch atlas_planning.pantry_need_batches%rowtype;
  version_before bigint;
  current_rows jsonb;
  issues jsonb;
  current_signature text;
  recorded jsonb;
  response jsonb;
begin
  prepared := atlas_core.pantry_02_prepare_command(
    request,
    command_name,
    'planning.pantry.write',
    'PantryNeedBatch'
  );
  if prepared ->> 'status' = 'RETURN' then
    return prepared -> 'response';
  end if;
  actor_id := atlas_core.pa_05b_safe_uuid(prepared ->> 'actor_id');
  receipt_id := atlas_core.pa_05b_safe_uuid(prepared ->> 'receipt_id');
  week_start := atlas_core.pa_05d_safe_date(
    request -> 'payload' ->> 'week_start'
  );
  expected_signature := atlas_core.pantry_02_normalize_text(
    request -> 'payload' ->> 'expected_source_signature'
  );

  select current_batch.*
    into batch
  from atlas_planning.pantry_need_batches current_batch
  where current_batch.week_start = week_start
  for update;
  if batch.pantry_need_batch_id is null then
    error_response := atlas_core.pa_05b_command_error(
      request,
      'NOT_FOUND',
      'No Pantry draft exists for the selected week.',
      'PLANNING',
      command_name
    );
    return atlas_core.pa_05b_finish_command(
      receipt_id,
      error_response,
      false
    );
  end if;
  perform 1
  from atlas_planning.pantry_need_lines line
  where line.pantry_need_batch_id = batch.pantry_need_batch_id
  order by line.pantry_need_line_id
  for update;

  if batch.version <> atlas_core.pa_05b_safe_bigint(
    request ->> 'expected_version'
  ) then
    error_response := atlas_core.pa_05b_command_error(
      request,
      'STALE_VERSION',
      'The Pantry week changed. Refresh before validation.',
      'PLANNING',
      command_name,
      false,
      '[]'::jsonb,
      pg_catalog.jsonb_build_array(batch.pantry_need_batch_id),
      batch.version
    );
    return atlas_core.pa_05b_finish_command(
      receipt_id,
      error_response,
      false
    );
  end if;
  if expected_signature is null
    or expected_signature is distinct from batch.source_signature
  then
    error_response := atlas_core.pa_05b_command_error(
      request,
      'STALE_SOURCE_SIGNATURE',
      'The Pantry source signature changed. Refresh before validation.',
      'PLANNING',
      command_name
    );
    return atlas_core.pa_05b_finish_command(
      receipt_id,
      error_response,
      false
    );
  end if;
  if batch.pantry_need_batch_status not in ('DRAFT', 'REOPENED') then
    error_response := atlas_core.pa_05b_command_error(
      request,
      'INVALID_LIFECYCLE_STATE',
      'Only a Draft or Reopened Pantry week can be validated.',
      'PLANNING',
      command_name
    );
    return atlas_core.pa_05b_finish_command(
      receipt_id,
      error_response,
      false
    );
  end if;

  current_rows := atlas_core.pantry_02_current_rows(
    batch.pantry_need_batch_id
  );
  perform atlas_core.pantry_02_lock_references(current_rows);
  issues := atlas_core.pantry_02_issues(
    batch.week_start,
    batch.no_additions_confirmed,
    current_rows
  );
  current_signature := atlas_core.pantry_02_signature(
    batch.week_start,
    batch.no_additions_confirmed,
    current_rows
  );
  if current_signature is distinct from batch.source_signature then
    issues := pg_catalog.jsonb_set(
      issues,
      '{blockers}',
      issues -> 'blockers' || pg_catalog.jsonb_build_array(
        atlas_core.pantry_02_issue(
          'PERSISTED_SIGNATURE_MISMATCH',
          'The persisted Pantry lines do not match the batch signature.',
          null,
          'source_signature'
        )
      )
    );
  end if;
  if pg_catalog.jsonb_array_length(issues -> 'blockers') > 0 then
    error_response := atlas_core.pa_05b_command_error(
      request,
      'INVARIANT_VIOLATION',
      'The Pantry week has blocking validation issues.',
      'PLANNING',
      command_name
    ) || pg_catalog.jsonb_build_object(
      'blockers', issues -> 'blockers',
      'warnings', issues -> 'warnings'
    );
    return atlas_core.pa_05b_finish_command(
      receipt_id,
      error_response,
      false
    );
  end if;

  version_before := batch.version;
  update atlas_planning.pantry_need_batches target_batch
  set
    pantry_need_batch_status = 'VALIDATED',
    version = target_batch.version + 1,
    updated_at = pg_catalog.transaction_timestamp()
  where target_batch.pantry_need_batch_id = batch.pantry_need_batch_id
  returning * into batch;

  recorded := atlas_core.pantry_02_record_change(
    'PantryValidated',
    batch.pantry_need_batch_id,
    version_before,
    batch.version,
    receipt_id,
    request,
    actor_id,
    pg_catalog.jsonb_build_object(
      'status', 'DRAFT_OR_REOPENED',
      'version', version_before
    ),
    pg_catalog.jsonb_build_object(
      'status', batch.pantry_need_batch_status,
      'version', batch.version,
      'source_signature', batch.source_signature,
      'line_count', pg_catalog.jsonb_array_length(current_rows)
    )
  );
  response := atlas_core.pantry_02_success(
    request,
    batch,
    pg_catalog.jsonb_build_array(recorded ->> 'domain_event_id'),
    pg_catalog.jsonb_build_array(recorded ->> 'audit_event_id'),
    'Pantry week validated.',
    atlas_core.pantry_02_workbench_payload(week_start, actor_id)
  );
  return atlas_core.pa_05b_finish_command(receipt_id, response, true);
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request,
      'RETRYABLE_CONCURRENCY_FAILURE',
      'The Pantry validation could not acquire a safe transaction state. Retry the exact request.',
      'PLANNING',
      command_name,
      true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'The Pantry week could not be validated safely.',
      'PLANNING',
      command_name
    );
end
$$;

create function atlas_api.approve_pantry(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
#variable_conflict use_variable
declare
  command_name constant text := 'approve_pantry';
  prepared jsonb;
  actor_id uuid;
  receipt_id uuid;
  error_response jsonb;
  week_start date;
  expected_signature text;
  batch atlas_planning.pantry_need_batches%rowtype;
  version_before bigint;
  current_rows jsonb;
  issues jsonb;
  current_signature text;
  snapshot_id uuid;
  approved_at timestamptz := pg_catalog.transaction_timestamp();
  recorded jsonb;
  response jsonb;
begin
  prepared := atlas_core.pantry_02_prepare_command(
    request,
    command_name,
    'planning.inputs.approve',
    'PantryNeedBatch'
  );
  if prepared ->> 'status' = 'RETURN' then
    return prepared -> 'response';
  end if;
  actor_id := atlas_core.pa_05b_safe_uuid(prepared ->> 'actor_id');
  receipt_id := atlas_core.pa_05b_safe_uuid(prepared ->> 'receipt_id');
  week_start := atlas_core.pa_05d_safe_date(
    request -> 'payload' ->> 'week_start'
  );
  expected_signature := atlas_core.pantry_02_normalize_text(
    request -> 'payload' ->> 'expected_source_signature'
  );

  select current_batch.*
    into batch
  from atlas_planning.pantry_need_batches current_batch
  where current_batch.week_start = week_start
  for update;
  if batch.pantry_need_batch_id is null then
    error_response := atlas_core.pa_05b_command_error(
      request,
      'NOT_FOUND',
      'No Pantry week exists for approval.',
      'PLANNING',
      command_name
    );
    return atlas_core.pa_05b_finish_command(
      receipt_id,
      error_response,
      false
    );
  end if;
  perform 1
  from atlas_planning.pantry_need_lines line
  where line.pantry_need_batch_id = batch.pantry_need_batch_id
  order by line.pantry_need_line_id
  for update;

  if batch.version <> atlas_core.pa_05b_safe_bigint(
    request ->> 'expected_version'
  ) then
    error_response := atlas_core.pa_05b_command_error(
      request,
      'STALE_VERSION',
      'The Pantry week changed. Refresh before approval.',
      'PLANNING',
      command_name,
      false,
      '[]'::jsonb,
      pg_catalog.jsonb_build_array(batch.pantry_need_batch_id),
      batch.version
    );
    return atlas_core.pa_05b_finish_command(
      receipt_id,
      error_response,
      false
    );
  end if;
  if expected_signature is null
    or expected_signature is distinct from batch.source_signature
  then
    error_response := atlas_core.pa_05b_command_error(
      request,
      'STALE_SOURCE_SIGNATURE',
      'The Pantry source signature changed. Refresh before approval.',
      'PLANNING',
      command_name
    );
    return atlas_core.pa_05b_finish_command(
      receipt_id,
      error_response,
      false
    );
  end if;
  if batch.pantry_need_batch_status <> 'VALIDATED' then
    error_response := atlas_core.pa_05b_command_error(
      request,
      'INVALID_LIFECYCLE_STATE',
      'Only a Validated Pantry week can be approved.',
      'PLANNING',
      command_name
    );
    return atlas_core.pa_05b_finish_command(
      receipt_id,
      error_response,
      false
    );
  end if;

  current_rows := atlas_core.pantry_02_current_rows(
    batch.pantry_need_batch_id
  );
  perform atlas_core.pantry_02_lock_references(current_rows);
  issues := atlas_core.pantry_02_issues(
    batch.week_start,
    batch.no_additions_confirmed,
    current_rows
  );
  current_signature := atlas_core.pantry_02_signature(
    batch.week_start,
    batch.no_additions_confirmed,
    current_rows
  );
  if current_signature is distinct from batch.source_signature then
    issues := pg_catalog.jsonb_set(
      issues,
      '{blockers}',
      issues -> 'blockers' || pg_catalog.jsonb_build_array(
        atlas_core.pantry_02_issue(
          'PERSISTED_SIGNATURE_MISMATCH',
          'The persisted Pantry lines do not match the batch signature.',
          null,
          'source_signature'
        )
      )
    );
  end if;
  if pg_catalog.jsonb_array_length(issues -> 'blockers') > 0 then
    error_response := atlas_core.pa_05b_command_error(
      request,
      'INVARIANT_VIOLATION',
      'The Pantry week has blocking approval issues.',
      'PLANNING',
      command_name
    ) || pg_catalog.jsonb_build_object(
      'blockers', issues -> 'blockers',
      'warnings', issues -> 'warnings'
    );
    return atlas_core.pa_05b_finish_command(
      receipt_id,
      error_response,
      false
    );
  end if;

  version_before := batch.version;
  insert into atlas_planning.pantry_need_approval_snapshots (
    pantry_need_batch_id,
    approved_batch_version,
    approved_by_actor_id,
    approved_at,
    source_signature,
    no_additions_confirmed,
    line_count,
    blocker_summary,
    warning_summary
  ) values (
    batch.pantry_need_batch_id,
    batch.version + 1,
    actor_id,
    approved_at,
    batch.source_signature,
    batch.no_additions_confirmed,
    pg_catalog.jsonb_array_length(current_rows),
    issues -> 'blockers',
    issues -> 'warnings'
  )
  returning pantry_need_approval_snapshot_id into snapshot_id;

  insert into atlas_planning.pantry_need_approval_snapshot_lines (
    pantry_need_approval_snapshot_id,
    pantry_need_line_id,
    service_date,
    school_id,
    school_code_snapshot,
    school_name_snapshot,
    delivery_location_id,
    delivery_location_code_snapshot,
    delivery_location_name_snapshot,
    delivery_location_address_snapshot,
    ingredient_id,
    ingredient_code_snapshot,
    ingredient_name_snapshot,
    unit_id,
    unit_code_snapshot,
    unit_name_snapshot,
    pantry_need_purpose_id,
    purpose_code_snapshot,
    purpose_name_snapshot,
    purpose_description_snapshot,
    purpose_note_rule_snapshot,
    requested_quantity,
    note,
    source_request_reference,
    source_row_reference
  )
  select
    snapshot_id,
    line.pantry_need_line_id,
    line.service_date,
    line.school_id,
    school.school_code,
    school.school_name,
    line.delivery_location_id,
    location.location_code,
    location.location_name,
    location.address_text,
    line.ingredient_id,
    ingredient.ingredient_code,
    ingredient.ingredient_name,
    line.unit_id,
    unit_row.unit_code,
    unit_row.unit_name,
    line.pantry_need_purpose_id,
    purpose.purpose_code,
    purpose.purpose_name_vi,
    purpose.purpose_description,
    purpose.note_rule,
    line.requested_quantity,
    line.note,
    line.source_request_reference,
    line.source_row_reference
  from atlas_planning.pantry_need_lines line
  join atlas_admin.schools school
    on school.school_id = line.school_id
  join atlas_admin.delivery_locations location
    on location.delivery_location_id = line.delivery_location_id
  join atlas_admin.ingredients ingredient
    on ingredient.ingredient_id = line.ingredient_id
  join atlas_admin.units unit_row
    on unit_row.unit_id = line.unit_id
  join atlas_planning.pantry_need_purposes purpose
    on purpose.pantry_need_purpose_id = line.pantry_need_purpose_id
  where line.pantry_need_batch_id = batch.pantry_need_batch_id
    and line.line_status = 'ACTIVE'
  order by line.pantry_need_line_id;

  update atlas_planning.pantry_need_batches target_batch
  set
    pantry_need_batch_status = 'APPROVED',
    version = target_batch.version + 1,
    latest_approved_by_actor_id = actor_id,
    latest_approved_at = approved_at,
    latest_approval_snapshot_id = snapshot_id,
    updated_at = pg_catalog.transaction_timestamp()
  where target_batch.pantry_need_batch_id = batch.pantry_need_batch_id
  returning * into batch;

  recorded := atlas_core.pantry_02_record_change(
    'PantryApproved',
    batch.pantry_need_batch_id,
    version_before,
    batch.version,
    receipt_id,
    request,
    actor_id,
    pg_catalog.jsonb_build_object(
      'status', 'VALIDATED',
      'version', version_before
    ),
    pg_catalog.jsonb_build_object(
      'status', batch.pantry_need_batch_status,
      'version', batch.version,
      'source_signature', batch.source_signature,
      'approval_snapshot_id', snapshot_id,
      'line_count', pg_catalog.jsonb_array_length(current_rows)
    )
  );
  response := atlas_core.pantry_02_success(
    request,
    batch,
    pg_catalog.jsonb_build_array(recorded ->> 'domain_event_id'),
    pg_catalog.jsonb_build_array(recorded ->> 'audit_event_id'),
    'Pantry week approved with an immutable snapshot.',
    atlas_core.pantry_02_workbench_payload(week_start, actor_id)
  );
  return atlas_core.pa_05b_finish_command(receipt_id, response, true);
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request,
      'RETRYABLE_CONCURRENCY_FAILURE',
      'The Pantry approval could not acquire a safe transaction state. Retry the exact request.',
      'PLANNING',
      command_name,
      true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'The Pantry week could not be approved safely.',
      'PLANNING',
      command_name
    );
end
$$;

create function atlas_api.reopen_pantry(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
#variable_conflict use_variable
declare
  command_name constant text := 'reopen_pantry';
  prepared jsonb;
  actor_id uuid;
  receipt_id uuid;
  error_response jsonb;
  week_start date;
  expected_signature text;
  normalized_reason text;
  batch atlas_planning.pantry_need_batches%rowtype;
  version_before bigint;
  recorded jsonb;
  response jsonb;
begin
  prepared := atlas_core.pantry_02_prepare_command(
    request,
    command_name,
    'planning.inputs.approve',
    'PantryNeedBatch'
  );
  if prepared ->> 'status' = 'RETURN' then
    return prepared -> 'response';
  end if;
  actor_id := atlas_core.pa_05b_safe_uuid(prepared ->> 'actor_id');
  receipt_id := atlas_core.pa_05b_safe_uuid(prepared ->> 'receipt_id');
  week_start := atlas_core.pa_05d_safe_date(
    request -> 'payload' ->> 'week_start'
  );
  expected_signature := atlas_core.pantry_02_normalize_text(
    request -> 'payload' ->> 'expected_source_signature'
  );
  normalized_reason := atlas_core.pantry_02_normalize_text(
    request ->> 'reason_note'
  );
  if normalized_reason is null then
    error_response := atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'Reopening Pantry requires a non-blank reason note.',
      'PLANNING',
      command_name,
      false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field', 'reason_note',
          'message', 'A non-blank reason note is required.'
        )
      )
    );
    return atlas_core.pa_05b_finish_command(
      receipt_id,
      error_response,
      false
    );
  end if;

  select current_batch.*
    into batch
  from atlas_planning.pantry_need_batches current_batch
  where current_batch.week_start = week_start
  for update;
  if batch.pantry_need_batch_id is null then
    error_response := atlas_core.pa_05b_command_error(
      request,
      'NOT_FOUND',
      'No Pantry week exists for reopening.',
      'PLANNING',
      command_name
    );
    return atlas_core.pa_05b_finish_command(
      receipt_id,
      error_response,
      false
    );
  end if;
  if batch.version <> atlas_core.pa_05b_safe_bigint(
    request ->> 'expected_version'
  ) then
    error_response := atlas_core.pa_05b_command_error(
      request,
      'STALE_VERSION',
      'The Pantry week changed. Refresh before reopening.',
      'PLANNING',
      command_name,
      false,
      '[]'::jsonb,
      pg_catalog.jsonb_build_array(batch.pantry_need_batch_id),
      batch.version
    );
    return atlas_core.pa_05b_finish_command(
      receipt_id,
      error_response,
      false
    );
  end if;
  if expected_signature is null
    or expected_signature is distinct from batch.source_signature
  then
    error_response := atlas_core.pa_05b_command_error(
      request,
      'STALE_SOURCE_SIGNATURE',
      'The Pantry source signature changed. Refresh before reopening.',
      'PLANNING',
      command_name
    );
    return atlas_core.pa_05b_finish_command(
      receipt_id,
      error_response,
      false
    );
  end if;
  if batch.pantry_need_batch_status <> 'APPROVED' then
    error_response := atlas_core.pa_05b_command_error(
      request,
      'INVALID_LIFECYCLE_STATE',
      'Only an Approved Pantry week can be reopened.',
      'PLANNING',
      command_name
    );
    return atlas_core.pa_05b_finish_command(
      receipt_id,
      error_response,
      false
    );
  end if;

  version_before := batch.version;
  update atlas_planning.pantry_need_batches target_batch
  set
    pantry_need_batch_status = 'REOPENED',
    version = target_batch.version + 1,
    updated_at = pg_catalog.transaction_timestamp()
  where target_batch.pantry_need_batch_id = batch.pantry_need_batch_id
  returning * into batch;

  recorded := atlas_core.pantry_02_record_change(
    'PantryReopened',
    batch.pantry_need_batch_id,
    version_before,
    batch.version,
    receipt_id,
    request,
    actor_id,
    pg_catalog.jsonb_build_object(
      'status', 'APPROVED',
      'version', version_before,
      'latest_approval_snapshot_id', batch.latest_approval_snapshot_id
    ),
    pg_catalog.jsonb_build_object(
      'status', batch.pantry_need_batch_status,
      'version', batch.version,
      'latest_approval_snapshot_id', batch.latest_approval_snapshot_id,
      'reopen_reason', normalized_reason
    )
  );
  response := atlas_core.pantry_02_success(
    request,
    batch,
    pg_catalog.jsonb_build_array(recorded ->> 'domain_event_id'),
    pg_catalog.jsonb_build_array(recorded ->> 'audit_event_id'),
    'Pantry week reopened; prior approval evidence was preserved.',
    atlas_core.pantry_02_workbench_payload(week_start, actor_id)
  );
  return atlas_core.pa_05b_finish_command(receipt_id, response, true);
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request,
      'RETRYABLE_CONCURRENCY_FAILURE',
      'The Pantry reopen could not acquire a safe transaction state. Retry the exact request.',
      'PLANNING',
      command_name,
      true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'The Pantry week could not be reopened safely.',
      'PLANNING',
      command_name
    );
end
$$;

grant select on
  atlas_admin.customers,
  atlas_admin.delivery_locations,
  atlas_admin.schools,
  atlas_admin.ingredients,
  atlas_admin.units,
  atlas_planning.pantry_need_purposes,
  atlas_planning.pantry_need_batches,
  atlas_planning.pantry_need_lines,
  atlas_planning.pantry_need_approval_snapshots,
  atlas_planning.pantry_need_approval_snapshot_lines
to atlas_read_runtime;

grant select on
  atlas_admin.customers,
  atlas_admin.delivery_locations,
  atlas_admin.schools,
  atlas_admin.ingredients,
  atlas_admin.units,
  atlas_planning.pantry_need_purposes,
  atlas_planning.pantry_need_batches,
  atlas_planning.pantry_need_lines,
  atlas_planning.pantry_need_approval_snapshots,
  atlas_planning.pantry_need_approval_snapshot_lines
to atlas_planning_command_runtime;
grant insert, update on
  atlas_planning.pantry_need_batches,
  atlas_planning.pantry_need_lines
to atlas_planning_command_runtime;
grant insert on
  atlas_planning.pantry_need_approval_snapshots,
  atlas_planning.pantry_need_approval_snapshot_lines
to atlas_planning_command_runtime;

create policy pantry_02_read_purpose_select
  on atlas_planning.pantry_need_purposes
  for select to atlas_read_runtime using (true);
create policy pantry_02_read_batch_select
  on atlas_planning.pantry_need_batches
  for select to atlas_read_runtime using (true);
create policy pantry_02_read_line_select
  on atlas_planning.pantry_need_lines
  for select to atlas_read_runtime using (true);
create policy pantry_02_read_snapshot_select
  on atlas_planning.pantry_need_approval_snapshots
  for select to atlas_read_runtime using (true);
create policy pantry_02_read_snapshot_line_select
  on atlas_planning.pantry_need_approval_snapshot_lines
  for select to atlas_read_runtime using (true);

create policy pantry_02_command_purpose_select
  on atlas_planning.pantry_need_purposes
  for select to atlas_planning_command_runtime using (true);
create policy pantry_02_command_batch_select
  on atlas_planning.pantry_need_batches
  for select to atlas_planning_command_runtime using (true);
create policy pantry_02_command_batch_insert
  on atlas_planning.pantry_need_batches
  for insert to atlas_planning_command_runtime with check (true);
create policy pantry_02_command_batch_update
  on atlas_planning.pantry_need_batches
  for update to atlas_planning_command_runtime
  using (true) with check (true);
create policy pantry_02_command_line_select
  on atlas_planning.pantry_need_lines
  for select to atlas_planning_command_runtime using (true);
create policy pantry_02_command_line_insert
  on atlas_planning.pantry_need_lines
  for insert to atlas_planning_command_runtime with check (true);
create policy pantry_02_command_line_update
  on atlas_planning.pantry_need_lines
  for update to atlas_planning_command_runtime
  using (true) with check (true);
create policy pantry_02_command_snapshot_select
  on atlas_planning.pantry_need_approval_snapshots
  for select to atlas_planning_command_runtime using (true);
create policy pantry_02_command_snapshot_insert
  on atlas_planning.pantry_need_approval_snapshots
  for insert to atlas_planning_command_runtime with check (true);
create policy pantry_02_command_snapshot_line_select
  on atlas_planning.pantry_need_approval_snapshot_lines
  for select to atlas_planning_command_runtime using (true);
create policy pantry_02_command_snapshot_line_insert
  on atlas_planning.pantry_need_approval_snapshot_lines
  for insert to atlas_planning_command_runtime with check (true);

alter function atlas_planning.pantry_02_purpose_guard()
  owner to atlas_owner;
alter function atlas_planning.pantry_02_batch_guard()
  owner to atlas_owner;
alter function atlas_planning.pantry_02_line_guard()
  owner to atlas_owner;
alter function atlas_planning.pantry_02_snapshot_guard()
  owner to atlas_owner;
alter function atlas_planning.pantry_02_snapshot_integrity_guard()
  owner to atlas_owner;

alter function atlas_core.pantry_02_read_error(
  jsonb, text, text, text, jsonb
) owner to atlas_owner;
alter function atlas_core.pantry_02_validate_read_request(
  jsonb, text, boolean
) owner to atlas_owner;
alter function atlas_core.pantry_02_validate_command_request(
  jsonb, text
) owner to atlas_owner;
alter function atlas_core.pantry_02_authorize_global(
  jsonb, text, text
) owner to atlas_owner;
alter function atlas_core.pantry_02_actor_has_capability(
  uuid, text
) owner to atlas_owner;
alter function atlas_core.pantry_02_prepare_command(
  jsonb, text, text, text
) owner to atlas_owner;
alter function atlas_core.pantry_02_normalize_text(text)
  owner to atlas_owner;
alter function atlas_core.pantry_02_safe_quantity(text)
  owner to atlas_owner;
alter function atlas_core.pantry_02_sha256(jsonb)
  owner to atlas_owner;
alter function atlas_core.pantry_02_canonical_rows(date, jsonb)
  owner to atlas_owner;
alter function atlas_core.pantry_02_signature(date, boolean, jsonb)
  owner to atlas_owner;
alter function atlas_core.pantry_02_current_rows(uuid)
  owner to atlas_owner;
alter function atlas_core.pantry_02_lock_references(jsonb)
  owner to atlas_owner;
alter function atlas_core.pantry_02_issue(text, text, text, text)
  owner to atlas_owner;
alter function atlas_core.pantry_02_issues(date, boolean, jsonb)
  owner to atlas_owner;
alter function atlas_core.pantry_02_record_change(
  text, uuid, bigint, bigint, uuid, jsonb, uuid, jsonb, jsonb
) owner to atlas_owner;
alter function atlas_core.pantry_02_success(
  jsonb,
  atlas_planning.pantry_need_batches,
  jsonb,
  jsonb,
  text,
  jsonb,
  text
) owner to atlas_owner;
reset role;
grant atlas_planning_command_runtime, atlas_read_runtime
  to postgres with set true;
grant create on schema atlas_planning
  to atlas_planning_command_runtime;
alter function atlas_planning.pantry_02_snapshot_integrity_guard()
  owner to atlas_planning_command_runtime;
revoke create on schema atlas_planning
  from atlas_planning_command_runtime;

grant execute on function
  atlas_core.pa_05d_safe_date(text),
  atlas_core.pa_05b_safe_uuid(text),
  atlas_core.pa_05b_safe_bigint(text),
  atlas_core.pa_05b_resolve_actor(jsonb, text, text),
  atlas_core.pa_05b_authorize_actor(
    jsonb, uuid, text, text, text, uuid, uuid, uuid
  ),
  atlas_core.pantry_02_read_error(jsonb, text, text, text, jsonb),
  atlas_core.pantry_02_validate_read_request(jsonb, text, boolean),
  atlas_core.pantry_02_authorize_global(jsonb, text, text),
  atlas_core.pantry_02_actor_has_capability(uuid, text),
  atlas_core.pantry_02_normalize_text(text),
  atlas_core.pantry_02_safe_quantity(text),
  atlas_core.pantry_02_sha256(jsonb),
  atlas_core.pantry_02_canonical_rows(date, jsonb),
  atlas_core.pantry_02_signature(date, boolean, jsonb),
  atlas_core.pantry_02_current_rows(uuid),
  atlas_core.pantry_02_issue(text, text, text, text),
  atlas_core.pantry_02_issues(date, boolean, jsonb),
  atlas_core.pantry_02_workbench_payload(date, uuid),
  extensions.digest(bytea, text)
to atlas_read_runtime;

grant execute on function
  atlas_core.pa_05d_safe_date(text),
  atlas_core.pa_05b_safe_uuid(text),
  atlas_core.pa_05b_safe_bigint(text),
  atlas_core.pa_05b_safe_timestamptz(text),
  atlas_core.pa_05b_command_error(
    jsonb, text, text, text, text, boolean, jsonb, jsonb, bigint
  ),
  atlas_core.pa_05b_resolve_actor(jsonb, text, text),
  atlas_core.pa_05b_authorize_actor(
    jsonb, uuid, text, text, text, uuid, uuid, uuid
  ),
  atlas_core.pa_05b_begin_command(jsonb, uuid, text, text, text),
  atlas_core.pa_05b_finish_command(uuid, jsonb, boolean),
  atlas_core.pantry_02_validate_command_request(jsonb, text),
  atlas_core.pantry_02_authorize_global(jsonb, text, text),
  atlas_core.pantry_02_actor_has_capability(uuid, text),
  atlas_core.pantry_02_prepare_command(jsonb, text, text, text),
  atlas_core.pantry_02_normalize_text(text),
  atlas_core.pantry_02_safe_quantity(text),
  atlas_core.pantry_02_sha256(jsonb),
  atlas_core.pantry_02_canonical_rows(date, jsonb),
  atlas_core.pantry_02_signature(date, boolean, jsonb),
  atlas_core.pantry_02_current_rows(uuid),
  atlas_core.pantry_02_lock_references(jsonb),
  atlas_core.pantry_02_issue(text, text, text, text),
  atlas_core.pantry_02_issues(date, boolean, jsonb),
  atlas_core.pantry_02_workbench_payload(date, uuid),
  atlas_core.pantry_02_record_change(
    text, uuid, bigint, bigint, uuid, jsonb, uuid, jsonb, jsonb
  ),
  atlas_core.pantry_02_success(
    jsonb,
    atlas_planning.pantry_need_batches,
    jsonb,
    jsonb,
    text,
    jsonb,
    text
  ),
  extensions.digest(bytea, text)
to atlas_planning_command_runtime;

grant create on schema atlas_core to atlas_read_runtime;
alter function atlas_core.pantry_02_workbench_payload(date, uuid)
  owner to atlas_read_runtime;
revoke create on schema atlas_core from atlas_read_runtime;

grant create on schema atlas_api
  to atlas_planning_command_runtime, atlas_read_runtime;
alter function atlas_api.get_pantry_source_workbench(jsonb)
  owner to atlas_read_runtime;
alter function atlas_api.preview_pantry_source(jsonb)
  owner to atlas_read_runtime;
alter function atlas_api.save_pantry_draft(jsonb)
  owner to atlas_planning_command_runtime;
alter function atlas_api.validate_pantry(jsonb)
  owner to atlas_planning_command_runtime;
alter function atlas_api.approve_pantry(jsonb)
  owner to atlas_planning_command_runtime;
alter function atlas_api.reopen_pantry(jsonb)
  owner to atlas_planning_command_runtime;
revoke create on schema atlas_api
  from atlas_planning_command_runtime, atlas_read_runtime;

revoke execute on function
  atlas_planning.pantry_02_purpose_guard(),
  atlas_planning.pantry_02_batch_guard(),
  atlas_planning.pantry_02_line_guard(),
  atlas_planning.pantry_02_snapshot_guard(),
  atlas_planning.pantry_02_snapshot_integrity_guard(),
  atlas_core.pantry_02_read_error(jsonb, text, text, text, jsonb),
  atlas_core.pantry_02_validate_read_request(jsonb, text, boolean),
  atlas_core.pantry_02_validate_command_request(jsonb, text),
  atlas_core.pantry_02_authorize_global(jsonb, text, text),
  atlas_core.pantry_02_actor_has_capability(uuid, text),
  atlas_core.pantry_02_prepare_command(jsonb, text, text, text),
  atlas_core.pantry_02_normalize_text(text),
  atlas_core.pantry_02_safe_quantity(text),
  atlas_core.pantry_02_sha256(jsonb),
  atlas_core.pantry_02_canonical_rows(date, jsonb),
  atlas_core.pantry_02_signature(date, boolean, jsonb),
  atlas_core.pantry_02_current_rows(uuid),
  atlas_core.pantry_02_lock_references(jsonb),
  atlas_core.pantry_02_issue(text, text, text, text),
  atlas_core.pantry_02_issues(date, boolean, jsonb),
  atlas_core.pantry_02_workbench_payload(date, uuid),
  atlas_core.pantry_02_record_change(
    text, uuid, bigint, bigint, uuid, jsonb, uuid, jsonb, jsonb
  ),
  atlas_core.pantry_02_success(
    jsonb,
    atlas_planning.pantry_need_batches,
    jsonb,
    jsonb,
    text,
    jsonb,
    text
  )
from public, anon, authenticated, service_role;

revoke execute on function
  atlas_api.get_pantry_source_workbench(jsonb),
  atlas_api.preview_pantry_source(jsonb),
  atlas_api.save_pantry_draft(jsonb),
  atlas_api.validate_pantry(jsonb),
  atlas_api.approve_pantry(jsonb),
  atlas_api.reopen_pantry(jsonb)
from public, anon, service_role;

grant execute on function
  atlas_api.get_pantry_source_workbench(jsonb),
  atlas_api.preview_pantry_source(jsonb),
  atlas_api.save_pantry_draft(jsonb),
  atlas_api.validate_pantry(jsonb),
  atlas_api.approve_pantry(jsonb),
  atlas_api.reopen_pantry(jsonb)
to authenticated;

comment on function atlas_api.get_pantry_source_workbench(jsonb) is
  'PANTRY-02 authorized exact-week Pantry source workbench with derived reference facts, issues, approval snapshots, change history, and backend action flags.';
comment on function atlas_api.preview_pantry_source(jsonb) is
  'PANTRY-02 no-write canonical preview with backend-derived Delivery Location and purchase Unit, signature, blockers, warnings, and replacement classification.';
comment on function atlas_api.save_pantry_draft(jsonb) is
  'PANTRY-02 atomic Pantry DRAFT or REOPENED full replacement preserving stable line identities, invalidating omissions, and returning authoritative readback.';
comment on function atlas_api.validate_pantry(jsonb) is
  'PANTRY-02 authoritative Pantry validation with current-reference, exact-quantity, lifecycle, version, and signature enforcement.';
comment on function atlas_api.approve_pantry(jsonb) is
  'PANTRY-02 Pantry approval with one immutable exact every-and-only active-line snapshot and advanced batch version.';
comment on function atlas_api.reopen_pantry(jsonb) is
  'PANTRY-02 reasoned Pantry reopen preserving prior approval evidence and advancing to the next working version.';

revoke atlas_planning_command_runtime, atlas_read_runtime from postgres;

reset role;
