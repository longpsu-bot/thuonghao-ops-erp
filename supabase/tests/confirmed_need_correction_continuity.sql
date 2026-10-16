begin;
create extension if not exists pgtap with schema extensions;
set search_path=extensions,public,pg_catalog;
select plan(137);
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
-- These compare captured public-history identities, not a copied projector loop.
do $resolved_projection_probe$
declare target record;current_facts jsonb;historical_facts jsonb;resolved_facts jsonb;
 missing_error text;wrong_error text;
begin
 if to_regprocedure('atlas_core.rmvp_07_validated_facts_projection(uuid,uuid,jsonb)')is null then return;end if;
 select * into strict target from c_selected;
 current_facts:=atlas_core.rmvp_07_validated_facts_projection(target.confirmed_need_batch_id);
 resolved_facts:=atlas_core.rmvp_07_validated_facts_projection(target.confirmed_need_batch_id,null::uuid,
 atlas_core.rmvp_06_canonical_evaluation(target.confirmed_need_batch_id));
 historical_facts:=atlas_core.rmvp_07_validated_facts_projection(target.confirmed_need_batch_id,target.attempt_id);
 insert into c_context values('resolved-projection',jsonb_build_object(
 'current_exact',current_facts=resolved_facts,
 'current_cardinality',jsonb_array_length(resolved_facts->'ordered_lines'),
 'captured_members',(select count(*)from jsonb_array_elements(resolved_facts->'ordered_lines')item
 join c_original old on item->>'confirmed_need_line_id'=old.confirmed_need_line_id::text
 and item->>'current_confirmed_need_line_revision_id'=old.revision_id::text
 and item->>'current_confirmed_need_line_decision_id'=old.decision_id::text
 and(item->>'confirmed_quantity')::numeric=old.confirmed_quantity),
 'historical_exact',historical_facts=atlas_core.rmvp_07_validated_facts_projection(
 target.confirmed_need_batch_id,target.attempt_id,'{"outcome":"BLOCKED","ordered_lines":[]}'::jsonb),
 'historical_fingerprint',atlas_core.rmvp_07_validated_facts_fingerprint(historical_facts)=
 atlas_core.rmvp_07_validated_facts_fingerprint(atlas_core.rmvp_07_validated_facts_projection(
 target.confirmed_need_batch_id,target.attempt_id,'{}'::jsonb))));
 begin perform atlas_core.rmvp_07_validated_facts_projection(target.confirmed_need_batch_id,gen_random_uuid(),'{}'::jsonb);
 exception when sqlstate '22023'then missing_error:=sqlstate;end;
 begin perform atlas_core.rmvp_07_validated_facts_projection((select confirmed_need_batch_id
 from atlas_planning.confirmed_need_batches where period_start='2026-11-03'and period_end=period_start),target.attempt_id,'{}'::jsonb);
 exception when sqlstate '22023'then wrong_error:=sqlstate;end;
 insert into c_context values('resolved-projection-errors',jsonb_build_object('missing',missing_error,'wrong_batch',wrong_error));
end;$resolved_projection_probe$;

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
declare context jsonb;original jsonb;middle jsonb;last_edge jsonb;result jsonb;mutation jsonb;
 family_key text;original_id text;original_key text;groups jsonb;members jsonb;foreign_members jsonb;null_error text;
 family_revision uuid:=(select family_revision_id from c_retained_families order by family_id limit 1);
begin
 context:=atlas_core.purchase_review_continuity_context((select confirmed_need_batch_id from c_selected));
 insert into c_context values('original-continuity-context',context);
 if not context?'handoff_members'then
  insert into c_context select name,'{}'from unnest(array['ambiguous-source','missing-member',
   'changed-decision','changed-school','predecessor-gap','predecessor-cycle','changed-then-reverted',
   'missing-group','empty-group','duplicate-member','locator-swap','foreign-only','foreign-filter','null-group'])name;
  return;
 end if;
 insert into c_context values('ambiguous-source',pg_temp.c_resolved_proof(family_revision,
  jsonb_set(context,'{sources}',(context->'sources')||(context->'sources'))));
 select h into original from jsonb_array_elements(context->'handoffs')h
 where h->>'is_current'='true'order by h->>'purchase_handoff_revision_id'limit 1;
 select jsonb_build_array(f.service_date::text,f.delivery_location_id::text,f.ingredient_id::text,f.unit_id::text)::text
 into family_key from c_retained_families f where f.family_revision_id=family_revision;
 original_id:=original->>'purchase_handoff_revision_id';original_key:=original->>'member_group_key';
 groups:=context#>array['handoff_members',original_id,original_key];members:=groups->family_key;
 -- Only consumed raw evidence is changed; no ignored legacy membership.members.
 insert into c_context values('missing-member',pg_temp.c_resolved_proof(family_revision,
  jsonb_set(context,array['handoff_members',original_id,original_key,family_key],members-0)));
 select jsonb_agg(jsonb_set(m,'{current_confirmed_need_line_decision_id}',to_jsonb(gen_random_uuid()))order by ordinality)
 into result from jsonb_array_elements(members)with ordinality item(m,ordinality);
 insert into c_context values('changed-decision',pg_temp.c_resolved_proof(family_revision,
  jsonb_set(context,array['handoff_members',original_id,original_key,family_key],result)));
 select jsonb_agg(jsonb_set(m,'{school_id}',to_jsonb(gen_random_uuid()))order by ordinality)
 into result from jsonb_array_elements(members)with ordinality item(m,ordinality);
 insert into c_context values('changed-school',pg_temp.c_resolved_proof(family_revision,
  jsonb_set(context,array['handoff_members',original_id,original_key,family_key],result)));
 middle:=original||jsonb_build_object('purchase_handoff_revision_id',gen_random_uuid(),
  'predecessor_revision_id',original->'purchase_handoff_revision_id','revision_number',
  (original->>'revision_number')::integer+2,'member_group_key','gap');
 mutation:=jsonb_set(context,'{handoff_members}',(context->'handoff_members')||jsonb_build_object(
  middle->>'purchase_handoff_revision_id',jsonb_build_object('gap',groups)));
 insert into c_context values('predecessor-gap',pg_temp.c_resolved_proof(family_revision,
  jsonb_set(mutation,'{handoffs}',jsonb_build_array(original,middle))));
 middle:=middle||jsonb_build_object('predecessor_revision_id',middle->'purchase_handoff_revision_id');
 insert into c_context values('predecessor-cycle',pg_temp.c_resolved_proof(family_revision,
  jsonb_set(mutation,'{handoffs}',jsonb_build_array(original,middle))));
 middle:=original||jsonb_build_object('purchase_handoff_revision_id',gen_random_uuid(),
  'predecessor_revision_id',original->'purchase_handoff_revision_id','revision_number',
  (original->>'revision_number')::integer+1,'member_group_key','changed-middle');
 last_edge:=original||jsonb_build_object('purchase_handoff_revision_id',gen_random_uuid(),
  'predecessor_revision_id',middle->'purchase_handoff_revision_id','revision_number',
  (original->>'revision_number')::integer+2,'member_group_key','reverted-last');
 mutation:=jsonb_set(context,'{handoffs}',jsonb_build_array(original,middle,last_edge));
 mutation:=jsonb_set(mutation,'{handoff_members}',(context->'handoff_members')||jsonb_build_object(
  middle->>'purchase_handoff_revision_id',jsonb_build_object('changed-middle',jsonb_set(groups,array[family_key],result)),
  last_edge->>'purchase_handoff_revision_id',jsonb_build_object('reverted-last',groups)));
 insert into c_context values('changed-then-reverted',pg_temp.c_resolved_proof(family_revision,mutation));
 insert into c_context values('locator-swap',pg_temp.c_resolved_proof(family_revision,
  jsonb_set(mutation,'{handoffs}',jsonb_build_array(original,
   middle||jsonb_build_object('member_group_key','reverted-last'),last_edge))));
 insert into c_context values('missing-group',pg_temp.c_resolved_proof(family_revision,
  context#-array['handoff_members',original_id,original_key,family_key]));
 insert into c_context values('empty-group',pg_temp.c_resolved_proof(family_revision,
  jsonb_set(context,array['handoff_members',original_id,original_key,family_key],'[]'::jsonb)));
 insert into c_context values('duplicate-member',pg_temp.c_resolved_proof(family_revision,
  jsonb_set(context,array['handoff_members',original_id,original_key,family_key],members||members)));
 begin perform pg_temp.c_resolved_proof(family_revision,
  jsonb_set(context,array['handoff_members',original_id,original_key,family_key],'null'::jsonb));
 exception when sqlstate '22023'then null_error:=sqlstate;end;
 insert into c_context values('null-group',jsonb_build_object('sqlstate',null_error));
 select jsonb_agg(jsonb_set(m,'{delivery_location_id}','null'::jsonb)order by ordinality)
 into foreign_members from jsonb_array_elements(members)with ordinality item(m,ordinality);
 insert into c_context values('foreign-only',pg_temp.c_resolved_proof(family_revision,
  jsonb_set(context,array['handoff_members',original_id,original_key,family_key],foreign_members)));
 insert into c_context values('foreign-filter',jsonb_build_object('exact',pg_temp.c_resolved_proof(family_revision,
  jsonb_set(context,array['handoff_members',original_id,original_key,family_key],members||foreign_members))
  =pg_temp.c_resolved_proof(family_revision,context)));
end;$edge_contexts$;
-- Real public Handoff history is the old flat-filter oracle, not a copied producer.
do $raw_group_parity$
declare context jsonb;h jsonb;flat jsonb;g jsonb;expected jsonb;actual jsonb;key_row record;
 expected_facts jsonb;actual_facts jsonb;raw_ok boolean:=true;facts_ok boolean:=true;ids_ok boolean:=true;
 thin_ok boolean:=true;count_members integer:=0;school_count integer;group_count integer:=0;flat_count integer:=0;
begin
 select value into context from c_context where name='original-continuity-context';
 if not context?'handoff_members'then return;end if;
 for h in select value from jsonb_array_elements(context->'handoffs')loop
  flat:=atlas_core.confirmed_need_handoff_membership((h->>'purchase_handoff_revision_id')::uuid);
  thin_ok:=thin_ok and not(h->'membership'?'members')and h->'membership'=flat-'members';
  g:=context#>array['handoff_members',h->>'purchase_handoff_revision_id',h->>'member_group_key'];
  flat_count:=flat_count+jsonb_array_length(flat->'members');
  select count(*)into count_members from jsonb_each(g)bucket cross join lateral jsonb_array_elements(bucket.value)m;
  group_count:=group_count+count_members;
  for key_row in select distinct m->>'service_date' service_date,m->>'delivery_location_id' location,
   m->>'ingredient_id' ingredient,m->>'controlled_unit_id' unit
   from jsonb_array_elements(flat->'members')m loop
   select jsonb_agg(m order by ordinality)into expected
   from jsonb_array_elements(flat->'members')with ordinality item(m,ordinality)
   where m->>'service_date'=key_row.service_date and m->>'delivery_location_id'=key_row.location
    and m->>'ingredient_id'=key_row.ingredient and m->>'controlled_unit_id'=key_row.unit;
   select jsonb_agg(m order by ordinality)into actual from jsonb_array_elements(g->
    jsonb_build_array(key_row.service_date,key_row.location,key_row.ingredient,key_row.unit)::text)
    with ordinality item(m,ordinality)
   where m->>'service_date'=key_row.service_date and m->>'delivery_location_id'=key_row.location
    and m->>'ingredient_id'=key_row.ingredient and m->>'controlled_unit_id'=key_row.unit;
   raw_ok:=raw_ok and expected is not distinct from actual;
   select jsonb_agg(m-array['line_sort_position','purchase_handoff_line_revision_id',
    'purchase_handoff_revision_id','source_confirmed_need_batch_id','confirmed_need_snapshot_line_id',
    'validation_attempt_id']order by m->>'confirmed_need_line_id')into expected_facts from jsonb_array_elements(expected)m;
   select jsonb_agg(m-array['line_sort_position','purchase_handoff_line_revision_id',
    'purchase_handoff_revision_id','source_confirmed_need_batch_id','confirmed_need_snapshot_line_id',
    'validation_attempt_id']order by m->>'confirmed_need_line_id')into actual_facts from jsonb_array_elements(actual)m;
   facts_ok:=facts_ok and expected_facts is not distinct from actual_facts
    and sha256(convert_to(expected_facts::text,'UTF8'))=sha256(convert_to(actual_facts::text,'UTF8'));
   ids_ok:=ids_ok and(select jsonb_agg(jsonb_build_array(m->>'purchase_handoff_line_revision_id',m->>'confirmed_quantity')
    order by m->>'purchase_handoff_line_revision_id')from jsonb_array_elements(expected)m)
    is not distinct from(select jsonb_agg(jsonb_build_array(m->>'purchase_handoff_line_revision_id',m->>'confirmed_quantity')
    order by m->>'purchase_handoff_line_revision_id')from jsonb_array_elements(actual)m);
  end loop;
 end loop;
 select count(distinct m->>'school_id')into school_count from jsonb_each(context->'handoff_members')hr
 cross join lateral jsonb_each(hr.value)entry cross join lateral jsonb_each(entry.value)bucket
 cross join lateral jsonb_array_elements(bucket.value)m;
 insert into c_context values('raw-group-parity',jsonb_build_object('raw',raw_ok,'facts_hash',facts_ok,'ph_ids_qty',ids_ok,
 'thin',thin_ok,'flat_count',flat_count,'group_count',group_count,'schools',school_count));
end;$raw_group_parity$;
select is((select value->>'thin'from c_context where name='raw-group-parity'),'true','thin metadata preserves complete membership without a second ignored raw array');
select is((select value->>'raw'from c_context where name='raw-group-parity'),'true','each genuine whole-family ordered raw group equals the old four-field filter');
select is((select value->>'facts_hash'from c_context where name='raw-group-parity'),'true','per-family normalized facts and exact hashes survive raw grouping');
select is((select value->>'ph_ids_qty'from c_context where name='raw-group-parity'),'true','raw PH line identities and exact quantity strings remain equal');
select ok((select value->>'flat_count'='4'and value->>'group_count'='4'from c_context where name='raw-group-parity'),'all four genuine historical members occur exactly once across groups');
select is((select value->>'schools'from c_context where name='raw-group-parity'),'2','grouping preserves both real Schools without clipping a shared family');
select is((select value->>'applicable'from c_context where name='missing-group'),'false','missing raw group is unavailable, never an empty authoritative family');
select is((select value->>'applicable'from c_context where name='empty-group'),'false','empty raw group cannot prove retained positive contributions');
select is((select value->>'sqlstate'from c_context where name='null-group'),'22023','JSON null retains invalid scalar-array error rather than becoming accepted evidence');
select is((select value->>'applicable'from c_context where name='duplicate-member'),'false','duplicate raw members retain multiplicity and cannot match exact original PH quantity set');
select is((select value->>'applicable'from c_context where name='locator-swap'),'false','changed middle cannot point to another PH identity reverted raw group');
select is((select value->>'applicable'from c_context where name='foreign-only'),'false','NULL family field in a misplaced bucket cannot authorize the selected family');
select is((select value->>'exact'from c_context where name='foreign-filter'),'true','original family filters ignore foreign NULL-field members while preserving exact original proof');
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

do $pending_phase_probe$
declare proof jsonb;
begin
 if to_regprocedure('atlas_core.purchase_review_official_continuity_map(date,date)')is null then return;end if;
 proof:=atlas_core.purchase_review_official_continuity_map(date '2026-11-02',date '2026-11-03');
 insert into c_context values('phase-pending-evidence',jsonb_build_object(
 'keys_exact',(select jsonb_agg(key order by key)from jsonb_each(proof))=
 (select jsonb_agg(family_revision_id::text order by family_revision_id::text)from c_retained_families),
 'count',(select count(*)from jsonb_each(proof)where value->>'classification'='CORRECTION_PENDING'
 and value->>'applicable'='false')));
end;$pending_phase_probe$;

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
select is((select array_agg(actor_role||':'||p.proname||':'||p.pronargs order by actor_role,p.proname,p.pronargs)from pg_proc p cross join unnest(array['atlas_read_runtime',
 'atlas_need_generation_runtime','atlas_confirmed_need_review_runtime',
 'atlas_planning_command_runtime','atlas_dispatch_command_runtime'])actor_role
 where p.oid in(to_regprocedure('atlas_core.purchase_review_continuity_context(uuid)'),
 to_regprocedure('atlas_core.purchase_review_family_continuity(uuid,text)'),
 to_regprocedure('atlas_core.purchase_review_family_continuity(uuid,text,jsonb)'))
 and has_function_privilege(actor_role,p.oid,'EXECUTE')),array['atlas_read_runtime:purchase_review_continuity_context:1',
 'atlas_read_runtime:purchase_review_family_continuity:3']::text[],
 'only the exact approved Read context/resolved pair gains consumer EXECUTE; scalar and all other runtimes remain denied');

select is((select count(*)from unnest(array[
 'atlas_core.confirmed_need_historical_validation_complete(uuid,uuid)',
 'atlas_core.confirmed_need_retained_release_evidence(uuid)'])signature
 where has_function_privilege('atlas_procurement_command_runtime',signature,'EXECUTE')),0::bigint,
 'procurement gains no access to lifecycle-only proof predicates');
select is((select count(*)from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='atlas_api'),123::bigint,'only the two approved correction APIs extend the public catalog');

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

select is(atlas_core.purchase_review_correction_roots((select confirmed_need_batch_id from c_selected)),
 (select value-'sources'from c_context where name='root-context'),
 'pure roots retain the exact invalidated-Handoff batch/family/period/allocation closure');
select ok((select p.proowner='atlas_procurement_command_runtime'::regrole and p.prosecdef
 and p.provolatile='s'and p.proconfig @>array['search_path=""']
 and has_function_privilege('atlas_need_generation_runtime',p.oid,'EXECUTE')
 and not exists(select 1 from unnest(array['authenticated','anon','service_role','atlas_read_runtime',
 'atlas_confirmed_need_review_runtime','atlas_planning_command_runtime','atlas_dispatch_command_runtime'])principal
 where has_function_privilege(principal,p.oid,'EXECUTE'))
 and not exists(select 1 from aclexplode(p.proacl)acl where acl.grantee=0)
 from pg_proc p where p.oid='atlas_core.purchase_review_correction_roots(uuid)'::regprocedure),
 'pure root closure exposes only the exact Need runtime bridge with Procurement ownership');

-- Phase-local maps are private backend evidence, never a public trusted input.
select ok(coalesce((select p.proowner='atlas_procurement_command_runtime'::regrole and p.prosecdef
 and p.provolatile='s'and p.proconfig @>array['search_path=""']
 and has_function_privilege('atlas_read_runtime',p.oid,'EXECUTE')
 and not exists(select 1 from unnest(array['authenticated','anon','service_role',
 'atlas_confirmed_need_review_runtime','atlas_need_generation_runtime','atlas_planning_command_runtime',
 'atlas_dispatch_command_runtime'])principal where has_function_privilege(principal,p.oid,'EXECUTE'))
 and not exists(select 1 from aclexplode(p.proacl)a where a.grantee=0)
 from pg_proc p where p.oid=to_regprocedure('atlas_core.purchase_review_official_continuity_map(date,date)')),false),
 'phase map exposes only the exact Read bridge under Procurement ownership');
select ok(coalesce((select p.proowner='atlas_owner'::regrole and not p.prosecdef
 and p.provolatile='s'and p.proconfig @>array['search_path=""']
 and has_function_privilege('atlas_read_runtime',p.oid,'EXECUTE')
 and has_function_privilege('atlas_procurement_command_runtime',p.oid,'EXECUTE')
 and not exists(select 1 from unnest(array['authenticated','anon','service_role',
 'atlas_confirmed_need_review_runtime','atlas_need_generation_runtime','atlas_planning_command_runtime',
 'atlas_dispatch_command_runtime'])principal where has_function_privilege(principal,p.oid,'EXECUTE'))
 and not exists(select 1 from aclexplode(p.proacl)a where a.grantee=0)
 from pg_proc p where p.oid=to_regprocedure('atlas_core.school_catering_po_date_readiness(date,jsonb)')),false),
 'resolved readiness retains INVOKER ownership and exact Read plus Procurement execution');
select ok(coalesce((select p.proowner='atlas_procurement_command_runtime'::regrole and p.prosecdef
 and p.provolatile='s'and p.proconfig @>array['search_path=""']
 and not exists(select 1 from unnest(array['authenticated','anon','service_role','atlas_read_runtime',
 'atlas_confirmed_need_review_runtime','atlas_need_generation_runtime','atlas_planning_command_runtime',
 'atlas_dispatch_command_runtime'])principal where has_function_privilege(principal,p.oid,'EXECUTE'))
 and not exists(select 1 from aclexplode(p.proacl)a where a.grantee=0)
 from pg_proc p where p.oid=to_regprocedure('atlas_core.purchase_review_po_coverage(date,jsonb)')),false),
 'resolved coverage is callable only by its Procurement owner');
do $phase_probe$
declare start_date date;end_date date;proof jsonb;daily jsonb;answer jsonb;
begin
 if to_regprocedure('atlas_core.purchase_review_official_continuity_map(date,date)')is null
 or to_regprocedure('atlas_core.school_catering_po_date_readiness(date,jsonb)')is null
 or to_regprocedure('atlas_core.purchase_review_po_coverage(date,jsonb)')is null then return;end if;
 select min(service_date),max(service_date)into start_date,end_date from atlas_planning.confirmed_need_line_revisions
 where is_current and confirmed_need_batch_id in(select confirmed_need_batch_id from c_selected);
 -- Include the genuine second day, even when the selected batch is a daily batch.
 end_date:=start_date+1;
 proof:=atlas_core.purchase_review_official_continuity_map(start_date,end_date);
 select coalesce(jsonb_object_agg(item.key,item.value),'{}'::jsonb)into daily
 from generate_series(start_date,end_date,interval '1 day')day
 cross join lateral jsonb_each(atlas_core.purchase_review_official_continuity_map(day::date,day::date))item;
 answer:=jsonb_build_object('range_exact',proof=daily,
 'readiness_exact',atlas_core.school_catering_po_date_readiness(start_date)
 =atlas_core.school_catering_po_date_readiness(start_date,proof),
 'coverage_exact',atlas_core.purchase_review_po_coverage(start_date)
 is not distinct from atlas_core.purchase_review_po_coverage(start_date,proof),
 'empty',atlas_core.purchase_review_official_continuity_map(date '2040-01-01',date '2040-01-01')='{}'::jsonb,
 'null',atlas_core.purchase_review_official_continuity_map(null,null)='{}'::jsonb,
 'reversed',atlas_core.purchase_review_official_continuity_map(end_date,start_date)='{}'::jsonb,
 'pending_keys_exact',(select value->'keys_exact'from c_context where name='phase-pending-evidence'),
 'pending_count',(select value->'count'from c_context where name='phase-pending-evidence'),
 'other_day_ready',atlas_core.school_catering_po_date_readiness(end_date)->'ready',
 'other_day_families',atlas_core.school_catering_po_date_readiness(end_date)->'family_count',
 'pending_coverage',atlas_core.purchase_review_po_coverage(start_date),
 'other_day_coverage',atlas_core.purchase_review_po_coverage(end_date));
 insert into c_context values('phase-local-proofs',answer);
end;$phase_probe$;
select is((select value->>'range_exact'from c_context where name='phase-local-proofs'),'true',
 'complete multiday phase map equals the union of exact per-day revision-keyed maps');
select is((select value->>'readiness_exact'from c_context where name='phase-local-proofs'),'true',
 'pending full-universe readiness matches its fresh wrapper with the same backend range map');
select is((select value->>'coverage_exact'from c_context where name='phase-local-proofs'),'true',
 'fresh PO coverage matches its resolved entry while querying current PO facts');
select is((select value->>'empty'from c_context where name='phase-local-proofs'),'true',
 'empty source date has no fabricated applicability proof');
select is((select value->>'null'from c_context where name='phase-local-proofs'),'true',
 'NULL private date bounds have no applicability evidence');
select is((select value->>'reversed'from c_context where name='phase-local-proofs'),'true',
 'reversed private date bounds do not manufacture family proof');

select is((select value->>'pending_keys_exact'from c_context where name='phase-local-proofs'),'true',
 'first correction map names exactly the two retained Nov2 PH revision identities');
select is((select value->>'pending_count'from c_context where name='phase-local-proofs'),'2',
 'both known Nov2 families remain pending and false, never zero or silently omitted');
select ok((select value->>'other_day_ready'='true'and value->>'other_day_families'='2'
 from c_context where name='phase-local-proofs'),
 'genuine released Nov3 remains ready with exactly two raw-current whole families');
select ok((select value->>'pending_coverage'='false'and value->>'other_day_coverage'='true'
 from c_context where name='phase-local-proofs'),
 'pending Nov2 has no exact coverage while unchanged released Nov3 retains exact coverage');

select ok(coalesce((select p.proowner='atlas_confirmed_need_review_runtime'::regrole and not p.prosecdef
 and p.provolatile='s'and p.proconfig @>array['search_path=""']and p.pronargdefaults=0
 and(select pronargdefaults=1 from pg_proc where oid='atlas_core.rmvp_07_validated_facts_projection(uuid,uuid)'::regprocedure)
 and not exists(select 1 from pg_roles role where role.rolname like 'atlas\_%'escape '\'
 and role.rolname<>'atlas_confirmed_need_review_runtime'and has_function_privilege(role.rolname,p.oid,'EXECUTE'))
 and not exists(select 1 from unnest(array['authenticated','anon','service_role'])principal
 where has_function_privilege(principal,p.oid,'EXECUTE'))
 and not exists(select 1 from aclexplode(p.proacl)a where a.grantee=0)
 from pg_proc p where p.oid=to_regprocedure('atlas_core.rmvp_07_validated_facts_projection(uuid,uuid,jsonb)')),false),
 'shared projection has no default or peer execution while old one-argument entry stays unambiguous');
select is((select value->>'current_exact'from c_context where name='resolved-projection'),'true',
 'fresh one-argument projection equals same-statement backend canonical projection');
select ok((select value->>'captured_members'='4'and value->>'current_cardinality'='4'
 from c_context where name='resolved-projection'),
 'shared current projection retains all four captured exact School R/D quantities');
select is((select value->>'historical_exact'from c_context where name='resolved-projection'),'true',
 'nonNULL historical attempt ignores supplied blocked empty current evidence');
select is((select value->>'historical_fingerprint'from c_context where name='resolved-projection'),'true',
 'historical projection fingerprint stays exact when an unrelated evaluation is supplied');
select is((select value->>'missing'from c_context where name='resolved-projection-errors'),'22023',
 'shared historical projector preserves unavailable-attempt error');
select is((select value->>'wrong_batch'from c_context where name='resolved-projection-errors'),'22023',
 'shared historical projector cannot borrow another batch attempt');

select ok(coalesce((select p.proowner='atlas_read_runtime'::regrole and p.prosecdef
 and p.provolatile='s'and p.proconfig @>array['search_path=""']and p.pronargdefaults=0
 and not exists(select 1 from pg_roles role where role.rolname like 'atlas\_%'escape '\'
 and role.rolname<>'atlas_read_runtime'and has_function_privilege(role.rolname,p.oid,'EXECUTE'))
 and not exists(select 1 from unnest(array['authenticated','anon','service_role'])principal
 where has_function_privilege(principal,p.oid,'EXECUTE'))
 and not exists(select 1 from aclexplode(p.proacl)a where a.grantee=0)
 from pg_proc p where p.oid=to_regprocedure('atlas_core.school_catering_procurement_date_current(date,jsonb)')),false),
 'resolved official date has no default and only Read-owner execution');
do $resolved_date_cases$
begin
 if to_regprocedure('atlas_core.school_catering_procurement_date_current(date,jsonb)')is null then return;end if;
 insert into c_context values('resolved-date-cases',jsonb_build_object(
 'pending',atlas_core.school_catering_procurement_date_current(date '2026-11-02',
 atlas_core.purchase_review_official_continuity_map(date '2026-11-02',date '2026-11-03')),
 'other_day',atlas_core.school_catering_procurement_date_current(date '2026-11-03',
 atlas_core.purchase_review_official_continuity_map(date '2026-11-02',date '2026-11-03'))));
end;$resolved_date_cases$;
select is((select value->>'pending'from c_context where name='resolved-date-cases'),'false',
 'pending Nov2 cannot become official through a full multiday map');
select is((select value->>'other_day'from c_context where name='resolved-date-cases'),'true',
 'same full multiday map preserves genuine current Nov3 without cross-day contamination');


-- Exercise the stored algorithm on disposable rowsets; no production predicate is copied.
create temporary table hp_target as select * from c_selected;
do $hp_setup$
declare relation text; definition text;
begin
 foreach relation in array array['confirmed_need_validation_attempts','confirmed_need_validation_lines',
 'confirmed_need_validation_issues','confirmed_need_lines','confirmed_need_line_revisions',
 'confirmed_need_line_decisions','planning_quantity_policy_revisions','confirmed_need_line_revision_contributions'] loop
  execute format('create temporary table hp_%I as select * from atlas_planning.%I',relation,relation);
 end loop;
 definition:=pg_get_functiondef('atlas_core.confirmed_need_historical_validation_complete(uuid,uuid)'::regprocedure);
 definition:=replace(definition,'atlas_core.confirmed_need_historical_validation_complete(',
 'pg_temp.hp_historical_complete(');
 foreach relation in array array['confirmed_need_validation_attempts','confirmed_need_validation_lines',
 'confirmed_need_validation_issues','confirmed_need_lines','confirmed_need_line_revisions',
 'confirmed_need_line_decisions','planning_quantity_policy_revisions','confirmed_need_line_revision_contributions'] loop
  definition:=replace(definition,'atlas_planning.'||relation,'pg_temp.hp_'||relation);
 end loop;
 execute definition;
end;$hp_setup$;
create temporary table hp_results(name text,actual boolean,expected boolean);
do $hp_properties$
declare property record; actual boolean; batch uuid; attempt uuid;
begin
 select confirmed_need_batch_id,attempt_id into strict batch,attempt from hp_target;
 for property in select * from(values
 ('captured historical attempt survives current pointer advancement','select 1',true),
 ('missing attempt','delete from pg_temp.hp_confirmed_need_validation_attempts',false),
 ('wrong batch','update pg_temp.hp_confirmed_need_validation_attempts set confirmed_need_batch_id=gen_random_uuid()',false),
 ('blocked attempt','update pg_temp.hp_confirmed_need_validation_attempts set outcome=''BLOCKED''',false),
 ('nonpositive line count','update pg_temp.hp_confirmed_need_validation_attempts set line_count=0',false),
 ('duplicate observations','insert into pg_temp.hp_confirmed_need_validation_lines select * from pg_temp.hp_confirmed_need_validation_lines where confirmed_need_validation_attempt_id=(select attempt_id from hp_target) limit 1',false),
 ('missing observation','delete from pg_temp.hp_confirmed_need_validation_lines where confirmed_need_line_id=(select confirmed_need_line_id from hp_target)',false),
 ('NULL line identity','update pg_temp.hp_confirmed_need_validation_lines set confirmed_need_line_id=null',false),
 ('missing revision','delete from pg_temp.hp_confirmed_need_line_revisions',false),
 ('NULL revision','update pg_temp.hp_confirmed_need_validation_lines set current_confirmed_need_line_revision_id=null',false),
 ('missing decision','delete from pg_temp.hp_confirmed_need_line_decisions',false),
 ('NULL decision','update pg_temp.hp_confirmed_need_validation_lines set current_confirmed_need_line_decision_id=null',false),
 ('missing policy','delete from pg_temp.hp_planning_quantity_policy_revisions',false),
 ('NULL policy','update pg_temp.hp_confirmed_need_validation_lines set planning_quantity_policy_id=null',false),
 ('missing stable line','delete from pg_temp.hp_confirmed_need_lines',false),
 ('wrong source kind','update pg_temp.hp_confirmed_need_validation_attempts set source_kind=''OTHER''',false),
 ('warning severity mismatch','update pg_temp.hp_confirmed_need_validation_attempts set warning_count=warning_count+1',false),
 ('blocking severity mismatch','update pg_temp.hp_confirmed_need_validation_attempts set blocking_issue_count=1',false),
 ('zero contributions preserve count zero and NULL sum','delete from pg_temp.hp_confirmed_need_line_revision_contributions',false),
 ('all NULL contribution quantities','update pg_temp.hp_confirmed_need_line_revision_contributions set controlled_contribution_quantity=null',false),
 ('duplicate contributions retain raw multiplicity','insert into pg_temp.hp_confirmed_need_line_revision_contributions select * from pg_temp.hp_confirmed_need_line_revision_contributions',false),
 ('shared revision keys cannot hide different lines','update pg_temp.hp_confirmed_need_validation_lines set current_confirmed_need_line_revision_id=(select revision_id from hp_target)',false),
 ('NULL observed member count','update pg_temp.hp_confirmed_need_validation_lines set observed_source_membership_count=null',false),
 ('NULL source total','update pg_temp.hp_confirmed_need_validation_lines set source_membership_total=null',false),
 ('exact captured quantity mismatch','update pg_temp.hp_confirmed_need_validation_lines set confirmed_quantity=confirmed_quantity+0.000001',false),
 ('tick mismatch','update pg_temp.hp_confirmed_need_validation_lines set planning_tick_count=planning_tick_count+1',false),
 ('revision cardinality mismatch','update pg_temp.hp_confirmed_need_validation_lines set observed_current_revision_count=2',false),
 ('policy cardinality mismatch','update pg_temp.hp_confirmed_need_validation_lines set observed_eligible_policy_count=0',false),
 ('current revision flag is not historical authority','update pg_temp.hp_confirmed_need_line_revisions set is_current=false',true)
 )cases(name,mutation,expected) loop
  begin
   execute property.mutation;
   actual:=pg_temp.hp_historical_complete(batch,attempt);
   raise sqlstate 'PZ001';
  exception when sqlstate 'PZ001' then null;
  end;
  insert into hp_results values(property.name,actual,property.expected);
 end loop;
end;$hp_properties$;
select is(actual,expected,'historical rowset: '||name)from hp_results;

select * from finish();
rollback;
