do $$
begin
  drop table if exists extensions.pantry_02_downstream_baseline;

  insert into atlas_admin.ingredients (
    ingredient_id,
    ingredient_code,
    ingredient_name,
    ingredient_group,
    ingredient_status,
    purchase_unit_id,
    ingredient_type,
    shopping_type,
    order_step
  )
  select
    'b6400000-0000-0000-0000-000000000050'::uuid,
    'rmvp05-browser-pantry',
    'RMVP-05 browser pantry ingredient',
    'LOCAL_ACCEPTANCE',
    'ACTIVE',
    unit.unit_id,
    'LOCAL_ACCEPTANCE',
    'LOCAL_ACCEPTANCE',
    0.000001
  from atlas_admin.units unit
  where unit.unit_status = 'ACTIVE'
  order by unit.unit_id
  limit 1
  on conflict (ingredient_code) do nothing;

  if not exists (
    select 1
    from atlas_planning.need_generation_calculation_contracts
    where contract_code = 'school_catering_proportional_per_basis'
  ) then
    insert into atlas_planning.need_generation_calculation_contracts (
      need_generation_calculation_contract_id,
      contract_code,
      current_revision_id,
      version
    ) values (
      'b6400000-0000-0000-0000-000000000040',
      'school_catering_proportional_per_basis',
      'b6400000-0000-0000-0000-000000000041',
      1
    );

    insert into atlas_planning.need_generation_calculation_contract_revisions (
      need_generation_calculation_contract_revision_id,
      need_generation_calculation_contract_id,
      revision_number,
      formula_kind,
      quantity_precision,
      quantity_scale,
      factor_precision,
      factor_scale,
      final_coercion_mode,
      approved_by_actor_id,
      approved_at
    ) values (
      'b6400000-0000-0000-0000-000000000041',
      'b6400000-0000-0000-0000-000000000040',
      1,
      'STUDENT_TEACHER_PORTIONS_X_RECIPE_QTY_DIV_BASIS',
      20,
      6,
      24,
      12,
      'POSTGRES_NUMERIC_SCALE_HALF_AWAY_FROM_ZERO',
      'b6000000-0000-0000-0000-000000000001',
      transaction_timestamp()
    );
  end if;
end;
$$;
