begin;
set local track_functions='all';
create extension if not exists pgtap with schema extensions;
set search_path=extensions,public,pg_catalog;
select no_plan();
\ir ../local/purchase_preparation_scale_fixture.sql

insert into atlas_core.role_capabilities(role_id,capability_id)
select 'b6000000-0000-0000-0000-000000000003',capability_id
from atlas_core.capabilities where capability_code='dispatch.school_release.read'
on conflict do nothing;

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

set constraints all deferred;
insert into scale_requests(name,request)
select 'issue',pg_temp.scale_command('allocation-read-issue','SCHOOL-CATERING-PROCUREMENT.v1',
  'SCHOOL_CATERING_PO_RELEASED',po.version,jsonb_build_object(
    'purchase_order_id',po.purchase_order_id,
    'expected_purchase_order_revision_id',revision.purchase_order_revision_id))
from atlas_procurement.purchase_orders po
join atlas_procurement.purchase_order_revisions revision using(purchase_order_id)
where po.school_catering_service_date='2027-01-18' and revision.is_current
  and not exists(select 1 from atlas_procurement.purchase_order_line_revisions line
    where line.purchase_order_revision_id=revision.purchase_order_revision_id
      and (line.ingredient_id,line.delivery_location_id)=(
        select current.ingredient_id,current.delivery_location_id
        from atlas_planning.confirmed_need_lines need
        join atlas_planning.confirmed_need_line_revisions current using(confirmed_need_line_id)
        where need.confirmed_need_batch_id=md5('allocation-released-read:confirmed-need-batch')::uuid
          and current.is_current order by need.confirmed_need_line_id limit 1))
order by po.purchase_order_id limit 1;
set local statement_timeout='8s';
set local role authenticated;
insert into scale_results(name,response)
select name,atlas_api.release_school_catering_purchase_order(request)
from scale_requests where name='issue';
set constraints all immediate;
reset role;
select is((select response->>'success' from scale_results where name='issue'),
  'true','fixture issues one genuine unaffected PO before checking dispatch impact');
select diag(response::text) from scale_results where name='issue' and response->>'success'<>'true';

create temporary table read_before as select pg_temp.scale_business_snapshot() facts,
  (select jsonb_agg(to_jsonb(r) order by command_receipt_id)
    from atlas_core.command_receipts r) receipts;
create temporary table reconciliation_parity_scopes(label text primary key,service_date date,
  school_id uuid,delivery_location_id uuid,actual jsonb);
create function pg_temp.capture_reconciliation_scope(p_label text) returns void language plpgsql as $$
declare context jsonb; scope record;
begin
  context:=atlas_core.procurement_read_context('2027-01-18','2027-01-18');
  if p_label='reopened' then
    select line.service_date,line.school_id,line.delivery_location_id into scope
    from atlas_planning.confirmed_need_lines line join scale_requests command
      on line.confirmed_need_line_id=(command.request#>>'{payload,lines,0,confirmed_need_line_id}')::uuid
    where command.name='correct';
  else
    select (source->>'service_date')::date service_date,
      (contribution->>'school_id')::uuid school_id,
      (source->>'delivery_location_id')::uuid delivery_location_id into scope
    from jsonb_array_elements(context->'sources') source
    cross join lateral jsonb_array_elements(source->'contributions') contribution
    order by contribution->>'school_id',source->>'ingredient_id' limit 1;
  end if;
  if not found then raise exception 'Reconciliation parity requires a genuine School scope'; end if;
  insert into reconciliation_parity_scopes values(p_label,scope.service_date,scope.school_id,
    scope.delivery_location_id,atlas_core.procurement_read_school_fulfilment_reconciliation_scope(
      scope.service_date,scope.school_id,scope.delivery_location_id,context));
end;
$$;
-- Each authority construction retains its own unchanged eight-second statement budget.
select pg_temp.capture_reconciliation_scope('ordinary');
select is(actual,atlas_core.school_fulfilment_reconciliation_scope(service_date,school_id,delivery_location_id),
  'ordinary reconciliation exactly matches the original complete scope result')
from reconciliation_parity_scopes where label='ordinary';
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

-- The reported Staging case is REOPENED, not the ordinary released case above.
set constraints all deferred;
insert into scale_requests(name,request)
select 'correct',pg_temp.scale_command('allocation-read-correct','RMVP-05.v3',
  'CONFIRMED_NEED_SAVED',b.version,jsonb_build_object(
    'confirmed_need_batch_id',b.confirmed_need_batch_id,
    'correction',jsonb_build_object(
      'expected_confirmed_need_release_id',b.current_confirmed_need_release_id,
      'expected_purchase_handoff_batch_id',h.purchase_handoff_batch_id,
      'expected_purchase_handoff_revision_id',hr.purchase_handoff_revision_id,
      'expected_purchase_handoff_version',h.version,
      'expected_source_fingerprint',encode(sha256(convert_to(
        atlas_core.rmvp_07_validated_facts_projection(b.confirmed_need_batch_id)::text,'UTF8')),'hex')),
    'lines',jsonb_build_array(jsonb_build_object(
      'confirmed_need_line_id',l.confirmed_need_line_id,
      'expected_current_revision_id',r.confirmed_need_line_revision_id,
      'expected_current_decision_id',l.current_confirmed_need_line_decision_id,
      'proposed_confirmed_quantity',(r.confirmed_quantity+1)::numeric(20,6)::text,
      'reason_code','OPERATIONAL_QUANTITY_ADJUSTMENT','reason_note','Read regression correction'))))
from atlas_planning.confirmed_need_batches b
join atlas_planning.purchase_handoff_batches h using(confirmed_need_batch_id)
join atlas_planning.purchase_handoff_revisions hr using(purchase_handoff_batch_id)
join atlas_planning.confirmed_need_lines l using(confirmed_need_batch_id)
join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
where b.confirmed_need_batch_id=md5('allocation-released-read:confirmed-need-batch')::uuid
  and r.is_current and hr.is_current
order by l.confirmed_need_line_id limit 1;
set local role authenticated;
insert into scale_results(name,response)
select name,atlas_api.save_confirmed_needs(request) from scale_requests where name='correct';
reset role;
select is((select response->>'success' from scale_results where name='correct'),
  'true','official post-release correction reopens the genuine 236-family batch');
select diag(response::text) from scale_results where name='correct' and response->>'success'<>'true';
select pg_temp.capture_reconciliation_scope('reopened');
select is((select jsonb_build_array(service_date,school_id,delivery_location_id)
    from reconciliation_parity_scopes where label='reopened'),
  (select jsonb_build_array(line.service_date,line.school_id,line.delivery_location_id)
    from atlas_planning.confirmed_need_lines line join scale_requests command
      on line.confirmed_need_line_id=(command.request#>>'{payload,lines,0,confirmed_need_line_id}')::uuid
    where command.name='correct'),'reopened parity targets the actual corrected line School and captured location');
select is(actual,atlas_core.school_fulfilment_reconciliation_scope(service_date,school_id,delivery_location_id),
  'reopened reconciliation exactly matches the original complete scope result')
from reconciliation_parity_scopes where label='reopened';
create temporary table reopened_before as select pg_temp.scale_business_snapshot() facts,
  (select jsonb_agg(to_jsonb(r) order by command_receipt_id) from atlas_core.command_receipts r) receipts;
create temporary table reopened_samples(kind text,response jsonb,elapsed_ms numeric,proof_calls bigint,context_calls bigint);
grant select,insert on reopened_samples to authenticated;
create function pg_temp.sample_reopened_read(p_kind text) returns void language plpgsql as $$
declare started timestamptz:=clock_timestamp(); answer jsonb; prior_calls bigint; prior_context_calls bigint; failure_context text;
begin
  select coalesce(sum(calls) filter(where funcname='procurement_read_batch_proof'),0),
    coalesce(sum(calls) filter(where funcname='procurement_read_context'),0)
  into prior_calls,prior_context_calls from pg_stat_xact_user_functions
  where schemaname='atlas_core' and funcname in ('procurement_read_batch_proof','procurement_read_context');
  if p_kind='allocation' then
    answer:=atlas_api.get_confirmed_supplier_allocation_workbench(jsonb_build_object(
      'contract_version','CONFIRMED-SUPPLIER-ALLOCATION.v1','correlation_id',gen_random_uuid(),
      'requested_by_auth_subject','b6000000-0000-0000-0000-000000000101',
      'payload',jsonb_build_object('date_start','2027-01-18','date_end','2027-01-18')));
  elsif p_kind='orders' then
    answer:=atlas_api.get_school_catering_purchase_orders(jsonb_build_object(
      'contract_version','SCHOOL-CATERING-PROCUREMENT.v1','correlation_id',gen_random_uuid(),
      'requested_by_auth_subject','b6000000-0000-0000-0000-000000000101',
      'payload',jsonb_build_object('date_start','2027-01-18','date_end','2027-01-18',
        'supplier_ids','[]'::jsonb,'statuses','[]'::jsonb,'search',null)));
  elsif p_kind='reconciliation' then
    answer:=atlas_api.get_school_fulfilment_reconciliation_workbench(jsonb_build_object(
      'contract_version','SCHOOL-FULFILMENT-RECONCILIATION.v1','correlation_id',gen_random_uuid(),
      'requested_by_auth_subject','b6000000-0000-0000-0000-000000000101',
      'payload',jsonb_build_object('date_start','2027-01-18','date_end','2027-01-18',
        'school_ids','[]'::jsonb,'search',null)));
  else
    answer:=atlas_api.get_school_dispatch_release_workbench(jsonb_build_object(
      'contract_version','SCHOOL-DISPATCH-RELEASE.v1','correlation_id',gen_random_uuid(),
      'requested_by_auth_subject','b6000000-0000-0000-0000-000000000101',
      'payload',jsonb_build_object('date_start','2027-01-18','date_end','2027-01-18',
        'school_ids','[]'::jsonb,'search',null)));
  end if;
  insert into reopened_samples select p_kind,answer,
    extract(epoch from clock_timestamp()-started)*1000,
    coalesce(sum(calls) filter(where funcname='procurement_read_batch_proof'),0)-prior_calls,
    coalesce(sum(calls) filter(where funcname='procurement_read_context'),0)-prior_context_calls
  from pg_stat_xact_user_functions
  where schemaname='atlas_core' and funcname in ('procurement_read_batch_proof','procurement_read_context');
exception when query_canceled then
  get stacked diagnostics failure_context=PG_EXCEPTION_CONTEXT;
  insert into reopened_samples values(p_kind,jsonb_build_object('success',false,'timeout',true,'context',failure_context),
    extract(epoch from clock_timestamp()-started)*1000,null,null);
end;
$$;
grant execute on function pg_temp.sample_reopened_read(text) to authenticated;
set local statement_timeout='8s';
-- Reproduce CI's custom-plan path; the private helper must bound its own plan.
set local plan_cache_mode='force_custom_plan';
set local role authenticated;
select pg_temp.sample_reopened_read('allocation');
select pg_temp.sample_reopened_read('orders');
select pg_temp.sample_reopened_read('dispatch');
select pg_temp.sample_reopened_read('reconciliation');
reset role;
set local plan_cache_mode='auto';
select ok(response->>'success'='true' and elapsed_ms<8000,
  'reopened 236-family '||kind||' read succeeds within the unchanged eight seconds') from reopened_samples;
select is(proof_calls,1::bigint,'closed batch proof runs once for '||kind) from reopened_samples;
select is((select context_calls from reopened_samples where kind='orders'),1::bigint,
  'whole-date PO prerequisite reuses the one authoritative context per public request');
select is((select context_calls from reopened_samples where kind='reconciliation'),1::bigint,
  'all-School reconciliation builds one authoritative context per public request');
select is((select jsonb_array_length(response->'rows') from reopened_samples where kind='allocation'),
  236,'reopened read retains every family');
select is((select count(*) from reopened_samples cross join lateral jsonb_array_elements(response->'rows') item
  where kind='allocation' and item#>>'{family,source_kind}'='CONFIRMED_NEED'),1::bigint,
  'only the genuinely corrected family changes source authority');
select is((select jsonb_array_length(response->'rows') from reopened_samples where kind='dispatch'),
  4,'issued-order dispatch impact retains all four School scopes');
select is((select jsonb_array_length(response->'rows') from reopened_samples where kind='reconciliation'),
  4,'reconciliation retains all four authorized School scopes after correction');
select ok((select bool_and(item->>'pxk_state'='BLOCKED'
    and jsonb_array_length(item->'blockers')>0)
  from reopened_samples cross join lateral jsonb_array_elements(response->'rows') item
  where kind='reconciliation'),'reconciliation preserves incomplete-coverage blockers');
select ok((select bool_and(item->>'state'='BLOCKED'
    and item#>>'{preview,ready}'='false' and item#>>'{allowed_actions,release}'='false')
  from reopened_samples cross join lateral jsonb_array_elements(response->'rows') item
  where kind='dispatch'),'dispatch impact retains incomplete-coverage release blockers');
select is(pg_temp.scale_business_snapshot(),(select facts from reopened_before),
  'reopened reads leave all business facts and historical documents unchanged');
select is((select jsonb_agg(to_jsonb(r) order by command_receipt_id) from atlas_core.command_receipts r),
  (select receipts from reopened_before),'reopened reads leave receipts unchanged');
select diag(jsonb_build_object('kind',kind,'elapsed_ms',elapsed_ms,'proof_calls',proof_calls,'context_calls',context_calls)::text)
from reopened_samples;
select diag(response::text) from reopened_samples where response->>'success'<>'true';
select ok(not exists(select 1 from pg_proc function
  join pg_namespace namespace on namespace.oid=function.pronamespace
  cross join pg_roles role where namespace.nspname='atlas_core'
    and function.proname like 'procurement_read_%'
    and role.rolname in ('anon','authenticated','service_role')
    and has_function_privilege(role.rolname,function.oid,'EXECUTE')),
  'public request roles cannot supply or execute a private read context');
select ok((select pg_get_userbyid(proowner)='atlas_read_runtime' and prosecdef
    and provolatile='s' and proconfig=array['search_path=""']
  from pg_proc where oid='atlas_core.procurement_read_school_fulfilment_reconciliation_scope(date,uuid,uuid,jsonb)'::regprocedure),
  'private reconciliation retains stable runtime ownership and empty definer search path');
set local role authenticated;
select throws_ok($$select atlas_core.procurement_read_school_fulfilment_reconciliation_scope(
    date '2027-01-18',null::uuid,null::uuid,'{}'::jsonb)$$,'42501',null,
  'authenticated clients cannot execute a caller-supplied private reconciliation context');
select is(atlas_api.get_school_fulfilment_reconciliation_workbench(jsonb_build_object(
    'contract_version','SCHOOL-FULFILMENT-RECONCILIATION.v1','correlation_id',gen_random_uuid(),
    'requested_by_auth_subject','b6000000-0000-0000-0000-000000000101',
    'payload',jsonb_build_object('date_start','2027-01-18','date_end','2027-01-18',
      'school_ids','[]'::jsonb,'search',null,'read_context','{}'::jsonb)))->>'error_code',
  'VALIDATION_FAILED','public reconciliation rejects injected read context');
reset role;
select ok(exists(select 1 from reopened_samples
  cross join lateral jsonb_array_elements(response->'purchase_orders') item
  where kind='orders' and item->>'commitment_state'='DRAFT_STALE'),
  'read reuse still reports the Draft affected by the actual correction as stale');
create temporary table context_parity as
with context as materialized(select atlas_core.procurement_read_context('2027-01-18','2027-01-18') value)
select distinct on (source->>'corrected_family') context.value context,source
from context cross join lateral jsonb_each(context.value->'confirmed') entry
cross join lateral jsonb_array_elements(entry.value) source
order by source->>'corrected_family',source->>'ingredient_id';
select is(atlas_core.procurement_read_purchase_review_confirmed_projection(
    (source->>'service_date')::date,(source->>'delivery_location_id')::uuid,
    (source->>'ingredient_id')::uuid,(source->>'unit_id')::uuid,context),
  atlas_core.purchase_review_confirmed_projection(
    (source->>'service_date')::date,(source->>'delivery_location_id')::uuid,
    (source->>'ingredient_id')::uuid,(source->>'unit_id')::uuid),
  'read proof exactly matches command proof; corrected='||(source->>'corrected_family')) from context_parity;
select is(atlas_core.procurement_read_school_catering_family_projection(
    (source->>'service_date')::date,(source->>'delivery_location_id')::uuid,
    (source->>'ingredient_id')::uuid,(source->>'unit_id')::uuid,context),
  atlas_core.school_catering_family_projection(
    (source->>'service_date')::date,(source->>'delivery_location_id')::uuid,
    (source->>'ingredient_id')::uuid,(source->>'unit_id')::uuid),
  'read family selector exactly matches canonical selector; corrected='||(source->>'corrected_family')) from context_parity;

-- Continue the operator's next step using only the authenticated read's binding.
set constraints all deferred;
insert into scale_requests(name,request)
select 'accept-correction',pg_temp.scale_command('allocation-read-accept-correction',
  'CONFIRMED-SUPPLIER-ALLOCATION.v1','CONFIRMED_SUPPLIER_ALLOCATION_SAVED',
  (row#>>'{family,version}')::bigint,jsonb_build_object(
    'family',jsonb_build_object('service_date',row->'service_date',
      'delivery_location_id',row->'delivery_location_id','ingredient_id',row->'ingredient_id',
      'unit_id',row->'unit_id','expected_source_fingerprint',row#>'{family,source_fingerprint}',
      'expected_source_batch_id',row#>'{family,source_confirmed_need_batch_id}',
      'expected_source_batch_version',row#>'{family,source_confirmed_need_batch_version}'),
    'splits',jsonb_build_array(jsonb_build_object('supplier_id',row#>'{splits,0,supplier_id}',
      'allocated_quantity',row->'family_quantity','supplier_note','Accepted fixture correction'))))
from reopened_samples cross join lateral jsonb_array_elements(response->'rows') row
where kind='allocation' and row#>>'{family,source_kind}'='CONFIRMED_NEED';
set local role authenticated;
insert into scale_results(name,response)
select name,atlas_api.save_confirmed_supplier_allocation(request)
from scale_requests where name='accept-correction';
set constraints all immediate;
reset role;
select is((select response->>'success' from scale_results where name='accept-correction'),
  'true','operator accepts the corrected allocation using exact public read bindings');
select diag(response::text) from scale_results where name='accept-correction' and response->>'success'<>'true';

set constraints all deferred;
insert into scale_requests(name,request)
select 'prepare-correction',pg_temp.scale_command('allocation-read-prepare-correction',
  'PURCHASE-COMMITMENT.v1','PURCHASE_ORDERS_PREPARED',batch.version,
  jsonb_build_object('confirmed_need_batch_id',batch.confirmed_need_batch_id,
    'service_date',batch.period_start))
from atlas_planning.confirmed_need_batches batch
where batch.confirmed_need_batch_id=md5('allocation-released-read:confirmed-need-batch')::uuid;
set local statement_timeout='20s';
set local role authenticated;
insert into scale_results(name,response)
select name,atlas_api.prepare_school_catering_purchase_orders(request)
from scale_requests where name='prepare-correction';
set constraints all immediate;
reset role;
select is((select response->>'success' from scale_results where name='prepare-correction'),
  'true','236-family corrected Preparation succeeds through the normal public command');
select diag(response::text) from scale_results where name='prepare-correction' and response->>'success'<>'true';

set constraints all deferred;
insert into scale_requests(name,request)
select 'issue-correction',pg_temp.scale_command('allocation-read-issue-correction',
  'SCHOOL-CATERING-PROCUREMENT.v1','SCHOOL_CATERING_PO_RELEASED',po.version,
  jsonb_build_object('purchase_order_id',po.purchase_order_id,
    'expected_purchase_order_revision_id',revision.purchase_order_revision_id))
from atlas_procurement.purchase_orders po
join atlas_procurement.purchase_order_revisions revision using(purchase_order_id)
where po.school_catering_service_date='2027-01-18' and po.purchase_order_status='DRAFT'
  and revision.is_current and exists(
    select 1 from atlas_procurement.purchase_order_line_revisions line
    join atlas_planning.confirmed_need_line_revisions need
      on need.ingredient_id=line.ingredient_id and need.unit_id=line.unit_id
      and need.delivery_location_id=line.delivery_location_id and need.is_current
    where line.purchase_order_revision_id=revision.purchase_order_revision_id
      and need.confirmed_need_line_id=(select (request#>>'{payload,lines,0,confirmed_need_line_id}')::uuid
        from scale_requests where name='correct'));
set local statement_timeout='8s';
set local role authenticated;
insert into scale_results(name,response)
select name,atlas_api.release_school_catering_purchase_order(request)
from scale_requests where name='issue-correction';
set constraints all immediate;
reset role;
select is((select response->>'success' from scale_results where name='issue-correction'),
  'true','operator releases the repaired corrected PO through the normal public command');
select diag(response::text) from scale_results where name='issue-correction' and response->>'success'<>'true';
select ok(exists(select 1 from atlas_procurement.purchase_orders po
  join atlas_procurement.purchase_order_revisions revision using(purchase_order_id)
  join atlas_procurement.purchase_order_line_revisions line using(purchase_order_revision_id)
  join atlas_planning.confirmed_need_line_revisions need
    on need.ingredient_id=line.ingredient_id and need.unit_id=line.unit_id
    and need.delivery_location_id=line.delivery_location_id and need.is_current
  where po.purchase_order_id=(select (response->>'purchase_order_id')::uuid
      from scale_results where name='issue-correction')
    and po.purchase_order_status='RELEASED_TO_SUPPLIER' and revision.is_current
    and need.confirmed_need_line_id=(select (request#>>'{payload,lines,0,confirmed_need_line_id}')::uuid
      from scale_requests where name='correct')
    and line.ordered_quantity=need.confirmed_quantity),
  'issued corrected document retains the exact newly confirmed quantity');
select is((select to_jsonb(po) from atlas_procurement.purchase_orders po
    where po.purchase_order_id=(select (response->>'purchase_order_id')::uuid
      from scale_results where name='issue')),
  (select old from read_before cross join lateral jsonb_array_elements(facts->'purchase_orders') old
    where old->>'purchase_order_id'=(select response->>'purchase_order_id' from scale_results where name='issue')),
  'correction and new issuance leave the unrelated issued order unchanged');
select * from finish();
rollback;
