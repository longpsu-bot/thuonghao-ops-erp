-- Migration 108 acceptance: existing workload is read-only. Probe identity writes roll back.
-- Run only after exact-target/deployed-SHA verification. No real PO is released here.
begin;
set local statement_timeout='8s';
set local lock_timeout='1s';
create temporary table a108_checks(label text primary key) on commit drop;
create temporary table a108_report(result jsonb) on commit drop;
create function pg_temp.a108_require(p_label text,p_pass boolean)
returns void language plpgsql set search_path='' as $$
begin
  if p_pass is distinct from true then
    raise exception 'A108 acceptance failed: %',p_label;
  end if;
  insert into pg_temp.a108_checks values(p_label);
end;
$$;

do $acceptance$
declare
  v_result jsonb; v_response jsonb; v_payload jsonb; v_request jsonb;
  v_po record; v_scopes uuid[]; v_date date; v_customer uuid;
  v_started timestamptz; v_full_ms numeric; v_partial_ms numeric;
  v_before text; v_after text; v_count integer;
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
    select 'f1080090-0000-4000-8000-000000000001','SCHOOL',school from unnest(v_scopes) school;
    insert into atlas_core.actor_scopes(actor_id,scope_kind,school_id)
    select 'f1080090-0000-4000-8000-000000000002','SCHOOL',school
    from unnest(v_scopes[1:cardinality(v_scopes)-1]) school;
    insert into atlas_core.actor_scopes(actor_id,scope_kind)
    select ('f1080090-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'GLOBAL'
    from generate_series(3,5) n;

    v_payload:=jsonb_build_object('date_start',v_po.school_catering_service_date,
      'date_end',v_po.school_catering_service_date,'supplier_ids',jsonb_build_array(v_po.supplier_id),
      'statuses','[]'::jsonb,'search',null);
    for actor_number in 1..3 loop
      perform set_config('request.jwt.claim.sub',
        'f1080090-0000-4000-8000-'||lpad(actor_number::text,12,'0'),true);
      v_request:=jsonb_build_object('contract_version','SCHOOL-CATERING-PROCUREMENT.v1',
        'requested_by_auth_subject',current_setting('request.jwt.claim.sub'),
        'correlation_id',gen_random_uuid(),'payload',v_payload);
      set local role authenticated;
      v_started:=clock_timestamp();
      v_response:=atlas_api.get_school_catering_purchase_orders(v_request);
      reset role;
      if actor_number=1 then v_full_ms:=extract(epoch from clock_timestamp()-v_started)*1000;
      elsif actor_number=2 then v_partial_ms:=extract(epoch from clock_timestamp()-v_started)*1000;
      end if;
      perform pg_temp.a108_require('real_po_read_success_'||actor_number,v_response->>'success'='true');
      perform pg_temp.a108_require('real_po_complete_or_hidden_'||actor_number,
        exists(select 1 from jsonb_array_elements(v_response->'purchase_orders') po
          where po->>'purchase_order_id'=v_po.purchase_order_id::text
            and jsonb_array_length(po->'lines')=v_po.line_count)=(actor_number<>2));
    end loop;

    select line.service_date into v_date
    from atlas_planning.need_generation_runs run
    join atlas_planning.need_generation_release_snapshots snapshot using(need_generation_run_id)
    join atlas_planning.need_generation_release_snapshot_lines member using(need_generation_release_snapshot_id)
    join atlas_planning.theoretical_need_lines line using(theoretical_need_line_id)
    where run.run_status='RELEASED_FOR_CONFIRMATION' and line.line_disposition='ACTIVE'
      and not exists(select 1 from atlas_planning.need_generation_runs later
        where later.planning_input_set_id=run.planning_input_set_id
          and later.attempt_ordinal>run.attempt_ordinal)
    order by line.service_date desc limit 1;
    perform pg_temp.a108_require('real_generated_source_available',v_date is not null);
    for actor_number in 3..5 loop
      perform set_config('request.jwt.claim.sub',
        'f1080090-0000-4000-8000-'||lpad(actor_number::text,12,'0'),true);
      v_request:=jsonb_build_object('contract_version','PURCHASE-REVIEW.v1',
        'requested_by_auth_subject',current_setting('request.jwt.claim.sub'),
        'correlation_id',gen_random_uuid(),'payload',jsonb_build_object('service_date',v_date));
      set local role authenticated;
      v_response:=atlas_api.get_generated_purchase_review(v_request);
      reset role;
      perform pg_temp.a108_require('generated_capability_'||actor_number,
        case when actor_number=5 then v_response->>'error_code'='CAPABILITY_DENIED'
          else v_response->>'success'='true' and jsonb_array_length(v_response->'rows')>0 end);
      if actor_number=4 then
        select customer_id into v_customer from atlas_admin.schools
        where school_id=(v_response#>>'{rows,0,school_id}')::uuid;
      end if;
    end loop;
    update atlas_core.actor_scopes set scope_kind='CUSTOMER',customer_id=v_customer
    where actor_id='f1080090-0000-4000-8000-000000000004';
    perform set_config('request.jwt.claim.sub','f1080090-0000-4000-8000-000000000004',true);
    v_request:=jsonb_build_object('contract_version','PURCHASE-REVIEW.v1',
      'requested_by_auth_subject',current_setting('request.jwt.claim.sub'),
      'correlation_id',gen_random_uuid(),'payload',jsonb_build_object('service_date',v_date));
    set local role authenticated;
    v_response:=atlas_api.get_generated_purchase_review(v_request);
    reset role;
    perform pg_temp.a108_require('generated_matching_customer_scope',
      v_response->>'success'='true' and jsonb_array_length(v_response->'rows')>0
      and not exists(select 1 from jsonb_array_elements(v_response->'rows') row
        join atlas_admin.schools school on school.school_id=(row->>'school_id')::uuid
        where school.customer_id<>v_customer));
    insert into atlas_admin.customers(customer_id,customer_code,customer_name,customer_type)
    values('f1080092-0000-4000-8000-000000000001','a108_workload_outside_customer',
      'A108 rolled-back outside Customer','SCHOOL_CATERING');
    update atlas_core.actor_scopes set customer_id='f1080092-0000-4000-8000-000000000001'
    where actor_id='f1080090-0000-4000-8000-000000000004';
    set local role authenticated;
    v_response:=atlas_api.get_generated_purchase_review(v_request);
    reset role;
    perform pg_temp.a108_require('generated_outside_scope_hidden',
      v_response->>'success'='true' and jsonb_array_length(v_response->'rows')=0);

    select count(*),jsonb_agg(label order by label) into v_count,v_result from pg_temp.a108_checks;
    if v_count<>16 then raise exception 'A108 workload case count mismatch: %',v_count; end if;
    v_result:=jsonb_build_object('case_count',v_count,'cases',v_result,
      'real_po_id',v_po.purchase_order_id,'real_po_scope_count',cardinality(v_scopes),
      'real_po_line_count',v_po.line_count,'real_po_fingerprint',v_before,
      'generated_source_date',v_date,'read_samples_per_scope',1,
      'full_read_elapsed_ms',round(v_full_ms,2),'partial_read_elapsed_ms',round(v_partial_ms,2));
    raise exception using errcode='Z1080',message='Successful acceptance rollback';
  exception when sqlstate 'Z1080' then null;
  end;

  if exists(select 1 from atlas_core.actors where actor_id::text like 'f108%')
    or exists(select 1 from atlas_core.roles where role_code like 'a108%') then
    raise exception 'A108 workload probe identity persisted';
  end if;
  select md5(to_jsonb(po)::text||to_jsonb(revision)::text||
    (select string_agg(to_jsonb(line)::text,'' order by line.purchase_order_line_revision_id)
      from atlas_procurement.purchase_order_line_revisions line
      where line.purchase_order_revision_id=revision.purchase_order_revision_id))
  into v_after from atlas_procurement.purchase_orders po
  join atlas_procurement.purchase_order_revisions revision
    on revision.purchase_order_id=po.purchase_order_id and revision.is_current
  where po.purchase_order_id=v_po.purchase_order_id;
  if v_before is distinct from v_after then raise exception 'A108 real PO changed'; end if;
  insert into pg_temp.a108_report values(v_result||jsonb_build_object(
    'success',true,'probe_rollback_verified',true,'real_po_unchanged',true));
end;
$acceptance$;
select result from pg_temp.a108_report;
rollback;
