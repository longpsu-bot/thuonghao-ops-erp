begin;
create extension if not exists pgtap with schema extensions;
set search_path=extensions,public,pg_catalog;
select plan(70);
\ir ../local/confirmed_need_correction_fixture.sql

-- These helpers only invoke existing public commands under the fixture JWT.
create function pg_temp.c_lifecycle_call(api text,request jsonb) returns jsonb
language plpgsql as $$
declare answer jsonb;
begin
 if api not in('prepare_planning_source_correction','save_confirmed_needs',
  'release_confirmed_needs','validate_confirmed_needs')then raise exception 'Unexpected lifecycle API';end if;
 set local role authenticated;
 perform set_config('request.jwt.claim.sub','c0150000-0000-4000-8000-000000000101',true);
 execute format('select atlas_api.%I($1)',api)into answer using request;
 reset role;return answer;
exception when others then reset role;raise;
end;$$;
create temporary table c_original as
select l.confirmed_need_line_id,l.current_confirmed_need_line_decision_id decision_id,
 r.confirmed_need_line_revision_id revision_id,r.confirmed_quantity,
 b.confirmed_need_batch_id,b.current_confirmed_need_approval_snapshot_id snapshot_id,
 s.confirmed_need_validation_attempt_id attempt_id
from atlas_planning.confirmed_need_batches b
join atlas_planning.confirmed_need_lines l using(confirmed_need_batch_id)
join atlas_planning.confirmed_need_line_revisions r
 on r.confirmed_need_line_id=l.confirmed_need_line_id and r.is_current
join atlas_planning.confirmed_need_approval_snapshots s
 on s.confirmed_need_approval_snapshot_id=b.current_confirmed_need_approval_snapshot_id
where b.period_start='2026-11-02' and b.period_end=b.period_start;
create temporary table c_selected as select * from c_original order by confirmed_need_line_id limit 1;
create temporary table c_retained_families as
select f.*,r.family_revision_id from atlas_procurement.school_catering_allocation_families f
join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
where r.is_current and f.service_date='2026-11-02';
create function pg_temp.c_family_proof(revision uuid,mode text)returns jsonb
language plpgsql as $$declare answer jsonb;begin
 if to_regprocedure('atlas_core.purchase_review_family_continuity(uuid,text)')is null then return '{}'::jsonb;end if;
 execute 'select atlas_core.purchase_review_family_continuity($1,$2)'into answer using revision,mode;
 return answer;
end;$$;
select is((select count(*)from c_retained_families),2::bigint,
 'continuity fixture has exactly two real retained Handoff allocation families');
select is((select count(*)from c_retained_families f
 where pg_temp.c_family_proof(f.family_revision_id,'OFFICIAL')->>'applicable'='true'),2::bigint,
 'both authentic current Handoff families initially have official applicability');
select is(pg_temp.c_family_proof(null,'OFFICIAL')->>'classification','SOURCE_UNAVAILABLE',
 'missing family identity is unavailable rather than zero');
select is(pg_temp.c_family_proof((select family_revision_id from c_retained_families limit 1),'UNKNOWN')
 ->>'classification','SOURCE_UNAVAILABLE','unknown continuity mode fails closed');
create function pg_temp.c_resolved_proof(revision uuid,context jsonb)returns jsonb
language plpgsql as $$declare answer jsonb;begin
 if to_regprocedure('atlas_core.purchase_review_family_continuity(uuid,text,jsonb)')is null then return '{}'::jsonb;end if;
 execute 'select atlas_core.purchase_review_family_continuity($1,''OFFICIAL'',$2)'into answer using revision,context;
 return answer;
end;$$;
do $edge_contexts$
declare context jsonb;original jsonb;middle jsonb;last_edge jsonb;other jsonb;result jsonb;
 family_revision uuid:=(select family_revision_id from c_retained_families order by family_id limit 1);
begin
 if to_regprocedure('atlas_core.purchase_review_continuity_context(uuid)')is null then
  insert into c_context select name,'{}'from unnest(array['ambiguous-source','missing-member',
   'changed-decision','changed-school','predecessor-gap','predecessor-cycle','changed-then-reverted'])name;
  return;
 end if;
 execute 'select atlas_core.purchase_review_continuity_context($1)'into context
  using(select confirmed_need_batch_id from c_selected);
 insert into c_context values('original-continuity-context',context);
 insert into c_context values('ambiguous-source',pg_temp.c_resolved_proof(family_revision,
  jsonb_set(context,'{sources}',(context->'sources')||(context->'sources'))));
 select h into original from jsonb_array_elements(context->'handoffs')h
 where h->>'is_current'='true' order by h->>'purchase_handoff_revision_id'limit 1;
 -- Negative resolved-context tests start with genuine public history; they do
 -- not fabricate accepted facts or claim a successful public successor journey.
 select jsonb_agg(m)into result from jsonb_array_elements(original#>'{membership,members}')m
 where m->>'ingredient_id'<>(select f.ingredient_id::text from c_retained_families f
  where f.family_revision_id=family_revision);
 insert into c_context values('missing-member',pg_temp.c_resolved_proof(family_revision,
  jsonb_set(context,'{handoffs}',jsonb_build_array(jsonb_set(original,'{membership,members}',result)))));
 select jsonb_agg(jsonb_set(m,'{current_confirmed_need_line_decision_id}',to_jsonb(gen_random_uuid())))into result
 from jsonb_array_elements(original#>'{membership,members}')m;
 insert into c_context values('changed-decision',pg_temp.c_resolved_proof(family_revision,
  jsonb_set(context,'{handoffs}',jsonb_build_array(jsonb_set(original,'{membership,members}',result)))));
 select jsonb_agg(jsonb_set(m,'{school_id}',to_jsonb(gen_random_uuid())))into result
 from jsonb_array_elements(original#>'{membership,members}')m;
 insert into c_context values('changed-school',pg_temp.c_resolved_proof(family_revision,
  jsonb_set(context,'{handoffs}',jsonb_build_array(jsonb_set(original,'{membership,members}',result)))));
 middle:=original||jsonb_build_object('purchase_handoff_revision_id',gen_random_uuid(),
  'predecessor_revision_id',original->'purchase_handoff_revision_id','revision_number',
  (original->>'revision_number')::integer+2);
 insert into c_context values('predecessor-gap',pg_temp.c_resolved_proof(family_revision,
  jsonb_set(context,'{handoffs}',jsonb_build_array(original,middle))));
 middle:=middle||jsonb_build_object('predecessor_revision_id',middle->'purchase_handoff_revision_id');
 insert into c_context values('predecessor-cycle',pg_temp.c_resolved_proof(family_revision,
  jsonb_set(context,'{handoffs}',jsonb_build_array(original,middle))));
 middle:=jsonb_set(original||jsonb_build_object('purchase_handoff_revision_id',gen_random_uuid(),
  'predecessor_revision_id',original->'purchase_handoff_revision_id','revision_number',
  (original->>'revision_number')::integer+1),'{membership,members}',result);
 last_edge:=original||jsonb_build_object('purchase_handoff_revision_id',gen_random_uuid(),
  'predecessor_revision_id',middle->'purchase_handoff_revision_id','revision_number',
  (original->>'revision_number')::integer+2);
 insert into c_context values('changed-then-reverted',pg_temp.c_resolved_proof(family_revision,
  jsonb_set(context,'{handoffs}',jsonb_build_array(original,middle,last_edge))));
end;$edge_contexts$;
select is((select value->>'applicable'from c_context where name='ambiguous-source'),'false',
 'duplicate authoritative source families cannot be treated as one whole family');
select is((select value->>'applicable'from c_context where name='missing-member'),'false',
 'missing historical member cannot prove a clipped School family');
select is((select value->>'applicable'from c_context where name='changed-decision'),'false',
 'same quantities with another historical decision fail exact fact proof');
select is((select value->>'applicable'from c_context where name='changed-school'),'false',
 'same quantities with another captured School fail exact fact proof');
select is((select value->>'applicable'from c_context where name='predecessor-gap'),'false',
 'a predecessor revision-number gap cannot be skipped');
select is((select value->>'applicable'from c_context where name='predecessor-cycle'),'false',
 'a predecessor cycle fails closed');
select is((select value->>'applicable'from c_context where name='changed-then-reverted'),'false',
 'equal endpoints never hide a changed intermediate immutable edge');
select ok(to_regprocedure('atlas_core.confirmed_need_historical_validation_evidence(uuid,uuid)')is not null,
 'narrow frozen-attempt bridge exists');
select ok(to_regprocedure('atlas_core.confirmed_need_retained_release_evidence(uuid)')is not null,
 'retained-release eligibility is shared/set-based');
-- Missing helpers give a normal assertion RED, without hiding prerequisite errors.
do $$begin
 if to_regprocedure('atlas_core.confirmed_need_historical_validation_evidence(uuid,uuid)')is not null then
  execute 'insert into c_context select ''historical-evidence'',atlas_core.confirmed_need_historical_validation_evidence(confirmed_need_batch_id,attempt_id)from c_selected';
 end if;
end;$$;
select is((select value->>'complete'from c_context where name='historical-evidence'),'true',
 'real prior public validation is complete immutable evidence');
select is((select jsonb_array_length(value#>'{projection,ordered_lines}')from c_context where name='historical-evidence'),4,
 'historical bridge preserves every School contribution line');
insert into c_results
select 'correction-prepare',pg_temp.c_lifecycle_call('prepare_planning_source_correction',
 pg_temp.c_command('PLANNING-CORRECTION.v1','PLANNING_SOURCE_CORRECTION_PREPARED',r.version,
 jsonb_build_object('need_generation_run_id',r.need_generation_run_id,
 'confirmed_need_batch_id',b.confirmed_need_batch_id,
 'expected_confirmed_need_batch_version',b.version),'C bounded lifecycle correction')),'authenticated'
from c_selected target join atlas_planning.confirmed_need_batches b using(confirmed_need_batch_id)
join atlas_planning.need_generation_runs r on r.need_generation_run_id=b.current_need_generation_run_id;
select is((select response->>'success'from c_results where name='correction-prepare'),'true',
 'existing authenticated prepare reopens the exact released batch');
insert into c_results
select 'correction-save',pg_temp.c_lifecycle_call('save_confirmed_needs',
 pg_temp.c_command('RMVP-05.v2','CONFIRMED_NEED_SAVED',b.version,jsonb_build_object(
 'confirmed_need_batch_id',b.confirmed_need_batch_id,'lines',jsonb_build_array(jsonb_build_object(
 'confirmed_need_line_id',target.confirmed_need_line_id,'expected_current_revision_id',target.revision_id,
 'expected_current_decision_id',target.decision_id,'proposed_confirmed_quantity',(target.confirmed_quantity+1)::text,
 'reason_code','OPERATIONAL_QUANTITY_ADJUSTMENT','reason_note','C bounded one-line correction'))))),'authenticated'
from c_selected target join atlas_planning.confirmed_need_batches b using(confirmed_need_batch_id);
select is((select response->>'success'from c_results where name='correction-save'),'true',
 'existing authenticated Save appends only the selected correction');
select is((select count(*)from c_original old join atlas_planning.confirmed_need_lines l using(confirmed_need_line_id)
 join atlas_planning.confirmed_need_line_revisions r on r.confirmed_need_line_id=l.confirmed_need_line_id and r.is_current
 where old.confirmed_need_line_id<>(select confirmed_need_line_id from c_selected)
 and row(r.confirmed_need_line_revision_id,l.current_confirmed_need_line_decision_id,r.revision_status)
 is not distinct from row(old.revision_id,old.decision_id,'RELEASED'::text)),3::bigint,
 'all three unaffected R/D identities stay RELEASED without churn');

insert into c_context
select 'prospective-'||f.ingredient_id,pg_temp.c_family_proof(f.family_revision_id,'PROSPECTIVE')
from c_retained_families f;
select is((select count(*)from c_context where name like 'prospective-%'
 and value->>'classification'='PROSPECTIVE_UNCHANGED'and value->>'applicable'='true'),1::bigint,
 'only the full unchanged shared-School family is prospectively reusable');
select is((select count(*)from c_context where name like 'prospective-%'
 and value->>'applicable'='false'),1::bigint,
 'a correction to one School denies reuse of its entire aggregate family');
select is((select count(*)from c_retained_families f
 where pg_temp.c_family_proof(f.family_revision_id,'OFFICIAL')->>'classification'='CORRECTION_PENDING'),2::bigint,
 'official applicability is pending while the released batch is reopened');
select is((select count(*)from c_context where name like 'prospective-%'
 and value->>'classification'='AUTHORITATIVE_ZERO'),0::bigint,
 'absent current Handoff during correction never becomes authoritative zero');
select is((select jsonb_array_length(value#>'{proof,contributions}')from c_context
 where name like 'prospective-%'and value->>'applicable'='true'),2,
 'unchanged proof retains both School contributions rather than a School slice');
select is((select value#>>'{proof,family_revision_id}'from c_context
 where name like 'prospective-%'and value->>'applicable'='true'),
 (select f.family_revision_id::text from c_retained_families f
 where f.ingredient_id<>(select r.ingredient_id from c_selected s
 join atlas_planning.confirmed_need_line_revisions r on r.confirmed_need_line_revision_id=s.revision_id)),
 'prospective proof binds the original exact allocation revision identity');
select ok((select value#>'{proof,supplier_splits}'=coalesce((select jsonb_agg(to_jsonb(s)order by s.supplier_split_id)
 from atlas_procurement.school_catering_allocation_supplier_splits s
 where s.family_revision_id=(value#>>'{proof,family_revision_id}')::uuid),'[]'::jsonb)
 from c_context where name like 'prospective-%'and value->>'applicable'='true'),
 'proof preserves complete exact Supplier split facts, IDs, ratios, origins and notes');

savepoint c_authoritative_zero;
insert into c_results select 'zero-family-save',pg_temp.c_lifecycle_call('save_confirmed_needs',
 pg_temp.c_command('RMVP-05.v2','CONFIRMED_NEED_SAVED',b.version,jsonb_build_object(
 'confirmed_need_batch_id',b.confirmed_need_batch_id,'lines',(select jsonb_agg(jsonb_build_object(
 'confirmed_need_line_id',l.confirmed_need_line_id,'expected_current_revision_id',r.confirmed_need_line_revision_id,
 'expected_current_decision_id',l.current_confirmed_need_line_decision_id,'proposed_confirmed_quantity','0',
 'reason_code','OPERATIONAL_QUANTITY_ADJUSTMENT','reason_note','C explicit complete zero family'))
 from atlas_planning.confirmed_need_lines l join atlas_planning.confirmed_need_line_revisions r
 on r.confirmed_need_line_id=l.confirmed_need_line_id and r.is_current
 where l.confirmed_need_batch_id=b.confirmed_need_batch_id and r.ingredient_id=(select old.ingredient_id
 from atlas_planning.confirmed_need_line_revisions old join c_selected target
 on target.revision_id=old.confirmed_need_line_revision_id))))),'authenticated'
 from atlas_planning.confirmed_need_batches b join c_selected target using(confirmed_need_batch_id);
select is((select response->>'success'from c_results where name='zero-family-save'),'true',
 'genuine public Save can explicitly correct every School contribution to zero');
select is((select count(*)from c_retained_families f where
 pg_temp.c_family_proof(f.family_revision_id,'PROSPECTIVE')->>'classification'='AUTHORITATIVE_ZERO'),1::bigint,
 'only a complete canonical explicit-zero family is classified as authoritative zero');
rollback to savepoint c_authoritative_zero;

-- Isolated lifecycle proof: explicitly review/save the two current allocation
-- families through existing authenticated commands. Unaffected allocation
-- continuity is Task4; this does not bypass strict existing release readiness.
do $allocation_readiness$
declare answer jsonb; item jsonb; ordinal integer:=0; supplier uuid;
begin
 answer:=pg_temp.c_invoke('lifecycle-allocation-read','get_confirmed_supplier_allocation_workbench',
  pg_temp.c_read('CONFIRMED-SUPPLIER-ALLOCATION.v1',
   jsonb_build_object('date_start','2026-11-02','date_end','2026-11-02')));
 for item in select value from jsonb_array_elements(answer->'rows')loop
  ordinal:=ordinal+1;
  supplier:=case when item->>'ingredient_id'='b6500000-0000-0000-0000-000000000006'
   then 'c7100000-0000-4000-8000-000000000001'::uuid
   else 'c7100000-0000-4000-8000-000000000002'::uuid end;
  perform pg_temp.c_invoke('lifecycle-allocation-save-'||ordinal,'save_confirmed_supplier_allocation',
   pg_temp.c_command('CONFIRMED-SUPPLIER-ALLOCATION.v1','CONFIRMED_SUPPLIER_ALLOCATION_SAVED',
    (item#>>'{family,version}')::bigint,jsonb_build_object('family',jsonb_build_object(
     'service_date',item->'service_date','delivery_location_id',item->'delivery_location_id',
     'ingredient_id',item->'ingredient_id','unit_id',item->'unit_id',
     'expected_source_fingerprint',item#>'{family,source_fingerprint}',
     'expected_source_batch_id',item->'source_confirmed_need_batch_id',
     'expected_source_batch_version',item->'source_confirmed_need_batch_version'),
     'splits',jsonb_build_array(jsonb_build_object('supplier_id',supplier,
      'allocated_quantity',item->'family_quantity')))));
 end loop;
 if ordinal<>2 then raise exception 'Expected two lifecycle allocation families, got %',ordinal;end if;
end;
$allocation_readiness$;

insert into c_results
select 'correction-release-v2',pg_temp.c_lifecycle_call('release_confirmed_needs',
 pg_temp.c_command('RMVP-07.v2','CONFIRMED_NEED_RELEASED',b.version,
 jsonb_build_object('confirmed_need_batch_id',b.confirmed_need_batch_id))),'authenticated'
from c_selected target join atlas_planning.confirmed_need_batches b using(confirmed_need_batch_id);
select is((select response->>'success'from c_results where name='correction-release-v2'),'true',
 'direct existing V2 releases a corrected mixed-status batch');
select is((select b.batch_status from c_selected target join atlas_planning.confirmed_need_batches b using(confirmed_need_batch_id)),
 'RELEASED_FOR_PURCHASE_HANDOFF','successful correction restores released batch lifecycle');
select is((select count(*)from c_original old join atlas_planning.confirmed_need_lines l using(confirmed_need_line_id)
 join atlas_planning.confirmed_need_line_revisions r on r.confirmed_need_line_id=l.confirmed_need_line_id and r.is_current
 where old.confirmed_need_line_id<>(select confirmed_need_line_id from c_selected)
 and row(r.confirmed_need_line_revision_id,l.current_confirmed_need_line_decision_id,r.revision_status)
 is not distinct from row(old.revision_id,old.decision_id,'RELEASED'::text)),3::bigint,
 'release retains unchanged exact R/D identities and statuses');
select is((select count(*)from atlas_planning.confirmed_need_approval_snapshots s join c_selected target using(confirmed_need_batch_id)),
 2::bigint,'correction creates a new complete approval snapshot beside retained history');
select is((select count(*)from atlas_planning.confirmed_need_snapshot_lines sl join atlas_planning.confirmed_need_batches b
 on b.current_confirmed_need_approval_snapshot_id=sl.confirmed_need_approval_snapshot_id
 join c_selected target using(confirmed_need_batch_id)),4::bigint,'new snapshot includes all four current revisions');
select is((select count(*)from atlas_planning.confirmed_need_snapshot_lines sl join c_original old
 on old.snapshot_id=sl.confirmed_need_approval_snapshot_id and old.revision_id=sl.confirmed_need_line_revision_id),
 4::bigint,'old released snapshot remains complete and immutable');
select is((select count(*)from atlas_procurement.purchase_orders where purchase_order_status='RELEASED_TO_SUPPLIER'),
 4::bigint,'Need lifecycle support issues no PO replacement/release');
select is((select count(*)from atlas_dispatch.school_dispatch_releases),3::bigint,
 'Need lifecycle support issues no PXK successor');
select is((select count(*)from atlas_procurement.school_catering_allocation_family_revisions r
 join c_retained_families f using(family_id)where r.is_current
 and pg_temp.c_family_proof(r.family_revision_id,'OFFICIAL')->>'classification'='CORRECTION_PENDING'),2::bigint,
 'released corrected Need without an explicit successor Handoff remains officially pending');

select is(atlas_core.confirmed_need_historical_validation_evidence(target.confirmed_need_batch_id,target.attempt_id),
 (select value from c_context where name='historical-evidence'),
 'supersession does not replace historical revision/decision observations')from c_selected target;
select is(atlas_core.confirmed_need_historical_validation_evidence(
 (select confirmed_need_batch_id from atlas_planning.confirmed_need_batches where period_start='2026-11-03'and period_end=period_start),
 (select attempt_id from c_selected))->>'complete','false','another batch cannot borrow a successful attempt');
select is(atlas_core.confirmed_need_historical_validation_evidence(
 (select confirmed_need_batch_id from c_selected),gen_random_uuid())->>'complete','false',
 'missing immutable observation authority fails closed');
select is(atlas_core.confirmed_need_historical_validation_evidence(
 (select confirmed_need_batch_id from c_selected),null)->>'complete','false',
 'NULL historical attempt is not a request for current mutable evidence');
select is((select count(*)from pg_proc p where p.oid in(
 'atlas_core.confirmed_need_historical_validation_complete(uuid,uuid)'::regprocedure,
 'atlas_core.confirmed_need_historical_validation_evidence(uuid,uuid)'::regprocedure,
 'atlas_core.confirmed_need_retained_release_evidence(uuid)'::regprocedure)
 and p.proowner='atlas_confirmed_need_review_runtime'::regrole and p.prosecdef
 and p.proconfig @> array['search_path=""']),3::bigint,
 'three private seams retain exact review owner/SECDEF/empty path');
select is((select count(*)from unnest(array['authenticated','anon','service_role'])role_name
 cross join unnest(array['atlas_core.confirmed_need_historical_validation_complete(uuid,uuid)',
 'atlas_core.confirmed_need_historical_validation_evidence(uuid,uuid)',
 'atlas_core.confirmed_need_retained_release_evidence(uuid)'])signature
 where has_function_privilege(role_name,signature,'EXECUTE')),0::bigint,
 'no browser or service principal may execute any private proof');
-- Task-owned rollback transaction only: postgres SET is normally disabled.
grant atlas_procurement_command_runtime to postgres with set true;
grant select on c_selected to atlas_procurement_command_runtime;
set local role atlas_procurement_command_runtime;
select is(atlas_core.confirmed_need_historical_validation_evidence(
 (select confirmed_need_batch_id from c_selected),(select attempt_id from c_selected))->>'complete','true',
 'procurement can use only the narrow review-owned historical bridge');
reset role;
grant atlas_procurement_command_runtime to postgres with set false;

-- A genuine ordinary same-quantity Save appends a new decision, not a revision.
-- It must NOT inherit the former decision's released authority merely by totals.
create temporary table c_before_second as
select l.confirmed_need_line_id,l.current_confirmed_need_line_decision_id decision_id,
 r.confirmed_need_line_revision_id revision_id,r.confirmed_quantity,b.confirmed_need_batch_id
from c_selected target join atlas_planning.confirmed_need_lines l using(confirmed_need_line_id)
join atlas_planning.confirmed_need_line_revisions r
 on r.confirmed_need_line_id=l.confirmed_need_line_id and r.is_current
join atlas_planning.confirmed_need_batches b on b.confirmed_need_batch_id=l.confirmed_need_batch_id;
insert into c_results
select 'second-prepare',pg_temp.c_lifecycle_call('prepare_planning_source_correction',
 pg_temp.c_command('PLANNING-CORRECTION.v1','PLANNING_SOURCE_CORRECTION_PREPARED',r.version,
 jsonb_build_object('need_generation_run_id',r.need_generation_run_id,
 'confirmed_need_batch_id',b.confirmed_need_batch_id,
 'expected_confirmed_need_batch_version',b.version),'C negative exact-decision proof')),'authenticated'
from c_before_second target join atlas_planning.confirmed_need_batches b using(confirmed_need_batch_id)
join atlas_planning.need_generation_runs r on r.need_generation_run_id=b.current_need_generation_run_id;
select is((select response->>'success'from c_results where name='second-prepare'),'true',
 'negative fixture reopens through existing public authority');
insert into c_results
select 'same-quantity-new-decision',pg_temp.c_lifecycle_call('save_confirmed_needs',
 pg_temp.c_command('RMVP-05.v2','CONFIRMED_NEED_SAVED',b.version,jsonb_build_object(
 'confirmed_need_batch_id',b.confirmed_need_batch_id,'lines',jsonb_build_array(jsonb_build_object(
 'confirmed_need_line_id',target.confirmed_need_line_id,'expected_current_revision_id',target.revision_id,
 'expected_current_decision_id',target.decision_id,'proposed_confirmed_quantity',target.confirmed_quantity::text,
 'reason_code','PROPOSAL_ACCEPTED','reason_note','C negative unchanged-quantity decision'))))),'authenticated'
from c_before_second target join atlas_planning.confirmed_need_batches b using(confirmed_need_batch_id);
select is((select response->>'success'from c_results where name='same-quantity-new-decision'),'true',
 'ordinary same-quantity Save behavior remains unchanged');
select ok((select r.confirmed_need_line_revision_id=target.revision_id
 and l.current_confirmed_need_line_decision_id<>target.decision_id and r.revision_status='RELEASED'
 from c_before_second target join atlas_planning.confirmed_need_lines l using(confirmed_need_line_id)
 join atlas_planning.confirmed_need_line_revisions r
 on r.confirmed_need_line_id=l.confirmed_need_line_id and r.is_current),
 'negative fixture has the SAME released revision but a NEW public decision');
insert into c_results
select 'second-validate',pg_temp.c_lifecycle_call('validate_confirmed_needs',
 pg_temp.c_command('RMVP-06.v1','BATCH_VALIDATION_REQUESTED',b.version,
 jsonb_build_object('confirmed_need_batch_id',b.confirmed_need_batch_id))),'authenticated'
from c_before_second target join atlas_planning.confirmed_need_batches b using(confirmed_need_batch_id);
select is((select response->>'success'from c_results where name='second-validate'),'true',
 'negative fixture still passes canonical current quantity validation');
select is((select atlas_core.rmvp_07_validation_evidence_complete(b.confirmed_need_batch_id,
 b.current_confirmed_need_validation_attempt_id,b.version)
 from c_before_second target join atlas_planning.confirmed_need_batches b using(confirmed_need_batch_id)),false,
 'new decision cannot borrow prior release authority from equal quantity or RELEASED status');
select is((select count(*)from atlas_procurement.school_catering_allocation_family_revisions r
 join c_retained_families f using(family_id)where r.is_current
 and pg_temp.c_family_proof(r.family_revision_id,'PROSPECTIVE')->>'applicable'='false'),1::bigint,
 'same revision and quantity with a new current decision denies that whole retained allocation');
select is((select count(*)from pg_proc p where p.oid in(
 to_regprocedure('atlas_core.purchase_review_continuity_context(uuid)'),
 to_regprocedure('atlas_core.purchase_review_family_continuity(uuid,text)'),
 to_regprocedure('atlas_core.purchase_review_family_continuity(uuid,text,jsonb)'))
 and p.proowner='atlas_procurement_command_runtime'::regrole and p.prosecdef
 and p.provolatile='s'and p.proconfig @> array['search_path=""']),3::bigint,
 'resolved applicability seams have the exact Procurement owner/STABLE/SECDEF/empty path');
select is((select count(*)from pg_proc p cross join unnest(array['anon','authenticated','service_role'])actor_role
 where p.oid in(to_regprocedure('atlas_core.purchase_review_continuity_context(uuid)'),
 to_regprocedure('atlas_core.purchase_review_family_continuity(uuid,text)'),
 to_regprocedure('atlas_core.purchase_review_family_continuity(uuid,text,jsonb)'))
 and has_function_privilege(actor_role,p.oid,'EXECUTE')),0::bigint,
 'no browser/service principal can supply private resolved evidence or invoke applicability');
select is((select count(*)from pg_proc p cross join unnest(array['atlas_read_runtime',
 'atlas_need_generation_runtime','atlas_confirmed_need_review_runtime',
 'atlas_planning_command_runtime','atlas_dispatch_command_runtime'])actor_role
 where p.oid in(to_regprocedure('atlas_core.purchase_review_continuity_context(uuid)'),
 to_regprocedure('atlas_core.purchase_review_family_continuity(uuid,text)'),
 to_regprocedure('atlas_core.purchase_review_family_continuity(uuid,text,jsonb)'))
 and has_function_privilege(actor_role,p.oid,'EXECUTE')),0::bigint,
 'this private proof checkpoint grants no speculative consumer access');

select is((select count(*)from unnest(array[
 'atlas_core.confirmed_need_historical_validation_complete(uuid,uuid)',
 'atlas_core.confirmed_need_retained_release_evidence(uuid)'])signature
 where has_function_privilege('atlas_procurement_command_runtime',signature,'EXECUTE')),0::bigint,
 'procurement gains no access to lifecycle-only proof predicates');
select is((select count(*)from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='atlas_api'),121::bigint,'private proof slice adds no public API');

select is((select count(*)from pg_proc p where p.oid=to_regprocedure(
 'atlas_core.confirmed_need_correction_lock_days(date,date)')
 and p.proowner='atlas_owner'::regrole and not p.prosecdef
 and p.provolatile='v' and p.proconfig @> array['search_path=""']),1::bigint,
 'daily absent-root fence is the exact private owner/INVOKER/volatile exception');
select is((select count(*)from pg_proc p cross join unnest(array['authenticated','anon','service_role'])actor_role
 where p.oid=to_regprocedure('atlas_core.confirmed_need_correction_lock_days(date,date)')
 and has_function_privilege(actor_role,p.oid,'EXECUTE')),0::bigint,
 'no browser/service principal can directly acquire daily fences');
select is((select count(*)from pg_proc p cross join unnest(array[
 'atlas_need_generation_runtime','atlas_planning_materialization_runtime',
 'atlas_planning_command_runtime','atlas_confirmed_need_review_runtime',
 'atlas_procurement_command_runtime','atlas_dispatch_command_runtime'])actor_role
 where p.oid=to_regprocedure('atlas_core.confirmed_need_correction_lock_days(date,date)')
 and has_function_privilege(actor_role,p.oid,'EXECUTE')),6::bigint,
 'only the exact existing writer runtimes gain the shared advisory primitive');
select throws_ok($$select atlas_core.confirmed_need_correction_lock_days(null,'2026-11-05')$$,
 '22023',null,'NULL fence bounds fail closed');
select throws_ok($$select atlas_core.confirmed_need_correction_lock_days('2026-11-05','2026-11-04')$$,
 '22023',null,'reversed fence bounds fail closed');
do $range_fence$
begin
 if to_regprocedure('atlas_core.confirmed_need_correction_lock_days(date,date)')is not null then
  grant atlas_need_generation_runtime to postgres with set true;
  set local role atlas_need_generation_runtime;
  perform atlas_core.confirmed_need_correction_lock_days('2026-11-04','2026-11-05');
  reset role;
  grant atlas_need_generation_runtime to postgres with set false;
 end if;
end;
$range_fence$;
select is((select count(*)from pg_locks where pid=pg_backend_pid()and locktype='advisory'
 and granted and objsubid=1 and ((classid::bigint<<32)|objid::bigint)in(
 hashtextextended('PLANNING-CONTRACT-01:2026-11-04:2026-11-04',0),
 hashtextextended('PLANNING-CONTRACT-01:2026-11-05:2026-11-05',0))),2::bigint,
 'an authorized range locks both individual day identities, not only its range hash');


-- The root universe is independent of continuity success/Supplier visibility.
-- At this point canonical validation succeeded but exact retained-D proof failed.
do $context_probe$begin
 if to_regprocedure('atlas_core.purchase_review_correction_context(uuid)')is not null then
  insert into c_context select 'root-context',atlas_core.purchase_review_correction_context(confirmed_need_batch_id)
  from c_selected;
 end if;
end;$context_probe$;
select is((select value->>'available'from c_context where name='root-context'),'true',
 'failed family continuity does not deny complete Need root enumeration');
select is((select jsonb_array_length(value->'batch_ids')from c_context where name='root-context'),1,
 'complete shared-School root is deduplicated without unrelated other-day batch');
select is((select jsonb_array_length(value->'family_ids')from c_context where name='root-context'),2,
 'both retained/current Ingredient families participate in root resolution');
select is((select count(distinct c->>'school_id')from c_context context
 cross join lateral jsonb_array_elements(context.value->'sources')source
 cross join lateral jsonb_array_elements(source->'contributions')c
 where context.name='root-context'),2::bigint,'root context preserves both shared-location Schools');
select is((select count(*)from pg_proc p where p.oid=to_regprocedure(
 'atlas_core.confirmed_need_correction_lock_roots(uuid)')
 and p.proowner='atlas_need_generation_runtime'::regrole and p.prosecdef
 and p.proconfig @> array['search_path=""']),1::bigint,'complete root locker retains exact Need runtime ownership');
do $root_probe$begin
 if to_regprocedure('atlas_core.confirmed_need_correction_lock_roots(uuid)')is not null then
  insert into c_context select 'locked-context',atlas_core.confirmed_need_correction_lock_roots(confirmed_need_batch_id)
  from c_selected;
 end if;
end;$root_probe$;
select ok(coalesce((select value->'batch_ids'from c_context where name='locked-context')
 = (select value->'batch_ids'from c_context where name='root-context'),false),
 'complete prelock returns a fresh root context with the exact contributing batch set');

select ok(has_function_privilege('atlas_need_generation_runtime',
 'atlas_core.purchase_review_lock_allocations(uuid)','EXECUTE'),
 'standalone Need prepare receives the exact private complete-domain lock bridge');

do $membership_probe$begin
 if to_regprocedure('atlas_core.confirmed_need_handoff_membership(uuid)')is not null then
  insert into c_context select 'historical-handoff-members',atlas_core.confirmed_need_handoff_membership(hr.purchase_handoff_revision_id)
  from atlas_planning.purchase_handoff_batches hb
  join atlas_planning.purchase_handoff_revisions hr using(purchase_handoff_batch_id)
  where hb.confirmed_need_batch_id=(select confirmed_need_batch_id from c_selected)
  order by hr.revision_number limit 1;
 end if;
end;$membership_probe$;
select is((select value->>'complete'from c_context where name='historical-handoff-members'),'true',
 'historical invalidated Handoff still reconstructs exact immutable released Need authority');
select is((select count(*)from c_context context
 cross join lateral jsonb_array_elements(context.value->'members')member
 join c_original old on old.confirmed_need_line_id=(member->>'confirmed_need_line_id')::uuid
 where context.name='historical-handoff-members'
 and row(member->>'current_confirmed_need_line_revision_id',member->>'current_confirmed_need_line_decision_id')
 is not distinct from row(old.revision_id::text,old.decision_id::text)),4::bigint,
 'every old Handoff member binds original R/D rather than current pointer or same quantity');
do $missing_membership$begin
 if to_regprocedure('atlas_core.confirmed_need_handoff_membership(uuid)')is not null then
  insert into c_context values('missing-handoff-members',atlas_core.confirmed_need_handoff_membership(null));
 end if;
end;$missing_membership$;
select is((select value->>'complete'from c_context where name='missing-handoff-members'),'false',
 'missing Handoff authority is unavailable, never an authoritative zero');

select * from finish();
rollback;
