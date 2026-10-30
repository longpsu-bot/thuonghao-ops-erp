-- Add the authoritative School Type expected by connected School previews.
-- Preserve the compatibility selector and every existing composition field.
set role atlas_owner;

create or replace function atlas_core.rmvp_02b_resolve_effective_composition(
  target_as_of_date date,
  target_school_id uuid,
  target_dish_id uuid,
  proposed_adjustment jsonb default null,
  excluded_adjustment_id uuid default null,
  historical_recipe_version_id uuid default null
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  return atlas_core.rmvp_02b_resolve_selected_composition(
    target_as_of_date,
    target_school_id,
    target_dish_id,
    proposed_adjustment,
    excluded_adjustment_id,
    historical_recipe_version_id
  ) || pg_catalog.jsonb_build_object(
    'school_type_id', (
      select school.school_type_id
      from atlas_admin.schools school
      where school.school_id = target_school_id
    )
  );
end;
$$;

reset role;
