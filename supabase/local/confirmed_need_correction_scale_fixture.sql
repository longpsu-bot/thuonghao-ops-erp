-- Genuine C scale source/master setup. No fabricated Need/approval/release authority.
-- The inherited template is source/master context only; public generation below
-- must append a distinct successful successor before any tested authority.
\ir purchase_review_confirm_release_fixture.sql
insert into atlas_core.actors(actor_id,actor_type,display_name) values
 ('c0150000-0000-4000-8000-000000000001','HUMAN','C public journey operator');
insert into atlas_core.actor_auth_subjects(actor_id,auth_subject_id) values
 ('c0150000-0000-4000-8000-000000000001','c0150000-0000-4000-8000-000000000101');
insert into atlas_core.actor_role_memberships(actor_id,role_id) values
 ('c0150000-0000-4000-8000-000000000001','b6000000-0000-0000-0000-000000000003');
insert into atlas_core.actor_scopes(actor_id,scope_kind) values
 ('c0150000-0000-4000-8000-000000000001','GLOBAL');
insert into atlas_core.role_capabilities(role_id,capability_id)
select 'b6000000-0000-0000-0000-000000000003',capability_id
from atlas_core.capabilities where capability_code like 'planning.%'
 or capability_code like 'confirmed_need_%'
 or capability_code like 'procurement.school_catering.%'
 or capability_code like 'dispatch.school_release.%'
on conflict do nothing;

-- Explicit synthetic issuer facts, not an inference or a staff assignment.
update atlas_admin.schools set dispatch_document_issuer_name='C fixture issuer',
 dispatch_document_issuer_address='C fixture synthetic address'
where school_id='b6500000-0000-0000-0000-000000000004';

create function pg_temp.c_command(contract text,reason text,version bigint,
 payload jsonb,note text default null) returns jsonb
language sql volatile set search_path='' as $$
 select jsonb_build_object('contract_version',contract,'command_id',gen_random_uuid(),
  'correlation_id',gen_random_uuid(),'idempotency_key',gen_random_uuid()::text,
  'expected_version',version,
  'requested_by_auth_subject','c0150000-0000-4000-8000-000000000101',
  'requested_at',transaction_timestamp(),'reason_code',reason,
  'reason_note',note,'payload',payload);
$$;
create function pg_temp.c_read(contract text,payload jsonb) returns jsonb
language sql volatile set search_path='' as $$
 select jsonb_build_object('contract_version',contract,
  'requested_by_auth_subject','c0150000-0000-4000-8000-000000000101',
  'correlation_id',gen_random_uuid(),'payload',payload);
$$;

create temporary table c_scale_schools as
 select n,case when n=1 then 'b6500000-0000-0000-0000-000000000004'::uuid
 else md5('c-scale-school:'||n)::uuid end school_id,
 case when n=1 then 'b6500000-0000-0000-0000-000000000002'::uuid
 else md5('c-scale-location:'||n)::uuid end location_id
 from generate_series(1,50)n;
create temporary table c_scale_ingredients as
 select n,case n when 1 then 'b6500000-0000-0000-0000-000000000006'::uuid
 when 2 then 'b6500000-0000-0000-0000-000000000007'::uuid
 else md5('c-scale-ingredient:'||n)::uuid end ingredient_id,
 case n when 1 then 'c7100000-0000-4000-8000-000000000001'::uuid
 when 2 then 'c7100000-0000-4000-8000-000000000002'::uuid
 else md5('c-scale-supplier:'||n)::uuid end supplier_id
 from generate_series(1,5)n;
insert into atlas_admin.delivery_locations
 select (jsonb_populate_record(null::atlas_admin.delivery_locations,to_jsonb(t)||jsonb_build_object(
 'delivery_location_id',s.location_id,'location_code','c-scale-l-'||s.n,
 'location_name','C scale kitchen '||s.n))).*
 from atlas_admin.delivery_locations t cross join c_scale_schools s
 where t.delivery_location_id='b6500000-0000-0000-0000-000000000002'and s.n>1;
insert into atlas_admin.schools
 select (jsonb_populate_record(null::atlas_admin.schools,to_jsonb(t)||jsonb_build_object(
 'school_id',s.school_id,'school_code','c-scale-s-'||s.n,'school_name','C scale School '||s.n,
 'default_delivery_location_id',s.location_id,'display_order',100+s.n,
 'dispatch_document_issuer_name','C scale issuer','dispatch_document_issuer_address','C scale address'))).*
 from atlas_admin.schools t cross join c_scale_schools s
 where t.school_id='b6500000-0000-0000-0000-000000000004'and s.n>1;
insert into atlas_admin.ingredients
 select (jsonb_populate_record(null::atlas_admin.ingredients,to_jsonb(t)||jsonb_build_object(
 'ingredient_id',i.ingredient_id,'ingredient_code','C-SCALE-I-'||i.n,
 'ingredient_name','C scale Ingredient '||i.n,'document_code','C-SCALE-I-'||i.n))).*
 from atlas_admin.ingredients t cross join c_scale_ingredients i
 where t.ingredient_id='b6500000-0000-0000-0000-000000000006'and i.n>2;
insert into atlas_admin.suppliers
 select (jsonb_populate_record(null::atlas_admin.suppliers,to_jsonb(t)||jsonb_build_object(
 'supplier_id',i.supplier_id,'supplier_code','C-SCALE-P-'||i.n,
 'supplier_name','C scale Supplier '||i.n,'document_code','C-SCALE-P-'||i.n))).*
 from atlas_admin.suppliers t cross join c_scale_ingredients i
 where t.supplier_id='c7100000-0000-4000-8000-000000000001'and i.n>2;
insert into atlas_admin.supplier_eligibilities(supplier_id,ingredient_id,effective_from,priority,reason_note)
 select i.supplier_id,i.ingredient_id,date'2020-01-01',1,'C scale synthetic eligibility'
 from c_scale_ingredients i where i.n>2;

create temporary table c_scale_results(name text primary key,api text,response jsonb,
 elapsed_ms numeric,command_ms numeric,guard_flush_ms numeric,invoked_as text,history_depth integer,
 settings_before jsonb,settings_after jsonb);
create temporary table c_scale_context(name text primary key,value jsonb);
create temporary table c_scale_requests(name text primary key,api text,request jsonb);
create function pg_temp.c_scale_call(p_name text,p_api text,p_request jsonb,p_depth integer default 0)
 returns jsonb language plpgsql volatile as $$
declare answer jsonb; started timestamptz; returned timestamptz; finished timestamptz; actor_role text;
 boundary_settings jsonb;nested_settings jsonb;
begin
 if p_api not in('save_pantry','execute_need_generation','save_confirmed_needs',
 'get_confirmed_supplier_allocation_workbench','save_confirmed_supplier_allocation',
 'release_confirmed_needs','release_school_catering_purchase_handoff',
 'prepare_school_catering_purchase_orders','create_school_catering_purchase_order_replacement',
 'release_school_catering_purchase_order','get_school_dispatch_release_workbench',
 'release_school_dispatch_document','get_school_catering_purchase_orders',
 'get_confirmed_need_correction_preview','correct_confirmed_need')then raise exception 'Unexpected scale API';end if;
 raise notice 'C_SCALE_START % % depth %',p_name,p_api,p_depth;
 set local role authenticated;
 perform set_config('request.jwt.claim.sub','c0150000-0000-4000-8000-000000000101',true);
 actor_role:=current_user;
 perform set_config('lock_timeout','1s',true);
 boundary_settings:=jsonb_build_object('lock_timeout',current_setting('lock_timeout'),
 'statement_timeout',current_setting('statement_timeout'));
 started:=clock_timestamp();
 execute format('select atlas_api.%I($1)',p_api)into answer using p_request;
 returned:=clock_timestamp();
 -- A real response also completes its own deferred integrity checks. Keep
 -- these in the SAME top-level budget, not charged to the next public call.
 set constraints all immediate;
 set constraints all deferred;
 finished:=clock_timestamp();
 nested_settings:=jsonb_build_object('lock_timeout',current_setting('lock_timeout'),
 'statement_timeout',current_setting('statement_timeout'));
 -- Preserve incumbent nested5s lock settings in evidence, then restore the
 -- caller boundary. SET here never rearms this already-running statement.
 perform set_config('lock_timeout',boundary_settings->>'lock_timeout',true);
 perform set_config('statement_timeout',boundary_settings->>'statement_timeout',true);
 reset role;
 insert into c_scale_results values(p_name,p_api,answer,
 extract(epoch from finished-started)*1000,extract(epoch from returned-started)*1000,
 extract(epoch from finished-returned)*1000,actor_role,p_depth,boundary_settings,nested_settings);
 raise notice 'C_SCALE_END % ms % success % code %',p_name,
 extract(epoch from finished-started)*1000,answer->>'success',answer->>'error_code';
 raise notice 'C_SCALE_SETTINGS % before % after %',p_name,boundary_settings,nested_settings;
 if answer->>'success'is distinct from'true'then raise exception 'Scale public stage % rejected: %',p_name,answer;end if;
 return answer;
exception when others then reset role;raise;end;$$;

set local statement_timeout='8s';
set local lock_timeout='1s';
-- Source/master template setup is not public-command work. Finish its own
-- checks before timing any tested public response.
set constraints all immediate;
set constraints all deferred;
-- Source Save creates the real complete 250-row source, not released facts.
select pg_temp.c_scale_call('source-save','save_pantry',pg_temp.c_command(
 'PANTRY-02.v2','PANTRY_SAVED',batch.version,jsonb_build_object('week_start',batch.week_start,
 'no_additions_confirmed',false,'expected_source_signature',batch.source_signature,
 'source_signature',atlas_core.pantry_02_signature(batch.week_start,false,
 atlas_core.pantry_02_canonical_rows(batch.week_start,source.rows)),'rows',source.rows))) ->>'success'
from atlas_planning.pantry_need_batches batch cross join lateral(
 select jsonb_agg(jsonb_build_object('service_date','2026-11-02','school_id',s.school_id,
 'ingredient_id',i.ingredient_id,'pantry_need_purpose_id','b6530000-0000-0000-0000-000000000001',
 'requested_quantity','100.000000','note','C public 250-family scale',
 'source_request_reference','C-SCALE','source_row_reference',s.n||':'||i.n)order by s.n,i.n)rows
 from c_scale_schools s cross join c_scale_ingredients i)source
where batch.pantry_need_batch_id='b6530000-0000-0000-0000-000000000002';
-- Exactly-once owned-fixture statistics prerequisite, outside measured APIs.
-- Preserve empty-schema/stale-statistics failures separately; this is not a
-- cold database-generation certification or a per-history refresh.
do $$declare relation text;rows bigint;before_stats jsonb;report jsonb:='[]';begin
 foreach relation in array array['atlas_admin.schools','atlas_admin.delivery_locations',
 'atlas_admin.ingredients','atlas_admin.suppliers','atlas_admin.supplier_eligibilities',
 'atlas_planning.pantry_need_lines','atlas_planning.pantry_need_approval_snapshot_lines',
 'atlas_planning.theoretical_need_lines','atlas_planning.need_generation_release_snapshot_lines',
 'atlas_planning.confirmed_need_lines','atlas_planning.confirmed_need_line_revisions',
 'atlas_planning.confirmed_need_line_revision_contributions','atlas_planning.planning_quantity_policy_revisions']loop
 execute format('select count(*)from %s',relation::regclass)into rows;
 select to_jsonb(s)into before_stats from pg_stat_user_tables s where s.relid=relation::regclass;
 report:=report||jsonb_build_array(jsonb_build_object('relation',relation,'actual_rows',rows,'before_stats',before_stats));
 execute format('analyze %s',relation::regclass);
 end loop;
 insert into c_scale_context values('once-statistics',jsonb_build_object('role',current_user,'relations',report));
end;$$;
select jsonb_build_object('C_SCALE_ONCE_STATISTICS',value)from c_scale_context where name='once-statistics';
select pg_temp.c_scale_call('generation','execute_need_generation',pg_temp.c_command(
 'RMVP-04.v3','NEED_GENERATION_EXECUTED',coalesce(run.version,1),jsonb_build_object(
 'service_date','2026-11-02','expected_current_need_generation_run_id',run.need_generation_run_id),
 'C genuine 250-family generation'))->>'success'
from(select 1)seed left join atlas_planning.need_generation_runs run
 on run.need_generation_run_id=(select b.current_need_generation_run_id
 from atlas_planning.confirmed_need_batches b where b.period_start='2026-11-02'and b.period_end='2026-11-02');
insert into c_scale_context select 'batch',response#>'{affected_aggregate_ids,confirmed_need_batch_id}'
 from c_scale_results where name='generation';
do $$begin
 if(select count(*)from atlas_planning.confirmed_need_lines l
 join atlas_planning.confirmed_need_line_revisions r on r.confirmed_need_line_id=l.confirmed_need_line_id and r.is_current
 where l.confirmed_need_batch_id=(select(value#>>'{}')::uuid from c_scale_context where name='batch')and r.confirmed_quantity>0)<>250
 then raise exception 'Scale generation must have exactly250 positive public lines';end if;
end;$$;
select pg_temp.c_scale_call('need-save','save_confirmed_needs',pg_temp.c_command(
 'RMVP-05.v2','CONFIRMED_NEED_SAVED',b.version,jsonb_build_object('confirmed_need_batch_id',b.confirmed_need_batch_id,
 'lines',(select jsonb_agg(jsonb_build_object('confirmed_need_line_id',l.confirmed_need_line_id,
 'expected_current_revision_id',r.confirmed_need_line_revision_id,
 'expected_current_decision_id',l.current_confirmed_need_line_decision_id,
 'proposed_confirmed_quantity',r.confirmed_quantity::numeric(20,6)::text,
 'reason_code','PROPOSAL_ACCEPTED','reason_note',null)order by l.confirmed_need_line_id)
 from atlas_planning.confirmed_need_lines l join atlas_planning.confirmed_need_line_revisions r
 on r.confirmed_need_line_id=l.confirmed_need_line_id and r.is_current where l.confirmed_need_batch_id=b.confirmed_need_batch_id))))->>'success'
from atlas_planning.confirmed_need_batches b where b.confirmed_need_batch_id=(select(value#>>'{}')::uuid from c_scale_context where name='batch');
select pg_temp.c_scale_call('allocation-read','get_confirmed_supplier_allocation_workbench',
 pg_temp.c_read('CONFIRMED-SUPPLIER-ALLOCATION.v1',jsonb_build_object('date_start','2026-11-02','date_end','2026-11-02')))->>'success';
insert into c_scale_requests
 select 'allocation-'||row_number()over(order by item->>'delivery_location_id',item->>'ingredient_id'),
 'save_confirmed_supplier_allocation',pg_temp.c_command('CONFIRMED-SUPPLIER-ALLOCATION.v1',
 'CONFIRMED_SUPPLIER_ALLOCATION_SAVED',(item#>>'{family,version}')::bigint,
 jsonb_build_object('family',jsonb_build_object('service_date',item->'service_date',
 'delivery_location_id',item->'delivery_location_id','ingredient_id',item->'ingredient_id','unit_id',item->'unit_id',
 'expected_source_fingerprint',item#>'{family,source_fingerprint}',
 'expected_source_batch_id',item->'source_confirmed_need_batch_id',
 'expected_source_batch_version',item->'source_confirmed_need_batch_version'),
 'splits',jsonb_build_array(jsonb_build_object('supplier_id',i.supplier_id,'allocated_quantity',item->'family_quantity',
 'supplier_note','C scale preserved note'))))
 from c_scale_results result cross join lateral jsonb_array_elements(result.response->'rows')item
 join c_scale_ingredients i on i.ingredient_id=(item->>'ingredient_id')::uuid
 where result.name='allocation-read';
-- Each generated statement gets its own unchanged8s budget; never one DO
-- loop whose entire250-call cost is mistaken for a single public RPC.
select format('select pg_temp.c_scale_call(%L,%L,%L::jsonb)->>''success'';',name,api,request::text)
 from c_scale_requests order by name
\gexec
select pg_temp.c_scale_call('need-release-v2','release_confirmed_needs',pg_temp.c_command(
 'RMVP-07.v2','CONFIRMED_NEED_RELEASED',b.version,jsonb_build_object('confirmed_need_batch_id',b.confirmed_need_batch_id)))->>'success'
from atlas_planning.confirmed_need_batches b where b.confirmed_need_batch_id=(select(value#>>'{}')::uuid from c_scale_context where name='batch');
select pg_temp.c_scale_call('handoff','release_school_catering_purchase_handoff',pg_temp.c_command(
 'SCHOOL-CATERING-HANDOFF.v1','SCHOOL_CATERING_PURCHASE_HANDOFF_RELEASED',b.version,
 jsonb_build_object('confirmed_need_batch_id',b.confirmed_need_batch_id)))->>'success'
from atlas_planning.confirmed_need_batches b where b.confirmed_need_batch_id=(select(value#>>'{}')::uuid from c_scale_context where name='batch');
set local statement_timeout='20s';
select pg_temp.c_scale_call('preparation','prepare_school_catering_purchase_orders',pg_temp.c_command(
 'PURCHASE-COMMITMENT.v1','PURCHASE_ORDERS_PREPARED',b.version,jsonb_build_object('service_date','2026-11-02',
 'confirmed_need_batch_id',b.confirmed_need_batch_id)))->>'success'
from atlas_planning.confirmed_need_batches b where b.confirmed_need_batch_id=(select(value#>>'{}')::uuid from c_scale_context where name='batch');
set local statement_timeout='8s';
-- Release each complete Supplier/date draft explicitly, without bulk release.
select format('select pg_temp.c_scale_call(%L,%L,%L::jsonb)->>''success'';',
 'po-release-'||row_number()over(order by po.purchase_order_id),'release_school_catering_purchase_order',
 pg_temp.c_command('SCHOOL-CATERING-PROCUREMENT.v1','SCHOOL_CATERING_PO_RELEASED',po.version,
 jsonb_build_object('purchase_order_id',po.purchase_order_id,'expected_purchase_order_revision_id',rev.purchase_order_revision_id))::text)
from atlas_procurement.purchase_orders po join atlas_procurement.purchase_order_revisions rev using(purchase_order_id)
where po.school_catering_service_date='2026-11-02'and rev.is_current
\gexec
-- Refuse to profile or accept a read on a partially released baseline.
-- This checks real stored authority/identity, without warming projection APIs.
do $$declare need_count bigint;family_count bigint;contribution_count bigint;
 released_count bigint;covered_lines bigint;begin
 select count(*)into need_count from atlas_planning.confirmed_need_lines l
 join atlas_planning.confirmed_need_line_revisions r on r.confirmed_need_line_id=l.confirmed_need_line_id and r.is_current
 where l.confirmed_need_batch_id=(select(value#>>'{}')::uuid from c_scale_context where name='batch')
 and r.confirmed_quantity=100 and r.revision_status='RELEASED'
 and l.current_confirmed_need_line_decision_id is not null;
 select count(distinct f.family_id),count(*)into family_count,contribution_count
 from atlas_procurement.school_catering_allocation_families f
 join atlas_procurement.school_catering_allocation_family_revisions r using(family_id)
 join atlas_procurement.school_catering_allocation_family_contributions c using(family_revision_id)
 join atlas_planning.purchase_handoff_line_revisions h using(purchase_handoff_line_revision_id)
 join atlas_planning.purchase_handoff_revisions hr using(purchase_handoff_revision_id)
 join atlas_planning.confirmed_need_line_revisions nr on nr.confirmed_need_line_revision_id=h.confirmed_need_line_revision_id
 where f.service_date='2026-11-02'and r.is_current and r.source_kind='PURCHASE_HANDOFF'
 and r.source_purchase_handoff_revision_id=hr.purchase_handoff_revision_id
 and hr.is_current and hr.revision_status='RELEASED_TO_PROCUREMENT'and nr.is_current
 and nr.confirmed_need_batch_id=(select(value#>>'{}')::uuid from c_scale_context where name='batch')
 and r.family_quantity=100 and c.contribution_quantity=100 and h.handoff_quantity=100 and nr.confirmed_quantity=100
 and nr.delivery_location_id=f.delivery_location_id and nr.ingredient_id=f.ingredient_id and nr.unit_id=f.unit_id;
 select count(*)into released_count from atlas_procurement.purchase_orders po
 join atlas_procurement.purchase_order_revisions r using(purchase_order_id)
 where po.school_catering_service_date='2026-11-02'and po.purchase_order_status='RELEASED_TO_SUPPLIER'
 and r.is_current and r.revision_status='RELEASED_TO_SUPPLIER';
 select count(*)into covered_lines from atlas_procurement.purchase_orders po
 join atlas_procurement.purchase_order_revisions r using(purchase_order_id)
 join atlas_procurement.purchase_order_line_revisions line using(purchase_order_revision_id)
 join atlas_procurement.school_catering_allocation_supplier_splits split
 on split.supplier_split_id=line.school_catering_allocation_supplier_split_id
 join atlas_procurement.school_catering_allocation_family_revisions family using(family_revision_id)
 where po.school_catering_service_date='2026-11-02'and po.purchase_order_status='RELEASED_TO_SUPPLIER'
 and r.is_current and family.is_current and split.supplier_id=po.supplier_id;
 if need_count<>250 or family_count<>250 or contribution_count<>250 or released_count<>5 or covered_lines<>250
 then raise exception 'Scale baseline incomplete: Need %, families %, contributions %, released POs %, covered lines %',
 need_count,family_count,contribution_count,released_count,covered_lines;end if;
 raise notice 'C_SCALE_BASELINE_GATE Need250/families250/contributions250/currentPH/fiveRELEASEDPO/covered250 PASS';
end;$$;
select pg_temp.c_scale_call('official-po-read-cold','get_school_catering_purchase_orders',
 pg_temp.c_read('SCHOOL-CATERING-PROCUREMENT.v1',jsonb_build_object('date_start','2026-11-02','date_end','2026-11-02',
 'supplier_ids','[]'::jsonb,'statuses','[]'::jsonb,'search',null)))->>'success';
select pg_temp.c_scale_call('official-pxk-read-cold','get_school_dispatch_release_workbench',
 pg_temp.c_read('SCHOOL-DISPATCH-RELEASE.v1',jsonb_build_object('date_start','2026-11-02','date_end','2026-11-02',
 'school_ids','[]'::jsonb,'search',null)))->>'success';
select pg_temp.c_scale_call('pxk-release-cold','release_school_dispatch_document',
 pg_temp.c_command('SCHOOL-DISPATCH-RELEASE.v1','SCHOOL_DISPATCH_DOCUMENT_RELEASED',
 (item->>'expected_version')::bigint,jsonb_build_object('service_date',item->'service_date',
 'school_id',item->'school_id','delivery_location_id',item->'delivery_location_id',
 'expected_source_fingerprint',item#>'{preview,source_fingerprint}','predecessor_release_id',null)))->>'success'
from c_scale_results r cross join lateral jsonb_array_elements(r.response->'rows')item
where r.name='official-pxk-read-cold'and item->>'school_id'='b6500000-0000-0000-0000-000000000004';

-- Freeze the249 untouched whole-family identities and four other Supplier POs.
create temporary table c_scale_preserved as
select f.family_id,to_jsonb(f)family,to_jsonb(rev)revision,
 (select jsonb_agg(to_jsonb(c)order by family_contribution_id)
 from atlas_procurement.school_catering_allocation_family_contributions c where c.family_revision_id=rev.family_revision_id)contributions,
 (select jsonb_agg(to_jsonb(s)order by supplier_split_id)
 from atlas_procurement.school_catering_allocation_supplier_splits s where s.family_revision_id=rev.family_revision_id)splits
from atlas_procurement.school_catering_allocation_families f
join atlas_procurement.school_catering_allocation_family_revisions rev using(family_id)
where rev.is_current and not(f.delivery_location_id='b6500000-0000-0000-0000-000000000002'
 and f.ingredient_id='b6500000-0000-0000-0000-000000000006');
create temporary table c_scale_other_pos as
 select po.purchase_order_id,to_jsonb(po)root,to_jsonb(rev)revision
 from atlas_procurement.purchase_orders po join atlas_procurement.purchase_order_revisions rev using(purchase_order_id)
 where rev.is_current and po.supplier_id<>'c7100000-0000-4000-8000-000000000001';
create function pg_temp.c_scale_history(p_stage text,p_depth integer)returns boolean language plpgsql as $$
declare request jsonb;answer jsonb;item jsonb;batch atlas_planning.confirmed_need_batches%rowtype;
 run atlas_planning.need_generation_runs%rowtype;line record;po record;prefix text:='history-'||p_depth||'-';
begin
 select b.* into strict batch from atlas_planning.confirmed_need_batches b
 where b.confirmed_need_batch_id=(select(value#>>'{}')::uuid from c_scale_context where name='batch');
 if p_stage='preview'then
 select r.*,l.current_confirmed_need_line_decision_id into strict line
 from atlas_planning.confirmed_need_lines l join atlas_planning.confirmed_need_line_revisions r
 on r.confirmed_need_line_id=l.confirmed_need_line_id and r.is_current
 where l.confirmed_need_batch_id=batch.confirmed_need_batch_id
 and r.school_id='b6500000-0000-0000-0000-000000000004'and r.ingredient_id='b6500000-0000-0000-0000-000000000006';
 select r.* into strict run from atlas_planning.need_generation_runs r where r.need_generation_run_id=batch.current_need_generation_run_id;
 request:=pg_temp.c_read('CONFIRMED-NEED-CORRECTION.v1',jsonb_build_object(
 'need_generation_run_id',run.need_generation_run_id,'expected_need_generation_run_version',run.version,
 'confirmed_need_batch_id',batch.confirmed_need_batch_id,'expected_confirmed_need_batch_version',batch.version,
 'confirmed_need_line_id',line.confirmed_need_line_id,'expected_current_revision_id',line.confirmed_need_line_revision_id,
 'expected_current_decision_id',line.current_confirmed_need_line_decision_id,
 'proposed_confirmed_quantity',(line.confirmed_quantity+1)::numeric(20,6)::text,
 'reason_code','OPERATIONAL_QUANTITY_ADJUSTMENT','reason_note','C measured history '||p_depth));
 insert into c_scale_requests values(prefix||p_stage,'get_confirmed_need_correction_preview',request);
 answer:=pg_temp.c_scale_call(prefix||p_stage,'get_confirmed_need_correction_preview',request,p_depth);
 elsif p_stage='correct'then
 select pg_temp.c_command('CONFIRMED-NEED-CORRECTION.v1','CONFIRMED_NEED_CORRECTION_SAVED',batch.version,
 original.request->'payload'||jsonb_build_object('proposal_fingerprint',preview.response->'proposal_fingerprint'),
 'C measured history '||p_depth) into request
 from c_scale_requests original cross join c_scale_results preview
 where original.name=prefix||'preview'and preview.name=original.name;
 answer:=pg_temp.c_scale_call(prefix||p_stage,'correct_confirmed_need',request,p_depth);
 elsif p_stage='allocation-read'then
 answer:=pg_temp.c_scale_call(prefix||p_stage,'get_confirmed_supplier_allocation_workbench',
 pg_temp.c_read('CONFIRMED-SUPPLIER-ALLOCATION.v1',jsonb_build_object('date_start','2026-11-02','date_end','2026-11-02')),p_depth);
 elsif p_stage='allocation-save'then
 select value into strict item from c_scale_results r cross join lateral jsonb_array_elements(r.response->'rows')
 where r.name=prefix||'allocation-read'and value->>'delivery_location_id'='b6500000-0000-0000-0000-000000000002'
 and value->>'ingredient_id'='b6500000-0000-0000-0000-000000000006';
 answer:=pg_temp.c_scale_call(prefix||p_stage,'save_confirmed_supplier_allocation',
 pg_temp.c_command('CONFIRMED-SUPPLIER-ALLOCATION.v1','CONFIRMED_SUPPLIER_ALLOCATION_SAVED',
 (item#>>'{family,version}')::bigint,jsonb_build_object('family',jsonb_build_object(
 'service_date',item->'service_date','delivery_location_id',item->'delivery_location_id','ingredient_id',item->'ingredient_id',
 'unit_id',item->'unit_id','expected_source_fingerprint',item#>'{family,source_fingerprint}',
 'expected_source_batch_id',item->'source_confirmed_need_batch_id','expected_source_batch_version',item->'source_confirmed_need_batch_version'),
 'splits',jsonb_build_array(jsonb_build_object('supplier_id','c7100000-0000-4000-8000-000000000001',
 'allocated_quantity',item->'family_quantity','supplier_note','C scale preserved note')))),p_depth);
 elsif p_stage='preparation'then
 answer:=pg_temp.c_scale_call(prefix||p_stage,'prepare_school_catering_purchase_orders',
 pg_temp.c_command('PURCHASE-COMMITMENT.v1','PURCHASE_ORDERS_PREPARED',batch.version,
 jsonb_build_object('service_date','2026-11-02','confirmed_need_batch_id',batch.confirmed_need_batch_id)),p_depth);
 if(select count(*)from c_scale_preserved)<>249 or exists(
 select from c_scale_preserved old left join atlas_procurement.school_catering_allocation_families f using(family_id)
 left join atlas_procurement.school_catering_allocation_family_revisions rev
 on rev.family_id=old.family_id and rev.family_revision_id=(old.revision->>'family_revision_id')::uuid and rev.is_current
 where f.family_id is null or rev.family_revision_id is null or(to_jsonb(f)is distinct from old.family or to_jsonb(rev)is distinct from old.revision
 or old.contributions is distinct from(select jsonb_agg(to_jsonb(c)order by family_contribution_id)
 from atlas_procurement.school_catering_allocation_family_contributions c where c.family_revision_id=rev.family_revision_id)
 or old.splits is distinct from(select jsonb_agg(to_jsonb(s)order by supplier_split_id)
 from atlas_procurement.school_catering_allocation_supplier_splits s where s.family_revision_id=rev.family_revision_id)))
 then raise exception 'C scale must preserve249 whole allocation identities';end if;
 elsif p_stage='replacement'then
 select p.purchase_order_id,p.version,r.purchase_order_revision_id into strict po
 from atlas_procurement.purchase_orders p join atlas_procurement.purchase_order_revisions r using(purchase_order_id)
 where p.school_catering_service_date='2026-11-02'and p.supplier_id='c7100000-0000-4000-8000-000000000001'
 and p.purchase_order_status='RELEASED_TO_SUPPLIER'and r.is_current;
 answer:=pg_temp.c_scale_call(prefix||p_stage,'create_school_catering_purchase_order_replacement',
 pg_temp.c_command('SCHOOL-CATERING-PROCUREMENT.v1','SCHOOL_CATERING_PO_REPLACEMENT_CREATED',po.version,
 jsonb_build_object('replaced_purchase_order_id',po.purchase_order_id,'expected_purchase_order_revision_id',po.purchase_order_revision_id)),p_depth);
 elsif p_stage='po-release'then
 select p.purchase_order_id,p.version,r.purchase_order_revision_id into strict po
 from atlas_procurement.purchase_orders p join atlas_procurement.purchase_order_revisions r using(purchase_order_id)
 where p.school_catering_service_date='2026-11-02'and p.supplier_id='c7100000-0000-4000-8000-000000000001'
 and p.purchase_order_status='DRAFT'and r.is_current;
 answer:=pg_temp.c_scale_call(prefix||p_stage,'release_school_catering_purchase_order',
 pg_temp.c_command('SCHOOL-CATERING-PROCUREMENT.v1','SCHOOL_CATERING_PO_RELEASED',po.version,
 jsonb_build_object('purchase_order_id',po.purchase_order_id,'expected_purchase_order_revision_id',po.purchase_order_revision_id)),p_depth);
 elsif p_stage='po-read'then
 answer:=pg_temp.c_scale_call(prefix||p_stage,'get_school_catering_purchase_orders',
 pg_temp.c_read('SCHOOL-CATERING-PROCUREMENT.v1',jsonb_build_object('date_start','2026-11-02','date_end','2026-11-02',
 'supplier_ids','[]'::jsonb,'statuses','[]'::jsonb,'search',null)),p_depth);
 elsif p_stage='pxk-read'then
 answer:=pg_temp.c_scale_call(prefix||p_stage,'get_school_dispatch_release_workbench',
 pg_temp.c_read('SCHOOL-DISPATCH-RELEASE.v1',jsonb_build_object('date_start','2026-11-02','date_end','2026-11-02',
 'school_ids','[]'::jsonb,'search',null)),p_depth);
 elsif p_stage='pxk-release'then
 select value into strict item from c_scale_results r cross join lateral jsonb_array_elements(r.response->'rows')
 where r.name=prefix||'pxk-read'and value->>'school_id'='b6500000-0000-0000-0000-000000000004';
 answer:=pg_temp.c_scale_call(prefix||p_stage,'release_school_dispatch_document',
 pg_temp.c_command('SCHOOL-DISPATCH-RELEASE.v1','SCHOOL_DISPATCH_DOCUMENT_RELEASED',(item->>'expected_version')::bigint,
 jsonb_build_object('service_date',item->'service_date','school_id',item->'school_id','delivery_location_id',item->'delivery_location_id',
 'expected_source_fingerprint',item#>'{preview,source_fingerprint}',
 'predecessor_release_id',item#>'{current_release,school_dispatch_release_id}')),p_depth);
 if(select count(*)from c_scale_other_pos)<>4 or exists(select from c_scale_other_pos old
 left join atlas_procurement.purchase_orders p using(purchase_order_id)
 left join atlas_procurement.purchase_order_revisions r
 on r.purchase_order_id=old.purchase_order_id and r.purchase_order_revision_id=(old.revision->>'purchase_order_revision_id')::uuid and r.is_current
 where p.purchase_order_id is null or r.purchase_order_revision_id is null
 or(to_jsonb(p)is distinct from old.root or to_jsonb(r)is distinct from old.revision))
 then raise exception 'C scale must preserve four other Supplier POs';end if;
 else raise exception 'Unexpected history stage';end if;
 return answer->>'success'='true';
end;$$;
select format('set local statement_timeout=%L;select pg_temp.c_scale_history(%L,%s);',
 case when stage='preparation'then'20s'else'8s'end,stage,depth)
from generate_series(1,8)depth cross join unnest(array['preview','correct','allocation-read','allocation-save',
 'preparation','replacement','po-release','po-read','pxk-read','pxk-release'])with ordinality stages(stage,ordinal)
order by depth,ordinal
\gexec
set local statement_timeout='8s';
