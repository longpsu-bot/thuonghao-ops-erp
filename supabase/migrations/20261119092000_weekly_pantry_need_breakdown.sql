-- Keep automatic deliveries separate in exact grouped Need evidence.
begin;
create temporary table weekly_pantry_breakdown_lease on commit drop as
select r.rolname,a.set_option from pg_roles r join pg_auth_members a on a.roleid=r.oid
where a.member=(select oid from pg_roles where rolname=current_user)
and a.grantor=(select oid from pg_roles where rolname=current_user)
and r.rolname in('atlas_owner','atlas_need_generation_runtime');
do $$ begin
 if (select count(*) from weekly_pantry_breakdown_lease)<>2 then raise exception 'Expected inherited B1 read authoring memberships'; end if;
end $$;
grant atlas_owner,atlas_need_generation_runtime to postgres with set true;
create temporary table weekly_pantry_breakdown_schema_lease on commit drop as
select has_schema_privilege('atlas_need_generation_runtime','atlas_core','CREATE') as had_create;
grant select on weekly_pantry_breakdown_schema_lease to atlas_owner;
set role atlas_owner;
grant create on schema atlas_core to atlas_need_generation_runtime;
reset role;
set role atlas_need_generation_runtime;
do $patch$
declare
  definition text := replace(pg_get_functiondef('atlas_core.rmvp_04_workbench_payload(date,date,uuid,jsonb,integer,integer,jsonb)'::regprocedure), E'\r\n', E'\n');
  patch record;
begin
  for patch in select * from (values
    ($old$'pantry_source_reference', pantry.source_request_reference,$old$,
     $new$'pantry_source_reference', pantry.source_request_reference,
          'counted_menu_days', pantry.counted_menu_days,
          'quantity_per_menu_day', (select r.quantity_per_day::text
            from atlas_planning.weekly_pantry_rule_revisions r
            where r.rule_revision_id = pantry.weekly_rule_revision_id),$new$),
    ($old$) as special_order_quantity,$old$,
     $new$) as special_order_quantity,
        sum(line.theoretical_quantity) filter (
          where line.contribution_family = 'PANTRY_DIRECT'
            and line.purpose_code_snapshot = 'auto_weekly_pantry'
        ) as automatic_pantry_quantity,$new$),
    ($old$('planning_identified_supplement','school_requested_supplement')$old$,
     $new$('planning_identified_supplement','school_requested_supplement','auto_weekly_pantry')$new$),
    ($old$'special_order_quantity', coalesce(page.special_order_quantity,0)::text,$old$,
     $new$'special_order_quantity', coalesce(page.special_order_quantity,0)::text,
          'automatic_pantry_quantity', coalesce(page.automatic_pantry_quantity,0)::text,$new$)
  ) as edits(original,replacement) loop
    if cardinality(string_to_array(definition,patch.original)) <> 2 then
      raise exception 'Weekly pantry source disclosure anchor changed: %',patch.original;
    end if;
    definition := replace(definition,patch.original,patch.replacement);
  end loop;
  execute definition;
end $patch$;
reset role;
set role atlas_owner;
do $$ begin
 if not(select had_create from weekly_pantry_breakdown_schema_lease) then
  revoke create on schema atlas_core from atlas_need_generation_runtime;
 end if;
end $$;
reset role;
do $$ declare membership record; begin
 for membership in select * from weekly_pantry_breakdown_lease loop
  execute format('grant %I to postgres with set %s',membership.rolname,case when membership.set_option then 'true' else 'false' end);
 end loop;
end $$;
commit;
