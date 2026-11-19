-- New installations and upgrades both start with an empty rule history.
begin;
create temporary table weekly_rule_memberships on commit drop as
select r.rolname, a.set_option from pg_auth_members a join pg_roles r on r.oid = a.roleid
where a.member = current_user::regrole and a.grantor = current_user::regrole
  and r.rolname in ('atlas_read_runtime','atlas_planning_command_runtime');
grant atlas_read_runtime, atlas_planning_command_runtime to postgres with set true;
create temporary table weekly_rule_schema_access on commit drop as
select rolname, has_schema_privilege(rolname,'atlas_api','CREATE') had_create
from pg_roles where rolname in ('atlas_read_runtime','atlas_planning_command_runtime');
grant select on weekly_rule_schema_access to atlas_owner;
set local role atlas_owner;
grant create on schema atlas_api to atlas_read_runtime, atlas_planning_command_runtime;

create table atlas_planning.weekly_pantry_rule_revisions (
  rule_revision_id uuid primary key default gen_random_uuid(),
  rule_id uuid not null,
  school_id uuid not null references atlas_admin.schools,
  ingredient_id uuid not null references atlas_admin.ingredients,
  unit_id uuid not null references atlas_admin.units,
  effective_from date not null check (extract(isodow from effective_from) = 1),
  quantity_per_day numeric(20,6) not null
    check (quantity_per_day > 0 and quantity_per_day * 7 < 100000000000000),
  enabled boolean not null,
  version bigint not null check (version > 0),
  command_receipt_id uuid not null unique references atlas_core.command_receipts,
  unique (school_id, ingredient_id, version)
);
create index weekly_pantry_rule_effectivity on atlas_planning.weekly_pantry_rule_revisions
  (school_id, ingredient_id, effective_from desc, version desc);
alter table atlas_planning.weekly_pantry_rule_revisions enable row level security;
alter table atlas_planning.weekly_pantry_rule_revisions force row level security;
revoke all on atlas_planning.weekly_pantry_rule_revisions from public, anon, authenticated, service_role;
grant select on atlas_planning.weekly_pantry_rule_revisions to atlas_read_runtime, atlas_planning_command_runtime, atlas_need_generation_runtime;
grant insert on atlas_planning.weekly_pantry_rule_revisions to atlas_planning_command_runtime;
create policy weekly_pantry_rule_read on atlas_planning.weekly_pantry_rule_revisions
  for select to atlas_read_runtime, atlas_planning_command_runtime, atlas_need_generation_runtime using (true);
create policy weekly_pantry_rule_append on atlas_planning.weekly_pantry_rule_revisions
  for insert to atlas_planning_command_runtime with check (true);

create function atlas_planning.effective_weekly_pantry_rules(p_week date)
returns setof atlas_planning.weekly_pantry_rule_revisions
language sql stable security invoker set search_path = '' as $$
  select r.* from (
    select distinct on (school_id, ingredient_id) *
    from atlas_planning.weekly_pantry_rule_revisions where effective_from <= p_week
    order by school_id, ingredient_id, effective_from desc, version desc
  ) r where r.enabled;
$$;

create function atlas_planning.weekly_pantry_menu_token(p_week date)
returns text language sql stable security invoker set search_path = '' as $$
  select atlas_core.pantry_02_sha256(coalesce(jsonb_agg(jsonb_build_array(
    week_start, latest_approval_snapshot_id, weekly_menu_status) order by week_start),'[]'))
  from atlas_planning.weekly_menus where week_start >= p_week and latest_approval_snapshot_id is not null;
$$;
revoke all on function atlas_planning.effective_weekly_pantry_rules(date), atlas_planning.weekly_pantry_menu_token(date)
  from public, anon, authenticated, service_role;
grant execute on function atlas_planning.effective_weekly_pantry_rules(date)
  to atlas_read_runtime, atlas_planning_command_runtime, atlas_need_generation_runtime;
grant execute on function atlas_planning.weekly_pantry_menu_token(date)
  to atlas_read_runtime, atlas_planning_command_runtime;

set local role atlas_read_runtime;
create function atlas_api.get_weekly_pantry_rules(request jsonb)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  op constant text := 'get_weekly_pantry_rules';
  p jsonb := request->'payload';
  w date;
  school uuid := atlas_core.pa_05b_safe_uuid(p->>'school_id');
  preview_school uuid := atlas_core.pa_05b_safe_uuid(p#>>'{preview,school_id}');
  rate numeric := atlas_core.pantry_02_safe_quantity(p#>>'{preview,quantity_per_day}');
  ctx jsonb;
  err jsonb;
  rules jsonb;
  menus jsonb;
  days date[];
  preview jsonb;
begin
  err := atlas_core.pantry_02_validate_read_request(request,op,true);
  if err is not null then return err; end if;
  ctx := atlas_core.pantry_02_authorize_global(request,'planning.inputs.read',op);
  if ctx ? 'error' then return ctx->'error'; end if;
  w := (p->>'week_start')::date;
  if (p ? 'school_id' and school is null) or (p ? 'preview' and
     (preview_school is null or (school is not null and school <> preview_school)
      or rate is null or rate * 7 >= 100000000000000)) then
    return atlas_core.pantry_02_read_error(request,op,'VALIDATION_FAILED','Invalid School or daily quantity.');
  end if;

  with dates as (
    select l.school_id, array_agg(distinct l.service_date order by l.service_date) as dates
    from atlas_planning.weekly_menus m join atlas_planning.weekly_menu_approval_snapshot_lines l
      on l.weekly_menu_approval_snapshot_id = m.latest_approval_snapshot_id
    where m.week_start = w and (school is null or l.school_id = school)
    group by l.school_id
  ), heads as (
    select distinct on (r.school_id, r.ingredient_id) r.*
    from atlas_planning.weekly_pantry_rule_revisions r
    where school is null or r.school_id = school
    order by r.school_id, r.ingredient_id, r.version desc
  )
  select coalesce((select jsonb_agg(jsonb_build_object(
    'school_id', h.school_id, 'school_name', s.school_name,
    'ingredient_id', h.ingredient_id, 'ingredient_name', i.ingredient_name,
    'unit_id', u.unit_id, 'unit_name', u.unit_name, 'version', h.version,
    'rule_revision_id', r.rule_revision_id, 'effective_from', r.effective_from,
    'enabled', coalesce(r.enabled,false), 'quantity_per_day', r.quantity_per_day::text,
    'menu_dates', coalesce(d.dates,'{}'), 'delivery_date', case when r.enabled then d.dates[1] end,
    'total_quantity', coalesce(case when r.enabled then r.quantity_per_day * cardinality(d.dates) end,0)::text
  ) order by s.school_name,i.ingredient_name,h.school_id,h.ingredient_id)
  from heads h join atlas_admin.schools s on s.school_id = h.school_id
  join atlas_admin.ingredients i on i.ingredient_id = h.ingredient_id
  left join lateral (
    select rev.* from atlas_planning.weekly_pantry_rule_revisions rev
    where rev.school_id = h.school_id and rev.ingredient_id = h.ingredient_id and rev.effective_from <= w
    order by rev.effective_from desc, rev.version desc limit 1
  ) r on true
  join atlas_admin.units u on u.unit_id = coalesce(r.unit_id,h.unit_id)
  left join dates d on d.school_id = h.school_id),'[]'),
  coalesce((select jsonb_agg(jsonb_build_object('school_id',d.school_id,'menu_dates',d.dates) order by d.school_id) from dates d),'[]'),
  coalesce((select d.dates from dates d where d.school_id = preview_school),'{}')
  into rules, menus, days;
  if p ? 'preview' then
    preview := jsonb_build_object('school_id',preview_school,'menu_dates',days,'delivery_date',days[1],
      'quantity_per_day',rate::text,'total_quantity',(rate * cardinality(days))::text);
  end if;
  return jsonb_build_object('success',true,'contract_version','PANTRY-02.v1','week_start',w,
    'can_manage',atlas_core.pantry_02_actor_has_capability((ctx->>'actor_id')::uuid,'planning.pantry.write'),
    'menu_token',atlas_planning.weekly_pantry_menu_token(w),'rules',rules,'school_menus',menus,'preview',preview);
end;
$$;

set local role atlas_planning_command_runtime;
create function atlas_api.save_weekly_pantry_rule(request jsonb)
returns jsonb language plpgsql volatile security definer set search_path = '' as $$
declare
  op constant text := 'save_weekly_pantry_rule';
  p jsonb := request->'payload';
  w date := atlas_core.pa_05d_safe_date(p->>'week_start');
  school uuid := atlas_core.pa_05b_safe_uuid(p->>'school_id');
  ingredient uuid := atlas_core.pa_05b_safe_uuid(p->>'ingredient_id');
  expected bigint := atlas_core.pa_05b_safe_bigint(request->>'expected_version');
  rate numeric := atlas_core.pantry_02_safe_quantity(p->>'quantity_per_day');
  enabled_rule boolean;
  purchase_unit uuid;
  head atlas_planning.weekly_pantry_rule_revisions%rowtype;
  prior atlas_planning.weekly_pantry_rule_revisions%rowtype;
  saved atlas_planning.weekly_pantry_rule_revisions%rowtype;
  actor uuid;
  receipt uuid;
  result jsonb;
  err jsonb;
  event jsonb;
  affected date[] := '{}';
  affected_week date;
  next_start date;
  previous_receipt text := current_setting('atlas.planning_contract_01_receipt_id',true);
  previous_actor text := current_setting('atlas.planning_contract_01_actor_id',true);
  previous_command text := current_setting('atlas.planning_contract_01_command_name',true);
begin
  -- Zero means a missing rule. Legacy Pantry envelopes and receipts use positive versions.
  err := atlas_core.pantry_02_validate_command_request(case when expected = 0 then
    jsonb_set(request,'{expected_version}','1') else request end,op);
  if err is not null then return err; end if;
  result := atlas_core.pantry_02_authorize_global(request,'planning.pantry.write',op);
  if result ? 'error' then return result->'error'; end if;
  actor := (result->>'actor_id')::uuid;
  if extract(isodow from w) <> 1 or school is null or ingredient is null
     or jsonb_typeof(p->'enabled') is distinct from 'boolean'
     or atlas_core.pa_05b_safe_uuid(p->>'expected_unit_id') is null
     or coalesce(p->>'expected_menu_token','') !~ '^[a-f0-9]{64}$' then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED','Invalid week, School, Ingredient or preview.','PLANNING',op);
  end if;
  enabled_rule := (p->>'enabled')::boolean;
  if enabled_rule and (rate is null or rate * 7 >= 100000000000000) then
    return atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED','Enter a positive daily quantity with up to six decimal places.','PLANNING',op);
  end if;

  perform pg_advisory_xact_lock(hashtextextended('ATLAS-WEEKLY-PANTRY-RULES',0));
  result := atlas_core.pa_05b_begin_command(case when expected = 0 then request - 'expected_version' else request end,
    actor,op,'PLANNING','weekly-pantry-rule:'||school::text||':'||ingredient::text);
  if result->>'status' in ('REPLAY','ERROR') then return result->'response'; end if;
  receipt := (result->>'receipt_id')::uuid;
  select * into head from atlas_planning.weekly_pantry_rule_revisions r
    where r.school_id = school and r.ingredient_id = ingredient order by r.version desc limit 1;
  select * into prior from atlas_planning.weekly_pantry_rule_revisions r
    where r.school_id = school and r.ingredient_id = ingredient and r.effective_from <= w
    order by r.effective_from desc,r.version desc limit 1;
  if expected <> coalesce(head.version,0) or p->>'expected_menu_token' <> atlas_planning.weekly_pantry_menu_token(w) then
    err := atlas_core.pa_05b_command_error(request,'STALE_VERSION','Reload the changed rule or Weekly Menu.','PLANNING',op);
  elsif enabled_rule then
    select i.purchase_unit_id into purchase_unit from atlas_admin.ingredients i join atlas_admin.units u on u.unit_id = i.purchase_unit_id
      cross join atlas_admin.schools s where i.ingredient_id = ingredient and i.ingredient_status = 'ACTIVE'
      and u.unit_status = 'ACTIVE' and s.school_id = school and s.school_status = 'ACTIVE';
    if purchase_unit is null then
      err := atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED','Select an active School and Ingredient with an active purchase unit.','PLANNING',op);
    end if;
  elsif prior.rule_revision_id is null then
    err := atlas_core.pa_05b_command_error(request,'VALIDATION_FAILED','There is no rule to stop for this week.','PLANNING',op);
  else
    purchase_unit := prior.unit_id;
    rate := prior.quantity_per_day;
  end if;
  if err is null and purchase_unit is distinct from (p->>'expected_unit_id')::uuid then
    err := atlas_core.pa_05b_command_error(request,'STALE_VERSION','The purchase unit changed. Reload the rule.','PLANNING',op);
  end if;
  if err is not null then return atlas_core.pa_05b_finish_command(receipt,err,false); end if;

  if (prior.enabled,prior.quantity_per_day,prior.unit_id) is not distinct from (enabled_rule,rate,purchase_unit) then
    saved := prior;
  else
    begin
      insert into atlas_planning.weekly_pantry_rule_revisions
        (rule_id,school_id,ingredient_id,unit_id,effective_from,quantity_per_day,enabled,version,command_receipt_id)
      values(coalesce(head.rule_id,gen_random_uuid()),school,ingredient,purchase_unit,w,rate,enabled_rule,coalesce(head.version,0)+1,receipt)
      returning * into saved;
      select min(r.effective_from) into next_start from atlas_planning.weekly_pantry_rule_revisions r
        where r.school_id = school and r.ingredient_id = ingredient and r.effective_from > w;
      perform set_config('atlas.planning_contract_01_receipt_id',receipt::text,true),
        set_config('atlas.planning_contract_01_actor_id',actor::text,true),
        set_config('atlas.planning_contract_01_command_name',op,true);
      for affected_week in select m.week_start from atlas_planning.weekly_menus m
        where m.week_start >= w and (next_start is null or m.week_start < next_start)
        and exists (select 1 from atlas_planning.weekly_menu_approval_snapshot_lines l
          where l.weekly_menu_approval_snapshot_id = m.latest_approval_snapshot_id and l.school_id = school)
        order by m.week_start
      loop
        err := atlas_core.weekly_pantry_refresh(request,affected_week);
        if err is not null then raise sqlstate 'WP001'; end if;
        affected := array_append(affected,affected_week);
      end loop;
      perform set_config('atlas.planning_contract_01_receipt_id',coalesce(previous_receipt,''),true),
        set_config('atlas.planning_contract_01_actor_id',coalesce(previous_actor,''),true),
        set_config('atlas.planning_contract_01_command_name',coalesce(previous_command,''),true);
      event := atlas_core.rmvp_03a_record_change(request,actor,receipt,'WeeklyPantryRuleChanged','WeeklyPantryRule',
        saved.rule_id,head.version,saved.version,to_jsonb(prior),to_jsonb(saved));
    exception when sqlstate 'WP001' then
      return atlas_core.pa_05b_finish_command(receipt,err,false);
    end;
  end if;
  result := jsonb_build_object('success',true,'contract_version','PANTRY-02.v1','command_id',request->>'command_id',
    'correlation_id',request->>'correlation_id','version',greatest(head.version,saved.version),
    'rule_revision_id',saved.rule_revision_id,'affected_weeks',affected,'event',event);
  return atlas_core.pa_05b_finish_command(receipt,result,true);
end;
$$;
revoke all on function atlas_api.save_weekly_pantry_rule(jsonb) from public,anon,service_role;
grant execute on function atlas_api.save_weekly_pantry_rule(jsonb) to authenticated;
set local role atlas_read_runtime;
revoke all on function atlas_api.get_weekly_pantry_rules(jsonb) from public,anon,service_role;
grant execute on function atlas_api.get_weekly_pantry_rules(jsonb) to authenticated;
set local role atlas_owner;
do $$ declare r record; begin
  for r in select * from pg_temp.weekly_rule_schema_access where not had_create loop
    execute format('revoke create on schema atlas_api from %I',r.rolname);
  end loop;
end $$;
reset role;
do $$ declare r record; begin
  for r in select * from pg_temp.weekly_rule_memberships where not set_option loop
    execute format('grant %I to postgres with set false',r.rolname);
  end loop;
end $$;
notify pgrst,'reload schema';
commit;
