-- Recurring H is a distinct source at the existing Pantry/Need boundary.
begin;
create temporary table weekly_pantry_authoring on commit drop as
select r.rolname,a.set_option from pg_auth_members a join pg_roles r on r.oid=a.roleid
where a.member=current_user::regrole and a.grantor=current_user::regrole
 and r.rolname in ('atlas_owner','atlas_read_runtime','atlas_planning_command_runtime');
grant atlas_owner,atlas_read_runtime,atlas_planning_command_runtime to postgres with set true;
create temporary table weekly_pantry_schema_lease on commit drop as
select n.nspname,r.rolname,has_schema_privilege(r.oid,n.oid,'CREATE') had_create
from pg_namespace n cross join pg_roles r
where n.nspname in ('atlas_core','atlas_planning','atlas_api')
 and r.rolname in ('atlas_read_runtime','atlas_planning_command_runtime');
grant select on weekly_pantry_schema_lease to atlas_owner;
create function pg_temp.patch_weekly_pantry(target regprocedure, anchor text, replacement text, occurrences integer default 1)
returns void language plpgsql as $$
declare definition text := replace(pg_get_functiondef(target),E'\r\n', E'\n');
begin
 if (length(definition)-length(replace(definition,anchor,'')))/length(anchor) <> occurrences then
   raise exception 'Unexpected weekly Pantry anchor in %: %',target,anchor;
 end if;
 execute replace(definition,anchor,replacement);
end $$;
set role atlas_owner;
grant create on schema atlas_core,atlas_planning,atlas_api to atlas_read_runtime,atlas_planning_command_runtime;
alter table atlas_planning.pantry_need_approval_snapshot_lines
 add column weekly_rule_revision_id uuid references atlas_planning.weekly_pantry_rule_revisions(rule_revision_id),
 add column weekly_menu_snapshot_id uuid references atlas_planning.weekly_menu_approval_snapshots(weekly_menu_approval_snapshot_id),
 add column counted_menu_days date[],
 add constraint weekly_pantry_exact_source check (
   case when purpose_code_snapshot='auto_weekly_pantry' then weekly_rule_revision_id is not null
    and weekly_menu_snapshot_id is not null and counted_menu_days is not null
    and cardinality(counted_menu_days) between 1 and 7 and counted_menu_days[1]=service_date
   else weekly_rule_revision_id is null and weekly_menu_snapshot_id is null and counted_menu_days is null end);
create index weekly_pantry_line_rule_idx on atlas_planning.pantry_need_approval_snapshot_lines(weekly_rule_revision_id)
 where weekly_rule_revision_id is not null;
create index weekly_pantry_line_menu_idx on atlas_planning.pantry_need_approval_snapshot_lines(weekly_menu_snapshot_id)
 where weekly_menu_snapshot_id is not null;
reset role;
insert into atlas_planning.pantry_need_purposes
 (pantry_need_purpose_id,purpose_code,purpose_name_vi,purpose_description,note_rule,display_order)
values ('69c413ef-4c9d-4671-b9c5-73a7901cd9f1','auto_weekly_pantry','Hàng đặt riêng tự động',
 'Lượng tính từ định mức của trường và các ngày có thực đơn đã lưu.','PROHIBITED',2147483646);

set role atlas_read_runtime;
create function atlas_planning.weekly_pantry_projection(p_week date,p_menu_rows jsonb default null)
returns table(rule_revision_id uuid,school_id uuid,ingredient_id uuid,unit_id uuid,
 quantity_per_day numeric,menu_days date[],service_date date,quantity numeric)
language sql stable security invoker set search_path='' as $$
 with menu as (
   select l.school_id,l.service_date from atlas_planning.weekly_menus m
   join atlas_planning.weekly_menu_approval_snapshot_lines l on l.weekly_menu_approval_snapshot_id=m.latest_approval_snapshot_id
   where p_menu_rows is null and m.week_start=p_week
   union all
   select atlas_core.pa_05b_safe_uuid(r->>'school_id'),atlas_core.pa_05d_safe_date(r->>'service_date')
   from jsonb_array_elements(p_menu_rows) r
   where atlas_core.pa_05b_safe_uuid(r->>'dish_id') is not null
 ), days as (
   select m.school_id,array_agg(distinct m.service_date order by m.service_date) as dates
   from menu m where m.service_date between p_week and p_week+6 group by m.school_id
 )
 select r.rule_revision_id,r.school_id,r.ingredient_id,r.unit_id,r.quantity_per_day,
        d.dates,d.dates[1],r.quantity_per_day*cardinality(d.dates)
 from atlas_planning.effective_weekly_pantry_rules(p_week) r join days d using(school_id);
$$;
create function atlas_core.weekly_pantry_unit_changed(p_week date) returns boolean
language sql stable security invoker set search_path='' as $$
 select exists(select 1 from atlas_planning.weekly_pantry_projection(p_week) p
  join atlas_admin.ingredients i on i.ingredient_id=p.ingredient_id where p.unit_id is distinct from i.purchase_unit_id);
$$;
revoke all on function atlas_core.weekly_pantry_unit_changed(date) from public,anon,authenticated,service_role;
grant execute on function atlas_core.weekly_pantry_unit_changed(date) to atlas_planning_command_runtime,atlas_owner;
create function atlas_core.weekly_pantry_canonical_rows(p_week date, manual_rows jsonb) returns jsonb
language sql stable security invoker set search_path='' as $$
 select atlas_core.pantry_02_canonical_rows(p_week,
   coalesce((select jsonb_agg(row order by ord) from jsonb_array_elements(manual_rows) with ordinality r(row,ord)
    where atlas_core.pa_05b_safe_uuid(row->>'pantry_need_purpose_id') is distinct from
      '69c413ef-4c9d-4671-b9c5-73a7901cd9f1'::uuid),'[]'::jsonb)
   || coalesce((select jsonb_agg(jsonb_build_object(
      'school_id',p.school_id,'ingredient_id',p.ingredient_id,'service_date',p.service_date,
      'pantry_need_purpose_id','69c413ef-4c9d-4671-b9c5-73a7901cd9f1',
      'requested_quantity',p.quantity,
      'source_request_reference',p.rule_revision_id::text||'/'||array_to_string(p.menu_days,','))
      order by p.school_id,p.ingredient_id) from atlas_planning.weekly_pantry_projection(p_week) p),'[]'::jsonb));
$$;
revoke all on function atlas_planning.weekly_pantry_projection(date,jsonb),atlas_core.weekly_pantry_canonical_rows(date,jsonb)
 from public,anon,authenticated,service_role;
grant execute on function atlas_planning.weekly_pantry_projection(date,jsonb),atlas_core.weekly_pantry_canonical_rows(date,jsonb)
 to atlas_planning_command_runtime,atlas_owner;

-- The operator edits only manual purposes. History retains all contributing lines.
select pg_temp.patch_weekly_pantry('atlas_core.direct_need_legacy_pantry_workbench_payload(date,uuid)',
 $a$where purpose.purpose_status = 'ACTIVE'$a$,$b$where purpose.purpose_status = 'ACTIVE' and purpose.purpose_code <> 'auto_weekly_pantry'$b$,2);
select pg_temp.patch_weekly_pantry('atlas_core.direct_need_legacy_pantry_workbench_payload(date,uuid)',
 $a$where line.pantry_need_batch_id =$a$,$b$where purpose.purpose_code <> 'auto_weekly_pantry' and line.pantry_need_batch_id =$b$,2);
select pg_temp.patch_weekly_pantry('atlas_core.direct_need_legacy_preview_pantry_source(jsonb)',
 $a$canonical_rows := atlas_core.pantry_02_canonical_rows(week_start, rows);$a$,
 $b$canonical_rows := atlas_core.weekly_pantry_canonical_rows(week_start, rows);
  no_additions := no_additions and not exists (
    select 1 from jsonb_array_elements(canonical_rows) r where r->>'purpose_code'='auto_weekly_pantry');$b$);
reset role;

set role atlas_owner;
select pg_temp.patch_weekly_pantry('atlas_core.pantry_02_issues(date,boolean,jsonb)',
 $a$  return pg_catalog.jsonb_build_object(
    'blockers', blockers,$a$,
 $b$  if exists (select 1 from jsonb_array_elements(canonical_rows) r where r->>'purpose_code'='auto_weekly_pantry')
     and atlas_core.weekly_pantry_unit_changed(target_week_start) then
    blockers:=blockers||jsonb_build_array(atlas_core.pantry_02_issue('WEEKLY_PANTRY_UNIT_CHANGED',
      'Đơn vị mua đã thay đổi. Cập nhật định mức hàng đặt riêng theo đơn vị mới trước khi lưu.',null,'unit_id'));
  end if;
  return pg_catalog.jsonb_build_object(
    'blockers', blockers,$b$);
select pg_temp.patch_weekly_pantry('atlas_core.direct_need_canonical_modes(date,jsonb,jsonb)',
 $a$where atlas_core.pantry_02_safe_quantity($a$,$b$where row_value->>'purpose_code' is distinct from 'auto_weekly_pantry'
      and atlas_core.pantry_02_safe_quantity($b$);
reset role;
set role atlas_planning_command_runtime;
create function atlas_planning.weekly_pantry_stamp_snapshot() returns trigger
language plpgsql security invoker set search_path='' as $$
declare p record;
begin
 select x.rule_revision_id,x.menu_days,m.latest_approval_snapshot_id into strict p
 from atlas_planning.pantry_need_batches b join atlas_planning.weekly_menus m using(week_start)
 cross join lateral atlas_planning.weekly_pantry_projection(b.week_start) x
 join atlas_planning.pantry_need_approval_snapshots s on s.pantry_need_batch_id=b.pantry_need_batch_id
 where s.pantry_need_approval_snapshot_id=new.pantry_need_approval_snapshot_id and x.school_id=new.school_id
 and x.ingredient_id=new.ingredient_id and x.unit_id=new.unit_id
 and x.service_date=new.service_date and x.quantity=new.requested_quantity;
 new.weekly_rule_revision_id:=p.rule_revision_id;
 new.weekly_menu_snapshot_id:=p.latest_approval_snapshot_id;
 new.counted_menu_days:=p.menu_days;
 return new;
end $$;
revoke all on function atlas_planning.weekly_pantry_stamp_snapshot() from public,anon,authenticated,service_role;
grant execute on function atlas_planning.weekly_pantry_stamp_snapshot() to atlas_owner;
reset role;
set role atlas_owner;
create trigger weekly_pantry_stamp_snapshot before insert on atlas_planning.pantry_need_approval_snapshot_lines
for each row when (new.purpose_code_snapshot='auto_weekly_pantry') execute function atlas_planning.weekly_pantry_stamp_snapshot();
reset role;
set role atlas_planning_command_runtime;
-- All writers derive generated rows from the saved menu, including the v1 draft API.
select pg_temp.patch_weekly_pantry('atlas_api.save_pantry_draft(jsonb)',
 $a$canonical_rows := atlas_core.pantry_02_canonical_rows(
    week_start,
    proposed_rows
  );$a$,
 $b$canonical_rows := atlas_core.weekly_pantry_canonical_rows(week_start, proposed_rows);
  no_additions := no_additions and not exists (
    select 1 from jsonb_array_elements(canonical_rows) r where r->>'purpose_code'='auto_weekly_pantry');$b$);
select pg_temp.patch_weekly_pantry('atlas_core.issue_222_affected_dates(text,jsonb)',
 'atlas_core.pantry_02_canonical_rows(', 'atlas_core.weekly_pantry_canonical_rows(');
select pg_temp.patch_weekly_pantry('atlas_core.issue_222_affected_dates(text,jsonb)',
 $a$  elsif v_kind = 'ATTENDANCE' then$a$,
 $b$    -- A Friday edit can change the amount already assigned to Tuesday.
    with old_amounts as (
      select school_id,ingredient_id,service_date,quantity from atlas_planning.weekly_pantry_projection(v_week_start)
    ), proposed_amounts as (
      select school_id,ingredient_id,service_date,quantity from atlas_planning.weekly_pantry_projection(v_week_start,v_rows)
    ), changed as (
      (table old_amounts except table proposed_amounts)
      union (table proposed_amounts except table old_amounts)
    ), affected as (
      select unnest(v_dates) service_date union select service_date from changed
      union select run.period_start from atlas_planning.need_generation_runs run
        join atlas_planning.planning_input_evaluations e using(planning_input_evaluation_id)
        where exists(select 1 from changed) and e.pantry_absent and run.run_status<>'INVALIDATED'
         and run.period_start between v_week_start and v_week_start+6
    )
    select coalesce(array_agg(service_date order by service_date),'{}'::date[]) into v_dates from affected;
  elsif v_kind = 'ATTENDANCE' then$b$);
select pg_temp.patch_weekly_pantry('atlas_core.issue_222_enforce_source_save(jsonb,text,text,text,text)',
 'atlas_core.pantry_02_canonical_rows(', 'atlas_core.weekly_pantry_canonical_rows(');
select pg_temp.patch_weekly_pantry('atlas_core.issue_222_enforce_source_save(jsonb,text,text,text,text)',
 $a$    v_claimed_signature := atlas_core.pantry_02_normalize_text($a$,
 $b$    v_no_additions := v_no_additions and not exists (
      select 1 from jsonb_array_elements(v_rows) r where r->>'purpose_code'='auto_weekly_pantry');
    v_claimed_signature := atlas_core.pantry_02_normalize_text($b$);

-- Reuse the same lock order and released-document checks for rule/menu-driven Pantry changes.
do $body$
declare target regprocedure:='atlas_core.issue_222_enforce_source_save(jsonb,text,text,text,text)';
 definition text:=replace(pg_get_functiondef(target),E'\r\n', E'\n');
 start_pos integer:=position('  v_dates := atlas_core.issue_222_affected_dates(' in definition);
 end_pos integer:=position('  return null;' in substring(definition from start_pos));
 guard_body text:=substring(definition from start_pos for end_pos+length('  return null;')-1);
begin
 if start_pos=0 or end_pos=0 or position('for v_run_id in' in guard_body)=0 then raise exception 'Missing Planning correction guard'; end if;
 execute 'create function atlas_core.weekly_pantry_guard(request jsonb,source_kind text,command_name text,contract_version text,v_source_payload jsonb)
 returns jsonb language plpgsql volatile security invoker set search_path='''' as $fn$
 declare v_dates date[]; v_run_id uuid; v_impact jsonb; begin '||guard_body||' end; $fn$';
 execute replace(definition,guard_body,'  return atlas_core.weekly_pantry_guard(request,source_kind,command_name,contract_version,v_source_payload);');
end $body$;
revoke all on function atlas_core.weekly_pantry_guard(jsonb,text,text,text,jsonb) from public,anon,authenticated,service_role;
select pg_temp.patch_weekly_pantry('atlas_core.issue_222_enforce_source_save(jsonb,text,text,text,text)',
 $a$  if source_kind='PANTRY' then
  perform pg_catalog.pg_advisory_xact_lock$a$,
 $b$  if source_kind='WEEKLY_MENU' then
    perform pg_advisory_xact_lock_shared(hashtextextended('ATLAS-WEEKLY-PANTRY-RULES',0));
  end if;
  if source_kind in ('WEEKLY_MENU','PANTRY') then
  perform pg_catalog.pg_advisory_xact_lock$b$);

-- A retry on a week with generated Pantry evidence returns its original receipt
-- even if Tuesday was subsequently released. Authorization already ran above.
select pg_temp.patch_weekly_pantry('atlas_core.issue_222_enforce_source_save(jsonb,text,text,text,text)',
 $a$  return atlas_core.weekly_pantry_guard(request,source_kind,command_name,contract_version,v_source_payload);$a$,
 $b$  if source_kind='WEEKLY_MENU' and exists (
      select 1 from atlas_planning.pantry_need_batches b
      join atlas_planning.pantry_need_approval_snapshots s using(pantry_need_batch_id)
      join atlas_planning.pantry_need_approval_snapshot_lines l using(pantry_need_approval_snapshot_id)
      where b.week_start=v_week_start and l.weekly_rule_revision_id is not null)
    and exists(select 1 from atlas_core.command_receipts r
      where r.command_id=atlas_core.pa_05b_safe_uuid(request->>'command_id')
        or (r.command_name=issue_222_enforce_source_save.command_name and r.idempotency_key=request->>'idempotency_key'
           and r.scope_key=(atlas_core.pa_05b_resolve_actor(request,'PLANNING',issue_222_enforce_source_save.command_name)->>'actor_id')
             ||':weekly-menu:'||v_week_start::text)) then
    v_impact:=atlas_core.planning_contract_01_prepare_top_command(request,command_name,contract_version,
      capability_code,'weekly-menu:'||v_week_start::text);
    if v_impact->>'status'='RETURN' then
      return (v_impact->'response')||jsonb_build_object('contract_version',contract_version);
    end if;
    raise exception 'Existing Weekly Menu receipt did not resolve';
  end if;
  return atlas_core.weekly_pantry_guard(request,source_kind,command_name,contract_version,v_source_payload);$b$);
select pg_temp.patch_weekly_pantry('atlas_core.issue_222_save_pantry_impl(jsonb)',
 'atlas_core.pantry_02_canonical_rows(', 'atlas_core.weekly_pantry_canonical_rows(');
select pg_temp.patch_weekly_pantry('atlas_core.issue_222_save_pantry_impl(jsonb)',
 $a$  v_modes := atlas_core.direct_need_canonical_modes($a$,
 $b$  v_no_additions := v_no_additions and not exists (
    select 1 from jsonb_array_elements(v_rows) r where r->>'purpose_code'='auto_weekly_pantry');
  v_modes := atlas_core.direct_need_canonical_modes($b$);

-- Keep manual provenance byte-for-byte during an automatic refresh. Omitted
-- manual lines still follow the existing complete-replacement contract.
select pg_temp.patch_weekly_pantry('atlas_api.save_pantry_draft(jsonb)',
 $a$and line.line_status = 'ACTIVE';$a$,
 $b$and line.line_status = 'ACTIVE' and not exists (
      select 1 from jsonb_array_elements(canonical_rows) r
      where line.service_date=(r->>'service_date')::date and line.school_id=(r->>'school_id')::uuid
       and line.ingredient_id=(r->>'ingredient_id')::uuid and line.delivery_location_id=(r->>'delivery_location_id')::uuid
       and line.pantry_need_purpose_id=(r->>'pantry_need_purpose_id')::uuid);$b$);
select pg_temp.patch_weekly_pantry('atlas_api.save_pantry_draft(jsonb)',
 $a$updated_by_actor_id = excluded.updated_by_actor_id,
      updated_at = pg_catalog.transaction_timestamp();$a$,
 $b$updated_by_actor_id = excluded.updated_by_actor_id,
      updated_at = pg_catalog.transaction_timestamp()
    where (pantry_need_lines.unit_id,pantry_need_lines.requested_quantity,pantry_need_lines.note,
       pantry_need_lines.source_request_reference,pantry_need_lines.source_row_reference,pantry_need_lines.line_status)
      is distinct from (excluded.unit_id,excluded.requested_quantity,excluded.note,
       excluded.source_request_reference,excluded.source_row_reference,excluded.line_status);$b$);

-- A private child command reuses the Pantry lifecycle and gets its own receipt.
-- Its caller has already authorized the parent Menu approval or rule command and
-- constructs all rows from database facts. Browser APIs only use the original overload.
do $body$
declare target regprocedure:='atlas_core.issue_222_save_pantry_impl(jsonb)';
 definition text:=replace(pg_get_functiondef(target),E'\r\n', E'\n');
 anchor text:=$a$  v_prepare := atlas_core.planning_contract_01_prepare_top_command(
    request, v_name, v_contract, 'planning.pantry.write',
    'pantry:' || v_week_start::text
  );$a$;
begin
 if position(anchor in definition)=0 then raise exception 'Missing Pantry receipt boundary'; end if;
 definition:=replace(definition,'issue_222_save_pantry_impl(request jsonb)','issue_222_save_pantry_impl(request jsonb, parent_actor uuid)');
 execute replace(definition,anchor,
 '  if parent_actor is null then '||anchor||$b$
  else
    v_prepare:=atlas_core.pa_05b_begin_command(request,parent_actor,v_name,'PLANNING','pantry:'||v_week_start::text);
    if v_prepare->>'status' in ('REPLAY','ERROR') then return v_prepare->'response'; end if;
    v_prepare:=v_prepare||jsonb_build_object('actor_id',parent_actor);
  end if;$b$);
end $body$;
-- Child refreshes have no authority over manually authored scope modes.
select pg_temp.patch_weekly_pantry('atlas_core.issue_222_save_pantry_impl(jsonb,uuid)',
 $a$    perform atlas_core.direct_need_replace_modes(
      v_week_start, v_rows, v_modes, v_actor_id
    );$a$,
 $b$    if parent_actor is null then
      perform atlas_core.direct_need_replace_modes(v_week_start,v_rows,v_modes,v_actor_id);
    end if;$b$);
create or replace function atlas_core.issue_222_save_pantry_impl(request jsonb)
returns jsonb language sql volatile security definer set search_path='' as $$
 select atlas_core.issue_222_save_pantry_impl(request,null::uuid);
$$;
revoke all on function atlas_core.issue_222_save_pantry_impl(jsonb,uuid) from public,anon,authenticated,service_role;

create function atlas_core.weekly_pantry_refresh(request jsonb, week_start date) returns jsonb
language plpgsql volatile security invoker set search_path='' as $$
declare
 b atlas_planning.pantry_need_batches%rowtype;
 manual_rows jsonb; canonical_rows jsonb; modes jsonb; signature text; payload jsonb;
 result jsonb; command_id uuid:=gen_random_uuid(); parent_actor uuid; parent_name text;
 old_receipt text:=current_setting('atlas.planning_contract_01_receipt_id',true);
 old_actor text:=current_setting('atlas.planning_contract_01_actor_id',true);
 old_name text:=current_setting('atlas.planning_contract_01_command_name',true);
begin
 perform pg_advisory_xact_lock(hashtextextended('ATLAS-PANTRY-WEEK:'||week_start::text,0));
 select batch.* into b from atlas_planning.pantry_need_batches batch where batch.week_start=$2 for update;
 if not exists(select 1 from atlas_planning.weekly_pantry_projection($2))
   and not exists(select 1 from atlas_planning.pantry_need_lines l where l.pantry_need_batch_id=b.pantry_need_batch_id
    and l.line_status='ACTIVE' and l.pantry_need_purpose_id='69c413ef-4c9d-4671-b9c5-73a7901cd9f1') then return null; end if;
 select coalesce(jsonb_agg(jsonb_build_object('service_date',l.service_date,'school_id',l.school_id,'ingredient_id',l.ingredient_id,
  'pantry_need_purpose_id',l.pantry_need_purpose_id,'requested_quantity',l.requested_quantity,'note',l.note,
  'source_request_reference',l.source_request_reference,'source_row_reference',l.source_row_reference)
  order by l.pantry_need_line_id),'[]') into manual_rows
 from atlas_planning.pantry_need_lines l where l.pantry_need_batch_id=b.pantry_need_batch_id and l.line_status='ACTIVE'
 and l.pantry_need_purpose_id<>'69c413ef-4c9d-4671-b9c5-73a7901cd9f1';
 canonical_rows:=atlas_core.weekly_pantry_canonical_rows($2,manual_rows);
 signature:=atlas_core.pantry_02_signature($2,canonical_rows='[]'::jsonb,canonical_rows);
 if signature=b.source_signature then return null; end if;
 select receipt.actor_id,receipt.command_name into strict parent_actor,parent_name from atlas_core.command_receipts receipt
 where receipt.command_id=atlas_core.pa_05b_safe_uuid(request->>'command_id') and receipt.outcome='IN_PROGRESS'
  and receipt.command_name in ('save_weekly_menu','approve_weekly_menu','save_weekly_pantry_rule');
 if atlas_core.weekly_pantry_unit_changed($2) then
   return atlas_core.pa_05b_command_error(request,'WEEKLY_PANTRY_UNIT_CHANGED',
    'Đơn vị mua đã thay đổi. Cập nhật định mức hàng đặt riêng theo đơn vị mới trước khi lưu.','PLANNING',parent_name);
 end if;
 if exists(select 1 from atlas_planning.pantry_need_lines l
   left join atlas_admin.schools s on s.school_id=l.school_id
   left join atlas_admin.ingredients i on i.ingredient_id=l.ingredient_id
   where l.pantry_need_batch_id=b.pantry_need_batch_id and l.line_status='ACTIVE'
    and l.pantry_need_purpose_id<>'69c413ef-4c9d-4671-b9c5-73a7901cd9f1'
    and (l.delivery_location_id,l.unit_id) is distinct from (s.default_delivery_location_id,i.purchase_unit_id)) then
   return atlas_core.pa_05b_command_error(request,'STALE_SOURCE_SIGNATURE',
    'Điểm giao hoặc đơn vị mua của dòng nhập tay đã thay đổi. Kiểm tra và lưu lại nguồn trước.','PLANNING',parent_name);
 end if;
 if b.pantry_need_batch_status is not null and b.pantry_need_batch_status<>'APPROVED' then
   return atlas_core.pa_05b_command_error(request,'PANTRY_DRAFT_IN_PROGRESS',
    'Tuần này có bản nháp Hàng đặt riêng. Hoàn tất bản nháp rồi lưu lại thay đổi.','PLANNING',parent_name);
 end if;
 select coalesce(jsonb_agg(jsonb_build_object('school_id',r.school_id,'service_date',r.service_date,
  'direct_need_mode',coalesce(m.direct_need_mode,'ADDITIVE')) order by r.school_id,r.service_date),'[]') into modes
 from (select distinct l.school_id,l.service_date from atlas_planning.pantry_need_lines l
   where l.pantry_need_batch_id=b.pantry_need_batch_id and l.line_status='ACTIVE'
   and l.pantry_need_purpose_id<>'69c413ef-4c9d-4671-b9c5-73a7901cd9f1') r
 left join atlas_planning.pantry_need_school_date_modes m on m.pantry_need_batch_id=b.pantry_need_batch_id
  and m.school_id=r.school_id and m.service_date=r.service_date;
 payload:=jsonb_build_object('week_start',$2,'no_additions_confirmed',canonical_rows='[]'::jsonb,
   'source_signature',signature,'expected_source_signature',b.source_signature,'rows',manual_rows,'school_date_modes',modes);
 result:=atlas_core.weekly_pantry_guard(request,'PANTRY',parent_name,request->>'contract_version',payload);
 if result is not null then return result; end if;
 result:=atlas_core.issue_222_save_pantry_impl(
   atlas_core.planning_contract_01_legacy_request(request,'PANTRY-02.v3',coalesce(b.version,1),'SOURCE_CORRECTION',
    'Cập nhật lượng hàng đặt riêng theo thực đơn.',payload)
   ||jsonb_build_object('command_id',command_id,'idempotency_key',command_id::text),parent_actor);
 perform set_config('atlas.planning_contract_01_receipt_id',coalesce(old_receipt,''),true),
         set_config('atlas.planning_contract_01_actor_id',coalesce(old_actor,''),true),
         set_config('atlas.planning_contract_01_command_name',coalesce(old_name,''),true);
 if result->>'success' is distinct from 'true' then return result; end if;
 return null;
end $$;
revoke all on function atlas_core.weekly_pantry_refresh(jsonb,date) from public,anon,authenticated,service_role;
-- A legacy approval also acquires the week lock before reading its menu.
select pg_temp.patch_weekly_pantry('atlas_api.approve_weekly_menu(jsonb)',
 $a$  select *
    into v_menu$a$,
 $b$  perform pg_advisory_xact_lock_shared(hashtextextended('ATLAS-WEEKLY-PANTRY-RULES',0));
  perform pg_advisory_xact_lock(hashtextextended('ATLAS-PANTRY-WEEK:'||v_week_start::text,0));
  select *
    into v_menu$b$);
select pg_temp.patch_weekly_pantry('atlas_api.approve_weekly_menu(jsonb)',
 $a$  return atlas_core.rmvp_03a_finish_success($a$,
 $b$  v_issues:=atlas_core.weekly_pantry_refresh(request,v_week_start);
  if v_issues is not null then raise sqlstate 'PWP01'; end if;
  return atlas_core.rmvp_03a_finish_success($b$);
select pg_temp.patch_weekly_pantry('atlas_api.approve_weekly_menu(jsonb)',
 $a$exception
  when serialization_failure$a$,
 $b$exception
  when sqlstate 'PWP01' then return v_issues;
  when serialization_failure$b$);
reset role;
set role atlas_owner;
do $$ declare l record; begin
 for l in select * from pg_temp.weekly_pantry_schema_lease where not had_create loop
  execute format('revoke create on schema %I from %I',l.nspname,l.rolname);
 end loop;
end $$;
reset role;
do $$ declare l record; begin
 for l in select * from weekly_pantry_authoring where not set_option loop
  execute format('grant %I to postgres with set false',l.rolname);
 end loop;
end $$;
commit;
