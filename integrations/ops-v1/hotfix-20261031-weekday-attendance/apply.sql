-- OPS v1 qnthofvccilhnefdcxnz only; outside Atlas migrations.
-- Owner approved deployment conditional on preserving all existing entered data.
-- Combines the reviewed menu-reset fix with weekday attendance defaults.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
DO $source_guard$
DECLARE r record;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('public.daily_orders_fill_default_portions()','4946897084088107af8715da766982a4',false,NULL::text[]),
    ('public.fn_save_daily_menus(jsonb)','1708cf37373fd87938875656f95d110a',true,NULL::text[]),
    ('public.fn_update_order_dishes(jsonb)','0ab7df7c51f5509591a7be1a4342fa7f',true,ARRAY['search_path=public, pg_temp']::text[]),
    ('public.fn_upsert_daily_orders(jsonb)','fc61219fcb3ab436078dd0ce27ad9f1b',true,ARRAY['search_path=public, pg_temp']::text[]),
    ('public.fn_upsert_weekly_menu(date,text,text,jsonb)','46489de13bcfd416d10c68711fbaf051',true,ARRAY['search_path=public']::text[]),
    ('public.schools_sync_default_attendance_incoming()','3c86aaa69a8efcc8294488bed26dc09f',false,NULL::text[]),
    ('public.sync_daily_order_dishes(bigint,jsonb,text)','6317f48f3ef5ebdd6788fd09b410276e',false,NULL::text[])
  ) expected(signature,source_hash,security_definer,settings)
  LOOP
    IF (SELECT md5(replace(p.prosrc,chr(13),'')) = r.source_hash
          AND p.prosecdef = r.security_definer
          AND p.proconfig IS NOT DISTINCT FROM r.settings
          AND NOT p.proisstrict AND p.provolatile = 'v'
          AND p.prolang = (SELECT oid FROM pg_language WHERE lanname='plpgsql')
        FROM pg_proc p WHERE p.oid = to_regprocedure(r.signature)) IS DISTINCT FROM true THEN
      RAISE EXCEPTION 'OPS_V1_WEEKDAY_SOURCE_MISMATCH: %', r.signature USING ERRCODE='55000';
    END IF;
  END LOOP;
END;
$source_guard$;
-- Lock existing business tables briefly; an in-use table aborts after five seconds.
CREATE TEMP TABLE ops_v1_preserved_rows(schema_name text,table_name text,row_count bigint,fingerprint text) ON COMMIT DROP;
CREATE TEMP TABLE ops_v1_preserved_security ON COMMIT DROP AS
SELECT p.oid,p.proowner,p.proacl,p.prosecdef,p.proconfig,p.proisstrict,p.provolatile,p.prorettype,p.proargtypes
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.proname IN (
  'daily_orders_fill_default_portions','fn_upsert_daily_orders','fn_save_daily_menus',
  'schools_sync_default_attendance_incoming','sync_daily_order_dishes',
  'fn_update_order_dishes','fn_upsert_weekly_menu');
DO $snapshot$
DECLARE r record; rows_count bigint; data_hash text; omitted text;
BEGIN
  FOR r IN SELECT n.nspname,c.relname FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
           WHERE n.nspname IN ('public','ops_v2') AND c.relkind='r' ORDER BY n.nspname,c.relname
  LOOP
    EXECUTE format('LOCK TABLE %I.%I IN SHARE MODE',r.nspname,r.relname);
    omitted := CASE WHEN r.nspname='public' AND r.relname='schools'
      THEN '{default_students_weekday,default_teachers_weekday}' ELSE '{}' END;
    EXECUTE format($q$SELECT count(*),md5(coalesce(string_agg(md5((to_jsonb(t)-%L::text[])::text),''
      ORDER BY md5((to_jsonb(t)-%L::text[])::text)),'')) FROM %I.%I t$q$,
      omitted,omitted,r.nspname,r.relname) INTO rows_count,data_hash;
    INSERT INTO pg_temp.ops_v1_preserved_rows VALUES(r.nspname,r.relname,rows_count,data_hash);
  END LOOP;
END;
$snapshot$;
ALTER TABLE public.schools
  ADD COLUMN default_students_weekday smallint[],
  ADD CONSTRAINT schools_default_students_weekday_valid CHECK (
    default_students_weekday IS NULL OR coalesce(
      array_dims(default_students_weekday) = '[1:5]'
      AND array_position(default_students_weekday, NULL) IS NULL
      AND 0 <= ALL (default_students_weekday), false)
  ),
  ADD COLUMN default_teachers_weekday smallint[],
  ADD CONSTRAINT schools_default_teachers_weekday_valid CHECK (
    default_teachers_weekday IS NULL OR coalesce(
      array_dims(default_teachers_weekday) = '[1:5]'
      AND array_position(default_teachers_weekday, NULL) IS NULL
      AND 0 <= ALL (default_teachers_weekday), false)
  );

COMMENT ON COLUMN public.schools.default_students_weekday IS 'OPS v1 weekday student defaults, Monday=1 through Friday=5; NULL uses the existing scalar default.';
COMMENT ON COLUMN public.schools.default_teachers_weekday IS 'OPS v1 weekday teacher defaults, Monday=1 through Friday=5; NULL uses the existing scalar default.';

CREATE OR REPLACE FUNCTION public.daily_orders_fill_default_portions()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
declare
  v_default_students int2;
  v_default_teachers int2;
begin
  select coalesce(s.default_students_weekday[extract(isodow from new.service_date)::int], s.default_students_num),
         coalesce(s.default_teachers_weekday[extract(isodow from new.service_date)::int], s.default_teacher_num)
    into v_default_students, v_default_teachers
  from public.schools s
  where s.id = new.school_id;

  if not found then
    return new;
  end if;

  -- STUDENTS: only fill when NULL
  if new.student_portions is null
     and v_default_students is not null then
    new.student_portions := v_default_students;
  end if;

  -- TEACHERS: only fill when NULL
  if new.teacher_portions is null
     and v_default_teachers is not null then
    new.teacher_portions := v_default_teachers;
  end if;

  return new;
end;
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

  perform 1
  from public.daily_orders d
  where exists (
    select 1 from jsonb_array_elements(p_rows) x(rec)
    where d.school_id = (x.rec->>'school_id')::bigint
      and d.service_date = (x.rec->>'service_date')::date
  )
  order by d.id
  for update of d;

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
    select coalesce(s.default_students_weekday[extract(isodow from v_date)::int], s.default_students_num),
           coalesce(s.default_teachers_weekday[extract(isodow from v_date)::int], s.default_teacher_num)
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
      student_portions = coalesce(v_student_portions, d.student_portions, excluded.student_portions),
      teacher_portions = coalesce(v_teacher_portions, d.teacher_portions, excluded.teacher_portions)
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
    select key, value from jsonb_each(p_body) order by key::bigint
  loop
    v_order_id := v_key::bigint;
    if v_order_id is null then
      continue;
    end if;

    perform public.sync_daily_order_dishes(v_order_id, v_val, 'manual');
  end loop;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fn_upsert_daily_orders(p_pairs jsonb)
 RETURNS TABLE(id bigint, school_id bigint, service_date date)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_item         jsonb;
  v_school_id    bigint;
  v_service_date date;
  v_students     smallint;
  v_teachers     smallint;
  v_id           bigint;
begin
  if p_pairs is null or jsonb_typeof(p_pairs) <> 'array' then
    raise exception 'p_pairs must be a JSON array';
  end if;

  for v_item in
    select value from jsonb_array_elements(p_pairs)
  loop
    v_school_id    := (v_item->>'school_id')::bigint;
    v_service_date := (v_item->>'service_date')::date;

    if v_school_id is null or v_service_date is null then
      continue;
    end if;

    -- 1) Try existing daily_orders row
    select d.id
    into v_id
    from public.daily_orders d
    where d.school_id = v_school_id
      and d.service_date = v_service_date;

    -- 2) If not found, insert with default portions from schools
    if v_id is null then
      select coalesce(s.default_students_weekday[extract(isodow from v_service_date)::int], s.default_students_num),
             coalesce(s.default_teachers_weekday[extract(isodow from v_service_date)::int], s.default_teacher_num)
      into v_students, v_teachers
      from public.schools s
      where s.id = v_school_id;

      insert into public.daily_orders as d (
        service_date,
        school_id,
        student_portions,
        teacher_portions
      )
      values (
        v_service_date,
        v_school_id,
        coalesce(v_students, 0),
        coalesce(v_teachers, 0)
      )
      returning d.id into v_id;
    end if;

    -- Return row to caller (same shape as your Edge function)
    id           := v_id;
    school_id    := v_school_id;
    service_date := v_service_date;
    return next;
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

CREATE OR REPLACE FUNCTION public.schools_sync_default_attendance_incoming()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
declare
  v_today date := current_date;
  old_stu int2 := old.default_students_num;
  new_stu int2 := new.default_students_num;
  old_tea int2 := old.default_teacher_num;
  new_tea int2 := new.default_teacher_num;
begin
  -- only react when defaults actually change
  if coalesce(old_stu, -32768) = coalesce(new_stu, -32768)
     and coalesce(old_tea, -32768) = coalesce(new_tea, -32768) then
    return new;
  end if;

  -- Current week (Mon-Sun)
  update public.daily_orders d
     set student_portions = case
           when coalesce(old_stu, -32768) <> coalesce(new_stu, -32768)
                and (d.student_portions is null or d.student_portions = old_stu)
                and (new.default_students_weekday is null
                     or extract(isodow from d.service_date) not between 1 and 5)
             then new_stu
           else d.student_portions
         end,
         teacher_portions = case
           when coalesce(old_tea, -32768) <> coalesce(new_tea, -32768)
                and (d.teacher_portions is null or d.teacher_portions = old_tea)
                and (new.default_teachers_weekday is null
                     or extract(isodow from d.service_date) not between 1 and 5)
             then new_tea
           else d.teacher_portions
         end
   where d.school_id = new.id
     and d.service_date >= date_trunc('week', v_today)::date
     and d.service_date <  (date_trunc('week', v_today)::date + 7);

  -- Next week only if service_date has not started yet
  if extract(isodow from v_today) = 1 then
    update public.daily_orders d
       set student_portions = case
             when coalesce(old_stu, -32768) <> coalesce(new_stu, -32768)
                  and (d.student_portions is null or d.student_portions = old_stu)
                and (new.default_students_weekday is null
                     or extract(isodow from d.service_date) not between 1 and 5)
               then new_stu
             else d.student_portions
           end,
           teacher_portions = case
             when coalesce(old_tea, -32768) <> coalesce(new_tea, -32768)
                  and (d.teacher_portions is null or d.teacher_portions = old_tea)
                and (new.default_teachers_weekday is null
                     or extract(isodow from d.service_date) not between 1 and 5)
               then new_tea
             else d.teacher_portions
           end
     where d.school_id = new.id
       and d.service_date >= (date_trunc('week', v_today)::date + 7)
       and d.service_date <  (date_trunc('week', v_today)::date + 14);
  end if;

  return new;
end;
$function$;

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
  SELECT DISTINCT _order_id, d.value::text::bigint
  FROM jsonb_array_elements(_dishes) d(value)
  WHERE d.value IS NOT NULL
    AND NOT EXISTS (
      SELECT 1 FROM public.daily_order_dishes e
      WHERE e.order_id = _order_id AND e.dish_id = d.value::text::bigint
    );

  DELETE FROM public.daily_order_dishes e
  WHERE e.order_id = _order_id
    AND NOT EXISTS (
      SELECT 1 FROM jsonb_array_elements(_dishes) d(value)
      WHERE d.value::text::bigint = e.dish_id
    );
END;
$function$;
-- Only the two new configuration columns are written. Existing order counts stay intact.
-- The existing Schools Syncing webhook remains enabled and receives these school updates.
DO $seed$
DECLARE
  updated_count integer;
BEGIN
  UPDATE public.schools s
  SET default_students_weekday = source.students,
      default_teachers_weekday = source.teachers
  FROM (VALUES
    (7::bigint, 'AN PHÚ (BD)'::text, ARRAY[2400, 2400, 2400, 2400, 2400]::smallint[], ARRAY[100, 100, 100, 100, 100]::smallint[]),
    (8::bigint, 'TIỂU HỌC BÌNH MỸ (P. BÌNH CƠ)'::text, ARRAY[975, 975, 975, 975, 975]::smallint[], ARRAY[50, 50, 50, 50, 50]::smallint[]),
    (9::bigint, 'TIỂU HỌC BÌNH MỸ (X. BÌNH MỸ)'::text, ARRAY[200, 200, 200, 200, 135]::smallint[], ARRAY[20, 20, 20, 20, 15]::smallint[]),
    (10::bigint, 'BÌNH QUỚI - PHÂN HIỆU'::text, ARRAY[1590, 1590, 1590, 1590, 1590]::smallint[], ARRAY[50, 50, 50, 50, 50]::smallint[]),
    (12::bigint, 'HỒ HẢO HỚN'::text, ARRAY[1190, 1190, 1190, 1190, 1190]::smallint[], ARRAY[50, 50, 50, 50, 50]::smallint[]),
    (14::bigint, 'LÊ VĂN THẾ'::text, ARRAY[155, 155, 155, 155, 155]::smallint[], ARRAY[10, 10, 10, 10, 10]::smallint[]),
    (15::bigint, 'LÝ THÁI TỔ'::text, ARRAY[0, 0, 0, 0, 0]::smallint[], ARRAY[0, 0, 0, 0, 0]::smallint[]),
    (17::bigint, 'PHẠM VĂN CỘI'::text, ARRAY[535, 535, 535, 535, 535]::smallint[], ARRAY[30, 30, 30, 30, 30]::smallint[]),
    (19::bigint, 'PHÚ HOÀ ĐÔNG 1'::text, ARRAY[270, 270, 270, 270, 0]::smallint[], ARRAY[20, 20, 20, 20, 0]::smallint[]),
    (23::bigint, 'NGUYỄN THỊ LẮNG'::text, ARRAY[670, 670, 670, 670, 0]::smallint[], ARRAY[30, 30, 30, 30, 0]::smallint[]),
    (24::bigint, 'TÂN THÀNH'::text, ARRAY[675, 675, 675, 675, 675]::smallint[], ARRAY[40, 40, 40, 40, 40]::smallint[]),
    (25::bigint, 'TÂN AN HỘI'::text, ARRAY[370, 370, 370, 370, 370]::smallint[], ARRAY[20, 20, 20, 20, 20]::smallint[]),
    (27::bigint, 'PHÚ HOÀ ĐÔNG 1 - PHÂN HIỆU 2'::text, ARRAY[190, 190, 190, 190, 0]::smallint[], ARRAY[20, 20, 20, 20, 0]::smallint[]),
    (28::bigint, 'PHÚ HOÀ ĐÔNG 1 - PHÂN HIỆU 3'::text, ARRAY[225, 225, 225, 225, 0]::smallint[], ARRAY[20, 20, 20, 20, 0]::smallint[]),
    (32::bigint, 'THUẬN GIAO'::text, ARRAY[800, 800, 800, 800, 800]::smallint[], ARRAY[50, 50, 50, 50, 50]::smallint[]),
    (33::bigint, 'THUẬN AN - PHÂN HIỆU'::text, ARRAY[700, 700, 700, 700, 700]::smallint[], ARRAY[20, 20, 20, 20, 20]::smallint[]),
    (34::bigint, 'TRỊNH HOÀI ĐỨC'::text, ARRAY[1100, 1100, 1100, 1100, 1100]::smallint[], ARRAY[30, 30, 30, 30, 30]::smallint[]),
    (37::bigint, 'TÂN THÀNH - PHÂN HIỆU 2'::text, ARRAY[490, 490, 490, 490, 490]::smallint[], ARRAY[30, 30, 30, 30, 30]::smallint[]),
    (38::bigint, 'VĨNH TÂN - PHÂN HIỆU'::text, ARRAY[280, 280, 280, 280, 280]::smallint[], ARRAY[25, 25, 25, 25, 25]::smallint[]),
    (39::bigint, 'TÂN THÀNH - PHÂN HIỆU 1'::text, ARRAY[490, 490, 490, 490, 490]::smallint[], ARRAY[30, 30, 30, 30, 30]::smallint[]),
    (40::bigint, 'VĨNH TÂN'::text, ARRAY[830, 830, 830, 830, 830]::smallint[], ARRAY[50, 50, 50, 50, 50]::smallint[]),
    (41::bigint, 'PHÚ LỢI'::text, ARRAY[0, 0, 0, 0, 0]::smallint[], ARRAY[0, 0, 0, 0, 0]::smallint[]),
    (42::bigint, 'MN VĨNH TÂN - PHÂN HIỆU'::text, ARRAY[0, 0, 0, 0, 0]::smallint[], ARRAY[0, 0, 0, 0, 0]::smallint[]),
    (43::bigint, 'MN VĨNH TÂN'::text, ARRAY[0, 0, 0, 0, 0]::smallint[], ARRAY[0, 0, 0, 0, 0]::smallint[]),
    (44::bigint, 'MN HOA MAI VÀNG 2'::text, ARRAY[0, 0, 0, 0, 0]::smallint[], ARRAY[0, 0, 0, 0, 0]::smallint[]),
    (45::bigint, 'MN HOA QUỲNH'::text, ARRAY[0, 0, 0, 0, 0]::smallint[], ARRAY[0, 0, 0, 0, 0]::smallint[]),
    (46::bigint, 'PHÚ HOÀ ĐÔNG 1 - PHÂN HIỆU 1'::text, ARRAY[105, 105, 105, 105, 0]::smallint[], ARRAY[10, 10, 10, 10, 0]::smallint[]),
    (47::bigint, 'CHUYÊN HÙNG VƯƠNG (Sáng)'::text, ARRAY[0, 0, 0, 0, 0]::smallint[], ARRAY[0, 0, 0, 0, 0]::smallint[]),
    (48::bigint, 'CHUYÊN HÙNG VƯƠNG (Trưa)'::text, ARRAY[180, 180, 180, 180, 180]::smallint[], ARRAY[0, 0, 0, 0, 0]::smallint[]),
    (49::bigint, 'CHUYÊN HÙNG VƯƠNG (Trưa Mặn 2)'::text, ARRAY[180, 180, 180, 180, 180]::smallint[], ARRAY[0, 0, 0, 0, 0]::smallint[]),
    (50::bigint, 'CHUYÊN HÙNG VƯƠNG (Chiều)'::text, ARRAY[180, 180, 180, 180, 180]::smallint[], ARRAY[0, 0, 0, 0, 0]::smallint[]),
    (52::bigint, 'BÌNH QUỚI'::text, ARRAY[1750, 1750, 1750, 1750, 1750]::smallint[], ARRAY[0, 0, 0, 0, 0]::smallint[]),
    (53::bigint, 'CHUYÊN HÙNG VƯƠNG (Chiều Mặn 2)'::text, ARRAY[180, 180, 180, 180, 180]::smallint[], ARRAY[0, 0, 0, 0, 0]::smallint[]),
    (54::bigint, 'TÂN AN HỘI (Mặn 2)'::text, ARRAY[370, 370, 370, 370, 370]::smallint[], ARRAY[20, 20, 20, 20, 20]::smallint[])
  ) AS source(id, expected_name, students, teachers)
  WHERE s.id = source.id AND s.name IS NOT DISTINCT FROM source.expected_name AND s.is_active;
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  IF updated_count <> 34 THEN
    RAISE EXCEPTION 'Expected 34 matching active school identities; found %; transaction aborted', updated_count;
  END IF;
END;
$seed$;
-- POSTFLIGHT: any change to previously entered business data aborts this migration.
DO $verify_preservation$
DECLARE r record; rows_count bigint; data_hash text; omitted text;
BEGIN
  IF (SELECT count(*) FROM pg_temp.ops_v1_preserved_rows) <>
     (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname IN ('public','ops_v2') AND c.relkind='r') THEN
    RAISE EXCEPTION 'OPS_V1_BUSINESS_TABLE_SET_CHANGED';
  END IF;
  FOR r IN SELECT * FROM pg_temp.ops_v1_preserved_rows
  LOOP
    omitted := CASE WHEN r.schema_name='public' AND r.table_name='schools'
      THEN '{default_students_weekday,default_teachers_weekday}' ELSE '{}' END;
    EXECUTE format($q$SELECT count(*),md5(coalesce(string_agg(md5((to_jsonb(t)-%L::text[])::text),''
      ORDER BY md5((to_jsonb(t)-%L::text[])::text)),'')) FROM %I.%I t$q$,
      omitted,omitted,r.schema_name,r.table_name) INTO rows_count,data_hash;
    IF rows_count IS DISTINCT FROM r.row_count OR data_hash IS DISTINCT FROM r.fingerprint THEN
      RAISE EXCEPTION 'OPS_V1_EXISTING_DATA_CHANGED: %.%',r.schema_name,r.table_name;
    END IF;
  END LOOP;
  IF EXISTS (SELECT 1 FROM pg_temp.ops_v1_preserved_security b LEFT JOIN pg_proc p ON p.oid=b.oid
    WHERE p.oid IS NULL OR (p.proowner,p.proacl,p.prosecdef,p.proconfig,p.proisstrict,p.provolatile,p.prorettype,p.proargtypes)
      IS DISTINCT FROM (b.proowner,b.proacl,b.prosecdef,b.proconfig,b.proisstrict,b.provolatile,b.prorettype,b.proargtypes)) THEN
    RAISE EXCEPTION 'OPS_V1_EXISTING_FUNCTION_SECURITY_CHANGED';
  END IF;
END;
$verify_preservation$;
COMMIT;
