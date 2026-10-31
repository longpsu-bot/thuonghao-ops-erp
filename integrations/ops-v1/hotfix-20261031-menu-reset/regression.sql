savepoint scenario;

-- The same source signature must still reconcile an actual Dish-set change.
select pg_temp.fn_upsert_weekly_menu('2026-11-02','fixture','retained-sig',
  '[{"school_id":1,"service_date":"2026-11-02","dish_id":12},
    {"school_id":1,"service_date":"2026-11-02","dish_id":13}]');
select pg_temp.assert_override(1,102),pg_temp.assert_override(1,104),
  pg_temp.assert_override(1,105),pg_temp.assert_override(2,101);
select pg_temp.assert_dish(1,12);
do $$ begin
  if exists(select 1 from actual_need_overrides where school_id=1 and ingredient_id in (101,103)) then
    raise exception 'affected Ingredients were not reset';
  end if;
  if (select array_agg(dish_id order by dish_id) from daily_order_dishes where order_id=1) <> array[12,13]::bigint[] then
    raise exception 'wrong final weekly Dish set';
  end if;
end $$;
\echo PASS weekly partial replacement preserves unrelated saved rows and identities
rollback to scenario;

insert into menu_import_weeks values ('2026-11-02','google_sheet','fixture',
  'retained-sig',2,now(),null);
do $$ declare result jsonb; begin
  result := pg_temp.fn_upsert_weekly_menu('2026-11-02','fixture','retained-sig',
    '[{"school_id":1,"service_date":"2026-11-02","dish_id":11},
      {"school_id":1,"service_date":"2026-11-02","dish_id":12}]');
  if result->>'skipped_by_signature' <> 'true'
    or result->>'changed_schooldays' <> '0' then
    raise exception 'unchanged replay reporting changed: %',result;
  end if;
end $$;
select pg_temp.assert_override(1,101),pg_temp.assert_override(1,102);
select pg_temp.assert_dish(1,11),pg_temp.assert_dish(1,12);
\echo PASS unchanged weekly replay
rollback to scenario;

select pg_temp.sync_daily_order_dishes(1,'[11,12,12]','test');
select pg_temp.assert_override(1,101),pg_temp.assert_override(1,102);
select pg_temp.assert_dish(1,11),pg_temp.assert_dish(1,12);
\echo PASS shared sync is idempotent and deduplicates input
rollback to scenario;

select pg_temp.fn_save_daily_menus(
  '[{"school_id":1,"service_date":"2026-11-02","mon_canh":12,"mon_man":13}]');
select pg_temp.assert_override(1,102),pg_temp.assert_override(1,105),
  pg_temp.assert_override(2,101);
select pg_temp.assert_dish(1,12);
\echo PASS manual daily menu save preserves unrelated rows
rollback to scenario;

select pg_temp.fn_update_order_dishes('{"1":[12,13]}');
select pg_temp.assert_override(1,102),pg_temp.assert_override(1,105),
  pg_temp.assert_override(2,101);
select pg_temp.assert_dish(1,12);
\echo PASS order Dish editor preserves unrelated rows
rollback to scenario;

delete from daily_order_dishes where order_id=1 and dish_id=12;
select pg_temp.sync_daily_order_dishes(1,'[13]','test');
select pg_temp.assert_override(1,105),pg_temp.assert_override(1,104),
  pg_temp.assert_override(2,101);
do $$ begin
  if exists(select 1 from actual_need_overrides where school_id=1 and ingredient_id in (101,103)) then
    raise exception 'single-Dish replacement did not reset affected Ingredients';
  end if;
end $$;
\echo PASS single-Dish replacement never transiently clears unrelated non-pantry rows
rollback to scenario;

select pg_temp.fn_update_order_dishes('{"1":[]}');
select pg_temp.assert_override(1,104),pg_temp.assert_override(2,101);
do $$ begin
  if exists(select 1 from daily_order_dishes where order_id=1)
    or (select count(*) from actual_need_overrides where school_id=1) <> 1 then
    raise exception 'explicit clear-day/pantry behavior changed';
  end if;
end $$;
\echo PASS explicit clear-day retains existing pantry protection
rollback to scenario;

do $$ begin
  begin
    perform pg_temp.fn_update_order_dishes('{"1":[12,-1]}');
    raise exception 'invalid Dish accepted';
  exception when foreign_key_violation then null;
  end;
  perform pg_temp.assert_override(1,101);
  perform pg_temp.assert_override(1,102);
  perform pg_temp.assert_dish(1,11);
  perform pg_temp.assert_dish(1,12);
end $$;
\echo PASS invalid Dish fails atomically
rollback to scenario;
