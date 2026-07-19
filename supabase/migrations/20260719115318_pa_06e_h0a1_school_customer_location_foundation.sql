set role atlas_owner;

alter table atlas_admin.customers
  drop constraint customers_customer_type_check;

alter table atlas_admin.customers
  add constraint customers_customer_type_check check (
    customer_type in ('WHOLESALE', 'SCHOOL_CATERING')
  ),
  add constraint customers_customer_id_type_key unique (customer_id, customer_type);

alter table atlas_admin.delivery_locations
  add constraint delivery_locations_customer_id_location_id_key unique (
    customer_id,
    delivery_location_id
  );

create table atlas_admin.school_types (
  school_type_id uuid not null default gen_random_uuid(),
  school_type_code text not null,
  school_type_name text not null,
  school_type_status text not null default 'ACTIVE',
  version bigint not null default 1,
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  constraint school_types_pkey primary key (school_type_id),
  constraint school_types_school_type_code_key unique (school_type_code),
  constraint school_types_school_type_code_check check (
    school_type_code = lower(school_type_code)
    and btrim(school_type_code) <> ''
  ),
  constraint school_types_school_type_name_check check (btrim(school_type_name) <> ''),
  constraint school_types_status_check check (school_type_status in ('ACTIVE', 'INACTIVE')),
  constraint school_types_version_check check (version > 0)
);

create index school_types_status_name_idx
  on atlas_admin.school_types (school_type_status, school_type_name);

create table atlas_admin.schools (
  school_id uuid not null default gen_random_uuid(),
  customer_id uuid not null,
  customer_type text not null default 'SCHOOL_CATERING',
  school_code text not null,
  school_name text not null,
  school_type_id uuid,
  default_delivery_location_id uuid not null,
  school_status text not null default 'ACTIVE',
  display_order integer not null default 0,
  operational_notes text,
  version bigint not null default 1,
  created_at timestamptz not null default transaction_timestamp(),
  updated_at timestamptz not null default transaction_timestamp(),
  constraint schools_pkey primary key (school_id),
  constraint schools_customer_type_fkey foreign key (customer_id, customer_type)
    references atlas_admin.customers (customer_id, customer_type) on delete restrict,
  constraint schools_customer_type_check check (customer_type = 'SCHOOL_CATERING'),
  constraint schools_school_type_fkey foreign key (school_type_id)
    references atlas_admin.school_types (school_type_id) on delete restrict,
  constraint schools_default_delivery_location_fkey foreign key (
    customer_id,
    default_delivery_location_id
  ) references atlas_admin.delivery_locations (customer_id, delivery_location_id) on delete restrict,
  constraint schools_customer_code_key unique (customer_id, school_code),
  constraint schools_school_code_check check (
    school_code = lower(school_code)
    and btrim(school_code) <> ''
  ),
  constraint schools_school_name_check check (btrim(school_name) <> ''),
  constraint schools_status_check check (school_status in ('ACTIVE', 'INACTIVE')),
  constraint schools_display_order_check check (display_order >= 0),
  constraint schools_version_check check (version > 0)
);

create index schools_customer_type_idx
  on atlas_admin.schools (customer_id, customer_type);
create index schools_school_type_idx
  on atlas_admin.schools (school_type_id)
  where school_type_id is not null;
create index schools_default_delivery_location_idx
  on atlas_admin.schools (customer_id, default_delivery_location_id);
create unique index schools_active_display_order_key
  on atlas_admin.schools (customer_id, display_order)
  where school_status = 'ACTIVE';

alter table atlas_core.actor_scopes
  add column school_id uuid,
  add constraint actor_scopes_school_fkey foreign key (school_id)
    references atlas_admin.schools (school_id) on delete restrict;

alter table atlas_core.actor_scopes
  drop constraint actor_scopes_kind_check,
  drop constraint actor_scopes_target_check;

alter table atlas_core.actor_scopes
  add constraint actor_scopes_kind_check check (
    scope_kind in ('GLOBAL', 'CUSTOMER', 'DELIVERY_LOCATION', 'DISPATCH_TRIP', 'SCHOOL')
  ),
  add constraint actor_scopes_target_check check (
    (
      scope_kind = 'GLOBAL'
      and customer_id is null
      and delivery_location_id is null
      and dispatch_trip_id is null
      and school_id is null
    )
    or (
      scope_kind = 'CUSTOMER'
      and customer_id is not null
      and delivery_location_id is null
      and dispatch_trip_id is null
      and school_id is null
    )
    or (
      scope_kind = 'DELIVERY_LOCATION'
      and customer_id is null
      and delivery_location_id is not null
      and dispatch_trip_id is null
      and school_id is null
    )
    or (
      scope_kind = 'DISPATCH_TRIP'
      and customer_id is null
      and delivery_location_id is null
      and dispatch_trip_id is not null
      and school_id is null
    )
    or (
      scope_kind = 'SCHOOL'
      and customer_id is null
      and delivery_location_id is null
      and dispatch_trip_id is null
      and school_id is not null
    )
  );

drop index atlas_core.actor_scopes_active_target_key;

create unique index actor_scopes_active_target_key
  on atlas_core.actor_scopes (
    actor_id,
    scope_kind,
    coalesce(customer_id, delivery_location_id, dispatch_trip_id, school_id)
  )
  where scope_status = 'ACTIVE' and scope_kind <> 'GLOBAL';

create index actor_scopes_school_idx
  on atlas_core.actor_scopes (school_id)
  where school_id is not null;

comment on table atlas_admin.school_types is
  'Private school classification reference data. H0A1 adds structure only and seeds no rows.';
comment on table atlas_admin.schools is
  'Private school reference data owned by one SCHOOL_CATERING customer with a same-customer default delivery location.';
comment on column atlas_admin.schools.customer_type is
  'Typed relational discriminator fixed to SCHOOL_CATERING for the composite customer foreign key.';
comment on column atlas_admin.schools.default_delivery_location_id is
  'Required default service location; the composite foreign key proves it belongs to the same customer.';
comment on column atlas_core.actor_scopes.school_id is
  'Relational target for SCHOOL scopes; null for every other scope kind.';

alter table atlas_admin.school_types enable row level security;
alter table atlas_admin.school_types force row level security;
alter table atlas_admin.schools enable row level security;
alter table atlas_admin.schools force row level security;

revoke all on table atlas_admin.school_types from public, anon, authenticated, service_role;
revoke all on table atlas_admin.schools from public, anon, authenticated, service_role;

reset role;
