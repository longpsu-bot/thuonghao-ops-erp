begin;
create extension if not exists pgtap with schema extensions;
set search_path=extensions,public,pg_catalog;
select no_plan();

-- Exact new function trust boundaries; CAT22's target-role digest omits PUBLIC.
select ok(p.proowner='atlas_owner'::regrole and not p.prosecdef
  and p.proconfig @> array['search_path=""'], 'bulk candidate helper retains intended owner, INVOKER and empty path')
from pg_proc p where p.oid='atlas_core.supplier_allocation_bulk_candidates(uuid,date,date,jsonb,boolean)'::regprocedure;
select ok(p.proowner='atlas_procurement_command_runtime'::regrole and p.prosecdef
  and p.proconfig @> array['search_path=""'], 'shared Confirmed command retains command owner, DEFINER and empty path')
from pg_proc p where p.oid='atlas_core.purchase_review_save_confirmed_allocation(jsonb,jsonb)'::regprocedure;
select ok(not has_function_privilege('authenticated',p.oid,'EXECUTE')
  and not has_function_privilege('anon',p.oid,'EXECUTE') and not has_function_privilege('service_role',p.oid,'EXECUTE')
  and not exists(select 1 from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where a.grantee=0 and a.privilege_type='EXECUTE'),
  'new private helper denies browser, service and PUBLIC EXECUTE: '||p.proname)
from pg_proc p where p.oid in ('atlas_core.supplier_allocation_bulk_candidates(uuid,date,date,jsonb,boolean)'::regprocedure,
  'atlas_core.purchase_review_save_confirmed_allocation(jsonb,jsonb)'::regprocedure) order by p.proname;
select ok(has_function_privilege('atlas_read_runtime','atlas_core.supplier_allocation_bulk_candidates(uuid,date,date,jsonb,boolean)','EXECUTE')
  and has_function_privilege('atlas_procurement_command_runtime','atlas_core.supplier_allocation_bulk_candidates(uuid,date,date,jsonb,boolean)','EXECUTE')
  and has_function_privilege('atlas_procurement_command_runtime','atlas_core.purchase_review_save_confirmed_allocation(jsonb,jsonb)','EXECUTE'),
  'only intended read/command paths can execute the new private seams');
select ok(p.proowner='atlas_procurement_command_runtime'::regrole and p.prosecdef
  and p.proconfig @> array['search_path=""']
  and has_function_privilege('authenticated',p.oid,'EXECUTE')
  and not has_function_privilege('anon',p.oid,'EXECUTE') and not has_function_privilege('service_role',p.oid,'EXECUTE')
  and not exists(select 1 from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a where a.grantee=0 and a.privilege_type='EXECUTE'),
  'batch API preserves exact command owner, DEFINER, empty path and authenticated-only browser entry')
from pg_proc p where p.oid='atlas_api.apply_supplier_allocation_batch(jsonb)'::regprocedure;

\ir ../local/purchase_review_confirm_release_fixture.sql
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
begin
  set local role authenticated;
  execute format('select atlas_api.%I($1)',api_name) into result using request;
  reset role; return result;
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
create function pg_temp.need_save_complete_review(quantity text) returns jsonb
language sql volatile set search_path='' as $$
  select pg_temp.review_command('RMVP-05.v2','CONFIRMED_NEED_SAVED',b.version,jsonb_build_object(
    'confirmed_need_batch_id',b.confirmed_need_batch_id,'lines',(
      select jsonb_agg(jsonb_build_object(
        'confirmed_need_line_id',l.confirmed_need_line_id,
        'expected_current_revision_id',r.confirmed_need_line_revision_id,
        'expected_current_decision_id',l.current_confirmed_need_line_decision_id,
        'proposed_confirmed_quantity',case
          when l.ingredient_id='b6500000-0000-0000-0000-000000000006' then quantity
          else (r.confirmed_quantity+1)::text
        end,
        'reason_code','OPERATIONAL_QUANTITY_ADJUSTMENT',
        'reason_note','Manual paper correction')
        order by l.confirmed_need_line_id)
      from atlas_planning.confirmed_need_lines l
      join atlas_planning.confirmed_need_line_revisions r
        on r.confirmed_need_line_id=l.confirmed_need_line_id and r.is_current
      where l.confirmed_need_batch_id=b.confirmed_need_batch_id)))
  from atlas_planning.confirmed_need_batches b
  where b.confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050';
$$;

create function pg_temp.bulk_read(extra jsonb default '{}') returns jsonb language plpgsql as $$
declare result jsonb;
begin
  set local role authenticated;
  result:=atlas_api.get_confirmed_supplier_allocation_workbench(jsonb_build_object(
    'contract_version','CONFIRMED-SUPPLIER-ALLOCATION.v1','correlation_id',gen_random_uuid(),
    'requested_by_auth_subject','b6000000-0000-0000-0000-000000000101',
    'payload','{"date_start":"2026-11-02","date_end":"2026-11-02"}'::jsonb||extra));
  reset role; return result;
end;
$$;
create function pg_temp.bulk_apply(payload jsonb) returns jsonb language plpgsql as $$
declare result jsonb;
begin
  execute 'select atlas_api.apply_supplier_allocation_batch($1)' into result using
    pg_temp.review_command('SUPPLIER-ALLOCATION-BATCH.v1','SUPPLIER_ALLOCATION_BATCH_APPLIED',1,payload);
  return result;
exception when undefined_function then return '{"missing_api":true}';
end;
$$;
select set_config('request.jwt.claim.sub','b6000000-0000-0000-0000-000000000101',true);
select ok(pg_temp.bulk_read()->>'success'='true','ordinary Allocation read succeeds on main109');
select ok(pg_temp.bulk_read('{"include_bulk_preview":false}')=pg_temp.bulk_read(),
  'explicit false strips optional flag before closed legacy forwarding and preserves response');
select is(pg_temp.bulk_read('{"include_bulk_preview":null}')->>'error_code','VALIDATION_FAILED',
  'null preview flag is rejected safely');
select is(pg_temp.bulk_read('{"include_bulk_preview":"true"}')->>'error_code','VALIDATION_FAILED',
  'string preview flag is rejected safely');
select ok(pg_temp.bulk_read('{"include_bulk_preview":true}')?'bulk_preview',
  'opt-in returns backend preview including incomplete exclusions');
select ok(pg_temp.bulk_apply('{"scope":{"date_start":"2026-11-02","date_end":"2026-11-02"},"candidates":[]}')->>'error_code'='VALIDATION_FAILED',
  'new batch command rejects an empty selected set');
select is(pg_temp.review_invoke('save_confirmed_needs',jsonb_set(pg_temp.need_save('100.000000'),'{payload,lines}',
  (select jsonb_agg(e||jsonb_build_object('reason_code','PROPOSAL_ACCEPTED','reason_note',null))
    from jsonb_array_elements(pg_temp.need_save('100.000000')#>'{payload,lines}') e)))->>'success','true',
  'fixture completes current saved Confirmed Need through authenticated command');
create temporary table bulk_results(name text primary key,value jsonb);
insert into bulk_results values ('preview',pg_temp.bulk_read('{"include_bulk_preview":true}'));
select ok((select jsonb_array_length(value#>'{bulk_preview,families}')=2 from bulk_results where name='preview'),
  'preview includes both exact complete families');
select is((select value#>>'{bulk_preview,applicable_count}' from bulk_results where name='preview'),'2',
  'two genuinely unallocated safe defaults are applicable');
select is((select e->>'family_quantity' from bulk_results,lateral jsonb_array_elements(value#>'{bulk_preview,families}') e
  where name='preview' and e->>'ingredient_id'='b6500000-0000-0000-0000-000000000006'),'100.000000',
  'default proposal retains exact six-decimal full family quantity');
select ok((select bool_and(e->>'unit_label'='RMVP-05 browser kilogram') from bulk_results,
  lateral jsonb_array_elements(value#>'{bulk_preview,families}') e where name='preview'),
  'new preview projects readable canonical Unit names');
select is(pg_temp.bulk_read('{"include_bulk_preview":true,"states":["BLOCKED"],"search":"no-match"}')->'bulk_preview',
  (select value->'bulk_preview' from bulk_results where name='preview'),
  'bulk preview ignores presentation-only state/search filters');
create function pg_temp.bulk_request(preview jsonb) returns jsonb language sql volatile as $$
  select pg_temp.review_command('SUPPLIER-ALLOCATION-BATCH.v1','SUPPLIER_ALLOCATION_BATCH_APPLIED',1,
    jsonb_build_object('scope','{"date_start":"2026-11-02","date_end":"2026-11-02"}'::jsonb,
      'candidates',(select jsonb_agg(e->'candidate' order by e->>'ingredient_id')
        from jsonb_array_elements(preview#>'{bulk_preview,families}') e where e->'candidate'<>'null'::jsonb)));
$$;
create temporary table bulk_requests as select pg_temp.bulk_request(value) request from bulk_results where name='preview';
-- Late child failure must undo earlier child revisions and its completed receipt/events.
create function pg_temp.bulk_case_bulk_late_failure() returns jsonb language plpgsql as $case$
declare checks jsonb:='[]';
begin

create function pg_temp.bulk_reject_second() returns trigger language plpgsql as $$
begin
  if new.ingredient_id='b6500000-0000-0000-0000-000000000007' then raise exception 'synthetic late writer rejection'; end if;
  return new;
end;
$$;
create trigger bulk_reject_second before insert on atlas_procurement.school_catering_allocation_families
  for each row execute function pg_temp.bulk_reject_second();
insert into bulk_results select 'late-failure',pg_temp.review_invoke('apply_supplier_allocation_batch',request) from bulk_requests;
checks:=checks||jsonb_build_array(jsonb_build_object('pass',coalesce((((select value->>'success' from bulk_results where name='late-failure')) is not distinct from ('false')),false),'message','late second child failure fails the whole batch'));
checks:=checks||jsonb_build_array(jsonb_build_object('pass',coalesce((((select value#>>'{conflicts,0,family,ingredient_id}' from bulk_results where name='late-failure')) is not distinct from ('b6500000-0000-0000-0000-000000000007')),false),'message','late failure occurs in second child after first was written'));
checks:=checks||jsonb_build_array(jsonb_build_object('pass',coalesce((((select count(*) from atlas_procurement.school_catering_allocation_family_revisions)) is not distinct from (0::bigint)),false),'message','late child failure leaves no partial allocation revisions'));
checks:=checks||jsonb_build_array(jsonb_build_object('pass',coalesce((((select count(*) from atlas_audit.domain_events where event_type='ConfirmedSupplierAllocationSaved')) is not distinct from (0::bigint)),false),'message','late child failure leaves no success child events'));

  raise exception using errcode='PBTC1';
exception when sqlstate 'PBTC1' then return checks;
end;
$case$;
select ok((e->>'pass')::boolean,e->>'message') from jsonb_array_elements(pg_temp.bulk_case_bulk_late_failure()) e;

create function pg_temp.bulk_case_changed_priority() returns jsonb language plpgsql as $case$
declare checks jsonb:='[]';
begin

update atlas_admin.supplier_eligibilities set priority=3 where supplier_id='c7100000-0000-4000-8000-000000000001';
insert into bulk_results select 'priority-race',pg_temp.review_invoke('apply_supplier_allocation_batch',request) from bulk_requests;
checks:=checks||jsonb_build_array(jsonb_build_object('pass',coalesce((((select value->>'error_code' from bulk_results where name='priority-race')) is not distinct from ('STALE_BULK_PROPOSAL')),false),'message','changed best Supplier rejects the exact reviewed proposal rather than substituting'));
checks:=checks||jsonb_build_array(jsonb_build_object('pass',coalesce((((select count(*) from atlas_procurement.school_catering_allocation_family_revisions)) is not distinct from (0::bigint)),false),'message','priority race writes zero allocation revisions'));

  raise exception using errcode='PBTC1';
exception when sqlstate 'PBTC1' then return checks;
end;
$case$;
select ok((e->>'pass')::boolean,e->>'message') from jsonb_array_elements(pg_temp.bulk_case_changed_priority()) e;

create function pg_temp.bulk_case_duplicate_family() returns jsonb language plpgsql as $case$
declare checks jsonb:='[]';
begin

insert into bulk_results select 'duplicate',pg_temp.review_invoke('apply_supplier_allocation_batch',
  jsonb_set(request,'{payload,candidates}',(request#>'{payload,candidates}')||jsonb_build_array(
    jsonb_set(request#>'{payload,candidates,0}','{proposal_fingerprint}','"different"')))) from bulk_requests;
checks:=checks||jsonb_build_array(jsonb_build_object('pass',coalesce((((select value->>'error_code' from bulk_results where name='duplicate')) is not distinct from ('VALIDATION_FAILED')),false),'message','duplicate whole-family keys are rejected independently of fingerprint'));

  raise exception using errcode='PBTC1';
exception when sqlstate 'PBTC1' then return checks;
end;
$case$;
select ok((e->>'pass')::boolean,e->>'message') from jsonb_array_elements(pg_temp.bulk_case_duplicate_family()) e;

create function pg_temp.bulk_case_source_race() returns jsonb language plpgsql as $case$
declare checks jsonb:='[]';
begin

checks:=checks||jsonb_build_array(jsonb_build_object('pass',coalesce(((pg_temp.review_invoke('save_confirmed_needs',pg_temp.need_save('120.000000'))->>'success') is not distinct from ('true')),false),'message','Planning source can advance after reviewed preview'));
insert into bulk_results select 'source-race',pg_temp.review_invoke('apply_supplier_allocation_batch',request) from bulk_requests;
checks:=checks||jsonb_build_array(jsonb_build_object('pass',coalesce((((select value->>'error_code' from bulk_results where name='source-race')) is not distinct from ('STALE_BULK_PROPOSAL')),false),'message','changed source/batch version fails the complete reviewed set'));

  raise exception using errcode='PBTC1';
exception when sqlstate 'PBTC1' then return checks;
end;
$case$;
select ok((e->>'pass')::boolean,e->>'message') from jsonb_array_elements(pg_temp.bulk_case_source_race()) e;

create function pg_temp.bulk_case_zero_source() returns jsonb language plpgsql as $case$
declare checks jsonb:='[]';
begin

checks:=checks||jsonb_build_array(jsonb_build_object('pass',coalesce(((pg_temp.review_invoke('save_confirmed_needs',pg_temp.need_save('0.000000'))->>'success') is not distinct from ('true')),false),'message','explicit saved zero is a real complete Planning fact'));
insert into bulk_results values('zero',pg_temp.bulk_read('{"include_bulk_preview":true}'));
checks:=checks||jsonb_build_array(jsonb_build_object('pass',coalesce(((select exists(select 1 from jsonb_array_elements(value#>'{bulk_preview,families}') e
  where e->>'ingredient_id'='b6500000-0000-0000-0000-000000000006'
    and e->>'exclusion_reason'='ZERO_QUANTITY' and e->'candidate'='null'::jsonb) from bulk_results where name='zero')),false),'message','bulk preview includes complete zero sources omitted from ordinary table'));
checks:=checks||jsonb_build_array(jsonb_build_object('pass',coalesce(((select not exists(select 1 from jsonb_array_elements(value->'rows') e
  where e->>'ingredient_id'='b6500000-0000-0000-0000-000000000006') from bulk_results where name='zero')),false),'message','ordinary table zero omission remains unchanged'));

  raise exception using errcode='PBTC1';
exception when sqlstate 'PBTC1' then return checks;
end;
$case$;
select ok((e->>'pass')::boolean,e->>'message') from jsonb_array_elements(pg_temp.bulk_case_zero_source()) e;

create function pg_temp.bulk_case_no_priority() returns jsonb language plpgsql as $case$
declare checks jsonb:='[]';
begin

update atlas_admin.supplier_eligibilities set priority=null;
checks:=checks||jsonb_build_array(jsonb_build_object('pass',coalesce(((pg_temp.bulk_read('{"include_bulk_preview":true}')#>>'{bulk_preview,applicable_count}') is not distinct from ('0')),false),'message','no effective preferred priority excludes defaults without a name/UUID tie-break'));

-- Production's unique active-priority index forbids new ties; retained tie behavior
-- follows the existing Handoff test pattern only inside this rolled-back fixture.
drop index atlas_admin.supplier_eligibilities_active_priority_key;
update atlas_admin.supplier_eligibilities set priority=1;
checks:=checks||jsonb_build_array(jsonb_build_object('pass',coalesce((select count(*)=2 and bool_and(
  e->'candidate'='null'::jsonb and e->>'exclusion_reason'='NO_UNIQUE_PREFERRED_SUPPLIER')
  from jsonb_array_elements(pg_temp.bulk_read('{"include_bulk_preview":true}')#>'{bulk_preview,families}') e),false),
  'message','retained tied best priorities exclude every default rather than choosing a name or UUID'));
update atlas_admin.suppliers set supplier_status='INACTIVE';
checks:=checks||jsonb_build_array(jsonb_build_object('pass',coalesce((select count(*)=2 and bool_and(
  e->'candidate'='null'::jsonb and e->>'exclusion_reason'='NO_ELIGIBLE_SUPPLIER')
  from jsonb_array_elements(pg_temp.bulk_read('{"include_bulk_preview":true}')#>'{bulk_preview,families}') e),false),
  'message','no active eligible Supplier is an explicit exclusion, never a zero or default'));


  raise exception using errcode='PBTC1';
exception when sqlstate 'PBTC1' then return checks;
end;
$case$;
select ok((e->>'pass')::boolean,e->>'message') from jsonb_array_elements(pg_temp.bulk_case_no_priority()) e;

create function pg_temp.bulk_case_supplier_race() returns jsonb language plpgsql as $case$
declare checks jsonb:='[]';
begin

update atlas_admin.suppliers set supplier_status='INACTIVE' where supplier_id='c7100000-0000-4000-8000-000000000001';
insert into bulk_results select 'supplier-race',pg_temp.review_invoke('apply_supplier_allocation_batch',request) from bulk_requests;
checks:=checks||jsonb_build_array(jsonb_build_object('pass',coalesce((((select value->>'error_code' from bulk_results where name='supplier-race')) is not distinct from ('STALE_BULK_PROPOSAL')),false),'message','changed Supplier eligibility cannot silently choose an alternative'));

  raise exception using errcode='PBTC1';
exception when sqlstate 'PBTC1' then return checks;
end;
$case$;
select ok((e->>'pass')::boolean,e->>'message') from jsonb_array_elements(pg_temp.bulk_case_supplier_race()) e;

create function pg_temp.bulk_case_no_write_capability() returns jsonb language plpgsql as $case$
declare checks jsonb:='[]';
begin

delete from atlas_core.role_capabilities where capability_id=(select capability_id from atlas_core.capabilities
  where capability_code='procurement.school_catering.write');
insert into bulk_results select 'no-write',pg_temp.review_invoke('apply_supplier_allocation_batch',request) from bulk_requests;
checks:=checks||jsonb_build_array(jsonb_build_object('pass',coalesce((((select value->>'error_code' from bulk_results where name='no-write')) is not distinct from ('CAPABILITY_DENIED')),false),'message','batch requires the existing Procurement write capability'));

  raise exception using errcode='PBTC1';
exception when sqlstate 'PBTC1' then return checks;
end;
$case$;
select ok((e->>'pass')::boolean,e->>'message') from jsonb_array_elements(pg_temp.bulk_case_no_write_capability()) e;

create function pg_temp.bulk_case_no_scope() returns jsonb language plpgsql as $case$
declare checks jsonb:='[]';
begin

delete from atlas_core.actor_scopes where actor_id='b6000000-0000-0000-0000-000000000001';
insert into bulk_results select 'no-scope',pg_temp.review_invoke('apply_supplier_allocation_batch',request) from bulk_requests;
checks:=checks||jsonb_build_array(jsonb_build_object('pass',coalesce((((select value->>'error_code' from bulk_results where name='no-scope')) is not distinct from ('SCOPE_DENIED')),false),'message','missing relational scope rejects all selected writes'));
checks:=checks||jsonb_build_array(jsonb_build_object('pass',coalesce(((pg_temp.bulk_read('{"include_bulk_preview":true}')#>>'{bulk_preview,total_count}') is not distinct from ('0')),false),'message','preview counts only authorized families'));

  raise exception using errcode='PBTC1';
exception when sqlstate 'PBTC1' then return checks;
end;
$case$;
select ok((e->>'pass')::boolean,e->>'message') from jsonb_array_elements(pg_temp.bulk_case_no_scope()) e;

create function pg_temp.bulk_case_relational_write_only() returns jsonb language plpgsql as $case$
declare checks jsonb:='[]';
begin

update atlas_core.actor_scopes set scope_kind='DELIVERY_LOCATION',delivery_location_id='b6500000-0000-0000-0000-000000000002'
  where actor_id='b6000000-0000-0000-0000-000000000001' and scope_kind='GLOBAL';
delete from atlas_core.role_capabilities where capability_id=(select capability_id from atlas_core.capabilities
  where capability_code='procurement.school_catering.read');
insert into bulk_results select 'relational-write-only',pg_temp.review_invoke('apply_supplier_allocation_batch',request) from bulk_requests;
checks:=checks||jsonb_build_array(jsonb_build_object('pass',coalesce((((select value->>'success' from bulk_results where name='relational-write-only')) is not distinct from ('true')),false),'message','Apply requires neither read capability nor GLOBAL when existing location-family scope allows'));

  raise exception using errcode='PBTC1';
exception when sqlstate 'PBTC1' then return checks;
end;
$case$;
select ok((e->>'pass')::boolean,e->>'message') from jsonb_array_elements(pg_temp.bulk_case_relational_write_only()) e;

insert into bulk_results select 'applied',pg_temp.review_invoke('apply_supplier_allocation_batch',request) from bulk_requests;
select is((select value->>'success' from bulk_results where name='applied'),'true','two-family default batch succeeds atomically');
select is((select value->>'applied_count' from bulk_results where name='applied'),'2','success count names only saved families');
select is((select count(*) from atlas_procurement.school_catering_allocation_family_revisions),2::bigint,
  'one immutable allocation revision per selected family');
insert into bulk_results select 'replay',pg_temp.review_invoke('apply_supplier_allocation_batch',request) from bulk_requests;
select is((select value from bulk_results where name='replay'),(select value from bulk_results where name='applied'),
  'exact replay resolves outer receipt without generating new child writes');
select is((select count(*) from atlas_procurement.school_catering_allocation_family_revisions),2::bigint,
  'replay appends no allocation revisions');
insert into bulk_results select 'conflicting-replay',pg_temp.review_invoke('apply_supplier_allocation_batch',
  jsonb_set(request,'{payload,candidates,0,proposal_fingerprint}','"different"')) from bulk_requests;
select is((select value->>'error_code' from bulk_results where name='conflicting-replay'),'IDEMPOTENCY_CONFLICT',
  'changed reviewed proposal cannot reuse accepted idempotency identity');
create function pg_temp.bulk_case_rebalance_notes() returns jsonb language plpgsql as $case$
declare checks jsonb:='[]';
begin

-- Replace the rice default with an explicit manual split, retaining a distinct note per Supplier.
insert into bulk_results values('manual-note',pg_temp.review_invoke('save_confirmed_supplier_allocation',
  pg_temp.review_command('CONFIRMED-SUPPLIER-ALLOCATION.v1','CONFIRMED_SUPPLIER_ALLOCATION_SAVED',1,
    jsonb_build_object('family',(select (e->'candidate'->'family')-array['source_kind','expected_family_version']
      from bulk_results,lateral jsonb_array_elements(value#>'{bulk_preview,families}') e
      where name='preview' and e->>'ingredient_id'='b6500000-0000-0000-0000-000000000006'),
      'splits','[{"supplier_id":"c7100000-0000-4000-8000-000000000001","allocated_quantity":"60.000001","supplier_note":"Retain A"},
      {"supplier_id":"c7100000-0000-4000-8000-000000000002","allocated_quantity":"39.999999","supplier_note":"Retain B"}]'::jsonb))));
checks:=checks||jsonb_build_array(jsonb_build_object('pass',coalesce((((select value->>'success' from bulk_results where name='manual-note')) is not distinct from ('true')),false),'message','manual split notes saved through existing command'));
checks:=checks||jsonb_build_array(jsonb_build_object('pass',coalesce(((pg_temp.review_invoke('save_confirmed_needs',pg_temp.need_save('120.01'))->>'success') is not distinct from ('true')),false),'message','Need advances to six-decimal residual case'));
insert into bulk_results values('rebalance',pg_temp.bulk_read('{"include_bulk_preview":true}'));
checks:=checks||jsonb_build_array(jsonb_build_object('pass',coalesce((((select e#>>'{candidate,proposal_kind}' from bulk_results,lateral jsonb_array_elements(value#>'{bulk_preview,families}') e
  where name='rebalance' and e->>'ingredient_id'='b6500000-0000-0000-0000-000000000006')) is not distinct from ('REBALANCE')),false),'message','stale manual split offers explicit rebalance'));
checks:=checks||jsonb_build_array(jsonb_build_object('pass',coalesce((((select e#>>'{candidate,proposed_splits,0,allocated_quantity}' from bulk_results,lateral jsonb_array_elements(value#>'{bulk_preview,families}') e
  where name='rebalance' and e->>'ingredient_id'='b6500000-0000-0000-0000-000000000006')) is not distinct from ('72.006001')),false),'message','first Supplier uses canonical six-decimal rounding'));
checks:=checks||jsonb_build_array(jsonb_build_object('pass',coalesce((((select e#>>'{candidate,proposed_splits,1,allocated_quantity}' from bulk_results,lateral jsonb_array_elements(value#>'{bulk_preview,families}') e
  where name='rebalance' and e->>'ingredient_id'='b6500000-0000-0000-0000-000000000006')) is not distinct from ('48.003999')),false),'message','last Supplier gets exact deterministic residual'));
insert into bulk_results select 'rebalanced',pg_temp.review_invoke('apply_supplier_allocation_batch',pg_temp.bulk_request(value))
  from bulk_results where name='rebalance';
checks:=checks||jsonb_build_array(jsonb_build_object('pass',coalesce((((select value->>'success' from bulk_results where name='rebalanced')) is not distinct from ('true')),false),'message','reviewed rebalance saves atomically'));
checks:=checks||jsonb_build_array(jsonb_build_object('pass',coalesce(((select count(*)=2 and bool_and(s.supplier_note is not distinct from case s.supplier_id
  when 'c7100000-0000-4000-8000-000000000001' then 'Retain A' else 'Retain B' end)
  from atlas_procurement.school_catering_allocation_supplier_splits s
  join atlas_procurement.school_catering_allocation_family_revisions r using(family_revision_id)
  join atlas_procurement.school_catering_allocation_families f using(family_id)
  where r.is_current and f.ingredient_id='b6500000-0000-0000-0000-000000000006')),false),'message','retained Supplier notes survive exact rebalance'));

  raise exception using errcode='PBTC1';
exception when sqlstate 'PBTC1' then return checks;
end;
$case$;
select ok((e->>'pass')::boolean,e->>'message') from jsonb_array_elements(pg_temp.bulk_case_rebalance_notes()) e;

select * from finish();
rollback;
