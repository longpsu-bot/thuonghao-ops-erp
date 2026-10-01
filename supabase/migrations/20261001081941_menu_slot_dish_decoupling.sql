-- MENU-SLOT-DISH-DECOUPLING-01: slot is assignment context, not Dish eligibility.
-- Predecessor: 20260727150000 plus Recipe-readiness amendment 20260904042117.
-- CREATE OR REPLACE retains the existing owner and ACL; no data or schema rewrite.
begin;

create or replace function atlas_core.rmvp_03a_menu_issues(
  week_start date,
  rows jsonb
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with canonical as (
    select value as row
    from pg_catalog.jsonb_array_elements(
      atlas_core.rmvp_03a_canonical_menu_rows(rows)
    )
  ),
  issues as (
    select
      'BLOCKER'::text as severity,
      'EMPTY_WEEKLY_MENU'::text as code,
      'The weekly menu contains no meaningful assignment.'::text as message,
      null::text as source_row_reference
    where not exists (select 1 from canonical)
    union all
    select
      'BLOCKER', 'INVALID_SCHOOL_ID',
      'A row does not identify a valid school.',
      row ->> 'source_row_reference'
    from canonical
    where atlas_core.pa_05b_safe_uuid(row ->> 'school_id') is null
    union all
    select
      'BLOCKER', 'INVALID_SERVICE_DATE',
      'A row does not contain a valid ISO service date.',
      row ->> 'source_row_reference'
    from canonical
    where atlas_core.pa_05d_safe_date(row ->> 'service_date') is null
    union all
    select
      'BLOCKER', 'SERVICE_DATE_OUTSIDE_WEEK',
      'A menu assignment falls outside the selected service week.',
      row ->> 'source_row_reference'
    from canonical
    where atlas_core.pa_05d_safe_date(row ->> 'service_date') is not null
      and atlas_core.pa_05d_safe_date(row ->> 'service_date')
        not between week_start and week_start + 6
    union all
    select
      'BLOCKER', 'UNKNOWN_DISH_TYPE',
      'A row references a Dish Type that does not exist.',
      row ->> 'source_row_reference'
    from canonical
    where not exists (
      select 1
      from atlas_admin.dish_types dish_type
      where dish_type.dish_type_code = row ->> 'menu_slot_code'
    )
    union all
    select
      'BLOCKER', 'INACTIVE_DISH_TYPE',
      'A row references an inactive Dish Type.',
      row ->> 'source_row_reference'
    from canonical
    join atlas_admin.dish_types dish_type
      on dish_type.dish_type_code = row ->> 'menu_slot_code'
    where dish_type.dish_type_status <> 'ACTIVE'
    union all
    select
      'BLOCKER', 'INVALID_DISH_ID',
      'A row does not identify a valid dish.',
      row ->> 'source_row_reference'
    from canonical
    where atlas_core.pa_05b_safe_uuid(row ->> 'dish_id') is null
    union all
    select
      'BLOCKER', 'UNKNOWN_SCHOOL',
      'A row references a school that does not exist.',
      row ->> 'source_row_reference'
    from canonical
    where atlas_core.pa_05b_safe_uuid(row ->> 'school_id') is not null
      and not exists (
        select 1
        from atlas_admin.schools school
        where school.school_id =
          atlas_core.pa_05b_safe_uuid(row ->> 'school_id')
      )
    union all
    select
      'BLOCKER', 'INACTIVE_SCHOOL',
      'A row references an inactive school.',
      row ->> 'source_row_reference'
    from canonical
    join atlas_admin.schools school
      on school.school_id =
        atlas_core.pa_05b_safe_uuid(row ->> 'school_id')
    where school.school_status <> 'ACTIVE'
    union all
    select
      'BLOCKER', 'UNKNOWN_DISH',
      'A row references a dish that does not exist.',
      row ->> 'source_row_reference'
    from canonical
    where atlas_core.pa_05b_safe_uuid(row ->> 'dish_id') is not null
      and not exists (
        select 1
        from atlas_admin.dishes dish
        where dish.dish_id =
          atlas_core.pa_05b_safe_uuid(row ->> 'dish_id')
      )
    union all
    select
      'BLOCKER', 'INACTIVE_DISH',
      'A row references an inactive dish.',
      row ->> 'source_row_reference'
    from canonical
    join atlas_admin.dishes dish
      on dish.dish_id =
        atlas_core.pa_05b_safe_uuid(row ->> 'dish_id')
    where dish.dish_status <> 'ACTIVE'
    union all
    select
      'BLOCKER', 'DUPLICATE_MENU_ASSIGNMENT',
      'The same school, date, and menu slot appears more than once.',
      pg_catalog.min(row ->> 'source_row_reference')
    from canonical
    group by
      row ->> 'school_id',
      row ->> 'service_date',
      row ->> 'menu_slot_code'
    having count(*) > 1
    union all
    select
      'WARNING', 'RECIPE_NOT_READY',
      'The assigned dish has no released active recipe for this school type.',
      row ->> 'source_row_reference'
    from canonical
    join atlas_admin.schools school
      on school.school_id =
        atlas_core.pa_05b_safe_uuid(row ->> 'school_id')
     and school.school_status = 'ACTIVE'
    join atlas_admin.dishes dish
      on dish.dish_id =
        atlas_core.pa_05b_safe_uuid(row ->> 'dish_id')
     and dish.dish_status = 'ACTIVE'
    where not exists (
        select 1
        from atlas_admin.recipes recipe
        join atlas_admin.recipe_versions version
          on version.recipe_id = recipe.recipe_id
        where recipe.dish_id = dish.dish_id
          and recipe.recipe_status = 'ACTIVE'
          and version.recipe_version_status = 'RELEASED_FOR_PLANNING'
          and (
            recipe.school_type_id is null
            or recipe.school_type_id = school.school_type_id
          )
      )
    union all
    select
      'WARNING', 'EFFECTIVE_BOM_BLOCKED',
      'Effective Recipe composition is currently blocked for this assignment.',
      row ->> 'source_row_reference'
    from canonical
    join atlas_admin.schools school
      on school.school_id =
        atlas_core.pa_05b_safe_uuid(row ->> 'school_id')
     and school.school_status = 'ACTIVE'
    join atlas_admin.dishes dish
      on dish.dish_id =
        atlas_core.pa_05b_safe_uuid(row ->> 'dish_id')
     and dish.dish_status = 'ACTIVE'
    cross join lateral (
      select atlas_core.rmvp_02b_resolve_effective_composition(
        atlas_core.pa_05d_safe_date(row ->> 'service_date'),
        school.school_id,
        dish.dish_id,
        null,
        null,
        null
      ) as result
    ) resolution
    where resolution.result ->> 'status' = 'BLOCKED'
    union all
    select
      'WARNING', 'SUSPICIOUS_DUPLICATE_DISH',
      'The same dish is assigned to multiple slots for one school and date.',
      pg_catalog.min(row ->> 'source_row_reference')
    from canonical
    group by
      row ->> 'school_id',
      row ->> 'service_date',
      row ->> 'dish_id'
    having count(distinct row ->> 'menu_slot_code') > 1
    union all
    select
      'WARNING', 'DIFFERS_FROM_APPROVED_MENU',
      'This assignment differs from the latest approved snapshot.',
      row ->> 'source_row_reference'
    from canonical
    join atlas_planning.weekly_menus menu
      on menu.week_start = $1
     and menu.latest_approval_snapshot_id is not null
    left join atlas_planning.weekly_menu_approval_snapshot_lines approved
      on approved.weekly_menu_approval_snapshot_id =
          menu.latest_approval_snapshot_id
     and approved.school_id =
          atlas_core.pa_05b_safe_uuid(row ->> 'school_id')
     and approved.service_date =
          atlas_core.pa_05d_safe_date(row ->> 'service_date')
     and approved.menu_slot_code = row ->> 'menu_slot_code'
    where approved.weekly_menu_line_id is null
       or approved.dish_id is distinct from
          atlas_core.pa_05b_safe_uuid(row ->> 'dish_id')
    union all
    select
      'WARNING', 'OMITS_APPROVED_MENU_ASSIGNMENT',
      'The draft omits an assignment from the latest approved snapshot.',
      approved.source_row_reference
    from atlas_planning.weekly_menus menu
    join atlas_planning.weekly_menu_approval_snapshot_lines approved
      on approved.weekly_menu_approval_snapshot_id =
          menu.latest_approval_snapshot_id
    where menu.week_start = $1
      and not exists (
        select 1
        from canonical
        where atlas_core.pa_05b_safe_uuid(row ->> 'school_id') =
              approved.school_id
          and atlas_core.pa_05d_safe_date(row ->> 'service_date') =
              approved.service_date
          and row ->> 'menu_slot_code' = approved.menu_slot_code
      )
  )
  select pg_catalog.jsonb_build_object(
    'blockers',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'code', code,
            'message', message,
            'source_row_reference', source_row_reference
          )
          order by code, source_row_reference nulls first
        )
        from issues
        where severity = 'BLOCKER'
      ),
      '[]'::jsonb
    ),
    'warnings',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'code', code,
            'message', message,
            'source_row_reference', source_row_reference
          )
          order by code, source_row_reference nulls first
        )
        from issues
        where severity = 'WARNING'
      ),
      '[]'::jsonb
    )
  );
$$;

commit;
