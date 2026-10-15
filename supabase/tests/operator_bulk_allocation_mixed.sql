begin;
create extension if not exists pgtap with schema extensions;
set search_path=extensions,public,pg_catalog;
select no_plan();
\ir ../local/purchase_preparation_scale_fixture.sql
-- Existing retained PO/Handoff fixture, moved unchanged from the PO suite.
-- Its source setup ends in origin; the tested commands use ordinary guards/RLS.
\ir ../local/school_catering_purchase_orders_fixture.sql
select pg_temp.seed_purchase_preparation_scale('bulk-mixed-cn','bulk-mixed',date '2026-09-21',null,null,2,1);
create temporary table mixed_requests(name text primary key,request jsonb);
create temporary table mixed_results(name text primary key,response jsonb);
grant select,insert,update on mixed_requests,mixed_results to authenticated;
insert into mixed_requests values('save',pg_temp.scale_confirmed_need_save_command('mixed-save',md5('bulk-mixed-cn:confirmed-need-batch')::uuid));
set local role authenticated;
select set_config('request.jwt.claim.sub','b6000000-0000-0000-0000-000000000101',true);
insert into mixed_results select 'save',atlas_api.save_confirmed_needs(request) from mixed_requests where name='save';
reset role;
select is((select response->>'success' from mixed_results where name='save'),'true','mixed fixture has real current saved Confirmed Need');
insert into mixed_requests values('read',jsonb_build_object('contract_version','CONFIRMED-SUPPLIER-ALLOCATION.v1',
  'correlation_id',gen_random_uuid(),'requested_by_auth_subject','b6000000-0000-0000-0000-000000000101',
  'payload','{"date_start":"2026-09-21","date_end":"2026-09-21","include_bulk_preview":true}'::jsonb));
set local role authenticated;
insert into mixed_results select 'preview',atlas_api.get_confirmed_supplier_allocation_workbench(request) from mixed_requests where name='read';
reset role;
select is((select response#>>'{bulk_preview,applicable_count}' from mixed_results where name='preview'),'5','preview includes three retained Handoff and two current CN families');
select is((select count(*) from mixed_results,lateral jsonb_array_elements(response#>'{bulk_preview,families}') e
  where name='preview' and e#>>'{candidate,family,source_kind}'='PURCHASE_HANDOFF'),3::bigint,'Handoff candidates retain their current writer route');
select ok((select count(*)=3 and bool_and(jsonb_array_length(e->'schools')=1)
  from mixed_results,lateral jsonb_array_elements(response#>'{bulk_preview,families}') e
  where name='preview' and e#>>'{candidate,family,source_kind}'='PURCHASE_HANDOFF'),'retained Handoff contributions expose captured School UUIDs');
insert into mixed_requests select 'apply',pg_temp.scale_command('mixed-apply','SUPPLIER-ALLOCATION-BATCH.v1',
  'SUPPLIER_ALLOCATION_BATCH_APPLIED',1,jsonb_build_object('scope','{"date_start":"2026-09-21","date_end":"2026-09-21"}'::jsonb,
    'candidates',(select jsonb_agg(e->'candidate') from jsonb_array_elements(response#>'{bulk_preview,families}') e
      where e->'candidate'<>'null'::jsonb))) from mixed_results where name='preview';
create function pg_temp.reject_confirmed_after_handoff() returns trigger language plpgsql as $$
begin
  if new.source_kind='CONFIRMED_NEED' and exists(select 1 from atlas_procurement.school_catering_allocation_family_revisions
    where source_kind='PURCHASE_HANDOFF') then raise exception 'synthetic second-writer rejection'; end if;
  return new;
end;
$$;
create function pg_temp.mixed_rollback_case() returns jsonb language plpgsql as $$
declare result jsonb; answer jsonb;
begin
  create trigger reject_confirmed_after_handoff before insert on atlas_procurement.school_catering_allocation_family_revisions
    for each row execute function pg_temp.reject_confirmed_after_handoff();
  set local role authenticated;
  result:=atlas_api.apply_supplier_allocation_batch((select request from mixed_requests where name='apply'));
  reset role;
  answer:=jsonb_build_object('response',result,'revisions',(select count(*) from atlas_procurement.school_catering_allocation_family_revisions),
    'child_receipts',(select count(*) from atlas_core.command_receipts where command_name in
      ('save_school_catering_supplier_allocation','save_confirmed_supplier_allocation')),
    'child_events',(select count(*) from atlas_audit.domain_events where event_type in
      ('SchoolCateringSupplierAllocationSaved','ConfirmedSupplierAllocationSaved')));
  raise exception using errcode='PBTC1';
exception when sqlstate 'PBTC1' then return answer;
end;
$$;
insert into mixed_results values('mixed-rollback',pg_temp.mixed_rollback_case());
select ok((select response#>>'{response,success}'='false' and response#>>'{response,conflicts,0,family,source_kind}'='CONFIRMED_NEED'
  from mixed_results where name='mixed-rollback'),'failure in Confirmed writer after real Handoff children rejects the whole mixed batch');
select ok((select response->>'revisions'='0' and response->>'child_receipts'='0' and response->>'child_events'='0'
  from mixed_results where name='mixed-rollback'),'mixed rollback removes both writers facts/child receipts/success events');
set local role authenticated;
insert into mixed_results select 'apply',atlas_api.apply_supplier_allocation_batch(request) from mixed_requests where name='apply';
reset role;
select is((select response->>'success' from mixed_results where name='apply'),'true','one mixed-source batch saves all explicit choices');
select is((select count(*) from atlas_procurement.school_catering_allocation_family_revisions where source_kind='PURCHASE_HANDOFF'),3::bigint,'three Handoff revisions written through existing writer');
select is((select count(*) from atlas_procurement.school_catering_allocation_family_revisions where source_kind='CONFIRMED_NEED'),2::bigint,'two Confirmed revisions written through existing writer');
select is((select count(*) from atlas_core.command_receipts where command_name in ('save_school_catering_supplier_allocation','save_confirmed_supplier_allocation') and outcome='COMPLETED'),5::bigint,
  'each child retains its own completed receipt');
select is((select count(distinct command_id) from atlas_core.command_receipts where command_name in ('save_school_catering_supplier_allocation','save_confirmed_supplier_allocation')),5::bigint,
  'child identities are distinct instead of reusing the outer command ID');
create function pg_temp.bulk_missing_school_lineage() returns jsonb language plpgsql as $$
declare result jsonb;
begin
  -- Retained incomplete history only, not accepted new source/command facts.
  set local session_replication_role=replica;
  update atlas_planning.purchase_handoff_line_revisions set confirmed_need_line_revision_id=gen_random_uuid()
    where purchase_handoff_line_revision_id='24030000-0000-4000-8000-000000000084';
  set local session_replication_role=origin;
  set local role authenticated;
  result:=atlas_api.get_confirmed_supplier_allocation_workbench(jsonb_set(
    (select request from mixed_requests where name='read'),'{payload,date_end}','"2026-09-22"'));
  reset role;
  raise exception using errcode='PBTC1';
exception when sqlstate 'PBTC1' then return result;
end;
$$;
insert into mixed_results values('missing-school',pg_temp.bulk_missing_school_lineage());
select ok((select count(*)=1 and bool_and(e->'candidate'='null'::jsonb and e->>'exclusion_reason'='SCHOOL_LINEAGE_UNAVAILABLE'
  and jsonb_array_length(e->'contributions')=1 and e->>'family_quantity'='20.000000')
  from mixed_results,lateral jsonb_array_elements(response#>'{bulk_preview,families}') e
  where name='missing-school' and e->>'service_date'='2026-09-22'),
  'missing School history retains full Handoff contribution/quantity but is explicitly excluded from optional bulk');
-- Independently authorized allocation writes do not depend on hidden PO existence.
insert into mixed_requests select 'changed-need',jsonb_set(
  pg_temp.scale_confirmed_need_save_command('mixed-change-need',md5('bulk-mixed-cn:confirmed-need-batch')::uuid),'{payload,lines}',
  (select jsonb_agg(e||jsonb_build_object('proposed_confirmed_quantity',((e->>'proposed_confirmed_quantity')::numeric+1)::text,
    'reason_code','OPERATIONAL_QUANTITY_ADJUSTMENT','reason_note','Synthetic local rebalance'))
  from jsonb_array_elements(pg_temp.scale_confirmed_need_save_command('mixed-change-need',
    md5('bulk-mixed-cn:confirmed-need-batch')::uuid)#>'{payload,lines}') e));
set local role authenticated;
insert into mixed_results select 'changed-need',atlas_api.save_confirmed_needs(request) from mixed_requests where name='changed-need';
reset role;
select is((select response->>'success' from mixed_results where name='changed-need'),'true','unreleased CN source changes through existing Planning Save');
delete from atlas_core.actor_scopes where actor_id='b6000000-0000-0000-0000-000000000001';
insert into atlas_core.actor_scopes(actor_id,scope_kind,customer_id)
values('b6000000-0000-0000-0000-000000000001','CUSTOMER',md5('bulk-mixed-cn:customer')::uuid);
insert into atlas_core.actor_scopes(actor_id,scope_kind,school_id)
values('b6000000-0000-0000-0000-000000000001','SCHOOL','24020000-0000-4000-8000-000000000021');
set local role authenticated;
insert into mixed_results select 'before-po',atlas_api.get_confirmed_supplier_allocation_workbench(request) from mixed_requests where name='read';
reset role;
insert into mixed_requests select 'rebalance',pg_temp.scale_command('mixed-rebalance','SUPPLIER-ALLOCATION-BATCH.v1',
  'SUPPLIER_ALLOCATION_BATCH_APPLIED',1,jsonb_build_object('scope','{"date_start":"2026-09-21","date_end":"2026-09-21"}'::jsonb,
    'candidates',(select jsonb_agg(e->'candidate') from jsonb_array_elements(response#>'{bulk_preview,families}') e
      where e->'candidate'<>'null'::jsonb))) from mixed_results where name='before-po';
create function pg_temp.bulk_apply_observation(p_request jsonb) returns jsonb language plpgsql as $$
declare result jsonb; answer jsonb;
begin
  set local role authenticated;
  result:=atlas_api.apply_supplier_allocation_batch(p_request);
  reset role;
  answer:=jsonb_build_object('success',result->'success','applied_count',result->'applied_count','error_code',result->'error_code',
    'revision_count',(select count(*) from atlas_procurement.school_catering_allocation_family_revisions));
  raise exception using errcode='PBTC1';
exception when sqlstate 'PBTC1' then return answer;
end;
$$;
insert into mixed_results select 'apply-before-po',pg_temp.bulk_apply_observation(request) from mixed_requests where name='rebalance';
insert into mixed_requests values('create-po',pg_temp.scale_command('mixed-create-po','SCHOOL-CATERING-PROCUREMENT.v1',
  'SCHOOL_CATERING_PO_DRAFTS_CREATED',1,'{"date_start":"2026-09-21","date_end":"2026-09-21"}')||
  jsonb_build_object('requested_by_auth_subject','24000000-0000-4000-8000-000000000101'));
set local role authenticated;
select set_config('request.jwt.claim.sub','24000000-0000-4000-8000-000000000101',true);
insert into mixed_results select 'create-po',atlas_api.create_school_catering_purchase_order_drafts(request) from mixed_requests where name='create-po';
select set_config('request.jwt.claim.sub','b6000000-0000-0000-0000-000000000101',true);
reset role;
select is((select response->>'success' from mixed_results where name='create-po'),'true','existing public command creates genuine Supplier/date POs');
select ok(exists(select 1 from atlas_procurement.purchase_orders po where po.supplier_id='24020000-0000-4000-8000-000000000051'
  and not atlas_core.school_catering_purchase_order_actor_has_full_scope('b6000000-0000-0000-0000-000000000001',po.purchase_order_id)),
  'fixture contains a real whole PO hidden because School B scope is absent');
set local role authenticated;
insert into mixed_results select 'after-po',atlas_api.get_confirmed_supplier_allocation_workbench(request) from mixed_requests where name='read';
reset role;
select is((select e->'purchase_order_impact' from mixed_results,lateral jsonb_array_elements(response#>'{bulk_preview,families}') e
  where name='after-po' and e->>'ingredient_id'='24020000-0000-4000-8000-000000000041'),
  (select e->'purchase_order_impact' from mixed_results,lateral jsonb_array_elements(response#>'{bulk_preview,families}') e
  where name='before-po' and e->>'ingredient_id'='24020000-0000-4000-8000-000000000041'),
  'hidden PO adds no identity/count/status/hidden-only flag to the family impact');
select ok((select count(*)=1 and bool_and(e#>>'{purchase_order_impact,coverage}'='AUTHORIZED_DOCUMENTS_ONLY'
  and jsonb_array_length(e#>'{purchase_order_impact,documents}')=1)
  from mixed_results,lateral jsonb_array_elements(response#>'{bulk_preview,families}') e
  where name='after-po' and e->>'ingredient_id'='24020000-0000-4000-8000-000000000042'),
  'visible whole PO details retain the same authorized-documents-only coverage');
insert into mixed_results select 'apply-after-po',pg_temp.bulk_apply_observation(request) from mixed_requests where name='rebalance';
select is((select response from mixed_results where name='apply-after-po'),
  (select response from mixed_results where name='apply-before-po'),'Apply behavior is identical with versus without an inaccessible PO');
select ok((select response->>'success'='true' and response->>'applied_count'='2' and response->>'revision_count'='7'
  from mixed_results where name='apply-after-po'),'both observations really saved the two selected authorized rebalance families before rollback');
-- A stable PO line can outlive its membership in the current revision.
create function pg_temp.bulk_removed_current_line() returns jsonb language plpgsql as $$
declare family jsonb; saved jsonb; regenerated jsonb; preview jsonb; old_po uuid; result jsonb;
begin
  insert into atlas_core.actor_scopes(actor_id,scope_kind) values('b6000000-0000-0000-0000-000000000001','GLOBAL');
  select po.purchase_order_id into old_po from atlas_procurement.purchase_orders po
    where supplier_id='24020000-0000-4000-8000-000000000051';
  select atlas_core.school_catering_family_projection(f.service_date,f.delivery_location_id,f.ingredient_id,f.unit_id)
    ||jsonb_build_object('version',f.version) into family from atlas_procurement.school_catering_allocation_families f
    where f.service_date='2026-09-21' and f.delivery_location_id='24020000-0000-4000-8000-000000000011'
      and f.ingredient_id='24020000-0000-4000-8000-000000000041';
  set local role authenticated;
  perform set_config('request.jwt.claim.sub','24000000-0000-4000-8000-000000000101',true);
  saved:=atlas_api.save_school_catering_supplier_allocation(pg_temp.scale_command('mixed-move-supplier',
    'SCHOOL-CATERING-PROCUREMENT.v1','SCHOOL_CATERING_SUPPLIER_ALLOCATION_SAVED',(family->>'version')::bigint,
    jsonb_build_object('family',jsonb_build_object('service_date',family->'service_date',
      'delivery_location_id',family->'delivery_location_id','ingredient_id',family->'ingredient_id','unit_id',family->'unit_id',
      'expected_source_fingerprint',family->'source_fingerprint'),'splits',jsonb_build_array(jsonb_build_object(
      'supplier_id','24020000-0000-4000-8000-000000000052','allocated_quantity',family->'family_quantity'))))||
      jsonb_build_object('requested_by_auth_subject','24000000-0000-4000-8000-000000000101'));
  regenerated:=atlas_api.create_school_catering_purchase_order_drafts((select request from mixed_requests where name='create-po')||
    jsonb_build_object('command_id',gen_random_uuid(),'idempotency_key',gen_random_uuid()::text));
  perform set_config('request.jwt.claim.sub','b6000000-0000-0000-0000-000000000101',true);
  preview:=atlas_api.get_confirmed_supplier_allocation_workbench((select request from mixed_requests where name='read'));
  reset role;
  result:=jsonb_build_object('saved',saved->'success','regenerated',regenerated->'success',
    'stable_line_remains',exists(select 1 from atlas_procurement.purchase_order_lines line
      join atlas_procurement.school_catering_allocation_families f on f.family_id=line.school_catering_allocation_family_id
      where line.purchase_order_id=old_po and f.delivery_location_id='24020000-0000-4000-8000-000000000011'),
    'current_line_absent',not exists(select 1 from atlas_procurement.purchase_order_line_revisions lr
      join atlas_procurement.purchase_order_lines line using(purchase_order_line_id)
      join atlas_procurement.purchase_order_revisions rev using(purchase_order_revision_id)
      join atlas_procurement.school_catering_allocation_families f on f.family_id=line.school_catering_allocation_family_id
      where rev.is_current and rev.purchase_order_id=old_po and f.delivery_location_id='24020000-0000-4000-8000-000000000011'),
    'old_po_in_impact',exists(select 1 from jsonb_array_elements(preview#>'{bulk_preview,families}') fam,
      lateral jsonb_array_elements(fam#>'{purchase_order_impact,documents}') doc
      where fam->>'delivery_location_id'='24020000-0000-4000-8000-000000000011'
        and fam->>'ingredient_id'='24020000-0000-4000-8000-000000000041' and doc->>'purchase_order_id'=old_po::text));
  raise exception using errcode='PBTC1';
exception when sqlstate 'PBTC1' then return result;
end;
$$;
insert into mixed_results values('removed-line',pg_temp.bulk_removed_current_line());
select ok((select response->>'saved'='true' and response->>'regenerated'='true' and response->>'stable_line_remains'='true'
  and response->>'current_line_absent'='true' from mixed_results where name='removed-line'),
  'existing allocation Save and PO regeneration retain a historical stable line outside current revision');
select is((select response->>'old_po_in_impact' from mixed_results where name='removed-line'),'false',
  'bulk impact excludes a PO whose current revision no longer contains this family');

-- Historical PO impact must use its released revision, never a renamed Master Data Supplier.
create function pg_temp.bulk_frozen_supplier_impact() returns jsonb language plpgsql as $$
declare release_request jsonb; released jsonb; preview jsonb; frozen text;
begin
  select pg_temp.scale_command('mixed-release-impact','SCHOOL-CATERING-PROCUREMENT.v1',
    'SCHOOL_CATERING_PO_RELEASED',po.version,jsonb_build_object('purchase_order_id',po.purchase_order_id,
      'expected_purchase_order_revision_id',rev.purchase_order_revision_id))||
    jsonb_build_object('requested_by_auth_subject','24000000-0000-4000-8000-000000000101')
    into release_request from atlas_procurement.purchase_orders po
    join atlas_procurement.purchase_order_revisions rev using(purchase_order_id)
    where rev.is_current and po.supplier_id='24020000-0000-4000-8000-000000000053';
  set local role authenticated;
  perform set_config('request.jwt.claim.sub','24000000-0000-4000-8000-000000000101',true);
  released:=atlas_api.release_school_catering_purchase_order(release_request);
  reset role;
  select rev.supplier_name_snapshot into frozen from atlas_procurement.purchase_order_revisions rev
    where rev.purchase_order_id=(release_request#>>'{payload,purchase_order_id}')::uuid and rev.is_current;
  update atlas_admin.suppliers set supplier_name='Renamed CURRENT Supplier — must not print'
    where supplier_id='24020000-0000-4000-8000-000000000053';
  set local role authenticated;
  perform set_config('request.jwt.claim.sub','b6000000-0000-0000-0000-000000000101',true);
  preview:=atlas_api.get_confirmed_supplier_allocation_workbench((select request from mixed_requests where name='read'));
  reset role;
  preview:=jsonb_build_object('released',released->'success','frozen',frozen,'shown',(
    select doc->'supplier_name' from jsonb_array_elements(preview#>'{bulk_preview,families}') fam,
      lateral jsonb_array_elements(fam#>'{purchase_order_impact,documents}') doc
    where doc->>'purchase_order_id'=release_request#>>'{payload,purchase_order_id}' limit 1));
  raise exception using errcode='PBTC1';
exception when sqlstate 'PBTC1' then return preview;
end;
$$;
insert into mixed_results values('frozen-impact',pg_temp.bulk_frozen_supplier_impact());
select is((select response->>'released' from mixed_results where name='frozen-impact'),'true',
  'historical Supplier impact fixture uses a genuine released PO');
select ok((select nullif(response->>'frozen','') is not null and response->>'shown'=response->>'frozen'
  from mixed_results where name='frozen-impact'),'released PO impact retains frozen Supplier name after current Master Data rename');

select * from finish();
rollback;
