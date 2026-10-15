-- Include within a rolled-back local test. Existing guarded fixtures supply
-- synthetic source/master prerequisites only; all tested successor authority
-- below is created through authenticated public commands. No replica mode.
\ir purchase_review_confirm_release_fixture.sql

insert into atlas_core.actors(actor_id,actor_type,display_name) values
 ('c0150000-0000-4000-8000-000000000001','HUMAN','C public journey operator');
insert into atlas_core.actor_auth_subjects(actor_id,auth_subject_id) values
 ('c0150000-0000-4000-8000-000000000001','c0150000-0000-4000-8000-000000000101');
insert into atlas_core.actor_role_memberships(actor_id,role_id) values
 ('c0150000-0000-4000-8000-000000000001','b6000000-0000-0000-0000-000000000003');
insert into atlas_core.actor_scopes(actor_id,scope_kind) values
 ('c0150000-0000-4000-8000-000000000001','GLOBAL');
insert into atlas_core.role_capabilities(role_id,capability_id)
select 'b6000000-0000-0000-0000-000000000003',capability_id
from atlas_core.capabilities where capability_code like 'planning.%'
 or capability_code like 'confirmed_need_%'
 or capability_code like 'procurement.school_catering.%'
 or capability_code like 'dispatch.school_release.%'
on conflict do nothing;

-- Explicit synthetic issuer facts, not an inference or a staff assignment.
update atlas_admin.schools set dispatch_document_issuer_name='C fixture issuer',
 dispatch_document_issuer_address='C fixture synthetic address'
where school_id='b6500000-0000-0000-0000-000000000004';

-- Shared-location School B and separate-date/location School C are explicit
-- synthetic master facts; none of their downstream authority is preseeded.
insert into atlas_admin.delivery_locations
select (jsonb_populate_record(null::atlas_admin.delivery_locations,to_jsonb(l)||
 jsonb_build_object('delivery_location_id','c0150000-0000-4000-8000-000000000013',
 'location_code','c-fixture-location-c','location_name','C fixture other kitchen'))).*
from atlas_admin.delivery_locations l
where delivery_location_id='b6500000-0000-0000-0000-000000000002';
insert into atlas_admin.schools
select (jsonb_populate_record(null::atlas_admin.schools,to_jsonb(s)||
 jsonb_build_object('school_id',v.school_id,'school_code',v.school_code,
 'school_name',v.school_name,'default_delivery_location_id',v.location_id,
 'display_order',v.display_order))).*
from atlas_admin.schools s cross join (values
 ('c0150000-0000-4000-8000-000000000012','c-fixture-school-b','C fixture School B',
  'b6500000-0000-0000-0000-000000000002',60),
 ('c0150000-0000-4000-8000-000000000014','c-fixture-school-c','C fixture School C',
  'c0150000-0000-4000-8000-000000000013',70))
 v(school_id,school_code,school_name,location_id,display_order)
where s.school_id='b6500000-0000-0000-0000-000000000004';

create temporary table c_results(name text primary key,response jsonb not null,
 invoked_as text not null);
grant select,insert on c_results to authenticated;
create temporary table c_context(name text primary key,value jsonb not null);

create function pg_temp.c_command(contract text,reason text,version bigint,
 payload jsonb,note text default null) returns jsonb
language sql volatile set search_path='' as $$
 select jsonb_build_object('contract_version',contract,'command_id',gen_random_uuid(),
  'correlation_id',gen_random_uuid(),'idempotency_key',gen_random_uuid()::text,
  'expected_version',version,
  'requested_by_auth_subject','c0150000-0000-4000-8000-000000000101',
  'requested_at',transaction_timestamp(),'reason_code',reason,
  'reason_note',note,'payload',payload);
$$;
create function pg_temp.c_read(contract text,payload jsonb) returns jsonb
language sql volatile set search_path='' as $$
 select jsonb_build_object('contract_version',contract,
  'requested_by_auth_subject','c0150000-0000-4000-8000-000000000101',
  'correlation_id',gen_random_uuid(),'payload',payload);
$$;
create function pg_temp.c_invoke(stage text,api text,request jsonb) returns jsonb
language plpgsql volatile as $$
declare response jsonb; invoked_as text;
begin
 if api not in ('save_pantry','execute_need_generation','save_confirmed_needs',
   'get_confirmed_supplier_allocation_workbench','save_confirmed_supplier_allocation',
   'validate_confirmed_needs','approve_confirmed_needs','release_confirmed_needs_for_purchase_handoff',
   'release_school_catering_purchase_handoff','create_school_catering_purchase_order_drafts',
   'release_school_catering_purchase_order','get_school_dispatch_release_workbench',
   'release_school_dispatch_document','get_school_catering_purchase_orders') then raise exception 'Unexpected fixture API';end if;
 set local role authenticated;
 perform set_config('request.jwt.claim.sub',
  'c0150000-0000-4000-8000-000000000101',true);
 invoked_as:=current_user;
 execute format('select atlas_api.%I($1)',api) into response using request;
 reset role;
 insert into c_results values(stage,response,invoked_as);
 if response->>'success' is distinct from 'true' then
  raise exception 'C public fixture stage % rejected: %',stage,response;
 end if;
 return response;
exception when others then reset role;raise;
end;
$$;

-- Change a real source before generation: NO_CHANGE over the seeded template
-- cannot establish the public generated successor required by this proof.
do $source$
declare rows jsonb; batch atlas_planning.pantry_need_batches%rowtype; answer jsonb;
begin
 select * into strict batch from atlas_planning.pantry_need_batches
 where pantry_need_batch_id='b6530000-0000-0000-0000-000000000002';
 select jsonb_agg(jsonb_build_object('service_date',l.service_date,
  'school_id',l.school_id,'ingredient_id',l.ingredient_id,
  'pantry_need_purpose_id',l.pantry_need_purpose_id,
  'requested_quantity',case when l.ingredient_id='b6500000-0000-0000-0000-000000000006'
   then '101.000000' else l.requested_quantity::text end,
  'note','C authentic public source fixture',
  'source_request_reference',l.source_request_reference,
  'source_row_reference',l.source_row_reference) order by l.pantry_need_line_id)
 into rows from atlas_planning.pantry_need_lines l
 where l.pantry_need_batch_id=batch.pantry_need_batch_id;
 rows:=rows||(select jsonb_agg(jsonb_build_object(
  'service_date',v.day,'school_id',v.school,'ingredient_id',v.ingredient,
  'pantry_need_purpose_id','b6530000-0000-0000-0000-000000000001',
  'requested_quantity',v.quantity,'note','C complete family source',
  'source_request_reference','C-FIXTURE','source_row_reference',v.reference))
 from(values
  ('2026-11-02','c0150000-0000-4000-8000-000000000012','b6500000-0000-0000-0000-000000000006','20.000000','B-I'),
  ('2026-11-02','c0150000-0000-4000-8000-000000000012','b6500000-0000-0000-0000-000000000007','5.000000','B-J'),
  ('2026-11-03','c0150000-0000-4000-8000-000000000014','b6500000-0000-0000-0000-000000000006','30.000000','C-I'),
  ('2026-11-03','c0150000-0000-4000-8000-000000000014','b6500000-0000-0000-0000-000000000007','7.000000','C-J'))
 v(day,school,ingredient,quantity,reference));
 answer:=pg_temp.c_invoke('source-save','save_pantry',pg_temp.c_command(
  'PANTRY-02.v2','PANTRY_SAVED',batch.version,jsonb_build_object(
   'week_start',batch.week_start,'no_additions_confirmed',false,
   'source_signature',atlas_core.pantry_02_signature(batch.week_start,false,
    atlas_core.pantry_02_canonical_rows(batch.week_start,rows)),
   'expected_source_signature',batch.source_signature,'rows',rows),
  'C public source setup'));
end;
$source$;

do $generation$
declare run atlas_planning.need_generation_runs%rowtype; answer jsonb; day date;
begin
 for day in select unnest(array[date '2026-11-02',date '2026-11-03'])loop
  select r.* into run from atlas_planning.need_generation_runs r
  join atlas_planning.confirmed_need_batches b on b.current_need_generation_run_id=r.need_generation_run_id
  where b.period_start=day and b.period_end=day;
  answer:=pg_temp.c_invoke('generation:'||day,'execute_need_generation',pg_temp.c_command(
   'RMVP-04.v3','NEED_GENERATION_EXECUTED',coalesce(run.version,1),jsonb_build_object(
    'service_date',day,'expected_current_need_generation_run_id',run.need_generation_run_id),
   'C public generated successor'));
  if answer#>>'{affected_aggregate_ids,need_generation_run_id}'=run.need_generation_run_id::text
   then raise exception 'Fixture generation must create a genuine successor';end if;
  insert into c_context values('batch:'||day,answer#>'{affected_aggregate_ids,confirmed_need_batch_id}');
 end loop;
end;
$generation$;

do $confirmed_save$
declare batch_id uuid; version bigint; lines jsonb; answer jsonb; context record;
begin
 for context in select * from c_context where name like 'batch:%' order by name loop
 batch_id:=(context.value#>>'{}')::uuid;
 select b.version into strict version from atlas_planning.confirmed_need_batches b
 where b.confirmed_need_batch_id=batch_id;
 select jsonb_agg(jsonb_build_object('confirmed_need_line_id',l.confirmed_need_line_id,
  'expected_current_revision_id',r.confirmed_need_line_revision_id,
  'expected_current_decision_id',l.current_confirmed_need_line_decision_id,
  'proposed_confirmed_quantity',r.confirmed_quantity::numeric(20,6)::text,
  'reason_code','PROPOSAL_ACCEPTED','reason_note',null)order by l.confirmed_need_line_id)
 into lines from atlas_planning.confirmed_need_lines l
 join atlas_planning.confirmed_need_line_revisions r on r.confirmed_need_line_id=l.confirmed_need_line_id
  and r.is_current where l.confirmed_need_batch_id=batch_id;
 answer:=pg_temp.c_invoke('need-save:'||context.name,'save_confirmed_needs',pg_temp.c_command(
  'RMVP-05.v2','CONFIRMED_NEED_SAVED',version,
  jsonb_build_object('confirmed_need_batch_id',batch_id,'lines',lines)));
 end loop;
end;
$confirmed_save$;

do $allocation$
declare answer jsonb; row jsonb; ordinal integer:=0; supplier uuid;
begin
 answer:=pg_temp.c_invoke('allocation-read','get_confirmed_supplier_allocation_workbench',
  pg_temp.c_read('CONFIRMED-SUPPLIER-ALLOCATION.v1',jsonb_build_object(
   'date_start','2026-11-02','date_end','2026-11-03')));
 for row in select value from jsonb_array_elements(answer->'rows')loop
  ordinal:=ordinal+1;
  supplier:=case when row->>'ingredient_id'='b6500000-0000-0000-0000-000000000006'
   then 'c7100000-0000-4000-8000-000000000001'::uuid
   else 'c7100000-0000-4000-8000-000000000002'::uuid end;
  perform pg_temp.c_invoke('allocation-save-'||ordinal,'save_confirmed_supplier_allocation',
   pg_temp.c_command('CONFIRMED-SUPPLIER-ALLOCATION.v1',
    'CONFIRMED_SUPPLIER_ALLOCATION_SAVED',(row#>>'{family,version}')::bigint,
    jsonb_build_object('family',jsonb_build_object(
     'service_date',row->'service_date','delivery_location_id',row->'delivery_location_id',
     'ingredient_id',row->'ingredient_id','unit_id',row->'unit_id',
     'expected_source_fingerprint',row#>'{family,source_fingerprint}',
     'expected_source_batch_id',row->'source_confirmed_need_batch_id',
     'expected_source_batch_version',row->'source_confirmed_need_batch_version'),
     'splits',jsonb_build_array(jsonb_build_object('supplier_id',supplier,
      'allocated_quantity',row->'family_quantity')))));
 end loop;
 if ordinal<>4 then raise exception 'Expected four complete allocation families, got %',ordinal;end if;
end;
$allocation$;

do $planning_release$
declare batch_id uuid; version bigint; stage text; context record;
begin
 for context in select * from c_context where name like 'batch:%' order by name loop
 batch_id:=(context.value#>>'{}')::uuid;
 for stage in select unnest(array['validate','approve','release','handoff'])loop
  select b.version into strict version from atlas_planning.confirmed_need_batches b
  where b.confirmed_need_batch_id=batch_id;
  perform pg_temp.c_invoke('need-'||stage||':'||context.name,
   case stage when 'validate' then 'validate_confirmed_needs'
    when 'approve' then 'approve_confirmed_needs'
    when 'release' then 'release_confirmed_needs_for_purchase_handoff'
    else 'release_school_catering_purchase_handoff' end,
   pg_temp.c_command(case stage when 'validate' then 'RMVP-06.v1'
    when 'approve' then 'RMVP-07.v1' when 'release' then 'RMVP-07.v1'
    else 'SCHOOL-CATERING-HANDOFF.v1' end,
    case stage when 'validate' then 'BATCH_VALIDATION_REQUESTED'
    when 'approve' then 'CONFIRMED_NEED_APPROVAL_REQUESTED'
    when 'release' then 'CONFIRMED_NEED_RELEASE_REQUESTED'
    else 'SCHOOL_CATERING_PURCHASE_HANDOFF_RELEASED' end,version,
    jsonb_build_object('confirmed_need_batch_id',batch_id)));
 end loop;
 end loop;
end;
$planning_release$;

select pg_temp.c_invoke('po-drafts','create_school_catering_purchase_order_drafts',
 pg_temp.c_command('SCHOOL-CATERING-PROCUREMENT.v1','SCHOOL_CATERING_PO_DRAFTS_CREATED',1,
 jsonb_build_object('date_start','2026-11-02','date_end','2026-11-03')))->>'success';

do $po_release$
declare row record; ordinal integer:=0;
begin
 for row in select po.purchase_order_id,po.version,r.purchase_order_revision_id
 from atlas_procurement.purchase_orders po
 join atlas_procurement.purchase_order_revisions r using(purchase_order_id)
 where po.school_catering_service_date between '2026-11-02' and '2026-11-03' and r.is_current
 order by po.purchase_order_id loop
  ordinal:=ordinal+1;
  perform pg_temp.c_invoke('po-release-'||ordinal,'release_school_catering_purchase_order',
   pg_temp.c_command('SCHOOL-CATERING-PROCUREMENT.v1','SCHOOL_CATERING_PO_RELEASED',row.version,
    jsonb_build_object('purchase_order_id',row.purchase_order_id,
     'expected_purchase_order_revision_id',row.purchase_order_revision_id)));
 end loop;
 if ordinal<>4 then raise exception 'Expected four actual Supplier/date POs, got %',ordinal;end if;
end;
$po_release$;

do $pxk_release$
declare answer jsonb; row jsonb; ordinal integer:=0;
begin
 answer:=pg_temp.c_invoke('pxk-read','get_school_dispatch_release_workbench',
  pg_temp.c_read('SCHOOL-DISPATCH-RELEASE.v1',jsonb_build_object(
   'date_start','2026-11-02','date_end','2026-11-03','school_ids','[]'::jsonb,'search',null)));
 for row in select value from jsonb_array_elements(answer->'rows')loop
  ordinal:=ordinal+1;
  perform pg_temp.c_invoke('pxk-release-'||ordinal,'release_school_dispatch_document',
   pg_temp.c_command('SCHOOL-DISPATCH-RELEASE.v1','SCHOOL_DISPATCH_DOCUMENT_RELEASED',
    (row->>'expected_version')::bigint,jsonb_build_object(
     'service_date',row->'service_date','school_id',row->'school_id',
     'delivery_location_id',row->'delivery_location_id',
     'expected_source_fingerprint',row#>'{preview,source_fingerprint}',
     'predecessor_release_id',null)));
 end loop;
 if ordinal<>3 then raise exception 'Expected three actual School PXKs, got %',ordinal;end if;
end;
$pxk_release$;
set constraints all immediate;
set constraints all deferred;

-- Real official consumers are retained for the later historical export proof.
select pg_temp.c_invoke('official-po-read','get_school_catering_purchase_orders',
 pg_temp.c_read('SCHOOL-CATERING-PROCUREMENT.v1',jsonb_build_object(
  'date_start','2026-11-02','date_end','2026-11-03','supplier_ids','[]'::jsonb,
  'statuses','[]'::jsonb,'search',null)))->>'success';
select pg_temp.c_invoke('official-pxk-read','get_school_dispatch_release_workbench',
 pg_temp.c_read('SCHOOL-DISPATCH-RELEASE.v1',jsonb_build_object(
  'date_start','2026-11-02','date_end','2026-11-03','school_ids','[]'::jsonb,
  'search',null)))->>'success';

-- Ordinary released Save must remain denied; this is not a C bypass.
create temporary table c_before_ordinary as select jsonb_agg(to_jsonb(r)
 order by r.confirmed_need_line_revision_id) revisions
 from atlas_planning.confirmed_need_line_revisions r;
insert into c_context
select 'ordinary-save-request',pg_temp.c_command('RMVP-05.v2','CONFIRMED_NEED_SAVED',
 b.version,jsonb_build_object('confirmed_need_batch_id',b.confirmed_need_batch_id,
 'lines',jsonb_build_array(jsonb_build_object('confirmed_need_line_id',l.confirmed_need_line_id,
  'expected_current_revision_id',r.confirmed_need_line_revision_id,
  'expected_current_decision_id',l.current_confirmed_need_line_decision_id,
  'proposed_confirmed_quantity',(r.confirmed_quantity+1)::text,
  'reason_code','OPERATIONAL_QUANTITY_ADJUSTMENT','reason_note','Must remain denied'))))
from atlas_planning.confirmed_need_batches b
join atlas_planning.confirmed_need_lines l using(confirmed_need_batch_id)
join atlas_planning.confirmed_need_line_revisions r
 on r.confirmed_need_line_id=l.confirmed_need_line_id and r.is_current
where b.period_start='2026-11-02' and b.period_end='2026-11-02'
order by l.confirmed_need_line_id limit 1;
grant select on c_context to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','c0150000-0000-4000-8000-000000000101',true);
insert into c_results select 'ordinary-released-save',
 atlas_api.save_confirmed_needs(value),current_user from c_context
where name='ordinary-save-request';
reset role;
