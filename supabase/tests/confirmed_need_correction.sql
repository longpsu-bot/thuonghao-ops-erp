begin;
create extension if not exists pgtap with schema extensions;
set search_path=extensions,public,pg_catalog;
select plan(83);
\ir ../local/confirmed_need_correction_fixture.sql
select ok(not exists(select from c_results where invoked_as<>'authenticated'),
 'C fixture calls tested public APIs as authenticated');
select is((select count(*) from atlas_planning.confirmed_need_validation_lines
 where current_confirmed_need_line_decision_id is not null),6::bigint,
 'real validation captured all six immutable non-NULL decisions');
select is((select count(*) from atlas_planning.confirmed_need_approval_snapshots),2::bigint,
 'real public approval created historical authority');
select is((select count(*) from atlas_procurement.purchase_orders
 where purchase_order_status='RELEASED_TO_SUPPLIER'),4::bigint,
 'four actual Supplier/date POs were explicitly released');
select is((select count(*) from atlas_dispatch.school_dispatch_releases
 where release_status='RELEASED'),3::bigint,'three actual School PXKs were explicitly released');
select is((select response->>'error_code' from c_results
 where name='ordinary-released-save'),'CONFIRMED_NEED_BATCH_NOT_EDITABLE',
 'ordinary released Save remains blocked');
select is((select jsonb_agg(to_jsonb(r)order by r.confirmed_need_line_revision_id)
 from atlas_planning.confirmed_need_line_revisions r),
 (select revisions from c_before_ordinary),'denied ordinary Save writes no successor');
select ok(to_regprocedure('atlas_api.get_confirmed_need_correction_preview(jsonb)')is not null,
 'C dedicated correction preview exists');
select ok(to_regprocedure('atlas_api.correct_confirmed_need(jsonb)')is not null,
 'C atomic correction command exists');
create temporary table c_requests(name text primary key,request jsonb not null);
create temporary table c_command_before as select count(*)run_count from atlas_planning.need_generation_runs;
insert into c_requests
select 'preview',pg_temp.c_read('CONFIRMED-NEED-CORRECTION.v1',jsonb_build_object(
 'need_generation_run_id',run.need_generation_run_id,'expected_need_generation_run_version',run.version,
 'confirmed_need_batch_id',b.confirmed_need_batch_id,'expected_confirmed_need_batch_version',b.version,
 'confirmed_need_line_id',l.confirmed_need_line_id,'expected_current_revision_id',r.confirmed_need_line_revision_id,
 'expected_current_decision_id',l.current_confirmed_need_line_decision_id,
 'proposed_confirmed_quantity',(r.confirmed_quantity+1)::text,
 'reason_code','OPERATIONAL_QUANTITY_ADJUSTMENT','reason_note','C explicit one-line correction'))
from atlas_planning.confirmed_need_batches b
join atlas_planning.need_generation_runs run on run.need_generation_run_id=b.current_need_generation_run_id
join atlas_planning.confirmed_need_lines l using(confirmed_need_batch_id)
join atlas_planning.confirmed_need_line_revisions r on r.confirmed_need_line_id=l.confirmed_need_line_id and r.is_current
where b.period_start='2026-11-02'order by l.confirmed_need_line_id limit 1;
create function pg_temp.c_correct_call(api text,request jsonb)returns jsonb language plpgsql as $$
declare answer jsonb;begin
 if api not in('get_confirmed_need_correction_preview','correct_confirmed_need')then raise exception 'Unexpected C API';end if;
 if to_regprocedure('atlas_api.'||api||'(jsonb)')is null then
  return jsonb_build_object('success',false,'error_code','MISSING_RPC');end if;
 set local role authenticated;
 perform set_config('request.jwt.claim.sub','c0150000-0000-4000-8000-000000000101',true);
 execute format('select atlas_api.%I($1)',api)into answer using request;
 reset role;return answer;
exception when others then reset role;raise;end;$$;
insert into c_results select 'correction-preview',pg_temp.c_correct_call('get_confirmed_need_correction_preview',request),
 'authenticated'from c_requests where name='preview';
select is((select response->>'success'from c_results where name='correction-preview'),'true',
 'dedicated preview accepts a real current released Need after PO/PXK');
select is((select response#>>'{quantity,delta}'from c_results where name='correction-preview'),'1.000000',
 'preview computes the exact authoritative delta');
select is((select jsonb_array_length(response#>'{family,contributions}')from c_results where name='correction-preview'),2,
 'preview discloses both Schools in the complete shared-location Need family');
select is((select count(distinct m->>'school_id')from c_results r
 cross join lateral jsonb_array_elements(r.response#>'{display,schools}')m
 where r.name='correction-preview'and nullif(m->>'school_name','')is not null),2::bigint,
 'backend display includes both authorized School names even outside a loaded School slice');
savepoint c_display_rename;
update atlas_admin.units set unit_name='Cái'where unit_id='b6500000-0000-0000-0000-000000000005';
insert into c_results select 'renamed-unit-preview',pg_temp.c_correct_call('get_confirmed_need_correction_preview',request),
 'authenticated'from c_requests where name='preview';
select is((select response#>>'{display,unit_name}'from c_results where name='renamed-unit-preview'),'Cái',
 'preview resolves a current human Unit label without a future snapshot dependency');
select is((select response->>'proposal_fingerprint'from c_results where name='renamed-unit-preview'),
 (select response->>'proposal_fingerprint'from c_results where name='correction-preview'),
 'display rename cannot change canonical quantity authority');
rollback to savepoint c_display_rename;
select ok((select response->>'proposal_fingerprint'~'^[0-9a-f]{64}$'from c_results where name='correction-preview'),
 'server proposal has a canonical SHA256 binding');
select is((select response->>'procurement_details_coverage'from c_results where name='correction-preview'),
 'AUTHORIZED_DETAILS_ONLY','Procurement coverage is explicitly authorized-details-only');
select is((select response->>'purchase_order_coverage'from c_results where name='correction-preview'),
 'AUTHORIZED_DOCUMENTS_ONLY','empty PO disclosure never claims no commitment');
select is((select jsonb_array_length(response->'procurement_details')from c_results where name='correction-preview'),1,
 'authorized Procurement reader sees the actual retained family decision');
select is((select jsonb_array_length(response->'purchase_orders')from c_results where name='correction-preview'),1,
 'authorized whole-PO reader sees the actual current matching document');
select is(pg_temp.c_correct_call('get_confirmed_need_correction_preview','null')->>'error_code','VALIDATION_FAILED',
 'explicit NULL request fails closed without a database exception');
select is(pg_temp.c_correct_call('get_confirmed_need_correction_preview',
 (select request||'{"unknown":true}'from c_requests where name='preview'))->>'error_code','VALIDATION_FAILED',
 'preview uses a closed envelope');
select is(pg_temp.c_correct_call('get_confirmed_need_correction_preview',
 (select jsonb_set(request,'{requested_by_auth_subject}',to_jsonb(gen_random_uuid()))from c_requests where name='preview'))
 ->>'error_code','AUTH_SUBJECT_MISMATCH','request subject cannot borrow the resolved authenticated Actor');
select is(pg_temp.c_correct_call('get_confirmed_need_correction_preview',
 (select jsonb_set(request,'{payload}',request->'payload'||'{"unknown":true}')from c_requests where name='preview'))
 ->>'error_code','VALIDATION_FAILED','preview rejects unknown payload fields');
select is(pg_temp.c_correct_call('get_confirmed_need_correction_preview',
 (select jsonb_set(request,'{payload,proposed_confirmed_quantity}','2')from c_requests where name='preview'))
 ->>'error_code','VALIDATION_FAILED','quantity must remain a typed exact numeric string');
select is(pg_temp.c_correct_call('get_confirmed_need_correction_preview',
 (select jsonb_set(request,'{payload,expected_current_decision_id}',to_jsonb(gen_random_uuid()))from c_requests where name='preview'))
 ->>'error_code','STALE_CONFIRMED_NEED_DECISION','preview rejects a different immutable decision identity');
select is(pg_temp.c_correct_call('get_confirmed_need_correction_preview',
 (select jsonb_set(request,'{payload,expected_need_generation_run_version}','999')from c_requests where name='preview'))
 ->>'error_code','STALE_VERSION','preview rejects a stale captured Need run version');
select is(pg_temp.c_correct_call('get_confirmed_need_correction_preview',
 (select jsonb_set(request,'{payload,expected_confirmed_need_batch_version}','999')from c_requests where name='preview'))
 ->>'error_code','STALE_VERSION','preview rejects a stale expected Need batch version');
select is(pg_temp.c_correct_call('get_confirmed_need_correction_preview',
 (select jsonb_set(request,'{payload,proposed_confirmed_quantity}','"0.0000001"')from c_requests where name='preview'))
 ->>'error_code','QUANTITY_NOT_REPRESENTABLE','canonical exact precision rules are reused');
select is(pg_temp.c_correct_call('get_confirmed_need_correction_preview',
 (select jsonb_set(request,'{payload,proposed_confirmed_quantity}',to_jsonb((
  select r.confirmed_quantity::text from atlas_planning.confirmed_need_line_revisions r
  where r.confirmed_need_line_revision_id=(request#>>'{payload,expected_current_revision_id}')::uuid)))
 from c_requests where name='preview'))->>'error_code','NO_APPLICABLE_CORRECTION',
 'unchanged quantity is not a new decision/reopen action');
insert into c_requests select 'command',pg_temp.c_command('CONFIRMED-NEED-CORRECTION.v1',
 'CONFIRMED_NEED_CORRECTION_SAVED',(request#>>'{payload,expected_confirmed_need_batch_version}')::bigint,
 request->'payload'||jsonb_build_object('proposal_fingerprint',response->'proposal_fingerprint'),
 'C reviewed one-line quantity correction')from c_requests cross join c_results
 where c_requests.name='preview'and c_results.name='correction-preview';
create function pg_temp.c_without_authority(cap text,p_write boolean)returns jsonb language plpgsql as $$
declare answer jsonb;begin
 begin
  if cap='GLOBAL'then update atlas_core.actor_scopes set scope_status='REVOKED'
   where actor_id='c0150000-0000-4000-8000-000000000001';
  else delete from atlas_core.role_capabilities rc using atlas_core.capabilities c
   where c.capability_id=rc.capability_id and rc.role_id='b6000000-0000-0000-0000-000000000003'
    and(c.capability_code=cap or(cap='NO_READ'and c.capability_code in(
     'confirmed_need_review.read','procurement.school_catering.read')));end if;
  answer:=pg_temp.c_correct_call(case when p_write then 'correct_confirmed_need'
   else 'get_confirmed_need_correction_preview'end,(select request from c_requests
    where name=case when p_write then 'command'else 'preview'end));
  raise exception using errcode='TST01',message='rollback synthetic authority probe';
 exception when sqlstate 'TST01'then return answer;end;
end;$$;
select is(pg_temp.c_without_authority('confirmed_need_review.read',false)->>'error_code','CAPABILITY_DENIED',
 'Need preview requires its existing read capability');
select is(pg_temp.c_without_authority('planning.need_generation.write',true)->>'error_code','CAPABILITY_DENIED',
 'correction requires existing Need generation write capability');
select is(pg_temp.c_without_authority('confirmed_need_release.release',true)->>'error_code','CAPABILITY_DENIED',
 'correction requires existing Need release capability');
select is(pg_temp.c_without_authority('confirmed_need_quantities.confirm',true)->>'error_code','CAPABILITY_DENIED',
 'correction requires existing quantity Save capability');
select is(pg_temp.c_without_authority('confirmed_need_quantities.confirm',false)#>>'{disabled_reasons,correct}',
 'CORRECTION_AUTHORITY_REQUIRED','read-only Need preview explains its disabled correction action authoritatively');
select is(pg_temp.c_without_authority('GLOBAL',true)->>'error_code','SCOPE_DENIED',
 'correction preserves the existing GLOBAL task scope requirement');
select is(pg_temp.c_without_authority('NO_READ',true)->>'success','true',
 'existing write authority can correct without Need/Procurement read capabilities');
insert into c_context values('no-proc-read-preview',pg_temp.c_without_authority('procurement.school_catering.read',false));
select is((select value->>'proposal_fingerprint'from c_context where name='no-proc-read-preview'),
 (select response->>'proposal_fingerprint'from c_results where name='correction-preview'),
 'optional Procurement visibility cannot change the canonical Need binding');
select is((select value->'allowed_actions'from c_context where name='no-proc-read-preview'),
 (select response->'allowed_actions'from c_results where name='correction-preview'),
 'missing Procurement read cannot change correction eligibility');
select is((select value->'procurement_details'from c_context where name='no-proc-read-preview'),'[]'::jsonb,
 'Need-only reader receives no Supplier splits or notes');
select is((select value->'purchase_orders'from c_context where name='no-proc-read-preview'),'[]'::jsonb,
 'Need-only reader receives no PO identities or hidden-existence flags');
insert into atlas_core.actors(actor_id,actor_type,display_name)values
 ('c0150000-0000-4000-8000-000000000201','HUMAN','Synthetic scope probe');
insert into atlas_core.actor_role_memberships(actor_id,role_id)values
 ('c0150000-0000-4000-8000-000000000201','b6000000-0000-0000-0000-000000000003');
insert into atlas_core.actor_scopes(actor_id,scope_kind,school_id)values
 ('c0150000-0000-4000-8000-000000000201','SCHOOL','c0150000-0000-4000-8000-000000000012');
insert into c_context select 'partial-school-details',atlas_core.confirmed_need_correction_procurement_details(
 'c0150000-0000-4000-8000-000000000201',r.service_date,r.delivery_location_id,r.ingredient_id,r.unit_id)
 from c_requests request join atlas_planning.confirmed_need_line_revisions r
 on r.confirmed_need_line_revision_id=(request.request#>>'{payload,expected_current_revision_id}')::uuid
 where request.name='preview';
select is((select jsonb_array_length(value->'procurement_details')from c_context where name='partial-school-details'),1,
 'impact disclosure preserves the incumbent location-family read predicate');
select is((select value->'purchase_orders'from c_context where name='partial-school-details'),'[]'::jsonb,
 'partial School authority cannot disclose a whole PO containing the other School');
update atlas_core.actor_scopes set scope_status='REVOKED'
 where actor_id='c0150000-0000-4000-8000-000000000201';
select is((select atlas_core.confirmed_need_correction_procurement_details(
 'c0150000-0000-4000-8000-000000000201',r.service_date,r.delivery_location_id,r.ingredient_id,r.unit_id)
 from c_requests request join atlas_planning.confirmed_need_line_revisions r
 on r.confirmed_need_line_revision_id=(request.request#>>'{payload,expected_current_revision_id}')::uuid
 where request.name='preview'),jsonb_build_object('procurement_details_coverage','AUTHORIZED_DETAILS_ONLY',
 'procurement_details','[]'::jsonb,'purchase_order_coverage','AUTHORIZED_DOCUMENTS_ONLY','purchase_orders','[]'::jsonb),
 'revoked scope returns exactly the constant empty disclosure with no hidden flags');
select is(pg_temp.c_correct_call('get_confirmed_need_correction_preview',
 (select jsonb_set(request,'{payload,expected_need_generation_run_version}','"3"')from c_requests where name='preview'))
 ->>'error_code','VALIDATION_FAILED','string run version is not accepted as a typed numeric version');
select is(pg_temp.c_correct_call('get_confirmed_need_correction_preview',
 (select jsonb_set(request,'{correlation_id}','11111111111111111111111111111111')from c_requests where name='preview'))
 ->>'error_code','VALIDATION_FAILED','a JSON number that parses as UUID is still not a typed correlation string');
select is(pg_temp.c_correct_call('correct_confirmed_need',
 (select jsonb_set(request,'{command_id}','11111111111111111111111111111111')from c_requests where name='command'))
 ->>'error_code','VALIDATION_FAILED','numeric UUID-shaped command identity fails closed');
select is(pg_temp.c_correct_call('correct_confirmed_need',
 (select jsonb_set(request,'{requested_at}','null')from c_requests where name='command'))
 ->>'error_code','VALIDATION_FAILED','explicit NULL command timestamp fails closed');
select is(pg_temp.c_correct_call('correct_confirmed_need',
 (select jsonb_set(request,'{expected_version}','5')from c_requests where name='command'))->>'error_code','VALIDATION_FAILED',
 'outer and payload expected batch versions must agree');
select is(pg_temp.c_correct_call('get_confirmed_need_correction_preview',
 (select jsonb_set(request,'{payload,expected_current_revision_id}',to_jsonb(gen_random_uuid()))
 from c_requests where name='preview'))->>'error_code','STALE_CONFIRMED_NEED_LINE',
 'released correction cannot borrow a different revision identity');
select is(pg_temp.c_correct_call('correct_confirmed_need',
 (select jsonb_set(request,'{payload,proposal_fingerprint}',to_jsonb(repeat('0',64)))||
 jsonb_build_object('command_id',gen_random_uuid(),'idempotency_key',gen_random_uuid())from c_requests where name='command'))
 ->>'error_code','STALE_CORRECTION_PROPOSAL','command binds the exact reviewed server proposal');
savepoint c_incomplete_overlap;
create function pg_temp.c_setup_call(api text,request jsonb)returns jsonb language plpgsql as $$
declare answer jsonb;begin
 if api not in('get_planning_input_preflight','evaluate_planning_input_readiness',
  'request_planning_input_need_generation','create_need_generation_run','validate_need_generation_run',
  'release_need_generation_run','create_confirmed_needs_from_generation')then raise exception 'Unexpected setup API';end if;
 set local role authenticated;
 perform set_config('request.jwt.claim.sub','c0150000-0000-4000-8000-000000000101',true);
 execute format('select atlas_api.%I($1)',api)into answer using request;reset role;
 if answer->>'success'is distinct from 'true'then raise exception 'Public setup % failed: %',api,answer;end if;
 return answer;
exception when others then reset role;raise;end;$$;
do $public_overlap$
declare preflight jsonb;candidates jsonb;request jsonb;answer jsonb;state record;run uuid;stage record;
begin
 preflight:=pg_temp.c_setup_call('get_planning_input_preflight',pg_temp.c_read('RMVP-03B.v2',
  jsonb_build_object('period_start','2026-11-02','period_end','2026-11-03')));
 preflight:=preflight->'preflight';
 candidates:=jsonb_build_object('weekly_menu',(preflight#>'{source_evidence,weekly_menu,selected}')-
  array['source_name','source_signature'],'attendance',preflight#>'{source_evidence,attendance,selected}',
  'pantry',preflight#>'{source_evidence,pantry,selected}');
 -- Only the incumbent exact source identity/version/snapshot fields are input.
 select jsonb_object_agg(kind,(select jsonb_object_agg(key,value)from jsonb_each(value)
  where key=any(case kind when 'weekly_menu'then array['weekly_menu_id','weekly_menu_version','weekly_menu_approval_snapshot_id']
   when 'attendance'then array['attendance_batch_id','attendance_version','attendance_approval_snapshot_id']
   else array['pantry_need_batch_id','pantry_need_batch_version','pantry_need_approval_snapshot_id']end)))
 into candidates from jsonb_each(candidates)source(kind,value);
 request:=pg_temp.c_command('RMVP-03B.v1','READINESS_EVALUATION_REQUESTED',1,jsonb_build_object(
  'period_start','2026-11-02','period_end','2026-11-03','source_candidates',candidates))-'expected_version';
 request:=request||jsonb_build_object('expected_root_status','ABSENT','expected_current_evaluation_id',null,
  'expected_current_evaluation_version',null);
 perform pg_temp.c_setup_call('evaluate_planning_input_readiness',request);
 select s.planning_input_set_id,s.current_evaluation_id,e.evaluation_version,s.readiness_status into state
 from atlas_planning.planning_input_sets s join atlas_planning.planning_input_evaluations e
 on e.planning_input_evaluation_id=s.current_evaluation_id
 where s.period_start='2026-11-02'and s.period_end='2026-11-03';
 request:=pg_temp.c_command('RMVP-03B.v1','NEED_GENERATION_HANDOFF_REQUESTED',1,jsonb_build_object(
  'planning_input_set_id',state.planning_input_set_id,'period_start','2026-11-02','period_end','2026-11-03'))-'expected_version';
 request:=request||jsonb_build_object('expected_root_status',state.readiness_status,
  'expected_current_evaluation_id',state.current_evaluation_id,'expected_current_evaluation_version',state.evaluation_version);
 perform pg_temp.c_setup_call('request_planning_input_need_generation',request);
 answer:=pg_temp.c_setup_call('create_need_generation_run',pg_temp.c_command('RMVP-04.v1','NEED_GENERATION_CREATED',
  state.evaluation_version,jsonb_build_object('planning_input_set_id',state.planning_input_set_id,
   'planning_input_evaluation_id',state.current_evaluation_id,'period_start','2026-11-02','period_end','2026-11-03')));
 run:=(answer#>>'{affected_aggregate_ids,need_generation_run_id}')::uuid;
 for stage in select * from(values('validate_need_generation_run','NEED_GENERATION_VALIDATED',1),
  ('release_need_generation_run','NEED_GENERATION_RELEASED',2))steps(api,reason,version)loop
  perform pg_temp.c_setup_call(stage.api,pg_temp.c_command('RMVP-04.v1',stage.reason,stage.version,
   jsonb_build_object('need_generation_run_id',run)));
 end loop;
 perform pg_temp.c_setup_call('create_confirmed_needs_from_generation',pg_temp.c_command(
  'PA-06E-H0C.v1','CONFIRMED_NEED_MATERIALIZED',1,jsonb_build_object('need_generation_run_id',run,
   'need_generation_run_version',3,'confirmed_need_batch_id',null)));
end;$public_overlap$;
select is((select count(*)from atlas_planning.confirmed_need_lines l
 join atlas_planning.confirmed_need_batches b using(confirmed_need_batch_id)
 where b.period_start='2026-11-02'and b.period_end='2026-11-03'),6::bigint,
 'public staged range materialization creates six genuine overlapping Need lines');
select is((select count(*)from atlas_planning.confirmed_need_lines l
 join atlas_planning.confirmed_need_batches b using(confirmed_need_batch_id)
 where b.period_start='2026-11-02'and b.period_end='2026-11-03'
 and l.current_confirmed_need_line_decision_id is not null),0::bigint,
 'overlapping source is genuinely incomplete rather than fabricated released authority');
select is(pg_temp.c_correct_call('get_confirmed_need_correction_preview',
 (select request from c_requests where name='preview'))->>'success','false',
 'an overlapping incomplete published source cannot become a valid aggregated family proposal');
rollback to savepoint c_incomplete_overlap;
create temporary table c_late_before as select jsonb_build_object(
 'batches',(select jsonb_agg(to_jsonb(x)order by confirmed_need_batch_id)from atlas_planning.confirmed_need_batches x),
 'runs',(select jsonb_agg(to_jsonb(x)order by need_generation_run_id)from atlas_planning.need_generation_runs x),
 'revisions',(select jsonb_agg(to_jsonb(x)order by confirmed_need_line_revision_id)from atlas_planning.confirmed_need_line_revisions x),
 'decisions',(select jsonb_agg(to_jsonb(x)order by confirmed_need_line_decision_id)from atlas_planning.confirmed_need_line_decisions x),
 'handoffs',(select jsonb_agg(to_jsonb(x)order by purchase_handoff_revision_id)from atlas_planning.purchase_handoff_revisions x),
 'events',(select jsonb_agg(to_jsonb(x)order by domain_event_id)from atlas_audit.domain_events x),
 'audits',(select jsonb_agg(to_jsonb(x)order by audit_event_id)from atlas_audit.audit_events x))facts;
insert into c_requests select 'late-command',request||jsonb_build_object('command_id',gen_random_uuid(),
 'idempotency_key',gen_random_uuid())from c_requests where name='command';
-- Controlled local fault at a real prerequisite boundary, not a stubbed Save:
-- public prepare really reopens first; canonical Save then sees inactive Unit.
-- The fixture trigger and every source change are inside this rollback suite.
create function pg_temp.c_late_unit_change()returns trigger language plpgsql security definer set search_path='' as $$
begin
 if old.batch_status='RELEASED_FOR_PURCHASE_HANDOFF'and new.batch_status='REOPENED'
  and new.confirmed_need_batch_id=(select(request#>>'{payload,confirmed_need_batch_id}')::uuid
   from pg_temp.c_requests where name='late-command')then
  update atlas_admin.units set unit_status='INACTIVE'
  where unit_id='b6500000-0000-0000-0000-000000000005';
 end if;return new;
end;$$;
create trigger c_late_unit_change after update of batch_status on atlas_planning.confirmed_need_batches
for each row execute function pg_temp.c_late_unit_change();
insert into c_results select 'late-save-failure',pg_temp.c_correct_call('correct_confirmed_need',request),
 'authenticated'from c_requests where name='late-command';
drop trigger c_late_unit_change on atlas_planning.confirmed_need_batches;
drop function pg_temp.c_late_unit_change();
select is((select response->>'error_code'from c_results where name='late-save-failure'),'UNIT_INACTIVE',
 'real late canonical Save rejection follows a successful potential reopen');
select is((select facts from c_late_before),jsonb_build_object(
 'batches',(select jsonb_agg(to_jsonb(x)order by confirmed_need_batch_id)from atlas_planning.confirmed_need_batches x),
 'runs',(select jsonb_agg(to_jsonb(x)order by need_generation_run_id)from atlas_planning.need_generation_runs x),
 'revisions',(select jsonb_agg(to_jsonb(x)order by confirmed_need_line_revision_id)from atlas_planning.confirmed_need_line_revisions x),
 'decisions',(select jsonb_agg(to_jsonb(x)order by confirmed_need_line_decision_id)from atlas_planning.confirmed_need_line_decisions x),
 'handoffs',(select jsonb_agg(to_jsonb(x)order by purchase_handoff_revision_id)from atlas_planning.purchase_handoff_revisions x),
 'events',(select jsonb_agg(to_jsonb(x)order by domain_event_id)from atlas_audit.domain_events x),
 'audits',(select jsonb_agg(to_jsonb(x)order by audit_event_id)from atlas_audit.audit_events x)),
 'late Save failure rolls back all run/batch/revision/decision/Handoff effects');
select is((select unit_status from atlas_admin.units where unit_id='b6500000-0000-0000-0000-000000000005'),
 'ACTIVE','even the induced prerequisite drift rolls back with the child transaction');
select is((select count(*)from atlas_core.command_receipts child
 where child.idempotency_key like(select parent.command_receipt_id::text||':%'
 from atlas_core.command_receipts parent join c_requests r
 on parent.command_id=(r.request->>'command_id')::uuid where r.name='late-command')),0::bigint,
 'failed outer command retains no rolled-back child receipts');
select is((select outcome from atlas_core.command_receipts parent join c_requests r
 on parent.command_id=(r.request->>'command_id')::uuid where r.name='late-command'),'FAILED_NON_RETRYABLE',
 'only the exact nonretryable outer failure receipt may remain');
select is(pg_temp.c_correct_call('correct_confirmed_need',(select request from c_requests where name='late-command')),
 (select response from c_results where name='late-save-failure'),'failed exact replay does not rerun mutable children');
select is((select response?'child_command_ids'from c_results where name='late-save-failure'),false,
 'failed outcome reports no rolled-back child success evidence');
savepoint c_retry_probe;
insert into c_requests select 'retry-command',request||jsonb_build_object('command_id',gen_random_uuid(),
 'idempotency_key',gen_random_uuid())from c_requests where name='command';
create function pg_temp.c_retry_prepare()returns trigger language plpgsql set search_path='' as $$
begin
 if old.batch_status='RELEASED_FOR_PURCHASE_HANDOFF'and new.batch_status='REOPENED'then
  raise exception using errcode='40001',message='controlled local serialization conflict';end if;
 return new;
end;$$;
create trigger c_retry_prepare after update of batch_status on atlas_planning.confirmed_need_batches
for each row execute function pg_temp.c_retry_prepare();
insert into c_results select 'retryable-conflict',pg_temp.c_correct_call('correct_confirmed_need',request),
 'authenticated'from c_requests where name='retry-command';
drop trigger c_retry_prepare on atlas_planning.confirmed_need_batches;
select is((select response->>'error_code'from c_results where name='retryable-conflict'),
 'RETRYABLE_CONCURRENCY_FAILURE','controlled child serialization failure returns exact-retry outcome');
select is((select response->>'write_certainty'from c_results where name='retryable-conflict'),
 'NO_COMMITTED_CHANGE','caught SQL failure reports the known rolled-back outcome explicitly');
select is((select response->>'refresh_read'from c_results where name='retryable-conflict'),
 'get_confirmed_need_review','retryable SQL outcome names the authoritative recovery read');
select is((select count(*)from atlas_core.command_receipts parent join c_requests r
 on parent.command_id=(r.request->>'command_id')::uuid where r.name='retry-command'),0::bigint,
 'retryable outer failure leaves no blocking outer receipt');
select is(pg_temp.c_correct_call('correct_confirmed_need',(select request from c_requests where name='retry-command'))->>'success',
 'true','exact original request succeeds after the transient prerequisite is removed');
rollback to savepoint c_retry_probe;
insert into c_results select 'saved-correction',pg_temp.c_correct_call('correct_confirmed_need',request),
 'authenticated'from c_requests where name='command';
select is((select response->>'success'from c_results where name='saved-correction'),'true',
 'atomic correction reopens and saves through the existing authenticated child commands');
select is((select count(*)from atlas_planning.need_generation_runs),(select run_count from c_command_before),
 'quantity correction preserves the existing Need runs');
select is((select count(*)from atlas_planning.confirmed_need_line_revisions),9::bigint,
 'only the selected Need revision is appended');
select is((select count(*)from atlas_procurement.purchase_orders),4::bigint,
 'correction creates no PO automatically');
select is((select count(*)from atlas_dispatch.school_dispatch_releases),3::bigint,
 'correction creates no PXK automatically');
select is(pg_temp.c_correct_call('correct_confirmed_need',(select request from c_requests where name='command')),
 (select response from c_results where name='saved-correction'),'exact success replays after its own mutable successor');
select is(pg_temp.c_correct_call('correct_confirmed_need',(select jsonb_set(request,
 '{payload,reason_note}','"Different correction intent"')from c_requests where name='command'))->>'error_code',
 'IDEMPOTENCY_CONFLICT','same command identity with different intent fails before mutable currentness');
select is(pg_temp.c_correct_call('correct_confirmed_need',(select jsonb_set(request,
 '{payload,reason_note}','"Different correction intent"')from c_requests where name='command'))->>'write_certainty',
 'NO_COMMITTED_CHANGE','conflicting replay reports safe rejection without an inferred UNKNOWN state');
select is((select count(distinct id)from c_results r
 cross join lateral jsonb_array_elements_text(r.response->'child_command_ids')id
 where r.name='saved-correction'and id<>r.response->>'command_id'),2::bigint,
 'prepare and Save use distinct child IDs instead of reusing the outer command');
select is((select count(*)from atlas_core.command_receipts child
 join c_results parent on parent.name='saved-correction'
 where child.command_id::text in(select jsonb_array_elements_text(parent.response->'child_command_ids'))
 and child.outcome='COMPLETED'and child.actor_id='c0150000-0000-4000-8000-000000000001'),2::bigint,
 'one existing authorized Actor completes both audited child commands');
select is((select count(*)from atlas_core.command_receipts child
 join c_results parent on parent.name='saved-correction'
 where child.command_id::text in(select jsonb_array_elements_text(parent.response->'child_command_ids'))
 and child.idempotency_key in(parent.response->>'receipt_id'||':prepare',parent.response->>'receipt_id'||':save')),2::bigint,
 'child idempotency keys derive from the durable outer receipt and stage');
insert into c_results
select 'later-ordinary-save',pg_temp.c_invoke('later-ordinary-child','save_confirmed_needs',
 pg_temp.c_command('RMVP-05.v2','CONFIRMED_NEED_SAVED',b.version,jsonb_build_object(
 'confirmed_need_batch_id',b.confirmed_need_batch_id,'lines',jsonb_build_array(jsonb_build_object(
 'confirmed_need_line_id',l.confirmed_need_line_id,'expected_current_revision_id',r.confirmed_need_line_revision_id,
 'expected_current_decision_id',l.current_confirmed_need_line_decision_id,
 'proposed_confirmed_quantity',(r.confirmed_quantity+1)::text,'reason_code','OPERATIONAL_QUANTITY_ADJUSTMENT',
 'reason_note','Later ordinary correction preserves original receipt authority'))))),'authenticated'
 from c_requests selected join atlas_planning.confirmed_need_batches b
 on b.confirmed_need_batch_id=(selected.request#>>'{payload,confirmed_need_batch_id}')::uuid
 join atlas_planning.confirmed_need_lines l on l.confirmed_need_line_id=(selected.request#>>'{payload,confirmed_need_line_id}')::uuid
 join atlas_planning.confirmed_need_line_revisions r on r.confirmed_need_line_id=l.confirmed_need_line_id and r.is_current
 where selected.name='command';
select is((select response->>'success'from c_results where name='later-ordinary-save'),'true',
 'a later ordinary correction genuinely advances the same selected current revision');
select is(pg_temp.c_correct_call('correct_confirmed_need',(select request from c_requests where name='command')),
 (select response from c_results where name='saved-correction'),'original exact success replays after later current revision/version changes');
select is((select count(*)from atlas_planning.confirmed_need_line_revisions),10::bigint,
 'replay after later correction creates no third successor');
select is((select count(*)from pg_proc p where p.oid in(
 'atlas_api.get_confirmed_need_correction_preview(jsonb)'::regprocedure,'atlas_api.correct_confirmed_need(jsonb)'::regprocedure)
 and p.proowner='atlas_confirmed_need_review_runtime'::regrole and p.prosecdef
 and p.proconfig @>array['search_path=""']),2::bigint,
 'both exact public APIs retain Review owner/SECDEF/empty path');
select ok((select bool_and(has_function_privilege('authenticated',p.oid,'EXECUTE')
 and not has_function_privilege('anon',p.oid,'EXECUTE')and not has_function_privilege('service_role',p.oid,'EXECUTE')
 and not exists(select from aclexplode(p.proacl)acl where acl.grantee=0))from pg_proc p where p.oid in(
 'atlas_api.get_confirmed_need_correction_preview(jsonb)'::regprocedure,'atlas_api.correct_confirmed_need(jsonb)'::regprocedure)),
 'only authenticated browser role gains the exact two guarded APIs');
select is((select count(*)from pg_proc p cross join unnest(array['authenticated','anon','service_role'])principal
 where p.oid in('atlas_core.confirmed_need_correction_request_valid(jsonb,boolean)'::regprocedure,
 'atlas_core.confirmed_need_correction_proposal(jsonb)'::regprocedure,
 'atlas_core.rmvp_05_canonical_preview(uuid,bigint,jsonb,boolean)'::regprocedure,
 'atlas_core.confirmed_need_correction_source_current(uuid)'::regprocedure,
 'atlas_core.confirmed_need_correction_procurement_details(uuid,date,uuid,uuid,uuid)'::regprocedure)
 and has_function_privilege(principal,p.oid,'EXECUTE')),0::bigint,
 'no browser or service role can supply private evaluator/source/disclosure input');
select * from finish();
rollback;
