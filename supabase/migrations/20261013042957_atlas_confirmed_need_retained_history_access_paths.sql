-- Membership completeness already filters this exact operational tuple.
-- Separate School/Ingredient bitmaps otherwise include every retained date.
create index theoretical_need_lines_positive_operational_lookup
  on atlas_planning.theoretical_need_lines (
    service_date, school_id, ingredient_id, unit_id, theoretical_need_line_id
  ) where line_disposition = 'ACTIVE' and theoretical_quantity > 0;

-- Partition guards group/order by release-member identity. The old member-ID
-- primary-key path walked other releases to keep that ordering.
create index need_generation_release_lines_partition_lookup
  on atlas_planning.need_generation_release_snapshot_lines (
    need_generation_release_snapshot_id, need_generation_release_snapshot_line_id
  ) include (theoretical_need_line_id);

-- Ready dates are derived exclusively inside this range. Keep the existing
-- readiness/source checks, but bound expensive projection before the JSON join.
do $draft_date_scope$
declare
  target regprocedure := 'atlas_api.create_school_catering_purchase_order_drafts(jsonb)'::regprocedure;
  original text := $old$    where to_char(f.service_date,'YYYY-MM-DD') in ($old$;
  replacement text := $new$    where f.service_date between v_date_start and v_date_end
      and to_char(f.service_date,'YYYY-MM-DD') in ($new$;
  definition text := pg_get_functiondef(target);
  prior pg_catalog.pg_proc%rowtype;
  updated pg_catalog.pg_proc%rowtype;
begin
  select * into strict prior from pg_catalog.pg_proc where oid=target;
  if (length(definition)-length(replace(definition,original,'')))/length(original)<>1 then
    raise exception 'Draft ready-date query boundary mismatch';
  end if;
  execute replace(definition,original,replacement);
  select * into strict updated from pg_catalog.pg_proc where oid=target;
  if (to_jsonb(updated)-'prosrc') is distinct from (to_jsonb(prior)-'prosrc') then
    raise exception 'Draft date scoping changed function catalog posture';
  end if;
end;
$draft_date_scope$;
