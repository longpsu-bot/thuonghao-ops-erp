begin;
create extension if not exists pgtap with schema extensions;
set search_path=extensions,public,pg_catalog;
select plan(29);
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

select is((select count(*)from unnest(array[
 'atlas_core.confirmed_need_historical_validation_complete(uuid,uuid)',
 'atlas_core.confirmed_need_retained_release_evidence(uuid)'])signature
 where has_function_privilege('atlas_procurement_command_runtime',signature,'EXECUTE')),0::bigint,
 'procurement gains no access to lifecycle-only proof predicates');
select is((select count(*)from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='atlas_api'),121::bigint,'private proof slice adds no public API');
select * from finish();
rollback;
