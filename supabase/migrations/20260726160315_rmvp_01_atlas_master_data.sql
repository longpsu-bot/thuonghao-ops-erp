-- RMVP-01: independent Atlas master-data foundation, bounded command/read API,
-- and a local-only deterministic legacy snapshot importer.

do $$
begin
  if not exists (
    select 1
    from pg_catalog.pg_roles
    where rolname = 'atlas_master_data_command_runtime'
  ) then
    create role atlas_master_data_command_runtime nologin noinherit;
  end if;
end
$$;

comment on role atlas_master_data_command_runtime is
  'RMVP-01 no-login, no-inherit SECURITY DEFINER owner for the seven reviewed master-data write commands only.';

create schema atlas_legacy;
alter schema atlas_legacy owner to atlas_owner;

comment on schema atlas_legacy is
  'Private one-way legacy snapshot migration evidence; never a live legacy integration or Data API surface.';

set role atlas_owner;

alter table atlas_admin.schools
  add column default_student_portions integer not null default 0,
  add column default_teacher_portions integer not null default 0,
  add constraint schools_default_student_portions_check
    check (default_student_portions >= 0),
  add constraint schools_default_teacher_portions_check
    check (default_teacher_portions >= 0);

alter table atlas_admin.ingredients
  drop constraint ingredients_status_check,
  add column purchase_unit_id uuid,
  add column ingredient_type text,
  add column shopping_type text,
  add column order_step numeric(20, 6),
  add constraint ingredients_purchase_unit_fkey foreign key (purchase_unit_id)
    references atlas_admin.units (unit_id) on delete restrict,
  add constraint ingredients_status_check
    check (ingredient_status in ('ACTIVE', 'INACTIVE', 'ARCHIVED')),
  add constraint ingredients_name_check check (btrim(ingredient_name) <> ''),
  add constraint ingredients_type_check
    check (ingredient_type is null or btrim(ingredient_type) <> ''),
  add constraint ingredients_shopping_type_check
    check (shopping_type is null or btrim(shopping_type) <> ''),
  add constraint ingredients_order_step_check
    check (order_step is null or order_step > 0);

create index ingredients_purchase_unit_idx
  on atlas_admin.ingredients (purchase_unit_id)
  where purchase_unit_id is not null;
create index ingredients_status_name_idx
  on atlas_admin.ingredients (ingredient_status, ingredient_name);

alter table atlas_admin.suppliers
  add column contact_name text,
  add column contact_phone text,
  add column contact_email text,
  add constraint suppliers_name_check check (btrim(supplier_name) <> ''),
  add constraint suppliers_contact_name_check
    check (contact_name is null or btrim(contact_name) <> ''),
  add constraint suppliers_contact_phone_check
    check (contact_phone is null or btrim(contact_phone) <> ''),
  add constraint suppliers_contact_email_check
    check (contact_email is null or btrim(contact_email) <> '');

create index suppliers_status_name_idx
  on atlas_admin.suppliers (supplier_status, supplier_name);

alter table atlas_admin.supplier_eligibilities
  add column priority smallint,
  add constraint supplier_eligibilities_priority_check
    check (priority is null or priority between 1 and 6);

create unique index supplier_eligibilities_active_priority_key
  on atlas_admin.supplier_eligibilities (ingredient_id, priority)
  where eligibility_status = 'ACTIVE' and priority is not null;
create index supplier_eligibilities_ingredient_priority_idx
  on atlas_admin.supplier_eligibilities (ingredient_id, priority, supplier_id)
  where eligibility_status = 'ACTIVE';

create table atlas_legacy.import_batches (
  import_batch_id uuid not null default gen_random_uuid(),
  source_system text not null,
  snapshot_id text not null,
  snapshot_checksum text not null,
  exported_at timestamptz not null,
  import_status text not null,
  source_counts jsonb not null,
  target_counts jsonb not null default '{}'::jsonb,
  mapping_counts jsonb not null default '{}'::jsonb,
  operation_counts jsonb not null default
    '{"inserted": 0, "updated": 0, "skipped": 0, "rejected": 0}'::jsonb,
  duplicate_references jsonb not null default '[]'::jsonb,
  missing_references jsonb not null default '[]'::jsonb,
  validation_errors jsonb not null default '[]'::jsonb,
  reconciliation jsonb not null default '{}'::jsonb,
  result_payload jsonb,
  started_at timestamptz not null default transaction_timestamp(),
  completed_at timestamptz,
  constraint import_batches_pkey primary key (import_batch_id),
  constraint import_batches_source_snapshot_key unique (source_system, snapshot_id),
  constraint import_batches_source_check check (btrim(source_system) <> ''),
  constraint import_batches_snapshot_check check (btrim(snapshot_id) <> ''),
  constraint import_batches_checksum_check check (length(snapshot_checksum) = 64),
  constraint import_batches_status_check
    check (import_status in ('REJECTED', 'COMPLETED')),
  constraint import_batches_completion_check check (
    completed_at is not null
  )
);

create table atlas_legacy.master_data_mappings (
  master_data_mapping_id uuid not null default gen_random_uuid(),
  import_batch_id uuid not null,
  source_system text not null,
  object_type text not null,
  legacy_id text not null,
  customer_id uuid,
  delivery_location_id uuid,
  school_type_id uuid,
  school_id uuid,
  unit_id uuid,
  ingredient_id uuid,
  supplier_id uuid,
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  constraint master_data_mappings_pkey primary key (master_data_mapping_id),
  constraint master_data_mappings_batch_fkey foreign key (import_batch_id)
    references atlas_legacy.import_batches (import_batch_id) on delete restrict,
  constraint master_data_mappings_customer_fkey foreign key (customer_id)
    references atlas_admin.customers (customer_id) on delete restrict,
  constraint master_data_mappings_location_fkey foreign key (delivery_location_id)
    references atlas_admin.delivery_locations (delivery_location_id) on delete restrict,
  constraint master_data_mappings_school_type_fkey foreign key (school_type_id)
    references atlas_admin.school_types (school_type_id) on delete restrict,
  constraint master_data_mappings_school_fkey foreign key (school_id)
    references atlas_admin.schools (school_id) on delete restrict,
  constraint master_data_mappings_unit_fkey foreign key (unit_id)
    references atlas_admin.units (unit_id) on delete restrict,
  constraint master_data_mappings_ingredient_fkey foreign key (ingredient_id)
    references atlas_admin.ingredients (ingredient_id) on delete restrict,
  constraint master_data_mappings_supplier_fkey foreign key (supplier_id)
    references atlas_admin.suppliers (supplier_id) on delete restrict,
  constraint master_data_mappings_source_key
    unique (source_system, object_type, legacy_id),
  constraint master_data_mappings_source_check check (btrim(source_system) <> ''),
  constraint master_data_mappings_legacy_id_check check (btrim(legacy_id) <> ''),
  constraint master_data_mappings_object_type_check check (
    object_type in (
      'CUSTOMER',
      'DELIVERY_LOCATION',
      'SCHOOL_TYPE',
      'SCHOOL',
      'UNIT',
      'INGREDIENT',
      'SUPPLIER'
    )
  ),
  constraint master_data_mappings_typed_target_check check (
    (
      object_type = 'CUSTOMER'
      and customer_id is not null
      and num_nonnulls(
        delivery_location_id,
        school_type_id,
        school_id,
        unit_id,
        ingredient_id,
        supplier_id
      ) = 0
    )
    or (
      object_type = 'DELIVERY_LOCATION'
      and delivery_location_id is not null
      and num_nonnulls(
        customer_id,
        school_type_id,
        school_id,
        unit_id,
        ingredient_id,
        supplier_id
      ) = 0
    )
    or (
      object_type = 'SCHOOL_TYPE'
      and school_type_id is not null
      and num_nonnulls(
        customer_id,
        delivery_location_id,
        school_id,
        unit_id,
        ingredient_id,
        supplier_id
      ) = 0
    )
    or (
      object_type = 'SCHOOL'
      and school_id is not null
      and num_nonnulls(
        customer_id,
        delivery_location_id,
        school_type_id,
        unit_id,
        ingredient_id,
        supplier_id
      ) = 0
    )
    or (
      object_type = 'UNIT'
      and unit_id is not null
      and num_nonnulls(
        customer_id,
        delivery_location_id,
        school_type_id,
        school_id,
        ingredient_id,
        supplier_id
      ) = 0
    )
    or (
      object_type = 'INGREDIENT'
      and ingredient_id is not null
      and num_nonnulls(
        customer_id,
        delivery_location_id,
        school_type_id,
        school_id,
        unit_id,
        supplier_id
      ) = 0
    )
    or (
      object_type = 'SUPPLIER'
      and supplier_id is not null
      and num_nonnulls(
        customer_id,
        delivery_location_id,
        school_type_id,
        school_id,
        unit_id,
        ingredient_id
      ) = 0
    )
  )
);

create index master_data_mappings_batch_idx
  on atlas_legacy.master_data_mappings (import_batch_id, object_type);

alter table atlas_legacy.import_batches enable row level security;
alter table atlas_legacy.import_batches force row level security;
alter table atlas_legacy.master_data_mappings enable row level security;
alter table atlas_legacy.master_data_mappings force row level security;

revoke all on schema atlas_legacy from public, anon, authenticated, service_role;
revoke all on all tables in schema atlas_legacy
  from public, anon, authenticated, service_role;

reset role;

insert into atlas_core.capabilities (
  capability_code,
  capability_name,
  owning_domain,
  capability_status
) values
  ('master_data.read', 'Read Master Data', 'ADMIN', 'ACTIVE'),
  ('master_data.schools.write', 'Maintain School Portion Defaults', 'ADMIN', 'ACTIVE'),
  ('master_data.ingredients.write', 'Maintain Ingredients', 'ADMIN', 'ACTIVE'),
  ('master_data.suppliers.write', 'Maintain Suppliers', 'ADMIN', 'ACTIVE'),
  (
    'master_data.priorities.write',
    'Replace Ingredient Supplier Priorities',
    'ADMIN',
    'ACTIVE'
  );

comment on column atlas_admin.schools.default_student_portions is
  'Current Admin-owned default student portion count used by connected master-data reads.';
comment on column atlas_admin.schools.default_teacher_portions is
  'Current Admin-owned default teacher portion count used by connected master-data reads.';
comment on column atlas_admin.ingredients.purchase_unit_id is
  'Admin-owned default purchase unit reference; downstream released facts retain their own snapshots.';
comment on column atlas_admin.supplier_eligibilities.priority is
  'Current ingredient supplier priority from 1 (highest) to 6; guidance only, never a supplier commitment.';

create or replace function atlas_core.rmvp_01_read_error(
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
    'contract_version', 'RMVP-01.v1',
    'error_code', error_code,
    'safe_message', safe_message,
    'domain', 'ADMIN',
    'read_name', read_name,
    'field_errors', coalesce(field_errors, '[]'::jsonb),
    'correlation_id', request ->> 'correlation_id'
  );
$$;

create or replace function atlas_core.rmvp_01_validate_read_request(
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
    return atlas_core.rmvp_01_read_error(
      coalesce(request, '{}'::jsonb),
      read_name,
      'VALIDATION_FAILED',
      'The read request must be a JSON object.',
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field',
          'request',
          'message',
          'A JSON object is required.'
        )
      )
    );
  end if;
  if request ->> 'contract_version' is distinct from 'RMVP-01.v1' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field',
        'contract_version',
        'message',
        'Use RMVP-01.v1.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'requested_by_auth_subject') is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field',
        'requested_by_auth_subject',
        'message',
        'A valid UUID is required.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id') is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field',
        'correlation_id',
        'message',
        'A valid UUID is required.'
      )
    );
  end if;
  if request -> 'payload' is null
     or pg_catalog.jsonb_typeof(request -> 'payload') <> 'object' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field',
        'payload',
        'message',
        'A JSON object is required.'
      )
    );
  end if;
  if pg_catalog.jsonb_array_length(v_errors) > 0 then
    return atlas_core.rmvp_01_read_error(
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

create or replace function atlas_core.rmvp_01_authorize_global(
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
    'ADMIN',
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
    'ADMIN',
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

create or replace function atlas_core.rmvp_01_record_change(
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
    'ADMIN',
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
    'ADMIN',
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
    'domain_event_id',
    v_domain_event_id,
    'audit_event_id',
    v_audit_event_id
  );
end;
$$;

create or replace function atlas_api.get_school_master_data(request jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'get_school_master_data';
  v_error jsonb;
  v_context jsonb;
  v_items jsonb;
begin
  v_error := atlas_core.rmvp_01_validate_read_request(request, v_name);
  if v_error is not null then return v_error; end if;
  v_context := atlas_core.rmvp_01_authorize_global(
    request,
    'master_data.read',
    v_name
  );
  if v_context ? 'error' then return v_context -> 'error'; end if;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'school_id', s.school_id,
        'school_code', s.school_code,
        'school_name', s.school_name,
        'school_status', s.school_status,
        'version', s.version,
        'display_order', s.display_order,
        'default_student_portions', s.default_student_portions,
        'default_teacher_portions', s.default_teacher_portions,
        'school_type_id', st.school_type_id,
        'school_type_name', st.school_type_name,
        'customer_id', c.customer_id,
        'customer_code', c.customer_code,
        'customer_name', c.customer_name,
        'delivery_location_id', dl.delivery_location_id,
        'delivery_location_name', dl.location_name,
        'delivery_address', dl.address_text,
        'delivery_instructions', dl.delivery_instructions,
        'contract_context', s.operational_notes
      )
      order by s.display_order, s.school_name, s.school_id
    ),
    '[]'::jsonb
  )
  into v_items
  from atlas_admin.schools s
  join atlas_admin.customers c on c.customer_id = s.customer_id
  join atlas_admin.delivery_locations dl
    on dl.delivery_location_id = s.default_delivery_location_id
  left join atlas_admin.school_types st on st.school_type_id = s.school_type_id;

  return pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RMVP-01.v1',
    'correlation_id', request ->> 'correlation_id',
    'schools', v_items,
    'safe_operator_message', 'Authorized school master data returned.'
  );
exception when others then
  return atlas_core.rmvp_01_read_error(
    request,
    v_name,
    'INTERNAL_READ_FAILURE',
    'School master data could not be returned safely.'
  );
end;
$$;

create or replace function atlas_api.get_ingredient_supplier_master_data(request jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'get_ingredient_supplier_master_data';
  v_error jsonb;
  v_context jsonb;
  v_ingredients jsonb;
  v_suppliers jsonb;
  v_units jsonb;
begin
  v_error := atlas_core.rmvp_01_validate_read_request(request, v_name);
  if v_error is not null then return v_error; end if;
  v_context := atlas_core.rmvp_01_authorize_global(
    request,
    'master_data.read',
    v_name
  );
  if v_context ? 'error' then return v_context -> 'error'; end if;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'ingredient_id', i.ingredient_id,
        'ingredient_code', i.ingredient_code,
        'ingredient_name', i.ingredient_name,
        'ingredient_status', i.ingredient_status,
        'ingredient_type', i.ingredient_type,
        'shopping_type', i.shopping_type,
        'purchase_unit_id', i.purchase_unit_id,
        'purchase_unit_code', u.unit_code,
        'purchase_unit_name', u.unit_name,
        'order_step', i.order_step,
        'version', i.version,
        'supplier_priorities',
        coalesce(
          (
            select pg_catalog.jsonb_agg(
              pg_catalog.jsonb_build_object(
                'supplier_eligibility_id', se.supplier_eligibility_id,
                'supplier_id', sp.supplier_id,
                'supplier_name', sp.supplier_name,
                'priority', se.priority
              )
              order by se.priority, sp.supplier_name, sp.supplier_id
            )
            from atlas_admin.supplier_eligibilities se
            join atlas_admin.suppliers sp on sp.supplier_id = se.supplier_id
            where se.ingredient_id = i.ingredient_id
              and se.eligibility_status = 'ACTIVE'
              and se.priority is not null
          ),
          '[]'::jsonb
        )
      )
      order by i.ingredient_name, i.ingredient_id
    ),
    '[]'::jsonb
  )
  into v_ingredients
  from atlas_admin.ingredients i
  left join atlas_admin.units u on u.unit_id = i.purchase_unit_id;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'supplier_id', s.supplier_id,
        'supplier_code', s.supplier_code,
        'supplier_name', s.supplier_name,
        'supplier_status', s.supplier_status,
        'contact_name', s.contact_name,
        'contact_phone', s.contact_phone,
        'contact_email', s.contact_email,
        'version', s.version
      )
      order by s.supplier_name, s.supplier_id
    ),
    '[]'::jsonb
  )
  into v_suppliers
  from atlas_admin.suppliers s;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'unit_id', u.unit_id,
        'unit_code', u.unit_code,
        'unit_name', u.unit_name,
        'unit_status', u.unit_status
      )
      order by u.unit_name, u.unit_id
    ),
    '[]'::jsonb
  )
  into v_units
  from atlas_admin.units u;

  return pg_catalog.jsonb_build_object(
    'success', true,
    'contract_version', 'RMVP-01.v1',
    'correlation_id', request ->> 'correlation_id',
    'ingredients', v_ingredients,
    'suppliers', v_suppliers,
    'units', v_units,
    'safe_operator_message', 'Authorized ingredient and supplier master data returned.'
  );
exception when others then
  return atlas_core.rmvp_01_read_error(
    request,
    v_name,
    'INTERNAL_READ_FAILURE',
    'Ingredient and supplier master data could not be returned safely.'
  );
end;
$$;

create or replace function atlas_core.rmvp_01_validate_command_request(
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
      'ADMIN',
      command_name,
      false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field',
          'request',
          'message',
          'A JSON object is required.'
        )
      )
    );
  end if;
  if request ->> 'contract_version' is distinct from 'RMVP-01.v1' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field',
        'contract_version',
        'message',
        'Use RMVP-01.v1.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'command_id') is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field',
        'command_id',
        'message',
        'A valid UUID is required.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'correlation_id') is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field',
        'correlation_id',
        'message',
        'A valid UUID is required.'
      )
    );
  end if;
  if pg_catalog.btrim(coalesce(request ->> 'idempotency_key', '')) = ''
     or pg_catalog.length(request ->> 'idempotency_key') > 200 then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field',
        'idempotency_key',
        'message',
        'A non-empty key of at most 200 characters is required.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') is null
     or atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') <= 0 then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field',
        'expected_version',
        'message',
        'A positive integer version is required.'
      )
    );
  end if;
  if atlas_core.pa_05b_safe_uuid(request ->> 'requested_by_auth_subject') is null then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field',
        'requested_by_auth_subject',
        'message',
        'A valid UUID is required.'
      )
    );
  end if;
  v_requested_at := atlas_core.pa_05b_safe_timestamptz(request ->> 'requested_at');
  if v_requested_at is null or v_requested_at > pg_catalog.transaction_timestamp() then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field',
        'requested_at',
        'message',
        'A valid non-future timestamp is required.'
      )
    );
  end if;
  if pg_catalog.btrim(coalesce(request ->> 'reason_code', '')) = '' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field',
        'reason_code',
        'message',
        'A reason code is required.'
      )
    );
  end if;
  if not (request ? 'reason_note') then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field',
        'reason_note',
        'message',
        'The reason_note field is required and may be null.'
      )
    );
  end if;
  if request -> 'payload' is null
     or pg_catalog.jsonb_typeof(request -> 'payload') <> 'object' then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field',
        'payload',
        'message',
        'A JSON object is required.'
      )
    );
  end if;
  if pg_catalog.jsonb_array_length(v_errors) > 0 then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'The command envelope is invalid.',
      'ADMIN',
      command_name,
      false,
      v_errors
    );
  end if;
  return null;
end;
$$;

create or replace function atlas_core.rmvp_01_prepare_command(
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
  v_error := atlas_core.rmvp_01_validate_command_request(request, command_name);
  if v_error is not null then
    return pg_catalog.jsonb_build_object('status', 'RETURN', 'response', v_error);
  end if;
  v_context := atlas_core.rmvp_01_authorize_global(
    request,
    capability_code,
    command_name
  );
  if v_context ? 'error' then
    return pg_catalog.jsonb_build_object(
      'status',
      'RETURN',
      'response',
      v_context -> 'error'
    );
  end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_context ->> 'actor_id');
  v_begin := atlas_core.pa_05b_begin_command(
    request,
    v_actor_id,
    command_name,
    'ADMIN',
    aggregate_scope
  );
  if v_begin ->> 'status' in ('REPLAY', 'ERROR') then
    return pg_catalog.jsonb_build_object(
      'status',
      'RETURN',
      'response',
      v_begin -> 'response'
    );
  end if;
  return pg_catalog.jsonb_build_object(
    'status',
    'READY',
    'actor_id',
    v_actor_id,
    'receipt_id',
    v_begin ->> 'receipt_id'
  );
end;
$$;

create or replace function atlas_core.rmvp_01_finish_success(
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
  affected_aggregate_ids jsonb
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
  v_events := atlas_core.rmvp_01_record_change(
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
    'contract_version', 'RMVP-01.v1',
    'command_id', request ->> 'command_id',
    'correlation_id', request ->> 'correlation_id',
    'idempotency_status', 'COMPLETED',
    'affected_aggregate_ids', affected_aggregate_ids,
    'new_versions', pg_catalog.jsonb_build_object(
      'aggregate_version',
      version_after
    ),
    'emitted_event_ids', pg_catalog.jsonb_build_array(
      v_events -> 'domain_event_id'
    ),
    'audit_event_ids', pg_catalog.jsonb_build_array(
      v_events -> 'audit_event_id'
    ),
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

create or replace function atlas_api.update_school_portion_defaults(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'update_school_portion_defaults';
  v_payload jsonb := request -> 'payload';
  v_school_id uuid;
  v_student integer;
  v_teacher integer;
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_school atlas_admin.schools%rowtype;
  v_before jsonb;
  v_after jsonb;
begin
  if atlas_core.rmvp_01_validate_command_request(request, v_name) is not null then
    return atlas_core.rmvp_01_validate_command_request(request, v_name);
  end if;
  v_school_id := atlas_core.pa_05b_safe_uuid(v_payload ->> 'school_id');
  begin
    v_student := (v_payload ->> 'default_student_portions')::integer;
    v_teacher := (v_payload ->> 'default_teacher_portions')::integer;
  exception when others then
    v_student := null;
    v_teacher := null;
  end;
  if v_school_id is null or v_student is null or v_teacher is null
     or v_student < 0 or v_teacher < 0 then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'School portion defaults are incomplete or invalid.',
      'ADMIN',
      v_name,
      false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field',
          'payload',
          'message',
          'school_id and non-negative integer student and teacher defaults are required.'
        )
      )
    );
  end if;
  v_prepare := atlas_core.rmvp_01_prepare_command(
    request,
    v_name,
    'master_data.schools.write',
    'school:' || v_school_id::text
  );
  if v_prepare ->> 'status' = 'RETURN' then return v_prepare -> 'response'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');

  select * into v_school
  from atlas_admin.schools
  where school_id = v_school_id
  for update;
  if not found then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'NOT_FOUND', 'The school was not found.', 'ADMIN', v_name
      ),
      false
    );
  end if;
  if v_school.version <> atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'STALE_VERSION',
        'The school changed after it was read. Refresh before saving.',
        'ADMIN',
        v_name,
        false,
        '[]'::jsonb,
        '[]'::jsonb,
        v_school.version
      ),
      false
    );
  end if;
  v_before := pg_catalog.jsonb_build_object(
    'default_student_portions', v_school.default_student_portions,
    'default_teacher_portions', v_school.default_teacher_portions
  );
  update atlas_admin.schools
  set default_student_portions = v_student,
      default_teacher_portions = v_teacher,
      version = version + 1,
      updated_at = pg_catalog.transaction_timestamp()
  where school_id = v_school_id;
  v_after := pg_catalog.jsonb_build_object(
    'default_student_portions', v_student,
    'default_teacher_portions', v_teacher
  );
  return atlas_core.rmvp_01_finish_success(
    request, v_actor_id, v_receipt_id, 'SchoolPortionDefaultsUpdated',
    'School', v_school_id, v_school.version, v_school.version + 1,
    v_before, v_after, 'School portion defaults saved.',
    pg_catalog.jsonb_build_object('school_id', v_school_id)
  );
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request,
      'RETRYABLE_CONCURRENCY_FAILURE',
      'The school could not be locked safely. Retry the exact request.',
      'ADMIN',
      v_name,
      true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request,
      'INTERNAL_COMMAND_FAILURE',
      'The school defaults could not be saved safely.',
      'ADMIN',
      v_name
    );
end;
$$;

create or replace function atlas_api.create_ingredient(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'create_ingredient';
  v_payload jsonb := request -> 'payload';
  v_code text := pg_catalog.lower(pg_catalog.btrim(coalesce(v_payload ->> 'ingredient_code', '')));
  v_ingredient_name text := pg_catalog.btrim(coalesce(v_payload ->> 'ingredient_name', ''));
  v_ingredient_type text := pg_catalog.btrim(coalesce(v_payload ->> 'ingredient_type', ''));
  v_shopping_type text := pg_catalog.btrim(coalesce(v_payload ->> 'shopping_type', ''));
  v_unit_id uuid := atlas_core.pa_05b_safe_uuid(v_payload ->> 'purchase_unit_id');
  v_order_step numeric := atlas_core.pa_05b_safe_numeric(v_payload ->> 'order_step');
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_ingredient_id uuid;
begin
  if atlas_core.rmvp_01_validate_command_request(request, v_name) is not null then
    return atlas_core.rmvp_01_validate_command_request(request, v_name);
  end if;
  if atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') <> 1
     or v_code = '' or v_ingredient_name = '' or v_ingredient_type = ''
     or v_shopping_type = '' or v_unit_id is null or v_order_step is null
     or v_order_step <= 0 then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'Ingredient values are incomplete or invalid.',
      'ADMIN',
      v_name,
      false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field',
          'payload',
          'message',
          'code, name, purchase unit, ingredient type, shopping type, and a positive order step are required; create uses expected_version 1.'
        )
      )
    );
  end if;
  v_prepare := atlas_core.rmvp_01_prepare_command(
    request,
    v_name,
    'master_data.ingredients.write',
    'ingredient-code:' || v_code
  );
  if v_prepare ->> 'status' = 'RETURN' then return v_prepare -> 'response'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  if not exists (
    select 1
    from atlas_admin.units
    where unit_id = v_unit_id and unit_status = 'ACTIVE'
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'VALIDATION_FAILED', 'The purchase unit is not active.', 'ADMIN', v_name
      ),
      false
    );
  end if;
  insert into atlas_admin.ingredients (
    ingredient_code,
    ingredient_name,
    ingredient_group,
    purchase_unit_id,
    ingredient_type,
    shopping_type,
    order_step
  ) values (
    v_code,
    v_ingredient_name,
    v_ingredient_type,
    v_unit_id,
    v_ingredient_type,
    v_shopping_type,
    v_order_step
  )
  returning ingredient_id into v_ingredient_id;
  return atlas_core.rmvp_01_finish_success(
    request, v_actor_id, v_receipt_id, 'IngredientCreated',
    'Ingredient', v_ingredient_id, null, 1, null,
    pg_catalog.jsonb_build_object(
      'ingredient_code', v_code,
      'ingredient_name', v_ingredient_name,
      'ingredient_status', 'ACTIVE',
      'purchase_unit_id', v_unit_id,
      'ingredient_type', v_ingredient_type,
      'shopping_type', v_shopping_type,
      'order_step', v_order_step
    ),
    'Ingredient created.',
    pg_catalog.jsonb_build_object('ingredient_id', v_ingredient_id)
  );
exception
  when unique_violation then
    return atlas_core.pa_05b_command_error(
      request, 'CONFLICT', 'The ingredient code is already in use.', 'ADMIN', v_name
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request, 'INTERNAL_COMMAND_FAILURE', 'The ingredient could not be created safely.', 'ADMIN', v_name
    );
end;
$$;

create or replace function atlas_api.update_ingredient(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'update_ingredient';
  v_payload jsonb := request -> 'payload';
  v_ingredient_id uuid := atlas_core.pa_05b_safe_uuid(v_payload ->> 'ingredient_id');
  v_ingredient_name text := pg_catalog.btrim(coalesce(v_payload ->> 'ingredient_name', ''));
  v_ingredient_type text := pg_catalog.btrim(coalesce(v_payload ->> 'ingredient_type', ''));
  v_shopping_type text := pg_catalog.btrim(coalesce(v_payload ->> 'shopping_type', ''));
  v_unit_id uuid := atlas_core.pa_05b_safe_uuid(v_payload ->> 'purchase_unit_id');
  v_order_step numeric := atlas_core.pa_05b_safe_numeric(v_payload ->> 'order_step');
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_ingredient atlas_admin.ingredients%rowtype;
  v_before jsonb;
  v_after jsonb;
begin
  if atlas_core.rmvp_01_validate_command_request(request, v_name) is not null then
    return atlas_core.rmvp_01_validate_command_request(request, v_name);
  end if;
  if v_ingredient_id is null or v_ingredient_name = '' or v_ingredient_type = ''
     or v_shopping_type = '' or v_unit_id is null or v_order_step is null
     or v_order_step <= 0 then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'Ingredient values are incomplete or invalid.',
      'ADMIN',
      v_name,
      false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field',
          'payload',
          'message',
          'ingredient_id, name, purchase unit, ingredient type, shopping type, and a positive order step are required.'
        )
      )
    );
  end if;
  v_prepare := atlas_core.rmvp_01_prepare_command(
    request,
    v_name,
    'master_data.ingredients.write',
    'ingredient:' || v_ingredient_id::text
  );
  if v_prepare ->> 'status' = 'RETURN' then return v_prepare -> 'response'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');

  select * into v_ingredient
  from atlas_admin.ingredients
  where ingredient_id = v_ingredient_id
  for update;
  if not found then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'NOT_FOUND', 'The ingredient was not found.', 'ADMIN', v_name
      ),
      false
    );
  end if;
  if v_ingredient.version <> atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'STALE_VERSION',
        'The ingredient changed after it was read. Refresh before saving.',
        'ADMIN',
        v_name,
        false,
        '[]'::jsonb,
        '[]'::jsonb,
        v_ingredient.version
      ),
      false
    );
  end if;
  if v_ingredient.ingredient_status = 'ARCHIVED' then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'INVARIANT_VIOLATION', 'Archived ingredients cannot be edited.', 'ADMIN', v_name
      ),
      false
    );
  end if;
  if not exists (
    select 1
    from atlas_admin.units
    where unit_id = v_unit_id and unit_status = 'ACTIVE'
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'VALIDATION_FAILED', 'The purchase unit is not active.', 'ADMIN', v_name
      ),
      false
    );
  end if;
  v_before := pg_catalog.jsonb_build_object(
    'ingredient_name', v_ingredient.ingredient_name,
    'purchase_unit_id', v_ingredient.purchase_unit_id,
    'ingredient_type', v_ingredient.ingredient_type,
    'shopping_type', v_ingredient.shopping_type,
    'order_step', v_ingredient.order_step,
    'ingredient_status', v_ingredient.ingredient_status
  );
  update atlas_admin.ingredients
  set ingredient_name = v_ingredient_name,
      ingredient_group = v_ingredient_type,
      purchase_unit_id = v_unit_id,
      ingredient_type = v_ingredient_type,
      shopping_type = v_shopping_type,
      order_step = v_order_step,
      version = version + 1,
      updated_at = pg_catalog.transaction_timestamp()
  where ingredient_id = v_ingredient_id;
  v_after := pg_catalog.jsonb_build_object(
    'ingredient_name', v_ingredient_name,
    'purchase_unit_id', v_unit_id,
    'ingredient_type', v_ingredient_type,
    'shopping_type', v_shopping_type,
    'order_step', v_order_step,
    'ingredient_status', v_ingredient.ingredient_status
  );
  return atlas_core.rmvp_01_finish_success(
    request, v_actor_id, v_receipt_id, 'IngredientUpdated',
    'Ingredient', v_ingredient_id, v_ingredient.version, v_ingredient.version + 1,
    v_before, v_after, 'Ingredient saved.',
    pg_catalog.jsonb_build_object('ingredient_id', v_ingredient_id)
  );
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request, 'RETRYABLE_CONCURRENCY_FAILURE',
      'The ingredient could not be locked safely. Retry the exact request.',
      'ADMIN', v_name, true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request, 'INTERNAL_COMMAND_FAILURE', 'The ingredient could not be saved safely.', 'ADMIN', v_name
    );
end;
$$;

create or replace function atlas_api.set_ingredient_lifecycle(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'set_ingredient_lifecycle';
  v_payload jsonb := request -> 'payload';
  v_ingredient_id uuid := atlas_core.pa_05b_safe_uuid(v_payload ->> 'ingredient_id');
  v_status text := pg_catalog.upper(pg_catalog.btrim(coalesce(v_payload ->> 'ingredient_status', '')));
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_ingredient atlas_admin.ingredients%rowtype;
begin
  if atlas_core.rmvp_01_validate_command_request(request, v_name) is not null then
    return atlas_core.rmvp_01_validate_command_request(request, v_name);
  end if;
  if v_ingredient_id is null or v_status not in ('ACTIVE', 'INACTIVE', 'ARCHIVED') then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'The ingredient lifecycle request is invalid.',
      'ADMIN',
      v_name,
      false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field',
          'payload.ingredient_status',
          'message',
          'Use ACTIVE, INACTIVE, or ARCHIVED.'
        )
      )
    );
  end if;
  v_prepare := atlas_core.rmvp_01_prepare_command(
    request,
    v_name,
    'master_data.ingredients.write',
    'ingredient:' || v_ingredient_id::text
  );
  if v_prepare ->> 'status' = 'RETURN' then return v_prepare -> 'response'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  select * into v_ingredient
  from atlas_admin.ingredients
  where ingredient_id = v_ingredient_id
  for update;
  if not found then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'NOT_FOUND', 'The ingredient was not found.', 'ADMIN', v_name
      ),
      false
    );
  end if;
  if v_ingredient.version <> atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'STALE_VERSION',
        'The ingredient changed after it was read. Refresh before saving.',
        'ADMIN', v_name, false, '[]'::jsonb, '[]'::jsonb, v_ingredient.version
      ),
      false
    );
  end if;
  if v_ingredient.ingredient_status = 'ARCHIVED' and v_status <> 'ARCHIVED' then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'INVARIANT_VIOLATION',
        'Archived ingredients are retained for traceability and cannot be reactivated.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  if v_status = 'ACTIVE' and (
    v_ingredient.purchase_unit_id is null
    or v_ingredient.ingredient_type is null
    or v_ingredient.shopping_type is null
    or v_ingredient.order_step is null
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request,
        'INVARIANT_VIOLATION',
        'The ingredient must have complete purchasing fields before activation.',
        'ADMIN',
        v_name
      ),
      false
    );
  end if;
  update atlas_admin.ingredients
  set ingredient_status = v_status,
      version = version + 1,
      updated_at = pg_catalog.transaction_timestamp()
  where ingredient_id = v_ingredient_id;
  if v_status <> 'ACTIVE' then
    update atlas_admin.supplier_eligibilities
    set eligibility_status = 'INACTIVE',
        effective_to = greatest(
          current_date,
          effective_from + 1
        ),
        version = version + 1,
        updated_at = pg_catalog.transaction_timestamp()
    where ingredient_id = v_ingredient_id
      and eligibility_status = 'ACTIVE';
  end if;
  return atlas_core.rmvp_01_finish_success(
    request, v_actor_id, v_receipt_id, 'IngredientLifecycleChanged',
    'Ingredient', v_ingredient_id, v_ingredient.version, v_ingredient.version + 1,
    pg_catalog.jsonb_build_object('ingredient_status', v_ingredient.ingredient_status),
    pg_catalog.jsonb_build_object('ingredient_status', v_status),
    'Ingredient lifecycle saved without deleting referenced history.',
    pg_catalog.jsonb_build_object('ingredient_id', v_ingredient_id)
  );
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request, 'RETRYABLE_CONCURRENCY_FAILURE',
      'The ingredient could not be locked safely. Retry the exact request.',
      'ADMIN', v_name, true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request, 'INTERNAL_COMMAND_FAILURE',
      'The ingredient lifecycle could not be saved safely.', 'ADMIN', v_name
    );
end;
$$;

create or replace function atlas_api.create_supplier(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'create_supplier';
  v_payload jsonb := request -> 'payload';
  v_code text := pg_catalog.lower(pg_catalog.btrim(coalesce(v_payload ->> 'supplier_code', '')));
  v_supplier_name text := pg_catalog.btrim(coalesce(v_payload ->> 'supplier_name', ''));
  v_contact_name text := nullif(pg_catalog.btrim(coalesce(v_payload ->> 'contact_name', '')), '');
  v_contact_phone text := nullif(pg_catalog.btrim(coalesce(v_payload ->> 'contact_phone', '')), '');
  v_contact_email text := nullif(pg_catalog.btrim(coalesce(v_payload ->> 'contact_email', '')), '');
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_supplier_id uuid;
begin
  if atlas_core.rmvp_01_validate_command_request(request, v_name) is not null then
    return atlas_core.rmvp_01_validate_command_request(request, v_name);
  end if;
  if atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') <> 1
     or v_code = '' or v_supplier_name = '' then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'Supplier values are incomplete or invalid.',
      'ADMIN',
      v_name,
      false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field',
          'payload',
          'message',
          'supplier_code and supplier_name are required; create uses expected_version 1.'
        )
      )
    );
  end if;
  v_prepare := atlas_core.rmvp_01_prepare_command(
    request,
    v_name,
    'master_data.suppliers.write',
    'supplier-code:' || v_code
  );
  if v_prepare ->> 'status' = 'RETURN' then return v_prepare -> 'response'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  insert into atlas_admin.suppliers (
    supplier_code,
    supplier_name,
    contact_name,
    contact_phone,
    contact_email
  ) values (
    v_code,
    v_supplier_name,
    v_contact_name,
    v_contact_phone,
    v_contact_email
  )
  returning supplier_id into v_supplier_id;
  return atlas_core.rmvp_01_finish_success(
    request, v_actor_id, v_receipt_id, 'SupplierCreated',
    'Supplier', v_supplier_id, null, 1, null,
    pg_catalog.jsonb_build_object(
      'supplier_code', v_code,
      'supplier_name', v_supplier_name,
      'supplier_status', 'ACTIVE',
      'contact_name', v_contact_name,
      'contact_phone', v_contact_phone,
      'contact_email', v_contact_email
    ),
    'Supplier created.',
    pg_catalog.jsonb_build_object('supplier_id', v_supplier_id)
  );
exception
  when unique_violation then
    return atlas_core.pa_05b_command_error(
      request, 'CONFLICT', 'The supplier code is already in use.', 'ADMIN', v_name
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request, 'INTERNAL_COMMAND_FAILURE', 'The supplier could not be created safely.', 'ADMIN', v_name
    );
end;
$$;

create or replace function atlas_api.update_supplier(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'update_supplier';
  v_payload jsonb := request -> 'payload';
  v_supplier_id uuid := atlas_core.pa_05b_safe_uuid(v_payload ->> 'supplier_id');
  v_supplier_name text := pg_catalog.btrim(coalesce(v_payload ->> 'supplier_name', ''));
  v_contact_name text := nullif(pg_catalog.btrim(coalesce(v_payload ->> 'contact_name', '')), '');
  v_contact_phone text := nullif(pg_catalog.btrim(coalesce(v_payload ->> 'contact_phone', '')), '');
  v_contact_email text := nullif(pg_catalog.btrim(coalesce(v_payload ->> 'contact_email', '')), '');
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_supplier atlas_admin.suppliers%rowtype;
  v_before jsonb;
  v_after jsonb;
begin
  if atlas_core.rmvp_01_validate_command_request(request, v_name) is not null then
    return atlas_core.rmvp_01_validate_command_request(request, v_name);
  end if;
  if v_supplier_id is null or v_supplier_name = '' then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'Supplier values are incomplete or invalid.',
      'ADMIN',
      v_name,
      false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field',
          'payload',
          'message',
          'supplier_id and supplier_name are required.'
        )
      )
    );
  end if;
  v_prepare := atlas_core.rmvp_01_prepare_command(
    request,
    v_name,
    'master_data.suppliers.write',
    'supplier:' || v_supplier_id::text
  );
  if v_prepare ->> 'status' = 'RETURN' then return v_prepare -> 'response'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  select * into v_supplier
  from atlas_admin.suppliers
  where supplier_id = v_supplier_id
  for update;
  if not found then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'NOT_FOUND', 'The supplier was not found.', 'ADMIN', v_name
      ),
      false
    );
  end if;
  if v_supplier.version <> atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'STALE_VERSION',
        'The supplier changed after it was read. Refresh before saving.',
        'ADMIN', v_name, false, '[]'::jsonb, '[]'::jsonb, v_supplier.version
      ),
      false
    );
  end if;
  v_before := pg_catalog.jsonb_build_object(
    'supplier_name', v_supplier.supplier_name,
    'contact_name', v_supplier.contact_name,
    'contact_phone', v_supplier.contact_phone,
    'contact_email', v_supplier.contact_email,
    'supplier_status', v_supplier.supplier_status
  );
  update atlas_admin.suppliers
  set supplier_name = v_supplier_name,
      contact_name = v_contact_name,
      contact_phone = v_contact_phone,
      contact_email = v_contact_email,
      version = version + 1,
      updated_at = pg_catalog.transaction_timestamp()
  where supplier_id = v_supplier_id;
  v_after := pg_catalog.jsonb_build_object(
    'supplier_name', v_supplier_name,
    'contact_name', v_contact_name,
    'contact_phone', v_contact_phone,
    'contact_email', v_contact_email,
    'supplier_status', v_supplier.supplier_status
  );
  return atlas_core.rmvp_01_finish_success(
    request, v_actor_id, v_receipt_id, 'SupplierUpdated',
    'Supplier', v_supplier_id, v_supplier.version, v_supplier.version + 1,
    v_before, v_after, 'Supplier saved.',
    pg_catalog.jsonb_build_object('supplier_id', v_supplier_id)
  );
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request, 'RETRYABLE_CONCURRENCY_FAILURE',
      'The supplier could not be locked safely. Retry the exact request.',
      'ADMIN', v_name, true
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request, 'INTERNAL_COMMAND_FAILURE', 'The supplier could not be saved safely.', 'ADMIN', v_name
    );
end;
$$;

create or replace function atlas_api.replace_ingredient_supplier_priorities(request jsonb)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_name constant text := 'replace_ingredient_supplier_priorities';
  v_payload jsonb := request -> 'payload';
  v_ingredient_id uuid := atlas_core.pa_05b_safe_uuid(v_payload ->> 'ingredient_id');
  v_priorities jsonb := v_payload -> 'priorities';
  v_prepare jsonb;
  v_actor_id uuid;
  v_receipt_id uuid;
  v_ingredient atlas_admin.ingredients%rowtype;
  v_row record;
  v_before jsonb;
  v_after jsonb;
  v_count integer;
  v_distinct_suppliers integer;
  v_distinct_priorities integer;
  v_invalid_count integer;
begin
  if atlas_core.rmvp_01_validate_command_request(request, v_name) is not null then
    return atlas_core.rmvp_01_validate_command_request(request, v_name);
  end if;
  if v_ingredient_id is null or v_priorities is null
     or pg_catalog.jsonb_typeof(v_priorities) <> 'array' then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'The supplier priority replacement is invalid.',
      'ADMIN',
      v_name,
      false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field',
          'payload.priorities',
          'message',
          'An array with at most six supplier_id and priority entries is required.'
        )
      )
    );
  end if;
  select
    count(*)::integer,
    count(distinct atlas_core.pa_05b_safe_uuid(value ->> 'supplier_id'))::integer,
    count(distinct atlas_core.pa_05b_safe_bigint(value ->> 'priority'))::integer,
    count(*) filter (
      where atlas_core.pa_05b_safe_uuid(value ->> 'supplier_id') is null
        or atlas_core.pa_05b_safe_bigint(value ->> 'priority') not between 1 and 6
    )::integer
  into v_count, v_distinct_suppliers, v_distinct_priorities, v_invalid_count
  from pg_catalog.jsonb_array_elements(v_priorities);
  if v_count > 6 or v_distinct_suppliers <> v_count
     or v_distinct_priorities <> v_count or v_invalid_count > 0 then
    return atlas_core.pa_05b_command_error(
      request,
      'VALIDATION_FAILED',
      'Supplier priorities must be unique and within the supported range.',
      'ADMIN',
      v_name,
      false,
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'field',
          'payload.priorities',
          'message',
          'Use no more than six unique suppliers and unique integer priorities from 1 through 6.'
        )
      )
    );
  end if;
  v_prepare := atlas_core.rmvp_01_prepare_command(
    request,
    v_name,
    'master_data.priorities.write',
    'ingredient-priorities:' || v_ingredient_id::text
  );
  if v_prepare ->> 'status' = 'RETURN' then return v_prepare -> 'response'; end if;
  v_actor_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'actor_id');
  v_receipt_id := atlas_core.pa_05b_safe_uuid(v_prepare ->> 'receipt_id');
  select * into v_ingredient
  from atlas_admin.ingredients
  where ingredient_id = v_ingredient_id
  for update;
  if not found then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'NOT_FOUND', 'The ingredient was not found.', 'ADMIN', v_name
      ),
      false
    );
  end if;
  if v_ingredient.version <> atlas_core.pa_05b_safe_bigint(request ->> 'expected_version') then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'STALE_VERSION',
        'The ingredient changed after it was read. Refresh before saving priorities.',
        'ADMIN', v_name, false, '[]'::jsonb, '[]'::jsonb, v_ingredient.version
      ),
      false
    );
  end if;
  if v_ingredient.ingredient_status <> 'ACTIVE' then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'INVARIANT_VIOLATION',
        'Supplier priorities can only be assigned to an active ingredient.',
        'ADMIN', v_name
      ),
      false
    );
  end if;
  if exists (
    select 1
    from pg_catalog.jsonb_array_elements(v_priorities) item
    left join atlas_admin.suppliers s
      on s.supplier_id = atlas_core.pa_05b_safe_uuid(item ->> 'supplier_id')
    where s.supplier_id is null or s.supplier_status <> 'ACTIVE'
  ) then
    return atlas_core.pa_05b_finish_command(
      v_receipt_id,
      atlas_core.pa_05b_command_error(
        request, 'VALIDATION_FAILED',
        'Every selected supplier must exist and be active.', 'ADMIN', v_name
      ),
      false
    );
  end if;
  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'supplier_id', supplier_id,
        'priority', priority
      )
      order by priority, supplier_id
    ),
    '[]'::jsonb
  )
  into v_before
  from atlas_admin.supplier_eligibilities
  where ingredient_id = v_ingredient_id
    and eligibility_status = 'ACTIVE'
    and priority is not null;

  update atlas_admin.supplier_eligibilities
  set eligibility_status = 'INACTIVE',
      effective_to = greatest(current_date, effective_from + 1),
      version = version + 1,
      updated_at = pg_catalog.transaction_timestamp()
  where ingredient_id = v_ingredient_id
    and eligibility_status = 'ACTIVE';

  for v_row in
    select
      atlas_core.pa_05b_safe_uuid(value ->> 'supplier_id') as supplier_id,
      atlas_core.pa_05b_safe_bigint(value ->> 'priority')::smallint as priority
    from pg_catalog.jsonb_array_elements(v_priorities)
    order by atlas_core.pa_05b_safe_bigint(value ->> 'priority')
  loop
    insert into atlas_admin.supplier_eligibilities (
      supplier_id,
      ingredient_id,
      eligibility_status,
      effective_from,
      priority,
      reason_note
    ) values (
      v_row.supplier_id,
      v_ingredient_id,
      'ACTIVE',
      current_date,
      v_row.priority,
      request ->> 'reason_note'
    )
    on conflict on constraint supplier_eligibilities_period_key
    do update set
      eligibility_status = 'ACTIVE',
      effective_to = null,
      priority = excluded.priority,
      reason_note = excluded.reason_note,
      version = atlas_admin.supplier_eligibilities.version + 1,
      updated_at = pg_catalog.transaction_timestamp();
  end loop;

  update atlas_admin.ingredients
  set version = version + 1,
      updated_at = pg_catalog.transaction_timestamp()
  where ingredient_id = v_ingredient_id;
  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'supplier_id', supplier_id,
        'priority', priority
      )
      order by priority, supplier_id
    ),
    '[]'::jsonb
  )
  into v_after
  from atlas_admin.supplier_eligibilities
  where ingredient_id = v_ingredient_id
    and eligibility_status = 'ACTIVE'
    and priority is not null;
  return atlas_core.rmvp_01_finish_success(
    request, v_actor_id, v_receipt_id, 'IngredientSupplierPrioritiesReplaced',
    'Ingredient', v_ingredient_id, v_ingredient.version, v_ingredient.version + 1,
    pg_catalog.jsonb_build_object('supplier_priorities', v_before),
    pg_catalog.jsonb_build_object('supplier_priorities', v_after),
    'Ingredient supplier priorities replaced atomically.',
    pg_catalog.jsonb_build_object('ingredient_id', v_ingredient_id)
  );
exception
  when serialization_failure or deadlock_detected then
    return atlas_core.pa_05b_command_error(
      request, 'RETRYABLE_CONCURRENCY_FAILURE',
      'Supplier priorities could not be locked safely. Retry the exact request.',
      'ADMIN', v_name, true
    );
  when unique_violation then
    return atlas_core.pa_05b_command_error(
      request, 'CONFLICT',
      'Supplier priority uniqueness changed concurrently. Refresh and try again.',
      'ADMIN', v_name
    );
  when others then
    return atlas_core.pa_05b_command_error(
      request, 'INTERNAL_COMMAND_FAILURE',
      'Supplier priorities could not be replaced safely.', 'ADMIN', v_name
    );
end;
$$;

create or replace function atlas_legacy.import_master_data_snapshot(snapshot jsonb)
returns jsonb
language plpgsql
volatile
security invoker
set search_path = ''
as $$
declare
  v_source_system text := pg_catalog.btrim(coalesce(snapshot ->> 'source_system', ''));
  v_snapshot_id text := pg_catalog.btrim(coalesce(snapshot ->> 'snapshot_id', ''));
  v_checksum text := pg_catalog.lower(pg_catalog.btrim(coalesce(snapshot ->> 'snapshot_checksum', '')));
  v_exported_at timestamptz := atlas_core.pa_05b_safe_timestamptz(snapshot ->> 'exported_at');
  v_records jsonb := snapshot -> 'records';
  v_existing atlas_legacy.import_batches%rowtype;
  v_batch_id uuid := gen_random_uuid();
  v_source_counts jsonb;
  v_target_counts jsonb;
  v_mapping_counts jsonb;
  v_operation_counts jsonb;
  v_duplicates jsonb := '[]'::jsonb;
  v_missing jsonb := '[]'::jsonb;
  v_errors jsonb := '[]'::jsonb;
  v_reconciliation jsonb;
  v_result jsonb;
  v_row record;
  v_target_id uuid;
  v_parent_id uuid;
  v_location_id uuid;
  v_school_type_id uuid;
  v_total_source_count bigint := 0;
  v_inserted_count bigint := 0;
  v_updated_count bigint := 0;
  v_was_inserted boolean;
begin
  if current_user <> 'postgres' then
    raise exception using
      errcode = '42501',
      message = 'RMVP-01 import is restricted to the privileged local database operator.';
  end if;

  if v_source_system = '' or v_snapshot_id = ''
     or v_checksum !~ '^[0-9a-f]{64}$'
     or v_exported_at is null
     or v_records is null
     or pg_catalog.jsonb_typeof(v_records) <> 'object' then
    return pg_catalog.jsonb_build_object(
      'success', false,
      'error_code', 'INVALID_SNAPSHOT_ENVELOPE',
      'safe_message', 'The snapshot envelope is incomplete or invalid.'
    );
  end if;

  select * into v_existing
  from atlas_legacy.import_batches
  where source_system = v_source_system
    and snapshot_id = v_snapshot_id;
  if found then
    if v_existing.snapshot_checksum <> v_checksum then
      return pg_catalog.jsonb_build_object(
        'success', false,
        'error_code', 'SNAPSHOT_ID_CONFLICT',
        'safe_message', 'The snapshot identifier was already used with different content.',
        'import_batch_id', v_existing.import_batch_id
      );
    end if;
    select coalesce(pg_catalog.sum(value::bigint), 0)
    into v_total_source_count
    from pg_catalog.jsonb_each_text(v_existing.source_counts);
    return coalesce(v_existing.result_payload, '{}'::jsonb)
      || pg_catalog.jsonb_build_object(
        'rerun', true,
        'import_batch_id', v_existing.import_batch_id,
        'operation_counts',
        pg_catalog.jsonb_build_object(
          'inserted', 0,
          'updated', 0,
          'skipped', v_total_source_count,
          'rejected', 0
        )
      );
  end if;

  v_source_counts := pg_catalog.jsonb_build_object(
    'customers', pg_catalog.jsonb_array_length(coalesce(v_records -> 'customers', '[]'::jsonb)),
    'delivery_locations', pg_catalog.jsonb_array_length(coalesce(v_records -> 'delivery_locations', '[]'::jsonb)),
    'school_types', pg_catalog.jsonb_array_length(coalesce(v_records -> 'school_types', '[]'::jsonb)),
    'schools', pg_catalog.jsonb_array_length(coalesce(v_records -> 'schools', '[]'::jsonb)),
    'units', pg_catalog.jsonb_array_length(coalesce(v_records -> 'units', '[]'::jsonb)),
    'ingredients', pg_catalog.jsonb_array_length(coalesce(v_records -> 'ingredients', '[]'::jsonb)),
    'suppliers', pg_catalog.jsonb_array_length(coalesce(v_records -> 'suppliers', '[]'::jsonb)),
    'supplier_priorities', pg_catalog.jsonb_array_length(coalesce(v_records -> 'supplier_priorities', '[]'::jsonb))
  );
  select coalesce(pg_catalog.sum(value::bigint), 0)
  into v_total_source_count
  from pg_catalog.jsonb_each_text(v_source_counts);

  with source_objects as (
    select 'CUSTOMER'::text object_type, value ->> 'legacy_id' legacy_id
    from pg_catalog.jsonb_array_elements(coalesce(v_records -> 'customers', '[]'::jsonb))
    union all
    select 'DELIVERY_LOCATION', value ->> 'legacy_id'
    from pg_catalog.jsonb_array_elements(coalesce(v_records -> 'delivery_locations', '[]'::jsonb))
    union all
    select 'SCHOOL_TYPE', value ->> 'legacy_id'
    from pg_catalog.jsonb_array_elements(coalesce(v_records -> 'school_types', '[]'::jsonb))
    union all
    select 'SCHOOL', value ->> 'legacy_id'
    from pg_catalog.jsonb_array_elements(coalesce(v_records -> 'schools', '[]'::jsonb))
    union all
    select 'UNIT', value ->> 'legacy_id'
    from pg_catalog.jsonb_array_elements(coalesce(v_records -> 'units', '[]'::jsonb))
    union all
    select 'INGREDIENT', value ->> 'legacy_id'
    from pg_catalog.jsonb_array_elements(coalesce(v_records -> 'ingredients', '[]'::jsonb))
    union all
    select 'SUPPLIER', value ->> 'legacy_id'
    from pg_catalog.jsonb_array_elements(coalesce(v_records -> 'suppliers', '[]'::jsonb))
  ), duplicate_objects as (
    select object_type, legacy_id, count(*) duplicate_count
    from source_objects
    group by object_type, legacy_id
    having legacy_id is null or pg_catalog.btrim(legacy_id) = '' or count(*) > 1
  ), priority_duplicates as (
    select
      'SUPPLIER_PRIORITY'::text object_type,
      coalesce(value ->> 'ingredient_legacy_id', '<missing>') || ':' ||
        coalesce(value ->> 'supplier_legacy_id', '<missing>') legacy_id,
      count(*) duplicate_count
    from pg_catalog.jsonb_array_elements(coalesce(v_records -> 'supplier_priorities', '[]'::jsonb))
    group by value ->> 'ingredient_legacy_id', value ->> 'supplier_legacy_id'
    having count(*) > 1
    union all
    select
      'INGREDIENT_PRIORITY',
      coalesce(value ->> 'ingredient_legacy_id', '<missing>') || ':' ||
        coalesce(value ->> 'priority', '<missing>'),
      count(*)
    from pg_catalog.jsonb_array_elements(coalesce(v_records -> 'supplier_priorities', '[]'::jsonb))
    group by value ->> 'ingredient_legacy_id', value ->> 'priority'
    having count(*) > 1
  )
  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'object_type', object_type,
        'legacy_reference', legacy_id,
        'duplicate_count', duplicate_count
      )
      order by object_type, legacy_id
    ),
    '[]'::jsonb
  )
  into v_duplicates
  from (
    select * from duplicate_objects
    union all
    select * from priority_duplicates
  ) duplicates;

  with missing_refs as (
    select
      'DELIVERY_LOCATION'::text object_type,
      value ->> 'legacy_id' legacy_id,
      'customer_legacy_id'::text field_name,
      value ->> 'customer_legacy_id' missing_legacy_id
    from pg_catalog.jsonb_array_elements(coalesce(v_records -> 'delivery_locations', '[]'::jsonb)) item
    where not exists (
      select 1
      from pg_catalog.jsonb_array_elements(coalesce(v_records -> 'customers', '[]'::jsonb)) parent
      where parent ->> 'legacy_id' = item.value ->> 'customer_legacy_id'
    )
    union all
    select
      'SCHOOL',
      value ->> 'legacy_id',
      'customer_legacy_id',
      value ->> 'customer_legacy_id'
    from pg_catalog.jsonb_array_elements(coalesce(v_records -> 'schools', '[]'::jsonb)) item
    where not exists (
      select 1 from pg_catalog.jsonb_array_elements(coalesce(v_records -> 'customers', '[]'::jsonb)) parent
      where parent ->> 'legacy_id' = item.value ->> 'customer_legacy_id'
    )
    union all
    select
      'SCHOOL',
      value ->> 'legacy_id',
      'delivery_location_legacy_id',
      value ->> 'delivery_location_legacy_id'
    from pg_catalog.jsonb_array_elements(coalesce(v_records -> 'schools', '[]'::jsonb)) item
    where not exists (
      select 1 from pg_catalog.jsonb_array_elements(coalesce(v_records -> 'delivery_locations', '[]'::jsonb)) parent
      where parent ->> 'legacy_id' = item.value ->> 'delivery_location_legacy_id'
    )
    union all
    select
      'SCHOOL',
      value ->> 'legacy_id',
      'school_type_legacy_id',
      value ->> 'school_type_legacy_id'
    from pg_catalog.jsonb_array_elements(coalesce(v_records -> 'schools', '[]'::jsonb)) item
    where nullif(item.value ->> 'school_type_legacy_id', '') is not null
      and not exists (
        select 1 from pg_catalog.jsonb_array_elements(coalesce(v_records -> 'school_types', '[]'::jsonb)) parent
        where parent ->> 'legacy_id' = item.value ->> 'school_type_legacy_id'
      )
    union all
    select
      'INGREDIENT',
      value ->> 'legacy_id',
      'purchase_unit_legacy_id',
      value ->> 'purchase_unit_legacy_id'
    from pg_catalog.jsonb_array_elements(coalesce(v_records -> 'ingredients', '[]'::jsonb)) item
    where not exists (
      select 1 from pg_catalog.jsonb_array_elements(coalesce(v_records -> 'units', '[]'::jsonb)) parent
      where parent ->> 'legacy_id' = item.value ->> 'purchase_unit_legacy_id'
    )
    union all
    select
      'SUPPLIER_PRIORITY',
      coalesce(value ->> 'ingredient_legacy_id', '<missing>'),
      'ingredient_legacy_id',
      value ->> 'ingredient_legacy_id'
    from pg_catalog.jsonb_array_elements(coalesce(v_records -> 'supplier_priorities', '[]'::jsonb)) item
    where not exists (
      select 1 from pg_catalog.jsonb_array_elements(coalesce(v_records -> 'ingredients', '[]'::jsonb)) parent
      where parent ->> 'legacy_id' = item.value ->> 'ingredient_legacy_id'
    )
    union all
    select
      'SUPPLIER_PRIORITY',
      coalesce(value ->> 'supplier_legacy_id', '<missing>'),
      'supplier_legacy_id',
      value ->> 'supplier_legacy_id'
    from pg_catalog.jsonb_array_elements(coalesce(v_records -> 'supplier_priorities', '[]'::jsonb)) item
    where not exists (
      select 1 from pg_catalog.jsonb_array_elements(coalesce(v_records -> 'suppliers', '[]'::jsonb)) parent
      where parent ->> 'legacy_id' = item.value ->> 'supplier_legacy_id'
    )
  )
  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'object_type', object_type,
        'legacy_id', legacy_id,
        'field', field_name,
        'missing_legacy_id', missing_legacy_id
      )
      order by object_type, legacy_id, field_name
    ),
    '[]'::jsonb
  )
  into v_missing
  from missing_refs;

  if exists (
    select 1
    from pg_catalog.jsonb_array_elements(coalesce(v_records -> 'supplier_priorities', '[]'::jsonb)) item
    where atlas_core.pa_05b_safe_bigint(item ->> 'priority') not between 1 and 6
  ) then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'records.supplier_priorities',
        'message', 'Every priority must be an integer from 1 through 6.'
      )
    );
  end if;
  if exists (
    select 1
    from (
      select value ->> 'ingredient_legacy_id' ingredient_legacy_id, count(*) item_count
      from pg_catalog.jsonb_array_elements(coalesce(v_records -> 'supplier_priorities', '[]'::jsonb))
      group by value ->> 'ingredient_legacy_id'
      having count(*) > 6
    ) excessive
  ) then
    v_errors := v_errors || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'records.supplier_priorities',
        'message', 'An ingredient may have at most six supplier priorities.'
      )
    );
  end if;

  if pg_catalog.jsonb_array_length(v_duplicates) > 0
     or pg_catalog.jsonb_array_length(v_missing) > 0
     or pg_catalog.jsonb_array_length(v_errors) > 0 then
    v_result := pg_catalog.jsonb_build_object(
      'success', false,
      'error_code', 'SNAPSHOT_REJECTED',
      'safe_message', 'The snapshot failed duplicate, reference, or value validation.',
      'import_batch_id', v_batch_id,
      'source_counts', v_source_counts,
      'duplicate_references', v_duplicates,
      'missing_references', v_missing,
      'validation_errors', v_errors,
      'operation_counts',
      pg_catalog.jsonb_build_object(
        'inserted', 0,
        'updated', 0,
        'skipped', 0,
        'rejected', v_total_source_count
      ),
      'reconciliation', pg_catalog.jsonb_build_object('passed', false),
      'rerun', false
    );
    insert into atlas_legacy.import_batches (
      import_batch_id,
      source_system,
      snapshot_id,
      snapshot_checksum,
      exported_at,
      import_status,
      source_counts,
      operation_counts,
      duplicate_references,
      missing_references,
      validation_errors,
      reconciliation,
      result_payload,
      completed_at
    ) values (
      v_batch_id,
      v_source_system,
      v_snapshot_id,
      v_checksum,
      v_exported_at,
      'REJECTED',
      v_source_counts,
      pg_catalog.jsonb_build_object(
        'inserted', 0,
        'updated', 0,
        'skipped', 0,
        'rejected', v_total_source_count
      ),
      v_duplicates,
      v_missing,
      v_errors,
      pg_catalog.jsonb_build_object('passed', false),
      v_result,
      pg_catalog.transaction_timestamp()
    );
    return v_result;
  end if;

  insert into atlas_legacy.import_batches (
    import_batch_id,
    source_system,
    snapshot_id,
    snapshot_checksum,
    exported_at,
    import_status,
    source_counts,
    reconciliation,
    completed_at
  ) values (
    v_batch_id,
    v_source_system,
    v_snapshot_id,
    v_checksum,
    v_exported_at,
    'COMPLETED',
    v_source_counts,
    pg_catalog.jsonb_build_object('passed', false, 'pending', true),
    pg_catalog.transaction_timestamp()
  );

  for v_row in
    select *
    from pg_catalog.jsonb_to_recordset(coalesce(v_records -> 'customers', '[]'::jsonb))
      as x(
        legacy_id text,
        customer_code text,
        customer_name text,
        customer_type text,
        customer_status text
      )
    order by legacy_id
  loop
    insert into atlas_admin.customers (
      customer_code,
      customer_name,
      customer_type,
      customer_status
    ) values (
      v_row.customer_code,
      v_row.customer_name,
      coalesce(v_row.customer_type, 'SCHOOL_CATERING'),
      coalesce(v_row.customer_status, 'ACTIVE')
    )
    on conflict (customer_code) do update set
      customer_name = excluded.customer_name,
      customer_status = excluded.customer_status,
      version = case
        when (atlas_admin.customers.customer_name, atlas_admin.customers.customer_status)
          is distinct from (excluded.customer_name, excluded.customer_status)
          then atlas_admin.customers.version + 1
        else atlas_admin.customers.version
      end,
      updated_at = case
        when (atlas_admin.customers.customer_name, atlas_admin.customers.customer_status)
          is distinct from (excluded.customer_name, excluded.customer_status)
          then pg_catalog.transaction_timestamp()
        else atlas_admin.customers.updated_at
      end
    returning customer_id, (xmax = 0) into v_target_id, v_was_inserted;
    if v_was_inserted then
      v_inserted_count := v_inserted_count + 1;
    else
      v_updated_count := v_updated_count + 1;
    end if;
    insert into atlas_legacy.master_data_mappings (
      import_batch_id, source_system, object_type, legacy_id, customer_id
    ) values (
      v_batch_id, v_source_system, 'CUSTOMER', v_row.legacy_id, v_target_id
    )
    on conflict (source_system, object_type, legacy_id) do update set
      import_batch_id = excluded.import_batch_id,
      customer_id = excluded.customer_id,
      updated_at = pg_catalog.transaction_timestamp();
  end loop;

  for v_row in
    select *
    from pg_catalog.jsonb_to_recordset(coalesce(v_records -> 'delivery_locations', '[]'::jsonb))
      as x(
        legacy_id text,
        customer_legacy_id text,
        location_code text,
        location_name text,
        address_text text,
        delivery_instructions text,
        location_status text
      )
    order by legacy_id
  loop
    select customer_id into v_parent_id
    from atlas_legacy.master_data_mappings
    where source_system = v_source_system
      and object_type = 'CUSTOMER'
      and legacy_id = v_row.customer_legacy_id;
    insert into atlas_admin.delivery_locations (
      customer_id, location_code, location_name, address_text,
      delivery_instructions, location_status
    ) values (
      v_parent_id, v_row.location_code, v_row.location_name, v_row.address_text,
      v_row.delivery_instructions, coalesce(v_row.location_status, 'ACTIVE')
    )
    on conflict (customer_id, location_code) do update set
      location_name = excluded.location_name,
      address_text = excluded.address_text,
      delivery_instructions = excluded.delivery_instructions,
      location_status = excluded.location_status,
      version = atlas_admin.delivery_locations.version + 1,
      updated_at = pg_catalog.transaction_timestamp()
    returning delivery_location_id, (xmax = 0) into v_target_id, v_was_inserted;
    if v_was_inserted then
      v_inserted_count := v_inserted_count + 1;
    else
      v_updated_count := v_updated_count + 1;
    end if;
    insert into atlas_legacy.master_data_mappings (
      import_batch_id, source_system, object_type, legacy_id, delivery_location_id
    ) values (
      v_batch_id, v_source_system, 'DELIVERY_LOCATION', v_row.legacy_id, v_target_id
    )
    on conflict (source_system, object_type, legacy_id) do update set
      import_batch_id = excluded.import_batch_id,
      delivery_location_id = excluded.delivery_location_id,
      updated_at = pg_catalog.transaction_timestamp();
  end loop;

  for v_row in
    select *
    from pg_catalog.jsonb_to_recordset(coalesce(v_records -> 'school_types', '[]'::jsonb))
      as x(
        legacy_id text,
        school_type_code text,
        school_type_name text,
        school_type_status text
      )
    order by legacy_id
  loop
    insert into atlas_admin.school_types (
      school_type_code, school_type_name, school_type_status
    ) values (
      v_row.school_type_code, v_row.school_type_name,
      coalesce(v_row.school_type_status, 'ACTIVE')
    )
    on conflict (school_type_code) do update set
      school_type_name = excluded.school_type_name,
      school_type_status = excluded.school_type_status,
      version = atlas_admin.school_types.version + 1,
      updated_at = pg_catalog.transaction_timestamp()
    returning school_type_id, (xmax = 0) into v_target_id, v_was_inserted;
    if v_was_inserted then
      v_inserted_count := v_inserted_count + 1;
    else
      v_updated_count := v_updated_count + 1;
    end if;
    insert into atlas_legacy.master_data_mappings (
      import_batch_id, source_system, object_type, legacy_id, school_type_id
    ) values (
      v_batch_id, v_source_system, 'SCHOOL_TYPE', v_row.legacy_id, v_target_id
    )
    on conflict (source_system, object_type, legacy_id) do update set
      import_batch_id = excluded.import_batch_id,
      school_type_id = excluded.school_type_id,
      updated_at = pg_catalog.transaction_timestamp();
  end loop;

  for v_row in
    select *
    from pg_catalog.jsonb_to_recordset(coalesce(v_records -> 'units', '[]'::jsonb))
      as x(
        legacy_id text,
        unit_code text,
        unit_name text,
        dimension_code text,
        decimal_scale smallint,
        unit_status text
      )
    order by legacy_id
  loop
    insert into atlas_admin.units (
      unit_code, unit_name, dimension_code, decimal_scale, unit_status
    ) values (
      v_row.unit_code, v_row.unit_name, v_row.dimension_code,
      coalesce(v_row.decimal_scale, 6), coalesce(v_row.unit_status, 'ACTIVE')
    )
    on conflict (unit_code) do update set
      unit_name = excluded.unit_name,
      dimension_code = excluded.dimension_code,
      decimal_scale = excluded.decimal_scale,
      unit_status = excluded.unit_status
    returning unit_id, (xmax = 0) into v_target_id, v_was_inserted;
    if v_was_inserted then
      v_inserted_count := v_inserted_count + 1;
    else
      v_updated_count := v_updated_count + 1;
    end if;
    insert into atlas_legacy.master_data_mappings (
      import_batch_id, source_system, object_type, legacy_id, unit_id
    ) values (
      v_batch_id, v_source_system, 'UNIT', v_row.legacy_id, v_target_id
    )
    on conflict (source_system, object_type, legacy_id) do update set
      import_batch_id = excluded.import_batch_id,
      unit_id = excluded.unit_id,
      updated_at = pg_catalog.transaction_timestamp();
  end loop;

  for v_row in
    select *
    from pg_catalog.jsonb_to_recordset(coalesce(v_records -> 'schools', '[]'::jsonb))
      as x(
        legacy_id text,
        customer_legacy_id text,
        school_code text,
        school_name text,
        school_type_legacy_id text,
        delivery_location_legacy_id text,
        school_status text,
        display_order integer,
        operational_notes text,
        default_student_portions integer,
        default_teacher_portions integer
      )
    order by legacy_id
  loop
    select customer_id into v_parent_id
    from atlas_legacy.master_data_mappings
    where source_system = v_source_system and object_type = 'CUSTOMER'
      and legacy_id = v_row.customer_legacy_id;
    select delivery_location_id into v_location_id
    from atlas_legacy.master_data_mappings
    where source_system = v_source_system and object_type = 'DELIVERY_LOCATION'
      and legacy_id = v_row.delivery_location_legacy_id;
    select school_type_id into v_school_type_id
    from atlas_legacy.master_data_mappings
    where source_system = v_source_system and object_type = 'SCHOOL_TYPE'
      and legacy_id = v_row.school_type_legacy_id;
    insert into atlas_admin.schools (
      customer_id, school_code, school_name, school_type_id,
      default_delivery_location_id, school_status, display_order,
      operational_notes, default_student_portions, default_teacher_portions
    ) values (
      v_parent_id, v_row.school_code, v_row.school_name, v_school_type_id,
      v_location_id, coalesce(v_row.school_status, 'ACTIVE'),
      coalesce(v_row.display_order, 0), v_row.operational_notes,
      coalesce(v_row.default_student_portions, 0),
      coalesce(v_row.default_teacher_portions, 0)
    )
    on conflict (customer_id, school_code) do update set
      school_name = excluded.school_name,
      school_type_id = excluded.school_type_id,
      default_delivery_location_id = excluded.default_delivery_location_id,
      school_status = excluded.school_status,
      display_order = excluded.display_order,
      operational_notes = excluded.operational_notes,
      default_student_portions = excluded.default_student_portions,
      default_teacher_portions = excluded.default_teacher_portions,
      version = atlas_admin.schools.version + 1,
      updated_at = pg_catalog.transaction_timestamp()
    returning school_id, (xmax = 0) into v_target_id, v_was_inserted;
    if v_was_inserted then
      v_inserted_count := v_inserted_count + 1;
    else
      v_updated_count := v_updated_count + 1;
    end if;
    insert into atlas_legacy.master_data_mappings (
      import_batch_id, source_system, object_type, legacy_id, school_id
    ) values (
      v_batch_id, v_source_system, 'SCHOOL', v_row.legacy_id, v_target_id
    )
    on conflict (source_system, object_type, legacy_id) do update set
      import_batch_id = excluded.import_batch_id,
      school_id = excluded.school_id,
      updated_at = pg_catalog.transaction_timestamp();
  end loop;

  for v_row in
    select *
    from pg_catalog.jsonb_to_recordset(coalesce(v_records -> 'ingredients', '[]'::jsonb))
      as x(
        legacy_id text,
        ingredient_code text,
        ingredient_name text,
        ingredient_type text,
        shopping_type text,
        purchase_unit_legacy_id text,
        order_step numeric,
        ingredient_status text
      )
    order by legacy_id
  loop
    select unit_id into v_parent_id
    from atlas_legacy.master_data_mappings
    where source_system = v_source_system and object_type = 'UNIT'
      and legacy_id = v_row.purchase_unit_legacy_id;
    insert into atlas_admin.ingredients (
      ingredient_code, ingredient_name, ingredient_group, purchase_unit_id,
      ingredient_type, shopping_type, order_step, ingredient_status
    ) values (
      v_row.ingredient_code, v_row.ingredient_name, v_row.ingredient_type,
      v_parent_id, v_row.ingredient_type, v_row.shopping_type,
      v_row.order_step, coalesce(v_row.ingredient_status, 'ACTIVE')
    )
    on conflict (ingredient_code) do update set
      ingredient_name = excluded.ingredient_name,
      ingredient_group = excluded.ingredient_group,
      purchase_unit_id = excluded.purchase_unit_id,
      ingredient_type = excluded.ingredient_type,
      shopping_type = excluded.shopping_type,
      order_step = excluded.order_step,
      ingredient_status = excluded.ingredient_status,
      version = atlas_admin.ingredients.version + 1,
      updated_at = pg_catalog.transaction_timestamp()
    returning ingredient_id, (xmax = 0) into v_target_id, v_was_inserted;
    if v_was_inserted then
      v_inserted_count := v_inserted_count + 1;
    else
      v_updated_count := v_updated_count + 1;
    end if;
    insert into atlas_legacy.master_data_mappings (
      import_batch_id, source_system, object_type, legacy_id, ingredient_id
    ) values (
      v_batch_id, v_source_system, 'INGREDIENT', v_row.legacy_id, v_target_id
    )
    on conflict (source_system, object_type, legacy_id) do update set
      import_batch_id = excluded.import_batch_id,
      ingredient_id = excluded.ingredient_id,
      updated_at = pg_catalog.transaction_timestamp();
  end loop;

  for v_row in
    select *
    from pg_catalog.jsonb_to_recordset(coalesce(v_records -> 'suppliers', '[]'::jsonb))
      as x(
        legacy_id text,
        supplier_code text,
        supplier_name text,
        supplier_status text,
        contact_name text,
        contact_phone text,
        contact_email text
      )
    order by legacy_id
  loop
    insert into atlas_admin.suppliers (
      supplier_code, supplier_name, supplier_status,
      contact_name, contact_phone, contact_email
    ) values (
      v_row.supplier_code, v_row.supplier_name,
      coalesce(v_row.supplier_status, 'ACTIVE'),
      v_row.contact_name, v_row.contact_phone, v_row.contact_email
    )
    on conflict (supplier_code) do update set
      supplier_name = excluded.supplier_name,
      supplier_status = excluded.supplier_status,
      contact_name = excluded.contact_name,
      contact_phone = excluded.contact_phone,
      contact_email = excluded.contact_email,
      version = atlas_admin.suppliers.version + 1,
      updated_at = pg_catalog.transaction_timestamp()
    returning supplier_id, (xmax = 0) into v_target_id, v_was_inserted;
    if v_was_inserted then
      v_inserted_count := v_inserted_count + 1;
    else
      v_updated_count := v_updated_count + 1;
    end if;
    insert into atlas_legacy.master_data_mappings (
      import_batch_id, source_system, object_type, legacy_id, supplier_id
    ) values (
      v_batch_id, v_source_system, 'SUPPLIER', v_row.legacy_id, v_target_id
    )
    on conflict (source_system, object_type, legacy_id) do update set
      import_batch_id = excluded.import_batch_id,
      supplier_id = excluded.supplier_id,
      updated_at = pg_catalog.transaction_timestamp();
  end loop;

  update atlas_admin.supplier_eligibilities se
  set eligibility_status = 'INACTIVE',
      effective_to = greatest(current_date, se.effective_from + 1),
      version = se.version + 1,
      updated_at = pg_catalog.transaction_timestamp()
  where se.eligibility_status = 'ACTIVE'
    and exists (
      select 1
      from atlas_legacy.master_data_mappings m
      where m.import_batch_id = v_batch_id
        and m.object_type = 'INGREDIENT'
        and m.ingredient_id = se.ingredient_id
    );

  for v_row in
    select *
    from pg_catalog.jsonb_to_recordset(coalesce(v_records -> 'supplier_priorities', '[]'::jsonb))
      as x(
        ingredient_legacy_id text,
        supplier_legacy_id text,
        priority smallint
      )
    order by ingredient_legacy_id, priority
  loop
    select ingredient_id into v_target_id
    from atlas_legacy.master_data_mappings
    where source_system = v_source_system and object_type = 'INGREDIENT'
      and legacy_id = v_row.ingredient_legacy_id;
    select supplier_id into v_parent_id
    from atlas_legacy.master_data_mappings
    where source_system = v_source_system and object_type = 'SUPPLIER'
      and legacy_id = v_row.supplier_legacy_id;
    insert into atlas_admin.supplier_eligibilities (
      supplier_id, ingredient_id, eligibility_status, effective_from, priority,
      reason_note
    ) values (
      v_parent_id, v_target_id, 'ACTIVE', current_date,
      v_row.priority, 'RMVP-01 validated legacy snapshot'
    )
    on conflict on constraint supplier_eligibilities_period_key do update set
      eligibility_status = 'ACTIVE',
      effective_to = null,
      priority = excluded.priority,
      reason_note = excluded.reason_note,
      version = atlas_admin.supplier_eligibilities.version + 1,
      updated_at = pg_catalog.transaction_timestamp()
    returning (xmax = 0) into v_was_inserted;
    if v_was_inserted then
      v_inserted_count := v_inserted_count + 1;
    else
      v_updated_count := v_updated_count + 1;
    end if;
  end loop;

  select pg_catalog.jsonb_object_agg(object_type, mapping_count)
  into v_mapping_counts
  from (
    select object_type, count(*) mapping_count
    from atlas_legacy.master_data_mappings
    where import_batch_id = v_batch_id
    group by object_type
    order by object_type
  ) counts;
  v_target_counts := pg_catalog.jsonb_build_object(
    'customers', coalesce((v_mapping_counts ->> 'CUSTOMER')::integer, 0),
    'delivery_locations', coalesce((v_mapping_counts ->> 'DELIVERY_LOCATION')::integer, 0),
    'school_types', coalesce((v_mapping_counts ->> 'SCHOOL_TYPE')::integer, 0),
    'schools', coalesce((v_mapping_counts ->> 'SCHOOL')::integer, 0),
    'units', coalesce((v_mapping_counts ->> 'UNIT')::integer, 0),
    'ingredients', coalesce((v_mapping_counts ->> 'INGREDIENT')::integer, 0),
    'suppliers', coalesce((v_mapping_counts ->> 'SUPPLIER')::integer, 0),
    'supplier_priorities', (
      select count(*)
      from atlas_admin.supplier_eligibilities se
      where se.eligibility_status = 'ACTIVE'
        and se.priority is not null
        and exists (
          select 1
          from atlas_legacy.master_data_mappings m
          where m.import_batch_id = v_batch_id
            and m.object_type = 'INGREDIENT'
            and m.ingredient_id = se.ingredient_id
        )
    )
  );
  v_reconciliation := pg_catalog.jsonb_build_object(
    'passed', v_source_counts = v_target_counts,
    'source_counts', v_source_counts,
    'target_counts', v_target_counts
  );
  v_operation_counts := pg_catalog.jsonb_build_object(
    'inserted', v_inserted_count,
    'updated', v_updated_count,
    'skipped', 0,
    'rejected', 0
  );
  if v_source_counts <> v_target_counts then
    raise exception using
      errcode = '23514',
      message = 'RMVP-01 import reconciliation failed; the transaction was rolled back.';
  end if;

  v_result := pg_catalog.jsonb_build_object(
    'success', true,
    'safe_message', 'The validated snapshot was imported and reconciled.',
    'import_batch_id', v_batch_id,
    'source_counts', v_source_counts,
    'target_counts', v_target_counts,
    'mapping_counts', coalesce(v_mapping_counts, '{}'::jsonb),
    'operation_counts', v_operation_counts,
    'duplicate_references', '[]'::jsonb,
    'missing_references', '[]'::jsonb,
    'validation_errors', '[]'::jsonb,
    'reconciliation', v_reconciliation,
    'rerun', false
  );
  update atlas_legacy.import_batches
  set target_counts = v_target_counts,
      mapping_counts = coalesce(v_mapping_counts, '{}'::jsonb),
      operation_counts = v_operation_counts,
      reconciliation = v_reconciliation,
      result_payload = v_result,
      completed_at = pg_catalog.transaction_timestamp()
  where import_batch_id = v_batch_id;
  return v_result;
exception
  when check_violation
    or not_null_violation
    or foreign_key_violation
    or unique_violation
    or invalid_text_representation then
    v_operation_counts := pg_catalog.jsonb_build_object(
      'inserted', 0,
      'updated', 0,
      'skipped', 0,
      'rejected', v_total_source_count
    );
    v_errors := pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'field', 'records',
        'message', 'A source value violated an Atlas master-data constraint.'
      )
    );
    v_result := pg_catalog.jsonb_build_object(
      'success', false,
      'error_code', 'SNAPSHOT_REJECTED',
      'safe_message', 'The snapshot failed Atlas value validation; no target writes were committed.',
      'import_batch_id', v_batch_id,
      'source_counts', coalesce(v_source_counts, '{}'::jsonb),
      'duplicate_references', coalesce(v_duplicates, '[]'::jsonb),
      'missing_references', coalesce(v_missing, '[]'::jsonb),
      'validation_errors', v_errors,
      'operation_counts', v_operation_counts,
      'reconciliation', pg_catalog.jsonb_build_object('passed', false),
      'rerun', false
    );
    insert into atlas_legacy.import_batches (
      import_batch_id,
      source_system,
      snapshot_id,
      snapshot_checksum,
      exported_at,
      import_status,
      source_counts,
      operation_counts,
      duplicate_references,
      missing_references,
      validation_errors,
      reconciliation,
      result_payload,
      completed_at
    ) values (
      v_batch_id,
      v_source_system,
      v_snapshot_id,
      v_checksum,
      v_exported_at,
      'REJECTED',
      coalesce(v_source_counts, '{}'::jsonb),
      v_operation_counts,
      coalesce(v_duplicates, '[]'::jsonb),
      coalesce(v_missing, '[]'::jsonb),
      v_errors,
      pg_catalog.jsonb_build_object('passed', false),
      v_result,
      pg_catalog.transaction_timestamp()
    )
    on conflict (source_system, snapshot_id) do nothing;
    return v_result;
end;
$$;

revoke execute on function atlas_legacy.import_master_data_snapshot(jsonb)
  from public, anon, authenticated, service_role;
grant execute on function atlas_legacy.import_master_data_snapshot(jsonb)
  to postgres;

comment on function atlas_legacy.import_master_data_snapshot(jsonb) is
  'RMVP-01 local-operator-only, transactional, idempotent, validated snapshot import; never exposed through atlas_api.';

grant usage on schema atlas_core, atlas_admin, atlas_audit, atlas_api
  to atlas_master_data_command_runtime;

grant execute on function
  atlas_core.pa_05b_safe_uuid(text),
  atlas_core.pa_05b_safe_bigint(text),
  atlas_core.pa_05b_safe_numeric(text),
  atlas_core.pa_05b_safe_timestamptz(text),
  atlas_core.pa_05b_current_auth_subject(),
  atlas_core.pa_05b_command_error(jsonb, text, text, text, text, boolean, jsonb, jsonb, bigint),
  atlas_core.pa_05b_resolve_actor(jsonb, text, text),
  atlas_core.pa_05b_authorize_actor(jsonb, uuid, text, text, text, uuid, uuid, uuid),
  atlas_core.pa_05b_request_hash(jsonb),
  atlas_core.pa_05b_begin_command(jsonb, uuid, text, text, text),
  atlas_core.pa_05b_finish_command(uuid, jsonb, boolean),
  atlas_core.rmvp_01_validate_command_request(jsonb, text),
  atlas_core.rmvp_01_authorize_global(jsonb, text, text),
  atlas_core.rmvp_01_prepare_command(jsonb, text, text, text),
  atlas_core.rmvp_01_record_change(jsonb, uuid, uuid, text, text, uuid, bigint, bigint, jsonb, jsonb),
  atlas_core.rmvp_01_finish_success(jsonb, uuid, uuid, text, text, uuid, bigint, bigint, jsonb, jsonb, text, jsonb)
to atlas_master_data_command_runtime;

grant select on
  atlas_core.actors,
  atlas_core.actor_auth_subjects,
  atlas_core.roles,
  atlas_core.capabilities,
  atlas_core.role_capabilities,
  atlas_core.actor_role_memberships,
  atlas_core.actor_scopes,
  atlas_core.command_receipts,
  atlas_admin.customers,
  atlas_admin.delivery_locations,
  atlas_admin.school_types,
  atlas_admin.schools,
  atlas_admin.units,
  atlas_admin.ingredients,
  atlas_admin.suppliers,
  atlas_admin.supplier_eligibilities
to atlas_master_data_command_runtime;
grant insert, update on atlas_core.command_receipts
  to atlas_master_data_command_runtime;
grant update (
  default_student_portions,
  default_teacher_portions,
  version,
  updated_at
) on atlas_admin.schools to atlas_master_data_command_runtime;
grant insert (
  ingredient_code,
  ingredient_name,
  ingredient_group,
  purchase_unit_id,
  ingredient_type,
  shopping_type,
  order_step
) on atlas_admin.ingredients to atlas_master_data_command_runtime;
grant update (
  ingredient_name,
  ingredient_group,
  purchase_unit_id,
  ingredient_type,
  shopping_type,
  order_step,
  ingredient_status,
  version,
  updated_at
) on atlas_admin.ingredients to atlas_master_data_command_runtime;
grant insert (
  supplier_code,
  supplier_name,
  contact_name,
  contact_phone,
  contact_email
) on atlas_admin.suppliers to atlas_master_data_command_runtime;
grant update (
  supplier_name,
  contact_name,
  contact_phone,
  contact_email,
  version,
  updated_at
) on atlas_admin.suppliers to atlas_master_data_command_runtime;
grant insert (
  supplier_id,
  ingredient_id,
  eligibility_status,
  effective_from,
  priority,
  reason_note
) on atlas_admin.supplier_eligibilities to atlas_master_data_command_runtime;
grant update (
  eligibility_status,
  effective_to,
  priority,
  reason_note,
  version,
  updated_at
) on atlas_admin.supplier_eligibilities to atlas_master_data_command_runtime;
grant insert on atlas_audit.domain_events, atlas_audit.audit_events
  to atlas_master_data_command_runtime;
grant select (domain_event_id) on atlas_audit.domain_events
  to atlas_master_data_command_runtime;
grant select (audit_event_id) on atlas_audit.audit_events
  to atlas_master_data_command_runtime;

create policy rmvp_01_command_select on atlas_core.actors
  for select to atlas_master_data_command_runtime using (true);
create policy rmvp_01_command_select on atlas_core.actor_auth_subjects
  for select to atlas_master_data_command_runtime using (true);
create policy rmvp_01_command_select on atlas_core.roles
  for select to atlas_master_data_command_runtime using (true);
create policy rmvp_01_command_select on atlas_core.capabilities
  for select to atlas_master_data_command_runtime using (true);
create policy rmvp_01_command_select on atlas_core.role_capabilities
  for select to atlas_master_data_command_runtime using (true);
create policy rmvp_01_command_select on atlas_core.actor_role_memberships
  for select to atlas_master_data_command_runtime using (true);
create policy rmvp_01_command_select on atlas_core.actor_scopes
  for select to atlas_master_data_command_runtime using (true);
create policy rmvp_01_command_receipt_select on atlas_core.command_receipts
  for select to atlas_master_data_command_runtime using (true);
create policy rmvp_01_command_receipt_insert on atlas_core.command_receipts
  for insert to atlas_master_data_command_runtime with check (true);
create policy rmvp_01_command_receipt_update on atlas_core.command_receipts
  for update to atlas_master_data_command_runtime using (true) with check (true);

create policy rmvp_01_command_select on atlas_admin.customers
  for select to atlas_master_data_command_runtime using (true);
create policy rmvp_01_command_select on atlas_admin.delivery_locations
  for select to atlas_master_data_command_runtime using (true);
create policy rmvp_01_command_select on atlas_admin.school_types
  for select to atlas_master_data_command_runtime using (true);
create policy rmvp_01_command_select on atlas_admin.schools
  for select to atlas_master_data_command_runtime using (true);
create policy rmvp_01_command_school_update on atlas_admin.schools
  for update to atlas_master_data_command_runtime using (true) with check (true);
create policy rmvp_01_command_select on atlas_admin.units
  for select to atlas_master_data_command_runtime using (true);
create policy rmvp_01_command_select on atlas_admin.ingredients
  for select to atlas_master_data_command_runtime using (true);
create policy rmvp_01_command_ingredient_insert on atlas_admin.ingredients
  for insert to atlas_master_data_command_runtime with check (true);
create policy rmvp_01_command_ingredient_update on atlas_admin.ingredients
  for update to atlas_master_data_command_runtime using (true) with check (true);
create policy rmvp_01_command_select on atlas_admin.suppliers
  for select to atlas_master_data_command_runtime using (true);
create policy rmvp_01_command_supplier_insert on atlas_admin.suppliers
  for insert to atlas_master_data_command_runtime with check (true);
create policy rmvp_01_command_supplier_update on atlas_admin.suppliers
  for update to atlas_master_data_command_runtime using (true) with check (true);
create policy rmvp_01_command_select on atlas_admin.supplier_eligibilities
  for select to atlas_master_data_command_runtime using (true);
create policy rmvp_01_command_eligibility_insert on atlas_admin.supplier_eligibilities
  for insert to atlas_master_data_command_runtime with check (true);
create policy rmvp_01_command_eligibility_update on atlas_admin.supplier_eligibilities
  for update to atlas_master_data_command_runtime using (true) with check (true);
create policy rmvp_01_command_audit_insert on atlas_audit.domain_events
  for insert to atlas_master_data_command_runtime with check (true);
create policy rmvp_01_command_audit_select on atlas_audit.domain_events
  for select to atlas_master_data_command_runtime using (true);
create policy rmvp_01_command_audit_insert on atlas_audit.audit_events
  for insert to atlas_master_data_command_runtime with check (true);
create policy rmvp_01_command_audit_select on atlas_audit.audit_events
  for select to atlas_master_data_command_runtime using (true);

grant select on
  atlas_admin.school_types,
  atlas_admin.schools,
  atlas_admin.units,
  atlas_admin.ingredients,
  atlas_admin.suppliers,
  atlas_admin.supplier_eligibilities
to atlas_read_runtime;
create policy rmvp_01_read_select on atlas_admin.school_types
  for select to atlas_read_runtime using (true);
create policy rmvp_01_read_select on atlas_admin.schools
  for select to atlas_read_runtime using (true);
create policy rmvp_01_read_select on atlas_admin.units
  for select to atlas_read_runtime using (true);
create policy rmvp_01_read_select on atlas_admin.ingredients
  for select to atlas_read_runtime using (true);
create policy rmvp_01_read_select on atlas_admin.suppliers
  for select to atlas_read_runtime using (true);
create policy rmvp_01_read_select on atlas_admin.supplier_eligibilities
  for select to atlas_read_runtime using (true);

alter function atlas_core.rmvp_01_read_error(jsonb, text, text, text, jsonb)
  owner to atlas_owner;
alter function atlas_core.rmvp_01_validate_read_request(jsonb, text)
  owner to atlas_owner;
alter function atlas_core.rmvp_01_authorize_global(jsonb, text, text)
  owner to atlas_owner;
alter function atlas_core.rmvp_01_record_change(
  jsonb, uuid, uuid, text, text, uuid, bigint, bigint, jsonb, jsonb
) owner to atlas_owner;
alter function atlas_core.rmvp_01_validate_command_request(jsonb, text)
  owner to atlas_owner;
alter function atlas_core.rmvp_01_prepare_command(jsonb, text, text, text)
  owner to atlas_owner;
alter function atlas_core.rmvp_01_finish_success(
  jsonb, uuid, uuid, text, text, uuid, bigint, bigint, jsonb, jsonb, text, jsonb
) owner to atlas_owner;

grant atlas_master_data_command_runtime, atlas_read_runtime
  to postgres with set true;
grant create on schema atlas_api to
  atlas_master_data_command_runtime,
  atlas_read_runtime;
alter function atlas_api.update_school_portion_defaults(jsonb)
  owner to atlas_master_data_command_runtime;
alter function atlas_api.create_ingredient(jsonb)
  owner to atlas_master_data_command_runtime;
alter function atlas_api.update_ingredient(jsonb)
  owner to atlas_master_data_command_runtime;
alter function atlas_api.set_ingredient_lifecycle(jsonb)
  owner to atlas_master_data_command_runtime;
alter function atlas_api.create_supplier(jsonb)
  owner to atlas_master_data_command_runtime;
alter function atlas_api.update_supplier(jsonb)
  owner to atlas_master_data_command_runtime;
alter function atlas_api.replace_ingredient_supplier_priorities(jsonb)
  owner to atlas_master_data_command_runtime;
alter function atlas_api.get_school_master_data(jsonb)
  owner to atlas_read_runtime;
alter function atlas_api.get_ingredient_supplier_master_data(jsonb)
  owner to atlas_read_runtime;
revoke create on schema atlas_api from
  atlas_master_data_command_runtime,
  atlas_read_runtime;

revoke execute on function
  atlas_core.rmvp_01_read_error(jsonb, text, text, text, jsonb),
  atlas_core.rmvp_01_validate_read_request(jsonb, text),
  atlas_core.rmvp_01_authorize_global(jsonb, text, text),
  atlas_core.rmvp_01_record_change(jsonb, uuid, uuid, text, text, uuid, bigint, bigint, jsonb, jsonb),
  atlas_core.rmvp_01_validate_command_request(jsonb, text),
  atlas_core.rmvp_01_prepare_command(jsonb, text, text, text),
  atlas_core.rmvp_01_finish_success(jsonb, uuid, uuid, text, text, uuid, bigint, bigint, jsonb, jsonb, text, jsonb)
from public, anon, authenticated, service_role;
grant execute on function
  atlas_core.rmvp_01_read_error(jsonb, text, text, text, jsonb),
  atlas_core.rmvp_01_validate_read_request(jsonb, text),
  atlas_core.rmvp_01_authorize_global(jsonb, text, text)
to atlas_read_runtime;

revoke execute on function
  atlas_api.update_school_portion_defaults(jsonb),
  atlas_api.create_ingredient(jsonb),
  atlas_api.update_ingredient(jsonb),
  atlas_api.set_ingredient_lifecycle(jsonb),
  atlas_api.create_supplier(jsonb),
  atlas_api.update_supplier(jsonb),
  atlas_api.replace_ingredient_supplier_priorities(jsonb),
  atlas_api.get_school_master_data(jsonb),
  atlas_api.get_ingredient_supplier_master_data(jsonb)
from public, anon, service_role;
grant execute on function
  atlas_api.update_school_portion_defaults(jsonb),
  atlas_api.create_ingredient(jsonb),
  atlas_api.update_ingredient(jsonb),
  atlas_api.set_ingredient_lifecycle(jsonb),
  atlas_api.create_supplier(jsonb),
  atlas_api.update_supplier(jsonb),
  atlas_api.replace_ingredient_supplier_priorities(jsonb),
  atlas_api.get_school_master_data(jsonb),
  atlas_api.get_ingredient_supplier_master_data(jsonb)
to authenticated;

revoke all on schema atlas_legacy
  from atlas_master_data_command_runtime, atlas_read_runtime;
revoke all on all tables in schema atlas_legacy
  from atlas_master_data_command_runtime, atlas_read_runtime;
revoke execute on function atlas_legacy.import_master_data_snapshot(jsonb)
  from atlas_master_data_command_runtime, atlas_read_runtime;

comment on function atlas_api.update_school_portion_defaults(jsonb) is
  'RMVP-01 versioned command for non-negative school student and teacher portion defaults.';
comment on function atlas_api.create_ingredient(jsonb) is
  'RMVP-01 command creating one complete active ingredient master row.';
comment on function atlas_api.update_ingredient(jsonb) is
  'RMVP-01 versioned command updating purchasing fields without replacing supplier priorities.';
comment on function atlas_api.set_ingredient_lifecycle(jsonb) is
  'RMVP-01 versioned activate, deactivate, or archive command; referenced rows are never deleted.';
comment on function atlas_api.create_supplier(jsonb) is
  'RMVP-01 command creating one supplier with allowlisted contact fields.';
comment on function atlas_api.update_supplier(jsonb) is
  'RMVP-01 versioned supplier name and contact update command.';
comment on function atlas_api.replace_ingredient_supplier_priorities(jsonb) is
  'RMVP-01 atomic full replacement of zero to six unique active supplier priorities for one ingredient.';
comment on function atlas_api.get_school_master_data(jsonb) is
  'RMVP-01 authorized global master-data read returning schools with delivery and supported contract context.';
comment on function atlas_api.get_ingredient_supplier_master_data(jsonb) is
  'RMVP-01 authorized global read returning ingredients, units, suppliers, and current priorities.';

comment on schema atlas_api is
  'Function-only Atlas Data API boundary; includes reviewed operational commands/reads and RMVP-01 master-data commands/reads.';

revoke atlas_master_data_command_runtime, atlas_read_runtime from postgres;
