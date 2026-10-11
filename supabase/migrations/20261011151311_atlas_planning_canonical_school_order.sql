-- Canonical School presentation for Planning reads only.
-- Preserve all signatures, payload fields, owners, grants, filters and business facts.
-- Pantry's direct-need wrapper continues to call its renamed original payload.

create or replace function atlas_core.rmvp_03a_default_attendance_rows(
  week_start date
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  with selected_menu as (
    select menu.weekly_menu_id
    from atlas_planning.weekly_menus menu
    where menu.week_start = $1
  ),
  menu_population as (
    select distinct line.school_id, line.service_date
    from selected_menu menu
    join atlas_planning.weekly_menu_lines line
      on line.weekly_menu_id = menu.weekly_menu_id
     and line.line_status = 'ACTIVE'
    join atlas_admin.schools school
      on school.school_id = line.school_id
     and school.school_status = 'ACTIVE'
  ),
  fallback_population as (
    select
      school.school_id,
      day.service_date::date
    from atlas_admin.schools school
    cross join pg_catalog.generate_series(
      $1::timestamp,
      ($1 + 6)::timestamp,
      interval '1 day'
    ) day(service_date)
    where school.school_status = 'ACTIVE'
      and not exists (select 1 from menu_population)
  ),
  population as (
    select * from menu_population
    union all
    select * from fallback_population
  )
  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'school_id', population.school_id,
        'service_date', population.service_date,
        'student_portions', school.default_student_portions,
        'teacher_portions', school.default_teacher_portions,
        'source_row_reference',
          'default:' || school.school_code || ':' ||
          population.service_date::text
      )
      order by
        school.display_order,
        school.school_name,
        school.school_id,
        population.service_date
    ),
    '[]'::jsonb
  )
  from population
  join atlas_admin.schools school
    on school.school_id = population.school_id;
$$;

create or replace function atlas_core.rmvp_03a_planning_workbench_payload(
  target_week_start date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_menu atlas_planning.weekly_menus%rowtype;
  v_attendance atlas_planning.attendance_batches%rowtype;
  v_menu_rows jsonb := '[]'::jsonb;
  v_attendance_rows jsonb := '[]'::jsonb;
  v_menu_issues jsonb;
  v_attendance_issues jsonb;
  v_coverage_warnings jsonb := '[]'::jsonb;
  v_missing_attendance integer := 0;
  v_without_menu integer := 0;
begin
  select *
    into v_menu
  from atlas_planning.weekly_menus menu
  where menu.week_start = target_week_start;

  if found then
    select coalesce(
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'weekly_menu_line_id', line.weekly_menu_line_id,
          'school_id', line.school_id,
          'service_date', line.service_date,
          'menu_slot_code', line.menu_slot_code,
          'dish_id', line.dish_id,
          'line_status', line.line_status,
          'source_row_reference', line.source_row_reference,
          'updated_by_actor_id', line.updated_by_actor_id,
          'updated_at', line.updated_at
        )
        order by
          school.display_order,
          school.school_name,
          school.school_id,
          line.service_date,
          line.menu_slot_code,
          line.weekly_menu_line_id
      ),
      '[]'::jsonb
    )
      into v_menu_rows
    from atlas_planning.weekly_menu_lines line
    join atlas_admin.schools school on school.school_id = line.school_id
    where line.weekly_menu_id = v_menu.weekly_menu_id;
  end if;

  select *
    into v_attendance
  from atlas_planning.attendance_batches batch
  where batch.period_start = target_week_start
    and batch.period_end = target_week_start + 6;

  if found then
    select coalesce(
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'attendance_line_id', line.attendance_line_id,
          'school_id', line.school_id,
          'service_date', line.service_date,
          'student_portions', line.student_portions,
          'teacher_portions', line.teacher_portions,
          'line_status', line.line_status,
          'source_row_reference', line.source_row_reference,
          'updated_by_actor_id', line.updated_by_actor_id,
          'updated_at', line.updated_at
        )
        order by
          school.display_order,
          school.school_name,
          school.school_id,
          line.service_date,
          line.attendance_line_id
      ),
      '[]'::jsonb
    )
      into v_attendance_rows
    from atlas_planning.attendance_lines line
    join atlas_admin.schools school on school.school_id = line.school_id
    where line.attendance_batch_id = v_attendance.attendance_batch_id;
  end if;

  v_menu_issues := atlas_core.rmvp_03a_menu_issues(
    target_week_start,
    (
      select coalesce(pg_catalog.jsonb_agg(row), '[]'::jsonb)
      from pg_catalog.jsonb_array_elements(v_menu_rows) row
      where row ->> 'line_status' = 'ACTIVE'
    )
  );
  v_attendance_issues := atlas_core.rmvp_03a_attendance_issues(
    target_week_start,
    (
      select coalesce(pg_catalog.jsonb_agg(row), '[]'::jsonb)
      from pg_catalog.jsonb_array_elements(v_attendance_rows) row
      where row ->> 'line_status' = 'ACTIVE'
    )
  );

  if v_menu.weekly_menu_id is not null
     and v_attendance.attendance_batch_id is not null then
    select count(*)::integer
      into v_missing_attendance
    from (
      select distinct line.school_id, line.service_date
      from atlas_planning.weekly_menu_lines line
      where line.weekly_menu_id = v_menu.weekly_menu_id
        and line.line_status = 'ACTIVE'
    ) menu_assignment
    where not exists (
      select 1
      from atlas_planning.attendance_lines attendance_line
      where attendance_line.attendance_batch_id =
          v_attendance.attendance_batch_id
        and attendance_line.line_status = 'ACTIVE'
        and attendance_line.school_id = menu_assignment.school_id
        and attendance_line.service_date = menu_assignment.service_date
    );

    select count(*)::integer
      into v_without_menu
    from atlas_planning.attendance_lines attendance_line
    where attendance_line.attendance_batch_id =
        v_attendance.attendance_batch_id
      and attendance_line.line_status = 'ACTIVE'
      and not exists (
        select 1
        from atlas_planning.weekly_menu_lines menu_line
        where menu_line.weekly_menu_id = v_menu.weekly_menu_id
          and menu_line.line_status = 'ACTIVE'
          and menu_line.school_id = attendance_line.school_id
          and menu_line.service_date = attendance_line.service_date
      );
  end if;

  if v_missing_attendance > 0 then
    v_coverage_warnings := v_coverage_warnings ||
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'code', 'MENU_ASSIGNMENT_WITHOUT_ATTENDANCE',
          'message',
            v_missing_attendance::text ||
            ' school/date menu assignments have no active attendance row.',
          'count', v_missing_attendance
        )
      );
  end if;
  if v_without_menu > 0 then
    v_coverage_warnings := v_coverage_warnings ||
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'code', 'ATTENDANCE_WITHOUT_MENU_ASSIGNMENT',
          'message',
            v_without_menu::text ||
            ' active attendance rows have no menu assignment.',
          'count', v_without_menu
        )
      );
  end if;

  return pg_catalog.jsonb_build_object(
    'week_start', target_week_start,
    'week_end', target_week_start + 6,
    'dish_types',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'dish_type_id', dish_type.dish_type_id,
            'dish_type_code', dish_type.dish_type_code,
            'dish_type_name', dish_type.dish_type_name,
            'source_header_aliases', dish_type.source_header_aliases,
            'display_order', dish_type.display_order,
            'dish_type_status', dish_type.dish_type_status,
            'version', dish_type.version
          )
          order by
            dish_type.display_order,
            dish_type.dish_type_code,
            dish_type.dish_type_id
        )
        from atlas_admin.dish_types dish_type
        where dish_type.dish_type_status = 'ACTIVE'
      ),
      '[]'::jsonb
    ),
    'schools',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'school_id', school.school_id,
            'school_code', school.school_code,
            'school_name', school.school_name,
            'school_status', school.school_status,
            'display_order', school.display_order,
            'school_type_id', school.school_type_id,
            'default_student_portions',
              school.default_student_portions,
            'default_teacher_portions',
              school.default_teacher_portions
          )
          order by
            school.display_order,
            school.school_name,
            school.school_id
        )
        from atlas_admin.schools school
      ),
      '[]'::jsonb
    ),
    'dishes',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'dish_id', dish.dish_id,
            'dish_code', dish.dish_code,
            'dish_name', dish.dish_name,
            'dish_category', dish.dish_category,
            'dish_type_id', dish.dish_type_id,
            'dish_type_code', dish_type.dish_type_code,
            'dish_type_name', dish_type.dish_type_name,
            'dish_status', dish.dish_status,
            'display_order', dish.display_order,
            'requires_need_generation', dish.requires_need_generation
          )
          order by
            dish.display_order,
            dish.dish_code,
            dish.dish_id
        )
        from atlas_admin.dishes dish
        left join atlas_admin.dish_types dish_type
          on dish_type.dish_type_id = dish.dish_type_id
      ),
      '[]'::jsonb
    ),
    'google_sheet_sources',
    coalesce(
      (
        select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'weekly_menu_google_source_id',
              source.weekly_menu_google_source_id,
            'source_code', source.source_code,
            'source_name', source.source_name,
            'source_status', source.source_status,
            'display_order', source.display_order
          )
          order by
            source.display_order,
            source.source_code,
            source.weekly_menu_google_source_id
        )
        from atlas_planning.weekly_menu_google_sources source
        where source.source_status = 'ACTIVE'
      ),
      '[]'::jsonb
    ),
    'weekly_menu',
    case
      when v_menu.weekly_menu_id is null then null
      else pg_catalog.jsonb_build_object(
        'weekly_menu_id', v_menu.weekly_menu_id,
        'week_start', v_menu.week_start,
        'week_end', v_menu.week_end,
        'source_type', v_menu.source_type,
        'source_name', v_menu.source_name,
        'source_signature', v_menu.source_signature,
        'weekly_menu_status', v_menu.weekly_menu_status,
        'row_count', v_menu.row_count,
        'imported_by_actor_id', v_menu.imported_by_actor_id,
        'imported_at', v_menu.imported_at,
        'latest_approved_by_actor_id',
          v_menu.latest_approved_by_actor_id,
        'latest_approved_at', v_menu.latest_approved_at,
        'latest_approval_snapshot_id',
          v_menu.latest_approval_snapshot_id,
        'version', v_menu.version,
        'created_at', v_menu.created_at,
        'updated_at', v_menu.updated_at,
        'lines', v_menu_rows,
        'issues', v_menu_issues,
        'change_history',
          coalesce(
            (
              select pg_catalog.jsonb_agg(
                pg_catalog.jsonb_build_object(
                  'audit_event_id', audit.audit_event_id,
                  'event_type', audit.event_type,
                  'version_before', audit.aggregate_version_before,
                  'version_after', audit.aggregate_version_after,
                  'actor_id', audit.actor_id,
                  'actor_display_name', actor.display_name,
                  'reason_code', audit.reason_code,
                  'reason_note', audit.reason_note,
                  'occurred_at', audit.occurred_at
                )
                order by audit.occurred_at desc, audit.audit_event_id
              )
              from atlas_audit.audit_events audit
              join atlas_core.actors actor
                on actor.actor_id = audit.actor_id
              where audit.aggregate_type = 'WeeklyMenu'
                and audit.aggregate_id = v_menu.weekly_menu_id
            ),
            '[]'::jsonb
          ),
        'approval_history',
          coalesce(
            (
              select pg_catalog.jsonb_agg(
                pg_catalog.jsonb_build_object(
                  'approval_snapshot_id',
                    snapshot.weekly_menu_approval_snapshot_id,
                  'version', snapshot.weekly_menu_version,
                  'approved_by_actor_id', snapshot.approved_by_actor_id,
                  'approved_by_display_name', actor.display_name,
                  'approved_at', snapshot.approved_at,
                  'line_count',
                    (
                      select count(*)
                      from
                        atlas_planning.weekly_menu_approval_snapshot_lines
                          snapshot_line
                      where snapshot_line.weekly_menu_approval_snapshot_id =
                        snapshot.weekly_menu_approval_snapshot_id
                    )
                )
                order by snapshot.weekly_menu_version desc
              )
              from atlas_planning.weekly_menu_approval_snapshots snapshot
              join atlas_core.actors actor
                on actor.actor_id = snapshot.approved_by_actor_id
              where snapshot.weekly_menu_id = v_menu.weekly_menu_id
            ),
            '[]'::jsonb
          )
      )
    end,
    'attendance',
    case
      when v_attendance.attendance_batch_id is null then null
      else pg_catalog.jsonb_build_object(
        'attendance_batch_id', v_attendance.attendance_batch_id,
        'period_start', v_attendance.period_start,
        'period_end', v_attendance.period_end,
        'source_type', v_attendance.source_type,
        'source_name', v_attendance.source_name,
        'source_signature', v_attendance.source_signature,
        'attendance_status', v_attendance.attendance_status,
        'row_count', v_attendance.row_count,
        'imported_by_actor_id', v_attendance.imported_by_actor_id,
        'imported_at', v_attendance.imported_at,
        'latest_approved_by_actor_id',
          v_attendance.latest_approved_by_actor_id,
        'latest_approved_at', v_attendance.latest_approved_at,
        'latest_approval_snapshot_id',
          v_attendance.latest_approval_snapshot_id,
        'version', v_attendance.version,
        'created_at', v_attendance.created_at,
        'updated_at', v_attendance.updated_at,
        'lines', v_attendance_rows,
        'issues', v_attendance_issues,
        'change_history',
          coalesce(
            (
              select pg_catalog.jsonb_agg(
                pg_catalog.jsonb_build_object(
                  'audit_event_id', audit.audit_event_id,
                  'event_type', audit.event_type,
                  'version_before', audit.aggregate_version_before,
                  'version_after', audit.aggregate_version_after,
                  'actor_id', audit.actor_id,
                  'actor_display_name', actor.display_name,
                  'reason_code', audit.reason_code,
                  'reason_note', audit.reason_note,
                  'occurred_at', audit.occurred_at
                )
                order by audit.occurred_at desc, audit.audit_event_id
              )
              from atlas_audit.audit_events audit
              join atlas_core.actors actor
                on actor.actor_id = audit.actor_id
              where audit.aggregate_type = 'AttendanceBatch'
                and audit.aggregate_id = v_attendance.attendance_batch_id
            ),
            '[]'::jsonb
          ),
        'approval_history',
          coalesce(
            (
              select pg_catalog.jsonb_agg(
                pg_catalog.jsonb_build_object(
                  'approval_snapshot_id',
                    snapshot.attendance_approval_snapshot_id,
                  'version', snapshot.attendance_version,
                  'approved_by_actor_id', snapshot.approved_by_actor_id,
                  'approved_by_display_name', actor.display_name,
                  'approved_at', snapshot.approved_at,
                  'line_count',
                    (
                      select count(*)
                      from
                        atlas_planning.attendance_approval_snapshot_lines
                          snapshot_line
                      where snapshot_line.attendance_approval_snapshot_id =
                        snapshot.attendance_approval_snapshot_id
                    )
                )
                order by snapshot.attendance_version desc
              )
              from atlas_planning.attendance_approval_snapshots snapshot
              join atlas_core.actors actor
                on actor.actor_id = snapshot.approved_by_actor_id
              where snapshot.attendance_batch_id =
                v_attendance.attendance_batch_id
            ),
            '[]'::jsonb
          )
      )
    end,
    'readiness', pg_catalog.jsonb_build_object(
      'weekly_menu_approved',
        coalesce(v_menu.weekly_menu_status = 'APPROVED', false),
      'attendance_approved',
        coalesce(v_attendance.attendance_status = 'APPROVED', false),
      'weekly_menu_approval_snapshot_id',
        v_menu.latest_approval_snapshot_id,
      'attendance_approval_snapshot_id',
        v_attendance.latest_approval_snapshot_id,
      'ready',
        coalesce(v_menu.weekly_menu_status = 'APPROVED', false)
        and coalesce(v_attendance.attendance_status = 'APPROVED', false),
      'warnings', v_coverage_warnings
    ),
    'default_attendance_preview',
      atlas_core.rmvp_03a_default_attendance_rows(target_week_start)
  );
end;
$$;

create or replace function atlas_core.direct_need_legacy_pantry_workbench_payload(
  target_week_start date,
  target_actor_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  batch atlas_planning.pantry_need_batches%rowtype;
  current_rows jsonb := '[]'::jsonb;
  current_issues jsonb := pg_catalog.jsonb_build_object(
    'blockers', '[]'::jsonb,
    'warnings', '[]'::jsonb
  );
  catalog_blockers jsonb := '[]'::jsonb;
  can_write boolean := atlas_core.pantry_02_actor_has_capability(
    target_actor_id,
    'planning.pantry.write'
  );
  can_approve boolean := atlas_core.pantry_02_actor_has_capability(
    target_actor_id,
    'planning.inputs.approve'
  );
begin
  select source_batch.*
    into batch
  from atlas_planning.pantry_need_batches source_batch
  where source_batch.week_start = target_week_start;

  if batch.pantry_need_batch_id is not null then
    current_rows := atlas_core.pantry_02_current_rows(
      batch.pantry_need_batch_id
    );
    current_issues := atlas_core.pantry_02_issues(
      target_week_start,
      batch.no_additions_confirmed,
      current_rows
    );
  end if;

  if not exists (
    select 1
    from atlas_planning.pantry_need_purposes purpose
    where purpose.purpose_status = 'ACTIVE'
  ) then
    catalog_blockers := pg_catalog.jsonb_build_array(
      atlas_core.pantry_02_issue(
        'PURPOSE_CATALOG_EMPTY',
        'No active Pantry Purpose is configured.',
        null,
        'pantry_need_purpose_id'
      )
    );
  end if;

  return pg_catalog.jsonb_build_object(
    'week_start', target_week_start,
    'week_end', target_week_start + 6,
    'source_method', pg_catalog.jsonb_build_object(
      'source_type', 'MANUAL_ATLAS',
      'source_name', 'Nhập thủ công Atlas'
    ),
    'purposes',
      coalesce(
        (
          select pg_catalog.jsonb_agg(
            pg_catalog.jsonb_build_object(
              'pantry_need_purpose_id', purpose.pantry_need_purpose_id,
              'purpose_code', purpose.purpose_code,
              'purpose_name_vi', purpose.purpose_name_vi,
              'purpose_description', purpose.purpose_description,
              'note_rule', purpose.note_rule,
              'purpose_status', purpose.purpose_status,
              'display_order', purpose.display_order,
              'version', purpose.version
            )
            order by
              purpose.display_order,
              purpose.purpose_code,
              purpose.pantry_need_purpose_id
          )
          from atlas_planning.pantry_need_purposes purpose
          where purpose.purpose_status = 'ACTIVE'
        ),
        '[]'::jsonb
      ),
    'schools',
      coalesce(
        (
          select pg_catalog.jsonb_agg(
            pg_catalog.jsonb_build_object(
              'school_id', school.school_id,
              'school_code', school.school_code,
              'school_name', school.school_name,
              'school_status', school.school_status,
              'display_order', school.display_order,
              'customer_id', school.customer_id,
              'customer_name', customer.customer_name,
              'default_delivery_location',
                pg_catalog.jsonb_build_object(
                  'delivery_location_id',
                    location.delivery_location_id,
                  'location_code', location.location_code,
                  'location_name', location.location_name,
                  'address_text', location.address_text,
                  'timezone_name', location.timezone_name
                )
            )
            order by
              school.display_order,
              school.school_name,
              school.school_id
          )
          from atlas_admin.schools school
          join atlas_admin.customers customer
            on customer.customer_id = school.customer_id
           and customer.customer_type = 'SCHOOL_CATERING'
           and customer.customer_status = 'ACTIVE'
          join atlas_admin.delivery_locations location
            on location.delivery_location_id =
              school.default_delivery_location_id
           and location.customer_id = school.customer_id
           and location.location_status = 'ACTIVE'
          where school.school_status = 'ACTIVE'
        ),
        '[]'::jsonb
      ),
    'ingredients',
      coalesce(
        (
          select pg_catalog.jsonb_agg(
            pg_catalog.jsonb_build_object(
              'ingredient_id', ingredient.ingredient_id,
              'ingredient_code', ingredient.ingredient_code,
              'ingredient_name', ingredient.ingredient_name,
              'ingredient_status', ingredient.ingredient_status,
              'purchase_unit',
                pg_catalog.jsonb_build_object(
                  'unit_id', unit.unit_id,
                  'unit_code', unit.unit_code,
                  'unit_name', unit.unit_name
                )
            )
            order by
              ingredient.ingredient_name,
              ingredient.ingredient_code,
              ingredient.ingredient_id
          )
          from atlas_admin.ingredients ingredient
          join atlas_admin.units unit
            on unit.unit_id = ingredient.purchase_unit_id
           and unit.unit_status = 'ACTIVE'
          where ingredient.ingredient_status = 'ACTIVE'
        ),
        '[]'::jsonb
      ),
    'catalog_issues', pg_catalog.jsonb_build_object(
      'blockers', catalog_blockers,
      'warnings', '[]'::jsonb
    ),
    'batch',
      case
        when batch.pantry_need_batch_id is null then null
        else pg_catalog.jsonb_build_object(
          'pantry_need_batch_id', batch.pantry_need_batch_id,
          'week_start', batch.week_start,
          'week_end', batch.week_end,
          'pantry_need_batch_status', batch.pantry_need_batch_status,
          'version', batch.version,
          'source_type', batch.source_type,
          'source_name', batch.source_name,
          'source_signature', batch.source_signature,
          'no_additions_confirmed',
            batch.no_additions_confirmed,
          'requesting_actor_id', batch.requesting_actor_id,
          'requesting_actor_name',
            (
              select requesting_actor.display_name
              from atlas_core.actors requesting_actor
              where requesting_actor.actor_id = batch.requesting_actor_id
            ),
          'creation_method', batch.creation_method,
          'latest_approved_by_actor_id',
            batch.latest_approved_by_actor_id,
          'latest_approved_at', batch.latest_approved_at,
          'latest_approval_snapshot_id',
            batch.latest_approval_snapshot_id,
          'created_at', batch.created_at,
          'updated_at', batch.updated_at,
          'active_lines',
            coalesce(
              (
                select pg_catalog.jsonb_agg(
                  pg_catalog.jsonb_build_object(
                    'pantry_need_line_id', line.pantry_need_line_id,
                    'service_date', line.service_date,
                    'school_id', line.school_id,
                    'school_code', school.school_code,
                    'school_name', school.school_name,
                    'delivery_location_id',
                      line.delivery_location_id,
                    'delivery_location_code',
                      location.location_code,
                    'delivery_location_name',
                      location.location_name,
                    'ingredient_id', line.ingredient_id,
                    'ingredient_code', ingredient.ingredient_code,
                    'ingredient_name', ingredient.ingredient_name,
                    'unit_id', line.unit_id,
                    'unit_code', unit.unit_code,
                    'unit_name', unit.unit_name,
                    'pantry_need_purpose_id',
                      line.pantry_need_purpose_id,
                    'purpose_code', purpose.purpose_code,
                    'purpose_name_vi', purpose.purpose_name_vi,
                    'purpose_description',
                      purpose.purpose_description,
                    'purpose_note_rule', purpose.note_rule,
                    'requested_quantity', line.requested_quantity,
                    'note', line.note,
                    'source_request_reference',
                      line.source_request_reference,
                    'source_row_reference',
                      line.source_row_reference,
                    'line_status', line.line_status,
                    'updated_by_actor_id',
                      line.updated_by_actor_id,
                    'updated_at', line.updated_at
                  )
                  order by
                    line.service_date,
                    school.display_order,
                    school.school_name,
                    school.school_id,
                    ingredient.ingredient_name,
                    line.pantry_need_line_id
                )
                from atlas_planning.pantry_need_lines line
                left join atlas_admin.schools school
                  on school.school_id = line.school_id
                left join atlas_admin.delivery_locations location
                  on location.delivery_location_id =
                    line.delivery_location_id
                left join atlas_admin.ingredients ingredient
                  on ingredient.ingredient_id = line.ingredient_id
                left join atlas_admin.units unit
                  on unit.unit_id = line.unit_id
                left join atlas_planning.pantry_need_purposes purpose
                  on purpose.pantry_need_purpose_id =
                    line.pantry_need_purpose_id
                where line.pantry_need_batch_id =
                  batch.pantry_need_batch_id
                  and line.line_status = 'ACTIVE'
              ),
              '[]'::jsonb
            ),
          'invalid_lines',
            coalesce(
              (
                select pg_catalog.jsonb_agg(
                  pg_catalog.jsonb_build_object(
                    'pantry_need_line_id', line.pantry_need_line_id,
                    'service_date', line.service_date,
                    'school_id', line.school_id,
                    'school_code', school.school_code,
                    'school_name', school.school_name,
                    'delivery_location_id',
                      line.delivery_location_id,
                    'delivery_location_name',
                      location.location_name,
                    'ingredient_id', line.ingredient_id,
                    'ingredient_code', ingredient.ingredient_code,
                    'ingredient_name', ingredient.ingredient_name,
                    'unit_id', line.unit_id,
                    'unit_code', unit.unit_code,
                    'unit_name', unit.unit_name,
                    'pantry_need_purpose_id',
                      line.pantry_need_purpose_id,
                    'purpose_code', purpose.purpose_code,
                    'purpose_name_vi', purpose.purpose_name_vi,
                    'requested_quantity', line.requested_quantity,
                    'note', line.note,
                    'source_request_reference',
                      line.source_request_reference,
                    'source_row_reference',
                      line.source_row_reference,
                    'line_status', line.line_status,
                    'updated_at', line.updated_at
                  )
                  order by
                    line.service_date,
                    school.display_order,
                    school.school_name,
                    school.school_id,
                    ingredient.ingredient_name,
                    line.pantry_need_line_id
                )
                from atlas_planning.pantry_need_lines line
                left join atlas_admin.schools school
                  on school.school_id = line.school_id
                left join atlas_admin.delivery_locations location
                  on location.delivery_location_id =
                    line.delivery_location_id
                left join atlas_admin.ingredients ingredient
                  on ingredient.ingredient_id = line.ingredient_id
                left join atlas_admin.units unit
                  on unit.unit_id = line.unit_id
                left join atlas_planning.pantry_need_purposes purpose
                  on purpose.pantry_need_purpose_id =
                    line.pantry_need_purpose_id
                where line.pantry_need_batch_id =
                  batch.pantry_need_batch_id
                  and line.line_status = 'INVALID'
              ),
              '[]'::jsonb
            ),
          'issues', current_issues,
          'approval_history',
            coalesce(
              (
                select pg_catalog.jsonb_agg(
                  pg_catalog.jsonb_build_object(
                    'pantry_need_approval_snapshot_id',
                      snapshot.pantry_need_approval_snapshot_id,
                    'approved_batch_version',
                      snapshot.approved_batch_version,
                    'approved_by_actor_id',
                      snapshot.approved_by_actor_id,
                    'approved_by_display_name',
                      approver.display_name,
                    'approved_at', snapshot.approved_at,
                    'source_signature',
                      snapshot.source_signature,
                    'no_additions_confirmed',
                      snapshot.no_additions_confirmed,
                    'line_count', snapshot.line_count,
                    'blocker_summary',
                      snapshot.blocker_summary,
                    'warning_summary',
                      snapshot.warning_summary,
                    'lines',
                      coalesce(
                        (
                          select pg_catalog.jsonb_agg(
                            pg_catalog.to_jsonb(snapshot_line)
                            order by
                              snapshot_line.service_date,
                              snapshot_line.school_code_snapshot,
                              snapshot_line.ingredient_code_snapshot,
                              snapshot_line.pantry_need_line_id
                          )
                          from atlas_planning
                            .pantry_need_approval_snapshot_lines
                              snapshot_line
                          where
                            snapshot_line
                              .pantry_need_approval_snapshot_id =
                            snapshot.pantry_need_approval_snapshot_id
                        ),
                        '[]'::jsonb
                      )
                  )
                  order by
                    snapshot.approved_batch_version desc,
                    snapshot.pantry_need_approval_snapshot_id
                )
                from atlas_planning.pantry_need_approval_snapshots
                  snapshot
                join atlas_core.actors approver
                  on approver.actor_id =
                    snapshot.approved_by_actor_id
                where snapshot.pantry_need_batch_id =
                  batch.pantry_need_batch_id
              ),
              '[]'::jsonb
            ),
          'change_history',
            coalesce(
              (
                select pg_catalog.jsonb_agg(
                  pg_catalog.jsonb_build_object(
                    'audit_event_id', audit.audit_event_id,
                    'event_type', audit.event_type,
                    'version_before',
                      audit.aggregate_version_before,
                    'version_after',
                      audit.aggregate_version_after,
                    'actor_id', audit.actor_id,
                    'actor_display_name', audit_actor.display_name,
                    'reason_code', audit.reason_code,
                    'reason_note', audit.reason_note,
                    'occurred_at', audit.occurred_at
                  )
                  order by audit.occurred_at desc, audit.audit_event_id
                )
                from atlas_audit.audit_events audit
                join atlas_core.actors audit_actor
                  on audit_actor.actor_id = audit.actor_id
                where audit.aggregate_type = 'PantryNeedBatch'
                  and audit.aggregate_id =
                    batch.pantry_need_batch_id
              ),
              '[]'::jsonb
            )
        )
      end,
    'allowed_actions', pg_catalog.jsonb_build_object(
      'can_preview', true,
      'can_save',
        can_write and (
          batch.pantry_need_batch_id is null
          or batch.pantry_need_batch_status in ('DRAFT', 'REOPENED')
        ),
      'can_validate',
        can_write
        and batch.pantry_need_batch_status in ('DRAFT', 'REOPENED'),
      'can_approve',
        can_approve
        and batch.pantry_need_batch_status = 'VALIDATED',
      'can_reopen',
        can_approve
        and batch.pantry_need_batch_status = 'APPROVED'
    )
  );
end
$$;
