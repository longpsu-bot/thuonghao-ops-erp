begin;
set local track_functions='all';
create extension if not exists pgtap with schema extensions;
set search_path=extensions,public,pg_catalog;
select no_plan();
\ir ../local/purchase_preparation_scale_fixture.sql

select pg_temp.seed_purchase_preparation_scale(
  'allocation-released-read','allocation-read',date '2027-01-18');
insert into scale_requests(name,request)
select 'save',pg_temp.scale_confirmed_need_save_command(
  'allocation-read-save',md5('allocation-released-read:confirmed-need-batch')::uuid);
set local statement_timeout='8s';
set local role authenticated;
select set_config('request.jwt.claim.sub','b6000000-0000-0000-0000-000000000101',true);
insert into scale_results(name,response)
select name,atlas_api.save_confirmed_needs(request) from scale_requests where name='save';
set constraints all immediate;
reset role;
set constraints all deferred;
select is((select response->>'success' from scale_results where name='save'),
  'true','local scale setup saves 236 authoritative decisions');

-- As in the existing preparation-scale test, plan against the seeded catalog.
do $fixture_statistics$
declare relation record;
begin
  for relation in select schemaname,relname from pg_stat_user_tables
    where schemaname in ('atlas_admin','atlas_planning','atlas_procurement','atlas_core')
  loop
    execute format('analyze %I.%I',relation.schemaname,relation.relname);
  end loop;
end;
$fixture_statistics$;

insert into scale_requests(name,request)
select 'prepare',pg_temp.scale_command('allocation-read-prepare','PURCHASE-COMMITMENT.v1',
  'PURCHASE_ORDERS_PREPARED',b.version,jsonb_build_object(
    'confirmed_need_batch_id',b.confirmed_need_batch_id,'service_date',b.period_start))
from atlas_planning.confirmed_need_batches b
where confirmed_need_batch_id=md5('allocation-released-read:confirmed-need-batch')::uuid;
set local statement_timeout='20s';
set local role authenticated;
insert into scale_results(name,response)
select name,atlas_api.prepare_school_catering_purchase_orders(request)
from scale_requests where name='prepare';
set constraints all immediate;
reset role;
select is((select response->>'success' from scale_results where name='prepare'),
  'true','local scale setup establishes released Handoff and Draft POs');

create temporary table read_before as select pg_temp.scale_business_snapshot() facts,
  (select jsonb_agg(to_jsonb(r) order by command_receipt_id)
    from atlas_core.command_receipts r) receipts;
create temporary table read_samples(sample integer,response jsonb,elapsed_ms numeric,source_calls bigint);
grant select,insert on read_samples to authenticated;
-- Each sample is a separate statement so the unchanged transport budget resets.
create function pg_temp.sample_released_read() returns void language plpgsql as $read_sample$
declare
  started timestamptz:=clock_timestamp();
  prior_calls bigint;
  answer jsonb;
begin
  select coalesce(calls,0) into prior_calls from pg_stat_xact_user_functions
  where schemaname='atlas_core' and funcname='purchase_review_confirmed_sources';
  answer:=atlas_api.get_confirmed_supplier_allocation_workbench(jsonb_build_object(
    'contract_version','CONFIRMED-SUPPLIER-ALLOCATION.v1',
    'requested_by_auth_subject','b6000000-0000-0000-0000-000000000101',
    'correlation_id','bd110000-0000-4000-8000-000000000001',
    'payload',jsonb_build_object('date_start','2027-01-18','date_end','2027-01-18')));
  insert into read_samples select coalesce((select max(sample) from read_samples),0)+1,
    answer,extract(epoch from clock_timestamp()-started)*1000,
    coalesce(calls,0)-coalesce(prior_calls,0)
  from pg_stat_xact_user_functions
  where schemaname='atlas_core' and funcname='purchase_review_confirmed_sources';
exception when query_canceled then
  insert into read_samples values(coalesce((select max(sample) from read_samples),0)+1,
    jsonb_build_object('success',false,'timeout',true),
    extract(epoch from clock_timestamp()-started)*1000,null);
end;
$read_sample$;
grant execute on function pg_temp.sample_released_read() to authenticated;
set local statement_timeout='8s';
set local role authenticated;
select pg_temp.sample_released_read();
select pg_temp.sample_released_read();
select pg_temp.sample_released_read();
reset role;

select ok(bool_and(response->>'success'='true'),'all three authenticated released reads succeed') from read_samples;
select ok(bool_and(elapsed_ms<8000),'all three reads fit the unchanged 8-second budget') from read_samples;
select ok(bool_and(source_calls<=3),'source reconstructions are bounded independently of 236 rows') from read_samples;
select is((select count(*) from read_samples where jsonb_array_length(response->'rows')=236),
  3::bigint,'every read returns exactly 236 families');
select ok((select bool_and(
    (select jsonb_agg(value#>'{family,family_id}' order by value#>>'{family,family_id}')
      from jsonb_array_elements(response->'rows') value)=
    (select jsonb_agg(to_jsonb(f.family_id) order by f.family_id::text)
      from atlas_procurement.school_catering_allocation_families f
      where f.service_date=date '2027-01-18')) from read_samples),
  'every read contains exactly the persisted set of 236 distinct family identities');
select is((select count(distinct response) from read_samples),1::bigint,
  'repeated reads return the same exact response');
select ok((select bool_and(value#>>'{family,source_kind}'='PURCHASE_HANDOFF'
    and value->>'complete'='true' and value->>'state'='BALANCED'
    and value#>>'{family,source_confirmed_need_batch_id}'=
      md5('allocation-released-read:confirmed-need-batch')::uuid::text
    and value->>'source_purchase_handoff_revision_id' is not null)
  from read_samples cross join lateral jsonb_array_elements(response->'rows') value),
  'released rows retain complete current Handoff authority and Confirmed Need lineage');
select ok((select bool_and(value->>'family_quantity'=r.family_quantity::text
    and value#>>'{family,source_fingerprint}'=r.source_fingerprint
    and value->>'service_date'=f.service_date::text
    and value->>'delivery_location_id'=f.delivery_location_id::text
    and value->>'ingredient_id'=f.ingredient_id::text and value->>'unit_id'=f.unit_id::text
    and value->'contributions'=(select jsonb_agg(contribution || jsonb_build_object(
      'contribution_quantity',(contribution->>'contribution_quantity')::numeric(20,6)::text)
      order by ordinal)
      from jsonb_array_elements(atlas_core.school_catering_family_projection(
        f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id)->'contributions')
        with ordinality source(contribution,ordinal))
    and value->'splits'=(select jsonb_agg(jsonb_build_object(
      'supplier_split_id',s.supplier_split_id,'supplier_id',s.supplier_id,
      'supplier_name',sp.supplier_name,'allocated_quantity',s.allocated_quantity::text,
      'split_ratio',s.split_ratio::text,'supplier_note',s.supplier_note) order by s.supplier_id)
      from atlas_procurement.school_catering_allocation_supplier_splits s
      join atlas_admin.suppliers sp using(supplier_id) where s.family_revision_id=r.family_revision_id))
  from read_samples cross join lateral jsonb_array_elements(response->'rows') value
  join atlas_procurement.school_catering_allocation_family_revisions r
    on r.family_id=(value#>>'{family,family_id}')::uuid and r.is_current
  join atlas_procurement.school_catering_allocation_families f using(family_id)),
  'exact identities, quantities, Handoff lineage and Supplier splits match current facts');
select ok((select bool_and(response#>>'{preparation,ready}'='true'
    and response#>>'{preparation,allowed}'='true'
    and response#>>'{preparation,expected_version}'=b.version::text)
  from read_samples cross join atlas_planning.confirmed_need_batches b
  where b.confirmed_need_batch_id=md5('allocation-released-read:confirmed-need-batch')::uuid),
  'released preparation status and authoritative version are preserved');
select is(pg_temp.scale_business_snapshot(),(select facts from read_before),
  'reads create or change no business facts, events or audit evidence');
select is((select jsonb_agg(to_jsonb(r) order by command_receipt_id)
  from atlas_core.command_receipts r),(select receipts from read_before),
  'reads create or change no receipts');
select diag(jsonb_build_object('sample',sample,'elapsed_ms',elapsed_ms,
  'source_calls',source_calls,'rows',jsonb_array_length(response->'rows'))::text)
from read_samples order by sample;
select * from finish();
rollback;
