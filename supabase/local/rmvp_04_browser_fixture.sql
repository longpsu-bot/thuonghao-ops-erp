do $$
begin
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
