-- Owner #400 amendment6249057414: additive R/B/H disclosure, no source rewrite.
begin;
create temporary table b1_product_lease on commit drop as
select r.rolname,a.set_option from pg_roles r join pg_auth_members a on a.roleid=r.oid
where a.member=(select oid from pg_roles where rolname=current_user)
and a.grantor=(select oid from pg_roles where rolname=current_user)
and r.rolname in('atlas_owner','atlas_need_generation_runtime');
do $$ begin
 if (select count(*) from b1_product_lease)<>2 then raise exception 'Expected inherited B1 read authoring memberships'; end if;
end $$;
grant atlas_owner,atlas_need_generation_runtime to postgres with set true;
create temporary table b1_product_schema_lease on commit drop as
select has_schema_privilege('atlas_need_generation_runtime','atlas_core','CREATE') as had_create;
grant select on b1_product_schema_lease to atlas_owner;
set role atlas_owner;
grant create on schema atlas_core to atlas_need_generation_runtime;
reset role;
set role atlas_need_generation_runtime;
do $patch$
declare definition text; change record;
begin
 definition:=pg_get_functiondef('atlas_core.rmvp_04_workbench_payload(date,date,uuid,jsonb,integer,integer,jsonb)'::regprocedure);
 for change in select * from (values
 (1,$old$        school.school_name,
        coalesce($old$,
 $new$        school.school_name,
        pantry.purpose_code_snapshot,
        coalesce($new$),
 (1,$old$      join atlas_admin.schools as school on school.school_id = line.school_id
      left join atlas_planning.confirmed_need_line_revision_contributions as contribution$old$,
 $new$      join atlas_admin.schools as school on school.school_id = line.school_id
      left join atlas_planning.pantry_need_approval_snapshot_lines as pantry
        on pantry.pantry_need_approval_snapshot_id = line.pantry_need_approval_snapshot_id
       and pantry.pantry_need_line_id = line.pantry_need_line_id
      left join atlas_planning.confirmed_need_line_revision_contributions as contribution$new$),
 (2,$old$      left join atlas_planning.confirmed_need_line_revision_contributions as contribution
        on contribution.theoretical_need_line_id = line.theoretical_need_line_id
       and contribution.need_generation_run_id = line.need_generation_run_id$old$,
 $new$      left join lateral (
        select membership.*
        from atlas_planning.confirmed_need_line_revision_contributions as membership
        join atlas_planning.confirmed_need_line_revisions as bound_revision
          on bound_revision.confirmed_need_line_revision_id = membership.confirmed_need_line_revision_id
        where membership.theoretical_need_line_id = line.theoretical_need_line_id
          and membership.need_generation_run_id = line.need_generation_run_id
          and (v_confirmed.confirmed_need_batch_id is null
            or membership.confirmed_need_batch_id = v_confirmed.confirmed_need_batch_id)
        order by bound_revision.is_current desc, bound_revision.revision_number desc,
          membership.confirmed_need_line_revision_contribution_id
        limit 1
      ) as contribution on true$new$),
 (1,$old$        ) as pantry_direct_quantity,
        count(*) filter$old$,
 $new$        ) as pantry_direct_quantity,
        sum(line.theoretical_quantity) filter (
          where line.contribution_family = 'PANTRY_DIRECT'
            and line.purpose_code_snapshot = 'planning_identified_supplement'
        ) as planning_supplement_quantity,
        sum(line.theoretical_quantity) filter (
          where line.contribution_family = 'RECIPE_DERIVED'
            or (line.contribution_family = 'PANTRY_DIRECT'
              and line.purpose_code_snapshot = 'planning_identified_supplement')
        ) as recipe_associated_quantity,
        sum(line.theoretical_quantity) filter (
          where line.contribution_family = 'PANTRY_DIRECT'
            and line.purpose_code_snapshot = 'school_requested_supplement'
        ) as special_order_quantity,
        sum(line.theoretical_quantity) filter (
          where line.contribution_family = 'PANTRY_DIRECT'
            and coalesce(line.purpose_code_snapshot,'') not in
              ('planning_identified_supplement','school_requested_supplement')
        ) as unclassified_direct_quantity,
        count(*) filter$new$),
 (1,$old$        'pantry_direct_quantity', coalesce(page.pantry_direct_quantity, 0),$old$,
 $new$        'pantry_direct_quantity', coalesce(page.pantry_direct_quantity, 0),
        'source_breakdown', pg_catalog.jsonb_build_object(
          'recipe_derived_quantity', coalesce(page.recipe_derived_quantity,0)::text,
          'planning_supplement_quantity', coalesce(page.planning_supplement_quantity,0)::text,
          'recipe_associated_quantity', coalesce(page.recipe_associated_quantity,0)::text,
          'special_order_quantity', coalesce(page.special_order_quantity,0)::text,
          'unclassified_direct_quantity', coalesce(page.unclassified_direct_quantity,0)::text,
          'total_theoretical_quantity', page.total_theoretical_quantity::text
        ),$new$),
 (1,$old$          'theoretical_quantity', line.theoretical_quantity,$old$,
 $new$          'theoretical_quantity', line.theoretical_quantity,
          'exact_theoretical_quantity', line.theoretical_quantity::text,$new$),
 (1,$old$          'recipe_id', line.recipe_id,$old$,
 $new$          'recipe_id', line.recipe_id,
          'recipe_version_id', line.recipe_version_id,
          'recipe_line_id', line.recipe_line_id,
          'recipe_line_revision_id', line.recipe_line_revision_id,
          'need_generation_recipe_line_use_id', line.need_generation_recipe_line_use_id,
          'pantry_need_line_id', line.pantry_need_line_id,
          'pantry_need_approval_snapshot_id', line.pantry_need_approval_snapshot_id,
          'pantry_need_purpose_id', pantry.pantry_need_purpose_id,
          'pantry_purpose_code', pantry.purpose_code_snapshot,$new$)
 ) as patches(expected_count,old_text,new_text) loop
  if (length(definition)-length(replace(definition,change.old_text,'')))/length(change.old_text)<>change.expected_count then
   raise exception 'B1 read inherited anchor changed: %',change.old_text;
  end if;
  definition:=replace(definition,change.old_text,change.new_text);
 end loop;
 execute definition;
end $patch$;
reset role;
set role atlas_owner;
do $$ begin
 if not(select had_create from b1_product_schema_lease) then
  revoke create on schema atlas_core from atlas_need_generation_runtime;
 end if;
end $$;
reset role;
do $$ declare membership record; begin
 for membership in select * from b1_product_lease loop
  execute format('grant %I to postgres with set %s',membership.rolname,case when membership.set_option then 'true' else 'false' end);
 end loop;
end $$;
commit;
