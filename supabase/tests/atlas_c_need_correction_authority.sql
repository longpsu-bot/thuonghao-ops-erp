-- C K1: public authenticated correction, normal RLS and deferred guards.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=extensions,public,pg_catalog;
set local statement_timeout='8s';
select no_plan();
select ok(has_function_privilege('atlas_confirmed_need_review_runtime',
 'atlas_core.planning_contract_01_preflight_payload(date,date,jsonb)','EXECUTE')
 and not exists(select 1 from unnest(array['anon','authenticated','service_role']) role_name
 where has_function_privilege(role_name,
 'atlas_core.planning_contract_01_preflight_payload(date,date,jsonb)','EXECUTE')),
 'K1 repair grants private preflight execution only to the existing Need runtime');
\ir ../local/purchase_review_confirm_release_fixture.sql

-- Key-only access permits locking, never source business writes or key writes.
select ok(has_column_privilege('atlas_confirmed_need_review_runtime',
  'atlas_planning.'||relation_name,key_name,'SELECT')
  and has_column_privilege('atlas_confirmed_need_review_runtime',
    'atlas_planning.'||relation_name,key_name,'UPDATE')
  and not has_table_privilege('atlas_confirmed_need_review_runtime',
    'atlas_planning.'||relation_name,'SELECT')
  and not has_table_privilege('atlas_confirmed_need_review_runtime',
    'atlas_planning.'||relation_name,'UPDATE')
  and not has_column_privilege('atlas_confirmed_need_review_runtime',
    'atlas_planning.'||relation_name,'version','UPDATE'),
  'K1 source lock access is key-only: '||relation_name)
from (values('weekly_menus','weekly_menu_id'),
  ('attendance_batches','attendance_batch_id'),
  ('pantry_need_batches','pantry_need_batch_id')) roots(relation_name,key_name);
create function pg_temp.k1_source_write_attempt(relation_name text,key_name text)
returns text language plpgsql set search_path='' as $$
begin
  set local role atlas_confirmed_need_review_runtime;
  execute format('update atlas_planning.%I set %I=%I',relation_name,key_name,key_name);
  reset role;
  return 'WRITE_ALLOWED';
exception when insufficient_privilege then return sqlstate;
end $$;
select is(pg_temp.k1_source_write_attempt(relation_name,key_name),'42501',
  'K1 forced RLS rejects even source key self-update: '||relation_name)
from (values('weekly_menus','weekly_menu_id'),
  ('attendance_batches','attendance_batch_id'),
  ('pantry_need_batches','pantry_need_batch_id')) roots(relation_name,key_name);

insert into atlas_core.role_capabilities(role_id,capability_id)
select 'b6000000-0000-0000-0000-000000000003',capability_id
from atlas_core.capabilities where capability_code in (
  'planning.need_generation.write','confirmed_need_release.release',
  'dispatch.school_release.read','dispatch.school_release.release')
on conflict do nothing;

create temporary table k1_results(name text primary key,response jsonb not null);
create temporary table k1_requests(name text primary key,request jsonb not null);
grant select,insert on k1_results,k1_requests to authenticated;

create function pg_temp.k1_command(contract text,reason text,version bigint,payload jsonb)
returns jsonb language sql volatile set search_path='' as $$
  select jsonb_build_object('contract_version',contract,'command_id',id,
    'correlation_id',gen_random_uuid(),'idempotency_key','c-k1:'||id,
    'expected_version',version,
    'requested_by_auth_subject','b6000000-0000-0000-0000-000000000101',
    'requested_at',transaction_timestamp()-interval '1 second',
    'reason_code',reason,'reason_note',null,'payload',payload)
  from (select gen_random_uuid() id) command;
$$;
grant execute on function pg_temp.k1_command(text,text,bigint,jsonb) to authenticated;

-- K3 reads are advisory only: the unchanged writer must recheck every fact.
create function pg_temp.k3_review(target uuid default 'b6500000-0000-0000-0000-000000000050')
returns jsonb language plpgsql set search_path='' as $$
declare response jsonb; prior_subject text:=current_setting('request.jwt.claim.sub',true);
begin
  set local role authenticated;
  perform set_config('request.jwt.claim.sub','b6000000-0000-0000-0000-000000000101',true);
  response:=atlas_api.get_confirmed_need_review(jsonb_build_object(
    'contract_version','RMVP-05.v1',
    'requested_by_auth_subject','b6000000-0000-0000-0000-000000000101',
    'correlation_id',gen_random_uuid(),'payload',jsonb_build_object(
      'confirmed_need_batch_id',target,'filters','{}'::jsonb,
      'line_offset',0,'line_limit',10000)));
  reset role;
  perform set_config('request.jwt.claim.sub',coalesce(prior_subject,''),true);
  return response;
end $$;
select is(pg_temp.k3_review()#>>'{workbench,allowed_actions,correct_released_confirmed_needs}',
  'false','K3 ordinary unissued batch has no post-release correction action');
select is(pg_temp.k3_review()#>>'{workbench,allowed_actions,save_confirmed_needs}',
  'true','K3 ordinary editable v2 Save remains available');

-- Initial human confirmation and transfer use the installed public commands.
insert into k1_requests
select 'initial_save',pg_temp.k1_command('RMVP-05.v2','CONFIRMED_NEED_SAVED',b.version,
  jsonb_build_object('confirmed_need_batch_id',b.confirmed_need_batch_id,'lines',(
    select jsonb_agg(jsonb_build_object(
      'confirmed_need_line_id',l.confirmed_need_line_id,
      'expected_current_revision_id',r.confirmed_need_line_revision_id,
      'expected_current_decision_id',l.current_confirmed_need_line_decision_id,
      'proposed_confirmed_quantity',r.confirmed_quantity::text,
      'reason_code','PROPOSAL_ACCEPTED','reason_note',null)
      order by l.confirmed_need_line_id)
    from atlas_planning.confirmed_need_lines l
    join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
    where l.confirmed_need_batch_id=b.confirmed_need_batch_id and r.is_current)))
from atlas_planning.confirmed_need_batches b
where b.confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050';
set local role authenticated;
select set_config('request.jwt.claim.sub','b6000000-0000-0000-0000-000000000101',true);
insert into k1_results select 'initial_save',atlas_api.save_confirmed_needs(request)
from k1_requests where name='initial_save';
reset role;
select is((select response->>'success' from k1_results where name='initial_save'),
  'true','K1 prerequisite: public editable Save succeeds');

insert into k1_requests
select 'initial_prepare',pg_temp.k1_command('PURCHASE-COMMITMENT.v1',
  'PURCHASE_ORDERS_PREPARED',version,jsonb_build_object(
    'confirmed_need_batch_id',confirmed_need_batch_id,'service_date','2026-11-02'))
from atlas_planning.confirmed_need_batches
where confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050';
set local role authenticated;
insert into k1_results select 'initial_prepare',
  atlas_api.prepare_school_catering_purchase_orders(request)
from k1_requests where name='initial_prepare';
reset role;
select is((select response->>'success' from k1_results where name='initial_prepare'),
  'true','K1 prerequisite: public Preparation releases Need and real Handoff');

-- Real issued documents precede the correction; K1 must retain every byte.
update atlas_admin.schools set dispatch_document_issuer_name='K1 disposable issuer',
  dispatch_document_issuer_address='K1 disposable address'
where school_id='b6500000-0000-0000-0000-000000000004';
insert into k1_requests
select 'initial_po',pg_temp.k1_command('SCHOOL-CATERING-PROCUREMENT.v1',
  'SCHOOL_CATERING_PO_RELEASED',po.version,jsonb_build_object(
    'purchase_order_id',po.purchase_order_id,
    'expected_purchase_order_revision_id',revision.purchase_order_revision_id))
from atlas_procurement.purchase_orders po
join atlas_procurement.purchase_order_revisions revision using(purchase_order_id)
where po.school_catering_service_date='2026-11-02' and revision.is_current;
set local role authenticated;
insert into k1_results select 'initial_po',atlas_api.release_school_catering_purchase_order(request)
from k1_requests where name='initial_po';
reset role;
select is((select response->>'success' from k1_results where name='initial_po'),
  'true','K1 prerequisite: real public Supplier PO release');
create temporary table k3_released_read as select pg_temp.k3_review() response;
select is((select response#>>'{workbench,allowed_actions,correct_released_confirmed_needs}'
  from k3_released_read),'true','K3 authenticated released batch permits explicit v3 correction');
select is((select response#>'{workbench,disabled_reason_codes,correct_released_confirmed_needs}'
  from k3_released_read),'null'::jsonb,'K3 eligible action has no disabled reason');
select is((select response#>>'{workbench,allowed_actions,save_confirmed_needs}'
  from k3_released_read),'false','K3 released correction never enables ordinary v2 Save');
select ok((select response#>'{workbench,need_correction_authority,pending_obligations}'
  from k3_released_read) ? 'PROCUREMENT_TRANSFER_NOT_IMPLEMENTED' = false,
  'K3 readback does not claim the proven K2 transfer is unimplemented');
insert into k1_requests
select 'initial_pxk',pg_temp.k1_command('SCHOOL-DISPATCH-RELEASE.v1',
  'SCHOOL_DISPATCH_DOCUMENT_RELEASED',0,jsonb_build_object('service_date','2026-11-02',
    'school_id','b6500000-0000-0000-0000-000000000004',
    'delivery_location_id','b6500000-0000-0000-0000-000000000002',
    'expected_source_fingerprint',preview->>'source_fingerprint',
    'predecessor_release_id',null))
from (select atlas_core.school_dispatch_release_preview('2026-11-02',
  'b6500000-0000-0000-0000-000000000004',
  'b6500000-0000-0000-0000-000000000002') preview) source;
set local role authenticated;
insert into k1_results select 'initial_pxk',atlas_api.release_school_dispatch_document(request)
from k1_requests where name='initial_pxk';
reset role;
select is((select response->>'success' from k1_results where name='initial_pxk'),
  'true','K1 prerequisite: real public School PXK release');

create function pg_temp.k1_snapshot(include_working boolean default false)
returns jsonb language plpgsql set search_path='' as $$
declare target text; facts jsonb; answer jsonb:='{}';
begin
  for target in select unnest(array[
    'atlas_planning.need_generation_release_snapshots',
    'atlas_planning.need_generation_release_snapshot_lines',
    'atlas_planning.confirmed_need_approval_snapshots',
    'atlas_planning.confirmed_need_snapshot_lines','atlas_planning.confirmed_need_releases',
    'atlas_planning.purchase_handoff_batches','atlas_planning.purchase_handoff_revisions',
    'atlas_planning.purchase_handoff_lines','atlas_planning.purchase_handoff_line_revisions',
    'atlas_planning.purchase_demand_references',
    'atlas_procurement.school_catering_allocation_families',
    'atlas_procurement.school_catering_allocation_family_revisions',
    'atlas_procurement.school_catering_allocation_family_contributions',
    'atlas_procurement.school_catering_allocation_supplier_splits',
    'atlas_procurement.purchase_orders','atlas_procurement.purchase_order_revisions',
    'atlas_procurement.purchase_order_lines','atlas_procurement.purchase_order_line_revisions',
    'atlas_dispatch.school_dispatch_releases','atlas_dispatch.school_dispatch_release_lines',
    'atlas_dispatch.school_dispatch_release_line_sources']||case when include_working then array[
    'atlas_planning.confirmed_need_batches','atlas_planning.confirmed_need_lines',
    'atlas_planning.confirmed_need_line_revisions','atlas_planning.confirmed_need_line_decisions',
    'atlas_planning.confirmed_need_line_revision_contributions',
    'atlas_core.command_receipts','atlas_audit.domain_events','atlas_audit.audit_events']
    else array[]::text[] end)
  loop
    execute format('select coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),''[]''::jsonb) from %s t',target)
      into facts;
    answer:=answer||jsonb_build_object(target,facts);
  end loop;
  return answer;
end $$;
create temporary table k1_original_history as select pg_temp.k1_snapshot() facts;

create temporary table k1_original_lines as
select l.confirmed_need_line_id,l.ingredient_id,l.current_confirmed_need_line_decision_id,
  r.confirmed_need_line_revision_id,to_jsonb(r) revision,
  (select to_jsonb(d) from atlas_planning.confirmed_need_line_decisions d
    where d.confirmed_need_line_decision_id=l.current_confirmed_need_line_decision_id) decision
from atlas_planning.confirmed_need_lines l
join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
where l.confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050' and r.is_current;

create temporary table k1_original_source as
select b.confirmed_need_batch_id,b.current_confirmed_need_release_id,
  h.purchase_handoff_batch_id,h.version handoff_version,
  hr.purchase_handoff_revision_id,
  (select count(*) from atlas_planning.confirmed_need_line_decisions) decision_count,
  (select count(*) from atlas_planning.confirmed_need_line_revisions) revision_count
from atlas_planning.confirmed_need_batches b
join atlas_planning.purchase_handoff_batches h on h.confirmed_need_batch_id=b.confirmed_need_batch_id
join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_batch_id=h.purchase_handoff_batch_id
where b.confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050' and hr.is_current;

insert into k1_requests
select 'correction110',pg_temp.k1_command('RMVP-05.v3','CONFIRMED_NEED_SAVED',b.version,
  jsonb_build_object('confirmed_need_batch_id',b.confirmed_need_batch_id,
    'correction',jsonb_build_object(
      'expected_confirmed_need_release_id',o.current_confirmed_need_release_id,
      'expected_purchase_handoff_batch_id',o.purchase_handoff_batch_id,
      'expected_purchase_handoff_revision_id',o.purchase_handoff_revision_id,
      'expected_purchase_handoff_version',o.handoff_version,
      'expected_source_fingerprint',encode(sha256(convert_to(
        atlas_core.rmvp_07_validated_facts_projection(b.confirmed_need_batch_id)::text,'UTF8')),'hex')),
    'lines',jsonb_build_array(jsonb_build_object(
      'confirmed_need_line_id',l.confirmed_need_line_id,
      'expected_current_revision_id',r.confirmed_need_line_revision_id,
      'expected_current_decision_id',l.current_confirmed_need_line_decision_id,
      'proposed_confirmed_quantity','110.000000',
      'reason_code','OPERATIONAL_QUANTITY_ADJUSTMENT',
      'reason_note','Điều chỉnh nhu cầu thực tế'))))
from atlas_planning.confirmed_need_batches b cross join k1_original_source o
join atlas_planning.confirmed_need_lines l on l.confirmed_need_batch_id=o.confirmed_need_batch_id
join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
where b.confirmed_need_batch_id=o.confirmed_need_batch_id and r.is_current
  and l.ingredient_id='b6500000-0000-0000-0000-000000000006';

create function pg_temp.k1_reject_case(fault text,original_request jsonb)
returns jsonb language plpgsql set search_path='' as $$
declare command jsonb:=original_request; response jsonb; before_state jsonb; answer jsonb;
begin
  begin
    if fault like 'missing:%' then
      delete from atlas_core.role_capabilities binding using atlas_core.capabilities capability
      where binding.capability_id=capability.capability_id
        and binding.role_id='b6000000-0000-0000-0000-000000000003'
        and capability.capability_code=substr(fault,9);
    elsif fault='inactive_actor' then
      update atlas_core.actors set actor_status='INACTIVE',deactivated_at=transaction_timestamp()
      where actor_id='b6000000-0000-0000-0000-000000000001';
    elsif fault='no_global' then
      delete from atlas_core.actor_scopes
      where actor_id='b6000000-0000-0000-0000-000000000001' and scope_kind='GLOBAL';
    elsif fault='inactive_unit' then
      update atlas_admin.units set unit_status='INACTIVE'
      where unit_id='b6500000-0000-0000-0000-000000000005';
    elsif fault='corrupt_untouched_receipt' then
      before_state:=pg_temp.k1_snapshot(true);
      begin
        update atlas_core.command_receipts set outcome='FAILED_NON_RETRYABLE'
        where command_id=(select (decision->>'command_id')::uuid from k1_original_lines
          where ingredient_id='b6500000-0000-0000-0000-000000000007');
      exception when check_violation then
        -- Receipt integrity now blocks this fault before correction can run.
        return jsonb_build_object('receipt_integrity_blocked',true,
          'business_unchanged',pg_temp.k1_snapshot(true)=before_state,
          'receipt_unchanged',true);
      end;
    elsif fault='stale_batch' then command:=jsonb_set(command,'{expected_version}','1');
    elsif fault='wrong_batch' then command:=jsonb_set(command,'{payload,confirmed_need_batch_id}',to_jsonb(gen_random_uuid()));
    elsif fault='missing_release' then command:=jsonb_set(command,'{payload,correction,expected_confirmed_need_release_id}',to_jsonb(gen_random_uuid()));
    elsif fault='wrong_handoff' then command:=jsonb_set(command,'{payload,correction,expected_purchase_handoff_batch_id}',to_jsonb(gen_random_uuid()));
    elsif fault='wrong_handoff_revision' then command:=jsonb_set(command,'{payload,correction,expected_purchase_handoff_revision_id}',to_jsonb(gen_random_uuid()));
    elsif fault='stale_handoff' then command:=jsonb_set(command,'{payload,correction,expected_purchase_handoff_version}','999');
    elsif fault='stale_source' then command:=jsonb_set(command,'{payload,correction,expected_source_fingerprint}',to_jsonb(repeat('f',64)));
    elsif fault='wrong_line' then command:=jsonb_set(command,'{payload,lines,0,confirmed_need_line_id}',to_jsonb(gen_random_uuid()));
    elsif fault='wrong_revision' then command:=jsonb_set(command,'{payload,lines,0,expected_current_revision_id}',to_jsonb(gen_random_uuid()));
    elsif fault='wrong_decision' then command:=jsonb_set(command,'{payload,lines,0,expected_current_decision_id}',to_jsonb(gen_random_uuid()));
    elsif fault='cross_membership' then command:=jsonb_set(command,'{payload,lines,0,confirmed_need_line_id}',
      to_jsonb((select confirmed_need_line_id from k1_original_lines where ingredient_id='b6500000-0000-0000-0000-000000000007')));
    elsif fault='missing_note' then command:=jsonb_set(command,'{payload,lines,0,reason_note}','null');
    elsif fault='invalid_step' then command:=jsonb_set(command,'{payload,lines,0,proposed_confirmed_quantity}','"110.001"');
    elsif fault='unchanged' then command:=jsonb_set(command,'{payload,lines,0,proposed_confirmed_quantity}','"100.000000"');
    elsif fault='unknown_field' then command:=jsonb_set(command,'{payload,correction,skip_history}','true');
    end if;
    before_state:=pg_temp.k1_snapshot(true);
    execute 'set local role authenticated';
    response:=atlas_api.save_confirmed_needs(command);
    execute 'reset role';
    answer:=jsonb_build_object('response',response,
      'review',pg_temp.k3_review(),
      'business_unchanged',(before_state-'atlas_core.command_receipts')=
        (pg_temp.k1_snapshot(true)-'atlas_core.command_receipts'),
      'receipt_unchanged',before_state->'atlas_core.command_receipts'=
        pg_temp.k1_snapshot(true)->'atlas_core.command_receipts');
    raise exception using errcode='K1001',message='Roll back only disposable negative-case setup';
  exception when sqlstate 'K1001' then return answer;
  end;
end $$;
create function pg_temp.k3_history_case(fault text,read_procurement boolean default false)
returns jsonb language plpgsql set search_path='' as $$
declare answer jsonb;
begin
  begin
    if fault='arbitrary_reopened' then
      update atlas_planning.confirmed_need_batches set batch_status='REOPENED',
        current_confirmed_need_validation_attempt_id=null,
        current_confirmed_need_approval_snapshot_id=null,current_confirmed_need_release_id=null
      where confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050';
    elsif fault='missing_release_pointer' then
      update atlas_planning.confirmed_need_batches set current_confirmed_need_release_id=null
      where confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050';
    elsif fault='missing_current_handoff' then
      update atlas_planning.purchase_handoff_revisions set is_current=false
      where purchase_handoff_batch_id=(select purchase_handoff_batch_id
        from atlas_planning.purchase_handoff_batches where confirmed_need_batch_id=
          'b6500000-0000-0000-0000-000000000050') and is_current;
    elsif fault='invalid_handoff_status' then
      update atlas_planning.purchase_handoff_batches set handoff_status='REOPENED'
      where confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050';
    elsif fault='same_total_membership' then
      update atlas_planning.confirmed_need_line_revision_contributions
      set theoretical_need_line_id=gen_random_uuid()
      where confirmed_need_line_revision_id=(select confirmed_need_line_revision_id
        from k1_original_lines order by confirmed_need_line_id limit 1);
    elsif fault='unsupported_source' then
      update atlas_planning.confirmed_need_batches set source_kind='WHOLESALE'
      where confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050';
    end if;
    answer:=case when read_procurement then '{}'::jsonb else pg_temp.k3_review() end;
    if read_procurement then
      set local role authenticated;
      perform set_config('request.jwt.claim.sub','b6000000-0000-0000-0000-000000000101',true);
      answer:=answer||jsonb_build_object('procurement',
        atlas_api.get_confirmed_supplier_allocation_workbench(jsonb_build_object(
          'contract_version','CONFIRMED-SUPPLIER-ALLOCATION.v1','correlation_id',gen_random_uuid(),
          'requested_by_auth_subject','b6000000-0000-0000-0000-000000000101',
          'payload',jsonb_build_object('date_start','2026-11-02','date_end','2026-11-02',
            'school_ids','[]'::jsonb,'states','[]'::jsonb,'search',null))));
      reset role;
    end if;
    raise exception using errcode='K3001',message='Roll back negative read fixture';
  exception when sqlstate 'K3001' then return answer;
    when check_violation or foreign_key_violation or not_null_violation or undefined_column then
      -- Existing immutable guards may reject corruption before the read. Keep
      -- the known 42703 contribution diagnostic visible; never bypass a guard.
      return jsonb_build_object('integrity_rejected',true,'sqlstate',sqlstate);
  end;
end $$;
create temporary table k3_history_denials as
select fault,pg_temp.k3_history_case(fault) response
from unnest(array['arbitrary_reopened','missing_release_pointer','missing_current_handoff',
  'invalid_handoff_status','same_total_membership','unsupported_source']) fault;
select ok(response->>'integrity_rejected'='true'
    or response#>>'{workbench,allowed_actions,correct_released_confirmed_needs}'='false',
  'K3 invalid historical evidence cannot authorize correction: '||fault)
from k3_history_denials;
select ok(pg_temp.k1_snapshot()=(select facts from k1_original_history),
  'K3 negative read probes preserve the exact original issued history');
select is(pg_temp.k3_review(gen_random_uuid())->>'success','false',
  'K3 unknown batch read cannot fabricate an eligible correction action');
-- Each independent public-command/read case retains its own unchanged 8-second
-- statement budget, as it does through PostgREST. Do not batch 22 RPC pairs
-- inside one artificial SQL statement during concurrent development checks.
create temporary table k1_negative(fault text primary key,result jsonb not null);
select format('insert into k1_negative select %L,pg_temp.k1_reject_case(%L,request) from k1_requests where name=''correction110'';',fault,fault)
from unnest(array[
  'missing:planning.need_generation.write','missing:confirmed_need_quantities.confirm',
  'missing:confirmed_need_release.release','inactive_actor','no_global','inactive_unit',
  'stale_batch','wrong_batch','missing_release','wrong_handoff','wrong_handoff_revision',
  'stale_handoff','stale_source','wrong_line','wrong_revision','wrong_decision',
  'cross_membership','missing_note','invalid_step','unchanged','unknown_field',
  'corrupt_untouched_receipt']) fault
\gexec
select ok((result#>>'{response,success}'='false'
    or (fault='corrupt_untouched_receipt' and result->>'receipt_integrity_blocked'='true'))
    and (result->>'business_unchanged')::boolean,
  'K1-06/10 '||fault||' rejected without authoritative business writes')
from k1_negative order by fault;
select ok(bool_and((result->>'receipt_unchanged')::boolean),
  'K1-06 capability/Actor/GLOBAL denials occur before command receipt creation')
from k1_negative where fault like 'missing:%' or fault in ('inactive_actor','no_global');
select ok(result#>>'{review,success}'='false'
    or result#>>'{review,workbench,allowed_actions,correct_released_confirmed_needs}'='false',
  'K3 authenticated eligibility rejects '||fault)
from k1_negative where fault like 'missing:%' or fault in ('inactive_actor','no_global','inactive_unit');
select is(result#>>'{review,workbench,disabled_reason_codes,correct_released_confirmed_needs}',
  'CORRECTION_CAPABILITY_REQUIRED','K3 missing capability has a stable safe reason: '||fault)
from k1_negative where fault like 'missing:%';
select is(result#>>'{review,workbench,disabled_reasons,correct_released_confirmed_needs}',
  'Bạn chưa có đủ quyền điều chỉnh nhu cầu đã phát hành.',
  'K3 missing capability has Vietnamese operator wording: '||fault)
from k1_negative where fault like 'missing:%';

set local role authenticated;
insert into k1_results select 'correction110',atlas_api.save_confirmed_needs(request)
from k1_requests where name='correction110';
reset role;
select is((select response->>'success' from k1_results where name='correction110'),
  'true','K1-01 public versioned released Save appends 100 to 110');
select is((select r.confirmed_quantity::text
  from atlas_planning.confirmed_need_line_revisions r
  join atlas_planning.confirmed_need_lines l using(confirmed_need_line_id)
  where r.is_current and l.ingredient_id='b6500000-0000-0000-0000-000000000006'),
  '110.000000','K1-01 authoritative current quantity is 110');
select is((select count(*) from atlas_planning.confirmed_need_line_decisions),
  (select decision_count+1 from k1_original_source),
  'K1-01 exactly one authentic new human decision');
select is((select r.predecessor_revision_id
  from atlas_planning.confirmed_need_line_revisions r
  join k1_original_lines old using(confirmed_need_line_id)
  where r.is_current and old.ingredient_id='b6500000-0000-0000-0000-000000000006'),
  (select confirmed_need_line_revision_id from k1_original_lines
    where ingredient_id='b6500000-0000-0000-0000-000000000006'),
  'K1-01 exact released revision predecessor');
select is((select decision.predecessor_decision_id
  from atlas_planning.confirmed_need_lines line
  join atlas_planning.confirmed_need_line_decisions decision
    on decision.confirmed_need_line_decision_id=line.current_confirmed_need_line_decision_id
  where line.ingredient_id='b6500000-0000-0000-0000-000000000006'),
  (select current_confirmed_need_line_decision_id from k1_original_lines
    where ingredient_id='b6500000-0000-0000-0000-000000000006'),
  'K1-01 exact original human decision predecessor');
select is((select response#>>'{authoritative_readback,need_correction_authority,current_lines,0,difference}'
  from k1_results where name='correction110'),'10.000000','K1-01 authoritative variance +10');
select is((select response#>>'{authoritative_readback,need_correction_authority,current_lines,0,decided_by_actor_id}'
  from k1_results where name='correction110'),'b6000000-0000-0000-0000-000000000001',
  'K1-01 JWT-bound accountable human Actor');
select is((select response#>>'{authoritative_readback,need_correction_authority,downstream_workflow_available}'
  from k1_results where name='correction110'),'true',
  'K3 fresh readback identifies valid corrected-source continuation, not PO issuance');
select is((select response->>'supplier_commitment_changed' from k1_results where name='correction110'),
  'false','K1 Save does not claim Supplier issuance');
select is(pg_temp.k1_snapshot(),(select facts from k1_original_history),
  'K1-05 original Need releases, Handoff, allocation, PO and PXK snapshots unchanged');

-- The command result is deliberately not used as authority for the next Save.
-- A fresh public read supplies recovery after a lost transport response.
insert into k1_requests select 'read',jsonb_build_object('contract_version','RMVP-05.v1',
  'requested_by_auth_subject','b6000000-0000-0000-0000-000000000101',
  'correlation_id',gen_random_uuid(),'payload',jsonb_build_object(
    'confirmed_need_batch_id','b6500000-0000-0000-0000-000000000050',
    'filters','{}'::jsonb,'line_offset',0,'line_limit',10000));
set local role authenticated;
insert into k1_results select 'recovered110',atlas_api.get_confirmed_need_review(request)
from k1_requests where name='read';
insert into k1_results select 'replay110',atlas_api.save_confirmed_needs(request)
from k1_requests where name='correction110';
insert into k1_results select 'changed_payload110',atlas_api.save_confirmed_needs(
  jsonb_set(request,'{payload,lines,0,proposed_confirmed_quantity}','"111.000000"'))
from k1_requests where name='correction110';
reset role;
select is((select response#>>'{workbench,need_correction_authority,current_lines,0,new_confirmed_quantity}'
  from k1_results where name='recovered110'),'110.000000',
  'K1-09 authoritative public read recovers executed Save after response loss');
select is((select response#>>'{workbench,allowed_actions,correct_released_confirmed_needs}'
  from k1_results where name='recovered110'),'true',
  'K3 genuine K1-reopened chain permits a second explicit correction');
select is((select response#>>'{workbench,allowed_actions,save_confirmed_needs}'
  from k1_results where name='recovered110'),'false',
  'K3 genuine K1-reopened chain still forbids ordinary v2 Save');
create temporary table k3_procurement_history(fault text,response jsonb);
select format('insert into k3_procurement_history select %L,pg_temp.k3_history_case(%L,true);',fault,fault)
from unnest(array['missing_current_handoff','invalid_handoff_status','unsupported_source']) fault
\gexec
select ok(case when fault='unsupported_source' then
    response='{"integrity_rejected":true,"sqlstate":"23514"}'::jsonb
  else response->>'integrity_rejected' is null and response#>>'{procurement,success}'='true' end,
  'post-release historical fault preserves the integrity guard or reaches the authenticated read: '||fault)
from k3_procurement_history;
select ok(case when fault='unsupported_source' then
    response->>'integrity_rejected'='true' and not response?'procurement'
  else response#>>'{procurement,preparation,ready}'='false'
    and not exists(select 1 from jsonb_array_elements(response#>'{procurement,rows}') row
      where row->>'state'='BALANCED' or row->>'complete'='true'
        or row#>>'{allowed_actions,save_allocation}'='true'
        or row#>>'{allowed_actions,confirm_recommendation}'='true') end,
  'unavailable historical authority blocks row actions and Preparation: '||fault)
from k3_procurement_history;
select is((select response from k1_results where name='replay110'),
  (select response from k1_results where name='correction110'),
  'K1-08 exact receipt replay returns original authoritative response and IDs');
select is((select response->>'error_code' from k1_results where name='changed_payload110'),
  'IDEMPOTENCY_CONFLICT','K1-08 changed-payload reuse conflicts');

create temporary table k1_second_source as select line.confirmed_need_line_id,
  line.current_confirmed_need_line_decision_id,revision.confirmed_need_line_revision_id
from atlas_planning.confirmed_need_lines line
join atlas_planning.confirmed_need_line_revisions revision using(confirmed_need_line_id)
where line.ingredient_id='b6500000-0000-0000-0000-000000000006' and revision.is_current;
insert into k1_requests
select 'correction90',pg_temp.k1_command('RMVP-05.v3','CONFIRMED_NEED_SAVED',b.version,
  jsonb_build_object('confirmed_need_batch_id',b.confirmed_need_batch_id,
    'correction',jsonb_build_object(
      'expected_confirmed_need_release_id',o.current_confirmed_need_release_id,
      'expected_purchase_handoff_batch_id',o.purchase_handoff_batch_id,
      'expected_purchase_handoff_revision_id',o.purchase_handoff_revision_id,
      'expected_purchase_handoff_version',o.handoff_version,
      'expected_source_fingerprint',encode(sha256(convert_to(
        atlas_core.rmvp_07_validated_facts_projection(b.confirmed_need_batch_id)::text,'UTF8')),'hex')),
    'lines',jsonb_build_array(jsonb_build_object(
      'confirmed_need_line_id',source.confirmed_need_line_id,
      'expected_current_revision_id',source.confirmed_need_line_revision_id,
      'expected_current_decision_id',source.current_confirmed_need_line_decision_id,
      'proposed_confirmed_quantity','90.000000','reason_code','OPERATIONAL_QUANTITY_ADJUSTMENT',
      'reason_note','Điều chỉnh nhu cầu lần hai'))))
from atlas_planning.confirmed_need_batches b cross join k1_original_source o
cross join k1_second_source source where b.confirmed_need_batch_id=o.confirmed_need_batch_id;
set local role authenticated;
insert into k1_results select 'correction90',atlas_api.save_confirmed_needs(request)
from k1_requests where name='correction90';
reset role;
select is((select response->>'success' from k1_results where name='correction90'),
  'true','K1-02 second authenticated correction 110 to 90 succeeds');
select is((select response#>>'{authoritative_readback,need_correction_authority,current_lines,0,new_confirmed_quantity}'
  from k1_results where name='correction90'),'90.000000','K1-02 authoritative current quantity 90');
select is((select response#>>'{authoritative_readback,need_correction_authority,current_lines,0,predecessor_revision_id}'
  from k1_results where name='correction90'),
  (select confirmed_need_line_revision_id::text from k1_second_source),
  'K1-02 direct predecessor is authentic 110 revision');
select is((select response#>>'{authoritative_readback,need_correction_authority,current_lines,0,predecessor_decision_id}'
  from k1_results where name='correction90'),
  (select current_confirmed_need_line_decision_id::text from k1_second_source),
  'K1-02 direct predecessor is authentic 110 decision');
select is((select jsonb_agg(confirmed_quantity::text order by revision_number)
  from atlas_planning.confirmed_need_line_revisions where confirmed_need_line_id=
    (select confirmed_need_line_id from k1_second_source)),
  '["100.000000","110.000000","90.000000"]'::jsonb,
  'K1-02 immutable complete 100 to 110 to 90 quantity chain');
select is((select to_jsonb(revision) from atlas_planning.confirmed_need_line_revisions revision
  join k1_original_lines old using(confirmed_need_line_revision_id)
  where old.ingredient_id='b6500000-0000-0000-0000-000000000007'),
  (select revision from k1_original_lines where ingredient_id='b6500000-0000-0000-0000-000000000007'),
  'K1-03 untouched Ingredient revision remains byte-identical');
select is((select to_jsonb(decision) from atlas_planning.confirmed_need_line_decisions decision
  join k1_original_lines old on old.current_confirmed_need_line_decision_id=decision.confirmed_need_line_decision_id
  where old.ingredient_id='b6500000-0000-0000-0000-000000000007'),
  (select decision from k1_original_lines where ingredient_id='b6500000-0000-0000-0000-000000000007'),
  'K1-03 untouched Ingredient human decision remains byte-identical');
select is(pg_temp.k1_snapshot(),(select facts from k1_original_history),
  'K1-05 complete original release/Handoff/PO/PXK evidence retained after two corrections');

-- A real deferred exception must roll back the entire Save subtransaction.
insert into k1_requests
select 'forced95',jsonb_set(jsonb_set(jsonb_set(jsonb_set(jsonb_set(jsonb_set(request,
  '{command_id}',to_jsonb(gen_random_uuid())),
  '{idempotency_key}',to_jsonb('k1-force:'||gen_random_uuid())),
  '{expected_version}',to_jsonb(batch.version)),
  '{payload,correction,expected_source_fingerprint}',to_jsonb(encode(sha256(convert_to(
    atlas_core.rmvp_07_validated_facts_projection(batch.confirmed_need_batch_id)::text,'UTF8')),'hex'))),
  '{payload,lines,0,expected_current_revision_id}',to_jsonb(revision.confirmed_need_line_revision_id)),
  '{payload,lines,0,expected_current_decision_id}',to_jsonb(line.current_confirmed_need_line_decision_id))
  ||jsonb_build_object('payload',(request->'payload')||jsonb_build_object('correction',
    (request#>'{payload,correction}')||jsonb_build_object('expected_source_fingerprint',
      encode(sha256(convert_to(atlas_core.rmvp_07_validated_facts_projection(batch.confirmed_need_batch_id)::text,'UTF8')),'hex')),
    'lines',jsonb_build_array((request#>'{payload,lines,0}')||jsonb_build_object(
      'expected_current_revision_id',revision.confirmed_need_line_revision_id,
      'expected_current_decision_id',line.current_confirmed_need_line_decision_id,
      'proposed_confirmed_quantity','95.000000'))))
from k1_requests cross join atlas_planning.confirmed_need_batches batch
join atlas_planning.confirmed_need_lines line using(confirmed_need_batch_id)
join atlas_planning.confirmed_need_line_revisions revision using(confirmed_need_line_id)
where name='correction90' and batch.confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050'
  and line.ingredient_id='b6500000-0000-0000-0000-000000000006' and revision.is_current;
create temporary table k1_before_failure as select pg_temp.k1_snapshot(true) facts;
create function pg_temp.k1_force_deferred_failure() returns trigger
language plpgsql set search_path='' as $$
begin raise exception using errcode='23514',message='K1 deliberate deferred failure'; end $$;
create constraint trigger k1_force_deferred_failure
after insert on atlas_planning.confirmed_need_line_decisions deferrable initially deferred
for each row execute function pg_temp.k1_force_deferred_failure();
set local role authenticated;
insert into k1_results select 'forced95',atlas_api.save_confirmed_needs(request)
from k1_requests where name='forced95';
reset role;
drop trigger k1_force_deferred_failure on atlas_planning.confirmed_need_line_decisions;
select is((select response->>'success' from k1_results where name='forced95'),
  'false','K1-11 forced deferred failure safely rejects correction');
select is((select response->>'write_certainty' from k1_results where name='forced95'),
  'NO_COMMITTED_CHANGE','K1-11 backend exception has definite no-commit certainty');
select is(pg_temp.k1_snapshot(true),(select facts from k1_before_failure),
  'K1-11 exact before/after table, receipt, event and audit state: zero partial writes');

-- K1-04 reuses the existing B1 real-input/generation fixture below. It does not
-- create a Confirmed Need correction by writing private quantity tables.
\ir ../local/atlas_b1_two_school_need_fixture.sql
create temporary table k1_b1_batch as
select b.confirmed_need_batch_id from atlas_planning.confirmed_need_batches b
join atlas_planning.need_generation_runs run on run.need_generation_run_id=b.current_need_generation_run_id
where run.generated_by_actor_id=pg_temp.ng_id(1) and run.period_start='2050-09-19';
insert into k1_requests
select 'b1_save28',pg_temp.ng_request('RMVP-05.v2','CONFIRMED_NEED_SAVED',jsonb_build_object(
 'confirmed_need_batch_id',b.confirmed_need_batch_id,'lines',(
 select jsonb_agg(jsonb_build_object('confirmed_need_line_id',l.confirmed_need_line_id,
 'expected_current_revision_id',r.confirmed_need_line_revision_id,
 'expected_current_decision_id',l.current_confirmed_need_line_decision_id,
 'proposed_confirmed_quantity',r.confirmed_quantity::text,
 'reason_code','PROPOSAL_ACCEPTED','reason_note',null) order by l.confirmed_need_line_id)
 from atlas_planning.confirmed_need_lines l join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
 where l.confirmed_need_batch_id=b.confirmed_need_batch_id and r.is_current)))
 ||jsonb_build_object('expected_version',b.version,'reason_note',null)
from atlas_planning.confirmed_need_batches b join k1_b1_batch using(confirmed_need_batch_id);
set local role authenticated;
insert into k1_results select 'b1_save28',atlas_api.save_confirmed_needs(request)
from k1_requests where name='b1_save28';
reset role;
select is((select response->>'success' from k1_results where name='b1_save28'),'true',
 'K1-04 real explicit B1 confirmation accepts theoretical28');
insert into k1_requests
select 'b1_prepare28',pg_temp.ng_request('PURCHASE-COMMITMENT.v1','PURCHASE_ORDERS_PREPARED',
 jsonb_build_object('confirmed_need_batch_id',b.confirmed_need_batch_id,'service_date','2050-09-19'))
 ||jsonb_build_object('expected_version',b.version,'reason_note',null)
from atlas_planning.confirmed_need_batches b join k1_b1_batch using(confirmed_need_batch_id);
set local role authenticated;
insert into k1_results select 'b1_prepare28',atlas_api.prepare_school_catering_purchase_orders(request)
from k1_requests where name='b1_prepare28';
reset role;
select is((select response->>'success' from k1_results where name='b1_prepare28'),'true',
 'K1-04 real B1 Planning release and Handoff before correction');
create temporary table k1_b1_before as
select pg_temp.k1_snapshot() history,
 (select jsonb_agg(jsonb_build_object('line_id',l.confirmed_need_line_id,'revision',to_jsonb(r),'decision',to_jsonb(d))
 order by l.confirmed_need_line_id)
 from atlas_planning.confirmed_need_lines l join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
 join atlas_planning.confirmed_need_line_decisions d on d.confirmed_need_line_decision_id=l.current_confirmed_need_line_decision_id
 where l.confirmed_need_batch_id=b.confirmed_need_batch_id and r.is_current
 and not(l.school_id=pg_temp.ng_id(5001) and l.ingredient_id=pg_temp.ng_id(2001))) unchanged,
 (select jsonb_agg(to_jsonb(t) order by t.theoretical_need_line_id)
 from atlas_planning.theoretical_need_lines t where t.school_id=pg_temp.ng_id(5001)
 and t.ingredient_id=pg_temp.ng_id(2001)) theoretical
from k1_b1_batch b;
insert into k1_requests
select 'b1_correct30',pg_temp.ng_request('RMVP-05.v3','CONFIRMED_NEED_SAVED',jsonb_build_object(
 'confirmed_need_batch_id',b.confirmed_need_batch_id,'correction',jsonb_build_object(
 'expected_confirmed_need_release_id',b.current_confirmed_need_release_id,
 'expected_purchase_handoff_batch_id',h.purchase_handoff_batch_id,
 'expected_purchase_handoff_revision_id',hr.purchase_handoff_revision_id,
 'expected_purchase_handoff_version',h.version,
 'expected_source_fingerprint',encode(sha256(convert_to(
 atlas_core.rmvp_07_validated_facts_projection(b.confirmed_need_batch_id)::text,'UTF8')),'hex')),
 'lines',jsonb_build_array(jsonb_build_object('confirmed_need_line_id',l.confirmed_need_line_id,
 'expected_current_revision_id',r.confirmed_need_line_revision_id,
 'expected_current_decision_id',l.current_confirmed_need_line_decision_id,
 'proposed_confirmed_quantity','30.000000','reason_code','OPERATIONAL_QUANTITY_ADJUSTMENT',
 'reason_note','B1 released Need correction with original R/B/H retained'))))
 ||jsonb_build_object('expected_version',b.version,'reason_note',null)
from atlas_planning.confirmed_need_batches b join k1_b1_batch using(confirmed_need_batch_id)
join atlas_planning.confirmed_need_lines l using(confirmed_need_batch_id)
join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
join atlas_planning.purchase_handoff_batches h on h.confirmed_need_batch_id=b.confirmed_need_batch_id
join atlas_planning.purchase_handoff_revisions hr on hr.purchase_handoff_batch_id=h.purchase_handoff_batch_id
where l.school_id=pg_temp.ng_id(5001) and l.ingredient_id=pg_temp.ng_id(2001) and r.is_current and hr.is_current;
set local role authenticated;
insert into k1_results select 'b1_correct30',atlas_api.save_confirmed_needs(request)
from k1_requests where name='b1_correct30';
reset role;
select is((select response->>'success' from k1_results where name='b1_correct30'),'true',
 'K1-04 public released B1 correction28 to30 succeeds');
select ok((select r.theoretical_quantity=28 and r.confirmed_quantity=30
 and d.theoretical_quantity_before=28 and d.proposed_quantity_before=28
 and d.confirmed_quantity_after=30 and d.predecessor_decision_id is not null
 from atlas_planning.confirmed_need_lines l join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
 join atlas_planning.confirmed_need_line_decisions d on d.confirmed_need_line_decision_id=l.current_confirmed_need_line_decision_id
 where l.school_id=pg_temp.ng_id(5001) and l.ingredient_id=pg_temp.ng_id(2001) and r.is_current),
 'K1-04 theoretical28 and authentic human+2 remain separate');
select is((select jsonb_agg(to_jsonb(t) order by t.theoretical_need_line_id)
 from atlas_planning.theoretical_need_lines t where t.school_id=pg_temp.ng_id(5001)
 and t.ingredient_id=pg_temp.ng_id(2001)),(select theoretical from k1_b1_before),
 'K1-04 exact original Recipe/B/H theoretical source rows unchanged');
select ok((select count(*)=3 and count(distinct t.pantry_need_line_id)=2
 and sum(c.controlled_contribution_quantity)=28
 and sum(c.controlled_contribution_quantity) filter(where t.contribution_family='RECIPE_DERIVED')=20
 and sum(c.controlled_contribution_quantity) filter(where t.pantry_need_line_id is not null)=8
 from atlas_planning.confirmed_need_line_revision_contributions c
 join atlas_planning.theoretical_need_lines t using(theoretical_need_line_id)
 join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_revision_id)
 where t.school_id=pg_temp.ng_id(5001) and t.ingredient_id=pg_temp.ng_id(2001) and r.is_current),
 'K1-04 corrected revision retains three exact R20/B5/H3 source identities');
select is((select jsonb_agg(jsonb_build_object('line_id',l.confirmed_need_line_id,'revision',to_jsonb(r),'decision',to_jsonb(d))
 order by l.confirmed_need_line_id)
 from atlas_planning.confirmed_need_lines l join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
 join atlas_planning.confirmed_need_line_decisions d on d.confirmed_need_line_decision_id=l.current_confirmed_need_line_decision_id
 where l.confirmed_need_batch_id=b.confirmed_need_batch_id and r.is_current
 and not(l.school_id=pg_temp.ng_id(5001) and l.ingredient_id=pg_temp.ng_id(2001))),
 (select unchanged from k1_b1_before),'K1-03 other School/Ingredient R/D identities unchanged')
from k1_b1_batch b;
select is(pg_temp.k1_snapshot(),(select history from k1_b1_before),
 'K1-05 B1 correction adds no release/Handoff/PO/PXK or allocation effects');

create function pg_temp.k3_source_reopen_case(source_name text)
returns jsonb language plpgsql set search_path='' as $$
declare command jsonb; reopened jsonb; review jsonb; procurement jsonb; answer jsonb;
  prior_subject text:=current_setting('request.jwt.claim.sub',true);
begin
  begin
    if source_name='attendance' then
      select pg_temp.ng_request('RMVP-03A.v1','ATTENDANCE_REOPENED',
        jsonb_build_object('week_start','2050-09-19','expected_source_signature',null))||jsonb_build_object('expected_version',version)
      into command from atlas_planning.attendance_batches where period_start='2050-09-19';
    else
      select pg_temp.ng_request('PANTRY-02.v1','PANTRY_REOPENED',
        jsonb_build_object('week_start','2050-09-19','expected_source_signature',source_signature))||jsonb_build_object('expected_version',version)
      into command from atlas_planning.pantry_need_batches where week_start='2050-09-19';
    end if;
    set local role authenticated;
    perform set_config('request.jwt.claim.sub',command->>'requested_by_auth_subject',true);
    if source_name='attendance' then reopened:=atlas_api.reopen_attendance(command);
    else reopened:=atlas_api.reopen_pantry(command); end if;
    procurement:=atlas_api.get_confirmed_supplier_allocation_workbench(jsonb_build_object(
      'contract_version','CONFIRMED-SUPPLIER-ALLOCATION.v1','correlation_id',gen_random_uuid(),
      'requested_by_auth_subject',command->>'requested_by_auth_subject',
      'payload',jsonb_build_object('date_start','2050-09-19','date_end','2050-09-19',
        'school_ids','[]'::jsonb,'states','[]'::jsonb,'search',null)));
    reset role;
    review:=pg_temp.k3_review((select confirmed_need_batch_id from k1_b1_batch));
    answer:=jsonb_build_object('reopened',reopened,'review',review,'procurement',procurement);
    raise exception using errcode='K3001',message='Roll back authenticated source reopen';
  exception when sqlstate 'K3001' then
    perform set_config('request.jwt.claim.sub',coalesce(prior_subject,''),true);
    return answer;
  end;
end $$;
create temporary table k3_source_denials(source_name text,response jsonb);
select format('insert into k3_source_denials select %L,pg_temp.k3_source_reopen_case(%L);',source_name,source_name)
from unnest(array['attendance','pantry']) source_name
\gexec
select is(response#>>'{reopened,success}','true',
  'K3 real authenticated source reopen succeeds: '||source_name) from k3_source_denials;
select is(response#>>'{review,workbench,allowed_actions,correct_released_confirmed_needs}',
  'false','K3 source reopen disables correction: '||source_name) from k3_source_denials;
select is(response#>>'{review,workbench,disabled_reason_codes,correct_released_confirmed_needs}',
  'CORRECTION_SOURCE_NOT_CURRENT','K3 source reopen reports currentness: '||source_name) from k3_source_denials;
select ok(response#>>'{procurement,preparation,ready}'='false'
    and not exists(select 1 from jsonb_array_elements(response#>'{procurement,rows}') row
      where row->>'state'='BALANCED' or row#>>'{allowed_actions,save_allocation}'='true'),
  'amended Procurement read blocks genuine upstream source change: '||source_name)
from k3_source_denials;

-- A public compatibility source reopen must remove current-source authority.
create temporary table k1_before_upstream_reopen as
select encode(sha256(convert_to(atlas_core.rmvp_07_validated_facts_projection(
 confirmed_need_batch_id)::text,'UTF8')),'hex') fingerprint from k1_b1_batch;
insert into k1_requests
select 'upstream_menu_reopen',pg_temp.ng_request('RMVP-03A.v1','WEEKLY_MENU_REOPENED',
 jsonb_build_object('week_start','2050-09-19'))||jsonb_build_object('expected_version',version)
from atlas_planning.weekly_menus where week_start='2050-09-19';
set local role authenticated;
insert into k1_results select 'upstream_menu_reopen',atlas_api.reopen_weekly_menu(request)
from k1_requests where name='upstream_menu_reopen';
insert into k1_results select 'upstream_preflight',atlas_api.get_planning_input_preflight(
 jsonb_build_object('contract_version','RMVP-03B.v2','requested_by_auth_subject',pg_temp.ng_id(101),
 'correlation_id',gen_random_uuid(),'payload',jsonb_build_object(
 'period_start','2050-09-19','period_end','2050-09-19')));
reset role;
select is((select response->>'success' from k1_results where name='upstream_menu_reopen'),'true',
 'K1-10 public upstream Menu reopen succeeds with its real guard');
select is(pg_temp.k3_review((select confirmed_need_batch_id from k1_b1_batch))
  #>>'{workbench,allowed_actions,correct_released_confirmed_needs}','false',
  'K3 read action becomes false after authenticated upstream Menu reopen');
select is(pg_temp.k3_review((select confirmed_need_batch_id from k1_b1_batch))
  #>>'{workbench,disabled_reason_codes,correct_released_confirmed_needs}',
  'CORRECTION_SOURCE_NOT_CURRENT','K3 stale source has a precise disabled reason');
select ok((select response#>>'{preflight,readiness_state}'='BLOCKED'
 and response#>>'{preflight,downstream_currentness}'='OUTDATED'
 and response#>>'{preflight,issues,0,issue_code}'='MISSING_WEEKLY_MENU_APPROVAL_SNAPSHOT'
 from k1_results where name='upstream_preflight'),
 'K1-10 authoritative preflight proves reopened Menu is BLOCKED/OUTDATED');
select ok(atlas_core.rmvp_06_canonical_evaluation(confirmed_need_batch_id)->>'outcome'='VALIDATED'
 and encode(sha256(convert_to(atlas_core.rmvp_07_validated_facts_projection(
 confirmed_need_batch_id)::text,'UTF8')),'hex')=(select fingerprint from k1_before_upstream_reopen),
 'K1 blocker: RMVP-06 and the captured-facts fingerprint miss upstream currency')
from k1_b1_batch;
insert into k1_requests
select 'stale_upstream31',request||jsonb_build_object('command_id',gen_random_uuid(),
 'idempotency_key','k1-upstream:'||gen_random_uuid(),'expected_version',b.version,
 'payload',(request->'payload')||jsonb_build_object('correction',
 (request#>'{payload,correction}')||jsonb_build_object('expected_source_fingerprint',
 encode(sha256(convert_to(atlas_core.rmvp_07_validated_facts_projection(b.confirmed_need_batch_id)::text,'UTF8')),'hex')),
 'lines',jsonb_build_array((request#>'{payload,lines,0}')||jsonb_build_object(
 'expected_current_revision_id',r.confirmed_need_line_revision_id,
 'expected_current_decision_id',l.current_confirmed_need_line_decision_id,
 'proposed_confirmed_quantity','31.000000'))))
from k1_requests cross join k1_b1_batch target
join atlas_planning.confirmed_need_batches b using(confirmed_need_batch_id)
join atlas_planning.confirmed_need_lines l using(confirmed_need_batch_id)
join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
where name='b1_correct30' and l.school_id=pg_temp.ng_id(5001)
and l.ingredient_id=pg_temp.ng_id(2001) and r.is_current;
set local role authenticated;
insert into k1_results select 'stale_upstream31',atlas_api.save_confirmed_needs(request)
from k1_requests where name='stale_upstream31';
reset role;
select is((select response->>'success' from k1_results where name='stale_upstream31'),'false',
 'K1-10 correction rejects upstream source that is no longer complete/current');
select is((select response->>'error_code' from k1_results where name='stale_upstream31'),
 'CORRECTION_SOURCE_NOT_CURRENT','K1-10 stale upstream returns the genuine source-currentness blocker');
select * from finish();
rollback;
