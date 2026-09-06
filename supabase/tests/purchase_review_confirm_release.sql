begin;
create extension if not exists pgtap with schema extensions;
set search_path=extensions,public,pg_catalog;
select no_plan();
\ir ../local/purchase_review_confirm_release_fixture.sql

select has_column('atlas_procurement','school_catering_allocation_family_revisions','source_kind','revision source is explicit');
select has_column('atlas_procurement','school_catering_allocation_family_contributions','confirmed_need_line_revision_id','confirmed contribution lineage exists');
create temporary table review_results(name text primary key,response jsonb);
grant all on review_results to authenticated;
-- Dynamic invocation keeps missing APIs as observable assertion failures during RED.
create function pg_temp.review_read(api_name text,contract text,payload jsonb) returns jsonb
language plpgsql set search_path='' as $$
declare result jsonb;
begin
  execute format('select atlas_api.%I($1)',api_name) into result using jsonb_build_object(
    'contract_version',contract,'correlation_id',gen_random_uuid(),
    'requested_by_auth_subject','b6000000-0000-0000-0000-000000000101',
    'payload',payload);
  return result;
exception when undefined_function then return jsonb_build_object('missing_api',api_name);
end;
$$;
grant execute on function pg_temp.review_read(text,text,jsonb) to authenticated;
create temporary table before_preview as select
  (select count(*) from atlas_procurement.school_catering_allocation_family_revisions) allocation_count,
  (select count(*) from atlas_planning.purchase_handoff_batches) handoff_count,
  (select count(*) from atlas_procurement.purchase_orders) po_count,
  (select count(*) from atlas_core.command_receipts) receipt_count,
  (select count(*) from atlas_audit.domain_events) event_count;
create function pg_temp.safe_review_read(payload jsonb) returns jsonb language plpgsql as $$
begin return pg_temp.review_read('get_confirmed_supplier_allocation_workbench','CONFIRMED-SUPPLIER-ALLOCATION.v1',payload);
exception when others then return jsonb_build_object('raised',sqlstate); end;
$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','b6000000-0000-0000-0000-000000000101',true);
insert into review_results values('generated',pg_temp.review_read('get_generated_purchase_review',
  'PURCHASE-REVIEW.v1','{"service_date":"2026-11-02"}'));
insert into review_results values('incomplete',pg_temp.review_read('get_confirmed_supplier_allocation_workbench',
  'CONFIRMED-SUPPLIER-ALLOCATION.v1','{"date_start":"2026-11-02","date_end":"2026-11-02"}'));
reset role;
select is(pg_temp.safe_review_read('{"date_start":"2026-11-02","date_end":"2026-11-02","school_ids":null}')->>'error_code',
  'VALIDATION_FAILED','explicit null filter returns safe validation error');
select is(pg_temp.safe_review_read('{"date_start":"2026-11-02","date_end":"2026-11-02","school_ids":"bad"}')->>'error_code',
  'VALIDATION_FAILED','scalar School filter returns safe validation error');
select is(pg_temp.safe_review_read('{"date_start":"2026-11-02","date_end":"2026-11-02","states":{}}')->>'error_code',
  'VALIDATION_FAILED','object state filter returns safe validation error');
select is(pg_temp.safe_review_read('{"date_start":"2026-11-02","date_end":"2026-11-02","states":["INVENTED"]}')->>'error_code',
  'VALIDATION_FAILED','unknown allocation state is rejected');
select is((select response->>'success' from review_results where name='generated'),'true','generated review is readable before decisions');
select is((select line->>'family_quantity' from review_results,
  lateral jsonb_array_elements(response->'rows') line where name='generated'
  and line->>'ingredient_id'='b6500000-0000-0000-0000-000000000006'),'100.000000','generated Need uses exact100');
select is((select line#>>'{recommendation,allocated_quantity}' from review_results,
  lateral jsonb_array_elements(response->'rows') line where name='generated'
  and line->>'ingredient_id'='b6500000-0000-0000-0000-000000000006'),'100.000000','unique priority suggests100 without accepting it');
select is((select response#>>'{blockers,0}' from review_results where name='incomplete'),
  'Hoàn tất xác nhận nhu cầu trước khi phân bổ NCC.','incomplete saved Need blocks allocation');
select is((select response#>>'{rows,0,family_quantity}' from review_results where name='incomplete'),
  null::text,'incomplete saved Need never substitutes zero or generated quantity');
-- An incomplete second School at a shared kitchen must still be visible in
-- source metadata/filtering; it does not become an allocatable happy-path fixture.
create function pg_temp.shared_school_read() returns jsonb language plpgsql as $$
declare answer jsonb; second_school uuid:='b6500000-0000-0000-0000-000000000099';
  second_line uuid:='b6560000-0000-0000-0000-000000000099';
begin
  set local session_replication_role=replica;
  insert into atlas_admin.schools select (jsonb_populate_record(null::atlas_admin.schools,to_jsonb(s)||
    jsonb_build_object('school_id',second_school,'school_code','pr_shared','school_name','Second School','display_order',51))).*
    from atlas_admin.schools s where school_id='b6500000-0000-0000-0000-000000000004';
  insert into atlas_planning.confirmed_need_lines select (jsonb_populate_record(null::atlas_planning.confirmed_need_lines,to_jsonb(l)||
    jsonb_build_object('confirmed_need_line_id',second_line,'school_id',second_school,'current_confirmed_need_line_decision_id',null))).*
    from atlas_planning.confirmed_need_lines l where ingredient_id='b6500000-0000-0000-0000-000000000006';
  insert into atlas_planning.confirmed_need_line_revisions select (jsonb_populate_record(null::atlas_planning.confirmed_need_line_revisions,to_jsonb(r)||
    jsonb_build_object('confirmed_need_line_revision_id',gen_random_uuid(),'confirmed_need_line_id',second_line))).*
    from atlas_planning.confirmed_need_line_revisions r where r.confirmed_need_line_id='b6560000-0000-0000-0000-000000000001' and r.is_current;
  set local session_replication_role=origin;
  answer:=pg_temp.review_read('get_confirmed_supplier_allocation_workbench','CONFIRMED-SUPPLIER-ALLOCATION.v1',
    jsonb_build_object('date_start','2026-11-02','date_end','2026-11-02','school_ids',jsonb_build_array(second_school)));
  raise exception using errcode='PPR99';
exception when sqlstate 'PPR99' then return answer;
end;
$$;
insert into review_results values('shared_school',pg_temp.shared_school_read());
select is((select jsonb_array_length(response->'rows') from review_results where name='shared_school'),1,
  'a shared family is findable by its second School');
select is((select jsonb_array_length(response#>'{rows,0,schools}') from review_results where name='shared_school'),2,
  'a shared family retains both contributing Schools');
select is((select count(*) from atlas_procurement.school_catering_allocation_family_revisions),
  (select allocation_count from before_preview),'preview writes zero allocation revisions');
select is((select count(*) from atlas_planning.purchase_handoff_batches),
  (select handoff_count from before_preview),'preview writes zero Handoffs');
select is((select count(*) from atlas_procurement.purchase_orders),
  (select po_count from before_preview),'preview writes zero POs');
select is((select count(*) from atlas_core.command_receipts),
  (select receipt_count from before_preview),'preview writes zero receipts');
select is((select count(*) from atlas_audit.domain_events),
  (select event_count from before_preview),'preview writes zero acceptance events');
-- Historical source fixture only: D-042 retains retired batches, but they are
-- not active allocation sources. Restore before any command acceptance test.
set local session_replication_role=replica;
update atlas_planning.need_generation_runs set run_status='INVALIDATED',invalidated_at=transaction_timestamp(),
  invalidated_by_actor_id='b6000000-0000-0000-0000-000000000001'
  where need_generation_run_id=(select current_need_generation_run_id from atlas_planning.confirmed_need_batches
    where confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050');
set local session_replication_role=origin;
select is((select count(*) from atlas_core.purchase_review_confirmed_sources('2026-11-02','2026-11-02')),0::bigint,
  'retired generation batch is excluded from current allocation, without deleting its history');
set local session_replication_role=replica;
update atlas_planning.need_generation_runs set run_status='RELEASED_FOR_CONFIRMATION',invalidated_at=null,invalidated_by_actor_id=null
  where need_generation_run_id=(select current_need_generation_run_id from atlas_planning.confirmed_need_batches
    where confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050');
set local session_replication_role=origin;
-- Real Save commands, with triggers active and literal operator decisions.
create function pg_temp.review_command(contract text,reason text,version bigint,payload jsonb) returns jsonb
language sql volatile set search_path='' as $$
  select jsonb_build_object('contract_version',contract,'command_id',gen_random_uuid(),
    'correlation_id',gen_random_uuid(),'idempotency_key',gen_random_uuid()::text,'expected_version',version,
    'requested_by_auth_subject','b6000000-0000-0000-0000-000000000101',
    'requested_at',transaction_timestamp()-interval '1 second','reason_code',reason,'reason_note',null,'payload',payload);
$$;
create function pg_temp.review_invoke(api_name text,request jsonb) returns jsonb
language plpgsql set search_path='' as $$
declare result jsonb;
begin execute format('select atlas_api.%I($1)',api_name) into result using request; return result;
exception when undefined_function then return jsonb_build_object('missing_api',api_name); end;
$$;
create function pg_temp.need_save(quantity text) returns jsonb language sql volatile set search_path='' as $$
  select pg_temp.review_command('RMVP-05.v2','CONFIRMED_NEED_SAVED',b.version,jsonb_build_object(
    'confirmed_need_batch_id',b.confirmed_need_batch_id,'lines',(
      select jsonb_agg(jsonb_build_object('confirmed_need_line_id',l.confirmed_need_line_id,
        'expected_current_revision_id',r.confirmed_need_line_revision_id,
        'expected_current_decision_id',l.current_confirmed_need_line_decision_id,
        'proposed_confirmed_quantity',case when l.ingredient_id='b6500000-0000-0000-0000-000000000006' then quantity else '3.000000' end,
        'reason_code',case when l.ingredient_id='b6500000-0000-0000-0000-000000000006' then 'OPERATIONAL_QUANTITY_ADJUSTMENT' else 'PROPOSAL_ACCEPTED' end,
        'reason_note',case when l.ingredient_id='b6500000-0000-0000-0000-000000000006' then 'Manual paper correction' else null end))
      from atlas_planning.confirmed_need_lines l join atlas_planning.confirmed_need_line_revisions r
        on r.confirmed_need_line_id=l.confirmed_need_line_id and r.is_current
      where l.confirmed_need_batch_id=b.confirmed_need_batch_id and
        (l.ingredient_id='b6500000-0000-0000-0000-000000000006' or l.current_confirmed_need_line_decision_id is null))))
  from atlas_planning.confirmed_need_batches b where b.confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050';
$$;
create function pg_temp.allocation_request(row_data jsonb,qa text,qb text) returns jsonb language sql volatile set search_path='' as $$
  select pg_temp.review_command('CONFIRMED-SUPPLIER-ALLOCATION.v1','CONFIRMED_SUPPLIER_ALLOCATION_SAVED',
    (row_data#>>'{family,version}')::bigint,jsonb_build_object('family',jsonb_build_object(
      'service_date',row_data->'service_date','delivery_location_id',row_data->'delivery_location_id',
      'ingredient_id',row_data->'ingredient_id','unit_id',row_data->'unit_id',
      'expected_source_fingerprint',row_data#>'{family,source_fingerprint}',
      'expected_source_batch_id',row_data->'source_confirmed_need_batch_id',
      'expected_source_batch_version',row_data->'source_confirmed_need_batch_version'),
      'splits',jsonb_build_array(
        jsonb_build_object('supplier_id','c7100000-0000-4000-8000-000000000001','allocated_quantity',qa),
        jsonb_build_object('supplier_id','c7100000-0000-4000-8000-000000000002','allocated_quantity',qb))));
$$;
grant execute on function pg_temp.review_command(text,text,bigint,jsonb),pg_temp.review_invoke(text,jsonb),
  pg_temp.allocation_request(jsonb,text,text) to authenticated;
create temporary table command_requests(name text primary key,request jsonb);
grant select,insert on command_requests to authenticated;
create function pg_temp.confirmed_rebalance_case() returns jsonb language plpgsql as $$
declare before_row jsonb;after_row jsonb;first_result jsonb;second_result jsonb;answer jsonb;request jsonb;
begin
  request:=pg_temp.need_save('100.00');
  request:=jsonb_set(request,'{payload,lines}',(select jsonb_agg(value||jsonb_build_object('reason_code','PROPOSAL_ACCEPTED','reason_note',null))
    from jsonb_array_elements(request#>'{payload,lines}')));
  first_result:=atlas_api.save_confirmed_needs(request);
  select value into before_row from jsonb_array_elements(pg_temp.review_read('get_confirmed_supplier_allocation_workbench',
    'CONFIRMED-SUPPLIER-ALLOCATION.v1','{"date_start":"2026-11-02","date_end":"2026-11-02"}')->'rows')
    where value->>'ingredient_id'='b6500000-0000-0000-0000-000000000006';
  first_result:=atlas_api.save_confirmed_supplier_allocation(pg_temp.allocation_request(before_row,'60.00','40.00'));
  second_result:=atlas_api.save_confirmed_needs(pg_temp.need_save('120.00'));
  select value into after_row from jsonb_array_elements(pg_temp.review_read('get_confirmed_supplier_allocation_workbench',
    'CONFIRMED-SUPPLIER-ALLOCATION.v1','{"date_start":"2026-11-02","date_end":"2026-11-02"}')->'rows')
    where value->>'ingredient_id'='b6500000-0000-0000-0000-000000000006';
  answer:=jsonb_build_object('saved',first_result,'changed',second_result,'stale',after_row);
  raise exception using errcode='PPR99';
exception when sqlstate 'PPR99' then return answer;
end;
$$;
insert into review_results values('rebalance60_40',pg_temp.confirmed_rebalance_case());
select is((select response#>>'{saved,success}' from review_results where name='rebalance60_40'),'true','confirmed100 accepts explicit60/40');
select is((select response#>>'{changed,success}' from review_results where name='rebalance60_40'),'true','Planning can change100 to120 before commitment');
select is((select response#>>'{stale,state}' from review_results where name='rebalance60_40'),'STALE_REBALANCE_AVAILABLE','100 to120 stales60/40');
select is((select response#>>'{stale,splits,0,allocated_quantity}' from review_results where name='rebalance60_40'),'60.000000','stale decision retains60 until explicit Save');
select is((select response#>>'{stale,rebalance_proposal,0,allocated_quantity}' from review_results where name='rebalance60_40'),'72.000000','rebalance suggests72 without accepting it');
select is((select response#>>'{stale,rebalance_proposal,1,allocated_quantity}' from review_results where name='rebalance60_40'),'48.000000','rebalance suggests48 without accepting it');
insert into command_requests values('save120',pg_temp.need_save('120.00'));
set local role authenticated;
insert into review_results select 'incomplete_save',atlas_api.save_confirmed_supplier_allocation(
  pg_temp.allocation_request(line,'72.00','48.00')) from review_results,
  lateral jsonb_array_elements(response->'rows') line where name='incomplete'
  and line->>'ingredient_id'='b6500000-0000-0000-0000-000000000006';
reset role;
select is((select response->>'error_code' from review_results where name='incomplete_save'),
  'CONFIRMED_NEED_INCOMPLETE','Save rejects incomplete confirmed source without generated fallback');
set local role authenticated;
insert into review_results values('save120',atlas_api.save_confirmed_needs((select request from command_requests where name='save120')));
insert into review_results values('confirmed120',pg_temp.review_read('get_confirmed_supplier_allocation_workbench',
  'CONFIRMED-SUPPLIER-ALLOCATION.v1','{"date_start":"2026-11-02","date_end":"2026-11-02"}'));
insert into command_requests select 'allocate120',pg_temp.allocation_request(line,'72.00','48.00') from review_results,
  lateral jsonb_array_elements(response->'rows') line where name='confirmed120'
  and line->>'ingredient_id'='b6500000-0000-0000-0000-000000000006';
insert into review_results select 'invalid_'||variant.name,pg_temp.review_invoke('save_confirmed_supplier_allocation',
  variant.request||jsonb_build_object('command_id',gen_random_uuid(),'idempotency_key',gen_random_uuid()::text))
from command_requests original cross join lateral (values
  ('imbalance',jsonb_set(original.request,'{payload,splits,0,allocated_quantity}','"71.00"')),
  ('duplicate',jsonb_set(original.request,'{payload,splits,1,supplier_id}',original.request#>'{payload,splits,0,supplier_id}')),
  ('source',jsonb_set(original.request,'{payload,family,expected_source_fingerprint}','"old-source"')),
  ('batch_version',jsonb_set(original.request,'{payload,family,expected_source_batch_version}','99')),
  ('version',jsonb_set(original.request,'{expected_version}','99'))
) variant(name,request) where original.name='allocate120';
reset role;
create function pg_temp.review_negative_context(variant text) returns jsonb language plpgsql as $$
declare generated jsonb;confirmed jsonb;saved jsonb;answer jsonb;
begin
  if variant='ineligible' then
    update atlas_admin.supplier_eligibilities set eligibility_status='INACTIVE';
  elsif variant='tie' then
    -- Historical ambiguity is otherwise prevented by the active-priority index.
    -- The local subtransaction rolls back both DDL and seed changes before Save.
    drop index atlas_admin.supplier_eligibilities_active_priority_key;
    update atlas_admin.supplier_eligibilities set priority=1;
  elsif variant='scope' then
    update atlas_core.actor_scopes set scope_status='REVOKED'
      where actor_id='b6000000-0000-0000-0000-000000000001';
  end if;
  generated:=pg_temp.review_read('get_generated_purchase_review','PURCHASE-REVIEW.v1','{"service_date":"2026-11-02"}');
  confirmed:=pg_temp.review_read('get_confirmed_supplier_allocation_workbench','CONFIRMED-SUPPLIER-ALLOCATION.v1',
    '{"date_start":"2026-11-02","date_end":"2026-11-02"}');
  if variant<>'tie' then
    saved:=atlas_api.save_confirmed_supplier_allocation((select request from command_requests where name='allocate120'));
  end if;
  answer:=jsonb_build_object('generated',generated,'confirmed',confirmed,'saved',saved);
  raise exception using errcode='PPR99';
exception when sqlstate 'PPR99' then return answer;
end;
$$;
insert into review_results values('context_ineligible',pg_temp.review_negative_context('ineligible')),
  ('context_tie',pg_temp.review_negative_context('tie')),('context_scope',pg_temp.review_negative_context('scope'));
select ok((select bool_and(line->'recommendation'='null'::jsonb and line->'warnings' ? 'NO_ELIGIBLE_SUPPLIER')
  from review_results,lateral jsonb_array_elements(response#>'{generated,rows}') line where name='context_ineligible'),
  'no eligible supplier remains unresolved in generated review');
select ok((select bool_and(line->'recommendation'='null'::jsonb and line->'warnings' ? 'AMBIGUOUS_SUPPLIER_PRIORITY')
  from review_results,lateral jsonb_array_elements(response#>'{generated,rows}') line where name='context_tie'),
  'tied supplier priority remains unresolved rather than choosing arbitrarily');
select is((select response#>>'{saved,error_code}' from review_results where name='context_ineligible'),'SUPPLIER_INELIGIBLE',
  'confirmed Save rechecks effective supplier eligibility');
select is((select jsonb_array_length(response#>'{generated,rows}') from review_results where name='context_scope'),0,
  'generated read leaks no out-of-scope rows');
select is((select jsonb_array_length(response#>'{confirmed,rows}') from review_results where name='context_scope'),0,
  'confirmed allocation read leaks no out-of-scope rows');
select is((select response#>>'{saved,error_code}' from review_results where name='context_scope'),'SCOPE_DENIED',
  'confirmed allocation Save independently denies out-of-scope source');
set local role authenticated;
insert into review_results values('allocate120',pg_temp.review_invoke('save_confirmed_supplier_allocation',
  (select request from command_requests where name='allocate120')));
insert into review_results values('replay120',pg_temp.review_invoke('save_confirmed_supplier_allocation',
  (select request from command_requests where name='allocate120')));
reset role;
select is((select response->>'success' from review_results where name='save120'),'true','Planning saves confirmed120');
select is((select response->>'error_code' from review_results where name='invalid_imbalance'),'ALLOCATION_IMBALANCED','confirmed allocation rejects imbalance');
select is((select response->>'error_code' from review_results where name='invalid_duplicate'),'DUPLICATE_SUPPLIER','confirmed allocation rejects duplicate Supplier');
select is((select response->>'error_code' from review_results where name='invalid_source'),'SOURCE_CHANGED','confirmed allocation rejects stale fingerprint');
select is((select response->>'error_code' from review_results where name='invalid_batch_version'),'SOURCE_CHANGED','confirmed allocation rejects stale source batch version');
select is((select response->>'error_code' from review_results where name='invalid_version'),'STALE_VERSION','confirmed allocation rejects stale expected version');
select diag(response::text) from review_results where name='save120' and response->>'success'<>'true';
select is((select line->>'family_quantity' from review_results,lateral jsonb_array_elements(response->'rows') line
  where name='confirmed120' and line->>'ingredient_id'='b6500000-0000-0000-0000-000000000006'),
  '120.000000','allocation reads saved120, not generated100');
select is((select response->>'success' from review_results where name='allocate120'),'true','explicit72/48 is accepted');
select is((select response#>>'{family,source_kind}' from review_results where name='allocate120'),'CONFIRMED_NEED','allocation retains pre-Handoff authority');
select is((select sum(s.allocated_quantity) from atlas_procurement.school_catering_allocation_supplier_splits s
  where s.family_revision_id=(select (response#>>'{family,family_revision_id}')::uuid from review_results where name='allocate120')),
  120::numeric,'persisted exact split sum is120');
select is((select response from review_results where name='replay120'),(select response from review_results where name='allocate120'),'exact Save replay returns original durable result');
set local role authenticated;
insert into review_results values('conflicting_replay',atlas_api.save_confirmed_supplier_allocation(
  (select jsonb_set(request,'{payload,splits,0,allocated_quantity}','"73"') from command_requests where name='allocate120')));
reset role;
select is((select response->>'error_code' from review_results where name='conflicting_replay'),'IDEMPOTENCY_CONFLICT',
  'same allocation command identity with changed splits conflicts');
select is((select count(*) from atlas_planning.purchase_handoff_batches),(select handoff_count from before_preview),'confirmed allocation creates no Handoff');
select is((select count(*) from atlas_procurement.purchase_orders),(select po_count from before_preview),'confirmed allocation creates no official PO');
select throws_ok($test$do $body$ begin
  insert into atlas_procurement.school_catering_allocation_family_revisions
    select (jsonb_populate_record(null::atlas_procurement.school_catering_allocation_family_revisions,
      to_jsonb(r)||jsonb_build_object('family_revision_id',gen_random_uuid(),'revision_number',99,'is_current',false))).*
    from atlas_procurement.school_catering_allocation_family_revisions r where r.is_current limit 1;
  set constraints all immediate;
end $body$;$test$,'23514','Allocation evidence must match its typed source and exact totals.',
  'incomplete allocation evidence cannot commit even through direct backend insertion');
set local role authenticated;
insert into review_results values('no_handoff_drafts',atlas_api.create_school_catering_purchase_order_drafts(pg_temp.review_command(
  'SCHOOL-CATERING-PROCUREMENT.v1','SCHOOL_CATERING_PO_DRAFTS_CREATED',1,'{"date_start":"2026-11-02","date_end":"2026-11-02"}')));
reset role;
select is((select count(*) from atlas_procurement.purchase_orders),(select po_count from before_preview),'confirmed-only allocation never creates official drafts');
insert into command_requests values('save125',pg_temp.need_save('125.00'));
set local role authenticated;
insert into review_results values('save125',atlas_api.save_confirmed_needs((select request from command_requests where name='save125')));
insert into review_results values('stale125',pg_temp.review_read('get_confirmed_supplier_allocation_workbench',
  'CONFIRMED-SUPPLIER-ALLOCATION.v1','{"date_start":"2026-11-02","date_end":"2026-11-02"}'));
insert into review_results values('blocked_release',atlas_api.release_confirmed_needs(pg_temp.review_command(
  'RMVP-07.v2','CONFIRMED_NEED_RELEASED',3,'{"confirmed_need_batch_id":"b6500000-0000-0000-0000-000000000050"}')));
reset role;
select is((select response->>'success' from review_results where name='save125'),'true','Planning may correct saved120 to125 before Handoff');
select is((select line->>'state' from review_results,lateral jsonb_array_elements(response->'rows') line
  where name='stale125' and line->>'ingredient_id'='b6500000-0000-0000-0000-000000000006'),
  'STALE_REBALANCE_AVAILABLE','source change marks allocation stale');
select is((select sum(s.allocated_quantity) from atlas_procurement.school_catering_allocation_supplier_splits s
  where s.family_revision_id=(select (response#>>'{family,family_revision_id}')::uuid from review_results where name='allocate120')),
  120::numeric,'stale72/48 remains immutable history');
select is((select response->>'error_code' from review_results where name='blocked_release'),'CONFIRMED_ALLOCATION_NOT_READY',
  'Planning commitment fails closed on stale and missing allocation');
select is((select batch_status from atlas_planning.confirmed_need_batches where confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050'),
  'DRAFT_REVIEW','blocked commitment leaves Planning editable');
set local role authenticated;
insert into command_requests select 'allocate125',pg_temp.allocation_request(line,'75.00','50.00') from review_results,
  lateral jsonb_array_elements(response->'rows') line where name='stale125'
  and line->>'ingredient_id'='b6500000-0000-0000-0000-000000000006';
insert into command_requests select 'allocate_beans',pg_temp.allocation_request(line,'1.00','2.00') from review_results,
  lateral jsonb_array_elements(response->'rows') line where name='stale125'
  and line->>'ingredient_id'='b6500000-0000-0000-0000-000000000007';
insert into review_results values('precision',pg_temp.review_invoke('save_confirmed_supplier_allocation',
  (select jsonb_set(jsonb_set(request,'{payload,splits,0,allocated_quantity}','"75.0000004"'),
    '{payload,splits,1,allocated_quantity}','"49.9999996"') || jsonb_build_object(
      'command_id',gen_random_uuid(),'idempotency_key',gen_random_uuid()::text)
    from command_requests where name='allocate125')));
reset role;
select is((select response->>'error_code' from review_results where name='precision'),'INVALID_SPLIT_PRECISION',
  'operator quantities are never silently rounded to six places');
set local role authenticated;
insert into review_results values('allocate125',pg_temp.review_invoke('save_confirmed_supplier_allocation',
  (select request from command_requests where name='allocate125')));
insert into review_results values('allocate_beans',pg_temp.review_invoke('save_confirmed_supplier_allocation',
  (select request from command_requests where name='allocate_beans')));
reset role;
create function pg_temp.test_released_allocation_recovery() returns jsonb language plpgsql set search_path='' as $$
declare result jsonb;row_data jsonb;
begin
  result:=atlas_api.release_confirmed_needs(pg_temp.review_command('RMVP-07.v2','CONFIRMED_NEED_RELEASED',3,
    '{"confirmed_need_batch_id":"b6500000-0000-0000-0000-000000000050"}'));
  if result->>'success'='true' then
    select value into row_data from jsonb_array_elements(pg_temp.review_read('get_confirmed_supplier_allocation_workbench',
      'CONFIRMED-SUPPLIER-ALLOCATION.v1','{"date_start":"2026-11-02","date_end":"2026-11-02"}')->'rows')
      where value->>'ingredient_id'='b6500000-0000-0000-0000-000000000006';
    result:=atlas_api.save_confirmed_supplier_allocation(pg_temp.allocation_request(row_data,'75.00','50.00'));
  end if;
  raise exception using errcode='PPR99';
exception when sqlstate 'PPR99' then return result;
end;
$$;
grant execute on function pg_temp.test_released_allocation_recovery() to authenticated;
set local role authenticated;
insert into review_results values('released_recovery',pg_temp.test_released_allocation_recovery());
reset role;
select is((select response->>'success' from review_results where name='released_recovery'),'true',
  'released-before-Handoff source supports explicit allocation recovery without reopening Need');

-- MC-Q04: catch a preparation implementation that leaves its successful release
-- or Handoff/promotion children committed when the final PO write fails.
create function pg_temp.preparation_business_snapshot() returns jsonb
language sql stable set search_path='' as $$
  select jsonb_build_object(
    'batch', (select to_jsonb(b) from atlas_planning.confirmed_need_batches b
      where confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050'),
    'releases', (select jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text)
      from atlas_planning.confirmed_need_releases r),
    'approvals', (select jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text)
      from atlas_planning.confirmed_need_approval_snapshots r),
    'need_snapshot_lines', (select jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text)
      from atlas_planning.confirmed_need_snapshot_lines r),
    'handoffs', (select jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text)
      from atlas_planning.purchase_handoff_batches r),
    'handoff_revisions', (select jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text)
      from atlas_planning.purchase_handoff_revisions r),
    'handoff_lines', (select jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text)
      from atlas_planning.purchase_handoff_lines r),
    'handoff_line_revisions', (select jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text)
      from atlas_planning.purchase_handoff_line_revisions r),
    'allocation_families', (select jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text)
      from atlas_procurement.school_catering_allocation_families r),
    'allocations', (select jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text)
      from atlas_procurement.school_catering_allocation_family_revisions r),
    'allocation_contributions', (select jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text)
      from atlas_procurement.school_catering_allocation_family_contributions r),
    'splits', (select jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text)
      from atlas_procurement.school_catering_allocation_supplier_splits r),
    'orders', (select jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text)
      from atlas_procurement.purchase_orders r),
    'order_revisions', (select jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text)
      from atlas_procurement.purchase_order_revisions r),
    'order_lines', (select jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text)
      from atlas_procurement.purchase_order_lines r),
    'order_line_revisions', (select jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text)
      from atlas_procurement.purchase_order_line_revisions r),
    'events', (select jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text)
      from atlas_audit.domain_events r),
    'audit', (select jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text)
      from atlas_audit.audit_events r)
  );
$$;
create temporary table before_failed_preparation as select
  pg_temp.preparation_business_snapshot() as business_snapshot,
  (select count(*) from atlas_core.command_receipts) as receipt_count;
-- Sequence advancement survives the command's subtransaction rollback, proving
-- the failure reached the PO child rather than an earlier validation branch.
create temporary sequence preparation_po_attempt minvalue 0 start 0;
create function pg_temp.reject_preparation_po() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  perform nextval('pg_temp.preparation_po_attempt'::regclass);
  raise exception using errcode='PPR98', message='Synthetic final PO write failure';
end;
$$;
create trigger convergence_reject_preparation_po
  before insert on atlas_procurement.purchase_orders
  for each row execute function pg_temp.reject_preparation_po();
set local role authenticated;
insert into command_requests values('prepare-child-failure',pg_temp.review_command(
  'PURCHASE-COMMITMENT.v1','PURCHASE_ORDERS_PREPARED',3,
  '{"confirmed_need_batch_id":"b6500000-0000-0000-0000-000000000050","service_date":"2026-11-02"}'));
insert into review_results values('prepare-child-failure',
  pg_temp.review_invoke('prepare_school_catering_purchase_orders',
    (select request from command_requests where name='prepare-child-failure')));
reset role;
drop trigger convergence_reject_preparation_po on atlas_procurement.purchase_orders;
select ok((select is_called from preparation_po_attempt),
  'MC-Q04 final PO write was reached before the injected failure');
select is((select response->>'success' from review_results where name='prepare-child-failure'),
  'false','MC-Q04 failed PO child is not a successful preparation');
select is(pg_temp.preparation_business_snapshot(),
  (select business_snapshot from before_failed_preparation),
  'MC-Q04 failed PO child rolls back release, Handoff, promotion, PO and audit evidence');
select is((select count(*) from atlas_core.command_receipts where command_id <>
  (select (request->>'command_id')::uuid from command_requests where name='prepare-child-failure')),
  (select receipt_count from before_failed_preparation),
  'MC-Q04 failed preparation retains no child receipt or accepted child command');

set local role authenticated;
insert into command_requests values('prepare',pg_temp.review_command('PURCHASE-COMMITMENT.v1',
  'PURCHASE_ORDERS_PREPARED',3,'{"confirmed_need_batch_id":"b6500000-0000-0000-0000-000000000050","service_date":"2026-11-02"}'));
insert into review_results values('prepare',pg_temp.review_invoke('prepare_school_catering_purchase_orders',
  (select request from command_requests where name='prepare')));
insert into review_results values('prepare_replay',pg_temp.review_invoke('prepare_school_catering_purchase_orders',
  (select request from command_requests where name='prepare')));
insert into review_results select 'release125',response->'planning_release' from review_results where name='prepare';
insert into review_results select 'handoff125',response->'handoff' from review_results where name='prepare';
insert into review_results values('promoted_read',pg_temp.review_read('get_confirmed_supplier_allocation_workbench',
  'CONFIRMED-SUPPLIER-ALLOCATION.v1','{"date_start":"2026-11-02","date_end":"2026-11-02"}'));
reset role;
select is((select response->>'success' from review_results where name='prepare'),'true','one atomic preparation command reaches official drafts');
-- Historical aggregate may contain contributions from more than one Handoff.
-- Source seeding is isolated and rolled back; allocation inserts/guards run normally.
create function pg_temp.multi_handoff_history() returns text language plpgsql as $$
declare original uuid;second_header uuid:=gen_random_uuid();second_batch uuid:=gen_random_uuid();
  second_line uuid:=gen_random_uuid();second_line_revision uuid:=gen_random_uuid();
  revision uuid:=gen_random_uuid();candidate record;outcome text;
begin
  select r.* into strict candidate from atlas_procurement.school_catering_allocation_family_revisions r
    join atlas_procurement.school_catering_allocation_families f using(family_id)
    where r.is_current and f.ingredient_id='b6500000-0000-0000-0000-000000000006';
  original:=candidate.family_revision_id;
  set local session_replication_role=replica;
  insert into atlas_planning.purchase_handoff_batches
    select (jsonb_populate_record(null::atlas_planning.purchase_handoff_batches,to_jsonb(b)||jsonb_build_object(
      'purchase_handoff_batch_id',second_batch,'confirmed_need_batch_id',gen_random_uuid()))).*
    from atlas_planning.purchase_handoff_batches b join atlas_planning.purchase_handoff_revisions h using(purchase_handoff_batch_id)
    where h.purchase_handoff_revision_id=candidate.source_purchase_handoff_revision_id;
  insert into atlas_planning.purchase_handoff_revisions
    select (jsonb_populate_record(null::atlas_planning.purchase_handoff_revisions,to_jsonb(h)||jsonb_build_object(
      'purchase_handoff_revision_id',second_header,'purchase_handoff_batch_id',second_batch))).*
    from atlas_planning.purchase_handoff_revisions h where h.purchase_handoff_revision_id=candidate.source_purchase_handoff_revision_id;
  insert into atlas_planning.purchase_handoff_lines
    select (jsonb_populate_record(null::atlas_planning.purchase_handoff_lines,to_jsonb(l)||jsonb_build_object(
      'purchase_handoff_line_id',second_line,'purchase_handoff_batch_id',second_batch,'confirmed_need_line_id',gen_random_uuid()))).*
    from atlas_planning.purchase_handoff_lines l join atlas_planning.purchase_handoff_line_revisions h using(purchase_handoff_line_id)
    join atlas_procurement.school_catering_allocation_family_contributions c using(purchase_handoff_line_revision_id)
    where c.family_revision_id=original limit 1;
  insert into atlas_planning.purchase_handoff_line_revisions
    select (jsonb_populate_record(null::atlas_planning.purchase_handoff_line_revisions,to_jsonb(h)||jsonb_build_object(
      'purchase_handoff_line_revision_id',second_line_revision,'purchase_handoff_line_id',second_line,
      'purchase_handoff_revision_id',second_header))).*
    from atlas_planning.purchase_handoff_line_revisions h join atlas_procurement.school_catering_allocation_family_contributions c using(purchase_handoff_line_revision_id)
    where c.family_revision_id=original limit 1;
  set local session_replication_role=origin;
  insert into atlas_procurement.school_catering_allocation_family_revisions
    select (jsonb_populate_record(null::atlas_procurement.school_catering_allocation_family_revisions,to_jsonb(candidate)||jsonb_build_object(
      'family_revision_id',revision,'revision_number',99,'is_current',false,'family_quantity',candidate.family_quantity*2,
      'source_purchase_handoff_revision_id',least(candidate.source_purchase_handoff_revision_id,second_header)))).*;
  insert into atlas_procurement.school_catering_allocation_family_contributions(family_revision_id,purchase_handoff_line_revision_id,contribution_quantity)
    select revision,purchase_handoff_line_revision_id,contribution_quantity from atlas_procurement.school_catering_allocation_family_contributions where family_revision_id=original;
  insert into atlas_procurement.school_catering_allocation_family_contributions(family_revision_id,purchase_handoff_line_revision_id,contribution_quantity)
    values(revision,second_line_revision,candidate.family_quantity);
  insert into atlas_procurement.school_catering_allocation_supplier_splits
    select (jsonb_populate_record(null::atlas_procurement.school_catering_allocation_supplier_splits,to_jsonb(s)||jsonb_build_object(
      'supplier_split_id',gen_random_uuid(),'family_revision_id',revision,'allocated_quantity',s.allocated_quantity*2))).*
    from atlas_procurement.school_catering_allocation_supplier_splits s where family_revision_id=original;
  set constraints all immediate;
  outcome:='accepted';raise exception using errcode='PPR99';
exception when sqlstate 'PPR99' then return outcome; when others then return sqlstate||':'||sqlerrm;
end;
$$;
select is(pg_temp.multi_handoff_history(),'accepted','historical multi-Handoff family retains plural exact lineage');
create function pg_temp.extra_po_line_coverage() returns boolean language plpgsql as $$
declare answer boolean;
begin
  set local session_replication_role=replica;
  insert into atlas_procurement.purchase_order_line_revisions
    select (jsonb_populate_record(null::atlas_procurement.purchase_order_line_revisions,to_jsonb(l)||jsonb_build_object(
      'purchase_order_line_revision_id',gen_random_uuid(),'purchase_order_line_id',gen_random_uuid(),
      'school_catering_allocation_supplier_split_id',gen_random_uuid()))).*
    from atlas_procurement.purchase_order_line_revisions l
    join atlas_procurement.purchase_order_revisions r using(purchase_order_revision_id)
    where r.is_current and l.service_date='2026-11-02' limit 1;
  set local session_replication_role=origin;
  answer:=atlas_core.purchase_review_po_coverage('2026-11-02');
  raise exception using errcode='PPR99';
exception when sqlstate 'PPR99' then return answer;
end;
$$;
select is(pg_temp.extra_po_line_coverage(),false,'preparation rejects extra PO lines outside the current saved split set');
select is((select response from review_results where name='prepare_replay'),
  (select response from review_results where name='prepare'),'preparation replays the complete durable result');
select ok((select bool_and(line->>'school_name' is not null) from review_results,
  lateral jsonb_array_elements(response->'rows') line where name='promoted_read'),
  'promoted allocation retains School evidence');
select is((select response->>'success' from review_results where name='allocate125'),'true','operator explicitly saves75/50');
select is((select response->>'success' from review_results where name='allocate_beans'),'true','all positive families explicitly allocated');
select is((select response->>'success' from review_results where name='release125'),'true','complete current allocation allows Planning release');
select is((select response->>'success' from review_results where name='handoff125'),'true','real Handoff and promotion succeed');
select is((select r.source_kind from atlas_procurement.school_catering_allocation_family_revisions r
  where r.family_id=(select (response#>>'{family,family_id}')::uuid from review_results where name='allocate125') and r.is_current),
  'PURCHASE_HANDOFF','Handoff appends committed successor');
select is((select r.predecessor_revision_id from atlas_procurement.school_catering_allocation_family_revisions r
  where r.family_id=(select (response#>>'{family,family_id}')::uuid from review_results where name='allocate125') and r.is_current),
  (select (response#>>'{family,family_revision_id}')::uuid from review_results where name='allocate125'),'confirmed predecessor retained');
select is((select sum(s.allocated_quantity) from atlas_procurement.school_catering_allocation_supplier_splits s
  join atlas_procurement.school_catering_allocation_family_revisions r using(family_revision_id)
  where r.family_id=(select (response#>>'{family,family_id}')::uuid from review_results where name='allocate125') and r.is_current),
  125::numeric,'promotion preserves exact125 without rebalance');
set local role authenticated;
insert into review_results values('drafts',atlas_api.create_school_catering_purchase_order_drafts(pg_temp.review_command(
  'SCHOOL-CATERING-PROCUREMENT.v1','SCHOOL_CATERING_PO_DRAFTS_CREATED',1,'{"date_start":"2026-11-02","date_end":"2026-11-02"}')));
reset role;
select is((select response->>'success' from review_results where name='drafts'),'true','official drafts consume Handoff successors');
select is((select sum(l.ordered_quantity) from atlas_procurement.purchase_orders po
  join atlas_procurement.purchase_order_revisions r using(purchase_order_id)
  join atlas_procurement.purchase_order_line_revisions l using(purchase_order_revision_id)
  where po.supplier_id='c7100000-0000-4000-8000-000000000001' and r.is_current
    and l.ingredient_id='b6500000-0000-0000-0000-000000000006'),75::numeric,'supplier A PO preserves75');
select is((select sum(l.ordered_quantity) from atlas_procurement.purchase_orders po
  join atlas_procurement.purchase_order_revisions r using(purchase_order_id)
  join atlas_procurement.purchase_order_line_revisions l using(purchase_order_revision_id)
  where po.supplier_id='c7100000-0000-4000-8000-000000000002' and r.is_current
    and l.ingredient_id='b6500000-0000-0000-0000-000000000006'),50::numeric,'supplier B PO preserves50');
insert into command_requests select 'release-po-'||po.supplier_id::text,pg_temp.review_command(
  'SCHOOL-CATERING-PROCUREMENT.v1','SCHOOL_CATERING_PO_RELEASED',po.version,
  jsonb_build_object('purchase_order_id',po.purchase_order_id,'expected_purchase_order_revision_id',r.purchase_order_revision_id))
  from atlas_procurement.purchase_orders po join atlas_procurement.purchase_order_revisions r using(purchase_order_id)
  where po.school_catering_service_date='2026-11-02' and r.is_current;
set local role authenticated;
insert into review_results select name,atlas_api.release_school_catering_purchase_order(request)
  from command_requests where name like 'release-po-%';
reset role;
select is((select count(*) from review_results where name like 'release-po-%' and response->>'success'='true'),2::bigint,'both supplier POs release');
select is((select count(*) from atlas_procurement.purchase_orders where school_catering_service_date='2026-11-02'
  and purchase_order_status='RELEASED_TO_SUPPLIER' and document_number like 'PO-20261102-%'),2::bigint,'official numbers are backend generated');
create temporary table released_snapshot as select to_jsonb(r) as revision,to_jsonb(l) as line
  from atlas_procurement.purchase_order_revisions r join atlas_procurement.purchase_order_line_revisions l using(purchase_order_revision_id)
  where r.is_current and r.revision_status='RELEASED_TO_SUPPLIER';
create function pg_temp.legacy_handoff_read() returns jsonb language plpgsql as $$
declare answer jsonb;
begin
  set local session_replication_role=replica;
  update atlas_planning.need_generation_runs set run_status='INVALIDATED',invalidated_at=transaction_timestamp(),
    invalidated_by_actor_id='b6000000-0000-0000-0000-000000000001'
    where need_generation_run_id=(select current_need_generation_run_id from atlas_planning.confirmed_need_batches
      where confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050');
  set local session_replication_role=origin;
  answer:=pg_temp.review_read('get_confirmed_supplier_allocation_workbench','CONFIRMED-SUPPLIER-ALLOCATION.v1',
    '{"date_start":"2026-11-02","date_end":"2026-11-02"}');
  raise exception using errcode='PPR99';
exception when sqlstate 'PPR99' then return answer;
end;
$$;
insert into review_results values('legacy_handoff',pg_temp.legacy_handoff_read());
select is((select jsonb_array_length(response->'rows') from review_results where name='legacy_handoff'),2,
  'current legacy Handoff rows remain visible when no active generated source exists');
select ok((select bool_and(line#>>'{family,source_kind}'='PURCHASE_HANDOFF') from review_results,
  lateral jsonb_array_elements(response->'rows') line where name='legacy_handoff'),'legacy rows retain Handoff authority');
-- Existing Handoff with later ineligible supplier: child draft API skips the
-- date, which must never be reported as successful commitment preparation.
update atlas_admin.supplier_eligibilities set eligibility_status='INACTIVE'
  where supplier_id='c7100000-0000-4000-8000-000000000001';
set local role authenticated;
insert into review_results values('ineligible_prepare',pg_temp.review_invoke('prepare_school_catering_purchase_orders',
  pg_temp.review_command('PURCHASE-COMMITMENT.v1','PURCHASE_ORDERS_PREPARED',6,
    '{"confirmed_need_batch_id":"b6500000-0000-0000-0000-000000000050","service_date":"2026-11-02"}')));
reset role;
select is((select response->>'success' from review_results where name='ineligible_prepare'),'false',
  'skipped unready PO date cannot become successful preparation');
select is((select jsonb_agg(jsonb_build_array(revision,line) order by line->>'purchase_order_line_revision_id') from released_snapshot),
  (select jsonb_agg(jsonb_build_array(to_jsonb(r),to_jsonb(l)) order by l.purchase_order_line_revision_id::text)
   from atlas_procurement.purchase_order_revisions r join atlas_procurement.purchase_order_line_revisions l using(purchase_order_revision_id)
   where r.is_current and r.revision_status='RELEASED_TO_SUPPLIER'),
  'eligibility changes and blocked preparation never rewrite released PO snapshots');
set constraints all immediate;
select * from finish();
rollback;
