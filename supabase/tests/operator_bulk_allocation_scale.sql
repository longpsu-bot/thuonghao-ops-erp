begin;
create extension if not exists pgtap with schema extensions;
set search_path=extensions,public,pg_catalog;
select no_plan();
\ir ../local/purchase_preparation_scale_fixture.sql
select pg_temp.seed_purchase_preparation_scale('bulk-scale-cn','bulk-scale',date '2027-03-01',null,null,50,5);
insert into scale_requests values('save-cn',pg_temp.scale_confirmed_need_save_command('bulk-save-cn',md5('bulk-scale-cn:confirmed-need-batch')::uuid));
set local role authenticated;
select set_config('request.jwt.claim.sub','b6000000-0000-0000-0000-000000000101',true);
insert into scale_results(name,response) select name,atlas_api.save_confirmed_needs(request) from scale_requests;
reset role;
select is((select response->>'success' from scale_results where name='save-cn'),'true',
  '250-line 50-School source saved through existing Planning command');
do $stats$ declare r record; begin
  for r in select schemaname,relname from pg_stat_user_tables where schemaname like 'atlas_%'
  loop execute format('analyze %I.%I',r.schemaname,r.relname); end loop;
end; $stats$;
insert into scale_requests values('read',jsonb_build_object('contract_version','CONFIRMED-SUPPLIER-ALLOCATION.v1',
  'correlation_id',gen_random_uuid(),'requested_by_auth_subject','b6000000-0000-0000-0000-000000000101',
  'payload','{"date_start":"2027-03-01","date_end":"2027-03-01","include_bulk_preview":true}'::jsonb));
set local statement_timeout='8s';
set local role authenticated;
select set_config('request.jwt.claim.sub','b6000000-0000-0000-0000-000000000101',true);
insert into scale_results(name,response,started_at) values('preview','{}',clock_timestamp());
update scale_results set response=atlas_api.get_confirmed_supplier_allocation_workbench(
  (select request from scale_requests where name='read')) where name='preview';
update scale_results set command_finished_at=clock_timestamp() where name='preview';
reset role;
select is((select response#>>'{bulk_preview,total_count}' from scale_results where name='preview'),'250','50 Schools × 5 Ingredients produce 250 whole families');
select is((select count(distinct s->>'school_id') from scale_results,lateral jsonb_array_elements(response#>'{bulk_preview,families}') e,
  lateral jsonb_array_elements(e->'schools') s where name='preview'),50::bigint,'benchmark represents exactly 50 canonical School identities');
select is((select count(*) from scale_results,lateral jsonb_array_elements(response#>'{bulk_preview,families}') e
  where name='preview' and e#>>'{candidate,family,source_kind}'='CONFIRMED_NEED'),250::bigint,'250 current saved Confirmed Need families are applicable');
insert into scale_requests select 'apply',pg_temp.scale_command('bulk-apply','SUPPLIER-ALLOCATION-BATCH.v1',
  'SUPPLIER_ALLOCATION_BATCH_APPLIED',1,jsonb_build_object('scope','{"date_start":"2027-03-01","date_end":"2027-03-01"}'::jsonb,
    'candidates',(select jsonb_agg(e->'candidate') from jsonb_array_elements(response#>'{bulk_preview,families}') e
      where e->'candidate'<>'null'::jsonb))) from scale_results where name='preview';
set local role authenticated;
select set_config('request.jwt.claim.sub','b6000000-0000-0000-0000-000000000101',true);
insert into scale_results(name,response,started_at) values('applied','{}',clock_timestamp());
update scale_results set response=atlas_api.apply_supplier_allocation_batch(
  (select request from scale_requests where name='apply')) where name='applied';
update scale_results set command_finished_at=clock_timestamp() where name='applied';
reset role;
select is((select response->>'success' from scale_results where name='applied'),'true','one 50-School command succeeds');
select is((select response->>'applied_count' from scale_results where name='applied'),'250','batch saves all 250 explicitly reviewed families');
select ok((select command_finished_at-started_at<interval '8 seconds' from scale_results where name='preview'),'preview remains within authenticated 8-second budget');
select ok((select command_finished_at-started_at<interval '8 seconds' from scale_results where name='applied'),'batch command remains within authenticated 8-second budget');
select jsonb_build_object('workload','50 Schools / 250 families / CONFIRMED_NEED / one date','operation',name,
  'elapsed_ms',extract(epoch from command_finished_at-started_at)*1000,'response',response-'bulk_preview'-'rows'-'families')
  from scale_results where name in ('preview','applied');
-- Separate small shared-School/overlap matrix; not part of the timed workload.
reset statement_timeout;
select pg_temp.seed_purchase_preparation_scale('bulk-shared','bulk-shared',date '2027-03-15',null,null,2,1,true);
insert into scale_requests values('save-shared',pg_temp.scale_confirmed_need_save_command('bulk-save-shared',md5('bulk-shared:confirmed-need-batch')::uuid));
set local role authenticated;
insert into scale_results(name,response) select 'save-shared',atlas_api.save_confirmed_needs(request) from scale_requests where name='save-shared';
reset role;
select is((select response->>'success' from scale_results where name='save-shared'),'true','shared-School source uses guarded real saved decisions');
insert into scale_requests values('read-shared',jsonb_build_object('contract_version','CONFIRMED-SUPPLIER-ALLOCATION.v1',
  'correlation_id',gen_random_uuid(),'requested_by_auth_subject','b6000000-0000-0000-0000-000000000101',
  'payload',jsonb_build_object('date_start','2027-03-15','date_end','2027-03-15','include_bulk_preview',true,
    'school_ids',jsonb_build_array(md5('bulk-shared:school:2')::uuid))));
set local role authenticated;
insert into scale_results(name,response) select 'shared',atlas_api.get_confirmed_supplier_allocation_workbench(request) from scale_requests where name='read-shared';
reset role;
select is((select response#>>'{bulk_preview,applicable_count}' from scale_results where name='shared'),'1','ANY contributor School selects one whole family');
select ok((select response#>>'{bulk_preview,families,0,family_quantity}'='5.300000'
  and jsonb_array_length(response#>'{bulk_preview,families,0,schools}')=2
  and jsonb_array_length(response#>'{bulk_preview,families,0,contributions}')=2
  from scale_results where name='shared'),'School filter never clips full quantity or contribution/School identities');
insert into scale_requests select 'apply-shared',pg_temp.scale_command('bulk-apply-shared','SUPPLIER-ALLOCATION-BATCH.v1',
  'SUPPLIER_ALLOCATION_BATCH_APPLIED',1,jsonb_build_object('scope',(select (request->'payload')-'include_bulk_preview'
  from scale_requests where name='read-shared'),'candidates',jsonb_build_array(response#>'{bulk_preview,families,0,candidate}')))
  from scale_results where name='shared';
select pg_temp.seed_purchase_preparation_scale('bulk-shared-overlap','bulk-overlap',date '2027-03-15','bulk-shared',null,2,1,true);
insert into scale_requests values('save-overlap',pg_temp.scale_confirmed_need_save_command('bulk-save-overlap',md5('bulk-shared-overlap:confirmed-need-batch')::uuid));
set local role authenticated;
insert into scale_results(name,response) select 'save-overlap',atlas_api.save_confirmed_needs(request) from scale_requests where name='save-overlap';
insert into scale_results(name,response) select 'overlap-preview',atlas_api.get_confirmed_supplier_allocation_workbench(request) from scale_requests where name='read-shared';
insert into scale_results(name,response) select 'overlap-apply',atlas_api.apply_supplier_allocation_batch(request) from scale_requests where name='apply-shared';
reset role;
select is((select response->>'success' from scale_results where name='save-overlap'),'true','second complete source is a real independently guarded overlapping batch');
select ok((select response#>>'{bulk_preview,total_count}'='1' and response#>>'{bulk_preview,applicable_count}'='0'
  and response#>>'{bulk_preview,families,0,exclusion_reason}'='CONFIRMED_SOURCE_AMBIGUOUS_OR_MISSING'
  from scale_results where name='overlap-preview'),'complete universe deduplicates and discloses ambiguity instead of choosing one batch');
select is((select response->>'error_code' from scale_results where name='overlap-apply'),'STALE_BULK_PROPOSAL',
  'new overlapping batch invalidates the prior reviewed candidate');
select is((select count(*) from atlas_procurement.school_catering_allocation_families where service_date='2027-03-15'),0::bigint,
  'overlap conflict cannot partially save one School slice');
select * from finish();
rollback;
