begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
set search_path = extensions, public, pg_catalog;

select plan(88);

select has_table('atlas_procurement', 'school_catering_allocation_families', 'Allocation Family roots exist');
select has_table('atlas_procurement', 'school_catering_allocation_family_revisions', 'Allocation Family revisions exist');
select has_table('atlas_procurement', 'school_catering_allocation_family_contributions', 'Allocation Family contributions exist');
select has_table('atlas_procurement', 'school_catering_allocation_supplier_splits', 'Allocation Family supplier splits exist');

select has_function('atlas_api', 'release_school_catering_purchase_handoff', array['jsonb']);
select has_function('atlas_api', 'save_school_catering_supplier_allocation', array['jsonb']);
select has_function('atlas_api', 'confirm_school_catering_supplier_recommendations', array['jsonb']);
select has_function('atlas_api', 'get_school_catering_procurement_workbench', array['jsonb']);

select ok(exists (
  select 1 from atlas_core.capabilities
  where capability_code = 'procurement.school_catering.read'
    and owning_domain = 'PROCUREMENT' and capability_status = 'ACTIVE'
), 'school-catering Procurement read capability is explicit');
select ok(exists (
  select 1 from atlas_core.capabilities
  where capability_code = 'procurement.school_catering.write'
    and owning_domain = 'PROCUREMENT' and capability_status = 'ACTIVE'
), 'school-catering Procurement write capability is explicit');

select has_column('atlas_planning', 'purchase_demand_references', 'source_kind', 'Purchase Demand Reference is source-qualified');
select ok(exists (
  select 1 from information_schema.columns
  where table_schema='atlas_planning' and table_name='purchase_demand_references'
    and column_name='wholesale_order_line_revision_id' and is_nullable='YES'
), 'wholesale source is nullable for source-qualified demand references');
select has_check('atlas_planning', 'purchase_demand_references', 'purchase_demand_references_source_kind_check');
select has_check('atlas_planning', 'purchase_demand_references', 'purchase_demand_references_source_shape_check');

select ok(exists (
  select 1 from pg_indexes where schemaname='atlas_procurement'
    and tablename='school_catering_allocation_families'
    and indexdef ilike '%unique%service_date%delivery_location_id%ingredient_id%unit_id%'
), 'Allocation Family key is unique');
select ok(exists (
  select 1 from pg_indexes
  where schemaname = 'atlas_procurement'
    and tablename = 'school_catering_allocation_family_revisions'
    and indexdef ilike '%unique%where (is_current = true)%'
), 'only one current revision is permitted per Allocation Family');
select ok(exists (
  select 1 from pg_indexes where schemaname='atlas_procurement'
    and tablename='school_catering_allocation_family_contributions'
    and indexdef ilike '%unique%family_revision_id%purchase_handoff_line_revision_id%'
), 'contribution lineage is unique within a family revision');
select ok(exists (
  select 1 from pg_indexes where schemaname='atlas_procurement'
    and tablename='school_catering_allocation_supplier_splits'
    and indexdef ilike '%unique%family_revision_id%supplier_id%'
), 'supplier is unique within a family revision');

select has_check('atlas_procurement', 'school_catering_allocation_family_revisions',
  'school_catering_allocation_family_revisions_quantity_check');
select has_check('atlas_procurement', 'school_catering_allocation_family_contributions',
  'school_catering_allocation_family_contributions_quantity_check');
select has_check('atlas_procurement', 'school_catering_allocation_supplier_splits',
  'school_catering_allocation_supplier_splits_quantity_check');
select has_check('atlas_procurement', 'school_catering_allocation_supplier_splits',
  'school_catering_allocation_supplier_splits_ratio_check');

select ok((select relrowsecurity and relforcerowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='atlas_procurement' and c.relname='school_catering_allocation_families'), 'family roots use forced RLS');
select ok((select relrowsecurity and relforcerowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='atlas_procurement' and c.relname='school_catering_allocation_family_revisions'), 'family revisions use forced RLS');
select ok((select relrowsecurity and relforcerowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='atlas_procurement' and c.relname='school_catering_allocation_family_contributions'), 'family contributions use forced RLS');
select ok((select relrowsecurity and relforcerowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='atlas_procurement' and c.relname='school_catering_allocation_supplier_splits'), 'supplier splits use forced RLS');

select function_owner_is('atlas_api', 'release_school_catering_purchase_handoff', array['jsonb'], 'atlas_planning_command_runtime');
select function_owner_is('atlas_api', 'save_school_catering_supplier_allocation', array['jsonb'], 'atlas_procurement_command_runtime');
select function_owner_is('atlas_api', 'confirm_school_catering_supplier_recommendations', array['jsonb'], 'atlas_procurement_command_runtime');
select function_owner_is('atlas_api', 'get_school_catering_procurement_workbench', array['jsonb'], 'atlas_read_runtime');

select ok((
  with helper as (
    select regexp_replace(lower(pg_get_functiondef(
      'atlas_core.school_catering_lock_supplier_evidence(date,uuid,jsonb,boolean)'::regprocedure
    )), '\s+', ' ', 'g') as body
  )
  select position('from atlas_admin.ingredients ingredient' in body) > 0
    and position('from atlas_admin.ingredients ingredient' in body)
      < position('from atlas_admin.suppliers supplier' in body)
    and position('for key share' in substring(
      body from position('from atlas_admin.ingredients ingredient' in body)
      for position('from atlas_admin.suppliers supplier' in body)
        - position('from atlas_admin.ingredients ingredient' in body)
    )) > 0
  from helper
), 'supplier evidence locks the Ingredient aggregate guard before Supplier evidence');
select ok((
  with helper as (
    select regexp_replace(lower(pg_get_functiondef(
      'atlas_core.school_catering_lock_supplier_evidence(date,uuid,jsonb,boolean)'::regprocedure
    )), '\s+', ' ', 'g') as body
  )
  select body ~ 'order by eligibility\.supplier_id,\s*eligibility\.supplier_eligibility_id for share;'
    and body !~ 'order by eligibility\.supplier_id,\s*eligibility\.supplier_eligibility_id for key share;'
  from helper
), 'current supplier eligibility evidence uses FOR SHARE against non-key updates');

select function_privs_are('atlas_api', 'release_school_catering_purchase_handoff', array['jsonb'], 'authenticated', array['EXECUTE']);
select function_privs_are('atlas_api', 'save_school_catering_supplier_allocation', array['jsonb'], 'authenticated', array['EXECUTE']);
select function_privs_are('atlas_api', 'confirm_school_catering_supplier_recommendations', array['jsonb'], 'authenticated', array['EXECUTE']);
select function_privs_are('atlas_api', 'get_school_catering_procurement_workbench', array['jsonb'], 'authenticated', array['EXECUTE']);

select function_privs_are('atlas_api', 'release_school_catering_purchase_handoff', array['jsonb'], 'anon', array[]::text[]);
select function_privs_are('atlas_api', 'save_school_catering_supplier_allocation', array['jsonb'], 'anon', array[]::text[]);
select function_privs_are('atlas_api', 'confirm_school_catering_supplier_recommendations', array['jsonb'], 'anon', array[]::text[]);
select function_privs_are('atlas_api', 'get_school_catering_procurement_workbench', array['jsonb'], 'anon', array[]::text[]);

select function_privs_are('atlas_api', 'release_school_catering_purchase_handoff', array['jsonb'], 'service_role', array[]::text[]);
select function_privs_are('atlas_api', 'save_school_catering_supplier_allocation', array['jsonb'], 'service_role', array[]::text[]);
select function_privs_are('atlas_api', 'confirm_school_catering_supplier_recommendations', array['jsonb'], 'service_role', array[]::text[]);
select function_privs_are('atlas_api', 'get_school_catering_procurement_workbench', array['jsonb'], 'service_role', array[]::text[]);

select table_privs_are('atlas_procurement', 'school_catering_allocation_families', 'authenticated', array[]::text[]);
select table_privs_are('atlas_procurement', 'school_catering_allocation_family_revisions', 'authenticated', array[]::text[]);
select table_privs_are('atlas_procurement', 'school_catering_allocation_family_contributions', 'authenticated', array[]::text[]);
select table_privs_are('atlas_procurement', 'school_catering_allocation_supplier_splits', 'authenticated', array[]::text[]);

select ok(to_regclass('atlas_procurement.fulfilment_allocations') is not null,
  'PA-05E wholesale fulfilment allocation remains present');
select ok(to_regprocedure('atlas_api.allocate_supplier_direct_fulfilment(jsonb)') is not null,
  'PA-05E wholesale allocation command remains present');

-- Focused behavioral proof for exact-head currentness, relational scope, and
-- server-authoritative Procurement workbench decisions.
insert into atlas_core.actors(actor_id,actor_type,display_name) values
  ('23800000-0000-4000-8000-000000000001','HUMAN','PR-A global operator'),
  ('23800000-0000-4000-8000-000000000002','HUMAN','PR-A location operator'),
  ('23800000-0000-4000-8000-000000000003','HUMAN','PR-A school operator'),
  ('23800000-0000-4000-8000-000000000004','HUMAN','PR-A customer operator');
insert into atlas_core.actor_auth_subjects(actor_id,auth_subject_id) values
  ('23800000-0000-4000-8000-000000000001','23800000-0000-4000-8000-000000000101'),
  ('23800000-0000-4000-8000-000000000002','23800000-0000-4000-8000-000000000102'),
  ('23800000-0000-4000-8000-000000000003','23800000-0000-4000-8000-000000000103'),
  ('23800000-0000-4000-8000-000000000004','23800000-0000-4000-8000-000000000104');
insert into atlas_core.roles(role_id,role_code,role_name)
values('23810000-0000-4000-8000-000000000001','pr_a_procurement_operator','PR-A Procurement operator');
insert into atlas_core.role_capabilities(role_id,capability_id)
select '23810000-0000-4000-8000-000000000001',capability_id
from atlas_core.capabilities where capability_code in (
  'confirmed_need_release.release','procurement.school_catering.read',
  'procurement.school_catering.write');
insert into atlas_core.actor_role_memberships(actor_id,role_id) values
  ('23800000-0000-4000-8000-000000000001','23810000-0000-4000-8000-000000000001'),
  ('23800000-0000-4000-8000-000000000002','23810000-0000-4000-8000-000000000001'),
  ('23800000-0000-4000-8000-000000000003','23810000-0000-4000-8000-000000000001'),
  ('23800000-0000-4000-8000-000000000004','23810000-0000-4000-8000-000000000001');

insert into atlas_admin.customers(customer_id,customer_code,customer_name,customer_type)
values('23820000-0000-4000-8000-000000000001','pr-a-school-customer','PR-A School Customer','SCHOOL_CATERING');
insert into atlas_admin.delivery_locations(
  delivery_location_id,customer_id,location_code,location_name,address_text)
values
  ('23820000-0000-4000-8000-000000000011','23820000-0000-4000-8000-000000000001',
   'pr-a-location-a','PR-A Location Alpha','Alpha address'),
  ('23820000-0000-4000-8000-000000000012','23820000-0000-4000-8000-000000000001',
   'pr-a-location-b','PR-A Location Beta','Beta address');
insert into atlas_admin.schools(
  school_id,customer_id,school_code,school_name,default_delivery_location_id,display_order)
values
  ('23820000-0000-4000-8000-000000000021','23820000-0000-4000-8000-000000000001',
   'pr-a-school-a','PR-A School Alpha','23820000-0000-4000-8000-000000000011',1),
  ('23820000-0000-4000-8000-000000000022','23820000-0000-4000-8000-000000000001',
   'pr-a-school-b','PR-A School Beta','23820000-0000-4000-8000-000000000012',2);
insert into atlas_admin.units(unit_id,unit_code,unit_name,dimension_code)
values('23820000-0000-4000-8000-000000000031','pr-a-kg','PR-A kilogram','mass');
insert into atlas_admin.ingredients(ingredient_id,ingredient_code,ingredient_name,purchase_unit_id) values
  ('23820000-0000-4000-8000-000000000041','pr-a-rice','PR-A Rice','23820000-0000-4000-8000-000000000031'),
  ('23820000-0000-4000-8000-000000000042','pr-a-beans','PR-A Beans','23820000-0000-4000-8000-000000000031'),
  ('23820000-0000-4000-8000-000000000043','pr-a-oil','PR-A Oil','23820000-0000-4000-8000-000000000031');
insert into atlas_admin.suppliers(supplier_id,supplier_code,supplier_name,supplier_status) values
  ('23820000-0000-4000-8000-000000000051','pr-a-supplier-a','Golden Supplier Alpha','ACTIVE'),
  ('23820000-0000-4000-8000-000000000052','pr-a-supplier-b','Silver Supplier Beta','ACTIVE'),
  ('23820000-0000-4000-8000-000000000053','pr-a-supplier-c','Inactive Supplier Gamma','INACTIVE'),
  ('23820000-0000-4000-8000-000000000054','pr-a-supplier-d','Ineligible Supplier Delta','ACTIVE');
-- The production catalog prevents new active priority ties. Drop the index only
-- inside this rolled-back test transaction to prove the command/read defensive
-- behavior against legacy or otherwise contradictory current evidence.
drop index atlas_admin.supplier_eligibilities_active_priority_key;
insert into atlas_admin.supplier_eligibilities(
  supplier_id,ingredient_id,effective_from,priority,reason_note)
values
  ('23820000-0000-4000-8000-000000000051','23820000-0000-4000-8000-000000000041','2026-01-01',1,'PR-A test'),
  ('23820000-0000-4000-8000-000000000052','23820000-0000-4000-8000-000000000041','2026-01-01',2,'PR-A test'),
  ('23820000-0000-4000-8000-000000000051','23820000-0000-4000-8000-000000000042','2026-01-01',1,'PR-A test'),
  ('23820000-0000-4000-8000-000000000052','23820000-0000-4000-8000-000000000042','2026-01-01',1,'PR-A test');

insert into atlas_core.actor_scopes(actor_id,scope_kind)
values('23800000-0000-4000-8000-000000000001','GLOBAL');
insert into atlas_core.actor_scopes(actor_id,scope_kind,delivery_location_id)
values('23800000-0000-4000-8000-000000000002','DELIVERY_LOCATION',
  '23820000-0000-4000-8000-000000000011');
insert into atlas_core.actor_scopes(actor_id,scope_kind,school_id)
values('23800000-0000-4000-8000-000000000003','SCHOOL',
  '23820000-0000-4000-8000-000000000021');
insert into atlas_core.actor_scopes(actor_id,scope_kind,customer_id)
values('23800000-0000-4000-8000-000000000004','CUSTOMER',
  '23820000-0000-4000-8000-000000000001');

set session_replication_role = replica;
insert into atlas_planning.purchase_handoff_batches(
  purchase_handoff_batch_id,confirmed_need_batch_id,period_start,period_end,
  handoff_status,created_by_actor_id)
values('23830000-0000-4000-8000-000000000061','23830000-0000-4000-8000-000000000060',
  '2026-09-10','2026-09-10','RELEASED_TO_PROCUREMENT','23800000-0000-4000-8000-000000000001');
insert into atlas_planning.purchase_handoff_revisions(
  purchase_handoff_revision_id,purchase_handoff_batch_id,revision_number,
  revision_status,is_current,released_by_actor_id,released_at)
values('23830000-0000-4000-8000-000000000062','23830000-0000-4000-8000-000000000061',
  1,'RELEASED_TO_PROCUREMENT',true,'23800000-0000-4000-8000-000000000001',transaction_timestamp());
insert into atlas_planning.purchase_handoff_lines(
  purchase_handoff_line_id,purchase_handoff_batch_id,confirmed_need_line_id)
values
  ('23830000-0000-4000-8000-000000000071','23830000-0000-4000-8000-000000000061','23830000-0000-4000-8000-000000000171'),
  ('23830000-0000-4000-8000-000000000072','23830000-0000-4000-8000-000000000061','23830000-0000-4000-8000-000000000172'),
  ('23830000-0000-4000-8000-000000000073','23830000-0000-4000-8000-000000000061','23830000-0000-4000-8000-000000000173'),
  ('23830000-0000-4000-8000-000000000074','23830000-0000-4000-8000-000000000061','23830000-0000-4000-8000-000000000174');
insert into atlas_planning.purchase_handoff_line_revisions(
  purchase_handoff_line_revision_id,purchase_handoff_revision_id,purchase_handoff_line_id,
  confirmed_need_line_revision_id,ingredient_id,handoff_quantity,unit_id,service_date,
  delivery_location_id,command_id)
values
  ('23830000-0000-4000-8000-000000000081','23830000-0000-4000-8000-000000000062',
   '23830000-0000-4000-8000-000000000071','23830000-0000-4000-8000-000000000181',
   '23820000-0000-4000-8000-000000000041',100,'23820000-0000-4000-8000-000000000031',
   '2026-09-10','23820000-0000-4000-8000-000000000011','23830000-0000-4000-8000-000000000161'),
  ('23830000-0000-4000-8000-000000000082','23830000-0000-4000-8000-000000000062',
   '23830000-0000-4000-8000-000000000072','23830000-0000-4000-8000-000000000182',
   '23820000-0000-4000-8000-000000000041',50,'23820000-0000-4000-8000-000000000031',
   '2026-09-10','23820000-0000-4000-8000-000000000012','23830000-0000-4000-8000-000000000162'),
  ('23830000-0000-4000-8000-000000000083','23830000-0000-4000-8000-000000000062',
   '23830000-0000-4000-8000-000000000073','23830000-0000-4000-8000-000000000183',
   '23820000-0000-4000-8000-000000000042',30,'23820000-0000-4000-8000-000000000031',
   '2026-09-10','23820000-0000-4000-8000-000000000011','23830000-0000-4000-8000-000000000163'),
  ('23830000-0000-4000-8000-000000000084','23830000-0000-4000-8000-000000000062',
   '23830000-0000-4000-8000-000000000074','23830000-0000-4000-8000-000000000184',
   '23820000-0000-4000-8000-000000000043',20,'23820000-0000-4000-8000-000000000031',
   '2026-09-10','23820000-0000-4000-8000-000000000011','23830000-0000-4000-8000-000000000164');
insert into atlas_planning.purchase_demand_references(
  purchase_demand_reference_id,purchase_handoff_line_revision_id,
  confirmed_need_snapshot_line_id,approved_quantity,unit_id,source_kind)
values
  ('23830000-0000-4000-8000-000000000091','23830000-0000-4000-8000-000000000081','23830000-0000-4000-8000-000000000191',100,'23820000-0000-4000-8000-000000000031','NEED_GENERATION'),
  ('23830000-0000-4000-8000-000000000092','23830000-0000-4000-8000-000000000082','23830000-0000-4000-8000-000000000192',50,'23820000-0000-4000-8000-000000000031','NEED_GENERATION'),
  ('23830000-0000-4000-8000-000000000093','23830000-0000-4000-8000-000000000083','23830000-0000-4000-8000-000000000193',30,'23820000-0000-4000-8000-000000000031','NEED_GENERATION'),
  ('23830000-0000-4000-8000-000000000094','23830000-0000-4000-8000-000000000084','23830000-0000-4000-8000-000000000194',20,'23820000-0000-4000-8000-000000000031','NEED_GENERATION');

-- Saved source fixtures for real release + Handoff complete-set scope.
insert into atlas_planning.confirmed_need_batches(
  confirmed_need_batch_id,period_start,period_end,batch_status,version,created_by_actor_id,
  source_kind,origin_need_generation_run_id,origin_need_generation_run_version,
  origin_need_generation_release_snapshot_id,current_need_generation_run_id,
  current_need_generation_run_version,current_need_generation_release_snapshot_id,
  current_confirmed_need_approval_snapshot_id,current_confirmed_need_release_id)
values
  ('23840000-0000-4000-8000-000000000101','2026-09-11','2026-09-11',
   'DRAFT_REVIEW',4,'23800000-0000-4000-8000-000000000001','NEED_GENERATION',
   '23840000-0000-4000-8000-000000000181',1,'23840000-0000-4000-8000-000000000191',
   '23840000-0000-4000-8000-000000000181',1,'23840000-0000-4000-8000-000000000191',
   null,null),
  ('23840000-0000-4000-8000-000000000102','2026-09-12','2026-09-12',
   'DRAFT_REVIEW',4,'23800000-0000-4000-8000-000000000001','NEED_GENERATION',
   '23840000-0000-4000-8000-000000000182',1,'23840000-0000-4000-8000-000000000192',
   '23840000-0000-4000-8000-000000000182',1,'23840000-0000-4000-8000-000000000192',
   null,null);
insert into atlas_planning.confirmed_need_lines(
  confirmed_need_line_id,confirmed_need_batch_id,source_kind,service_date,customer_id,
  school_id,delivery_location_id,ingredient_id,controlled_unit_id)
values
  ('23840000-0000-4000-8000-000000000131','23840000-0000-4000-8000-000000000101','NEED_GENERATION','2026-09-11','23820000-0000-4000-8000-000000000001','23820000-0000-4000-8000-000000000021','23820000-0000-4000-8000-000000000011','23820000-0000-4000-8000-000000000041','23820000-0000-4000-8000-000000000031'),
  ('23840000-0000-4000-8000-000000000132','23840000-0000-4000-8000-000000000102','NEED_GENERATION','2026-09-12','23820000-0000-4000-8000-000000000001','23820000-0000-4000-8000-000000000021','23820000-0000-4000-8000-000000000011','23820000-0000-4000-8000-000000000041','23820000-0000-4000-8000-000000000031'),
  ('23840000-0000-4000-8000-000000000133','23840000-0000-4000-8000-000000000102','NEED_GENERATION','2026-09-12','23820000-0000-4000-8000-000000000001','23820000-0000-4000-8000-000000000022','23820000-0000-4000-8000-000000000012','23820000-0000-4000-8000-000000000041','23820000-0000-4000-8000-000000000031');
insert into atlas_planning.confirmed_need_line_revisions(
  confirmed_need_line_revision_id,confirmed_need_line_id,revision_number,ingredient_id,
  theoretical_quantity,confirmed_quantity,unit_id,revision_status,is_current,
  created_by_actor_id,source_kind,confirmed_need_batch_id,service_date,customer_id,
  school_id,delivery_location_id,need_generation_run_id,need_generation_run_version,
  need_generation_release_snapshot_id)
values
  ('23840000-0000-4000-8000-000000000141','23840000-0000-4000-8000-000000000131',1,'23820000-0000-4000-8000-000000000041',10,10,'23820000-0000-4000-8000-000000000031','DRAFT',true,'23800000-0000-4000-8000-000000000001','NEED_GENERATION','23840000-0000-4000-8000-000000000101','2026-09-11','23820000-0000-4000-8000-000000000001','23820000-0000-4000-8000-000000000021','23820000-0000-4000-8000-000000000011','23840000-0000-4000-8000-000000000181',1,'23840000-0000-4000-8000-000000000191'),
  ('23840000-0000-4000-8000-000000000142','23840000-0000-4000-8000-000000000132',1,'23820000-0000-4000-8000-000000000041',10,10,'23820000-0000-4000-8000-000000000031','DRAFT',true,'23800000-0000-4000-8000-000000000001','NEED_GENERATION','23840000-0000-4000-8000-000000000102','2026-09-12','23820000-0000-4000-8000-000000000001','23820000-0000-4000-8000-000000000021','23820000-0000-4000-8000-000000000011','23840000-0000-4000-8000-000000000182',1,'23840000-0000-4000-8000-000000000192'),
  ('23840000-0000-4000-8000-000000000143','23840000-0000-4000-8000-000000000133',1,'23820000-0000-4000-8000-000000000041',15,15,'23820000-0000-4000-8000-000000000031','DRAFT',true,'23800000-0000-4000-8000-000000000001','NEED_GENERATION','23840000-0000-4000-8000-000000000102','2026-09-12','23820000-0000-4000-8000-000000000001','23820000-0000-4000-8000-000000000022','23820000-0000-4000-8000-000000000012','23840000-0000-4000-8000-000000000182',1,'23840000-0000-4000-8000-000000000192');

-- Retained upstream source seeding only. Operational commands below run with
-- ordinary triggers, policy checks, RLS and exact current-decision evidence.
do $fixture$
declare b record;r record;input_id uuid;theory_id uuid;member_id uuid;decision_id uuid;
  policy_id uuid:=gen_random_uuid();policy_revision_id uuid:=gen_random_uuid();
  actor_id uuid:='23800000-0000-4000-8000-000000000001';
begin
  insert into atlas_planning.planning_quantity_policies(planning_quantity_policy_id,unit_id,created_by_actor_id)
    values(policy_id,'23820000-0000-4000-8000-000000000031',actor_id);
  insert into atlas_planning.planning_quantity_policy_revisions(planning_quantity_policy_revision_id,
    planning_quantity_policy_id,unit_id,revision_number,planning_step,effective_from,policy_revision_status,
    created_by_actor_id,approved_by_actor_id,approved_at,activated_by_actor_id,activated_at)
    values(policy_revision_id,policy_id,'23820000-0000-4000-8000-000000000031',1,1,'2026-01-01','ACTIVE',
      actor_id,actor_id,transaction_timestamp(),actor_id,transaction_timestamp());
  for b in select * from atlas_planning.confirmed_need_batches
    where confirmed_need_batch_id in ('23840000-0000-4000-8000-000000000101','23840000-0000-4000-8000-000000000102') loop
    input_id:=gen_random_uuid();
    insert into atlas_planning.need_generation_runs(need_generation_run_id,planning_input_set_id,planning_input_evaluation_id,
      evaluation_version,period_start,period_end,attempt_ordinal,input_snapshot_id,run_status,version,generated_line_count,
      blocking_issue_count,warning_count,generated_by_actor_id,generated_at,validated_by_actor_id,validated_at,
      released_by_actor_id,released_at,updated_at)
      values(b.current_need_generation_run_id,gen_random_uuid(),gen_random_uuid(),1,b.period_start,b.period_end,1,
        input_id,'RELEASED_FOR_CONFIRMATION',1,(select count(*) from atlas_planning.confirmed_need_lines
          where confirmed_need_batch_id=b.confirmed_need_batch_id),0,0,actor_id,transaction_timestamp(),actor_id,
        transaction_timestamp(),actor_id,transaction_timestamp(),transaction_timestamp());
    insert into atlas_planning.need_generation_release_snapshots(need_generation_release_snapshot_id,need_generation_run_id,
      released_run_version,need_generation_input_snapshot_id,released_by_actor_id,released_at,generated_line_count,
      active_line_count,removed_line_count,blocking_issue_count,warning_count)
      select b.current_need_generation_release_snapshot_id,b.current_need_generation_run_id,1,input_id,actor_id,
        transaction_timestamp(),count(*),count(*),0,0,0 from atlas_planning.confirmed_need_lines
        where confirmed_need_batch_id=b.confirmed_need_batch_id;
    for r in select * from atlas_planning.confirmed_need_line_revisions where confirmed_need_batch_id=b.confirmed_need_batch_id loop
      theory_id:=gen_random_uuid();member_id:=gen_random_uuid();decision_id:=gen_random_uuid();
      insert into atlas_planning.theoretical_need_lines(theoretical_need_line_id,need_generation_run_id,need_generation_input_snapshot_id,
        school_id,service_date,ingredient_id,unit_id,line_disposition,theoretical_quantity,contribution_family,
        delivery_location_id,pantry_need_batch_id,pantry_need_batch_version,pantry_need_approval_snapshot_id,
        pantry_need_line_id,pantry_active_snapshot_member_line_id,created_at)
        values(theory_id,b.current_need_generation_run_id,input_id,r.school_id,r.service_date,r.ingredient_id,r.unit_id,
          'ACTIVE',r.theoretical_quantity,'PANTRY_DIRECT',r.delivery_location_id,gen_random_uuid(),1,gen_random_uuid(),
          theory_id,theory_id,transaction_timestamp());
      insert into atlas_planning.need_generation_release_snapshot_lines(need_generation_release_snapshot_line_id,
        need_generation_release_snapshot_id,need_generation_run_id,released_run_version,theoretical_need_line_id)
        values(member_id,b.current_need_generation_release_snapshot_id,b.current_need_generation_run_id,1,theory_id);
      insert into atlas_planning.confirmed_need_line_revision_contributions(confirmed_need_batch_id,confirmed_need_line_id,
        confirmed_need_line_revision_id,need_generation_run_id,need_generation_run_version,need_generation_release_snapshot_id,
        need_generation_release_snapshot_line_id,theoretical_need_line_id,service_date,customer_id,school_id,
        delivery_location_id,ingredient_id,source_unit_id,controlled_unit_id,source_theoretical_quantity,controlled_contribution_quantity)
        values(b.confirmed_need_batch_id,r.confirmed_need_line_id,r.confirmed_need_line_revision_id,b.current_need_generation_run_id,1,
          b.current_need_generation_release_snapshot_id,member_id,theory_id,r.service_date,r.customer_id,r.school_id,r.delivery_location_id,
          r.ingredient_id,r.unit_id,r.unit_id,r.theoretical_quantity,r.theoretical_quantity);
      insert into atlas_planning.confirmed_need_line_decisions(confirmed_need_line_decision_id,confirmed_need_batch_id,
        confirmed_need_line_id,confirmed_need_line_revision_id,source_kind,service_date,customer_id,school_id,delivery_location_id,
        ingredient_id,unit_id,decision_number,decision_kind,planning_quantity_policy_id,planning_quantity_policy_revision_id,
        theoretical_quantity_before,proposed_quantity_before,confirmed_quantity_after,planning_tick_count,reason_code,
        decided_by_actor_id,decided_at,command_id,confirmed_need_batch_version)
        values(decision_id,b.confirmed_need_batch_id,r.confirmed_need_line_id,r.confirmed_need_line_revision_id,'NEED_GENERATION',
          r.service_date,r.customer_id,r.school_id,r.delivery_location_id,r.ingredient_id,r.unit_id,1,'UNCHANGED_PROPOSAL_ACCEPTED',
          policy_id,policy_revision_id,r.theoretical_quantity,r.theoretical_quantity,r.confirmed_quantity,r.confirmed_quantity,
          'PROPOSAL_ACCEPTED',actor_id,transaction_timestamp(),gen_random_uuid(),4);
      update atlas_planning.confirmed_need_lines set current_confirmed_need_line_decision_id=decision_id
        where confirmed_need_line_id=r.confirmed_need_line_id;
    end loop;
  end loop;
end;
$fixture$;
set session_replication_role = origin;

create temporary table sc_results(name text primary key,response jsonb not null);
grant select,insert on sc_results to authenticated;
create function pg_temp.sc_read(p_subject uuid,p_search text default null)
returns jsonb language sql stable set search_path='' as $$
  select jsonb_build_object('contract_version','SCHOOL-CATERING-PROCUREMENT.v1',
    'requested_by_auth_subject',p_subject,'correlation_id',gen_random_uuid(),
    'payload',jsonb_build_object('date_start','2026-09-10','date_end','2026-09-10',
      'school_ids','[]'::jsonb,'states','[]'::jsonb,'search',p_search));
$$;
create function pg_temp.sc_command(
  p_subject uuid,p_contract text,p_command uuid,p_expected bigint,p_reason text,p_payload jsonb)
returns jsonb language sql stable set search_path='' as $$
  select jsonb_build_object('contract_version',p_contract,'command_id',p_command,
    'correlation_id',gen_random_uuid(),'idempotency_key','pr-a:' || p_command::text,
    'expected_version',p_expected,'requested_by_auth_subject',p_subject,
    'requested_at',transaction_timestamp()-interval '1 second','reason_code',p_reason,
    'reason_note',null,'payload',p_payload);
$$;
create function pg_temp.sc_family(p_location uuid,p_ingredient uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object('service_date','2026-09-10','delivery_location_id',p_location,
    'ingredient_id',p_ingredient,'unit_id','23820000-0000-4000-8000-000000000031'::uuid,
    'expected_source_fingerprint',projection ->> 'source_fingerprint')
  from (select atlas_core.school_catering_family_projection(
    '2026-09-10',p_location,p_ingredient,'23820000-0000-4000-8000-000000000031') projection) source;
$$;
create function pg_temp.sc_candidate(p_location uuid,p_ingredient uuid)
returns jsonb language sql stable set search_path='' as $$
  select pg_temp.sc_family(p_location,p_ingredient) ||
    jsonb_build_object('expected_family_version',0);
$$;
grant execute on function pg_temp.sc_read(uuid,text),
  pg_temp.sc_command(uuid,text,uuid,bigint,text,jsonb),
  pg_temp.sc_family(uuid,uuid),pg_temp.sc_candidate(uuid,uuid) to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.sub','23800000-0000-4000-8000-000000000101',true);
insert into sc_results values('global_read',atlas_api.get_school_catering_procurement_workbench(
  pg_temp.sc_read('23800000-0000-4000-8000-000000000101',null)));
insert into sc_results values('supplier_search',atlas_api.get_school_catering_procurement_workbench(
  pg_temp.sc_read('23800000-0000-4000-8000-000000000101','Golden Supplier Alpha')));
select set_config('request.jwt.claim.sub','23800000-0000-4000-8000-000000000102',true);
insert into sc_results values('location_read',atlas_api.get_school_catering_procurement_workbench(
  pg_temp.sc_read('23800000-0000-4000-8000-000000000102',null)));
select set_config('request.jwt.claim.sub','23800000-0000-4000-8000-000000000103',true);
insert into sc_results values('school_read',atlas_api.get_school_catering_procurement_workbench(
  pg_temp.sc_read('23800000-0000-4000-8000-000000000103',null)));
select set_config('request.jwt.claim.sub','23800000-0000-4000-8000-000000000104',true);
insert into sc_results values('customer_read',atlas_api.get_school_catering_procurement_workbench(
  pg_temp.sc_read('23800000-0000-4000-8000-000000000104',null)));
reset role;

select is(jsonb_array_length((select response -> 'rows' from sc_results where name='global_read')),4,
  'GLOBAL reader sees every eligible school-catering family in the bounded date');
select ok((select (response ->> 'success')::boolean and jsonb_array_length(response -> 'rows')=3
  from sc_results where name='location_read'),
  'DELIVERY_LOCATION reader can use the workbench for its three authorized families');
select ok(not exists(select 1 from sc_results r cross join lateral jsonb_array_elements(r.response -> 'rows') row
  where r.name='location_read' and row ->> 'delivery_location_id' <> '23820000-0000-4000-8000-000000000011'),
  'DELIVERY_LOCATION reader receives no family outside its active scope');
select is(jsonb_array_length((select response -> 'rows' from sc_results where name='school_read')),3,
  'SCHOOL scope resolves relationally to only its default delivery location');
select is(jsonb_array_length((select response -> 'rows' from sc_results where name='customer_read')),4,
  'CUSTOMER scope resolves relationally to all contained school delivery locations');
select ok((select row -> 'recommendation' = 'null'::jsonb from sc_results r
  cross join lateral jsonb_array_elements(r.response -> 'rows') row
  where r.name='global_read' and row ->> 'ingredient_id'='23820000-0000-4000-8000-000000000043'),
  'zero eligible suppliers returns no recommendation');
select is((select row #>> '{allowed_actions,confirm_recommendation}' from sc_results r
  cross join lateral jsonb_array_elements(r.response -> 'rows') row
  where r.name='global_read' and row ->> 'ingredient_id'='23820000-0000-4000-8000-000000000043'),'false',
  'zero eligible suppliers disables recommendation confirmation');
select is((select row #>> '{allowed_actions,save_allocation}' from sc_results r
  cross join lateral jsonb_array_elements(r.response -> 'rows') row
  where r.name='global_read' and row ->> 'ingredient_id'='23820000-0000-4000-8000-000000000043'),'false',
  'zero eligible suppliers does not advertise an impossible manual allocation');
select ok((select (row -> 'disabled_reasons') ? 'NO_ELIGIBLE_SUPPLIER'
    and (row -> 'blockers') ? 'NO_ELIGIBLE_SUPPLIER' from sc_results r
  cross join lateral jsonb_array_elements(r.response -> 'rows') row
  where r.name='global_read' and row ->> 'ingredient_id'='23820000-0000-4000-8000-000000000043'),
  'zero eligible suppliers returns an explicit authoritative blocker and disabled reason');
select ok((select row -> 'recommendation' = 'null'::jsonb from sc_results r
  cross join lateral jsonb_array_elements(r.response -> 'rows') row
  where r.name='global_read' and row ->> 'ingredient_id'='23820000-0000-4000-8000-000000000042'),
  'tied best priority returns no recommendation');
select is((select row #>> '{allowed_actions,confirm_recommendation}' from sc_results r
  cross join lateral jsonb_array_elements(r.response -> 'rows') row
  where r.name='global_read' and row ->> 'ingredient_id'='23820000-0000-4000-8000-000000000042'),'false',
  'tied best priority disables recommendation confirmation');
select ok((select (row -> 'disabled_reasons') ? 'AMBIGUOUS_SUPPLIER_PRIORITY'
    and (row -> 'blockers') ? 'AMBIGUOUS_SUPPLIER_PRIORITY' from sc_results r
  cross join lateral jsonb_array_elements(r.response -> 'rows') row
  where r.name='global_read' and row ->> 'ingredient_id'='23820000-0000-4000-8000-000000000042'),
  'tied best priority returns an explicit authoritative blocker and disabled reason');
select ok((select row -> 'recommendation' is not null and row -> 'recommendation' <> 'null'::jsonb
  from sc_results r cross join lateral jsonb_array_elements(r.response -> 'rows') row
  where r.name='global_read' and row ->> 'ingredient_id'='23820000-0000-4000-8000-000000000041'
    and row ->> 'delivery_location_id'='23820000-0000-4000-8000-000000000011'),
  'unique lowest priority returns the authoritative recommendation');
select is((select row #>> '{allowed_actions,confirm_recommendation}' from sc_results r
  cross join lateral jsonb_array_elements(r.response -> 'rows') row
  where r.name='global_read' and row ->> 'ingredient_id'='23820000-0000-4000-8000-000000000041'
    and row ->> 'delivery_location_id'='23820000-0000-4000-8000-000000000011'),'true',
  'unique lowest priority enables authoritative recommendation confirmation');
select is(jsonb_array_length((select response -> 'rows' from sc_results where name='supplier_search')),3,
  'supplier-name search returns every current family for which that supplier is eligible');
select ok((select jsonb_typeof(row -> 'family_quantity')='string'
    and row ->> 'family_quantity'='100.000000'
    and jsonb_typeof(row #> '{contributions,0,contribution_quantity}')='string'
    and row #>> '{contributions,0,contribution_quantity}'='100.000000'
    and jsonb_typeof(row #> '{recommendation,allocated_quantity}')='string'
    and row #>> '{recommendation,allocated_quantity}'='100.000000'
    and jsonb_typeof(row #> '{recommendation,split_ratio}')='string'
    and row #>> '{recommendation,split_ratio}'='1.000000000000'
  from sc_results r cross join lateral jsonb_array_elements(r.response -> 'rows') row
  where r.name='global_read' and row ->> 'ingredient_id'='23820000-0000-4000-8000-000000000041'
    and row ->> 'delivery_location_id'='23820000-0000-4000-8000-000000000011'),
  'workbench read serializes exact family, contribution, and recommendation quantities as strings');

set local role authenticated;
select set_config('request.jwt.claim.sub','23800000-0000-4000-8000-000000000102',true);
insert into sc_results values('mixed_scope_confirm',
  atlas_api.confirm_school_catering_supplier_recommendations(pg_temp.sc_command(
    '23800000-0000-4000-8000-000000000102','SCHOOL-CATERING-PROCUREMENT.v1',
    '23850000-0000-4000-8000-000000000001',1,
    'SCHOOL_CATERING_SUPPLIER_RECOMMENDATIONS_CONFIRMED',jsonb_build_object('candidates',jsonb_build_array(
      pg_temp.sc_candidate('23820000-0000-4000-8000-000000000011','23820000-0000-4000-8000-000000000041'),
      pg_temp.sc_candidate('23820000-0000-4000-8000-000000000012','23820000-0000-4000-8000-000000000041'))))));
reset role;
select is((select response ->> 'error_code' from sc_results where name='mixed_scope_confirm'),'SCOPE_DENIED',
  'mixed in-scope and out-of-scope recommendation batch fails closed');
select is((select count(*)::integer from atlas_procurement.school_catering_allocation_families),0,
  'mixed unauthorized recommendation batch writes no candidate');

set local role authenticated;
select set_config('request.jwt.claim.sub','23800000-0000-4000-8000-000000000102',true);
insert into sc_results values('scoped_confirm',
  atlas_api.confirm_school_catering_supplier_recommendations(pg_temp.sc_command(
    '23800000-0000-4000-8000-000000000102','SCHOOL-CATERING-PROCUREMENT.v1',
    '23850000-0000-4000-8000-000000000002',1,
    'SCHOOL_CATERING_SUPPLIER_RECOMMENDATIONS_CONFIRMED',jsonb_build_object('candidates',jsonb_build_array(
      pg_temp.sc_candidate('23820000-0000-4000-8000-000000000011','23820000-0000-4000-8000-000000000041'))))));
insert into sc_results values('scoped_manual',
  atlas_api.save_school_catering_supplier_allocation(pg_temp.sc_command(
    '23800000-0000-4000-8000-000000000102','SCHOOL-CATERING-PROCUREMENT.v1',
    '23850000-0000-4000-8000-000000000003',1,
    'SCHOOL_CATERING_SUPPLIER_ALLOCATION_SAVED',jsonb_build_object(
      'family',pg_temp.sc_family('23820000-0000-4000-8000-000000000011','23820000-0000-4000-8000-000000000041'),
      'splits',jsonb_build_array(
        jsonb_build_object('supplier_id','23820000-0000-4000-8000-000000000051','allocated_quantity',60),
        jsonb_build_object('supplier_id','23820000-0000-4000-8000-000000000052','allocated_quantity',40))))));
insert into sc_results values('out_of_scope_save',
  atlas_api.save_school_catering_supplier_allocation(pg_temp.sc_command(
    '23800000-0000-4000-8000-000000000102','SCHOOL-CATERING-PROCUREMENT.v1',
    '23850000-0000-4000-8000-000000000004',0,
    'SCHOOL_CATERING_SUPPLIER_ALLOCATION_SAVED',jsonb_build_object(
      'family',pg_temp.sc_family('23820000-0000-4000-8000-000000000012','23820000-0000-4000-8000-000000000041'),
      'splits',jsonb_build_array(jsonb_build_object(
        'supplier_id','23820000-0000-4000-8000-000000000051','allocated_quantity',50))))));
reset role;
select is(jsonb_array_length((select response -> 'confirmed' from sc_results where name='scoped_confirm')),1,
  'DELIVERY_LOCATION-scoped actor confirms an in-scope recommendation');
select is((select response #>> '{family,family_version}' from sc_results where name='scoped_manual'),'2',
  'DELIVERY_LOCATION-scoped actor saves an exact balanced successor allocation');
select ok((select count(*)=2 and count(*) filter(where is_current)=1
  from atlas_procurement.school_catering_allocation_family_revisions r
  join atlas_procurement.school_catering_allocation_families f using(family_id)
  where f.delivery_location_id='23820000-0000-4000-8000-000000000011'
    and f.ingredient_id='23820000-0000-4000-8000-000000000041'),
  'successor allocation retains prior immutable history and one current revision');
select ok((select count(*) filter(where split_ratio=0.600000000000)=1
    and count(*) filter(where split_ratio=0.400000000000)=1
  from atlas_procurement.school_catering_allocation_supplier_splits s
  join atlas_procurement.school_catering_allocation_family_revisions r using(family_revision_id)
  join atlas_procurement.school_catering_allocation_families f using(family_id)
  where f.delivery_location_id='23820000-0000-4000-8000-000000000011'
    and f.ingredient_id='23820000-0000-4000-8000-000000000041' and r.is_current),
  'server calculates and persists exact 60/40 ratios');
select is((select response ->> 'error_code' from sc_results where name='out_of_scope_save'),'SCOPE_DENIED',
  'out-of-scope manual family save is denied');

set local role authenticated;
select set_config('request.jwt.claim.sub','23800000-0000-4000-8000-000000000101',true);
insert into sc_results values('stale_fingerprint',atlas_api.save_school_catering_supplier_allocation(
  pg_temp.sc_command('23800000-0000-4000-8000-000000000101','SCHOOL-CATERING-PROCUREMENT.v1',
    '23850000-0000-4000-8000-000000000005',0,'SCHOOL_CATERING_SUPPLIER_ALLOCATION_SAVED',
    jsonb_build_object('family',pg_temp.sc_family('23820000-0000-4000-8000-000000000012',
      '23820000-0000-4000-8000-000000000041') || jsonb_build_object('expected_source_fingerprint','stale'),
      'splits',jsonb_build_array(jsonb_build_object('supplier_id','23820000-0000-4000-8000-000000000051','allocated_quantity',50))))));
insert into sc_results values('duplicate_supplier',atlas_api.save_school_catering_supplier_allocation(
  pg_temp.sc_command('23800000-0000-4000-8000-000000000101','SCHOOL-CATERING-PROCUREMENT.v1',
    '23850000-0000-4000-8000-000000000006',0,'SCHOOL_CATERING_SUPPLIER_ALLOCATION_SAVED',
    jsonb_build_object('family',pg_temp.sc_family('23820000-0000-4000-8000-000000000012','23820000-0000-4000-8000-000000000041'),
      'splits',jsonb_build_array(
        jsonb_build_object('supplier_id','23820000-0000-4000-8000-000000000051','allocated_quantity',25),
        jsonb_build_object('supplier_id','23820000-0000-4000-8000-000000000051','allocated_quantity',25))))));
insert into sc_results values('non_positive_split',atlas_api.save_school_catering_supplier_allocation(
  pg_temp.sc_command('23800000-0000-4000-8000-000000000101','SCHOOL-CATERING-PROCUREMENT.v1',
    '23850000-0000-4000-8000-000000000007',0,'SCHOOL_CATERING_SUPPLIER_ALLOCATION_SAVED',
    jsonb_build_object('family',pg_temp.sc_family('23820000-0000-4000-8000-000000000012','23820000-0000-4000-8000-000000000041'),
      'splits',jsonb_build_array(jsonb_build_object('supplier_id','23820000-0000-4000-8000-000000000051','allocated_quantity',0))))));
insert into sc_results values('imbalanced',atlas_api.save_school_catering_supplier_allocation(
  pg_temp.sc_command('23800000-0000-4000-8000-000000000101','SCHOOL-CATERING-PROCUREMENT.v1',
    '23850000-0000-4000-8000-000000000008',0,'SCHOOL_CATERING_SUPPLIER_ALLOCATION_SAVED',
    jsonb_build_object('family',pg_temp.sc_family('23820000-0000-4000-8000-000000000012','23820000-0000-4000-8000-000000000041'),
      'splits',jsonb_build_array(jsonb_build_object('supplier_id','23820000-0000-4000-8000-000000000051','allocated_quantity',49))))));
insert into sc_results values('inactive_supplier',atlas_api.save_school_catering_supplier_allocation(
  pg_temp.sc_command('23800000-0000-4000-8000-000000000101','SCHOOL-CATERING-PROCUREMENT.v1',
    '23850000-0000-4000-8000-000000000009',0,'SCHOOL_CATERING_SUPPLIER_ALLOCATION_SAVED',
    jsonb_build_object('family',pg_temp.sc_family('23820000-0000-4000-8000-000000000012','23820000-0000-4000-8000-000000000041'),
      'splits',jsonb_build_array(jsonb_build_object('supplier_id','23820000-0000-4000-8000-000000000053','allocated_quantity',50))))));
insert into sc_results values('ineligible_supplier',atlas_api.save_school_catering_supplier_allocation(
  pg_temp.sc_command('23800000-0000-4000-8000-000000000101','SCHOOL-CATERING-PROCUREMENT.v1',
    '23850000-0000-4000-8000-000000000010',0,'SCHOOL_CATERING_SUPPLIER_ALLOCATION_SAVED',
    jsonb_build_object('family',pg_temp.sc_family('23820000-0000-4000-8000-000000000012','23820000-0000-4000-8000-000000000041'),
      'splits',jsonb_build_array(jsonb_build_object('supplier_id','23820000-0000-4000-8000-000000000054','allocated_quantity',50))))));
reset role;
select is((select response ->> 'error_code' from sc_results where name='stale_fingerprint'),'SOURCE_CHANGED',
  'stale expected source fingerprint fails SOURCE_CHANGED');
select is((select response ->> 'error_code' from sc_results where name='duplicate_supplier'),'DUPLICATE_SUPPLIER',
  'duplicate supplier fails closed');
select is((select response ->> 'error_code' from sc_results where name='non_positive_split'),'NON_POSITIVE_SPLIT',
  'non-positive split fails closed');
select is((select response ->> 'error_code' from sc_results where name='imbalanced'),'ALLOCATION_IMBALANCED',
  'exact split imbalance fails closed');
select is((select response ->> 'error_code' from sc_results where name='inactive_supplier'),'SUPPLIER_INACTIVE',
  'inactive supplier fails using current evidence');
select is((select response ->> 'error_code' from sc_results where name='ineligible_supplier'),'SUPPLIER_INELIGIBLE',
  'ineligible supplier fails using current evidence');

-- Capture an untouched candidate, then change current priority before acceptance.
create temporary table sc_captured_candidate as
select pg_temp.sc_candidate('23820000-0000-4000-8000-000000000012',
  '23820000-0000-4000-8000-000000000041') candidate;
grant select on sc_captured_candidate to authenticated;
update atlas_admin.supplier_eligibilities set priority=1
where supplier_id='23820000-0000-4000-8000-000000000052'
  and ingredient_id='23820000-0000-4000-8000-000000000041';
set local role authenticated;
select set_config('request.jwt.claim.sub','23800000-0000-4000-8000-000000000101',true);
insert into sc_results select 'priority_became_ambiguous',
  atlas_api.confirm_school_catering_supplier_recommendations(pg_temp.sc_command(
    '23800000-0000-4000-8000-000000000101','SCHOOL-CATERING-PROCUREMENT.v1',
    '23850000-0000-4000-8000-000000000011',1,
    'SCHOOL_CATERING_SUPPLIER_RECOMMENDATIONS_CONFIRMED',
    jsonb_build_object('candidates',jsonb_build_array(candidate))))
from sc_captured_candidate;
reset role;
select is((select response #>> '{skipped,0,reason}' from sc_results
  where name='priority_became_ambiguous'),'AMBIGUOUS_SUPPLIER_PRIORITY',
  'recommendation is safely skipped when best priority becomes ambiguous');
select is((select count(*)::integer from atlas_procurement.school_catering_allocation_families
  where delivery_location_id='23820000-0000-4000-8000-000000000012'),0,
  'ambiguous recommendation persists no Allocation Family');
update atlas_admin.supplier_eligibilities set priority=2
where supplier_id='23820000-0000-4000-8000-000000000052'
  and ingredient_id='23820000-0000-4000-8000-000000000041';

set local role authenticated;
select set_config('request.jwt.claim.sub','23800000-0000-4000-8000-000000000101',true);
insert into sc_results values('global_manual',atlas_api.save_school_catering_supplier_allocation(
  pg_temp.sc_command('23800000-0000-4000-8000-000000000101','SCHOOL-CATERING-PROCUREMENT.v1',
    '23850000-0000-4000-8000-000000000012',0,'SCHOOL_CATERING_SUPPLIER_ALLOCATION_SAVED',
    jsonb_build_object('family',pg_temp.sc_family('23820000-0000-4000-8000-000000000012','23820000-0000-4000-8000-000000000041'),
      'splits',jsonb_build_array(
        jsonb_build_object('supplier_id','23820000-0000-4000-8000-000000000051','allocated_quantity',25),
        jsonb_build_object('supplier_id','23820000-0000-4000-8000-000000000052','allocated_quantity',25))))));
insert into sc_results values('global_successor',atlas_api.save_school_catering_supplier_allocation(
  pg_temp.sc_command('23800000-0000-4000-8000-000000000101','SCHOOL-CATERING-PROCUREMENT.v1',
    '23850000-0000-4000-8000-000000000013',1,'SCHOOL_CATERING_SUPPLIER_ALLOCATION_SAVED',
    jsonb_build_object('family',pg_temp.sc_family('23820000-0000-4000-8000-000000000012','23820000-0000-4000-8000-000000000041'),
      'splits',jsonb_build_array(
        jsonb_build_object('supplier_id','23820000-0000-4000-8000-000000000051','allocated_quantity',30),
        jsonb_build_object('supplier_id','23820000-0000-4000-8000-000000000052','allocated_quantity',20))))));
insert into sc_results values('allocated_read',atlas_api.get_school_catering_procurement_workbench(
  pg_temp.sc_read('23800000-0000-4000-8000-000000000101',null)));
reset role;
select is((select response #>> '{family,family_version}' from sc_results where name='global_manual'),'1',
  'GLOBAL actor saves a current exact balanced manual allocation');
select is((select response #>> '{family,family_version}' from sc_results where name='global_successor'),'2',
  'GLOBAL actor saves a successor allocation revision');
select ok((select count(*)=2 and count(*) filter(where not is_current)=1
  from atlas_procurement.school_catering_allocation_family_revisions r
  join atlas_procurement.school_catering_allocation_families f using(family_id)
  where f.delivery_location_id='23820000-0000-4000-8000-000000000012'),
  'GLOBAL successor preserves the prior Allocation revision intact');
select ok((select bool_and(jsonb_typeof(split -> 'allocated_quantity')='string'
      and jsonb_typeof(split -> 'split_ratio')='string')
  from sc_results r cross join lateral jsonb_array_elements(r.response -> 'rows') row
  cross join lateral jsonb_array_elements(row -> 'splits') split
  where r.name='allocated_read'
    and row ->> 'delivery_location_id'='23820000-0000-4000-8000-000000000012'
    and row ->> 'ingredient_id'='23820000-0000-4000-8000-000000000041'),
  'workbench read serializes persisted allocation quantities and ratios as strings');

-- Complete saved allocations before invoking the real release command.
insert into atlas_core.role_capabilities(role_id,capability_id)
  select '23810000-0000-4000-8000-000000000001',capability_id from atlas_core.capabilities
  where capability_code in ('confirmed_need_review.read','confirmed_need_review.confirm','confirmed_need_validation.validate',
    'confirmed_need_approval.approve','confirmed_need_release.release') on conflict do nothing;
set local role authenticated;
select set_config('request.jwt.claim.sub','23800000-0000-4000-8000-000000000101',true);
do $prepare$
declare row_data jsonb;answer jsonb;batch_id uuid;request jsonb;
  subject_id uuid:='23800000-0000-4000-8000-000000000101';
begin
  for row_data in select value from jsonb_array_elements(atlas_api.get_confirmed_supplier_allocation_workbench(
    jsonb_build_object('contract_version','CONFIRMED-SUPPLIER-ALLOCATION.v1','correlation_id',gen_random_uuid(),
      'requested_by_auth_subject',subject_id,'payload',jsonb_build_object('date_start','2026-09-11','date_end','2026-09-12')))->'rows') loop
    request:=pg_temp.sc_command(subject_id,'CONFIRMED-SUPPLIER-ALLOCATION.v1',gen_random_uuid(),0,
      'CONFIRMED_SUPPLIER_ALLOCATION_SAVED',jsonb_build_object('family',jsonb_build_object(
        'service_date',row_data->'service_date','delivery_location_id',row_data->'delivery_location_id',
        'ingredient_id',row_data->'ingredient_id','unit_id',row_data->'unit_id',
        'expected_source_fingerprint',row_data#>'{family,source_fingerprint}',
        'expected_source_batch_id',row_data->'source_confirmed_need_batch_id',
        'expected_source_batch_version',4),'splits',jsonb_build_array(jsonb_build_object(
          'supplier_id','23820000-0000-4000-8000-000000000051','allocated_quantity',row_data->'family_quantity'))));
    answer:=atlas_api.save_confirmed_supplier_allocation(request);
    if answer->>'success' is distinct from 'true' then raise exception 'Allocation fixture failed: %',answer;end if;
  end loop;
  foreach batch_id in array array['23840000-0000-4000-8000-000000000101'::uuid,'23840000-0000-4000-8000-000000000102'::uuid] loop
    answer:=atlas_api.release_confirmed_needs(pg_temp.sc_command(subject_id,'RMVP-07.v2',gen_random_uuid(),4,
      'CONFIRMED_NEED_RELEASED',jsonb_build_object('confirmed_need_batch_id',batch_id)));
    if answer->>'success' is distinct from 'true' then raise exception 'Release fixture failed: %',answer;end if;
  end loop;
end;
$prepare$;
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','23800000-0000-4000-8000-000000000102',true);
insert into sc_results values('scoped_handoff',atlas_api.release_school_catering_purchase_handoff(
  pg_temp.sc_command('23800000-0000-4000-8000-000000000102','SCHOOL-CATERING-HANDOFF.v1',
    '23850000-0000-4000-8000-000000000014',7,'SCHOOL_CATERING_PURCHASE_HANDOFF_RELEASED',
    jsonb_build_object('confirmed_need_batch_id','23840000-0000-4000-8000-000000000101'))));
insert into sc_results values('mixed_handoff_denied',atlas_api.release_school_catering_purchase_handoff(
  pg_temp.sc_command('23800000-0000-4000-8000-000000000102','SCHOOL-CATERING-HANDOFF.v1',
    '23850000-0000-4000-8000-000000000015',7,'SCHOOL_CATERING_PURCHASE_HANDOFF_RELEASED',
    jsonb_build_object('confirmed_need_batch_id','23840000-0000-4000-8000-000000000102'))));
reset role;
select is((select response ->> 'success' from sc_results where name='scoped_handoff'),'true',
  'DELIVERY_LOCATION-scoped actor releases an entirely in-scope Handoff');
select ok((select response ->> 'error_code' from sc_results where name='mixed_handoff_denied')='SCOPE_DENIED'
    and not exists(select 1 from atlas_planning.purchase_handoff_batches
      where confirmed_need_batch_id='23840000-0000-4000-8000-000000000102'),
  'mixed-location Handoff fails closed before writes for a partially scoped actor');

set local role authenticated;
select set_config('request.jwt.claim.sub','23800000-0000-4000-8000-000000000101',true);
insert into sc_results values('global_handoff',atlas_api.release_school_catering_purchase_handoff(
  pg_temp.sc_command('23800000-0000-4000-8000-000000000101','SCHOOL-CATERING-HANDOFF.v1',
    '23850000-0000-4000-8000-000000000016',7,'SCHOOL_CATERING_PURCHASE_HANDOFF_RELEASED',
    jsonb_build_object('confirmed_need_batch_id','23840000-0000-4000-8000-000000000102'))));
reset role;
select is((select response ->> 'success' from sc_results where name='global_handoff'),'true',
  'GLOBAL actor releases the same mixed-location Handoff');

select * from finish();
rollback;
