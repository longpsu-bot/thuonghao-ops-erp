begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;

select plan(59);

select ok(
  to_regclass('atlas_admin.school_types') is not null,
  'school_types exists in the private Admin schema'
);

select ok(
  to_regclass('atlas_admin.schools') is not null,
  'schools exists in the private Admin schema'
);

select is(
  (
    select array_agg(a.attname order by a.attnum)::text[]
    from pg_attribute a
    where a.attrelid = 'atlas_admin.school_types'::regclass
      and a.attnum > 0
      and not a.attisdropped
  ),
  array[
    'school_type_id',
    'school_type_code',
    'school_type_name',
    'school_type_status',
    'version',
    'created_at',
    'updated_at'
  ]::text[],
  'school_types has only the approved reference fields'
);

select is(
  (
    select array_agg(a.attname order by a.attnum)::text[]
    from pg_attribute a
    where a.attrelid = 'atlas_admin.schools'::regclass
      and a.attnum > 0
      and not a.attisdropped
  ),
  array[
    'school_id',
    'customer_id',
    'customer_type',
    'school_code',
    'school_name',
    'school_type_id',
    'default_delivery_location_id',
    'school_status',
    'display_order',
    'operational_notes',
    'version',
    'created_at',
    'updated_at'
  ]::text[],
  'schools has only the approved reference fields'
);

select ok(
  exists (
    select 1
    from pg_attribute a
    where a.attrelid = 'atlas_core.actor_scopes'::regclass
      and a.attname = 'school_id'
      and not a.attisdropped
  ),
  'actor_scopes has a nullable school target'
);

select ok(
  (
    select not a.attnotnull
    from pg_attribute a
    where a.attrelid = 'atlas_core.actor_scopes'::regclass
      and a.attname = 'school_id'
      and not a.attisdropped
  ),
  'actor_scopes.school_id remains nullable for non-school scopes'
);

select is(
  (
    select pg_get_expr(ad.adbin, ad.adrelid)
    from pg_attrdef ad
    join pg_attribute a
      on a.attrelid = ad.adrelid
     and a.attnum = ad.adnum
    where ad.adrelid = 'atlas_admin.school_types'::regclass
      and a.attname = 'school_type_id'
  ),
  'gen_random_uuid()',
  'school type IDs are database-generated UUIDs'
);

select is(
  (
    select pg_get_expr(ad.adbin, ad.adrelid)
    from pg_attrdef ad
    join pg_attribute a
      on a.attrelid = ad.adrelid
     and a.attnum = ad.adnum
    where ad.adrelid = 'atlas_admin.schools'::regclass
      and a.attname = 'school_id'
  ),
  'gen_random_uuid()',
  'school IDs are database-generated UUIDs'
);

select lives_ok(
  $$
    insert into atlas_admin.customers (
      customer_id,
      customer_code,
      customer_name
    ) values (
      '7e000000-0000-0000-0000-000000000100',
      'pa06e-h0a1-wholesale',
      'PA-06E-H0A1 synthetic wholesale customer'
    )
  $$,
  'existing WHOLESALE customer inserts remain compatible'
);

select lives_ok(
  $$
    insert into atlas_admin.customers (
      customer_id,
      customer_code,
      customer_name,
      customer_type
    ) values (
      '7e000000-0000-0000-0000-000000000200',
      'pa06e-h0a1-school-a',
      'PA-06E-H0A1 synthetic school-catering customer A',
      'SCHOOL_CATERING'
    )
  $$,
  'SCHOOL_CATERING is an accepted customer classification'
);

select lives_ok(
  $$
    insert into atlas_admin.customers (
      customer_id,
      customer_code,
      customer_name,
      customer_type
    ) values (
      '7e000000-0000-0000-0000-000000000300',
      'pa06e-h0a1-school-b',
      'PA-06E-H0A1 synthetic school-catering customer B',
      'SCHOOL_CATERING'
    )
  $$,
  'multiple school-catering customers remain independent'
);

select throws_ok(
  $$
    insert into atlas_admin.customers (
      customer_id,
      customer_code,
      customer_name,
      customer_type
    ) values (
      '7e000000-0000-0000-0000-000000000400',
      'pa06e-h0a1-invalid-customer',
      'PA-06E-H0A1 invalid customer type',
      'SCHOOL'
    )
  $$,
  '23514',
  'new row for relation "customers" violates check constraint "customers_customer_type_check"',
  'customer classifications remain closed to the two approved values'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'atlas_admin.customers'::regclass
      and conname = 'customers_customer_id_type_key'
      and contype = 'u'
  ),
  'customers exposes a typed relational unique key'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'atlas_admin.delivery_locations'::regclass
      and conname = 'delivery_locations_customer_id_location_id_key'
      and contype = 'u'
  ),
  'delivery locations expose a same-customer relational unique key'
);

select lives_ok(
  $$
    insert into atlas_admin.delivery_locations (
      delivery_location_id,
      customer_id,
      location_code,
      location_name,
      address_text
    ) values (
      '7e000000-0000-0000-0000-000000000101',
      '7e000000-0000-0000-0000-000000000100',
      'pa06e-h0a1-wholesale-location',
      'PA-06E-H0A1 synthetic wholesale location',
      'Synthetic wholesale address'
    )
  $$,
  'existing delivery-location inserts remain compatible'
);

select is(
  (
    select timezone_name
    from atlas_admin.delivery_locations
    where delivery_location_id = '7e000000-0000-0000-0000-000000000101'
  ),
  'Asia/Bangkok',
  'the existing delivery-location timezone default is unchanged'
);

select lives_ok(
  $$
    insert into atlas_admin.delivery_locations (
      delivery_location_id,
      customer_id,
      location_code,
      location_name,
      address_text,
      timezone_name
    ) values (
      '7e000000-0000-0000-0000-000000000201',
      '7e000000-0000-0000-0000-000000000200',
      'pa06e-h0a1-school-location-a',
      'PA-06E-H0A1 synthetic school location A',
      'Synthetic school address A',
      'Asia/Ho_Chi_Minh'
    )
  $$,
  'school fixture A uses an explicit Vietnam timezone'
);

select lives_ok(
  $$
    insert into atlas_admin.delivery_locations (
      delivery_location_id,
      customer_id,
      location_code,
      location_name,
      address_text,
      timezone_name
    ) values (
      '7e000000-0000-0000-0000-000000000301',
      '7e000000-0000-0000-0000-000000000300',
      'pa06e-h0a1-school-location-b',
      'PA-06E-H0A1 synthetic school location B',
      'Synthetic school address B',
      'Asia/Ho_Chi_Minh'
    )
  $$,
  'school fixture B uses an explicit Vietnam timezone'
);

select lives_ok(
  $$
    insert into atlas_admin.school_types (
      school_type_id,
      school_type_code,
      school_type_name
    ) values (
      '7e000000-0000-0000-0000-000000000500',
      'primary',
      'Primary School'
    )
  $$,
  'a valid private school type can be recorded'
);

select throws_ok(
  $$
    insert into atlas_admin.school_types (
      school_type_id,
      school_type_code,
      school_type_name
    ) values (
      '7e000000-0000-0000-0000-000000000501',
      'UPPERCASE',
      'Invalid uppercase type'
    )
  $$,
  '23514',
  'new row for relation "school_types" violates check constraint "school_types_school_type_code_check"',
  'school type codes must be lowercase stable codes'
);

select throws_ok(
  $$
    insert into atlas_admin.school_types (
      school_type_id,
      school_type_code,
      school_type_name,
      school_type_status
    ) values (
      '7e000000-0000-0000-0000-000000000502',
      'invalid-status',
      'Invalid status type',
      'DELETED'
    )
  $$,
  '23514',
  'new row for relation "school_types" violates check constraint "school_types_status_check"',
  'school types use only ACTIVE or INACTIVE lifecycle states'
);

select lives_ok(
  $$
    insert into atlas_admin.schools (
      school_id,
      customer_id,
      school_code,
      school_name,
      school_type_id,
      default_delivery_location_id,
      display_order,
      operational_notes
    ) values (
      '7e000000-0000-0000-0000-000000000600',
      '7e000000-0000-0000-0000-000000000200',
      'campus-a',
      'PA-06E-H0A1 synthetic school A',
      '7e000000-0000-0000-0000-000000000500',
      '7e000000-0000-0000-0000-000000000201',
      10,
      'Synthetic fixture only'
    )
  $$,
  'a valid school uses a school-catering customer and same-customer location'
);

select is(
  (
    select row(
      customer_type,
      school_status,
      display_order,
      version
    )::text
    from atlas_admin.schools
    where school_id = '7e000000-0000-0000-0000-000000000600'
  ),
  '(SCHOOL_CATERING,ACTIVE,10,1)',
  'school classification, lifecycle, order, and version defaults are exact'
);

select throws_ok(
  $$
    insert into atlas_admin.schools (
      school_id,
      customer_id,
      school_code,
      school_name,
      default_delivery_location_id,
      display_order
    ) values (
      '7e000000-0000-0000-0000-000000000601',
      '7e000000-0000-0000-0000-000000000100',
      'wholesale-school',
      'Invalid wholesale school',
      '7e000000-0000-0000-0000-000000000101',
      1
    )
  $$,
  '23503',
  'insert or update on table "schools" violates foreign key constraint "schools_customer_type_fkey"',
  'a WHOLESALE customer cannot own a school'
);

select throws_ok(
  $$
    insert into atlas_admin.schools (
      school_id,
      customer_id,
      school_code,
      school_name,
      default_delivery_location_id,
      display_order
    ) values (
      '7e000000-0000-0000-0000-000000000602',
      '7e000000-0000-0000-0000-000000000200',
      'cross-customer-location',
      'Invalid cross-customer school',
      '7e000000-0000-0000-0000-000000000301',
      11
    )
  $$,
  '23503',
  'insert or update on table "schools" violates foreign key constraint "schools_default_delivery_location_fkey"',
  'a school cannot use another customer default location'
);

select throws_ok(
  $$
    insert into atlas_admin.schools (
      school_id,
      customer_id,
      school_code,
      school_name,
      default_delivery_location_id,
      display_order
    ) values (
      '7e000000-0000-0000-0000-000000000603',
      '7e000000-0000-0000-0000-000000000200',
      'UPPERCASE',
      'Invalid uppercase school code',
      '7e000000-0000-0000-0000-000000000201',
      11
    )
  $$,
  '23514',
  'new row for relation "schools" violates check constraint "schools_school_code_check"',
  'school codes must be lowercase stable codes'
);

select throws_ok(
  $$
    insert into atlas_admin.schools (
      school_id,
      customer_id,
      school_code,
      school_name,
      default_delivery_location_id,
      display_order
    ) values (
      '7e000000-0000-0000-0000-000000000604',
      '7e000000-0000-0000-0000-000000000200',
      'campus-a',
      'Duplicate school code',
      '7e000000-0000-0000-0000-000000000201',
      11
    )
  $$,
  '23505',
  'duplicate key value violates unique constraint "schools_customer_code_key"',
  'school codes are unique within one customer'
);

select lives_ok(
  $$
    insert into atlas_admin.schools (
      school_id,
      customer_id,
      school_code,
      school_name,
      default_delivery_location_id,
      display_order
    ) values (
      '7e000000-0000-0000-0000-000000000605',
      '7e000000-0000-0000-0000-000000000300',
      'campus-a',
      'Same code under another customer',
      '7e000000-0000-0000-0000-000000000301',
      10
    )
  $$,
  'the same school code is valid under a different customer'
);

select throws_ok(
  $$
    insert into atlas_admin.schools (
      school_id,
      customer_id,
      school_code,
      school_name,
      default_delivery_location_id,
      display_order
    ) values (
      '7e000000-0000-0000-0000-000000000606',
      '7e000000-0000-0000-0000-000000000200',
      'duplicate-active-order',
      'Duplicate active order',
      '7e000000-0000-0000-0000-000000000201',
      10
    )
  $$,
  '23505',
  'duplicate key value violates unique constraint "schools_active_display_order_key"',
  'active school display order is unique within one customer'
);

select lives_ok(
  $$
    insert into atlas_admin.schools (
      school_id,
      customer_id,
      school_code,
      school_name,
      default_delivery_location_id,
      school_status,
      display_order
    ) values (
      '7e000000-0000-0000-0000-000000000607',
      '7e000000-0000-0000-0000-000000000200',
      'historical-order',
      'Inactive historical order',
      '7e000000-0000-0000-0000-000000000201',
      'INACTIVE',
      10
    )
  $$,
  'inactive school history can retain a reused display order'
);

select throws_ok(
  $$
    insert into atlas_admin.schools (
      school_id,
      customer_id,
      school_code,
      school_name,
      default_delivery_location_id,
      display_order
    ) values (
      '7e000000-0000-0000-0000-000000000608',
      '7e000000-0000-0000-0000-000000000200',
      'negative-order',
      'Invalid negative order',
      '7e000000-0000-0000-0000-000000000201',
      -1
    )
  $$,
  '23514',
  'new row for relation "schools" violates check constraint "schools_display_order_check"',
  'school display order cannot be negative'
);

select throws_ok(
  $$
    insert into atlas_admin.schools (
      school_id,
      customer_id,
      school_code,
      school_name,
      school_type_id,
      default_delivery_location_id,
      display_order
    ) values (
      '7e000000-0000-0000-0000-000000000609',
      '7e000000-0000-0000-0000-000000000200',
      'missing-school-type',
      'Invalid missing school type',
      '7e000000-0000-0000-0000-000000000599',
      '7e000000-0000-0000-0000-000000000201',
      11
    )
  $$,
  '23503',
  'insert or update on table "schools" violates foreign key constraint "schools_school_type_fkey"',
  'school type references are relational and typed'
);

select throws_ok(
  $$delete from atlas_admin.school_types where school_type_id = '7e000000-0000-0000-0000-000000000500'$$,
  '23503',
  'update or delete on table "school_types" violates foreign key constraint "schools_school_type_fkey" on table "schools"',
  'referenced school types cannot be cascade-deleted'
);

select throws_ok(
  $$delete from atlas_admin.delivery_locations where delivery_location_id = '7e000000-0000-0000-0000-000000000201'$$,
  '23503',
  'update or delete on table "delivery_locations" violates foreign key constraint "schools_default_delivery_location_fkey" on table "schools"',
  'referenced default delivery locations cannot be cascade-deleted'
);

select ok(
  (
    select count(*) = 4 and bool_and(con.confdeltype = 'r')
    from pg_constraint con
    where con.conname in (
      'schools_customer_type_fkey',
      'schools_school_type_fkey',
      'schools_default_delivery_location_fkey',
      'actor_scopes_school_fkey'
    )
  ),
  'every H0A1 foreign key uses ON DELETE RESTRICT'
);

insert into atlas_core.actors (
  actor_id,
  actor_type,
  display_name
) values (
  '7e000000-0000-0000-0000-000000000700',
  'HUMAN',
  'PA-06E-H0A1 synthetic scoped actor'
);

insert into atlas_dispatch.dispatch_plans (
  dispatch_plan_id,
  plan_reference,
  service_date,
  created_by_actor_id
) values (
  '7e000000-0000-0000-0000-000000000710',
  'PA06E-H0A1-PLAN',
  date '2026-07-20',
  '7e000000-0000-0000-0000-000000000700'
);

insert into atlas_dispatch.dispatch_trips (
  dispatch_trip_id,
  dispatch_plan_id,
  trip_reference
) values (
  '7e000000-0000-0000-0000-000000000711',
  '7e000000-0000-0000-0000-000000000710',
  'PA06E-H0A1-TRIP'
);

select lives_ok(
  $$
    insert into atlas_core.actor_scopes (
      actor_scope_id,
      actor_id,
      scope_kind
    ) values (
      '7e000000-0000-0000-0000-000000000720',
      '7e000000-0000-0000-0000-000000000700',
      'GLOBAL'
    )
  $$,
  'the existing GLOBAL scope kind remains valid without a target'
);

select lives_ok(
  $$
    insert into atlas_core.actor_scopes (
      actor_scope_id,
      actor_id,
      scope_kind,
      customer_id
    ) values (
      '7e000000-0000-0000-0000-000000000721',
      '7e000000-0000-0000-0000-000000000700',
      'CUSTOMER',
      '7e000000-0000-0000-0000-000000000200'
    )
  $$,
  'the existing CUSTOMER scope kind remains valid'
);

select lives_ok(
  $$
    insert into atlas_core.actor_scopes (
      actor_scope_id,
      actor_id,
      scope_kind,
      delivery_location_id
    ) values (
      '7e000000-0000-0000-0000-000000000722',
      '7e000000-0000-0000-0000-000000000700',
      'DELIVERY_LOCATION',
      '7e000000-0000-0000-0000-000000000201'
    )
  $$,
  'the existing DELIVERY_LOCATION scope kind remains valid'
);

select lives_ok(
  $$
    insert into atlas_core.actor_scopes (
      actor_scope_id,
      actor_id,
      scope_kind,
      dispatch_trip_id
    ) values (
      '7e000000-0000-0000-0000-000000000723',
      '7e000000-0000-0000-0000-000000000700',
      'DISPATCH_TRIP',
      '7e000000-0000-0000-0000-000000000711'
    )
  $$,
  'the existing DISPATCH_TRIP scope kind remains valid'
);

select lives_ok(
  $$
    insert into atlas_core.actor_scopes (
      actor_scope_id,
      actor_id,
      scope_kind,
      school_id
    ) values (
      '7e000000-0000-0000-0000-000000000724',
      '7e000000-0000-0000-0000-000000000700',
      'SCHOOL',
      '7e000000-0000-0000-0000-000000000600'
    )
  $$,
  'a SCHOOL scope accepts exactly one relational school target'
);

select throws_ok(
  $$
    insert into atlas_core.actor_scopes (
      actor_scope_id,
      actor_id,
      scope_kind
    ) values (
      '7e000000-0000-0000-0000-000000000725',
      '7e000000-0000-0000-0000-000000000700',
      'SCHOOL'
    )
  $$,
  '23514',
  'new row for relation "actor_scopes" violates check constraint "actor_scopes_target_check"',
  'a SCHOOL scope requires a school target'
);

select throws_ok(
  $$
    insert into atlas_core.actor_scopes (
      actor_scope_id,
      actor_id,
      scope_kind,
      customer_id,
      school_id
    ) values (
      '7e000000-0000-0000-0000-000000000726',
      '7e000000-0000-0000-0000-000000000700',
      'SCHOOL',
      '7e000000-0000-0000-0000-000000000200',
      '7e000000-0000-0000-0000-000000000600'
    )
  $$,
  '23514',
  'new row for relation "actor_scopes" violates check constraint "actor_scopes_target_check"',
  'a SCHOOL scope cannot mix school and customer targets'
);

select throws_ok(
  $$
    insert into atlas_core.actor_scopes (
      actor_scope_id,
      actor_id,
      scope_kind,
      school_id
    ) values (
      '7e000000-0000-0000-0000-000000000727',
      '7e000000-0000-0000-0000-000000000700',
      'GLOBAL',
      '7e000000-0000-0000-0000-000000000600'
    )
  $$,
  '23514',
  'new row for relation "actor_scopes" violates check constraint "actor_scopes_target_check"',
  'GLOBAL cannot be mixed with a school target'
);

select throws_ok(
  $$
    insert into atlas_core.actor_scopes (
      actor_scope_id,
      actor_id,
      scope_kind,
      school_id
    ) values (
      '7e000000-0000-0000-0000-000000000728',
      '7e000000-0000-0000-0000-000000000700',
      'SCHOOL',
      '7e000000-0000-0000-0000-000000000600'
    )
  $$,
  '23505',
  'duplicate key value violates unique constraint "actor_scopes_active_target_key"',
  'one actor cannot hold duplicate active SCHOOL scopes'
);

select lives_ok(
  $$
    insert into atlas_core.actor_scopes (
      actor_scope_id,
      actor_id,
      scope_kind,
      school_id,
      scope_status
    ) values (
      '7e000000-0000-0000-0000-000000000729',
      '7e000000-0000-0000-0000-000000000700',
      'SCHOOL',
      '7e000000-0000-0000-0000-000000000600',
      'REVOKED'
    )
  $$,
  'revoked SCHOOL scope history remains retainable'
);

select throws_ok(
  $$
    insert into atlas_core.actor_scopes (
      actor_scope_id,
      actor_id,
      scope_kind,
      school_id
    ) values (
      '7e000000-0000-0000-0000-000000000730',
      '7e000000-0000-0000-0000-000000000700',
      'SCHOOL',
      '7e000000-0000-0000-0000-000000000699'
    )
  $$,
  '23503',
  'insert or update on table "actor_scopes" violates foreign key constraint "actor_scopes_school_fkey"',
  'SCHOOL scope targets must reference a real school'
);

select throws_ok(
  $$delete from atlas_admin.schools where school_id = '7e000000-0000-0000-0000-000000000600'$$,
  '23503',
  'update or delete on table "schools" violates foreign key constraint "actor_scopes_school_fkey" on table "actor_scopes"',
  'a scoped school cannot be cascade-deleted'
);

select ok(
  exists (
    select 1
    from pg_indexes
    where schemaname = 'atlas_core'
      and indexname = 'actor_scopes_active_target_key'
      and indexdef ilike '%school_id%'
  ),
  'active scope uniqueness includes the SCHOOL target'
);

select ok(
  not exists (
    select 1
    from pg_constraint con
    where con.conname in (
      'schools_customer_type_fkey',
      'schools_school_type_fkey',
      'schools_default_delivery_location_fkey',
      'actor_scopes_school_fkey'
    )
      and not exists (
        select 1
        from pg_index idx
        where idx.indrelid = con.conrelid
          and idx.indisvalid
          and (
            select array_agg(key_column.attnum::smallint order by key_column.ordinality)
            from unnest(idx.indkey::smallint[]) with ordinality
              as key_column(attnum, ordinality)
            where key_column.ordinality <= cardinality(con.conkey)
          ) = con.conkey
      )
  ),
  'every H0A1 foreign key has a matching leading-column index'
);

select ok(
  exists (
    select 1
    from pg_indexes
    where schemaname = 'atlas_admin'
      and indexname = 'schools_active_display_order_key'
      and indexdef ilike '%unique%'
      and indexdef ilike '%where (school_status = ''ACTIVE''%'
  ),
  'active school display order is protected by a partial unique index'
);

select ok(
  not exists (
    select 1
    from pg_class c
    where c.oid in (
      'atlas_admin.school_types'::regclass,
      'atlas_admin.schools'::regclass
    )
      and (not c.relrowsecurity or not c.relforcerowsecurity)
  ),
  'school tables have RLS enabled and forced'
);

select is(
  (
    select array_agg(r.rolname order by c.relname)::text[]
    from pg_class c
    join pg_roles r on r.oid = c.relowner
    where c.oid in (
      'atlas_admin.school_types'::regclass,
      'atlas_admin.schools'::regclass
    )
  ),
  array['atlas_owner', 'atlas_owner']::text[],
  'school tables are owned by atlas_owner'
);

select ok(
  not exists (
    select 1
    from unnest(array['anon', 'authenticated', 'service_role']) as api_role(role_name)
    cross join unnest(
      array['atlas_admin.school_types', 'atlas_admin.schools']
    ) as private_relation(relation_name)
    where has_table_privilege(api_role.role_name, private_relation.relation_name, 'SELECT')
      or has_table_privilege(api_role.role_name, private_relation.relation_name, 'INSERT')
      or has_table_privilege(api_role.role_name, private_relation.relation_name, 'UPDATE')
      or has_table_privilege(api_role.role_name, private_relation.relation_name, 'DELETE')
  ),
  'browser-facing API roles have no direct school-table privileges'
);

select ok(
  not exists (
    select 1
    from pg_policy p
    where p.polrelid in (
      'atlas_admin.school_types'::regclass,
      'atlas_admin.schools'::regclass
    )
  ),
  'school tables expose no direct RLS policy path'
);

select ok(
  not exists (
    select 1
    from unnest(array['anon', 'authenticated', 'service_role']) as api_role(role_name)
    cross join pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname in ('atlas_admin', 'atlas_core')
      and c.relkind = 'S'
      and has_sequence_privilege(api_role.role_name, c.oid, 'USAGE')
  ),
  'browser-facing API roles have no private sequence usage'
);

select ok(
  not exists (
    select 1
    from pg_default_acl d
    join pg_namespace n on n.oid = d.defaclnamespace
    cross join lateral aclexplode(d.defaclacl) privilege
    left join pg_roles grantee on grantee.oid = privilege.grantee
    where d.defaclrole = 'atlas_owner'::regrole
      and n.nspname in ('atlas_admin', 'atlas_core')
      and d.defaclobjtype in ('r', 'S', 'f')
      and (
        privilege.grantee = 0
        or grantee.rolname in ('anon', 'authenticated', 'service_role')
      )
  ),
  'atlas_owner default privileges remain fail-closed for public and API roles'
);

select is(
  (
    select array_agg(
      format('%s(%s)', p.proname, pg_get_function_identity_arguments(p.oid))
      order by p.proname
    )::text[]
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
  ),
  array[
    'allocate_supplier_direct_fulfilment(request jsonb)',
    'apply_supplier_evidence_to_allocation(request jsonb)',
    'close_successful_trip(request jsonb)',
    'confirm_dispatch_load(request jsonb)',
    'confirm_successful_delivery(request jsonb)',
    'create_confirmed_needs_from_generation(request jsonb)',
    'create_dispatch_plan(request jsonb)',
    'create_or_assign_dispatch_trip(request jsonb)',
    'get_command_audit_timeline(request jsonb)',
    'get_dispatch_evidence_readiness(request jsonb)',
    'get_operator_blockers(request jsonb)',
    'get_supplier_direct_trace(request jsonb)',
    'record_dispatch_departure(request jsonb)',
    'record_supplier_receiving_evidence(request jsonb)',
    'record_wholesale_source(request jsonb)',
    'release_dispatch_requirement(request jsonb)',
    'release_purchase_handoff(request jsonb)',
    'release_supplier_purchase_order(request jsonb)',
    'release_wholesale_order(request jsonb)'
  ]::text[],
  'the exact 19-function atlas_api registry includes CMD-15'
);

select is(
  (select count(*)::integer from atlas_core.roles),
  0,
  'H0A1 seeds no roles'
);

select is(
  (select count(*)::integer from atlas_core.capabilities),
  0,
  'H0A1 seeds no capabilities'
);

select * from finish();

rollback;
