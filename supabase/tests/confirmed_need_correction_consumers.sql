begin;
create extension if not exists pgtap with schema extensions;
set search_path=extensions,public,pg_catalog;
select plan(47);
\ir ../local/confirmed_need_correction_fixture.sql
set local statement_timeout='8s';
create function pg_temp.c_consumer_call(api text,request jsonb)returns jsonb language plpgsql as $$
declare answer jsonb;begin
 if api not in('get_confirmed_need_correction_preview','correct_confirmed_need',
  'get_confirmed_supplier_allocation_workbench','save_confirmed_supplier_allocation','save_confirmed_needs',
  'prepare_school_catering_purchase_orders','create_school_catering_purchase_order_replacement',
  'release_school_catering_purchase_order','get_school_dispatch_release_workbench','release_confirmed_needs','release_school_catering_purchase_handoff',
  'release_school_dispatch_document','get_school_catering_purchase_orders')then raise exception 'Unexpected consumer API';end if;
 set local role authenticated;
 perform set_config('request.jwt.claim.sub','c0150000-0000-4000-8000-000000000101',true);
 execute format('select atlas_api.%I($1)',api)into answer using request;
 reset role;return answer;
exception when others then reset role;raise;end;$$;
create temporary table c_consumer_selected as
select b.confirmed_need_batch_id,b.version batch_version,run.need_generation_run_id,run.version run_version,
 l.confirmed_need_line_id,l.current_confirmed_need_line_decision_id decision_id,
 r.confirmed_need_line_revision_id revision_id,r.confirmed_quantity
from atlas_planning.confirmed_need_batches b
join atlas_planning.need_generation_runs run on run.need_generation_run_id=b.current_need_generation_run_id
join atlas_planning.confirmed_need_lines l using(confirmed_need_batch_id)
join atlas_planning.confirmed_need_line_revisions r on r.confirmed_need_line_id=l.confirmed_need_line_id and r.is_current
where r.service_date='2026-11-02'and r.school_id='b6500000-0000-0000-0000-000000000004'
 and r.ingredient_id='b6500000-0000-0000-0000-000000000006';
create temporary table c_consumer_pxks as
select release.school_dispatch_release_id,to_jsonb(release)root,
 (select jsonb_agg(to_jsonb(line)order by line.school_dispatch_release_line_id)
 from atlas_dispatch.school_dispatch_release_lines line where line.school_dispatch_release_id=release.school_dispatch_release_id)lines,
 (select jsonb_agg(to_jsonb(source)order by source.school_dispatch_release_line_source_id)
 from atlas_dispatch.school_dispatch_release_line_sources source join atlas_dispatch.school_dispatch_release_lines line using(school_dispatch_release_line_id)
 where line.school_dispatch_release_id=release.school_dispatch_release_id)sources
from atlas_dispatch.school_dispatch_releases release;
create temporary table c_consumer_documents as
select po.purchase_order_id,po.document_number,to_jsonb(po)root,
 (select jsonb_agg(to_jsonb(r)-array['is_current','revision_status']order by r.purchase_order_revision_id)
 from atlas_procurement.purchase_order_revisions r where r.purchase_order_id=po.purchase_order_id)revisions,
 (select jsonb_agg(to_jsonb(l)order by l.purchase_order_line_revision_id)
 from atlas_procurement.purchase_order_line_revisions l join atlas_procurement.purchase_order_revisions r using(purchase_order_revision_id)
 where r.purchase_order_id=po.purchase_order_id)lines
from atlas_procurement.purchase_orders po;
create temporary table c_consumer_before as
select f.family_id,to_jsonb(f)family,to_jsonb(r)revision,
 (select jsonb_agg(to_jsonb(c)order by c.family_contribution_id)
  from atlas_procurement.school_catering_allocation_family_contributions c where c.family_revision_id=r.family_revision_id)contributions,
 (select jsonb_agg(to_jsonb(s)order by s.supplier_split_id)
  from atlas_procurement.school_catering_allocation_supplier_splits s where s.family_revision_id=r.family_revision_id)splits
from atlas_procurement.school_catering_allocation_families f
join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
where r.is_current and(f.service_date<>'2026-11-02'or f.ingredient_id<>'b6500000-0000-0000-0000-000000000006');
insert into c_context select 'consumer-preview-request',pg_temp.c_read('CONFIRMED-NEED-CORRECTION.v1',jsonb_build_object(
 'need_generation_run_id',need_generation_run_id,'expected_need_generation_run_version',run_version,
 'confirmed_need_batch_id',confirmed_need_batch_id,'expected_confirmed_need_batch_version',batch_version,
 'confirmed_need_line_id',confirmed_need_line_id,'expected_current_revision_id',revision_id,
 'expected_current_decision_id',decision_id,'proposed_confirmed_quantity',(confirmed_quantity+1)::text,
 'reason_code','OPERATIONAL_QUANTITY_ADJUSTMENT','reason_note','Explicit C increase'))from c_consumer_selected;
insert into c_results select 'consumer-preview',pg_temp.c_consumer_call('get_confirmed_need_correction_preview',value),'authenticated'
 from c_context where name='consumer-preview-request';
select is((select response->>'success'from c_results where name='consumer-preview'),'true','consumer journey begins with real released-Need C preview');
insert into c_results select 'consumer-correct',pg_temp.c_consumer_call('correct_confirmed_need',
 pg_temp.c_command('CONFIRMED-NEED-CORRECTION.v1','CONFIRMED_NEED_CORRECTION_SAVED',selected.batch_version,
 request.value->'payload'||jsonb_build_object('proposal_fingerprint',preview.response->'proposal_fingerprint'),
 'Explicit downstream correction')),'authenticated'
 from c_consumer_selected selected cross join c_context request cross join c_results preview
 where request.name='consumer-preview-request'and preview.name='consumer-preview';
select is((select response->>'success'from c_results where name='consumer-correct'),'true','one authorized Actor atomically corrects selected I through new public command');
select ok(not exists(select from atlas_procurement.purchase_orders po
 join atlas_procurement.purchase_order_revisions r using(purchase_order_id)
 where po.school_catering_service_date='2026-11-02'and r.is_current
 and atlas_core.school_catering_po_commitment_state(po.purchase_order_id,r.purchase_order_revision_id)='CANCELLATION_REQUIRED'),
 'pending supporting Handoff absence is not a proved zero-supplier cancellation');
insert into c_results select 'consumer-pending-po-read',pg_temp.c_consumer_call('get_school_catering_purchase_orders',
 pg_temp.c_read('SCHOOL-CATERING-PROCUREMENT.v1',jsonb_build_object('date_start','2026-11-02','date_end','2026-11-02',
 'supplier_ids','[]'::jsonb,'statuses','[]'::jsonb,'search',null))),'authenticated';
select ok((select bool_and(coalesce(item#>>'{allowed_actions,create_replacement}','false')='false')
 from c_results r cross join lateral jsonb_array_elements(r.response->'purchase_orders')item where r.name='consumer-pending-po-read'),
 'pending Need cannot enable replacement from the actual official PO read');
insert into c_results select 'consumer-pending-replacement',pg_temp.c_consumer_call('create_school_catering_purchase_order_replacement',
 pg_temp.c_command('SCHOOL-CATERING-PROCUREMENT.v1','SCHOOL_CATERING_PO_REPLACEMENT_CREATED',po.version,
 jsonb_build_object('replaced_purchase_order_id',po.purchase_order_id,'expected_purchase_order_revision_id',rev.purchase_order_revision_id))),
 'authenticated'from atlas_procurement.purchase_orders po join atlas_procurement.purchase_order_revisions rev using(purchase_order_id)
 where po.school_catering_service_date='2026-11-02'and po.supplier_id='c7100000-0000-4000-8000-000000000002'and rev.is_current;
select is((select response->>'error_code'from c_results where name='consumer-pending-replacement'),'PO_REPLACEMENT_BLOCKED',
 'direct replacement blocks pending source instead of claiming cancellation');
select is(atlas_core.school_catering_po_date_readiness('2026-11-02')->>'ready','false',
 'official date readiness stays false during saved but unreleased Need correction');
insert into c_results select 'consumer-allocation-read',pg_temp.c_consumer_call('get_confirmed_supplier_allocation_workbench',
 pg_temp.c_read('CONFIRMED-SUPPLIER-ALLOCATION.v1',jsonb_build_object('date_start','2026-11-02','date_end','2026-11-02'))),'authenticated';
select is((select item->>'state'from c_results r cross join lateral jsonb_array_elements(r.response->'rows')item
 where r.name='consumer-allocation-read'and item->>'ingredient_id'<>'b6500000-0000-0000-0000-000000000006'),'BALANCED',
 'unchanged J remains balanced prospectively without a redundant allocation Save');
insert into c_results select 'consumer-allocation-save',pg_temp.c_consumer_call('save_confirmed_supplier_allocation',
 pg_temp.c_command('CONFIRMED-SUPPLIER-ALLOCATION.v1','CONFIRMED_SUPPLIER_ALLOCATION_SAVED',
 (item#>>'{family,version}')::bigint,jsonb_build_object('family',jsonb_build_object(
 'service_date',item->'service_date','delivery_location_id',item->'delivery_location_id','ingredient_id',item->'ingredient_id','unit_id',item->'unit_id',
 'expected_source_fingerprint',item#>'{family,source_fingerprint}','expected_source_batch_id',item->'source_confirmed_need_batch_id',
 'expected_source_batch_version',item->'source_confirmed_need_batch_version'),
 'splits',jsonb_build_array(jsonb_build_object('supplier_id','c7100000-0000-4000-8000-000000000001',
 'allocated_quantity',item->'family_quantity','supplier_note','Retained explicit Supplier I note'))))),'authenticated'
 from c_results r cross join lateral jsonb_array_elements(r.response->'rows')item
 where r.name='consumer-allocation-read'and item->>'ingredient_id'='b6500000-0000-0000-0000-000000000006';
select is((select response->>'success'from c_results where name='consumer-allocation-save'),'true','only changed I gets an explicit current allocation Save');
select ok(atlas_core.purchase_review_allocation_ready(confirmed_need_batch_id),'strict release readiness accepts unchanged whole J plus explicitly saved I')from c_consumer_selected;
select ok(atlas_core.purchase_review_preparation_allocation_ready(confirmed_need_batch_id),'Preparation readiness shares the same prospective complete-family proof')from c_consumer_selected;
set local statement_timeout='20s';
insert into c_results select 'consumer-preparation',pg_temp.c_consumer_call('prepare_school_catering_purchase_orders',
 pg_temp.c_command('PURCHASE-COMMITMENT.v1','PURCHASE_ORDERS_PREPARED',b.version,
 jsonb_build_object('service_date','2026-11-02','confirmed_need_batch_id',b.confirmed_need_batch_id))),'authenticated'
 from c_consumer_selected selected join atlas_planning.confirmed_need_batches b using(confirmed_need_batch_id);
set local statement_timeout='8s';
select diag(response::text)from c_results where name='consumer-preparation'and response->>'success'is distinct from 'true';
select is((select response->>'success'from c_results where name='consumer-preparation'),'true','explicit Preparation releases corrected Need and successor Handoff without redundant J Save');
select is((select jsonb_agg(jsonb_build_object('family',to_jsonb(f),'revision',to_jsonb(r),
 'contributions',(select jsonb_agg(to_jsonb(c)order by c.family_contribution_id)from atlas_procurement.school_catering_allocation_family_contributions c where c.family_revision_id=r.family_revision_id),
 'splits',(select jsonb_agg(to_jsonb(s)order by s.supplier_split_id)from atlas_procurement.school_catering_allocation_supplier_splits s where s.family_revision_id=r.family_revision_id))order by f.family_id)
 from c_consumer_before old join atlas_procurement.school_catering_allocation_families f using(family_id)
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)where r.is_current),
 (select jsonb_agg(to_jsonb(old)-'family_id'order by family_id)from c_consumer_before old),
 'unaffected J and other-day families retain exact root/revision/contribution/split rows');
select is((select count(*)from atlas_procurement.purchase_orders po join atlas_procurement.purchase_order_revisions r using(purchase_order_id)
 where po.school_catering_service_date='2026-11-02'and po.supplier_id='c7100000-0000-4000-8000-000000000002'and r.is_current
 and atlas_core.school_catering_po_commitment_state(po.purchase_order_id,r.purchase_order_revision_id)='CURRENT'),1::bigint,
 'unaffected Supplier J official PO is current after explicit successor Handoff');
insert into c_results select 'consumer-replacement',pg_temp.c_consumer_call('create_school_catering_purchase_order_replacement',
 pg_temp.c_command('SCHOOL-CATERING-PROCUREMENT.v1','SCHOOL_CATERING_PO_REPLACEMENT_CREATED',po.version,
 jsonb_build_object('replaced_purchase_order_id',po.purchase_order_id,'expected_purchase_order_revision_id',rev.purchase_order_revision_id))),
 'authenticated'from atlas_procurement.purchase_orders po join atlas_procurement.purchase_order_revisions rev using(purchase_order_id)
 where po.school_catering_service_date='2026-11-02'and po.supplier_id='c7100000-0000-4000-8000-000000000001'
 and po.purchase_order_status='RELEASED_TO_SUPPLIER'and rev.is_current;
select is((select response->>'success'from c_results where name='consumer-replacement'),'true',
 'valid positive affected Supplier I explicitly creates a complete replacement');
insert into c_results select 'consumer-replacement-release',pg_temp.c_consumer_call('release_school_catering_purchase_order',
 pg_temp.c_command('SCHOOL-CATERING-PROCUREMENT.v1','SCHOOL_CATERING_PO_RELEASED',po.version,
 jsonb_build_object('purchase_order_id',po.purchase_order_id,'expected_purchase_order_revision_id',rev.purchase_order_revision_id))),
 'authenticated'from atlas_procurement.purchase_orders po join atlas_procurement.purchase_order_revisions rev using(purchase_order_id)
 where po.replaces_purchase_order_id is not null and rev.is_current;
select is((select response->>'success'from c_results where name='consumer-replacement-release'),'true',
 'the same Actor explicitly releases the reviewed positive PO replacement');
select is((select count(*)from atlas_procurement.purchase_orders po join c_consumer_documents old using(purchase_order_id)
 where po.purchase_order_status='SUPERSEDED'and po.document_number is not distinct from old.document_number),1::bigint,
 'explicit replacement supersedes one old root while preserving its official number');
select ok(not exists(select from c_consumer_documents old where old.revisions is distinct from
 (select jsonb_agg(to_jsonb(r)-array['is_current','revision_status']order by r.purchase_order_revision_id)
 from atlas_procurement.purchase_order_revisions r where r.purchase_order_id=old.purchase_order_id)
 or old.lines is distinct from(select jsonb_agg(to_jsonb(l)order by l.purchase_order_line_revision_id)
 from atlas_procurement.purchase_order_line_revisions l join atlas_procurement.purchase_order_revisions r using(purchase_order_revision_id)
 where r.purchase_order_id=old.purchase_order_id)),'all old frozen PO revisions and line evidence survive unchanged');
select ok(not exists(select from c_consumer_documents old join atlas_procurement.purchase_orders po using(purchase_order_id)
 where not(po.school_catering_service_date='2026-11-02'and po.supplier_id='c7100000-0000-4000-8000-000000000001')
 and to_jsonb(po)is distinct from old.root),'unaffected Supplier and other-day PO roots retain exact IDs/numbers/versions');
insert into c_results select 'consumer-pxk-after-po',pg_temp.c_consumer_call('get_school_dispatch_release_workbench',
 pg_temp.c_read('SCHOOL-DISPATCH-RELEASE.v1',jsonb_build_object('date_start','2026-11-02','date_end','2026-11-03',
 'school_ids','[]'::jsonb,'search',null))),'authenticated';
select is((select count(*)from c_results response cross join lateral jsonb_array_elements(response.response->'rows')item
 cross join lateral jsonb_array_elements(item#>'{preview,lines}')line
 where response.name='consumer-pxk-after-po'and item->>'service_date'='2026-11-02'
 and line->>'ingredient_id'='b6500000-0000-0000-0000-000000000007'),2::bigint,
 'PXK preview retains J for both Schools through renewed supporting Handoff identity');
select is((select count(*)from c_results response cross join lateral jsonb_array_elements(response.response->'rows')item
 where response.name='consumer-pxk-after-po'and item->>'service_date'='2026-11-02'
 and item#>>'{allowed_actions,replace}'='true'),2::bigint,'both affected Schools can explicitly review a PXK successor after current POs');
do $pxk_successors$
declare item jsonb;ordinal integer:=0;answer jsonb;
begin
 for item in select value from c_results response cross join lateral jsonb_array_elements(response.response->'rows')
 where response.name='consumer-pxk-after-po'and value->>'service_date'='2026-11-02'loop
 ordinal:=ordinal+1;answer:=pg_temp.c_consumer_call('release_school_dispatch_document',
 pg_temp.c_command('SCHOOL-DISPATCH-RELEASE.v1','SCHOOL_DISPATCH_DOCUMENT_RELEASED',(item->>'expected_version')::bigint,
 jsonb_build_object('service_date',item->'service_date','school_id',item->'school_id','delivery_location_id',item->'delivery_location_id',
 'expected_source_fingerprint',item#>'{preview,source_fingerprint}','predecessor_release_id',item#>'{current_release,school_dispatch_release_id}')));
 insert into c_results values('consumer-pxk-successor-'||ordinal,answer,'authenticated');
 end loop;
end;$pxk_successors$;
select is((select count(*)from c_results where name like 'consumer-pxk-successor-%'and response->>'success'='true'),2::bigint,
 'same Actor explicitly releases both School PXK successors without handoff to another staff member');
select is((select count(*)from atlas_dispatch.school_dispatch_releases),5::bigint,
 'two explicit successors append beside three original releases');
select is((select count(*)from atlas_dispatch.school_dispatch_releases where service_date='2026-11-03'),1::bigint,
 'other-day School PXK receives no successor');
select ok(not exists(select from c_consumer_pxks old join atlas_dispatch.school_dispatch_releases release using(school_dispatch_release_id)
 where (to_jsonb(release)-array['release_status','version'])is distinct from(old.root-array['release_status','version'])
 or old.lines is distinct from(select jsonb_agg(to_jsonb(line)order by line.school_dispatch_release_line_id)
 from atlas_dispatch.school_dispatch_release_lines line where line.school_dispatch_release_id=old.school_dispatch_release_id)
 or old.sources is distinct from(select jsonb_agg(to_jsonb(source)order by source.school_dispatch_release_line_source_id)
 from atlas_dispatch.school_dispatch_release_line_sources source join atlas_dispatch.school_dispatch_release_lines line using(school_dispatch_release_line_id)
 where line.school_dispatch_release_id=old.school_dispatch_release_id)),
 'all old PXK numbers/fingerprints/frozen contents/line provenance remain exact through explicit supersession');
select ok(not exists(select from c_consumer_pxks old join atlas_dispatch.school_dispatch_releases release using(school_dispatch_release_id)
 where release.service_date='2026-11-03'and to_jsonb(release)is distinct from old.root),
 'truly unaffected other-day PXK retains exact ID/number/version/fingerprint/contents');
insert into c_results select 'consumer-official-po-after',pg_temp.c_consumer_call('get_school_catering_purchase_orders',
 pg_temp.c_read('SCHOOL-CATERING-PROCUREMENT.v1',jsonb_build_object('date_start','2026-11-02','date_end','2026-11-03',
 'supplier_ids','[]'::jsonb,'statuses','[]'::jsonb,'search',null))),'authenticated';
select is((select count(*)from c_results before_read cross join lateral jsonb_array_elements(before_read.response->'purchase_orders')old
 where before_read.name='official-po-read'and exists(select from c_results after_read
 cross join lateral jsonb_array_elements(after_read.response->'purchase_orders')current
 where after_read.name='consumer-official-po-after'and current->'purchase_order_id'=old->'purchase_order_id'
 and current->'lines'=old->'lines'and current->'supplier'=old->'supplier'and current->'document_number'=old->'document_number'
 and current->>'export_ready'='true')),4::bigint,'authenticated official PO read retains all four historical frozen export inputs');
insert into c_results select 'consumer-official-pxk-after',pg_temp.c_consumer_call('get_school_dispatch_release_workbench',
 pg_temp.c_read('SCHOOL-DISPATCH-RELEASE.v1',jsonb_build_object('date_start','2026-11-02','date_end','2026-11-03','school_ids','[]'::jsonb,'search',null))),'authenticated';
select is((select count(*)from c_results before_read cross join lateral jsonb_array_elements(before_read.response->'rows')old
 where before_read.name='official-pxk-read'and exists(select from c_results after_read
 cross join lateral jsonb_array_elements(after_read.response->'rows')current cross join lateral jsonb_array_elements(current->'history')history
 where after_read.name='consumer-official-pxk-after'and history->'school_dispatch_release_id'=old#>'{current_release,school_dispatch_release_id}'
 and(history-array['status','version'])=((old->'current_release')-array['status','version']))),3::bigint,
 'authenticated official PXK history retains all original frozen export inputs');

-- Additional genuine public journeys start from the preceding released successor,
-- so retained J crosses multiple adjacent immutable Handoff edges.
create function pg_temp.c_variant(label text,delta numeric,equal_total boolean)returns jsonb language plpgsql as $$
declare target record;payload jsonb;request jsonb;answer jsonb;before_pxk jsonb;item jsonb;
 old_i uuid;j_before jsonb;j_after jsonb;replacement_ids uuid[]:='{}';replacement record;
 source_row jsonb;steps jsonb:='{}';old_school_line record;
begin
 select b.confirmed_need_batch_id,b.version batch_version,run.need_generation_run_id,run.version run_version,
 l.confirmed_need_line_id,l.current_confirmed_need_line_decision_id decision_id,r.confirmed_need_line_revision_id revision_id,
 r.confirmed_quantity into strict target from atlas_planning.confirmed_need_batches b
 join atlas_planning.need_generation_runs run on run.need_generation_run_id=b.current_need_generation_run_id
 join atlas_planning.confirmed_need_lines l using(confirmed_need_batch_id)
 join atlas_planning.confirmed_need_line_revisions r on r.confirmed_need_line_id=l.confirmed_need_line_id and r.is_current
 where r.service_date='2026-11-02'and r.school_id='b6500000-0000-0000-0000-000000000004'
 and r.ingredient_id='b6500000-0000-0000-0000-000000000006';
 select jsonb_agg(jsonb_build_object('id',school_dispatch_release_id,'school_id',school_id,'fingerprint',source_fingerprint)
 order by school_id)into before_pxk from atlas_dispatch.school_dispatch_releases
 where service_date='2026-11-02'and release_status='RELEASED';
 select revision.family_revision_id into strict old_i from atlas_procurement.school_catering_allocation_families family
 join atlas_procurement.school_catering_allocation_family_revisions revision using(family_id)
 where revision.is_current and family.service_date='2026-11-02'and family.ingredient_id='b6500000-0000-0000-0000-000000000006';
 select jsonb_build_object('family',to_jsonb(f),'revision',to_jsonb(r),'splits',
 (select jsonb_agg(to_jsonb(sp)order by sp.supplier_split_id)from atlas_procurement.school_catering_allocation_supplier_splits sp where sp.family_revision_id=r.family_revision_id),
 'contributions',(select jsonb_agg(to_jsonb(c)order by c.family_contribution_id)from atlas_procurement.school_catering_allocation_family_contributions c where c.family_revision_id=r.family_revision_id))
 into j_before from atlas_procurement.school_catering_allocation_families f join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 where r.is_current and f.service_date='2026-11-02'and f.ingredient_id='b6500000-0000-0000-0000-000000000007';
 payload:=jsonb_build_object('need_generation_run_id',target.need_generation_run_id,'expected_need_generation_run_version',target.run_version,
 'confirmed_need_batch_id',target.confirmed_need_batch_id,'expected_confirmed_need_batch_version',target.batch_version,
 'confirmed_need_line_id',target.confirmed_need_line_id,'expected_current_revision_id',target.revision_id,'expected_current_decision_id',target.decision_id,
 'proposed_confirmed_quantity',(target.confirmed_quantity+delta)::text,'reason_code','OPERATIONAL_QUANTITY_ADJUSTMENT','reason_note',label);
 answer:=pg_temp.c_consumer_call('get_confirmed_need_correction_preview',pg_temp.c_read('CONFIRMED-NEED-CORRECTION.v1',payload));
 steps:=steps||jsonb_build_object('preview',answer);if answer->>'success'is distinct from 'true'then raise exception 'preview rejected';end if;
 answer:=pg_temp.c_consumer_call('correct_confirmed_need',pg_temp.c_command('CONFIRMED-NEED-CORRECTION.v1',
 'CONFIRMED_NEED_CORRECTION_SAVED',target.batch_version,payload||jsonb_build_object('proposal_fingerprint',answer->'proposal_fingerprint'),label));
 steps:=steps||jsonb_build_object('correction',answer);if answer->>'success'is distinct from 'true'then raise exception 'correction rejected';end if;
 if equal_total then
 select l.confirmed_need_line_id,l.current_confirmed_need_line_decision_id decision_id,r.confirmed_need_line_revision_id revision_id,
 r.confirmed_quantity,b.version into strict old_school_line from atlas_planning.confirmed_need_lines l
 join atlas_planning.confirmed_need_line_revisions r on r.confirmed_need_line_id=l.confirmed_need_line_id and r.is_current
 join atlas_planning.confirmed_need_batches b on b.confirmed_need_batch_id=l.confirmed_need_batch_id
 where b.confirmed_need_batch_id=target.confirmed_need_batch_id and r.school_id='c0150000-0000-4000-8000-000000000012'
 and r.ingredient_id='b6500000-0000-0000-0000-000000000006';
 answer:=pg_temp.c_consumer_call('save_confirmed_needs',pg_temp.c_command('RMVP-05.v2','CONFIRMED_NEED_SAVED',old_school_line.version,
 jsonb_build_object('confirmed_need_batch_id',target.confirmed_need_batch_id,'lines',jsonb_build_array(jsonb_build_object(
 'confirmed_need_line_id',old_school_line.confirmed_need_line_id,'expected_current_revision_id',old_school_line.revision_id,
 'expected_current_decision_id',old_school_line.decision_id,'proposed_confirmed_quantity',(old_school_line.confirmed_quantity-delta)::text,
 'reason_code','OPERATIONAL_QUANTITY_ADJUSTMENT','reason_note','Explicit B decrease preserves total while changing exact lineage')))));
 steps:=steps||jsonb_build_object('second_school_save',answer);if answer->>'success'is distinct from 'true'then raise exception 'second School Save rejected';end if;
 end if;
 steps:=steps||jsonb_build_object('old_I_applicable_after_correction',atlas_core.purchase_review_family_continuity(old_i,'PROSPECTIVE')->'applicable');
 answer:=pg_temp.c_consumer_call('get_confirmed_supplier_allocation_workbench',pg_temp.c_read('CONFIRMED-SUPPLIER-ALLOCATION.v1',
 jsonb_build_object('date_start','2026-11-02','date_end','2026-11-02')));
 select value into strict source_row from jsonb_array_elements(answer->'rows')where value->>'ingredient_id'='b6500000-0000-0000-0000-000000000006';
 answer:=pg_temp.c_consumer_call('save_confirmed_supplier_allocation',pg_temp.c_command('CONFIRMED-SUPPLIER-ALLOCATION.v1','CONFIRMED_SUPPLIER_ALLOCATION_SAVED',
 (source_row#>>'{family,version}')::bigint,jsonb_build_object('family',jsonb_build_object('service_date',source_row->'service_date',
 'delivery_location_id',source_row->'delivery_location_id','ingredient_id',source_row->'ingredient_id','unit_id',source_row->'unit_id',
 'expected_source_fingerprint',source_row#>'{family,source_fingerprint}','expected_source_batch_id',source_row->'source_confirmed_need_batch_id',
 'expected_source_batch_version',source_row->'source_confirmed_need_batch_version'),'splits',jsonb_build_array(
 jsonb_build_object('supplier_id','c7100000-0000-4000-8000-000000000001','allocated_quantity',((source_row->>'family_quantity')::numeric-1)::text,'supplier_note','I retained A note'),
 jsonb_build_object('supplier_id','c7100000-0000-4000-8000-000000000002','allocated_quantity','1','supplier_note','I B explicit note')))));
 steps:=steps||jsonb_build_object('allocation',answer);if answer->>'success'is distinct from 'true'then raise exception 'allocation rejected';end if;
 select b.version into target.batch_version from atlas_planning.confirmed_need_batches b where b.confirmed_need_batch_id=target.confirmed_need_batch_id;
 answer:=pg_temp.c_consumer_call('prepare_school_catering_purchase_orders',pg_temp.c_command('PURCHASE-COMMITMENT.v1','PURCHASE_ORDERS_PREPARED',
 target.batch_version,jsonb_build_object('confirmed_need_batch_id',target.confirmed_need_batch_id,'service_date','2026-11-02')));
 steps:=steps||jsonb_build_object('preparation',answer);if answer->>'success'is distinct from 'true'then raise exception 'Preparation rejected';end if;
 for replacement in select po.*,rev.purchase_order_revision_id from atlas_procurement.purchase_orders po
 join atlas_procurement.purchase_order_revisions rev using(purchase_order_id)
 where po.school_catering_service_date='2026-11-02'and po.purchase_order_status='RELEASED_TO_SUPPLIER'and rev.is_current
 and atlas_core.school_catering_po_commitment_state(po.purchase_order_id,rev.purchase_order_revision_id)='REPLACEMENT_REQUIRED'order by po.supplier_id loop
 answer:=pg_temp.c_consumer_call('create_school_catering_purchase_order_replacement',pg_temp.c_command('SCHOOL-CATERING-PROCUREMENT.v1',
 'SCHOOL_CATERING_PO_REPLACEMENT_CREATED',replacement.version,jsonb_build_object('replaced_purchase_order_id',replacement.purchase_order_id,
 'expected_purchase_order_revision_id',replacement.purchase_order_revision_id)));
 steps:=steps||jsonb_build_object('replacement:'||replacement.supplier_id,answer);if answer->>'success'is distinct from 'true'then raise exception 'replacement rejected';end if;
 end loop;
 for replacement in select po.*,rev.purchase_order_revision_id from atlas_procurement.purchase_orders po
 join atlas_procurement.purchase_order_revisions rev using(purchase_order_id)
 where po.school_catering_service_date='2026-11-02'and po.purchase_order_status='DRAFT'and rev.is_current order by po.supplier_id loop
 replacement_ids:=array_append(replacement_ids,replacement.purchase_order_id);
 answer:=pg_temp.c_consumer_call('release_school_catering_purchase_order',pg_temp.c_command('SCHOOL-CATERING-PROCUREMENT.v1','SCHOOL_CATERING_PO_RELEASED',
 replacement.version,jsonb_build_object('purchase_order_id',replacement.purchase_order_id,'expected_purchase_order_revision_id',replacement.purchase_order_revision_id)));
 steps:=steps||jsonb_build_object('release:'||replacement.supplier_id,answer);if answer->>'success'is distinct from 'true'then raise exception 'PO release rejected';end if;
 end loop;
 steps:=steps||jsonb_build_object('replacement_count',cardinality(replacement_ids),'supplier_B_line_count',(
 select count(*)from atlas_procurement.purchase_orders po join atlas_procurement.purchase_order_revisions rev using(purchase_order_id)
 join atlas_procurement.purchase_order_line_revisions line using(purchase_order_revision_id)
 where po.purchase_order_id=any(replacement_ids)and po.supplier_id='c7100000-0000-4000-8000-000000000002'and rev.is_current),
 'supplier_quantities',(select jsonb_object_agg(split.supplier_id,split.allocated_quantity::text)
 from atlas_procurement.school_catering_allocation_families f join atlas_procurement.school_catering_allocation_family_revisions rev using(family_id)
 join atlas_procurement.school_catering_allocation_supplier_splits split using(family_revision_id)
 where rev.is_current and f.service_date='2026-11-02'and f.ingredient_id='b6500000-0000-0000-0000-000000000006'));
 select jsonb_build_object('family',to_jsonb(f),'revision',to_jsonb(r),'splits',
 (select jsonb_agg(to_jsonb(sp)order by sp.supplier_split_id)from atlas_procurement.school_catering_allocation_supplier_splits sp where sp.family_revision_id=r.family_revision_id),
 'contributions',(select jsonb_agg(to_jsonb(c)order by c.family_contribution_id)from atlas_procurement.school_catering_allocation_family_contributions c where c.family_revision_id=r.family_revision_id))
 into j_after from atlas_procurement.school_catering_allocation_families f join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 where r.is_current and f.service_date='2026-11-02'and f.ingredient_id='b6500000-0000-0000-0000-000000000007';
 answer:=pg_temp.c_consumer_call('get_school_dispatch_release_workbench',pg_temp.c_read('SCHOOL-DISPATCH-RELEASE.v1',
 jsonb_build_object('date_start','2026-11-02','date_end','2026-11-02','school_ids','[]'::jsonb,'search',null)));
 steps:=steps||jsonb_build_object('changed_School_PXK_count',(select count(*)from jsonb_array_elements(answer->'rows')c_variant_row
 join jsonb_array_elements(before_pxk)c_variant_old on c_variant_old->>'school_id'=c_variant_row->>'school_id'
 where c_variant_old->>'fingerprint'is distinct from c_variant_row#>>'{preview,source_fingerprint}'));
 for item in select value from jsonb_array_elements(answer->'rows')loop
 answer:=pg_temp.c_consumer_call('release_school_dispatch_document',pg_temp.c_command('SCHOOL-DISPATCH-RELEASE.v1','SCHOOL_DISPATCH_DOCUMENT_RELEASED',
 (item->>'expected_version')::bigint,jsonb_build_object('service_date',item->'service_date','school_id',item->'school_id',
 'delivery_location_id',item->'delivery_location_id','expected_source_fingerprint',item#>'{preview,source_fingerprint}',
 'predecessor_release_id',item#>'{current_release,school_dispatch_release_id}')));
 if answer->>'success'is distinct from 'true'then raise exception 'PXK successor rejected: %',answer;end if;
 end loop;
 return steps||jsonb_build_object('success',true,'retained_J_exact',j_before=j_after);
exception when others then return steps||jsonb_build_object('success',false,'stage_failure',sqlerrm,'sqlstate',sqlstate);
end;$$;
insert into c_context values('decrease-and-shared-Supplier',pg_temp.c_variant('Explicit I decrease and two-Supplier review',-1,false));
select diag(jsonb_build_object('stage_failure',value->'stage_failure','sqlstate',value->'sqlstate')::text)from c_context where name='decrease-and-shared-Supplier'and value->>'success'is distinct from 'true';
select is((select value->>'success'from c_context where name='decrease-and-shared-Supplier'),'true','public decrease completes both Supplier replacements and explicit School successors');
select is((select value->>'replacement_count'from c_context where name='decrease-and-shared-Supplier'),'2','reviewed multi-Supplier split replaces exactly both affected supplier/date commitments');
select is((select value->>'supplier_B_line_count'from c_context where name='decrease-and-shared-Supplier'),'2','same Supplier/date replacement includes changed I and retained J in full');
select is((select value->>'retained_J_exact'from c_context where name='decrease-and-shared-Supplier'),'true','retained J family/contribution/split identity survives complete same-Supplier PO replacement');
select is((select value->>'changed_School_PXK_count'from c_context where name='decrease-and-shared-Supplier'),'2','changed PO provenance requires both School successors including unchanged School quantity');
select is((select value#>>'{correction,idempotency_status}'from c_context where name='decrease-and-shared-Supplier'),'COMPLETED','decrease has a completed durable existing-authority correction receipt');
insert into c_context values('equal-total-changed-lineage',pg_temp.c_variant('Explicit A increase and B decrease retain total',1,true));
select diag(jsonb_build_object('stage_failure',value->'stage_failure','sqlstate',value->'sqlstate')::text)from c_context where name='equal-total-changed-lineage'and value->>'success'is distinct from 'true';
select is((select value->>'success'from c_context where name='equal-total-changed-lineage'),'true','public equal-total lineage change completes reviewed replacements and successors');
select is((select value->>'old_I_applicable_after_correction'from c_context where name='equal-total-changed-lineage'),'false','equal family total cannot prove unchanged immutable School revision/decision lineage');
select is((select value->'supplier_quantities'from c_context where name='equal-total-changed-lineage'),
 (select value->'supplier_quantities'from c_context where name='decrease-and-shared-Supplier'),'unchanged exact Supplier totals do not bypass replacement provenance');
select is((select value->>'replacement_count'from c_context where name='equal-total-changed-lineage'),'2','equal Supplier totals still require both explicit PO replacements');
select is((select value->>'changed_School_PXK_count'from c_context where name='equal-total-changed-lineage'),'2','both School PXK fingerprints change with the real R/D and PO provenance');
select is((select value->>'retained_J_exact'from c_context where name='equal-total-changed-lineage'),'true','unaffected J identity survives another adjacent Handoff successor');

create function pg_temp.c_obligation(zero_family boolean)returns jsonb language plpgsql as $$
declare target record;other_school record;payload jsonb;answer jsonb;row_data jsonb;version bigint;report jsonb;original_po record;
 original_documents jsonb;after_documents jsonb;handoff_before jsonb;handoff_after jsonb;handoff_answer jsonb;
begin
 begin
 select b.confirmed_need_batch_id,b.version batch_version,run.need_generation_run_id,run.version run_version,
 l.confirmed_need_line_id,l.current_confirmed_need_line_decision_id decision_id,r.confirmed_need_line_revision_id revision_id,
 r.confirmed_quantity into strict target from atlas_planning.confirmed_need_batches b
 join atlas_planning.need_generation_runs run on run.need_generation_run_id=b.current_need_generation_run_id
 join atlas_planning.confirmed_need_lines l using(confirmed_need_batch_id)
 join atlas_planning.confirmed_need_line_revisions r on r.confirmed_need_line_id=l.confirmed_need_line_id and r.is_current
 where r.service_date='2026-11-02'and r.school_id='b6500000-0000-0000-0000-000000000004'
 and r.ingredient_id='b6500000-0000-0000-0000-000000000006';
 payload:=jsonb_build_object('need_generation_run_id',target.need_generation_run_id,'expected_need_generation_run_version',target.run_version,
 'confirmed_need_batch_id',target.confirmed_need_batch_id,'expected_confirmed_need_batch_version',target.batch_version,
 'confirmed_need_line_id',target.confirmed_need_line_id,'expected_current_revision_id',target.revision_id,'expected_current_decision_id',target.decision_id,
 'proposed_confirmed_quantity',case when zero_family then '0'else(target.confirmed_quantity-1)::text end,
 'reason_code','OPERATIONAL_QUANTITY_ADJUSTMENT','reason_note','Explicit zero or Supplier transfer boundary');
 answer:=pg_temp.c_consumer_call('get_confirmed_need_correction_preview',pg_temp.c_read('CONFIRMED-NEED-CORRECTION.v1',payload));
 if answer->>'success'is distinct from 'true'then raise exception 'obligation preview rejected: %',answer->>'error_code';end if;
 answer:=pg_temp.c_consumer_call('correct_confirmed_need',pg_temp.c_command('CONFIRMED-NEED-CORRECTION.v1','CONFIRMED_NEED_CORRECTION_SAVED',
 target.batch_version,payload||jsonb_build_object('proposal_fingerprint',answer->'proposal_fingerprint'),'Explicit obligation correction'));
 if answer->>'success'is distinct from 'true'then raise exception 'obligation correction rejected: %',answer->>'error_code';end if;
 if zero_family then
 select l.confirmed_need_line_id,l.current_confirmed_need_line_decision_id decision_id,r.confirmed_need_line_revision_id revision_id,
 b.version into strict other_school from atlas_planning.confirmed_need_lines l
 join atlas_planning.confirmed_need_line_revisions r on r.confirmed_need_line_id=l.confirmed_need_line_id and r.is_current
 join atlas_planning.confirmed_need_batches b on b.confirmed_need_batch_id=l.confirmed_need_batch_id
 where b.confirmed_need_batch_id=target.confirmed_need_batch_id and r.school_id='c0150000-0000-4000-8000-000000000012'
 and r.ingredient_id='b6500000-0000-0000-0000-000000000006';
 answer:=pg_temp.c_consumer_call('save_confirmed_needs',pg_temp.c_command('RMVP-05.v2','CONFIRMED_NEED_SAVED',other_school.version,
 jsonb_build_object('confirmed_need_batch_id',target.confirmed_need_batch_id,'lines',jsonb_build_array(jsonb_build_object(
 'confirmed_need_line_id',other_school.confirmed_need_line_id,'expected_current_revision_id',other_school.revision_id,
 'expected_current_decision_id',other_school.decision_id,'proposed_confirmed_quantity','0',
 'reason_code','OPERATIONAL_QUANTITY_ADJUSTMENT','reason_note','Every School contribution explicitly zero')))));
 if answer->>'success'is distinct from 'true'then raise exception 'zero second School rejected: %',answer->>'error_code';end if;
 else
 answer:=pg_temp.c_consumer_call('get_confirmed_supplier_allocation_workbench',pg_temp.c_read('CONFIRMED-SUPPLIER-ALLOCATION.v1',
 jsonb_build_object('date_start','2026-11-02','date_end','2026-11-02')));
 select value into strict row_data from jsonb_array_elements(answer->'rows')where value->>'ingredient_id'='b6500000-0000-0000-0000-000000000006';
 answer:=pg_temp.c_consumer_call('save_confirmed_supplier_allocation',pg_temp.c_command('CONFIRMED-SUPPLIER-ALLOCATION.v1','CONFIRMED_SUPPLIER_ALLOCATION_SAVED',
 (row_data#>>'{family,version}')::bigint,jsonb_build_object('family',jsonb_build_object('service_date',row_data->'service_date',
 'delivery_location_id',row_data->'delivery_location_id','ingredient_id',row_data->'ingredient_id','unit_id',row_data->'unit_id',
 'expected_source_fingerprint',row_data#>'{family,source_fingerprint}','expected_source_batch_id',row_data->'source_confirmed_need_batch_id',
 'expected_source_batch_version',row_data->'source_confirmed_need_batch_version'),'splits',jsonb_build_array(
 jsonb_build_object('supplier_id','c7100000-0000-4000-8000-000000000002','allocated_quantity',row_data->'family_quantity','supplier_note','Explicit full transfer')))));
 if answer->>'success'is distinct from 'true'then raise exception 'transfer allocation rejected: %',answer->>'error_code';end if;
 end if;
 select b.version into version from atlas_planning.confirmed_need_batches b where b.confirmed_need_batch_id=target.confirmed_need_batch_id;
 answer:=pg_temp.c_consumer_call('release_confirmed_needs',pg_temp.c_command('RMVP-07.v2','CONFIRMED_NEED_RELEASED',version,
 jsonb_build_object('confirmed_need_batch_id',target.confirmed_need_batch_id)));
 if answer->>'success'is distinct from 'true'then raise exception 'obligation Need release rejected: %',answer->>'error_code';end if;
 select b.version into version from atlas_planning.confirmed_need_batches b where b.confirmed_need_batch_id=target.confirmed_need_batch_id;
 select jsonb_build_object('batches',(select jsonb_agg(to_jsonb(h)order by h.purchase_handoff_batch_id)from atlas_planning.purchase_handoff_batches h),
 'revisions',(select jsonb_agg(to_jsonb(h)order by h.purchase_handoff_revision_id)from atlas_planning.purchase_handoff_revisions h))into handoff_before;
 answer:=pg_temp.c_consumer_call('release_school_catering_purchase_handoff',pg_temp.c_command('SCHOOL-CATERING-HANDOFF.v1','SCHOOL_CATERING_PURCHASE_HANDOFF_RELEASED',version,
 jsonb_build_object('confirmed_need_batch_id',target.confirmed_need_batch_id)));
 handoff_answer:=answer;
 select jsonb_build_object('batches',(select jsonb_agg(to_jsonb(h)order by h.purchase_handoff_batch_id)from atlas_planning.purchase_handoff_batches h),
 'revisions',(select jsonb_agg(to_jsonb(h)order by h.purchase_handoff_revision_id)from atlas_planning.purchase_handoff_revisions h))into handoff_after;
 if not zero_family and answer->>'success'is distinct from 'true'then raise exception 'obligation Handoff release rejected: %',answer;end if;
 select po.*,rev.purchase_order_revision_id into strict original_po from atlas_procurement.purchase_orders po
 join atlas_procurement.purchase_order_revisions rev using(purchase_order_id)
 where po.school_catering_service_date='2026-11-02'and po.purchase_order_status='RELEASED_TO_SUPPLIER'and rev.is_current
 and po.supplier_id='c7100000-0000-4000-8000-000000000001';
 report:=jsonb_build_object('success',true,'handoff_error',handoff_answer->>'error_code','handoff_exact',handoff_before=handoff_after,
 'commitment_state',atlas_core.school_catering_po_commitment_state(original_po.purchase_order_id,original_po.purchase_order_revision_id));
 select jsonb_agg(to_jsonb(po)order by purchase_order_id)into original_documents from atlas_procurement.purchase_orders po;
 answer:=pg_temp.c_consumer_call('create_school_catering_purchase_order_replacement',pg_temp.c_command('SCHOOL-CATERING-PROCUREMENT.v1','SCHOOL_CATERING_PO_REPLACEMENT_CREATED',
 original_po.version,jsonb_build_object('replaced_purchase_order_id',original_po.purchase_order_id,'expected_purchase_order_revision_id',original_po.purchase_order_revision_id)));
 select jsonb_agg(to_jsonb(po)order by purchase_order_id)into after_documents from atlas_procurement.purchase_orders po;
 report:=report||jsonb_build_object('replacement_error',answer->>'error_code','replacement_success',answer->'success','documents_exact',original_documents=after_documents);
 raise exception using errcode='TST01',message='rollback genuine obligation variant';
 exception when sqlstate 'TST01'then return report;end;
exception when others then return jsonb_build_object('success',false,'stage_failure',sqlerrm,'sqlstate',sqlstate);
end;$$;
insert into c_context values('real-transfer',pg_temp.c_obligation(false));
select diag(value::text)from c_context where name='real-transfer'and value->>'success'is distinct from 'true';
select is((select value->>'commitment_state'from c_context where name='real-transfer'),'CANCELLATION_REQUIRED',
 'genuine full Supplier transfer proves no remaining old Supplier obligation');
select is((select value->>'replacement_error'from c_context where name='real-transfer'),'CANCELLATION_REQUIRED',
 'direct replacement preserves approved cancellation frontier after real transfer');
select is((select value->>'documents_exact'from c_context where name='real-transfer'),'true','denied transfer replacement creates or changes no PO');
insert into c_context values('real-zero',pg_temp.c_obligation(true));
select diag(value::text)from c_context where name='real-zero'and value->>'success'is distinct from 'true';
select is((select value->>'commitment_state'from c_context where name='real-zero'),'CANCELLATION_REQUIRED',
 'genuine complete all-School zero after explicit Need release reaches zero cancellation without empty Handoff');
select is((select value->>'replacement_error'from c_context where name='real-zero'),'CANCELLATION_REQUIRED',
 'direct replacement cannot turn true zero into an empty replacement or automatic cancellation');
select is((select value->>'documents_exact'from c_context where name='real-zero'),'true','denied true-zero replacement preserves every old PO root exactly');
select is((select value->>'handoff_error'from c_context where name='real-zero'),'INVARIANT_VIOLATION',
 'zero Need retains the existing positive-completeness Handoff guard');
select is((select value->>'handoff_exact'from c_context where name='real-zero'),'true',
 'rejected zero Handoff preserves all Handoff batches and revision identities');
select * from finish();
rollback;
