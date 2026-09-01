begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set search_path = extensions, public, pg_catalog;

select plan(59);

-- Public surface, ownership, and execute boundary.
select has_function('atlas_api', 'create_school_catering_purchase_order_drafts', array['jsonb']);
select has_function('atlas_api', 'release_school_catering_purchase_order', array['jsonb']);
select has_function('atlas_api', 'get_school_catering_purchase_orders', array['jsonb']);
select function_owner_is('atlas_api', 'create_school_catering_purchase_order_drafts', array['jsonb'],
  'atlas_procurement_command_runtime');
select function_owner_is('atlas_api', 'release_school_catering_purchase_order', array['jsonb'],
  'atlas_procurement_command_runtime');
select function_owner_is('atlas_api', 'get_school_catering_purchase_orders', array['jsonb'],
  'atlas_read_runtime');
select ok(not exists(
  select 1
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  join pg_roles r on r.oid=p.proowner
  where n.nspname='atlas_api'
    and p.proname in (
      'create_school_catering_purchase_order_drafts',
      'release_school_catering_purchase_order',
      'get_school_catering_purchase_orders'
    )
    and (
      not p.prosecdef
      or p.proconfig is null
      or p.proconfig::text not like '%search_path=%'
      or r.rolname not in ('atlas_procurement_command_runtime','atlas_read_runtime')
    )
), 'PR-B entry functions are hardened definers with pinned search paths');
select ok(not exists(
  select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='atlas_api'
    and p.proname in (
      'create_school_catering_purchase_order_drafts',
      'release_school_catering_purchase_order',
      'get_school_catering_purchase_orders'
    )
    and pg_get_functiondef(p.oid) ~* '\\mexecute\\M'
), 'PR-B entry functions contain no dynamic SQL');
select function_privs_are('atlas_api', 'create_school_catering_purchase_order_drafts',
  array['jsonb'], 'authenticated', array['EXECUTE']);
select function_privs_are('atlas_api', 'release_school_catering_purchase_order',
  array['jsonb'], 'authenticated', array['EXECUTE']);
select function_privs_are('atlas_api', 'get_school_catering_purchase_orders',
  array['jsonb'], 'authenticated', array['EXECUTE']);
select function_privs_are('atlas_api', 'create_school_catering_purchase_order_drafts',
  array['jsonb'], 'anon', array[]::text[]);
select function_privs_are('atlas_api', 'release_school_catering_purchase_order',
  array['jsonb'], 'anon', array[]::text[]);
select function_privs_are('atlas_api', 'get_school_catering_purchase_orders',
  array['jsonb'], 'anon', array[]::text[]);

-- Shared Purchase Order aggregate extension.
select has_column('atlas_procurement','purchase_orders','purchase_order_kind',
  'shared PO root declares its source kind');
select has_column('atlas_procurement','purchase_orders','school_catering_service_date',
  'school-catering root stores the supplier/date identity date');
select col_default_is('atlas_procurement','purchase_orders','purchase_order_kind',
  'SUPPLIER_DIRECT_WHOLESALE',
  'legacy/wholesale inserts default to the existing PO kind');
select has_check('atlas_procurement','purchase_orders','purchase_orders_kind_check');
select has_check('atlas_procurement','purchase_orders','purchase_orders_school_catering_date_check');
select ok(exists(
  select 1 from pg_indexes
  where schemaname='atlas_procurement' and tablename='purchase_orders'
    and indexdef ilike '%unique%supplier_id%school_catering_service_date%'
    and indexdef ilike '%purchase_order_kind%SCHOOL_CATERING%'
), 'one active school-catering PO lineage is enforced per supplier and service date');
select has_column('atlas_procurement','purchase_order_lines','school_catering_allocation_family_id',
  'stable PO line supports a school-catering Allocation Family source');
select ok(exists(
  select 1 from information_schema.columns
  where table_schema='atlas_procurement' and table_name='purchase_order_lines'
    and column_name='fulfilment_allocation_line_id' and is_nullable='YES'
), 'wholesale PO stable-line source becomes nullable for the shared XOR');
select has_check('atlas_procurement','purchase_order_lines','purchase_order_lines_source_xor_check');
select has_column('atlas_procurement','purchase_order_line_revisions',
  'school_catering_allocation_supplier_split_id',
  'PO line revision supports an exact school-catering Supplier Split source');
select ok(exists(
  select 1 from information_schema.columns
  where table_schema='atlas_procurement' and table_name='purchase_order_line_revisions'
    and column_name='fulfilment_allocation_line_revision_id' and is_nullable='YES'
), 'wholesale PO line-revision source becomes nullable for the shared XOR');
select has_check('atlas_procurement','purchase_order_line_revisions',
  'purchase_order_line_revisions_source_xor_check');
select ok(exists(
  select 1 from information_schema.columns
  where table_schema='atlas_procurement' and table_name='purchase_order_revisions'
    and column_name='delivery_location_id' and is_nullable='YES'
), 'school-catering PO revisions permit a null multi-destination header location');
select ok(exists(
  select 1 from pg_trigger
  where tgrelid='atlas_procurement.purchase_order_revisions'::regclass
    and tgname='school_catering_purchase_order_revision_integrity'
    and not tgisinternal
), 'shared PO revision integrity is enforced by a deferred exact trigger');

-- Real PR-A source facts: one ready date with three balanced families and one
-- blocked date with an unallocated family.
insert into atlas_core.actors(actor_id,actor_type,display_name)
values('24000000-0000-4000-8000-000000000001','HUMAN','PR-B Procurement operator');
insert into atlas_core.actor_auth_subjects(actor_id,auth_subject_id)
values('24000000-0000-4000-8000-000000000001','24000000-0000-4000-8000-000000000101');
insert into atlas_core.roles(role_id,role_code,role_name)
values('24010000-0000-4000-8000-000000000001','pr_b_procurement_operator',
  'PR-B Procurement operator');
insert into atlas_core.role_capabilities(role_id,capability_id)
select '24010000-0000-4000-8000-000000000001',capability_id
from atlas_core.capabilities
where capability_code in ('procurement.school_catering.read','procurement.school_catering.write');
insert into atlas_core.actor_role_memberships(actor_id,role_id)
values('24000000-0000-4000-8000-000000000001','24010000-0000-4000-8000-000000000001');
insert into atlas_core.actor_scopes(actor_id,scope_kind)
values('24000000-0000-4000-8000-000000000001','GLOBAL');

insert into atlas_admin.customers(customer_id,customer_code,customer_name,customer_type)
values('24020000-0000-4000-8000-000000000001','pr-b-school-customer',
  'PR-B School Customer','SCHOOL_CATERING');
insert into atlas_admin.delivery_locations(
  delivery_location_id,customer_id,location_code,location_name,address_text)
values
  ('24020000-0000-4000-8000-000000000011','24020000-0000-4000-8000-000000000001',
   'pr-b-location-a','PR-B Location Alpha','Alpha address'),
  ('24020000-0000-4000-8000-000000000012','24020000-0000-4000-8000-000000000001',
   'pr-b-location-b','PR-B Location Beta','Beta address');
insert into atlas_admin.schools(
  school_id,customer_id,school_code,school_name,default_delivery_location_id,display_order)
values
  ('24020000-0000-4000-8000-000000000021','24020000-0000-4000-8000-000000000001',
   'pr-b-school-a','PR-B School Alpha','24020000-0000-4000-8000-000000000011',1),
  ('24020000-0000-4000-8000-000000000022','24020000-0000-4000-8000-000000000001',
   'pr-b-school-b','PR-B School Beta','24020000-0000-4000-8000-000000000012',2);
insert into atlas_admin.units(unit_id,unit_code,unit_name,dimension_code)
values('24020000-0000-4000-8000-000000000031','pr-b-kg','PR-B kilogram','mass');
insert into atlas_admin.ingredients(ingredient_id,ingredient_code,ingredient_name,purchase_unit_id)
values
  ('24020000-0000-4000-8000-000000000041','pr-b-rice','PR-B Rice',
   '24020000-0000-4000-8000-000000000031'),
  ('24020000-0000-4000-8000-000000000042','pr-b-beans','PR-B Beans',
   '24020000-0000-4000-8000-000000000031');
insert into atlas_admin.suppliers(supplier_id,supplier_code,supplier_name,supplier_status)
values
  ('24020000-0000-4000-8000-000000000051','pr-b-supplier-a','PR-B Supplier Alpha','ACTIVE'),
  ('24020000-0000-4000-8000-000000000052','pr-b-supplier-b','PR-B Supplier Beta','ACTIVE'),
  ('24020000-0000-4000-8000-000000000053','pr-b-supplier-c','PR-B Supplier Gamma','ACTIVE');
insert into atlas_admin.supplier_eligibilities(
  supplier_id,ingredient_id,effective_from,priority,reason_note)
values
  ('24020000-0000-4000-8000-000000000051','24020000-0000-4000-8000-000000000041',
   '2026-01-01',1,'PR-B test'),
  ('24020000-0000-4000-8000-000000000052','24020000-0000-4000-8000-000000000041',
   '2026-01-01',2,'PR-B test'),
  ('24020000-0000-4000-8000-000000000053','24020000-0000-4000-8000-000000000042',
   '2026-01-01',1,'PR-B test');

set session_replication_role = replica;
insert into atlas_planning.purchase_handoff_batches(
  purchase_handoff_batch_id,confirmed_need_batch_id,period_start,period_end,
  handoff_status,created_by_actor_id)
values('24030000-0000-4000-8000-000000000061','24030000-0000-4000-8000-000000000060',
  '2026-09-21','2026-09-22','RELEASED_TO_PROCUREMENT','24000000-0000-4000-8000-000000000001');
insert into atlas_planning.purchase_handoff_revisions(
  purchase_handoff_revision_id,purchase_handoff_batch_id,revision_number,
  revision_status,is_current,released_by_actor_id,released_at)
values('24030000-0000-4000-8000-000000000062','24030000-0000-4000-8000-000000000061',
  1,'RELEASED_TO_PROCUREMENT',true,'24000000-0000-4000-8000-000000000001',
  transaction_timestamp());
insert into atlas_planning.purchase_handoff_lines(
  purchase_handoff_line_id,purchase_handoff_batch_id,confirmed_need_line_id)
values
  ('24030000-0000-4000-8000-000000000071','24030000-0000-4000-8000-000000000061','24030000-0000-4000-8000-000000000171'),
  ('24030000-0000-4000-8000-000000000072','24030000-0000-4000-8000-000000000061','24030000-0000-4000-8000-000000000172'),
  ('24030000-0000-4000-8000-000000000073','24030000-0000-4000-8000-000000000061','24030000-0000-4000-8000-000000000173'),
  ('24030000-0000-4000-8000-000000000074','24030000-0000-4000-8000-000000000061','24030000-0000-4000-8000-000000000174');
insert into atlas_planning.purchase_handoff_line_revisions(
  purchase_handoff_line_revision_id,purchase_handoff_revision_id,purchase_handoff_line_id,
  confirmed_need_line_revision_id,ingredient_id,handoff_quantity,unit_id,service_date,
  delivery_location_id,command_id)
values
  ('24030000-0000-4000-8000-000000000081','24030000-0000-4000-8000-000000000062',
   '24030000-0000-4000-8000-000000000071','24030000-0000-4000-8000-000000000181',
   '24020000-0000-4000-8000-000000000041',100,'24020000-0000-4000-8000-000000000031',
   '2026-09-21','24020000-0000-4000-8000-000000000011','24030000-0000-4000-8000-000000000161'),
  ('24030000-0000-4000-8000-000000000082','24030000-0000-4000-8000-000000000062',
   '24030000-0000-4000-8000-000000000072','24030000-0000-4000-8000-000000000182',
   '24020000-0000-4000-8000-000000000041',50,'24020000-0000-4000-8000-000000000031',
   '2026-09-21','24020000-0000-4000-8000-000000000012','24030000-0000-4000-8000-000000000162'),
  ('24030000-0000-4000-8000-000000000083','24030000-0000-4000-8000-000000000062',
   '24030000-0000-4000-8000-000000000073','24030000-0000-4000-8000-000000000183',
   '24020000-0000-4000-8000-000000000042',30,'24020000-0000-4000-8000-000000000031',
   '2026-09-21','24020000-0000-4000-8000-000000000011','24030000-0000-4000-8000-000000000163'),
  ('24030000-0000-4000-8000-000000000084','24030000-0000-4000-8000-000000000062',
   '24030000-0000-4000-8000-000000000074','24030000-0000-4000-8000-000000000184',
   '24020000-0000-4000-8000-000000000041',20,'24020000-0000-4000-8000-000000000031',
   '2026-09-22','24020000-0000-4000-8000-000000000011','24030000-0000-4000-8000-000000000164');
insert into atlas_planning.purchase_demand_references(
  purchase_demand_reference_id,purchase_handoff_line_revision_id,
  confirmed_need_snapshot_line_id,approved_quantity,unit_id,source_kind)
values
  ('24030000-0000-4000-8000-000000000091','24030000-0000-4000-8000-000000000081','24030000-0000-4000-8000-000000000191',100,'24020000-0000-4000-8000-000000000031','NEED_GENERATION'),
  ('24030000-0000-4000-8000-000000000092','24030000-0000-4000-8000-000000000082','24030000-0000-4000-8000-000000000192',50,'24020000-0000-4000-8000-000000000031','NEED_GENERATION'),
  ('24030000-0000-4000-8000-000000000093','24030000-0000-4000-8000-000000000083','24030000-0000-4000-8000-000000000193',30,'24020000-0000-4000-8000-000000000031','NEED_GENERATION'),
  ('24030000-0000-4000-8000-000000000094','24030000-0000-4000-8000-000000000084','24030000-0000-4000-8000-000000000194',20,'24020000-0000-4000-8000-000000000031','NEED_GENERATION');
set session_replication_role = origin;

create temporary table prb_results(name text primary key,response jsonb not null);
grant select,insert on prb_results to authenticated;
create function pg_temp.prb_command(
  p_command uuid,p_expected bigint,p_reason text,p_payload jsonb,
  p_subject uuid default '24000000-0000-4000-8000-000000000101'
) returns jsonb language sql stable set search_path='' as $$
  select jsonb_build_object(
    'contract_version','SCHOOL-CATERING-PROCUREMENT.v1',
    'command_id',p_command,'correlation_id',gen_random_uuid(),
    'idempotency_key','pr-b:' || p_command::text,'expected_version',p_expected,
    'requested_by_auth_subject',p_subject,
    'requested_at',transaction_timestamp()-interval '1 second',
    'reason_code',p_reason,'reason_note',null,'payload',p_payload);
$$;
create function pg_temp.prb_family(p_date date,p_location uuid,p_ingredient uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object(
    'service_date',p_date,'delivery_location_id',p_location,'ingredient_id',p_ingredient,
    'unit_id','24020000-0000-4000-8000-000000000031'::uuid,
    'expected_source_fingerprint',projection ->> 'source_fingerprint')
  from (select atlas_core.school_catering_family_projection(
    p_date,p_location,p_ingredient,'24020000-0000-4000-8000-000000000031') projection) source;
$$;
create function pg_temp.prb_read()
returns jsonb language sql stable set search_path='' as $$
  select jsonb_build_object(
    'contract_version','SCHOOL-CATERING-PROCUREMENT.v1',
    'requested_by_auth_subject','24000000-0000-4000-8000-000000000101'::uuid,
    'correlation_id',gen_random_uuid(),
    'payload',jsonb_build_object('date_start','2026-09-21','date_end','2026-09-22',
      'supplier_ids','[]'::jsonb,'statuses','[]'::jsonb,'search',null));
$$;
create function pg_temp.prb_release(
  p_command uuid,p_supplier uuid,p_expected bigint default null,
  p_use_predecessor boolean default false,p_extra_payload jsonb default '{}'::jsonb
) returns jsonb language sql stable security definer set search_path='' as $$
  select pg_temp.prb_command(p_command,coalesce(p_expected,po.version),
    'SCHOOL_CATERING_PO_RELEASED',jsonb_build_object(
      'purchase_order_id',po.purchase_order_id,
      'expected_purchase_order_revision_id',case when p_use_predecessor
        then por.predecessor_revision_id else por.purchase_order_revision_id end
    ) || p_extra_payload) || jsonb_build_object('correlation_id',p_command)
  from atlas_procurement.purchase_orders po
  join atlas_procurement.purchase_order_revisions por using(purchase_order_id)
  where po.supplier_id=p_supplier and po.purchase_order_kind='SCHOOL_CATERING'
    and por.is_current;
$$;
grant execute on function pg_temp.prb_command(uuid,bigint,text,jsonb,uuid),
  pg_temp.prb_family(date,uuid,uuid),pg_temp.prb_read(),
  pg_temp.prb_release(uuid,uuid,bigint,boolean,jsonb) to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.sub','24000000-0000-4000-8000-000000000101',true);
insert into prb_results values('allocation-a-b',atlas_api.save_school_catering_supplier_allocation(
  pg_temp.prb_command('24050000-0000-4000-8000-000000000001',0,
    'SCHOOL_CATERING_SUPPLIER_ALLOCATION_SAVED',jsonb_build_object(
      'family',pg_temp.prb_family('2026-09-21','24020000-0000-4000-8000-000000000011',
        '24020000-0000-4000-8000-000000000041'),
      'splits',jsonb_build_array(
        jsonb_build_object('supplier_id','24020000-0000-4000-8000-000000000051','allocated_quantity',60),
        jsonb_build_object('supplier_id','24020000-0000-4000-8000-000000000052','allocated_quantity',40))))));
insert into prb_results values('allocation-a',atlas_api.save_school_catering_supplier_allocation(
  pg_temp.prb_command('24050000-0000-4000-8000-000000000002',0,
    'SCHOOL_CATERING_SUPPLIER_ALLOCATION_SAVED',jsonb_build_object(
      'family',pg_temp.prb_family('2026-09-21','24020000-0000-4000-8000-000000000012',
        '24020000-0000-4000-8000-000000000041'),
      'splits',jsonb_build_array(jsonb_build_object(
        'supplier_id','24020000-0000-4000-8000-000000000051','allocated_quantity',50))))));
insert into prb_results values('allocation-c',atlas_api.save_school_catering_supplier_allocation(
  pg_temp.prb_command('24050000-0000-4000-8000-000000000003',0,
    'SCHOOL_CATERING_SUPPLIER_ALLOCATION_SAVED',jsonb_build_object(
      'family',pg_temp.prb_family('2026-09-21','24020000-0000-4000-8000-000000000011',
        '24020000-0000-4000-8000-000000000042'),
      'splits',jsonb_build_array(jsonb_build_object(
        'supplier_id','24020000-0000-4000-8000-000000000053','allocated_quantity',30))))));
reset role;

select ok(not exists(select 1 from prb_results where name like 'allocation-%'
  and response ->> 'success' <> 'true'), 'PR-A produces the three exact balanced input families');

set local role authenticated;
select set_config('request.jwt.claim.sub','24000000-0000-4000-8000-000000000101',true);
insert into prb_results values('drafts',atlas_api.create_school_catering_purchase_order_drafts(
  pg_temp.prb_command('24050000-0000-4000-8000-000000000010',1,
    'SCHOOL_CATERING_PO_DRAFTS_CREATED',
    jsonb_build_object('date_start','2026-09-21','date_end','2026-09-22'))));
reset role;

select ok((select (response ->> 'success')::boolean from prb_results where name='drafts'),
  'bounded range draft materialization succeeds for ready dates');
select ok((select response -> 'ready_dates' @> '["2026-09-21"]'::jsonb
    and response -> 'skipped_dates' @> '[{"service_date":"2026-09-22"}]'::jsonb
  from prb_results where name='drafts'),
  'ready dates materialize while blocked dates are returned explicitly');
select is((select count(*)::integer from atlas_procurement.purchase_orders
  where purchase_order_kind='SCHOOL_CATERING' and school_catering_service_date='2026-09-22'),0,
  'a blocked date creates no incomplete PO');
select is((select count(*)::integer from atlas_procurement.purchase_orders
  where purchase_order_kind='SCHOOL_CATERING' and school_catering_service_date='2026-09-21'),3,
  'ready families group into one PO per supplier and service date');
select ok(not exists(
  select 1 from atlas_procurement.purchase_orders
  where purchase_order_kind='SCHOOL_CATERING'
    and (purchase_order_status<>'DRAFT' or document_number is not null
      or school_catering_service_date is null)
), 'school-catering roots start as internal DRAFTs without official numbers');
select ok((
  select count(*)=2 and count(distinct polr.delivery_location_id)=2
  from atlas_procurement.purchase_orders po
  join atlas_procurement.purchase_order_lines pol using(purchase_order_id)
  join atlas_procurement.purchase_order_line_revisions polr using(purchase_order_line_id)
  where po.supplier_id='24020000-0000-4000-8000-000000000051'
    and polr.purchase_order_revision_id=(select purchase_order_revision_id
      from atlas_procurement.purchase_order_revisions
      where purchase_order_id=po.purchase_order_id and is_current)
), 'one supplier/date PO retains multiple school delivery locations');
select ok(not exists(
  select 1
  from atlas_procurement.purchase_orders po
  join atlas_procurement.purchase_order_revisions por using(purchase_order_id)
  where po.purchase_order_kind='SCHOOL_CATERING' and por.is_current
    and (por.delivery_location_id is not null
      or por.delivery_location_snapshot<>'Nhiều điểm giao'
      or por.service_date<>po.school_catering_service_date
      or por.revision_status<>'DRAFT')
), 'multi-destination DRAFT headers use the server-owned summary and exact date');
select ok(not exists(
  select 1
  from atlas_procurement.purchase_orders po
  join atlas_procurement.purchase_order_revisions por using(purchase_order_id)
  join atlas_procurement.purchase_order_line_revisions polr using(purchase_order_revision_id)
  where po.purchase_order_kind='SCHOOL_CATERING' and por.is_current
    and (polr.delivery_location_id is null or polr.service_date<>po.school_catering_service_date)
), 'every school-catering PO line retains a non-null location and exact service date');
select ok(not exists(
  select 1
  from atlas_procurement.purchase_order_lines pol
  join atlas_procurement.purchase_order_line_revisions polr using(purchase_order_line_id)
  join atlas_procurement.purchase_orders po using(purchase_order_id)
  where po.purchase_order_kind='SCHOOL_CATERING'
    and (num_nonnulls(pol.fulfilment_allocation_line_id,
      pol.school_catering_allocation_family_id)<>1
      or num_nonnulls(polr.fulfilment_allocation_line_revision_id,
        polr.school_catering_allocation_supplier_split_id)<>1)
), 'stable PO lines and line revisions retain exactly one source family');

set local role authenticated;
select set_config('request.jwt.claim.sub','24000000-0000-4000-8000-000000000101',true);
insert into prb_results values('read-draft',atlas_api.get_school_catering_purchase_orders(pg_temp.prb_read()));
insert into prb_results values('allocation-successor',atlas_api.save_school_catering_supplier_allocation(
  pg_temp.prb_command('24050000-0000-4000-8000-000000000011',1,
    'SCHOOL_CATERING_SUPPLIER_ALLOCATION_SAVED',jsonb_build_object(
      'family',pg_temp.prb_family('2026-09-21','24020000-0000-4000-8000-000000000011',
        '24020000-0000-4000-8000-000000000041'),
      'splits',jsonb_build_array(
        jsonb_build_object('supplier_id','24020000-0000-4000-8000-000000000051','allocated_quantity',50),
        jsonb_build_object('supplier_id','24020000-0000-4000-8000-000000000052','allocated_quantity',50))))));
insert into prb_results values('read-stale',atlas_api.get_school_catering_purchase_orders(pg_temp.prb_read()));
insert into prb_results values('release-stale',
  atlas_api.release_school_catering_purchase_order(pg_temp.prb_release(
    '24050000-0000-4000-8000-000000000012',
    '24020000-0000-4000-8000-000000000051')));
reset role;

select ok((select (response ->> 'success')::boolean
    and jsonb_array_length(response -> 'purchase_orders')=3
    and not exists(select 1 from jsonb_array_elements(response -> 'purchase_orders') row
      where not (row ?& array['purchase_order_id','supplier','service_date','status',
        'version','current_revision','lines','stale','release_eligible','export_ready',
        'blockers','warnings','allowed_actions','disabled_reasons']))
  from prb_results where name='read-draft'),
  'PO read returns the complete backend-owned draft decision shape');
select ok((
  select count(*) filter(where (row ->> 'stale')::boolean)=2
    and count(*) filter(where not (row ->> 'stale')::boolean)=1
  from prb_results r cross join lateral jsonb_array_elements(r.response -> 'purchase_orders') row
  where r.name='read-stale'
), 'only supplier/date DRAFTs using the changed family become stale');
select is((select response ->> 'error_code' from prb_results where name='release-stale'),
  'PO_DRAFT_STALE','a stale DRAFT cannot be released');

set local role authenticated;
select set_config('request.jwt.claim.sub','24000000-0000-4000-8000-000000000101',true);
insert into prb_results values('regenerate',atlas_api.create_school_catering_purchase_order_drafts(
  pg_temp.prb_command('24050000-0000-4000-8000-000000000013',1,
    'SCHOOL_CATERING_PO_DRAFTS_CREATED',
    jsonb_build_object('date_start','2026-09-21','date_end','2026-09-21'))));
reset role;

select ok((select (response ->> 'success')::boolean
    and jsonb_array_length(response -> 'regenerated_purchase_order_ids')=2
  from prb_results where name='regenerate'),
  'regeneration creates successor DRAFT revisions only for affected POs');
select ok((
  select count(*) filter(where supplier_id in (
      '24020000-0000-4000-8000-000000000051','24020000-0000-4000-8000-000000000052')
      and version=2)=2
    and count(*) filter(where supplier_id='24020000-0000-4000-8000-000000000053'
      and version=1)=1
  from atlas_procurement.purchase_orders
  where purchase_order_kind='SCHOOL_CATERING'
), 'unrelated supplier/date PO roots remain unchanged');
select ok((
  select count(*)=4 and count(*) filter(where is_current)=2
  from atlas_procurement.purchase_order_revisions por
  join atlas_procurement.purchase_orders po using(purchase_order_id)
  where po.supplier_id in (
    '24020000-0000-4000-8000-000000000051','24020000-0000-4000-8000-000000000052')
), 'regeneration preserves both affected historical DRAFT snapshots');

set local role authenticated;
select set_config('request.jwt.claim.sub','24000000-0000-4000-8000-000000000101',true);
insert into prb_results values('release-unknown-field',
  atlas_api.release_school_catering_purchase_order(pg_temp.prb_release(
    '24050000-0000-4000-8000-000000000014',
    '24020000-0000-4000-8000-000000000051',null,false,
    jsonb_build_object('document_number','caller-must-not-author-this'))));
reset role;
select is((select response ->> 'error_code' from prb_results where name='release-unknown-field'),
  'VALIDATION_FAILED','release rejects caller-authored document numbers and unknown fields');

update atlas_admin.suppliers set supplier_status='INACTIVE'
where supplier_id='24020000-0000-4000-8000-000000000052';
set local role authenticated;
select set_config('request.jwt.claim.sub','24000000-0000-4000-8000-000000000101',true);
insert into prb_results values('release-inactive',
  atlas_api.release_school_catering_purchase_order(pg_temp.prb_release(
    '24050000-0000-4000-8000-000000000015',
    '24020000-0000-4000-8000-000000000052')));
reset role;
select is((select response ->> 'error_code' from prb_results where name='release-inactive'),
  'SUPPLIER_INACTIVE','release revalidates current supplier activity');
update atlas_admin.suppliers set supplier_status='ACTIVE'
where supplier_id='24020000-0000-4000-8000-000000000052';

set local role authenticated;
select set_config('request.jwt.claim.sub','24000000-0000-4000-8000-000000000101',true);
insert into prb_results values('release-a',
  atlas_api.release_school_catering_purchase_order(pg_temp.prb_release(
    '24050000-0000-4000-8000-000000000016',
    '24020000-0000-4000-8000-000000000051')));
insert into prb_results values('release-a-replay',
  atlas_api.release_school_catering_purchase_order(pg_temp.prb_release(
    '24050000-0000-4000-8000-000000000016',
    '24020000-0000-4000-8000-000000000051',2,true)));
insert into prb_results values('release-a-conflict',
  atlas_api.release_school_catering_purchase_order(pg_temp.prb_release(
    '24050000-0000-4000-8000-000000000016',
    '24020000-0000-4000-8000-000000000053')));
insert into prb_results values('release-a-second',
  atlas_api.release_school_catering_purchase_order(pg_temp.prb_release(
    '24050000-0000-4000-8000-000000000017',
    '24020000-0000-4000-8000-000000000051')));
reset role;

select ok((select (response ->> 'success')::boolean from prb_results where name='release-a'),
  'one current PO releases successfully');
select ok((
  select response ->> 'document_number'=format('PO-20260921-%s',
    upper(substr(replace((response ->> 'purchase_order_id'),'-',''),1,16)))
  from prb_results where name='release-a'
), 'official PO number is generated server-side from the approved deterministic format');
select ok((
  select count(*)=3 and count(*) filter(where is_current)=1
    and max(revision_number)=3
    and bool_or(is_current and revision_status='RELEASED_TO_SUPPLIER')
  from atlas_procurement.purchase_order_revisions por
  join atlas_procurement.purchase_orders po using(purchase_order_id)
  where po.supplier_id='24020000-0000-4000-8000-000000000051'
), 'release creates a successor revision and preserves both DRAFT revisions');
select ok((
  select purchase_order_status='RELEASED_TO_SUPPLIER' and version=3
    and document_number is not null
  from atlas_procurement.purchase_orders
  where supplier_id='24020000-0000-4000-8000-000000000051'
), 'release advances the root once and stores the immutable official number');
select is((select response from prb_results where name='release-a-replay'),
  (select response from prb_results where name='release-a'),
  'exact release replay returns identical IDs and official number');
select is((select response ->> 'error_code' from prb_results where name='release-a-conflict'),
  'IDEMPOTENCY_CONFLICT','same command identity with changed PO payload conflicts');
select is((select response ->> 'error_code' from prb_results where name='release-a-second'),
  'PO_ALREADY_RELEASED','a second release attempt creates no second supplier commitment');

set local role authenticated;
select set_config('request.jwt.claim.sub','24000000-0000-4000-8000-000000000101',true);
insert into prb_results values('after-release-drafts',atlas_api.create_school_catering_purchase_order_drafts(
  pg_temp.prb_command('24050000-0000-4000-8000-000000000018',1,
    'SCHOOL_CATERING_PO_DRAFTS_CREATED',
    jsonb_build_object('date_start','2026-09-21','date_end','2026-09-21'))));
reset role;
select is((
  select count(*)::integer from atlas_procurement.purchase_order_revisions por
  join atlas_procurement.purchase_orders po using(purchase_order_id)
  where po.supplier_id='24020000-0000-4000-8000-000000000051'
),3,'draft materialization never regenerates a released PO');

select ok((
  select count(*)=2
    and bool_and(polr.predecessor_revision_id is not null)
    and bool_and(polr.school_catering_allocation_supplier_split_id is not null)
  from atlas_procurement.purchase_order_line_revisions polr
  join atlas_procurement.purchase_order_revisions por using(purchase_order_revision_id)
  join atlas_procurement.purchase_orders po using(purchase_order_id)
  where po.supplier_id='24020000-0000-4000-8000-000000000051'
    and por.is_current and por.revision_status='RELEASED_TO_SUPPLIER'
), 'released successor lines preserve exact immutable source and predecessor references');

set local role authenticated;
select set_config('request.jwt.claim.sub','24000000-0000-4000-8000-000000000101',true);
insert into prb_results values('read-released',
  atlas_api.get_school_catering_purchase_orders(pg_temp.prb_read()));
reset role;
select ok((
  select count(*)=1
  from prb_results r cross join lateral
    jsonb_array_elements(r.response -> 'purchase_orders') row
  where r.name='read-released'
    and row #>> '{supplier,supplier_id}'='24020000-0000-4000-8000-000000000051'
    and (row ->> 'export_ready')::boolean
    and not (row ->> 'release_eligible')::boolean
    and row ->> 'document_number' is not null
), 'read model exposes only a released PO as export-ready with its official number');

select ok((
  select count(*)=1 from atlas_audit.domain_events
  where event_type='SchoolCateringPurchaseOrderReleased'
) and (
  select count(*)=1 from atlas_audit.audit_events
  where event_type='SchoolCateringPurchaseOrderReleased'
) and (
  select count(*)=1 from atlas_core.command_receipts
  where command_name='release_school_catering_purchase_order' and outcome='COMPLETED'
), 'one release creates exactly one receipt, domain event, and audit event');

insert into atlas_procurement.purchase_orders(supplier_id,purchase_order_status)
values('24020000-0000-4000-8000-000000000053','DRAFT');
select ok((
  select purchase_order_kind='SUPPLIER_DIRECT_WHOLESALE'
    and school_catering_service_date is null
  from atlas_procurement.purchase_orders
  where supplier_id='24020000-0000-4000-8000-000000000053'
    and purchase_order_kind='SUPPLIER_DIRECT_WHOLESALE'
  order by created_at desc limit 1
), 'legacy wholesale root inserts retain their default shape');

select ok((
  select pg_get_functiondef('atlas_api.release_school_catering_purchase_order(jsonb)'::regprocedure)
    ~* 'pg_advisory_xact_lock'
) and (
  select pg_get_functiondef('atlas_api.release_school_catering_purchase_order(jsonb)'::regprocedure)
    ~* 'order by[^;]+for (key )?share'
), 'release combines a uniqueness guard with deterministic ordered source locks');

select * from finish();
rollback;
