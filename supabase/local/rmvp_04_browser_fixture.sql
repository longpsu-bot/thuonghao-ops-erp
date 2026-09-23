do $$
declare
  v_now timestamptz := pg_catalog.clock_timestamp();
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
  where unit.unit_code = 'kg'
    and unit.dimension_code = 'MASS'
    and unit.unit_status = 'ACTIVE'
  order by unit.unit_id
  limit 1
  on conflict (ingredient_code) do nothing;

  insert into atlas_planning.planning_quantity_policies (
    planning_quantity_policy_id,
    unit_id,
    created_by_actor_id,
    created_at
  )
  select
    md5('rmvp04-browser-policy:' || unit.unit_id::text)::uuid,
    unit.unit_id,
    'a1010000-0000-4000-8000-000000000001'::uuid,
    v_now
  from atlas_admin.units unit
  where unit.unit_code in ('kg', 'rmvp02b-local-kg')
    and unit.dimension_code = 'MASS'
    and unit.unit_status = 'ACTIVE'
  on conflict (unit_id) do nothing;

  insert into atlas_planning.planning_quantity_policy_revisions (
    planning_quantity_policy_revision_id,
    planning_quantity_policy_id,
    unit_id,
    revision_number,
    predecessor_policy_revision_id,
    planning_step,
    effective_from,
    policy_revision_status,
    created_by_actor_id,
    created_at
  )
  select
    md5('rmvp04-browser-policy-revision:' || policy.unit_id::text)::uuid,
    policy.planning_quantity_policy_id,
    policy.unit_id,
    1,
    null,
    0.01,
    date '2026-01-01',
    'DRAFT',
    'a1010000-0000-4000-8000-000000000001'::uuid,
    v_now
  from atlas_planning.planning_quantity_policies policy
  join atlas_admin.units unit
    on unit.unit_id = policy.unit_id
   and unit.unit_code in ('kg', 'rmvp02b-local-kg')
   and unit.dimension_code = 'MASS'
   and unit.unit_status = 'ACTIVE'
  where not exists (
    select 1
    from atlas_planning.planning_quantity_policy_revisions revision
    where revision.planning_quantity_policy_id =
      policy.planning_quantity_policy_id
  );

  update atlas_planning.planning_quantity_policy_revisions revision
  set policy_revision_status = 'ACTIVE',
      approved_by_actor_id = 'a1010000-0000-4000-8000-000000000001'::uuid,
      approved_at = v_now,
      activated_by_actor_id = 'a1010000-0000-4000-8000-000000000001'::uuid,
      activated_at = v_now
  from atlas_admin.units unit
  where unit.unit_id = revision.unit_id
    and unit.unit_code in ('kg', 'rmvp02b-local-kg')
    and unit.dimension_code = 'MASS'
    and unit.unit_status = 'ACTIVE'
    and revision.policy_revision_status = 'DRAFT'
    and revision.revision_number = 1
    and revision.predecessor_policy_revision_id is null
    and revision.planning_step = 0.01
    and revision.effective_from = date '2026-01-01'
    and revision.created_by_actor_id =
      'a1010000-0000-4000-8000-000000000001'::uuid;

end;
$$;
