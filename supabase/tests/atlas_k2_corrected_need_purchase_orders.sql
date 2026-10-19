-- Authenticated K2 correction-to-PO journey; every fixture write rolls back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=extensions,public,pg_catalog;
set local statement_timeout='8s';
select no_plan();
\ir ../local/purchase_review_confirm_release_fixture.sql

insert into atlas_core.role_capabilities(role_id,capability_id)
select 'b6000000-0000-0000-0000-000000000003',capability_id
from atlas_core.capabilities where capability_code in (
  'planning.need_generation.write','confirmed_need_release.release')
on conflict do nothing;

-- Actual key writes remain forbidden even though row locks require column grants.
create temporary table k2_core_lock_results(table_name text,result boolean);
create function pg_temp.k2_core_write_denied() returns void
language plpgsql set search_path='' as $$
declare target text; key_name text; denied boolean;
begin
  for target,key_name in values
    ('actors','actor_id'),('actor_auth_subjects','actor_auth_subject_id'),
    ('roles','role_id'),('role_capabilities','role_id'),('capabilities','capability_id'),
    ('actor_role_memberships','actor_role_membership_id'),('actor_scopes','actor_scope_id') loop
    denied:=false;
    begin
      execute format('update atlas_core.%I set %I=%I',target,key_name,key_name);
    exception when insufficient_privilege then denied:=true;
    end;
    insert into pg_temp.k2_core_lock_results values(target,denied);
  end loop;
end;
$$;
grant insert on k2_core_lock_results to atlas_procurement_command_runtime;
grant atlas_procurement_command_runtime to postgres with set true;
set local role atlas_procurement_command_runtime;
select atlas_core.school_catering_lock_po_release_actor('b6000000-0000-0000-0000-000000000001');
select pg_temp.k2_core_write_denied();
insert into k2_core_lock_results values('empty_ancestry',atlas_core.school_catering_corrected_allocation_ancestry('{}'::jsonb) is false);
reset role;
grant atlas_procurement_command_runtime to postgres with set false;
select ok(result,'Procurement key-only lock grant cannot update '||table_name)
from k2_core_lock_results order by table_name;
select ok(not exists(select 1 from pg_roles role cross join unnest(array[
  'atlas_core.school_catering_lock_po_release_actor(uuid)',
  'atlas_core.school_catering_corrected_allocation_ancestry(jsonb)']) helper(signature)
  where role.rolname in ('anon','authenticated','service_role')
    and has_function_privilege(role.rolname,helper.signature,'EXECUTE')),
  'private lock and ancestry helpers are inaccessible to public request roles');

create temporary table k2_results(name text primary key,response jsonb not null);
create temporary table k2_requests(name text primary key,request jsonb not null);
grant select,insert on k2_results,k2_requests to authenticated;

create function pg_temp.k2_command(contract text,reason text,version bigint,payload jsonb)
returns jsonb language sql volatile set search_path='' as $$
  select jsonb_build_object('contract_version',contract,'command_id',id,
    'correlation_id',gen_random_uuid(),'idempotency_key','k2:'||id,
    'expected_version',version,
    'requested_by_auth_subject','b6000000-0000-0000-0000-000000000101',
    'requested_at',transaction_timestamp()-interval '1 second',
    'reason_code',reason,'reason_note',null,'payload',payload)
  from (select gen_random_uuid() id) command;
$$;
grant execute on function pg_temp.k2_command(text,text,bigint,jsonb) to authenticated;

insert into k2_requests
select 'initial_save',pg_temp.k2_command('RMVP-05.v2','CONFIRMED_NEED_SAVED',b.version,
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
insert into k2_results select 'initial_save',atlas_api.save_confirmed_needs(request)
from k2_requests where name='initial_save';
reset role;
select is((select response->>'success' from k2_results where name='initial_save'),
  'true','initial authenticated human confirmation succeeds');

insert into k2_requests
select 'initial_prepare',pg_temp.k2_command('PURCHASE-COMMITMENT.v1',
  'PURCHASE_ORDERS_PREPARED',version,jsonb_build_object(
    'confirmed_need_batch_id',confirmed_need_batch_id,'service_date','2026-11-02'))
from atlas_planning.confirmed_need_batches
where confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050';
set local role authenticated;
insert into k2_results select 'initial_prepare',
  atlas_api.prepare_school_catering_purchase_orders(request)
from k2_requests where name='initial_prepare';
reset role;
select is((select response->>'success' from k2_results where name='initial_prepare'),
  'true','initial Preparation preserves ordinary release and real Handoff');

insert into k2_requests
select 'po001',pg_temp.k2_command('SCHOOL-CATERING-PROCUREMENT.v1',
  'SCHOOL_CATERING_PO_RELEASED',po.version,jsonb_build_object(
    'purchase_order_id',po.purchase_order_id,
    'expected_purchase_order_revision_id',r.purchase_order_revision_id))
from atlas_procurement.purchase_orders po
join atlas_procurement.purchase_order_revisions r using(purchase_order_id)
where po.school_catering_service_date='2026-11-02' and r.is_current;
set local role authenticated;
insert into k2_results select 'po001',atlas_api.release_school_catering_purchase_order(request)
from k2_requests where name='po001';
reset role;
select is((select response->>'success' from k2_results where name='po001'),
  'true','PO-001 is issued through the authenticated public release command');

create function pg_temp.k2_issued_snapshot(po_id uuid)
returns jsonb language sql stable set search_path='' as $$
  select jsonb_build_object('document_number',po.document_number,'supplier_id',po.supplier_id,
    'service_date',po.school_catering_service_date,'replaces_purchase_order_id',po.replaces_purchase_order_id,
    'revisions',(select jsonb_agg(to_jsonb(r) order by r.revision_number)
      from atlas_procurement.purchase_order_revisions r where r.purchase_order_id=po_id),
    'lines',(select jsonb_agg(to_jsonb(l) order by l.purchase_order_line_revision_id)
      from atlas_procurement.purchase_order_line_revisions l
      join atlas_procurement.purchase_order_revisions r using(purchase_order_revision_id)
      where r.purchase_order_id=po_id))
  from atlas_procurement.purchase_orders po where po.purchase_order_id=po_id;
$$;
create temporary table k2_issued_history as select 'po001' name,
  (response->>'purchase_order_id')::uuid po_id,
  pg_temp.k2_issued_snapshot((response->>'purchase_order_id')::uuid) facts
from k2_results where name='po001';

create function pg_temp.k2_replacement_request()
returns jsonb language sql volatile set search_path='' as $$
  select pg_temp.k2_command('SCHOOL-CATERING-PROCUREMENT.v1',
    'SCHOOL_CATERING_PO_REPLACEMENT_CREATED',po.version,jsonb_build_object(
      'replaced_purchase_order_id',po.purchase_order_id,
      'expected_purchase_order_revision_id',r.purchase_order_revision_id))
  from atlas_procurement.purchase_orders po
  join atlas_procurement.purchase_order_revisions r using(purchase_order_id)
  where po.school_catering_service_date='2026-11-02' and r.is_current
    and po.purchase_order_status='RELEASED_TO_SUPPLIER';
$$;
create function pg_temp.k2_release_request()
returns jsonb language sql volatile set search_path='' as $$
  select pg_temp.k2_command('SCHOOL-CATERING-PROCUREMENT.v1',
    'SCHOOL_CATERING_PO_RELEASED',po.version,jsonb_build_object(
      'purchase_order_id',po.purchase_order_id,
      'expected_purchase_order_revision_id',r.purchase_order_revision_id))
  from atlas_procurement.purchase_orders po
  join atlas_procurement.purchase_order_revisions r using(purchase_order_id)
  where po.school_catering_service_date='2026-11-02' and r.is_current
    and po.purchase_order_status='DRAFT';
$$;

create temporary table k2_original_source as
select b.confirmed_need_batch_id,b.current_confirmed_need_release_id,
  h.purchase_handoff_batch_id,h.version handoff_version,r.purchase_handoff_revision_id
from atlas_planning.confirmed_need_batches b
join atlas_planning.purchase_handoff_batches h using(confirmed_need_batch_id)
join atlas_planning.purchase_handoff_revisions r using(purchase_handoff_batch_id)
where b.confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050' and r.is_current;

-- A valid receipt lifecycle supplies no missing business lineage or decision.
grant atlas_procurement_command_runtime to postgres with set true;
set local role atlas_procurement_command_runtime;
insert into atlas_core.command_receipts(command_name,scope_key,idempotency_key,
  command_id,correlation_id,actor_id,expected_version,request_hash,outcome)
values('prepare_corrected_need_transfer','unsupported:k2','unsupported:k2',
  'b6900000-0000-0000-0000-000000000021',gen_random_uuid(),
  'b6000000-0000-0000-0000-000000000001',1,repeat('f',64),'IN_PROGRESS');
select atlas_core.pa_05b_finish_command(command_receipt_id,
  '{"success":true,"corrected_source_eligible":true}'::jsonb,true)
from atlas_core.command_receipts where command_id='b6900000-0000-0000-0000-000000000021';
reset role;
grant atlas_procurement_command_runtime to postgres with set false;
insert into k2_requests select 'forged_receipt_draft',pg_temp.k2_replacement_request();
set local role authenticated;
insert into k2_results select 'forged_receipt_draft',
  atlas_api.create_school_catering_purchase_order_replacement(request)
from k2_requests where name='forged_receipt_draft';
reset role;
select is((select response->>'success' from k2_results where name='forged_receipt_draft'),
  'false','a manufactured completed transfer receipt alone cannot enable a replacement Draft');
select is((select count(*) from atlas_procurement.purchase_orders
  where purchase_order_kind='SCHOOL_CATERING'),1::bigint,
  'manufactured receipt creates no PO root or supplier commitment');

insert into k2_requests
select 'correction110',pg_temp.k2_command('RMVP-05.v3','CONFIRMED_NEED_SAVED',b.version,
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
      'reason_note','Correct actual Need after supplier release'))))
from atlas_planning.confirmed_need_batches b cross join k2_original_source o
join atlas_planning.confirmed_need_lines l on l.confirmed_need_batch_id=o.confirmed_need_batch_id
join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
where b.confirmed_need_batch_id=o.confirmed_need_batch_id and r.is_current
  and l.ingredient_id='b6500000-0000-0000-0000-000000000006';
set local role authenticated;
insert into k2_results select 'correction110',atlas_api.save_confirmed_needs(request)
from k2_requests where name='correction110';
reset role;
select is((select response->>'success' from k2_results where name='correction110'),
  'true','authentic K1 correction from 100 to 110 succeeds');

insert into k2_requests
select 'allocation110',pg_temp.k2_command('CONFIRMED-SUPPLIER-ALLOCATION.v1',
  'CONFIRMED_SUPPLIER_ALLOCATION_SAVED',f.version,jsonb_build_object(
    'family',jsonb_build_object('service_date',p->'service_date',
      'delivery_location_id',p->'delivery_location_id','ingredient_id',p->'ingredient_id',
      'unit_id',p->'unit_id','expected_source_fingerprint',p->'source_fingerprint',
      'expected_source_batch_id',p->'source_confirmed_need_batch_id',
      'expected_source_batch_version',p->'source_confirmed_need_batch_version'),
    'splits',jsonb_build_array(jsonb_build_object('supplier_id',s.supplier_id,
      'allocated_quantity','110.000000','supplier_note','Accepted corrected quantity'))))
from atlas_core.purchase_review_confirmed_sources('2026-11-02','2026-11-02') p
join atlas_procurement.school_catering_allocation_families f
  on f.ingredient_id=(p->>'ingredient_id')::uuid
  and f.delivery_location_id=(p->>'delivery_location_id')::uuid
  and f.service_date=(p->>'service_date')::date and f.unit_id=(p->>'unit_id')::uuid
join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
join atlas_procurement.school_catering_allocation_supplier_splits s using(family_revision_id)
where r.is_current and f.ingredient_id='b6500000-0000-0000-0000-000000000006';
set local role authenticated;
insert into k2_results select 'allocation110',atlas_api.save_confirmed_supplier_allocation(request)
from k2_requests where name='allocation110';
reset role;
select is((select response->>'success' from k2_results where name='allocation110'),
  'true','affected 110 Supplier Allocation is explicitly accepted');

insert into k2_requests
select 'prepare110',pg_temp.k2_command('PURCHASE-COMMITMENT.v1',
  'PURCHASE_ORDERS_PREPARED',version,jsonb_build_object(
    'confirmed_need_batch_id',confirmed_need_batch_id,'service_date','2026-11-02'))
from atlas_planning.confirmed_need_batches
where confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050';
set local role authenticated;
insert into k2_results select 'prepare110',atlas_api.prepare_school_catering_purchase_orders(request)
from k2_requests where name='prepare110';
reset role;
select is((select response->>'success' from k2_results where name='prepare110'),
  'true','K2 Preparation accepts authentic correction without another Planning release');

insert into k2_requests select 'draft002',pg_temp.k2_replacement_request();
set local role authenticated;
insert into k2_results select 'draft002',atlas_api.create_school_catering_purchase_order_replacement(request)
from k2_requests where name='draft002';
reset role;
select is((select response->>'success' from k2_results where name='draft002'),
  'true','complete replacement Draft for PO-002 is generated through the public command');
select is((select po.purchase_order_status from atlas_procurement.purchase_orders po
  join k2_issued_history history on po.purchase_order_id=history.po_id where history.name='po001'),
  'RELEASED_TO_SUPPLIER','Preparation and replacement Draft leave PO-001 active');

insert into k2_requests select 'po002',pg_temp.k2_release_request();

create temporary table k2_proof_cases(name text,payload jsonb,expected boolean);
insert into k2_proof_cases
select 'valid accepted corrected source',to_jsonb(family)||jsonb_build_object(
  'source_batch_id',revision.source_confirmed_need_batch_id,
  'source_version',revision.source_confirmed_need_batch_version,
  'contributions',(select jsonb_agg(to_jsonb(c))
    from atlas_procurement.school_catering_allocation_family_contributions c
    where c.family_revision_id=revision.family_revision_id)),true
from atlas_procurement.school_catering_allocation_families family
join atlas_procurement.school_catering_allocation_family_revisions revision using(family_id)
where family.service_date='2026-11-02' and family.ingredient_id='b6500000-0000-0000-0000-000000000006'
  and revision.is_current;
insert into k2_proof_cases
select 'unknown appended contribution',jsonb_set(payload,'{contributions}',payload->'contributions'||
  jsonb_build_array(jsonb_build_object('confirmed_need_line_revision_id',gen_random_uuid(),
    'confirmed_need_line_decision_id',gen_random_uuid(),'contribution_quantity','1.000000'))),false
from k2_proof_cases where expected;
insert into k2_proof_cases
select 'mismatched revision and decision',jsonb_set(payload,'{contributions,0,confirmed_need_line_revision_id}',
  to_jsonb('b6560000-0000-0000-0000-000000000011'::text)),false from k2_proof_cases where expected;
insert into k2_proof_cases
select 'wrong contribution quantity',jsonb_set(payload,'{contributions,0,contribution_quantity}',
  to_jsonb('999.000000'::text)),false from k2_proof_cases where expected;
insert into k2_proof_cases
select 'wrong controlled Unit',jsonb_set(payload,'{unit_id}',to_jsonb(gen_random_uuid())),false
from k2_proof_cases where expected;
create temporary table k2_proof_results(name text,result boolean,expected boolean);
grant select on k2_proof_cases to atlas_procurement_command_runtime;
grant insert on k2_proof_results to atlas_procurement_command_runtime;
grant atlas_procurement_command_runtime to postgres with set true;
set local role atlas_procurement_command_runtime;
insert into k2_proof_results select name,
  atlas_core.school_catering_corrected_allocation_ancestry(payload),expected from k2_proof_cases;
reset role;
grant atlas_procurement_command_runtime to postgres with set false;
select is(result,expected,'immutable proof: '||name) from k2_proof_results order by name;

create function pg_temp.k2_unsupported_history_probe()
returns jsonb language plpgsql volatile set search_path='' as $$
declare prior record; member record; revision_id uuid;
begin
  begin
    select r.* into strict prior from atlas_procurement.purchase_order_revisions r
    join atlas_procurement.purchase_orders po using(purchase_order_id)
    where po.purchase_order_status='DRAFT' and po.school_catering_service_date='2026-11-02'
      and r.is_current;
    select split.supplier_split_id,split.allocated_quantity,f.*,line.purchase_order_line_id,
      line.purchase_order_line_revision_id into strict member
    from atlas_procurement.school_catering_allocation_families f
    join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
    join atlas_procurement.school_catering_allocation_supplier_splits split using(family_revision_id)
    join atlas_procurement.purchase_order_line_revisions line
      on line.purchase_order_revision_id=prior.purchase_order_revision_id and line.ingredient_id=f.ingredient_id
    where f.ingredient_id='b6500000-0000-0000-0000-000000000006'
      and r.source_kind='CONFIRMED_NEED' and not r.is_current;
    insert into atlas_procurement.purchase_order_revisions(purchase_order_id,revision_number,revision_kind,
      revision_status,is_current,predecessor_revision_id,service_date,delivery_location_id,
      supplier_name_snapshot,delivery_location_snapshot,command_id)
    values(prior.purchase_order_id,prior.revision_number+1,'SUPERSEDING','DRAFT',false,
      prior.purchase_order_revision_id,prior.service_date,null,prior.supplier_name_snapshot,
      prior.delivery_location_snapshot,prior.command_id)
    returning purchase_order_revision_id into revision_id;
    insert into atlas_procurement.purchase_order_line_revisions(purchase_order_revision_id,purchase_order_line_id,
      school_catering_allocation_supplier_split_id,ingredient_id,ordered_quantity,unit_id,
      delivery_location_id,service_date,predecessor_revision_id)
    values(revision_id,member.purchase_order_line_id,member.supplier_split_id,member.ingredient_id,
      member.allocated_quantity,member.unit_id,member.delivery_location_id,member.service_date,
      member.purchase_order_line_revision_id);
    set constraints all immediate;
    raise exception using errcode='K2H01',message='Unsupported history was accepted';
  exception when others then return jsonb_build_object('sqlstate',sqlstate,'message',sqlerrm); end;
end;
$$;
create temporary table k2_history_probe as select pg_temp.k2_unsupported_history_probe() result;
select is(result->>'sqlstate','23514','noncurrent Draft history cannot launder an initial pre-issuance CN allocation')
from k2_history_probe;
select is(result->>'message','Official PO requires Purchase Handoff allocation authority.',
  'historical rejection comes from the official source guard') from k2_history_probe;

create function pg_temp.k2_commitment_state()
returns jsonb language sql stable set search_path='' as $$
  select jsonb_build_object(
    'roots',(select jsonb_agg(to_jsonb(po) order by purchase_order_id)
      from atlas_procurement.purchase_orders po),
    'revisions',(select jsonb_agg(to_jsonb(r) order by purchase_order_revision_id)
      from atlas_procurement.purchase_order_revisions r),
    'lines',(select jsonb_agg(to_jsonb(l) order by purchase_order_line_revision_id)
      from atlas_procurement.purchase_order_line_revisions l));
$$;
create function pg_temp.k2_forced_failure() returns trigger
language plpgsql set search_path='' as $$
begin raise exception using errcode='23514',message='K2 deliberate release rollback'; end $$;
create function pg_temp.k2_release_probe(fault text)
returns jsonb language plpgsql volatile set search_path='' as $$
declare response jsonb; source_response jsonb; command jsonb; before_state jsonb; answer jsonb;
begin
  begin
    if fault='no_planning_roles' then
      delete from atlas_core.role_capabilities binding using atlas_core.capabilities capability
      where binding.capability_id=capability.capability_id
        and binding.role_id='b6000000-0000-0000-0000-000000000003'
        and capability.capability_code in('planning.need_generation.write',
          'confirmed_need_release.release','confirmed_need_quantities.confirm');
    elsif fault='no_procurement_write' then
      delete from atlas_core.role_capabilities binding using atlas_core.capabilities capability
      where binding.capability_id=capability.capability_id
        and binding.role_id='b6000000-0000-0000-0000-000000000003'
        and capability.capability_code='procurement.school_catering.write';
    elsif fault='inactive_actor' then
      update atlas_core.actors set actor_status='INACTIVE',deactivated_at=transaction_timestamp()
      where actor_id='b6000000-0000-0000-0000-000000000001';
    elsif fault='wrong_scope' then
      delete from atlas_core.actor_scopes
      where actor_id='b6000000-0000-0000-0000-000000000001';
    elsif fault='inactive_supplier' then
      update atlas_admin.suppliers set supplier_status='INACTIVE'
      where supplier_id=(select supplier_id from atlas_procurement.purchase_orders
        where purchase_order_id=(select (request#>>'{payload,purchase_order_id}')::uuid
          from k2_requests where name='po002'));
    elsif fault='upstream_reopened' then
      select pg_temp.k2_command('RMVP-03A.v1','WEEKLY_MENU_REOPENED',version,
        jsonb_build_object('week_start','2026-11-02'))||jsonb_build_object(
          'reason_note','Disposable upstream correction') into command
      from atlas_planning.weekly_menus where week_start='2026-11-02';
      set local role authenticated;
      source_response:=atlas_api.reopen_weekly_menu(command);
      reset role;
    elsif fault='new_need_decision' then
      select pg_temp.k2_command('RMVP-05.v3','CONFIRMED_NEED_SAVED',b.version,
        jsonb_build_object('confirmed_need_batch_id',b.confirmed_need_batch_id,
          'correction',(request#>'{payload,correction}')||jsonb_build_object(
            'expected_source_fingerprint',encode(sha256(convert_to(
              atlas_core.rmvp_07_validated_facts_projection(b.confirmed_need_batch_id)::text,'UTF8')),'hex')),
          'lines',jsonb_build_array((request#>'{payload,lines,0}')||jsonb_build_object(
            'expected_current_revision_id',r.confirmed_need_line_revision_id,
            'expected_current_decision_id',l.current_confirmed_need_line_decision_id,
            'proposed_confirmed_quantity','111.000000')))) into command
      from k2_requests cross join atlas_planning.confirmed_need_batches b
      join atlas_planning.confirmed_need_lines l using(confirmed_need_batch_id)
      join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
      where name='correction110' and b.confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050'
        and l.ingredient_id='b6500000-0000-0000-0000-000000000006' and r.is_current;
      set local role authenticated;
      source_response:=atlas_api.save_confirmed_needs(command);
      reset role;
    elsif fault='rollback' then
      create trigger k2_deliberate_failure
      after insert on atlas_procurement.purchase_order_line_revisions
      for each row execute function pg_temp.k2_forced_failure();
    end if;
    before_state:=pg_temp.k2_commitment_state();
    select request into command from k2_requests where name='po002';
    command:=command||jsonb_build_object('command_id',gen_random_uuid(),
      'idempotency_key','k2-probe:'||gen_random_uuid());
    set local role authenticated;
    response:=atlas_api.release_school_catering_purchase_order(command);
    reset role;
    answer:=jsonb_build_object('response',response,'source_response',source_response,
      'commitment_unchanged',pg_temp.k2_commitment_state()=before_state);
    raise exception using errcode='K2T01';
  exception when sqlstate 'K2T01' then return answer; end;
end;
$$;
create temporary table k2_release_probes as
select fault,pg_temp.k2_release_probe(fault) result from (values
  ('no_planning_roles'),('no_procurement_write'),('inactive_actor'),('wrong_scope'),
  ('inactive_supplier'),('upstream_reopened'),('new_need_decision'),('rollback')) cases(fault);
select is(result#>>'{response,success}','true',
  'Procurement releaser needs no current Planning capabilities after authentic K1 Save')
from k2_release_probes where fault='no_planning_roles';
select is(result#>>'{response,success}','false','release rejects '||fault)
from k2_release_probes where fault<>'no_planning_roles' order by fault;
select is(result->>'commitment_unchanged','true','rejected '||fault||' leaves every PO fact unchanged')
from k2_release_probes where fault<>'no_planning_roles' order by fault;
select is(result#>>'{source_response,success}','true',fault||' is performed by its real public command')
from k2_release_probes where fault in('upstream_reopened','new_need_decision') order by fault;

set local role authenticated;
insert into k2_results select 'po002',atlas_api.release_school_catering_purchase_order(request)
from k2_requests where name='po002';
reset role;
select is((select response->>'success' from k2_results where name='po002'),
  'true','explicit authenticated Release issues PO-002');
select is((select line.ordered_quantity::text from atlas_procurement.purchase_order_line_revisions line
  join atlas_procurement.purchase_order_revisions revision using(purchase_order_revision_id)
  join k2_results result on revision.purchase_order_id=(result.response->>'purchase_order_id')::uuid
  where result.name='po002' and revision.is_current
    and line.ingredient_id='b6500000-0000-0000-0000-000000000006'),
  '110.000000','PO-002 contains the complete 110, not a difference-only 10');
select is((select po.purchase_order_status from atlas_procurement.purchase_orders po
  join k2_issued_history history on po.purchase_order_id=history.po_id where history.name='po001'),
  'SUPERSEDED','PO-002 release supersedes PO-001 atomically');
select is(pg_temp.k2_issued_snapshot(po_id),facts,
  'PO-001 number, original 100, revisions, School snapshots and export facts stay identical')
from k2_issued_history where name='po001';
insert into k2_issued_history select 'po002',(response->>'purchase_order_id')::uuid,
  pg_temp.k2_issued_snapshot((response->>'purchase_order_id')::uuid)
from k2_results where name='po002';

insert into k2_requests
select 'correction90',pg_temp.k2_command('RMVP-05.v3','CONFIRMED_NEED_SAVED',b.version,
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
      'proposed_confirmed_quantity','90.000000',
      'reason_code','OPERATIONAL_QUANTITY_ADJUSTMENT','reason_note','Second actual Need correction'))))
from atlas_planning.confirmed_need_batches b cross join k2_original_source o
join atlas_planning.confirmed_need_lines l on l.confirmed_need_batch_id=o.confirmed_need_batch_id
join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
where b.confirmed_need_batch_id=o.confirmed_need_batch_id and r.is_current
  and l.ingredient_id='b6500000-0000-0000-0000-000000000006';
set local role authenticated;
insert into k2_results select 'correction90',atlas_api.save_confirmed_needs(request)
from k2_requests where name='correction90';
reset role;
select is((select response->>'success' from k2_results where name='correction90'),
  'true','second authentic K1 correction from 110 to 90 succeeds after PO-002');

insert into k2_requests
select 'allocation90',pg_temp.k2_command('CONFIRMED-SUPPLIER-ALLOCATION.v1',
  'CONFIRMED_SUPPLIER_ALLOCATION_SAVED',f.version,jsonb_build_object(
    'family',jsonb_build_object('service_date',p->'service_date',
      'delivery_location_id',p->'delivery_location_id','ingredient_id',p->'ingredient_id',
      'unit_id',p->'unit_id','expected_source_fingerprint',p->'source_fingerprint',
      'expected_source_batch_id',p->'source_confirmed_need_batch_id',
      'expected_source_batch_version',p->'source_confirmed_need_batch_version'),
    'splits',jsonb_build_array(jsonb_build_object('supplier_id',s.supplier_id,
      'allocated_quantity','90.000000','supplier_note','Accepted second corrected quantity'))))
from atlas_core.purchase_review_confirmed_sources('2026-11-02','2026-11-02') p
join atlas_procurement.school_catering_allocation_families f
  on f.ingredient_id=(p->>'ingredient_id')::uuid
  and f.delivery_location_id=(p->>'delivery_location_id')::uuid
  and f.service_date=(p->>'service_date')::date and f.unit_id=(p->>'unit_id')::uuid
join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
join atlas_procurement.school_catering_allocation_supplier_splits s using(family_revision_id)
where r.is_current and f.ingredient_id='b6500000-0000-0000-0000-000000000006';
set local role authenticated;
insert into k2_results select 'allocation90',atlas_api.save_confirmed_supplier_allocation(request)
from k2_requests where name='allocation90';
reset role;
select is((select response->>'success' from k2_results where name='allocation90'),
  'true','affected 90 Supplier Allocation is explicitly reaccepted');
insert into k2_requests
select 'prepare90',pg_temp.k2_command('PURCHASE-COMMITMENT.v1',
  'PURCHASE_ORDERS_PREPARED',version,jsonb_build_object(
    'confirmed_need_batch_id',confirmed_need_batch_id,'service_date','2026-11-02'))
from atlas_planning.confirmed_need_batches
where confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050';
set local role authenticated;
insert into k2_results select 'prepare90',atlas_api.prepare_school_catering_purchase_orders(request)
from k2_requests where name='prepare90';
reset role;
select is((select response->>'success' from k2_results where name='prepare90'),
  'true','second Preparation preserves the original release and Handoff');
insert into k2_requests select 'draft003',pg_temp.k2_replacement_request();
set local role authenticated;
insert into k2_results select 'draft003',atlas_api.create_school_catering_purchase_order_replacement(request)
from k2_requests where name='draft003';
reset role;
select is((select response->>'success' from k2_results where name='draft003'),
  'true','second complete replacement Draft succeeds');
insert into k2_requests select 'po003',pg_temp.k2_release_request();
set local role authenticated;
insert into k2_results select 'po003',atlas_api.release_school_catering_purchase_order(request)
from k2_requests where name='po003';
insert into k2_results select 'replay003',atlas_api.release_school_catering_purchase_order(request)
from k2_requests where name='po003';
reset role;
select is((select response->>'success' from k2_results where name='po003'),
  'true','explicit authenticated Release issues PO-003');
select is((select line.ordered_quantity::text from atlas_procurement.purchase_order_line_revisions line
  join atlas_procurement.purchase_order_revisions revision using(purchase_order_revision_id)
  join k2_results result on revision.purchase_order_id=(result.response->>'purchase_order_id')::uuid
  where result.name='po003' and revision.is_current
    and line.ingredient_id='b6500000-0000-0000-0000-000000000006'),
  '90.000000','PO-003 contains complete 90');
select is((select count(distinct response->>'document_number') from k2_results
  where name in ('po001','po002','po003')),3::bigint,'three releases have three independent official numbers');
select is((select response from k2_results where name='replay003'),
  (select response from k2_results where name='po003'),'duplicate Release returns exactly the original PO-003 response');
select is(pg_temp.k2_issued_snapshot(po_id),facts,
  name||' immutable history remains identical after PO-003') from k2_issued_history order by name;

-- Real R20/B5/H3 generation, two Schools sharing one location, two Suppliers.
\ir ../local/atlas_b1_two_school_need_fixture.sql
insert into atlas_admin.suppliers(supplier_id,supplier_code,supplier_name,document_code)
values(pg_temp.ng_id(61),'k2-b1-second-supplier','K2 B1 second Supplier','K2-B1-2');
insert into atlas_admin.supplier_eligibilities(supplier_id,ingredient_id,effective_from,priority)
select pg_temp.ng_id(61),pg_temp.ng_id(2001),'2050-01-01',2;
create temporary table k2_b1_batch as
select b.confirmed_need_batch_id from atlas_planning.confirmed_need_batches b
join atlas_planning.need_generation_runs run on run.need_generation_run_id=b.current_need_generation_run_id
where run.generated_by_actor_id=pg_temp.ng_id(1) and run.period_start='2050-09-19';
insert into k2_requests
select 'b1_save',pg_temp.ng_request('RMVP-05.v2','CONFIRMED_NEED_SAVED',jsonb_build_object(
  'confirmed_need_batch_id',b.confirmed_need_batch_id,'lines',(
    select jsonb_agg(jsonb_build_object('confirmed_need_line_id',l.confirmed_need_line_id,
      'expected_current_revision_id',r.confirmed_need_line_revision_id,
      'expected_current_decision_id',l.current_confirmed_need_line_decision_id,
      'proposed_confirmed_quantity',r.confirmed_quantity::text,
      'reason_code','PROPOSAL_ACCEPTED','reason_note',null) order by l.confirmed_need_line_id)
    from atlas_planning.confirmed_need_lines l
    join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
    where l.confirmed_need_batch_id=b.confirmed_need_batch_id and r.is_current)))
  ||jsonb_build_object('expected_version',b.version,'reason_note',null)
from atlas_planning.confirmed_need_batches b join k2_b1_batch using(confirmed_need_batch_id);
set local role authenticated;
insert into k2_results select 'b1_save',atlas_api.save_confirmed_needs(request)
from k2_requests where name='b1_save';
reset role;
select is((select response->>'success' from k2_results where name='b1_save'),'true',
  'B1 real human confirmation keeps R20+B5+H3 and the other School20');

-- Public regeneration carries unchanged authority before issuance. Later K1
-- must accept both that carried predecessor and the other School's carried line.
create temporary table k2_b1_before_carry as
select l.confirmed_need_line_id,l.current_confirmed_need_line_decision_id,r.confirmed_need_line_revision_id
from atlas_planning.confirmed_need_lines l
join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
join k2_b1_batch target on target.confirmed_need_batch_id=l.confirmed_need_batch_id
where r.is_current and l.ingredient_id=pg_temp.ng_id(2001);
with rows as (
  select (request#>'{payload,rows}')||jsonb_build_array(jsonb_build_object(
    'service_date','2050-09-19','school_id',pg_temp.ng_id(5001),'ingredient_id',pg_temp.ng_id(2002),
    'pantry_need_purpose_id',pg_temp.ng_id(40),'requested_quantity',1,'note',null,
    'source_request_reference','K2:carry-other-family','source_row_reference','K2:carry-other-family')) value,
    request->'payload' payload from ng_requests where name='pantry'
)
insert into k2_requests
select 'b1_carry_pantry',pg_temp.ng_request('PANTRY-02.v3','PANTRY_SAVED',payload||jsonb_build_object(
  'rows',value,'source_signature',atlas_core.pantry_02_signature('2050-09-19',false,
    atlas_core.pantry_02_canonical_rows('2050-09-19',value)),
  'expected_source_signature',batch.source_signature))||jsonb_build_object('expected_version',batch.version)
from rows cross join atlas_planning.pantry_need_batches batch where batch.week_start='2050-09-19';
set local role authenticated;
insert into k2_results select name,atlas_api.save_pantry(request)
from k2_requests where name='b1_carry_pantry';
reset role;
select is((select response->>'success' from k2_results where name='b1_carry_pantry'),'true',
  'unrelated B1 Pantry correction uses the public source writer before issuance');
insert into k2_requests
select 'b1_carry_generate',pg_temp.ng_request('RMVP-04.v3','UPSTREAM_SOURCE_CHANGED',jsonb_build_object(
  'service_date','2050-09-19','expected_current_need_generation_run_id',b.current_need_generation_run_id))
  ||jsonb_build_object('expected_version',b.current_need_generation_run_version)
from atlas_planning.confirmed_need_batches b join k2_b1_batch using(confirmed_need_batch_id);
set local role authenticated;
insert into k2_results select name,atlas_api.execute_need_generation(request)
from k2_requests where name='b1_carry_generate';
reset role;
select is((select response->>'success' from k2_results where name='b1_carry_generate'),'true',
  'public regeneration establishes approved carried authority');
select ok((select count(*)=2 and bool_and(
    r.confirmed_need_line_revision_id<>prior.confirmed_need_line_revision_id
    and l.current_confirmed_need_line_decision_id=prior.current_confirmed_need_line_decision_id
    and atlas_core.planning_contract_02b_decision_authorizes_revision(
      l.current_confirmed_need_line_decision_id,l.confirmed_need_line_id,r.confirmed_need_line_revision_id))
  from k2_b1_before_carry prior join atlas_planning.confirmed_need_lines l using(confirmed_need_line_id)
  join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id) where r.is_current),
  'both target Schools retain exact carried human authority through successor revisions');
insert into k2_requests
select 'b1_carry_save',pg_temp.ng_request('RMVP-05.v2','CONFIRMED_NEED_SAVED',jsonb_build_object(
  'confirmed_need_batch_id',b.confirmed_need_batch_id,'lines',(
    select jsonb_agg(jsonb_build_object('confirmed_need_line_id',l.confirmed_need_line_id,
      'expected_current_revision_id',r.confirmed_need_line_revision_id,'expected_current_decision_id',null,
      'proposed_confirmed_quantity',r.confirmed_quantity::text,'reason_code','PROPOSAL_ACCEPTED','reason_note',null))
    from atlas_planning.confirmed_need_lines l join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
    where l.confirmed_need_batch_id=b.confirmed_need_batch_id and r.is_current
      and l.current_confirmed_need_line_decision_id is null)))
  ||jsonb_build_object('expected_version',b.version,'reason_note',null)
from atlas_planning.confirmed_need_batches b join k2_b1_batch using(confirmed_need_batch_id);
set local role authenticated;
insert into k2_results select name,atlas_api.save_confirmed_needs(request)
from k2_requests where name='b1_carry_save';
reset role;
select is((select response->>'success' from k2_results where name='b1_carry_save'),'true',
  'selective human Save confirms only invalidated lines and leaves carried authority intact');

create function pg_temp.k2_b1_allocation(a numeric,b numeric)
returns jsonb language sql volatile set search_path='' as $$
  select pg_temp.ng_request('CONFIRMED-SUPPLIER-ALLOCATION.v1',
    'CONFIRMED_SUPPLIER_ALLOCATION_SAVED',jsonb_build_object(
      'family',jsonb_build_object('service_date',p->'service_date',
        'delivery_location_id',p->'delivery_location_id','ingredient_id',p->'ingredient_id',
        'unit_id',p->'unit_id','expected_source_fingerprint',p->'source_fingerprint',
        'expected_source_batch_id',p->'source_confirmed_need_batch_id',
        'expected_source_batch_version',p->'source_confirmed_need_batch_version'),
      'splits',jsonb_build_array(jsonb_build_object('supplier_id',pg_temp.ng_id(60),
        'allocated_quantity',a::text,'supplier_note','Whole shared-School allocation'))
        ||case when b>0 then jsonb_build_array(jsonb_build_object('supplier_id',pg_temp.ng_id(61),
          'allocated_quantity',b::text,'supplier_note','Second Supplier accepted note')) else '[]'::jsonb end))
    ||jsonb_build_object('expected_version',coalesce(f.version,0),'reason_note',null)
  from atlas_core.purchase_review_confirmed_sources('2050-09-19','2050-09-19') p
  left join atlas_procurement.school_catering_allocation_families f
    on f.service_date=(p->>'service_date')::date
    and f.delivery_location_id=(p->>'delivery_location_id')::uuid
    and f.ingredient_id=(p->>'ingredient_id')::uuid and f.unit_id=(p->>'unit_id')::uuid
  where p->>'ingredient_id'=pg_temp.ng_id(2001)::text;
$$;
insert into k2_requests values('b1_allocation48',pg_temp.k2_b1_allocation(30,18));
set local role authenticated;
insert into k2_results select 'b1_allocation48',atlas_api.save_confirmed_supplier_allocation(request)
from k2_requests where name='b1_allocation48';
reset role;
select is((select response->>'success' from k2_results where name='b1_allocation48'),'true',
  'B1 explicit initial two-Supplier split totals the whole shared family48');
insert into k2_requests
select 'b1_prepare48',pg_temp.ng_request('PURCHASE-COMMITMENT.v1','PURCHASE_ORDERS_PREPARED',
  jsonb_build_object('confirmed_need_batch_id',b.confirmed_need_batch_id,'service_date','2050-09-19'))
  ||jsonb_build_object('expected_version',b.version,'reason_note',null)
from atlas_planning.confirmed_need_batches b join k2_b1_batch using(confirmed_need_batch_id);
set local role authenticated;
insert into k2_results select 'b1_prepare48',atlas_api.prepare_school_catering_purchase_orders(request)
from k2_requests where name='b1_prepare48';
reset role;
select is((select response->>'success' from k2_results where name='b1_prepare48'),'true',
  'B1 initial two-Supplier Preparation succeeds');
insert into k2_requests
select 'b1_po001:'||po.supplier_id,pg_temp.ng_request('SCHOOL-CATERING-PROCUREMENT.v1',
  'SCHOOL_CATERING_PO_RELEASED',jsonb_build_object('purchase_order_id',po.purchase_order_id,
    'expected_purchase_order_revision_id',r.purchase_order_revision_id))
  ||jsonb_build_object('expected_version',po.version,'reason_note',null)
from atlas_procurement.purchase_orders po
join atlas_procurement.purchase_order_revisions r using(purchase_order_id)
where po.school_catering_service_date='2050-09-19' and r.is_current;
set local role authenticated;
insert into k2_results select name,atlas_api.release_school_catering_purchase_order(request)
from k2_requests where name like 'b1_po001:%';
reset role;
select is((select count(*) from k2_results where name like 'b1_po001:%'
  and response->>'success'='true'),2::bigint,'both initial shared-School Supplier POs are actually released');
insert into k2_issued_history select name,(response->>'purchase_order_id')::uuid,
  pg_temp.k2_issued_snapshot((response->>'purchase_order_id')::uuid)
from k2_results where name like 'b1_po001:%';
create temporary table k2_b1_unchanged as
select l.confirmed_need_line_id,to_jsonb(r) revision,to_jsonb(d) decision
from atlas_planning.confirmed_need_lines l
join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
join atlas_planning.confirmed_need_line_decisions d
  on d.confirmed_need_line_decision_id=l.current_confirmed_need_line_decision_id
join k2_b1_batch target on target.confirmed_need_batch_id=l.confirmed_need_batch_id
where r.is_current and not(l.school_id=pg_temp.ng_id(5001) and l.ingredient_id=pg_temp.ng_id(2001));
insert into k2_requests
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
    'reason_note','B1 actual quantity correction preserves R20/B5/H3'))))
  ||jsonb_build_object('expected_version',b.version,'reason_note',null)
from atlas_planning.confirmed_need_batches b join k2_b1_batch using(confirmed_need_batch_id)
join atlas_planning.confirmed_need_lines l using(confirmed_need_batch_id)
join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
join atlas_planning.purchase_handoff_batches h on h.confirmed_need_batch_id=b.confirmed_need_batch_id
join atlas_planning.purchase_handoff_revisions hr using(purchase_handoff_batch_id)
where l.school_id=pg_temp.ng_id(5001) and l.ingredient_id=pg_temp.ng_id(2001)
  and r.is_current and hr.is_current;
set local role authenticated;
insert into k2_results select 'b1_correct30',atlas_api.save_confirmed_needs(request)
from k2_requests where name='b1_correct30';
reset role;
select is((select response->>'success' from k2_results where name='b1_correct30'),'true',
  'B1 public K1 correction changes School A28 to30 while School B20 retains its identity');

-- Removing a previously issued Supplier never auto-cancels its commitment.
savepoint b1_removed_supplier;
insert into k2_requests values('b1_removed_allocation',pg_temp.k2_b1_allocation(50,0));
set local role authenticated;
insert into k2_results select name,atlas_api.save_confirmed_supplier_allocation(request)
from k2_requests where name='b1_removed_allocation';
reset role;
select is((select response->>'success' from k2_results where name='b1_removed_allocation'),'true',
  'removed-Supplier scenario uses an authentic explicit allocation Save');
select is(atlas_core.school_catering_po_commitment_state(po.purchase_order_id,r.purchase_order_revision_id),
  'CANCELLATION_REQUIRED','removed Supplier keeps a cancellation obligation')
from atlas_procurement.purchase_orders po
join atlas_procurement.purchase_order_revisions r using(purchase_order_id)
where po.school_catering_service_date='2050-09-19' and po.supplier_id=pg_temp.ng_id(61) and r.is_current;
insert into k2_requests
select 'b1_removed_replacement',pg_temp.ng_request('SCHOOL-CATERING-PROCUREMENT.v1',
  'SCHOOL_CATERING_PO_REPLACEMENT_CREATED',jsonb_build_object('replaced_purchase_order_id',po.purchase_order_id,
    'expected_purchase_order_revision_id',r.purchase_order_revision_id))
  ||jsonb_build_object('expected_version',po.version,'reason_note',null)
from atlas_procurement.purchase_orders po
join atlas_procurement.purchase_order_revisions r using(purchase_order_id)
where po.school_catering_service_date='2050-09-19' and po.supplier_id=pg_temp.ng_id(61) and r.is_current;
set local role authenticated;
insert into k2_results select name,atlas_api.create_school_catering_purchase_order_replacement(request)
from k2_requests where name='b1_removed_replacement';
reset role;
select is((select response->>'error_code' from k2_results where name='b1_removed_replacement'),
  'CANCELLATION_REQUIRED','public replacement refuses a zero-Supplier document');
rollback to savepoint b1_removed_supplier;

insert into k2_requests values('b1_allocation50',pg_temp.k2_b1_allocation(32,18));
set local role authenticated;
insert into k2_results select name,atlas_api.save_confirmed_supplier_allocation(request)
from k2_requests where name='b1_allocation50';
reset role;
select is((select response->>'success' from k2_results where name='b1_allocation50'),'true',
  'B1 corrected shared-School family50 requires explicit two-Supplier acceptance');
insert into k2_requests
select 'b1_prepare50',pg_temp.ng_request('PURCHASE-COMMITMENT.v1','PURCHASE_ORDERS_PREPARED',
  jsonb_build_object('confirmed_need_batch_id',b.confirmed_need_batch_id,'service_date','2050-09-19'))
  ||jsonb_build_object('expected_version',b.version,'reason_note',null)
from atlas_planning.confirmed_need_batches b join k2_b1_batch using(confirmed_need_batch_id);
set local role authenticated;
insert into k2_results select 'b1_prepare50',atlas_api.prepare_school_catering_purchase_orders(request)
from k2_requests where name='b1_prepare50';
reset role;
select is((select response->>'success' from k2_results where name='b1_prepare50'),'true',
  'B1 corrected Preparation validates every family across both Schools');
insert into k2_requests
select 'b1_draft002:'||po.supplier_id,pg_temp.ng_request('SCHOOL-CATERING-PROCUREMENT.v1',
  'SCHOOL_CATERING_PO_REPLACEMENT_CREATED',jsonb_build_object('replaced_purchase_order_id',po.purchase_order_id,
    'expected_purchase_order_revision_id',r.purchase_order_revision_id))
  ||jsonb_build_object('expected_version',po.version,'reason_note',null)
from atlas_procurement.purchase_orders po
join atlas_procurement.purchase_order_revisions r using(purchase_order_id)
where po.school_catering_service_date='2050-09-19' and po.purchase_order_status='RELEASED_TO_SUPPLIER' and r.is_current;
set local role authenticated;
insert into k2_results select name,atlas_api.create_school_catering_purchase_order_replacement(request)
from k2_requests where name like 'b1_draft002:%';
reset role;
select is((select count(*) from k2_results where name like 'b1_draft002:%'
  and response->>'success'='true'),2::bigint,'both Suppliers receive complete replacement Drafts');
insert into k2_requests
select 'b1_po002:'||po.supplier_id,pg_temp.ng_request('SCHOOL-CATERING-PROCUREMENT.v1',
  'SCHOOL_CATERING_PO_RELEASED',jsonb_build_object('purchase_order_id',po.purchase_order_id,
    'expected_purchase_order_revision_id',r.purchase_order_revision_id))
  ||jsonb_build_object('expected_version',po.version,'reason_note',null)
from atlas_procurement.purchase_orders po
join atlas_procurement.purchase_order_revisions r using(purchase_order_id)
where po.school_catering_service_date='2050-09-19' and po.purchase_order_status='DRAFT' and r.is_current;

-- A later allocation in another family cannot leave an omitted Supplier.
savepoint b1_omitted_supplier;
insert into atlas_admin.suppliers(supplier_id,supplier_code,supplier_name,document_code)
values(pg_temp.ng_id(62),'k2-b1-third-supplier','K2 B1 third Supplier','K2-B1-3');
insert into atlas_admin.supplier_eligibilities(supplier_id,ingredient_id,effective_from,priority)
values(pg_temp.ng_id(62),pg_temp.ng_id(2002),'2050-01-01',2);
insert into k2_requests
select 'b1_reassign_other_family',pg_temp.ng_request('SCHOOL-CATERING-PROCUREMENT.v1',
  'SCHOOL_CATERING_SUPPLIER_ALLOCATION_SAVED',jsonb_build_object(
    'family',jsonb_build_object('service_date',f.service_date,'delivery_location_id',f.delivery_location_id,
      'ingredient_id',f.ingredient_id,'unit_id',f.unit_id,'expected_source_fingerprint',p->>'source_fingerprint'),
    'splits',jsonb_build_array(jsonb_build_object('supplier_id',pg_temp.ng_id(62),
      'allocated_quantity',r.family_quantity::text,'supplier_note','New Supplier needs complete coverage'))))
  ||jsonb_build_object('expected_version',f.version,'reason_note',null)
from atlas_procurement.school_catering_allocation_families f
join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
cross join lateral(select atlas_core.school_catering_family_projection(
  f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id) p) source
where f.service_date='2050-09-19' and f.ingredient_id=pg_temp.ng_id(2002) and r.is_current;
set local role authenticated;
insert into k2_results select name,atlas_api.save_school_catering_supplier_allocation(request)
from k2_requests where name='b1_reassign_other_family';
reset role;
select is((select response->>'success' from k2_results where name='b1_reassign_other_family'),
  'true','omitted-Supplier scenario uses an explicit Save in a different family');
select is(atlas_core.school_catering_po_draft_is_stale(
  (request#>>'{payload,purchase_order_id}')::uuid,(request#>>'{payload,expected_purchase_order_revision_id}')::uuid),
  false,'target Supplier Draft itself remains current despite the other-family change')
from k2_requests where name='b1_po002:'||pg_temp.ng_id(61);
set local role authenticated;
insert into k2_results select 'b1_omitted_supplier_release',atlas_api.release_school_catering_purchase_order(request)
from k2_requests where name='b1_po002:'||pg_temp.ng_id(61);
reset role;
select is((select response->>'error_code' from k2_results where name='b1_omitted_supplier_release'),
  'PREPARATION_BLOCKED','final Release rejects the missing Supplier/date document despite current target totals');
rollback to savepoint b1_omitted_supplier;

-- Inherited immutable guard rejects contribution UPDATE before touching data;
-- its existing 42703 diagnostic is outside this task's historical-guard scope.
select throws_ok($attempt$
  update atlas_procurement.school_catering_allocation_family_contributions contribution
  set confirmed_need_line_revision_id=(select r.confirmed_need_line_revision_id
    from atlas_planning.confirmed_need_line_revisions r
    join atlas_planning.confirmed_need_lines line using(confirmed_need_line_id)
    where line.school_id=pg_temp.ng_id(5002) and line.ingredient_id=pg_temp.ng_id(2001) and r.is_current)
  where contribution.family_revision_id=(select r.family_revision_id
    from atlas_procurement.school_catering_allocation_family_revisions r
    join atlas_procurement.school_catering_allocation_families f using(family_id)
    where f.service_date='2050-09-19' and f.ingredient_id=pg_temp.ng_id(2001) and r.is_current)
    and contribution.confirmed_need_line_revision_id<>(select r.confirmed_need_line_revision_id
      from atlas_planning.confirmed_need_line_revisions r
      join atlas_planning.confirmed_need_lines line using(confirmed_need_line_id)
      where line.school_id=pg_temp.ng_id(5002) and line.ingredient_id=pg_temp.ng_id(2001) and r.is_current)
$attempt$,'42703',null,'equal total50 cannot hide changed immutable School membership');

savepoint b1_wrong_shared_scope;
delete from atlas_core.actor_scopes where actor_id=pg_temp.ng_id(1);
insert into atlas_core.actor_scopes(actor_id,scope_kind,school_id)
values(pg_temp.ng_id(1),'SCHOOL',pg_temp.ng_id(5001));
set local role authenticated;
insert into k2_results select 'b1_wrong_shared_scope',atlas_api.release_school_catering_purchase_order(request)
from k2_requests where name='b1_po002:'||pg_temp.ng_id(60);
reset role;
select is((select response->>'error_code' from k2_results where name='b1_wrong_shared_scope'),
  'SCOPE_DENIED','one School at a shared location cannot issue the whole shared-School PO');
rollback to savepoint b1_wrong_shared_scope;
set local role authenticated;
insert into k2_results select name,atlas_api.release_school_catering_purchase_order(request)
from k2_requests where name like 'b1_po002:%';
reset role;
select is((select count(*) from k2_results where name like 'b1_po002:%'
  and response->>'success'='true'),2::bigint,'both complete shared-School replacement POs are explicitly released');
select is((select sum(l.ordered_quantity) from atlas_procurement.purchase_orders po
  join atlas_procurement.purchase_order_revisions r using(purchase_order_id)
  join atlas_procurement.purchase_order_line_revisions l using(purchase_order_revision_id)
  where po.school_catering_service_date='2050-09-19' and po.purchase_order_status='RELEASED_TO_SUPPLIER'
    and r.is_current and l.ingredient_id=pg_temp.ng_id(2001)),50::numeric,
  'complete current supplier/date coverage totals corrected School A30 plus unchanged School B20');
select ok(not exists(select 1 from k2_b1_unchanged old
  join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_id)
  join atlas_planning.confirmed_need_line_decisions d
    on d.confirmed_need_line_decision_id=(old.decision->>'confirmed_need_line_decision_id')::uuid
  where r.is_current and (to_jsonb(r)<>old.revision or to_jsonb(d)<>old.decision)),
  'unaffected B1 School/Ingredient revisions and decisions remain byte-identical');
select ok((select count(*)=3 and sum(c.controlled_contribution_quantity)=28
  and sum(c.controlled_contribution_quantity) filter(where t.contribution_family='RECIPE_DERIVED')=20
  and sum(c.controlled_contribution_quantity) filter(where t.pantry_need_line_id is not null)=8
  from atlas_planning.confirmed_need_line_revision_contributions c
  join atlas_planning.theoretical_need_lines t using(theoretical_need_line_id)
  join atlas_planning.confirmed_need_line_revisions r using(confirmed_need_line_revision_id)
  where t.school_id=pg_temp.ng_id(5001) and t.ingredient_id=pg_temp.ng_id(2001) and r.is_current),
  'issued correction retains exact R20/B5/H3 theoretical evidence beneath human30');
select is(pg_temp.k2_issued_snapshot(po_id),facts,
  name||' original issued content remains identical') from k2_issued_history where name like 'b1_po001:%';
select * from finish();
rollback;
