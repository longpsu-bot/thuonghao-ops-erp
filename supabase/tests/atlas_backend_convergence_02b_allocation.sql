begin;
create extension if not exists pgtap with schema extensions;
set search_path=extensions,public,pg_catalog;
select no_plan();
\ir ../local/purchase_review_confirm_release_fixture.sql
select set_config('request.jwt.claim.sub','b6000000-0000-0000-0000-000000000101',true);

create function pg_temp.command(contract text,reason text,version bigint,payload jsonb)
returns jsonb language sql volatile set search_path='' as $$
  select jsonb_build_object('contract_version',contract,'command_id',gen_random_uuid(),
    'correlation_id',gen_random_uuid(),'idempotency_key',gen_random_uuid()::text,
    'expected_version',version,'requested_by_auth_subject','b6000000-0000-0000-0000-000000000101',
    'requested_at',transaction_timestamp()-interval '1 second','reason_code',reason,
    'reason_note',null,'payload',payload);
$$;
create function pg_temp.invoke(api_name text,request jsonb) returns jsonb
language plpgsql set search_path='' as $$
declare answer jsonb;
begin
  set local role authenticated;
  execute format('select atlas_api.%I($1)',api_name) into answer using request;
  reset role;
  return answer;
end;
$$;

-- Real Planning Save over the existing guarded, two-Ingredient fixture.
select is(pg_temp.invoke('save_confirmed_needs',pg_temp.command('RMVP-05.v2',
  'CONFIRMED_NEED_SAVED',b.version,jsonb_build_object('confirmed_need_batch_id',b.confirmed_need_batch_id,
    'lines',(select jsonb_agg(jsonb_build_object('confirmed_need_line_id',l.confirmed_need_line_id,
      'expected_current_revision_id',r.confirmed_need_line_revision_id,
      'expected_current_decision_id',l.current_confirmed_need_line_decision_id,
      'proposed_confirmed_quantity',case when l.ingredient_id='b6500000-0000-0000-0000-000000000006'
        then '100.000000' else '3.000000' end,
      'reason_code','PROPOSAL_ACCEPTED','reason_note',null))
    from atlas_planning.confirmed_need_lines l join atlas_planning.confirmed_need_line_revisions r
      on r.confirmed_need_line_id=l.confirmed_need_line_id and r.is_current
    where l.confirmed_need_batch_id=b.confirmed_need_batch_id
      and l.current_confirmed_need_line_decision_id is null))))->>'success','true',
  'minimum source facts are saved through the complete Planning command')
from atlas_planning.confirmed_need_batches b
where b.confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050';

create function pg_temp.allocation_request(source_kind text,ingredient uuid,qa text,qb text)
returns jsonb language plpgsql set search_path='' as $$
declare projection jsonb;family jsonb;version bigint;contract text;reason text;splits jsonb;
begin
  if source_kind='CONFIRMED_NEED' then
    projection:=atlas_core.purchase_review_confirmed_projection('2026-11-02',
      'b6500000-0000-0000-0000-000000000002',ingredient,'b6500000-0000-0000-0000-000000000005');
    contract:='CONFIRMED-SUPPLIER-ALLOCATION.v1';reason:='CONFIRMED_SUPPLIER_ALLOCATION_SAVED';
  else
    projection:=atlas_core.school_catering_family_projection('2026-11-02',
      'b6500000-0000-0000-0000-000000000002',ingredient,'b6500000-0000-0000-0000-000000000005');
    contract:='SCHOOL-CATERING-PROCUREMENT.v1';reason:='SCHOOL_CATERING_SUPPLIER_ALLOCATION_SAVED';
  end if;
  family:=jsonb_build_object('service_date','2026-11-02',
    'delivery_location_id','b6500000-0000-0000-0000-000000000002','ingredient_id',ingredient,
    'unit_id','b6500000-0000-0000-0000-000000000005',
    'expected_source_fingerprint',projection->>'source_fingerprint');
  if source_kind='CONFIRMED_NEED' then
    family:=family||jsonb_build_object('expected_source_batch_id',projection->>'source_confirmed_need_batch_id',
      'expected_source_batch_version',(projection->>'source_confirmed_need_batch_version')::bigint);
  end if;
  select f.version into version from atlas_procurement.school_catering_allocation_families f
    where f.service_date='2026-11-02' and f.ingredient_id=ingredient;
  splits:=jsonb_build_array(jsonb_build_object('supplier_id','c7100000-0000-4000-8000-000000000001',
    'allocated_quantity',qa));
  if qb is not null then splits:=splits||jsonb_build_array(jsonb_build_object(
    'supplier_id','c7100000-0000-4000-8000-000000000002','allocated_quantity',qb)); end if;
  return pg_temp.command(contract,reason,coalesce(version,0),jsonb_build_object('family',family,'splits',splits));
end;
$$;

create function pg_temp.allocation_facts() returns jsonb language sql stable set search_path='' as $$
  select jsonb_build_array(
    (select jsonb_agg(to_jsonb(f) order by family_id) from atlas_procurement.school_catering_allocation_families f),
    (select jsonb_agg(to_jsonb(r) order by family_revision_id) from atlas_procurement.school_catering_allocation_family_revisions r),
    (select jsonb_agg(to_jsonb(c) order by to_jsonb(c)::text) from atlas_procurement.school_catering_allocation_family_contributions c),
    (select jsonb_agg(to_jsonb(s) order by supplier_split_id) from atlas_procurement.school_catering_allocation_supplier_splits s));
$$;
create function pg_temp.retry_failure() returns trigger language plpgsql as $$
begin raise exception using errcode='40001',message='02B disposable retry failure'; end;
$$;
create function pg_temp.probe(source_kind text,variant text,qa text,qb text) returns jsonb
language plpgsql set search_path='' as $$
declare request jsonb;answer jsonb;replay jsonb;conflict jsonb;evidence jsonb;
  before_facts jsonb;accepted_facts jsonb;prior_id uuid;prior_splits jsonb;new_id uuid;
  receipt_count bigint;
begin
  request:=pg_temp.allocation_request(source_kind,'b6500000-0000-0000-0000-000000000006',qa,qb);
  if variant='duplicate' then request:=jsonb_set(request,'{payload,splits,1,supplier_id}',request#>'{payload,splits,0,supplier_id}');
  elsif variant='source' then request:=jsonb_set(request,'{payload,family,expected_source_fingerprint}','"stale"');
  elsif variant='version' then request:=jsonb_set(request,'{expected_version}','999');
  elsif variant='batch_version' then request:=jsonb_set(request,'{payload,family,expected_source_batch_version}','999');
  elsif variant='inactive' then update atlas_admin.suppliers set supplier_status='INACTIVE'
    where supplier_id='c7100000-0000-4000-8000-000000000001';
  elsif variant='ineligible' then update atlas_admin.supplier_eligibilities set eligibility_status='INACTIVE'
    where supplier_id='c7100000-0000-4000-8000-000000000001';
  elsif variant='retry' then
    create trigger atlas_02b_retry before insert on atlas_procurement.school_catering_allocation_supplier_splits
      for each row execute function pg_temp.retry_failure();
  elsif variant like 'note_%' then
    request:=jsonb_set(request,'{payload,splits,0,supplier_note}',to_jsonb(case variant
      when 'note_trim' then E' \tGiao trước 5h\n ' when 'note_blank' then E' \t\n '
      when 'note_500' then repeat('x',500) else repeat('x',501) end));
  end if;
  before_facts:=pg_temp.allocation_facts();
  select r.family_revision_id into prior_id from atlas_procurement.school_catering_allocation_family_revisions r
    join atlas_procurement.school_catering_allocation_families f using(family_id)
    where r.is_current and f.ingredient_id='b6500000-0000-0000-0000-000000000006';
  select jsonb_agg(to_jsonb(s) order by supplier_split_id) into prior_splits
    from atlas_procurement.school_catering_allocation_supplier_splits s where family_revision_id=prior_id;
  answer:=pg_temp.invoke(case source_kind when 'CONFIRMED_NEED' then 'save_confirmed_supplier_allocation'
    else 'save_school_catering_supplier_allocation' end,request);
  set constraints all immediate;
  accepted_facts:=pg_temp.allocation_facts();
  replay:=pg_temp.invoke(case source_kind when 'CONFIRMED_NEED' then 'save_confirmed_supplier_allocation'
    else 'save_school_catering_supplier_allocation' end,request);
  select count(*) into receipt_count from atlas_core.command_receipts
    where command_id=(request->>'command_id')::uuid;
  conflict:=pg_temp.invoke(case source_kind when 'CONFIRMED_NEED' then 'save_confirmed_supplier_allocation'
    else 'save_school_catering_supplier_allocation' end,
    jsonb_set(request,'{payload,splits,0,allocated_quantity}','"2.000000"'));
  new_id:=nullif(answer#>>'{family,family_revision_id}','')::uuid;
  evidence:=jsonb_build_object('response',answer,'replay',replay,'conflict',conflict,
    'facts_unchanged',before_facts=pg_temp.allocation_facts(),
    'replay_facts_unchanged',accepted_facts=pg_temp.allocation_facts(),
    'predecessor_unchanged',prior_splits is not distinct from (select jsonb_agg(to_jsonb(s) order by supplier_split_id)
      from atlas_procurement.school_catering_allocation_supplier_splits s where family_revision_id=prior_id),
    'predecessor_id',(select predecessor_revision_id from atlas_procurement.school_catering_allocation_family_revisions where family_revision_id=new_id),
    'prior_id',prior_id,
    'stored',(select jsonb_agg(jsonb_build_object('quantity',allocated_quantity::text,'ratio',split_ratio::text,'note',supplier_note) order by supplier_id)
      from atlas_procurement.school_catering_allocation_supplier_splits where family_revision_id=new_id),
    'source_kind',(select r.source_kind from atlas_procurement.school_catering_allocation_family_revisions r where family_revision_id=new_id),
    'receipts',receipt_count,
    'events',(select count(*) from atlas_audit.domain_events where command_id=(request->>'command_id')::uuid),
    'audits',(select count(*) from atlas_audit.audit_events where command_id=(request->>'command_id')::uuid));
  raise exception using errcode='P2B01';
exception when sqlstate 'P2B01' then return evidence;
end;
$$;

create temporary table results(source_kind text,variant text,expected text,evidence jsonb);
create temporary table cases(variant text,qa text,qb text,expected text);
insert into cases values
  ('exact','1.000000','99.000000','ACCEPT'),
  ('precision_one','1.0000004','98.9999996','INVALID_SPLIT_PRECISION'),
  ('precision_rounded_total','1.0000004','99.000000','INVALID_SPLIT_PRECISION'),
  ('precision_tiny','0.0000004','99.9999996','INVALID_SPLIT_PRECISION'),
  ('precision_72','72.1234567','27.8765433','INVALID_SPLIT_PRECISION'),
  ('range_limit','100000000000000',null,'INVALID_SPLIT_PRECISION'),
  ('range_max','99999999999999.999999',null,'ALLOCATION_IMBALANCED'),
  ('zero','0','100','NON_POSITIVE_SPLIT'),('negative','-1','101','NON_POSITIVE_SPLIT'),
  ('duplicate','1','99','DUPLICATE_SUPPLIER'),('inactive','1','99','SUPPLIER_INACTIVE'),
  ('ineligible','1','99','SUPPLIER_INELIGIBLE'),('imbalance','1','98.999999','ALLOCATION_IMBALANCED'),
  ('residual','1.123456','98.876544','ACCEPT'),('note_trim','1','99','ACCEPT'),
  ('note_blank','1','99','ACCEPT'),('note_500','1','99','ACCEPT'),
  ('note_501','1','99','SUPPLIER_NOTE_INVALID'),('source','1','99','SOURCE_CHANGED'),
  ('version','1','99','STALE_VERSION'),('retry','1','99','RETRYABLE_CONCURRENCY_FAILURE');

-- Start both route matrices with a real predecessor, so note-only checks cannot
-- accidentally compare two NULL predecessor identities on initial creation.
select is(pg_temp.invoke('save_confirmed_supplier_allocation',pg_temp.allocation_request('CONFIRMED_NEED',
  'b6500000-0000-0000-0000-000000000006','1','99'))->>'success','true','save current exact rice allocation');
insert into results select 'CONFIRMED_NEED',variant,expected,pg_temp.probe('CONFIRMED_NEED',variant,qa,qb) from cases;
insert into results values('CONFIRMED_NEED','batch_version','SOURCE_CHANGED',pg_temp.probe('CONFIRMED_NEED','batch_version','1','99'));
-- Accept the other family through its real command, then atomically prepare.
select is(pg_temp.invoke('save_confirmed_supplier_allocation',pg_temp.allocation_request('CONFIRMED_NEED',
  'b6500000-0000-0000-0000-000000000007','3',null))->>'success','true','save other positive family');
select is(pg_temp.invoke('prepare_school_catering_purchase_orders',pg_temp.command('PURCHASE-COMMITMENT.v1',
  'PURCHASE_ORDERS_PREPARED',b.version,'{"confirmed_need_batch_id":"b6500000-0000-0000-0000-000000000050","service_date":"2026-11-02"}'))->>'success',
  'true','complete preparation creates real Handoff and promotes exact allocations')
from atlas_planning.confirmed_need_batches b where confirmed_need_batch_id='b6500000-0000-0000-0000-000000000050';
insert into results select 'PURCHASE_HANDOFF',variant,expected,pg_temp.probe('PURCHASE_HANDOFF',variant,qa,qb) from cases;

select diag(source_kind||' '||variant||': '||evidence::text) from results
where coalesce(evidence#>>'{response,error_code}','ACCEPT')<>expected;
select is(case when evidence#>>'{response,success}'='true' then 'ACCEPT'
  else evidence#>>'{response,error_code}' end,expected,source_kind||' complete command: '||variant) from results;
select ok((evidence->>'facts_unchanged')::boolean,source_kind||' denied command changes no allocation facts: '||variant)
from results where expected<>'ACCEPT';
select is(evidence->'replay',evidence->'response',source_kind||' exact replay retains original response: '||variant)
from results where variant<>'retry';
select is(evidence#>>'{conflict,error_code}','IDEMPOTENCY_CONFLICT',source_kind||' conflicting replay cannot overwrite: '||variant)
from results where variant<>'retry';
select is((evidence->>'events')::int,case expected when 'ACCEPT' then 1 else 0 end,
  source_kind||' one success event / no failure event: '||variant) from results;
select is((evidence->>'audits')::int,case expected when 'ACCEPT' then 1 else 0 end,
  source_kind||' one success audit / no failure audit: '||variant) from results;
select is((evidence->>'receipts')::int,case variant when 'retry' then 0 else 1 end,
  source_kind||' original receipt certainty: '||variant) from results;
select ok((evidence->>'predecessor_unchanged')::boolean,source_kind||' predecessor split history preserved: '||variant) from results;
select ok((evidence->>'replay_facts_unchanged')::boolean,source_kind||' replay and conflict change no accepted facts: '||variant) from results;
select is(evidence->>'source_kind',source_kind,source_kind||' accepted revision retains source authority: '||variant)
from results where expected='ACCEPT';
select is(evidence#>>'{stored,0,note}','Giao trước 5h',source_kind||' supplier note trimmed') from results where variant='note_trim';
select is(evidence#>>'{stored,0,note}',null::text,source_kind||' blank supplier note is NULL') from results where variant='note_blank';
select is(length(evidence#>>'{stored,0,note}'),500,source_kind||' exactly 500 note characters preserved') from results where variant='note_500';
select is(evidence->>'predecessor_id',evidence->>'prior_id',source_kind||' note-only Save appends successor')
from results where variant='note_trim';
select ok(evidence->>'prior_id' is not null,source_kind||' note-only predecessor exists') from results where variant='note_trim';
select is(evidence#>>'{stored,0,ratio}','0.010000000000',source_kind||' note-only split ratio remains exact') from results where variant='note_trim';
select is(evidence#>>'{stored,0,quantity}','1.000000',source_kind||' note-only split quantity remains exact') from results where variant='note_trim';
select is((select sum((s->>'quantity')::numeric) from jsonb_array_elements(evidence->'stored') s),
  100::numeric,source_kind||' accepted quantities reconcile exactly: '||variant)
from results where expected='ACCEPT';
select is(evidence#>>'{stored,0,quantity}','1.000000',source_kind||' six-decimal exact entry preserved')
from results where variant='exact';
select is(evidence#>>'{stored,0,quantity}','1.123456',source_kind||' exact residual entry preserved')
from results where variant='residual';
select is(evidence#>>'{response,retryable}','true',source_kind||' retry failure preserves certainty')
from results where variant='retry';
select * from finish();
rollback;
