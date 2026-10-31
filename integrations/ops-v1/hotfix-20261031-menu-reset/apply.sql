-- OPS v1 only. Keep outside Atlas Supabase migrations.
begin;

do $guard$
declare
  r record;
begin
  for r in select * from (values
    ('public.sync_daily_order_dishes(bigint,jsonb,text)', '4a0f52c5f651e8e7df6977b781a847cd'),
    ('public.fn_save_daily_menus(jsonb)', '1cdd0a9516402d5f6337e00c5c079ee5'),
    ('public.fn_update_order_dishes(jsonb)', '1279e9953a458f2a9dd8cab4b34e7424'),
    ('public.fn_upsert_weekly_menu(date,text,text,jsonb)', 'c1370673f758348b5934c42ad5163425')
  ) expected(signature, source_hash)
  loop
    if (
      select md5(replace(p.prosrc, chr(13), '')) = r.source_hash
        and p.prosecdef = (p.proname <> 'sync_daily_order_dishes')
        and not p.proisstrict and p.provolatile = 'v'
        and p.proconfig is not distinct from
          case p.proname
            when 'fn_update_order_dishes' then array['search_path=public, pg_temp']
            when 'fn_upsert_weekly_menu' then array['search_path=public']
            else null::text[]
          end
        and p.prolang = (select oid from pg_language where lanname = 'plpgsql')
      from pg_proc p where p.oid = to_regprocedure(r.signature)
    ) is distinct from true then
      raise exception 'OPS_V1_MENU_HOTFIX_SOURCE_MISMATCH: %', r.signature
        using errcode = '55000';
    end if;
  end loop;
end;
$guard$;
CREATE OR REPLACE FUNCTION public.sync_daily_order_dishes(_order_id bigint, _dishes jsonb, _source text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF _dishes IS NULL OR jsonb_typeof(_dishes) <> 'array' THEN
    _dishes := '[]'::jsonb;
  END IF;

  PERFORM 1 FROM public.daily_orders WHERE id = _order_id FOR UPDATE;

  -- Insert first so a replacement never looks like an explicit empty menu.
  INSERT INTO public.daily_order_dishes (order_id, dish_id)
  SELECT DISTINCT _order_id, d.value::bigint
  FROM jsonb_array_elements(_dishes) d(value)
  WHERE d.value IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM public.daily_order_dishes e
      WHERE e.order_id = _order_id AND e.dish_id = d.value::bigint
    );

  DELETE FROM public.daily_order_dishes e
  WHERE e.order_id = _order_id
    AND NOT EXISTS (
      SELECT 1 FROM jsonb_array_elements(_dishes) d(value)
      WHERE d.value::bigint = e.dish_id
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.fn_save_daily_menus(p_rows jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  rec          jsonb;
  v_school_id  bigint;
  v_date       date;
  v_order_id   bigint;

  v_students_default smallint;
  v_teachers_default smallint;

  v_student_portions smallint;
  v_teacher_portions smallint;

  dish_cols text[] := array['mon_canh','mon_man','mon_xao','trang_mieng','buoi_xe'];
  v_col     text;
  v_dish_id bigint;
  v_dishes jsonb;
begin
  if p_rows is null or jsonb_typeof(p_rows) <> 'array' then
    return;
  end if;

  -- iterate each row from importer/editor
  for rec in
    select value
    from jsonb_array_elements(p_rows)
  loop
    v_school_id := (rec ->> 'school_id')::bigint;
    v_date      := (rec ->> 'service_date')::date;

    if v_school_id is null or v_date is null then
      continue;
    end if;

    -- defaults from schools
    select s.default_students_num, s.default_teacher_num
    into v_students_default, v_teachers_default
    from public.schools s
    where s.id = v_school_id;

    v_student_portions := nullif(rec ->> 'student_portions', '')::smallint;
    v_teacher_portions := nullif(rec ->> 'teacher_portions', '')::smallint;

    insert into public.daily_orders as d
      (service_date, school_id, student_portions, teacher_portions)
    values
      (
        v_date,
        v_school_id,
        coalesce(v_student_portions, v_students_default),
        coalesce(v_teacher_portions, v_teachers_default)
      )
    on conflict (service_date, school_id)
    do update set
      student_portions = coalesce(excluded.student_portions, d.student_portions),
      teacher_portions = coalesce(excluded.teacher_portions, d.teacher_portions)
    returning id into v_order_id;

    if v_order_id is null then
      select id into v_order_id
      from public.daily_orders
      where service_date = v_date and school_id = v_school_id;
    end if;

    if v_order_id is null then
      continue;
    end if;

    v_dishes := '[]'::jsonb;

    -- insert one row per non-null dish_id
    foreach v_col in array dish_cols loop
      v_dish_id := null;

      begin
        v_dish_id := nullif(rec ->> v_col, '')::bigint;
      exception when others then
        v_dish_id := null;
      end;

      if v_dish_id is not null then
        v_dishes := v_dishes || jsonb_build_array(v_dish_id);
      end if;
    end loop;

    perform public.sync_daily_order_dishes(v_order_id, v_dishes, 'manual');
  end loop;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_update_order_dishes(p_body jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_key      text;
  v_val      jsonb;
  v_order_id bigint;
begin
  if p_body is null or jsonb_typeof(p_body) <> 'object' then
    raise exception 'p_body must be a JSON object of order_id -> dish_id[]';
  end if;

  -- Loop over each "order_id" key
  for v_key, v_val in
    select key, value from jsonb_each(p_body)
  loop
    v_order_id := v_key::bigint;
    if v_order_id is null then
      continue;
    end if;

    perform public.sync_daily_order_dishes(v_order_id, v_val, 'manual');
  end loop;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_upsert_weekly_menu(_week_start date, _sheet_name text, _sig text, _rows jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_week_end       date := _week_start + 6;
  v_rows_count     integer;

  v_orders_before  integer;
  v_dishes_before  integer;
  v_orders_after   integer;
  v_dishes_after   integer;

  v_sig_match      boolean := false;
  v_changed_days   integer := 0;
  v_skipped        boolean := false;
  v_keys           jsonb := '[]'::jsonb;
BEGIN
  IF _rows IS NULL OR jsonb_typeof(_rows) <> 'array' THEN
    RAISE EXCEPTION 'Payload must be a JSON array';
  END IF;

  v_rows_count := jsonb_array_length(_rows);

  v_sig_match := EXISTS (
    SELECT 1
    FROM public.menu_import_weeks miw
    WHERE miw.week_start = _week_start
      AND miw.source     = 'google_sheet'
      AND miw.sig        = _sig
  );

  SELECT count(*) INTO v_orders_before
  FROM public.daily_orders d
  WHERE d.service_date BETWEEN _week_start AND v_week_end;

  SELECT count(*) INTO v_dishes_before
  FROM public.daily_order_dishes dod
  JOIN public.daily_orders d ON d.id = dod.order_id
  WHERE d.service_date BETWEEN _week_start AND v_week_end;

  -- PATCH: payload days from raw rows, including clear-day markers
  CREATE TEMP TABLE tmp_payload_days ON COMMIT DROP AS
  SELECT DISTINCT
    (elem->>'school_id')::bigint  AS school_id,
    (elem->>'service_date')::date AS service_date
  FROM jsonb_array_elements(_rows) AS elem
  WHERE (elem->>'school_id') IS NOT NULL
    AND (elem->>'service_date') IS NOT NULL;

  -- validate using payload days
  IF EXISTS (
    SELECT 1
    FROM tmp_payload_days pd
    WHERE pd.service_date < _week_start
       OR pd.service_date > v_week_end
  ) THEN
    RAISE EXCEPTION 'One or more service_date values are outside the week [% – %]',
      _week_start, v_week_end;
  END IF;

  CREATE TEMP TABLE tmp_payload_dishes ON COMMIT DROP AS
  SELECT DISTINCT
    (elem->>'school_id')::bigint  AS school_id,
    (elem->>'service_date')::date AS service_date,
    (elem->>'dish_id')::bigint    AS dish_id
  FROM jsonb_array_elements(_rows) AS elem
  WHERE (elem->>'school_id') IS NOT NULL
    AND (elem->>'service_date') IS NOT NULL
    AND (elem->>'dish_id') IS NOT NULL;

  -- preserve old behavior: only create daily_orders for actual dish rows
  INSERT INTO public.daily_orders (service_date, school_id)
  SELECT DISTINCT pd.service_date, pd.school_id
  FROM tmp_payload_dishes pd
  ON CONFLICT (service_date, school_id) DO NOTHING;

  PERFORM 1
  FROM public.daily_orders o
  JOIN tmp_payload_days p
    ON p.school_id = o.school_id AND p.service_date = o.service_date
  ORDER BY o.id
  FOR UPDATE OF o;

  CREATE TEMP TABLE tmp_db_dishes ON COMMIT DROP AS
  SELECT DISTINCT
    o.school_id,
    o.service_date,
    dod.dish_id
  FROM tmp_payload_days p
  JOIN public.daily_orders o
    ON o.school_id = p.school_id
   AND o.service_date = p.service_date
  JOIN public.daily_order_dishes dod
    ON dod.order_id = o.id;

  CREATE TEMP TABLE tmp_changed_days ON COMMIT DROP AS
  WITH desired AS (
    SELECT pd.school_id, pd.service_date, pd.dish_id
    FROM tmp_payload_dishes pd
  ),
  existing AS (
    SELECT db.school_id, db.service_date, db.dish_id
    FROM tmp_db_dishes db
  ),
  diff AS (
    (SELECT desired.school_id, desired.service_date, desired.dish_id FROM desired
     EXCEPT
     SELECT existing.school_id, existing.service_date, existing.dish_id FROM existing)
    UNION ALL
    (SELECT existing.school_id, existing.service_date, existing.dish_id FROM existing
     EXCEPT
     SELECT desired.school_id, desired.service_date, desired.dish_id FROM desired)
  )
  SELECT DISTINCT diff.school_id, diff.service_date
  FROM diff;

  SELECT count(*) INTO v_changed_days FROM tmp_changed_days;

  v_skipped := v_sig_match AND v_changed_days = 0;

  IF NOT v_skipped THEN
    PERFORM set_config('ops.skip_rebalance', 'true', true);

    PERFORM public.sync_daily_order_dishes(
      o.id,
      COALESCE((
        SELECT jsonb_agg(pd.dish_id ORDER BY pd.dish_id)
        FROM tmp_payload_dishes pd
        WHERE pd.school_id = c.school_id
          AND pd.service_date = c.service_date
      ), '[]'::jsonb),
      'google_sheet'
    )
    FROM public.daily_orders o
    JOIN tmp_changed_days c
      ON c.school_id = o.school_id
     AND c.service_date = o.service_date
    ORDER BY o.id;

    PERFORM set_config('ops.skip_rebalance', 'false', true);

    SELECT COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'service_date', c.service_date,
          'school_id',    c.school_id
        )
        ORDER BY c.service_date, c.school_id
      ),
      '[]'::jsonb
    )
    INTO v_keys
    FROM tmp_changed_days c;

    IF v_keys <> '[]'::jsonb THEN
      PERFORM public.fn_rebalance_purchase_assignments_for_keys_fast(v_keys);
    END IF;

    INSERT INTO public.menu_import_weeks (
      week_start, source, sheet_name, sig,
      rows_count, imported_at, imported_by
    )
    VALUES (
      _week_start,
      'google_sheet',
      _sheet_name,
      _sig,
      v_rows_count,
      now(),
      auth.uid()
    )
    ON CONFLICT (week_start, source)
    DO UPDATE
    SET sig         = EXCLUDED.sig,
        sheet_name  = EXCLUDED.sheet_name,
        rows_count  = EXCLUDED.rows_count,
        imported_at = now(),
        imported_by = EXCLUDED.imported_by;
  END IF;

  SELECT count(*) INTO v_orders_after
  FROM public.daily_orders d
  WHERE d.service_date BETWEEN _week_start AND v_week_end;

  SELECT count(*) INTO v_dishes_after
  FROM public.daily_order_dishes dod
  JOIN public.daily_orders d ON d.id = dod.order_id
  WHERE d.service_date BETWEEN _week_start AND v_week_end;

  RETURN jsonb_build_object(
    'skipped_by_signature', v_skipped,
    'sig_match',           v_sig_match,
    'db_drift_detected',   (v_changed_days > 0),
    'changed_schooldays',  v_changed_days,
    'rows_in_payload',     v_rows_count,
    'orders_before',       v_orders_before,
    'dishes_before',       v_dishes_before,
    'orders_after',        v_orders_after,
    'dishes_after',        v_dishes_after
  );
END;
$function$;

commit;
