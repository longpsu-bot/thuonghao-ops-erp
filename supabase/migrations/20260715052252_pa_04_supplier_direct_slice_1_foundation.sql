-- PA-04: minimal Atlas supplier-direct wholesale Slice 1 foundation.
--
-- This migration creates new, private Atlas objects only. It does not touch
-- OPS v1/public tables, seed data, Storage, Edge Functions, or a hosted project.

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'atlas_owner') then
    execute 'create role atlas_owner nologin noinherit';
  end if;

  if not exists (select 1 from pg_roles where rolname = 'atlas_command_runtime') then
    execute 'create role atlas_command_runtime nologin noinherit';
  end if;

  if not exists (select 1 from pg_roles where rolname = 'atlas_read_runtime') then
    execute 'create role atlas_read_runtime nologin noinherit';
  end if;
end
$$;

grant atlas_owner to postgres with set true;

create schema if not exists atlas_core authorization atlas_owner;
create schema if not exists atlas_admin authorization atlas_owner;
create schema if not exists atlas_planning authorization atlas_owner;
create schema if not exists atlas_procurement authorization atlas_owner;
create schema if not exists atlas_evidence authorization atlas_owner;
create schema if not exists atlas_dispatch authorization atlas_owner;
create schema if not exists atlas_audit authorization atlas_owner;
create schema if not exists atlas_reporting authorization atlas_owner;
create schema if not exists atlas_api authorization atlas_owner;

comment on schema atlas_core is 'Private Atlas cross-domain identity, authorization, and command infrastructure.';
comment on schema atlas_admin is 'Private Atlas master references for the supplier-direct Slice 1.';
comment on schema atlas_planning is 'Private Atlas wholesale source, approval, handoff, and delivery-requirement facts.';
comment on schema atlas_procurement is 'Private Atlas fulfilment-allocation and supplier purchase commitments.';
comment on schema atlas_evidence is 'Private source-owned supplier evidence and exact quantity applications.';
comment on schema atlas_dispatch is 'Private Atlas transport, load, departure, and destination-outcome facts.';
comment on schema atlas_audit is 'Private append-only Atlas domain-event and audit evidence.';
comment on schema atlas_reporting is 'Private derived Atlas read models; never an authoritative write or safety-gate surface.';
comment on schema atlas_api is 'Reserved function-only Atlas Data API boundary; PA-04 exposes no functions.';

set role atlas_owner;

create table atlas_core.actors (
  actor_id uuid not null default gen_random_uuid(),
  actor_type text not null,
  display_name text not null,
  actor_status text not null default 'ACTIVE',
  version bigint not null default 1,
  created_at timestamptz not null default transaction_timestamp(),
  deactivated_at timestamptz,
  constraint actors_pkey primary key (actor_id),
  constraint actors_actor_type_check check (
    actor_type in ('HUMAN', 'DELEGATED_DRIVER', 'INTEGRATION', 'MIGRATION', 'EMERGENCY')
  ),
  constraint actors_actor_status_check check (actor_status in ('ACTIVE', 'INACTIVE')),
  constraint actors_version_check check (version > 0),
  constraint actors_deactivation_check check (
    (actor_status = 'ACTIVE' and deactivated_at is null)
    or (actor_status = 'INACTIVE' and deactivated_at is not null)
  )
);

create table atlas_core.actor_auth_subjects (
  actor_auth_subject_id uuid not null default gen_random_uuid(),
  actor_id uuid not null,
  auth_provider text not null default 'SUPABASE_AUTH',
  auth_subject_id uuid not null,
  subject_status text not null default 'ACTIVE',
  linked_at timestamptz not null default transaction_timestamp(),
  revoked_at timestamptz,
  constraint actor_auth_subjects_pkey primary key (actor_auth_subject_id),
  constraint actor_auth_subjects_actor_fkey foreign key (actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint actor_auth_subjects_subject_key unique (auth_provider, auth_subject_id),
  constraint actor_auth_subjects_provider_check check (auth_provider = 'SUPABASE_AUTH'),
  constraint actor_auth_subjects_status_check check (subject_status in ('ACTIVE', 'REVOKED')),
  constraint actor_auth_subjects_revocation_check check (
    (subject_status = 'ACTIVE' and revoked_at is null)
    or (subject_status = 'REVOKED' and revoked_at is not null)
  )
);

create table atlas_core.roles (
  role_id uuid not null default gen_random_uuid(),
  role_code text not null,
  role_name text not null,
  role_status text not null default 'ACTIVE',
  version bigint not null default 1,
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  constraint roles_pkey primary key (role_id),
  constraint roles_role_code_key unique (role_code),
  constraint roles_role_code_check check (role_code = lower(role_code)),
  constraint roles_role_status_check check (role_status in ('ACTIVE', 'INACTIVE')),
  constraint roles_version_check check (version > 0)
);

create table atlas_core.capabilities (
  capability_id uuid not null default gen_random_uuid(),
  capability_code text not null,
  capability_name text not null,
  owning_domain text not null,
  capability_status text not null default 'ACTIVE',
  created_at timestamptz not null default transaction_timestamp(),
  constraint capabilities_pkey primary key (capability_id),
  constraint capabilities_capability_code_key unique (capability_code),
  constraint capabilities_capability_code_check check (capability_code = lower(capability_code)),
  constraint capabilities_owning_domain_check check (
    owning_domain in ('CORE', 'ADMIN', 'PLANNING', 'PROCUREMENT', 'EVIDENCE', 'DISPATCH', 'AUDIT')
  ),
  constraint capabilities_status_check check (capability_status in ('ACTIVE', 'INACTIVE'))
);

create table atlas_core.role_capabilities (
  role_capability_id uuid not null default gen_random_uuid(),
  role_id uuid not null,
  capability_id uuid not null,
  granted_at timestamptz not null default transaction_timestamp(),
  granted_by_actor_id uuid,
  constraint role_capabilities_pkey primary key (role_capability_id),
  constraint role_capabilities_role_fkey foreign key (role_id)
    references atlas_core.roles (role_id) on delete restrict,
  constraint role_capabilities_capability_fkey foreign key (capability_id)
    references atlas_core.capabilities (capability_id) on delete restrict,
  constraint role_capabilities_granted_by_actor_fkey foreign key (granted_by_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint role_capabilities_role_capability_key unique (role_id, capability_id)
);

create table atlas_core.actor_role_memberships (
  actor_role_membership_id uuid not null default gen_random_uuid(),
  actor_id uuid not null,
  role_id uuid not null,
  membership_status text not null default 'ACTIVE',
  effective_from timestamptz not null default transaction_timestamp(),
  effective_to timestamptz,
  granted_by_actor_id uuid,
  reason_note text,
  constraint actor_role_memberships_pkey primary key (actor_role_membership_id),
  constraint actor_role_memberships_actor_fkey foreign key (actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint actor_role_memberships_role_fkey foreign key (role_id)
    references atlas_core.roles (role_id) on delete restrict,
  constraint actor_role_memberships_granted_by_actor_fkey foreign key (granted_by_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint actor_role_memberships_status_check check (membership_status in ('ACTIVE', 'REVOKED', 'EXPIRED')),
  constraint actor_role_memberships_period_check check (effective_to is null or effective_to > effective_from)
);

create table atlas_core.command_receipts (
  command_receipt_id uuid not null default gen_random_uuid(),
  command_name text not null,
  scope_key text not null,
  idempotency_key text not null,
  command_id uuid not null default gen_random_uuid(),
  correlation_id uuid not null,
  actor_id uuid not null,
  expected_version bigint,
  request_hash text not null,
  outcome text not null,
  response_payload jsonb,
  error_code text,
  started_at timestamptz not null default transaction_timestamp(),
  completed_at timestamptz,
  constraint command_receipts_pkey primary key (command_receipt_id),
  constraint command_receipts_actor_fkey foreign key (actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint command_receipts_command_id_key unique (command_id),
  constraint command_receipts_idempotency_key unique (scope_key, command_name, idempotency_key),
  constraint command_receipts_expected_version_check check (expected_version is null or expected_version > 0),
  constraint command_receipts_request_hash_check check (length(request_hash) = 64),
  constraint command_receipts_outcome_check check (
    outcome in ('IN_PROGRESS', 'COMPLETED', 'FAILED_NON_RETRYABLE')
  ),
  constraint command_receipts_completion_check check (
    (outcome = 'IN_PROGRESS' and completed_at is null)
    or (outcome in ('COMPLETED', 'FAILED_NON_RETRYABLE') and completed_at is not null)
  )
);

create table atlas_admin.customers (
  customer_id uuid not null default gen_random_uuid(),
  customer_code text not null,
  customer_name text not null,
  customer_type text not null default 'WHOLESALE',
  customer_status text not null default 'ACTIVE',
  version bigint not null default 1,
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  constraint customers_pkey primary key (customer_id),
  constraint customers_customer_code_key unique (customer_code),
  constraint customers_customer_type_check check (customer_type = 'WHOLESALE'),
  constraint customers_customer_status_check check (customer_status in ('ACTIVE', 'INACTIVE')),
  constraint customers_version_check check (version > 0)
);

create table atlas_admin.delivery_locations (
  delivery_location_id uuid not null default gen_random_uuid(),
  customer_id uuid not null,
  location_code text not null,
  location_name text not null,
  address_text text not null,
  delivery_instructions text,
  timezone_name text not null default 'Asia/Bangkok',
  location_status text not null default 'ACTIVE',
  version bigint not null default 1,
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  constraint delivery_locations_pkey primary key (delivery_location_id),
  constraint delivery_locations_customer_fkey foreign key (customer_id)
    references atlas_admin.customers (customer_id) on delete restrict,
  constraint delivery_locations_customer_code_key unique (customer_id, location_code),
  constraint delivery_locations_status_check check (location_status in ('ACTIVE', 'INACTIVE')),
  constraint delivery_locations_version_check check (version > 0)
);

create table atlas_admin.units (
  unit_id uuid not null default gen_random_uuid(),
  unit_code text not null,
  unit_name text not null,
  dimension_code text not null,
  decimal_scale smallint not null default 6,
  unit_status text not null default 'ACTIVE',
  created_at timestamptz not null default transaction_timestamp(),
  constraint units_pkey primary key (unit_id),
  constraint units_unit_code_key unique (unit_code),
  constraint units_unit_code_check check (unit_code = lower(unit_code)),
  constraint units_decimal_scale_check check (decimal_scale between 0 and 6),
  constraint units_status_check check (unit_status in ('ACTIVE', 'INACTIVE'))
);

create table atlas_admin.ingredients (
  ingredient_id uuid not null default gen_random_uuid(),
  ingredient_code text not null,
  ingredient_name text not null,
  ingredient_group text,
  ingredient_status text not null default 'ACTIVE',
  version bigint not null default 1,
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  constraint ingredients_pkey primary key (ingredient_id),
  constraint ingredients_ingredient_code_key unique (ingredient_code),
  constraint ingredients_status_check check (ingredient_status in ('ACTIVE', 'INACTIVE')),
  constraint ingredients_version_check check (version > 0)
);

create table atlas_admin.suppliers (
  supplier_id uuid not null default gen_random_uuid(),
  supplier_code text not null,
  supplier_name text not null,
  supplier_status text not null default 'ACTIVE',
  version bigint not null default 1,
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  constraint suppliers_pkey primary key (supplier_id),
  constraint suppliers_supplier_code_key unique (supplier_code),
  constraint suppliers_status_check check (supplier_status in ('ACTIVE', 'INACTIVE', 'SUSPENDED')),
  constraint suppliers_version_check check (version > 0)
);

create table atlas_admin.supplier_eligibilities (
  supplier_eligibility_id uuid not null default gen_random_uuid(),
  supplier_id uuid not null,
  ingredient_id uuid not null,
  eligibility_status text not null default 'ACTIVE',
  effective_from date not null,
  effective_to date,
  reason_note text,
  version bigint not null default 1,
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  constraint supplier_eligibilities_pkey primary key (supplier_eligibility_id),
  constraint supplier_eligibilities_supplier_fkey foreign key (supplier_id)
    references atlas_admin.suppliers (supplier_id) on delete restrict,
  constraint supplier_eligibilities_ingredient_fkey foreign key (ingredient_id)
    references atlas_admin.ingredients (ingredient_id) on delete restrict,
  constraint supplier_eligibilities_period_key unique (supplier_id, ingredient_id, effective_from),
  constraint supplier_eligibilities_status_check check (eligibility_status in ('ACTIVE', 'INACTIVE', 'SUSPENDED')),
  constraint supplier_eligibilities_period_check check (effective_to is null or effective_to > effective_from),
  constraint supplier_eligibilities_version_check check (version > 0)
);

create table atlas_planning.wholesale_orders (
  wholesale_order_id uuid not null default gen_random_uuid(),
  customer_id uuid not null,
  delivery_location_id uuid not null,
  customer_order_reference text,
  service_date date not null,
  order_status text not null default 'DRAFT',
  version bigint not null default 1,
  created_by_actor_id uuid not null,
  created_at timestamptz not null default transaction_timestamp(),
  approved_by_actor_id uuid,
  approved_at timestamptz,
  released_by_actor_id uuid,
  released_at timestamptz,
  updated_at timestamptz not null default transaction_timestamp(),
  constraint wholesale_orders_pkey primary key (wholesale_order_id),
  constraint wholesale_orders_customer_fkey foreign key (customer_id)
    references atlas_admin.customers (customer_id) on delete restrict,
  constraint wholesale_orders_location_fkey foreign key (delivery_location_id)
    references atlas_admin.delivery_locations (delivery_location_id) on delete restrict,
  constraint wholesale_orders_created_by_actor_fkey foreign key (created_by_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint wholesale_orders_approved_by_actor_fkey foreign key (approved_by_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint wholesale_orders_released_by_actor_fkey foreign key (released_by_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint wholesale_orders_status_check check (
    order_status in ('DRAFT', 'VALIDATED', 'APPROVED', 'RELEASED', 'REVISED', 'CANCELLED')
  ),
  constraint wholesale_orders_version_check check (version > 0),
  constraint wholesale_orders_approval_check check (
    (approved_by_actor_id is null and approved_at is null)
    or (approved_by_actor_id is not null and approved_at is not null)
  ),
  constraint wholesale_orders_release_check check (
    (released_by_actor_id is null and released_at is null)
    or (released_by_actor_id is not null and released_at is not null)
  )
);

create table atlas_planning.wholesale_order_lines (
  wholesale_order_line_id uuid not null default gen_random_uuid(),
  wholesale_order_id uuid not null,
  source_line_number integer not null,
  created_at timestamptz not null default transaction_timestamp(),
  constraint wholesale_order_lines_pkey primary key (wholesale_order_line_id),
  constraint wholesale_order_lines_order_fkey foreign key (wholesale_order_id)
    references atlas_planning.wholesale_orders (wholesale_order_id) on delete restrict,
  constraint wholesale_order_lines_order_line_key unique (wholesale_order_id, source_line_number),
  constraint wholesale_order_lines_number_check check (source_line_number > 0)
);

create table atlas_planning.wholesale_order_line_revisions (
  wholesale_order_line_revision_id uuid not null default gen_random_uuid(),
  wholesale_order_line_id uuid not null,
  revision_number integer not null,
  ingredient_id uuid not null,
  requested_quantity numeric(20, 6) not null,
  unit_id uuid not null,
  revision_status text not null default 'DRAFT',
  is_current boolean not null default true,
  predecessor_revision_id uuid,
  command_id uuid,
  created_by_actor_id uuid not null,
  created_at timestamptz not null default transaction_timestamp(),
  constraint wholesale_order_line_revisions_pkey primary key (wholesale_order_line_revision_id),
  constraint wholesale_order_line_revisions_line_fkey foreign key (wholesale_order_line_id)
    references atlas_planning.wholesale_order_lines (wholesale_order_line_id) on delete restrict,
  constraint wholesale_order_line_revisions_ingredient_fkey foreign key (ingredient_id)
    references atlas_admin.ingredients (ingredient_id) on delete restrict,
  constraint wholesale_order_line_revisions_unit_fkey foreign key (unit_id)
    references atlas_admin.units (unit_id) on delete restrict,
  constraint wholesale_order_line_revisions_predecessor_fkey foreign key (predecessor_revision_id)
    references atlas_planning.wholesale_order_line_revisions (wholesale_order_line_revision_id) on delete restrict,
  constraint wholesale_order_line_revisions_created_by_actor_fkey foreign key (created_by_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint wholesale_order_line_revisions_line_revision_key unique (wholesale_order_line_id, revision_number),
  constraint wholesale_order_line_revisions_number_check check (revision_number > 0),
  constraint wholesale_order_line_revisions_quantity_check check (requested_quantity > 0),
  constraint wholesale_order_line_revisions_status_check check (
    revision_status in ('DRAFT', 'APPROVED', 'RELEASED', 'SUPERSEDED', 'CANCELLED')
  ),
  constraint wholesale_order_line_revisions_predecessor_check check (
    predecessor_revision_id is null or predecessor_revision_id <> wholesale_order_line_revision_id
  )
);

create table atlas_planning.confirmed_need_batches (
  confirmed_need_batch_id uuid not null default gen_random_uuid(),
  wholesale_order_id uuid not null,
  period_start date not null,
  period_end date not null,
  batch_status text not null default 'DRAFT_REVIEW',
  version bigint not null default 1,
  created_by_actor_id uuid not null,
  created_at timestamptz not null default transaction_timestamp(),
  approved_by_actor_id uuid,
  approved_at timestamptz,
  released_by_actor_id uuid,
  released_at timestamptz,
  updated_at timestamptz not null default transaction_timestamp(),
  constraint confirmed_need_batches_pkey primary key (confirmed_need_batch_id),
  constraint confirmed_need_batches_wholesale_order_fkey foreign key (wholesale_order_id)
    references atlas_planning.wholesale_orders (wholesale_order_id) on delete restrict,
  constraint confirmed_need_batches_created_by_actor_fkey foreign key (created_by_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint confirmed_need_batches_approved_by_actor_fkey foreign key (approved_by_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint confirmed_need_batches_released_by_actor_fkey foreign key (released_by_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint confirmed_need_batches_period_check check (period_end >= period_start),
  constraint confirmed_need_batches_status_check check (
    batch_status in ('DRAFT_REVIEW', 'VALIDATED', 'APPROVED', 'RELEASED_FOR_PURCHASE_HANDOFF', 'REOPENED')
  ),
  constraint confirmed_need_batches_version_check check (version > 0)
);

create table atlas_planning.confirmed_need_lines (
  confirmed_need_line_id uuid not null default gen_random_uuid(),
  confirmed_need_batch_id uuid not null,
  wholesale_order_line_id uuid not null,
  created_at timestamptz not null default transaction_timestamp(),
  constraint confirmed_need_lines_pkey primary key (confirmed_need_line_id),
  constraint confirmed_need_lines_batch_fkey foreign key (confirmed_need_batch_id)
    references atlas_planning.confirmed_need_batches (confirmed_need_batch_id) on delete restrict,
  constraint confirmed_need_lines_wholesale_order_line_fkey foreign key (wholesale_order_line_id)
    references atlas_planning.wholesale_order_lines (wholesale_order_line_id) on delete restrict,
  constraint confirmed_need_lines_source_key unique (confirmed_need_batch_id, wholesale_order_line_id)
);

create table atlas_planning.confirmed_need_line_revisions (
  confirmed_need_line_revision_id uuid not null default gen_random_uuid(),
  confirmed_need_line_id uuid not null,
  revision_number integer not null,
  wholesale_order_line_revision_id uuid not null,
  ingredient_id uuid not null,
  theoretical_quantity numeric(20, 6) not null,
  confirmed_quantity numeric(20, 6) not null,
  unit_id uuid not null,
  revision_status text not null default 'DRAFT',
  is_current boolean not null default true,
  predecessor_revision_id uuid,
  command_id uuid,
  created_by_actor_id uuid not null,
  created_at timestamptz not null default transaction_timestamp(),
  constraint confirmed_need_line_revisions_pkey primary key (confirmed_need_line_revision_id),
  constraint confirmed_need_line_revisions_line_fkey foreign key (confirmed_need_line_id)
    references atlas_planning.confirmed_need_lines (confirmed_need_line_id) on delete restrict,
  constraint confirmed_need_line_revisions_source_revision_fkey foreign key (wholesale_order_line_revision_id)
    references atlas_planning.wholesale_order_line_revisions (wholesale_order_line_revision_id) on delete restrict,
  constraint confirmed_need_line_revisions_ingredient_fkey foreign key (ingredient_id)
    references atlas_admin.ingredients (ingredient_id) on delete restrict,
  constraint confirmed_need_line_revisions_unit_fkey foreign key (unit_id)
    references atlas_admin.units (unit_id) on delete restrict,
  constraint confirmed_need_line_revisions_predecessor_fkey foreign key (predecessor_revision_id)
    references atlas_planning.confirmed_need_line_revisions (confirmed_need_line_revision_id) on delete restrict,
  constraint confirmed_need_line_revisions_created_by_actor_fkey foreign key (created_by_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint confirmed_need_line_revisions_line_revision_key unique (confirmed_need_line_id, revision_number),
  constraint confirmed_need_line_revisions_number_check check (revision_number > 0),
  constraint confirmed_need_line_revisions_quantity_check check (
    theoretical_quantity >= 0 and confirmed_quantity >= 0
  ),
  constraint confirmed_need_line_revisions_status_check check (
    revision_status in ('DRAFT', 'APPROVED', 'RELEASED', 'SUPERSEDED')
  ),
  constraint confirmed_need_line_revisions_predecessor_check check (
    predecessor_revision_id is null or predecessor_revision_id <> confirmed_need_line_revision_id
  )
);

create table atlas_planning.confirmed_need_approval_snapshots (
  confirmed_need_approval_snapshot_id uuid not null default gen_random_uuid(),
  confirmed_need_batch_id uuid not null,
  approved_version bigint not null,
  approved_by_actor_id uuid not null,
  approved_at timestamptz not null,
  command_id uuid not null,
  constraint confirmed_need_approval_snapshots_pkey primary key (confirmed_need_approval_snapshot_id),
  constraint confirmed_need_approval_snapshots_batch_fkey foreign key (confirmed_need_batch_id)
    references atlas_planning.confirmed_need_batches (confirmed_need_batch_id) on delete restrict,
  constraint confirmed_need_approval_snapshots_actor_fkey foreign key (approved_by_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint confirmed_need_approval_snapshots_version_key unique (confirmed_need_batch_id, approved_version),
  constraint confirmed_need_approval_snapshots_command_key unique (command_id),
  constraint confirmed_need_approval_snapshots_version_check check (approved_version > 0)
);

create table atlas_planning.confirmed_need_snapshot_lines (
  confirmed_need_snapshot_line_id uuid not null default gen_random_uuid(),
  confirmed_need_approval_snapshot_id uuid not null,
  confirmed_need_line_revision_id uuid not null,
  ingredient_id uuid not null,
  approved_quantity numeric(20, 6) not null,
  unit_id uuid not null,
  ingredient_name_snapshot text not null,
  constraint confirmed_need_snapshot_lines_pkey primary key (confirmed_need_snapshot_line_id),
  constraint confirmed_need_snapshot_lines_snapshot_fkey foreign key (confirmed_need_approval_snapshot_id)
    references atlas_planning.confirmed_need_approval_snapshots (confirmed_need_approval_snapshot_id) on delete restrict,
  constraint confirmed_need_snapshot_lines_revision_fkey foreign key (confirmed_need_line_revision_id)
    references atlas_planning.confirmed_need_line_revisions (confirmed_need_line_revision_id) on delete restrict,
  constraint confirmed_need_snapshot_lines_ingredient_fkey foreign key (ingredient_id)
    references atlas_admin.ingredients (ingredient_id) on delete restrict,
  constraint confirmed_need_snapshot_lines_unit_fkey foreign key (unit_id)
    references atlas_admin.units (unit_id) on delete restrict,
  constraint confirmed_need_snapshot_lines_snapshot_line_key unique (
    confirmed_need_approval_snapshot_id,
    confirmed_need_line_revision_id
  ),
  constraint confirmed_need_snapshot_lines_quantity_check check (approved_quantity >= 0)
);

create table atlas_planning.purchase_handoff_batches (
  purchase_handoff_batch_id uuid not null default gen_random_uuid(),
  confirmed_need_batch_id uuid not null,
  period_start date not null,
  period_end date not null,
  handoff_status text not null default 'PREPARED',
  version bigint not null default 1,
  created_by_actor_id uuid not null,
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  constraint purchase_handoff_batches_pkey primary key (purchase_handoff_batch_id),
  constraint purchase_handoff_batches_confirmed_need_batch_fkey foreign key (confirmed_need_batch_id)
    references atlas_planning.confirmed_need_batches (confirmed_need_batch_id) on delete restrict,
  constraint purchase_handoff_batches_created_by_actor_fkey foreign key (created_by_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint purchase_handoff_batches_confirmed_need_key unique (confirmed_need_batch_id),
  constraint purchase_handoff_batches_period_check check (period_end >= period_start),
  constraint purchase_handoff_batches_status_check check (
    handoff_status in ('PREPARED', 'VALIDATED', 'RELEASED_TO_PROCUREMENT', 'INVALIDATED', 'REOPENED')
  ),
  constraint purchase_handoff_batches_version_check check (version > 0)
);

create table atlas_planning.purchase_handoff_revisions (
  purchase_handoff_revision_id uuid not null default gen_random_uuid(),
  purchase_handoff_batch_id uuid not null,
  revision_number integer not null,
  revision_kind text not null default 'BASE',
  revision_status text not null default 'PREPARED',
  is_current boolean not null default true,
  predecessor_revision_id uuid,
  released_by_actor_id uuid,
  released_at timestamptz,
  reason_note text,
  command_id uuid,
  created_at timestamptz not null default transaction_timestamp(),
  constraint purchase_handoff_revisions_pkey primary key (purchase_handoff_revision_id),
  constraint purchase_handoff_revisions_batch_fkey foreign key (purchase_handoff_batch_id)
    references atlas_planning.purchase_handoff_batches (purchase_handoff_batch_id) on delete restrict,
  constraint purchase_handoff_revisions_predecessor_fkey foreign key (predecessor_revision_id)
    references atlas_planning.purchase_handoff_revisions (purchase_handoff_revision_id) on delete restrict,
  constraint purchase_handoff_revisions_released_by_actor_fkey foreign key (released_by_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint purchase_handoff_revisions_batch_revision_key unique (purchase_handoff_batch_id, revision_number),
  constraint purchase_handoff_revisions_number_check check (revision_number > 0),
  constraint purchase_handoff_revisions_kind_check check (
    revision_kind in ('BASE', 'SUPERSEDING', 'ADDITIVE', 'CANCELLATION')
  ),
  constraint purchase_handoff_revisions_status_check check (
    revision_status in ('PREPARED', 'VALIDATED', 'RELEASED_TO_PROCUREMENT', 'INVALIDATED')
  ),
  constraint purchase_handoff_revisions_release_check check (
    (released_by_actor_id is null and released_at is null)
    or (released_by_actor_id is not null and released_at is not null)
  ),
  constraint purchase_handoff_revisions_predecessor_check check (
    predecessor_revision_id is null or predecessor_revision_id <> purchase_handoff_revision_id
  )
);

create table atlas_planning.purchase_handoff_lines (
  purchase_handoff_line_id uuid not null default gen_random_uuid(),
  purchase_handoff_batch_id uuid not null,
  confirmed_need_line_id uuid not null,
  created_at timestamptz not null default transaction_timestamp(),
  constraint purchase_handoff_lines_pkey primary key (purchase_handoff_line_id),
  constraint purchase_handoff_lines_batch_fkey foreign key (purchase_handoff_batch_id)
    references atlas_planning.purchase_handoff_batches (purchase_handoff_batch_id) on delete restrict,
  constraint purchase_handoff_lines_confirmed_need_line_fkey foreign key (confirmed_need_line_id)
    references atlas_planning.confirmed_need_lines (confirmed_need_line_id) on delete restrict,
  constraint purchase_handoff_lines_source_key unique (purchase_handoff_batch_id, confirmed_need_line_id)
);

create table atlas_planning.purchase_handoff_line_revisions (
  purchase_handoff_line_revision_id uuid not null default gen_random_uuid(),
  purchase_handoff_revision_id uuid not null,
  purchase_handoff_line_id uuid not null,
  confirmed_need_line_revision_id uuid not null,
  ingredient_id uuid not null,
  handoff_quantity numeric(20, 6) not null,
  unit_id uuid not null,
  service_date date not null,
  delivery_location_id uuid not null,
  predecessor_revision_id uuid,
  command_id uuid,
  created_at timestamptz not null default transaction_timestamp(),
  constraint purchase_handoff_line_revisions_pkey primary key (purchase_handoff_line_revision_id),
  constraint purchase_handoff_line_revisions_revision_fkey foreign key (purchase_handoff_revision_id)
    references atlas_planning.purchase_handoff_revisions (purchase_handoff_revision_id) on delete restrict,
  constraint purchase_handoff_line_revisions_line_fkey foreign key (purchase_handoff_line_id)
    references atlas_planning.purchase_handoff_lines (purchase_handoff_line_id) on delete restrict,
  constraint purchase_handoff_line_revisions_confirmed_need_revision_fkey foreign key (confirmed_need_line_revision_id)
    references atlas_planning.confirmed_need_line_revisions (confirmed_need_line_revision_id) on delete restrict,
  constraint purchase_handoff_line_revisions_ingredient_fkey foreign key (ingredient_id)
    references atlas_admin.ingredients (ingredient_id) on delete restrict,
  constraint purchase_handoff_line_revisions_unit_fkey foreign key (unit_id)
    references atlas_admin.units (unit_id) on delete restrict,
  constraint purchase_handoff_line_revisions_location_fkey foreign key (delivery_location_id)
    references atlas_admin.delivery_locations (delivery_location_id) on delete restrict,
  constraint purchase_handoff_line_revisions_predecessor_fkey foreign key (predecessor_revision_id)
    references atlas_planning.purchase_handoff_line_revisions (purchase_handoff_line_revision_id) on delete restrict,
  constraint purchase_handoff_line_revisions_revision_line_key unique (
    purchase_handoff_revision_id,
    purchase_handoff_line_id
  ),
  constraint purchase_handoff_line_revisions_quantity_check check (handoff_quantity > 0),
  constraint purchase_handoff_line_revisions_predecessor_check check (
    predecessor_revision_id is null or predecessor_revision_id <> purchase_handoff_line_revision_id
  )
);

create table atlas_planning.purchase_demand_references (
  purchase_demand_reference_id uuid not null default gen_random_uuid(),
  purchase_handoff_line_revision_id uuid not null,
  confirmed_need_snapshot_line_id uuid not null,
  wholesale_order_line_revision_id uuid not null,
  approved_quantity numeric(20, 6) not null,
  unit_id uuid not null,
  constraint purchase_demand_references_pkey primary key (purchase_demand_reference_id),
  constraint purchase_demand_references_handoff_line_revision_fkey foreign key (purchase_handoff_line_revision_id)
    references atlas_planning.purchase_handoff_line_revisions (purchase_handoff_line_revision_id) on delete restrict,
  constraint purchase_demand_references_confirmed_snapshot_line_fkey foreign key (confirmed_need_snapshot_line_id)
    references atlas_planning.confirmed_need_snapshot_lines (confirmed_need_snapshot_line_id) on delete restrict,
  constraint purchase_demand_references_wholesale_revision_fkey foreign key (wholesale_order_line_revision_id)
    references atlas_planning.wholesale_order_line_revisions (wholesale_order_line_revision_id) on delete restrict,
  constraint purchase_demand_references_unit_fkey foreign key (unit_id)
    references atlas_admin.units (unit_id) on delete restrict,
  constraint purchase_demand_references_handoff_line_key unique (purchase_handoff_line_revision_id),
  constraint purchase_demand_references_quantity_check check (approved_quantity >= 0)
);

create table atlas_planning.dispatch_requirements (
  dispatch_requirement_id uuid not null default gen_random_uuid(),
  source_of_need text not null default 'WHOLESALE',
  customer_id uuid not null,
  delivery_location_id uuid not null,
  service_date date not null,
  requirement_status text not null default 'DRAFT',
  version bigint not null default 1,
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  constraint dispatch_requirements_pkey primary key (dispatch_requirement_id),
  constraint dispatch_requirements_customer_fkey foreign key (customer_id)
    references atlas_admin.customers (customer_id) on delete restrict,
  constraint dispatch_requirements_location_fkey foreign key (delivery_location_id)
    references atlas_admin.delivery_locations (delivery_location_id) on delete restrict,
  constraint dispatch_requirements_source_check check (source_of_need = 'WHOLESALE'),
  constraint dispatch_requirements_status_check check (
    requirement_status in ('DRAFT', 'RELEASED', 'REVISED', 'CANCELLED')
  ),
  constraint dispatch_requirements_version_check check (version > 0)
);

create table atlas_planning.dispatch_requirement_revisions (
  dispatch_requirement_revision_id uuid not null default gen_random_uuid(),
  dispatch_requirement_id uuid not null,
  purchase_handoff_revision_id uuid not null,
  revision_number integer not null,
  revision_kind text not null default 'BASE',
  revision_status text not null default 'PREPARED',
  is_current boolean not null default true,
  predecessor_revision_id uuid,
  customer_name_snapshot text not null,
  location_name_snapshot text not null,
  address_snapshot text not null,
  timezone_name text not null default 'Asia/Bangkok',
  window_start_local time,
  window_end_local time,
  released_by_actor_id uuid,
  released_at timestamptz,
  reason_note text,
  command_id uuid,
  created_at timestamptz not null default transaction_timestamp(),
  constraint dispatch_requirement_revisions_pkey primary key (dispatch_requirement_revision_id),
  constraint dispatch_requirement_revisions_requirement_fkey foreign key (dispatch_requirement_id)
    references atlas_planning.dispatch_requirements (dispatch_requirement_id) on delete restrict,
  constraint dispatch_requirement_revisions_handoff_revision_fkey foreign key (purchase_handoff_revision_id)
    references atlas_planning.purchase_handoff_revisions (purchase_handoff_revision_id) on delete restrict,
  constraint dispatch_requirement_revisions_predecessor_fkey foreign key (predecessor_revision_id)
    references atlas_planning.dispatch_requirement_revisions (dispatch_requirement_revision_id) on delete restrict,
  constraint dispatch_requirement_revisions_released_by_actor_fkey foreign key (released_by_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint dispatch_requirement_revisions_requirement_revision_key unique (
    dispatch_requirement_id,
    revision_number
  ),
  constraint dispatch_requirement_revisions_number_check check (revision_number > 0),
  constraint dispatch_requirement_revisions_kind_check check (
    revision_kind in ('BASE', 'SUPERSEDING', 'ADDITIVE', 'CANCELLATION')
  ),
  constraint dispatch_requirement_revisions_status_check check (
    revision_status in ('PREPARED', 'RELEASED', 'SUPERSEDED', 'CANCELLED')
  ),
  constraint dispatch_requirement_revisions_release_check check (
    (released_by_actor_id is null and released_at is null)
    or (released_by_actor_id is not null and released_at is not null)
  ),
  constraint dispatch_requirement_revisions_predecessor_check check (
    predecessor_revision_id is null or predecessor_revision_id <> dispatch_requirement_revision_id
  )
);

create table atlas_planning.dispatch_requirement_lines (
  dispatch_requirement_line_id uuid not null default gen_random_uuid(),
  dispatch_requirement_id uuid not null,
  purchase_handoff_line_id uuid not null,
  created_at timestamptz not null default transaction_timestamp(),
  constraint dispatch_requirement_lines_pkey primary key (dispatch_requirement_line_id),
  constraint dispatch_requirement_lines_requirement_fkey foreign key (dispatch_requirement_id)
    references atlas_planning.dispatch_requirements (dispatch_requirement_id) on delete restrict,
  constraint dispatch_requirement_lines_handoff_line_fkey foreign key (purchase_handoff_line_id)
    references atlas_planning.purchase_handoff_lines (purchase_handoff_line_id) on delete restrict,
  constraint dispatch_requirement_lines_source_key unique (
    dispatch_requirement_id,
    purchase_handoff_line_id
  )
);

create table atlas_planning.dispatch_requirement_line_revisions (
  dispatch_requirement_line_revision_id uuid not null default gen_random_uuid(),
  dispatch_requirement_revision_id uuid not null,
  dispatch_requirement_line_id uuid not null,
  purchase_handoff_line_revision_id uuid not null,
  ingredient_id uuid not null,
  required_quantity numeric(20, 6) not null,
  unit_id uuid not null,
  predecessor_revision_id uuid,
  created_at timestamptz not null default transaction_timestamp(),
  constraint dispatch_requirement_line_revisions_pkey primary key (dispatch_requirement_line_revision_id),
  constraint dispatch_requirement_line_revisions_requirement_revision_fkey foreign key (dispatch_requirement_revision_id)
    references atlas_planning.dispatch_requirement_revisions (dispatch_requirement_revision_id) on delete restrict,
  constraint dispatch_requirement_line_revisions_line_fkey foreign key (dispatch_requirement_line_id)
    references atlas_planning.dispatch_requirement_lines (dispatch_requirement_line_id) on delete restrict,
  constraint dispatch_requirement_line_revisions_handoff_line_revision_fkey foreign key (purchase_handoff_line_revision_id)
    references atlas_planning.purchase_handoff_line_revisions (purchase_handoff_line_revision_id) on delete restrict,
  constraint dispatch_requirement_line_revisions_ingredient_fkey foreign key (ingredient_id)
    references atlas_admin.ingredients (ingredient_id) on delete restrict,
  constraint dispatch_requirement_line_revisions_unit_fkey foreign key (unit_id)
    references atlas_admin.units (unit_id) on delete restrict,
  constraint dispatch_requirement_line_revisions_predecessor_fkey foreign key (predecessor_revision_id)
    references atlas_planning.dispatch_requirement_line_revisions (dispatch_requirement_line_revision_id) on delete restrict,
  constraint dispatch_requirement_line_revisions_revision_line_key unique (
    dispatch_requirement_revision_id,
    dispatch_requirement_line_id
  ),
  constraint dispatch_requirement_line_revisions_quantity_check check (required_quantity > 0),
  constraint dispatch_requirement_line_revisions_predecessor_check check (
    predecessor_revision_id is null or predecessor_revision_id <> dispatch_requirement_line_revision_id
  )
);

create table atlas_procurement.fulfilment_allocations (
  fulfilment_allocation_id uuid not null default gen_random_uuid(),
  dispatch_requirement_id uuid not null,
  allocation_status text not null default 'DRAFT',
  version bigint not null default 1,
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  constraint fulfilment_allocations_pkey primary key (fulfilment_allocation_id),
  constraint fulfilment_allocations_requirement_fkey foreign key (dispatch_requirement_id)
    references atlas_planning.dispatch_requirements (dispatch_requirement_id) on delete restrict,
  constraint fulfilment_allocations_requirement_key unique (dispatch_requirement_id),
  constraint fulfilment_allocations_status_check check (
    allocation_status in (
      'DRAFT',
      'ALLOCATED',
      'VALIDATED',
      'READY_FOR_PHYSICAL_FULFILMENT',
      'EVIDENCE_PENDING',
      'EVIDENCE_RECORDED',
      'READY_FOR_DISPATCH',
      'REVISED_WITH_REASON'
    )
  ),
  constraint fulfilment_allocations_version_check check (version > 0)
);

create table atlas_procurement.fulfilment_allocation_revisions (
  fulfilment_allocation_revision_id uuid not null default gen_random_uuid(),
  fulfilment_allocation_id uuid not null,
  revision_number integer not null,
  revision_kind text not null default 'BASE',
  revision_status text not null default 'ALLOCATED',
  is_current boolean not null default true,
  predecessor_revision_id uuid,
  allocated_by_actor_id uuid not null,
  allocated_at timestamptz not null default transaction_timestamp(),
  reason_note text,
  command_id uuid,
  constraint fulfilment_allocation_revisions_pkey primary key (fulfilment_allocation_revision_id),
  constraint fulfilment_allocation_revisions_allocation_fkey foreign key (fulfilment_allocation_id)
    references atlas_procurement.fulfilment_allocations (fulfilment_allocation_id) on delete restrict,
  constraint fulfilment_allocation_revisions_predecessor_fkey foreign key (predecessor_revision_id)
    references atlas_procurement.fulfilment_allocation_revisions (fulfilment_allocation_revision_id) on delete restrict,
  constraint fulfilment_allocation_revisions_actor_fkey foreign key (allocated_by_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint fulfilment_allocation_revisions_allocation_revision_key unique (
    fulfilment_allocation_id,
    revision_number
  ),
  constraint fulfilment_allocation_revisions_number_check check (revision_number > 0),
  constraint fulfilment_allocation_revisions_kind_check check (
    revision_kind in ('BASE', 'SUPERSEDING', 'CANCELLATION')
  ),
  constraint fulfilment_allocation_revisions_status_check check (
    revision_status in (
      'ALLOCATED',
      'VALIDATED',
      'READY_FOR_PHYSICAL_FULFILMENT',
      'EVIDENCE_PENDING',
      'EVIDENCE_RECORDED',
      'READY_FOR_DISPATCH',
      'REVISED_WITH_REASON'
    )
  ),
  constraint fulfilment_allocation_revisions_predecessor_check check (
    predecessor_revision_id is null or predecessor_revision_id <> fulfilment_allocation_revision_id
  )
);

create table atlas_procurement.fulfilment_allocation_lines (
  fulfilment_allocation_line_id uuid not null default gen_random_uuid(),
  fulfilment_allocation_id uuid not null,
  dispatch_requirement_line_id uuid not null,
  portion_sequence integer not null default 1,
  created_at timestamptz not null default transaction_timestamp(),
  constraint fulfilment_allocation_lines_pkey primary key (fulfilment_allocation_line_id),
  constraint fulfilment_allocation_lines_allocation_fkey foreign key (fulfilment_allocation_id)
    references atlas_procurement.fulfilment_allocations (fulfilment_allocation_id) on delete restrict,
  constraint fulfilment_allocation_lines_requirement_line_fkey foreign key (dispatch_requirement_line_id)
    references atlas_planning.dispatch_requirement_lines (dispatch_requirement_line_id) on delete restrict,
  constraint fulfilment_allocation_lines_portion_key unique (
    fulfilment_allocation_id,
    dispatch_requirement_line_id,
    portion_sequence
  ),
  constraint fulfilment_allocation_lines_portion_sequence_check check (portion_sequence > 0)
);

create table atlas_procurement.fulfilment_allocation_line_revisions (
  fulfilment_allocation_line_revision_id uuid not null default gen_random_uuid(),
  fulfilment_allocation_revision_id uuid not null,
  fulfilment_allocation_line_id uuid not null,
  dispatch_requirement_line_revision_id uuid not null,
  fulfilment_source_type text not null default 'SUPPLIER_PO',
  supplier_id uuid not null,
  allocated_quantity numeric(20, 6) not null,
  unit_id uuid not null,
  line_status text not null default 'ALLOCATED',
  predecessor_revision_id uuid,
  created_at timestamptz not null default transaction_timestamp(),
  constraint fulfilment_allocation_line_revisions_pkey primary key (fulfilment_allocation_line_revision_id),
  constraint fulfilment_allocation_line_revisions_allocation_revision_fkey foreign key (fulfilment_allocation_revision_id)
    references atlas_procurement.fulfilment_allocation_revisions (fulfilment_allocation_revision_id) on delete restrict,
  constraint fulfilment_allocation_line_revisions_line_fkey foreign key (fulfilment_allocation_line_id)
    references atlas_procurement.fulfilment_allocation_lines (fulfilment_allocation_line_id) on delete restrict,
  constraint allocation_line_revisions_requirement_revision_fkey foreign key (dispatch_requirement_line_revision_id)
    references atlas_planning.dispatch_requirement_line_revisions (dispatch_requirement_line_revision_id) on delete restrict,
  constraint fulfilment_allocation_line_revisions_supplier_fkey foreign key (supplier_id)
    references atlas_admin.suppliers (supplier_id) on delete restrict,
  constraint fulfilment_allocation_line_revisions_unit_fkey foreign key (unit_id)
    references atlas_admin.units (unit_id) on delete restrict,
  constraint fulfilment_allocation_line_revisions_predecessor_fkey foreign key (predecessor_revision_id)
    references atlas_procurement.fulfilment_allocation_line_revisions (fulfilment_allocation_line_revision_id) on delete restrict,
  constraint fulfilment_allocation_line_revisions_revision_line_key unique (
    fulfilment_allocation_revision_id,
    fulfilment_allocation_line_id
  ),
  constraint fulfilment_allocation_line_revisions_source_check check (fulfilment_source_type = 'SUPPLIER_PO'),
  constraint fulfilment_allocation_line_revisions_quantity_check check (allocated_quantity > 0),
  constraint fulfilment_allocation_line_revisions_status_check check (
    line_status in ('ALLOCATED', 'READY_FOR_EVIDENCE', 'EVIDENCED', 'SUPERSEDED')
  ),
  constraint fulfilment_allocation_line_revisions_predecessor_check check (
    predecessor_revision_id is null or predecessor_revision_id <> fulfilment_allocation_line_revision_id
  )
);

create table atlas_procurement.purchase_orders (
  purchase_order_id uuid not null default gen_random_uuid(),
  supplier_id uuid not null,
  document_number text,
  purchase_order_status text not null default 'DRAFT',
  version bigint not null default 1,
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  constraint purchase_orders_pkey primary key (purchase_order_id),
  constraint purchase_orders_supplier_fkey foreign key (supplier_id)
    references atlas_admin.suppliers (supplier_id) on delete restrict,
  constraint purchase_orders_status_check check (
    purchase_order_status in (
      'DRAFT',
      'VALIDATED',
      'RELEASED_TO_SUPPLIER',
      'SUPPLIER_CONFIRMED',
      'CANCELLED',
      'SUPERSEDED'
    )
  ),
  constraint purchase_orders_version_check check (version > 0)
);

create table atlas_procurement.purchase_order_revisions (
  purchase_order_revision_id uuid not null default gen_random_uuid(),
  purchase_order_id uuid not null,
  revision_number integer not null,
  revision_kind text not null default 'BASE',
  revision_status text not null default 'DRAFT',
  is_current boolean not null default true,
  predecessor_revision_id uuid,
  service_date date not null,
  delivery_location_id uuid not null,
  supplier_name_snapshot text not null,
  delivery_location_snapshot text not null,
  released_by_actor_id uuid,
  released_at timestamptz,
  reason_note text,
  command_id uuid,
  created_at timestamptz not null default transaction_timestamp(),
  constraint purchase_order_revisions_pkey primary key (purchase_order_revision_id),
  constraint purchase_order_revisions_purchase_order_fkey foreign key (purchase_order_id)
    references atlas_procurement.purchase_orders (purchase_order_id) on delete restrict,
  constraint purchase_order_revisions_predecessor_fkey foreign key (predecessor_revision_id)
    references atlas_procurement.purchase_order_revisions (purchase_order_revision_id) on delete restrict,
  constraint purchase_order_revisions_location_fkey foreign key (delivery_location_id)
    references atlas_admin.delivery_locations (delivery_location_id) on delete restrict,
  constraint purchase_order_revisions_released_by_actor_fkey foreign key (released_by_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint purchase_order_revisions_order_revision_key unique (purchase_order_id, revision_number),
  constraint purchase_order_revisions_number_check check (revision_number > 0),
  constraint purchase_order_revisions_kind_check check (
    revision_kind in ('BASE', 'SUPERSEDING', 'CANCELLATION')
  ),
  constraint purchase_order_revisions_status_check check (
    revision_status in (
      'DRAFT',
      'VALIDATED',
      'RELEASED_TO_SUPPLIER',
      'SUPPLIER_CONFIRMED',
      'CANCELLED',
      'SUPERSEDED'
    )
  ),
  constraint purchase_order_revisions_release_check check (
    (released_by_actor_id is null and released_at is null)
    or (released_by_actor_id is not null and released_at is not null)
  ),
  constraint purchase_order_revisions_predecessor_check check (
    predecessor_revision_id is null or predecessor_revision_id <> purchase_order_revision_id
  )
);

create table atlas_procurement.purchase_order_lines (
  purchase_order_line_id uuid not null default gen_random_uuid(),
  purchase_order_id uuid not null,
  fulfilment_allocation_line_id uuid not null,
  created_at timestamptz not null default transaction_timestamp(),
  constraint purchase_order_lines_pkey primary key (purchase_order_line_id),
  constraint purchase_order_lines_purchase_order_fkey foreign key (purchase_order_id)
    references atlas_procurement.purchase_orders (purchase_order_id) on delete restrict,
  constraint purchase_order_lines_allocation_line_fkey foreign key (fulfilment_allocation_line_id)
    references atlas_procurement.fulfilment_allocation_lines (fulfilment_allocation_line_id) on delete restrict,
  constraint purchase_order_lines_source_key unique (purchase_order_id, fulfilment_allocation_line_id)
);

create table atlas_procurement.purchase_order_line_revisions (
  purchase_order_line_revision_id uuid not null default gen_random_uuid(),
  purchase_order_revision_id uuid not null,
  purchase_order_line_id uuid not null,
  fulfilment_allocation_line_revision_id uuid not null,
  ingredient_id uuid not null,
  ordered_quantity numeric(20, 6) not null,
  unit_id uuid not null,
  delivery_location_id uuid not null,
  service_date date not null,
  predecessor_revision_id uuid,
  created_at timestamptz not null default transaction_timestamp(),
  constraint purchase_order_line_revisions_pkey primary key (purchase_order_line_revision_id),
  constraint purchase_order_line_revisions_order_revision_fkey foreign key (purchase_order_revision_id)
    references atlas_procurement.purchase_order_revisions (purchase_order_revision_id) on delete restrict,
  constraint purchase_order_line_revisions_line_fkey foreign key (purchase_order_line_id)
    references atlas_procurement.purchase_order_lines (purchase_order_line_id) on delete restrict,
  constraint purchase_order_line_revisions_allocation_line_revision_fkey foreign key (fulfilment_allocation_line_revision_id)
    references atlas_procurement.fulfilment_allocation_line_revisions (fulfilment_allocation_line_revision_id) on delete restrict,
  constraint purchase_order_line_revisions_ingredient_fkey foreign key (ingredient_id)
    references atlas_admin.ingredients (ingredient_id) on delete restrict,
  constraint purchase_order_line_revisions_unit_fkey foreign key (unit_id)
    references atlas_admin.units (unit_id) on delete restrict,
  constraint purchase_order_line_revisions_location_fkey foreign key (delivery_location_id)
    references atlas_admin.delivery_locations (delivery_location_id) on delete restrict,
  constraint purchase_order_line_revisions_predecessor_fkey foreign key (predecessor_revision_id)
    references atlas_procurement.purchase_order_line_revisions (purchase_order_line_revision_id) on delete restrict,
  constraint purchase_order_line_revisions_revision_line_key unique (
    purchase_order_revision_id,
    purchase_order_line_id
  ),
  constraint purchase_order_line_revisions_quantity_check check (ordered_quantity > 0),
  constraint purchase_order_line_revisions_predecessor_check check (
    predecessor_revision_id is null or predecessor_revision_id <> purchase_order_line_revision_id
  )
);

create table atlas_evidence.supplier_receiving_evidence (
  supplier_receiving_evidence_id uuid not null default gen_random_uuid(),
  supplier_id uuid not null,
  purchase_order_line_revision_id uuid not null,
  ingredient_id uuid not null,
  evidence_reference text not null,
  evidence_quantity numeric(20, 6) not null,
  unit_id uuid not null,
  evidence_status text not null default 'VALID',
  supersedes_evidence_id uuid,
  reason_note text,
  occurred_at timestamptz not null,
  recorded_at timestamptz not null default transaction_timestamp(),
  recorded_by_actor_id uuid not null,
  command_id uuid not null,
  correlation_id uuid not null,
  constraint supplier_receiving_evidence_pkey primary key (supplier_receiving_evidence_id),
  constraint supplier_receiving_evidence_supplier_fkey foreign key (supplier_id)
    references atlas_admin.suppliers (supplier_id) on delete restrict,
  constraint supplier_receiving_evidence_po_line_revision_fkey foreign key (purchase_order_line_revision_id)
    references atlas_procurement.purchase_order_line_revisions (purchase_order_line_revision_id) on delete restrict,
  constraint supplier_receiving_evidence_ingredient_fkey foreign key (ingredient_id)
    references atlas_admin.ingredients (ingredient_id) on delete restrict,
  constraint supplier_receiving_evidence_unit_fkey foreign key (unit_id)
    references atlas_admin.units (unit_id) on delete restrict,
  constraint supplier_receiving_evidence_supersedes_fkey foreign key (supersedes_evidence_id)
    references atlas_evidence.supplier_receiving_evidence (supplier_receiving_evidence_id) on delete restrict,
  constraint supplier_receiving_evidence_actor_fkey foreign key (recorded_by_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint supplier_receiving_evidence_reference_key unique (supplier_id, evidence_reference),
  constraint supplier_receiving_evidence_command_key unique (command_id),
  constraint supplier_receiving_evidence_quantity_check check (evidence_quantity > 0),
  constraint supplier_receiving_evidence_status_check check (
    evidence_status in ('VALID', 'SUPERSEDED', 'VOIDED')
  ),
  constraint supplier_receiving_evidence_time_check check (recorded_at >= occurred_at),
  constraint supplier_receiving_evidence_supersedes_check check (
    supersedes_evidence_id is null or supersedes_evidence_id <> supplier_receiving_evidence_id
  )
);

create table atlas_evidence.evidence_applications (
  evidence_application_id uuid not null default gen_random_uuid(),
  supplier_receiving_evidence_id uuid not null,
  fulfilment_allocation_line_revision_id uuid not null,
  applied_quantity numeric(20, 6) not null,
  unit_id uuid not null,
  application_status text not null default 'VALID',
  supersedes_evidence_application_id uuid,
  reason_note text,
  occurred_at timestamptz not null,
  recorded_at timestamptz not null default transaction_timestamp(),
  recorded_by_actor_id uuid not null,
  command_id uuid not null,
  correlation_id uuid not null,
  constraint evidence_applications_pkey primary key (evidence_application_id),
  constraint evidence_applications_evidence_fkey foreign key (supplier_receiving_evidence_id)
    references atlas_evidence.supplier_receiving_evidence (supplier_receiving_evidence_id) on delete restrict,
  constraint evidence_applications_allocation_line_revision_fkey foreign key (fulfilment_allocation_line_revision_id)
    references atlas_procurement.fulfilment_allocation_line_revisions (fulfilment_allocation_line_revision_id) on delete restrict,
  constraint evidence_applications_unit_fkey foreign key (unit_id)
    references atlas_admin.units (unit_id) on delete restrict,
  constraint evidence_applications_supersedes_fkey foreign key (supersedes_evidence_application_id)
    references atlas_evidence.evidence_applications (evidence_application_id) on delete restrict,
  constraint evidence_applications_actor_fkey foreign key (recorded_by_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint evidence_applications_command_key unique (command_id),
  constraint evidence_applications_quantity_check check (applied_quantity > 0),
  constraint evidence_applications_status_check check (
    application_status in ('VALID', 'SUPERSEDED', 'VOIDED')
  ),
  constraint evidence_applications_time_check check (recorded_at >= occurred_at),
  constraint evidence_applications_supersedes_check check (
    supersedes_evidence_application_id is null
    or supersedes_evidence_application_id <> evidence_application_id
  )
);

create table atlas_dispatch.dispatch_plans (
  dispatch_plan_id uuid not null default gen_random_uuid(),
  plan_reference text not null,
  service_date date not null,
  dispatch_wave text,
  plan_status text not null default 'PLANNED',
  version bigint not null default 1,
  created_by_actor_id uuid not null,
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  constraint dispatch_plans_pkey primary key (dispatch_plan_id),
  constraint dispatch_plans_created_by_actor_fkey foreign key (created_by_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint dispatch_plans_plan_reference_key unique (plan_reference),
  constraint dispatch_plans_status_check check (plan_status in ('PLANNED', 'REVISED', 'CANCELLED')),
  constraint dispatch_plans_version_check check (version > 0)
);

create table atlas_dispatch.dispatch_plan_requirements (
  dispatch_plan_requirement_id uuid not null default gen_random_uuid(),
  dispatch_plan_id uuid not null,
  dispatch_requirement_revision_id uuid not null,
  fulfilment_allocation_revision_id uuid not null,
  created_at timestamptz not null default transaction_timestamp(),
  constraint dispatch_plan_requirements_pkey primary key (dispatch_plan_requirement_id),
  constraint dispatch_plan_requirements_plan_fkey foreign key (dispatch_plan_id)
    references atlas_dispatch.dispatch_plans (dispatch_plan_id) on delete restrict,
  constraint dispatch_plan_requirements_requirement_revision_fkey foreign key (dispatch_requirement_revision_id)
    references atlas_planning.dispatch_requirement_revisions (dispatch_requirement_revision_id) on delete restrict,
  constraint dispatch_plan_requirements_allocation_revision_fkey foreign key (fulfilment_allocation_revision_id)
    references atlas_procurement.fulfilment_allocation_revisions (fulfilment_allocation_revision_id) on delete restrict,
  constraint dispatch_plan_requirements_membership_key unique (
    dispatch_plan_id,
    dispatch_requirement_revision_id,
    fulfilment_allocation_revision_id
  )
);

create table atlas_dispatch.dispatch_trips (
  dispatch_trip_id uuid not null default gen_random_uuid(),
  dispatch_plan_id uuid not null,
  trip_reference text not null,
  trip_status text not null default 'PLANNED',
  driver_actor_id uuid,
  vehicle_reference text,
  planned_departure_at timestamptz,
  departed_at timestamptz,
  completed_at timestamptz,
  version bigint not null default 1,
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  constraint dispatch_trips_pkey primary key (dispatch_trip_id),
  constraint dispatch_trips_plan_fkey foreign key (dispatch_plan_id)
    references atlas_dispatch.dispatch_plans (dispatch_plan_id) on delete restrict,
  constraint dispatch_trips_driver_actor_fkey foreign key (driver_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint dispatch_trips_trip_reference_key unique (trip_reference),
  constraint dispatch_trips_status_check check (
    trip_status in (
      'PLANNED',
      'ASSIGNED',
      'LOADED',
      'IN_TRANSIT',
      'PARTIALLY_DELIVERED',
      'DELIVERED',
      'CLOSED_WITH_EXCEPTION',
      'CANCELLED',
      'VOIDED'
    )
  ),
  constraint dispatch_trips_version_check check (version > 0),
  constraint dispatch_trips_completion_check check (
    completed_at is null or (departed_at is not null and completed_at >= departed_at)
  )
);

create table atlas_dispatch.dispatch_stops (
  dispatch_stop_id uuid not null default gen_random_uuid(),
  dispatch_trip_id uuid not null,
  stop_sequence integer not null,
  dispatch_requirement_revision_id uuid not null,
  customer_id uuid not null,
  delivery_location_id uuid not null,
  planned_window_start timestamptz,
  planned_window_end timestamptz,
  stop_status text not null default 'PENDING',
  version bigint not null default 1,
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  constraint dispatch_stops_pkey primary key (dispatch_stop_id),
  constraint dispatch_stops_trip_fkey foreign key (dispatch_trip_id)
    references atlas_dispatch.dispatch_trips (dispatch_trip_id) on delete restrict,
  constraint dispatch_stops_requirement_revision_fkey foreign key (dispatch_requirement_revision_id)
    references atlas_planning.dispatch_requirement_revisions (dispatch_requirement_revision_id) on delete restrict,
  constraint dispatch_stops_customer_fkey foreign key (customer_id)
    references atlas_admin.customers (customer_id) on delete restrict,
  constraint dispatch_stops_location_fkey foreign key (delivery_location_id)
    references atlas_admin.delivery_locations (delivery_location_id) on delete restrict,
  constraint dispatch_stops_trip_sequence_key unique (dispatch_trip_id, stop_sequence),
  constraint dispatch_stops_sequence_check check (stop_sequence > 0),
  constraint dispatch_stops_window_check check (
    planned_window_end is null
    or planned_window_start is null
    or planned_window_end > planned_window_start
  ),
  constraint dispatch_stops_status_check check (
    stop_status in (
      'PENDING',
      'LOADED',
      'IN_TRANSIT',
      'DELIVERED',
      'PARTIALLY_DELIVERED',
      'FAILED',
      'RETURNED',
      'RESOLVED_WITH_EXCEPTION'
    )
  ),
  constraint dispatch_stops_version_check check (version > 0)
);

create table atlas_dispatch.dispatch_loads (
  dispatch_load_id uuid not null default gen_random_uuid(),
  dispatch_trip_id uuid not null,
  dispatch_requirement_revision_id uuid not null,
  fulfilment_allocation_revision_id uuid not null,
  load_status text not null default 'DRAFT',
  loaded_by_actor_id uuid,
  loaded_at timestamptz,
  version bigint not null default 1,
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  constraint dispatch_loads_pkey primary key (dispatch_load_id),
  constraint dispatch_loads_trip_fkey foreign key (dispatch_trip_id)
    references atlas_dispatch.dispatch_trips (dispatch_trip_id) on delete restrict,
  constraint dispatch_loads_requirement_revision_fkey foreign key (dispatch_requirement_revision_id)
    references atlas_planning.dispatch_requirement_revisions (dispatch_requirement_revision_id) on delete restrict,
  constraint dispatch_loads_allocation_revision_fkey foreign key (fulfilment_allocation_revision_id)
    references atlas_procurement.fulfilment_allocation_revisions (fulfilment_allocation_revision_id) on delete restrict,
  constraint dispatch_loads_loaded_by_actor_fkey foreign key (loaded_by_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint dispatch_loads_scope_key unique (
    dispatch_trip_id,
    dispatch_requirement_revision_id,
    fulfilment_allocation_revision_id
  ),
  constraint dispatch_loads_status_check check (load_status in ('DRAFT', 'CONFIRMED', 'VOIDED')),
  constraint dispatch_loads_loaded_check check (
    (load_status = 'DRAFT' and loaded_by_actor_id is null and loaded_at is null)
    or (load_status in ('CONFIRMED', 'VOIDED') and loaded_by_actor_id is not null and loaded_at is not null)
  ),
  constraint dispatch_loads_version_check check (version > 0)
);

create table atlas_dispatch.dispatch_load_lines (
  dispatch_load_line_id uuid not null default gen_random_uuid(),
  dispatch_load_id uuid not null,
  dispatch_stop_id uuid not null,
  dispatch_requirement_line_revision_id uuid not null,
  fulfilment_allocation_line_revision_id uuid not null,
  ingredient_id uuid not null,
  loaded_quantity numeric(20, 6) not null,
  unit_id uuid not null,
  line_status text not null default 'CONFIRMED',
  command_id uuid not null,
  created_at timestamptz not null default transaction_timestamp(),
  constraint dispatch_load_lines_pkey primary key (dispatch_load_line_id),
  constraint dispatch_load_lines_load_fkey foreign key (dispatch_load_id)
    references atlas_dispatch.dispatch_loads (dispatch_load_id) on delete restrict,
  constraint dispatch_load_lines_stop_fkey foreign key (dispatch_stop_id)
    references atlas_dispatch.dispatch_stops (dispatch_stop_id) on delete restrict,
  constraint dispatch_load_lines_requirement_line_revision_fkey foreign key (dispatch_requirement_line_revision_id)
    references atlas_planning.dispatch_requirement_line_revisions (dispatch_requirement_line_revision_id) on delete restrict,
  constraint dispatch_load_lines_allocation_line_revision_fkey foreign key (fulfilment_allocation_line_revision_id)
    references atlas_procurement.fulfilment_allocation_line_revisions (fulfilment_allocation_line_revision_id) on delete restrict,
  constraint dispatch_load_lines_ingredient_fkey foreign key (ingredient_id)
    references atlas_admin.ingredients (ingredient_id) on delete restrict,
  constraint dispatch_load_lines_unit_fkey foreign key (unit_id)
    references atlas_admin.units (unit_id) on delete restrict,
  constraint dispatch_load_lines_command_key unique (command_id, fulfilment_allocation_line_revision_id),
  constraint dispatch_load_lines_scope_key unique (dispatch_load_id, fulfilment_allocation_line_revision_id),
  constraint dispatch_load_lines_quantity_check check (loaded_quantity > 0),
  constraint dispatch_load_lines_status_check check (line_status in ('CONFIRMED', 'VOIDED'))
);

create table atlas_dispatch.dispatch_load_line_applications (
  dispatch_load_line_application_id uuid not null default gen_random_uuid(),
  dispatch_load_line_id uuid not null,
  evidence_application_id uuid not null,
  applied_to_load_quantity numeric(20, 6) not null,
  unit_id uuid not null,
  application_status text not null default 'VALID',
  created_at timestamptz not null default transaction_timestamp(),
  constraint dispatch_load_line_applications_pkey primary key (dispatch_load_line_application_id),
  constraint dispatch_load_line_applications_load_line_fkey foreign key (dispatch_load_line_id)
    references atlas_dispatch.dispatch_load_lines (dispatch_load_line_id) on delete restrict,
  constraint dispatch_load_line_applications_evidence_application_fkey foreign key (evidence_application_id)
    references atlas_evidence.evidence_applications (evidence_application_id) on delete restrict,
  constraint dispatch_load_line_applications_unit_fkey foreign key (unit_id)
    references atlas_admin.units (unit_id) on delete restrict,
  constraint dispatch_load_line_applications_quantity_check check (applied_to_load_quantity > 0),
  constraint dispatch_load_line_applications_status_check check (
    application_status in ('VALID', 'VOIDED')
  )
);

create table atlas_dispatch.delivery_confirmations (
  delivery_confirmation_id uuid not null default gen_random_uuid(),
  dispatch_stop_id uuid not null,
  revision_number integer not null,
  delivery_outcome text not null,
  confirmation_status text not null default 'VALID',
  supersedes_delivery_confirmation_id uuid,
  confirmed_by_actor_id uuid not null,
  confirmed_at timestamptz not null,
  received_by_reference text,
  notes text,
  command_id uuid not null,
  correlation_id uuid not null,
  recorded_at timestamptz not null default transaction_timestamp(),
  constraint delivery_confirmations_pkey primary key (delivery_confirmation_id),
  constraint delivery_confirmations_stop_fkey foreign key (dispatch_stop_id)
    references atlas_dispatch.dispatch_stops (dispatch_stop_id) on delete restrict,
  constraint delivery_confirmations_supersedes_fkey foreign key (supersedes_delivery_confirmation_id)
    references atlas_dispatch.delivery_confirmations (delivery_confirmation_id) on delete restrict,
  constraint delivery_confirmations_actor_fkey foreign key (confirmed_by_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint delivery_confirmations_stop_revision_key unique (dispatch_stop_id, revision_number),
  constraint delivery_confirmations_command_key unique (command_id),
  constraint delivery_confirmations_number_check check (revision_number > 0),
  constraint delivery_confirmations_outcome_check check (delivery_outcome = 'DELIVERED'),
  constraint delivery_confirmations_status_check check (
    confirmation_status in ('VALID', 'SUPERSEDED', 'VOIDED')
  ),
  constraint delivery_confirmations_time_check check (recorded_at >= confirmed_at),
  constraint delivery_confirmations_supersedes_check check (
    supersedes_delivery_confirmation_id is null
    or supersedes_delivery_confirmation_id <> delivery_confirmation_id
  )
);

create table atlas_dispatch.delivery_confirmation_lines (
  delivery_confirmation_line_id uuid not null default gen_random_uuid(),
  delivery_confirmation_id uuid not null,
  dispatch_load_line_id uuid not null,
  delivered_quantity numeric(20, 6) not null,
  returned_quantity numeric(20, 6) not null default 0,
  exception_quantity numeric(20, 6) not null default 0,
  unit_id uuid not null,
  created_at timestamptz not null default transaction_timestamp(),
  constraint delivery_confirmation_lines_pkey primary key (delivery_confirmation_line_id),
  constraint delivery_confirmation_lines_confirmation_fkey foreign key (delivery_confirmation_id)
    references atlas_dispatch.delivery_confirmations (delivery_confirmation_id) on delete restrict,
  constraint delivery_confirmation_lines_load_line_fkey foreign key (dispatch_load_line_id)
    references atlas_dispatch.dispatch_load_lines (dispatch_load_line_id) on delete restrict,
  constraint delivery_confirmation_lines_unit_fkey foreign key (unit_id)
    references atlas_admin.units (unit_id) on delete restrict,
  constraint delivery_confirmation_lines_confirmation_load_key unique (
    delivery_confirmation_id,
    dispatch_load_line_id
  ),
  constraint delivery_confirmation_lines_happy_path_check check (
    delivered_quantity > 0 and returned_quantity = 0 and exception_quantity = 0
  )
);

create table atlas_core.actor_scopes (
  actor_scope_id uuid not null default gen_random_uuid(),
  actor_id uuid not null,
  scope_kind text not null,
  customer_id uuid,
  delivery_location_id uuid,
  dispatch_trip_id uuid,
  scope_status text not null default 'ACTIVE',
  effective_from timestamptz not null default transaction_timestamp(),
  effective_to timestamptz,
  granted_by_actor_id uuid,
  reason_note text,
  constraint actor_scopes_pkey primary key (actor_scope_id),
  constraint actor_scopes_actor_fkey foreign key (actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint actor_scopes_customer_fkey foreign key (customer_id)
    references atlas_admin.customers (customer_id) on delete restrict,
  constraint actor_scopes_delivery_location_fkey foreign key (delivery_location_id)
    references atlas_admin.delivery_locations (delivery_location_id) on delete restrict,
  constraint actor_scopes_dispatch_trip_fkey foreign key (dispatch_trip_id)
    references atlas_dispatch.dispatch_trips (dispatch_trip_id) on delete restrict,
  constraint actor_scopes_granted_by_actor_fkey foreign key (granted_by_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint actor_scopes_kind_check check (
    scope_kind in ('GLOBAL', 'CUSTOMER', 'DELIVERY_LOCATION', 'DISPATCH_TRIP')
  ),
  constraint actor_scopes_target_check check (
    (scope_kind = 'GLOBAL' and customer_id is null and delivery_location_id is null and dispatch_trip_id is null)
    or (scope_kind = 'CUSTOMER' and customer_id is not null and delivery_location_id is null and dispatch_trip_id is null)
    or (scope_kind = 'DELIVERY_LOCATION' and customer_id is null and delivery_location_id is not null and dispatch_trip_id is null)
    or (scope_kind = 'DISPATCH_TRIP' and customer_id is null and delivery_location_id is null and dispatch_trip_id is not null)
  ),
  constraint actor_scopes_status_check check (scope_status in ('ACTIVE', 'REVOKED', 'EXPIRED')),
  constraint actor_scopes_period_check check (effective_to is null or effective_to > effective_from)
);

create table atlas_audit.domain_events (
  domain_event_id uuid not null default gen_random_uuid(),
  event_type text not null,
  source_domain text not null,
  aggregate_type text not null,
  aggregate_id uuid not null,
  aggregate_version bigint,
  command_receipt_id uuid,
  command_id uuid not null,
  correlation_id uuid not null,
  actor_id uuid not null,
  occurred_at timestamptz not null,
  recorded_at timestamptz not null default transaction_timestamp(),
  payload_summary jsonb not null default '{}'::jsonb,
  constraint domain_events_pkey primary key (domain_event_id),
  constraint domain_events_command_receipt_fkey foreign key (command_receipt_id)
    references atlas_core.command_receipts (command_receipt_id) on delete restrict,
  constraint domain_events_actor_fkey foreign key (actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint domain_events_command_event_key unique (command_id, event_type, aggregate_id),
  constraint domain_events_source_domain_check check (
    source_domain in ('CORE', 'ADMIN', 'PLANNING', 'PROCUREMENT', 'EVIDENCE', 'DISPATCH')
  ),
  constraint domain_events_aggregate_version_check check (
    aggregate_version is null or aggregate_version > 0
  ),
  constraint domain_events_time_check check (recorded_at >= occurred_at)
);

create table atlas_audit.audit_events (
  audit_event_id uuid not null default gen_random_uuid(),
  event_type text not null,
  source_domain text not null,
  aggregate_type text not null,
  aggregate_id uuid not null,
  aggregate_version_before bigint,
  aggregate_version_after bigint,
  command_receipt_id uuid,
  command_id uuid not null,
  correlation_id uuid not null,
  actor_id uuid not null,
  delegated_actor_id uuid,
  reason_code text,
  reason_note text,
  before_summary jsonb,
  after_summary jsonb,
  source_interface text not null,
  occurred_at timestamptz not null,
  recorded_at timestamptz not null default transaction_timestamp(),
  constraint audit_events_pkey primary key (audit_event_id),
  constraint audit_events_command_receipt_fkey foreign key (command_receipt_id)
    references atlas_core.command_receipts (command_receipt_id) on delete restrict,
  constraint audit_events_actor_fkey foreign key (actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint audit_events_delegated_actor_fkey foreign key (delegated_actor_id)
    references atlas_core.actors (actor_id) on delete restrict,
  constraint audit_events_command_event_key unique (command_id, event_type, aggregate_id),
  constraint audit_events_source_domain_check check (
    source_domain in ('CORE', 'ADMIN', 'PLANNING', 'PROCUREMENT', 'EVIDENCE', 'DISPATCH')
  ),
  constraint audit_events_version_before_check check (
    aggregate_version_before is null or aggregate_version_before > 0
  ),
  constraint audit_events_version_after_check check (
    aggregate_version_after is null or aggregate_version_after > 0
  ),
  constraint audit_events_time_check check (recorded_at >= occurred_at)
);

create unique index actor_auth_subjects_active_actor_key
  on atlas_core.actor_auth_subjects (actor_id)
  where subject_status = 'ACTIVE';
create unique index actor_role_memberships_active_key
  on atlas_core.actor_role_memberships (actor_id, role_id)
  where membership_status = 'ACTIVE';
create unique index actor_scopes_active_global_key
  on atlas_core.actor_scopes (actor_id, scope_kind)
  where scope_status = 'ACTIVE' and scope_kind = 'GLOBAL';
create unique index actor_scopes_active_target_key
  on atlas_core.actor_scopes (
    actor_id,
    scope_kind,
    coalesce(customer_id, delivery_location_id, dispatch_trip_id)
  )
  where scope_status = 'ACTIVE' and scope_kind <> 'GLOBAL';
create index command_receipts_correlation_recorded_idx
  on atlas_core.command_receipts (correlation_id, started_at);
create unique index supplier_eligibilities_active_key
  on atlas_admin.supplier_eligibilities (supplier_id, ingredient_id)
  where eligibility_status = 'ACTIVE';
create index delivery_locations_customer_status_idx
  on atlas_admin.delivery_locations (customer_id, location_status);
create index wholesale_orders_service_status_idx
  on atlas_planning.wholesale_orders (service_date, order_status);
create unique index wholesale_orders_customer_reference_key
  on atlas_planning.wholesale_orders (customer_id, customer_order_reference)
  where customer_order_reference is not null;
create index wholesale_order_lines_order_idx
  on atlas_planning.wholesale_order_lines (wholesale_order_id);
create unique index wholesale_order_line_revisions_current_key
  on atlas_planning.wholesale_order_line_revisions (wholesale_order_line_id)
  where is_current;
create index wholesale_order_line_revisions_ingredient_idx
  on atlas_planning.wholesale_order_line_revisions (ingredient_id);
create index confirmed_need_batches_status_period_idx
  on atlas_planning.confirmed_need_batches (batch_status, period_start, period_end);
create index confirmed_need_lines_batch_idx
  on atlas_planning.confirmed_need_lines (confirmed_need_batch_id);
create unique index confirmed_need_line_revisions_current_key
  on atlas_planning.confirmed_need_line_revisions (confirmed_need_line_id)
  where is_current;
create index confirmed_need_snapshot_lines_revision_idx
  on atlas_planning.confirmed_need_snapshot_lines (confirmed_need_line_revision_id);
create index purchase_handoff_batches_status_period_idx
  on atlas_planning.purchase_handoff_batches (handoff_status, period_start, period_end);
create unique index purchase_handoff_revisions_current_key
  on atlas_planning.purchase_handoff_revisions (purchase_handoff_batch_id)
  where is_current;
create index purchase_handoff_lines_batch_idx
  on atlas_planning.purchase_handoff_lines (purchase_handoff_batch_id);
create index purchase_handoff_line_revisions_service_idx
  on atlas_planning.purchase_handoff_line_revisions (service_date, delivery_location_id);
create index dispatch_requirements_service_status_idx
  on atlas_planning.dispatch_requirements (service_date, requirement_status);
create unique index dispatch_requirement_revisions_current_key
  on atlas_planning.dispatch_requirement_revisions (dispatch_requirement_id)
  where is_current;
create index dispatch_requirement_lines_requirement_idx
  on atlas_planning.dispatch_requirement_lines (dispatch_requirement_id);
create index dispatch_requirement_line_revisions_handoff_idx
  on atlas_planning.dispatch_requirement_line_revisions (purchase_handoff_line_revision_id);
create index fulfilment_allocations_status_idx
  on atlas_procurement.fulfilment_allocations (allocation_status);
create unique index fulfilment_allocation_revisions_current_key
  on atlas_procurement.fulfilment_allocation_revisions (fulfilment_allocation_id)
  where is_current;
create index fulfilment_allocation_lines_requirement_line_idx
  on atlas_procurement.fulfilment_allocation_lines (dispatch_requirement_line_id);
create index fulfilment_allocation_line_revisions_requirement_idx
  on atlas_procurement.fulfilment_allocation_line_revisions (dispatch_requirement_line_revision_id);
create index fulfilment_allocation_line_revisions_supplier_status_idx
  on atlas_procurement.fulfilment_allocation_line_revisions (supplier_id, line_status);
create unique index purchase_orders_document_number_key
  on atlas_procurement.purchase_orders (document_number)
  where document_number is not null;
create index purchase_orders_supplier_status_idx
  on atlas_procurement.purchase_orders (supplier_id, purchase_order_status);
create unique index purchase_order_revisions_current_key
  on atlas_procurement.purchase_order_revisions (purchase_order_id)
  where is_current;
create index purchase_order_revisions_service_status_idx
  on atlas_procurement.purchase_order_revisions (service_date, revision_status);
create index purchase_order_lines_order_idx
  on atlas_procurement.purchase_order_lines (purchase_order_id);
create index purchase_order_line_revisions_allocation_idx
  on atlas_procurement.purchase_order_line_revisions (fulfilment_allocation_line_revision_id);
create index supplier_receiving_evidence_po_line_status_idx
  on atlas_evidence.supplier_receiving_evidence (purchase_order_line_revision_id, evidence_status);
create index supplier_receiving_evidence_correlation_idx
  on atlas_evidence.supplier_receiving_evidence (correlation_id, recorded_at);
create unique index evidence_applications_valid_pair_key
  on atlas_evidence.evidence_applications (
    supplier_receiving_evidence_id,
    fulfilment_allocation_line_revision_id
  )
  where application_status = 'VALID';
create index evidence_applications_allocation_status_idx
  on atlas_evidence.evidence_applications (
    fulfilment_allocation_line_revision_id,
    application_status
  );
create index evidence_applications_correlation_idx
  on atlas_evidence.evidence_applications (correlation_id, recorded_at);
create index dispatch_plans_service_status_idx
  on atlas_dispatch.dispatch_plans (service_date, plan_status);
create index dispatch_plan_requirements_requirement_idx
  on atlas_dispatch.dispatch_plan_requirements (dispatch_requirement_revision_id);
create index dispatch_plan_requirements_allocation_idx
  on atlas_dispatch.dispatch_plan_requirements (fulfilment_allocation_revision_id);
create index dispatch_trips_plan_idx
  on atlas_dispatch.dispatch_trips (dispatch_plan_id);
create index dispatch_trips_status_departure_idx
  on atlas_dispatch.dispatch_trips (trip_status, planned_departure_at);
create index dispatch_stops_requirement_idx
  on atlas_dispatch.dispatch_stops (dispatch_requirement_revision_id);
create index dispatch_loads_trip_status_idx
  on atlas_dispatch.dispatch_loads (dispatch_trip_id, load_status);
create index dispatch_load_lines_allocation_idx
  on atlas_dispatch.dispatch_load_lines (fulfilment_allocation_line_revision_id);
create unique index dispatch_load_line_applications_valid_pair_key
  on atlas_dispatch.dispatch_load_line_applications (
    dispatch_load_line_id,
    evidence_application_id
  )
  where application_status = 'VALID';
create index dispatch_load_line_applications_evidence_idx
  on atlas_dispatch.dispatch_load_line_applications (evidence_application_id);
create unique index delivery_confirmations_valid_stop_key
  on atlas_dispatch.delivery_confirmations (dispatch_stop_id)
  where confirmation_status = 'VALID';
create index delivery_confirmation_lines_load_line_idx
  on atlas_dispatch.delivery_confirmation_lines (dispatch_load_line_id);
create index domain_events_correlation_recorded_idx
  on atlas_audit.domain_events (correlation_id, recorded_at);
create index domain_events_aggregate_recorded_idx
  on atlas_audit.domain_events (aggregate_type, aggregate_id, recorded_at);
create index domain_events_command_idx
  on atlas_audit.domain_events (command_id);
create index audit_events_correlation_recorded_idx
  on atlas_audit.audit_events (correlation_id, recorded_at);
create index audit_events_aggregate_recorded_idx
  on atlas_audit.audit_events (aggregate_type, aggregate_id, recorded_at);
create index audit_events_actor_recorded_idx
  on atlas_audit.audit_events (actor_id, recorded_at);

create view atlas_reporting.dispatch_evidence_readiness
with (security_invoker = true)
as
with valid_applications as (
  select
    ea.fulfilment_allocation_line_revision_id,
    sum(ea.applied_quantity) as applied_quantity
  from atlas_evidence.evidence_applications ea
  join atlas_evidence.supplier_receiving_evidence sre
    on sre.supplier_receiving_evidence_id = ea.supplier_receiving_evidence_id
  where ea.application_status = 'VALID'
    and sre.evidence_status = 'VALID'
  group by ea.fulfilment_allocation_line_revision_id
), valid_loaded as (
  select
    dll.fulfilment_allocation_line_revision_id,
    sum(dlla.applied_to_load_quantity) as loaded_quantity
  from atlas_dispatch.dispatch_load_line_applications dlla
  join atlas_dispatch.dispatch_load_lines dll
    on dll.dispatch_load_line_id = dlla.dispatch_load_line_id
  join atlas_dispatch.dispatch_loads dl
    on dl.dispatch_load_id = dll.dispatch_load_id
  join atlas_evidence.evidence_applications ea
    on ea.evidence_application_id = dlla.evidence_application_id
  join atlas_evidence.supplier_receiving_evidence sre
    on sre.supplier_receiving_evidence_id = ea.supplier_receiving_evidence_id
  where dlla.application_status = 'VALID'
    and dll.line_status = 'CONFIRMED'
    and dl.load_status = 'CONFIRMED'
    and ea.application_status = 'VALID'
    and sre.evidence_status = 'VALID'
  group by dll.fulfilment_allocation_line_revision_id
)
select
  falr.fulfilment_allocation_line_revision_id,
  falr.fulfilment_allocation_revision_id,
  falr.dispatch_requirement_line_revision_id,
  falr.supplier_id,
  falr.allocated_quantity,
  falr.unit_id,
  coalesce(va.applied_quantity, 0::numeric) as valid_applied_quantity,
  coalesce(vl.loaded_quantity, 0::numeric) as valid_loaded_quantity,
  coalesce(va.applied_quantity, 0::numeric) >= falr.allocated_quantity as evidence_sufficient,
  greatest(falr.allocated_quantity - coalesce(va.applied_quantity, 0::numeric), 0::numeric) as uncovered_quantity
from atlas_procurement.fulfilment_allocation_line_revisions falr
left join valid_applications va
  on va.fulfilment_allocation_line_revision_id = falr.fulfilment_allocation_line_revision_id
left join valid_loaded vl
  on vl.fulfilment_allocation_line_revision_id = falr.fulfilment_allocation_line_revision_id;

create view atlas_reporting.supplier_direct_slice_trace
with (security_invoker = true)
as
select
  wo.wholesale_order_id,
  wol.wholesale_order_line_id,
  wolr.wholesale_order_line_revision_id,
  cnl.confirmed_need_line_id,
  cnlr.confirmed_need_line_revision_id,
  phl.purchase_handoff_line_id,
  phlr.purchase_handoff_line_revision_id,
  dr.dispatch_requirement_id,
  drlr.dispatch_requirement_line_revision_id,
  fal.fulfilment_allocation_line_id,
  falr.fulfilment_allocation_line_revision_id,
  pol.purchase_order_line_id,
  polr.purchase_order_line_revision_id,
  sre.supplier_receiving_evidence_id,
  ea.evidence_application_id,
  dll.dispatch_load_line_id,
  dc.delivery_confirmation_id,
  dcl.delivery_confirmation_line_id,
  wo.service_date,
  wo.customer_id,
  wo.delivery_location_id,
  wolr.ingredient_id,
  falr.allocated_quantity,
  ea.applied_quantity,
  dll.loaded_quantity,
  dcl.delivered_quantity,
  falr.unit_id
from atlas_planning.wholesale_orders wo
join atlas_planning.wholesale_order_lines wol
  on wol.wholesale_order_id = wo.wholesale_order_id
join atlas_planning.wholesale_order_line_revisions wolr
  on wolr.wholesale_order_line_id = wol.wholesale_order_line_id
join atlas_planning.confirmed_need_lines cnl
  on cnl.wholesale_order_line_id = wol.wholesale_order_line_id
join atlas_planning.confirmed_need_line_revisions cnlr
  on cnlr.confirmed_need_line_id = cnl.confirmed_need_line_id
  and cnlr.wholesale_order_line_revision_id = wolr.wholesale_order_line_revision_id
join atlas_planning.purchase_handoff_lines phl
  on phl.confirmed_need_line_id = cnl.confirmed_need_line_id
join atlas_planning.purchase_handoff_line_revisions phlr
  on phlr.purchase_handoff_line_id = phl.purchase_handoff_line_id
  and phlr.confirmed_need_line_revision_id = cnlr.confirmed_need_line_revision_id
join atlas_planning.dispatch_requirement_lines drl
  on drl.purchase_handoff_line_id = phl.purchase_handoff_line_id
join atlas_planning.dispatch_requirements dr
  on dr.dispatch_requirement_id = drl.dispatch_requirement_id
join atlas_planning.dispatch_requirement_line_revisions drlr
  on drlr.dispatch_requirement_line_id = drl.dispatch_requirement_line_id
  and drlr.purchase_handoff_line_revision_id = phlr.purchase_handoff_line_revision_id
join atlas_procurement.fulfilment_allocation_lines fal
  on fal.dispatch_requirement_line_id = drl.dispatch_requirement_line_id
join atlas_procurement.fulfilment_allocation_line_revisions falr
  on falr.fulfilment_allocation_line_id = fal.fulfilment_allocation_line_id
  and falr.dispatch_requirement_line_revision_id = drlr.dispatch_requirement_line_revision_id
join atlas_procurement.purchase_order_lines pol
  on pol.fulfilment_allocation_line_id = fal.fulfilment_allocation_line_id
join atlas_procurement.purchase_order_line_revisions polr
  on polr.purchase_order_line_id = pol.purchase_order_line_id
  and polr.fulfilment_allocation_line_revision_id = falr.fulfilment_allocation_line_revision_id
join atlas_evidence.supplier_receiving_evidence sre
  on sre.purchase_order_line_revision_id = polr.purchase_order_line_revision_id
join atlas_evidence.evidence_applications ea
  on ea.supplier_receiving_evidence_id = sre.supplier_receiving_evidence_id
  and ea.fulfilment_allocation_line_revision_id = falr.fulfilment_allocation_line_revision_id
join atlas_dispatch.dispatch_load_line_applications dlla
  on dlla.evidence_application_id = ea.evidence_application_id
join atlas_dispatch.dispatch_load_lines dll
  on dll.dispatch_load_line_id = dlla.dispatch_load_line_id
  and dll.fulfilment_allocation_line_revision_id = falr.fulfilment_allocation_line_revision_id
join atlas_dispatch.delivery_confirmation_lines dcl
  on dcl.dispatch_load_line_id = dll.dispatch_load_line_id
join atlas_dispatch.delivery_confirmations dc
  on dc.delivery_confirmation_id = dcl.delivery_confirmation_id;

comment on table atlas_core.actors is 'Stable server-owned Atlas actors; historical actors are deactivated, not deleted.';
comment on table atlas_core.actor_auth_subjects is 'Controlled links from an Atlas actor to one active Supabase Auth subject, with revoked history preserved.';
comment on table atlas_core.roles is 'Assignable authorization bundles; roles never imply unrestricted access.';
comment on table atlas_core.capabilities is 'Server-owned capability vocabulary for future atlas_api command checks.';
comment on table atlas_core.role_capabilities is 'Controlled role-to-capability assignments.';
comment on table atlas_core.actor_role_memberships is 'Effective, revocable actor role memberships.';
comment on table atlas_core.actor_scopes is 'Typed Slice 1 customer, location, or trip scopes for an actor.';
comment on table atlas_core.command_receipts is 'Idempotency, expected-version, command, and correlation foundation; populated only by future commands.';
comment on table atlas_admin.customers is 'Minimal wholesale customer master reference.';
comment on table atlas_admin.delivery_locations is 'Admin-owned delivery-location reference; released work snapshots the address.';
comment on table atlas_admin.units is 'Controlled quantity-unit reference.';
comment on table atlas_admin.ingredients is 'Minimal ingredient master reference.';
comment on table atlas_admin.suppliers is 'Supplier master identity; Procurement owns commitments.';
comment on table atlas_admin.supplier_eligibilities is 'Effective supplier-to-ingredient eligibility guidance, not a commitment.';
comment on table atlas_planning.wholesale_orders is 'Planning-owned direct wholesale source root.';
comment on table atlas_planning.wholesale_order_lines is 'Stable wholesale source-line identities.';
comment on table atlas_planning.wholesale_order_line_revisions is 'Immutable-on-release wholesale source-line revisions.';
comment on table atlas_planning.confirmed_need_batches is 'Planning approval gate for direct wholesale demand.';
comment on table atlas_planning.confirmed_need_lines is 'Stable Planning-approved demand-line identities.';
comment on table atlas_planning.confirmed_need_line_revisions is 'Versioned Confirmed Need quantities and exact wholesale source revision.';
comment on table atlas_planning.confirmed_need_approval_snapshots is 'Immutable Confirmed Need approval envelope.';
comment on table atlas_planning.confirmed_need_snapshot_lines is 'Immutable approved line facts consumed by Purchase Handoff.';
comment on table atlas_planning.purchase_handoff_batches is 'Planning-owned release boundary to Procurement.';
comment on table atlas_planning.purchase_handoff_revisions is 'Immutable Purchase Handoff release revisions.';
comment on table atlas_planning.purchase_handoff_lines is 'Stable Purchase Handoff line identities.';
comment on table atlas_planning.purchase_handoff_line_revisions is 'Exact released purchase-demand quantities and destination references.';
comment on table atlas_planning.purchase_demand_references is 'Immutable trace from handoff demand to approved and wholesale source revisions.';
comment on table atlas_planning.dispatch_requirements is 'Planning-owned wholesale delivery obligation root.';
comment on table atlas_planning.dispatch_requirement_revisions is 'Immutable Planning release and destination snapshot.';
comment on table atlas_planning.dispatch_requirement_lines is 'Stable delivery-obligation line identities.';
comment on table atlas_planning.dispatch_requirement_line_revisions is 'Exact released requirement-line facts consumed downstream.';
comment on table atlas_procurement.fulfilment_allocations is 'Procurement-owned fulfilment decision for one Planning requirement.';
comment on table atlas_procurement.fulfilment_allocation_revisions is 'Immutable fulfilment-allocation revisions.';
comment on table atlas_procurement.fulfilment_allocation_lines is 'Stable supplier-direct allocation portion identities.';
comment on table atlas_procurement.fulfilment_allocation_line_revisions is 'Exact supplier-direct allocated quantity for one requirement-line revision.';
comment on table atlas_procurement.purchase_orders is 'Stable supplier commitment root; document number is not identity.';
comment on table atlas_procurement.purchase_order_revisions is 'Immutable-on-release supplier commitment revisions.';
comment on table atlas_procurement.purchase_order_lines is 'Stable purchase-order line identities linked to allocation portions.';
comment on table atlas_procurement.purchase_order_line_revisions is 'Exact PO line facts and allocation-line revision trace.';
comment on table atlas_evidence.supplier_receiving_evidence is 'Source-owned physical supplier evidence; not a Procurement confirmation.';
comment on table atlas_evidence.evidence_applications is 'Mandatory positive application from one evidence fact to one exact allocation-line revision.';
comment on table atlas_dispatch.dispatch_plans is 'Dispatch grouping root for one service day.';
comment on table atlas_dispatch.dispatch_plan_requirements is 'Exact requirement/allocation revisions admitted to a plan.';
comment on table atlas_dispatch.dispatch_trips is 'Independent movement execution root with explicit departure and completion instants.';
comment on table atlas_dispatch.dispatch_stops is 'Ordered customer destination within a trip.';
comment on table atlas_dispatch.dispatch_loads is 'Confirmed trip load envelope for exact requirement/allocation revisions.';
comment on table atlas_dispatch.dispatch_load_lines is 'Positive loaded quantity for exact requirement and allocation line revisions.';
comment on table atlas_dispatch.dispatch_load_line_applications is 'Mandatory bridge from a load line to consumed evidence applications.';
comment on table atlas_dispatch.delivery_confirmations is 'Append-only successful destination confirmation envelope for Slice 1.';
comment on table atlas_dispatch.delivery_confirmation_lines is 'Successful delivered quantity for one exact load line.';
comment on table atlas_audit.domain_events is 'Append-only domain event evidence; not an event-sourced current-state store.';
comment on table atlas_audit.audit_events is 'Append-only actor, command, version, reason, and before/after audit evidence.';
comment on view atlas_reporting.dispatch_evidence_readiness is 'Private derived evidence coverage; commands must re-read and lock authoritative rows.';
comment on view atlas_reporting.supplier_direct_slice_trace is 'Private canonical wholesale-source-to-delivery trace for PA-04 verification.';

do $$
declare
  atlas_table record;
begin
  for atlas_table in
    select n.nspname as schema_name, c.relname as table_name
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname in (
      'atlas_core',
      'atlas_admin',
      'atlas_planning',
      'atlas_procurement',
      'atlas_evidence',
      'atlas_dispatch',
      'atlas_audit'
    )
      and c.relkind = 'r'
  loop
    execute format('alter table %I.%I enable row level security', atlas_table.schema_name, atlas_table.table_name);
    execute format('alter table %I.%I force row level security', atlas_table.schema_name, atlas_table.table_name);
  end loop;
end
$$;

revoke all on schema atlas_core, atlas_admin, atlas_planning, atlas_procurement,
  atlas_evidence, atlas_dispatch, atlas_audit, atlas_reporting, atlas_api
  from public, anon, authenticated, service_role;

revoke all on all tables in schema atlas_core, atlas_admin, atlas_planning,
  atlas_procurement, atlas_evidence, atlas_dispatch, atlas_audit, atlas_reporting
  from public, anon, authenticated, service_role;

revoke all on all sequences in schema atlas_core, atlas_admin, atlas_planning,
  atlas_procurement, atlas_evidence, atlas_dispatch, atlas_audit
  from public, anon, authenticated, service_role;

revoke all on all functions in schema atlas_core, atlas_admin, atlas_planning,
  atlas_procurement, atlas_evidence, atlas_dispatch, atlas_audit, atlas_reporting, atlas_api
  from public, anon, authenticated, service_role;

alter default privileges for role atlas_owner in schema atlas_core, atlas_admin,
  atlas_planning, atlas_procurement, atlas_evidence, atlas_dispatch, atlas_audit,
  atlas_reporting, atlas_api revoke all on tables from public, anon, authenticated, service_role;

alter default privileges for role atlas_owner in schema atlas_core, atlas_admin,
  atlas_planning, atlas_procurement, atlas_evidence, atlas_dispatch, atlas_audit,
  atlas_reporting, atlas_api revoke all on sequences from public, anon, authenticated, service_role;

alter default privileges for role atlas_owner in schema atlas_core, atlas_admin,
  atlas_planning, atlas_procurement, atlas_evidence, atlas_dispatch, atlas_audit,
  atlas_reporting, atlas_api revoke execute on functions from public, anon, authenticated, service_role;

reset role;
