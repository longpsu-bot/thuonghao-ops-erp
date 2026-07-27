begin;

create schema if not exists extensions;
create extension if not exists pgtap with schema extensions;
select no_plan();

grant usage on schema extensions to authenticated;
grant execute on all functions in schema extensions to authenticated;

select is(
  (
    select array_agg(capability_code order by capability_code)::text[]
    from atlas_core.capabilities
    where capability_code like 'master_data.recipe_adjustments.%'
  ),
  array[
    'master_data.recipe_adjustments.cancel',
    'master_data.recipe_adjustments.read',
    'master_data.recipe_adjustments.write'
  ]::text[],
  'RMVP-02B registers exactly the read, write, and cancel capabilities'
);

select is(
  (
    select array_agg(p.proname order by p.proname)::text[]
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname in (
        'get_recipe_adjustment_workbench',
        'resolve_effective_recipe_composition',
        'preview_recipe_composition_adjustment',
        'create_recipe_composition_adjustment',
        'supersede_recipe_composition_adjustment',
        'cancel_recipe_composition_adjustment'
      )
  ),
  array[
    'cancel_recipe_composition_adjustment',
    'create_recipe_composition_adjustment',
    'get_recipe_adjustment_workbench',
    'preview_recipe_composition_adjustment',
    'resolve_effective_recipe_composition',
    'supersede_recipe_composition_adjustment'
  ]::text[],
  'RMVP-02B exposes exactly six bounded browser APIs'
);

select ok(
  (
    select bool_and(
      p.prosecdef
      and p.proconfig = array['search_path=""']::text[]
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')
      and not has_function_privilege('anon', p.oid, 'EXECUTE')
      and not has_function_privilege('service_role', p.oid, 'EXECUTE')
    )
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'atlas_api'
      and p.proname in (
        'get_recipe_adjustment_workbench',
        'resolve_effective_recipe_composition',
        'preview_recipe_composition_adjustment',
        'create_recipe_composition_adjustment',
        'supersede_recipe_composition_adjustment',
        'cancel_recipe_composition_adjustment'
      )
  ),
  'all RMVP-02B APIs use fixed search paths and the browser-key role boundary'
);

select is(
  (
    select array_agg(
      p.proname || '=' || r.rolname
      order by p.proname
    )::text[]
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    join pg_roles r on r.oid = p.proowner
    where n.nspname = 'atlas_api'
      and p.proname in (
        'get_recipe_adjustment_workbench',
        'resolve_effective_recipe_composition',
        'preview_recipe_composition_adjustment',
        'create_recipe_composition_adjustment',
        'supersede_recipe_composition_adjustment',
        'cancel_recipe_composition_adjustment'
      )
  ),
  array[
    'cancel_recipe_composition_adjustment=atlas_master_data_command_runtime',
    'create_recipe_composition_adjustment=atlas_master_data_command_runtime',
    'get_recipe_adjustment_workbench=atlas_read_runtime',
    'preview_recipe_composition_adjustment=atlas_read_runtime',
    'resolve_effective_recipe_composition=atlas_read_runtime',
    'supersede_recipe_composition_adjustment=atlas_master_data_command_runtime'
  ]::text[],
  'read, preview, and command APIs have the approved runtime ownership split'
);

select is(
  (
    select array_agg(tablename order by tablename)::text[]
    from pg_tables
    where schemaname = 'atlas_admin'
      and tablename like 'recipe_composition_adjustment%'
  ),
  array[
    'recipe_composition_adjustment_revisions',
    'recipe_composition_adjustments'
  ]::text[],
  'one root and one immutable revision relation form the persistence boundary'
);

select ok(
  (
    select bool_and(c.relrowsecurity and c.relforcerowsecurity)
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'atlas_admin'
      and c.relname in (
        'recipe_composition_adjustments',
        'recipe_composition_adjustment_revisions'
      )
  )
  and not has_schema_privilege('authenticated', 'atlas_admin', 'USAGE')
  and not has_schema_privilege('anon', 'atlas_admin', 'USAGE')
  and not has_schema_privilege('service_role', 'atlas_admin', 'USAGE'),
  'private adjustment relations force RLS and remain unavailable to API roles'
);

insert into atlas_core.actors (
  actor_id, actor_type, display_name
) values
  (
    'b2000000-0000-0000-0000-000000000001',
    'HUMAN',
    'RMVP-02B authorized adjustment operator'
  ),
  (
    'b2000000-0000-0000-0000-000000000002',
    'HUMAN',
    'RMVP-02B denied operator'
  );

insert into atlas_core.actor_auth_subjects (
  actor_auth_subject_id, actor_id, auth_subject_id
) values
  (
    'b2000000-0000-0000-0000-000000000011',
    'b2000000-0000-0000-0000-000000000001',
    'b2000000-0000-0000-0000-000000000101'
  ),
  (
    'b2000000-0000-0000-0000-000000000012',
    'b2000000-0000-0000-0000-000000000002',
    'b2000000-0000-0000-0000-000000000102'
  );

insert into atlas_core.roles (
  role_id, role_code, role_name
) values
  (
    'b2000000-0000-0000-0000-000000000020',
    'rmvp02b.adjustment_operator',
    'RMVP-02B adjustment operator'
  ),
  (
    'b2000000-0000-0000-0000-000000000021',
    'rmvp02b.no_capability',
    'RMVP-02B no capability'
  );

insert into atlas_core.role_capabilities (role_id, capability_id)
select 'b2000000-0000-0000-0000-000000000020', capability_id
from atlas_core.capabilities
where capability_code like 'master_data.recipe_adjustments.%';

insert into atlas_core.actor_role_memberships (actor_id, role_id) values
  (
    'b2000000-0000-0000-0000-000000000001',
    'b2000000-0000-0000-0000-000000000020'
  ),
  (
    'b2000000-0000-0000-0000-000000000002',
    'b2000000-0000-0000-0000-000000000021'
  );

insert into atlas_core.actor_scopes (actor_id, scope_kind) values
  ('b2000000-0000-0000-0000-000000000001', 'GLOBAL'),
  ('b2000000-0000-0000-0000-000000000002', 'GLOBAL');

insert into atlas_admin.customers (
  customer_id, customer_code, customer_name, customer_type
) values (
  'b2100000-0000-0000-0000-000000000100',
  'rmvp02b-school-customer',
  'RMVP-02B school customer',
  'SCHOOL_CATERING'
);

insert into atlas_admin.delivery_locations (
  delivery_location_id, customer_id, location_code, location_name,
  address_text, timezone_name
) values (
  'b2100000-0000-0000-0000-000000000101',
  'b2100000-0000-0000-0000-000000000100',
  'rmvp02b-school-location',
  'RMVP-02B school location',
  'Synthetic RMVP-02B address',
  'Asia/Ho_Chi_Minh'
);

insert into atlas_admin.school_types (
  school_type_id, school_type_code, school_type_name
) values (
  'b2100000-0000-0000-0000-000000000110',
  'rmvp02b-primary',
  'RMVP-02B Primary'
);

insert into atlas_admin.schools (
  school_id, customer_id, school_code, school_name, school_type_id,
  default_delivery_location_id, display_order
) values (
  'b2100000-0000-0000-0000-000000000120',
  'b2100000-0000-0000-0000-000000000100',
  'rmvp02b-school',
  'RMVP-02B School',
  'b2100000-0000-0000-0000-000000000110',
  'b2100000-0000-0000-0000-000000000101',
  20
);

insert into atlas_admin.units (
  unit_id, unit_code, unit_name, dimension_code, decimal_scale
) values (
  'b2200000-0000-0000-0000-000000000010',
  'rmvp02b-kg',
  'RMVP-02B kilogram',
  'MASS',
  3
);

insert into atlas_admin.ingredients (
  ingredient_id, ingredient_code, ingredient_name, ingredient_group,
  purchase_unit_id, ingredient_type, shopping_type, order_step
) values
  (
    'b2200000-0000-0000-0000-000000000020',
    'rmvp02b-a',
    'RMVP-02B Ingredient A',
    'Food',
    'b2200000-0000-0000-0000-000000000010',
    'Food',
    'Planned',
    1
  ),
  (
    'b2200000-0000-0000-0000-000000000021',
    'rmvp02b-b',
    'RMVP-02B Ingredient B',
    'Food',
    'b2200000-0000-0000-0000-000000000010',
    'Food',
    'Planned',
    1
  ),
  (
    'b2200000-0000-0000-0000-000000000022',
    'rmvp02b-c',
    'RMVP-02B Ingredient C',
    'Food',
    'b2200000-0000-0000-0000-000000000010',
    'Food',
    'Planned',
    1
  ),
  (
    'b2200000-0000-0000-0000-000000000023',
    'rmvp02b-d',
    'RMVP-02B Ingredient D',
    'Food',
    'b2200000-0000-0000-0000-000000000010',
    'Food',
    'Planned',
    1
  ),
  (
    'b2200000-0000-0000-0000-000000000024',
    'rmvp02b-e',
    'RMVP-02B Ingredient E',
    'Food',
    'b2200000-0000-0000-0000-000000000010',
    'Food',
    'Planned',
    1
  ),
  (
    'b2200000-0000-0000-0000-000000000025',
    'rmvp02b-f',
    'RMVP-02B Ingredient F',
    'Food',
    'b2200000-0000-0000-0000-000000000010',
    'Food',
    'Planned',
    1
  );

insert into atlas_admin.dishes (
  dish_id, dish_code, dish_name, dish_status, display_order
) values
  (
    'b2200000-0000-0000-0000-000000000100',
    'rmvp02b-main-dish',
    'RMVP-02B Main Dish',
    'ACTIVE',
    10
  ),
  (
    'b2200000-0000-0000-0000-000000000101',
    'rmvp02b-cycle-dish',
    'RMVP-02B Cycle Dish',
    'ACTIVE',
    11
  );

insert into atlas_admin.recipes (
  recipe_id, dish_id
) values
  (
    'b2200000-0000-0000-0000-000000000200',
    'b2200000-0000-0000-0000-000000000100'
  ),
  (
    'b2200000-0000-0000-0000-000000000201',
    'b2200000-0000-0000-0000-000000000101'
  );

insert into atlas_admin.recipe_versions (
  recipe_version_id, recipe_id, version_number, basis_portions,
  created_by_actor_id, source_evidence
) values
  (
    'b2200000-0000-0000-0000-000000000300',
    'b2200000-0000-0000-0000-000000000200',
    1,
    100,
    'b2000000-0000-0000-0000-000000000001',
    '{"source_kind":"RMVP02B_TEST"}'::jsonb
  ),
  (
    'b2200000-0000-0000-0000-000000000301',
    'b2200000-0000-0000-0000-000000000201',
    1,
    100,
    'b2000000-0000-0000-0000-000000000001',
    '{"source_kind":"RMVP02B_TEST"}'::jsonb
  );

insert into atlas_admin.recipe_lines (
  recipe_line_id, recipe_id, line_code
) values
  (
    'b2200000-0000-0000-0000-000000000400',
    'b2200000-0000-0000-0000-000000000200',
    'main-a'
  ),
  (
    'b2200000-0000-0000-0000-000000000401',
    'b2200000-0000-0000-0000-000000000200',
    'main-d'
  ),
  (
    'b2200000-0000-0000-0000-000000000402',
    'b2200000-0000-0000-0000-000000000201',
    'cycle-d'
  );

insert into atlas_admin.recipe_line_revisions (
  recipe_line_revision_id, recipe_id, recipe_version_id, recipe_line_id,
  line_revision_number, ingredient_id, quantity_per_basis, unit_id,
  created_by_actor_id
) values
  (
    'b2200000-0000-0000-0000-000000000500',
    'b2200000-0000-0000-0000-000000000200',
    'b2200000-0000-0000-0000-000000000300',
    'b2200000-0000-0000-0000-000000000400',
    1,
    'b2200000-0000-0000-0000-000000000020',
    10,
    'b2200000-0000-0000-0000-000000000010',
    'b2000000-0000-0000-0000-000000000001'
  ),
  (
    'b2200000-0000-0000-0000-000000000501',
    'b2200000-0000-0000-0000-000000000200',
    'b2200000-0000-0000-0000-000000000300',
    'b2200000-0000-0000-0000-000000000401',
    1,
    'b2200000-0000-0000-0000-000000000025',
    5,
    'b2200000-0000-0000-0000-000000000010',
    'b2000000-0000-0000-0000-000000000001'
  ),
  (
    'b2200000-0000-0000-0000-000000000502',
    'b2200000-0000-0000-0000-000000000201',
    'b2200000-0000-0000-0000-000000000301',
    'b2200000-0000-0000-0000-000000000402',
    1,
    'b2200000-0000-0000-0000-000000000023',
    8,
    'b2200000-0000-0000-0000-000000000010',
    'b2000000-0000-0000-0000-000000000001'
  );

set constraints all immediate;

update atlas_admin.recipe_versions
set recipe_version_status = 'VALIDATED',
    validated_by_actor_id =
      'b2000000-0000-0000-0000-000000000001',
    validated_at = transaction_timestamp() - interval '2 hours'
where recipe_version_id in (
  'b2200000-0000-0000-0000-000000000300',
  'b2200000-0000-0000-0000-000000000301'
);

update atlas_admin.recipe_versions
set recipe_version_status = 'RELEASED_FOR_PLANNING',
    released_by_actor_id =
      'b2000000-0000-0000-0000-000000000001',
    released_at = transaction_timestamp() - interval '1 hour'
where recipe_version_id in (
  'b2200000-0000-0000-0000-000000000300',
  'b2200000-0000-0000-0000-000000000301'
);

set constraints all deferred;

insert into atlas_admin.recipe_composition_adjustments (
  recipe_composition_adjustment_id, scope_kind, action_kind, school_id,
  dish_id, school_type_id, target_ingredient_id, target_recipe_line_id,
  adjustment_line_id, created_by_actor_id, updated_by_actor_id
) values
  (
    'b2300000-0000-0000-0000-000000000001',
    'SYSTEM_INGREDIENT',
    'REPLACE',
    null,
    null,
    null,
    'b2200000-0000-0000-0000-000000000020',
    null,
    null,
    'b2000000-0000-0000-0000-000000000001',
    'b2000000-0000-0000-0000-000000000001'
  ),
  (
    'b2300000-0000-0000-0000-000000000002',
    'SYSTEM_DISH',
    'ADJUST_QUANTITY',
    null,
    'b2200000-0000-0000-0000-000000000100',
    'b2100000-0000-0000-0000-000000000110',
    null,
    'b2200000-0000-0000-0000-000000000400',
    null,
    'b2000000-0000-0000-0000-000000000001',
    'b2000000-0000-0000-0000-000000000001'
  ),
  (
    'b2300000-0000-0000-0000-000000000003',
    'SCHOOL',
    'REPLACE',
    'b2100000-0000-0000-0000-000000000120',
    null,
    null,
    'b2200000-0000-0000-0000-000000000021',
    null,
    null,
    'b2000000-0000-0000-0000-000000000001',
    'b2000000-0000-0000-0000-000000000001'
  ),
  (
    'b2300000-0000-0000-0000-000000000004',
    'SCHOOL_DISH',
    'ADJUST_QUANTITY',
    'b2100000-0000-0000-0000-000000000120',
    'b2200000-0000-0000-0000-000000000100',
    null,
    null,
    'b2200000-0000-0000-0000-000000000400',
    null,
    'b2000000-0000-0000-0000-000000000001',
    'b2000000-0000-0000-0000-000000000001'
  ),
  (
    'b2300000-0000-0000-0000-000000000005',
    'SYSTEM_INGREDIENT',
    'REPLACE',
    null,
    null,
    null,
    'b2200000-0000-0000-0000-000000000023',
    null,
    null,
    'b2000000-0000-0000-0000-000000000001',
    'b2000000-0000-0000-0000-000000000001'
  );

insert into atlas_admin.recipe_composition_adjustment_revisions (
  recipe_composition_adjustment_revision_id,
  recipe_composition_adjustment_id, scope_kind, action_kind,
  revision_number, effective_from, effective_to,
  substitute_ingredient_id, quantity_per_basis, unit_id,
  reason_code, reason_note, source_evidence, created_by_actor_id
) values
  (
    'b2310000-0000-0000-0000-000000000001',
    'b2300000-0000-0000-0000-000000000001',
    'SYSTEM_INGREDIENT',
    'REPLACE',
    1,
    date '2026-07-01',
    null,
    'b2200000-0000-0000-0000-000000000021',
    null,
    null,
    'SYSTEM_SUBSTITUTION',
    'Approved system Ingredient substitution.',
    '{"source":"rmvp02b-test"}'::jsonb,
    'b2000000-0000-0000-0000-000000000001'
  ),
  (
    'b2310000-0000-0000-0000-000000000002',
    'b2300000-0000-0000-0000-000000000002',
    'SYSTEM_DISH',
    'ADJUST_QUANTITY',
    1,
    date '2026-07-01',
    null,
    null,
    20,
    null,
    'DISH_QUANTITY',
    'Approved Dish quantity adjustment.',
    '{"source":"rmvp02b-test"}'::jsonb,
    'b2000000-0000-0000-0000-000000000001'
  ),
  (
    'b2310000-0000-0000-0000-000000000003',
    'b2300000-0000-0000-0000-000000000003',
    'SCHOOL',
    'REPLACE',
    1,
    date '2026-07-01',
    null,
    'b2200000-0000-0000-0000-000000000022',
    null,
    null,
    'SCHOOL_SUBSTITUTION',
    'Approved School substitution.',
    '{"source":"rmvp02b-test"}'::jsonb,
    'b2000000-0000-0000-0000-000000000001'
  ),
  (
    'b2310000-0000-0000-0000-000000000004',
    'b2300000-0000-0000-0000-000000000004',
    'SCHOOL_DISH',
    'ADJUST_QUANTITY',
    1,
    date '2026-07-01',
    null,
    null,
    30,
    null,
    'SCHOOL_DISH_QUANTITY',
    'Approved School and Dish quantity adjustment.',
    '{"source":"rmvp02b-test"}'::jsonb,
    'b2000000-0000-0000-0000-000000000001'
  ),
  (
    'b2310000-0000-0000-0000-000000000005',
    'b2300000-0000-0000-0000-000000000005',
    'SYSTEM_INGREDIENT',
    'REPLACE',
    1,
    date '2026-08-01',
    null,
    'b2200000-0000-0000-0000-000000000024',
    null,
    null,
    'CYCLE_EDGE',
    'First deterministic cycle edge.',
    '{"source":"rmvp02b-test"}'::jsonb,
    'b2000000-0000-0000-0000-000000000001'
  );

update atlas_admin.recipe_composition_adjustments root
set current_revision_id =
      (
        select revision.recipe_composition_adjustment_revision_id
        from atlas_admin.recipe_composition_adjustment_revisions revision
        where revision.recipe_composition_adjustment_id =
          root.recipe_composition_adjustment_id
      ),
    current_revision_number = 1;

-- Temporal-integrity fixtures deliberately retain complete revision chains.
insert into atlas_admin.recipe_composition_adjustments (
  recipe_composition_adjustment_id, scope_kind, action_kind, school_id,
  dish_id, school_type_id, target_ingredient_id, target_recipe_line_id,
  adjustment_line_id, lifecycle_status, version,
  created_by_actor_id, updated_by_actor_id
) values
  (
    'b2500000-0000-0000-0000-000000000001',
    'SYSTEM_DISH',
    'ADJUST_QUANTITY',
    null,
    'b2200000-0000-0000-0000-000000000101',
    null,
    null,
    'b2200000-0000-0000-0000-000000000402',
    null,
    'ACTIVE',
    2,
    'b2000000-0000-0000-0000-000000000001',
    'b2000000-0000-0000-0000-000000000001'
  ),
  (
    'b2500000-0000-0000-0000-000000000002',
    'SCHOOL_DISH',
    'ADJUST_QUANTITY',
    'b2100000-0000-0000-0000-000000000120',
    'b2200000-0000-0000-0000-000000000101',
    null,
    null,
    'b2200000-0000-0000-0000-000000000402',
    null,
    'CANCELLED',
    2,
    'b2000000-0000-0000-0000-000000000001',
    'b2000000-0000-0000-0000-000000000001'
  );

insert into atlas_admin.recipe_composition_adjustment_revisions (
  recipe_composition_adjustment_revision_id,
  recipe_composition_adjustment_id,
  scope_kind,
  action_kind,
  revision_number,
  predecessor_revision_id,
  revision_status,
  effective_from,
  effective_to,
  substitute_ingredient_id,
  quantity_per_basis,
  unit_id,
  reason_code,
  reason_note,
  source_evidence,
  created_by_actor_id
) values
  (
    'b2510000-0000-0000-0000-000000000001',
    'b2500000-0000-0000-0000-000000000001',
    'SYSTEM_DISH',
    'ADJUST_QUANTITY',
    1,
    null,
    'ACTIVE',
    date '2026-07-01',
    null,
    null,
    11,
    null,
    'TEMPORAL_PREDECESSOR',
    'Predecessor remains authoritative outside successor periods.',
    '{"source":"rmvp02b-temporal-test"}'::jsonb,
    'b2000000-0000-0000-0000-000000000001'
  ),
  (
    'b2510000-0000-0000-0000-000000000002',
    'b2500000-0000-0000-0000-000000000001',
    'SYSTEM_DISH',
    'ADJUST_QUANTITY',
    2,
    'b2510000-0000-0000-0000-000000000001',
    'ACTIVE',
    date '2026-08-01',
    date '2026-09-01',
    null,
    12,
    null,
    'FINITE_SUCCESSOR',
    'Finite successor temporarily masks the predecessor.',
    '{"source":"rmvp02b-temporal-test"}'::jsonb,
    'b2000000-0000-0000-0000-000000000001'
  ),
  (
    'b2510000-0000-0000-0000-000000000003',
    'b2500000-0000-0000-0000-000000000002',
    'SCHOOL_DISH',
    'ADJUST_QUANTITY',
    1,
    null,
    'ACTIVE',
    date '2026-07-01',
    null,
    null,
    14,
    null,
    'DATED_CANCELLATION_PREDECESSOR',
    'Predecessor remains authoritative before dated cancellation.',
    '{"source":"rmvp02b-temporal-test"}'::jsonb,
    'b2000000-0000-0000-0000-000000000001'
  ),
  (
    'b2510000-0000-0000-0000-000000000004',
    'b2500000-0000-0000-0000-000000000002',
    'SCHOOL_DISH',
    'ADJUST_QUANTITY',
    2,
    'b2510000-0000-0000-0000-000000000003',
    'CANCELLED',
    date '2026-08-15',
    null,
    null,
    null,
    null,
    'DATED_CANCELLATION',
    'Cancellation stops authority from its effective date.',
    '{"source":"rmvp02b-temporal-test"}'::jsonb,
    'b2000000-0000-0000-0000-000000000001'
  );

update atlas_admin.recipe_composition_adjustments
set current_revision_id =
      case recipe_composition_adjustment_id
        when 'b2500000-0000-0000-0000-000000000001'
          then 'b2510000-0000-0000-0000-000000000002'::uuid
        else 'b2510000-0000-0000-0000-000000000004'::uuid
      end,
    current_revision_number = 2
where recipe_composition_adjustment_id in (
  'b2500000-0000-0000-0000-000000000001',
  'b2500000-0000-0000-0000-000000000002'
);

select ok(
  (
    select not (validation ->> 'valid')::boolean
      and exists (
        select 1
        from jsonb_array_elements(validation -> 'blockers') blocker
        where blocker ->> 'code' = 'OVERLAPPING_ACTIVE_RULE'
      )
    from (
      select atlas_core.rmvp_02b_validate_proposed_adjustment(
        jsonb_build_object(
          'adjustment_id', 'b2520000-0000-0000-0000-000000000001',
          'revision_id', 'b2530000-0000-0000-0000-000000000001',
          'scope_kind', 'SYSTEM_DISH',
          'action_kind', 'ADJUST_QUANTITY',
          'dish_id', 'b2200000-0000-0000-0000-000000000101',
          'target_recipe_line_id',
            'b2200000-0000-0000-0000-000000000402',
          'quantity_per_basis', 15,
          'effective_from', '2026-07-10',
          'effective_to', '2026-07-20',
          'reason_code', 'OVERLAP_PREDECESSOR',
          'reason_note', 'Must overlap the historically effective predecessor.'
        ),
        date '2026-07-15'
      ) as validation
    ) checked
  ),
  'overlap validation includes a predecessor before its dated successor'
);

select ok(
  (
    select not (validation ->> 'valid')::boolean
      and exists (
        select 1
        from jsonb_array_elements(validation -> 'blockers') blocker
        where blocker ->> 'code' = 'OVERLAPPING_ACTIVE_RULE'
      )
    from (
      select atlas_core.rmvp_02b_validate_proposed_adjustment(
        jsonb_build_object(
          'adjustment_id', 'b2520000-0000-0000-0000-000000000002',
          'revision_id', 'b2530000-0000-0000-0000-000000000002',
          'scope_kind', 'SCHOOL_DISH',
          'action_kind', 'ADJUST_QUANTITY',
          'school_id', 'b2100000-0000-0000-0000-000000000120',
          'dish_id', 'b2200000-0000-0000-0000-000000000101',
          'target_recipe_line_id',
            'b2200000-0000-0000-0000-000000000402',
          'quantity_per_basis', 16,
          'effective_from', '2026-08-10',
          'effective_to', '2026-08-12',
          'reason_code', 'OVERLAP_BEFORE_CANCELLATION',
          'reason_note', 'Must overlap the predecessor before cancellation.'
        ),
        date '2026-08-10'
      ) as validation
    ) checked
  ),
  'overlap validation includes a predecessor before a dated cancellation'
);

select ok(
  (
    atlas_core.rmvp_02b_validate_proposed_adjustment(
      jsonb_build_object(
        'adjustment_id', 'b2520000-0000-0000-0000-000000000003',
        'revision_id', 'b2530000-0000-0000-0000-000000000003',
        'scope_kind', 'SCHOOL_DISH',
        'action_kind', 'ADJUST_QUANTITY',
        'school_id', 'b2100000-0000-0000-0000-000000000120',
        'dish_id', 'b2200000-0000-0000-0000-000000000101',
        'target_recipe_line_id',
          'b2200000-0000-0000-0000-000000000402',
        'quantity_per_basis', 17,
        'effective_from', '2026-08-15',
        'reason_code', 'AFTER_CANCELLATION',
        'reason_note', 'Begins exactly when the prior root loses authority.'
      ),
      date '2026-08-15'
    ) ->> 'valid'
  )::boolean,
  'a same-target root beginning at cancellation is genuinely non-overlapping'
);

select ok(
  (
    select resolution ->> 'status' = 'BLOCKED'
      and exists (
        select 1
        from jsonb_array_elements(resolution -> 'blockers') blocker
        where blocker ->> 'code' = 'AMBIGUOUS_SYSTEM_DISH_TARGET'
      )
      and not exists (
        select 1
        from jsonb_array_elements(resolution -> 'lines') line,
          jsonb_array_elements(line -> 'applied_adjustment_ids') applied
      )
    from (
      select atlas_core.rmvp_02b_resolve_effective_composition(
        date '2026-07-15',
        'b2100000-0000-0000-0000-000000000120',
        'b2200000-0000-0000-0000-000000000101',
        jsonb_build_object(
          'adjustment_id', 'b2520000-0000-0000-0000-000000000004',
          'revision_id', 'b2530000-0000-0000-0000-000000000004',
          'revision_number', 1,
          'scope_kind', 'SYSTEM_DISH',
          'action_kind', 'REMOVE',
          'dish_id', 'b2200000-0000-0000-0000-000000000101',
          'target_recipe_line_id',
            'b2200000-0000-0000-0000-000000000402',
          'effective_from', '2026-07-10',
          'effective_to', '2026-07-20',
          'reason_code', 'AMBIGUITY_TEST',
          'reason_note', 'Resolver must fail closed.'
        )
      ) as resolution
    ) resolved
  ),
  'same-target SYSTEM_DISH ambiguity blocks before UUID-ordered application'
);

select ok(
  (
    select resolution ->> 'status' = 'BLOCKED'
      and exists (
        select 1
        from jsonb_array_elements(resolution -> 'blockers') blocker
        where blocker ->> 'code' = 'AMBIGUOUS_SCHOOL_DISH_TARGET'
      )
      and not exists (
        select 1
        from jsonb_array_elements(resolution -> 'lines') line,
          jsonb_array_elements(line -> 'applied_adjustment_ids') applied
      )
    from (
      select atlas_core.rmvp_02b_resolve_effective_composition(
        date '2026-08-10',
        'b2100000-0000-0000-0000-000000000120',
        'b2200000-0000-0000-0000-000000000101',
        jsonb_build_object(
          'adjustment_id', 'b2520000-0000-0000-0000-000000000005',
          'revision_id', 'b2530000-0000-0000-0000-000000000005',
          'revision_number', 1,
          'scope_kind', 'SCHOOL_DISH',
          'action_kind', 'REMOVE',
          'school_id', 'b2100000-0000-0000-0000-000000000120',
          'dish_id', 'b2200000-0000-0000-0000-000000000101',
          'target_recipe_line_id',
            'b2200000-0000-0000-0000-000000000402',
          'effective_from', '2026-08-10',
          'effective_to', '2026-08-12',
          'reason_code', 'AMBIGUITY_TEST',
          'reason_note', 'Resolver must fail closed.'
        )
      ) as resolution
    ) resolved
  ),
  'same-target SCHOOL_DISH ambiguity blocks before UUID-ordered application'
);

select is(
  (
    select string_agg(
      (line ->> 'final_quantity_per_basis')::numeric::integer::text,
      ','
      order by requested_date
    )
    from (
      values
        (
          date '2026-08-20',
          atlas_core.rmvp_02b_resolve_effective_composition(
            date '2026-08-20',
            'b2100000-0000-0000-0000-000000000120',
            'b2200000-0000-0000-0000-000000000101'
          )
        ),
        (
          date '2026-09-01',
          atlas_core.rmvp_02b_resolve_effective_composition(
            date '2026-09-01',
            'b2100000-0000-0000-0000-000000000120',
            'b2200000-0000-0000-0000-000000000101'
          )
        )
    ) result(requested_date, resolution),
      jsonb_array_elements(result.resolution -> 'lines') line
    where line ->> 'base_recipe_line_id' =
      'b2200000-0000-0000-0000-000000000402'
  ),
  '12,11',
  'a finite successor masks its predecessor, which resumes at effective_to'
);

select ok(
  (
    select not (validation ->> 'valid')::boolean
      and exists (
        select 1
        from jsonb_array_elements(validation -> 'blockers') blocker
        where blocker ->> 'code' = 'OVERLAPPING_ACTIVE_RULE'
      )
    from (
      select atlas_core.rmvp_02b_validate_proposed_adjustment(
        jsonb_build_object(
          'adjustment_id', 'b2520000-0000-0000-0000-000000000006',
          'revision_id', 'b2530000-0000-0000-0000-000000000006',
          'scope_kind', 'SYSTEM_DISH',
          'action_kind', 'REMOVE',
          'dish_id', 'b2200000-0000-0000-0000-000000000101',
          'target_recipe_line_id',
            'b2200000-0000-0000-0000-000000000402',
          'effective_from', '2026-09-10',
          'effective_to', '2026-09-20',
          'reason_code', 'RESUMED_PREDECESSOR_OVERLAP',
          'reason_note', 'Must overlap the resumed predecessor.'
        ),
        date '2026-09-10'
      ) as validation
    ) checked
  ),
  'overlap validation includes the predecessor after finite successor expiry'
);

select ok(
  (
    with function_definitions as (
      select
        (
          select pg_get_functiondef(p.oid)
          from pg_proc p
          join pg_namespace n on n.oid = p.pronamespace
          where n.nspname = 'atlas_api'
            and p.proname = 'create_recipe_composition_adjustment'
        ) as create_definition,
        (
          select pg_get_functiondef(p.oid)
          from pg_proc p
          join pg_namespace n on n.oid = p.pronamespace
          where n.nspname = 'atlas_api'
            and p.proname = 'supersede_recipe_composition_adjustment'
        ) as supersede_definition,
        pg_get_functiondef(
          'atlas_core.rmvp_02b_typed_target_lock_key(
            text, text, uuid, uuid, uuid, uuid, uuid, uuid
          )'::regprocedure
        ) as helper_definition
    )
    select
      position('pg_advisory_xact_lock' in create_definition) > 0
      and position('pg_advisory_xact_lock' in supersede_definition) > 0
      and position(
        'atlas_core.rmvp_02b_typed_target_lock_key(' in create_definition
      ) > 0
      and position(
        'atlas_core.rmvp_02b_typed_target_lock_key(' in supersede_definition
      ) > 0
      and position(
        'rmvp_02b_typed_target_lock_key(' in create_definition
      ) < position(
        'insert into atlas_admin.recipe_composition_adjustments'
        in create_definition
      )
      and position(
        'rmvp_02b_typed_target_lock_key(' in supersede_definition
      ) < position('for update' in supersede_definition)
      and position('for update' in supersede_definition) < position(
        'v_validation := atlas_core.rmvp_02b_validate_proposed_adjustment'
        in supersede_definition
      )
      and helper_definition like '%RMVP-02B_TYPED_TARGET_V1%'
      and helper_definition like '%target_kind%'
      and helper_definition like '%target_id%'
      and helper_definition not like '%concat_ws%'
      and create_definition not like '%concat_ws%'
      and supersede_definition not like '%concat_ws%'
    from function_definitions
  ),
  'create and supersede share labeled typed-target locking before final validation'
);

select is(
  (
    atlas_core.rmvp_02b_adjustment_workbench_payload()
      -> 'scope_catalog'
  )::text,
  '[
    {"actions": ["REPLACE"], "scope_kind": "SYSTEM_INGREDIENT"},
    {"actions": ["ADD", "REPLACE", "ADJUST_QUANTITY", "REMOVE"], "scope_kind": "SYSTEM_DISH"},
    {"actions": ["REPLACE", "REMOVE"], "scope_kind": "SCHOOL"},
    {"actions": ["ADD", "REPLACE", "ADJUST_QUANTITY", "REMOVE"], "scope_kind": "SCHOOL_DISH"}
  ]'::jsonb::text,
  'the closed scope/action catalog is exact'
);

select is(
  (
    atlas_core.rmvp_02b_adjustment_workbench_payload()
      -> 'precedence'
  )::text,
  '[
    "RELEASED_RECIPE_VERSION",
    "SYSTEM_INGREDIENT",
    "SYSTEM_DISH",
    "SCHOOL",
    "SCHOOL_DISH"
  ]'::jsonb::text,
  'the effective-composition precedence is exact'
);

select is(
  atlas_core.rmvp_02b_resolve_effective_composition(
    date '2026-07-15',
    'b2100000-0000-0000-0000-000000000120',
    'b2200000-0000-0000-0000-000000000100'
  ) ->> 'status',
  'READY',
  'the layered effective composition resolves deterministically'
);

select is(
  (
    select row(
      line ->> 'final_ingredient_id',
      line ->> 'final_quantity_per_basis',
      line ->> 'source_layer',
      jsonb_array_length(line -> 'lineage')
    )::text
    from jsonb_array_elements(
      atlas_core.rmvp_02b_resolve_effective_composition(
        date '2026-07-15',
        'b2100000-0000-0000-0000-000000000120',
        'b2200000-0000-0000-0000-000000000100'
      ) -> 'lines'
    ) line
    where line ->> 'base_recipe_line_id' =
      'b2200000-0000-0000-0000-000000000400'
  ),
  '(b2200000-0000-0000-0000-000000000022,30.000000,SCHOOL_DISH,4)',
  'all four adjustment layers produce the final Ingredient, quantity, source layer, and lineage'
);

select is(
  (
    select jsonb_agg(step ->> 'scope_kind')::text
    from jsonb_array_elements(
      (
        select line -> 'lineage'
        from jsonb_array_elements(
          atlas_core.rmvp_02b_resolve_effective_composition(
            date '2026-07-15',
            'b2100000-0000-0000-0000-000000000120',
            'b2200000-0000-0000-0000-000000000100'
          ) -> 'lines'
        ) line
        where line ->> 'base_recipe_line_id' =
          'b2200000-0000-0000-0000-000000000400'
      )
    ) step
  ),
  '["SYSTEM_INGREDIENT", "SYSTEM_DISH", "SCHOOL", "SCHOOL_DISH"]'::jsonb::text,
  'source audit retains the exact low-to-high application order'
);

select ok(
  (
    select (step ->> 'adjustment_id') is not null
      and (step ->> 'revision_id') is not null
      and (step ->> 'reason_code') is not null
      and (step ->> 'reason_note') is not null
    from jsonb_array_elements(
      (
        select line -> 'lineage'
        from jsonb_array_elements(
          atlas_core.rmvp_02b_resolve_effective_composition(
            date '2026-07-15',
            'b2100000-0000-0000-0000-000000000120',
            'b2200000-0000-0000-0000-000000000100'
          ) -> 'lines'
        ) line
        where line ->> 'base_recipe_line_id' =
          'b2200000-0000-0000-0000-000000000400'
      )
    ) step
    limit 1
  ),
  'lineage is complete enough to identify the accepted rule, revision, and reason'
);

select ok(
  (
    select bool_or(blocker ->> 'code' = 'REPLACEMENT_CYCLE')
    from jsonb_array_elements(
      atlas_core.rmvp_02b_resolve_effective_composition(
        date '2026-08-01',
        'b2100000-0000-0000-0000-000000000120',
        'b2200000-0000-0000-0000-000000000101',
        jsonb_build_object(
          'adjustment_id', 'b2320000-0000-0000-0000-000000000003',
          'revision_id', 'b2330000-0000-0000-0000-000000000003',
          'revision_number', 1,
          'scope_kind', 'SYSTEM_INGREDIENT',
          'action_kind', 'REPLACE',
          'target_ingredient_id',
            'b2200000-0000-0000-0000-000000000024',
          'substitute_ingredient_id',
            'b2200000-0000-0000-0000-000000000023',
          'effective_from', '2026-08-01',
          'reason_code', 'CYCLE_TEST',
          'reason_note', 'Second deterministic cycle edge.'
        )
      ) -> 'blockers'
    ) blocker
  ),
  'recursive system replacement cycles fail closed'
);

select is(
  (
    atlas_core.rmvp_02b_resolve_effective_composition(
      date '2026-07-31',
      'b2100000-0000-0000-0000-000000000120',
      'b2200000-0000-0000-0000-000000000101'
    ) #>> '{lines,0,final_ingredient_id}'
  ),
  'b2200000-0000-0000-0000-000000000023',
  'a future rule is not effective before its explicit half-open period'
);

select is(
  (
    atlas_core.rmvp_02b_resolve_effective_composition(
      date '2026-08-01',
      'b2100000-0000-0000-0000-000000000120',
      'b2200000-0000-0000-0000-000000000101',
      jsonb_build_object(
        'adjustment_id', 'b2320000-0000-0000-0000-000000000004',
        'revision_id', 'b2330000-0000-0000-0000-000000000004',
        'revision_number', 1,
        'scope_kind', 'SYSTEM_INGREDIENT',
        'action_kind', 'REPLACE',
        'target_ingredient_id',
          'b2200000-0000-0000-0000-000000000024',
        'substitute_ingredient_id',
          'b2200000-0000-0000-0000-000000000025',
        'effective_from', '2026-08-01',
        'reason_code', 'CHAIN_TEST',
        'reason_note', 'Second valid replacement-chain edge.'
      )
    ) #>> '{lines,0,final_ingredient_id}'
  ),
  'b2200000-0000-0000-0000-000000000025',
  'a multi-step system Ingredient replacement resolves to one deterministic terminal Ingredient'
);

select is(
  (
    select count(*)::integer
    from jsonb_array_elements(
      atlas_core.rmvp_02b_resolve_effective_composition(
        date '2026-08-01',
        'b2100000-0000-0000-0000-000000000120',
        'b2200000-0000-0000-0000-000000000101',
        jsonb_build_object(
          'adjustment_id', 'b2320000-0000-0000-0000-000000000004',
          'revision_id', 'b2330000-0000-0000-0000-000000000004',
          'revision_number', 1,
          'scope_kind', 'SYSTEM_INGREDIENT',
          'action_kind', 'REPLACE',
          'target_ingredient_id',
            'b2200000-0000-0000-0000-000000000024',
          'substitute_ingredient_id',
            'b2200000-0000-0000-0000-000000000025',
          'effective_from', '2026-08-01',
          'reason_code', 'CHAIN_TEST',
          'reason_note', 'Second valid replacement-chain edge.'
        )
      ) -> 'lines'
    ) line,
      jsonb_array_elements(line -> 'lineage') lineage
    where lineage ->> 'scope_kind' = 'SYSTEM_INGREDIENT'
  ),
  2,
  'every hop in a multi-step global replacement chain remains auditable'
);

select ok(
  (
    select not (validation ->> 'valid')::boolean
      and bool_or(blocker ->> 'code' = 'SELF_REPLACEMENT')
    from (
      select atlas_core.rmvp_02b_validate_proposed_adjustment(
        jsonb_build_object(
          'adjustment_id', 'b2320000-0000-0000-0000-000000000005',
          'revision_id', 'b2330000-0000-0000-0000-000000000005',
          'scope_kind', 'SYSTEM_INGREDIENT',
          'action_kind', 'REPLACE',
          'target_ingredient_id',
            'b2200000-0000-0000-0000-000000000020',
          'substitute_ingredient_id',
            'b2200000-0000-0000-0000-000000000020',
          'effective_from', '2026-07-15',
          'reason_code', 'SELF_TEST',
          'reason_note', 'Self replacement must fail.'
        ),
        date '2026-07-15'
      ) validation
    ) checked,
      jsonb_array_elements(validation -> 'blockers') blocker
    group by validation
  ),
  'self-replacement is rejected explicitly'
);

select ok(
  (
    select not (validation ->> 'valid')::boolean
      and bool_or(blocker ->> 'code' = 'EFFECTIVE_PERIOD_INVALID')
    from (
      select atlas_core.rmvp_02b_validate_proposed_adjustment(
        jsonb_build_object(
          'adjustment_id', 'b2320000-0000-0000-0000-000000000006',
          'revision_id', 'b2330000-0000-0000-0000-000000000006',
          'scope_kind', 'SYSTEM_DISH',
          'action_kind', 'REMOVE',
          'dish_id', 'b2200000-0000-0000-0000-000000000100',
          'target_recipe_line_id',
            'b2200000-0000-0000-0000-000000000401',
          'effective_from', '2026-07-15',
          'effective_to', '2026-07-15',
          'reason_code', 'PERIOD_TEST',
          'reason_note', 'Empty period must fail.'
        ),
        date '2026-07-15'
      ) validation
    ) checked,
      jsonb_array_elements(validation -> 'blockers') blocker
    group by validation
  ),
  'an empty or reversed effective period is rejected'
);

select ok(
  (
    select not (validation ->> 'valid')::boolean
      and bool_or(blocker ->> 'code' = 'OVERLAPPING_ACTIVE_RULE')
    from (
      select atlas_core.rmvp_02b_validate_proposed_adjustment(
        jsonb_build_object(
          'adjustment_id', 'b2320000-0000-0000-0000-000000000007',
          'revision_id', 'b2330000-0000-0000-0000-000000000007',
          'scope_kind', 'SYSTEM_DISH',
          'action_kind', 'ADJUST_QUANTITY',
          'dish_id', 'b2200000-0000-0000-0000-000000000100',
          'school_type_id',
            'b2100000-0000-0000-0000-000000000110',
          'target_recipe_line_id',
            'b2200000-0000-0000-0000-000000000400',
          'quantity_per_basis', 21,
          'effective_from', '2026-07-15',
          'reason_code', 'OVERLAP_TEST',
          'reason_note', 'Exact target overlap must fail.'
        ),
        date '2026-07-15'
      ) validation
    ) checked,
      jsonb_array_elements(validation -> 'blockers') blocker
    group by validation
  ),
  'overlapping active rules for one exact typed target are rejected'
);

select ok(
  (
    select line ->> 'adjustment_line_id' =
        'b2340000-0000-0000-0000-000000000008'
      and line ->> 'final_ingredient_id' =
        'b2200000-0000-0000-0000-000000000024'
      and line ->> 'final_quantity_per_basis' = '2'
      and line ->> 'final_unit_id' =
        'b2200000-0000-0000-0000-000000000010'
      and line ->> 'source_layer' = 'SYSTEM_DISH'
    from jsonb_array_elements(
      atlas_core.rmvp_02b_resolve_effective_composition(
        date '2026-07-15',
        'b2100000-0000-0000-0000-000000000120',
        'b2200000-0000-0000-0000-000000000100',
        jsonb_build_object(
          'adjustment_id', 'b2320000-0000-0000-0000-000000000008',
          'revision_id', 'b2330000-0000-0000-0000-000000000008',
          'revision_number', 1,
          'scope_kind', 'SYSTEM_DISH',
          'action_kind', 'ADD',
          'dish_id', 'b2200000-0000-0000-0000-000000000100',
          'target_ingredient_id',
            'b2200000-0000-0000-0000-000000000024',
          'adjustment_line_id',
            'b2340000-0000-0000-0000-000000000008',
          'quantity_per_basis', 2,
          'unit_id', 'b2200000-0000-0000-0000-000000000010',
          'effective_from', '2026-07-15',
          'reason_code', 'ADD_TEST',
          'reason_note', 'Unique addition must remain atomic.'
        )
      ) -> 'lines'
    ) line
    where line ->> 'adjustment_line_id' =
      'b2340000-0000-0000-0000-000000000008'
  ),
  'ADD creates one stable atomic adjustment line with explicit quantity and Unit'
);

select is(
  (
    select row(
      line ->> 'final_ingredient_id',
      line ->> 'final_quantity_per_basis',
      line ->> 'final_unit_id'
    )::text
    from jsonb_array_elements(
      atlas_core.rmvp_02b_resolve_effective_composition(
        date '2026-07-15',
        'b2100000-0000-0000-0000-000000000120',
        'b2200000-0000-0000-0000-000000000100',
        jsonb_build_object(
          'adjustment_id', 'b2320000-0000-0000-0000-000000000009',
          'revision_id', 'b2330000-0000-0000-0000-000000000009',
          'revision_number', 1,
          'scope_kind', 'SCHOOL_DISH',
          'action_kind', 'REPLACE',
          'school_id', 'b2100000-0000-0000-0000-000000000120',
          'dish_id', 'b2200000-0000-0000-0000-000000000100',
          'target_recipe_line_id',
            'b2200000-0000-0000-0000-000000000401',
          'substitute_ingredient_id',
            'b2200000-0000-0000-0000-000000000024',
          'effective_from', '2026-07-15',
          'reason_code', 'REPLACE_TEST',
          'reason_note', 'Replacement inherits quantity and Unit.'
        )
      ) -> 'lines'
    ) line
    where line ->> 'base_recipe_line_id' =
      'b2200000-0000-0000-0000-000000000401'
  ),
  '(b2200000-0000-0000-0000-000000000024,5.000000,b2200000-0000-0000-0000-000000000010)',
  'REPLACE inherits source quantity and Unit by default'
);

select is(
  (
    select row(
      line ->> 'final_ingredient_id',
      line ->> 'final_quantity_per_basis',
      line ->> 'final_unit_id'
    )::text
    from jsonb_array_elements(
      atlas_core.rmvp_02b_resolve_effective_composition(
        date '2026-07-15',
        'b2100000-0000-0000-0000-000000000120',
        'b2200000-0000-0000-0000-000000000100',
        jsonb_build_object(
          'adjustment_id', 'b2320000-0000-0000-0000-000000000010',
          'revision_id', 'b2330000-0000-0000-0000-000000000010',
          'revision_number', 1,
          'scope_kind', 'SCHOOL_DISH',
          'action_kind', 'REPLACE',
          'school_id', 'b2100000-0000-0000-0000-000000000120',
          'dish_id', 'b2200000-0000-0000-0000-000000000100',
          'target_recipe_line_id',
            'b2200000-0000-0000-0000-000000000401',
          'substitute_ingredient_id',
            'b2200000-0000-0000-0000-000000000024',
          'quantity_per_basis', 6,
          'unit_id', 'b2200000-0000-0000-0000-000000000010',
          'effective_from', '2026-07-15',
          'reason_code', 'REPLACE_QUANTITY_TEST',
          'reason_note', 'Replacement quantity names an explicit Unit.'
        )
      ) -> 'lines'
    ) line
    where line ->> 'base_recipe_line_id' =
      'b2200000-0000-0000-0000-000000000401'
  ),
  '(b2200000-0000-0000-0000-000000000024,6,b2200000-0000-0000-0000-000000000010)',
  'REPLACE accepts a positive quantity override only with an explicit Unit'
);

select ok(
  (
    select bool_or(blocker ->> 'code' = 'TARGET_NOT_APPLICABLE')
    from jsonb_array_elements(
      atlas_core.rmvp_02b_resolve_effective_composition(
        date '2026-07-15',
        'b2100000-0000-0000-0000-000000000120',
        'b2200000-0000-0000-0000-000000000100',
        jsonb_build_object(
          'adjustment_id', 'b2320000-0000-0000-0000-000000000011',
          'revision_id', 'b2330000-0000-0000-0000-000000000011',
          'revision_number', 1,
          'scope_kind', 'SCHOOL_DISH',
          'action_kind', 'REMOVE',
          'school_id', 'b2100000-0000-0000-0000-000000000120',
          'dish_id', 'b2200000-0000-0000-0000-000000000100',
          'target_recipe_line_id',
            'b2200000-0000-0000-0000-000000009999',
          'effective_from', '2026-07-15',
          'reason_code', 'STALE_TARGET_TEST',
          'reason_note', 'A missing stable target must block.'
        )
      ) -> 'blockers'
    ) blocker
  ),
  'a stale or absent stable RecipeLine target is never silently retargeted'
);

select is(
  atlas_core.rmvp_02b_resolve_effective_composition(
    date '2026-07-15',
    'b2100000-0000-0000-0000-000000000120',
    'b2200000-0000-0000-0000-000000000100'
  ) #>> '{selected_recipe,selection_scope}',
  'GENERAL',
  'Recipe selection falls back deterministically to the one eligible general release'
);

select ok(
  pg_get_functiondef(
    'atlas_core.rmvp_02b_resolve_effective_composition(date,uuid,uuid,jsonb,uuid,uuid)'::regprocedure
  ) !~* '\mcurrent_date\M',
  'authoritative resolution contains no implicit CURRENT_DATE authority'
);

select ok(
  (
    select bool_or(blocker ->> 'code' = 'DUPLICATE_EFFECTIVE_INGREDIENT')
    from jsonb_array_elements(
      atlas_core.rmvp_02b_resolve_effective_composition(
        date '2026-07-15',
        'b2100000-0000-0000-0000-000000000120',
        'b2200000-0000-0000-0000-000000000100',
        jsonb_build_object(
          'adjustment_id', 'b2320000-0000-0000-0000-000000000001',
          'revision_id', 'b2330000-0000-0000-0000-000000000001',
          'revision_number', 1,
          'scope_kind', 'SCHOOL_DISH',
          'action_kind', 'ADD',
          'school_id', 'b2100000-0000-0000-0000-000000000120',
          'dish_id', 'b2200000-0000-0000-0000-000000000100',
          'target_ingredient_id',
            'b2200000-0000-0000-0000-000000000022',
          'adjustment_line_id',
            'b2340000-0000-0000-0000-000000000001',
          'quantity_per_basis', 1,
          'unit_id', 'b2200000-0000-0000-0000-000000000010',
          'effective_from', '2026-07-01',
          'reason_code', 'DUPLICATE_TEST',
          'reason_note', 'Duplicate blocker test.'
        )
      ) -> 'blockers'
    ) blocker
  ),
  'duplicate final Ingredients fail closed'
);

select is(
  (
    select row(
      line ->> 'final_disposition',
      line ->> 'final_quantity_per_basis',
      line ->> 'source_layer'
    )::text
    from jsonb_array_elements(
      atlas_core.rmvp_02b_resolve_effective_composition(
        date '2026-07-15',
        'b2100000-0000-0000-0000-000000000120',
        'b2200000-0000-0000-0000-000000000100',
        jsonb_build_object(
          'adjustment_id', 'b2320000-0000-0000-0000-000000000002',
          'revision_id', 'b2330000-0000-0000-0000-000000000002',
          'revision_number', 1,
          'scope_kind', 'SCHOOL_DISH',
          'action_kind', 'REMOVE',
          'school_id', 'b2100000-0000-0000-0000-000000000120',
          'dish_id', 'b2200000-0000-0000-0000-000000000100',
          'target_recipe_line_id',
            'b2200000-0000-0000-0000-000000000400',
          'effective_from', '2026-07-01',
          'reason_code', 'REMOVAL_TEST',
          'reason_note', 'Explicit removal audit test.'
        ),
        'b2300000-0000-0000-0000-000000000004'
      ) -> 'lines'
    ) line
    where line ->> 'base_recipe_line_id' =
      'b2200000-0000-0000-0000-000000000400'
  ),
  '(REMOVED,0,SCHOOL_DISH)',
  'explicit removal remains visible as an audited line'
);

select throws_ok(
  $$
    insert into atlas_admin.recipe_composition_adjustments (
      scope_kind, action_kind, target_ingredient_id,
      created_by_actor_id, updated_by_actor_id
    ) values (
      'SYSTEM_INGREDIENT',
      'REMOVE',
      'b2200000-0000-0000-0000-000000000020',
      'b2000000-0000-0000-0000-000000000001',
      'b2000000-0000-0000-0000-000000000001'
    )
  $$,
  '23514',
  null,
  'an action outside the closed scope/action catalog is rejected'
);

create temporary table rmvp02b_import_results (
  snapshot_name text primary key,
  unsigned_snapshot jsonb not null,
  signed_snapshot jsonb,
  response_payload jsonb,
  replay_payload jsonb
);

insert into rmvp02b_import_results (
  snapshot_name, unsigned_snapshot
) values
  (
    'valid',
    jsonb_build_object(
      'source_system', 'OPS_V1_RECIPE_ADJUSTMENTS',
      'snapshot_id', 'rmvp02b-valid-explicit-export',
      'exported_at', '2026-07-27T00:00:00Z',
      'imported_by_actor_id',
        'b2000000-0000-0000-0000-000000000001',
      'records', jsonb_build_object(
        'ingredient_change_orders', '[]'::jsonb,
        'system_bom_change_orders', jsonb_build_array(
          jsonb_build_object(
            'legacy_id', 'ops-v1:system-bom:add-f',
            'action', 'ADD',
            'dish_id', 'b2200000-0000-0000-0000-000000000101',
            'target_ingredient_id',
              'b2200000-0000-0000-0000-000000000025',
            'quantity_per_basis', 2,
            'unit_id', 'b2200000-0000-0000-0000-000000000010',
            'effective_from', '2026-07-01',
            'effective_to', '2026-08-01',
            'is_active', true,
            'reason_note', 'Reviewed OPS v1 system BOM addition.'
          )
        ),
        'school_overrides', '[]'::jsonb,
        'school_dish_overrides', '[]'::jsonb
      )
    )
  ),
  (
    'missing-reference',
    jsonb_build_object(
      'source_system', 'OPS_V1_RECIPE_ADJUSTMENTS',
      'snapshot_id', 'rmvp02b-missing-reference-export',
      'exported_at', '2026-07-27T00:00:00Z',
      'imported_by_actor_id',
        'b2000000-0000-0000-0000-000000000001',
      'records', jsonb_build_object(
        'ingredient_change_orders', '[]'::jsonb,
        'system_bom_change_orders', jsonb_build_array(
          jsonb_build_object(
            'legacy_id', 'ops-v1:system-bom:missing-line',
            'action', 'REMOVE',
            'dish_id', 'b2200000-0000-0000-0000-000000000101',
            'target_ingredient_id',
              'b2200000-0000-0000-0000-000000009999',
            'effective_from', '2026-07-01',
            'is_active', true
          )
        ),
        'school_overrides', '[]'::jsonb,
        'school_dish_overrides', '[]'::jsonb
      )
    )
  ),
  (
    'historical-overlap',
    jsonb_build_object(
      'source_system', 'OPS_V1_RECIPE_ADJUSTMENTS',
      'snapshot_id', 'rmvp02b-historical-overlap-export',
      'exported_at', '2026-07-27T00:00:00Z',
      'imported_by_actor_id',
        'b2000000-0000-0000-0000-000000000001',
      'records', jsonb_build_object(
        'ingredient_change_orders', '[]'::jsonb,
        'system_bom_change_orders', jsonb_build_array(
          jsonb_build_object(
            'legacy_id', 'ops-v1:system-bom:historical-overlap',
            'action', 'ADJUST_QUANTITY',
            'dish_id', 'b2200000-0000-0000-0000-000000000101',
            'target_recipe_line_id',
              'b2200000-0000-0000-0000-000000000402',
            'quantity_per_basis', 18,
            'effective_from', '2026-07-10',
            'effective_to', '2026-07-20',
            'is_active', true,
            'reason_note',
              'Must be rejected against predecessor authority.'
          )
        ),
        'school_overrides', '[]'::jsonb,
        'school_dish_overrides', '[]'::jsonb
      )
    )
  );

update rmvp02b_import_results
set signed_snapshot = unsigned_snapshot || jsonb_build_object(
  'snapshot_checksum',
  encode(
    extensions.digest(
      convert_to(unsigned_snapshot::text, 'UTF8'),
      'sha256'
    ),
    'hex'
  )
);

update rmvp02b_import_results
set response_payload =
  atlas_legacy.import_recipe_adjustment_snapshot(signed_snapshot);

update rmvp02b_import_results
set replay_payload =
  atlas_legacy.import_recipe_adjustment_snapshot(signed_snapshot)
where snapshot_name = 'valid';

select is(
  (
    select response_payload ->> 'status'
    from rmvp02b_import_results
    where snapshot_name = 'valid'
  ),
  'COMPLETED',
  'an explicit reviewed OPS v1 adjustment snapshot imports successfully'
);

select is(
  (
    select replay_payload ->> 'status'
    from rmvp02b_import_results
    where snapshot_name = 'valid'
  ),
  'REPLAYED',
  'an identical explicit snapshot replay is idempotent'
);

select ok(
  (
    select response_payload ->> 'status' = 'REJECTED'
      and jsonb_array_length(
        response_payload -> 'missing_references'
      ) = 1
      and (
        response_payload #>> '{reconciliation,passed}'
      )::boolean is false
    from rmvp02b_import_results
    where snapshot_name = 'missing-reference'
  ),
  'missing legacy RecipeLine references reject the batch with a reconciliation report'
);

select ok(
  (
    select response_payload ->> 'status' = 'REJECTED'
      and exists (
        select 1
        from jsonb_array_elements(
          response_payload -> 'validation_errors'
        ) validation_error,
          jsonb_array_elements(
            validation_error -> 'blockers'
          ) blocker
        where blocker ->> 'code' = 'OVERLAPPING_ACTIVE_RULE'
      )
    from rmvp02b_import_results
    where snapshot_name = 'historical-overlap'
  ),
  'OPS v1 import validation rejects overlap with derived predecessor authority'
);

select ok(
  (
    select root.lifecycle_status = 'ACTIVE'
      and root.legacy_source = 'OPS_V1_SYSTEM_BOM_CHANGE_ORDER'
      and revision.source_evidence #>> '{legacy_record_id}'
        = 'ops-v1:system-bom:add-f'
      and (
        revision.source_evidence
          #>> '{historical_actor_approval_claimed}'
      )::boolean is false
    from atlas_admin.recipe_composition_adjustments root
    join atlas_admin.recipe_composition_adjustment_revisions revision
      on revision.recipe_composition_adjustment_revision_id =
        root.current_revision_id
    where root.legacy_record_id = 'ops-v1:system-bom:add-f'
  ),
  'controlled import preserves source identity while avoiding false historical actor claims'
);

select is(
  (
    select count(*)::integer
    from atlas_legacy.import_batches
    where snapshot_id in (
      'rmvp02b-valid-explicit-export',
      'rmvp02b-missing-reference-export',
      'rmvp02b-historical-overlap-export'
    )
      and result_payload is not null
  ),
  3,
  'completed and rejected import batches retain durable evidence'
);

create or replace function pg_temp.rmvp02b_read(
  p_payload jsonb,
  p_subject uuid default 'b2000000-0000-0000-0000-000000000101'
)
returns jsonb
language sql
as $$
  select jsonb_build_object(
    'contract_version', 'RMVP-02B.v1',
    'correlation_id', 'b2900000-0000-0000-0000-000000000001',
    'requested_by_auth_subject', p_subject,
    'payload', p_payload
  );
$$;

create or replace function pg_temp.rmvp02b_command(
  p_name text,
  p_expected_version bigint,
  p_payload jsonb,
  p_subject uuid default 'b2000000-0000-0000-0000-000000000101'
)
returns jsonb
language sql
as $$
  select jsonb_build_object(
    'contract_version', 'RMVP-02B.v1',
    'command_id', md5('rmvp02b-command:' || p_name)::uuid,
    'correlation_id', 'b2900000-0000-0000-0000-000000000001',
    'idempotency_key', 'rmvp02b:' || p_name,
    'expected_version', p_expected_version,
    'requested_by_auth_subject', p_subject,
    'requested_at', transaction_timestamp() - interval '1 second',
    'reason_code', 'RMVP02B_TEST',
    'reason_note', 'Rolled-back RMVP-02B acceptance test: ' || p_name,
    'payload', p_payload
  );
$$;

create temporary table rmvp02b_results (
  result_name text primary key,
  response_payload jsonb not null
);
grant select, insert on rmvp02b_results to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b2000000-0000-0000-0000-000000000101',
  true
);

insert into rmvp02b_results values (
  'authorized-workbench',
  atlas_api.get_recipe_adjustment_workbench(
    pg_temp.rmvp02b_read('{}'::jsonb)
  )
);

insert into rmvp02b_results values (
  'authorized-resolution',
  atlas_api.resolve_effective_recipe_composition(
    pg_temp.rmvp02b_read(
      jsonb_build_object(
        'as_of_date', '2026-07-15',
        'school_id', 'b2100000-0000-0000-0000-000000000120',
        'dish_id', 'b2200000-0000-0000-0000-000000000100'
      )
    )
  )
);

insert into rmvp02b_results values (
  'missing-as-of-date',
  atlas_api.resolve_effective_recipe_composition(
    pg_temp.rmvp02b_read(
      jsonb_build_object(
        'school_id', 'b2100000-0000-0000-0000-000000000120',
        'dish_id', 'b2200000-0000-0000-0000-000000000100'
      )
    )
  )
);

insert into rmvp02b_results values (
  'preview-create',
  atlas_api.preview_recipe_composition_adjustment(
    pg_temp.rmvp02b_read(
      jsonb_build_object(
        'as_of_date', '2026-07-15',
        'school_id', 'b2100000-0000-0000-0000-000000000120',
        'dish_id', 'b2200000-0000-0000-0000-000000000100',
        'proposed_adjustment', jsonb_build_object(
          'adjustment_id', 'b2400000-0000-0000-0000-000000000001',
          'revision_id', 'b2410000-0000-0000-0000-000000000001',
          'scope_kind', 'SYSTEM_DISH',
          'action_kind', 'ADJUST_QUANTITY',
          'dish_id', 'b2200000-0000-0000-0000-000000000100',
          'target_recipe_line_id',
            'b2200000-0000-0000-0000-000000000401',
          'quantity_per_basis', 7,
          'effective_from', '2026-07-01',
          'reason_code', 'RMVP02B_TEST',
          'reason_note', 'Authenticated no-write preview.'
        )
      )
    )
  )
);

insert into rmvp02b_results values (
  'create',
  atlas_api.create_recipe_composition_adjustment(
    pg_temp.rmvp02b_command(
      'create',
      1,
      jsonb_build_object(
        'adjustment_id', 'b2400000-0000-0000-0000-000000000001',
        'revision_id', 'b2410000-0000-0000-0000-000000000001',
        'scope_kind', 'SYSTEM_DISH',
        'action_kind', 'ADJUST_QUANTITY',
        'dish_id', 'b2200000-0000-0000-0000-000000000100',
        'target_recipe_line_id',
          'b2200000-0000-0000-0000-000000000401',
        'quantity_per_basis', 7,
        'effective_from', '2026-07-01',
        'as_of_date', '2026-07-15',
        'preview_school_id', 'b2100000-0000-0000-0000-000000000120',
        'preview_dish_id', 'b2200000-0000-0000-0000-000000000100',
        'source_evidence', '{"source":"authenticated-test"}'::jsonb
      )
    )
  )
);

insert into rmvp02b_results values (
  'create-replay',
  atlas_api.create_recipe_composition_adjustment(
    pg_temp.rmvp02b_command(
      'create',
      1,
      jsonb_build_object(
        'adjustment_id', 'b2400000-0000-0000-0000-000000000001',
        'revision_id', 'b2410000-0000-0000-0000-000000000001',
        'scope_kind', 'SYSTEM_DISH',
        'action_kind', 'ADJUST_QUANTITY',
        'dish_id', 'b2200000-0000-0000-0000-000000000100',
        'target_recipe_line_id',
          'b2200000-0000-0000-0000-000000000401',
        'quantity_per_basis', 7,
        'effective_from', '2026-07-01',
        'as_of_date', '2026-07-15',
        'preview_school_id', 'b2100000-0000-0000-0000-000000000120',
        'preview_dish_id', 'b2200000-0000-0000-0000-000000000100',
        'source_evidence', '{"source":"authenticated-test"}'::jsonb
      )
    )
  )
);

insert into rmvp02b_results values (
  'backdated-supersede',
  atlas_api.supersede_recipe_composition_adjustment(
    pg_temp.rmvp02b_command(
      'backdated-supersede',
      1,
      jsonb_build_object(
        'adjustment_id', 'b2400000-0000-0000-0000-000000000001',
        'revision_id', 'b2410000-0000-0000-0000-000000000099',
        'predecessor_revision_id',
          'b2410000-0000-0000-0000-000000000001',
        'quantity_per_basis', 8,
        'effective_from', '2026-06-01',
        'as_of_date', '2026-07-15',
        'preview_school_id', 'b2100000-0000-0000-0000-000000000120',
        'preview_dish_id', 'b2200000-0000-0000-0000-000000000100'
      )
    )
  )
);

insert into rmvp02b_results values (
  'supersede',
  atlas_api.supersede_recipe_composition_adjustment(
    pg_temp.rmvp02b_command(
      'supersede',
      1,
      jsonb_build_object(
        'adjustment_id', 'b2400000-0000-0000-0000-000000000001',
        'revision_id', 'b2410000-0000-0000-0000-000000000002',
        'predecessor_revision_id',
          'b2410000-0000-0000-0000-000000000001',
        'quantity_per_basis', 9,
        'effective_from', '2026-08-01',
        'as_of_date', '2026-08-01',
        'preview_school_id', 'b2100000-0000-0000-0000-000000000120',
        'preview_dish_id', 'b2200000-0000-0000-0000-000000000100',
        'source_evidence', '{"source":"authenticated-correction"}'::jsonb
      )
    )
  )
);

insert into rmvp02b_results values (
  'historical-before-successor',
  atlas_api.resolve_effective_recipe_composition(
    pg_temp.rmvp02b_read(
      jsonb_build_object(
        'as_of_date', '2026-07-15',
        'school_id', 'b2100000-0000-0000-0000-000000000120',
        'dish_id', 'b2200000-0000-0000-0000-000000000100'
      )
    )
  )
);

insert into rmvp02b_results values (
  'successor-effective',
  atlas_api.resolve_effective_recipe_composition(
    pg_temp.rmvp02b_read(
      jsonb_build_object(
        'as_of_date', '2026-08-10',
        'school_id', 'b2100000-0000-0000-0000-000000000120',
        'dish_id', 'b2200000-0000-0000-0000-000000000100'
      )
    )
  )
);

insert into rmvp02b_results values (
  'cancel',
  atlas_api.cancel_recipe_composition_adjustment(
    pg_temp.rmvp02b_command(
      'cancel',
      2,
      jsonb_build_object(
        'adjustment_id', 'b2400000-0000-0000-0000-000000000001',
        'revision_id', 'b2410000-0000-0000-0000-000000000003',
        'predecessor_revision_id',
          'b2410000-0000-0000-0000-000000000002',
        'effective_from', '2026-08-15'
      )
    )
  )
);

insert into rmvp02b_results values (
  'historical-after-cancel',
  atlas_api.resolve_effective_recipe_composition(
    pg_temp.rmvp02b_read(
      jsonb_build_object(
        'as_of_date', '2026-08-10',
        'school_id', 'b2100000-0000-0000-0000-000000000120',
        'dish_id', 'b2200000-0000-0000-0000-000000000100'
      )
    )
  )
);

insert into rmvp02b_results values (
  'post-cancel',
  atlas_api.resolve_effective_recipe_composition(
    pg_temp.rmvp02b_read(
      jsonb_build_object(
        'as_of_date', '2026-08-15',
        'school_id', 'b2100000-0000-0000-0000-000000000120',
        'dish_id', 'b2200000-0000-0000-0000-000000000100'
      )
    )
  )
);

insert into rmvp02b_results values (
  'stale-cancel',
  atlas_api.cancel_recipe_composition_adjustment(
    pg_temp.rmvp02b_command(
      'stale-cancel',
      2,
      jsonb_build_object(
        'adjustment_id', 'b2400000-0000-0000-0000-000000000001',
        'revision_id', 'b2410000-0000-0000-0000-000000000004',
        'predecessor_revision_id',
          'b2410000-0000-0000-0000-000000000002',
        'effective_from', '2026-08-16'
      )
    )
  )
);

insert into rmvp02b_results values (
  'workbench-after-cancel',
  atlas_api.get_recipe_adjustment_workbench(
    pg_temp.rmvp02b_read('{}'::jsonb)
  )
);

select set_config(
  'request.jwt.claim.sub',
  'b2000000-0000-0000-0000-000000000102',
  true
);

insert into rmvp02b_results values (
  'denied-read',
  atlas_api.get_recipe_adjustment_workbench(
    pg_temp.rmvp02b_read(
      '{}'::jsonb,
      'b2000000-0000-0000-0000-000000000102'
    )
  )
);

insert into rmvp02b_results values (
  'denied-preview',
  atlas_api.preview_recipe_composition_adjustment(
    pg_temp.rmvp02b_read(
      jsonb_build_object(
        'as_of_date', '2026-07-15',
        'school_id', 'b2100000-0000-0000-0000-000000000120',
        'dish_id', 'b2200000-0000-0000-0000-000000000100',
        'proposed_adjustment', '{}'::jsonb
      ),
      'b2000000-0000-0000-0000-000000000102'
    )
  )
);

select throws_ok(
  $$select count(*) from atlas_admin.recipe_composition_adjustments$$,
  '42501',
  'permission denied for schema atlas_admin',
  'authenticated cannot bypass the API to read private adjustment roots'
);

reset role;

select ok(
  (
    select bool_and((response_payload ->> 'success')::boolean)
    from rmvp02b_results
    where result_name in (
      'authorized-workbench',
      'authorized-resolution',
      'preview-create',
      'create',
      'create-replay',
      'supersede',
      'historical-before-successor',
      'successor-effective',
      'cancel',
      'historical-after-cancel',
      'post-cancel',
      'workbench-after-cancel'
    )
  ),
  'the authenticated read, preview, create, replay, supersede, cancel, and history workflow succeeds'
);

select ok(
  (
    select (response_payload #>> '{preview,can_save}')::boolean
      and (
        response_payload #>> '{preview,affected_line_count}'
      )::integer = 1
      and response_payload #>> '{preview,before,status}' = 'READY'
      and response_payload #>> '{preview,after,status}' = 'READY'
    from rmvp02b_results
    where result_name = 'preview-create'
  ),
  'what-if preview uses the resolver, returns before/after, and performs no write'
);

select ok(
  (
    with preview_line as (
      select
        result.response_payload #>> '{preview,after,recipe_version_id}'
          as recipe_version_id,
        line ->> 'base_recipe_line_id' as base_recipe_line_id,
        line ->> 'final_ingredient_id' as final_ingredient_id,
        (line ->> 'final_quantity_per_basis')::numeric
          as final_quantity_per_basis,
        line ->> 'final_unit_id' as final_unit_id,
        line ->> 'final_disposition' as final_disposition,
        line ->> 'source_layer' as source_layer
      from rmvp02b_results result,
        jsonb_array_elements(
          result.response_payload #> '{preview,after,lines}'
        ) line
      where result.result_name = 'preview-create'
        and line ->> 'base_recipe_line_id' =
          'b2200000-0000-0000-0000-000000000401'
    ),
    persisted_line as (
      select
        result.response_payload #>> '{resolution,recipe_version_id}'
          as recipe_version_id,
        line ->> 'base_recipe_line_id' as base_recipe_line_id,
        line ->> 'final_ingredient_id' as final_ingredient_id,
        (line ->> 'final_quantity_per_basis')::numeric
          as final_quantity_per_basis,
        line ->> 'final_unit_id' as final_unit_id,
        line ->> 'final_disposition' as final_disposition,
        line ->> 'source_layer' as source_layer
      from rmvp02b_results result,
        jsonb_array_elements(
          result.response_payload #> '{resolution,lines}'
        ) line
      where result.result_name = 'historical-before-successor'
        and line ->> 'base_recipe_line_id' =
          'b2200000-0000-0000-0000-000000000401'
    )
    select preview_line = persisted_line
    from preview_line
    cross join persisted_line
  ),
  'preview and persisted resolution are equivalent for unchanged authoritative inputs'
);

select is(
  (
    select response_payload ->> 'error_code'
    from rmvp02b_results
    where result_name = 'missing-as-of-date'
  ),
  'VALIDATION_FAILED',
  'authoritative effective resolution rejects a missing explicit as_of_date'
);

select is(
  (
    select count(*)::integer
    from atlas_admin.recipe_composition_adjustments
    where recipe_composition_adjustment_id =
      'b2400000-0000-0000-0000-000000000001'
  ),
  1,
  'idempotent replay produces one stable adjustment root'
);

select is(
  (
    select response_payload ->> 'idempotency_status'
    from rmvp02b_results
    where result_name = 'create-replay'
  ),
  'COMPLETED',
  'an exact create replay returns the original durable successful receipt'
);

select is(
  (
    select response_payload ->> 'error_code'
    from rmvp02b_results
    where result_name = 'backdated-supersede'
  ),
  'VALIDATION_FAILED',
  'a successor cannot move the direct correction chain backward in effective time'
);

select is(
  (
    select line ->> 'final_quantity_per_basis'
    from rmvp02b_results result,
      jsonb_array_elements(
        result.response_payload #> '{resolution,lines}'
      ) line
    where result.result_name = 'historical-before-successor'
      and line ->> 'base_recipe_line_id' =
        'b2200000-0000-0000-0000-000000000401'
  ),
  '7.000000',
  'a superseding correction preserves the prior dated revision'
);

select is(
  (
    select line ->> 'final_quantity_per_basis'
    from rmvp02b_results result,
      jsonb_array_elements(
        result.response_payload #> '{resolution,lines}'
      ) line
    where result.result_name in (
        'successor-effective',
        'historical-after-cancel'
      )
      and line ->> 'base_recipe_line_id' =
        'b2200000-0000-0000-0000-000000000401'
    limit 1
  ),
  '9.000000',
  'the direct successor is authoritative from its effective date and remains historically resolvable'
);

select is(
  (
    select line ->> 'final_quantity_per_basis'
    from rmvp02b_results result,
      jsonb_array_elements(
        result.response_payload #> '{resolution,lines}'
      ) line
    where result.result_name = 'post-cancel'
      and line ->> 'base_recipe_line_id' =
        'b2200000-0000-0000-0000-000000000401'
  ),
  '5.000000',
  'dated cancellation stops future rule effect without recalculating the base Recipe'
);

select is(
  (
    select response_payload ->> 'error_code'
    from rmvp02b_results
    where result_name = 'stale-cancel'
  ),
  'STALE_VERSION',
  'stale mutation fails closed'
);

select is(
  (
    select count(*)::integer
    from atlas_admin.recipe_composition_adjustment_revisions
    where recipe_composition_adjustment_id =
      'b2400000-0000-0000-0000-000000000001'
  ),
  3,
  'create, supersede, and cancellation append one direct immutable revision each'
);

select is(
  (
    select array_agg(revision ->> 'lifecycle_status' order by
      (revision ->> 'revision_number')::integer
    )::text[]
    from rmvp02b_results result,
      jsonb_array_elements(
        result.response_payload #> '{workbench,adjustments}'
      ) adjustment,
      jsonb_array_elements(adjustment -> 'revisions') revision
    where result.result_name = 'workbench-after-cancel'
      and adjustment ->> 'adjustment_id' =
        'b2400000-0000-0000-0000-000000000001'
  ),
  array['SUPERSEDED', 'SUPERSEDED', 'CANCELLED']::text[],
  'workbench lineage exposes superseded history and the current cancellation'
);

select is(
  (
    select response_payload ->> 'error_code'
    from rmvp02b_results
    where result_name = 'denied-read'
  ),
  'CAPABILITY_DENIED',
  'read capability denial fails closed'
);

select is(
  (
    select response_payload ->> 'error_code'
    from rmvp02b_results
    where result_name = 'denied-preview'
  ),
  'CAPABILITY_DENIED',
  'preview requires write authority and fails closed'
);

select ok(
  (
    select jsonb_array_length(
      response_payload -> 'emitted_event_ids'
    ) = 1
      and jsonb_array_length(
        response_payload -> 'audit_event_ids'
      ) = 1
      and response_payload ->> 'command_id' is not null
    from rmvp02b_results
    where result_name = 'cancel'
  ),
  'accepted commands return complete command, domain-event, and audit identities'
);

select throws_ok(
  $$
    update atlas_admin.recipe_composition_adjustment_revisions
    set reason_note = 'Attempted mutation'
    where recipe_composition_adjustment_revision_id =
      'b2410000-0000-0000-0000-000000000001'
  $$,
  '23514',
  'accepted Recipe composition adjustment revisions are immutable and cannot be deleted',
  'accepted revisions cannot be updated'
);

select throws_ok(
  $$
    delete from atlas_admin.recipe_composition_adjustment_revisions
    where recipe_composition_adjustment_revision_id =
      'b2410000-0000-0000-0000-000000000001'
  $$,
  '23514',
  'accepted Recipe composition adjustment revisions are immutable and cannot be deleted',
  'accepted revisions cannot be deleted'
);

select throws_ok(
  $$
    delete from atlas_admin.recipe_composition_adjustments
    where recipe_composition_adjustment_id =
      'b2400000-0000-0000-0000-000000000001'
  $$,
  '23514',
  'Recipe composition adjustment roots cannot be deleted',
  'stable adjustment roots cannot be hard-deleted'
);

select * from finish();
rollback;
