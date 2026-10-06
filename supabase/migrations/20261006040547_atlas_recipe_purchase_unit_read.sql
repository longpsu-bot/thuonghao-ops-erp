-- Extend only the existing v2 read/readback. Immutable compositions and the
-- D-047 release guard keep their stored Units and validation semantics.
grant atlas_owner to postgres with set true;
set role atlas_owner;

create or replace function atlas_core.uiq03a_workbench_payload(
  p_actor_id uuid,
  p_dish_id uuid,
  p_school_type_id uuid
)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select atlas_core.rmvp_02a_recipe_workbench_payload()
    || pg_catalog.jsonb_build_object(
      'selected_recipe', atlas_core.uiq03a_selection_payload(
        p_actor_id, p_dish_id, p_school_type_id
      ),
      'ingredients', (
        select coalesce(pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'ingredient_id', ingredient.ingredient_id,
            'ingredient_code', ingredient.ingredient_code,
            'ingredient_name', ingredient.ingredient_name,
            'ingredient_status', ingredient.ingredient_status,
            'purchase_unit_id', ingredient.purchase_unit_id,
            'purchase_unit_name', purchase_unit.unit_name
          ) order by ingredient.ingredient_name, ingredient.ingredient_id
        ), '[]'::jsonb)
        from atlas_admin.ingredients ingredient
        left join atlas_admin.units purchase_unit
          on purchase_unit.unit_id = ingredient.purchase_unit_id
      )
    );
$$;

reset role;
grant atlas_owner to postgres with set false;
