-- Migration 108: real workload READS ONLY; probe identities roll back per RPC case.
-- One top-level SELECT per RPC gives each its own unchanged PostgreSQL 17 statement budget.
begin;
set local statement_timeout='8s';
set local lock_timeout='1s';
create temporary table a108_checks(label text primary key) on commit drop;
create temporary table a108_case_results(case_number integer primary key,result jsonb) on commit drop;
create temporary table a108_context(
 purchase_order_id uuid,supplier_id uuid,service_date date,scope_ids uuid[],line_count integer,
 fingerprint text,generated_date date,generated_customer_id uuid) on commit drop;
create temporary table a108_report(result jsonb) on commit drop;
create function pg_temp.a108_require(p_label text,p_pass boolean)
returns void language plpgsql set search_path='' as $require$
begin
 if p_pass is distinct from true then raise exception 'A108 acceptance failed: %',p_label; end if;
 insert into pg_temp.a108_checks values(p_label);
end;
$require$;
do $preflight$
declare v_po record; v_scopes uuid[]; v_before text; v_date date; v_customer uuid;
begin
  perform pg_temp.a108_require('migration_108_present',exists(
    select 1 from supabase_migrations.schema_migrations
    where version='20261014090000'));
  perform pg_temp.a108_require('helper_exact_security_boundary',(
    select pg_get_userbyid(p.proowner)='atlas_owner' and not p.prosecdef
      and p.proconfig=array['search_path=""']::text[]
      and not exists(select 1 from aclexplode(p.proacl) acl
        where acl.grantee<>p.proowner and (
          acl.grantee not in ('atlas_read_runtime'::regrole,
            'atlas_procurement_command_runtime'::regrole)
          or acl.privilege_type<>'EXECUTE' or acl.is_grantable))
      and has_function_privilege('atlas_read_runtime',p.oid,'EXECUTE')
      and has_function_privilege('atlas_procurement_command_runtime',p.oid,'EXECUTE')
      and not has_function_privilege('authenticated',p.oid,'EXECUTE')
      and not has_function_privilege('anon',p.oid,'EXECUTE')
      and not has_function_privilege('service_role',p.oid,'EXECUTE')
    from pg_proc p where p.oid=
      'atlas_core.school_catering_purchase_order_actor_has_full_scope(uuid,uuid)'::regprocedure));
  perform pg_temp.a108_require('probe_namespace_empty',not exists(
    select 1 from atlas_core.actors where actor_id::text like 'f108%'));

  select po.purchase_order_id,po.supplier_id,po.school_catering_service_date,
    count(distinct school->>'school_id') scope_count,
    count(distinct line.purchase_order_line_revision_id) line_count
  into v_po
  from atlas_procurement.purchase_orders po
  join atlas_procurement.purchase_order_revisions revision
    on revision.purchase_order_id=po.purchase_order_id and revision.is_current
  join atlas_procurement.purchase_order_line_revisions line using(purchase_order_revision_id)
  cross join lateral jsonb_array_elements(atlas_core.school_catering_po_school_breakdown(
    line.school_catering_allocation_supplier_split_id)) school
  where po.purchase_order_kind='SCHOOL_CATERING' and po.purchase_order_status='DRAFT'
  group by po.purchase_order_id
  having count(distinct school->>'school_id')>1
  order by scope_count desc,po.school_catering_service_date desc,po.purchase_order_id
  limit 1;
  perform pg_temp.a108_require('real_multischool_draft_available',v_po.purchase_order_id is not null);
  select array_agg(distinct (school->>'school_id')::uuid order by (school->>'school_id')::uuid)
  into v_scopes
  from atlas_procurement.purchase_order_revisions revision
  join atlas_procurement.purchase_order_line_revisions line using(purchase_order_revision_id)
  cross join lateral jsonb_array_elements(atlas_core.school_catering_po_school_breakdown(
    line.school_catering_allocation_supplier_split_id)) school
  where revision.purchase_order_id=v_po.purchase_order_id and revision.is_current;
  select md5(to_jsonb(po)::text||to_jsonb(revision)::text||
    (select string_agg(to_jsonb(line)::text,'' order by line.purchase_order_line_revision_id)
      from atlas_procurement.purchase_order_line_revisions line
      where line.purchase_order_revision_id=revision.purchase_order_revision_id))
  into v_before from atlas_procurement.purchase_orders po
  join atlas_procurement.purchase_order_revisions revision
    on revision.purchase_order_id=po.purchase_order_id and revision.is_current
  where po.purchase_order_id=v_po.purchase_order_id;

    select line.service_date,school.customer_id into v_date,v_customer
    from atlas_planning.need_generation_runs run
    join atlas_planning.need_generation_release_snapshots snapshot using(need_generation_run_id)
    join atlas_planning.need_generation_release_snapshot_lines member using(need_generation_release_snapshot_id)
    join atlas_planning.theoretical_need_lines line using(theoretical_need_line_id)
    join atlas_admin.schools school on school.school_id=line.school_id
    where run.run_status='RELEASED_FOR_CONFIRMATION' and line.line_disposition='ACTIVE'
      and not exists(select 1 from atlas_planning.need_generation_runs later
        where later.planning_input_set_id=run.planning_input_set_id
          and later.attempt_ordinal>run.attempt_ordinal)
    order by line.service_date desc,school.school_id limit 1;
    perform pg_temp.a108_require('real_generated_source_available',v_date is not null);
 insert into pg_temp.a108_context values(v_po.purchase_order_id,v_po.supplier_id,
  v_po.school_catering_service_date,v_scopes,v_po.line_count,v_before,v_date,v_customer);
end;
$preflight$;
create function pg_temp.a108_workload_case(p_case integer)
returns void language plpgsql volatile set search_path='' as $case$
declare
 context record; prior_labels text[]; new_labels text[]; response jsonb; request jsonb;
 payload jsonb; subject_number integer; started timestamptz; elapsed_ms numeric; result jsonb;
begin
 if p_case not between 1 and 8 then raise exception 'A108 unsupported workload case'; end if;
 select * into strict context from pg_temp.a108_context;
 select array_agg(label) into prior_labels from pg_temp.a108_checks;
 begin
    insert into atlas_core.actors(actor_id,actor_type,display_name)
    select ('f1080090-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
      'HUMAN','A108 rolled-back workload probe '||n from generate_series(1,5) n;
    insert into atlas_core.actor_auth_subjects(actor_id,auth_subject_id)
    select actor_id,actor_id from atlas_core.actors where actor_id::text like 'f1080090-%';
    insert into atlas_core.roles(role_id,role_code,role_name)
    select ('f1080091-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
      'a108_workload_'||n,'A108 rolled-back workload role '||n from generate_series(1,2) n;
    insert into atlas_core.role_capabilities(role_id,capability_id)
    select 'f1080091-0000-4000-8000-000000000001',capability_id
    from atlas_core.capabilities where capability_code='procurement.school_catering.read';
    insert into atlas_core.role_capabilities(role_id,capability_id)
    select 'f1080091-0000-4000-8000-000000000002',capability_id
    from atlas_core.capabilities where capability_code='confirmed_need_review.read';
    insert into atlas_core.actor_role_memberships(actor_id,role_id)
    select ('f1080090-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
      case when n=5 then 'f1080091-0000-4000-8000-000000000002'::uuid
        else 'f1080091-0000-4000-8000-000000000001'::uuid end from generate_series(1,5) n;
    insert into atlas_core.actor_scopes(actor_id,scope_kind,school_id)
    select 'f1080090-0000-4000-8000-000000000001','SCHOOL',school from unnest(context.scope_ids) school;
    insert into atlas_core.actor_scopes(actor_id,scope_kind,school_id)
    select 'f1080090-0000-4000-8000-000000000002','SCHOOL',school
    from unnest(context.scope_ids[1:cardinality(context.scope_ids)-1]) school;
    insert into atlas_core.actor_scopes(actor_id,scope_kind)
    select ('f1080090-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'GLOBAL'
    from generate_series(3,5) n;

  subject_number:=case when p_case<=3 then p_case when p_case=4 then 3
   when p_case=6 then 5 else 4 end;
  if p_case=7 then
   update atlas_core.actor_scopes set scope_kind='CUSTOMER',customer_id=context.generated_customer_id
   where actor_id='f1080090-0000-4000-8000-000000000004';
  elsif p_case=8 then
   insert into atlas_admin.customers(customer_id,customer_code,customer_name,customer_type)
   values('f1080092-0000-4000-8000-000000000001','a108_workload_outside_customer',
    'A108 rolled-back outside Customer','SCHOOL_CATERING');
   update atlas_core.actor_scopes set scope_kind='CUSTOMER',
    customer_id='f1080092-0000-4000-8000-000000000001'
   where actor_id='f1080090-0000-4000-8000-000000000004';
  end if;
  perform set_config('request.jwt.claim.sub',
   'f1080090-0000-4000-8000-'||lpad(subject_number::text,12,'0'),true);
  if p_case<=3 then
   payload:=jsonb_build_object('date_start',context.service_date,'date_end',context.service_date,
    'supplier_ids',jsonb_build_array(context.supplier_id),'statuses','[]'::jsonb,'search',null);
  else payload:=jsonb_build_object('service_date',context.generated_date); end if;
  request:=jsonb_build_object('contract_version',case when p_case<=3
   then 'SCHOOL-CATERING-PROCUREMENT.v1' else 'PURCHASE-REVIEW.v1' end,
   'requested_by_auth_subject',current_setting('request.jwt.claim.sub'),
   'correlation_id',gen_random_uuid(),'payload',payload);
  set local role authenticated;
  started:=clock_timestamp();
  if p_case<=3 then response:=atlas_api.get_school_catering_purchase_orders(request);
  else response:=atlas_api.get_generated_purchase_review(request); end if;
  elapsed_ms:=extract(epoch from clock_timestamp()-started)*1000;
  reset role;
  if p_case<=3 then
   perform pg_temp.a108_require('real_po_read_success_'||p_case,response->>'success'='true');
   perform pg_temp.a108_require('real_po_complete_or_hidden_'||p_case,
    case when p_case=2 then
     not exists(select 1 from jsonb_array_elements(response->'purchase_orders') po
      where po->>'purchase_order_id'=context.purchase_order_id::text)
    else exists(select 1 from jsonb_array_elements(response->'purchase_orders') po
     where po->>'purchase_order_id'=context.purchase_order_id::text
      and jsonb_array_length(po->'lines')=context.line_count) end);
  elsif p_case<=6 then
   perform pg_temp.a108_require('generated_capability_'||(p_case-1),
    case when p_case=6 then response->>'error_code'='CAPABILITY_DENIED'
     else response->>'success'='true' and jsonb_array_length(response->'rows')>0 end);
  elsif p_case=7 then
   perform pg_temp.a108_require('generated_matching_customer_scope',
    response->>'success'='true' and jsonb_array_length(response->'rows')>0
    and not exists(select 1 from jsonb_array_elements(response->'rows') row
     join atlas_admin.schools school on school.school_id=(row->>'school_id')::uuid
     where school.customer_id<>context.generated_customer_id));
  else
   perform pg_temp.a108_require('generated_outside_scope_hidden',
    response->>'success'='true' and jsonb_array_length(response->'rows')=0);
  end if;
  select array_agg(label order by label) into new_labels from pg_temp.a108_checks
   where label<>all(prior_labels);
  result:=jsonb_build_object('case_number',p_case,'rpc_elapsed_ms',round(elapsed_ms,2),
   'checks',to_jsonb(new_labels));
  raise exception using errcode='Z1080',message='Successful per-case probe rollback';
 exception when sqlstate 'Z1080' then null;
 end;
 if exists(select 1 from atlas_core.actors where actor_id::text like 'f108%')
  or exists(select 1 from atlas_admin.customers where customer_id::text like 'f108%') then
  raise exception 'A108 workload case identity persisted';
 end if;
 insert into pg_temp.a108_checks select unnest(new_labels);
 insert into pg_temp.a108_case_results values(p_case,result);
end;
$case$;
-- Separate top-level statements: no public RPC shares its statement budget with another.
select pg_temp.a108_workload_case(1);
select pg_temp.a108_workload_case(2);
select pg_temp.a108_workload_case(3);
select pg_temp.a108_workload_case(4);
select pg_temp.a108_workload_case(5);
select pg_temp.a108_workload_case(6);
select pg_temp.a108_workload_case(7);
select pg_temp.a108_workload_case(8);
do $report$
declare context record; after_fingerprint text; check_count integer; cases jsonb; results jsonb;
begin
 select * into strict context from pg_temp.a108_context;
 select count(*),jsonb_agg(label order by label) into check_count,cases from pg_temp.a108_checks;
 if check_count<>16 or (select count(*) from pg_temp.a108_case_results)<>8 then
  raise exception 'A108 workload case count mismatch'; end if;
 select md5(to_jsonb(po)::text||to_jsonb(revision)::text||
  (select string_agg(to_jsonb(line)::text,'' order by line.purchase_order_line_revision_id)
   from atlas_procurement.purchase_order_line_revisions line
   where line.purchase_order_revision_id=revision.purchase_order_revision_id))
 into after_fingerprint from atlas_procurement.purchase_orders po
 join atlas_procurement.purchase_order_revisions revision
  on revision.purchase_order_id=po.purchase_order_id and revision.is_current
 where po.purchase_order_id=context.purchase_order_id;
 if context.fingerprint is distinct from after_fingerprint then raise exception 'A108 real PO changed'; end if;
 select jsonb_agg(result order by case_number) into results from pg_temp.a108_case_results;
 insert into pg_temp.a108_report values(jsonb_build_object('success',true,
  'case_count',check_count,'cases',cases,'top_level_rpc_cases',8,'rpc_results',results,
  'real_po_id',context.purchase_order_id,'real_po_scope_count',cardinality(context.scope_ids),
  'real_po_line_count',context.line_count,'real_po_fingerprint',context.fingerprint,
  'generated_source_date',context.generated_date,'probe_rollback_verified',true,'real_po_unchanged',true));
end;
$report$;
select result from pg_temp.a108_report;
rollback;
